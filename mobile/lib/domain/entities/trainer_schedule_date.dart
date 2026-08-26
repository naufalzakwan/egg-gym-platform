class TrainerScheduleMonth {
  TrainerScheduleMonth({
    required this.timezone,
    required this.month,
    required this.editableFrom,
    required this.editableUntil,
    required List<TrainerScheduleDate> dates,
  }) : dates = List<TrainerScheduleDate>.unmodifiable(dates);

  final String timezone;
  final String month;
  final String editableFrom;
  final String editableUntil;
  final List<TrainerScheduleDate> dates;

  factory TrainerScheduleMonth.fromJson(Map<String, dynamic> json) {
    final timezone = json['timezone'];
    final month = json['month'];
    final editableFrom = json['editable_from'];
    final editableUntil = json['editable_until'];
    final rawDates = json['dates'];
    if (timezone is! String ||
        timezone.trim().isEmpty ||
        month is! String ||
        !RegExp(r'^\d{4}-\d{2}$').hasMatch(month) ||
        editableFrom is! String ||
        !_isDate(editableFrom) ||
        editableUntil is! String ||
        !_isDate(editableUntil) ||
        rawDates is! List) {
      throw const FormatException('Data jadwal per tanggal tidak valid.');
    }

    final dates = rawDates.map((item) {
      if (item is! Map) {
        throw const FormatException('Data tanggal jadwal tidak valid.');
      }
      return TrainerScheduleDate.fromJson(Map<String, dynamic>.from(item));
    }).toList(growable: false)
      ..sort((a, b) => a.date.compareTo(b.date));

    return TrainerScheduleMonth(
      timezone: timezone,
      month: month,
      editableFrom: editableFrom,
      editableUntil: editableUntil,
      dates: dates,
    );
  }

  TrainerScheduleMonth replaceDate(TrainerScheduleDate value) {
    final updated = dates
        .map((date) => date.date == value.date ? value : date)
        .toList(growable: false);
    if (!updated.any((date) => date.date == value.date)) {
      throw const FormatException('Tanggal hasil perubahan tidak ditemukan.');
    }
    return TrainerScheduleMonth(
      timezone: timezone,
      month: month,
      editableFrom: editableFrom,
      editableUntil: editableUntil,
      dates: updated,
    );
  }
}

class TrainerScheduleDate {
  TrainerScheduleDate({
    required this.date,
    required this.dayOfWeek,
    required this.dayName,
    required this.state,
    required this.source,
    required this.lockVersion,
    this.hasBlockers = false,
    this.canClose = true,
    this.canReset = true,
    required List<TrainerScheduleDateShift> shifts,
    required List<TrainerScheduleDateShift> templateShifts,
  })  : shifts = List<TrainerScheduleDateShift>.unmodifiable(shifts),
        templateShifts =
            List<TrainerScheduleDateShift>.unmodifiable(templateShifts);

  final String date;
  final int dayOfWeek;
  final String dayName;
  final TrainerScheduleDateState state;
  final TrainerScheduleDateSource source;
  final int lockVersion;
  final bool hasBlockers;
  final bool canClose;
  final bool canReset;
  final List<TrainerScheduleDateShift> shifts;
  final List<TrainerScheduleDateShift> templateShifts;

  bool get isOpen => state == TrainerScheduleDateState.open;
  bool get isManual => source == TrainerScheduleDateSource.manual;

  factory TrainerScheduleDate.fromJson(Map<String, dynamic> json) {
    final date = json['date'];
    final dayOfWeek = json['day_of_week'];
    final dayName = json['day_name'];
    final state = json['state'];
    final source = json['source'];
    final lockVersion = json['lock_version'];
    final rawShifts = json['shifts'];
    final rawTemplateShifts = json['template_shifts'];
    if (date is! String ||
        !_isDate(date) ||
        dayOfWeek is! int ||
        dayOfWeek < 1 ||
        dayOfWeek > 7 ||
        dayName is! String ||
        dayName.trim().isEmpty ||
        state is! String ||
        !const {'open', 'closed'}.contains(state) ||
        source is! String ||
        !const {'generated', 'manual'}.contains(source) ||
        lockVersion is! int ||
        rawShifts is! List ||
        rawTemplateShifts is! List) {
      throw const FormatException('Data tanggal jadwal tidak valid.');
    }

    return TrainerScheduleDate(
      date: date,
      dayOfWeek: dayOfWeek,
      dayName: dayName,
      state: state == 'open'
          ? TrainerScheduleDateState.open
          : TrainerScheduleDateState.closed,
      source: source == 'manual'
          ? TrainerScheduleDateSource.manual
          : TrainerScheduleDateSource.generated,
      lockVersion: lockVersion,
      hasBlockers: json['has_blockers'] == true,
      canClose: json['can_close'] != false,
      canReset: json['can_reset'] != false,
      shifts: _parseShifts(rawShifts),
      templateShifts: _parseShifts(rawTemplateShifts),
    );
  }

  static List<TrainerScheduleDateShift> _parseShifts(List<dynamic> raw) =>
      raw.map((item) {
        if (item is! Map) {
          throw const FormatException('Data shift tanggal tidak valid.');
        }
        return TrainerScheduleDateShift.fromJson(
          Map<String, dynamic>.from(item),
        );
      }).toList(growable: false);
}

enum TrainerScheduleDateState { open, closed }

enum TrainerScheduleDateSource { generated, manual }

class TrainerScheduleDateShift {
  const TrainerScheduleDateShift({
    required this.startTime,
    required this.endTime,
    this.isLocked = false,
    this.blockingCount = 0,
    this.blockingTypes = const [],
  });

  final String startTime;
  final String endTime;
  final bool isLocked;
  final int blockingCount;
  final List<String> blockingTypes;

  factory TrainerScheduleDateShift.fromJson(Map<String, dynamic> json) {
    final startTime = json['start_time'];
    final endTime = json['end_time'];
    if (startTime is! String ||
        !_isTime(startTime) ||
        endTime is! String ||
        !_isTime(endTime)) {
      throw const FormatException('Data shift tanggal tidak valid.');
    }
    return TrainerScheduleDateShift(
      startTime: startTime,
      endTime: endTime,
      isLocked: json['is_locked'] == true,
      blockingCount:
          json['blocking_count'] is int ? json['blocking_count'] as int : 0,
      blockingTypes: (json['blocking_types'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'start_time': startTime,
        'end_time': endTime,
      };
}

bool _isDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
  final parsed = DateTime.tryParse(value);
  return parsed != null &&
      parsed.year.toString().padLeft(4, '0') == value.substring(0, 4) &&
      parsed.month.toString().padLeft(2, '0') == value.substring(5, 7) &&
      parsed.day.toString().padLeft(2, '0') == value.substring(8, 10);
}

bool _isTime(String value) {
  final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value);
  if (match == null) return false;
  return int.parse(match.group(1)!) <= 23 && int.parse(match.group(2)!) <= 59;
}
