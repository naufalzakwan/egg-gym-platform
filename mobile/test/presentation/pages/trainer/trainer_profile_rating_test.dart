import 'package:egg_gym/presentation/pages/trainer/trainer_shell_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('active trainer profile never uses a demo rating fallback', () {
    expect(activeTrainerProfileRatingDisplay(null), '-');
    expect(activeTrainerProfileRatingDisplay(0), '-');
    expect(activeTrainerProfileRatingDisplay(4.72), '4.7');
  });
}
