import 'dart:convert';

import 'package:egg_gym/data/services/backend_api_config.dart';
import 'package:egg_gym/data/services/backend_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('login maps invalid credentials to a user-friendly message', () async {
    BackendApiConfig.activePublicBaseUrl = 'http://auth.test';
    addTearDown(() => BackendApiConfig.activePublicBaseUrl = null);
    final service = BackendAuthService(
      client: MockClient((_) async => http.Response(
            jsonEncode({
              'message': 'These credentials do not match our records.',
              'errors': {
                'email': ['Kredensial yang diberikan tidak valid.'],
              },
            }),
            401,
          )),
    );

    expect(
      () => service.login(
        email: 'salah@example.test',
        password: 'password-salah',
      ),
      throwsA(
        isA<AuthApiException>().having(
          (error) => error.message,
          'message',
          'Email atau password salah.',
        ),
      ),
    );
  });

  test(
      'register surfaces first field validation message instead of raw summary',
      () async {
    BackendApiConfig.activePublicBaseUrl = 'http://auth.test';
    addTearDown(() => BackendApiConfig.activePublicBaseUrl = null);
    final service = BackendAuthService(
      client: MockClient((_) async => http.Response(
            jsonEncode({
              'message': 'The given data was invalid.',
              'errors': {
                'name': [
                  'Nama hanya boleh huruf dan spasi.',
                ],
              },
            }),
            422,
          )),
    );

    expect(
      () => service.register(
        name: 'dsds123',
        email: 'member@example.test',
        password: 'EggGym@123',
        passwordConfirmation: 'EggGym@123',
        phone: '081234567890',
      ),
      throwsA(
        isA<AuthApiException>().having(
          (error) => error.message,
          'message',
          'Nama hanya boleh huruf dan spasi.',
        ),
      ),
    );
  });
}
