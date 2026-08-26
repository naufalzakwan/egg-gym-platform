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

class ProgramDetailTrackerPage extends StatefulWidget {
  const ProgramDetailTrackerPage({super.key});

  @override
  State<ProgramDetailTrackerPage> createState() =>
      _ProgramDetailTrackerPageState();
}

class _ProgramDetailTrackerPageState extends State<ProgramDetailTrackerPage> {
  late final WorkoutSession _session;
  late final String _programMode;
  late final String? _syncSourceLabel;
  late final List<TrainerSyncedExerciseProgress>? _syncedTrainerExercises;
  late List<_ExerciseChecklistItem> _exercises;

  bool get _isTrainerProgram => _programMode == 'trainer_program';

  @override
  void initState() {
    super.initState();
    _programMode = _resolveProgramMode();
    _session = _resolveSession();
    _syncSourceLabel = _resolveSyncSourceLabel();
    _syncedTrainerExercises = _resolveSyncedTrainerExercises();
    _exercises = _buildDefaultExercises();
    _syncExerciseStates();
  }

  String _resolveProgramMode() {
    final argument = Get.arguments;
    if (argument is Map<String, dynamic>) {
      final mappedMode = argument['programMode'];
      if (mappedMode is String && mappedMode.isNotEmpty) {
        return mappedMode;
      }
    }

    return 'trainer_program';
  }

  WorkoutSession _resolveSession() {
    final argument = Get.arguments;
    if (argument is WorkoutSession) {
      return argument;
    }
    if (argument is Map<String, dynamic> &&
        argument['workout'] is WorkoutSession) {
      return argument['workout'] as WorkoutSession;
    }

    return const WorkoutSession(
      title: 'Pull Day: Lat Thickness',
      focus: 'Scheduled for today - 6 exercises',
      progressText: 'Start session and open details',
      statusLabel: 'Active',
    );
  }

  String? _resolveSyncSourceLabel() {
    final argument = Get.arguments;
    if (argument is Map<String, dynamic>) {
      final mappedSource = argument['syncSourceLabel'];
      if (mappedSource is String && mappedSource.isNotEmpty) {
        return mappedSource;
      }
    }

    return null;
  }

  List<TrainerSyncedExerciseProgress>? _resolveSyncedTrainerExercises() {
    final argument = Get.arguments;
    if (argument is! Map<String, dynamic>) {
      return null;
    }

    final mappedExercises = argument['syncedExercises'];
    if (mappedExercises is List<TrainerSyncedExerciseProgress> &&
        mappedExercises.isNotEmpty) {
      return mappedExercises;
    }

    if (mappedExercises is List) {
      final parsedExercises = mappedExercises
          .whereType<TrainerSyncedExerciseProgress>()
          .toList(growable: false);
      if (parsedExercises.isNotEmpty) {
        return parsedExercises;
      }
    }

    return null;
  }

