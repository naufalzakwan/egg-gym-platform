class TrainerSchedule {
  TrainerSchedule({
    required this.timezone,
    required List<TrainerScheduleDay> days,
  }) : days = List<TrainerScheduleDay>.unmodifiable(days);

  final String timezone;
  final List<TrainerScheduleDay> days;

  factory TrainerSchedule.fromJson(Map<String, dynamic> json) {
    final timezone = json['timezone'];
    final rawDays = json['days'];
    if (timezone is! String || timezone.trim().isEmpty || rawDays is! List) {
      throw const FormatException('Data jadwal trainer tidak valid.');
    }

    final days = rawDays.map((day) {
      if (day is! Map) {
        throw const FormatException('Data hari jadwal tidak valid.');
      }
      return TrainerScheduleDay.fromJson(Map<String, dynamic>.from(day));
    }).toList(growable: false);

    if (days.length != 7 ||
        days.map((day) => day.dayOfWeek).toSet().length != 7) {
      throw const FormatException('Jadwal harus berisi tujuh hari berbeda.');
    }
    days.sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));

    return TrainerSchedule(timezone: timezone, days: days);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'timezone': timezone,
        'days': days.map((day) => day.toJson()).toList(growable: false),
      };
}

class TrainerScheduleDay {
  TrainerScheduleDay({
    required this.dayOfWeek,
    required this.dayName,
    required this.enabled,
    required List<TrainerScheduleShift> shifts,
  }) : shifts = List<TrainerScheduleShift>.unmodifiable(shifts);

  final int dayOfWeek;
  final String dayName;
  final bool enabled;
  final List<TrainerScheduleShift> shifts;

  factory TrainerScheduleDay.fromJson(Map<String, dynamic> json) {
    final dayOfWeek = json['day_of_week'];
    final dayName = json['day_name'];
    final enabled = json['enabled'];
    final rawShifts = json['shifts'];
    if (dayOfWeek is! int ||
        dayOfWeek < 1 ||
        dayOfWeek > 7 ||
        dayName is! String ||
        dayName.trim().isEmpty ||
        enabled is! bool ||
        rawShifts is! List) {
      throw const FormatException('Data hari jadwal tidak valid.');
    }

    return TrainerScheduleDay(
      dayOfWeek: dayOfWeek,
      dayName: dayName,
      enabled: enabled,
      shifts: rawShifts.map((shift) {
        if (shift is! Map) {
          throw const FormatException('Data shift jadwal tidak valid.');
        }
        return TrainerScheduleShift.fromJson(
          Map<String, dynamic>.from(shift),
        );
      }).toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'day_of_week': dayOfWeek,
        'enabled': enabled,
        'shifts': shifts.map((shift) => shift.toJson()).toList(growable: false),
      };
}

class TrainerScheduleShift {
  const TrainerScheduleShift({
    this.id,
    required this.startTime,
    required this.endTime,
  });

  final int? id;
  final String startTime;
  final String endTime;

  factory TrainerScheduleShift.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final startTime = json['start_time'];
    final endTime = json['end_time'];
    if ((id != null && id is! int) ||
        startTime is! String ||
        !_isTime(startTime) ||
        endTime is! String ||
        !_isTime(endTime)) {
      throw const FormatException('Data shift jadwal tidak valid.');
    }

    return TrainerScheduleShift(
      id: id as int?,
      startTime: startTime,
      endTime: endTime,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'start_time': startTime,
        'end_time': endTime,
      };

  static bool _isTime(String value) {
    final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value);
    if (match == null) return false;
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    return hour <= 23 && minute <= 59;
  }
}
