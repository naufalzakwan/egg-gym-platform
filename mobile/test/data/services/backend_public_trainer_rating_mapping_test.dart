import 'dart:convert';

import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:egg_gym/data/services/backend_api_config.dart';
import 'package:egg_gym/data/services/backend_public_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSessionService.instance.clear();
    BackendApiConfig.activePublicBaseUrl = 'http://public.test';
  });

  tearDown(() {
    BackendApiConfig.activePublicBaseUrl = null;
  });

  test('maps numeric review count and removes positive zero-count rating',
      () async {
    final client = MockClient((request) async {
      expect(
          request.url.toString(), 'http://public.test/api/v1/public/trainers');
      return http.Response(
        jsonEncode({
          'success': true,
          'data': [
            {
              'id': 1,
              'name': 'Unrated Coach',
              'rating': '4.9',
              'reviews_count': '0',
              'certifications': 'Ignored Legacy',
              'certifications_list': [],
            },
            {
              'id': 2,
              'name': 'Rated Coach',
              'rating': '4.7',
              'reviews_count': '3',
              'certifications': 'Legacy One, Legacy Two',
              'certifications_list': ['NASM CPT', 'Sports Nutrition Coach'],
            },
            {
              'id': 3,
              'name': 'Legacy Coach',
              'rating': 0,
              'reviews_count': 0,
              'certifications': 'RYT 500',
            },
          ],
        }),
        200,
      );
    });

    final trainers = await BackendPublicService(client: client).getTrainers();

    expect(trainers.first.reviewsCount, 0);
    expect(trainers.first.rating, 0);
    expect(trainers.first.certificationCount, 0);
    expect(trainers[1].reviewsCount, 3);
    expect(trainers[1].rating, 4.7);
    expect(trainers[1].certifications, ['NASM CPT', 'Sports Nutrition Coach']);
    expect(trainers[1].certificationCount, 2);
    expect(trainers.last.certifications, ['RYT 500']);
    expect(trainers.last.certificationCount, 1);
  });
}
