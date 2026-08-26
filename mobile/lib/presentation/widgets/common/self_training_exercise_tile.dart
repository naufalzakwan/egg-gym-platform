import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/data/services/backend_self_training_service.dart';
import 'package:flutter/material.dart';

/// Kartu gerakan pada halaman Latihan Mandiri (Movement Checklist).
///
/// Widget presentasi reusable: dipakai halaman detail program & halaman detail
/// sesi. Logic centang/hapus tetap di halaman pemanggil lewat callback
/// [onToggle] & [onDelete] -- widget ini tidak memanggil service apa pun.
class SelfTrainingExerciseTile extends StatelessWidget {
  const SelfTrainingExerciseTile({
    super.key,
    required this.exercise,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final SelfTrainingExerciseData exercise;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    // Load bersifat opsional (String?, mis. "85kg"); kalau kosong tampil "-",
    // tidak dikarang. Sets & reps selalu ada (int).
    final loadText = (exercise.load != null && exercise.load!.trim().isNotEmpty)
        ? exercise.load!.trim()
        : '-';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: exercise.isCompleted
            ? AppColors.success.withValues(alpha: 0.08)
            : AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: exercise.isCompleted
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.divider,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checkbox KOTAK (bukan lingkaran). Tercentang: kuning solid + centang;
          // belum: outline abu.
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: exercise.isCompleted
                    ? AppColors.accent
                    : Colors.transparent,
                border: Border.all(
                  color: exercise.isCompleted
                      ? AppColors.accent
                      : AppColors.textSecondary,
                  width: 2,
                ),
              ),
              child: exercise.isCompleted
                  ? const Icon(Icons.check_rounded,
                      size: 16, color: AppColors.background)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (exercise.equipmentName != null) ...[
                  Text(
                    exercise.equipmentName!,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 3),
                ],
                // Nama gerakan
                Text(
                  exercise.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        decoration: exercise.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                ),
                // Target otot (kecil abu) - hanya bila ada di data.
                if (exercise.targetMuscle != null &&
                    exercise.targetMuscle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    exercise.targetMuscle!.trim(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                  ),
                ],
                const SizedBox(height: 10),
                // Tiga kotak metrik: SETS / REPS / LOAD (LOAD beraksen kuning).
                Row(
                  children: [
                    _MetricBox(label: 'SETS', value: '${exercise.sets}'),
                    const SizedBox(width: 8),
                    _MetricBox(label: 'REPS', value: '${exercise.reps}'),
                    const SizedBox(width: 8),
                    _MetricBox(label: 'LOAD', value: loadText, accent: true),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // Aksi edit gerakan (pensil).
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined,
                color: AppColors.textSecondary, size: 18),
          ),
          // Aksi hapus gerakan.
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onDelete,
            icon: const Icon(Icons.close_rounded,
                color: AppColors.textSecondary, size: 18),
          ),
        ],
      ),
    );
  }
}

/// Kotak metrik kecil: label abu di atas, nilai lebih besar di bawah.
/// [accent] true memberi aksen kuning (dipakai untuk LOAD).
class _MetricBox extends StatelessWidget {
  const _MetricBox({
    required this.label,
    required this.value,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: accent
                ? AppColors.accent.withValues(alpha: 0.4)
                : AppColors.divider,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: accent ? AppColors.accent : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
