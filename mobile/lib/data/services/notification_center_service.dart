import 'package:egg_gym/app/routes/app_routes.dart';
import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:egg_gym/data/services/backend_notification_service.dart';
import 'package:egg_gym/presentation/controllers/member_shell_controller.dart';
import 'package:egg_gym/presentation/controllers/trainer_shell_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class NotificationCenterService extends ChangeNotifier {
  NotificationCenterService._() {
    AppSessionService.instance.addListener(_sessionChanged);
    _sessionIdentity = _currentSessionIdentity;
  }
  static final instance = NotificationCenterService._();

  final BackendNotificationService _backend = BackendNotificationService();
  List<NotificationItem> items = const [];
  int unreadCount = 0;
  bool loading = false;
  bool markingAllRead = false;
  String? error;
  final Set<int> _openingIds = <int>{};
  int _generation = 0;
  String? _sessionIdentity;
  Map<String, dynamic>? _pendingPushData;

  String? get _currentSessionIdentity {
    final session = AppSessionService.instance.currentSession;
    return session == null
        ? null
        : '${session.baseUrl}|${session.role}|${session.userId}|${session.token}';
  }

  void _sessionChanged() {
    final identity = _currentSessionIdentity;
    if (identity == _sessionIdentity) return;
    _sessionIdentity = identity;
    clear(clearPendingPush: identity == null);
  }

  Future<void> refresh() async {
    final identity = _currentSessionIdentity;
    if (identity == null) {
      clear();
      return;
    }
    final generation = _generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await _backend.getNotifications();
      if (generation != _generation || identity != _currentSessionIdentity) {
        return;
      }
      items = result.items;
      unreadCount = result.unreadCount;
    } catch (exception) {
      if (generation != _generation || identity != _currentSessionIdentity) {
        return;
      }
      error = exception.toString();
    } finally {
      if (generation == _generation && identity == _currentSessionIdentity) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> open(NotificationItem item) async {
    if (!_openingIds.add(item.id)) return;
    final identity = _currentSessionIdentity;
    final generation = _generation;
    try {
      if (!item.isRead) {
        final updated = await _backend.markAsRead(item.id);
        if (generation != _generation || identity != _currentSessionIdentity) {
          return;
        }
        items = items
            .map((current) => current.id == item.id ? updated : current)
            .toList();
        unreadCount = items.where((current) => !current.isRead).length;
        notifyListeners();
      }
      if (generation == _generation && identity == _currentSessionIdentity) {
        _route(item.data);
      }
    } catch (exception) {
      if (generation == _generation && identity == _currentSessionIdentity) {
        error = exception.toString();
        notifyListeners();
      }
    } finally {
      _openingIds.remove(item.id);
    }
  }

  Future<void> markAllRead() async {
    if (markingAllRead || unreadCount == 0) return;
    final identity = _currentSessionIdentity;
    final generation = _generation;
    markingAllRead = true;
    error = null;
    notifyListeners();
    try {
      await _backend.markAllAsRead();
      if (generation != _generation || identity != _currentSessionIdentity) {
        return;
      }
      items = items.map((item) => item.copyWith(isRead: true)).toList();
      unreadCount = 0;
    } catch (exception) {
      if (generation == _generation && identity == _currentSessionIdentity) {
        error = exception.toString();
      }
    } finally {
      if (generation == _generation && identity == _currentSessionIdentity) {
        markingAllRead = false;
        notifyListeners();
      }
    }
  }

  void clear({bool clearPendingPush = true}) {
    _generation++;
    items = const [];
    unreadCount = 0;
    loading = false;
    markingAllRead = false;
    _openingIds.clear();
    if (clearPendingPush) _pendingPushData = null;
    error = null;
    notifyListeners();
  }

  void handlePushData(Map<String, dynamic> data, {bool open = false}) {
    if (AppSessionService.instance.isAuthenticated) refresh();
    if (open) _pendingPushData = Map<String, dynamic>.from(data);
  }

  void dispatchPendingPush() {
    final data = _pendingPushData;
    if (data == null || !AppSessionService.instance.isAuthenticated) return;
    if (_route(data)) _pendingPushData = null;
  }

  bool _route(Map<String, dynamic> data) {
    final target = data['target']?.toString();
    final role = AppSessionService.instance.currentSession?.role;
    final bookingId = int.tryParse(data['booking_id']?.toString() ?? '');
    final programId = int.tryParse(data['program_id']?.toString() ?? '');

    if (role == 'member') {
      if (target == 'booking_payment' && bookingId != null) {
        Get.toNamed(AppRoutes.bookingPayment,
            arguments: {'bookingId': bookingId});
        return true;
      } else if (target == 'program' && programId != null) {
        Get.toNamed(AppRoutes.memberSessionTimeline,
            arguments: {'programId': programId});
        return true;
      } else if (Get.isRegistered<MemberShellController>()) {
        Get.find<MemberShellController>().changeTab(target == 'membership'
            ? 3
            : target == 'program'
                ? 1
                : 0);
        Get.until((route) => route.settings.name == AppRoutes.memberShell);
        return true;
      }
    } else if (role == 'trainer' &&
        Get.isRegistered<TrainerShellController>()) {
      Get.find<TrainerShellController>()
          .changeTab(target == 'trainer_program' ? 3 : 1);
      Get.until((route) => route.settings.name == AppRoutes.trainerShell);
      return true;
    }
    return false;
  }
}
