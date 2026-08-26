import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/data/services/backend_payment_service.dart';
import 'package:egg_gym/presentation/pages/details/pending_payment_helper.dart';
import 'package:egg_gym/presentation/widgets/common/decorated_screen.dart';
import 'package:egg_gym/presentation/widgets/common/egg_button.dart';
import 'package:egg_gym/presentation/widgets/common/member_transaction_tile.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Halaman "Semua Transaksi" member.
///
/// Fetch SELURUH transaksi (limit null) dari endpoint transaksi yang sudah ada
/// (`getMemberTransactions`), reuse [MemberTransactionTile] + formatter bersama.
/// Tidak menambah endpoint baru & tidak mengubah logic transaksi.
class MemberAllTransactionsPage extends StatefulWidget {
  const MemberAllTransactionsPage({super.key});

  @override
  State<MemberAllTransactionsPage> createState() =>
      _MemberAllTransactionsPageState();
}

class _MemberAllTransactionsPageState extends State<MemberAllTransactionsPage> {
  final BackendPaymentService _paymentService = BackendPaymentService();

  bool _isLoading = true;
  String? _error;
  List<MemberTransactionListItem> _transactions = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await _paymentService.getMemberTransactions(limit: null);
      if (!mounted) return;
      setState(() {
        _transactions = items;
        _isLoading = false;
      });
    } on PaymentApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat transaksi. Pastikan backend aktif.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedScreen(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: 4),
              Text(
                'Semua Transaksi',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            _buildError(context)
          else if (_transactions.isEmpty)
            Text(
              'Belum ada riwayat transaksi membership.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            )
          else
            ..._transactions.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: MemberTransactionTile(
                  title: item.title,
                  amountLabel: formatTransactionRupiah(item.amount),
                  dateLabel: transactionDateLabel(
                    paidAt: item.paidAt,
                    createdAt: item.createdAt,
                  ),
                  status: item.status,
                  onTap: _tapHandlerFor(item),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Handler tap kartu: SUCCESS -> struk; PENDING -> reuse/regenerate via helper.
  /// Null (tidak diklik) bila tak ada reference_code.
  VoidCallback? _tapHandlerFor(MemberTransactionListItem item) {
    final ref = item.referenceCode;
    if (ref == null) return null;

    if (isTransactionSuccess(item.status)) {
      return () => showTransactionReceiptSheet(
            context,
            planName: item.title,
            amount: item.amount,
            status: item.status,
            invoiceCode: ref,
            paidAt: item.paidAt,
          );
    }

    if (item.status.toLowerCase() == 'pending') {
      return () => handlePendingPaymentTap(
            context,
            referenceCode: ref,
            isExpired: item.isExpired,
            amount: item.amount,
            status: item.status,
            paymentMethod: item.paymentMethod,
            qrString: item.qrString,
            paymentNumber: item.paymentNumber,
            expiredAt: item.expiredAt,
            onShouldRefresh: _load,
          );
    }

    return null;
  }

  Widget _buildError(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Icon(Icons.wifi_off_rounded,
            size: 44, color: AppColors.textSecondary),
        const SizedBox(height: 12),
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),
        EggButton.secondary(label: 'Coba Lagi', onPressed: _load),
      ],
    );
  }
}
