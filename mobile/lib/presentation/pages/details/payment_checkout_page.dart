import 'dart:async';

import 'package:egg_gym/app/routes/app_routes.dart';
import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/core/utils/membership_duration_label.dart';
import 'package:egg_gym/core/formatters/app_date_formatter.dart';
import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:egg_gym/data/services/backend_payment_service.dart';
import 'package:egg_gym/data/services/public_settings_service.dart';
import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:egg_gym/domain/repositories/demo_repository.dart';
import 'package:egg_gym/presentation/widgets/common/decorated_screen.dart';
import 'package:egg_gym/presentation/widgets/common/detail_screen_header.dart';
import 'package:egg_gym/presentation/widgets/common/egg_button.dart';
import 'package:egg_gym/presentation/widgets/common/egg_card.dart';
import 'package:egg_gym/presentation/widgets/common/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PaymentCheckoutPage extends StatefulWidget {
  const PaymentCheckoutPage({super.key});

  @override
  State<PaymentCheckoutPage> createState() => _PaymentCheckoutPageState();
}

class _PaymentCheckoutPageState extends State<PaymentCheckoutPage> {
  final BackendPaymentService _paymentService = BackendPaymentService();

  bool _initialized = false;
  bool _isSubmitting = false;
  late MembershipPlan _selectedPlan;
  int _selectedMethodIndex = 0;
  String _source = 'member';
  String? _errorMessage;
  PakasirCheckoutSession? _checkoutSession;

  bool get _canCheckout =>
      _source == 'member' && AppSessionService.instance.isMemberAuthenticated;

  List<_PaymentMethodOption> get _methods =>
      PublicSettingsService.instance.settings.value.paymentChannels
          .map((channel) => _PaymentMethodOption.fromChannel(channel))
          .toList(growable: false);

  @override
  void initState() {
    super.initState();
    PublicSettingsService.instance.settings.addListener(_settingsChanged);
  }

  @override
  void dispose() {
    PublicSettingsService.instance.settings.removeListener(_settingsChanged);
    super.dispose();
  }

