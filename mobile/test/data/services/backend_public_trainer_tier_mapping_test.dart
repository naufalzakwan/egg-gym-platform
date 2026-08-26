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

  tearDown(() => BackendApiConfig.activePublicBaseUrl = null);

  test('public trainer mapper prefers tier and accepts legacy badge fallback',
      () async {
    final client = MockClient((_) async => http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {'name': 'Basic', 'tier': 'standard'},
              {'name': 'Precedence', 'tier': 'basic', 'badge': 'elite'},
              {'name': 'Legacy', 'badge': 'pro'},
              {'name': 'Invalid tier', 'tier': 'master', 'badge': 'elite'},
              {'name': 'Unknown', 'badge': 'coach'},
            ],
          }),
          200,
        ));

    final trainers = await BackendPublicService(client: client).getTrainers();

    expect(
      trainers.map((trainer) => trainer.tier),
      <String?>['standard', 'basic', 'pro', null, null],
    );
  });
}
