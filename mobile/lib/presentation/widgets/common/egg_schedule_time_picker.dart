import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/core/utils/schedule_time.dart';
import 'package:flutter/material.dart';

Future<String?> showEggScheduleTimePicker({
  required BuildContext context,
  required String title,
  required String initialValue,
  int minMinutes = 0,
  int maxMinutes = 23 * 60 + 30,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => EggScheduleTimePickerSheet(
      title: title,
      initialValue: initialValue,
      minMinutes: minMinutes,
      maxMinutes: maxMinutes,
    ),
  );
}

class EggScheduleTimePickerSheet extends StatefulWidget {
  const EggScheduleTimePickerSheet({
    super.key,
    required this.title,
    required this.initialValue,
    this.minMinutes = 0,
    this.maxMinutes = 23 * 60 + 30,
  });

  final String title;
  final String initialValue;
  final int minMinutes;
  final int maxMinutes;

  @override
  State<EggScheduleTimePickerSheet> createState() =>
      _EggScheduleTimePickerSheetState();
}

class _EggScheduleTimePickerSheetState
    extends State<EggScheduleTimePickerSheet> {
  late final List<int> _options;
  late int _selected;

  @override
  void initState() {
    super.initState();
    _options = scheduleTimeOptions(
      minMinutes: widget.minMinutes,
      maxMinutes: widget.maxMinutes,
    );
    if (_options.isEmpty) {
      throw ArgumentError('The schedule time picker has no valid values.');
    }
    _selected = nearestScheduleTime(
      parseScheduleTime(widget.initialValue) ?? widget.minMinutes,
      minMinutes: widget.minMinutes,
      maxMinutes: widget.maxMinutes,
    );
  }

  List<int> get _hours => _options.map((value) => value ~/ 60).toSet().toList();

  List<int> _minutesForHour(int hour) => _options
      .where((value) => value ~/ 60 == hour)
      .map((value) => value % 60)
      .toList();

  void _selectHour(int hour) {
    final minutes = _minutesForHour(hour);
    final selectedMinute =
        minutes.contains(_selected % 60) ? _selected % 60 : minutes.first;
    setState(() => _selected = hour * 60 + selectedMinute);
  }

  @override
  Widget build(BuildContext context) {
    final hour = _selected ~/ 60;
    final minutes = _minutesForHour(hour);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppColors.accentDeep)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Waktu menggunakan format 24 jam dan interval 30 menit.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _TimeDropdown(
                    label: 'JAM',
                    key: const ValueKey('schedule-hour'),
                    value: hour,
                    values: _hours,
                    onChanged: _selectHour,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 24, 14, 0),
                  child: Text(':', style: TextStyle(fontSize: 28)),
                ),
                Expanded(
                  child: _TimeDropdown(
                    label: 'MENIT',
                    key: const ValueKey('schedule-minute'),
                    value: _selected % 60,
                    values: minutes,
                    onChanged: (minute) =>
                        setState(() => _selected = hour * 60 + minute),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('cancel-schedule-time'),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('confirm-schedule-time'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.background,
                    ),
                    onPressed: () =>
                        Navigator.pop(context, formatScheduleTime(_selected)),
                    child: const Text('Pilih'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeDropdown extends StatelessWidget {
  const _TimeDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final int value;
  final List<int> values;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 7),
          DropdownButtonFormField<int>(
            value: value,
            dropdownColor: AppColors.surfaceElevated,
            decoration: const InputDecoration(
              filled: true,
              fillColor: AppColors.surfaceSoft,
              border: OutlineInputBorder(),
            ),
            items: values
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(
                      value.toString().padLeft(2, '0'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
          ),
        ],
      );
}
