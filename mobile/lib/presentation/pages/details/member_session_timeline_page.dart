import 'package:egg_gym/app/routes/app_routes.dart';
import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/core/formatters/app_date_formatter.dart';
import 'package:egg_gym/data/services/backend_member_service.dart';
import 'package:egg_gym/presentation/widgets/common/decorated_screen.dart';
import 'package:egg_gym/presentation/widgets/common/egg_button.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MemberSessionTimelinePage extends StatefulWidget {
  const MemberSessionTimelinePage({super.key});

  @override
  State<MemberSessionTimelinePage> createState() =>
      _MemberSessionTimelinePageState();
}

class _MemberSessionTimelinePageState extends State<MemberSessionTimelinePage> {
  final BackendMemberService _memberService = BackendMemberService();
  MemberProgramDetailData? _programDetail;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProgramDetail();
  }

  int? get _programId {
    final argument = Get.arguments;
    if (argument is Map<String, dynamic>) {
      final id = argument['programId'];
      if (id is int) return id;
      if (id != null) return int.tryParse(id.toString());
    }
    return null;
  }

  Future<void> _loadProgramDetail() async {
    final programId = _programId;
    if (programId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Program ID tidak ditemukan.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final detail = await _memberService.getProgramDetail(programId);
      if (!mounted) return;
      setState(() {
        _programDetail = detail;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _startSession(MemberProgramSessionData session) async {
    final programId = _programId;
    debugPrint(
        'DEBUG _startSession: programId=$programId, sessionId=${session.id}, memberReady=${session.memberReady}');
    if (programId == null) return;

    // Toggle gembok izin centang trainer (BUKAN pembatalan progres):
    // - belum siap -> "Sesi Siap" (PT boleh mencentang dari progres terakhir)
    // - sudah siap -> "Mulai Sesi" (PT terkunci; centangan yang sudah ada
    //   tetap tersimpan). Boleh ditekan kapan saja berapapun progress-nya.
    setState(() => _isSubmitting = true);

    try {
      debugPrint('DEBUG _startSession: calling markSessionReady (toggle)...');
      final result = await _memberService.markSessionReady(
        programId: programId,
        sessionId: session.id,
      );
      debugPrint(
          'DEBUG _startSession: toggle success, memberReady=${result.memberReady}');
      if (!mounted) return;

      // Reload program detail
      await _loadProgramDetail();

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
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _openSessionDetail(MemberProgramSessionData session) {
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

  @override
  Widget build(BuildContext context) {
    return DecoratedScreen(
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError()
              : _programDetail == null
                  ? _buildEmpty()
                  : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            EggButton.secondary(
              label: 'Coba Lagi',
              onPressed: _loadProgramDetail,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fitness_center_rounded,
                size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              'Program tidak ditemukan',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),
            EggButton.secondary(
              label: 'Kembali',
              onPressed: () => Get.back(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final program = _programDetail!;
    final presentedSessions =
        sortMemberProgramSessionsBySchedule(program.sessions);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Header navigasi (back + konteks trainer). Judul fase ada di Phase Card.
        Row(
          children: [
            IconButton(
              onPressed: () => Get.back(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              color: AppColors.textPrimary,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                program.trainerName != null
                    ? 'Program dari ${program.trainerName}'
                    : 'Program Latihan',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildProgressCard(program),
        const SizedBox(height: 24),
        // Section header: Session Timeline + ikon filter (dekoratif, belum ada endpoint filter)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Session Timeline',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
            ),
            const Icon(
              Icons.tune_rounded,
              size: 20,
              color: Color(0xFF9A9A9A),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...presentedSessions.asMap().entries.map((entry) {
          final index = entry.key;
          final session = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildSessionTile(session, index),
          );
        }),
      ],
    );
  }

  // Watermark "LEVEL X" bersifat dekoratif (spec PROGRAM_TAB §7.2).
  // Backend tidak punya field "level" tersendiri, jadi angka diturunkan dari
  // posisi sesi aktif (sequenceOrder) atau jumlah sesi selesai -- data nyata,
  // bukan konstanta palsu. Dipakai hanya sebagai tekstur latar (opacity ~6%).
  int _deriveLevel(MemberProgramDetailData program) {
    final active = program.sessions.where((s) => s.isActive);
    if (active.isNotEmpty) return active.first.sequenceOrder;
    if (program.completedSessions > 0) return program.completedSessions;
    return 1;
  }

  Widget _buildProgressCard(MemberProgramDetailData program) {
    final percent = program.progressPercent.clamp(0, 100).toDouble();
    final levelValue = _deriveLevel(program);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Stack(
          children: [
            // Watermark dekoratif, di belakang konten & tidak menangkap sentuhan.
            Positioned.fill(
              child: IgnorePointer(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      'LEVEL $levelValue',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.clip,
                      style: const TextStyle(
                        fontSize: 88,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        letterSpacing: -2,
                        color: Color(0x0FF5C518), // rgba(245,197,24,~0.06)
                      ),
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
                  const Text(
                    'CURRENT PHASE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: Color(0xFF9A9A9A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    program.title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      height: 1.1,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${percent.round()}',
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
                          '${program.completedSessions} OF ${program.totalSessions} SESSIONS',
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
    );
  }

  Widget _buildSessionTile(MemberProgramSessionData session, int index) {
    final isCompleted = session.isCompleted;
    final isActive = session.isActive;
    final isLocked = session.isLocked;
    final isClickable = !isLocked;

    // Warna per varian state (PROGRAM_TAB §8.2/8.3/8.4). Logic penentuan state
    // (isCompleted/isActive/isLocked) TIDAK diubah -- murni pemetaan visual.
    final Color bgColor = isActive
        ? const Color(0xFF1A1A1A)
        : isLocked
            ? const Color(0xFF141414)
            : const Color(0xFF161616); // PAST
    final Color borderColor =
        isLocked ? const Color(0xFF1E1E1E) : const Color(0xFF262626);
    final Color titleColor =
        isLocked ? const Color(0xFF6B6B6B) : const Color(0xFFFFFFFF);
    final Color metaColor =
        isActive ? const Color(0xFFF5C518) : const Color(0xFF9A9A9A);

    // Bug 2 fix (Opsi A, sama seperti view utama): border seragam + borderRadius
    // legal, accent rail kuning dibuat sebagai widget terpisah (Positioned) di
    // dalam ClipRRect+Stack -- BUKAN sisi Border berwarna beda. Menghindari
    // "A borderRadius can only be given on borders with uniform colors" yang
    // membuat kartu ACTIVE gagal paint jadi kotak kosong (ErrorWidget).
    final tile = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusCircle(isCompleted, isActive, isLocked),
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
                            _sessionMeta(
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
                    _buildStateBadge(isCompleted, isActive),
                  ],
                ),
                // Tombol aksi inline hanya untuk sesi ACTIVE. Logic toggle "Sesi
                // Siap"/"Mulai Sesi" (gembok izin PT) & buka detail TIDAK diubah.
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
                          label: _isSubmitting
                              ? 'Memproses...'
                              : (session.memberReady
                                  ? 'Sesi Siap'
                                  : 'Mulai Sesi'),
                          onPressed:
                              _isSubmitting || session.hasPendingReschedule
                                  ? () {}
                                  : () => _startSession(session),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: EggButton.secondary(
                          label: 'Details',
                          onPressed: () => _openSessionDetail(session),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Accent rail kuning 3px di sisi kiri (hanya ACTIVE). Widget terpisah,
          // ter-clip rapi oleh ClipRRect di atas.
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

    final wrapped = GestureDetector(
      onTap: isClickable
          ? () => Get.toNamed(
                AppRoutes.memberSessionDetailReadOnly,
                arguments: {
                  'sessionId': session.id,
                  'sessionTitle': session.title,
                  'sessionFocus': session.focus,
                  'exercises': session.exercises,
                  'sessionStatus': session.status,
                },
              )
          : null,
      child: tile,
    );

    // Varian LOCKED diturunkan opacity-nya ~60% (spec §8.4).
    return isLocked ? Opacity(opacity: 0.6, child: wrapped) : wrapped;
  }

  Widget _buildStatusCircle(bool isCompleted, bool isActive, bool isLocked) {
    final Color circleBg = isActive
        ? const Color(0xFFF5C518)
        : isLocked
            ? const Color(0xFF1C1C1C)
            : const Color(0x26F5C518); // PAST: kuning ~15%
    final IconData icon = isCompleted
        ? Icons.check_rounded
        : isLocked
            ? Icons.lock_rounded
            : Icons.play_arrow_rounded;
    final Color iconColor = isActive
        ? const Color(0xFF0E0E0E)
        : isLocked
            ? const Color(0xFF6B6B6B)
            : const Color(0xFFF5C518); // PAST check kuning

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(shape: BoxShape.circle, color: circleBg),
      alignment: Alignment.center,
      child: Icon(icon, size: 14, color: iconColor),
    );
  }

  Widget _buildStateBadge(bool isCompleted, bool isActive) {
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
  String _sessionMeta(
    MemberProgramSessionData session,
    bool isCompleted,
    bool isActive,
    bool isLocked,
  ) {
    final schedule = _scheduleLabel(session);
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

  String? _scheduleLabel(MemberProgramSessionData session) {
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
}
