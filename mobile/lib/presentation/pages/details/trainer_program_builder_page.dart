import 'package:egg_gym/app/routes/app_routes.dart';
import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/core/formatters/app_date_formatter.dart';
import 'package:egg_gym/data/services/backend_program_service.dart';
import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:egg_gym/domain/repositories/demo_repository.dart';
import 'package:egg_gym/presentation/widgets/common/decorated_screen.dart';
import 'package:egg_gym/presentation/widgets/common/detail_screen_header.dart';
import 'package:egg_gym/presentation/widgets/common/egg_button.dart';
import 'package:egg_gym/presentation/widgets/common/egg_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class TrainerProgramBuilderPage extends StatefulWidget {
  const TrainerProgramBuilderPage({super.key});

  @override
  State<TrainerProgramBuilderPage> createState() =>
      _TrainerProgramBuilderPageState();
}

class _TrainerProgramBuilderPageState extends State<TrainerProgramBuilderPage> {
  final BackendProgramService _programService = BackendProgramService();

  late final TextEditingController _programNameController;
  late final TextEditingController _descriptionController;
  late List<TrainerDraftSession> _draftSessions;

  int _selectedClientIndex = 0;
  List<ProgramClient> _backendClients = [];
  bool _isSaving = false;
  String? _preSelectedClientName;
  ScheduleSession? _preSelectedSession;
  int? _preSelectedMemberProfileId;

  @override
  void initState() {
    super.initState();
    _resolveArguments();
    _programNameController = TextEditingController();
    _descriptionController = TextEditingController();
    _draftSessions = [];

    _loadClients();
  }

