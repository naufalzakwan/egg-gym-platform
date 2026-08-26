import 'dart:convert';

import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:egg_gym/data/services/backend_trainer_profile_service.dart';
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
        token: 'token',
        baseUrl: 'http://profile.test',
        role: 'trainer',
        userId: 1,
        name: 'Trainer',
        email: 'trainer@example.test',
      ),
    );
  });

  test('profile mapper prefers certification list and update sends array',
      () async {
    late Map<String, dynamic> updateBody;
    final service = BackendTrainerProfileService(
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'data': {
                'id': 1,
                'certifications': 'Legacy One, Legacy Two',
                'certifications_list': ['NASM CPT', 'Sports Nutrition Coach'],
              },
            }),
            200,
          );
        }
        updateBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'data': updateBody}), 200);
      }),
    );

    final profile = await service.getProfile();
    expect(profile.certifications, ['NASM CPT', 'Sports Nutrition Coach']);

    await service
        .updateProfile(certifications: ['NASM CPT', 'Mobility Specialist']);
    expect(updateBody['certifications'], ['NASM CPT', 'Mobility Specialist']);
  });

  test('profile mapper splits legacy comma string when list is absent',
      () async {
    final service = BackendTrainerProfileService(
      client: MockClient((_) async => http.Response(
            jsonEncode({
              'data': {'certifications': 'RYT 500, Mobility Specialist'},
            }),
            200,
          )),
    );

    expect(
      (await service.getProfile()).certifications,
      ['RYT 500', 'Mobility Specialist'],
    );
  });
}
