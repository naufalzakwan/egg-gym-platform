import 'package:egg_gym/app/routes/app_routes.dart';
import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:egg_gym/presentation/widgets/common/egg_button.dart';
import 'package:egg_gym/presentation/widgets/common/egg_card.dart';
import 'package:egg_gym/presentation/widgets/common/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class HomeHeroPanel extends StatelessWidget {
  const HomeHeroPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return EggCard(
      padding: const EdgeInsets.all(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 286),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [AppColors.accentBronze, Color(0xFF1A1A1A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -8,
              top: -18,
              child: Text(
                'EGG',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.05),
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const StatusChip(label: 'TRY THE EXPERIENCE'),
                const SizedBox(height: 28),
                Text(
                  'Train Hard.\nTrack Smart.',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Preview gym ecosystem, elite trainers, and membership flow before you sign in.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                ),
                const SizedBox(height: 16),
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HeroStatPill(label: 'Open 06.00'),
                    _HeroStatPill(label: '3 Elite Coach'),
                    _HeroStatPill(label: '3 Paket Demo'),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: EggButton.primary(
                        label: 'Daftar Sekarang',
                        onPressed: () => Get.offAllNamed(AppRoutes.login),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: EggButton.secondary(
                        label: 'Lihat Paket',
                        onPressed: () => Get.toNamed(
                          AppRoutes.membershipPackages,
                          arguments: const {'source': 'guest'},
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class LockedTimerPanel extends StatelessWidget {
  const LockedTimerPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return EggCard(
      child: Row(
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.18),
                width: 6,
              ),
              gradient: const RadialGradient(
                colors: [Color(0x221F1B10), Colors.transparent],
              ),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '00:00',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'LOCKED',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                        letterSpacing: 1.2,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart Workout Timer',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Login untuk membuka countdown, stopwatch, dan preset timer saat latihan.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 14),
                Text(
                  'MEMBER FEATURE',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LockedProgramTile extends StatelessWidget {
  const LockedProgramTile({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.accentBronze, AppColors.surfaceSoft],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.lock_rounded,
              color: AppColors.accent,
              size: 18,
            ),
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
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EquipmentPreviewCard extends StatelessWidget {
  const EquipmentPreviewCard({
    super.key,
    required this.equipment,
    this.source = 'guest',
  });

  final EquipmentInfo equipment;
  final String source;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Get.toNamed(
        AppRoutes.equipmentDetail,
        arguments: {
          'equipment': equipment,
          'source': source,
        },
      ),
      borderRadius: BorderRadius.circular(24),
      child: EggCard(
        child: Row(
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [AppColors.accentBronze, Color(0xFF1A1A1A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.fitness_center_rounded,
                size: 30,
                color: AppColors.accent,
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
                          equipment.name,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                      StatusChip(
                        label: equipment.category.toUpperCase(),
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    equipment.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Focus: ${equipment.focus}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.accent,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap untuk lihat detail alat',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
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
}

class PlanPreviewCard extends StatelessWidget {
  const PlanPreviewCard({super.key, required this.plan});

  final MembershipPlan plan;

  List<String> _features() {
    switch (plan.title) {
      case 'Starter Pack':
        return const ['Gym floor access', 'Locker access', 'Basic guidance'];
      case 'Elite Member':
        return const ['Priority PT', 'Sauna access', 'Premium amenities'];
      default:
        return const ['Annual saving', 'Premium support', 'All access'];
    }
  }

  @override
  Widget build(BuildContext context) {
    return EggCard(
      highlight: false,
      padding: const EdgeInsets.all(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 388),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            colors: [AppColors.surfaceMuted, Color(0xFF171717)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MEMBERSHIP ACCESS',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: plan.isHighlighted
                        ? AppColors.background.withValues(alpha: 0.72)
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: plan.isHighlighted
                              ? AppColors.background
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                if (plan.badge != null)
                  StatusChip(
                    label: plan.badge!,
                    color: plan.isHighlighted
                        ? AppColors.background
                        : AppColors.accent,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: plan.isHighlighted
                    ? AppColors.background.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: plan.isHighlighted
                      ? AppColors.background.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.04),
                ),
              ),
              child: Column(
                children: List.generate(
                  _features().length,
                  (index) {
                    final feature = _features()[index];
                    final isLast = index == _features().length - 1;

                    return Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: plan.isHighlighted
                                ? AppColors.background
                                : AppColors.accent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              feature,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: plan.isHighlighted
                                        ? AppColors.background
                                            .withValues(alpha: 0.8)
                                        : AppColors.textSecondary,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${plan.priceLabel}${plan.periodLabel}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: plan.isHighlighted
                        ? AppColors.background
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Get.toNamed(
                  AppRoutes.membershipPackages,
                  arguments: {
                    'plan': plan,
                    'source': 'guest',
                  },
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: plan.isHighlighted
                      ? AppColors.background
                      : AppColors.accent,
                  foregroundColor: plan.isHighlighted
                      ? AppColors.accent
                      : AppColors.background,
                  minimumSize: const Size.fromHeight(46),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text(
                  'Preview Paket',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroStatPill extends StatelessWidget {
  const _HeroStatPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
      ),
    );
  }
}