  List<_ExerciseChecklistItem> _buildDefaultExercises() {
    if (_isTrainerProgram) {
      final syncedTrainerExercises = _syncedTrainerExercises;
      if (syncedTrainerExercises != null && syncedTrainerExercises.isNotEmpty) {
        return syncedTrainerExercises
            .map(
              (exercise) => _ExerciseChecklistItem(
                order: exercise.order,
                title: exercise.title,
                subtitle: exercise.subtitle,
                cue: exercise.cue,
                totalSets: exercise.totalSets,
                completedSets: exercise.completedSets,
              ),
            )
            .toList();
      }

      return [
        _ExerciseChecklistItem(
          order: 1,
          title: 'Lat Pulldown',
          subtitle: '4 set x 12 reps',
          cue: 'Progress ini sudah ditandai selesai dari aplikasi PT.',
          totalSets: 4,
          completedSets: 4,
        ),
        _ExerciseChecklistItem(
          order: 2,
          title: 'Barbell Row',
          subtitle: '4 set x 10 reps',
          cue: 'Progress ini sudah ditandai selesai dari aplikasi PT.',
          totalSets: 4,
          completedSets: 4,
        ),
        _ExerciseChecklistItem(
          order: 3,
          title: 'Seated Cable Row',
          subtitle: '3 set x 12 reps',
          cue: 'Masih berjalan dan menunggu update lanjutan dari sisi PT.',
          totalSets: 3,
          completedSets: 1,
        ),
        _ExerciseChecklistItem(
          order: 4,
          title: 'Straight Arm Pulldown',
          subtitle: '3 set x 15 reps',
          cue: 'Belum dibuka karena progres dari PT belum masuk.',
          totalSets: 3,
          completedSets: 0,
        ),
        _ExerciseChecklistItem(
          order: 5,
          title: 'Rear Delt Fly',
          subtitle: '3 set x 15 reps',
          cue: 'Belum dibuka karena progres dari PT belum masuk.',
          totalSets: 3,
          completedSets: 0,
        ),
      ];
    }

    return [
      _ExerciseChecklistItem(
        order: 1,
        title: 'Cat Cow Flow',
        subtitle: '3 set x 30 sec',
        cue: 'Gerakkan tulang belakang perlahan dan jaga napas tetap stabil.',
        totalSets: 3,
        completedSets: 1,
      ),
      _ExerciseChecklistItem(
        order: 2,
        title: 'World Greatest Stretch',
        subtitle: '2 set x 8 reps',
        cue: 'Tahan rotasi sebentar supaya pinggul dan punggung lebih terbuka.',
        totalSets: 2,
        completedSets: 0,
      ),
      _ExerciseChecklistItem(
        order: 3,
        title: 'Band Pull Apart',
        subtitle: '3 set x 15 reps',
        cue: 'Jaga bahu turun dan fokus ke kontraksi upper back.',
        totalSets: 3,
        completedSets: 0,
      ),
      _ExerciseChecklistItem(
        order: 4,
        title: 'Breathing Reset',
        subtitle: '2 set x 45 sec',
        cue:
            'Tarik napas dari diafragma dan tenangkan heart rate sebelum selesai.',
        totalSets: 2,
        completedSets: 0,
      ),
    ];
  }

  void _syncExerciseStates() {
    final firstIncompleteIndex =
        _exercises.indexWhere((exercise) => !exercise.isFullyComplete);

    for (var index = 0; index < _exercises.length; index++) {
      final exercise = _exercises[index];
      if (exercise.isFullyComplete) {
        exercise.state = _ExerciseChecklistState.complete;
      } else if (index == firstIncompleteIndex) {
        exercise.state = _ExerciseChecklistState.active;
      } else {
        exercise.state = _ExerciseChecklistState.pending;
      }
    }
  }

  int get _completedExercises =>
      _exercises.where((exercise) => exercise.isFullyComplete).length;
  int get _totalExercises => _exercises.length;
  int get _completedSets =>
      _exercises.fold(0, (total, exercise) => total + exercise.completedSets);
  int get _totalSets =>
      _exercises.fold(0, (total, exercise) => total + exercise.totalSets);
  int get _lockedExercises => _exercises
      .where((exercise) => exercise.state == _ExerciseChecklistState.pending)
      .length;
  bool get _allExercisesComplete => _completedExercises == _totalExercises;
  double get _checklistProgress =>
      _totalSets == 0 ? 0 : _completedSets / _totalSets;

  _ExerciseChecklistItem? get _activeExercise {
    for (final exercise in _exercises) {
      if (exercise.state == _ExerciseChecklistState.active) {
        return exercise;
      }
    }
    return null;
  }

