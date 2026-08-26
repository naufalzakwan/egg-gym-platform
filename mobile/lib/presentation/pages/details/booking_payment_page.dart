import 'dart:io';

import 'package:egg_gym/app/routes/app_routes.dart';
import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/core/utils/payment_verification_overdue_copy.dart';
import 'package:egg_gym/core/formatters/app_date_formatter.dart';
import 'package:egg_gym/data/services/backend_booking_payment_service.dart';
import 'package:egg_gym/presentation/controllers/member_shell_controller.dart';
import 'package:egg_gym/presentation/widgets/common/decorated_screen.dart';
import 'package:egg_gym/presentation/widgets/common/egg_button.dart';
import 'package:egg_gym/presentation/widgets/common/egg_card.dart';
import 'package:egg_gym/presentation/widgets/common/booking_expiry_countdown.dart';
import 'package:egg_gym/presentation/widgets/common/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

class BookingPaymentPage extends StatefulWidget {
  const BookingPaymentPage({super.key});

  @override
  State<BookingPaymentPage> createState() => _BookingPaymentPageState();
}

class _BookingPaymentPageState extends State<BookingPaymentPage> {
  final BackendBookingPaymentService _service = BackendBookingPaymentService();
  final ImagePicker _picker = ImagePicker();
  BookingPaymentInfo? _paymentInfo;
  File? _selectedProof;
  bool _isLoading = true;
  bool _isUploading = false;
  String? _errorMessage;