  void _settingsChanged() {
    if (!mounted || _checkoutSession != null) return;
    final methods = _methods;
    setState(() {
      if (_selectedMethodIndex >= methods.length) _selectedMethodIndex = 0;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initialized) {
      return;
    }

    final plans = context.read<DemoRepository>().getMembershipPlans();
    final argument = Get.arguments;

    if (argument is MembershipPlan) {
      _selectedPlan = argument;
    } else if (argument is Map<String, dynamic> &&
        argument['plan'] is MembershipPlan) {
      _selectedPlan = argument['plan'] as MembershipPlan;
    } else {
      _selectedPlan = plans.firstWhere(
        (plan) => plan.isHighlighted,
        orElse: () => plans.first,
      );
    }

    if (argument is Map<String, dynamic>) {
      final mappedSource = argument['source'];
      if (mappedSource is String && mappedSource.isNotEmpty) {
        _source = mappedSource;
      }
    }

    _initialized = true;
  }

  _PaymentBreakdown _breakdownForPlan(MembershipPlan plan) {
    if (plan.priceValue != null) {
      return _PaymentBreakdown(
        subtotal: plan.priceValue!,
        estimatedFee: (plan.priceValue! * 0.01).roundToDouble(),
      );
    }

    switch (plan.title) {
      case 'Starter Pack':
        return const _PaymentBreakdown(
          subtotal: 299000,
          estimatedFee: 2990,
        );
      case 'Elite Member':
        return const _PaymentBreakdown(
          subtotal: 549000,
          estimatedFee: 5490,
        );
      default:
        return const _PaymentBreakdown(
          subtotal: 1900000,
          estimatedFee: 19000,
        );
    }
  }

  int _membershipPlanIdForPlan(MembershipPlan plan) {
    if (plan.backendId != null) {
      return plan.backendId!;
    }

    switch (plan.title) {
      case 'Starter Pack':
        return 1;
      case 'Elite Member':
        return 2;
      default:
        return 3;
    }
  }

  Future<void> _createCheckout() async {
    if (_isSubmitting || _methods.isEmpty) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final session = await _paymentService.createMembershipCheckout(
        membershipPlanId: _membershipPlanIdForPlan(_selectedPlan),
        paymentMethod: _methods[_selectedMethodIndex].backendMethod,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _checkoutSession = session;
      });
    } on PaymentApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            'Checkout belum berhasil dibuat. Periksa koneksi lalu coba lagi.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _copyPaymentCode() async {
    final paymentCode = _checkoutSession?.paymentCode;
    if (paymentCode == null || paymentCode.isEmpty) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: paymentCode));

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Kode pembayaran berhasil disalin.'),
      ),
    );
  }

  void _openStatusPage() {
    final session = _checkoutSession;
    if (session == null) {
      return;
    }

    Get.toNamed(
      AppRoutes.paymentSuccess,
      arguments: <String, dynamic>{
        'plan': _selectedPlan,
        'source': _source,
        'checkout': session.toMap(),
      },
    );
  }

  /// Batalkan pesanan (transaksi pending aktif). Konfirmasi dulu, lalu ubah
  /// status di backend jadi 'cancelled' (tetap tercatat di riwayat), kemudian
  /// arahkan ke halaman pemilihan paket.
  Future<void> _cancelOrder() async {
    final session = _checkoutSession;
    if (session == null || _isSubmitting) {
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Batalkan Pesanan'),
        content: const Text(
          'Yakin batalkan pesanan ini? Kode pembayaran yang sudah dibuat tidak '
          'bisa dipakai lagi, tapi transaksinya tetap tercatat di riwayat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Tidak'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await _paymentService.cancelPendingPayment(session.referenceCode);
      if (!mounted) {
        return;
      }
      // Kembali ke halaman pemilihan paket supaya bisa pilih paket lain.
      Get.offNamed(
        AppRoutes.membershipPackages,
        arguments: {'source': _source},
      );
    } on PaymentApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Gagal membatalkan pesanan. Silakan coba lagi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_canCheckout) {
      return DecoratedScreen(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const DetailScreenHeader(
              title: 'Payment Checkout',
              subtitle:
                  'Checkout hanya boleh diakses dari flow member yang sudah login.',
            ),
            const SizedBox(height: 20),
            EggCard(
              highlight: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const StatusChip(label: 'ACCESS LOCKED'),
                  const SizedBox(height: 14),
                  Text(
                    'Checkout hanya tersedia untuk member yang sudah login.',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Silakan masuk sebagai member untuk membuat kode pembayaran dan melanjutkan checkout.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.45,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            EggButton.primary(
              label: 'Masuk Sekarang',
              onPressed: () => Get.offAllNamed(AppRoutes.login),
            ),
            const SizedBox(height: 10),
            EggButton.secondary(
              label: 'Kembali ke Paket',
              onPressed: () => Get.back(),
            ),
          ],
        ),
      );
    }

    final methods = _methods;
    final safeMethodIndex =
        _selectedMethodIndex.clamp(0, methods.isEmpty ? 0 : methods.length - 1);
    final method = methods.isEmpty
        ? (_checkoutSession == null
            ? null
            : _PaymentMethodOption.fromSnapshot(
                _checkoutSession!.paymentMethod))
        : methods[safeMethodIndex];
    final defaultBreakdown = _breakdownForPlan(_selectedPlan);
    final subtotal = _checkoutSession?.amount ?? defaultBreakdown.subtotal;
    final fee = _checkoutSession?.fee ?? defaultBreakdown.estimatedFee;
    final total = _checkoutSession?.totalPayment ?? (subtotal + fee);

    return DecoratedScreen(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const DetailScreenHeader(title: 'Payment Checkout'),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              const StatusChip(label: '1. Paket Dipilih'),
              StatusChip(
                label: _checkoutSession == null
                    ? '2. Buat Kode Bayar'
                    : '2. Kode Aktif',
                color: AppColors.success,
              ),
              StatusChip(
                label: _checkoutSession == null
                    ? '3. Menunggu Bayar'
                    : '3. Cek Status',
                color: _checkoutSession == null
                    ? AppColors.textSecondary
                    : AppColors.info,
              ),
            ],
          ),
          const SizedBox(height: 20),
          EggCard(
            highlight: true,
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                // Gradient gelap (kecoklatan -> hitam) + outline tipis gold,
                // seragam dgn card "STATUS KEANGGOTAAN" di halaman Membership.
                // Warna teks disesuaikan agar kontras di background gelap;
                // konten/struktur kotak DURASI & STATUS tetap sama.
                gradient: const LinearGradient(
                  colors: [AppColors.accentBronze, Color(0xFF191919)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ORDER SUMMARY',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _selectedPlan.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _CheckoutStat(
                          label: 'Durasi',
                          value: membershipDurationLabel(
                            durationDays: _selectedPlan.durationDays,
                            billingPeriod: _selectedPlan.billingPeriod,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _CheckoutStat(
                          label: 'Harga',
                          value: _selectedPlan.priceLabel,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                'Metode Pembayaran',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              Text(
                'PILIH SALAH SATU',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (methods.isEmpty)
            const EggCard(
                child: Text(
                    'Metode pembayaran Membership belum tersedia. Coba refresh aplikasi.'))
          else
            ...List.generate(
              methods.length,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PaymentMethodTile(
                  option: methods[index],
                  selected: index == safeMethodIndex,
                  locked: _checkoutSession != null,
                  onTap: () {
                    if (_checkoutSession != null) {
                      return;
                    }

                    setState(() => _selectedMethodIndex = index);
                  },
                ),
              ),
            ),
          const SizedBox(height: 6),
          EggCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rincian Pembayaran',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 14),
                _CheckoutLine(
                    label: 'Subtotal paket', value: _formatCurrency(subtotal)),
                const SizedBox(height: 10),
                _CheckoutLine(
                    label: 'Fee provider', value: _formatCurrency(fee)),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Divider(color: AppColors.divider, height: 1),
                ),
                _CheckoutLine(
                  label: 'Total pembayaran',
                  value: _formatCurrency(total),
                  emphasize: true,
                ),
              ],
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            EggCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_checkoutSession != null) ...[
            const SizedBox(height: 16),
            _ActiveCheckoutCard(
              plan: _selectedPlan,
              method: method!,
              session: _checkoutSession!,
              onCopyCode: _copyPaymentCode,
            ),
          ],
          const SizedBox(height: 18),
          EggButton.primary(
            label: _isSubmitting
                ? 'Membuat Kode Pembayaran...'
                : (_checkoutSession == null
                    ? 'Buat Kode Pembayaran'
                    : 'Lihat Status Pembayaran'),
            onPressed:
                _isSubmitting || (methods.isEmpty && _checkoutSession == null)
                    ? () {}
                    : (_checkoutSession == null
                        ? _createCheckout
                        : _openStatusPage),
          ),
          const SizedBox(height: 10),
          EggButton.secondary(
            label: _checkoutSession == null
                ? 'Kembali ke Paket'
                : 'Batalkan Pesanan Ini',
            onPressed: _isSubmitting
                ? () {}
                : () {
                    if (_checkoutSession == null) {
                      Get.back();
                      return;
                    }
                    // Ada transaksi pending aktif -> batalkan (konfirmasi dulu).
                    _cancelOrder();
                  },
          ),
        ],
      ),
    );
  }

  String _formatCurrency(num value) {
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
}

