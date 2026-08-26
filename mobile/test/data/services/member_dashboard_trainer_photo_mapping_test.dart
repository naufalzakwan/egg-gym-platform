import 'dart:convert';

import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:egg_gym/data/services/backend_member_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const baseUrl = 'http://member-dashboard.test';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSessionService.instance.clear();
    await AppSessionService.instance.setSession(
      const AppAuthenticatedSession(
        baseUrl: baseUrl,
        token: 'member-token',
        role: 'member',
        userId: 1,
        name: 'Member',
        email: 'member@example.test',
      ),
    );
  });

  tearDown(() async {
    await AppSessionService.instance.clear();
  });

  test('maps trainer display photo and avatar from member dashboard', () async {
    final service = BackendMemberService(
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/member/dashboard');
        expect(request.headers['Authorization'], 'Bearer member-token');
        return http.Response(
          jsonEncode({
            'data': {
              'member_name': 'Member',
              'current_tier': 'Member Status',
              'package_name': 'Bulanan',
              'valid_until': '2026-08-31',
              'remaining_days': 30,
              'next_session': {
                'id': 12,
                'trainer_profile_id': 7,
                'trainer_name': 'Coach Elena Rodriguez',
                'trainer_avatar_url': 'avatars/elena.jpg',
                'trainer_display_photo_path':
                    'trainer-display-photos/elena.jpg',
                'date': '2026-08-10',
                'time_range': '15:00 - 16:00',
                'location': 'Egg Gym Pontianak',
                'status': 'payment_verified',
                'session_reservations': [],
              },
            },
          }),
          200,
        );
      }),
    );

    final dashboard = await service.getDashboard();

    expect(dashboard.nextSession?.clientName, 'Coach Elena Rodriguez');
    expect(
      dashboard.nextSession?.trainerDisplayPhotoPath,
      'trainer-display-photos/elena.jpg',
    );
    expect(dashboard.nextSession?.trainerAvatarUrl, 'avatars/elena.jpg');
  });
}
