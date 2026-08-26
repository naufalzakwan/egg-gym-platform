import 'dart:convert';

import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:egg_gym/data/services/backend_api_config.dart';
import 'package:egg_gym/data/services/backend_public_service.dart';
import 'package:egg_gym/data/services/backend_trainer_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const baseUrl = 'http://schedule.test';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSessionService.instance.clear();
    BackendApiConfig.activePublicBaseUrl = baseUrl;
  });

  tearDown(() async {
    await AppSessionService.instance.clear();
    BackendApiConfig.activePublicBaseUrl = null;
  });

  test('public trainers map schedule independently from quota', () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), '$baseUrl/api/v1/public/trainers');
      return http.Response(
        jsonEncode({
          'success': true,
          'data': [
            {
              'id': 1,
              'name': 'Scheduled Full',
              'specialty': 'strength_conditioning',
              'is_available': false,
              'has_active_schedule': true,
            },
            {
              'id': 2,
              'name': 'Missing Flag',
              'specialty': 'yoga',
              'is_available': true,
            },
          ],
        }),
        200,
      );
    });

    final trainers = await BackendPublicService(client: client).getTrainers();

    expect(trainers[0].isAvailable, isFalse);
    expect(trainers[0].hasActiveSchedule, isTrue);
    expect(trainers[1].isAvailable, isTrue);
    expect(trainers[1].hasActiveSchedule, isFalse);
  });

  test('trainer dashboard maps authoritative schedule flag', () async {
    await AppSessionService.instance.setSession(
      const AppAuthenticatedSession(
        baseUrl: baseUrl,
        token: 'token',
        role: 'trainer',
        userId: 7,
        name: 'Coach',
        email: 'coach@example.test',
      ),
    );
    final client = MockClient((request) async {
      expect(request.url.toString(), '$baseUrl/api/v1/trainer/dashboard');
      return http.Response(
        jsonEncode({
          'data': {
            'trainer_name': 'Coach',
            'tier': 'elite',
            'active_clients': 0,
            'today_sessions': 0,
            'rating': 0,
            'today_agenda': [],
            'has_active_schedule': false,
          },
        }),
        200,
      );
    });

    final dashboard =
        await BackendTrainerService(client: client).getDashboard();

    expect(dashboard.hasActiveSchedule, isFalse);
    expect(dashboard.tier, 'elite');
  });
}
