import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/app/routes/app_routes.dart';
import 'package:egg_gym/core/utils/trainer_session_visibility.dart';
import 'package:egg_gym/core/utils/trainer_tier.dart';
import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:egg_gym/data/services/backend_trainer_service.dart';
import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:egg_gym/presentation/providers/workout_timer_provider.dart';
import 'package:egg_gym/presentation/controllers/trainer_shell_controller.dart';
import 'package:egg_gym/presentation/pages/trainer/trainer_countdown_duration_sheet.dart';
import 'package:egg_gym/presentation/widgets/common/initial_avatar.dart';
import 'package:egg_gym/presentation/widgets/common/notification_bell_button.dart';
import 'package:egg_gym/presentation/widgets/common/booking_expiry_countdown.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class _HomeDensity {
  const _HomeDensity(this.scale, this.horizontalPadding);

  factory _HomeDensity.from(Size size) {
    final widthScale = (size.width / 430).clamp(0.88, 1.0);
    final heightScale = (size.height / 900).clamp(0.90, 1.0);
    final scale = (widthScale * heightScale).clamp(0.82, 0.98);
    final horizontalPadding = (size.width * 0.045).clamp(16.0, 20.0);
    return _HomeDensity(scale, horizontalPadding);
  }

  final double scale;
  final double horizontalPadding;

  double space(double value) => value * scale;
  double font(double value) => value * scale.clamp(0.90, 1.0);
}

class TrainerHomeDashboard extends StatefulWidget {
  const TrainerHomeDashboard({
    super.key,
    required this.trainerName,
    required this.tier,
    required this.backendService,
    required this.onSeeAllSessions,
    this.onBookingConfirmed,
  });

  final String trainerName;
  final String? tier;
  final BackendTrainerService backendService;
  final VoidCallback onSeeAllSessions;
  final VoidCallback? onBookingConfirmed;

  @override
  State<TrainerHomeDashboard> createState() => _TrainerHomeDashboardState();
}

class _TrainerHomeDashboardState extends State<TrainerHomeDashboard> {
  final ScrollController _scrollController = ScrollController();
  TrainerLiveDashboardOverview? _dashboard;
  List<ScheduleSession>? _todayAgenda;
  ScheduleSession? _pendingRequest;
  List<ScheduleSession> _paymentVerificationRequests = const [];
  String? _error;
  bool _loading = false;
  late final Worker _homeTabWorker;

  @override
  void initState() {
    super.initState();
    _homeTabWorker = ever<int>(
      Get.find<TrainerShellController>().currentIndex,
      (index) {
        if (index == 0 && !_loading) _load();
      },
    );
    _load();
  }

