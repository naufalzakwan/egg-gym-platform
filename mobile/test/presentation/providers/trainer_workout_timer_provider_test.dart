import 'package:egg_gym/presentation/providers/workout_timer_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('trainer intensity follows selected countdown duration', () {
    final timer = TrainerWorkoutTimerProvider();
    addTearDown(timer.dispose);

    expect(timer.intensityLabel, 'HIGH INTENSITY');

    timer.selectPreset(30);
    expect(timer.intensityLabel, 'MEDIUM INTENSITY');

    timer.selectPreset(20);
    expect(timer.intensityLabel, 'LIGHT INTENSITY');

    timer.selectPreset(10);
    expect(timer.intensityLabel, 'QUICK SESSION');

    timer.selectPreset(60);
    expect(timer.intensityLabel, 'HIGH INTENSITY');
  });

  test('custom duration uses total minutes and resets to selected value', () {
    final timer = TrainerWorkoutTimerProvider();
    addTearDown(timer.dispose);

    timer.selectPreset(60);
    expect(timer.displayValue, '60:00');
    expect(timer.progressValue, 0);

    timer.selectPreset(120);
    expect(timer.displayValue, '120:00');
    timer.reset();
    expect(timer.displayValue, '120:00');
  });
}
