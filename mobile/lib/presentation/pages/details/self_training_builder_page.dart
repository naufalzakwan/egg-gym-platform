import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/data/services/backend_self_training_service.dart';
import 'package:egg_gym/data/services/backend_public_service.dart';
import 'package:egg_gym/presentation/widgets/common/decorated_screen.dart';
import 'package:egg_gym/presentation/widgets/common/detail_screen_header.dart';
import 'package:egg_gym/presentation/widgets/common/egg_button.dart';
import 'package:egg_gym/presentation/widgets/common/egg_card.dart';
import 'package:egg_gym/presentation/widgets/common/status_chip.dart';
import 'package:egg_gym/presentation/widgets/common/equipment_movement_exercise_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class _DraftExercise {
  _DraftExercise({
    required this.name,
    this.targetMuscle,
    required this.sets,
    required this.reps,
    this.equipmentId,
    this.equipmentName,
    this.equipmentMovementId,
  });

  final String name;
  final String? targetMuscle;
  final int sets;
  final int reps;
  final int? equipmentId;
  final String? equipmentName;
  final int? equipmentMovementId;
}

class _DraftSession {
  _DraftSession({
    String? title,
    List<_DraftExercise>? exercises,
  })  : titleController = TextEditingController(text: title ?? ''),
        exercises = exercises ?? [];

  // Nama sesi editable inline (Figma A: supra-label "NAMA SESI" + input field).
  final TextEditingController titleController;
  final List<_DraftExercise> exercises;

  // Dipakai _saveProgram lewat session.title -> tetap kompatibel tanpa ubah logic.
  String get title => titleController.text.trim();

  int get totalExercises => exercises.length;

  void dispose() => titleController.dispose();
}

class SelfTrainingBuilderPage extends StatefulWidget {
  const SelfTrainingBuilderPage({super.key});

  @override
  State<SelfTrainingBuilderPage> createState() =>
      _SelfTrainingBuilderPageState();
}

class _SelfTrainingBuilderPageState extends State<SelfTrainingBuilderPage> {
  final BackendSelfTrainingService _service = BackendSelfTrainingService();
  final _programNameController = TextEditingController(text: 'Program Mandiri');
  final _programDescController = TextEditingController();
  final List<_DraftSession> _sessions = [];
  bool _isSaving = false;
  bool _isLoadingEquipment = false;

  @override
  void dispose() {
    _programNameController.dispose();
    _programDescController.dispose();
    for (final session in _sessions) {
      session.dispose();
    }
    super.dispose();
  }

  void _addSession() {
    // Nama sesi diketik inline di kartu (Figma A), jadi tak perlu dialog.
    setState(() {
      _sessions.add(_DraftSession());
    });
  }

  void _removeSession(int index) {
    setState(() {
      _sessions[index].dispose();
      _sessions.removeAt(index);
    });
  }

