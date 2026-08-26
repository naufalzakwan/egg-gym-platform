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

  tearDown(() async {
    await AppSessionService.instance.clear();
  });

  test('member programs map rating recovery metadata', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/v1/member/programs');
      return http.Response(
        jsonEncode({
          'data': [
            {
              'id': 41,
              'title': 'Strength Recovery',
              'status': 'completed',
              'trainer_name': 'Coach Maya',
              'trainer_avatar_url': 'avatars/maya.jpg',
              'trainer_display_photo_path': 'trainer-display-photos/maya.jpg',
              'progress_percent': 100,
              'total_sessions': 8,
              'completed_sessions': 8,
              'program_completed': true,
              'already_rated': false,
              'can_rate': true,
              'last_session_date': '2026-07-25',
              'completed_at': '2026-07-25T11:30:00+07:00',
              'last_session_duration_minutes': 75,
            },
          ],
        }),
        200,
      );
    });

    final programs = await BackendMemberService(client: client).getPrograms();
    final program = programs.single;

    expect(program.trainerAvatarUrl, 'avatars/maya.jpg');
    expect(program.displayPhotoPath, 'trainer-display-photos/maya.jpg');
    expect(program.lastSessionDate, '2026-07-25');
    expect(program.completedAt, '2026-07-25T11:30:00+07:00');
    expect(program.lastSessionDurationMinutes, 75);
    expect(program.canRate, isTrue);
  });
}
