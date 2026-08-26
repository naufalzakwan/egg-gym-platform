import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/data/services/backend_member_service.dart';
import 'package:egg_gym/presentation/widgets/common/decorated_screen.dart';
import 'package:egg_gym/presentation/widgets/common/egg_card.dart';
import 'package:egg_gym/presentation/widgets/common/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MemberSessionDetailPage extends StatelessWidget {
  const MemberSessionDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final argument = Get.arguments;
    final sessionTitle =
        argument is Map<String, dynamic> ? argument['sessionTitle'] : 'Sesi';
    final sessionFocus =
        argument is Map<String, dynamic> ? argument['sessionFocus'] : null;
    final exercises = argument is Map<String, dynamic>
        ? argument['exercises'] as List<MemberExerciseData>?
        : null;
    final sessionStatus =
        argument is Map<String, dynamic> ? argument['sessionStatus'] : 'active';

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
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detail Sesi',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      'Mode baca - Pelatih Anda mengontrol daftar periksa ini',
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
          EggCard(
            highlight: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sessionTitle,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          if (sessionFocus != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              sessionFocus,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    StatusChip(
                      label: sessionStatus == 'completed' ? 'SELESAI' : 'AKTIF',
                      color: sessionStatus == 'completed'
                          ? AppColors.success
                          : AppColors.accent,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          EggCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Workout Plan',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.visibility_rounded,
                              size: 14, color: AppColors.accent),
                          const SizedBox(width: 4),
                          Text(
                            'READ ONLY',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Pelatih Anda mengontrol daftar periksa ini. Status latihan akan diperbarui otomatis saat pelatih memberikan verifikasi.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                ),
                const SizedBox(height: 16),
                if (exercises != null && exercises.isNotEmpty)
                  ...exercises.map((exercise) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ExerciseReadOnlyTile(exercise: exercise),
                      ))
                else
                  Text(
                    'Belum ada latihan dalam sesi ini.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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

class _ExerciseReadOnlyTile extends StatelessWidget {
  const _ExerciseReadOnlyTile({required this.exercise});

  final MemberExerciseData exercise;

  @override
  Widget build(BuildContext context) {
    final isCompleted = exercise.isFullyCompleted;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCompleted
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.divider,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted ? AppColors.success : AppColors.surfaceSoft,
              border: Border.all(
                color:
                    isCompleted ? AppColors.success : AppColors.textSecondary,
                width: 2,
              ),
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check_rounded,
                      size: 16, color: AppColors.background)
                  : Text(
                      '${exercise.order}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  exercise.subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          StatusChip(
            label: isCompleted
                ? 'SELESAI'
                : '${exercise.completedSets}/${exercise.totalSets}',
            color: isCompleted ? AppColors.success : AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