  @override
  void dispose() {
    _homeTabWorker.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _forceAgendaViewportRepaint() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_scrollController.hasClients) return;
      final current = _scrollController.offset;
      final max = _scrollController.position.maxScrollExtent;
      final nudge = (current + 1).clamp(0.0, max);
      if (nudge == current) return;
      _scrollController.jumpTo(nudge);
      await Future<void>.delayed(Duration.zero);
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(current.clamp(
          _scrollController.position.minScrollExtent,
          _scrollController.position.maxScrollExtent,
        ));
      }
    });
  }

  Future<void> _load() async {
    if (!AppSessionService.instance.isTrainerAuthenticated) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    Object? dashboardError;
    Object? agendaError;
    try {
      final dashboard = await widget.backendService.getDashboard();
      if (mounted) {
        setState(() {
          _dashboard = dashboard;
          _paymentVerificationRequests = dashboard.paymentVerificationRequests;
        });
      }
    } catch (error) {
      dashboardError = error;
      debugPrint('Trainer home overview load failed: $error');
    }
    try {
      final sessions = await widget.backendService.getScheduleSessions();
      ScheduleSession? pendingRequest;
      final paymentVerificationRequests = <ScheduleSession>[];
      for (final session in sessions) {
        final status = TrainerSessionVisibility.rawStatus(session);
        if (status == 'pending' && pendingRequest == null) {
          pendingRequest = session;
        } else if (status == 'payment_uploaded') {
          paymentVerificationRequests.add(session);
        }
      }
      final today = TrainerSessionVisibility.jakartaToday;
      final agenda = sessions
          .where(
            (session) =>
                TrainerSessionVisibility.isActiveForDate(session, today),
          )
          .toList()
        ..sort(
          (a, b) => TrainerSessionVisibility.timeForDate(a, today)
              .compareTo(TrainerSessionVisibility.timeForDate(b, today)),
        );
      if (mounted) {
        setState(() {
          _todayAgenda = agenda;
          _pendingRequest = pendingRequest;
          _paymentVerificationRequests = paymentVerificationRequests;
        });
        _forceAgendaViewportRepaint();
      }
      assert(() {
        debugPrint(
          'Trainer Home agenda: ${agenda.length} item(s) | '
          '${agenda.map((session) => '${session.clientName}:'
              '${TrainerSessionVisibility.rawStatus(session)}:'
              '${TrainerSessionVisibility.timeForDate(session, today)}').join(', ')}',
        );
        return true;
      }());
    } catch (error) {
      agendaError = error;
      debugPrint('Trainer home agenda load failed: $error');
    }
    if (!mounted) return;
    setState(() {
      if (dashboardError != null && agendaError != null) {
        _error = 'Data dashboard belum dapat dimuat. Tarik untuk mencoba lagi.';
      } else if (agendaError != null) {
        _error = 'Agenda sesi belum dapat dimuat. Tarik untuk mencoba lagi.';
      } else if (dashboardError != null) {
        _error = 'Statistik coach belum dapat dimuat. Agenda tetap diperbarui.';
      }
      _loading = false;
    });
  }

  Future<void> _settings(TrainerWorkoutTimerProvider timer) async {
    final minutes = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => TrainerCountdownDurationSheet(
        presets: timer.presets,
        selectedMinutes: timer.selectedPresetMinutes,
      ),
    );
    if (minutes != null && mounted) timer.selectPreset(minutes);
  }

  Future<void> _openSchedule() async {
    await Get.toNamed(
      AppRoutes.trainerSchedule,
      arguments: widget.backendService,
    );
    if (mounted) await _load();
  }

  Future<void> _openPendingDetail() async {
    final pending = _pendingRequest;
    if (pending == null) return;
    final result = await Get.toNamed(
      AppRoutes.trainerBookingDetail,
      arguments: <String, dynamic>{
        'session': pending,
        'backendService': widget.backendService,
      },
    );
    if (result == 'confirmed') widget.onBookingConfirmed?.call();
    if (mounted) await _load();
  }

  Future<void> _openPaymentVerification(ScheduleSession session) async {
    await Get.toNamed(
      AppRoutes.trainerSessionDetail,
      arguments: <String, dynamic>{
        'session': session,
        'memberProfileId': session.memberProfileId,
        'role': 'trainer',
      },
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final timer = context.watch<TrainerWorkoutTimerProvider>();
    final density = _HomeDensity.from(MediaQuery.sizeOf(context));
    final dashboard = _dashboard;
    final name = dashboard?.trainerName.trim().isNotEmpty == true
        ? dashboard!.trainerName.trim()
        : widget.trainerName;
    final tier = dashboard?.tier ?? widget.tier;
    final coachName = name.replaceFirst(
      RegExp(r'^coach\s+', caseSensitive: false),
      '',
    );
    final agenda = _todayAgenda ?? const <ScheduleSession>[];

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _load,
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          density.horizontalPadding,
          density.space(12),
          density.horizontalPadding,
          density.space(84),
        ),
        children: [
          _Header(name: name, tier: tier, density: density),
          SizedBox(height: density.space(16)),
          Text('Halo, Coach $coachName 👋',
              style: TextStyle(
                  fontSize: density.font(20),
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3)),
          SizedBox(height: density.space(2)),
          Text('Siap membakar kalori hari ini?',
              style: TextStyle(
                  color: const Color(0xFF9A9A9A),
                  fontSize: density.font(12),
                  height: 1.35)),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ErrorNotice(message: _error!, onRetry: _load),
          ],
          if (dashboard != null && !dashboard.hasActiveSchedule) ...[
            SizedBox(height: density.space(12)),
            _ScheduleWarning(onConfigure: _openSchedule, density: density),
          ],
          SizedBox(height: density.space(18)),
          LayoutBuilder(builder: (context, constraints) {
            final gap = density.space(10);
            final cardWidth = (constraints.maxWidth - (gap * 2)) / 3;
            final normalHeight = (cardWidth * 0.70).clamp(70.0, 82.0);
            final middleHeight = (cardWidth * 0.79).clamp(80.0, 92.0);
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: _Stat(
                      label: 'KLIEN AKTIF',
                      value: '${dashboard?.activeClients ?? 0}',
                      icon: Icons.groups_rounded,
                      height: normalHeight,
                      density: density)),
              SizedBox(width: gap),
              Expanded(
                  child: _Stat(
                      label: 'SESI HARI INI',
                      value: '${dashboard?.todaySessions ?? agenda.length}',
                      icon: Icons.calendar_today_rounded,
                      height: middleHeight,
                      density: density)),
              SizedBox(width: gap),
              Expanded(
                  child: _Stat(
                      label: 'RATING',
                      value: dashboard == null || dashboard.rating <= 0
                          ? '-'
                          : dashboard.rating.toStringAsFixed(1),
                      icon: Icons.star_rounded,
                      height: normalHeight,
                      density: density)),
            ]);
          }),
          SizedBox(height: density.space(18)),
          _TimerPanel(
              timer: timer,
              onSettings: () => _settings(timer),
              density: density),
          SizedBox(height: density.space(16)),
          if (_pendingRequest != null) ...[
            Row(
              children: [
                Text(
                  'Permintaan Booking',
                  style: TextStyle(
                    fontSize: density.font(17),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  'MENUNGGU',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: density.font(9),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
            SizedBox(height: density.space(6)),
            _PendingRequestCard(
              key: const Key('trainer-home-pending-request'),
              session: _pendingRequest!,
              density: density,
              onTap: _openPendingDetail,
            ),
            SizedBox(height: density.space(4)),
          ],
          if (_paymentVerificationRequests.isNotEmpty) ...[
            SizedBox(height: density.space(12)),
            Row(
              children: [
                Text(
                  'Verifikasi Pembayaran',
                  style: TextStyle(
                    fontSize: density.font(17),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_paymentVerificationRequests.length} MENUNGGU',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: density.font(9),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
            SizedBox(height: density.space(6)),
            ..._paymentVerificationRequests.map(
              (session) => Padding(
                padding: EdgeInsets.only(bottom: density.space(8)),
                child: _PaymentVerificationCard(
                  key: ValueKey(
                    'trainer-home-payment-verification-${session.backendId}',
                  ),
                  session: session,
                  density: density,
                  onTap: () => _openPaymentVerification(session),
                  onExpired: _load,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PendingRequestCard extends StatelessWidget {
  const _PendingRequestCard({
    super.key,
    required this.session,
    required this.density,
    required this.onTap,
  });

  final ScheduleSession session;
  final _HomeDensity density;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(density.space(12)),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                InitialAvatar(
                  name: session.clientName,
                  avatarPath: session.memberAvatarUrl,
                  radius: density.space(18),
                ),
                SizedBox(width: density.space(10)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.clientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: density.font(13),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: density.space(2)),
                      Text(
                        session.timeRange == '-'
                            ? 'Jadwal belum tersedia'
                            : session.timeRange,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFF9A9A9A),
                          fontSize: density.font(10),
                        ),
                      ),
                      if (session.sessionTitle?.trim().isNotEmpty == true) ...[
                        SizedBox(height: density.space(2)),
                        Text(
                          session.sessionTitle!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFFB8B8B8),
                            fontSize: density.font(9.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Lihat Detail',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.accent,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      );
}

class _PaymentVerificationCard extends StatelessWidget {
  const _PaymentVerificationCard({
    super.key,
    required this.session,
    required this.density,
    required this.onTap,
    required this.onExpired,
  });

  final ScheduleSession session;
  final _HomeDensity density;
  final VoidCallback onTap;
  final VoidCallback onExpired;

  @override
  Widget build(BuildContext context) {
    final overdue = session.isPaymentVerificationOverdue;
    final focus = session.sessionTitle?.trim().isNotEmpty == true
        ? session.sessionTitle!.trim()
        : session.memberNote?.trim();
    return Material(
      color: const Color(0xFF161616),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(density.space(12)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: overdue
                  ? AppColors.error.withValues(alpha: 0.65)
                  : AppColors.accent.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InitialAvatar(
                    name: session.clientName,
                    avatarPath: session.memberAvatarUrl,
                    radius: density.space(18),
                  ),
                  SizedBox(width: density.space(10)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.clientName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: density.font(13),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: density.space(2)),
                        Text(
                          session.timeRange == '-'
                              ? 'Jadwal belum tersedia'
                              : session.timeRange,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFF9A9A9A),
                            fontSize: density.font(10),
                          ),
                        ),
                        if (focus?.isNotEmpty == true) ...[
                          SizedBox(height: density.space(2)),
                          Text(
                            focus!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: const Color(0xFFB8B8B8),
                              fontSize: density.font(9.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    overdue ? 'VERIFIKASI TERLAMBAT' : 'LIHAT BUKTI',
                    style: TextStyle(
                      color: overdue ? AppColors.error : AppColors.accent,
                      fontSize: density.font(8.5),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: overdue ? AppColors.error : AppColors.accent,
                    size: 20,
                  ),
                ],
              ),
              SizedBox(height: density.space(8)),
              if (overdue)
                Text(
                  'Menunggu Verifikasi Pembayaran · SLA terlewati',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: density.font(10),
                    fontWeight: FontWeight.w700,
                  ),
                )
              else if (session.expiredAt != null)
                BookingExpiryCountdown(
                  expiredAt: session.expiredAt,
                  label: 'Sisa waktu verifikasi',
                  onExpired: onExpired,
                )
              else
                Text(
                  'Menunggu Verifikasi Pembayaran',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: density.font(10),
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleWarning extends StatelessWidget {
  const _ScheduleWarning({
    required this.onConfigure,
    required this.density,
  });

  final VoidCallback onConfigure;
  final _HomeDensity density;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(density.space(16)),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_busy_rounded, color: AppColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Anda belum mengatur jadwal',
                  style: TextStyle(
                    fontSize: density.font(15),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: density.space(8)),
          Text(
            'Atur jadwal terlebih dahulu agar profil Anda dapat ditampilkan kepada Member pada halaman booking.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: density.font(12),
              height: 1.45,
            ),
          ),
          SizedBox(height: density.space(12)),
          FilledButton(
            onPressed: onConfigure,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: const Color(0xFF0E0E0E),
            ),
            child: const Text('Atur Jadwal'),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(
      {required this.name, required this.tier, required this.density});
  final String name;
  final String? tier;
  final _HomeDensity density;

  @override
  Widget build(BuildContext context) => Row(children: [
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
                radius: density.space(17).clamp(15.0, 17.0)),
          ),
        ),
        SizedBox(width: density.space(9)),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name.trim().isEmpty ? 'Trainer' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: AppColors.accent,
                    fontSize: density.font(14),
                    fontWeight: FontWeight.w800)),
            Text(trainerRoleLabel(tier),
                style: TextStyle(
                    color: const Color(0xFF9A9A9A),
                    fontSize: density.font(9),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5)),
          ]),
        ),
        Container(
          width: density.space(36).clamp(32.0, 36.0),
          height: density.space(36).clamp(32.0, 36.0),
          decoration: BoxDecoration(
              color: const Color(0xFF1C1C1C),
              borderRadius: BorderRadius.circular(12)),
          child: const NotificationBellButton(
              color: AppColors.accent, icon: Icons.notifications_rounded),
        ),
      ]);
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.icon,
    required this.height,
    required this.density,
  });
  final String label;
  final String value;
  final IconData icon;
  final double height;
  final _HomeDensity density;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        clipBehavior: Clip.antiAlias,
        padding: EdgeInsets.fromLTRB(
          density.space(9),
          density.space(7),
          density.space(8),
          density.space(6),
        ),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF262626))),
        child: Stack(children: [
          Positioned(
            right: -density.space(12),
            bottom: -density.space(14),
            child: IgnorePointer(
              child: Icon(
                icon,
                size: density.space(58).clamp(48.0, 58.0),
                color: AppColors.accent.withValues(alpha: 0.10),
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                      height: density.space(21),
                      child: Text(label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: const Color(0xFF9A9A9A),
                              fontSize: density.font(10),
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4))),
                  SizedBox(height: density.space(1)),
                  Text(value,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.accent,
                          fontSize: density.font(34),
                          height: 0.9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1)),
                ]),
          ),
        ]),
      );
}