  int? get _bookingId {
    final argument = Get.arguments;
    if (argument is Map<String, dynamic>) {
      final id = argument['bookingId'];
      if (id is int) return id;
      if (id != null) return int.tryParse(id.toString());
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadPaymentInfo();
  }

  Future<void> _loadPaymentInfo() async {
    final bookingId = _bookingId;
    if (bookingId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Booking ID tidak ditemukan.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final info = await _service.getPaymentInfo(bookingId);
      if (!mounted) return;
      if (info.isExpired || info.status == 'expired') {
        if (Get.isRegistered<MemberShellController>()) {
          Get.find<MemberShellController>().changeTab(0);
        }
        Get.offAllNamed(AppRoutes.memberShell);
        Get.snackbar(
          'Pembayaran Kedaluwarsa',
          'Waktu pembayaran telah habis.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.surface,
          colorText: AppColors.textPrimary,
        );
        return;
      }
      setState(() {
        _paymentInfo = info;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _pickFile() async {
    if (_isUploading) return;

    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
      );

      if (picked == null) return; // User membatalkan pemilihan.
      if (!mounted) return;

      setState(() {
        _selectedProof = File(picked.path);
      });
    } catch (e) {
      if (!mounted) return;
      Get.snackbar(
        'Gagal Membuka Galeri',
        'Tidak bisa mengakses foto. Pastikan izin galeri diberikan. (${e.toString().replaceAll('Exception: ', '')})',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
    }
  }

  Future<void> _uploadProof() async {
    if (_isUploading) return;

    final bookingId = _bookingId;
    if (bookingId == null) return;

    final file = _selectedProof;
    if (file == null) {
      Get.snackbar(
        'Bukti Belum Dipilih',
        'Silakan pilih foto bukti transfer terlebih dahulu.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      await _service.uploadProof(bookingId, file);
      if (!mounted) return;

      setState(() => _selectedProof = null);
      if (Get.isRegistered<MemberShellController>()) {
        Get.find<MemberShellController>().changeTab(0);
      }
      Get.offAllNamed(AppRoutes.memberShell);
      Get.snackbar(
        'Berhasil',
        'Bukti transfer berhasil diupload. Menunggu verifikasi trainer.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
    } catch (e) {
      if (!mounted) return;
      Get.snackbar(
        'Gagal Upload',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedScreen(
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError()
              : _paymentInfo == null
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
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            EggButton.secondary(
                label: 'Coba Lagi', onPressed: _loadPaymentInfo),
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
            const Icon(Icons.receipt_long_rounded,
                size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            const Text('Info pembayaran tidak ditemukan'),
            const SizedBox(height: 16),
            EggButton.secondary(label: 'Kembali', onPressed: () => Get.back()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final info = _paymentInfo!;
    final isWaiting =
        info.status == 'waiting_payment' || info.status == 'payment_rejected';
    final isUploaded = info.status == 'payment_uploaded';
    final isVerified = info.status == 'payment_verified';
    final deadlinePassed =
        info.expiredAt != null && !info.expiredAt!.isAfter(DateTime.now());

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => Get.back(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              color: AppColors.textPrimary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Pembayaran Sesi PT',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            IconButton(
              onPressed: _loadPaymentInfo,
              icon: const Icon(Icons.refresh_rounded),
              color: AppColors.textSecondary,
            ),
          ],
        ),
        const SizedBox(height: 18),
        // Status Card
        EggCard(
          highlight: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'STATUS PEMBAYARAN',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const Spacer(),
                  StatusChip(
                    label: _statusLabel(info.status),
                    color: _statusColor(info.status),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                info.isPaymentVerificationOverdue
                    ? PaymentVerificationOverdueCopy.memberMessage
                    : _statusDescription(info.status),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (info.expiredAt != null && !info.isPaymentVerificationOverdue) ...[
          EggCard(
            child: BookingExpiryCountdown(
              expiredAt: info.expiredAt,
              label: isUploaded
                  ? 'Sisa waktu verifikasi trainer'
                  : 'Sisa waktu pembayaran',
              onExpired: _loadPaymentInfo,
            ),
          ),
          const SizedBox(height: 18),
        ],
        // Trainer Payment Info
        EggCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Info Transfer',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              if (info.trainerName != null)
                _buildInfoRow('Trainer', info.trainerName!),
              if (_hasBankPayment(info)) ...[
                const SizedBox(height: 14),
                _buildPaymentMethod(
                  'REKENING BANK',
                  [
                    if (info.bankName != null) ('Bank', info.bankName!),
                    if (info.bankAccountNumber != null)
                      ('No. Rekening', info.bankAccountNumber!),
                    if (info.bankAccountName != null)
                      ('Atas Nama', info.bankAccountName!),
                  ],
                ),
              ],
              if (_hasDanaPayment(info)) ...[
                const SizedBox(height: 12),
                _buildPaymentMethod(
                  'DANA',
                  [
                    if (info.danaNumber != null)
                      ('Nomor DANA', info.danaNumber!),
                    if (info.danaAccountName != null)
                      ('Atas Nama', info.danaAccountName!),
                  ],
                ),
              ],
              if (_hasOtherPayment(info)) ...[
                const SizedBox(height: 12),
                _buildPaymentMethod(
                  info.otherPaymentMethod ?? 'PEMBAYARAN LAINNYA',
                  [
                    if (info.otherPaymentNumber != null)
                      ('Nomor / ID', info.otherPaymentNumber!),
                    if (info.otherPaymentAccountName != null)
                      ('Atas Nama', info.otherPaymentAccountName!),
                  ],
                ),
              ],
              if (!_hasAnyPaymentMethod(info)) ...[
                const SizedBox(height: 8),
                Text(
                  'Trainer belum mengisi metode pembayaran. Silakan hubungi trainer untuk info pembayaran.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        // Harga per Sesi + Jumlah Sesi + Total Pembayaran
        ..._buildPricingSection(info, isWaiting),
        ..._buildReservationSection(info),
        // Upload Proof Section
        if (isWaiting) ...[
          EggCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upload Bukti Transfer',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _isUploading || deadlinePassed ? null : _pickFile,
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.divider),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _selectedProof != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(
                                _selectedProof!,
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Material(
                                  color: Colors.black54,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: _isUploading
                                        ? null
                                        : () => setState(
                                            () => _selectedProof = null),
                                    child: const Padding(
                                      padding: EdgeInsets.all(6),
                                      child: Icon(Icons.close_rounded,
                                          size: 20, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'Tap untuk ganti foto',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_photo_alternate_rounded,
                                  size: 48, color: AppColors.textSecondary),
                              const SizedBox(height: 8),
                              Text(
                                'Tap untuk pilih foto bukti transfer',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                EggButton.primary(
                  label: _isUploading
                      ? 'Mengupload...'
                      : (_selectedProof == null
                          ? 'Pilih Bukti Pembayaran'
                          : 'Upload Bukti Pembayaran'),
                  onPressed: _isUploading || deadlinePassed
                      ? null
                      : (_selectedProof == null ? _pickFile : _uploadProof),
                ),
              ],
            ),
          ),
        ],
        // Already Uploaded
        if (isUploaded || isVerified) ...[
          EggCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bukti Pembayaran',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Icon(Icons.check_circle_rounded,
                        size: 48, color: AppColors.success),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isVerified
                      ? 'Bukti pembayaran sudah diverifikasi oleh trainer.'
                      : info.isPaymentVerificationOverdue
                          ? PaymentVerificationOverdueCopy.memberMessage
                          : 'Bukti pembayaran sudah diupload. Menunggu verifikasi dari trainer.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        EggButton.secondary(
          label: 'Kembali',
          onPressed: () => Get.back(),
        ),
      ],
    );
  }

  bool _hasBankPayment(BookingPaymentInfo info) =>
      info.bankName != null ||
      info.bankAccountNumber != null ||
      info.bankAccountName != null;

  bool _hasDanaPayment(BookingPaymentInfo info) =>
      info.danaNumber != null || info.danaAccountName != null;

  bool _hasOtherPayment(BookingPaymentInfo info) =>
      info.otherPaymentMethod != null ||
      info.otherPaymentNumber != null ||
      info.otherPaymentAccountName != null;

  bool _hasAnyPaymentMethod(BookingPaymentInfo info) =>
      _hasBankPayment(info) || _hasDanaPayment(info) || _hasOtherPayment(info);

  Widget _buildPaymentMethod(
    String title,
    List<(String, String)> rows,
  ) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
              ),
            ),
            for (final row in rows) ...[
              const SizedBox(height: 8),
              _buildInfoRow(row.$1, row.$2),
            ],
          ],
        ),
      );

  List<Widget> _buildPricingSection(BookingPaymentInfo info, bool isWaiting) {
    final price = info.pricePerSession;

    // Trainer belum mengatur harga per sesi.
    if (price == null || price <= 0) {
      return [
        EggCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: AppColors.textSecondary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Trainer belum mengatur harga per sesi. Silakan hubungi trainer untuk informasi biaya sebelum melakukan pembayaran.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
      ];
    }

    final total = info.totalAmount;

    return [
      // Card Harga per Sesi
      EggCard(
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.sell_outlined, color: AppColors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Harga per Sesi',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatRupiah(price),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      // Jumlah sesi dibekukan saat booking dibuat.
      EggCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Jumlah Sesi',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Jumlah sesi final dari request booking.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 14),
            Text(
              '${info.sessionCount} sesi',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      // Total Pembayaran
      EggCard(
        highlight: true,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Pembayaran',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatRupiah(price)} × ${info.sessionCount} sesi',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            Text(
              total != null ? _formatRupiah(total) : '-',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
    ];
  }

  List<Widget> _buildReservationSection(BookingPaymentInfo info) {
    if (info.reservations.isEmpty) return const [];
    return [
      EggCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Jadwal Sesi Direservasi',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            ...info.reservations.map((reservation) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildInfoRow(
                    'Sesi ${reservation.sequenceOrder}',
                    '${AppDateFormatter.schedule(dateValue: reservation.sessionDate, startTime: reservation.startTime, endTime: reservation.endTime)} | ${reservation.status.toUpperCase()}',
                  ),
                )),
          ],
        ),
      ),
      const SizedBox(height: 18),
    ];
  }

  String _formatRupiah(double value) {
    final intValue = value.round();
    final digits = intValue.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }
    return 'Rp $buffer';
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
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
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'waiting_payment':
        return 'MENUNGGU BAYAR';
      case 'payment_uploaded':
        return 'MENUNGGU VERIFIKASI';
      case 'payment_verified':
        return 'TERVERIFIKASI';
      case 'payment_rejected':
        return 'DITOLAK';
      default:
        return status.toUpperCase();
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'waiting_payment':
        return AppColors.accent;
      case 'payment_uploaded':
        return AppColors.accent;
      case 'payment_verified':
        return AppColors.success;
      case 'payment_rejected':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  String _statusDescription(String status) {
    switch (status) {
      case 'waiting_payment':
        return 'Silakan transfer ke rekening trainer yang tertera di bawah, lalu upload bukti transfer.';
      case 'payment_uploaded':
        return 'Bukti pembayaran sudah diupload. Menunggu trainer memverifikasi.';
      case 'payment_verified':
        return 'Pembayaran sudah diverifikasi. Program latihan akan segera dibuat.';
      case 'payment_rejected':
        return 'Bukti pembayaran ditolak. Silakan upload ulang bukti transfer yang valid.';
      default:
        return '';
    }
  }
}
