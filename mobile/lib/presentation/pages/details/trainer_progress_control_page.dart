import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/core/formatters/app_date_formatter.dart';
import 'package:egg_gym/data/services/backend_trainer_service.dart';
import 'package:egg_gym/presentation/widgets/common/decorated_screen.dart';
import 'package:egg_gym/presentation/widgets/common/egg_button.dart';
import 'package:egg_gym/presentation/widgets/common/egg_card.dart';
import 'package:egg_gym/presentation/widgets/common/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TrainerProgressControlPage extends StatefulWidget {
  const TrainerProgressControlPage({super.key});

  @override
  State<TrainerProgressControlPage> createState() =>
      _TrainerProgressControlPageState();
}

class _TrainerProgressControlPageState
    extends State<TrainerProgressControlPage> {
  final BackendTrainerService _trainerService = BackendTrainerService();

  TrainerProgramDetailData? _programDetail;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final role = _resolveRole();
    if (role != 'trainer') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Get.back();
          Get.snackbar(
            'Akses Ditolak',
            'Halaman Kontrol Progres PT hanya dapat diakses oleh Personal Trainer.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppColors.surface,
            colorText: AppColors.textPrimary,
          );
        }
      });
      return;
    }

    _loadProgramDetail();
  }

  String _resolveRole() {
    final argument = Get.arguments;
    if (argument is Map<String, dynamic>) {
      final role = argument['role'];
      if (role is String && role.isNotEmpty) {
        return role;
      }
    }
    return 'trainer';
  }

  int? get _trainingProgramId {
    final argument = Get.arguments;
    if (argument is Map<String, dynamic>) {
      final id = argument['trainingProgramId'];
      if (id is int) return id;
      if (id != null) return int.tryParse(id.toString());
    }
    return null;
  }

  Future<void> _loadProgramDetail() async {
    final programId = _trainingProgramId;
    if (programId == null) {
      setState(() {
        _errorMessage = 'Program ID tidak ditemukan.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final detail = await _trainerService.getProgramDetail(programId);
      debugPrint('DEBUG: _loadProgramDetail - Program loaded: ${detail.title}');
      for (final s in detail.sessions) {
        debugPrint(
            'DEBUG: _loadProgramDetail - Session ${s.sequenceOrder}: ${s.title} - status: ${s.status}');
      }
      if (!mounted) return;
      setState(() {
        _programDetail = detail;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('DEBUG: _loadProgramDetail failed: $error');
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _updateExerciseProgress(
    TrainerProgramSessionDetailData session,
    TrainerProgramExerciseDetailData exercise,
    int completedSets,
  ) async {
    debugPrint('DEBUG: _updateExerciseProgress called');
    debugPrint(
        'DEBUG: session.id=${session.id}, exercise.id=${exercise.id}, completedSets=$completedSets');

    setState(() => _isSubmitting = true);

    try {
      final result = await _trainerService.updateProgramSessionProgress(
        trainingProgramSessionId: session.id,
        exerciseId: exercise.id,
        completedSets: completedSets,
      );
      debugPrint('DEBUG: API call successful, result=${result.status}');
      if (!mounted) return;
      await _loadProgramDetail();
      debugPrint('DEBUG: _loadProgramDetail completed');
    } catch (error) {
      debugPrint('DEBUG: API call failed: $error');
      if (!mounted) return;
      Get.snackbar(
        'Gagal Update',
        error.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _completeSession(TrainerProgramSessionDetailData session) async {
    debugPrint(
        'DEBUG: _completeSession called for session ${session.id} - ${session.title}');
    setState(() => _isSubmitting = true);

    try {
      await _trainerService.completeProgramSessionProgress(session.id);
      debugPrint('DEBUG: completeSessionProgress API call successful');
      if (!mounted) return;
      await _loadProgramDetail();
      debugPrint('DEBUG: _loadProgramDetail completed after session complete');

      // Log all session statuses after reload
      if (_programDetail != null) {
        for (final s in _programDetail!.sessions) {
          debugPrint(
              'DEBUG: Session ${s.id} - ${s.title} - status: ${s.status}');
        }
      }

      Get.snackbar(
        'Sesi Selesai',
        'Sesi "${session.title}" telah diselesaikan. Sesi berikutnya akan terbuka.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
    } catch (error) {
      debugPrint('DEBUG: completeSession failed: $error');
      if (!mounted) return;
      Get.snackbar(
        'Gagal',
        error.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedScreen(
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError()
              : _programDetail == null
                  ? _buildEmpty()
                  : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            EggButton.secondary(
              label: 'Coba Lagi',
              onPressed: _loadProgramDetail,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fitness_center_rounded,
                size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              'Program tidak ditemukan',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),
            EggButton.secondary(
              label: 'Kembali',
              onPressed: () => Get.back(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final program = _programDetail!;
    final presentedSessions =
        sortTrainerProgramSessionsBySchedule(program.sessions);

    // Debug: log semua sesi dan statusnya
    debugPrint('DEBUG: _buildContent - Program: ${program.title}');
    for (final s in program.sessions) {
      debugPrint(
          'DEBUG: Session ${s.sequenceOrder} - ${s.title} - status: ${s.status} - isActive: ${s.isActive} - isLocked: ${s.isLocked}');
    }

    return ListView(
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
                    'Progressive Unlock',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (program.memberName != null)
                    Text(
                      'Member: ${program.memberName}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                ],
              ),
            ),
            IconButton(
              onPressed: _loadProgramDetail,
              icon: const Icon(Icons.refresh_rounded),
              color: AppColors.textSecondary,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _buildCompletionCard(program),
        const SizedBox(height: 18),
        ...presentedSessions.asMap().entries.map((entry) {
          final index = entry.key;
          final session = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildSessionCard(session, index),
          );
        }),
      ],
    );
  }

  Widget _buildCompletionCard(TrainerProgramDetailData program) {
    return EggCard(
      highlight: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COMPLETION STATUS',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            program.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '${program.completionPercent.round()}',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '%',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const Spacer(),
              Text(
                '${program.totalSessions} sesi | ${program.totalReservationDurationMinutes} menit',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: program.completionPercent / 100,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: AppColors.surfaceSoft,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(TrainerProgramSessionDetailData session, int index) {
    final isCompleted = session.isCompleted;
    final isActive = session.isActive;
    final isLocked = session.isLocked;

    return EggCard(
      highlight: isActive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? AppColors.success
                      : isActive
                          ? AppColors.accent
                          : AppColors.surfaceSoft,
                ),
                child: Icon(
                  isCompleted
                      ? Icons.check_rounded
                      : isLocked
                          ? Icons.lock_rounded
                          : Icons.play_arrow_rounded,
                  color: isCompleted || isActive
                      ? AppColors.background
                      : AppColors.textSecondary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session ${session.sequenceOrder}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      session.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (session.focus != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        session.focus!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                    if (session.reservationDate != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${AppDateFormatter.schedule(dateValue: session.reservationDate, startTime: session.reservationStartTime, endTime: session.reservationEndTime)} | ${(session.reservationStatus ?? '-').toUpperCase()}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              StatusChip(
                label: isCompleted
                    ? 'SELESAI'
                    : isActive
                        ? 'AKTIF'
                        : 'TERKUNCI',
                color: isCompleted
                    ? AppColors.success
                    : isActive
                        ? AppColors.accent
                        : AppColors.textSecondary,
              ),
            ],
          ),
          if (isCompleted) ...[
            const SizedBox(height: 12),
            Text(
              '${session.durationMinutes ?? 0} menit selesai | ${session.exercises.length} exercises',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.success,
                  ),
            ),
          ],
          if (isActive) ...[
            if (session.hasPendingReschedule) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Menunggu keputusan reschedule. Sesi tidak dapat dimulai atau diperbarui sebelum request diputuskan.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ] else if (!session.memberReady) ...[
              // Sesi sudah aktif/ter-unlock tapi member belum menekan
              // "Mulai Sesi" — trainer belum boleh mencentang exercise.
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.hourglass_top_rounded,
                        size: 18, color: AppColors.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Menunggu member menekan "Mulai Sesi" untuk sesi ini. '
                        'Kamu bisa mulai mencentang latihan setelah member menyiapkan sesi.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Text(
                '${session.completionPercent.round()}% selesai | ${session.exercises.length} exercises',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: session.completionPercent / 100,
                minHeight: 6,
                borderRadius: BorderRadius.circular(999),
                backgroundColor: AppColors.surfaceSoft,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.accent),
              ),
              const SizedBox(height: 16),
              ...session.exercises.map((exercise) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ExerciseTile(
                      exercise: exercise,
                      isSubmitting: _isSubmitting,
                      onSetSelected: (completedSets) => _updateExerciseProgress(
                          session, exercise, completedSets),
                    ),
                  )),
              const SizedBox(height: 12),
              EggButton.primary(
                label: 'Selesaikan Latihan',
                onPressed:
                    _isSubmitting ? () {} : () => _completeSession(session),
              ),
            ],
          ],
          if (isLocked) ...[
            const SizedBox(height: 12),
            Text(
              'Sesi berikutnya terbuka setelah sesi aktif selesai 100%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({
    required this.exercise,
    required this.isSubmitting,
    required this.onSetSelected,
  });

  final TrainerProgramExerciseDetailData exercise;
  final bool isSubmitting;
  final ValueChanged<int> onSetSelected;

  @override
  Widget build(BuildContext context) {
    final isCompleted = exercise.isFullyCompleted;
    final statusColor =
        isCompleted ? AppColors.success : AppColors.textSecondary;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: isSubmitting
                    ? null
                    : () {
                        if (isCompleted) {
                          // Uncheck: reset to 0
                          onSetSelected(0);
                        } else {
                          // Check: mark all sets as completed
                          onSetSelected(exercise.totalSets);
                        }
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        isCompleted ? AppColors.success : AppColors.surfaceSoft,
                    border: Border.all(
                      color: isCompleted
                          ? AppColors.success
                          : AppColors.textSecondary,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: AppColors.background,
                          )
                        : Text(
                            '${exercise.order}',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (exercise.equipmentName != null) ...[
                      Text(
                        exercise.equipmentName!,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 3),
                    ],
                    Text(
                      exercise.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    if (exercise.targetMuscle != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          exercise.targetMuscle!.toUpperCase(),
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
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
                color: statusColor,
              ),
            ],
          ),
          if (!isCompleted) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(exercise.totalSets, (index) {
                final setNumber = index + 1;
                final isSelected = setNumber <= exercise.completedSets;

                return GestureDetector(
                  onTap: isSubmitting ? null : () => onSetSelected(setNumber),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.accent : AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            isSelected ? Colors.transparent : AppColors.divider,
                      ),
                    ),
                    child: Text(
                      'SET $setNumber',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: isSelected
                                ? AppColors.background
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}
