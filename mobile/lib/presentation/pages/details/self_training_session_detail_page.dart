import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/data/services/backend_self_training_service.dart';
import 'package:egg_gym/presentation/widgets/common/decorated_screen.dart';
import 'package:egg_gym/presentation/widgets/common/egg_button.dart';
import 'package:egg_gym/presentation/widgets/common/self_training_exercise_tile.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Halaman detail satu sesi Latihan Mandiri (Movement Checklist per sesi).
///
/// Argumen: { 'programId': int, 'session': SelfTrainingSessionData }.
/// Render awal langsung dari objek [session] yang dioper (tanpa fetch).
/// Re-fetch HANYA dipicu aksi user nyata (centang/tambah/hapus) untuk menjaga
/// progress tetap dari backend (anti bug "0 OF 0"), bukan hitung lokal.
class SelfTrainingSessionDetailPage extends StatefulWidget {
  const SelfTrainingSessionDetailPage({super.key});

  @override
  State<SelfTrainingSessionDetailPage> createState() =>
      _SelfTrainingSessionDetailPageState();
}

class _SelfTrainingSessionDetailPageState
    extends State<SelfTrainingSessionDetailPage> {
  final BackendSelfTrainingService _service = BackendSelfTrainingService();
  SelfTrainingSessionData? _session;
  int? _programId;
  bool _isRefreshing = false;
  // Menandai ada perubahan agar halaman daftar ikut reload saat kembali.
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    final arg = Get.arguments;
    if (arg is Map) {
      final id = arg['programId'];
      _programId = id is int ? id : int.tryParse('${id ?? ''}');
      final session = arg['session'];
      if (session is SelfTrainingSessionData) _session = session;
    }
  }

  /// Re-fetch program lalu ambil ulang sesi ini by id. Dipanggil HANYA setelah
  /// aksi user (bukan saat rebuild). Menjaga angka progress dari backend.
  Future<void> _refreshSession() async {
    final programId = _programId;
    final sessionId = _session?.id;
    if (programId == null || sessionId == null) return;

    setState(() => _isRefreshing = true);
    try {
      final programs = await _service.getPrograms();
      final program = programs.where((p) => p.id == programId).firstOrNull;
      final updated =
          program?.sessions.where((s) => s.id == sessionId).firstOrNull;
      if (!mounted) return;
      setState(() {
        if (updated != null) _session = updated;
        _isRefreshing = false;
        _changed = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRefreshing = false);
      Get.snackbar(
        'Gagal',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
    }
  }

  Future<void> _toggleExercise(SelfTrainingExerciseData exercise) async {
    final programId = _programId;
    final sessionId = _session?.id;
    if (programId == null || sessionId == null) return;
    try {
      await _service.toggleExercise(
        programId: programId,
        sessionId: sessionId,
        exerciseId: exercise.id,
      );
      await _refreshSession();
    } catch (e) {
      if (!mounted) return;
      Get.snackbar(
        'Gagal',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
    }
  }

  Future<void> _deleteExercise(SelfTrainingExerciseData exercise) async {
    final programId = _programId;
    final sessionId = _session?.id;
    if (programId == null || sessionId == null) return;
    try {
      await _service.deleteExercise(
        programId: programId,
        sessionId: sessionId,
        exerciseId: exercise.id,
      );
      await _refreshSession();
    } catch (e) {
      if (!mounted) return;
      Get.snackbar(
        'Gagal',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
    }
  }

  Future<void> _addExercise() => _openExerciseForm();

  /// Dialog tambah/edit gerakan (reuse). Bila [existing] null -> tambah baru
  /// (addExercise); bila terisi -> edit (updateExercise) dengan field terisi
  /// nama/target/sets/reps/load saat ini. Keduanya -> _refreshSession().
  Future<void> _openExerciseForm({SelfTrainingExerciseData? existing}) async {
    final programId = _programId;
    final sessionId = _session?.id;
    if (programId == null || sessionId == null) return;

    final isEdit = existing != null;
    final nameController = TextEditingController(text: existing?.name ?? '');
    final targetController =
        TextEditingController(text: existing?.targetMuscle ?? '');
    final setsController =
        TextEditingController(text: '${existing?.sets ?? 3}');
    final repsController =
        TextEditingController(text: '${existing?.reps ?? 10}');
    final loadController = TextEditingController(text: existing?.load ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isEdit ? 'Edit Latihan' : 'Tambah Latihan'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: 12),
              // Load opsional (String?, mis. "85kg"). Bila kosong -> null, kotak
              // LOAD di kartu tetap tampil "-" (tidak dikarang).
              TextField(
                controller: loadController,
                decoration: const InputDecoration(
                  labelText: 'Load (opsional)',
                  hintText: 'Contoh: 85kg',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.background,
            ),
            child: Text(isEdit ? 'Simpan' : 'Tambah'),
          ),
        ],
      ),
    );

    if (ok == true && nameController.text.trim().isNotEmpty) {
      final target = targetController.text.trim().isNotEmpty
          ? targetController.text.trim()
          : null;
      final load = loadController.text.trim().isNotEmpty
          ? loadController.text.trim()
          : null;
      final sets = int.tryParse(setsController.text) ?? 3;
      final reps = int.tryParse(repsController.text) ?? 10;
      try {
        if (isEdit) {
          await _service.updateExercise(
            programId: programId,
            sessionId: sessionId,
            exerciseId: existing.id,
            name: nameController.text.trim(),
            targetMuscle: target,
            sets: sets,
            reps: reps,
            load: load,
            equipmentId: existing.equipmentId,
            equipmentName: existing.equipmentName,
            equipmentMovementId: existing.equipmentMovementId,
          );
        } else {
          await _service.addExercise(
            programId: programId,
            sessionId: sessionId,
            name: nameController.text.trim(),
            targetMuscle: target,
            sets: sets,
            reps: reps,
            load: load,
          );
        }
        await _refreshSession();
      } catch (e) {
        if (!mounted) return;
        Get.snackbar(
          'Gagal',
          e.toString().replaceAll('Exception: ', ''),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.surface,
          colorText: AppColors.textPrimary,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return DecoratedScreen(
      child: session == null ? _buildEmpty() : _buildContent(session),
    );
  }

  Widget _buildEmpty() {
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
              'Data sesi tidak tersedia.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            EggButton.secondary(
              label: 'Kembali',
              onPressed: () => Get.back(result: _changed),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(SelfTrainingSessionData session) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => Get.back(result: _changed),
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              color: AppColors.textPrimary,
            ),
            const Spacer(),
            if (_isRefreshing)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _buildHeaderCard(session),
        const SizedBox(height: 18),
        Text(
          'Daftar Latihan',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        if (session.exercises.isEmpty)
          Text(
            'Belum ada latihan pada sesi ini.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          )
        else
          ...session.exercises.map((exercise) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SelfTrainingExerciseTile(
                  exercise: exercise,
                  onToggle: () => _toggleExercise(exercise),
                  onEdit: () => _openExerciseForm(existing: exercise),
                  onDelete: () => _deleteExercise(exercise),
                ),
              )),
        const SizedBox(height: 12),
        EggButton.secondary(
          label: '+ Tambah Latihan',
          onPressed: _addExercise,
        ),
      ],
    );
  }

  // Header sesi bergaya "CURRENT FOCUS". Progress memakai sumber yang SAMA
  // dengan kartu daftar sesi (jumlah gerakan tercentang / total) -- bukan
  // perhitungan baru.
  Widget _buildHeaderCard(SelfTrainingSessionData session) {
    final completed = session.exercises.where((e) => e.isCompleted).length;
    final total = session.exercises.length;
    final percent = total > 0 ? (completed / total * 100).round() : 0;
    final title = 'Sesi ${session.sequenceOrder}: ${session.title}';

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'SESI',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: const TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                      letterSpacing: -2,
                      color: Color(0x0FF5C518),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CURRENT FOCUS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: Color(0xFF9A9A9A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      letterSpacing: -0.5,
                      color: Color(0xFFFFFFFF),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$percent',
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                          letterSpacing: -1,
                          color: Color(0xFFFFFFFF),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: 2, bottom: 4),
                        child: Text(
                          '%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF9A9A9A),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '$completed OF $total EXERCISES',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF9A9A9A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: percent / 100,
                      minHeight: 6,
                      backgroundColor: const Color(0xFF2A2A2A),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFF5C518),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
