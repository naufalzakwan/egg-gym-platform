import 'dart:convert';

import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:egg_gym/data/services/backend_program_service.dart';
import 'package:egg_gym/presentation/pages/trainer/trainer_shell_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const baseUrl = 'http://authenticated-program.test';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSessionService.instance.clear();
    await AppSessionService.instance.setSession(
      const AppAuthenticatedSession(
        baseUrl: baseUrl,
        token: 'trainer-token',
        role: 'trainer',
        userId: 9,
        name: 'Coach',
        email: 'coach@example.test',
      ),
    );
  });

  tearDown(() async {
    await AppSessionService.instance.clear();
  });

  test('maps active authority, metrics, and next session from trainer API',
      () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), '$baseUrl/api/v1/trainer/programs');
      expect(request.headers['Authorization'], 'Bearer trainer-token');
      return http.Response(
        jsonEncode({
          'data': [
            {
              'id': 21,
              'title': 'Future Strength',
              'member_profile_id': 8,
              'member_name': 'Member A',
              'status': 'active',
              'sessions_count': 4,
              'completed_sessions_count': 1,
              'progress_percent': 25,
              'is_active_control': true,
              'total_duration_minutes': 240,
              'exercises_count': 12,
              'next_session': {
                'session_date': '2030-08-15',
                'start': '10:00:00',
                'end': '11:30:00',
                'status': 'reserved',
              },
            },
          ],
        }),
        200,
      );
    });

    final programs =
        await BackendProgramService(client: client).getTrainerPrograms();
    final program = programs.single;

    expect(program.isActiveControl, isTrue);
    expect(program.totalDurationMinutes, 240);
    expect(program.exercisesCount, 12);
    expect(program.nextSession?.sessionDate, '2030-08-15');
    expect(program.nextSession?.startTime, '10:00:00');
    expect(program.nextSession?.endTime, '11:30:00');
    expect(program.nextSession?.status, 'reserved');
  });

  test('active filter uses only backend isActiveControl', () {
    const active = ProgramListItem(
      id: 1,
      title: 'Future active program',
      memberProfileId: 1,
      status: 'draft',
      sessionsCount: 0,
      progressPercent: 100,
      isActiveControl: true,
    );
    const inactive = ProgramListItem(
      id: 2,
      title: 'Locally plausible but backend inactive',
      memberProfileId: 2,
      status: 'active',
      sessionsCount: 8,
      progressPercent: 20,
      isActiveControl: false,
    );

    expect(isTrainerProgramActive(active), isTrue);
    expect(isTrainerProgramActive(inactive), isFalse);
  });
}