  // Form tambah/edit gerakan (draft lokal). Bila [exerciseIndex] diisi -> mode
  // edit gerakan yang sudah ada; bila null -> tambah baru. Tanpa field beban
  // (Figma: nama, sets, reps, target otot).
  void _openExerciseForm(int sessionIndex, {int? exerciseIndex}) {
    final existing = exerciseIndex != null
        ? _sessions[sessionIndex].exercises[exerciseIndex]
        : null;
    final nameController = TextEditingController(text: existing?.name ?? '');
    final targetController =
        TextEditingController(text: existing?.targetMuscle ?? '');
    final setsController =
        TextEditingController(text: '${existing?.sets ?? 3}');
    final repsController =
        TextEditingController(text: '${existing?.reps ?? 10}');

    Get.defaultDialog(
      title: existing == null ? 'Tambah Latihan' : 'Edit Latihan',
      titleStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Latihan',
                hintText: 'Contoh: Barbell Back Squat',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: targetController,
              decoration: const InputDecoration(
                labelText: 'Target Otot',
                hintText: 'Contoh: Quadriceps',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: setsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Sets'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: repsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Reps'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      confirm: ElevatedButton(
        onPressed: () {
          final name = nameController.text.trim();
          final target = targetController.text.trim();
          final sets = int.tryParse(setsController.text.trim()) ?? 0;
          final reps = int.tryParse(repsController.text.trim()) ?? 0;
          if (name.isEmpty || target.isEmpty || sets <= 0 || reps <= 0) {
            Get.snackbar(
              'Latihan Belum Lengkap',
              'Isi nama, target otot, sets, dan reps dengan angka lebih dari 0.',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: AppColors.surface,
              colorText: AppColors.textPrimary,
            );
            return;
          }
          Get.back();
          final draft = _DraftExercise(
            name: name,
            targetMuscle: target,
            sets: sets,
            reps: reps,
            equipmentId: existing?.equipmentId,
            equipmentName: existing?.equipmentName,
            equipmentMovementId: existing?.equipmentMovementId,
          );
          setState(() {
            if (exerciseIndex != null) {
              _sessions[sessionIndex].exercises[exerciseIndex] = draft;
            } else {
              _sessions[sessionIndex].exercises.add(draft);
            }
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.background,
        ),
        child: Text(existing == null ? 'Tambah' : 'Simpan'),
      ),
      cancel: TextButton(
        onPressed: () => Get.back(),
        child: const Text('Batal'),
      ),
    );
  }

  Future<void> _openDatabasePicker(int sessionIndex) async {
    if (_isLoadingEquipment) return;
    setState(() => _isLoadingEquipment = true);
    try {
      final equipments = await BackendPublicService().getEquipments();
      if (!mounted) return;
      final selection =
          await pickEquipmentMovementExercise(context, equipments);
      if (selection == null || !mounted) return;
      setState(() {
        _sessions[sessionIndex].exercises.add(
              _DraftExercise(
                name: selection.movement.movementName,
                targetMuscle: selection.movement.targetArea,
                sets: selection.sets,
                reps: selection.reps,
                equipmentId: selection.equipment.id,
                equipmentName: selection.equipment.name,
                equipmentMovementId: selection.movement.id,
              ),
            );
      });
    } catch (error) {
      if (!mounted) return;
      Get.snackbar(
        'Database Alat Tidak Tersedia',
        error.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
    } finally {
      if (mounted) setState(() => _isLoadingEquipment = false);
    }
  }

  void _removeExercise(int sessionIndex, int exerciseIndex) {
    setState(() {
      _sessions[sessionIndex].exercises.removeAt(exerciseIndex);
    });
  }

  Future<void> _saveProgram() async {
    final title = _programNameController.text.trim();
    if (title.isEmpty) {
      Get.snackbar('Error', 'Nama program wajib diisi.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.surface,
          colorText: AppColors.textPrimary);
      return;
    }

    if (_sessions.isEmpty) {
      Get.snackbar('Error', 'Tambah minimal 1 sesi.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.surface,
          colorText: AppColors.textPrimary);
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Create program
      final program = await _service.createProgram(
        title: title,
        description: _programDescController.text.trim().isNotEmpty
            ? _programDescController.text.trim()
            : null,
      );

      // Create sessions and exercises
      for (int i = 0; i < _sessions.length; i++) {
        final session = _sessions[i];
        final createdSession = await _service.createSession(
          programId: program.id,
          title: session.title,
        );

        // Add exercises to session
        for (int j = 0; j < session.exercises.length; j++) {
          final exercise = session.exercises[j];
          await _service.addExercise(
            programId: program.id,
            sessionId: createdSession.id,
            name: exercise.name,
            targetMuscle: exercise.targetMuscle,
            sets: exercise.sets,
            reps: exercise.reps,
            equipmentId: exercise.equipmentId,
            equipmentName: exercise.equipmentName,
            equipmentMovementId: exercise.equipmentMovementId,
          );
        }
      }

      if (!mounted) return;

      Get.back();
      Get.snackbar(
        'Program Tersimpan',
        'Program "$title" berhasil dibuat dengan ${_sessions.length} sesi.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      Get.snackbar(
        'Gagal',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalExercises =
        _sessions.fold<int>(0, (sum, s) => sum + s.totalExercises);

    return DecoratedScreen(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const DetailScreenHeader(
            title: 'Buat Latihan Mandiri',
            subtitle:
                'Buat program latihan untuk diri sendiri. Tambah sesi dan exercise sesuai kebutuhan.',
          ),
          const SizedBox(height: 20),
          // Program Info Card
          EggCard(
            highlight: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Informasi Program',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _programNameController,
                  label: 'Nama Program',
                  hint: 'Contoh: Morning Stretch',
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _programDescController,
                  label: 'Deskripsi (opsional)',
                  hint: 'Contoh: Program stretching pagi hari',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    StatusChip(
                      label: '${_sessions.length} Sesi',
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 8),
                    StatusChip(
                      label: '$totalExercises Exercise',
                      color: AppColors.accent,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // Sessions
          Row(
            children: [
              Text(
                'Struktur Sesi',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              SizedBox(
                width: 160,
                child: EggButton.secondary(
                  label: '+ Tambah Sesi',
                  onPressed: _addSession,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_sessions.isEmpty)
            EggCard(
              child: Column(
                children: [
                  const Icon(Icons.event_note_rounded,
                      size: 48, color: AppColors.textSecondary),
                  const SizedBox(height: 12),
                  Text(
                    'Belum ada sesi',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tekan "Tambah Sesi" untuk mulai menyusun program.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            )
          else
            ..._sessions.asMap().entries.map((entry) {
              final index = entry.key;
              final session = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildSessionCard(index, session),
              );
            }),
          const SizedBox(height: 18),
          EggButton.primary(
            label: _isSaving ? 'Menyimpan...' : 'Simpan Program',
            onPressed: _isSaving ? () {} : _saveProgram,
          ),
          const SizedBox(height: 10),
          EggButton.secondary(
            label: 'Batal',
            onPressed: () => Get.back(),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(int index, _DraftSession session) {
    return EggCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baris nomor sesi + aksi hapus sesi.
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: AppColors.background,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Sesi ${index + 1}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              IconButton(
                onPressed: () => _removeSession(index),
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.error, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Figma A: supra-label "NAMA SESI" + input field nama sesi (inline).
          Text(
            'NAMA SESI',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: session.titleController,
            style: Theme.of(context).textTheme.bodyMedium,
            onChanged: (_) => setState(() {}), // segarkan pill/label bila perlu
            decoration: InputDecoration(
              hintText: 'Contoh: Leg Power Day',
              filled: true,
              fillColor: AppColors.surfaceSoft,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppColors.accent, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Figma B: sub-header "Daftar Latihan" + pill kuning "X LATIHAN".
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daftar Latihan',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${session.totalExercises} LATIHAN',
                  style: const TextStyle(
                    color: AppColors.background,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Figma C: daftar kartu gerakan.
          ...session.exercises.asMap().entries.map((entry) {
            final exIndex = entry.key;
            final exercise = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildExerciseTile(index, exIndex, exercise),
            );
          }),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: EggButton.secondary(
                  label: 'Pilih Database',
                  onPressed: _isLoadingEquipment
                      ? () {}
                      : () => _openDatabasePicker(index),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: EggButton.secondary(
                  label: 'Tambah Manual',
                  onPressed: () => _openExerciseForm(index),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseTile(
      int sessionIndex, int exerciseIndex, _DraftExercise exercise) {
    // Figma C: kartu gerakan. Tanpa drag-handle (reorder belum ada logic).
    // Konten: nama (bold) -> meta "X sets - Y reps" (ikon kuning) -> target otot
    // uppercase abu. Aksi kanan: edit (pensil) + delete, keduanya fungsional.
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                Text(
                  exercise.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (exercise.targetMuscle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    exercise.targetMuscle!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                  ),
                ],
                const SizedBox(height: 6),
                // Meta sets & reps dengan ikon kecil kuning.
                Row(
                  children: [
                    const Icon(Icons.repeat_rounded,
                        size: 14, color: AppColors.accent),
                    const SizedBox(width: 4),
                    Text(
                      '${exercise.sets} sets',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.fitness_center_rounded,
                        size: 14, color: AppColors.accent),
                    const SizedBox(width: 4),
                    Text(
                      '${exercise.reps} reps',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Aksi: edit (pensil) + delete. Keduanya beroperasi di draft lokal.
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () =>
                _openExerciseForm(sessionIndex, exerciseIndex: exerciseIndex),
            icon: const Icon(Icons.edit_outlined,
                color: AppColors.textSecondary, size: 18),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => _removeExercise(sessionIndex, exerciseIndex),
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.error, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: Theme.of(context).textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: AppColors.surfaceSoft,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
