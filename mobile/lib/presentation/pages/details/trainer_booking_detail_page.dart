import 'package:egg_gym/app/routes/app_routes.dart';
import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/core/formatters/app_date_formatter.dart';
import 'package:egg_gym/data/services/backend_trainer_service.dart';
import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:egg_gym/presentation/widgets/common/decorated_screen.dart';
import 'package:egg_gym/presentation/widgets/common/booking_expiry_countdown.dart';
import 'package:egg_gym/presentation/widgets/common/egg_card.dart';
import 'package:egg_gym/presentation/widgets/common/initial_avatar.dart';
import 'package:egg_gym/presentation/widgets/common/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TrainerBookingDetailPage extends StatefulWidget {
  const TrainerBookingDetailPage({
    super.key,
    this.initialSession,
    this.backendService,
  });

  final ScheduleSession? initialSession;
  final BackendTrainerService? backendService;

  @override
  State<TrainerBookingDetailPage> createState() =>
      _TrainerBookingDetailPageState();
}

class _TrainerBookingDetailPageState extends State<TrainerBookingDetailPage> {
  ScheduleSession? _session;
  ScheduleSession? _initialSession;
  late final BackendTrainerService _backendService;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isMutating = false;

  @override
  void initState() {
    super.initState();
    _backendService = widget.backendService ??
        _serviceFromArguments() ??
        BackendTrainerService();
    _initialSession = widget.initialSession ?? _sessionFromArguments();
    _loadDetail();
  }

  ScheduleSession? _sessionFromArguments() {
    final arguments = Get.arguments;
    if (arguments is ScheduleSession) return arguments;
    if (arguments is Map && arguments['session'] is ScheduleSession) {
      return arguments['session'] as ScheduleSession;
    }
    return null;
  }

  BackendTrainerService? _serviceFromArguments() {
    final arguments = Get.arguments;
    if (arguments is Map &&
        arguments['backendService'] is BackendTrainerService) {
      return arguments['backendService'] as BackendTrainerService;
    }
    return null;
  }

