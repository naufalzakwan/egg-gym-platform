import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Bulan singkat (untuk format "DD MMM YYYY").
const List<String> _kMonthAbbr = [
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

/// Format nominal rupiah dengan pemisah ribuan titik (mis. "Rp 299.000").
String formatTransactionRupiah(double value) {
  final whole = value.round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < whole.length; index++) {
    final reversedIndex = whole.length - index;
    buffer.write(whole[index]);
    if (reversedIndex > 1 && reversedIndex % 3 == 1) {
      buffer.write('.');
    }
  }
  return 'Rp $buffer';
}

/// Format tanggal + jam: "DD MMM YYYY · HH:mm".
/// Dari timestamp transaksi nyata (paid_at). Tidak mengarang jam.
String formatTransactionDateTime(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = _kMonthAbbr[value.month - 1];
  final year = value.year.toString();
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day $month $year \u00b7 $hour:$minute';
}

/// Label tanggal+jam untuk baris transaksi (dipakai bersama halaman Membership
/// & Semua Transaksi). Pakai [paidAt] bila ada (transaksi lunas), else
/// [createdAt] (pending/cancelled/expired -> pakai waktu dibuat). Kalau dua-
/// duanya null -> "Menunggu pembayaran" sebagai fallback. Tidak mengarang waktu.
String transactionDateLabel({DateTime? paidAt, DateTime? createdAt}) {
  final ts = paidAt ?? createdAt;
  if (ts == null) return 'Menunggu pembayaran';
  return formatTransactionDateTime(ts);
}

/// Mapping label status ke teks yang tampil ke user (status internal di DB
/// TIDAK diubah — cuma tampilannya). completed/paid -> "SUCCESS".
String transactionStatusDisplayLabel(String status) {
  switch (status.toLowerCase()) {
    case 'completed':
    case 'paid':
      return 'SUCCESS';
    default:
      return status.toUpperCase();
  }
}

Color transactionStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'completed':
    case 'paid':
      return AppColors.success;
    case 'pending':
      return AppColors.info;
    default:
      return AppColors.textSecondary;
  }
}

/// Kartu satu baris riwayat transaksi (reusable): ikon + judul + tanggal/jam +
/// nominal + badge status. Semua nilai diformat di call site (data nyata).
/// [onTap] opsional: bila diisi, kartu bisa diklik (mis. buka struk).
class MemberTransactionTile extends StatelessWidget {
  const MemberTransactionTile({
    super.key,
    required this.title,
    required this.amountLabel,
    required this.dateLabel,
    required this.status,
    this.onTap,
  });

  final String title;
  final String amountLabel;
  final String dateLabel;
  final String status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.receipt_long_rounded),
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
                  dateLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amountLabel,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                transactionStatusDisplayLabel(status),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: transactionStatusColor(status),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: card,
    );
  }
}

/// Apakah status transaksi tergolong SUCCESS (lunas).
bool isTransactionSuccess(String status) {
  final normalized = status.toLowerCase();
  return normalized == 'completed' || normalized == 'paid';
}

/// Tampilkan detail transaksi SUCCESS sebagai bottom sheet bergaya struk.
/// Semua nilai dari data nyata yang dioper — tidak ada dummy. [invoiceCode]
/// = reference_code transaksi (nomor invoice). [paidAt] boleh null.
void showTransactionReceiptSheet(
  BuildContext context, {
  required String planName,
  required double amount,
  required String status,
  required String invoiceCode,
  DateTime? paidAt,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _TransactionReceiptSheet(
      planName: planName,
      amount: amount,
      status: status,
      invoiceCode: invoiceCode,
      paidAt: paidAt,
    ),
  );
}

class _TransactionReceiptSheet extends StatelessWidget {
  const _TransactionReceiptSheet({
    required this.planName,
    required this.amount,
    required this.status,
    required this.invoiceCode,
    required this.paidAt,
  });

  final String planName;
  final double amount;
  final String status;
  final String invoiceCode;
  final DateTime? paidAt;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            // Ikon + judul struk
            Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: transactionStatusColor(status).withValues(alpha: 0.15),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.check_circle_rounded,
                  color: transactionStatusColor(status),
                  size: 30,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                'Struk Pembayaran',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                formatTransactionRupiah(amount),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            const SizedBox(height: 18),
            const Divider(color: Color(0xFF262626), height: 1),
            const SizedBox(height: 14),
            _receiptRow(context, 'Paket', planName),
            _receiptRow(context, 'Nominal', formatTransactionRupiah(amount)),
            _receiptRow(
              context,
              'Tanggal & Waktu',
              paidAt != null ? formatTransactionDateTime(paidAt!) : '-',
            ),
            _receiptRow(
              context,
              'Status',
              transactionStatusDisplayLabel(status),
              valueColor: transactionStatusColor(status),
            ),
            _receiptRow(context, 'No. Invoice', invoiceCode, mono: true),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.surfaceSoft,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Tutup',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _receiptRow(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
    bool mono = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: valueColor ?? AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontFamily: mono ? 'monospace' : null,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
