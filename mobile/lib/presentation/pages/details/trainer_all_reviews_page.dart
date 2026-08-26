import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/data/services/backend_rating_service.dart';
import 'package:egg_gym/presentation/widgets/common/decorated_screen.dart';
import 'package:egg_gym/presentation/widgets/common/trainer_review_tile.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Halaman "Semua Ulasan" satu trainer.
///
/// Argumen: `{ 'trainerName': String, 'reviews': List<TrainerRatingData> }`.
/// Data review dioper dari section "Recent Feedback" (sudah di memori) ->
/// TANPA re-fetch. Reuse [TrainerReviewTile] yang sama dengan halaman detail.
class TrainerAllReviewsPage extends StatelessWidget {
  const TrainerAllReviewsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments;
    final trainerName = (args is Map && args['trainerName'] is String)
        ? args['trainerName'] as String
        : 'Trainer';
    final reviews = (args is Map && args['reviews'] is List<TrainerRatingData>)
        ? args['reviews'] as List<TrainerRatingData>
        : const <TrainerRatingData>[];

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Semua Ulasan',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      trainerName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (reviews.isEmpty)
            Text(
              'Belum ada ulasan.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            )
          else
            ...reviews.map((r) => TrainerReviewTile(review: r)),
        ],
      ),
    );
  }
}
