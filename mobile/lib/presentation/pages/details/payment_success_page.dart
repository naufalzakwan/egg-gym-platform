import 'dart:async';
import 'dart:ui' as ui;

import 'package:egg_gym/app/routes/app_routes.dart';
import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/presentation/widgets/common/brand_logo.dart';
import 'package:egg_gym/core/formatters/app_date_formatter.dart';
import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:egg_gym/data/services/backend_payment_service.dart';
import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:egg_gym/domain/repositories/demo_repository.dart';
import 'package:egg_gym/presentation/widgets/common/decorated_screen.dart';
import 'package:egg_gym/presentation/widgets/common/detail_screen_header.dart';
import 'package:egg_gym/presentation/widgets/common/egg_button.dart';
import 'package:egg_gym/presentation/widgets/common/egg_card.dart';
import 'package:egg_gym/presentation/widgets/common/status_chip.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PaymentSuccessPage extends StatefulWidget {
  const PaymentSuccessPage({super.key});

  @override
  State<PaymentSuccessPage> createState() => _PaymentSuccessPageState();
}

class _PaymentSuccessPageState extends State<PaymentSuccessPage> {
  final BackendPaymentService _paymentService = BackendPaymentService();

  bool _initialized = false;
  bool _isLoading = false;
  String? _statusError;
  String _source = 'member';
  MembershipPlan? _selectedPlan;
  PakasirCheckoutSession? _checkoutSession;
  MemberTransactionSnapshot? _transaction;
  Timer? _pollingTimer;
  // Timer 1 detik khusus untuk update tampilan countdown MM:SS.
  Timer? _countdownTimer;
  // Cegah spam _refreshStatus saat countdown menyentuh 0 (sekali saja).
  bool _expiryRefreshTriggered = false;
  // Key untuk RepaintBoundary card resi (capture PNG saat unduh).
  final GlobalKey _receiptBoundaryKey = GlobalKey();
  // Cegah double-tap saat proses simpan resi berjalan.
  bool _isSavingReceipt = false;

  bool get _isCompleted {
    final normalized =
        (_transaction?.status ?? _checkoutSession?.status ?? '').toLowerCase();
    return normalized == 'completed' || normalized == 'paid';
  }

  /// Status EXPIRED dari BACKEND (sumber kebenaran, bukan sekadar countdown UI).
  bool get _statusIsExpired {
    final normalized =
        (_transaction?.status ?? _checkoutSession?.status ?? '').toLowerCase();
    return normalized == 'expired';
  }

