import 'package:egg_gym/app/routes/app_routes.dart';
import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:egg_gym/presentation/widgets/common/decorated_screen.dart';
import 'package:egg_gym/presentation/widgets/common/detail_screen_header.dart';
import 'package:egg_gym/presentation/widgets/common/egg_button.dart';
import 'package:egg_gym/presentation/widgets/common/egg_card.dart';
import 'package:egg_gym/presentation/widgets/common/initial_avatar.dart';
import 'package:egg_gym/presentation/widgets/common/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LiveTrainingSessionPage extends StatelessWidget {
  const LiveTrainingSessionPage({super.key});

  _LiveSessionArguments _resolveArguments() {
    final argument = Get.arguments;
    WorkoutSession? workout;
    ScheduleSession? schedule;
    var role = 'member';
    var programMode = '';

    if (argument is WorkoutSession) {
      workout = argument;
    } else if (argument is ScheduleSession) {
      schedule = argument;
      role = 'trainer';
    } else if (argument is Map<String, dynamic>) {
      if (argument['workout'] is WorkoutSession) {
        workout = argument['workout'] as WorkoutSession;
      }
      if (argument['session'] is ScheduleSession) {
        schedule = argument['session'] as ScheduleSession;
      }
      final mappedRole = argument['role'];
      final mappedMode = argument['programMode'];
      if (mappedRole is String && mappedRole.isNotEmpty) role = mappedRole;
      if (mappedMode is String && mappedMode.isNotEmpty) {
        programMode = mappedMode;
      }
    }
    return _LiveSessionArguments(
      workout: workout,
      schedule: schedule,
      role: role,
      programMode: programMode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _resolveArguments();
    if (data.workout == null && data.schedule == null) {
      return DecoratedScreen(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const DetailScreenHeader(
              title: 'Sesi Latihan',
              subtitle: 'Data sesi aktif tidak tersedia.',
            ),
            const SizedBox(height: 20),
            EggCard(
              child: Text(
                'Tidak ada sesi atau program aktual yang dikirim ke halaman ini. Buka sesi dari jadwal atau tracker program terbaru.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
              ),
            ),
            const SizedBox(height: 18),
            EggButton.secondary(label: 'Kembali', onPressed: () => Get.back()),
          ],
        ),
      );
    }

    final schedule = data.schedule;
    final workout = data.workout;
    final isTrainer = data.role == 'trainer';
    final title = workout?.title ?? schedule?.sessionTitle ?? 'Sesi PT';
    final focus = workout?.focus ?? schedule?.note;

    return DecoratedScreen(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          DetailScreenHeader(
            title: isTrainer ? 'Sesi PT Aktif' : 'Sesi Latihan Aktif',
            subtitle: 'Informasi sesi yang diterima dari jadwal atau program.',
          ),
          const SizedBox(height: 20),
          EggCard(
            highlight: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusChip(label: workout?.statusLabel ?? schedule!.status),
                const SizedBox(height: 16),
                if (schedule != null) ...[
                  Row(
                    children: [
                      InitialAvatar(name: schedule.clientName, radius: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              schedule.clientName,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              schedule.timeRange,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                            if (schedule.location.trim().isNotEmpty)
                              Text(
                                schedule.location,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                ],
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (focus != null && focus.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    focus,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.45,
                        ),
                  ),
                ],
                if (workout != null &&
                    workout.progressText.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    workout.progressText,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          EggCard(
            child: Text(
              'Detail progres live, timer, set, beban, dan exercise tidak tersedia dari argumen sesi ini. Tidak ada nilai perkiraan yang ditampilkan.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
            ),
          ),
          const SizedBox(height: 20),
          EggButton.primary(
            label: isTrainer ? 'Buka Detail Sesi PT' : 'Buka Tracker Program',
            onPressed: () => Get.toNamed(
              isTrainer
                  ? AppRoutes.trainerSessionDetail
                  : AppRoutes.programTracker,
              arguments: isTrainer
                  ? <String, dynamic>{'session': schedule}
                  : <String, dynamic>{
                      'workout': workout,
                      'programMode': data.programMode,
                    },
            ),
          ),
          const SizedBox(height: 10),
          EggButton.secondary(label: 'Kembali', onPressed: () => Get.back()),
        ],
      ),
    );
  }
}

class _LiveSessionArguments {
  const _LiveSessionArguments({
    required this.workout,
    required this.schedule,
    required this.role,
    required this.programMode,
  });

  final WorkoutSession? workout;
  final ScheduleSession? schedule;
  final String role;
  final String programMode;
}
