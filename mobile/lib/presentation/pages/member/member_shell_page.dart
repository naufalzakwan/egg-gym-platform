import 'package:egg_gym/app/routes/app_routes.dart';
import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/core/utils/member_program_rating.dart';
import 'package:egg_gym/core/utils/membership_duration_label.dart';
import 'package:egg_gym/core/utils/member_trainer_rating_refresh.dart';
import 'package:egg_gym/core/utils/monthly_workout_count_display.dart';
import 'package:egg_gym/core/utils/payment_verification_overdue_copy.dart';
import 'package:egg_gym/core/utils/physical_progress_weight_preview.dart';
import 'package:egg_gym/core/utils/trainer_schedule_visibility.dart';
import 'package:egg_gym/core/utils/trainer_rating_display.dart';
import 'package:egg_gym/core/utils/trainer_tier.dart';
import 'package:egg_gym/core/formatters/app_date_formatter.dart';
import 'package:egg_gym/core/constants/trainer_specialties.dart';
import 'package:egg_gym/core/utils/public_storage_url.dart';
import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:egg_gym/data/services/backend_member_service.dart';
import 'package:egg_gym/data/services/backend_trainer_service.dart';
import 'package:egg_gym/data/services/backend_payment_service.dart';
import 'package:egg_gym/data/services/backend_public_service.dart';
import 'package:egg_gym/data/services/backend_self_training_service.dart';
import 'package:egg_gym/data/services/notification_center_service.dart';
import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:egg_gym/domain/repositories/demo_repository.dart';
import 'package:egg_gym/presentation/controllers/member_shell_controller.dart';
import 'package:egg_gym/presentation/pages/details/pending_payment_helper.dart';
import 'package:egg_gym/presentation/pages/details/member_trainer_rating_page.dart';
import 'package:egg_gym/presentation/providers/workout_timer_provider.dart';
import 'package:egg_gym/presentation/widgets/common/egg_button.dart';
import 'package:egg_gym/presentation/widgets/common/egg_card.dart';
import 'package:egg_gym/presentation/widgets/common/initial_avatar.dart';
import 'package:egg_gym/presentation/widgets/common/member_transaction_tile.dart';
import 'package:egg_gym/presentation/widgets/common/profile_avatar_editor.dart';
import 'package:egg_gym/presentation/widgets/common/status_chip.dart';
import 'package:egg_gym/presentation/widgets/common/booking_expiry_countdown.dart';
import 'package:egg_gym/presentation/widgets/common/reschedule_request_card.dart';
import 'package:egg_gym/presentation/widgets/common/trainer_rating_dialog.dart';
import 'package:egg_gym/presentation/widgets/common/notification_bell_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class MemberShellPage extends StatefulWidget {
  const MemberShellPage({super.key});

  @override
  State<MemberShellPage> createState() => _MemberShellPageState();
}

class _MemberShellPageState extends State<MemberShellPage>
    with WidgetsBindingObserver {
  final MemberShellController _controller = Get.find<MemberShellController>();
  final BackendPublicService _publicService = BackendPublicService();
  final BackendMemberService _memberService = BackendMemberService();
  Worker? _tabWorker;

  late MemberDashboardData _dashboard;
  // Equipment tidak memakai demo fallback: kosong sampai public API berhasil.
  List<EquipmentInfo> _equipments = const <EquipmentInfo>[];
  List<TrainerProfile> _trainers = const <TrainerProfile>[];
  bool _isTrainersLoading = false;
  String? _trainersError;
  List<MembershipPlan> _plans = const <MembershipPlan>[];
  bool _isPlansLoading = false;
  String? _plansError;
  MemberPhysicalProgressSnapshot? _physicalProgressSnapshot;
  bool _physicalProgressLoaded = false;
  // Profil member (berat badan, target/goal) dari backend. Null bila belum
  // ter-load; field-nya sendiri boleh null bila member belum mengisi.
  MemberProfileData? _memberProfile;
  bool _memberProfileRequestFailed = false;
  // Status engagement PT aktif (untuk disable tombol Booking di tab Trainer).
  bool _hasActivePtEngagement = false;
  String? _activePtTrainerName;
  String? _activePtStatus;
  // Tri-state: true/false hanya berasal dari response dashboard sukses; null
  // berarti belum diketahui / network error dan TIDAK boleh dianggap incomplete.
  final ValueNotifier<bool?> _profileComplete = ValueNotifier<bool?>(null);
  // Lazy-load: tab yang datanya sudah (mulai) di-fetch, agar tidak fetch ulang
  // saat berpindah tab. Mencegah burst request serentak saat cold start.
  final Set<int> _loadedTabs = <int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final repo = context.read<DemoRepository>();
    _dashboard = repo.getMemberDashboard();

    // Home (tab 0) fetch duluan dengan prioritas tertinggi saat login.
    _ensureTabLoaded(_controller.currentIndex.value);
    NotificationCenterService.instance.refresh();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => NotificationCenterService.instance.dispatchPendingPush(),
    );

    // Lazy-load: tab lain baru fetch saat pertama kali dibuka user.
    _tabWorker = ever(_controller.currentIndex, (int index) {
      if (index == 3) {
        _reloadTab(index);
      } else {
        _ensureTabLoaded(index);
      }
    });
  }

  @override
  void dispose() {
    _tabWorker?.dispose();
    _profileComplete.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationCenterService.instance.refresh();
      // Saat app kembali aktif, segarkan hanya tab yang sedang dibuka.
      _reloadTab(_controller.currentIndex.value);
    }
  }

  /// Fetch data untuk sebuah tab jika belum pernah di-load (lazy-load).
  void _ensureTabLoaded(int index) {
    if (_loadedTabs.contains(index)) return;
    _loadedTabs.add(index);
    _reloadTab(index);
  }

  /// Muat/segarkan data spesifik per tab (dipakai lazy-load & pull-to-refresh).
  void _reloadTab(int index) {
    switch (index) {
      case 0: // Home
        _loadDashboardData();
        break;
      case 2: // Trainer (butuh daftar trainer + flag engagement dari dashboard)
        _loadDashboardData();
        _loadTrainersData();
        break;
      case 3: // Membership (butuh sisa hari dari dashboard + daftar paket)
        _loadDashboardData();
        _loadPlansData();
        break;
      case 4: // Profile (equipment + profil member utk berat badan/target)
        _loadEquipmentsData();
        _loadMemberProfile();
        _loadPhysicalProgressData();
        break;
      // Tab 1 (Program) memakai data internal tab-nya sendiri.
    }
  }

  /// Loader Home/dashboard — sumber data utama (nama, tier, sisa hari, next
  /// session, flag engagement, kelengkapan profil).
  Future<void> _loadDashboardData() async {
    try {
      final liveDashboard = await _memberService.getDashboard();
      if (!mounted) return;

      setState(() {
        _dashboard = MemberDashboardData(
          memberName: liveDashboard.memberName,
          currentTier: liveDashboard.currentTier,
          packageName: liveDashboard.packageName,
          validUntil: liveDashboard.validUntil,
          remainingDays: liveDashboard.remainingDays,
          nextSession: liveDashboard.nextSession ??
              const ScheduleSession(
                clientName: '-',
                timeRange: '-',
                location: '-',
                status: 'Tidak ada',
                note: 'Belum ada sesi terjadwal',
              ),
          programSessions: _dashboard.programSessions,
          recentTransactions: _dashboard.recentTransactions,
        );
        _hasActivePtEngagement = liveDashboard.hasActivePtEngagement;
        _activePtTrainerName = liveDashboard.activePtTrainerName;
        _activePtStatus = liveDashboard.activePtStatus;
        _profileComplete.value = liveDashboard.profileComplete;
      });
    } catch (_) {
      _profileComplete.value = null;
      _loadedTabs.remove(0); // izinkan retry saat tab dibuka lagi
    }
  }

  Future<void> _loadTrainersData() async {
    if (mounted) {
      setState(() {
        _isTrainersLoading = true;
        _trainersError = null;
      });
    }
    try {
      final trainers = await _publicService.getTrainers();
      if (!mounted) return;
      setState(() {
        _trainers = trainers;
        _isTrainersLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isTrainersLoading = false;
        _trainersError = 'Daftar Personal Trainer belum dapat dimuat.';
      });
      _loadedTabs.remove(2);
    }
  }

  Future<void> _refreshTrainersTab() async {
    await Future.wait([
      _loadDashboardData(),
      _loadTrainersData(),
    ]);
  }

  Future<void> _loadPlansData() async {
    if (mounted) {
      setState(() {
        _isPlansLoading = true;
        _plansError = null;
      });
    }
    try {
      final plans = await _publicService.getMembershipPlans();
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _isPlansLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _plans = const [];
        _isPlansLoading = false;
        _plansError = 'Daftar paket membership belum dapat dimuat.';
      });
      _loadedTabs.remove(3);
    }
  }

  Future<void> _loadEquipmentsData() async {
    try {
      final equipments = await _publicService.getEquipments();
      if (!mounted) return;
      setState(() => _equipments = equipments);
    } catch (_) {
      _loadedTabs.remove(4);
    }
  }

  /// Muat profil member (berat badan & target) untuk kartu statistik di tab
  /// Profil. Data nyata dari backend; kalau gagal, biarkan null -> UI tampil
  /// state kosong ("Belum diisi"), bukan dummy.
  Future<void> _loadMemberProfile() async {
    if (mounted) setState(() => _memberProfileRequestFailed = false);
    try {
      final profile = await _memberService.getProfile();
      if (!mounted) return;
      setState(() {
        _memberProfile = profile;
        _memberProfileRequestFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _memberProfileRequestFailed = true);
      _loadedTabs.remove(4);
    }
  }

  Future<void> _loadPhysicalProgressData() async {
    try {
      final snapshot = await _memberService.getPhysicalProgress();
      if (!mounted) return;
      setState(() {
        _physicalProgressSnapshot = snapshot;
        _physicalProgressLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _physicalProgressSnapshot = null;
        _physicalProgressLoaded = false;
      });
      _loadedTabs.remove(4);
    }
  }

  /// Refresh penuh (dipakai pull-to-refresh di Home) — dashboard + trainer.
  Future<void> _loadLiveData() async {
    await _loadDashboardData();
    await _loadTrainersData();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _HomeTab(dashboard: _dashboard, onRefresh: _loadLiveData),
      _ProgramTab(
        sessions: _dashboard.programSessions,
        nextBooking: _dashboard.nextSession,
        onRatingSubmitted: _loadTrainersData,
      ),
      _TrainersTabV2(
        trainers: _trainers,
        isLoading: _isTrainersLoading,
        error: _trainersError,
        onRefresh: _refreshTrainersTab,
        hasActivePtEngagement: _hasActivePtEngagement,
        activePtTrainerName: _activePtTrainerName,
        activePtStatus: _activePtStatus,
        profileCompleteness: _profileComplete,
      ),
      _MembershipTabV2(
        dashboard: _dashboard,
        plans: _plans,
        isPlansLoading: _isPlansLoading,
        plansError: _plansError,
        onRefreshPlans: _loadPlansData,
      ),
      _ProfileTabV2(
        name: _dashboard.memberName,
        equipments: _equipments,
        memberProfile: _memberProfile,
        physicalProgressSnapshot: _physicalProgressSnapshot,
        physicalProgressLoaded: _physicalProgressLoaded,
        onPhysicalProgressUpdated: _loadPhysicalProgressData,
        profileRequestFailed: _memberProfileRequestFailed,
        onProfileUpdated: () async {
          await Future.wait([
            _loadMemberProfile(),
            _loadDashboardData(),
          ]);
        },
        // Avatar berubah -> rebuild shell agar header di semua tab ikut update
        // (baca 1 sumber: session.avatarUrl).
        onAvatarChanged: () {
          if (mounted) setState(() {});
        },
      ),
    ];

    return Obx(
      () => Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _controller.currentIndex.value,
            children: tabs,
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _controller.currentIndex.value,
          onTap: _controller.changeTab,
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.accent,
          unselectedItemColor: AppColors.textSecondary,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5),
          unselectedLabelStyle: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5),
          items: [
            _navItem(Icons.home_filled, 'HOME'),
            _navItem(Icons.bolt_rounded, 'PROGRAM'),
            _navItem(Icons.groups_rounded, 'TRAINER'),
            _navItem(Icons.card_membership_rounded, 'MEMBERSHIP'),
            _navItem(Icons.person_outline_rounded, 'PROFIL'),
          ],
        ),
      ),
    );
  }

  // Item bottom-nav dengan highlight pill di balik ikon saat aktif
  // (spec PROGRAM_TAB 11.3, bg rgba(245,197,24,0.12), radius 12px).
  BottomNavigationBarItem _navItem(IconData icon, String label) {
    return BottomNavigationBarItem(
      icon: Icon(icon),
      activeIcon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon),
      ),
      label: label,
    );
  }
}

