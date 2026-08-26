import 'dart:convert';

import 'package:egg_gym/data/services/device_token_registration_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('register posts a stable device id and FCM token', () async {
    final bodies = <Map<String, dynamic>>[];
    final service = DeviceTokenRegistrationService(
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/device-token');
        expect(request.headers['authorization'], 'Bearer auth-token');
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(jsonEncode({'success': true}), 200);
      }),
    );

    expect(
      await service.register(
        baseUrl: 'http://backend.test',
        authToken: 'auth-token',
        fcmToken: 'fcm-one',
      ),
      isTrue,
    );
    expect(
      await service.register(
        baseUrl: 'http://backend.test',
        authToken: 'auth-token',
        fcmToken: 'fcm-two',
      ),
      isTrue,
    );

    expect(bodies, hasLength(2));
    expect(bodies.first['device_id'], isNotEmpty);
    expect(bodies.last['device_id'], bodies.first['device_id']);
    expect(bodies.last['fcm_token'], 'fcm-two');
    expect(bodies.last['platform'], 'android');
  });

  test('unregister sends the same persisted device id', () async {
    String? registeredDeviceId;
    final service = DeviceTokenRegistrationService(
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (request.method == 'POST') {
          registeredDeviceId = body['device_id'] as String;
        } else {
          expect(request.method, 'DELETE');
          expect(body['device_id'], registeredDeviceId);
        }
        return http.Response(jsonEncode({'success': true}), 200);
      }),
    );

    await service.register(
      baseUrl: 'http://backend.test',
      authToken: 'auth-token',
      fcmToken: 'fcm-token',
    );
    expect(
      await service.unregisterIfRegistered(
        baseUrl: 'http://backend.test',
        authToken: 'auth-token',
      ),
      isTrue,
    );
  });
}