  void _updateExerciseSets(int exerciseIndex, int selectedSet) {
    if (_isTrainerProgram) {
      Get.snackbar(
        'Read Only',
        'Checklist program PT hanya bisa diupdate dari aplikasi trainer.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
      return;
    }

    final exercise = _exercises[exerciseIndex];
    final activeIndex = _exercises.indexWhere(
      (item) => item.state == _ExerciseChecklistState.active,
    );
    final isEditable = exercise.state == _ExerciseChecklistState.active ||
        exercise.state == _ExerciseChecklistState.complete ||
        (activeIndex != -1 && exerciseIndex < activeIndex);

    if (!isEditable) {
      Get.snackbar(
        'Checklist Demo',
        'Selesaikan exercise aktif dulu sebelum membuka blok berikutnya.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
      return;
    }

    setState(() {
      exercise.completedSets = selectedSet.clamp(0, exercise.totalSets).toInt();
      _syncExerciseStates();
    });
  }

  void _advanceChecklist() {
    if (_isTrainerProgram) {
      Get.snackbar(
        'Read Only',
        'Member hanya melihat progres program PT yang sudah disinkronkan.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
      return;
    }

    if (_allExercisesComplete) {
      Get.snackbar(
        'Checklist Demo',
        'Semua exercise dummy sudah complete dan siap dipresentasikan.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
      return;
    }

    final activeIndex = _exercises.indexWhere(
      (exercise) => exercise.state == _ExerciseChecklistState.active,
    );
    if (activeIndex == -1) {
      return;
    }

    final activeExercise = _exercises[activeIndex];
    setState(() {
      activeExercise.completedSets = (activeExercise.completedSets + 1)
          .clamp(0, activeExercise.totalSets)
          .toInt();
      _syncExerciseStates();
    });

    if (activeExercise.isFullyComplete) {
      Get.snackbar(
        'Exercise Complete',
        '${activeExercise.title} selesai. Lanjut ke blok berikutnya.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
    }
  }

  void _resetChecklist() {
    if (_isTrainerProgram) {
      return;
    }
    setState(() {
      _exercises = _buildDefaultExercises();
      _syncExerciseStates();
    });
  }

  @override
  Widget build(BuildContext context) {
    final progressPercent = (_checklistProgress * 100).round();
    final activeExercise = _activeExercise;
    final modeTitle = _isTrainerProgram ? 'Program dari PT' : 'Latihan Mandiri';

    return DecoratedScreen(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          DetailScreenHeader(
            title: 'Program Detail',
            subtitle: _isTrainerProgram
                ? 'Tracker progres program PT yang disinkronkan ke aplikasi member.'
                : 'Tracker latihan mandiri yang bisa kamu update langsung.',
          ),
          const SizedBox(height: 20),
          EggCard(
            highlight: true,
            padding: const EdgeInsets.all(14),
            child: _HeroCard(
              session: _session,
              activeExercise: activeExercise,
              allComplete: _allExercisesComplete,
              readOnly: _isTrainerProgram,
              modeTitle: modeTitle,
              progressPercent: progressPercent,
              completedExercises: _completedExercises,
              totalExercises: _totalExercises,
              completedSets: _completedSets,
              totalSets: _totalSets,
              lockedExercises: _lockedExercises,
              progress: _checklistProgress,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _TrackerMetric(
                  label: 'Exercise',
                  value: '$_completedExercises/$_totalExercises',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TrackerMetric(
                  label: 'Sets',
                  value: '$_completedSets/$_totalSets',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TrackerMetric(
                  label: _isTrainerProgram ? 'Locked' : 'Active',
                  value: _isTrainerProgram
                      ? '$_lockedExercises'
                      : _allExercisesComplete
                          ? 'Done'
                          : activeExercise?.orderLabel ?? 'Live',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_isTrainerProgram) ...[
            _ProgramSyncBanner(
              activeExercise: activeExercise,
              progressPercent: progressPercent,
              syncSourceLabel: _syncSourceLabel,
            ),
            const SizedBox(height: 18),
            const _TrainerValidatorCard(),
            const SizedBox(height: 18),
          ] else ...[
            const _InteractiveTrackerHintCard(),
            const SizedBox(height: 18),
          ],
          _SequenceSummaryCard(
            completedExercises: _completedExercises,
            totalExercises: _totalExercises,
            lockedExercises: _lockedExercises,
            activeLabel: _allExercisesComplete
                ? 'Ready to close'
                : activeExercise?.title ?? 'Sequence active',
            readOnly: _isTrainerProgram,
          ),
          const SizedBox(height: 18),
          EggCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _isTrainerProgram
                          ? 'Checklist Sinkron PT'
                          : 'Checklist Latihan',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      _allExercisesComplete
                          ? 'SIAP'
                          : '$_completedExercises/$_totalExercises',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _isTrainerProgram
                      ? 'Checklist ini hanya menampilkan progres yang sudah disinkronkan dari aplikasi PT.'
                      : 'Tap set chip untuk update progres per exercise. Exercise berikutnya otomatis terbuka saat blok aktif selesai.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                ),
                const SizedBox(height: 16),
                ..._exercises.asMap().entries.map((entry) {
                  final index = entry.key;
                  final exercise = entry.value;
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == _exercises.length - 1 ? 0 : 12,
                    ),
                    child: _ExerciseTile(
                      exercise: exercise,
                      readOnly: _isTrainerProgram,
                      onSetSelected: (selectedSet) =>
                          _updateExerciseSets(index, selectedSet),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 18),
          EggCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Catatan Coach',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  activeExercise?.cue ??
                      (_isTrainerProgram
                          ? 'Program PT bersifat read-only di member. Progress di sini hanya hasil sinkron dari aplikasi trainer.'
                          : 'Checklist sudah lengkap. Kamu bisa masuk sesi latihan aktif atau tutup sesi demo.'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (_isTrainerProgram) ...[
            EggButton.primary(
              label: 'Kembali ke Program PT',
              onPressed: () => Get.back(),
            ),
          ] else ...[
            EggButton.primary(
              label: _allExercisesComplete
                  ? 'Checklist Demo Selesai'
                  : 'Tandai Set Berikutnya',
              onPressed: _advanceChecklist,
            ),
            const SizedBox(height: 10),
            EggButton.secondary(
              label: 'Reset Checklist Demo',
              onPressed: _resetChecklist,
            ),
            const SizedBox(height: 10),
            EggButton.secondary(
              label: 'Buka Sesi Latihan Aktif',
              onPressed: () => Get.toNamed(
                AppRoutes.liveTrainingSession,
                arguments: {
                  'workout': _session,
                  'role': 'member',
                  'programMode': 'self_training',
                },
              ),
            ),
          ],
          if (!_isTrainerProgram) ...[
            const SizedBox(height: 10),
            EggButton.secondary(
              label: 'Kembali ke Program',
              onPressed: () => Get.back(),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.session,
    required this.activeExercise,
    required this.allComplete,
    required this.readOnly,
    required this.modeTitle,
    required this.progressPercent,
    required this.completedExercises,
    required this.totalExercises,
    required this.completedSets,
    required this.totalSets,
    required this.lockedExercises,
    required this.progress,
  });

  final WorkoutSession session;
  final _ExerciseChecklistItem? activeExercise;
  final bool allComplete;
  final bool readOnly;
  final String modeTitle;
  final int progressPercent;
  final int completedExercises;
  final int totalExercises;
  final int completedSets;
  final int totalSets;
  final int lockedExercises;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF564523), Color(0xFF1B1B1B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusChip(
                label: readOnly
                    ? 'SINKRON DARI PT'
                    : allComplete
                        ? 'CHECKLIST SELESAI'
                        : 'FASE AKTIF',
              ),
              const Spacer(),
              Text(
                modeTitle.toUpperCase(),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            session.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            session.focus,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  readOnly
                      ? 'Last PT update'
                      : allComplete
                          ? 'Semua exercise dummy selesai.'
                          : 'Current active move',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  readOnly
                      ? activeExercise?.title ?? 'Progres tersinkron'
                      : allComplete
                          ? 'Siap tutup sesi'
                          : activeExercise?.title ?? 'Exercise selesai',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (!allComplete && activeExercise != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${activeExercise!.completedSets}/${activeExercise!.totalSets} sets selesai | ${activeExercise!.subtitle}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$progressPercent',
                        style:
                            Theme.of(context).textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 14, left: 4),
                        child: Text(
                          '%',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    readOnly ? 'Progres sinkron PT' : 'Progres checklist live',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${completedExercises.toString().padLeft(2, '0')} / ${totalExercises.toString().padLeft(2, '0')} EXERCISES',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$completedSets / $totalSets sets tracked',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$lockedExercises locked blocks',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: AppColors.surfaceSoft,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
          ),
        ],
      ),
    );
  }
}

class _TrackerMetric extends StatelessWidget {
  const _TrackerMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return EggCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _ProgramSyncBanner extends StatelessWidget {
  const _ProgramSyncBanner({
    required this.activeExercise,
    required this.progressPercent,
    required this.syncSourceLabel,
  });

  final _ExerciseChecklistItem? activeExercise;
  final int progressPercent;
  final String? syncSourceLabel;

  @override
  Widget build(BuildContext context) {
    return EggCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.sync_rounded,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Disinkron dari Aplikasi PT',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Member hanya melihat hasil progres yang sudah diverifikasi trainer.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                    ),
                    if (syncSourceLabel != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        syncSourceLabel!,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              StatusChip(
                label: '$progressPercent%',
                color: AppColors.accent,
              ),
            ],
          ),
          if (activeExercise != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                'Update terakhir menunjukkan ${activeExercise!.title} masih berjalan pada ${activeExercise!.completedSets}/${activeExercise!.totalSets} sets.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InteractiveTrackerHintCard extends StatelessWidget {
  const _InteractiveTrackerHintCard();

  @override
  Widget build(BuildContext context) {
    return EggCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.touch_app_rounded,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Latihan mandiri ini interaktif. Kamu bisa tap chip set untuk menggerakkan progres secara manual.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrainerValidatorCard extends StatelessWidget {
  const _TrainerValidatorCard();

  @override
  Widget build(BuildContext context) {
    return EggCard(
      child: Row(
        children: [
          InitialAvatar(name: 'Coach Reyhan', radius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trainer Validator',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Coach Reyhan W. terverifikasi',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          const StatusChip(
            label: 'TERSINKRON',
            color: AppColors.success,
          ),
        ],
      ),
    );
  }
}

class _SequenceSummaryCard extends StatelessWidget {
  const _SequenceSummaryCard({
    required this.completedExercises,
    required this.totalExercises,
    required this.lockedExercises,
    required this.activeLabel,
    required this.readOnly,
  });

  final int completedExercises;
  final int totalExercises;
  final int lockedExercises;
  final String activeLabel;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final activeCount = (totalExercises - completedExercises - lockedExercises)
        .clamp(0, totalExercises);

    return EggCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status Urutan',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            readOnly
                ? 'Status sesi di bawah ini mengikuti urutan progres yang dibuka oleh trainer.'
                : 'Exercise berikutnya terbuka otomatis saat blok aktif selesai.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusChip(
                label: '$completedExercises selesai',
                color: AppColors.success,
              ),
              StatusChip(
                label: '$activeCount aktif',
                color: AppColors.accent,
              ),
              StatusChip(
                label: '$lockedExercises terkunci',
                color: AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              'Sesi aktif saat ini: $activeLabel',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ExerciseChecklistState { complete, active, pending }

class _ExerciseChecklistItem {
  _ExerciseChecklistItem({
    required this.order,
    required this.title,
    required this.subtitle,
    required this.cue,
    required this.totalSets,
    required this.completedSets,
  });

  final int order;
  final String title;
  final String subtitle;
  final String cue;
  final int totalSets;
  int completedSets;
  _ExerciseChecklistState state = _ExerciseChecklistState.pending;

  String get orderLabel => order.toString().padLeft(2, '0');
  bool get isFullyComplete => completedSets >= totalSets;
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({
    required this.exercise,
    required this.readOnly,
    required this.onSetSelected,
  });

  final _ExerciseChecklistItem exercise;
  final bool readOnly;
  final ValueChanged<int> onSetSelected;

  @override
  Widget build(BuildContext context) {
    final isComplete = exercise.state == _ExerciseChecklistState.complete;
    final isActive = exercise.state == _ExerciseChecklistState.active;
    final statusColor = isComplete
        ? AppColors.success
        : isActive
            ? AppColors.accent
            : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isActive ? AppColors.surfaceSoft : AppColors.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isComplete
              ? AppColors.success.withValues(alpha: 0.3)
              : isActive
                  ? AppColors.accent.withValues(alpha: 0.4)
                  : AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isComplete
                      ? AppColors.success
                      : isActive
                          ? AppColors.accent
                          : AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  exercise.orderLabel,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: isComplete || isActive
                            ? AppColors.background
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      exercise.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                isComplete
                    ? Icons.check_circle_rounded
                    : isActive
                        ? Icons.play_circle_fill_rounded
                        : Icons.lock_outline_rounded,
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              StatusChip(
                label: isComplete
                    ? 'SELESAI'
                    : isActive
                        ? 'AKTIF'
                        : 'TERKUNCI',
                color: isComplete ? AppColors.success : statusColor,
              ),
              const SizedBox(width: 8),
              Text(
                '${exercise.completedSets}/${exercise.totalSets} sets',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            exercise.cue,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(exercise.totalSets, (index) {
              final setNumber = index + 1;
              final selected = setNumber <= exercise.completedSets;
              final enabled = !readOnly &&
                  (exercise.state != _ExerciseChecklistState.pending ||
                      selected);

              return GestureDetector(
                onTap: enabled ? () => onSetSelected(setNumber) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? statusColor
                        : enabled
                            ? AppColors.surface
                            : AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? Colors.transparent
                          : enabled
                              ? AppColors.divider
                              : Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                  child: Text(
                    'SET $setNumber',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: selected
                              ? AppColors.background
                              : enabled
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
