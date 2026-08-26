import 'package:egg_gym/app/routes/app_routes.dart';
import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/core/utils/membership_duration_label.dart';
import 'package:egg_gym/core/utils/membership_primary_benefit.dart';
import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:egg_gym/data/services/backend_payment_service.dart';
import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:egg_gym/presentation/widgets/common/decorated_screen.dart';
import 'package:egg_gym/presentation/widgets/common/detail_screen_header.dart';
import 'package:egg_gym/presentation/widgets/common/egg_button.dart';
import 'package:egg_gym/presentation/widgets/common/egg_card.dart';
import 'package:egg_gym/presentation/widgets/common/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MembershipPackagesPage extends StatefulWidget {
  const MembershipPackagesPage({super.key});

  @override
  State<MembershipPackagesPage> createState() => _MembershipPackagesPageState();
}

class _MembershipPackagesPageState extends State<MembershipPackagesPage> {
  final BackendPaymentService _paymentService = BackendPaymentService();

  bool _initialized = false;
  bool _isLoadingPlans = false;
  bool _plansLoaded = false;
  MembershipPlan? _selectedPlan;
  String _source = 'member';
  String? _plansError;
  List<MembershipPlan> _livePlans = const [];

  bool get _canCheckout =>
      _source == 'member' && AppSessionService.instance.isMemberAuthenticated;
  List<MembershipPlan> get _displayPlans => _livePlans;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initialized) {
      return;
    }

    final argument = Get.arguments;

    if (argument is MembershipPlan) {
      _selectedPlan = argument;
    } else if (argument is Map<String, dynamic> &&
        argument['plan'] is MembershipPlan) {
      _selectedPlan = argument['plan'] as MembershipPlan;
    } else {
      _selectedPlan = null;
    }

    if (argument is Map<String, dynamic>) {
      final mappedSource = argument['source'];
      if (mappedSource is String && mappedSource.isNotEmpty) {
        _source = mappedSource;
      }
    }

    _initialized = true;
    _loadLivePlans();
  }

  Future<void> _loadLivePlans() async {
    if (_isLoadingPlans) {
      return;
    }

    setState(() {
      _isLoadingPlans = true;
      _plansLoaded = false;
      _plansError = null;
    });

    try {
      final plans = await _paymentService.getPublicMembershipPlans();

      if (!mounted) {
        return;
      }

      final matchedPlan = _matchSelectedPlan(plans);

      setState(() {
        _livePlans = plans;
        if (matchedPlan != null) {
          _selectedPlan = matchedPlan;
        } else if (plans.isNotEmpty) {
          _selectedPlan = plans.firstWhere(
            (plan) => plan.isHighlighted,
            orElse: () => plans.first,
          );
        } else {
          _selectedPlan = null;
        }
      });
    } on PaymentApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _plansError = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _plansError =
            'Daftar paket membership belum bisa dimuat. Silakan coba lagi.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPlans = false;
          _plansLoaded = true;
        });
      }
    }
  }

  MembershipPlan? _matchSelectedPlan(List<MembershipPlan> plans) {
    final selectedPlan = _selectedPlan;
    if (selectedPlan == null) return null;
    for (final plan in plans) {
      if (selectedPlan.backendId != null &&
          plan.backendId == selectedPlan.backendId) {
        return plan;
      }

      if (selectedPlan.slug != null &&
          plan.slug != null &&
          plan.slug == selectedPlan.slug) {
        return plan;
      }

      if (plan.title == selectedPlan.title) {
        return plan;
      }
    }

    return null;
  }

  String _durationValue(MembershipPlan plan) {
    return membershipDurationLabel(
      durationDays: plan.durationDays,
      billingPeriod: plan.billingPeriod,
    );
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Get.back();
    } else {
      Get.offAllNamed(AppRoutes.memberShell);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = _displayPlans;
    final selectedPlan = _selectedPlan;

    return DecoratedScreen(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          DetailScreenHeader(
            title: 'Membership Packages',
            subtitle: !_canCheckout
                ? 'Login sebagai member diperlukan untuk melanjutkan pembayaran.'
                : null,
          ),
          if (!_plansLoaded && plans.isEmpty) ...[
            const SizedBox(height: 72),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 16),
            Text(
              'Memuat paket membership...',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ] else if (_plansError != null && plans.isEmpty) ...[
            const SizedBox(height: 32),
            EggCard(
              child: Column(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.error,
                    size: 34,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _plansError!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.45,
                        ),
                  ),
                  const SizedBox(height: 18),
                  EggButton.primary(
                    label: 'Coba Lagi',
                    onPressed: _isLoadingPlans ? null : _loadLivePlans,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            EggButton.secondary(label: 'Kembali', onPressed: _goBack),
          ] else if (_plansLoaded && plans.isEmpty) ...[
            const SizedBox(height: 32),
            EggCard(
              child: Column(
                children: [
                  const Icon(
                    Icons.card_membership_outlined,
                    color: AppColors.textSecondary,
                    size: 36,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Belum ada paket membership yang tersedia.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            EggButton.secondary(label: 'Kembali', onPressed: _goBack),
          ] else ...[
            // Badge SYNCED BACKEND + tombol refresh dihapus (tidak ada di Figma).
            // Data paket tetap di-load di background (initState). Error tetap
            // ditampilkan agar user tahu bila gagal memuat.
            if (_plansError != null) ...[
              const SizedBox(height: 12),
              Text(
                _plansError!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
              ),
            ],
            const SizedBox(height: 20),
            if (selectedPlan != null)
              EggCard(
                highlight: true,
                padding: const EdgeInsets.all(12),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    // Gradient gelap (kecoklatan -> hitam) + outline tipis gold,
                    // seragam dgn card "STATUS KEANGGOTAAN" di halaman Membership.
                    // Warna teks ikut disesuaikan agar kontras di background gelap;
                    // konten teksnya tetap sama.
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
                        'CURRENT SELECTION',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        selectedPlan.title,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _PackageStat(
                              label: 'Durasi',
                              value: _durationValue(selectedPlan),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _PackageStat(
                              label: 'Benefit',
                              value: membershipPrimaryBenefit(
                                selectedPlan.features,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _PackageStat(
                              label: 'Harga',
                              value: selectedPlan.priceLabel,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            SizedBox(height: selectedPlan != null ? 18 : 8),
            ...plans.map(
              (plan) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _MembershipPackageCard(
                  plan: plan,
                  selected: plan.backendId == selectedPlan?.backendId &&
                      plan.title == selectedPlan?.title,
                  onTap: () => setState(() => _selectedPlan = plan),
                ),
              ),
            ),
            const SizedBox(height: 4),
            EggButton.primary(
              label: !_canCheckout
                  ? 'Masuk untuk Lanjutkan'
                  : 'Lanjut ke Pembayaran',
              onPressed: selectedPlan == null
                  ? null
                  : () {
                      if (!_canCheckout) {
                        Get.offAllNamed(AppRoutes.login);
                        return;
                      }

                      Get.toNamed(
                        AppRoutes.paymentCheckout,
                        arguments: <String, dynamic>{
                          'plan': selectedPlan,
                          'source': _source,
                        },
                      );
                    },
            ),
            const SizedBox(height: 10),
            EggButton.secondary(
              label: 'Kembali',
              onPressed: _goBack,
            ),
          ],
        ],
      ),
    );
  }
}

class _MembershipPackageCard extends StatelessWidget {
  const _MembershipPackageCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final MembershipPlan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final highlighted = selected;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: EggCard(
        highlight: highlighted,
        padding: const EdgeInsets.all(12),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: highlighted
                ? const LinearGradient(
                    colors: [Color(0xFFFFD54D), AppColors.accentDeep],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [AppColors.surfaceMuted, Color(0xFF171717)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            border: Border.all(
              color: highlighted
                  ? Colors.white.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PACKAGE OPTION',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: highlighted
                          ? AppColors.background.withValues(alpha: 0.72)
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.9,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      plan.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: highlighted
                                ? AppColors.background
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  if (plan.isBestSeller)
                    StatusChip(
                      label: 'TERLARIS',
                      color:
                          highlighted ? AppColors.background : AppColors.accent,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${plan.priceLabel}${plan.periodLabel}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: highlighted
                          ? AppColors.background
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              if (plan.features.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...plan.features.map(
                  (benefit) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: highlighted
                              ? AppColors.background
                              : AppColors.accent,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            benefit,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: highlighted
                                          ? AppColors.background
                                              .withValues(alpha: 0.8)
                                          : AppColors.textSecondary,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  StatusChip(
                    label: selected ? 'SELECTED' : 'AVAILABLE',
                    color: highlighted
                        ? AppColors.background
                        : AppColors.textSecondary,
                  ),
                  const Spacer(),
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: highlighted
                        ? AppColors.background
                        : AppColors.textSecondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PackageStat extends StatelessWidget {
  const _PackageStat({
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
                ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
