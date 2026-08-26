import 'package:egg_gym/core/formatters/app_date_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats API date using full Indonesian month', () {
    expect(AppDateFormatter.date('2026-07-23'), '23 Juli 2026');
  });

  test('formats compact chip date without changing source value', () {
    const source = '2026-07-27';
    expect(
      AppDateFormatter.date(
        source,
        abbreviatedMonth: true,
        includeWeekday: true,
        includeYear: false,
      ),
      'Sen 27 Jul',
    );
    expect(source, '2026-07-27');
  });

  test('formats schedule and removes time seconds', () {
    expect(
      AppDateFormatter.schedule(
        dateValue: '2026-08-20',
        startTime: '16:00:00',
        endTime: '17:00:00',
      ),
      '20 Agustus 2026 | 16:00–17:00',
    );
  });

  test('does not expose malformed raw dates', () {
    expect(AppDateFormatter.date('not-a-date'), '-');
  });
}
