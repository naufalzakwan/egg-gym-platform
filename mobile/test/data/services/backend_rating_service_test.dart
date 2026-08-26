import 'dart:convert';

import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:egg_gym/data/services/backend_rating_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSessionService.instance.clear();
  });

  tearDown(() async {
    await AppSessionService.instance.clear();
  });

  test('public GET works without auth and normalizes zero-count rating',
      () async {
    final client = MockClient((request) async {
      expect(request.url.toString(),
          'http://public.test/api/v1/public/trainers/12/ratings');
      expect(request.headers['Authorization'], isNull);
      return http.Response(
        jsonEncode({
          'data': {
            'average_rating': '4.9',
            'reviews_count': '0',
            'reviews': <Object>[],
          },
        }),
        200,
      );
    });

    final summary = await BackendRatingService(
      client: client,
      publicBaseUrl: 'http://public.test',
    ).getTrainerRatings(12);

    expect(summary.averageRating, 0);
    expect(summary.reviewsCount, 0);
  });

  test('public GET parses one numeric-string review consistently', () async {
    final client = MockClient((_) async => http.Response(
          jsonEncode({
            'data': {
              'average_rating': '5.0',
              'reviews_count': '1',
              'reviews': [
                {'id': '7', 'member_name': 'Member', 'rating': '5'}
              ],
            },
          }),
          200,
        ));

    final summary = await BackendRatingService(
      client: client,
      publicBaseUrl: 'http://public.test',
    ).getTrainerRatings(8);

    expect(summary.averageRating, 5);
    expect(summary.reviewsCount, 1);
    expect(summary.reviews.single.rating, 5);
  });

  test('rejects invalid read and submit arguments before network or auth', () {
    final service = BackendRatingService(
      client: MockClient((_) async => http.Response('{}', 500)),
      publicBaseUrl: 'http://public.test',
    );

    expect(() => service.getTrainerRatings(0), throwsArgumentError);
    expect(
      () => service.submitRating(trainingProgramId: 1, rating: 0),
      throwsArgumentError,
    );
    expect(
      () => service.submitRating(trainingProgramId: 0, rating: 5),
      throwsArgumentError,
    );
  });
}
