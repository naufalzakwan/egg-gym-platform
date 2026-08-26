import 'dart:convert';

import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:egg_gym/data/services/backend_member_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSessionService.instance.clear();
    await AppSessionService.instance.setSession(
      const AppAuthenticatedSession(
        baseUrl: 'http://member.test',
        token: 'token',
        role: 'member',
        userId: 1,
        name: 'Member',
        email: 'member@example.test',
      ),
    );
  });

  tearDown(() => AppSessionService.instance.clear());

  for (final testCase in <({Object? jsonValue, int? expected})>[
    (jsonValue: 0, expected: 0),
    (jsonValue: 7, expected: 7),
    (jsonValue: null, expected: null),
    (jsonValue: '12', expected: 12),
  ]) {
    test('maps workouts_this_month value ${testCase.jsonValue}', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/member/profile');
        return http.Response(
          jsonEncode({
            'data': {
              'name': 'Member',
              'email': 'member@example.test',
              if (testCase.jsonValue != null)
                'workouts_this_month': testCase.jsonValue,
            },
          }),
          200,
        );
      });

      final profile = await BackendMemberService(client: client).getProfile();

      expect(profile.workoutsThisMonth, testCase.expected);
    });
  }
}
