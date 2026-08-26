import 'package:egg_gym/app/routes/app_routes.dart';
import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/core/utils/membership_duration_label.dart';
import 'package:egg_gym/presentation/widgets/common/brand_logo.dart';
import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class GuestMembershipTabV2 extends StatelessWidget {
  const GuestMembershipTabV2({
    super.key,
    required this.plans,
    required this.isLoading,
    required this.loadError,
    required this.onRetry,
  });

  final List<MembershipPlan> plans;
  final bool isLoading;
  final String? loadError;
  final Future<void> Function() onRetry;

  void _openLogin() => Get.offAllNamed(AppRoutes.login);

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: onRetry,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
        children: [
          _MembershipGuestHeader(onLogin: _openLogin),
          const SizedBox(height: 26),
          const _MembershipHero(),
          const SizedBox(height: 22),
          _MembershipAuthCard(onPressed: _openLogin),
          const SizedBox(height: 28),
          const Text(
            'PAKET MEMBERSHIP',
            style: TextStyle(
              color: Color(0xFF938B77),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          if (isLoading && plans.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            )
          else if (plans.isEmpty)
            _MembershipEmptyState(
              hasError: loadError != null,
              onRetry: onRetry,
            )
          else ...[
            if (loadError != null) ...[
              _MembershipLoadNotice(onRetry: onRetry),
              const SizedBox(height: 14),
            ],
            ...plans.map(
              (plan) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _MembershipPackageCard(
                  plan: plan,
                  onChoose: _openLogin,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          const _TransactionLockedState(),
        ],
      ),
    );
  }
}

class _MembershipGuestHeader extends StatelessWidget {
  const _MembershipGuestHeader({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Expanded(child: BrandLogo(compact: true, showTagline: false)),
          FilledButton(
            onPressed: onLogin,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.background,
              minimumSize: const Size(80, 40),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            child: const Text(
              'Masuk',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      );
}

class _MembershipHero extends StatelessWidget {
  const _MembershipHero();

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 226),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF202020), Color(0xFF111111)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -10,
                top: -20,
                child: Icon(
                  Icons.bookmark_rounded,
                  size: 155,
                  color: Colors.white.withValues(alpha: 0.045),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 3, color: AppColors.accent),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(26, 25, 24, 25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EXCLUSIVE MEMBERSHIP',
                      style: TextStyle(
                        color: Color(0xFF9B927D),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.9,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Invest in Your\nPrime Performance',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        height: 1.22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    SizedBox(height: 14),
                    Text(
                      'Pilih paket yang sesuai dengan tujuan fitness Anda dan nikmati fasilitas EggGym sebagai member.',
                      style: TextStyle(
                        color: Color(0xFFB8B09F),
                        fontSize: 11,
                        height: 1.55,
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

class _MembershipAuthCard extends StatelessWidget {
  const _MembershipAuthCard({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 10),
        decoration: BoxDecoration(
          color: const Color(0xFF292929),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF343434)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: Color(0xFF343434),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.login_rounded,
                    color: AppColors.accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mulai Perjalanan Anda',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Daftar atau masuk untuk mengambil paket membership.',
                        style: TextStyle(
                          color: Color(0xFFA79F8D),
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 43,
              child: FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                child: const Text(
                  'Daftar Sekarang',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      );
}

class _MembershipPackageCard extends StatelessWidget {
  const _MembershipPackageCard({
    required this.plan,
    required this.onChoose,
  });

  final MembershipPlan plan;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(19, 20, 19, 18),
          decoration: BoxDecoration(
            color: const Color(0xFF202020),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFF2B2B2B)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _periodHeading(plan),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF99917E),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.star_border_rounded,
                    color: Color(0xFF99917E),
                    size: 19,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                plan.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      plan.priceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 30,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      plan.periodLabel.trim().isEmpty
                          ? ''
                          : plan.periodLabel.trim(),
                      style: const TextStyle(
                        color: Color(0xFF9D9583),
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              if (plan.features.isNotEmpty) ...[
                const SizedBox(height: 24),
                ...plan.features.map(
                  (feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 11),
                    child: _PackageBenefit(label: feature),
                  ),
                ),
              ],
              const SizedBox(height: 13),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton(
                  onPressed: onChoose,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE5DFD2),
                    side: const BorderSide(color: Color(0xFF51482B)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const _ChoosePackageLabel(),
                ),
              ),
            ],
          ),
        ),
        if (plan.isBestSeller)
          Positioned(
            top: -9,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'TERLARIS',
                  style: TextStyle(
                    color: AppColors.background,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _periodHeading(MembershipPlan value) {
    return membershipDurationLabel(
      durationDays: value.durationDays,
      billingPeriod: value.billingPeriod,
    ).toUpperCase();
  }
}

class _ChoosePackageLabel extends StatelessWidget {
  const _ChoosePackageLabel();

  @override
  Widget build(BuildContext context) => const Text(
        'Pilih Paket',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
      );
}

class _PackageBenefit extends StatelessWidget {
  const _PackageBenefit({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            color: const Color(0xFFD7C82E),
            size: 15,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFFC8C1B2),
                fontSize: 10,
                height: 1.4,
              ),
            ),
          ),
        ],
      );
}

class _TransactionLockedState extends StatelessWidget {
  const _TransactionLockedState();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF181818),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF252525)),
        ),
        child: const Row(
          children: [
            Icon(Icons.lock_outline_rounded,
                color: Color(0xFF777062), size: 22),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Riwayat Transaksi',
                    style: TextStyle(
                      color: Color(0xFFC0B9AB),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Login sebagai member untuk melihat riwayat transaksi.',
                    style: TextStyle(
                      color: Color(0xFF777062),
                      fontSize: 10,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _MembershipEmptyState extends StatelessWidget {
  const _MembershipEmptyState({required this.hasError, required this.onRetry});

  final bool hasError;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        decoration: BoxDecoration(
          color: const Color(0xFF191919),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF252525)),
        ),
        child: Column(
          children: [
            const Icon(Icons.card_membership_rounded,
                color: Color(0xFF777062), size: 34),
            const SizedBox(height: 10),
            Text(
              hasError
                  ? 'Paket membership belum dapat dimuat.'
                  : 'Belum ada paket membership aktif.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF9A9384), fontSize: 11),
            ),
            if (hasError) ...[
              const SizedBox(height: 7),
              TextButton(onPressed: onRetry, child: const Text('Coba Lagi')),
            ],
          ],
        ),
      );
}

class _MembershipLoadNotice extends StatelessWidget {
  const _MembershipLoadNotice({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFF211F18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF3D361B)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                color: AppColors.accent, size: 16),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Sebagian data Guest belum dapat diperbarui.',
                style: TextStyle(color: Color(0xFFC0B8A5), fontSize: 9),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Muat Ulang')),
          ],
        ),
      );
}
