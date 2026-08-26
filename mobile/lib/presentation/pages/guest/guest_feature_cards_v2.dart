import 'package:egg_gym/app/routes/app_routes.dart';
import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/core/utils/trainer_rating_display.dart';
import 'package:egg_gym/core/utils/trainer_tier.dart';
import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:egg_gym/presentation/widgets/common/egg_button.dart';
import 'package:egg_gym/presentation/widgets/common/egg_card.dart';
import 'package:egg_gym/presentation/widgets/common/initial_avatar.dart';
import 'package:egg_gym/presentation/widgets/common/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

void _openGuestTrainerDetail(TrainerProfile trainer) {
  Get.toNamed(
    AppRoutes.trainerProfileDetail,
    arguments: {
      'trainer': trainer,
      'source': 'guest',
    },
  );
}

class TrainerMiniCard extends StatelessWidget {
  const TrainerMiniCard({super.key, required this.trainer});

  final TrainerProfile trainer;

  @override
  Widget build(BuildContext context) {
    final tierLabel = trainerTierLabel(trainer.tier);
    return GestureDetector(
      onTap: () => _openGuestTrainerDetail(trainer),
      child: EggCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    colors: [AppColors.accentBronze, Color(0xFF1C1C1C)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: 14,
                      top: 10,
                      child: tierLabel == null
                          ? const SizedBox.shrink()
                          : StatusChip(label: tierLabel),
                    ),
                    Positioned(
                      left: 14,
                      top: 12,
                      child: Text(
                        'PT',
                        style:
                            Theme.of(context).textTheme.headlineLarge?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: InitialAvatar(name: trainer.name, radius: 38),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              trainer.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              trainer.specialty,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              trainerRatingDisplay(
                rating: trainer.rating,
                reviewsCount: trainer.reviewsCount,
              ),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class TrainerFeatureCard extends StatelessWidget {
  const TrainerFeatureCard({super.key, required this.trainer});

  final TrainerProfile trainer;

  @override
  Widget build(BuildContext context) {
    final tierLabel = trainerTierLabel(trainer.tier);
    return EggCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 240,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [AppColors.accentBronze, Color(0xFF191919)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 16,
                  top: 14,
                  child: Text(
                    'COACH',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.06),
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Positioned(
                  right: 14,
                  top: 14,
                  child: tierLabel == null
                      ? const SizedBox.shrink()
                      : StatusChip(label: tierLabel),
                ),
                Align(
                  alignment: Alignment.center,
                  child: InitialAvatar(name: trainer.name, radius: 42),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trainer.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        trainer.specialty,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            trainer.bio,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                size: 18,
                color: AppColors.accent,
              ),
              const SizedBox(width: 6),
              Text(
                trainerRatingDisplay(
                  rating: trainer.rating,
                  reviewsCount: trainer.reviewsCount,
                ),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: EggButton.primary(
                  label: 'LIHAT PROFIL',
                  onPressed: () => _openGuestTrainerDetail(trainer),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: EggButton.secondary(
                  label: 'LOGIN',
                  onPressed: () => Get.offAllNamed(AppRoutes.login),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MembershipFeatureCard extends StatelessWidget {
  const MembershipFeatureCard({super.key, required this.plan});

  final MembershipPlan plan;

  List<String> _benefits() {
    switch (plan.title) {
      case 'Starter Pack':
        return const [
          'Basic entry and onboarding',
          'Suitable for first-time gym members',
        ];
      case 'Elite Member':
        return const [
          'Priority booking and premium areas',
          'Best pick for regular training routine',
        ];
      default:
        return const [
          'Lower cost over long-term period',
          'Made for consistent yearly commitment',
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return EggCard(
      highlight: false,
      padding: const EdgeInsets.all(12),
      child: Container(
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
              'MEMBERSHIP OPTION',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: plan.isHighlighted
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
                          color: plan.isHighlighted
                              ? AppColors.background
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
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
            ..._benefits().map(
              (benefit) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: plan.isHighlighted
                          ? AppColors.background
                          : AppColors.accent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        benefit,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: plan.isHighlighted
                                  ? AppColors.background.withValues(alpha: 0.8)
                                  : AppColors.textSecondary,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            EggButton.secondary(
              label: 'Preview Paket',
              onPressed: () => Get.toNamed(
                AppRoutes.membershipPackages,
                arguments: {
                  'plan': plan,
                  'source': 'guest',
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
