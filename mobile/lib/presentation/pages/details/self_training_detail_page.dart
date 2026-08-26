import 'package:egg_gym/app/routes/app_routes.dart';
import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/data/services/backend_self_training_service.dart';
import 'package:egg_gym/presentation/widgets/common/decorated_screen.dart';
import 'package:egg_gym/presentation/widgets/common/egg_button.dart';
import 'package:egg_gym/presentation/widgets/common/egg_card.dart';
import 'package:egg_gym/presentation/widgets/common/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SelfTrainingDetailPage extends StatefulWidget {
  const SelfTrainingDetailPage({super.key});

  @override
  State<SelfTrainingDetailPage> createState() => _SelfTrainingDetailPageState();
}

class _SelfTrainingDetailPageState extends State<SelfTrainingDetailPage> {
  final BackendSelfTrainingService _service = BackendSelfTrainingService();
  SelfTrainingProgramData? _program;
  bool _isLoading = true;
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

  Future<void> _addSession() => _openSessionForm();

  /// Dialog tambah/edit sesi (reuse). Bila [existing] null -> tambah baru
  /// (createSession); bila terisi -> edit (updateSession) dengan field terisi
  /// judul & fokus saat ini. Keduanya lalu _loadProgram() untuk refresh.
  Future<void> _openSessionForm({SelfTrainingSessionData? existing}) async {
    final isEdit = existing != null;
    final titleController = TextEditingController(text: existing?.title ?? '');
    final focusController = TextEditingController(text: existing?.focus ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isEdit ? 'Edit Sesi' : 'Tambah Sesi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Judul Sesi',
                hintText: 'Contoh: Upper Body',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: focusController,
              decoration: const InputDecoration(
                labelText: 'Fokus (opsional)',
                hintText: 'Contoh: Chest & Triceps',
              ),
            ),
          ],
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

    if (result == true && titleController.text.trim().isNotEmpty) {
      final focus = focusController.text.trim().isNotEmpty
          ? focusController.text.trim()
          : null;
      try {
        if (isEdit) {
          await _service.updateSession(
            programId: _program!.id,
            sessionId: existing.id,
            title: titleController.text.trim(),
            focus: focus,
          );
        } else {
          await _service.createSession(
            programId: _program!.id,
            title: titleController.text.trim(),
            focus: focus,
          );
        }
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
      }
    }
  }

  Future<void> _deleteSession(SelfTrainingSessionData session) async {
    try {
      await _service.deleteSession(_program!.id, session.id);
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
            const Spacer(),
            IconButton(
              onPressed: _loadProgram,
              icon: const Icon(Icons.refresh_rounded),
              color: AppColors.textSecondary,
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Progress card (CURRENT FOCUS). Angka progress & exercise memakai
        // sumber yang SUDAH dipakai: program.progressPercent /
        // completedExercises / totalExercises -- tanpa perhitungan baru.
        ClipRRect(
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
                // Watermark dekoratif dari judul program (data nyata), ~6%
                // opacity, di belakang konten & tidak menangkap gesture.
                Positioned.fill(
                  child: IgnorePointer(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'LATIHAN',
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
                        program.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          letterSpacing: -0.5,
                          color: Color(0xFFFFFFFF),
                        ),
                      ),
                      if (program.description != null &&
                          program.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          program.description!.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: Color(0xFF9A9A9A),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${program.progressPercent}',
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
                              '${program.completedExercises} OF ${program.totalExercises} EXERCISES',
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
                          value: program.progressPercent / 100,
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
        ),
        const SizedBox(height: 18),
        // Tombol "Mulai Latihan" dihapus (redundan): tiap kartu sesi sudah bisa
        // ditekan untuk masuk & memulai sesinya masing-masing.
        // Sessions. Tombol "+ Tambah Sesi" dipindah ke bawah daftar (lihat akhir).
        Text(
          'Sesi Latihan',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        if (program.sessions.isEmpty)
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
                  'Tambah sesi latihan untuk mulai membuat program.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          )
        else
          ...program.sessions.map((session) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildSessionCard(session),
              )),
        const SizedBox(height: 4),
        // Tombol "+ Tambah Sesi" dipindah ke bawah daftar, gaya full-width
        // konsisten dengan "+ Tambah Latihan". Fungsi (_addSession) tidak diubah.
        EggButton.secondary(
          label: '+ Tambah Sesi',
          onPressed: _addSession,
        ),
      ],
    );
  }

  // Buka halaman detail sesi (halaman terpisah). Oper objek session yang sudah
  // ada di memori -> tanpa fetch awal. Halaman sesi mengembalikan `true` bila
  // ada perubahan (centang/tambah/hapus); baru saat itu daftar di-reload agar
  // persen kartu sesi ikut update. Tidak re-fetch tanpa perubahan.
  Future<void> _openSession(SelfTrainingSessionData session) async {
    final result = await Get.toNamed(
      AppRoutes.memberSelfTrainingSessionDetail,
      arguments: {'programId': _program!.id, 'session': session},
    );
    if (result == true) {
      await _loadProgram();
    }
  }

  Widget _buildSessionCard(SelfTrainingSessionData session) {
    // Progress per sesi memakai sumber yang SUDAH dipakai (jumlah gerakan
    // tercentang / total di badge) -- bukan perhitungan baru berisiko beda.
    final completedCount = session.exercises.where((e) => e.isCompleted).length;
    final totalCount = session.exercises.length;
    final percent =
        totalCount > 0 ? (completedCount / totalCount * 100).round() : 0;

    return EggCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openSession(session),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Sesi ${session.sequenceOrder}: ${session.title}',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                StatusChip(
                  label: '$completedCount/$totalCount',
                  color: completedCount == totalCount && totalCount > 0
                      ? AppColors.success
                      : AppColors.accent,
                ),
                // Edit sesi (pensil): reuse dialog dalam mode edit, terisi judul
                // & fokus saat ini -> updateSession (endpoint PUT yang sudah ada).
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _openSessionForm(existing: session),
                  icon: const Icon(Icons.edit_outlined,
                      color: AppColors.textSecondary, size: 20),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _deleteSession(session),
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.error, size: 20),
                ),
                // Panah ">" menandakan masuk ke halaman lain (bukan buka-tutup).
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary),
              ],
            ),
            // Fokus sesi (opsional, dari field yang diinput di dialog "+ Tambah
            // Sesi"). Tampil hanya bila diisi; kalau kosong barisnya disembunyikan.
            if (session.focus != null && session.focus!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                session.focus!.trim(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
            const SizedBox(height: 10),
            // Persen + progress bar tipis fill kuning (gaya Current Phase Card).
            Text(
              '$percent%',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
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
    );
  }
}