  Future<void> _loadDetail() async {
    final backendId = _initialSession?.backendId;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    if (backendId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'ID booking tidak tersedia.';
      });
      return;
    }
    try {
      final detail = await _backendService.getBookingDetail(backendId);
      if (!mounted) return;
      setState(() => _session = detail);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error is TrainerApiException
            ? error.message
            : 'Detail booking gagal dimuat. Periksa koneksi lalu coba lagi.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _rawStatus(ScheduleSession session) =>
      session.rawStatus?.toLowerCase() ?? '';

  bool _isActionable(ScheduleSession session) =>
      const {'pending', 'rescheduled'}.contains(_rawStatus(session));

  bool _needsProgram(ScheduleSession session) =>
      _rawStatus(session) == 'payment_verified' && !session.hasProgram;

  Future<void> _createProgram(ScheduleSession session) async {
    await Get.toNamed(
      AppRoutes.trainerProgramBuilder,
      arguments: <String, dynamic>{
        'clientName': session.clientName,
        'memberProfileId': session.memberProfileId,
        'session': session,
      },
    );
    if (mounted) await _loadDetail();
  }

  Future<void> _mutate(String action) async {
    final session = _session;
    final backendId = session?.backendId;
    if (_isMutating || session == null || backendId == null) return;
    setState(() => _isMutating = true);
    try {
      if (action == 'confirmed') {
        await _backendService.confirmBooking(backendId);
      } else {
        await _backendService.rejectBooking(backendId);
      }
      if (!mounted) return;
      Get.back<String>(result: action);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
      setState(() => _isMutating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final titleSession = session ?? _initialSession;
    final isPending =
        titleSession != null && _rawStatus(titleSession) == 'pending';

    return DecoratedScreen(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: _isMutating ? null : () => Get.back(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                Expanded(
                  child: Text(
                    isPending ? 'Detail Permintaan Booking' : 'Detail Booking',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  )
                : _errorMessage != null
                    ? _DetailLoadError(
                        message: _errorMessage!,
                        onRetry: _loadDetail,
                      )
                    : _buildDetail(context, session!),
          ),
          if (session != null &&
              (_isActionable(session) || _needsProgram(session)))
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                child: _needsProgram(session)
                    ? FilledButton(
                        key: const Key('create-program-button'),
                        onPressed:
                            _isMutating ? null : () => _createProgram(session),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.background,
                          minimumSize: const Size.fromHeight(52),
                        ),
                        child: const Text('Buat Program Dulu'),
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              key: const Key('reject-booking-button'),
                              onPressed: _isMutating
                                  ? null
                                  : () => _mutate('rejected'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                minimumSize: const Size.fromHeight(52),
                              ),
                              child: const Text('Tolak'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              key: const Key('confirm-booking-button'),
                              onPressed: _isMutating
                                  ? null
                                  : () => _mutate('confirmed'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: AppColors.background,
                                minimumSize: const Size.fromHeight(52),
                              ),
                              child: _isMutating
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.background,
                                      ),
                                    )
                                  : const Text('Konfirmasi'),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetail(BuildContext context, ScheduleSession session) {
    final membership = session.activeMembership;
    final rawStatus = _rawStatus(session);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _StatusHeader(
          label: rawStatus == 'pending'
              ? 'MENUNGGU KONFIRMASI'
              : session.status.toUpperCase(),
          isPending: _isActionable(session),
        ),
        const SizedBox(height: 14),
        EggCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle('Informasi Booking'),
              const SizedBox(height: 12),
              _DetailRow(label: 'ID Booking', value: _value(session.backendId)),
              _DetailRow(
                label: 'Nomor Booking',
                value: _value(session.bookingNumber),
              ),
              _DetailRow(
                label: 'Dibuat',
                value: _createdAtLabel(session.createdAt),
                isLast: session.expiredAt == null,
              ),
              if (session.expiredAt != null)
                BookingExpiryCountdown(
                  expiredAt: session.expiredAt,
                  label: 'Sisa waktu konfirmasi',
                  onExpired: _loadDetail,
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        EggCard(
          child: Column(
            children: [
              InitialAvatar(
                name: session.clientName,
                avatarPath: session.memberAvatarUrl,
                radius: 36,
              ),
              const SizedBox(height: 12),
              Text(
                session.clientName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              StatusChip(
                label: _value(membership?.planName).toUpperCase(),
                color: AppColors.accent,
              ),
              const SizedBox(height: 14),
              _DetailRow(
                  label: 'Kode Member', value: _value(session.memberCode)),
              _DetailRow(label: 'Email', value: _value(session.memberEmail)),
              _DetailRow(
                label: 'Telepon',
                value: _value(session.memberPhone),
                isLast: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _ScheduleBox(
                icon: Icons.event_rounded,
                label: 'JADWAL SESI',
                value: _value(session.timeRange),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ScheduleBox(
                icon: Icons.place_rounded,
                label: 'LOKASI',
                value: _value(session.location),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        EggCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle('Fokus Latihan'),
              const SizedBox(height: 12),
              _DetailRow(
                label: 'Judul',
                value: _value(session.sessionTitle),
              ),
              _DetailRow(
                label: 'Fokus',
                value: _value(session.memberNote),
                isLast: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        EggCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(
                'Jadwal yang Diajukan (${session.sessionCount} sesi)',
              ),
              const SizedBox(height: 12),
              if (session.reservations.isEmpty)
                const Text('-')
              else
                ...session.reservations.map(
                  (reservation) => _DetailRow(
                    label: 'Sesi ${reservation.sequenceOrder}',
                    value:
                        '${AppDateFormatter.schedule(dateValue: reservation.sessionDate, startTime: reservation.startTime, endTime: reservation.endTime)} | ${reservation.status.toUpperCase()}',
                    isLast: reservation == session.reservations.last,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        EggCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle('Membership Aktif'),
              const SizedBox(height: 12),
              _DetailRow(label: 'Paket', value: _value(membership?.planName)),
              _DetailRow(
                label: 'Periode',
                value: membership == null
                    ? '-'
                    : '${AppDateFormatter.date(membership.startDate)} - ${AppDateFormatter.date(membership.endDate)}',
              ),
              _DetailRow(
                label: 'Status',
                value: _value(membership?.status),
                isLast: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        EggCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle('Catatan dari Member'),
              const SizedBox(height: 10),
              Text(
                _hasValue(session.memberNote)
                    ? session.memberNote!.trim()
                    : 'Tidak ada catatan tambahan',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        EggCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle('Snapshot Harga'),
              const SizedBox(height: 12),
              _DetailRow(
                label: 'Per Sesi',
                value: _formatRupiah(session.pricePerSession),
              ),
              _DetailRow(
                label: 'Jumlah Sesi',
                value: '${session.sessionCount}',
              ),
              _DetailRow(
                label: 'Total',
                value: _formatRupiah(session.totalAmount),
                isLast: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        EggCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle('Profil Fisik Member'),
              const SizedBox(height: 12),
              _DetailRow(
                label: 'Jenis Kelamin',
                value: _genderLabel(session.memberGender),
              ),
              _DetailRow(
                label: 'Tanggal Lahir',
                value: _birthDateLabel(session.memberBirthDate),
              ),
              _DetailRow(
                  label: 'Usia', value: _ageLabel(session.memberBirthDate)),
              _DetailRow(
                label: 'Tinggi Badan',
                value: session.memberHeightCm == null
                    ? '-'
                    : '${session.memberHeightCm!.toStringAsFixed(0)} cm',
              ),
              _DetailRow(
                label: 'Berat Badan',
                value: session.memberWeightKg == null
                    ? '-'
                    : '${session.memberWeightKg!.toStringAsFixed(0)} kg',
              ),
              _DetailRow(
                label: 'Target Latihan',
                value: _value(session.memberFitnessGoal),
              ),
              _DetailRow(
                label: 'Catatan Medis',
                value: _value(session.memberMedicalNote),
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _hasValue(Object? value) => value?.toString().trim().isNotEmpty == true;

  String _value(Object? value) =>
      _hasValue(value) ? value.toString().trim() : '-';

  String _createdAtLabel(DateTime? value) {
    if (value == null) return '-';
    final local = value.toLocal();
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '${AppDateFormatter.date(local, includeWeekday: true)} | $time';
  }

  String _formatRupiah(double? value) {
    if (value == null) return '-';
    final digits = value.round().toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) buffer.write('.');
      buffer.write(digits[index]);
    }
    return 'Rp $buffer';
  }

  String _genderLabel(String? gender) {
    switch (gender?.toLowerCase()) {
      case 'male':
      case 'l':
      case 'laki-laki':
        return 'Laki-laki';
      case 'female':
      case 'p':
      case 'perempuan':
        return 'Perempuan';
      default:
        return gender == null || gender.isEmpty ? '-' : gender;
    }
  }

  String _ageLabel(String? birthDate) {
    if (birthDate == null || birthDate.isEmpty) return '-';
    final date = DateTime.tryParse(birthDate);
    if (date == null) return '-';
    final now = DateTime.now();
    var age = now.year - date.year;
    if (now.month < date.month ||
        (now.month == date.month && now.day < date.day)) {
      age--;
    }
    return age > 0 ? '$age tahun' : '-';
  }

  String _birthDateLabel(String? birthDate) {
    if (birthDate == null || birthDate.isEmpty) return '-';
    final date = DateTime.tryParse(birthDate);
    return date == null ? '-' : AppDateFormatter.date(date);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      );
}

class _DetailLoadError extends StatelessWidget {
  const _DetailLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 42,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(
                key: const Key('retry-booking-detail-button'),
                onPressed: onRetry,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.label, required this.isPending});

  final String label;
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: isPending
              ? [AppColors.surfaceElevated, AppColors.surface]
              : [const Color(0xFFFFD54D), AppColors.accentDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STATUS BOOKING',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: isPending
                      ? AppColors.textSecondary
                      : AppColors.background.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color:
                      isPending ? AppColors.textPrimary : AppColors.background,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleBox extends StatelessWidget {
  const _ScheduleBox({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return EggCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.accent),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
