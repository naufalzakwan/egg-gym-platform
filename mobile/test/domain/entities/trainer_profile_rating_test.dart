import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TrainerProfile profile({required double rating, required int reviewsCount}) {
    return TrainerProfile(
      name: 'Coach Test',
      specialty: 'Strength',
      bio: '-',
      rating: rating,
      reviewsCount: reviewsCount,
    );
  }

  test('zero count clears a positive cached rating', () {
    final trainer = profile(rating: 4.9, reviewsCount: 0);

    expect(trainer.rating, 0);
    expect(trainer.reviewsCount, 0);
    expect(trainer.reviewsLabel, '0 reviews');
  });

  test('reviews label is derived from numeric count without string parsing',
      () {
    expect(profile(rating: 5, reviewsCount: 1).reviewsLabel, '1 review');
    expect(
        profile(rating: 4.7, reviewsCount: 1200).reviewsLabel, '1200 reviews');
  });

  test('invalid rating cannot retain a positive review count', () {
    final trainer = profile(rating: 0, reviewsCount: 3);

    expect(trainer.rating, 0);
    expect(trainer.reviewsCount, 0);
  });
}
