import 'dart:async';

import 'package:egg_gym/app/routes/app_routes.dart';
import 'package:egg_gym/core/formatters/app_date_formatter.dart';
import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/core/utils/payment_verification_overdue_copy.dart';
import 'package:egg_gym/core/utils/trainer_session_visibility.dart';
import 'package:egg_gym/core/utils/trainer_rating_display.dart';
import 'package:egg_gym/core/utils/trainer_tier.dart';
import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:egg_gym/data/services/backend_program_service.dart';
import 'package:egg_gym/data/services/backend_trainer_profile_service.dart';
import 'package:egg_gym/data/services/backend_trainer_service.dart';
import 'package:egg_gym/data/services/notification_center_service.dart';
import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:egg_gym/domain/entities/trainer_schedule.dart';
import 'package:egg_gym/domain/repositories/demo_repository.dart';
import 'package:egg_gym/presentation/controllers/trainer_shell_controller.dart';
import 'package:egg_gym/presentation/pages/trainer/trainer_home_dashboard.dart';
import 'package:egg_gym/presentation/providers/workout_timer_provider.dart';
import 'package:egg_gym/presentation/widgets/common/brand_logo.dart';
import 'package:egg_gym/presentation/widgets/common/egg_button.dart';
import 'package:egg_gym/presentation/widgets/common/egg_card.dart';
import 'package:egg_gym/presentation/widgets/common/initial_avatar.dart';
import 'package:egg_gym/presentation/widgets/common/profile_avatar_editor.dart';
import 'package:egg_gym/presentation/widgets/common/section_header.dart';
import 'package:egg_gym/presentation/widgets/common/status_chip.dart';
import 'package:egg_gym/presentation/widgets/common/booking_expiry_countdown.dart';
import 'package:egg_gym/presentation/widgets/common/reschedule_request_card.dart';
import 'package:egg_gym/presentation/widgets/common/notification_bell_button.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

bool _isPendingSession(ScheduleSession session) => session.status == 'Menunggu';

bool isTrainerProgramActive(ProgramListItem program) => program.isActiveControl;

void _openPrimarySessionAction(
  ScheduleSession session, {
  Future<void> Function(ScheduleSession)? onConfirm,
  Future<void> Function(ScheduleSession)? onReject,
}) {
  if (_isPendingSession(session)) {
    _showBookingActionDialog(session, onConfirm: onConfirm, onReject: onReject);
    return;
  }

  Get.toNamed(
    AppRoutes.trainerSessionDetail,
    arguments: <String, dynamic>{
      'session': session,
      'memberProfileId': session.memberProfileId,
      'role': 'trainer',
    },
  );
}

