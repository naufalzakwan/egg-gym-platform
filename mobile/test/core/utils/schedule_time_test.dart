import 'package:egg_gym/core/utils/schedule_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats noon half-hour values as HH:mm', () {
    expect(formatScheduleTime(12 * 60), '12:00');
    expect(formatScheduleTime(12 * 60 + 30), '12:30');
  });

  test('schedule options contain only minute 00 and 30', () {
    final options = scheduleTimeOptions();

    expect(options, contains(12 * 60));
    expect(options, contains(12 * 60 + 30));
    expect(options, isNot(contains(12 * 60 + 45)));
    expect(options.every((value) => value % 30 == 0), isTrue);
  });

  test('end options start at least 30 minutes after start', () {
    final options = scheduleEndTimeOptions(12 * 60);

    expect(options.first, 12 * 60 + 30);
    expect(options, isNot(contains(12 * 60)));
  });

  test('legacy off-grid initial value resolves to nearest convenience value',
      () {
    expect(nearestScheduleTime(12 * 60 + 45), 12 * 60 + 30);
    expect(isHalfHourScheduleTime('12:45'), isFalse);
  });
}