class _ActiveCheckoutCard extends StatefulWidget {
  const _ActiveCheckoutCard({
    required this.plan,
    required this.method,
    required this.session,
    required this.onCopyCode,
  });

  final MembershipPlan plan;
  final _PaymentMethodOption method;
  final PakasirCheckoutSession session;
  final Future<void> Function() onCopyCode;

  @override
  State<_ActiveCheckoutCard> createState() => _ActiveCheckoutCardState();
}

class _ActiveCheckoutCardState extends State<_ActiveCheckoutCard> {
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    // Countdown MM:SS berbasis expired_at (instant server). Hanya jalan bila
    // status pending & ada expired_at. Tidak mengubah data apa pun; murni UI.
    if (widget.session.status.toLowerCase() == 'pending' &&
        widget.session.expiredAt != null) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {}); // refresh tampilan MM:SS tiap detik
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Duration get _remaining {
    final exp = widget.session.expiredAt;
    if (exp == null) return Duration.zero;
    final diff = exp.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  bool get _isExpired =>
      widget.session.expiredAt != null && _remaining == Duration.zero;

  String _formatCountdown(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final method = widget.method;
    final plan = widget.plan;
    final isQris = session.providerMethod == 'qris' && session.qrString != null;

    return EggCard(
      highlight: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(method.icon, color: AppColors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kode Pembayaran Aktif',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${session.providerName.toUpperCase()} | ${method.title}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              StatusChip(
                label:
                    _isExpired ? 'KEDALUWARSA' : session.status.toUpperCase(),
                color: _isExpired
                    ? AppColors.textSecondary
                    : (session.status.toLowerCase() == 'pending'
                        ? AppColors.info
                        : AppColors.success),
              ),
            ],
          ),
          // Countdown MM:SS: hanya saat pending & belum habis. Anchor expired_at
          // (instant server). 00:00 -> tampil "Kedaluwarsa" (badge + info bar).
          if (session.status.toLowerCase() == 'pending' &&
              session.expiredAt != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: _isExpired
                    ? AppColors.textSecondary.withValues(alpha: 0.12)
                    : AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isExpired ? Icons.timer_off_rounded : Icons.timer_outlined,
                    size: 18,
                    color:
                        _isExpired ? AppColors.textSecondary : AppColors.accent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isExpired ? 'Kedaluwarsa' : 'Bayar sebelum',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _isExpired
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (!_isExpired) ...[
                    const SizedBox(width: 10),
                    Text(
                      _formatCountdown(_remaining),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        fontFeatures: const [
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (isQris) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  QrImageView(
                    data: session.qrString!,
                    size: 210,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Scan QR ini dari mobile banking atau e-wallet yang support QRIS.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.black87,
                          height: 1.45,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(label: 'Paket', value: plan.title),
                const SizedBox(height: 10),
                _InfoRow(label: 'Reference', value: session.referenceCode),
                const SizedBox(height: 10),
                _InfoRow(label: 'Payment code', value: session.paymentCode),
                const SizedBox(height: 10),
                _InfoRow(
                  label: 'Expired',
                  value: session.expiredAt != null
                      ? _formatDateTime(session.expiredAt!)
                      : 'Belum ada',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          EggButton.secondary(
            label: 'Salin Payment Code',
            icon: Icons.copy_rounded,
            onPressed: () => widget.onCopyCode(),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${AppDateFormatter.date(value)} | $hour:$minute';
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.option,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final _PaymentMethodOption option;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Opacity(
        opacity: locked && !selected ? 0.6 : 1,
        child: EggCard(
          highlight: selected,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: selected
                        ? const [Color(0xFFFFD54D), AppColors.accentDeep]
                        : const [AppColors.accentBronze, AppColors.surfaceSoft],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  option.icon,
                  color: selected ? AppColors.background : AppColors.accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            option.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        StatusChip(
                          label: option.badge,
                          color:
                              selected ? AppColors.success : AppColors.accent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      option.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? AppColors.accent : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckoutStat extends StatelessWidget {
  const _CheckoutStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutLine extends StatelessWidget {
  const _CheckoutLine({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: emphasize
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
                ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: emphasize ? AppColors.accent : AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
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
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}

class _PaymentMethodOption {
  const _PaymentMethodOption({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.backendMethod,
  });

  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final String backendMethod;

  factory _PaymentMethodOption.fromChannel(MembershipPaymentChannel channel) {
    final isQris = channel.code == 'qris';
    return _PaymentMethodOption(
      title: channel.label,
      subtitle: channel.description,
      badge: isQris ? 'QRIS' : 'VA',
      icon: isQris ? Icons.qr_code_2_rounded : Icons.account_balance_rounded,
      backendMethod: channel.code,
    );
  }

  factory _PaymentMethodOption.fromSnapshot(String code) =>
      _PaymentMethodOption(
        title:
            code == 'qris' ? 'QRIS' : code.replaceAll('_', ' ').toUpperCase(),
        subtitle: 'Metode transaksi tersimpan',
        badge: code == 'qris' ? 'QRIS' : 'VA',
        icon: code == 'qris'
            ? Icons.qr_code_2_rounded
            : Icons.account_balance_rounded,
        backendMethod: code,
      );
}

class _PaymentBreakdown {
  const _PaymentBreakdown({
    required this.subtotal,
    required this.estimatedFee,
  });

  final double subtotal;
  final double estimatedFee;
}
