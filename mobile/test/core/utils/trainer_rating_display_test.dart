import 'package:egg_gym/core/utils/trainer_rating_display.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('trainerRatingDisplay', () {
    test('formats zero, one, and multiple reviews', () {
      expect(
        trainerRatingDisplay(rating: 4.9, reviewsCount: 0),
        'Belum ada rating',
      );
      expect(
        trainerRatingDisplay(rating: 5, reviewsCount: 1),
        '5.0 • 1 review',
      );
      expect(
        trainerRatingDisplay(rating: 4.74, reviewsCount: 3),
        '4.7 • 3 reviews',
      );
    });

    test('rejects invalid arguments', () {
      expect(
        () => trainerRatingDisplay(rating: 4, reviewsCount: -1),
        throwsArgumentError,
      );
      expect(
        () => trainerRatingDisplay(rating: 0, reviewsCount: 1),
        throwsArgumentError,
      );
      expect(
        () => trainerRatingDisplay(rating: 6, reviewsCount: 1),
        throwsArgumentError,
      );
    });
  });

  test('trainer own profile stays empty without a real rating', () {
    expect(trainerOwnProfileRatingDisplay(null), '-');
    expect(trainerOwnProfileRatingDisplay(0), '-');
    expect(trainerOwnProfileRatingDisplay(4.86), '4.9');
  });
}
