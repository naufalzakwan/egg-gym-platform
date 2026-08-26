abstract final class AppDateFormatter {
  static const _monthsLong = [
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

  static const _monthsShort = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  static const _weekdaysShort = [
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab',
    'Min',
  ];

  static String date(
    Object? value, {
    bool abbreviatedMonth = false,
    bool includeWeekday = false,
    bool includeYear = true,
    String fallback = '-',
  }) {
    final parsed = _parseCalendarDate(value);
    if (parsed == null) return fallback;
    final month =
        (abbreviatedMonth ? _monthsShort : _monthsLong)[parsed.month - 1];
    return [
      if (includeWeekday) _weekdaysShort[parsed.weekday - 1],
      '${parsed.day}',
      month,
      if (includeYear) '${parsed.year}',
    ].join(' ');
  }

  static String time(String? value, {String fallback = '-'}) {
    final normalized = value?.trim() ?? '';
    final match = RegExp(r'^(\d{2}):(\d{2})(?::\d{2})?').firstMatch(normalized);
    if (match == null) return fallback;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || hour > 23 || minute == null || minute > 59) {
      return fallback;
    }
    return '${match.group(1)}:${match.group(2)}';
  }

  static String schedule({
    required Object? dateValue,
    String? startTime,
    String? endTime,
    bool abbreviatedMonth = false,
    String fallback = '-',
  }) {
    final dateLabel = date(
      dateValue,
      abbreviatedMonth: abbreviatedMonth,
      fallback: fallback,
    );
    final startLabel = time(startTime, fallback: fallback);
    final endLabel = time(endTime, fallback: fallback);
    if (startTime == null && endTime == null) return dateLabel;
    return '$dateLabel | $startLabel–$endLabel';
  }

  static DateTime? _parseCalendarDate(Object? value) {
    if (value is DateTime) return value;
    final raw = value?.toString().trim() ?? '';
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(raw);
    if (match == null) return null;
    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final day = int.tryParse(match.group(3)!);
    if (year == null || month == null || day == null) return null;
    final parsed = DateTime(year, month, day);
    return parsed.year == year && parsed.month == month && parsed.day == day
        ? parsed
        : null;
  }
}
