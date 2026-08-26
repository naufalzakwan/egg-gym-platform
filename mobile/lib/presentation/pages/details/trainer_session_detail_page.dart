import 'package:egg_gym/app/routes/app_routes.dart';
import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/core/formatters/app_date_formatter.dart';
import 'package:egg_gym/data/services/backend_trainer_service.dart';
import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:egg_gym/presentation/widgets/common/decorated_screen.dart';
import 'package:egg_gym/presentation/widgets/common/detail_screen_header.dart';
import 'package:egg_gym/presentation/widgets/common/egg_button.dart';
import 'package:egg_gym/presentation/widgets/common/egg_card.dart';
import 'package:egg_gym/presentation/widgets/common/initial_avatar.dart';
import 'package:egg_gym/presentation/widgets/common/status_chip.dart';
import 'package:egg_gym/presentation/widgets/common/booking_expiry_countdown.dart';
import 'package:egg_gym/presentation/widgets/common/reschedule_request_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TrainerSessionDetailPage extends StatefulWidget {
  const TrainerSessionDetailPage({super.key});

  @override
  State<TrainerSessionDetailPage> createState() =>
      _TrainerSessionDetailPageState();
}

class _TrainerSessionDetailPageState extends State<TrainerSessionDetailPage>
    with WidgetsBindingObserver {
  final BackendTrainerService _trainerService = BackendTrainerService();
  int? _activeProgramSessionId;
  String? _activeProgramSessionTitle;
  int? _activeProgramId;
  bool _memberReady = false;
  bool _isLoadingProgram = false;

  ScheduleSession? _session;
  late final String _viewerRole;
  late final int? _memberProfileId;
  late final int? _trainerProfileId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session = _resolveSession();
    _viewerRole = _resolveViewerRole();
    _memberProfileId = _resolveMemberProfileId();
    _trainerProfileId = _resolveTrainerProfileId();

    if (_viewerRole == 'trainer') _loadActiveProgram();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_viewerRole == 'trainer') _loadActiveProgram();
    }
  }

  ScheduleSession? _resolveSession() {
    final argument = Get.arguments;
    if (argument is ScheduleSession) {
      return argument;
    }
    if (argument is Map<String, dynamic> &&
        argument['session'] is ScheduleSession) {
      final session = argument['session'] as ScheduleSession;
      return ScheduleSession(
        backendId: session.backendId,
        memberProfileId: session.memberProfileId,
        trainerProfileId: session.trainerProfileId,
        clientName: argument['clientName'] as String? ?? session.clientName,
        timeRange: argument['timeRange'] as String? ?? session.timeRange,
        location: argument['location'] as String? ?? session.location,
        status: argument['status'] as String? ?? session.status,
        note: argument['note'] as String? ?? session.note,
        sessionDate: session.sessionDate,
        paymentProofUrl:
            argument['paymentProofUrl'] as String? ?? session.paymentProofUrl,
        paymentVerifiedAt: session.paymentVerifiedAt,
        sessionCount: session.sessionCount,
        pricePerSession: session.pricePerSession,
        totalAmount: session.totalAmount,
        reservations: session.reservations,
        rawStatus: session.rawStatus,
        hasProgram: session.hasProgram,
        trainingProgramId: session.trainingProgramId,
        activeProgramSessionId: session.activeProgramSessionId,
        activeProgramSessionTitle: session.activeProgramSessionTitle,
        activeProgramSessionMemberReady:
            session.activeProgramSessionMemberReady,
        expiredAt: session.expiredAt,
        remainingSeconds: session.remainingSeconds,
        expiryStage: session.expiryStage,
        isExpired: session.isExpired,
        isPaymentVerificationOverdue: session.isPaymentVerificationOverdue,
        paymentVerificationOverdueSeconds:
            session.paymentVerificationOverdueSeconds,
      );
    }

    return null;
  }

  String _resolveViewerRole() {
    final argument = Get.arguments;
    if (argument is Map<String, dynamic>) {
      final role = argument['role'] ?? argument['viewerRole'];
      if (role is String && role.isNotEmpty) {
        return role;
      }
    }
    return 'trainer';
  }

  int? _resolveMemberProfileId() {
    final argument = Get.arguments;
    if (argument is Map<String, dynamic>) {
      final id = argument['memberProfileId'];
      if (id is int) return id;
      if (id != null) return int.tryParse(id.toString());
    }
    return _session?.memberProfileId;
  }

  int? _resolveTrainerProfileId() {
    final argument = Get.arguments;
    if (argument is Map<String, dynamic>) {
      final id = argument['trainerProfileId'];
      if (id is int) return id;
      if (id != null) return int.tryParse(id.toString());
    }
    return _session?.trainerProfileId;
  }

  Future<void> _loadActiveProgram() async {
    setState(() => _isLoadingProgram = true);

    try {
      final bookingId = _session?.backendId;
      if (bookingId == null) return;
      final detail = await _trainerService.getBookingDetail(bookingId);
      if (!mounted) return;

      setState(() {
        _session = detail;
        _activeProgramSessionId = detail.activeProgramSessionId;
        _activeProgramSessionTitle = detail.activeProgramSessionTitle;
        _activeProgramId = detail.trainingProgramId;
        _memberReady = detail.activeProgramSessionMemberReady;
      });
    } catch (_) {
      // Keep null if API fails
    } finally {
      if (mounted) {
        setState(() => _isLoadingProgram = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) {
      return DecoratedScreen(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const DetailScreenHeader(
              title: 'Session Detail',
              subtitle: 'Rincian sesi tidak tersedia.',
            ),
            const SizedBox(height: 20),
            EggCard(
              child: Text(
                'Data sesi tidak ditemukan. Buka halaman ini dari daftar sesi terbaru.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
              ),
            ),
            const SizedBox(height: 18),
            EggButton.secondary(label: 'Kembali', onPressed: () => Get.back()),
          ],
        ),
      );
    }
    final viewerRole = _viewerRole;
    final isMemberViewer = viewerRole == 'member';
    final statusKey = _resolveStatusKey(session);
    final isPending = statusKey == 'pending';
    final isRescheduled = statusKey == 'rescheduled';
    final isAwaitingPayment =
        statusKey == 'waiting_payment' || statusKey == 'confirmed';
    final isVerificationOverdue = session.isPaymentVerificationOverdue ||
        (statusKey == 'payment_uploaded' &&
            session.expiredAt != null &&
            !session.expiredAt!.isAfter(DateTime.now()));
    final hasActiveProgram = _activeProgramSessionId != null;

    return DecoratedScreen(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          DetailScreenHeader(
            title: 'Session Detail',
            subtitle: isMemberViewer
                ? 'Rincian sesi personal trainer Anda.'
                : 'Rincian sesi personal trainer.',
          ),
          if (!isMemberViewer && _memberProfileId != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: _isLoadingProgram ? null : _loadActiveProgram,
                  icon: _isLoadingProgram
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          const SizedBox(height: 20),
          EggCard(
            highlight: true,
            child: Column(
              children: [
                Row(
                  children: [
                    InitialAvatar(name: session.clientName, radius: 30),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.clientName,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${session.timeRange} | ${session.location}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    StatusChip(
                      label: session.status.toUpperCase(),
                      color: isPending
                          ? AppColors.textSecondary
                          : isRescheduled
                              ? AppColors.success
                              : AppColors.accent,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tujuan Sesi',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        session.note,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Icon(Icons.event_repeat_rounded,
                              size: 18, color: AppColors.accent),
                          const SizedBox(width: 8),
                          Text(
                            'Jumlah Sesi Dibayar: ',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                          Text(
                            '${session.sessionCount} sesi',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
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
          const SizedBox(height: 18),
          if (session.expiredAt != null && !isVerificationOverdue) ...[
            EggCard(
              child: BookingExpiryCountdown(
                expiredAt: session.expiredAt,
                label: statusKey == 'payment_uploaded'
                    ? 'Sisa waktu verifikasi'
                    : isAwaitingPayment
                        ? 'Sisa waktu pembayaran'
                        : 'Sisa waktu konfirmasi',
                onExpired: statusKey == 'payment_uploaded'
                    ? () => setState(() {})
                    : () => Get.back(),
              ),
            ),
            const SizedBox(height: 18),
          ],
          if (session.reservations.isNotEmpty) ...[
            _ReservationScheduleCard(reservations: session.reservations),
            const SizedBox(height: 18),
          ],
          ...session.reservations
              .where((item) => item.activeRescheduleRequest != null)
              .expand((item) => [
                    RescheduleRequestCard(
                      request: item.activeRescheduleRequest!,
                      onAccept: () => _respondReschedule(
                          item.activeRescheduleRequest!, 'accept'),
                      onReject: () => _respondReschedule(
                          item.activeRescheduleRequest!, 'reject'),
                      onCancel: () => _respondReschedule(
                          item.activeRescheduleRequest!, 'cancel'),
                      onExpired: () async => Get.back(result: true),
                    ),
                    const SizedBox(height: 18),
                  ]),
          if (statusKey == 'payment_uploaded')
            _PaymentProofCard(
              proofUrl: session.paymentProofUrl,
              heroTag:
                  'booking-payment-proof-${session.backendId ?? 'unknown'}',
            )
          else
            _ProgramAvailabilityCard(
              hasProgram: session.hasProgram,
              isAwaitingPayment: isAwaitingPayment,
            ),
          const SizedBox(height: 18),
          EggCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aksi Booking',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 14),
                _ActionRow(
                  label: 'Status',
                  value: _statusLabel(session.status),
                ),
                const SizedBox(height: 10),
                _ActionRow(
                  label: 'Schedule',
                  value: session.timeRange,
                ),
                const SizedBox(height: 10),
                _ActionRow(
                  label: 'Location',
                  value: session.location,
                ),
                const SizedBox(height: 14),
                Text(
                  statusKey == 'payment_uploaded'
                      ? isVerificationOverdue
                          ? 'Verifikasi pembayaran terlambat. Booking dan slot tetap aktif; segera periksa bukti lalu pilih Tolak atau Valid.'
                          : 'Periksa bukti pembayaran member, lalu pilih Tolak atau Valid.'
                      : isPending
                          ? 'Booking ini masih menunggu keputusan trainer.'
                          : isAwaitingPayment
                              ? 'Booking sudah dikonfirmasi. Menunggu member mengunggah bukti pembayaran.'
                              : 'Sesi ini sudah siap dijalankan. Kalau slot berubah, kamu tetap bisa pindah ke flow reschedule.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (!isMemberViewer && statusKey == 'payment_uploaded')
            Row(
              children: [
                Expanded(
                  child: EggButton.secondary(
                    label: 'Tolak',
                    onPressed: () => _submitPaymentVerification(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: EggButton.primary(
                    label: 'Valid',
                    onPressed: () => _submitPaymentVerification(true),
                  ),
                ),
              ],
            )
          else if (!isMemberViewer)
            Row(
              children: [
                if (statusKey == 'payment_verified' &&
                    !session.reservations
                        .any((item) => item.activeRescheduleRequest != null) &&
                    session.reservations.any((item) =>
                        item.status == 'reserved' &&
                        item.activeRescheduleRequest == null)) ...[
                  Expanded(
                    child: EggButton.secondary(
                      label: 'Reschedule',
                      onPressed: () async {
                        final updated = await Get.toNamed(
                          AppRoutes.bookingReschedule,
                          arguments: <String, dynamic>{
                            'session': session,
                            if (_trainerProfileId != null)
                              'trainerProfileId': _trainerProfileId,
                          },
                        );
                        if (updated == true && mounted) Get.back(result: true);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: EggButton.primary(
                    label: isMemberViewer
                        ? 'Kembali'
                        : (isPending
                            ? 'Konfirmasi Booking'
                            : (isAwaitingPayment
                                ? 'Menunggu Bayar'
                                : (statusKey == 'payment_uploaded'
                                    ? 'Verifikasi Pembayaran'
                                    : (statusKey == 'payment_rejected'
                                        ? 'Menunggu Upload Ulang'
                                        : (hasActiveProgram
                                            ? (_memberReady
                                                ? 'Kontrol Progres PT'
                                                : 'Menunggu Member')
                                            : 'Buat Program Dulu'))))),
                    onPressed: () async {
                      if (isMemberViewer) {
                        Get.back();
                        return;
                      }

                      if (isPending) {
                        Get.toNamed(
                          AppRoutes.bookingConfirmation,
                          arguments: session,
                        );
                        return;
                      }

                      if (isAwaitingPayment) {
                        Get.snackbar(
                          'Menunggu Pembayaran',
                          'Menunggu bukti pembayaran dari member.',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: AppColors.surface,
                          colorText: AppColors.textPrimary,
                        );
                        return;
                      }

                      if (statusKey == 'payment_rejected') {
                        Get.snackbar(
                          'Menunggu Upload Ulang',
                          'Member belum mengupload ulang bukti pembayaran.',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: AppColors.surface,
                          colorText: AppColors.textPrimary,
                        );
                        return;
                      }

                      if (!hasActiveProgram) {
                        // Langsung arahkan ke Program Builder dengan member
                        // sudah otomatis terpilih sebagai klien target.
                        await Get.toNamed(
                          AppRoutes.trainerProgramBuilder,
                          arguments: <String, dynamic>{
                            'clientName': session.clientName,
                            'memberProfileId': session.memberProfileId,
                            'session': session,
                          },
                        );
                        // Segarkan status program aktif saat kembali agar tombol
                        // ikut ter-update bila program sudah dibuat.
                        if (_viewerRole == 'trainer') _loadActiveProgram();
                        return;
                      }

                      if (!_memberReady) {
                        Get.snackbar(
                          'Member Belum Siap',
                          'Member belum menekan "Mulai Sesi". Tunggu hingga member menandai dirinya siap.',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: AppColors.surface,
                          colorText: AppColors.textPrimary,
                        );
                        return;
                      }

                      Get.toNamed(
                        AppRoutes.trainerProgressControl,
                        arguments: {
                          'session': session,
                          'trainingProgramSessionId': _activeProgramSessionId,
                          'trainingProgramId': _activeProgramId,
                          'activeProgramSessionTitle':
                              _activeProgramSessionTitle,
                          'role': 'trainer',
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Status mentah booking untuk logika tombol. Utamakan [rawStatus] dari
  /// backend; bila tidak ada (mis. data demo) petakan balik dari label
  /// terlokalisasi di [session.status].
  String _resolveStatusKey(ScheduleSession session) {
    final raw = session.rawStatus;
    if (raw != null && raw.isNotEmpty) {
      return raw.toLowerCase();
    }
    switch (session.status) {
      case 'Menunggu':
        return 'pending';
      case 'Menunggu Pembayaran':
      case 'Menunggu Bayar':
        return 'waiting_payment';
      case 'Menunggu Verifikasi':
      case 'Bukti Diupload':
        return 'payment_uploaded';
      case 'Terverifikasi':
      case 'Pembayaran Valid':
        return 'payment_verified';
      case 'Pembayaran Ditolak':
        return 'payment_rejected';
      case 'Dijadwalkan Ulang':
        return 'rescheduled';
      case 'Terkonfirmasi':
      case 'Dikonfirmasi':
        return 'confirmed';
      default:
        return session.status;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Menunggu';
      case 'waiting_payment':
        return 'Menunggu Bayar';
      case 'payment_uploaded':
        return 'Bukti Diupload';
      case 'payment_verified':
        return 'Pembayaran Valid';
      case 'payment_rejected':
        return 'Pembayaran Ditolak';
      case 'confirmed':
        return 'Dikonfirmasi';
      case 'rescheduled':
        return 'Dijadwalkan Ulang';
      default:
        return status;
    }
  }

  Future<void> _submitPaymentVerification(bool verified) async {
    final bookingId = _session?.backendId;
    if (bookingId == null) {
      Get.snackbar(
        'Gagal',
        'ID booking tidak ditemukan.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
      return;
    }

    String? rejectionNote;
    if (!verified) {
      final noteController = TextEditingController();
      final confirmed = await Get.dialog<bool>(
        AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Alasan Penolakan'),
          content: TextField(
            controller: noteController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText:
                  'Contoh: Nominal tidak sesuai / bukti tidak terbaca (opsional).',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Get.back(result: true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Tolak Pembayaran'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
      rejectionNote = noteController.text.trim();
    }

    // Tutup dialog verifikasi utama sebelum menampilkan loading.
    if (Get.isDialogOpen ?? false) {
      Get.back();
    }

    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    try {
      final updated = await _trainerService.verifyPayment(
        bookingId,
        verified: verified,
        rejectionNote: rejectionNote,
      );

      if (Get.isDialogOpen ?? false) {
        Get.back(); // tutup loading
      }
      if (!mounted) return;

      if (verified) {
        Get.back(result: updated);
        Get.snackbar(
          'Pembayaran Valid',
          'Pembayaran diverifikasi. Atur program latihan sebelum memulai sesi.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.surface,
          colorText: AppColors.textPrimary,
        );
      } else {
        setState(() => _session = updated);
        Get.snackbar(
          'Pembayaran Ditolak',
          'Pembayaran ditolak. Member diminta upload ulang bukti transfer.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.surface,
          colorText: AppColors.textPrimary,
        );
      }
    } catch (error) {
      if (Get.isDialogOpen ?? false) {
        Get.back(); // tutup loading
      }
      if (!mounted) return;

      Get.snackbar(
        'Gagal',
        error is TrainerApiException
            ? error.message
            : error.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
    }
  }

  Future<void> _respondReschedule(
      BookingRescheduleRequestData request, String action) async {
    String? type;
    String? note;
    if (action == 'reject') {
      final result = await _showRejectRescheduleDialog();
      if (result == null) return;
      type = result.$1;
      note = result.$2;
    }
    try {
      await _trainerService.respondRescheduleRequest(
        request.id,
        action: action,
        asMember: _viewerRole == 'member',
        rejectionType: type,
        rejectionNote: note,
      );
      if (!mounted) return;
      Get.back(result: true);
      Get.snackbar(
        'Reschedule Diperbarui',
        action == 'accept'
            ? 'Jadwal baru sudah diterapkan.'
            : action == 'reject'
                ? 'Permintaan reschedule ditolak.'
                : 'Permintaan reschedule dibatalkan.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
    } catch (error) {
      Get.snackbar(
        'Gagal Memproses Reschedule',
        error.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
    }
  }

  Future<(String, String?)?> _showRejectRescheduleDialog() async {
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
                      child: Text('Slot tidak sesuai jadwal aktif')),
                  DropdownMenuItem(
                      value: 'too_close',
                      child: Text('Terlalu dekat dengan sesi')),
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
                child: const Text('Batal')),
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
}

class _ProofUnavailable extends StatelessWidget {
  const _ProofUnavailable({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.image_not_supported_outlined,
              size: 44, color: AppColors.textSecondary),
          const SizedBox(height: 10),
          Text(
            message ?? 'Member belum mengupload bukti pembayaran.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _PaymentProofCard extends StatelessWidget {
  const _PaymentProofCard({
    required this.proofUrl,
    required this.heroTag,
  });

  final String? proofUrl;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    final url = proofUrl?.trim();
    final hasProof = url != null && url.isNotEmpty;

    return EggCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bukti Pembayaran',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            hasProof
                ? 'Tap foto untuk melihat bukti pembayaran secara penuh.'
                : 'Bukti pembayaran belum diunggah.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 200, maxHeight: 360),
              color: AppColors.surfaceSoft,
              child: hasProof
                  ? GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        _PaymentProofViewer.route(
                          proofUrl: url,
                          heroTag: heroTag,
                        ),
                      ),
                      child: Hero(
                        tag: heroTag,
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const SizedBox(
                              height: 200,
                              child: Center(child: CircularProgressIndicator()),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              const _ProofUnavailable(
                            message:
                                'Bukti pembayaran gagal dimuat. Pastikan koneksi dan storage backend dapat diakses.',
                          ),
                        ),
                      ),
                    )
                  : const _ProofUnavailable(
                      message: 'Bukti pembayaran belum diunggah.',
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgramAvailabilityCard extends StatelessWidget {
  const _ProgramAvailabilityCard({
    required this.hasProgram,
    required this.isAwaitingPayment,
  });

  final bool hasProgram;
  final bool isAwaitingPayment;

  @override
  Widget build(BuildContext context) {
    return EggCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasProgram
                    ? Icons.assignment_turned_in_outlined
                    : Icons.assignment_late_outlined,
                color: hasProgram ? AppColors.success : AppColors.accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isAwaitingPayment
                      ? 'Menunggu Pembayaran Member'
                      : hasProgram
                          ? 'Program Latihan Tersedia'
                          : 'Program Latihan Belum Dibuat',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isAwaitingPayment
                ? 'Program latihan dapat dibuat setelah member mengunggah bukti dan pembayaran dinyatakan valid.'
                : hasProgram
                    ? 'Program latihan asli sudah tersedia. Buka flow program untuk melihat sesi dan latihan member.'
                    : 'Atur program latihan terlebih dahulu sebelum memulai sesi.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
          ),
        ],
      ),
    );
  }
}

class _ReservationScheduleCard extends StatelessWidget {
  const _ReservationScheduleCard({required this.reservations});

  final List<BookingSessionReservation> reservations;

  @override
  Widget build(BuildContext context) {
    return EggCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Jadwal Sesi Direservasi',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 14),
          ...reservations.map((reservation) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ActionRow(
                  label: 'Sesi ${reservation.sequenceOrder}',
                  value:
                      '${AppDateFormatter.schedule(dateValue: reservation.sessionDate, startTime: reservation.startTime, endTime: reservation.endTime)} | ${reservation.status.toUpperCase()}',
                ),
              )),
        ],
      ),
    );
  }
}

class _PaymentProofViewer extends StatelessWidget {
  const _PaymentProofViewer({
    required this.proofUrl,
    required this.heroTag,
  });

  final String proofUrl;
  final String heroTag;

  static Route<void> route({
    required String proofUrl,
    required String heroTag,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => _PaymentProofViewer(
        proofUrl: proofUrl,
        heroTag: heroTag,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Bukti Pembayaran'),
      ),
      body: SafeArea(
        child: Center(
          child: Hero(
            tag: heroTag,
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Image.network(
                proofUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Bukti pembayaran gagal dimuat.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}