  /// Sisa waktu sampai expired_at (instant absolut dari server). Device clock
  /// dipakai untuk "now"; kalau miring, countdown bisa sedikit meleset TAPI
  /// status EXPIRED final tetap ditentukan server (lazy-flip + polling 5s).
  Duration get _remaining {
    final exp = _checkoutSession?.expiredAt;
    if (exp == null) return Duration.zero;
    final diff = exp.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Tampilkan state "Kedaluwarsa": bila backend sudah expired, ATAU countdown
  /// device sudah habis (0) sambil menunggu backend flip lewat polling.
  bool get _showExpired =>
      _statusIsExpired ||
      (_checkoutSession?.expiredAt != null && _remaining == Duration.zero);

  String _formatCountdown(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    if (_checkoutSession?.expiredAt == null) return;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _isCompleted || _statusIsExpired) {
        _countdownTimer?.cancel();
        _countdownTimer = null;
        return;
      }

      // Countdown baru menyentuh 0 -> paksa satu refresh supaya backend
      // lazy-flip pending->expired langsung terbaca (tak perlu tunggu poll 5s).
      if (_remaining == Duration.zero && !_expiryRefreshTriggered) {
        _expiryRefreshTriggered = true;
        _refreshStatus();
      }

      setState(() {}); // update tampilan MM:SS tiap detik
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

    if (argument is Map<String, dynamic>) {
      final mappedSource = argument['source'];
      if (mappedSource is String && mappedSource.isNotEmpty) {
        _source = mappedSource;
      }

      if (argument['plan'] is MembershipPlan) {
        _selectedPlan = argument['plan'] as MembershipPlan;
      }

      final checkoutMap = argument['checkout'];
      if (checkoutMap is Map<String, dynamic>) {
        _checkoutSession = PakasirCheckoutSession.fromMap(checkoutMap);
      }
    }

    _selectedPlan ??= plans.firstWhere(
      (plan) => plan.isHighlighted,
      orElse: () => plans.first,
    );

    _initialized = true;

    if (_source == 'member' && _checkoutSession != null) {
      _refreshStatus();
      _startCountdown();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    final checkoutSession = _checkoutSession;
    if (_isLoading || checkoutSession == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _statusError = null;
    });

    try {
      final transaction = await _paymentService
          .getTransactionByReference(checkoutSession.referenceCode);

      if (!mounted) {
        return;
      }

      setState(() {
        _transaction = transaction;
      });

      _syncPollingState();
    } on PaymentApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusError = error.message;
      });

      _syncPollingState();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusError =
            'Status pembayaran belum bisa di-refresh. Pastikan backend Laravel aktif dan histori transaksi member bisa diambil.';
      });

      _syncPollingState();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _copyReference() async {
    final referenceCode = _checkoutSession?.referenceCode;
    if (referenceCode == null || referenceCode.isEmpty) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: referenceCode));

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reference code berhasil disalin.')),
    );
  }

  /// [SANDBOX/DEV ONLY] Picu simulasi pembayaran berhasil di backend lalu
  /// refresh status (reuse _refreshStatus) supaya UI langsung jadi "Lunas".
  /// Hanya dipanggil dari tombol yang tampil di build non-release; backend juga
  /// menolak (403) di production sebagai lapis pengaman kedua.
  Future<void> _simulatePayment() async {
    final checkoutSession = _checkoutSession;
    if (_isLoading || checkoutSession == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _statusError = null;
    });

    try {
      await _paymentService
          .simulatePaymentSuccess(checkoutSession.referenceCode);
    } on PaymentApiException catch (error) {
      if (!mounted) return;
      setState(() => _statusError = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _statusError =
          'Simulasi gagal. Pastikan backend Laravel aktif (non-production).');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }

    // Refresh status memakai logic yang sudah ada -> UI update ke "Lunas".
    if (mounted && _statusError == null) {
      await _refreshStatus();
    }
  }

  void _syncPollingState() {
    if (!mounted) {
      return;
    }

    if (_isCompleted) {
      _pollingTimer?.cancel();
      _pollingTimer = null;
      return;
    }

    if (_pollingTimer != null) {
      return;
    }

    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _isCompleted || _isLoading) {
        return;
      }

      _refreshStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final checkout = _checkoutSession;
    final plan = _selectedPlan;

    if (_source != 'member' || checkout == null || plan == null) {
      return DecoratedScreen(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const DetailScreenHeader(
              title: 'Payment Status',
              subtitle:
                  'Halaman status pembayaran hanya boleh dibuka dari checkout member.',
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
                    'Flow status pembayaran dibatasi untuk member yang masuk dari checkout.',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Kalau halaman ini terbuka tanpa data checkout, kita arahkan kembali ke daftar paket agar alurnya tetap rapi.',
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
              label: 'Kembali ke Membership',
              onPressed: () => Get.offAllNamed(
                AppRoutes.membershipPackages,
                arguments: const {'source': 'member'},
              ),
            ),
          ],
        ),
      );
    }

    // Layout SUKSES di-redesign terpisah (Figma). State pending/expired tetap
    // memakai layout lama di bawahnya (countdown/QR/simulate tak berubah).
    if (_isCompleted) {
      return _buildCompletedView(context, checkout, plan);
    }

    final title = _isCompleted
        ? 'Pembayaran Berhasil'
        : _showExpired
            ? 'Pembayaran Kedaluwarsa'
            : 'Menunggu Pembayaran';
    final subtitle = _isCompleted
        ? 'Backend sudah menandai transaksi ini completed. Membership baru harusnya ikut aktif sesuai aturan backend.'
        : _showExpired
            ? 'Waktu pembayaran sudah habis. Kode/QR ini tidak berlaku lagi. Silakan buat pembayaran baru dari halaman paket.'
            : 'Selesaikan pembayaran sebelum waktu habis. Status akan diperbarui otomatis setelah pembayaran diproses.';
    final total =
        checkout.totalPayment ?? (checkout.amount + (checkout.fee ?? 0));

    return DecoratedScreen(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const DetailScreenHeader(title: 'Payment Status'),
          const SizedBox(height: 14),
          EggCard(
            highlight: true,
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: _isCompleted
                      ? const [Color(0xFF62D981), Color(0xFF1F5B2F)]
                      : _showExpired
                          ? const [Color(0xFF6B6B6B), Color(0xFF2A2A2A)]
                          : const [Color(0xFFFFD54D), AppColors.accentDeep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.background.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Icon(
                      _isCompleted
                          ? Icons.check_rounded
                          : _showExpired
                              ? Icons.timer_off_rounded
                              : Icons.schedule_rounded,
                      size: 42,
                      color: AppColors.background,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.background,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.background.withValues(alpha: 0.78),
                          height: 1.45,
                        ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _formatCurrency(total),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: AppColors.background,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  // Countdown MM:SS: hanya saat pending & belum habis. Anchor =
                  // expiredAt (instant server). Update tiap detik via _countdownTimer.
                  if (!_isCompleted &&
                      !_showExpired &&
                      _checkoutSession?.expiredAt != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'BAYAR SEBELUM',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.background.withValues(alpha: 0.72),
                            letterSpacing: 1,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatCountdown(_remaining),
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AppColors.background,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      StatusChip(
                        label: _showExpired
                            ? 'KEDALUWARSA'
                            : (_transaction?.status ?? checkout.status)
                                .toUpperCase(),
                        color: AppColors.background,
                      ),
                      StatusChip(
                        label: checkout.providerMethod.toUpperCase(),
                        color: AppColors.background,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_statusError != null) ...[
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
                      _statusError!,
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
          const SizedBox(height: 18),
          EggCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ringkasan Transaksi',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 14),
                _SuccessLine(label: 'Paket', value: plan.title),
                const SizedBox(height: 10),
                _SuccessLine(
                  label: 'Status Pembayaran',
                  value:
                      (_transaction?.status ?? checkout.status).toUpperCase(),
                ),
                const SizedBox(height: 10),
                _SuccessLine(label: 'Reference', value: checkout.referenceCode),
                const SizedBox(height: 10),
                _SuccessLine(label: 'Provider', value: checkout.providerName),
                const SizedBox(height: 10),
                _SuccessLine(
                    label: 'Payment code', value: checkout.paymentCode),
                const SizedBox(height: 10),
                _SuccessLine(
                  label: 'Paid at',
                  value: _transaction?.paidAt != null
                      ? _formatDateTime(_transaction!.paidAt!)
                      : 'Belum dibayar',
                ),
                const SizedBox(height: 10),
                _SuccessLine(
                  label: 'Expired at',
                  value: checkout.expiredAt != null
                      ? _formatDateTime(checkout.expiredAt!)
                      : 'Belum tersedia',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (checkout.providerMethod == 'qris' && checkout.qrString != null)
            EggCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'QR Pembayaran',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 14),
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
                          data: checkout.qrString!,
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
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            EggCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kode Virtual Account',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Text(
                      checkout.paymentCode,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.accent,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          // [SANDBOX/DEV ONLY] Tombol simulasi hanya di build non-release dan
          // hanya saat belum lunas. Di app produksi (kReleaseMode) tidak muncul,
          // dan backend juga menolak (403) sebagai lapis pengaman kedua.
          if (!kReleaseMode && !_isCompleted) ...[
            EggButton.primary(
              label: _isLoading
                  ? 'Memproses...'
                  : 'Simulasikan Pembayaran Berhasil',
              onPressed: _isLoading ? () {} : _simulatePayment,
            ),
            const SizedBox(height: 10),
          ],
          // Tombol "Refresh Status Pembayaran" (state pending) dihapus —
          // halaman sudah auto-refresh tiap 5 detik di background. Tombol
          // primer kini hanya untuk state SUKSES ("Kembali" -> Home) supaya
          // alur setelah pembayaran berhasil tetap bisa menuju Home.
          if (_isCompleted) ...[
            EggButton.primary(
              label: _isLoading ? 'Memuat Status...' : 'Kembali',
              onPressed: _isLoading
                  // Pembayaran sukses: kembali ke Home. offAllNamed membangun
                  // MemberShellPage baru sehingga initState -> _loadLiveData()
                  // fetch ulang dashboard (card membership langsung ter-update
                  // ke paket terbaru) dan mendarat di tab Home (index 0).
                  ? () {}
                  : () => Get.offAllNamed(
                        AppRoutes.memberShell,
                        arguments: const {'source': 'member'},
                      ),
            ),
            const SizedBox(height: 10),
          ],
          EggButton.secondary(
            label: _isCompleted ? 'Salin Reference' : 'Kembali ke Checkout',
            onPressed: _isCompleted ? _copyReference : () => Get.back(),
          ),
        ],
      ),
    );
  }

  /// Layout SUKSES (Figma): aksen kuning/gold, badge centang bulat + watermark
  /// nama paket, subjudul ramah, card ringkas, 2 tombol. Semua data dari
  /// transaksi/checkout yang sudah ada (tidak menyentuh logic pembayaran).
  /// Capture card resi (RepaintBoundary) jadi PNG lalu simpan ke galeri device
  /// via package `gal`. Izin galeri ditangani gal (hasAccess/requestAccess);
  /// kalau ditolak -> pesan jelas, tidak crash. Tidak menyentuh data transaksi.
  Future<void> _saveReceipt() async {
    if (_isSavingReceipt) return;
    setState(() => _isSavingReceipt = true);

    try {
      // 1) Cek/minta izin galeri (built-in gal). Ditolak -> pesan ramah.
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          if (!mounted) return;
          _showReceiptSnack(
            'Izin galeri ditolak. Aktifkan izin foto/galeri di pengaturan untuk menyimpan resi.',
          );
          return;
        }
      }

      // 2) Capture RepaintBoundary -> PNG bytes. pixelRatio 3x agar tajam.
      final boundaryContext = _receiptBoundaryKey.currentContext;
      final renderObject = boundaryContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        if (!mounted) return;
        _showReceiptSnack('Gagal menyiapkan gambar resi. Coba lagi.');
        return;
      }

      final image = await renderObject.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        if (!mounted) return;
        _showReceiptSnack('Gagal membuat gambar resi. Coba lagi.');
        return;
      }

      final pngBytes = byteData.buffer.asUint8List();

      // 3) Simpan ke galeri. Nama file pakai reference_code biar mudah dicari.
      final refCode = _checkoutSession?.referenceCode ?? 'transaksi';
      await Gal.putImageBytes(pngBytes, name: 'resi-egggym-$refCode');

      if (!mounted) return;
      _showReceiptSnack('Resi berhasil disimpan ke galeri.');
    } on GalException catch (e) {
      if (!mounted) return;
      // Pesan spesifik dari gal (accessDenied/notEnoughSpace/dll) - tidak crash.
      _showReceiptSnack('Gagal menyimpan resi: ${e.type.message}');
    } catch (_) {
      if (!mounted) return;
      _showReceiptSnack('Gagal menyimpan resi. Coba lagi.');
    } finally {
      if (mounted) setState(() => _isSavingReceipt = false);
    }
  }

  void _showReceiptSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildCompletedView(
    BuildContext context,
    PakasirCheckoutSession checkout,
    MembershipPlan plan,
  ) {
    final total =
        checkout.totalPayment ?? (checkout.amount + (checkout.fee ?? 0));
    final paidAtText = _transaction?.paidAt != null
        ? _formatDateTime(_transaction!.paidAt!)
        : '-';
    final methodLabel =
        checkout.providerMethod.toUpperCase().replaceAll('_', ' ');
    // Nama member yang login (dari session) untuk info pemesan di resi.
    final rawName = AppSessionService.instance.currentSession?.name?.trim();
    final memberName = (rawName != null && rawName.isNotEmpty) ? rawName : null;

    return DecoratedScreen(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const DetailScreenHeader(
            title: 'Pembayaran Berhasil',
            subtitle: 'Keanggotaan kamu sudah aktif.',
          ),
          const SizedBox(height: 20),
          // ── Hero: badge centang bulat kuning + watermark nama paket ──
          EggCard(
            highlight: true,
            padding: const EdgeInsets.all(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF161616),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF262626)),
                ),
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  alignment: Alignment.center,
                  children: [
                    // Watermark nama paket (nice-to-have) - transparan, di belakang.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Align(
                          alignment: Alignment.center,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              plan.title.toUpperCase(),
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 72,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                                color: AppColors.accent.withValues(alpha: 0.06),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        // Badge centang bulat kuning/gold.
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accent.withValues(alpha: 0.15),
                            border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.5),
                              width: 2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.check_rounded,
                            size: 46,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Pembayaran Berhasil',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Selamat! Keanggotaan ${plan.title} Anda telah aktif.',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1.45,
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          // ── Card resi (di-capture jadi PNG saat "Unduh Resi") ──
          // RepaintBoundary HANYA membungkus Container resi ini. Sengaja TIDAK
          // pakai EggCard karena box-shadow besar EggCard meluber keluar bounds
          // -> bikin ruang kosong berlebih di hasil capture. Background solid
          // (opaque) supaya PNG tidak transparan.
          RepaintBoundary(
            key: _receiptBoundaryKey,
            child: Container(
              width: double.infinity,
              // Padding lebih lega di semua sisi (gaya struk ShopeePay).
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              decoration: BoxDecoration(
                color: const Color(0xFF161616),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF262626)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header: identitas gym + badge LUNAS ──
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const BrandLogo(compact: true, showTagline: false),
                            Text(
                              'Struk Pembayaran Membership',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      // Badge LUNAS (kontekstual: card ini hanya untuk COMPLETED).
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'LUNAS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: Color(0xFF0E0E0E),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Jarak lebih lega setelah header sebelum list info.
                  const Divider(color: Color(0xFF262626), height: 40),
                  // ── Info pemesan + detail transaksi ──
                  if (memberName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child:
                          _SuccessLine(label: 'Nama Member', value: memberName),
                    ),
                  _SuccessLine(
                      label: 'Nomor Pesanan', value: checkout.referenceCode),
                  const SizedBox(height: 18),
                  _SuccessLine(label: 'Paket', value: plan.title),
                  const SizedBox(height: 18),
                  _SuccessLine(label: 'Tanggal', value: paidAtText),
                  const SizedBox(height: 18),
                  _SuccessLine(label: 'Metode Pembayaran', value: methodLabel),
                  const Divider(color: Color(0xFF262626), height: 40),
                  // ── Rincian nominal: harga paket + biaya admin (bila ada) ──
                  _SuccessLine(
                      label: 'Harga Paket',
                      value: _formatCurrency(checkout.amount)),
                  // Biaya admin/layanan HANYA bila fee nyata dari backend > 0
                  // (tidak dihitung manual/hardcode).
                  if (checkout.fee != null && checkout.fee! > 0) ...[
                    const SizedBox(height: 18),
                    _SuccessLine(
                        label: 'Biaya Admin',
                        value: _formatCurrency(checkout.fee!)),
                  ],
                  const Divider(color: Color(0xFF262626), height: 40),
                  // ── Total ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          'Total',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        _formatCurrency(total),
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                    ],
                  ),
                  // Jarak lebih lega setelah Total sebelum footer.
                  const SizedBox(height: 28),
                  // ── Footer ──
                  Center(
                    child: Text(
                      'Struk ini adalah bukti pembayaran yang sah.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // ── Tombol ──
          EggButton.primary(
            label: 'Kembali ke Beranda',
            trailingIcon: Icons.arrow_forward_rounded,
            // Home: offAllNamed bangun MemberShellPage baru -> initState fetch
            // ulang dashboard (card membership ter-update) & mendarat di Home.
            onPressed: () => Get.offAllNamed(
              AppRoutes.memberShell,
              arguments: const {'source': 'member'},
            ),
          ),
          const SizedBox(height: 10),
          EggButton.secondary(
            label: _isSavingReceipt ? 'Menyimpan...' : 'Unduh Resi Pembayaran',
            icon: Icons.download_rounded,
            onPressed: _isSavingReceipt ? () {} : _saveReceipt,
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

  String _formatDateTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${AppDateFormatter.date(value)} | $hour:$minute';
  }
}

class _SuccessLine extends StatelessWidget {
  const _SuccessLine({
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
