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

class TrainerProgressiveUnlockTimelinePage extends StatefulWidget {
  const TrainerProgressiveUnlockTimelinePage({super.key});

  @override
  State<TrainerProgressiveUnlockTimelinePage> createState() =>
      _TrainerProgressiveUnlockTimelinePageState();
}

class _TrainerProgressiveUnlockTimelinePageState
    extends State<TrainerProgressiveUnlockTimelinePage> {
  late final ClientSummary _client;
  late final String _programName;
  late List<_TimelineStageData> _stages;

  @override
  void initState() {
    super.initState();
    final payload = _resolvePayload();
    _client = payload.client;
    _programName = payload.programName;
    _stages = _buildStages(payload.sessions);
  }

  _TimelinePayload _resolvePayload() {
    final argument = Get.arguments;
    if (argument is Map<String, dynamic>) {
      final mappedClient = argument['client'];
      final mappedProgramName = argument['programName'];
      final mappedSessions = argument['sessions'];
      if (mappedClient is ClientSummary &&
          mappedProgramName is String &&
          mappedSessions is List<TrainerDraftSession>) {
        return _TimelinePayload(
          client: mappedClient,
          programName: mappedProgramName,
          sessions: mappedSessions,
        );
      }
    }

    return const _TimelinePayload(
      client: ClientSummary(
        name: 'Sarah Jenkins',
        goal: 'Mass building and performance phase',
        progressLabel: '42%',
        nextSession: 'Tue | 08.15 - 09.30',
      ),
      programName: 'Mass Builder Program',
      sessions: [
        TrainerDraftSession(
          title: 'Initial Assessment',
          focus: 'Movement screening and baseline testing',
          totalExercises: 2,
          durationMinutes: 50,
          exercises: [
            TrainerDraftExercise(
              name: 'Mobility Screen',
              targetMuscle: 'Full Body',
              sets: 2,
              reps: 8,
            ),
            TrainerDraftExercise(
              name: 'Strength Baseline',
              targetMuscle: 'Compound Lift',
              sets: 3,
              reps: 5,
            ),
          ],
        ),
        TrainerDraftSession(
          title: 'Hypertrophy Phase A',
          focus: 'Upper and lower split introduction',
          totalExercises: 3,
          durationMinutes: 75,
          exercises: [
            TrainerDraftExercise(
              name: 'Incline Dumbbell Press',
              targetMuscle: 'Chest',
              sets: 4,
              reps: 10,
            ),
            TrainerDraftExercise(
              name: 'Weighted Pull-Ups',
              targetMuscle: 'Back',
              sets: 3,
              reps: 8,
            ),
            TrainerDraftExercise(
              name: 'Lateral Raises',
              targetMuscle: 'Shoulders',
              sets: 3,
              reps: 15,
            ),
          ],
        ),
        TrainerDraftSession(
          title: 'Posterior Chain Mastery',
          focus: 'Strength build-up and tempo work',
          totalExercises: 3,
          durationMinutes: 70,
          exercises: [
            TrainerDraftExercise(
              name: 'Romanian Deadlift',
              targetMuscle: 'Hamstrings',
              sets: 3,
              reps: 12,
            ),
            TrainerDraftExercise(
              name: 'Hip Thrust',
              targetMuscle: 'Glutes',
              sets: 4,
              reps: 10,
            ),
            TrainerDraftExercise(
              name: 'Seated Leg Curl',
              targetMuscle: 'Hamstrings',
              sets: 3,
              reps: 15,
            ),
          ],
        ),
      ],
    );
  }

  List<_TimelineStageData> _buildStages(List<TrainerDraftSession> sessions) {
    if (sessions.isEmpty) {
      return const [];
    }

    if (sessions.length == 1) {
      return [
        _TimelineStageData(
          session: sessions.first,
          state: _TimelineState.active,
          progressPercent: 65,
          note: 'Sesi pertama sedang berjalan dan siap dibuka ke tracker.',
        ),
      ];
    }

    return List<_TimelineStageData>.generate(sessions.length, (index) {
      if (index == 0) {
        return _TimelineStageData(
          session: sessions[index],
          state: _TimelineState.complete,
          progressPercent: 100,
          note: 'Completed and verified by trainer demo flow.',
        );
      }
      if (index == 1) {
        return _TimelineStageData(
          session: sessions[index],
          state: _TimelineState.active,
          progressPercent: 65,
          note: 'Current active block waiting for session completion.',
        );
      }
      return _TimelineStageData(
        session: sessions[index],
        state: _TimelineState.locked,
        progressPercent: 0,
        note: 'Locked until previous session reaches 100 percent completion.',
      );
    });
  }

  int get _completionPercent {
    if (_stages.isEmpty) {
      return 0;
    }
    final sum = _stages.fold<int>(
      0,
      (total, stage) => total + stage.progressPercent,
    );
    return (sum / _stages.length).round();
  }

  int get _unlockedCount =>
      _stages.where((stage) => stage.state != _TimelineState.locked).length;

  int get _activeIndex => _stages.indexWhere(
        (stage) => stage.state == _TimelineState.active,
      );

  void _openActiveTracker() {
    final activeIndex = _activeIndex;
    if (activeIndex == -1) {
      Get.snackbar(
        'No Active Session',
        'Belum ada sesi aktif yang bisa dibuka ke tracker.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
      return;
    }

    final activeSession = _stages[activeIndex].session;
    final workout = WorkoutSession(
      title: activeSession.title,
      focus:
          '${activeSession.totalExercises} latihan | ${activeSession.durationMinutes} menit',
      progressText: 'Unlock sequence active | trainer program sync',
      statusLabel: 'Active',
    );

    Get.toNamed(
      AppRoutes.programTracker,
      arguments: <String, dynamic>{
        'workout': workout,
        'programMode': 'trainer_program',
      },
    );
  }

  void _overrideSequence() {
    final activeIndex = _activeIndex;
    final nextLockedIndex = _stages.indexWhere(
      (stage) => stage.state == _TimelineState.locked,
    );

    if (nextLockedIndex == -1) {
      Get.snackbar(
        'Sequence Complete',
        'Semua sesi sudah terbuka untuk demo flow ini.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
      return;
    }

    setState(() {
      if (activeIndex != -1) {
        _stages[activeIndex] = _stages[activeIndex].copyWith(
          state: _TimelineState.complete,
          progressPercent: 100,
          note: 'Trainer override marked this stage as complete.',
        );
      }

      _stages[nextLockedIndex] = _stages[nextLockedIndex].copyWith(
        state: _TimelineState.active,
        progressPercent: 35,
        note: 'Unlocked manually through trainer override control.',
      );
    });

    Get.snackbar(
      'Sequence Overridden',
      'Sesi berikutnya sudah dibuka untuk kebutuhan demo.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.surface,
      colorText: AppColors.textPrimary,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedScreen(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const DetailScreenHeader(
            title: 'Program Progress',
            subtitle:
                'Timeline unlock untuk mengatur sesi aktif, sesi selesai, dan sesi yang masih terkunci.',
          ),
          const SizedBox(height: 20),
          EggCard(
            highlight: true,
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [AppColors.accentBronze, Color(0xFF181818)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      StatusChip(label: 'COMPLETION STATUS'),
                      StatusChip(label: 'PROGRESSIVE UNLOCK'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$_completionPercent%',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: _completionPercent / 100,
                    minHeight: 8,
                    backgroundColor: AppColors.surfaceSoft,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.accent),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sesi berikutnya terbuka setelah blok aktif selesai 100 persen atau dibuka manual oleh trainer.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.45,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          EggCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    InitialAvatar(name: _client.name, radius: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _client.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ADVANCED MEMBER | $_programName',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    StatusChip(
                      label: _client.progressLabel,
                      color: AppColors.accent,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _QuickStat(
                        label: 'UNLOCKED',
                        value: '$_unlockedCount/${_stages.length}',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickStat(
                        label: 'NEXT SESSION',
                        value: _client.nextSession,
                      ),
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
                      'Curriculum Journey',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      'TRAINER ACCESS MODE',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.textSecondary,
                            letterSpacing: 0.8,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ..._stages.asMap().entries.map(
                      (entry) => _TimelineStageTile(
                        stage: entry.value,
                        index: entry.key,
                        isLast: entry.key == _stages.length - 1,
                        onOpenTracker:
                            entry.value.state == _TimelineState.active
                                ? _openActiveTracker
                                : null,
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          EggCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unlock Flow Control',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Next session automatically unlocks upon completion of the active stage. Untuk demo, trainer bisa memaksa membuka sesi berikutnya.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                ),
                const SizedBox(height: 16),
                EggButton.secondary(
                  label: 'Override Sequence',
                  onPressed: _overrideSequence,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          EggButton.primary(
            label: 'Buka Tracker Sesi Aktif',
            onPressed: _openActiveTracker,
          ),
        ],
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  const _QuickStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _TimelineStageTile extends StatelessWidget {
  const _TimelineStageTile({
    required this.stage,
    required this.index,
    required this.isLast,
    this.onOpenTracker,
  });

  final _TimelineStageData stage;
  final int index;
  final bool isLast;
  final VoidCallback? onOpenTracker;

  Color get _accentColor {
    switch (stage.state) {
      case _TimelineState.complete:
        return AppColors.success;
      case _TimelineState.active:
        return AppColors.accent;
      case _TimelineState.locked:
        return AppColors.textSecondary;
    }
  }

  String get _statusLabel {
    switch (stage.state) {
      case _TimelineState.complete:
        return 'SELESAI';
      case _TimelineState.active:
        return 'AKTIF';
      case _TimelineState.locked:
        return 'TERKUNCI';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = stage.state == _TimelineState.active;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _accentColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: stage.state == _TimelineState.complete
                      ? const Icon(
                          Icons.check,
                          size: 11,
                          color: AppColors.background,
                        )
                      : stage.state == _TimelineState.locked
                          ? const Icon(
                              Icons.lock_outline,
                              size: 10,
                              color: AppColors.background,
                            )
                          : null,
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 118,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: stage.state == _TimelineState.active
                    ? AppColors.surfaceElevated
                    : AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: stage.state == _TimelineState.active
                      ? AppColors.accent.withValues(alpha: 0.36)
                      : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Session ${index + 1}',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: _accentColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ),
                      StatusChip(
                        label: _statusLabel,
                        color: _accentColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    stage.session.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    stage.session.focus,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StageMetric(
                          label: 'TARGET REPS',
                          value:
                              '${stage.session.exercises.first.sets}-${stage.session.exercises.first.reps}',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StageMetric(
                          label: 'DURATION',
                          value: '${stage.session.durationMinutes}m',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: stage.progressPercent / 100,
                    minHeight: 7,
                    backgroundColor: AppColors.surface,
                    valueColor: AlwaysStoppedAnimation<Color>(_accentColor),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${stage.progressPercent}% | ${stage.note}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  if (isActive && onOpenTracker != null) ...[
                    const SizedBox(height: 14),
                    EggButton.primary(
                      label: 'Buka Sesi',
                      onPressed: onOpenTracker!,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StageMetric extends StatelessWidget {
  const _StageMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 0.6,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _TimelinePayload {
  const _TimelinePayload({
    required this.client,
    required this.programName,
    required this.sessions,
  });

  final ClientSummary client;
  final String programName;
  final List<TrainerDraftSession> sessions;
}

class _TimelineStageData {
  const _TimelineStageData({
    required this.session,
    required this.state,
    required this.progressPercent,
    required this.note,
  });

  final TrainerDraftSession session;
  final _TimelineState state;
  final int progressPercent;
  final String note;

  _TimelineStageData copyWith({
    TrainerDraftSession? session,
    _TimelineState? state,
    int? progressPercent,
    String? note,
  }) {
    return _TimelineStageData(
      session: session ?? this.session,
      state: state ?? this.state,
      progressPercent: progressPercent ?? this.progressPercent,
      note: note ?? this.note,
    );
  }
}

enum _TimelineState { complete, active, locked }
