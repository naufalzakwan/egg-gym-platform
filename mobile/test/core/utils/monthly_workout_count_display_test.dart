import 'package:egg_gym/core/utils/monthly_workout_count_display.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('valid zero displays as zero', () {
    expect(monthlyWorkoutCountDisplay(0, failed: false), '0');
  });

  test('positive count displays its value', () {
    expect(monthlyWorkoutCountDisplay(4, failed: false), '4');
  });

  test('missing count displays a dash', () {
    expect(monthlyWorkoutCountDisplay(null, failed: false), '-');
  });

  test('request failure displays a dash even when stale data exists', () {
    expect(monthlyWorkoutCountDisplay(4, failed: true), '-');
  });
}