  @override
  void dispose() {
    _programNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  ClientSummary _selectedClient(List<ClientSummary> clients) {
    final safeIndex = _selectedClientIndex.clamp(0, clients.length - 1).toInt();
    return clients[safeIndex];
  }

  /// Jumlah sesi yang sudah dipilih & dibayar member saat proses pembayaran
  /// (diambil dari booking). Bernilai null bila builder dibuka tanpa konteks
  /// booking (mis. jalur dropdown klien lama), sehingga validasi tidak dipaksa.
  int? get _paidSessions {
    final count = _preSelectedSession?.sessionCount;
    if (count != null && count > 0) return count;
    return null;
  }

  TrainerDraftSession _buildEmptySession() {
    return const TrainerDraftSession(
      title: '',
      focus: '',
      totalExercises: 0,
      durationMinutes: 60,
      exercises: [],
    );
  }

  Future<void> _loadClients() async {
    try {
      final clients = await _programService.getTrainerClients();
      if (!mounted) return;
      setState(() {
        _backendClients = clients;
      });
    } catch (_) {}
  }

  void _resolveArguments() {
    final argument = Get.arguments;
    if (argument is Map<String, dynamic>) {
      final clientName = argument['clientName'];
      if (clientName is String && clientName.isNotEmpty) {
        _preSelectedClientName = clientName;
      }

      final session = argument['session'];
      if (session is ScheduleSession) {
        _preSelectedSession = session;
      }

      // Also try to get memberProfileId directly from arguments
      final memberProfileId = argument['memberProfileId'];
      if (memberProfileId is int && memberProfileId > 0) {
        _preSelectedMemberProfileId = memberProfileId;
      } else if (memberProfileId != null) {
        _preSelectedMemberProfileId = int.tryParse(memberProfileId.toString());
      }
    }
  }

  Future<void> _openTrainingSessionEditor({
    TrainerDraftSession? session,
    int? index,
  }) async {
    final result = await Get.toNamed(
      AppRoutes.editTrainingSession,
      arguments: <String, dynamic>{
        'session': session ?? _buildEmptySession(),
        'isNew': session == null,
      },
    );

    if (result is! TrainerDraftSession) {
      return;
    }

    setState(() {
      if (index == null) {
        _draftSessions.add(result);
      } else {
        _draftSessions[index] = result;
      }
    });
  }

  void _removeSession(int index) {
    final removed = _draftSessions[index];
    setState(() {
      _draftSessions.removeAt(index);
    });

    Get.snackbar(
      'Sesi Dihapus',
      '${removed.title} dikeluarkan dari draft program.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.surface,
      colorText: AppColors.textPrimary,
    );
  }

  void _saveProgram(List<ClientSummary> clients) async {
    final name = _programNameController.text.trim();
    final description = _descriptionController.text.trim();

    if (name.isEmpty || description.isEmpty) {
      Get.snackbar(
        'Program Belum Lengkap',
        'Isi nama dan deskripsi sebelum menyimpan program.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
      return;
    }

    if (_draftSessions.isEmpty) {
      Get.snackbar(
        'Sesi Belum Dibuat',
        'Tambahkan minimal 1 sesi latihan terlebih dahulu.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
      return;
    }

    // Validasi: jumlah sesi di Struktur Sesi harus sama persis dengan jumlah
    // sesi yang sudah dibayar member (tidak boleh kurang/lebih).
    final paidSessions = _paidSessions;
    if (paidSessions != null && _draftSessions.length != paidSessions) {
      final made = _draftSessions.length;
      final lessOrMore = made < paidSessions ? 'baru dibuat' : 'sudah dibuat';
      Get.snackbar(
        'Jumlah Sesi Belum Sesuai',
        'Member membayar untuk $paidSessions sesi tetapi $lessOrMore $made sesi. '
            '${made < paidSessions ? 'Tambah' : 'Kurangi'} sesi agar berjumlah $paidSessions sebelum menyimpan.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
        duration: const Duration(seconds: 4),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Use pre-selected memberProfileId if available, otherwise fallback to selected client
      final memberProfileId =
          _preSelectedMemberProfileId ?? _selectedClient(clients).backendId;
      debugPrint(
          'DEBUG _saveProgram: _preSelectedMemberProfileId=$_preSelectedMemberProfileId, selectedClient.backendId=${_selectedClient(clients).backendId}, final memberProfileId=$memberProfileId');

      if (memberProfileId == null || memberProfileId <= 0) {
        Get.snackbar(
          'Klien Tidak Valid',
          'Klien yang dipilih tidak memiliki ID backend. Coba pilih klien lain.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.surface,
          colorText: AppColors.textPrimary,
        );
        setState(() => _isSaving = false);
        return;
      }

      final sessions = _draftSessions.asMap().entries.map((entry) {
        final index = entry.key;
        final session = entry.value;
        return ProgramSession(
          sequenceOrder: index + 1,
          title: session.title,
          focus: session.focus,
          durationMinutes: session.durationMinutes,
          exercises: session.exercises
              .asMap()
              .entries
              .map((exerciseEntry) => ProgramExercise(
                    sequenceOrder: exerciseEntry.key + 1,
                    name: exerciseEntry.value.name,
                    targetMuscle: exerciseEntry.value.targetMuscle,
                    sets: exerciseEntry.value.sets,
                    reps: exerciseEntry.value.reps,
                    equipmentId: exerciseEntry.value.equipmentId,
                    equipmentName: exerciseEntry.value.equipmentName,
                    equipmentMovementId:
                        exerciseEntry.value.equipmentMovementId,
                  ))
              .toList(),
        );
      }).toList();

      final result = await _programService.createFullProgram(
        memberProfileId: memberProfileId,
        title: name,
        description: description,
        sessions: sessions,
        bookingId: _preSelectedSession?.backendId,
      );

      if (!mounted) return;

      Get.back();
      Get.snackbar(
        'Program Tersimpan',
        '"${result.title}" berhasil disimpan ke backend dengan status ${result.status}.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
        duration: const Duration(seconds: 3),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      Get.snackbar(
        'Gagal Menyimpan',
        error.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
        duration: const Duration(seconds: 3),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.read<DemoRepository>().getTrainerDashboard();
    final demoClients = dashboard.clients;
    final clients = _backendClients.isNotEmpty
        ? _backendClients
            .map((c) => ClientSummary(
                  backendId: c.memberProfileId,
                  memberCode: c.memberCode,
                  name: c.name,
                  goal: c.goal,
                  progressLabel: '${c.bookingCount} booking',
                  nextSession: 'Tersedia',
                  heightCm: c.heightCm,
                  weightKg: c.weightKg,
                  medicalNote: c.medicalNote,
                ))
            .toList()
        : demoClients;

    // Booking baru memilih klien berdasarkan ID backend agar nama yang sama
    // tidak membuat profil klien lain terlihat pada form.
    ClientSummary selectedClient;
    if (_preSelectedClientName != null || _preSelectedMemberProfileId != null) {
      final existingIndex = _preSelectedMemberProfileId != null
          ? clients.indexWhere(
              (c) => c.backendId == _preSelectedMemberProfileId,
            )
          : clients.indexWhere(
              (c) =>
                  c.name.toLowerCase() == _preSelectedClientName!.toLowerCase(),
            );
      if (existingIndex >= 0) {
        _selectedClientIndex = existingIndex;
        // Use the existing client but override backendId if we have it
        final existingClient = clients[existingIndex];
        selectedClient = ClientSummary(
          backendId: _preSelectedMemberProfileId ?? existingClient.backendId,
          memberCode: existingClient.memberCode,
          name: existingClient.name,
          goal: existingClient.goal,
          progressLabel: existingClient.progressLabel,
          nextSession: existingClient.nextSession,
          heightCm:
              _preSelectedSession?.memberHeightCm ?? existingClient.heightCm,
          weightKg:
              _preSelectedSession?.memberWeightKg ?? existingClient.weightKg,
          medicalNote: _preSelectedSession?.memberMedicalNote ??
              existingClient.medicalNote,
        );
      } else {
        // Create a temporary client entry for the pre-selected member
        selectedClient = ClientSummary(
          backendId: _preSelectedMemberProfileId ??
              _preSelectedSession?.memberProfileId,
          name: _preSelectedClientName ?? 'Member',
          goal: 'Program latihan',
          progressLabel: 'Booking terkonfirmasi',
          nextSession: _preSelectedSession?.timeRange ?? '-',
          heightCm: _preSelectedSession?.memberHeightCm,
          weightKg: _preSelectedSession?.memberWeightKg,
          medicalNote: _preSelectedSession?.memberMedicalNote,
        );
      }
    } else {
      selectedClient = _selectedClient(clients);
    }

    return DecoratedScreen(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          DetailScreenHeader(
            title: 'Buat Program',
            subtitle:
                'Susun latihan sesuai kondisi fisik, target, dan jadwal member.',
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
                  colors: [Color(0xFFFFD54D), AppColors.accentDeep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Susun Program Latihan',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.background,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Atur struktur latihan berdasarkan profil dan jadwal sesi member.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.background.withValues(alpha: 0.8),
                          height: 1.45,
                        ),
                  ),
                  const SizedBox(height: 18),
                  _HeroInfoRow(
                    label: 'Member',
                    value: selectedClient.name,
                  ),
                  const SizedBox(height: 10),
                  _HeroInfoRow(
                    label: 'Target / Tujuan',
                    value: _fallbackText(selectedClient.goal),
                  ),
                  const SizedBox(height: 10),
                  _HeroInfoRow(
                    label: 'Jumlah Sesi',
                    value: _paidSessions != null
                        ? 'Sesi yang harus dibuat: ${_draftSessions.length} dari $_paidSessions'
                        : '${_draftSessions.length} sesi disusun',
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Pastikan jumlah sesi program sesuai dengan jumlah sesi yang dibayar member.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.background,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
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
                Text(
                  'Profil Fisik Member',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Informasi read-only sebagai pertimbangan penyusunan program.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ProfileMetric(
                        label: 'Tinggi Badan (TB)',
                        value: selectedClient.heightCm != null
                            ? '${_formatMetric(selectedClient.heightCm!)} cm'
                            : 'Belum diisi',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ProfileMetric(
                        label: 'Berat Badan (BB)',
                        value: selectedClient.weightKg != null
                            ? '${_formatMetric(selectedClient.weightKg!)} kg'
                            : 'Belum diisi',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _SummaryRow(
                  label: 'Target Fitness',
                  value: _fallbackText(selectedClient.goal),
                ),
                const SizedBox(height: 10),
                _SummaryRow(
                  label: 'Catatan Medis',
                  value: _fallbackText(selectedClient.medicalNote),
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
                  'Detail Program',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 16),
                _SessionField(
                  label: 'Nama program',
                  child: _BuilderTextField(
                    controller: _programNameController,
                    hintText: 'Contoh: Hypertrophy Phase A',
                  ),
                ),
                const SizedBox(height: 14),
                _SessionField(
                  label: 'Deskripsi',
                  child: _BuilderTextField(
                    controller: _descriptionController,
                    hintText:
                        'Contoh: Program 4 minggu untuk meningkatkan massa otot...',
                    maxLines: 4,
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
                Row(
                  children: [
                    Text(
                      'Struktur Sesi',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _openTrainingSessionEditor(),
                      icon: const Icon(
                        Icons.add_rounded,
                        color: AppColors.accent,
                        size: 18,
                      ),
                      label: const Text(
                        'Tambah Sesi',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_draftSessions.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.fitness_center_rounded,
                          color: AppColors.textSecondary,
                          size: 30,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Belum ada sesi latihan',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _paidSessions == null
                              ? 'Tambahkan sesi latihan sesuai kebutuhan member.'
                              : 'Member membeli $_paidSessions sesi. Tambahkan $_paidSessions sesi latihan sebelum menyimpan program.',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1.45,
                                  ),
                        ),
                      ],
                    ),
                  )
                else
                  ..._draftSessions.asMap().entries.map(
                        (entry) => Padding(
                          padding: EdgeInsets.only(
                            bottom:
                                entry.key == _draftSessions.length - 1 ? 0 : 12,
                          ),
                          child: _DraftSessionCard(
                            index: entry.key,
                            session: entry.value,
                            scheduleLabel: _reservationLabel(entry.key),
                            onEdit: () => _openTrainingSessionEditor(
                              session: entry.value,
                              index: entry.key,
                            ),
                            onDelete: () => _removeSession(entry.key),
                          ),
                        ),
                      ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          EggButton.primary(
            label: _isSaving ? 'Menyimpan...' : 'Simpan Program',
            icon: Icons.save_outlined,
            onPressed: _isSaving ? () {} : () => _saveProgram(clients),
          ),
        ],
      ),
    );
  }

  String _formatMetric(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  String _fallbackText(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty || text == '-' ? 'Belum diisi' : text;
  }

  String _reservationLabel(int sessionIndex) {
    final reservations = _preSelectedSession?.reservations ?? const [];
    BookingSessionReservation? reservation;
    for (final item in reservations) {
      if (item.sequenceOrder == sessionIndex + 1) {
        reservation = item;
        break;
      }
    }
    if (reservation == null) return 'Jadwal belum tersedia';

    final date = AppDateFormatter.date(
      reservation.sessionDate,
      abbreviatedMonth: true,
    );
    return '$date | ${_shortTime(reservation.startTime)}–${_shortTime(reservation.endTime)}';
  }

  String _shortTime(String value) =>
      value.length >= 5 ? value.substring(0, 5) : value;
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 6),
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

InputDecoration _fieldDecoration({
  required String hintText,
}) {
  return InputDecoration(
    hintText: hintText,
    filled: true,
    fillColor: AppColors.surfaceSoft,
    hintStyle: const TextStyle(color: AppColors.textSecondary),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
  );
}

class _BuilderTextField extends StatelessWidget {
  const _BuilderTextField({
    required this.controller,
    required this.hintText,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hintText;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: _fieldDecoration(hintText: hintText),
    );
  }
}

class _SessionField extends StatelessWidget {
  const _SessionField({
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

class _HeroInfoRow extends StatelessWidget {
  const _HeroInfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.background.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.background,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
      ],
    );
  }
}

class _DraftSessionCard extends StatelessWidget {
  const _DraftSessionCard({
    required this.index,
    required this.session,
    required this.scheduleLabel,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final TrainerDraftSession session;
  final String scheduleLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SESI ${index + 1}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      session.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_outlined,
                          size: 15,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            scheduleLabel,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _SessionActionButton(
                icon: Icons.edit_outlined,
                onTap: onEdit,
              ),
              const SizedBox(width: 8),
              _SessionActionButton(
                icon: Icons.delete_outline_rounded,
                onTap: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            session.focus,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 14),
          _SessionMetricTile(
            label: 'TOTAL EXERCISE',
            value: '${session.totalExercises}',
          ),
        ],
      ),
    );
  }
}

class _SessionMetricTile extends StatelessWidget {
  const _SessionMetricTile({
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
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 0.7,
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

class _SessionActionButton extends StatelessWidget {
  const _SessionActionButton({
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
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 18, color: AppColors.textSecondary),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}