void _showBookingActionDialog(
  ScheduleSession session, {
  Future<void> Function(ScheduleSession)? onConfirm,
  Future<void> Function(ScheduleSession)? onReject,
}) {
  Get.defaultDialog(
    title: 'Booking dari ${session.clientName}',
    titleStyle: const TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 18,
    ),
    content: Column(
      children: [
        Text(
          '${session.timeRange} | ${session.location}',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Text(
          session.note,
          style: const TextStyle(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    ),
    confirm: ElevatedButton(
      onPressed: () async {
        Get.back();
        if (onConfirm != null) {
          await onConfirm(session);
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.background,
      ),
      child: const Text('Konfirmasi'),
    ),
    cancel: OutlinedButton(
      onPressed: () {
        Get.back();
        Get.toNamed(
          AppRoutes.bookingReschedule,
          arguments: session,
        );
      },
      child: const Text('Reschedule'),
    ),
    textCancel: 'Tolak',
    onCancel: () async {
      Get.back();
      if (onReject != null) {
        await onReject(session);
      }
    },
  );
}

void _openRescheduleFlow(ScheduleSession session) {
  Get.toNamed(
    AppRoutes.bookingReschedule,
    arguments: session,
  );
}

String _trainerSessionDisplayName(String fallback) {
  final session = AppSessionService.instance.currentSession;
  final sessionName = session?.name?.trim();

  if (session?.role == 'trainer' &&
      sessionName != null &&
      sessionName.isNotEmpty) {
    return sessionName;
  }

  return fallback;
}

String? _trainerSessionDisplayEmail() {
  final session = AppSessionService.instance.currentSession;
  final sessionEmail = session?.email?.trim();

  if (session?.role == 'trainer' &&
      sessionEmail != null &&
      sessionEmail.isNotEmpty) {
    return sessionEmail;
  }

  return null;
}

class TrainerShellPage extends StatefulWidget {
  const TrainerShellPage({super.key});

  @override
  State<TrainerShellPage> createState() => _TrainerShellPageState();
}

class _TrainerShellPageState extends State<TrainerShellPage>
    with WidgetsBindingObserver {
  final TrainerShellController _controller = Get.find<TrainerShellController>();
  final GlobalKey<_ProgramsTabState> _programsTabKey =
      GlobalKey<_ProgramsTabState>();

  // Lazy-load: tab yang sudah pernah aktif dibangun penuh (widget + initState
  // fetch). Home (0) selalu diaktifkan lebih dulu agar data utama tampil saat
  // login. Tab lain baru dibangun saat pertama kali dibuka user, mencegah
  // burst request serentak ke dev server single-thread.
  final Set<int> _activatedTabs = <int>{0};
  String? _trainerTier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationCenterService.instance.refresh();
    _loadTrainerTier();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => NotificationCenterService.instance.dispatchPendingPush(),
    );
  }

  Future<void> _loadTrainerTier() async {
    if (!AppSessionService.instance.isTrainerAuthenticated) return;
    try {
      final dashboard = await BackendTrainerService().getDashboard();
      if (mounted) setState(() => _trainerTier = dashboard.tier);
    } catch (error) {
      debugPrint('Trainer tier load failed: $error');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationCenterService.instance.refresh();
      _loadTrainerTier();
    }
  }

  void _onBookingConfirmed() {
    // Refresh Programs tab when a booking is confirmed
    _programsTabKey.currentState?.refreshConfirmedBookings();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<DemoRepository>();
    final dashboard = repo.getTrainerDashboard();
    final trainerDisplayName =
        _trainerSessionDisplayName(dashboard.trainerName);
    final trainerDisplayEmail = _trainerSessionDisplayEmail();
    final trainerService = BackendTrainerService();

    // Bangun widget tab sesungguhnya per index. Dipanggil hanya untuk tab yang
    // sudah pernah aktif (lazy-load), supaya initState (fetch) tidak jalan untuk
    // tab yang belum dibuka -> mencegah burst request saat cold start/login.
    Widget buildRealTab(int index) {
      switch (index) {
        case 0:
          return TrainerHomeDashboard(
            trainerName: trainerDisplayName,
            tier: _trainerTier,
            backendService: trainerService,
            onSeeAllSessions: () => _controller.changeTab(1),
            onBookingConfirmed: _onBookingConfirmed,
          );
        case 1:
          return _ScheduleTabV2(
            sessions: dashboard.todayAgenda,
            tier: _trainerTier,
            backendService: trainerService,
            onBookingConfirmed: _onBookingConfirmed,
          );
        case 2:
          return _ClientsTab(
            backendService: trainerService,
            tier: _trainerTier,
          );
        case 3:
          return _ProgramsTab(
            key: _programsTabKey,
            backendService: trainerService,
            tier: _trainerTier,
          );
        default:
          return _TrainerProfileTabV2(
            name: trainerDisplayName,
            email: trainerDisplayEmail,
            activeClients: dashboard.activeClients,
            tier: _trainerTier,
            backendService: trainerService,
            // Avatar berubah -> rebuild shell agar header ikut update
            // (1 sumber: session.avatarUrl).
            onAvatarChanged: () {
              if (mounted) setState(() {});
            },
          );
      }
    }

    return Obx(
      () {
        // Home (tab 0) + tab yang sedang aktif ditandai sudah "diaktifkan".
        // Tab yang belum pernah dibuka pakai placeholder ringan (initState-nya
        // tidak jalan sehingga tidak fetch), tapi tab yang sudah dibuka tetap
        // dipertahankan hidup di IndexedStack (state preservation).
        _activatedTabs.add(_controller.currentIndex.value);

        final children = List<Widget>.generate(5, (i) {
          return _activatedTabs.contains(i)
              ? buildRealTab(i)
              : const SizedBox.shrink();
        });

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _controller.currentIndex.value,
              children: children,
            ),
          ),
          bottomNavigationBar: DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0xFF121212),
              border: Border(top: BorderSide(color: Color(0xFF1E1E1E))),
              boxShadow: [
                BoxShadow(
                  color: Color(0x80000000),
                  blurRadius: 12,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 72,
                child: BottomNavigationBar(
                  currentIndex: _controller.currentIndex.value,
                  onTap: _controller.changeTab,
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  selectedItemColor: AppColors.accent,
                  unselectedItemColor: const Color(0xFF6B6B6B),
                  selectedFontSize: 9,
                  unselectedFontSize: 9,
                  selectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                  items: const [
                    BottomNavigationBarItem(
                        icon: Icon(Icons.home_filled),
                        activeIcon:
                            _TrainerNavActiveIcon(icon: Icons.home_filled),
                        label: 'HOME'),
                    BottomNavigationBarItem(
                        icon: Icon(Icons.calendar_today_rounded),
                        activeIcon: _TrainerNavActiveIcon(
                            icon: Icons.calendar_today_rounded),
                        label: 'JADWAL'),
                    BottomNavigationBarItem(
                        icon: Icon(Icons.groups_rounded),
                        activeIcon:
                            _TrainerNavActiveIcon(icon: Icons.groups_rounded),
                        label: 'KLIEN'),
                    BottomNavigationBarItem(
                        icon: Icon(Icons.bolt_rounded),
                        activeIcon:
                            _TrainerNavActiveIcon(icon: Icons.bolt_rounded),
                        label: 'PROGRAM'),
                    BottomNavigationBarItem(
                        icon: Icon(Icons.person_outline_rounded),
                        activeIcon: _TrainerNavActiveIcon(
                            icon: Icons.person_outline_rounded),
                        label: 'PROFIL'),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TrainerNavActiveIcon extends StatelessWidget {
  const _TrainerNavActiveIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 22),
      );
}

// ignore: unused_element
class _TrainerHomeTab extends StatelessWidget {
  const _TrainerHomeTab({required this.dashboard});

  final TrainerDashboardData dashboard;

  @override
  Widget build(BuildContext context) {
    final timer = context.watch<TrainerWorkoutTimerProvider>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 120),
      children: [
        Row(
          children: [
            const BrandLogo(compact: true),
            const Spacer(),
            IconButton(
              onPressed: () => Get.toNamed(AppRoutes.projectBoard),
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text('Halo, ${dashboard.trainerName} 👋',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Siap membakar kalori hari ini?',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
                child: _StatCard(
                    label: 'Klien Aktif', value: '${dashboard.activeClients}')),
            const SizedBox(width: 10),
            Expanded(
                child: _StatCard(
                    label: 'Sesi Hari Ini',
                    value: '${dashboard.todaySessions}')),
            const SizedBox(width: 10),
            Expanded(
                child: _StatCard(
                    label: 'Rating',
                    value: dashboard.rating.toStringAsFixed(1))),
          ],
        ),
        const SizedBox(height: 18),
        EggCard(
          child: Column(
            children: [
              Row(
                children: [
                  _TimerModePill(
                    label: 'Countdown',
                    selected: timer.mode == TimerMode.countdown,
                    onTap: () => timer.toggleMode(TimerMode.countdown),
                  ),
                  const SizedBox(width: 8),
                  _TimerModePill(
                    label: 'Stopwatch',
                    selected: timer.mode == TimerMode.stopwatch,
                    onTap: () => timer.toggleMode(TimerMode.stopwatch),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: 180,
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: CircularProgressIndicator(
                        value: timer.progressValue == 0
                            ? 0.02
                            : timer.progressValue,
                        strokeWidth: 10,
                        backgroundColor: AppColors.surfaceSoft,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.accent),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(timer.displayValue,
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text('HIGH INTENSITY',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                children: timer.presets.map((preset) {
                  final selected = timer.selectedPresetMinutes == preset;
                  return ChoiceChip(
                    label: Text('$preset:00'),
                    selected: selected,
                    onSelected: (_) => timer.selectPreset(preset),
                    selectedColor: AppColors.accent,
                    backgroundColor: AppColors.surfaceSoft,
                    labelStyle: TextStyle(
                        color: selected
                            ? AppColors.background
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w700),
                    side: const BorderSide(color: AppColors.divider),
                  );
                }).toList(),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  _RoundAction(
                      icon: Icons.restart_alt_rounded, onTap: timer.reset),
                  const SizedBox(width: 12),
                  Expanded(
                    child: EggButton.primary(
                      label: timer.isRunning ? 'Pause' : 'Mulai Sesi',
                      onPressed: timer.toggleRunning,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeader(
            title: "Today's Sessions",
            subtitle: 'Agenda coaching utama hari ini.'),
        const SizedBox(height: 14),
        ...dashboard.todayAgenda.take(2).map((session) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: EggCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        InitialAvatar(name: session.clientName, radius: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(session.clientName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700)),
                              Text('${session.timeRange} • ${session.location}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        StatusChip(
                          label: session.status,
                          color: session.status == 'Menunggu'
                              ? AppColors.error
                              : AppColors.accent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    EggButton.primary(
                      label: session.status == 'Menunggu'
                          ? 'Konfirmasi Booking'
                          : 'Mulai Sesi',
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

// ignore: unused_element
class _ScheduleTab extends StatelessWidget {
  const _ScheduleTab({required this.sessions});

  final List<ScheduleSession> sessions;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 120),
      children: [
        const SectionHeader(
            title: 'Jadwal PT',
            subtitle: 'Daftar booking yang menunggu atau sudah confirm.'),
        const SizedBox(height: 16),
        ...sessions.map((session) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: EggCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: Text(session.clientName,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700))),
                        StatusChip(
                          label: session.status,
                          color: session.status == 'Menunggu'
                              ? AppColors.error
                              : AppColors.accent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('${session.timeRange} • ${session.location}',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Text(session.note,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: EggButton.secondary(
                            label: 'Tolak',
                            onPressed: () =>
                                Get.toNamed(AppRoutes.projectBoard),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: EggButton.primary(
                            label: 'Konfirmasi',
                            onPressed: () =>
                                Get.toNamed(AppRoutes.projectBoard),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }
}

class _ClientsTab extends StatefulWidget {
  const _ClientsTab({required this.backendService, required this.tier});

  final BackendTrainerService backendService;
  final String? tier;

  @override
  State<_ClientsTab> createState() => _ClientsTabState();
}

class _ClientsTabState extends State<_ClientsTab> {
  List<ClientSummary>? _liveClients;
  Map<int, ProgramListItem> _programByMember = const {};
  Map<int, ScheduleSession> _todaySessionByMember = const {};
  String? _errorMessage;
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _dayRolloverTimer;

  @override
  void initState() {
    super.initState();
    _scheduleDayRollover();
    _loadClients();
  }

  @override
  void dispose() {
    _dayRolloverTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    if (_isLoading || !AppSessionService.instance.isTrainerAuthenticated) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final clients = await widget.backendService.getClients();
      if (!mounted) return;
      setState(() => _liveClients = clients);

      List<ScheduleSession>? sessions;
      String? sessionsError;
      try {
        sessions = await widget.backendService.getScheduleSessions();
      } catch (error) {
        sessionsError =
            'Daftar klien termuat, tetapi sesi hari ini gagal dimuat. Tekan Coba Lagi.';
        debugPrint('Trainer active-today sessions load failed: $error');
      }

      List<ProgramListItem> programs = const [];
      try {
        programs = await BackendProgramService().getTrainerPrograms();
      } catch (error) {
        debugPrint('Trainer client program enrichment failed: $error');
      }
      final latestPrograms = <int, ProgramListItem>{};
      for (final program in programs) {
        if (program.memberProfileId <= 0 ||
            program.sessionsCount <= 0 ||
            !program.isActiveControl ||
            program.progressPercent >= 100) {
          continue;
        }
        latestPrograms.putIfAbsent(program.memberProfileId, () => program);
      }
      Map<int, ScheduleSession>? todaySessions;
      if (sessions != null) {
        todaySessions = <int, ScheduleSession>{};
        for (final session in sessions) {
          final memberId = session.memberProfileId;
          if (memberId == null || !_isClientActiveToday(session)) continue;
          todaySessions.putIfAbsent(memberId, () => session);
        }
      }
      if (!mounted) {
        return;
      }

      setState(() {
        _liveClients = clients;
        _programByMember = latestPrograms;
        if (todaySessions != null) {
          _todaySessionByMember = todaySessions;
        }
        _errorMessage = sessionsError;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      debugPrint('Trainer clients load failed: $error');

      setState(() {
        _errorMessage =
            'Gagal memuat daftar klien. Periksa koneksi lalu coba lagi.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  DateTime get _jakartaToday {
    final jakartaNow = DateTime.now().toUtc().add(const Duration(hours: 7));
    return DateTime(jakartaNow.year, jakartaNow.month, jakartaNow.day);
  }

  void _scheduleDayRollover() {
    _dayRolloverTimer?.cancel();
    final jakartaNow = DateTime.now().toUtc().add(const Duration(hours: 7));
    final nextDay = DateTime(
      jakartaNow.year,
      jakartaNow.month,
      jakartaNow.day + 1,
    );
    final delay = nextDay.difference(jakartaNow) + const Duration(seconds: 1);
    _dayRolloverTimer = Timer(delay, () {
      if (!mounted) return;
      setState(() {});
      _scheduleDayRollover();
    });
  }

  bool _isSameJakartaDate(String rawDate) {
    final parsed = DateTime.tryParse(rawDate);
    final today = _jakartaToday;
    return parsed != null &&
        parsed.year == today.year &&
        parsed.month == today.month &&
        parsed.day == today.day;
  }

  bool _isClientActiveToday(ScheduleSession session) {
    const eligibleStatuses = {
      'payment_verified',
      'confirmed',
      'rescheduled',
    };
    if (!eligibleStatuses.contains(session.rawStatus?.toLowerCase())) {
      return false;
    }
    if (session.rawStatus?.toLowerCase() == 'rescheduled' &&
        session.paymentVerifiedAt == null) {
      return false;
    }
    if (session.rawStatus?.toLowerCase() == 'confirmed' &&
        session.paymentVerifiedAt == null) {
      return false;
    }
    if (session.reservations.isNotEmpty) {
      return session.reservations.any((reservation) =>
          reservation.status == 'reserved' &&
          _isSameJakartaDate(reservation.sessionDate));
    }
    return session.sessionDate != null &&
        _isSameJakartaDate(session.sessionDate!);
  }

  @override
  Widget build(BuildContext context) {
    final clients = _liveClients ?? const <ClientSummary>[];
    final query = _searchQuery.trim().toLowerCase();
    final activeClients = clients
        .where((client) =>
            client.backendId != null &&
            _todaySessionByMember.containsKey(client.backendId))
        .toList();
    final visibleClients = clients.where((client) {
      if (query.isEmpty) return true;
      final program = _programByMember[client.backendId];
      return client.name.toLowerCase().contains(query) ||
          client.goal.toLowerCase().contains(query) ||
          (program?.title.toLowerCase().contains(query) ?? false);
    }).toList();
    final activeToday = activeClients.length;

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _loadClients,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 92),
        children: [
          _TrainerBrandHeader(
            name: AppSessionService.instance.currentSession?.name ?? 'Trainer',
            tier: widget.tier,
          ),
          const SizedBox(height: 17),
          const Text('Daftar Klien',
              style: TextStyle(
                  fontSize: 25,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3)),
          const SizedBox(height: 4),
          const Text('Kelola kemajuan dan program latihan klien Anda.',
              style: TextStyle(color: Color(0xFF9A9A9A), fontSize: 12)),
          const SizedBox(height: 17),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Cari nama klien atau program...',
              hintStyle:
                  const TextStyle(color: Color(0xFF6B6B6B), fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: Color(0xFF9A9A9A), size: 19),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Hapus pencarian',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              isDense: true,
              constraints: const BoxConstraints(minHeight: 48, maxHeight: 48),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.accent),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: _ClientStatCard(
                label: 'TOTAL KLIEN',
                value: '${clients.length}',
                accent: AppColors.accent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ClientStatCard(
                label: 'AKTIF HARI INI',
                value: activeToday.toString().padLeft(2, '0'),
                accent: const Color(0xFF2DD4D4),
              ),
            ),
          ]),
          const SizedBox(height: 17),
          if (_errorMessage != null && _liveClients != null) ...[
            _ClientLoadNotice(
              message: _errorMessage!,
              onRetry: _loadClients,
            ),
            const SizedBox(height: 12),
          ],
          if (_isLoading && _liveClients == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            )
          else if (_errorMessage != null && _liveClients == null)
            _ClientLoadNotice(
              message: _errorMessage!,
              onRetry: _loadClients,
            )
          else if (visibleClients.isEmpty)
            _ClientEmptyState(searching: query.isNotEmpty)
          else
            ...visibleClients.map((client) {
              final program = _programByMember[client.backendId];
              return Padding(
                padding: const EdgeInsets.only(bottom: 13),
                child: _TrainerClientCard(
                  client: client,
                  program: program,
                  todaySession: _todaySessionByMember[client.backendId],
                  onOpen: () => Get.toNamed(
                    AppRoutes.clientDetail,
                    arguments: client,
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _TrainerBrandHeader extends StatelessWidget {
  const _TrainerBrandHeader({required this.name, required this.tier});
  final String name;
  final String? tier;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Semantics(
            button: true,
            label: 'Buka Profil Trainer',
            child: InkWell(
              onTap: () => Get.find<TrainerShellController>().changeTab(4),
              customBorder: const CircleBorder(),
              child: InitialAvatar(
                name: name,
                avatarPath:
                    AppSessionService.instance.currentSession?.avatarUrl,
                radius: 18,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.trim().isEmpty ? 'Trainer' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
                Text(trainerRoleLabel(tier),
                    style: const TextStyle(
                        color: Color(0xFF9A9A9A),
                        fontSize: 7,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.3)),
              ],
            ),
          ),
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1C),
                  borderRadius: BorderRadius.circular(12)),
              child: const NotificationBellButton(
                  color: AppColors.accent, icon: Icons.notifications_rounded)),
        ],
      );
}

class _ClientStatCard extends StatelessWidget {
  const _ClientStatCard({
    required this.label,
    required this.value,
    required this.accent,
  });
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 84,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  border: Border.all(color: const Color(0xFF262626)),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 13, 13, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFF9A9A9A),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6)),
                    const Spacer(),
                    Text(value,
                        style: TextStyle(
                            color: accent,
                            fontSize: 29,
                            height: 1,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child:
                    ColoredBox(color: accent, child: const SizedBox(width: 3)),
              ),
            ],
          ),
        ),
      );
}

class _TrainerClientCard extends StatelessWidget {
  const _TrainerClientCard({
    required this.client,
    required this.program,
    required this.todaySession,
    required this.onOpen,
  });
  final ClientSummary client;
  final ProgramListItem? program;
  final ScheduleSession? todaySession;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final progress = (program?.progressPercent ?? 0).clamp(0, 100);
    final programTitle = program?.title.trim().isNotEmpty == true
        ? program!.title.trim()
        : 'Belum ada program';
    final todayScheduleLabel = _todayScheduleLabel();
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InitialAvatar(
                name: client.name,
                avatarPath: client.avatarUrl,
                radius: 21,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(client.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 7,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (client.memberCode?.trim().isNotEmpty ?? false)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.13),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              client.memberCode!.trim().toUpperCase(),
                              style: const TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5),
                            ),
                          ),
                        Text(client.goal.toUpperCase(),
                            style: const TextStyle(
                                color: Color(0xFF9A9A9A),
                                fontSize: 9,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Buka detail ${client.name}',
                onPressed: onOpen,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.more_vert_rounded,
                    color: Color(0xFF7E7E7E), size: 18),
              ),
            ],
          ),
          const SizedBox(height: 11),
          const Text('CURRENT PROGRAM',
              style: TextStyle(
                  color: Color(0xFF9A9A9A),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7)),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: Text(programTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Text('$progress%',
                  style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            label: 'Progress program ${client.name} $progress persen',
            value: '$progress%',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress / 100,
                minHeight: 6,
                backgroundColor: const Color(0xFF2A2A2A),
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _ClientMetaIcon(
                  icon: Icons.calendar_today_rounded,
                  tooltip: todayScheduleLabel),
              const SizedBox(width: 7),
              Expanded(
                child: Text(todayScheduleLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFF8A8A8A), fontSize: 10)),
              ),
              TextButton(
                onPressed: onOpen,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Lihat Detail →',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _todayScheduleLabel() {
    final session = todaySession;
    if (session == null) {
      final nextSession = client.nextSession.trim();
      return nextSession.isEmpty || nextSession == '-'
          ? 'Belum ada sesi hari ini'
          : nextSession;
    }
    final jakartaNow = DateTime.now().toUtc().add(const Duration(hours: 7));
    for (final reservation in session.reservations) {
      final date = DateTime.tryParse(reservation.sessionDate);
      if (date != null &&
          date.year == jakartaNow.year &&
          date.month == jakartaNow.month &&
          date.day == jakartaNow.day) {
        return '${reservation.startTime} - ${reservation.endTime}';
      }
    }
    return session.timeRange;
  }
}

class _ClientMetaIcon extends StatelessWidget {
  const _ClientMetaIcon({required this.icon, required this.tooltip});
  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: const Color(0xFF9A9A9A)),
        ),
      );
}

class _ClientLoadNotice extends StatelessWidget {
  const _ClientLoadNotice({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Row(children: [
          const Icon(Icons.cloud_off_rounded,
              color: Color(0xFF9A9A9A), size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 11))),
          TextButton(onPressed: onRetry, child: const Text('Coba Lagi')),
        ]),
      );
}

class _ClientEmptyState extends StatelessWidget {
  const _ClientEmptyState({required this.searching});
  final bool searching;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Row(children: [
          const Icon(Icons.people_outline_rounded,
              color: AppColors.accent, size: 22),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              searching
                  ? 'Klien atau program tidak ditemukan.'
                  : 'Tidak ada klien aktif hari ini.',
              style: const TextStyle(color: Color(0xFF9A9A9A), fontSize: 12),
            ),
          ),
        ]),
      );
}

class _ProgramsTab extends StatefulWidget {
  const _ProgramsTab({
    super.key,
    required this.backendService,
    required this.tier,
  });

  final BackendTrainerService backendService;
  final String? tier;

  @override
  State<_ProgramsTab> createState() => _ProgramsTabState();
}

class _ProgramsTabState extends State<_ProgramsTab> {
  final BackendProgramService _programService = BackendProgramService();

  // Member yang bookingnya sudah payment_verified TAPI belum dibuatkan program.
  List<ScheduleSession>? _pendingProgramMembers;
  // Program yang sudah dibuat (punya sesi) beserta progressnya.
  List<ProgramListItem>? _activePrograms;
  bool _isSessionsLoading = false;
  bool _isProgramsLoading = false;
  String? _sessionsError;
  String? _programsError;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void refreshConfirmedBookings() {
    _loadData();
  }

  Future<void> _loadData() async {
    if (!AppSessionService.instance.isTrainerAuthenticated) {
      return;
    }

    await Future.wait([_loadSessions(), _loadPrograms()]);
  }

  Future<void> _loadSessions() async {
    if (!mounted) return;
    setState(() {
      _isSessionsLoading = true;
      _sessionsError = null;
    });

    try {
      final allSessions = await widget.backendService.getScheduleSessions();

      if (!mounted) return;

      // Program PT: booking payment_verified yang BELUM punya program.
      final pending = allSessions
          .where((s) => s.rawStatus == 'payment_verified' && !s.hasProgram)
          .toList();

      setState(() {
        _pendingProgramMembers = pending;
        _sessionsError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sessionsError = 'Gagal memuat member yang perlu dibuatkan program.';
      });
    } finally {
      if (mounted) {
        setState(() => _isSessionsLoading = false);
      }
    }
  }

  Future<void> _loadPrograms() async {
    if (!mounted) return;
    setState(() {
      _isProgramsLoading = true;
      _programsError = null;
    });

    try {
      final programs = await _programService.getTrainerPrograms();
      if (!mounted) return;
      setState(() {
        _activePrograms = programs.where(isTrainerProgramActive).toList();
        _programsError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _programsError = 'Gagal memuat program aktif.';
      });
    } finally {
      if (mounted) {
        setState(() => _isProgramsLoading = false);
      }
    }
  }

  /// Buka halaman kontrol progres/centang sesi untuk program tertentu.
  Future<void> _openProgressControl(int programId) async {
    await Get.toNamed(
      AppRoutes.trainerProgressControl,
      arguments: <String, dynamic>{
        'trainingProgramId': programId,
        'role': 'trainer',
      },
    );
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final pendingMembers = _pendingProgramMembers ?? [];
    final activePrograms = _activePrograms ?? const <ProgramListItem>[];

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
        children: [
          _TrainerBrandHeader(
            name: AppSessionService.instance.currentSession?.name ?? 'Trainer',
            tier: widget.tier,
          ),
          const SizedBox(height: 17),
          const Text(
            'Program PT',
            style: TextStyle(
              fontSize: 22,
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Buat program latihan untuk member yang sudah dikonfirmasi pembayarannya.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          EggCard(
            padding: EdgeInsets.zero,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final watermarkSize =
                    (constraints.maxWidth * 0.235).clamp(62.0, 82.0);
                return ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    height: 138,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF2A2924)),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF282310), Color(0xFF171717)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned(
                          top: -watermarkSize * 0.34,
                          right: -watermarkSize * 0.42,
                          child: IgnorePointer(
                            child: Text(
                              'PROGRAM',
                              maxLines: 1,
                              style: TextStyle(
                                color:
                                    AppColors.accent.withValues(alpha: 0.085),
                                fontSize: watermarkSize,
                                height: 1,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -3,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const StatusChip(label: 'PROGRAM LAB'),
                                  if (_isSessionsLoading ||
                                      _isProgramsLoading) ...[
                                    const SizedBox(width: 8),
                                    const SizedBox(
                                      width: 15,
                                      height: 15,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const Spacer(),
                              const Text(
                                'Program Latihan',
                                style: TextStyle(
                                  fontSize: 20,
                                  height: 1.15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 5),
                              const Text(
                                'Susun dan pantau program latihan untuk member terverifikasi.',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Color(0xFFB0ADA4),
                                  fontSize: 12,
                                  height: 1.4,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_sessionsError != null) ...[
            const SizedBox(height: 12),
            _ClientLoadNotice(
              message: _sessionsError!,
              onRetry: _loadSessions,
            ),
          ],
          if (_pendingProgramMembers == null && _isSessionsLoading) ...[
            const SizedBox(height: 18),
            const Center(child: CircularProgressIndicator()),
          ],
          if (pendingMembers.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Perlu Dibuatkan Program (${pendingMembers.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 9),
            ...pendingMembers.map(
              (session) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: EggCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          InitialAvatar(name: session.clientName, radius: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  session.clientName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  '${session.sessionCount} sesi dibayar',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          const StatusChip(
                            label: 'TERVERIFIKASI',
                            color: AppColors.accent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () async {
                            await Get.toNamed(
                              AppRoutes.trainerProgramBuilder,
                              arguments: <String, dynamic>{
                                'clientName': session.clientName,
                                'memberProfileId': session.memberProfileId,
                                'session': session,
                              },
                            );
                            _loadData();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: AppColors.background,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Buat Program',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
          ] else
            const SizedBox(height: 18),
          Row(
            children: [
              const Text(
                'PROGRAM AKTIF',
                style: TextStyle(
                  color: Color(0xFF9A9A9A),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              if (_activePrograms != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${activePrograms.length} TOTAL',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_programsError != null) ...[
            _ClientLoadNotice(
              message: _programsError!,
              onRetry: _loadPrograms,
            ),
            const SizedBox(height: 14),
          ],
          if (_activePrograms == null && _isProgramsLoading)
            const Center(child: CircularProgressIndicator())
          else if (_activePrograms != null && activePrograms.isEmpty)
            EggCard(
              child: Column(
                children: [
                  const Icon(Icons.auto_graph_rounded,
                      size: 48, color: AppColors.textSecondary),
                  const SizedBox(height: 12),
                  Text(
                    'Tidak ada program aktif.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            )
          else
            ...activePrograms.map(
              (program) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _ActiveProgramCard(
                  program: program,
                  onOpen: () => _openProgressControl(program.id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActiveProgramCard extends StatelessWidget {
  const _ActiveProgramCard({required this.program, required this.onOpen});

  final ProgramListItem program;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final progress = program.progressPercent.clamp(0, 100);
    final rawStatus = program.status.trim().toLowerCase();
    final isCompleted = progress >= 100 ||
        const {'completed', 'finished', 'archived', 'closed'}
            .contains(rawStatus);
    final statusLabel = _statusLabel(rawStatus, isCompleted: isCompleted);
    final accent = isCompleted ? const Color(0xFF77736A) : AppColors.accent;
    final primaryText = isCompleted ? const Color(0xFF9A9A9A) : Colors.white;
    final secondaryText =
        isCompleted ? const Color(0xFF77736A) : const Color(0xFF9A9A9A);

    return Semantics(
      button: true,
      label:
          '${program.title}, ${program.memberName ?? 'Member'}, progress $progress persen',
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFF161616)
                        : const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isCompleted
                          ? const Color(0xFF1E1E1E)
                          : const Color(0xFF262626),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x40000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isCompleted)
                const Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: ColoredBox(
                    color: AppColors.accent,
                    child: SizedBox(width: 3),
                  ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(isCompleted ? 16 : 18, 15, 16, 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? const Color(0xFF1C1C1C)
                                : AppColors.accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                            border: isCompleted
                                ? Border.all(color: const Color(0xFF2A2A2A))
                                : null,
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: accent,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('$progress%',
                                style: TextStyle(
                                    color: accent,
                                    fontSize: 27,
                                    height: 1,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5)),
                            const SizedBox(height: 2),
                            Text('PROGRES',
                                style: TextStyle(
                                    color: secondaryText,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.7)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      program.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 19,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(Icons.person_outline_rounded,
                            color: secondaryText, size: 14),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            program.memberName ?? 'Member',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: secondaryText,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    Wrap(
                      spacing: 12,
                      runSpacing: 7,
                      children: [
                        _ProgramMetric(
                          icon: Icons.schedule_rounded,
                          label: '${program.totalDurationMinutes} menit',
                          color: secondaryText,
                        ),
                        _ProgramMetric(
                          icon: Icons.fitness_center_rounded,
                          label: '${program.exercisesCount} latihan',
                          color: secondaryText,
                        ),
                        if (program.nextSession?.sessionDate != null)
                          _ProgramMetric(
                            icon: Icons.event_available_rounded,
                            label: AppDateFormatter.schedule(
                              dateValue: program.nextSession!.sessionDate,
                              startTime: program.nextSession!.startTime,
                              endTime: program.nextSession!.endTime,
                              abbreviatedMonth: true,
                            ),
                            color: secondaryText,
                          ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    Semantics(
                      value: '$progress%',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progress / 100,
                          minHeight: 6,
                          backgroundColor: const Color(0xFF2A2A2A),
                          valueColor: AlwaysStoppedAnimation(accent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SESI SELESAI',
                                style: TextStyle(
                                    color: secondaryText,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.7)),
                            const SizedBox(height: 5),
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${program.completedSessionsCount}',
                                    style: TextStyle(
                                      color: primaryText,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' / ${program.sessionsCount}',
                                    style: TextStyle(
                                      color: secondaryText,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: onOpen,
                          style: TextButton.styleFrom(
                            foregroundColor: isCompleted
                                ? const Color(0xFF9A9A9A)
                                : AppColors.accent,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 4),
                            minimumSize: const Size(0, 40),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Lihat Detail →',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
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
      ),
    );
  }

  String _statusLabel(String status, {required bool isCompleted}) {
    if (isCompleted) return 'SELESAI';
    return switch (status) {
      'active' || 'in_progress' || 'ongoing' => 'AKTIF',
      'draft' => 'DRAFT',
      'cancelled' || 'canceled' => 'DIBATALKAN',
      _ => status.isEmpty ? 'AKTIF' : status.replaceAll('_', ' ').toUpperCase(),
    };
  }
}

class _ProgramMetric extends StatelessWidget {
  const _ProgramMetric({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ignore: unused_element
class _TrainerProfileTab extends StatelessWidget {
  const _TrainerProfileTab({required this.name, required this.rating});

  final String name;
  final double rating;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 120),
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
              Text('Strength & hypertrophy coach • Rating $rating',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const _ProfileActionTile(
          title: 'Task Board',
          subtitle: 'Pantau progress pengerjaan fitur mobile',
          icon: Icons.dashboard_customize_outlined,
          routeName: AppRoutes.projectBoard,
        ),
        const SizedBox(height: 12),
        const _ProfileActionTile(
          title: 'Preview Member Flow',
          subtitle: 'Balik ke tampilan member untuk demo',
          icon: Icons.swap_horiz_rounded,
          routeName: AppRoutes.memberShell,
        ),
        const SizedBox(height: 12),
        const _ProfileActionTile(
          title: 'Logout',
          subtitle: 'Kembali ke halaman login',
          icon: Icons.logout_rounded,
          routeName: AppRoutes.login,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return EggCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.textSecondary,
                    letterSpacing: 0.4,
                  )),
          const SizedBox(height: 8),
          Text(value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.accent, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _CoachQuickMetric extends StatelessWidget {
  const _CoachQuickMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return EggCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.accentBronze, AppColors.surfaceSoft],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 18, color: AppColors.accent),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 0.4,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _CoachFocusTile extends StatelessWidget {
  const _CoachFocusTile({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.surfaceElevated, AppColors.surfaceSoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.accentBronze, AppColors.background],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: AppColors.accent,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
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

class _TimerModePill extends StatelessWidget {
  const _TimerModePill(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: selected ? AppColors.accent : AppColors.surfaceElevated,
      side: BorderSide(
        color: selected
            ? AppColors.accent.withValues(alpha: 0.24)
            : Colors.white.withValues(alpha: 0.08),
      ),
      labelStyle: TextStyle(
        color: selected ? AppColors.background : AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
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

class _ProfileActionTile extends StatelessWidget {
  const _ProfileActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.routeName,
    this.arguments,
    this.onReturn,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String routeName;
  final Object? arguments;
  final Future<void> Function()? onReturn;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        if (routeName == AppRoutes.login) {
          await AppSessionService.instance.clear();
          Get.offAllNamed(routeName);
          return;
        }

        final result = await Get.toNamed(routeName, arguments: arguments);
        await onReturn?.call();
        if (result == true && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Perubahan berhasil disimpan.')),
          );
        }
      },
      borderRadius: BorderRadius.circular(24),
      child: EggCard(
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.accentBronze, AppColors.surfaceSoft],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.accent),
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
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          ],
        ),
      ),
    );
  }
}

class _TrainerHomeTabV2 extends StatefulWidget {
  const _TrainerHomeTabV2({
    required this.dashboard,
    required this.trainerName,
    required this.backendService,
  });

  final TrainerDashboardData dashboard;
  final String trainerName;
  final BackendTrainerService backendService;

  @override
  State<_TrainerHomeTabV2> createState() => _TrainerHomeTabV2State();
}

class _TrainerHomeTabV2State extends State<_TrainerHomeTabV2> {
  TrainerLiveDashboardOverview? _liveDashboard;
  String? _errorMessage;
  bool _isLoading = false;

  bool get _hasLiveSync => _liveDashboard != null;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    if (!AppSessionService.instance.isTrainerAuthenticated) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Auto-retry ringan: di cold start banyak tab menembak request sekaligus,
    // sementara dev server (php artisan serve) single-thread sehingga sebagian
    // request antre & bisa timeout. Retry singkat memberi kesempatan saat
    // antrean longgar, tanpa langsung memaksa user menekan "Coba Lagi".
    const maxAttempts = 3;
    Object? lastError;
    StackTrace? lastStack;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final dashboard = await widget.backendService.getDashboard();
        if (!mounted) {
          return;
        }
        setState(() {
          _liveDashboard = dashboard;
          _errorMessage = null;
          _isLoading = false;
        });
        return; // sukses
      } catch (error, stackTrace) {
        lastError = error;
        lastStack = stackTrace;
        if (!mounted) {
          return;
        }
        // Jeda bertahap sebelum mencoba lagi (kecuali percobaan terakhir).
        if (attempt < maxAttempts) {
          await Future<void>.delayed(Duration(milliseconds: 600 * attempt));
        }
      }
    }

    if (!mounted) {
      return;
    }

    // Semua percobaan gagal. Log detail asli untuk developer; UI dapat pesan
    // ramah, bukan exception mentah (mis. TimeoutException).
    debugPrint(
        'Coach dashboard load failed after $maxAttempts attempts: $lastError');
    if (lastStack != null) {
      debugPrint(lastStack.toString());
    }
    setState(() {
      _errorMessage =
          'Gagal memuat data coach. Periksa koneksi lalu coba lagi.';
      _isLoading = false;
    });
  }

  /// Data demo hanya boleh dipakai di build non-produksi. Di produksi, coach
  /// yang login TIDAK boleh melihat data dummy (klien/sesi/rating palsu).
  bool get _allowDemoData => !kReleaseMode;

  @override
  Widget build(BuildContext context) {
    final timer = context.watch<TrainerWorkoutTimerProvider>();
    final activeClients = _liveDashboard?.activeClients ??
        (_allowDemoData ? widget.dashboard.activeClients : 0);
    final todaySessions = _liveDashboard?.todaySessions ??
        (_allowDemoData ? widget.dashboard.todaySessions : 0);
    final rating = _liveDashboard?.rating ??
        (_allowDemoData ? widget.dashboard.rating : 0.0);
    final agenda = _liveDashboard?.todayAgenda ??
        (_allowDemoData
            ? widget.dashboard.todayAgenda
            : const <ScheduleSession>[]);
    final trainerName = _liveDashboard?.trainerName.isNotEmpty == true
        ? _liveDashboard!.trainerName
        : widget.trainerName;

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _loadDashboard,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          Row(
            children: [
              const BrandLogo(compact: true),
              const Spacer(),
              IconButton(
                onPressed: () => Get.toNamed(AppRoutes.projectBoard),
                icon: const Icon(Icons.notifications_none_rounded),
              ),
              const SizedBox(width: 10),
              InitialAvatar(name: trainerName, radius: 15),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'COACH',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w400,
                ),
          ),
          Text(
            'DASHBOARD',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'Halo, $trainerName',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Siap membakar kalori hari ini?',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 18),
          EggCard(
            highlight: true,
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [AppColors.accentBronze, Color(0xFF171717)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -8,
                    top: -14,
                    child: Text(
                      'PT',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.06),
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatusChip(
                        label:
                            _hasLiveSync ? 'TRAINER BACKEND' : 'ACTIVE COACH',
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Lead your clients through every session with better clarity.',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Pantau jadwal, buka detail sesi, dan jaga kualitas coaching langsung dari mobile dashboard.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.45,
                            ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          const StatusChip(label: 'Coach Mode'),
                          if (_hasLiveSync)
                            const StatusChip(
                              label: 'Session Synced',
                              color: AppColors.textSecondary,
                            ),
                          if (_isLoading)
                            const StatusChip(
                              label: 'SYNCING',
                              color: AppColors.textSecondary,
                            ),
                        ],
                      ),
                      if (_errorMessage != null &&
                          !_hasLiveSync &&
                          !_isLoading) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.cloud_off_rounded,
                                size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: _isLoading ? null : _loadDashboard,
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.accent,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Coba Lagi'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                  child:
                      _StatCard(label: 'KLIEN AKTIF', value: '$activeClients')),
              const SizedBox(width: 10),
              Expanded(
                  child: _StatCard(
                      label: 'SESI HARI INI', value: '$todaySessions')),
              const SizedBox(width: 10),
              Expanded(
                  child: _StatCard(
                      label: 'RATING', value: rating.toStringAsFixed(1))),
            ],
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Expanded(
                child: _CoachQuickMetric(
                  label: 'CHECK-IN',
                  value: '08.00',
                  icon: Icons.alarm_on_rounded,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _CoachQuickMetric(
                  label: 'FOCUS',
                  value: 'Strength',
                  icon: Icons.fitness_center_rounded,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _CoachQuickMetric(
                  label: 'LOAD',
                  value: 'High',
                  icon: Icons.bolt_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          EggCard(
            child: Column(
              children: [
                Row(
                  children: [
                    _TimerModePill(
                      label: 'COUNTDOWN',
                      selected: timer.mode == TimerMode.countdown,
                      onTap: () => timer.toggleMode(TimerMode.countdown),
                    ),
                    const SizedBox(width: 8),
                    _TimerModePill(
                      label: 'STOPWATCH',
                      selected: timer.mode == TimerMode.stopwatch,
                      onTap: () => timer.toggleMode(TimerMode.stopwatch),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 180,
                  height: 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 180,
                        height: 180,
                        child: CircularProgressIndicator(
                          value: timer.progressValue == 0
                              ? 0.02
                              : timer.progressValue,
                          strokeWidth: 10,
                          backgroundColor: AppColors.surfaceSoft,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.accent),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            timer.displayValue,
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'HIGH INTENSITY',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _RoundAction(
                        icon: Icons.restart_alt_rounded, onTap: timer.reset),
                    const SizedBox(width: 18),
                    Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent,
                      ),
                      child: IconButton(
                        onPressed: timer.toggleRunning,
                        icon: Icon(
                          timer.isRunning
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: AppColors.background,
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    const _RoundAction(icon: Icons.stop_rounded),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          EggCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Coach Focus Today',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                const _CoachFocusTile(
                  title: 'Prioritize form review',
                  subtitle: 'Perhatikan pola gerak compound lift klien baru.',
                ),
                const SizedBox(height: 10),
                const _CoachFocusTile(
                  title: 'Update session notes',
                  subtitle:
                      'Isi feedback setelah sesi selesai untuk tracking progress.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                "Today's Sessions",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              Text(
                _hasLiveSync ? 'LIVE BACKEND' : 'LIHAT SEMUA',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...agenda.take(2).map(
                (session) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: EggCard(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            InitialAvatar(name: session.clientName, radius: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    session.clientName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    session.timeRange,
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
                            StatusChip(
                              label: session.status,
                              color: session.status == 'Menunggu'
                                  ? AppColors.textSecondary
                                  : AppColors.accent,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: EggButton.primary(
                                label: _isPendingSession(session)
                                    ? 'Konfirmasi Booking'
                                    : 'Mulai Sesi',
                                onPressed: () =>
                                    _openPrimarySessionAction(session),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: EggButton.secondary(
                                label: 'Reschedule',
                                onPressed: () => _openRescheduleFlow(session),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _ScheduleTabV2 extends StatefulWidget {
  const _ScheduleTabV2({
    required this.sessions,
    required this.backendService,
    required this.tier,
    this.onBookingConfirmed,
  });

  final List<ScheduleSession> sessions;
  final BackendTrainerService backendService;
  final String? tier;
  final VoidCallback? onBookingConfirmed;

  @override
  State<_ScheduleTabV2> createState() => _ScheduleTabV2State();
}

class _ScheduleTabV2State extends State<_ScheduleTabV2> {
  List<ScheduleSession>? _liveSessions;
  String? _errorMessage;
  bool _isLoading = false;
  late DateTime _selectedDate;
  String _requestFilter = 'Menunggu';
  late final Worker _tabWorker;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _tabWorker = ever<int>(
      Get.find<TrainerShellController>().currentIndex,
      (index) {
        if (index == 1 && !_isLoading) {
          _loadSessions();
        }
      },
    );
    _loadSessions();
  }

  @override
  void dispose() {
    _tabWorker.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    if (!AppSessionService.instance.isTrainerAuthenticated) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sessions = await widget.backendService.getScheduleSessions();
      if (!mounted) {
        return;
      }

      // Sembunyikan booking berstatus final/non-aktif dari menu Jadwal.
      // Hanya tampilkan yang masih aktif/berjalan.
      const hiddenStatuses = <String>{
        'cancelled',
      };
      final visibleSessions = sessions
          .where((s) => !hiddenStatuses.contains(s.rawStatus?.toLowerCase()))
          .toList();
      assert(() {
        debugPrint(
          'Trainer schedule sync: ${visibleSessions.length} booking(s) | '
          '${visibleSessions.map((item) => '${item.clientName}:${item.rawStatus}').join(', ')}',
        );
        return true;
      }());

      setState(() {
        _liveSessions = visibleSessions;
      });
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }

      // Log detail asli untuk developer; UI dapat pesan ramah, bukan exception mentah.
      debugPrint('Trainer schedule load failed: $error');
      debugPrint(stackTrace.toString());

      setState(() {
        _errorMessage =
            'Gagal memuat jadwal sesi. Periksa koneksi lalu coba lagi.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _confirmBooking(ScheduleSession session) async {
    setState(() => _isLoading = true);
    try {
      final backendId = session.backendId;
      if (backendId == null) {
        throw Exception('ID booking tidak ditemukan');
      }

      await widget.backendService.confirmBooking(backendId);

      if (!mounted) return;

      Get.snackbar(
        'Booking Dikonfirmasi',
        'Booking berhasil dikonfirmasi. Menunggu bukti pembayaran dari member.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
        duration: const Duration(seconds: 3),
      );

      widget.onBookingConfirmed?.call();
      await _loadSessions();
    } catch (error) {
      if (!mounted) return;
      Get.snackbar(
        'Gagal Konfirmasi',
        error.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _rejectBooking(ScheduleSession session) async {
    setState(() => _isLoading = true);
    try {
      final backendId = session.backendId;
      if (backendId == null) {
        throw Exception('ID booking tidak ditemukan');
      }

      await widget.backendService.rejectBooking(backendId);

      if (!mounted) return;

      Get.snackbar(
        'Booking Ditolak',
        'Sesi dengan ${session.clientName} telah ditolak.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );

      await _loadSessions();
    } catch (error) {
      if (!mounted) return;
      Get.snackbar(
        'Gagal Menolak',
        error.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Status mentah booking; fallback dari label bila rawStatus tidak tersedia
  /// (mis. data demo).
  String _resolveRawStatus(ScheduleSession session) {
    return TrainerSessionVisibility.rawStatus(session);
  }

  Future<void> _respondRescheduleRequest(
    BookingRescheduleRequestData request,
    String action,
  ) async {
    String? rejectionType;
    String? rejectionNote;
    if (action == 'reject') {
      final result = await _showRescheduleRejectionDialog();
      if (result == null) return;
      rejectionType = result.$1;
      rejectionNote = result.$2;
    }
    try {
      await widget.backendService.respondRescheduleRequest(
        request.id,
        action: action,
        rejectionType: rejectionType,
        rejectionNote: rejectionNote,
      );
      await _loadSessions();
    } catch (error) {
      if (!mounted) return;
      Get.snackbar(
        'Gagal Memproses Reschedule',
        error.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
    }
  }

  Future<(String, String?)?> _showRescheduleRejectionDialog() async {
    String selected = 'schedule_conflict';
    final controller = TextEditingController();
    final result = await showDialog<(String, String?)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tolak Reschedule'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selected,
                items: const [
                  DropdownMenuItem(
                      value: 'schedule_conflict',
                      child: Text('Jadwal baru bentrok')),
                  DropdownMenuItem(
                      value: 'outside_active_schedule',
                      child: Text('Di luar jadwal aktif')),
                  DropdownMenuItem(
                      value: 'operational_issue',
                      child: Text('Kendala operasional')),
                  DropdownMenuItem(value: 'other', child: Text('Lainnya')),
                ],
                onChanged: (value) =>
                    setDialogState(() => selected = value ?? selected),
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
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                final note = controller.text.trim();
                if (selected == 'other' && note.isEmpty) return;
                Navigator.pop(
                    dialogContext, (selected, note.isEmpty ? null : note));
              },
              child: const Text('Tolak'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  /// Shortcut "Mulai Sesi": pindah ke menu Program lalu buka halaman kontrol
  /// progres/centang sesi member untuk program yang bersangkutan.
  Future<void> _openMemberProgress(ScheduleSession session) async {
    final programId = session.trainingProgramId;
    if (programId == null) {
      // Fallback aman bila id program belum tersedia.
      await _openSessionDetail(session);
      return;
    }

    // Pindah ke tab Program (index 3) sebagai konteks, lalu buka halaman progres.
    Get.find<TrainerShellController>().changeTab(3);

    await Get.toNamed(
      AppRoutes.trainerProgressControl,
      arguments: <String, dynamic>{
        'trainingProgramId': programId,
        'role': 'trainer',
      },
    );
    await _loadSessions();
  }

  /// Buka detail sesi (untuk Verifikasi Pembayaran / Mulai Sesi), lalu refresh.
  Future<void> _openSessionDetail(ScheduleSession session) async {
    await Get.toNamed(
      AppRoutes.trainerSessionDetail,
      arguments: <String, dynamic>{
        'session': session,
        'memberProfileId': session.memberProfileId,
        'role': 'trainer',
      },
    );
    await _loadSessions();
  }

  /// Buka halaman Detail Booking (info lengkap member + tombol Konfirmasi/Tolak),
  /// lalu refresh daftar sesi saat kembali (mis. setelah konfirmasi/tolak).
  Future<void> _openBookingDetail(ScheduleSession session) async {
    final result = await Get.toNamed(
      AppRoutes.trainerBookingDetail,
      arguments: <String, dynamic>{
        'session': session,
        'backendService': widget.backendService,
      },
    );
    if (result == 'confirmed') {
      widget.onBookingConfirmed?.call();
    }
    await _loadSessions();
  }

  DateTime? _sessionDate(ScheduleSession session) {
    final raw = session.sessionDate ??
        (session.reservations.isEmpty
            ? null
            : session.reservations
                .map((item) => item.sessionDate)
                .where((value) => value != '-')
                .fold<String?>(
                    null,
                    (current, value) =>
                        current == null || value.compareTo(current) < 0
                            ? value
                            : current));
    return raw == null ? null : DateTime.tryParse(raw);
  }

  bool _sameDay(DateTime? a, DateTime b) =>
      a != null && a.year == b.year && a.month == b.month && a.day == b.day;

  bool _occursOnDate(ScheduleSession session, DateTime date) {
    if (session.reservations.isNotEmpty) {
      return session.reservations
          .any((item) => _sameDay(DateTime.tryParse(item.sessionDate), date));
    }
    return _sameDay(_sessionDate(session), date);
  }

  bool _isActiveScheduledSessionForDate(
    ScheduleSession session,
    DateTime date,
  ) =>
      TrainerSessionVisibility.isActiveForDate(session, date);

  String _timeForSelectedDate(ScheduleSession session) {
    for (final reservation in session.reservations) {
      if (_sameDay(DateTime.tryParse(reservation.sessionDate), _selectedDate)) {
        return '${reservation.startTime} - ${reservation.endTime}';
      }
    }
    return session.timeRange;
  }

  List<DateTime> get _visibleDates => List.generate(
        5,
        (index) => DateTime.now().add(Duration(days: index)),
      ).map((date) => DateTime(date.year, date.month, date.day)).toList();

  bool _matchesRequestFilter(ScheduleSession session) =>
      _matchesRequestFilterName(session, _requestFilter);

  bool _matchesRequestFilterName(ScheduleSession session, String filter) {
    final status = _resolveRawStatus(session);
    return switch (filter) {
      'Menunggu' => status == 'pending',
      'Dikonfirmasi' => status == 'waiting_payment' ||
          (const {
                'payment_rejected',
                'payment_uploaded',
                'payment_verified',
                'confirmed',
                'rescheduled',
              }.contains(status) &&
              !_isActiveScheduledSessionForDate(session, _selectedDate)),
      'Selesai' => status == 'completed',
      'Ditolak' => status == 'rejected',
      'Expired' => status == 'expired',
      _ => false,
    };
  }

  bool _needsTrainerAction(ScheduleSession session) {
    final status = _resolveRawStatus(session);
    if (status == 'payment_uploaded') return true;
    if (status == 'payment_verified' && !session.hasProgram) return true;

    return session.reservations.any((reservation) {
      final request = reservation.activeRescheduleRequest;
      return request != null &&
          request.status == 'pending' &&
          request.isIncoming &&
          (request.canAccept || request.canReject);
    });
  }

  int _requestActionCount(String filter, List<ScheduleSession> sessions) {
    return sessions.where((session) {
      if (!_matchesRequestFilterName(session, filter)) return false;
      return filter == 'Menunggu'
          ? _resolveRawStatus(session) == 'pending'
          : filter == 'Dikonfirmasi' && _needsTrainerAction(session);
    }).length;
  }

  String get _requestEmptyMessage => switch (_requestFilter) {
        'Menunggu' => 'Tidak ada permintaan menunggu.',
        'Dikonfirmasi' => 'Tidak ada permintaan dikonfirmasi.',
        'Selesai' => 'Tidak ada sesi selesai.',
        'Ditolak' => 'Tidak ada permintaan ditolak.',
        'Expired' => 'Tidak ada booking expired.',
        _ => 'Tidak ada data pada filter ini.',
      };

  String _requestStatusLabel(ScheduleSession session) =>
      switch (_resolveRawStatus(session)) {
        'pending' => 'MENUNGGU',
        'waiting_payment' => 'MENUNGGU BAYAR',
        'payment_rejected' => 'BUKTI DITOLAK',
        'payment_uploaded' => session.isPaymentVerificationOverdue
            ? PaymentVerificationOverdueCopy.trainerBadge
            : 'VERIFIKASI PEMBAYARAN',
        'payment_verified' => 'TERVERIFIKASI',
        'confirmed' => 'MENUNGGU BAYAR',
        'rescheduled' => 'DIJADWALKAN ULANG',
        'completed' => 'SELESAI',
        'rejected' => 'DITOLAK',
        'expired' => 'EXPIRED',
        _ => session.status.toUpperCase(),
      };

  Widget _compactActions(ScheduleSession session, {required bool requestCard}) {
    final status = _resolveRawStatus(session);
    if (status == 'pending') {
      return Row(children: [
        Expanded(
          child: _ScheduleActionButton(
            label: 'Konfirmasi',
            tone: _ScheduleActionTone.confirm,
            onPressed: () => _confirmBooking(session),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ScheduleActionButton(
            label: 'Tolak',
            tone: _ScheduleActionTone.reject,
            onPressed: () => _rejectBooking(session),
          ),
        ),
      ]);
    }
    if (requestCard) {
      return _ScheduleActionButton(
        label: status == 'payment_uploaded'
            ? 'Verifikasi Pembayaran'
            : 'Lihat Detail',
        onPressed: () => _openSessionDetail(session),
      );
    }
    if (status == 'payment_uploaded') {
      return _ScheduleActionButton(
        label: 'Verifikasi Pembayaran',
        primary: true,
        onPressed: () => _openSessionDetail(session),
      );
    }
    if (const {'waiting_payment', 'confirmed'}.contains(status)) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: const Text(
          'Menunggu bukti pembayaran dari member',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    if (status == 'payment_rejected') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: const Text(
          'Menunggu upload ulang bukti pembayaran oleh member',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    if (status == 'payment_verified' && !session.hasProgram) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: const Text(
          'Program latihan belum dibuat. Buat program terlebih dahulu sebelum sesi dimulai.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    final canStart = status == 'payment_verified' &&
        session.hasProgram &&
        !session.executionBlockedByPendingReschedule;
    final hasPending = session.reservations
        .any((item) => item.activeRescheduleRequest != null);
    final canReschedule = status == 'payment_verified' &&
        !hasPending &&
        session.reservations.any((item) => item.status == 'reserved');
    return Row(children: [
      Expanded(
        flex: 2,
        child: _ScheduleActionButton(
          label: status == 'waiting_payment' || status == 'payment_rejected'
              ? 'Menunggu Pembayaran'
              : 'Mulai Sesi',
          primary: status == 'payment_verified',
          onPressed: canStart ? () => _openMemberProgress(session) : null,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _ScheduleActionButton(
          label: 'Detail',
          onPressed: () => _openBookingDetail(session),
        ),
      ),
      if (canReschedule) ...[
        const SizedBox(width: 6),
        IconButton(
          tooltip: 'Reschedule',
          onPressed: () => _openRescheduleFlow(session),
          style: IconButton.styleFrom(
            fixedSize: const Size(44, 44),
            foregroundColor: AppColors.accent,
            side: const BorderSide(color: Color(0xFF2A2A2A)),
          ),
          icon: const Icon(Icons.event_repeat_rounded, size: 18),
        ),
      ],
    ]);
  }

  Widget? _scheduleExtra(ScheduleSession session) {
    final widgets = <Widget>[];
    if (session.expiredAt != null &&
        !session.isPaymentVerificationOverdue &&
        ['pending', 'rescheduled', 'payment_uploaded']
            .contains(_resolveRawStatus(session))) {
      widgets.add(BookingExpiryCountdown(
        expiredAt: session.expiredAt,
        label: _resolveRawStatus(session) == 'payment_uploaded'
            ? 'Sisa waktu verifikasi'
            : 'Sisa waktu konfirmasi',
        onExpired: _loadSessions,
      ));
    } else if (session.isPaymentVerificationOverdue) {
      widgets.add(const Text(
        PaymentVerificationOverdueCopy.trainerMessage,
        style: TextStyle(
          color: AppColors.accent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ));
    }
    for (final reservation in session.reservations) {
      final request = reservation.activeRescheduleRequest;
      if (request == null) continue;
      if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 8));
      widgets.add(RescheduleRequestCard(
        request: request,
        onAccept: () => _respondRescheduleRequest(request, 'accept'),
        onReject: () => _respondRescheduleRequest(request, 'reject'),
        onCancel: () => _respondRescheduleRequest(request, 'cancel'),
        onExpired: _loadSessions,
      ));
    }
    return widgets.isEmpty
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: widgets,
          );
  }

  @override
  Widget build(BuildContext context) {
    final sessionTrainerName =
        AppSessionService.instance.currentSession?.name?.trim();
    final trainerName = sessionTrainerName?.isNotEmpty == true
        ? sessionTrainerName!
        : 'Trainer';
    final sessions = _liveSessions ?? const <ScheduleSession>[];
    final scheduledSessions = sessions
        .where(
          (session) =>
              _occursOnDate(session, _selectedDate) &&
              _isActiveScheduledSessionForDate(session, _selectedDate),
        )
        .toList();
    final filteredRequests = sessions.where(_matchesRequestFilter).toList();
    final pendingActionCount = _requestActionCount('Menunggu', sessions);
    final confirmedActionCount = _requestActionCount('Dikonfirmasi', sessions);
    assert(() {
      debugPrint(
        'Trainer request filter $_requestFilter: ${filteredRequests.length} item(s)',
      );
      return true;
    }());
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _loadSessions,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 92),
        children: [
          Row(
            children: [
              Semantics(
                button: true,
                label: 'Buka Profil Trainer',
                child: InkWell(
                  onTap: () => Get.find<TrainerShellController>().changeTab(4),
                  customBorder: const CircleBorder(),
                  child: InitialAvatar(
                    name: trainerName,
                    avatarPath:
                        AppSessionService.instance.currentSession?.avatarUrl,
                    radius: 17,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trainerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(trainerRoleLabel(widget.tier),
                        style: const TextStyle(
                            color: Color(0xFF9A9A9A),
                            fontSize: 7,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4)),
                  ],
                ),
              ),
              Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1C),
                      borderRadius: BorderRadius.circular(11)),
                  child: const NotificationBellButton(
                      color: AppColors.accent,
                      icon: Icons.notifications_rounded)),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Jadwal Sesi',
              style: TextStyle(
                  fontSize: 21,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3)),
          const SizedBox(height: 3),
          const Text('MANAJEMEN PELATIHAN PERSONAL',
              style: TextStyle(
                  color: Color(0xFF9A9A9A),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1)),
          const SizedBox(height: 12),
          Row(
            children: _visibleDates.asMap().entries.expand((entry) {
              final date = entry.value;
              return [
                Expanded(
                  child: _ScheduleDateTile(
                    date: date,
                    selected: _sameDay(date, _selectedDate),
                    onTap: () => setState(() => _selectedDate = date),
                  ),
                ),
                if (entry.key < _visibleDates.length - 1)
                  const SizedBox(width: 7),
              ];
            }).toList(),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            _ScheduleLoadNotice(
              message: _errorMessage!,
              onRetry: _isLoading ? null : _loadSessions,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Sesi Hari Ini',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text(
                '${scheduledSessions.length} TERJADWAL',
                style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_isLoading && _liveSessions == null)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: AppColors.accent)))
          else if (scheduledSessions.isEmpty)
            const _ScheduleEmptyState(
                message: 'Tidak ada sesi pada tanggal ini.')
          else
            ...scheduledSessions.map((session) => Padding(
                  key: ValueKey('scheduled-${session.backendId}'),
                  padding: const EdgeInsets.only(bottom: 7),
                  child: _ScheduleSessionCard(
                    session: session,
                    timeLabel: _timeForSelectedDate(session),
                    status: _requestStatusLabel(session),
                    extra: _scheduleExtra(session),
                    child: _compactActions(session, requestCard: false),
                  ),
                )),
          const SizedBox(height: 9),
          const Text('Permintaan Booking',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                'Menunggu',
                'Dikonfirmasi',
                'Selesai',
                'Ditolak',
                'Expired',
              ]
                  .map((filter) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: _ScheduleFilterLabel(
                            label: filter,
                            count: switch (filter) {
                              'Menunggu' => pendingActionCount,
                              'Dikonfirmasi' => confirmedActionCount,
                              _ => 0,
                            },
                          ),
                          selected: _requestFilter == filter,
                          onSelected: (_) =>
                              setState(() => _requestFilter = filter),
                          selectedColor: AppColors.accent,
                          backgroundColor: const Color(0xFF1C1C1C),
                          side: const BorderSide(color: Color(0xFF2A2A2A)),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: const VisualDensity(
                            horizontal: -3,
                            vertical: -4,
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          labelStyle: TextStyle(
                            color: _requestFilter == filter
                                ? AppColors.background
                                : const Color(0xFF9A9A9A),
                            fontWeight: FontWeight.w700,
                            fontSize: 10.5,
                          ),
                          showCheckmark: false,
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 6),
          if (_isLoading && _liveSessions == null)
            const _ScheduleInlineLoading()
          else if (filteredRequests.isEmpty)
            _ScheduleInlineEmpty(message: _requestEmptyMessage)
          else
            ...filteredRequests.map((session) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: _ScheduleSessionCard(
                    session: session,
                    timeLabel: session.timeRange,
                    requestCard: true,
                    onInfoTap: _resolveRawStatus(session) == 'pending'
                        ? () => _openBookingDetail(session)
                        : null,
                    status: _requestStatusLabel(session),
                    extra: _scheduleExtra(session),
                    child: _compactActions(session, requestCard: true),
                  ),
                )),
        ],
      ),
    );
  }
}

class _ScheduleFilterLabel extends StatelessWidget {
  const _ScheduleFilterLabel({
    required this.label,
    required this.count,
  });

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        if (count > 0) ...[
          const SizedBox(width: 5),
          Transform.translate(
            offset: const Offset(0, -4),
            child: Container(
              key: ValueKey('schedule-filter-badge-$label'),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: Colors.black, width: 1.25),
              ),
              alignment: Alignment.center,
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ScheduleDateTile extends StatelessWidget {
  const _ScheduleDateTile({
    required this.date,
    required this.selected,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const days = ['SEN', 'SEL', 'RAB', 'KAM', 'JUM', 'SAB', 'MIN'];
    return Semantics(
      selected: selected,
      button: true,
      label: '${days[date.weekday - 1]} ${date.day}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 53,
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.accent : const Color(0xFF262626),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.24),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(days[date.weekday - 1],
                  style: TextStyle(
                    color: selected
                        ? AppColors.background.withValues(alpha: 0.7)
                        : const Color(0xFF6B6B6B),
                    fontSize: 7.5,
                    fontWeight: FontWeight.w700,
                  )),
              const SizedBox(height: 2),
              Text('${date.day}',
                  style: TextStyle(
                    color: selected ? AppColors.background : Colors.white,
                    fontSize: 15,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ScheduleActionTone { neutral, confirm, reject }

class _ScheduleActionButton extends StatelessWidget {
  const _ScheduleActionButton({
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.tone = _ScheduleActionTone.neutral,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final _ScheduleActionTone tone;

  @override
  Widget build(BuildContext context) {
    final foreground = primary
        ? AppColors.background
        : tone == _ScheduleActionTone.confirm
            ? AppColors.accent
            : tone == _ScheduleActionTone.reject
                ? const Color(0xFFE0524D)
                : Colors.white;
    final background = primary
        ? AppColors.accent
        : tone == _ScheduleActionTone.confirm
            ? AppColors.accent.withValues(alpha: 0.15)
            : tone == _ScheduleActionTone.reject
                ? const Color(0xFFE0524D).withValues(alpha: 0.12)
                : const Color(0xFF1C1C1C);
    return SizedBox(
      height: 38,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledForegroundColor: const Color(0xFF6B6B6B),
          side: BorderSide(
            color: primary
                ? AppColors.accent
                : tone == _ScheduleActionTone.confirm
                    ? AppColors.accent.withValues(alpha: 0.18)
                    : tone == _ScheduleActionTone.reject
                        ? const Color(0xFFE0524D).withValues(alpha: 0.18)
                        : const Color(0xFF2A2A2A),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _ScheduleSessionCard extends StatelessWidget {
  const _ScheduleSessionCard({
    required this.session,
    required this.timeLabel,
    required this.child,
    this.status,
    this.extra,
    this.requestCard = false,
    this.onInfoTap,
  });

  final ScheduleSession session;
  final String timeLabel;
  final Widget child;
  final String? status;
  final Widget? extra;
  final bool requestCard;
  final VoidCallback? onInfoTap;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: requestCard
                      ? const Color(0xFF161616)
                      : const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF262626)),
                ),
              ),
            ),
            if (requestCard)
              const Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: ColoredBox(
                  color: AppColors.accent,
                  child: SizedBox(width: 3),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                requestCard ? 13 : 10,
                10,
                10,
                10,
              ),
              child: Column(
                children: [
                  InkWell(
                    key: onInfoTap == null
                        ? null
                        : ValueKey('pending-info-${session.backendId}'),
                    onTap: onInfoTap,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          InitialAvatar(
                            name: session.clientName,
                            avatarPath: session.memberAvatarUrl,
                            radius: 17,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(session.clientName,
                                    style: TextStyle(
                                        fontSize: requestCard ? 12.5 : 13.5,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 1),
                                Row(
                                  children: [
                                    const Icon(Icons.schedule_rounded,
                                        size: 13, color: AppColors.accent),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(timeLabel,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: const Color(0xFF9A9A9A),
                                            fontSize: requestCard ? 9.5 : 10.5,
                                          )),
                                    ),
                                  ],
                                ),
                                if ((session.sessionTitle?.trim().isNotEmpty ??
                                        false) ||
                                    (session.memberNote?.trim().isNotEmpty ??
                                        false)) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    (session.sessionTitle?.trim().isNotEmpty ??
                                            false)
                                        ? session.sessionTitle!.trim()
                                        : session.memberNote!.trim(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF7E7E7E),
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (status != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(status!,
                                  style: const TextStyle(
                                      color: AppColors.accent,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w700)),
                            ),
                          if (onInfoTap != null) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.accent,
                              size: 20,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (extra != null) ...[
                    const SizedBox(height: 7),
                    extra!,
                  ],
                  const SizedBox(height: 8),
                  child,
                ],
              ),
            ),
          ],
        ),
      );
}

class _ScheduleLoadNotice extends StatelessWidget {
  const _ScheduleLoadNotice({required this.message, required this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Row(children: [
          const Icon(Icons.cloud_off_rounded,
              size: 16, color: Color(0xFF9A9A9A)),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 11))),
          TextButton(onPressed: onRetry, child: const Text('Coba Lagi')),
        ]),
      );
}

class _ScheduleEmptyState extends StatelessWidget {
  const _ScheduleEmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Row(children: [
          const Icon(Icons.event_busy_rounded,
              color: AppColors.accent, size: 19),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style:
                      const TextStyle(color: Color(0xFF9A9A9A), fontSize: 11))),
        ]),
      );
}

class _ScheduleInlineEmpty extends StatelessWidget {
  const _ScheduleInlineEmpty({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            const Icon(Icons.inbox_outlined,
                color: Color(0xFF6B6B6B), size: 17),
            const SizedBox(width: 7),
            Text(
              message,
              style: const TextStyle(
                color: Color(0xFF8A8A8A),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}

class _ScheduleInlineLoading extends StatelessWidget {
  const _ScheduleInlineLoading();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Memuat permintaan booking...',
              style: TextStyle(
                color: Color(0xFF8A8A8A),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}

class _TrainerProfileTabV2 extends StatefulWidget {
  const _TrainerProfileTabV2({
    required this.name,
    required this.email,
    required this.activeClients,
    required this.tier,
    required this.backendService,
    this.onAvatarChanged,
  });

  final String name;
  final String? email;
  final int activeClients;
  final String? tier;
  final BackendTrainerService backendService;
  // Dipanggil setelah avatar berubah (upload/hapus) -> shell setState agar
  // header trainer ikut update (1 sumber: session.avatarUrl).
  final VoidCallback? onAvatarChanged;

  @override
  State<_TrainerProfileTabV2> createState() => _TrainerProfileTabV2State();
}

class _TrainerProfileTabV2State extends State<_TrainerProfileTabV2> {
  final BackendTrainerProfileService _profileService =
      BackendTrainerProfileService();
  TrainerSchedule? _schedule;
  TrainerProfileData? _profile;
  String? _scheduleError;
  bool _isScheduleLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _profileService.getProfile();
      if (mounted) setState(() => _profile = profile);
    } catch (error) {
      debugPrint('Trainer profile presentation load failed: $error');
    }
  }

  Future<void> _loadSchedule() async {
    setState(() {
      _isScheduleLoading = true;
      _scheduleError = null;
    });
    try {
      final schedule = await widget.backendService.getTrainerSchedule();
      if (!mounted) return;
      setState(() {
        _schedule = schedule;
        _isScheduleLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _scheduleError = error.toString();
        _isScheduleLoading = false;
      });
    }
  }

  Future<void> _openScheduleEditor() async {
    final result = await Get.toNamed(
      AppRoutes.trainerSchedule,
      arguments: widget.backendService,
    );
    if (!mounted) return;
    if (result is TrainerSchedule) {
      setState(() {
        _schedule = result;
        _scheduleError = null;
        _isScheduleLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _profile?.name ?? widget.name;
    final displayEmail = _profile?.email ?? widget.email;
    final rating = _profile?.rating;
    final specialties = _profile?.specialtyLabels.isNotEmpty == true
        ? _profile!.specialtyLabels
        : _splitSpecialties(_profile?.specialtyLabel ?? _profile?.specialty);
    final bio = _profile?.bio?.trim();
    final profileTier = _profile?.tier;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 108),
      children: [
        Row(
          children: [
            const Spacer(),
            const NotificationBellButton(color: AppColors.accent),
          ],
        ),
        const SizedBox(height: 14),
        Center(
          child: Column(
            children: [
              ProfileAvatarEditor(
                displayName: displayName,
                avatarPath:
                    AppSessionService.instance.currentSession?.avatarUrl,
                onAvatarChanged: widget.onAvatarChanged,
              ),
              const SizedBox(height: 12),
              Text(
                displayName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                displayEmail?.trim().isNotEmpty == true
                    ? displayEmail!.trim()
                    : 'Email belum tersedia',
                style: const TextStyle(
                  color: Color(0xFFB8AD91),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                trainerRoleLabel(profileTier),
                key: const Key('trainer-profile-tier'),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(child: _TrainerProfileStatCard.rating(rating: rating)),
            const SizedBox(width: 12),
            Expanded(
              child: _TrainerProfileStatCard.clients(
                activeClients: widget.activeClients,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _TrainerProfileSectionCard(
          title: 'SPESIALISASI',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (specialties.isEmpty)
                const Text('Spesialisasi belum diisi.',
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 13))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: specialties
                      .map((specialty) => _TrainerSpecialtyChip(specialty))
                      .toList(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _TrainerProfileSectionCard(
          title: 'BIO',
          child: Text(
            bio?.isNotEmpty == true ? bio! : 'Bio trainer belum diisi.',
            style: const TextStyle(
              color: Color(0xFFC7BDA5),
              fontSize: 13,
              height: 1.55,
            ),
          ),
        ),
        const SizedBox(height: 14),
        _buildScheduleCard(context),
        const SizedBox(height: 14),
        _ProfileActionTile(
          title: 'Pengaturan Akun',
          subtitle: 'Kelola preferensi dan informasi akun',
          icon: Icons.settings_outlined,
          routeName: AppRoutes.trainerAccountSettings,
          onReturn: _loadProfile,
        ),
        const SizedBox(height: 12),
        const _ProfileActionTile(
          title: 'Bantuan & Panduan',
          subtitle: 'Panduan booking, pembayaran, dan Program PT',
          icon: Icons.help_outline_rounded,
          routeName: AppRoutes.helpCenter,
          arguments: {'role': 'trainer'},
        ),
        const SizedBox(height: 12),
        const _ProfileActionTile(
          title: 'Logout',
          subtitle: 'Kembali ke halaman login',
          icon: Icons.logout_rounded,
          routeName: AppRoutes.login,
        ),
      ],
    );
  }

  List<String> _splitSpecialties(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    return raw
        .split(RegExp(r'\s*(?:,|\||/|\s+-\s+)\s*'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  Widget _buildScheduleCard(BuildContext context) {
    final schedule = _schedule;
    final activeDays = schedule?.days.where((day) => day.enabled).toList() ??
        const <TrainerScheduleDay>[];

    return EggCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Jadwal Aktif',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _openScheduleEditor,
                child: const Text(
                  'Ubah',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (_isScheduleLoading) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(),
            const SizedBox(height: 10),
            Text(
              'Memuat jadwal aktif...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ] else if (_scheduleError != null) ...[
            const SizedBox(height: 8),
            Text(
              _scheduleError!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.error,
                  ),
            ),
            TextButton.icon(
              onPressed: _loadSchedule,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi'),
            ),
          ] else if (schedule != null) ...[
            Text(
              activeDays.isEmpty
                  ? 'Belum ada hari aktif'
                  : '${activeDays.length} hari aktif | ${schedule.timezone}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: schedule.days
                  .map(
                    (day) => _DayDot(
                      label: _scheduleDayLabel(day.dayOfWeek),
                      active: day.enabled,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  static String _scheduleDayLabel(int dayOfWeek) => const <String>[
        'SEN',
        'SEL',
        'RAB',
        'KAM',
        'JUM',
        'SAB',
        'MIN'
      ][dayOfWeek - 1];
}

class _TrainerProfileStatCard extends StatelessWidget {
  const _TrainerProfileStatCard._({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  factory _TrainerProfileStatCard.rating({required double? rating}) =>
      _TrainerProfileStatCard._(
        icon: Icons.star_rounded,
        iconColor: AppColors.accent,
        label: 'RATING',
        value: trainerOwnProfileRatingDisplay(rating),
      );

  factory _TrainerProfileStatCard.clients({required int activeClients}) =>
      _TrainerProfileStatCard._(
        icon: Icons.group_outlined,
        iconColor: const Color(0xFF16D9E3),
        label: 'KLIEN',
        value: '$activeClients',
      );

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        height: 118,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
        decoration: BoxDecoration(
          color: const Color(0xFF292929),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFF303030)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 22),
                const Spacer(),
                Text(label,
                    style: const TextStyle(
                      color: Color(0xFF8F8878),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.7,
                    )),
              ],
            ),
            const Spacer(),
            Text(value,
                style: TextStyle(
                  color: iconColor == AppColors.accent
                      ? AppColors.accent
                      : Colors.white,
                  fontSize: 28,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                )),
            const SizedBox(height: 5),
          ],
        ),
      );
}

@visibleForTesting
String activeTrainerProfileRatingDisplay(double? realProfileRating) =>
    trainerOwnProfileRatingDisplay(realProfileRating);

class _TrainerProfileSectionCard extends StatelessWidget {
  const _TrainerProfileSectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF202020)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                  color: Color(0xFF958D79),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                )),
            const SizedBox(height: 13),
            child,
          ],
        ),
      );
}

class _TrainerSpecialtyChip extends StatelessWidget {
  const _TrainerSpecialtyChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFF313131),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            )),
      );
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.label,
    required this.active,
  });

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? AppColors.accent : AppColors.surfaceSoft,
          ),
        ),
      ],
    );
  }
}
