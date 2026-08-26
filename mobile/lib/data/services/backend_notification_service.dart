import 'dart:async';
import 'dart:convert';

import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:egg_gym/data/services/backend_api_config.dart';
import 'package:http/http.dart' as http;

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.priority,
    required this.data,
    required this.isRead,
    this.sentAt,
  });

  final int id;
  final String title;
  final String message;
  final String type;
  final String priority;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime? sentAt;

  NotificationItem copyWith({bool? isRead}) => NotificationItem(
        id: id,
        title: title,
        message: message,
        type: type,
        priority: priority,
        data: data,
        isRead: isRead ?? this.isRead,
        sentAt: sentAt,
      );

  String get timeLabel {
    if (sentAt == null) return '-';
    final diff = DateTime.now().difference(sentAt!.toLocal());
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return '${sentAt!.day}/${sentAt!.month}/${sentAt!.year}';
  }

  String get typeIcon => switch (type) {
        'membership' => '⭐',
        'booking' => '📅',
        'payment' => '💳',
        'program' => '📋',
        'schedule' => '⏰',
        'reminder' => '🔔',
        _ => '📌',
      };
}

class NotificationListResult {
  const NotificationListResult(
      {required this.items, required this.unreadCount});
  final List<NotificationItem> items;
  final int unreadCount;
}

class BackendNotificationService {
  BackendNotificationService({http.Client? client})
      : _client = client ?? http.Client();
  final http.Client _client;

  ({String baseUrl, String token, String role}) _authenticate() {
    final session = AppSessionService.instance.currentSession;
    if (session == null) {
      throw Exception('Sesi pengguna belum aktif.');
    }
    if (!['member', 'trainer'].contains(session.role)) {
      throw Exception('Role tidak mendukung pusat notifikasi.');
    }
    return (baseUrl: session.baseUrl, token: session.token, role: session.role);
  }

  Future<NotificationListResult> getNotifications() async {
    final auth = _authenticate();
    final response = await _client
        .get(
          Uri.parse('${auth.baseUrl}/api/v1/${auth.role}/notifications'),
          headers: _headers(auth.token),
        )
        .timeout(BackendApiConfig.requestTimeout);
    final payload = _decodeJson(response.body);
    _assertSuccess(response, payload, 'Gagal memuat notifikasi');
    final data = payload['data'];
    final items = data is List
        ? data.whereType<Map<String, dynamic>>().map(_parseItem).toList()
        : <NotificationItem>[];
    final meta = payload['meta'];
    final unread = meta is Map<String, dynamic>
        ? _asInt(meta['unread_count']) ??
            items.where((item) => !item.isRead).length
        : items.where((item) => !item.isRead).length;
    return NotificationListResult(items: items, unreadCount: unread);
  }

  Future<NotificationItem> markAsRead(int notificationId) async {
    final auth = _authenticate();
    final response = await _client
        .post(
          Uri.parse(
              '${auth.baseUrl}/api/v1/${auth.role}/notifications/$notificationId/read'),
          headers: _headers(auth.token),
        )
        .timeout(BackendApiConfig.requestTimeout);
    final payload = _decodeJson(response.body);
    _assertSuccess(response, payload, 'Gagal menandai notifikasi');
    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('Response notifikasi tidak valid.');
    }
    return _parseItem(data);
  }

  Future<void> markAllAsRead() async {
    final auth = _authenticate();
    final response = await _client
        .post(
          Uri.parse(
              '${auth.baseUrl}/api/v1/${auth.role}/notifications/read-all'),
          headers: _headers(auth.token),
        )
        .timeout(BackendApiConfig.requestTimeout);
    final payload = _decodeJson(response.body);
    _assertSuccess(response, payload, 'Gagal menandai semua notifikasi');
  }

  void close() => _client.close();

  NotificationItem _parseItem(Map<String, dynamic> item) => NotificationItem(
        id: _asInt(item['id']) ?? 0,
        title: _asString(item['title']) ?? 'Notifikasi',
        message: _asString(item['message']) ?? '-',
        type: _asString(item['type']) ?? 'general',
        priority: _asString(item['priority']) ?? 'normal',
        data: item['data'] is Map<String, dynamic>
            ? item['data'] as Map<String, dynamic>
            : const {},
        isRead: item['is_read'] == true,
        sentAt: _parseDateTime(item['sent_at'] ?? item['created_at']),
      );

  Map<String, String> _headers(String token) =>
      {'Accept': 'application/json', 'Authorization': 'Bearer $token'};

  void _assertSuccess(
      http.Response response, Map<String, dynamic> payload, String fallback) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception('Sesi habis atau role tidak diizinkan.');
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        payload['success'] != true) {
      throw Exception(payload['message'] ?? fallback);
    }
  }

  Map<String, dynamic> _decodeJson(String rawBody) {
    if (rawBody.isEmpty) return const {};
    final decoded = jsonDecode(rawBody);
    return decoded is Map<String, dynamic> ? decoded : const {};
  }

  static int? _asInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
  static String? _asString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static DateTime? _parseDateTime(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString());
}
