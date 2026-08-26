class TrainerAvailability {
  const TrainerAvailability({
    required this.trainerProfileId,
    required this.timezone,
    required this.currentServerDate,
    required this.monthEndDate,
    required this.horizonDays,
    required this.slotPolicy,
    required this.slotIntervalMinutes,
    required this.bufferMinutes,
    required this.leadTimeMinutes,
    required this.weekdays,
  });

  factory TrainerAvailability.fromJson(Map<String, dynamic> json) {
    final rawWeekdays = json['weekdays'];
    return TrainerAvailability(
      trainerProfileId: _asInt(json['trainer_profile_id']),
      timezone: _asString(json['timezone']),
      currentServerDate: _asString(json['current_server_date']),
      monthEndDate: _asString(json['month_end_date']),
      horizonDays: _asInt(json['horizon_days']),
      slotPolicy: _asNullableString(json['slot_policy']),
      slotIntervalMinutes: _asNullableInt(json['slot_interval_minutes']),
      bufferMinutes: _asInt(json['buffer_minutes']),
      leadTimeMinutes: _asInt(json['lead_time_minutes']),
      weekdays: rawWeekdays is List
          ? rawWeekdays
              .whereType<Map<String, dynamic>>()
              .map(TrainerAvailabilityWeekday.fromJson)
              .toList(growable: false)
          : const <TrainerAvailabilityWeekday>[],
    );
  }

  final int trainerProfileId;
  final String timezone;
  final String currentServerDate;
  final String monthEndDate;
  final int horizonDays;
  final String? slotPolicy;
  final int? slotIntervalMinutes;
  final int bufferMinutes;
  final int leadTimeMinutes;
  final List<TrainerAvailabilityWeekday> weekdays;

  /// Compatibility projection untuk Booking Form: tetap memakai tanggal konkret.
  List<TrainerAvailabilityDate> get dates =>
      weekdays.expand((weekday) => weekday.occurrences).toList(growable: false)
        ..sort((a, b) => a.date.compareTo(b.date));
}

class TrainerAvailabilityWeekday {
  const TrainerAvailabilityWeekday({
    required this.dayOfWeek,
    required this.dayName,
    required this.scheduleEnabled,
    required this.occurrences,
  });

  factory TrainerAvailabilityWeekday.fromJson(Map<String, dynamic> json) {
    final rawOccurrences = json['occurrences'];
    final dayOfWeek = _asInt(json['day_of_week']);
    final dayName = _asString(json['day_name']);
    return TrainerAvailabilityWeekday(
      dayOfWeek: dayOfWeek,
      dayName: dayName,
      scheduleEnabled: json['schedule_enabled'] == true,
      occurrences: rawOccurrences is List
          ? rawOccurrences
              .whereType<Map<String, dynamic>>()
              .map(
                (occurrence) => TrainerAvailabilityDate.fromJson(
                  occurrence,
                  dayOfWeek: dayOfWeek,
                  dayName: dayName,
                ),
              )
              .toList(growable: false)
          : const <TrainerAvailabilityDate>[],
    );
  }

  final int dayOfWeek;
  final String dayName;
  final bool scheduleEnabled;
  final List<TrainerAvailabilityDate> occurrences;
}

class TrainerAvailabilityDate {
  const TrainerAvailabilityDate({
    required this.date,
    required this.dayOfWeek,
    required this.dayName,
    required this.effectiveShifts,
    required this.slots,
  });

  factory TrainerAvailabilityDate.fromJson(
    Map<String, dynamic> json, {
    int? dayOfWeek,
    String? dayName,
  }) {
    final rawSlots = json['slots'];
    final rawEffectiveShifts = json['effective_shifts'];
    return TrainerAvailabilityDate(
      date: _asString(json['date']),
      dayOfWeek: dayOfWeek ?? _asInt(json['day_of_week']),
      dayName: dayName ?? _asString(json['day_name']),
      effectiveShifts: rawEffectiveShifts is List
          ? rawEffectiveShifts
              .whereType<Map<String, dynamic>>()
              .map(TrainerAvailabilityEffectiveShift.fromJson)
              .toList(growable: false)
          : const <TrainerAvailabilityEffectiveShift>[],
      slots: rawSlots is List
          ? rawSlots
              .whereType<Map<String, dynamic>>()
              .map(TrainerAvailabilitySlot.fromJson)
              .toList(growable: false)
          : const <TrainerAvailabilitySlot>[],
    );
  }

  final String date;
  final int dayOfWeek;
  final String dayName;
  final List<TrainerAvailabilityEffectiveShift> effectiveShifts;
  final List<TrainerAvailabilitySlot> slots;
}

class TrainerAvailabilityEffectiveShift {
  const TrainerAvailabilityEffectiveShift({
    required this.startTime,
    required this.endTime,
    this.sessionDurationMinutes,
    required this.slotCount,
    required this.slotKeys,
  });

  factory TrainerAvailabilityEffectiveShift.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawKeys = json['slot_keys'];
    return TrainerAvailabilityEffectiveShift(
      startTime: _asString(json['start_time']),
      endTime: _asString(json['end_time']),
      sessionDurationMinutes: _asNullableInt(json['session_duration_minutes']),
      slotCount: _asInt(json['slot_count']),
      slotKeys: rawKeys is List
          ? rawKeys.map(_asString).where((key) => key.isNotEmpty).toList(
                growable: false,
              )
          : const <String>[],
    );
  }

  final String startTime;
  final String endTime;
  final int? sessionDurationMinutes;
  final int slotCount;
  final List<String> slotKeys;
}

class TrainerAvailabilitySlot {
  const TrainerAvailabilitySlot({
    required this.key,
    required this.startTime,
    required this.endTime,
    this.sessionDurationMinutes,
    required this.shiftStartTime,
    required this.shiftEndTime,
    required this.location,
    required this.isAvailable,
    this.unavailableReason,
  });

  factory TrainerAvailabilitySlot.fromJson(Map<String, dynamic> json) {
    return TrainerAvailabilitySlot(
      key: _asString(json['key']),
      startTime: _asString(json['start_time']),
      endTime: _asString(json['end_time']),
      sessionDurationMinutes: _asNullableInt(json['session_duration_minutes']),
      shiftStartTime: _asString(json['shift_start_time']),
      shiftEndTime: _asString(json['shift_end_time']),
      location: _asString(json['location']),
      isAvailable: json['is_available'] != false,
      unavailableReason: _asNullableString(json['unavailable_reason']),
    );
  }

  final String key;
  final String startTime;
  final String endTime;
  final int? sessionDurationMinutes;
  final String shiftStartTime;
  final String shiftEndTime;
  final String location;
  final bool isAvailable;
  final String? unavailableReason;
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _asNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

String _asString(dynamic value) => value?.toString().trim() ?? '';

String? _asNullableString(dynamic value) {
  final normalized = value?.toString().trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
