import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/core/utils/schedule_time.dart';
import 'package:egg_gym/app/routes/app_routes.dart';
import 'package:egg_gym/data/services/backend_trainer_service.dart';
import 'package:egg_gym/domain/entities/trainer_schedule.dart';
import 'package:egg_gym/presentation/widgets/common/decorated_screen.dart';
import 'package:egg_gym/presentation/widgets/common/egg_button.dart';
import 'package:egg_gym/presentation/widgets/common/egg_card.dart';
import 'package:egg_gym/presentation/widgets/common/egg_schedule_time_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TrainerScheduleEditorPage extends StatefulWidget {
  const TrainerScheduleEditorPage({
    super.key,
    required this.backendService,
  });

  final BackendTrainerService backendService;

  @override
  State<TrainerScheduleEditorPage> createState() =>
      _TrainerScheduleEditorPageState();
}

class _TrainerScheduleEditorPageState extends State<TrainerScheduleEditorPage> {
  String? _timezone;
  List<_EditableDay> _days = const [];
  String? _errorMessage;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final schedule = await widget.backendService.getTrainerSchedule();
      if (!mounted) return;
      setState(() {
        _timezone = schedule.timezone;
        _days = schedule.days.map(_EditableDay.fromModel).toList();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _addShift(_EditableDay day) async {
    final now = TimeOfDay.now();
    final start = await showEggScheduleTimePicker(
      context: context,
      title: 'Pilih Waktu Mulai',
      initialValue: formatScheduleTime(now.hour * 60 + now.minute),
      maxMinutes: 23 * 60,
    );
    if (start == null || !mounted) return;
    final startMinutes = parseScheduleTime(start)!;
    final end = await showEggScheduleTimePicker(
      context: context,
      title: 'Pilih Waktu Selesai',
      initialValue: formatScheduleTime((startMinutes + 60).clamp(0, 1430)),
      minMinutes: startMinutes + 30,
    );
    if (end == null || !mounted) return;

    final validation = _validateCandidateShift(
      day,
      startTime: start,
      endTime: end,
    );
    if (validation != null) {
      _showMessage('Shift tidak valid', validation);
      return;
    }

    setState(() {
      day.shifts.add(
        _EditableShift(
          startTime: start,
          endTime: end,
        ),
      );
    });
  }

  Future<void> _editTime(
    _EditableDay day,
    _EditableShift shift, {
    required bool start,
  }) async {
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

    final candidateStart = start ? picked : shift.startTime;
    final candidateEnd = start ? shift.endTime : picked;
    final validation = _validateCandidateShift(
      day,
      startTime: candidateStart,
      endTime: candidateEnd,
      excludeShift: shift,
    );
    if (validation != null) {
      _showMessage('Shift tidak valid', validation);
      return;
    }

    setState(() {
      shift.startTime = candidateStart;
      shift.endTime = candidateEnd;
    });
  }

  String? _validateCandidateShift(
    _EditableDay day, {
    required String startTime,
    required String endTime,
    _EditableShift? excludeShift,
  }) {
    final candidateStart = _minutes(startTime);
    final candidateEnd = _minutes(endTime);

    if (!isHalfHourScheduleTime(startTime) ||
        !isHalfHourScheduleTime(endTime)) {
      return 'Shift $startTime–$endTime harus menggunakan interval kelipatan 30 menit.';
    }
    if (candidateEnd <= candidateStart) {
      return 'Jam selesai $endTime harus setelah jam mulai $startTime.';
    }

    for (final existing in day.shifts) {
      if (identical(existing, excludeShift)) continue;
      final existingStart = _minutes(existing.startTime);
      final existingEnd = _minutes(existing.endTime);
      final overlaps =
          candidateStart < existingEnd && candidateEnd > existingStart;
      if (overlaps) {
        return 'Shift $startTime–$endTime overlap dengan shift '
            '${existing.startTime}–${existing.endTime}.';
      }
    }

    return null;
  }

  String? _validate() {
    for (final day in _days) {
      if (!day.enabled) continue;
      if (day.shifts.isEmpty) {
        return '${_dayLabel(day.dayOfWeek)} aktif tetapi belum memiliki shift.';
      }

      final ranges = day.shifts.map((shift) {
        final start = _minutes(shift.startTime);
        final end = _minutes(shift.endTime);
        if (start % 30 != 0 || end % 30 != 0) {
          throw _ScheduleValidation(
            'Waktu ${_dayLabel(day.dayOfWeek)} harus dalam interval 30 menit.',
          );
        }
        if (end <= start) {
          throw _ScheduleValidation(
            'Waktu selesai ${_dayLabel(day.dayOfWeek)} harus setelah waktu mulai.',
          );
        }
        if (end - start < 30) {
          throw _ScheduleValidation(
            'Shift ${_dayLabel(day.dayOfWeek)} minimal 30 menit.',
          );
        }
        return (start: start, end: end);
      }).toList()
        ..sort((a, b) => a.start.compareTo(b.start));

      for (var index = 1; index < ranges.length; index++) {
        if (ranges[index].start < ranges[index - 1].end) {
          return 'Shift ${_dayLabel(day.dayOfWeek)} tidak boleh tumpang tindih.';
        }
      }
    }
    return null;
  }

  Future<void> _save() async {
    String? validation;
    try {
      validation = _validate();
    } on _ScheduleValidation catch (error) {
      validation = error.message;
    }
    if (validation != null) {
      _showMessage('Jadwal belum valid', validation);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final schedule = TrainerSchedule(
        timezone: _timezone!,
        days: _days.map((day) {
          final shifts = day.shifts
              .map(
                (shift) => TrainerScheduleShift(
                  id: shift.id,
                  startTime: shift.startTime,
                  endTime: shift.endTime,
                ),
              )
              .toList()
            ..sort((a, b) => a.startTime.compareTo(b.startTime));
          return TrainerScheduleDay(
            dayOfWeek: day.dayOfWeek,
            dayName: day.dayName,
            enabled: day.enabled,
            shifts: shifts,
          );
        }).toList(),
      );
      final normalized =
          await widget.backendService.updateTrainerSchedule(schedule);
      if (!mounted) return;
      Get.back(result: normalized);
      Get.snackbar(
        'Jadwal tersimpan',
        'Jadwal aktif trainer berhasil diperbarui.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage('Gagal menyimpan', error.toString());
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

  @override
  Widget build(BuildContext context) {
    return DecoratedScreen(
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildError()
                    : _buildEditor(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: _isSaving ? null : Get.back,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Template Mingguan',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.event_busy_rounded,
              size: 48,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 14),
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            EggButton.secondary(label: 'Coba Lagi', onPressed: _loadSchedule),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(
          'Zona waktu: $_timezone',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Aktifkan hari kerja dan susun shift dalam interval 30 menit. '
          'Setiap shift adalah satu slot booking; tambahkan shift terpisah '
          'untuk beberapa sesi.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 16),
        EggButton.secondary(
          label: 'Jadwal per Tanggal',
          icon: Icons.calendar_month_rounded,
          onPressed: _isSaving
              ? null
              : () => Get.toNamed(
                    AppRoutes.trainerScheduleDates,
                    arguments: widget.backendService,
                  ),
        ),
        const SizedBox(height: 16),
        for (final day in _days) ...[
          _buildDay(day),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 4),
        EggButton.primary(
          label: _isSaving ? 'Menyimpan...' : 'Simpan Template Mingguan',
          onPressed: _isSaving ? null : _save,
        ),
      ],
    );
  }

  Widget _buildDay(_EditableDay day) {
    return EggCard(
      padding: const EdgeInsets.all(16),
      highlight: day.enabled,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color:
                      day.enabled ? AppColors.accent : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _dayLabel(day.dayOfWeek),
                  style: TextStyle(
                    color: day.enabled
                        ? AppColors.background
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  day.dayName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Switch.adaptive(
                value: day.enabled,
                activeTrackColor: AppColors.accent,
                onChanged: (value) => _toggleDay(day, value),
              ),
            ],
          ),
          if (day.enabled) ...[
            const SizedBox(height: 12),
            if (day.shifts.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Belum ada shift untuk hari ini.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ),
            for (var index = 0; index < day.shifts.length; index++) ...[
              if (index > 0) const SizedBox(height: 8),
              _buildShift(day, day.shifts[index]),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _addShift(day),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Tambah shift'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _toggleDay(_EditableDay day, bool enabled) async {
    if (!enabled && day.shifts.isNotEmpty) {
      final clear = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Nonaktifkan hari?'),
          content: Text(
            'Semua ${day.shifts.length} shift pada ${day.dayName} akan dihapus.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Nonaktifkan'),
            ),
          ],
        ),
      );
      if (clear != true || !mounted) return;
    }

    setState(() {
      day.enabled = enabled;
      if (!enabled) day.shifts.clear();
    });
  }

  Widget _buildShift(_EditableDay day, _EditableShift shift) {
    return Row(
      children: [
        Expanded(
          child: _TimeButton(
            label: 'Mulai',
            value: shift.startTime,
            onTap: () => _editTime(day, shift, start: true),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.arrow_forward_rounded, size: 16),
        ),
        Expanded(
          child: _TimeButton(
            label: 'Selesai',
            value: shift.endTime,
            onTap: () => _editTime(day, shift, start: false),
          ),
        ),
        IconButton(
          tooltip: 'Hapus shift',
          visualDensity: VisualDensity.compact,
          onPressed: () => setState(() => day.shifts.remove(shift)),
          icon: const Icon(Icons.delete_outline_rounded),
          color: AppColors.error,
        ),
      ],
    );
  }

  static int _minutes(String value) => parseScheduleTime(value)!;

  static String _dayLabel(int dayOfWeek) => const <String>[
        'SEN',
        'SEL',
        'RAB',
        'KAM',
        'JUM',
        'SAB',
        'MIN'
      ][dayOfWeek - 1];
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
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
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _EditableDay {
  _EditableDay({
    required this.dayOfWeek,
    required this.dayName,
    required this.enabled,
    required this.shifts,
  });

  factory _EditableDay.fromModel(TrainerScheduleDay day) => _EditableDay(
        dayOfWeek: day.dayOfWeek,
        dayName: day.dayName,
        enabled: day.enabled,
        shifts: day.shifts
            .map(
              (shift) => _EditableShift(
                id: shift.id,
                startTime: shift.startTime,
                endTime: shift.endTime,
              ),
            )
            .toList(),
      );

  final int dayOfWeek;
  final String dayName;
  bool enabled;
  final List<_EditableShift> shifts;
}

class _EditableShift {
  _EditableShift({
    this.id,
    required this.startTime,
    required this.endTime,
  });

  final int? id;
  String startTime;
  String endTime;
}

class _ScheduleValidation implements Exception {
  const _ScheduleValidation(this.message);

  final String message;
}
