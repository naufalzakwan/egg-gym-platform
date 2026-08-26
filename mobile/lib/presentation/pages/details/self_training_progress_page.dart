import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/data/services/backend_self_training_service.dart';
import 'package:egg_gym/presentation/widgets/common/decorated_screen.dart';
import 'package:egg_gym/presentation/widgets/common/egg_button.dart';
import 'package:egg_gym/presentation/widgets/common/egg_card.dart';
import 'package:egg_gym/presentation/widgets/common/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SelfTrainingProgressPage extends StatefulWidget {
  const SelfTrainingProgressPage({super.key});

  @override
  State<SelfTrainingProgressPage> createState() =>
      _SelfTrainingProgressPageState();
}

class _SelfTrainingProgressPageState extends State<SelfTrainingProgressPage> {
  final BackendSelfTrainingService _service = BackendSelfTrainingService();
  SelfTrainingProgramData? _program;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  int? get _programId {
    final argument = Get.arguments;
    if (argument is Map<String, dynamic>) {
      final id = argument['programId'];
      if (id is int) return id;
      if (id != null) return int.tryParse(id.toString());
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadProgram();
  }

  Future<void> _loadProgram() async {
    final programId = _programId;
    if (programId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Program ID tidak ditemukan.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final programs = await _service.getPrograms();
      final program = programs.where((p) => p.id == programId).firstOrNull;
      if (!mounted) return;
      setState(() {
        _program = program;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleExercise(SelfTrainingSessionData session,
      SelfTrainingExerciseData exercise) async {
    setState(() => _isSubmitting = true);

    try {
      await _service.toggleExercise(
        programId: _program!.id,
        sessionId: session.id,
        exerciseId: exercise.id,
      );
      await _loadProgram();
    } catch (e) {
      if (!mounted) return;
      Get.snackbar(
        'Gagal',
        e.toString().replaceAll('Exception: ', ''),
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
              : _program == null
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
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            EggButton.secondary(label: 'Coba Lagi', onPressed: _loadProgram),
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
            const Text('Program tidak ditemukan'),
            const SizedBox(height: 16),
            EggButton.secondary(label: 'Kembali', onPressed: () => Get.back()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final program = _program!;

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
                    'Latihan Mandiri',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    program.title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _loadProgram,
              icon: const Icon(Icons.refresh_rounded),
              color: AppColors.textSecondary,
            ),
          ],
        ),
        const SizedBox(height: 18),
        // Completion Status
        EggCard(
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
              Row(
                children: [
                  Text(
                    '${program.progressPercent}',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '%',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${program.completedExercises}/${program.totalExercises} exercise',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: program.progressPercent / 100,
                minHeight: 8,
                borderRadius: BorderRadius.circular(999),
                backgroundColor: AppColors.surfaceSoft,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.accent),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        // Sessions
        ...program.sessions.asMap().entries.map((entry) {
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

  Widget _buildSessionCard(SelfTrainingSessionData session, int index) {
    final completedCount = session.exercises.where((e) => e.isCompleted).length;
    final totalCount = session.exercises.length;
    final isSessionComplete = completedCount == totalCount && totalCount > 0;

    return EggCard(
      highlight: !isSessionComplete && totalCount > 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      isSessionComplete ? AppColors.success : AppColors.accent,
                ),
                child: Center(
                  child: isSessionComplete
                      ? const Icon(Icons.check_rounded,
                          size: 18, color: AppColors.background)
                      : Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: AppColors.background,
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
                      session.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (session.focus != null)
                      Text(
                        session.focus!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                  ],
                ),
              ),
              StatusChip(
                label: isSessionComplete
                    ? 'SELESAI'
                    : '$completedCount/$totalCount',
                color: isSessionComplete ? AppColors.success : AppColors.accent,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar per session
          if (totalCount > 0) ...[
            LinearProgressIndicator(
              value: completedCount / totalCount,
              minHeight: 6,
              borderRadius: BorderRadius.circular(999),
              backgroundColor: AppColors.surfaceSoft,
              valueColor: AlwaysStoppedAnimation<Color>(
                isSessionComplete ? AppColors.success : AppColors.accent,
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Exercises
          ...session.exercises.map((exercise) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildExerciseTile(session, exercise),
              )),
        ],
      ),
    );
  }

  Widget _buildExerciseTile(
      SelfTrainingSessionData session, SelfTrainingExerciseData exercise) {
    return GestureDetector(
      onTap: _isSubmitting ? null : () => _toggleExercise(session, exercise),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
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
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: exercise.isCompleted
                    ? AppColors.success
                    : AppColors.surfaceSoft,
                border: Border.all(
                  color: exercise.isCompleted
                      ? AppColors.success
                      : AppColors.textSecondary,
                  width: 2,
                ),
              ),
              child: Center(
                child: exercise.isCompleted
                    ? const Icon(Icons.check_rounded,
                        size: 16, color: AppColors.background)
                    : Text(
                        '${exercise.sequenceOrder}',
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
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    exercise.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          decoration: exercise.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${exercise.sets} set x ${exercise.reps} reps${exercise.load != null ? ' • ${exercise.load}' : ''}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            StatusChip(
              label: exercise.isCompleted
                  ? 'SELESAI'
                  : '${exercise.sets}/${exercise.sets}',
              color: exercise.isCompleted
                  ? AppColors.success
                  : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