class _TimerPanel extends StatelessWidget {
  const _TimerPanel(
      {required this.timer, required this.onSettings, required this.density});
  final TrainerWorkoutTimerProvider timer;
  final VoidCallback onSettings;
  final _HomeDensity density;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(
          density.space(12),
          density.space(12),
          density.space(12),
          density.space(14),
        ),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF262626))),
        child: Column(children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1C),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _ModeTab(
                    label: 'COUNTDOWN',
                    selected: timer.mode == TimerMode.countdown,
                    onTap: () => timer.toggleMode(TimerMode.countdown)),
                _ModeTab(
                    label: 'STOPWATCH',
                    selected: timer.mode == TimerMode.stopwatch,
                    onTap: () => timer.toggleMode(TimerMode.stopwatch)),
              ]),
            ),
            const Spacer(),
            IconButton(
                tooltip: 'Atur durasi timer',
                onPressed: onSettings,
                style: IconButton.styleFrom(
                    fixedSize: const Size(30, 30),
                    backgroundColor: const Color(0xFF1C1C1C)),
                icon: const Icon(Icons.settings_rounded,
                    color: Color(0xFF9A9A9A), size: 16)),
          ]),
          SizedBox(height: density.space(10)),
          Semantics(
            liveRegion: true,
            label: 'Timer ${timer.displayValue}',
            child: LayoutBuilder(builder: (context, constraints) {
              final ringSize =
                  (constraints.maxWidth * 0.42).clamp(136.0, 156.0);
              return SizedBox(
                width: ringSize,
                height: ringSize,
                child: Stack(alignment: Alignment.center, children: [
                  SizedBox(
                    width: ringSize,
                    height: ringSize,
                    child: CircularProgressIndicator(
                        value: timer.progressValue == 0
                            ? 0.015
                            : timer.progressValue,
                        strokeWidth: 5.5,
                        strokeCap: StrokeCap.round,
                        backgroundColor: const Color(0xFF2A2A2A),
                        valueColor:
                            const AlwaysStoppedAnimation(AppColors.accent)),
                  ),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(timer.displayValue,
                        style: TextStyle(
                            fontSize: density.font(37),
                            height: 1,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1)),
                    SizedBox(height: density.space(4)),
                    Text(timer.intensityLabel,
                        style: TextStyle(
                            color: const Color(0xFF9A9A9A),
                            fontSize: density.font(8.5),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5)),
                  ]),
                ]),
              );
            }),
          ),
          SizedBox(height: density.space(14)),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _TimerButton(
                tooltip: 'Reset timer',
                icon: Icons.restart_alt_rounded,
                onTap: timer.reset),
            SizedBox(width: density.space(16)),
            _TimerButton(
                tooltip: timer.isRunning ? 'Jeda timer' : 'Mulai timer',
                icon: timer.isRunning
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                primary: true,
                onTap: timer.toggleRunning),
            SizedBox(width: density.space(16)),
            _TimerButton(
                tooltip: 'Hentikan timer',
                icon: Icons.stop_rounded,
                onTap: timer.isRunning ? timer.toggleRunning : () {}),
          ]),
        ]),
      );
}

class _ModeTab extends StatelessWidget {
  const _ModeTab(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Text(label,
                style: TextStyle(
                    color:
                        selected ? AppColors.accent : const Color(0xFF9A9A9A),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4)),
          ),
        ),
      );
}

class _TimerButton extends StatelessWidget {
  const _TimerButton(
      {required this.tooltip,
      required this.icon,
      required this.onTap,
      this.primary = false});
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: primary ? 54 : 44,
            height: primary ? 54 : 44,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primary ? AppColors.accent : const Color(0xFF1C1C1C),
                boxShadow: primary
                    ? [
                        BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.34),
                            blurRadius: 16)
                      ]
                    : null),
            child: Icon(icon,
                color: primary ? AppColors.background : Colors.white,
                size: primary ? 24 : 19),
          ),
        ),
      );
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF262626))),
        child: Row(children: [
          const Icon(Icons.cloud_off_rounded,
              size: 18, color: Color(0xFF9A9A9A)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style:
                      const TextStyle(color: Color(0xFF9A9A9A), fontSize: 12))),
          TextButton(onPressed: onRetry, child: const Text('Coba Lagi')),
        ]),
      );
}
