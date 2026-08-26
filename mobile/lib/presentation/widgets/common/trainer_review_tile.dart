import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/data/services/backend_rating_service.dart';
import 'package:egg_gym/presentation/widgets/common/initial_avatar.dart';
import 'package:flutter/material.dart';

/// Kartu satu review trainer (avatar inisial + nama + bintang + komentar).
///
/// Widget presentasi reusable: dipakai section "Recent Feedback" di Trainer
/// Detail dan halaman "Semua Ulasan". Data dari [TrainerRatingData] nyata.
class TrainerReviewTile extends StatelessWidget {
  const TrainerReviewTile({super.key, required this.review});

  final TrainerRatingData review;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: AppColors.surfaceSoft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InitialAvatar(name: review.memberName, radius: 14),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    review.memberName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Row(
                  children: List.generate(5, (index) {
                    final filled = index < review.rating;
                    return Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 14,
                      color: AppColors.accent,
                    );
                  }),
                ),
              ],
            ),
            if (review.testimonial != null &&
                review.testimonial!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                review.testimonial!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
