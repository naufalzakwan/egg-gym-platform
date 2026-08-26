import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/data/services/backend_public_service.dart';
import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:egg_gym/presentation/widgets/common/decorated_screen.dart';
import 'package:egg_gym/presentation/widgets/common/detail_screen_header.dart';
import 'package:egg_gym/presentation/widgets/common/egg_button.dart';
import 'package:egg_gym/presentation/widgets/common/egg_card.dart';
import 'package:egg_gym/presentation/widgets/common/equipment_movement_exercise_picker.dart';
import 'package:egg_gym/presentation/widgets/common/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TrainerEditTrainingSessionPage extends StatefulWidget {
  const TrainerEditTrainingSessionPage({super.key});

  @override
  State<TrainerEditTrainingSessionPage> createState() =>
      _TrainerEditTrainingSessionPageState();
}

class _TrainerEditTrainingSessionPageState
    extends State<TrainerEditTrainingSessionPage> {
  late final TextEditingController _titleController;
  late List<TrainerDraftExercise> _exercises;
  late int _durationMinutes;
  late bool _isNewSession;
  bool _loadingEquipment = false;

  TrainerDraftSession _resolveSession() {
    final argument = Get.arguments;
    if (argument is Map<String, dynamic>) {
      final mappedSession = argument['session'];
      if (mappedSession is TrainerDraftSession) {
        _isNewSession = argument['isNew'] == true;
        return mappedSession;
      }
    }

    _isNewSession = true;
    return const TrainerDraftSession(
      title: '',
      focus: '',
      totalExercises: 0,
      durationMinutes: 60,
      exercises: [],
    );
  }

  @override
  void initState() {
    super.initState();
    final session = _resolveSession();
    _titleController = TextEditingController(text: session.title);
    _durationMinutes = session.durationMinutes;
    _exercises = List<TrainerDraftExercise>.from(session.exercises);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  String get _focusSummary {
    if (_exercises.isEmpty) {
      return 'Belum ada latihan dipilih';
    }
    final focusLabels = _exercises
        .map((exercise) => exercise.targetMuscle)
        .toSet()
        .take(3)
        .join(' • ');
    return focusLabels;
  }

  Future<void> _showExerciseEditor({
    TrainerDraftExercise? existing,
    int? index,
  }) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final targetController =
        TextEditingController(text: existing?.targetMuscle ?? '');
    final setsController =
        TextEditingController(text: existing?.sets.toString() ?? '');
    final repsController =
        TextEditingController(text: existing?.reps.toString() ?? '');

    final updatedExercise = await showDialog<TrainerDraftExercise>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          existing == null ? 'Tambah Latihan Manual' : 'Edit Latihan',
          style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ExerciseField(
                label: 'Nama latihan',
                child: _EditTextField(
                  controller: nameController,
                  hintText: 'Contoh: Dumbbell Bench Press',
                ),
              ),
              const SizedBox(height: 12),
              _ExerciseField(
                label: 'Target otot',
                child: _EditTextField(
                  controller: targetController,
                  hintText: 'Contoh: Chest',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ExerciseField(
                      label: 'Sets',
                      child: _EditTextField(
                        controller: setsController,
                        hintText: '4',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ExerciseField(
                      label: 'Reps',
                      child: _EditTextField(
                        controller: repsController,
                        hintText: '10',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Batal',
              style: Theme.of(dialogContext).textTheme.titleSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () {
              final name = nameController.text.trim();
              final target = targetController.text.trim();
              final sets = int.tryParse(setsController.text.trim()) ?? 0;
              final reps = int.tryParse(repsController.text.trim()) ?? 0;

              if (name.isEmpty || target.isEmpty || sets <= 0 || reps <= 0) {
                Get.snackbar(
                  'Latihan Belum Lengkap',
                  'Isi nama, target otot, sets, dan reps dengan valid.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: AppColors.surface,
                  colorText: AppColors.textPrimary,
                );
                return;
              }

              final exercise = TrainerDraftExercise(
                name: name,
                targetMuscle: target,
                sets: sets,
                reps: reps,
                equipmentId: existing?.equipmentId,
                equipmentName: existing?.equipmentName,
                equipmentMovementId: existing?.equipmentMovementId,
              );

              Navigator.of(dialogContext).pop(exercise);
            },
            child: Text(existing == null ? 'Tambah' : 'Simpan'),
          ),
        ],
      ),
    );

    if (updatedExercise == null) {
      return;
    }

    setState(() {
      if (index == null) {
        _exercises.add(updatedExercise);
      } else {
        _exercises[index] = updatedExercise;
      }
    });
  }

  Future<void> _showDatabasePicker() async {
    if (_loadingEquipment) return;
    setState(() => _loadingEquipment = true);
    List<EquipmentInfo> equipments;
    try {
      equipments = await BackendPublicService().getEquipments();
    } catch (error) {
      if (!mounted) return;
      Get.snackbar(
        'Database Alat Tidak Tersedia',
        error.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
      return;
    } finally {
      if (mounted) setState(() => _loadingEquipment = false);
    }
    if (!mounted) return;

    final selection = await pickEquipmentMovementExercise(context, equipments);
    if (selection == null || !mounted) return;
    setState(
      () => _exercises.add(
        TrainerDraftExercise(
          name: selection.movement.movementName,
          targetMuscle: selection.movement.targetArea,
          sets: selection.sets,
          reps: selection.reps,
          equipmentId: selection.equipment.id,
          equipmentName: selection.equipment.name,
          equipmentMovementId: selection.movement.id,
        ),
      ),
    );
  }

  void _deleteExercise(int index) {
    final removed = _exercises[index];
    setState(() {
      _exercises.removeAt(index);
    });
    Get.snackbar(
      'Latihan Dihapus',
      '${removed.name} dikeluarkan dari sesi.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.surface,
      colorText: AppColors.textPrimary,
    );
  }

  void _saveSession() {
    final title = _titleController.text.trim();
    if (title.isEmpty || _exercises.isEmpty) {
      Get.snackbar(
        'Sesi Belum Lengkap',
        'Isi nama sesi dan minimal satu latihan sebelum menyimpan.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
      return;
    }

    final session = TrainerDraftSession(
      title: title,
      focus: _focusSummary,
      totalExercises: _exercises.length,
      durationMinutes: _durationMinutes,
      exercises: _exercises,
    );

    Get.back(result: session);
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedScreen(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          DetailScreenHeader(
            title: 'Buat Sesi',
            subtitle: _isNewSession
                ? 'Susun sesi baru untuk draft program trainer.'
                : 'Edit isi sesi, daftar latihan, dan struktur beban demo.',
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
                      StatusChip(label: 'SESSION BUILDER'),
                      StatusChip(label: 'TRAINER EDIT'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Edit Training Session',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Trainer bisa mengelola nama sesi, daftar latihan, input dari database, atau menambah latihan manual untuk demo flow utama.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.45,
                        ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _TopMetricCard(
                          label: 'LATIHAN',
                          value: '${_exercises.length}',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TopMetricCard(
                          label: 'DURASI',
                          value: '${_durationMinutes}m',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TopMetricCard(
                          label: 'FOCUS',
                          value: _exercises.isEmpty ? 'Draft' : 'Ready',
                        ),
                      ),
                    ],
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
                Text(
                  'Nama Sesi',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 14),
                _EditTextField(
                  controller: _titleController,
                  hintText: 'Contoh: Leg Power Day',
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
                      'Daftar Latihan',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      '${_exercises.length} LATIHAN',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ..._exercises.asMap().entries.map(
                      (entry) => Padding(
                        padding: EdgeInsets.only(
                          bottom: entry.key == _exercises.length - 1 ? 0 : 10,
                        ),
                        child: _ExerciseCard(
                          exercise: entry.value,
                          onEdit: () => _showExerciseEditor(
                            existing: entry.value,
                            index: entry.key,
                          ),
                          onDelete: () => _deleteExercise(entry.key),
                        ),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: EggButton.secondary(
                  label: 'Pilih Database',
                  icon: Icons.storage_rounded,
                  onPressed: _loadingEquipment ? () {} : _showDatabasePicker,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: EggButton.secondary(
                  label: 'Tambah Manual',
                  icon: Icons.add_rounded,
                  onPressed: _showExerciseEditor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          EggButton.primary(
            label: 'Simpan Sesi',
            icon: Icons.save_outlined,
            onPressed: _saveSession,
          ),
        ],
      ),
    );
  }
}

class _EditTextField extends StatelessWidget {
  const _EditTextField({
    required this.controller,
    required this.hintText,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: AppColors.surfaceSoft,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
      ),
    );
  }
}

class _ExerciseField extends StatelessWidget {
  const _ExerciseField({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 0.8,
              ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _TopMetricCard extends StatelessWidget {
  const _TopMetricCard({
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
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textPrimary.withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.onEdit,
    required this.onDelete,
  });

  final TrainerDraftExercise exercise;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.fitness_center_rounded,
              color: AppColors.accent,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  exercise.equipmentName == null
                      ? exercise.targetMuscle.toUpperCase()
                      : '${exercise.targetMuscle} · ${exercise.equipmentName}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${exercise.sets} set × ${exercise.reps} reps',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _ExerciseIconButton(
            icon: Icons.edit_outlined,
            onTap: onEdit,
          ),
          const SizedBox(width: 8),
          _ExerciseIconButton(
            icon: Icons.delete_outline_rounded,
            onTap: onDelete,
          ),
        ],
      ),
    );
  }
}

class _ExerciseIconButton extends StatelessWidget {
  const _ExerciseIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 17, color: AppColors.textSecondary),
      ),
    );
  }
}
