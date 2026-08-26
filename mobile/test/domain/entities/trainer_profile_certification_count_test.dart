import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TrainerProfile trainer(List<String> certifications) => TrainerProfile(
        name: 'Coach',
        specialty: 'Strength',
        bio: '-',
        rating: 0,
        reviewsCount: 0,
        certifications: certifications,
      );

  test('CERTS count uses real certification list length', () {
    expect(trainer(const []).certificationCount, 0);
    expect(trainer(const ['NASM CPT']).certificationCount, 1);
    expect(
      trainer(const ['NASM CPT', 'Sports Nutrition Coach']).certificationCount,
      2,
    );
  });
}