String _sessionDisplayName(String fallback) {
  final sessionName = AppSessionService.instance.currentSession?.name?.trim();
  if (sessionName != null && sessionName.isNotEmpty) {
    return sessionName;
  }

  return fallback;
}

String? _sessionDisplayEmail() {
  final sessionEmail = AppSessionService.instance.currentSession?.email?.trim();
  if (sessionEmail != null && sessionEmail.isNotEmpty) {
    return sessionEmail;
  }

  return null;
}

void _openMemberProfileTab() {
  final controller = Get.find<MemberShellController>();
  if (controller.currentIndex.value != 4) controller.changeTab(4);
}

/// Label jenis kelamin ramah dari nilai backend (male/female/dll).
String _genderLabel(String? gender) {
  final g = gender?.trim().toLowerCase();
  if (g == null || g.isEmpty) return 'Belum diisi';
  switch (g) {
    case 'male':
    case 'laki-laki':
    case 'l':
      return 'Laki-laki';
    case 'female':
    case 'perempuan':
    case 'p':
      return 'Perempuan';
    default:
      return gender!.trim();
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.dashboard, this.onRefresh});

  final MemberDashboardData dashboard;
  final VoidCallback? onRefresh;

  bool get _hasPtActivity => (dashboard.nextSession.backendId ?? 0) > 0;

  bool get _canRequestReschedule {
    final status = dashboard.nextSession.rawStatus?.toLowerCase() ??
        dashboard.nextSession.status.toLowerCase();
    if (status != 'payment_verified' && status != 'confirmed') return false;
    return dashboard.nextSession.trainerProfileId != null &&
        dashboard.nextSession.reservations.any((reservation) =>
            reservation.status == 'reserved' &&
            reservation.id != null &&
            reservation.activeRescheduleRequest == null);
  }

  Future<void> _openReschedule() async {
    final changed = await Get.toNamed(
      AppRoutes.bookingReschedule,
      arguments: <String, dynamic>{
        'session': dashboard.nextSession,
        'trainerProfileId': dashboard.nextSession.trainerProfileId,
      },
    );
    if (changed == true) onRefresh?.call();
  }

  BookingRescheduleRequestData? get _activeRescheduleRequest {
    for (final reservation in dashboard.nextSession.reservations) {
      if (reservation.activeRescheduleRequest != null) {
        return reservation.activeRescheduleRequest;
      }
    }
    return null;
  }

  Future<void> _respondReschedule(
    BuildContext context,
    String action,
  ) async {
    final request = _activeRescheduleRequest;
    if (request == null) return;
    String? type;
    String? note;
    if (action == 'reject') {
      final controller = TextEditingController();
      String selected = 'new_schedule_not_suitable';
      final result = await showDialog<(String, String?)>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Tolak Reschedule'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selected,
                  items: const [
                    DropdownMenuItem(
                        value: 'new_schedule_not_suitable',
                        child: Text('Jadwal baru tidak cocok')),
                    DropdownMenuItem(
                        value: 'other_activity',
                        child: Text('Ada kegiatan lain')),
                    DropdownMenuItem(
                        value: 'too_close',
                        child: Text('Terlalu dekat dengan sesi')),
                    DropdownMenuItem(
                        value: 'keep_original_schedule',
                        child: Text('Tetap di jadwal lama')),
                    DropdownMenuItem(value: 'other', child: Text('Lainnya')),
                  ],
                  onChanged: (value) =>
                      setState(() => selected = value ?? selected),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: selected == 'other'
                        ? 'Alasan tambahan (wajib)'
                        : 'Alasan tambahan',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Batal')),
              FilledButton(
                onPressed: () {
                  final text = controller.text.trim();
                  if (selected == 'other' && text.isEmpty) return;
                  Navigator.pop(
                      dialogContext, (selected, text.isEmpty ? null : text));
                },
                child: const Text('Tolak'),
              ),
            ],
          ),
        ),
      );
      controller.dispose();
      if (result == null) return;
      type = result.$1;
      note = result.$2;
    }
    try {
      await BackendTrainerService().respondRescheduleRequest(
        request.id,
        action: action,
        asMember: true,
        rejectionType: type,
        rejectionNote: note,
      );
      onRefresh?.call();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final timer = context.watch<MemberWorkoutTimerProvider>();
    final memberDisplayName = _sessionDisplayName(dashboard.memberName);

    return RefreshIndicator(
      color: AppColors.accent,
      // Pull-to-refresh memakai loader yang sudah ada (tidak menambah request
      // baru; hanya memicu ulang fetch dashboard yang sudah teroptimasi).
      onRefresh: () async => onRefresh?.call(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          // (1) HEADER — avatar + greeting kuning + notif dot.
          Row(
            children: [
              InitialAvatar(
                name: memberDisplayName,
                radius: 20,
                avatarPath:
                    AppSessionService.instance.currentSession?.avatarUrl,
                onTap: _openMemberProfileTab,
                semanticLabel: 'Buka Profil Member',
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ATHLETE PROFILE',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Halo, $memberDisplayName \u{1F44B}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const NotificationBellButton(color: AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // (2) MEMBERSHIP STATUS CARD
          EggCard(
            highlight: true,
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E1A0A), Color(0xFF1A1A1A)],
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                ),
                border: Border.all(color: const Color(0xFF262626)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          'PAKET MEMBERSHIP',
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                      // Badge pill outline kuning "AKTIF" (teks + warna, aksesibel).
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: dashboard.remainingDays > 0
                                ? AppColors.accent
                                : AppColors.textSecondary,
                          ),
                        ),
                        child: Text(
                          dashboard.remainingDays > 0 ? 'AKTIF' : 'NONAKTIF',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: dashboard.remainingDays > 0
                                        ? AppColors.accent
                                        : AppColors.textSecondary,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dashboard.packageName.toUpperCase(),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'VALID UNTIL',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                    letterSpacing: 1,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppDateFormatter.date(dashboard.validUntil),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Angka hari tersisa (dari data dashboard, dihitung
                          // backend sebagai selisih hari — bukan hardcoded).
                          Text(
                            '${dashboard.remainingDays}',
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w800,
                                  height: 1.0,
                                ),
                          ),
                          Text(
                            'DAYS REMAINING',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  letterSpacing: 1,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // (3) TIMER CARD — logic timer TIDAK diubah, hanya visual.
          EggCard(
            child: Column(
              children: [
                Row(
                  children: [
                    _TimerTab(
                      label: 'Countdown',
                      selected: timer.mode == TimerMode.countdown,
                      onTap: () => timer.toggleMode(TimerMode.countdown),
                    ),
                    const SizedBox(width: 20),
                    _TimerTab(
                      label: 'Stopwatch',
                      selected: timer.mode == TimerMode.stopwatch,
                      onTap: () => timer.toggleMode(TimerMode.stopwatch),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                // Timer besar dengan separator ":" berwarna kuning.
                _TimerDisplay(value: timer.displayValue),
                const SizedBox(height: 8),
                Text(
                  'READY TO GRIND',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.textSecondary,
                        letterSpacing: 2,
                      ),
                ),
                const SizedBox(height: 20),
                // Preset chips — aktif = outline kuning.
                Wrap(
                  spacing: 12,
                  alignment: WrapAlignment.center,
                  children: timer.presets.map((preset) {
                    final selected = timer.selectedPresetMinutes == preset;
                    return GestureDetector(
                      onTap: () => timer.selectPreset(preset),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.transparent
                              : AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                selected ? AppColors.accent : AppColors.divider,
                          ),
                        ),
                        child: Text(
                          '$preset:00',
                          style: TextStyle(
                            color: selected
                                ? AppColors.accent
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    _CircleAction(
                        icon: Icons.restart_alt_rounded, onTap: timer.reset),
                    const SizedBox(width: 14),
                    // CTA START SESSION dengan glow.
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.45),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                        child: EggButton.primary(
                          label: timer.isRunning
                              ? 'PAUSE SESSION'
                              : 'START SESSION',
                          onPressed: timer.toggleRunning,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Pause: pakai logic timer yang sama, aktif hanya saat berjalan.
                    _CircleAction(
                      icon: Icons.pause_rounded,
                      onTap: timer.isRunning ? timer.toggleRunning : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // (4) AKTIVITAS PT
          Text(
            'Aktivitas PT',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          if (_hasPtActivity)
            EggCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      InitialAvatar(
                        name: dashboard.nextSession.clientName,
                        radius: 32,
                        avatarPath:
                            dashboard.nextSession.trainerDisplayPhotoPath ??
                                dashboard.nextSession.trainerAvatarUrl,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dashboard.nextSession.clientName,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            // Meta row: ikon jam (jadwal) + ikon pin (lokasi).
                            Row(
                              children: [
                                const Icon(Icons.schedule_rounded,
                                    size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    dashboard.nextSession.timeRange,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                            color: AppColors.textSecondary),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                const Icon(Icons.place_rounded,
                                    size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    dashboard.nextSession.location,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                            color: AppColors.textSecondary),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Chevron kuning untuk membuka detail sesi.
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.background,
                        ),
                      ),
                    ],
                  ),
                  // Status ringkas (info, bukan hanya warna) + aksi pembayaran.
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _nextSessionStatusLabel(dashboard.nextSession),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                    ),
                  ),
                  if (dashboard.nextSession.expiredAt != null &&
                      !dashboard.nextSession.isPaymentVerificationOverdue) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: BookingExpiryCountdown(
                        expiredAt: dashboard.nextSession.expiredAt,
                        label: dashboard.nextSession.expiryStage ==
                                'member_payment'
                            ? 'Sisa waktu pembayaran'
                            : dashboard.nextSession.expiryStage ==
                                    'trainer_verification'
                                ? 'Sisa waktu verifikasi trainer'
                                : 'Sisa waktu konfirmasi trainer',
                        onExpired: () async => onRefresh?.call(),
                      ),
                    ),
                  ],
                  if (dashboard.nextSession.status == 'waiting_payment' ||
                      dashboard.nextSession.status == 'payment_rejected') ...[
                    if (dashboard.nextSession.status == 'payment_rejected') ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Bukti pembayaran ditolak. Silakan upload ulang bukti transfer.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1.45,
                                  ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: EggButton.primary(
                        label:
                            dashboard.nextSession.status == 'payment_rejected'
                                ? 'Upload Ulang Bukti'
                                : 'Upload Bukti Pembayaran',
                        onPressed: () async {
                          await Get.toNamed(
                            AppRoutes.bookingPayment,
                            arguments: {
                              'bookingId': dashboard.nextSession.backendId,
                            },
                          );
                          // Re-fetch data booking saat kembali dari halaman
                          // pembayaran agar status card selalu sinkron dengan
                          // backend (mis. setelah bukti pembayaran diupload).
                          onRefresh?.call();
                        },
                      ),
                    ),
                  ] else if (dashboard.nextSession.status ==
                      'payment_uploaded') ...[
                    const SizedBox(height: 14),
                    if (dashboard.nextSession.isPaymentVerificationOverdue) ...[
                      Text(
                        PaymentVerificationOverdueCopy.memberMessage,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.accent,
                              height: 1.45,
                            ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: EggButton.primary(
                        label:
                            dashboard.nextSession.isPaymentVerificationOverdue
                                ? 'Verifikasi Terlambat'
                                : 'Menunggu Verifikasi Trainer',
                        onPressed: null,
                      ),
                    ),
                  ],
                  if (_activeRescheduleRequest != null) ...[
                    const SizedBox(height: 14),
                    RescheduleRequestCard(
                      request: _activeRescheduleRequest!,
                      onAccept: () => _respondReschedule(context, 'accept'),
                      onReject: () => _respondReschedule(context, 'reject'),
                      onCancel: () => _respondReschedule(context, 'cancel'),
                      onExpired: () async => onRefresh?.call(),
                    ),
                  ] else if (_canRequestReschedule) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: EggButton.secondary(
                        label: 'Ajukan Reschedule',
                        onPressed: _openReschedule,
                      ),
                    ),
                  ],
                ],
              ),
            )
          else
            EggCard(
              child: Text(
                'Belum ada aktivitas PT',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Timer besar dengan separator ":" berwarna kuning (aksen visual, MD 7.3).
class _TimerDisplay extends StatelessWidget {
  const _TimerDisplay({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.displayMedium?.copyWith(
      fontWeight: FontWeight.w300,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final parts = value.split(':');

    if (parts.length < 2) {
      return Text(value, style: baseStyle);
    }

    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: parts.first),
          const TextSpan(
            text: ':',
            style: TextStyle(color: AppColors.accent),
          ),
          TextSpan(text: parts.sublist(1).join(':')),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _ProgramTab extends StatefulWidget {
  const _ProgramTab({
    required this.sessions,
    required this.nextBooking,
    required this.onRatingSubmitted,
  });

  final List<WorkoutSession> sessions;
  final ScheduleSession? nextBooking;
  final Future<void> Function() onRatingSubmitted;

  @override
  State<_ProgramTab> createState() => _ProgramTabState();
}

class _ProgramTabState extends State<_ProgramTab> with WidgetsBindingObserver {
  var _showTrainerPrograms = true;
  final BackendMemberService _memberService = BackendMemberService();
  final BackendSelfTrainingService _selfTrainingService =
      BackendSelfTrainingService();
  final MemberShellController _shellController =
      Get.find<MemberShellController>();
  List<MemberProgramData>? _livePrograms;
  List<SelfTrainingProgramData>? _selfTrainingPrograms;
  bool _isLoading = false;
  // State error eksplisit untuk Latihan Mandiri. null = tidak ada error.
  // Dipakai agar kegagalan getPrograms tampil sebagai pesan + tombol "Coba
  // Lagi", bukan spinner abadi (null list = loading).
  String? _selfTrainingError;
  bool _isLoadingSelfTraining = false;
  // --- Session Timeline (inline) ---
  // Detail sesi 3-state hanya tersedia via getProgramDetail (tidak ada di
  // ringkasan program yang sudah dimuat). Di-fetch lazy saat tab Program aktif,
  // sekali, lalu di-cache di state ini.
  MemberProgramDetailData? _activeProgramDetail;
  bool _isLoadingSessions = false;
  bool _sessionsLoaded = false;
  bool _isSubmittingSession = false;
  String? _sessionsError;
  Worker? _programTabWorker;
  // Booking-booking yang popup rating-nya sudah ditampilkan di sesi app ini,
  // supaya popup tidak muncul berulang-ulang saat data di-refresh.
  final Set<int> _ratingPromptShown = <int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPrograms();
    _loadSelfTrainingPrograms();
    // Lazy: detail sesi (Session Timeline) hanya di-fetch saat tab Program
    // benar-benar aktif (index 1), bukan saat cold start semua tab.
    _programTabWorker = ever<int>(_shellController.currentIndex, (index) {
      if (index == 1) {
        _loadPrograms();
        _maybeLoadActiveSessions();
      }
    });
    if (_shellController.currentIndex.value == 1) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _maybeLoadActiveSessions(),
      );
    }
  }

  @override
  void dispose() {
    _programTabWorker?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadPrograms();
      _loadSelfTrainingPrograms();
    }
  }

  Future<void> _loadPrograms() async {
    setState(() => _isLoading = true);
    try {
      final programs = await _memberService.getPrograms();
      if (!mounted) return;
      final previousActiveId = _activeProgram?.id;
      setState(() {
        _livePrograms = programs;
        if (previousActiveId != _activeProgram?.id) {
          _activeProgramDetail = null;
          _sessionsLoaded = false;
          _sessionsError = null;
        }
      });
      _maybePromptRating(programs);
      // Kalau tab Program sedang dibuka dan sesi belum dimuat, muat sekarang
      // (daftar program baru saja tersedia untuk menentukan program aktif).
      if (_shellController.currentIndex.value == 1) {
        _maybeLoadActiveSessions();
      }
    } catch (_) {
      // Keep demo data if API fails
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _isCompletedRatedProgram(MemberProgramData program) {
    return program.status == 'completed' &&
        program.programCompleted &&
        program.progressPercent >= 100 &&
        program.totalSessions > 0 &&
        program.completedSessions == program.totalSessions &&
        program.alreadyRated;
  }

  /// Program yang belum final dan masih boleh memenuhi Current Phase/timeline.
  MemberProgramData? get _activeProgram {
    final programs = _livePrograms;
    if (programs == null || programs.isEmpty) return null;
    return programs.where((p) => !_isCompletedRatedProgram(p)).firstOrNull;
  }

  List<MemberProgramData> get _programHistory => (_livePrograms ?? const [])
      .where(_isCompletedRatedProgram)
      .toList(growable: false);

  bool get _waitingForTrainerProgram {
    final booking = widget.nextBooking;
    if (booking == null || booking.hasProgram) return false;
    return const {'payment_verified', 'confirmed'}
        .contains(booking.rawStatus?.toLowerCase());
  }

  /// Muat detail sesi (Session Timeline) untuk program aktif — LAZY & SEKALI.
  /// Hasil di-cache di [_activeProgramDetail]; tidak re-fetch saat rebuild atau
  /// saat toggle PT/Mandiri. [force] hanya dipakai setelah aksi ubah status.
  Future<void> _maybeLoadActiveSessions({bool force = false}) async {
    if (!force && (_sessionsLoaded || _isLoadingSessions)) return;
    final program = _activeProgram;
    if (program == null) return; // daftar program belum siap; coba lagi nanti

    setState(() {
      _isLoadingSessions = true;
      _sessionsError = null;
    });

    try {
      final detail = await _memberService.getProgramDetail(program.id);
      if (!mounted) return;
      setState(() {
        _activeProgramDetail = detail;
        _sessionsLoaded = true;
        _isLoadingSessions = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sessionsError = error.toString().replaceAll('Exception: ', '');
        _isLoadingSessions = false;
      });
    }
  }

  /// Toggle "gembok izin" PT untuk sebuah sesi. Logic identik dengan halaman
  /// detail (markSessionReady) — bukan pembatalan progres.
  Future<void> _startSessionInline(MemberProgramSessionData session) async {
    final program = _activeProgram;
    if (program == null) return;
    setState(() => _isSubmittingSession = true);
    try {
      final result = await _memberService.markSessionReady(
        programId: program.id,
        sessionId: session.id,
      );
      if (!mounted) return;
      // Segarkan cache detail agar status sesi terbaru ikut tampil.
      await _maybeLoadActiveSessions(force: true);
      Get.snackbar(
        result.memberReady ? 'Sesi Dibuka' : 'Sesi Dikunci',
        result.memberReady
            ? 'Trainer bisa mencentang latihan dari progres terakhir.'
            : 'Trainer terkunci dan tidak bisa mencentang. Progres yang sudah tercentang tetap tersimpan.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
    } catch (error) {
      if (!mounted) return;
      Get.snackbar(
        'Gagal',
        error.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
    } finally {
      if (mounted) setState(() => _isSubmittingSession = false);
    }
  }

  /// Buka detail sesi (read-only) — argumen navigasi identik halaman detail.
  void _openSessionDetailInline(MemberProgramSessionData session) {
    Get.toNamed(
      AppRoutes.memberSessionDetailReadOnly,
      arguments: {
        'sessionId': session.id,
        'sessionTitle': session.title,
        'sessionFocus': session.focus,
        'exercises': session.exercises,
        'sessionStatus': session.status,
      },
    );
  }

  // ── SESSION TIMELINE (inline) — UI ──────────────────────────────────────
  // Section header + daftar kartu sesi 3 varian. Data dari _activeProgramDetail
  // (di-cache). Section hanya tampil jika ada program PT.
  List<Widget> _buildSessionTimelineSection(BuildContext context) {
    if (_activeProgram == null) return const [];

    final header = Text(
      'Session Timeline',
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
    );

    Widget body;
    final detail = _activeProgramDetail;
    if (detail != null) {
      if (detail.sessions.isEmpty) {
        body = _buildSessionTimelineInfo(
          'Belum ada sesi pada program ini.',
        );
      } else {
        // Sliding window: tampilkan maksimal 3 kartu dengan sesi aktif di tengah
        // ([sebelum, aktif, sesudah]). Ini memastikan sesi aktif (yang punya
        // tombol START SESSION/DETAILS) SELALU masuk jendela, memperbaiki bug
        // take(3) yang menyembunyikan sesi aktif bila 3 sesi awal sudah selesai.
        // Sisanya diakses via link "LIHAT SEMUA SESI (N)". N = total seluruh sesi
        // (sumber sama, tanpa hitung baru).
        final presentedSessions =
            sortMemberProgramSessionsBySchedule(detail.sessions);
        final totalSessions = presentedSessions.length;

        // Tentukan indeks sesi aktif:
        // 1) sesi berstatus active; kalau tidak ada
        // 2) sesi pertama yang belum selesai (current/berikutnya); kalau semua
        //    selesai
        // 3) sesi terakhir (jendela di sekitar sesi terakhir).
        var activeIndex = presentedSessions.indexWhere((s) => s.isActive);
        if (activeIndex < 0) {
          activeIndex = presentedSessions.indexWhere((s) => !s.isCompleted);
        }
        if (activeIndex < 0) {
          activeIndex = totalSessions - 1;
        }

        // Batas jendela: satu sebelum + aktif + satu sesudah, di-clamp ke rentang
        // valid. Bila aktif = terakhir -> otomatis [sebelum, aktif] (2 kartu),
        // tanpa slot kosong. Bila ada sesudahnya -> 3 kartu, aktif di tengah.
        var start = activeIndex - 1;
        var end = activeIndex + 1;
        if (start < 0) start = 0;
        if (end > totalSessions - 1) end = totalSessions - 1;
        final visibleSessions = presentedSessions.sublist(start, end + 1);

        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...visibleSessions.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildInlineSessionTile(s),
                )),
            // Link muncul bila ADA sesi tersembunyi di luar jendela (termasuk
            // sesi lama yang sudah selesai & tergeser ke atas).
            if (visibleSessions.length < totalSessions)
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => Get.toNamed(
                    AppRoutes.memberSessionTimeline,
                    arguments: {'programId': _activeProgram!.id},
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'LIHAT SEMUA SESI ($totalSessions)',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontSize: 12,
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                    ),
                  ),
                ),
              ),
          ],
        );
      }
    } else if (_sessionsError != null) {
      body = _buildSessionTimelineError();
    } else {
      body = _buildSessionTimelineSkeleton();
    }

    return [
      header,
      const SizedBox(height: 12),
      body,
    ];
  }

  Widget _buildSessionTimelineInfo(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
      ),
    );
  }

  Widget _buildSessionTimelineError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _sessionsError ?? 'Gagal memuat sesi.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _isLoadingSessions
                  ? null
                  : () => _maybeLoadActiveSessions(force: true),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                foregroundColor: AppColors.accent,
              ),
              child: Text(_isLoadingSessions ? 'Memuat...' : 'Coba Lagi'),
            ),
          ),
        ],
      ),
    );
  }

  // Skeleton loading sederhana (tanpa paket shimmer tambahan) — placeholder
  // kartu abu saat detail sesi sedang diambil.
  Widget _buildSessionTimelineSkeleton() {
    Widget bar(double width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFF232323),
            borderRadius: BorderRadius.circular(6),
          ),
        );

    Widget skeletonCard() => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF262626)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF232323),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    bar(60, 10),
                    const SizedBox(height: 8),
                    bar(double.infinity, 14),
                    const SizedBox(height: 8),
                    bar(160, 12),
                  ],
                ),
              ),
            ],
          ),
        );

    return Column(children: [skeletonCard(), skeletonCard()]);
  }

  Widget _buildInlineSessionTile(MemberProgramSessionData session) {
    final isCompleted = session.isCompleted;
    final isActive = session.isActive;
    final isLocked = session.isLocked;

    final Color bgColor = isActive
        ? const Color(0xFF1A1A1A)
        : isLocked
            ? const Color(0xFF141414)
            : const Color(0xFF161616);
    final Color borderColor =
        isLocked ? const Color(0xFF1E1E1E) : const Color(0xFF262626);
    final Color titleColor =
        isLocked ? const Color(0xFF6B6B6B) : const Color(0xFFFFFFFF);
    final Color metaColor =
        isActive ? const Color(0xFFF5C518) : const Color(0xFF9A9A9A);

    final tile = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              // Border seragam agar borderRadius legal di Flutter.
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInlineStatusCircle(isCompleted, isActive, isLocked),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SESSION ${session.sequenceOrder}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              color: isLocked
                                  ? const Color(0xFF6B6B6B)
                                  : const Color(0xFF9A9A9A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            session.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _inlineSessionMeta(
                                session, isCompleted, isActive, isLocked),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  isActive ? FontWeight.w600 : FontWeight.w400,
                              height: 1.4,
                              color: metaColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildInlineStateBadge(isCompleted, isActive),
                  ],
                ),
                if (isActive) ...[
                  const SizedBox(height: 12),
                  if (session.hasPendingReschedule) ...[
                    const Text(
                      'Sesi tidak bisa dimulai sebelum permintaan reschedule diputuskan.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: EggButton.primary(
                          label: _isSubmittingSession
                              ? 'Memproses...'
                              : (session.memberReady
                                  ? 'Sesi Siap'
                                  : 'Mulai Sesi'),
                          onPressed: _isSubmittingSession ||
                                  session.hasPendingReschedule
                              ? () {}
                              : () => _startSessionInline(session),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: EggButton.secondary(
                          label: 'Details',
                          onPressed: () => _openSessionDetailInline(session),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Accent rail kuning 3px di sisi kiri (hanya ACTIVE). Widget terpisah
          // agar tidak melanggar aturan Flutter (borderRadius + border warna
          // tidak seragam). Ter-clip rapi oleh ClipRRect di atas.
          if (isActive)
            const Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: SizedBox(
                width: 3,
                child: ColoredBox(color: Color(0xFFF5C518)),
              ),
            ),
        ],
      ),
    );

    // Body kartu sesi non-interaktif: tap dimatikan (tanpa GestureDetector).
    // Aksi hanya lewat tombol di dalam tile ("Mulai Sesi"/"Details" untuk
    // ACTIVE) yang fungsinya tidak diubah. Varian LOCKED tetap opacity 0.6.
    return isLocked ? Opacity(opacity: 0.6, child: tile) : tile;
  }

  Widget _buildInlineStatusCircle(
      bool isCompleted, bool isActive, bool isLocked) {
    final Color circleBg = isActive
        ? const Color(0xFFF5C518)
        : isLocked
            ? const Color(0xFF1C1C1C)
            : const Color(0x26F5C518);
    final IconData icon = isCompleted
        ? Icons.check_rounded
        : isLocked
            ? Icons.lock_rounded
            : Icons.play_arrow_rounded;
    final Color iconColor = isActive
        ? const Color(0xFF0E0E0E)
        : isLocked
            ? const Color(0xFF6B6B6B)
            : const Color(0xFFF5C518);

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(shape: BoxShape.circle, color: circleBg),
      alignment: Alignment.center,
      child: Icon(icon, size: 14, color: iconColor),
    );
  }

  Widget _buildInlineStateBadge(bool isCompleted, bool isActive) {
    final String label = isActive
        ? 'ACTIVE'
        : isCompleted
            ? 'PAST'
            : 'LOCKED';
    final Color textColor =
        isActive ? const Color(0xFF0E0E0E) : const Color(0xFF6B6B6B);
    final Color bg =
        isActive ? const Color(0xFFF5C518) : const Color(0xFF1C1C1C);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: textColor,
        ),
      ),
    );
  }

  // Meta memakai jadwal child reservation terbaru tanpa mengubah identitas sesi.
  String _inlineSessionMeta(
    MemberProgramSessionData session,
    bool isCompleted,
    bool isActive,
    bool isLocked,
  ) {
    final schedule = _memberProgramScheduleLabel(session);
    if (isCompleted) {
      final duration = session.durationMinutes ?? 0;
      final base = '$duration mins completed';
      return [
        if (schedule != null) schedule,
        base,
      ].join(' \u2022 ');
    }
    if (isActive) {
      final base = '${session.exercises.length} Exercises';
      return [
        if (schedule != null) schedule,
        base,
      ].join(' \u2022 ');
    }
    return [
      if (schedule != null) schedule,
      'Terbuka setelah sesi aktif selesai 100%',
    ].join(' \u2022 ');
  }

  String? _memberProgramScheduleLabel(MemberProgramSessionData session) {
    final date = session.reservationDate;
    final start = session.reservationStartTime;
    final end = session.reservationEndTime;
    if (date == null || start == null || end == null) return null;
    final startLabel = start.length >= 5 ? start.substring(0, 5) : start;
    final endLabel = end.length >= 5 ? end.substring(0, 5) : end;
    return AppDateFormatter.schedule(
      dateValue: date,
      startTime: startLabel,
      endTime: endLabel,
    );
  }

  /// Munculkan popup "Beri Rating Trainer" otomatis untuk program yang sudah
  /// 100% selesai dan belum pernah dirating oleh member (satu kali per sesi app).
  Future<void> _maybePromptRating(List<MemberProgramData> programs) async {
    final target = programs.where((p) {
      return memberProgramNeedsRating(p) && !_ratingPromptShown.contains(p.id);
    }).firstOrNull;

    if (target == null) return;

    // Tandai lebih dulu agar tidak dobel walau widget rebuild.
    _ratingPromptShown.add(target.id);

    // Beri jeda singkat supaya tab sudah ter-render sebelum popup muncul.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    final submitted = await TrainerRatingDialog.show(
      trainingProgramId: target.id,
      trainerName: target.trainerName ?? 'Trainer',
    );

    // Kalau berhasil kirim rating, segarkan daftar agar flag already_rated ikut update.
    if (submitted == true && mounted) {
      await refreshMemberTrainerRatingData(
        reloadPrograms: _loadPrograms,
        reloadTrainerCatalog: widget.onRatingSubmitted,
      );
    }
  }

  Future<void> _openMemberTrainerRating(MemberProgramData program) async {
    if (!memberProgramNeedsRating(program)) return;

    final submitted = await Get.to<bool>(
      () => MemberTrainerRatingPage(program: program),
      routeName: AppRoutes.memberTrainerRating,
    );
    if (submitted == true && mounted) {
      await refreshMemberTrainerRatingData(
        reloadPrograms: _loadPrograms,
        reloadTrainerCatalog: widget.onRatingSubmitted,
      );
    }
  }

  List<Widget> _buildProgramHistorySection(BuildContext context) {
    final history = _programHistory;
    if (history.isEmpty) return const [];

    return [
      const SizedBox(height: 24),
      Text(
        'Riwayat Program',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
      ),
      const SizedBox(height: 12),
      ...history.map(
        (program) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Get.toNamed(
              AppRoutes.memberSessionTimeline,
              arguments: {'programId': program.id},
            ),
            child: EggCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.history_rounded,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              program.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            if (program.trainerName != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Trainer: ${program.trainerName}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const StatusChip(
                        label: 'COMPLETED',
                        color: AppColors.success,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      StatusChip(
                        label:
                            '${program.completedSessions}/${program.totalSessions} SESI',
                        color: AppColors.textSecondary,
                      ),
                      if (program.rating != null)
                        StatusChip(
                          label: 'RATING ${program.rating}/5',
                          color: AppColors.accent,
                        ),
                    ],
                  ),
                  if (program.endedAt != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Selesai: ${program.endedAt}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ];
  }

  Future<void> _loadSelfTrainingPrograms() async {
    if (!mounted) return;
    setState(() {
      _isLoadingSelfTraining = true;
      _selfTrainingError = null;
    });
    try {
      final programs = await _selfTrainingService.getPrograms();
      if (!mounted) return;
      setState(() {
        _selfTrainingPrograms = programs;
        _isLoadingSelfTraining = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Set state error eksplisit (bukan diam-diam) supaya UI menampilkan pesan
      // + tombol "Coba Lagi", bukan spinner abadi.
      setState(() {
        _selfTrainingError = e.toString().replaceAll('Exception: ', '');
        _isLoadingSelfTraining = false;
      });
    }
  }

  void _openSelfTrainingDetail(SelfTrainingProgramData program) async {
    await Get.toNamed(
      AppRoutes.memberSelfTrainingDetail,
      arguments: {
        'programId': program.id,
        'program': program,
      },
    );
    // Refresh list when coming back from detail
    _loadSelfTrainingPrograms();
  }

  void _showCreateSelfTrainingDialog() async {
    await Get.toNamed(AppRoutes.memberSelfTrainingBuilder);
    // Refresh list when coming back from builder
    _loadSelfTrainingPrograms();
  }

  Future<void> _deleteSelfTrainingProgram(
      SelfTrainingProgramData program) async {
    try {
      await _selfTrainingService.deleteProgram(program.id);
      await _loadSelfTrainingPrograms();
      Get.snackbar(
        'Program Dihapus',
        'Program "${program.title}" berhasil dihapus.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
    } catch (e) {
      Get.snackbar(
        'Gagal',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
    }
  }

  /// Dialog edit program (nama + deskripsi), field terisi otomatis nilai saat
  /// ini -> updateProgram (endpoint PUT baru) -> refresh list. Hanya mengubah
  /// nama & deskripsi (tidak menyentuh sesi/gerakan).
  Future<void> _editSelfTrainingProgram(SelfTrainingProgramData program) async {
    final titleController = TextEditingController(text: program.title);
    final descController =
        TextEditingController(text: program.description ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Program'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Nama Program',
                hintText: 'Contoh: Latihan Khusus Minggu',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Deskripsi (opsional)',
                hintText: 'Contoh: Fokus cardio',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.background,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (result == true && titleController.text.trim().isNotEmpty) {
      try {
        await _selfTrainingService.updateProgram(
          programId: program.id,
          title: titleController.text.trim(),
          description: descController.text.trim().isNotEmpty
              ? descController.text.trim()
              : null,
        );
        await _loadSelfTrainingPrograms();
      } catch (e) {
        Get.snackbar(
          'Gagal',
          e.toString().replaceAll('Exception: ', ''),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.surface,
          colorText: AppColors.textPrimary,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final memberDisplayName = _sessionDisplayName('Member');

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            Row(
              children: [
                InitialAvatar(
                  name: memberDisplayName,
                  radius: 18,
                  avatarPath:
                      AppSessionService.instance.currentSession?.avatarUrl,
                  onTap: _openMemberProfileTab,
                  semanticLabel: 'Buka Profil Member',
                ),
                const SizedBox(width: 10),
                Text(
                  'Program Latihan',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                const NotificationBellButton(),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _SwitchPill(
                    label: 'Program dari PT',
                    selected: _showTrainerPrograms,
                    onTap: () => setState(() => _showTrainerPrograms = true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SwitchPill(
                    label: 'Latihan Mandiri',
                    selected: !_showTrainerPrograms,
                    onTap: () => setState(() => _showTrainerPrograms = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_showTrainerPrograms) ...[
              if (_isLoading)
                const EggCard(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                )
              else if (_activeProgram != null) ...[
                // View PT menampilkan HANYA program aktif sebagai satu Current Phase
                // Card (sesuai Figma). Program PT lain tidak dirender sebagai kartu
                // terpisah di sini. _activeProgram dijamin non-null pada cabang ini.
                Builder(builder: (context) {
                  final program = _activeProgram!;
                  // Bug 1 fix: Current Phase Card membaca jumlah sesi & persen
                  // dari DETAIL (sumber yang sama dengan timeline) bila detail
                  // sudah ter-load & di-cache untuk program aktif. Fallback ke
                  // angka endpoint list bila detail belum tersedia. Tanpa query
                  // baru, tanpa mengubah logic penentuan status sesi.
                  final detail = (_activeProgramDetail != null &&
                          _activeProgram != null &&
                          program.id == _activeProgram!.id)
                      ? _activeProgramDetail
                      : null;
                  final int phaseTotal = detail != null
                      ? detail.sessions.length
                      : program.totalSessions;
                  final int phaseCompleted = detail != null
                      ? detail.sessions.where((s) => s.isCompleted).length
                      : program.completedSessions;
                  final double phasePercent = detail != null
                      ? (phaseTotal > 0 ? phaseCompleted / phaseTotal * 100 : 0)
                      : program.progressPercent;
                  final needsRating = memberProgramNeedsRating(program);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      key: const Key('current-phase-card-action'),
                      behavior: HitTestBehavior.opaque,
                      onTap: needsRating
                          ? () => _openMemberTrainerRating(program)
                          : null,
                      child: Semantics(
                        button: needsRating,
                        label: needsRating
                            ? 'Beri rating untuk ${program.trainerName ?? 'trainer'}'
                            : null,
                        child: EggCard(
                          highlight: needsRating,
                          child: Stack(
                            clipBehavior: Clip.hardEdge,
                            children: [
                              // Watermark dekoratif "LEVEL X" (~6% opacity) di
                              // belakang konten. Di-clip rapi oleh Stack.hardEdge &
                              // dibungkus IgnorePointer agar tidak menangkap tap.
                              // Angka level diturunkan dari sesi selesai (data nyata),
                              // bukan hardcoded.
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      'LEVEL ${phaseCompleted > 0 ? phaseCompleted : 1}',
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.clip,
                                      style: const TextStyle(
                                        fontSize: 88,
                                        fontWeight: FontWeight.w900,
                                        height: 1.0,
                                        letterSpacing: -2,
                                        color: Color(0x0FF5C518),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'CURRENT PHASE',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(
                                                    color:
                                                        AppColors.textSecondary,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    letterSpacing: 1.5,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              program.title,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .headlineMedium
                                                  ?.copyWith(
                                                    color: AppColors.accent,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      StatusChip(
                                        key: const Key('current-phase-status'),
                                        label: needsRating
                                            ? 'BERI RATING'
                                            : program.status.toUpperCase(),
                                        color: needsRating
                                            ? AppColors.accent
                                            : program.status == 'active'
                                                ? AppColors.accent
                                                : AppColors.textSecondary,
                                      ),
                                    ],
                                  ),
                                  if (program.trainerName != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Oleh: ${program.trainerName}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              color: AppColors.textSecondary),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${phasePercent.round()}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .displaySmall
                                            ?.copyWith(
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(width: 4),
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 8),
                                        child: Text(
                                          '%',
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(
                                                color: AppColors.textSecondary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 8),
                                        child: Text(
                                          '$phaseCompleted OF $phaseTotal SESSIONS',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelLarge
                                              ?.copyWith(
                                                color: AppColors.textSecondary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  LinearProgressIndicator(
                                    value: phasePercent / 100,
                                    minHeight: 8,
                                    borderRadius: BorderRadius.circular(999),
                                    backgroundColor: AppColors.surfaceSoft,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                            AppColors.accent),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ] else if (_waitingForTrainerProgram)
                EggCard(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.pending_actions_rounded,
                        size: 48,
                        color: AppColors.accent,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Menunggu program dari PT',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pembayaran sesi sudah diverifikasi. Personal Trainer sedang menyiapkan program untuk booking ini.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.45,
                            ),
                      ),
                    ],
                  ),
                )
              else
                EggCard(
                  child: Column(
                    children: [
                      const Icon(Icons.fitness_center_rounded,
                          size: 48, color: AppColors.textSecondary),
                      const SizedBox(height: 12),
                      Text(
                        'Tidak ada program PT aktif',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                      ),
                      if (_programHistory.isEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Program latihan dari Personal Trainer akan muncul di sini setelah dibuat.',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              ..._buildSessionTimelineSection(context),
              ..._buildProgramHistorySection(context),
              // Preview "Latihan Mandiri" di bawah Session Timeline (view PT).
              // Hanya tampil bila member sudah punya program mandiri (data yang
              // SUDAH dimuat di state -- tanpa query baru). Teaser 1 kartu pertama;
              // aksi penuh ada di tab Latihan Mandiri (link "LIHAT SEMUA").
              if (_selfTrainingPrograms != null &&
                  _selfTrainingPrograms!.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Latihan Mandiri',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    // Pindah ke tab Latihan Mandiri lewat toggle yang sudah ada
                    // (bukan route baru).
                    GestureDetector(
                      onTap: () => setState(() => _showTrainerPrograms = false),
                      child: Text(
                        'LIHAT SEMUA',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontSize: 12,
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SelfTrainingProgramCard(
                  program: _selfTrainingPrograms!.first,
                  onTap: () =>
                      _openSelfTrainingDetail(_selfTrainingPrograms!.first),
                  onEdit: () {},
                  onDelete: () {},
                  showDelete: false,
                ),
              ],
            ] else ...[
              // Tautan "+ BUAT PROGRAM BARU" dihapus (redundan dengan FAB "+").
              // Pembuatan program baru dilakukan lewat FAB di pojok kanan bawah.
              if (_selfTrainingError != null && _selfTrainingPrograms == null)
                // State error eksplisit: pesan + tombol "Coba Lagi" (bukan spinner
                // abadi). Hanya tampil bila belum ada data yang berhasil dimuat.
                EggCard(
                  child: Column(
                    children: [
                      const Icon(Icons.wifi_off_rounded,
                          size: 44, color: AppColors.textSecondary),
                      const SizedBox(height: 12),
                      Text(
                        'Gagal memuat latihan mandiri',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _selfTrainingError!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 14),
                      EggButton.secondary(
                        label:
                            _isLoadingSelfTraining ? 'Memuat...' : 'Coba Lagi',
                        onPressed: _isLoadingSelfTraining
                            ? () {}
                            : () => _loadSelfTrainingPrograms(),
                      ),
                    ],
                  ),
                )
              else if (_selfTrainingPrograms == null)
                const Center(child: CircularProgressIndicator())
              else if (_selfTrainingPrograms!.isEmpty)
                EggCard(
                  child: Column(
                    children: [
                      const Icon(Icons.fitness_center_rounded,
                          size: 48, color: AppColors.textSecondary),
                      const SizedBox(height: 12),
                      Text(
                        'Belum ada program latihan mandiri',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Buat program latihan mandiri untuk diri sendiri.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                )
              else
                ..._selfTrainingPrograms!.map((program) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SelfTrainingProgramCard(
                      program: program,
                      onTap: () => _openSelfTrainingDetail(program),
                      onEdit: () => _editSelfTrainingProgram(program),
                      onDelete: () => _deleteSelfTrainingProgram(program),
                    ),
                  );
                }),
            ],
          ],
        ),
        // FAB (spec 10): rounded-square 56px kuning + glow, shortcut buat
        // program mandiri baru. Memanggil flow create yang sudah ada.
        Positioned(
          right: 16,
          bottom: 24,
          child: GestureDetector(
            onTap: () => _showCreateSelfTrainingDialog(),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.5),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.add_rounded,
                size: 24,
                color: Color(0xFF0E0E0E),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ignore: unused_element
class _TrainersTab extends StatelessWidget {
  const _TrainersTab({required this.trainers});

  final List<TrainerProfile> trainers;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        Text(
          'FIND YOUR',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w400,
              ),
        ),
        Text(
          'EXPERT GUIDE',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 10),
        Text(
          'Performance coaches.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 16),
        const TextField(
          decoration: InputDecoration(
            hintText: 'Search by trainer or specialty',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            StatusChip(label: 'ALL TRAINERS'),
            StatusChip(label: 'BODYBUILDING', color: AppColors.textSecondary),
            StatusChip(label: 'YOGA', color: AppColors.textSecondary),
          ],
        ),
        const SizedBox(height: 16),
        ...trainers.map((trainer) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: EggCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 230,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF524225), Color(0xFF1D1D1D)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Align(
                            alignment: Alignment.topRight,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: trainerTierLabel(trainer.tier) == null
                                  ? const SizedBox.shrink()
                                  : StatusChip(
                                      label: trainerTierLabel(trainer.tier)!,
                                    ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    trainer.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    trainer.specialty,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      trainer.bio,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                        trainerRatingDisplay(
                          rating: trainer.rating,
                          reviewsCount: trainer.reviewsCount,
                        ),
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(color: AppColors.accent)),
                    const SizedBox(height: 14),
                    EggButton.primary(
                      label: 'LIHAT PROFIL',
                      onPressed: () => Get.toNamed(AppRoutes.projectBoard),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }
}

/* Legacy V1 membership/profile tabs disabled in favor of V2 variants.

        ...dashboard.recentTransactions.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: EggCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(item.dateLabel,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Text('${item.amount} • ${item.status}',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(color: AppColors.success)),
                  ],
                ),
              ),
            )),
      ],
    );
  }
}

// ignore: unused_element
class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.name, required this.tier});

  final String name;
  final String tier;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        Center(
          child: Column(
            children: [
              InitialAvatar(name: name, radius: 34),
              const SizedBox(height: 14),
              Text(name,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('$tier • Active member',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Row(
          children: [
            Expanded(child: _MiniMetric(label: 'Height', value: '175 cm')),
            SizedBox(width: 12),
            Expanded(child: _MiniMetric(label: 'Weight', value: '74 kg')),
            SizedBox(width: 12),
            Expanded(child: _MiniMetric(label: 'Goal', value: 'Lean Bulk')),
          ],
        ),
        const SizedBox(height: 20),
        _ActionTile(
          title: 'Task Board',
          subtitle: 'Lihat fitur done / progress / todo',
          icon: Icons.fact_check_outlined,
          onTap: () => Get.toNamed(AppRoutes.projectBoard),
        ),
        const SizedBox(height: 12),
        _ActionTile(
          title: 'Preview PT Flow',
          subtitle: 'Pindah ke demo role trainer',
          icon: Icons.swap_horiz_rounded,
          onTap: () => Get.toNamed(AppRoutes.trainerShell),
        ),
        const SizedBox(height: 12),
        _ActionTile(
          title: 'Logout',
          subtitle: 'Kembali ke halaman login',
          icon: Icons.logout_rounded,
          onTap: () async {
            await AppSessionService.instance.clear();
            Get.offAllNamed(AppRoutes.login);
          },
        ),
      ],
    );
  }
}

*/
String _bookingStatusLabel(String status) {
  switch (status) {
    case 'pending':
      return 'MENUNGGU KONFIRMASI';
    case 'waiting_payment':
      return 'MENUNGGU PEMBAYARAN';
    case 'payment_uploaded':
      return 'MENUNGGU VERIFIKASI';
    case 'payment_verified':
      return 'PEMBAYARAN VALID';
    case 'payment_rejected':
      return 'PEMBAYARAN DITOLAK';
    case 'confirmed':
      return 'DIKONFIRMASI';
    case 'rescheduled':
      return 'DIJADWALKAN ULANG';
    default:
      return status.toUpperCase();
  }
}

/// Label status untuk card "Aktivitas PT" di Home member.
///
/// Membedakan kondisi pembayaran sudah valid tapi trainer belum membuat
/// program latihan, agar member tahu progresnya (bukan sekadar "PEMBAYARAN
/// VALID"). Setelah program dibuat, tampilkan "PROGRAM AKTIF", dan begitu
/// seluruh sesi program selesai 100% tampilkan "PROGRAM SELESAI".
String _nextSessionStatusLabel(ScheduleSession session) {
  final status = session.status;
  if (status == 'payment_verified' || status == 'confirmed') {
    if (session.programCompleted) {
      return 'PROGRAM SELESAI';
    }
    return session.hasProgram
        ? 'PROGRAM AKTIF'
        : 'PEMBAYARAN VALID — TRAINER SEDANG MENYUSUN PROGRAM LATIHAN';
  }
  return _bookingStatusLabel(status);
}

class _TimerTab extends StatelessWidget {
  const _TimerTab(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: selected ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              decoration: selected ? TextDecoration.underline : null,
              decorationColor: AppColors.accent,
            ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [AppColors.surfaceElevated, AppColors.surfaceSoft],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: AppColors.divider),
        ),
        child: Icon(icon, color: AppColors.textPrimary),
      ),
    );
  }
}

/// Kartu statistik profil: label kecil abu di atas, angka besar kuning di baris
/// tengah, lalu satuan kecil abu di baris terpisah (2 baris nilai+satuan).
class _ProfileStatCard extends StatelessWidget {
  const _ProfileStatCard({
    required this.label,
    required this.value,
    this.unit,
  });

  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    return EggCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
          ),
          const SizedBox(height: 12),
          // Angka/teks besar warna kuning (baris atas).
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
          ),
          // Satuan kecil abu (baris bawah).
          if (unit != null) ...[
            const SizedBox(height: 2),
            Text(
              unit!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Card Target full-width tersendiri (ruang lebar -> teks target panjang tidak
/// kepotong). Label kecil abu di atas, nilai target di bawah (kuning bila diisi,
/// abu bila "Belum diisi"). Data nyata dari fitnessGoal.
class _ProfileTargetCard extends StatelessWidget {
  const _ProfileTargetCard({required this.value, required this.filled});

  final String value;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return EggCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.flag_rounded,
                color: AppColors.accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TARGET',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color:
                            filled ? AppColors.accent : AppColors.textSecondary,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.onTap,
      this.previewRows = const []});

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  // Baris preview ringkas (label -> value) di bawah deskripsi. Opsional; kalau
  // kosong, tampilan card seperti semula. Aman untuk tinggi (menambah baris di
  // Column dalam Expanded, tanpa stretch -> tidak memicu infinite height).
  final List<({String label, String value})> previewRows;

  @override
  Widget build(BuildContext context) {
    // Restyle proporsi Figma: radius 16, padding lega, icon dalam kotak accent
    // membulat, label kiri + chevron kanan. Navigasi (onTap) TIDAK diubah.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF262626)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.35,
                            )),
                    // Preview rows (data nyata / "Belum diisi").
                    if (previewRows.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Divider(color: Color(0xFF262626), height: 1),
                      const SizedBox(height: 12),
                      ...previewRows.map(
                        (row) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 96,
                                child: Text(
                                  row.label,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: AppColors.textSecondary),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  row.value,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(Icons.arrow_forward_ios_rounded,
                    size: 16, color: Color(0xFF9A9A9A)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchPill extends StatelessWidget {
  const _SwitchPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: selected ? AppColors.background : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _SelfTrainingProgramCard extends StatelessWidget {
  const _SelfTrainingProgramCard({
    required this.program,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.showDelete = true,
  });

  final SelfTrainingProgramData program;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  // Preview/teaser (mis. di view PT) menyembunyikan aksi edit/delete agar user
  // tidak tak sengaja mengubah dari tempat yang salah. Aksi penuh ada di tab Mandiri.
  final bool showDelete;

  @override
  Widget build(BuildContext context) {
    // Semua angka dari objek program yang SAMA (sumber yang sudah dipakai):
    // progressPercent, completedExercises, totalExercises -- bukan hitung baru.
    final percent = program.progressPercent;
    final completed = program.completedExercises;
    final total = program.totalExercises;
    // "Kategori" abu memakai description (satu-satunya teks opsional di model;
    // tidak ada field category tersendiri). Sembunyikan bila kosong.
    final category = program.description?.trim();

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF262626)),
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Watermark dekoratif nama program (~6% opacity), tidak menangkap tap.
              Positioned.fill(
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'LATIHAN',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.clip,
                      style: const TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        letterSpacing: -2,
                        color: Color(0x0FF5C518),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'CURRENT FOCUS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                              color: Color(0xFF9A9A9A),
                            ),
                          ),
                        ),
                        // Edit & delete dipertahankan (fungsi tidak diubah);
                        // tersembunyi di mode preview (showDelete: false).
                        if (showDelete) ...[
                          GestureDetector(
                            onTap: onEdit,
                            behavior: HitTestBehavior.opaque,
                            child: const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(Icons.edit_outlined,
                                  color: Color(0xFF9A9A9A), size: 20),
                            ),
                          ),
                          GestureDetector(
                            onTap: onDelete,
                            behavior: HitTestBehavior.opaque,
                            child: const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(Icons.delete_outline_rounded,
                                  color: AppColors.error, size: 20),
                            ),
                          ),
                        ],
                        // Panah ">" (kartu mengarah ke halaman detail program).
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.chevron_right_rounded,
                              color: Color(0xFF9A9A9A), size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      program.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        letterSpacing: -0.5,
                        color: Color(0xFFFFFFFF),
                      ),
                    ),
                    if (category != null && category.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9A9A9A),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$percent',
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                            letterSpacing: -1,
                            color: Color(0xFFFFFFFF),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(left: 2, bottom: 4),
                          child: Text(
                            '%',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF9A9A9A),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '$completed OF $total EXERCISES',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF9A9A9A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: percent / 100,
                        minHeight: 6,
                        backgroundColor: const Color(0xFF2A2A2A),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFF5C518),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrainersTabV2 extends StatefulWidget {
  const _TrainersTabV2({
    required this.trainers,
    required this.isLoading,
    required this.error,
    required this.onRefresh,
    this.hasActivePtEngagement = false,
    this.activePtTrainerName,
    this.activePtStatus,
    required this.profileCompleteness,
  });

  final List<TrainerProfile> trainers;
  final bool isLoading;
  final String? error;
  final Future<void> Function() onRefresh;
  final bool hasActivePtEngagement;
  final String? activePtTrainerName;
  final String? activePtStatus;
  final ValueListenable<bool?> profileCompleteness;

  @override
  State<_TrainersTabV2> createState() => _TrainersTabV2State();
}

class _TrainersTabV2State extends State<_TrainersTabV2> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _activeSpecialty;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Filter frontend gabungan (AND): kategori chip + pencarian nama/spesialisasi.
  // Semua case-insensitive & substring. Memakai daftar yang sudah dimuat --
  // tanpa fetch baru.
  List<TrainerProfile> get _filteredTrainers {
    return TrainerScheduleVisibility.filterMemberTrainers(
      widget.trainers,
      query: _query,
      specialty: _activeSpecialty,
    );
  }

  // Filter chip (spec §8). Aktif = kuning solid teks gelap; inaktif = outline
  // abu. Hanya satu aktif pada satu waktu.
  Widget _buildFilterChip(String label) {
    final specialty = label == 'All Trainers' ? null : label;
    final active = _activeSpecialty == specialty;
    return GestureDetector(
      onTap: () => setState(() => _activeSpecialty = specialty),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.accent : const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(999),
          border: active ? null : Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: active ? const Color(0xFF0E0E0E) : const Color(0xFF9A9A9A),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final memberDisplayName = _sessionDisplayName('Member');
    final eligible = TrainerScheduleVisibility.bookingEligible(widget.trainers);
    final filtered = _filteredTrainers;

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: widget.onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          Row(
            children: [
              InitialAvatar(
                name: memberDisplayName,
                radius: 16,
                avatarPath:
                    AppSessionService.instance.currentSession?.avatarUrl,
                onTap: _openMemberProfileTab,
                semanticLabel: 'Buka Profil Member',
              ),
              const SizedBox(width: 8),
              Text(
                'Find Your Trainer',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              const NotificationBellButton(),
            ],
          ),
          const SizedBox(height: 8),
          // Hero dua-warna (spec §6): "FIND YOUR" putih + "EXPERT GUIDE" kuning,
          // 32px w900 uppercase, letter-spacing -0.5, line-height 1.05.
          const Text(
            'FIND YOUR',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              height: 1.05,
              letterSpacing: -0.5,
              color: Color(0xFFFFFFFF),
            ),
          ),
          const Text(
            'EXPERT GUIDE',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              height: 1.05,
              letterSpacing: -0.5,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 8),
          // Subtitle (spec §6): uppercase, 13px w600, letter-spacing 1, #9A9A9A.
          const Text(
            'PERFORMANCE COACHES.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
              height: 1.4,
              color: Color(0xFF9A9A9A),
            ),
          ),
          // TOP MATCH block dihapus (tidak ada di spec Figma, dekoratif/statis).
          const SizedBox(height: 24),
          // Search bar (spec §7): bg #1A1A1A, border #2A2A2A, radius 12.
          // Dekoratif (belum ada logic filter) -- hanya visual.
          TextField(
            controller: _searchController,
            style: Theme.of(context).textTheme.bodyMedium,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'Search by name or specialty…',
              hintStyle:
                  const TextStyle(color: Color(0xFF6B6B6B), fontSize: 14),
              prefixIcon:
                  const Icon(Icons.search, size: 18, color: Color(0xFF9A9A9A)),
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.accent, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Filter chips (spec §8): scroll horizontal, satu aktif (kuning solid),
          // lainnya outline. Aktif diklik -> filter kategori by specialty.
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              children: [
                _buildFilterChip('All Trainers'),
                for (final specialty in TrainerSpecialties.popularLabels) ...[
                  const SizedBox(width: 10),
                  _buildFilterChip(specialty),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (widget.isLoading && widget.trainers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            )
          else if (widget.error != null && widget.trainers.isEmpty)
            _buildTrainerLoadError(context)
          else if (eligible.isEmpty)
            _buildNoScheduleEmptyState(context)
          else if (filtered.isEmpty)
            _buildTrainerSearchEmptyState(context)
          else ...[
            if (widget.error != null) _buildRefreshError(context),
            ...filtered.map(
              (trainer) => Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _buildTrainerCard(context, trainer),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrainerSearchEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded,
              size: 44, color: Color(0xFF6B6B6B)),
          const SizedBox(height: 12),
          Text(
            'Tidak ada trainer yang cocok',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Coba ubah kata kunci pencarian atau pilih kategori lain.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Color(0xFF6B6B6B),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoScheduleEmptyState(BuildContext context) {
    return _buildTrainerStateCard(
      context,
      icon: Icons.event_busy_rounded,
      message:
          'Belum ada Personal Trainer dengan jadwal booking yang tersedia.',
    );
  }

  Widget _buildTrainerLoadError(BuildContext context) {
    return _buildTrainerStateCard(
      context,
      icon: Icons.cloud_off_rounded,
      message: widget.error!,
      actionLabel: 'COBA LAGI',
      onAction: widget.onRefresh,
    );
  }

  Widget _buildRefreshError(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _buildTrainerStateCard(
        context,
        icon: Icons.sync_problem_rounded,
        message: 'Daftar Personal Trainer belum berhasil diperbarui.',
        actionLabel: 'COBA LAGI',
        onAction: widget.onRefresh,
        compact: true,
      ),
    );
  }

  Widget _buildTrainerStateCard(
    BuildContext context, {
    required IconData icon,
    required String message,
    String? actionLabel,
    Future<void> Function()? onAction,
    bool compact = false,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: compact ? 18 : 40,
        horizontal: 16,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        children: [
          Icon(icon, size: compact ? 28 : 44, color: const Color(0xFF6B6B6B)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            TextButton(
              onPressed: widget.isLoading ? null : () => onAction(),
              child: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }

  // Kartu trainer varian STANDARD (spec §9). Semua data dari sumber nyata:
  // nama, rating, reviews, specialty, kuota, badge (derived). Foto belum ada
  // datanya -> placeholder inisial (kode siap disambung NetworkImage nanti).
  Widget _buildTrainerCard(BuildContext context, TrainerProfile trainer) {
    final initials = _trainerInitials(trainer.name);
    final tierLabel = trainerTierLabel(trainer.tier);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF262626)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x80000000), // rgba(0,0,0,0.5)
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Area foto (image-dominant ~380px) ──
            SizedBox(
              height: 380,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildTrainerPhoto(trainer, initials),
                  // Gradient overlay (transparent 35% -> rgba(14,14,14,0.95)).
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.35, 1.0],
                        colors: [
                          Colors.transparent,
                          Color(0xF20E0E0E), // rgba(14,14,14,0.95)
                        ],
                      ),
                    ),
                  ),
                  // Tier badge (PRO/ELITE) pojok kanan atas — hanya bila ada.
                  if (tierLabel != null)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tierLabel,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: Color(0xFF0E0E0E),
                          ),
                        ),
                      ),
                    ),
                  // Nama + rating overlay (bottom-left, di atas gradient).
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trainer.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            letterSpacing: -0.3,
                            color: Color(0xFFFFFFFF),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Rating nyata (bintang + angka + jumlah review).
                        Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 16, color: AppColors.accent),
                            const SizedBox(width: 4),
                            Text(
                              trainerRatingDisplay(
                                rating: trainer.rating,
                                reviewsCount: trainer.reviewsCount,
                              ),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // ── Info area (di bawah foto) ──
            Container(
              width: double.infinity,
              color: const Color(0xFF161616),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (trainer.specialtyLabels.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...trainer.specialtyLabels.take(2).map((label) =>
                            _buildTrainerTag(
                                TrainerSpecialties.displayLabel(label)
                                    .toUpperCase())),
                        if (trainer.specialtyLabels.length > 2)
                          _buildTrainerTag(
                              '+${trainer.specialtyLabels.length - 2}'),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                  // Badge kuota (dipertahankan — data nyata).
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: trainer.isAvailable
                            ? AppColors.surfaceSoft
                            : AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            trainer.isAvailable
                                ? Icons.group_rounded
                                : Icons.lock_rounded,
                            size: 14,
                            color: trainer.isAvailable
                                ? AppColors.textSecondary
                                : AppColors.error,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            trainer.isAvailable
                                ? 'Slot tersedia (${trainer.activeMembers}/${trainer.maxMembers})'
                                : 'Kuota Penuh (${trainer.activeMembers}/${trainer.maxMembers})',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: trainer.isAvailable
                                          ? AppColors.textSecondary
                                          : AppColors.error,
                                      fontWeight: FontWeight.w700,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // CTA LIHAT PROFIL (navigasi & argumen TIDAK diubah).
                  SizedBox(
                    width: double.infinity,
                    child: EggButton.primary(
                      label: 'LIHAT PROFIL',
                      onPressed: () => Get.toNamed(
                        AppRoutes.trainerProfileDetail,
                        arguments: {
                          'trainer': trainer,
                          'source': 'member',
                          'hasActivePtEngagement': widget.hasActivePtEngagement,
                          'activePtStatus': widget.activePtStatus,
                          'activePtTrainerName': widget.activePtTrainerName,
                          'profileCompleteness': widget.profileCompleteness,
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrainerPhoto(TrainerProfile trainer, String initials) {
    final displayUrl = resolvePublicStorageUrl(trainer.displayPhotoPath);
    final avatarUrl = resolvePublicStorageUrl(trainer.avatarUrl);
    final fallback = ColoredBox(
      color: const Color(0xFF1A1A1A),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: 96,
            fontWeight: FontWeight.w900,
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
      ),
    );

    Widget avatarOrInitial() => avatarUrl == null
        ? fallback
        : Image.network(
            avatarUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
          );

    return displayUrl == null
        ? avatarOrInitial()
        : Image.network(
            displayUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => avatarOrInitial(),
          );
  }

  // Tag spesialisasi (spec §9.3): bg #1C1C1C, border #2A2A2A, radius 8.
  Widget _buildTrainerTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: Color(0xFF9A9A9A),
        ),
      ),
    );
  }

  String _trainerInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    final letters = parts.take(2).map((w) => w[0]).join();
    return letters.toUpperCase();
  }
}

class _MembershipTabV2 extends StatefulWidget {
  const _MembershipTabV2({
    required this.dashboard,
    required this.plans,
    required this.isPlansLoading,
    required this.plansError,
    required this.onRefreshPlans,
  });

  final MemberDashboardData dashboard;
  final List<MembershipPlan> plans;
  final bool isPlansLoading;
  final String? plansError;
  final Future<void> Function() onRefreshPlans;

  @override
  State<_MembershipTabV2> createState() => _MembershipTabV2State();
}

class _MembershipTabV2State extends State<_MembershipTabV2> {
  final BackendPaymentService _paymentService = BackendPaymentService();

  bool _isLoading = false;
  String? _backendError;
  MemberMembershipOverview? _membershipOverview;
  List<MemberTransactionListItem> _transactions = const [];

  @override
  void initState() {
    super.initState();
    _loadLiveMembershipData();
  }

  Future<void> _loadLiveMembershipData() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
      _backendError = null;
    });

    try {
      final results = await Future.wait<Object>([
        _paymentService.getMembershipOverview(),
        _paymentService.getMemberTransactions(limit: 5),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _membershipOverview = results[0] as MemberMembershipOverview;
        _transactions = results[1] as List<MemberTransactionListItem>;
      });
    } on PaymentApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _backendError = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _backendError =
            'Status membership belum dapat diperbarui. Silakan coba lagi.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  ActiveMembershipSummary? get _activeMembership =>
      _membershipOverview?.activeMembership;

  String get _activePlanName =>
      _activeMembership?.planName ?? widget.dashboard.packageName;

  int get _remainingDays =>
      _activeMembership?.remainingDays ?? widget.dashboard.remainingDays;

  bool get _hasActiveMembership => _activeMembership?.isActive ?? true;

  String get _memberStatusLabel =>
      _hasActiveMembership ? 'Active Member' : 'Belum Ada Paket Aktif';

  // "Expires on [tanggal]" dari end_date rantai kontigu (fix stacking kemarin;
  // endDate sudah di-override backend ke ujung rantai). Null bila tak ada paket.
  String? get _expiresOnLabel {
    final end = _activeMembership?.endDate;
    if (end == null || !_hasActiveMembership) return null;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final day = end.day.toString().padLeft(2, '0');
    return 'Expires on $day ${months[end.month - 1]} ${end.year}';
  }

  double get _progressValue {
    if (!_hasActiveMembership) {
      return 0;
    }

    final remaining = _remainingDays.clamp(0, 365);
    return (remaining / 180).clamp(0.08, 1.0);
  }

  List<_MembershipTransactionView> get _transactionViews {
    if (_transactions.isNotEmpty) {
      return _transactions
          .map(
            (item) => _MembershipTransactionView(
              title: item.title,
              amountLabel: formatTransactionRupiah(item.amount),
              // Tanggal + jam: pakai paid_at bila lunas, else created_at
              // (pending/cancelled/expired). Konsisten dgn halaman Semua Transaksi.
              dateLabel: transactionDateLabel(
                paidAt: item.paidAt,
                createdAt: item.createdAt,
              ),
              status: item.status,
              referenceCode: item.referenceCode,
              amount: item.amount,
              paidAt: item.paidAt,
              paymentMethod: item.paymentMethod,
              qrString: item.qrString,
              paymentNumber: item.paymentNumber,
              expiredAt: item.expiredAt,
              isExpired: item.isExpired,
            ),
          )
          .toList();
    }

    return const [];
  }

  List<MembershipPlan> get _displayPlans => widget.plans;

  Future<void> _refreshMembershipTab() async {
    await Future.wait([
      _loadLiveMembershipData(),
      widget.onRefreshPlans(),
    ]);
  }

  String get _memberDisplayName =>
      _sessionDisplayName(widget.dashboard.memberName);

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _refreshMembershipTab,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          Row(
            children: [
              InitialAvatar(
                name: _memberDisplayName,
                radius: 16,
                avatarPath:
                    AppSessionService.instance.currentSession?.avatarUrl,
                onTap: _openMemberProfileTab,
                semanticLabel: 'Buka Profil Member',
              ),
              const SizedBox(width: 8),
              Text(
                'Welcome, $_memberDisplayName',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              // Icon bell/lonceng: buka halaman notifikasi yang SAMA dengan tab
              // lain (Home dll) -> reuse route AppRoutes.notifications, bukan
              // sistem terpisah. Gaya container bulat Membership dipertahankan.
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFF1C1C1C),
                  shape: BoxShape.circle,
                ),
                child: const NotificationBellButton(
                    color: AppColors.textSecondary),
              ),
            ],
          ),
          // Judul "Keanggotaan" diperbesar & tegas (skala heading besar).
          // Badge SYNCED BACKEND & baris "CURRENT TIER" dihapus (tidak ada di Figma).
          // Status sinkron backend tetap jalan di background, hanya indikator
          // visualnya yang dihilangkan.
          Text(
            'Keanggotaan',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
          ),
          const SizedBox(height: 10),
          if (_backendError != null) ...[
            const SizedBox(height: 10),
            Text(
              _backendError!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
            ),
          ],
          const SizedBox(height: 16),
          EggCard(
            highlight: true,
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [AppColors.accentBronze, Color(0xFF191919)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Supra-label kecil kuning, sejajar horizontal dgn badge
                      // centang di pojok kanan atas card.
                      Text(
                        'STATUS KEANGGOTAAN',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _memberStatusLabel,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      // Paragraf deskripsi dihapus (tidak dipakai di desain baru).
                      const SizedBox(height: 16),
                      // Baris: angka besar + "HARI TERSISA" (kiri), "Expires on"
                      // (kanan) sejajar. Data tidak berubah, hanya posisi.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$_remainingDays',
                                style: Theme.of(context)
                                    .textTheme
                                    .displaySmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              Text(
                                _hasActiveMembership
                                    ? 'HARI TERSISA'
                                    : 'BELUM AKTIF',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.0,
                                    ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          // "Expires on [tanggal]" dari end_date rantai kontigu.
                          if (_expiresOnLabel != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                _expiresOnLabel!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: _progressValue,
                        minHeight: 7,
                        borderRadius: BorderRadius.circular(99),
                        backgroundColor: AppColors.surfaceSoft,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.accent),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _activePlanName,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                  // Badge centang bulat kecil di pojok kanan atas (warna kuning/gold
                  // aksen, konsisten dgn tombol & progress bar). Bentuk/posisi tetap.
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (_hasActiveMembership
                                ? AppColors.accent
                                : AppColors.info)
                            .withValues(alpha: 0.2),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        _hasActiveMembership
                            ? Icons.check_rounded
                            : Icons.lock_outline_rounded,
                        size: 16,
                        color: _hasActiveMembership
                            ? AppColors.accent
                            : AppColors.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          EggButton.primary(
            label: 'Pilih / Perpanjang Paket',
            trailingIcon: Icons.arrow_forward_rounded,
            onPressed: () => Get.toNamed(
              AppRoutes.membershipPackages,
              arguments: const {'source': 'member'},
            ),
          ),
          const SizedBox(height: 22),
          // Judul section Pilihan Paket (sebelumnya belum ada).
          Text(
            'Pilihan Paket',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          if (widget.isPlansLoading && _displayPlans.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (widget.plansError != null && _displayPlans.isEmpty)
            Text(
              widget.plansError!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            )
          else if (_displayPlans.isEmpty)
            Text(
              'Belum ada paket membership yang tersedia.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            )
          else
            ..._displayPlans.map(
              (plan) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: EggCard(
                  highlight: false,
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: const LinearGradient(
                        colors: [AppColors.surfaceMuted, Color(0xFF171717)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Label jenis paket dari billing_period nyata + icon petir.
                        Row(
                          children: [
                            Icon(
                              Icons.bolt_rounded,
                              size: 14,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              membershipDurationLabel(
                                durationDays: plan.durationDays,
                                billingPeriod: plan.billingPeriod,
                              ).toUpperCase(),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.9,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                plan.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                            if (plan.isBestSeller)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.accent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.workspace_premium_rounded,
                                      size: 12,
                                      color: AppColors.accent,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'TERLARIS',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${plan.priceLabel}${plan.periodLabel}',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                'Riwayat Transaksi',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              // Link "VIEW ALL" (ganti badge LIVE BACKEND) -> halaman semua transaksi.
              if (_transactionViews.isNotEmpty)
                GestureDetector(
                  onTap: () => Get.toNamed(AppRoutes.memberAllTransactions),
                  child: Text(
                    'VIEW ALL',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontSize: 12,
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Halaman utama: tampilkan maksimal 2 transaksi TERBARU (list sudah
          // urut terbaru->lama dari backend). Selebihnya via "VIEW ALL" ->
          // halaman Semua Transaksi (tidak dibatasi). Slice dari list yang sudah
          // ada di state, tanpa fetch baru.
          if (_transactionViews.isEmpty)
            Text(
              'Belum ada riwayat transaksi membership.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            )
          else
            ..._transactionViews.take(2).map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: MemberTransactionTile(
                      title: item.title,
                      amountLabel: item.amountLabel,
                      dateLabel: item.dateLabel,
                      status: item.status,
                      // SUCCESS -> struk; PENDING -> reuse QR / regenerate (helper).
                      onTap: _transactionTapHandler(context, item),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  /// Handler tap kartu transaksi (halaman utama): SUCCESS -> struk;
  /// PENDING -> reuse QR / regenerate via helper. Null bila tak bisa diklik.
  VoidCallback? _transactionTapHandler(
      BuildContext context, _MembershipTransactionView item) {
    final ref = item.referenceCode;
    if (ref == null) return null;

    if (isTransactionSuccess(item.status) && item.amount != null) {
      return () => showTransactionReceiptSheet(
            context,
            planName: item.title,
            amount: item.amount!,
            status: item.status,
            invoiceCode: ref,
            paidAt: item.paidAt,
          );
    }

    if (item.status.toLowerCase() == 'pending' && item.amount != null) {
      return () => handlePendingPaymentTap(
            context,
            referenceCode: ref,
            isExpired: item.isExpired,
            amount: item.amount!,
            status: item.status,
            paymentMethod: item.paymentMethod,
            qrString: item.qrString,
            paymentNumber: item.paymentNumber,
            expiredAt: item.expiredAt,
            onShouldRefresh: _loadLiveMembershipData,
          );
    }

    return null;
  }
}

class _MembershipTransactionView {
  const _MembershipTransactionView({
    required this.title,
    required this.amountLabel,
    required this.dateLabel,
    required this.status,
    this.referenceCode,
    this.amount,
    this.paidAt,
    this.paymentMethod,
    this.qrString,
    this.paymentNumber,
    this.expiredAt,
    this.isExpired = false,
  });

  final String title;
  final String amountLabel;
  final String dateLabel;
  final String status;
  // Data tambahan untuk struk (hanya terisi dari transaksi backend live).
  final String? referenceCode;
  final double? amount;
  final DateTime? paidAt;
  // Data pending untuk "lanjutkan pembayaran".
  final String? paymentMethod;
  final String? qrString;
  final String? paymentNumber;
  final DateTime? expiredAt;
  final bool isExpired;
}

class _ProfileTabV2 extends StatelessWidget {
  const _ProfileTabV2({
    required this.name,
    required this.equipments,
    this.memberProfile,
    this.physicalProgressSnapshot,
    this.physicalProgressLoaded = false,
    this.onPhysicalProgressUpdated,
    this.profileRequestFailed = false,
    this.onProfileUpdated,
    this.onAvatarChanged,
  });

  final String name;
  final List<EquipmentInfo> equipments;
  // Profil member dari backend (berat badan & target). Null bila belum ter-load.
  final MemberProfileData? memberProfile;
  final MemberPhysicalProgressSnapshot? physicalProgressSnapshot;
  final bool physicalProgressLoaded;
  final Future<void> Function()? onPhysicalProgressUpdated;
  final bool profileRequestFailed;
  final Future<void> Function()? onProfileUpdated;
  // Dipanggil setelah avatar berubah (upload/hapus) -> shell setState supaya
  // header di semua tab ikut ter-update (sinkron 1 sumber: session.avatarUrl).
  final VoidCallback? onAvatarChanged;

  @override
  Widget build(BuildContext context) {
    final displayName = _sessionDisplayName(name);
    final displayEmail = _sessionDisplayEmail() ??
        '${displayName.toLowerCase().replaceAll(' ', '.')}@egggym.com';
    // Tier/paket aktif untuk pill kecil di bawah email (data nyata dari
    // current_tier profil member). Disembunyikan bila belum ada.
    final tierLabel = memberProfile?.membershipTier?.trim();
    final hasTier = tierLabel != null && tierLabel.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        Row(
          children: [
            Text(
              'Profil Saya',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const Spacer(),
            const NotificationBellButton(),
            const SizedBox(width: 8),
            InitialAvatar(
              name: displayName,
              radius: 15,
              avatarPath: AppSessionService.instance.currentSession?.avatarUrl,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Center(
          child: Column(
            children: [
              ProfileAvatarEditor(
                displayName: displayName,
                avatarPath:
                    AppSessionService.instance.currentSession?.avatarUrl,
                onAvatarChanged: onAvatarChanged,
              ),
              const SizedBox(height: 16),
              Text(
                displayName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                displayEmail,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              // Pill kecil tier/paket aktif (ganti badge MEMBER BACKEND).
              // Data nyata dari current_tier; disembunyikan bila belum ada.
              if (hasTier) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tierLabel.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Card besar "MEMBER STATUS" dihapus (tidak ada di Figma).
        const SizedBox(height: 24),
        // Kartu statistik: angka besar (kuning) + satuan kecil (abu) di 2 baris.
        // Data dari backend (memberProfile). Empty state jujur bila belum diisi.
        Builder(builder: (context) {
          final profile = memberProfile;
          final weightKg = profile?.weightKg;
          final hasWeight = weightKg != null && weightKg > 0;

          // Row 2 kotak (Latihan Bulan Ini + Berat Badan). IntrinsicHeight
          // memberi Row tinggi TERHINGGA supaya stretch (2 kartu sama tinggi)
          // aman di ListView unbounded. Target dipindah ke card full-width di
          // bawah (lihat setelah blok ini).
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _ProfileStatCard(
                    label: 'LATIHAN BULAN INI',
                    value: monthlyWorkoutCountDisplay(
                      profile?.workoutsThisMonth,
                      failed: profileRequestFailed,
                    ),
                    unit: 'Sesi',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ProfileStatCard(
                    label: 'BERAT BADAN',
                    value: hasWeight ? weightKg.toStringAsFixed(0) : '-',
                    unit: hasWeight ? 'kg' : 'Belum diisi',
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),
        // Target: card full-width tersendiri (dapat ruang lebar -> teks target
        // panjang tidak kepotong). Data nyata dari fitnessGoal, empty state jujur.
        Builder(builder: (context) {
          final goal = memberProfile?.fitnessGoal?.trim();
          final hasGoal = goal != null && goal.isNotEmpty;
          return _ProfileTargetCard(
            value: hasGoal ? goal : 'Belum diisi',
            filled: hasGoal,
          );
        }),
        const SizedBox(height: 20),
        Text(
          'Informasi Akun',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        _ActionTile(
          title: 'Data Pribadi',
          subtitle: 'Nama, tanggal lahir, dan identitas member',
          icon: Icons.badge_outlined,
          onTap: () => Get.toNamed(
            AppRoutes.memberPersonalInfo,
            arguments: {'onProfileUpdated': onProfileUpdated},
          ),
          // Preview dari data nyata getProfile(); "Belum diisi" bila null/kosong.
          previewRows: [
            (
              label: 'Nama',
              value: (memberProfile?.name.trim().isNotEmpty ?? false)
                  ? memberProfile!.name.trim()
                  : displayName,
            ),
            (
              label: 'Tgl Lahir',
              value: AppDateFormatter.date(
                memberProfile?.birthDate,
                fallback: 'Belum diisi',
              ),
            ),
            (
              label: 'Jenis Kelamin',
              value: _genderLabel(memberProfile?.gender),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Builder(builder: (context) {
          final weights = physicalProgressWeightPreview(
            physicalProgressSnapshot,
          );
          return _ActionTile(
            title: 'Progress Fisik',
            subtitle: 'Perbandingan berat awal dan terbaru',
            icon: Icons.monitor_weight_outlined,
            onTap: () async {
              final hasCheckpoint =
                  physicalProgressSnapshot?.hasCheckpoint == true;
              if (physicalProgressLoaded && !hasCheckpoint) {
                await Get.toNamed(
                  AppRoutes.memberPhysicalProgressForm,
                  arguments: const {'openOverviewAfterSave': true},
                );
              } else {
                await Get.toNamed(AppRoutes.memberPhysicalProgress);
              }
              await onPhysicalProgressUpdated?.call();
            },
            previewRows: [
              (label: 'Berat Before', value: weights.before),
              (label: 'Berat After', value: weights.after),
            ],
          );
        }),
        const SizedBox(height: 12),
        _ActionTile(
          title: 'Peralatan Gym',
          subtitle:
              'Lihat katalog, status alat, target otot, dan panduan pemakaian',
          icon: Icons.fitness_center_rounded,
          onTap: () => Get.toNamed(
            AppRoutes.memberEquipmentCatalog,
            arguments: {'equipments': equipments},
          ),
          // Tanpa personalisasi palsu: hanya ringkasan yang definisinya jelas.
          previewRows: [
            (
              label: 'Total Alat Tersedia',
              value: '${equipments.where((e) => e.isAvailable).length} alat',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ActionTile(
          title: 'Bantuan & Panduan',
          subtitle: 'Cari panduan membership, booking, dan latihan',
          icon: Icons.help_outline_rounded,
          onTap: () => Get.toNamed(
            AppRoutes.helpCenter,
            arguments: const {'role': 'member'},
          ),
        ),
        const SizedBox(height: 20),
        EggButton.secondary(
          label: 'Keluar dari Akun',
          onPressed: () async {
            await AppSessionService.instance.clear();
            Get.offAllNamed(AppRoutes.login);
          },
        ),
      ],
    );
  }
}
