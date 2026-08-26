import 'package:egg_gym/app/routes/app_routes.dart';
import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/data/services/backend_payment_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Aksi saat card transaksi PENDING ditekan (dipakai bersama halaman Membership
/// utama & halaman Semua Transaksi supaya tidak duplikasi logic).
///
/// - BELUM expired (dicek server via [isExpired]): reuse QR/VA lama -> buka
///   PaymentSuccessPage dengan data yang sudah ada. TIDAK membuat transaksi baru.
/// - SUDAH expired: tampilkan dialog "QR kedaluwarsa" + tombol "Buat Pembayaran
///   Baru". Bila dikonfirmasi -> regeneratePendingPayment (backend menandai
///   transaksi lama 'expired' lebih dulu, lalu buat baru = anti-duplikasi) ->
///   buka PaymentSuccessPage dengan QR baru.
///
/// [onShouldRefresh] dipanggil setelah kembali dari PaymentSuccessPage supaya
/// list transaksi bisa di-refresh (status mungkin berubah).
Future<void> handlePendingPaymentTap(
  BuildContext context, {
  required String referenceCode,
  required bool isExpired,
  required double amount,
  required String status,
  String? paymentMethod,
  String? qrString,
  String? paymentNumber,
  DateTime? expiredAt,
  VoidCallback? onShouldRefresh,
}) async {
  final method = paymentMethod ?? 'qris';

  // ── BELUM EXPIRED: reuse QR/VA lama (tanpa transaksi baru) ──
  if (!isExpired) {
    final session = PakasirCheckoutSession(
      transactionId: 0,
      referenceCode: referenceCode,
      paymentMethod: method,
      amount: amount,
      fee: null,
      totalPayment: null,
      status: status,
      providerName: 'pakasir',
      providerMethod: method,
      paymentCode: paymentNumber ?? '-',
      qrString: qrString,
      expiredAt: expiredAt,
    );
    await Get.toNamed(
      AppRoutes.paymentSuccess,
      arguments: {'source': 'member', 'checkout': session.toMap()},
    );
    onShouldRefresh?.call();
    return;
  }

  // ── SUDAH EXPIRED: konfirmasi buat pembayaran baru ──
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('QR Kedaluwarsa'),
      content: const Text(
        'QR pembayaran untuk transaksi ini sudah kedaluwarsa. Buat pembayaran '
        'baru? Transaksi lama akan ditandai kedaluwarsa agar tidak menumpuk.',
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
          child: const Text('Buat Pembayaran Baru'),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  try {
    final session =
        await BackendPaymentService().regeneratePendingPayment(referenceCode);
    await Get.toNamed(
      AppRoutes.paymentSuccess,
      arguments: {'source': 'member', 'checkout': session.toMap()},
    );
    onShouldRefresh?.call();
  } on PaymentApiException catch (e) {
    Get.snackbar(
      'Gagal',
      e.message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.surface,
      colorText: AppColors.textPrimary,
    );
  } catch (_) {
    Get.snackbar(
      'Gagal',
      'Tidak bisa membuat pembayaran baru. Pastikan backend aktif.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.surface,
      colorText: AppColors.textPrimary,
    );
  }
}
