import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/core/utils/schedule_time.dart';
import 'package:egg_gym/data/services/backend_trainer_service.dart';
import 'package:egg_gym/domain/entities/trainer_schedule_date.dart';
import 'package:egg_gym/presentation/widgets/common/decorated_screen.dart';
import 'package:egg_gym/presentation/widgets/common/egg_button.dart';
import 'package:egg_gym/presentation/widgets/common/egg_card.dart';
import 'package:egg_gym/presentation/widgets/common/egg_schedule_time_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TrainerScheduleDatesPage extends StatefulWidget {
  const TrainerScheduleDatesPage({
    super.key,
    required this.backendService,
  });

  final BackendTrainerService backendService;

  @override
  State<TrainerScheduleDatesPage> createState() =>
      _TrainerScheduleDatesPageState();
}

class _TrainerScheduleDatesPageState extends State<TrainerScheduleDatesPage> {
  TrainerScheduleMonth? _schedule;
  String _month = '';
  String? _selectedDate;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    // Initial month ditentukan backend (Asia/Jakarta), bukan timezone device.
    _loadMonth();
  }

  Future<void> _loadMonth([String? month]) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final schedule =
          await widget.backendService.getTrainerScheduleMonth(month);
      if (!mounted) return;
      final retained = schedule.dates.any((date) => date.date == _selectedDate)
          ? _selectedDate
          : _initialSelection(schedule);
      setState(() {
        _schedule = schedule;
        _month = schedule.month;
        _selectedDate = retained;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (month != null) _month = month;
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  String? _initialSelection(TrainerScheduleMonth schedule) {
    if (schedule.dates.isEmpty) return null;
    final serverDate = schedule.editableFrom;
    return schedule.dates.any((date) => date.date == serverDate)
        ? serverDate
        : schedule.dates.first.date;
  }

  TrainerScheduleDate? get _selected {
    final schedule = _schedule;
    if (schedule == null || _selectedDate == null) return null;
    for (final date in schedule.dates) {
      if (date.date == _selectedDate) return date;
    }
    return null;
  }

  bool _canOpenMonth(String month) {
    final schedule = _schedule;
    if (schedule == null) return false;
    final first = '${month.substring(0, 7)}-01';
    final parsed = DateTime.parse('$month-01');
    final last = _dateIso(DateTime(parsed.year, parsed.month + 1, 0));
    return first.compareTo(schedule.editableUntil) <= 0 &&
        last.compareTo(schedule.editableFrom) >= 0;
  }

  Future<void> _moveMonth(int delta) async {
    final current = DateTime.parse('$_month-01');
    final target = _monthIso(DateTime(current.year, current.month + delta));
    if (_canOpenMonth(target)) await _loadMonth(target);
  }

  bool _isEditable(TrainerScheduleDate date) {
    final schedule = _schedule!;
    return date.date.compareTo(schedule.editableFrom) >= 0 &&
        date.date.compareTo(schedule.editableUntil) <= 0;
  }

  Future<void> _editShifts() async {
    final selected = _selected;
    if (selected == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) => TrainerScheduleDateOverrideSheet(
        date: selected,
        onSave: (shifts) => _saveDate(
          () => widget.backendService.updateTrainerScheduleDate(
            date: selected.date,
            mode: 'override',
            lockVersion: selected.lockVersion,
            shifts: shifts,
          ),
        ),
      ),
    );
  }

  Future<void> _closeDate() async {
    final selected = _selected;
    if (selected == null) return;
    final confirmed = await _confirm(
      title: 'Tutup tanggal?',
      message:
          '${_fullDate(selected.date)} akan ditutup khusus pada tanggal ini.',
      action: 'Tutup Tanggal',
    );
    if (confirmed != true || !mounted) return;
    await _saveDate(() => widget.backendService.updateTrainerScheduleDate(
          date: selected.date,
          mode: 'closed',
          lockVersion: selected.lockVersion,
        ));
  }

  Future<void> _resetDate() async {
    final selected = _selected;
    if (selected == null) return;
    final confirmed = await _confirm(
      title: 'Reset ke template?',
      message:
          'Pengaturan manual ${_fullDate(selected.date)} akan dihapus dan kembali mengikuti template mingguan.',
      action: 'Reset',
    );
    if (confirmed != true || !mounted) return;
    await _saveDate(() => widget.backendService.resetTrainerScheduleDate(
          date: selected.date,
          lockVersion: selected.lockVersion,
        ));
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String action,
  }) =>
      showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      );

  Future<bool> _saveDate(
    Future<TrainerScheduleDate> Function() request,
  ) async {
    final selectedIso = _selectedDate;
    setState(() => _isSaving = true);
    try {
      final normalized = await request();
      if (!mounted) return false;
      _changed = true;
      if (normalized.date != selectedIso) {
        await _loadMonth(_month);
        return true;
      }
      setState(() {
        _schedule = _schedule!.replaceDate(normalized);
        _selectedDate = normalized.date;
      });
      _showMessage('Jadwal diperbarui', _fullDate(normalized.date));
      return true;
    } catch (error) {
      if (!mounted) return false;
      _showMessage('Gagal memperbarui', error.toString());
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.surface,
      colorText: AppColors.textPrimary,
    );
  }

  void _leave() => Get.back(result: _changed);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_isSaving) _leave();
      },
      child: DecoratedScreen(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? _buildError()
                      : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Kembali',
              onPressed: _isSaving ? null : _leave,
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Jadwal per Tanggal',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      );

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.event_busy_rounded,
                  size: 48, color: AppColors.textSecondary),
              const SizedBox(height: 14),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              EggButton.secondary(
                label: 'Coba Lagi',
                onPressed: () => _loadMonth(_month.isEmpty ? null : _month),
              ),
            ],
          ),
        ),
      );

  Widget _buildContent() {
    final schedule = _schedule!;
    final selected = _selected;
    final current = DateTime.parse('${schedule.month}-01');
    final previous = _monthIso(DateTime(current.year, current.month - 1));
    final next = _monthIso(DateTime(current.year, current.month + 1));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Row(
          children: [
            IconButton.outlined(
              tooltip: 'Bulan sebelumnya',
              onPressed: _canOpenMonth(previous) && !_isSaving
                  ? () => _moveMonth(-1)
                  : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    _monthLabel(schedule.month),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  Text(
                    'Zona waktu: ${schedule.timezone}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            IconButton.outlined(
              tooltip: 'Bulan berikutnya',
              onPressed: _canOpenMonth(next) && !_isSaving
                  ? () => _moveMonth(1)
                  : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: schedule.dates.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final date = schedule.dates[index];
              final selected = date.date == _selectedDate;
              return Semantics(
                selected: selected,
                button: true,
                label: '${_fullDate(date.date)}, ${_statusText(date)}',
                child: ChoiceChip(
                  selected: selected,
                  onSelected: _isSaving
                      ? null
                      : (_) => setState(() => _selectedDate = date.date),
                  selectedColor: AppColors.accent,
                  backgroundColor: AppColors.surfaceElevated,
                  labelStyle: TextStyle(
                    color: selected
                        ? AppColors.background
                        : date.isOpen
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                  label: SizedBox(
                    width: 42,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_shortDay(date.dayName)),
                        Text(date.date.substring(8, 10)),
                        Icon(
                          date.isOpen
                              ? Icons.circle
                              : Icons.remove_circle_outline_rounded,
                          size: 9,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        if (selected == null)
          const Center(child: Text('Tidak ada tanggal pada bulan ini.'))
        else
          _buildDateCard(selected),
      ],
    );
  }

  Widget _buildDateCard(TrainerScheduleDate date) {
    final editable = _isEditable(date);
    return EggCard(
      highlight: date.isManual,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _fullDate(date.date),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Badge(
                label: date.isManual ? 'Manual' : 'Dari Template',
                color: date.isManual ? AppColors.info : AppColors.accent,
                icon: date.isManual
                    ? Icons.edit_calendar_rounded
                    : Icons.auto_awesome_rounded,
              ),
              _Badge(
                label: date.isOpen ? 'Buka' : 'Tutup',
                color: date.isOpen ? AppColors.success : AppColors.error,
                icon: date.isOpen
                    ? Icons.check_circle_outline_rounded
                    : Icons.block_rounded,
              ),
            ],
          ),
          const SizedBox(height: 22),
          _ShiftSection(
            title: 'Shift Efektif',
            emptyLabel: date.isOpen
                ? 'Tidak ada shift efektif.'
                : 'Tanggal ditutup secara eksplisit.',
            shifts: date.shifts,
            accent: date.isOpen ? AppColors.success : AppColors.error,
          ),
          const SizedBox(height: 22),
          EggButton.primary(
            label: 'Ubah Shift',
            icon: Icons.edit_calendar_rounded,
            onPressed: editable && !_isSaving ? _editShifts : null,
          ),
          const SizedBox(height: 10),
          if (date.isOpen)
            EggButton.secondary(
              label: 'Tutup Tanggal',
              icon: Icons.block_rounded,
              onPressed:
                  editable && !_isSaving && date.canClose ? _closeDate : null,
            ),
          if (date.isOpen && !date.canClose) ...[
            const SizedBox(height: 6),
            const Text(
              'Tanggal tidak dapat ditutup karena memiliki shift dengan booking, reservation, atau hold aktif.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
          if (date.isManual) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed:
                  editable && !_isSaving && date.canReset ? _resetDate : null,
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Reset ke Template'),
            ),
            if (!date.canReset)
              const Text(
                'Template saat ini tidak memuat seluruh shift yang sudah terpakai.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
          ],
          if (_isSaving) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const SizedBox(height: 6),
            const Text('Menyimpan perubahan...'),
          ],
        ],
      ),
    );
  }
}

class TrainerScheduleDateOverrideSheet extends StatefulWidget {
  const TrainerScheduleDateOverrideSheet({
    super.key,
    required this.date,
    required this.onSave,
  });

  final TrainerScheduleDate date;
  final Future<bool> Function(List<TrainerScheduleDateShift> shifts) onSave;

  @override
  State<TrainerScheduleDateOverrideSheet> createState() =>
      _ShiftOverrideSheetState();
}

class _ShiftOverrideSheetState extends State<TrainerScheduleDateOverrideSheet> {
  late final List<_EditableShift> _shifts;
  String? _validation;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _shifts = widget.date.shifts
        .map((shift) => _EditableShift(
              shift.startTime,
              shift.endTime,
              isLocked: shift.isLocked,
              blockingCount: shift.blockingCount,
            ))
        .toList();
  }

  Future<void> _add() async {
    final now = TimeOfDay.now();
    final start = await showEggScheduleTimePicker(
      context: context,
      title: 'Pilih Waktu Mulai',
      initialValue: formatScheduleTime(now.hour * 60 + now.minute),
      maxMinutes: 23 * 60,
    );
    if (start == null || !mounted) return;
    final startMinutes = parseScheduleTime(start)!;
    final initialEnd = (startMinutes + 60).clamp(0, 1430);
    final end = await showEggScheduleTimePicker(
      context: context,
      title: 'Pilih Waktu Selesai',
      initialValue: formatScheduleTime(initialEnd),
      minMinutes: startMinutes + 30,
    );
    if (end == null || !mounted) return;
    final candidate = _EditableShift(start, end);
    final error = _validateCandidate(candidate);
    if (error != null) {
      setState(() => _validation = error);
      return;
    }
    setState(() {
      _shifts.add(candidate);
      _shifts.sort((a, b) => a.startTime.compareTo(b.startTime));
      _validation = null;
    });
  }

  Future<void> _edit(_EditableShift shift, bool start) async {
    final currentValue = start ? shift.startTime : shift.endTime;
    final otherMinutes = parseScheduleTime(
      start ? shift.endTime : shift.startTime,
    )!;
    final safeMax =
        start && otherMinutes >= 30 ? otherMinutes - 30 : 23 * 60 + 30;
    final safeMin = !start && otherMinutes <= 23 * 60 ? otherMinutes + 30 : 0;
    final picked = await showEggScheduleTimePicker(
      context: context,
      title: start ? 'Pilih Waktu Mulai' : 'Pilih Waktu Selesai',
      initialValue: currentValue,
      minMinutes: safeMin,
      maxMinutes: safeMax,
    );
    if (picked == null || !mounted) return;
    final candidate = _EditableShift(
      start ? picked : shift.startTime,
      start ? shift.endTime : picked,
    );
    final error = _validateCandidate(candidate, excluding: shift);
    if (error != null) {
      setState(() => _validation = error);
      return;
    }
    setState(() {
      shift.startTime = candidate.startTime;
      shift.endTime = candidate.endTime;
      _shifts.sort((a, b) => a.startTime.compareTo(b.startTime));
      _validation = null;
    });
  }

  String? _validateCandidate(_EditableShift candidate,
      {_EditableShift? excluding}) {
    final start = _minutes(candidate.startTime);
    final end = _minutes(candidate.endTime);
    if (!isHalfHourScheduleTime(candidate.startTime) ||
        !isHalfHourScheduleTime(candidate.endTime)) {
      return 'Shift ${candidate.startTime}-${candidate.endTime} harus memakai interval 30 menit.';
    }
    if (end <= start) {
      return 'Jam selesai harus setelah jam mulai.';
    }
    for (final existing in _shifts) {
      if (identical(existing, excluding)) continue;
      if (start < _minutes(existing.endTime) &&
          end > _minutes(existing.startTime)) {
        return 'Shift ${candidate.startTime}-${candidate.endTime} overlap dengan ${existing.startTime}-${existing.endTime}.';
      }
    }
    return null;
  }

  String? _validateAll() {
    if (_shifts.isEmpty) {
      return 'Override harus memiliki minimal satu shift. Gunakan Tutup Tanggal untuk menutup jadwal.';
    }
    final sorted = [..._shifts]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    for (var index = 0; index < sorted.length; index++) {
      final shift = sorted[index];
      if (!isHalfHourScheduleTime(shift.startTime) ||
          !isHalfHourScheduleTime(shift.endTime)) {
        return 'Shift ${shift.startTime}-${shift.endTime} harus memakai interval 30 menit.';
      }
      if (_minutes(shift.endTime) - _minutes(shift.startTime) < 30) {
        return 'Jam selesai harus minimal 30 menit setelah jam mulai.';
      }
      if (index > 0 &&
          _minutes(shift.startTime) < _minutes(sorted[index - 1].endTime)) {
        return 'Shift ${shift.startTime}-${shift.endTime} overlap dengan ${sorted[index - 1].startTime}-${sorted[index - 1].endTime}.';
      }
    }
    return null;
  }

  Future<void> _save() async {
    final validation = _validateAll();
    if (validation != null) {
      setState(() => _validation = validation);
      return;
    }
    setState(() {
      _isSaving = true;
      _validation = null;
    });
    final shifts = _shifts
        .map((shift) => TrainerScheduleDateShift(
              startTime: shift.startTime,
              endTime: shift.endTime,
            ))
        .toList(growable: false);
    final saved = await widget.onSave(shifts);
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _isSaving = false;
      _validation = 'Gagal menyimpan. Perubahan Anda tetap tersedia.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ubah Shift',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                _fullDate(widget.date.date),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              const Text(
                'Setiap shift adalah satu slot booking; tambahkan shift '
                'terpisah untuk beberapa sesi.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),
              if (_shifts.isEmpty)
                const Text('Belum ada shift. Tambahkan shift untuk override.'),
              for (final shift in _shifts) ...[
                if (shift.isLocked)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Shift ${shift.startTime}-${shift.endTime} terkunci karena memiliki ${shift.blockingCount} booking/reservation/hold aktif.',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: _TimeTile(
                        label: 'Mulai',
                        value: shift.startTime,
                        onTap: shift.isLocked ? null : () => _edit(shift, true),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward_rounded, size: 18),
                    ),
                    Expanded(
                      child: _TimeTile(
                        label: 'Selesai',
                        value: shift.endTime,
                        onTap:
                            shift.isLocked ? null : () => _edit(shift, false),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Hapus shift',
                      color: AppColors.error,
                      onPressed: shift.isLocked
                          ? null
                          : () => setState(() {
                                _shifts.remove(shift);
                                _validation = null;
                              }),
                      icon: Icon(shift.isLocked
                          ? Icons.lock_outline_rounded
                          : Icons.delete_outline_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              TextButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Tambah shift'),
              ),
              if (_validation != null) ...[
                const SizedBox(height: 8),
                Text(
                  _validation!,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              EggButton.primary(
                label: _isSaving ? 'Menyimpan...' : 'Simpan Override',
                onPressed: _isSaving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShiftSection extends StatelessWidget {
  const _ShiftSection({
    required this.title,
    required this.emptyLabel,
    required this.shifts,
    required this.accent,
  });

  final String title;
  final String emptyLabel;
  final List<TrainerScheduleDateShift> shifts;
  final Color accent;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (shifts.isEmpty)
            Text(emptyLabel,
                style: const TextStyle(color: AppColors.textSecondary))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: shifts
                  .map((shift) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          border:
                              Border.all(color: accent.withValues(alpha: 0.45)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${shift.startTime} - ${shift.endTime}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ))
                  .toList(),
            ),
        ],
      );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, required this.icon});

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          border: Border.all(color: color.withValues(alpha: 0.48)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );
}

class _EditableShift {
  _EditableShift(
    this.startTime,
    this.endTime, {
    this.isLocked = false,
    this.blockingCount = 0,
  });

  String startTime;
  String endTime;
  final bool isLocked;
  final int blockingCount;
}

String _statusText(TrainerScheduleDate date) =>
    '${date.isManual ? 'manual' : 'dari template'}, ${date.isOpen ? 'buka' : 'tutup'}';

String _shortDay(String value) =>
    value.length <= 3 ? value : value.substring(0, 3);

String _monthLabel(String value) {
  final date = DateTime.parse('$value-01');
  return '${_months[date.month - 1]} ${date.year}';
}

String _fullDate(String value) {
  final date = DateTime.parse(value);
  return '${_days[date.weekday - 1]}, ${date.day} ${_months[date.month - 1]} ${date.year}';
}

String _monthIso(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}';

String _dateIso(DateTime value) =>
    '${_monthIso(value)}-${value.day.toString().padLeft(2, '0')}';

int _minutes(String value) => parseScheduleTime(value)!;

const _months = <String>[
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

const _days = <String>[
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];
