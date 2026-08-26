const scheduleMinuteSteps = <int>[0, 30];

int? parseScheduleTime(String value) {
  final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value);
  if (match == null) return null;
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (hour > 23 || minute > 59) return null;
  return hour * 60 + minute;
}

String formatScheduleTime(int minutes) {
  final hour = minutes ~/ 60;
  final minute = minutes % 60;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

bool isHalfHourScheduleTime(String value) {
  final minutes = parseScheduleTime(value);
  return minutes != null && minutes % 30 == 0;
}

List<int> scheduleTimeOptions({
  int minMinutes = 0,
  int maxMinutes = 23 * 60 + 30,
}) {
  final first = ((minMinutes.clamp(0, 1439) + 29) ~/ 30) * 30;
  final last = (maxMinutes.clamp(0, 1439) ~/ 30) * 30;
  if (first > last) return const [];
  return [for (var value = first; value <= last; value += 30) value];
}

int nearestScheduleTime(
  int minutes, {
  int minMinutes = 0,
  int maxMinutes = 23 * 60 + 30,
}) {
  final options = scheduleTimeOptions(
    minMinutes: minMinutes,
    maxMinutes: maxMinutes,
  );
  if (options.isEmpty) {
    throw ArgumentError('The schedule time range has no valid values.');
  }
  return options.reduce(
    (best, value) =>
        (value - minutes).abs() < (best - minutes).abs() ? value : best,
  );
}

List<int> scheduleEndTimeOptions(int startMinutes) =>
    scheduleTimeOptions(minMinutes: startMinutes + 30);
