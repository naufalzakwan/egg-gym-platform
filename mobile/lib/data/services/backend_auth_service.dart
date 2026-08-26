import 'dart:async';
import 'dart:convert';

import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:egg_gym/data/services/backend_api_config.dart';
import 'package:egg_gym/data/services/device_token_registration_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

class BackendAuthService {
  BackendAuthService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<AppAuthenticatedSession> login({
    required String email,
    required String password,
  }) async {
    AuthApiException? responseError;

    for (final baseUrl in BackendApiConfig.candidateBaseUrls) {
      var shouldStopAfterAuthError = false;

      try {
        final response = await _client
            .post(
              Uri.parse('$baseUrl/api/v1/auth/login'),
              headers: const <String, String>{
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode(<String, dynamic>{
                'email': email,
                'password': password,
              }),
            )
            .timeout(BackendApiConfig.requestTimeout);

        final payload = _decodeJson(response.body);

        if (response.statusCode < 200 || response.statusCode >= 300) {
          final authError = AuthApiException(
            response.statusCode == 401
                ? 'Email atau password salah.'
                : _extractMessage(
                    payload,
                    fallback: 'Login backend gagal diproses.',
                  ),
          );

          if (_isAuthoritativeAuthStatus(response.statusCode)) {
            shouldStopAfterAuthError = true;
            throw authError;
          }

          responseError ??= authError;
          continue;
        }

        final data = payload['data'];
        if (data is! Map<String, dynamic>) {
          responseError ??=
              const AuthApiException('Response login backend tidak valid.');
          continue;
        }

        final user = data['user'];
        if (user is! Map<String, dynamic>) {
          responseError ??= const AuthApiException(
            'Response user backend tidak ditemukan.',
          );
          continue;
        }

        final token = _asNullableString(data['token']);
        final role = _asNullableString(user['role']);

        if (token == null || token.isEmpty) {
          responseError ??=
              const AuthApiException('Token login backend tidak ditemukan.');
          continue;
        }

        if (role == null || role.isEmpty) {
          responseError ??=
              const AuthApiException('Role user backend tidak ditemukan.');
          continue;
        }

        final session = AppAuthenticatedSession(
          baseUrl: baseUrl,
          token: token,
          role: role,
          userId: _asNullableInt(user['id']),
          name: _asNullableString(user['name']),
          email: _asNullableString(user['email']),
          avatarUrl: _asNullableString(user['avatar_url']),
        );

        await AppSessionService.instance.setSession(session);
        unawaited(_registerDeviceToken(session));
        return session;
      } on AuthApiException catch (error) {
        responseError ??= error;

        if (shouldStopAfterAuthError) {
          rethrow;
        }
      } catch (_) {
        // Keep probing fallback hosts only for transport/network failures.
      }
    }

    if (responseError != null) {
      throw responseError;
    }

    throw const AuthApiException(
      'App belum bisa menjangkau backend Laravel untuk login.',
    );
  }

  Future<AppAuthenticatedSession> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    required String phone,
  }) async {
    AuthApiException? responseError;

    for (final baseUrl in BackendApiConfig.candidateBaseUrls) {
      var shouldStopAfterAuthError = false;

      try {
        final response = await _client
            .post(
              Uri.parse('$baseUrl/api/v1/auth/register'),
              headers: const <String, String>{
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode(<String, dynamic>{
                'name': name,
                'email': email,
                'password': password,
                'password_confirmation': passwordConfirmation,
                'phone': phone,
              }),
            )
            .timeout(BackendApiConfig.requestTimeout);

        final payload = _decodeJson(response.body);

        if (response.statusCode < 200 || response.statusCode >= 300) {
          final authError = AuthApiException(
            _extractMessage(payload, fallback: 'Registrasi gagal diproses.'),
          );

          if (_isAuthoritativeAuthStatus(response.statusCode)) {
            shouldStopAfterAuthError = true;
            throw authError;
          }

          responseError ??= authError;
          continue;
        }

        final data = payload['data'];
        if (data is! Map<String, dynamic>) {
          responseError ??= const AuthApiException(
              'Response registrasi backend tidak valid.');
          continue;
        }

        final user = data['user'];
        if (user is! Map<String, dynamic>) {
          responseError ??= const AuthApiException(
            'Response user backend tidak ditemukan.',
          );
          continue;
        }

        final token = _asNullableString(data['token']);
        final role = _asNullableString(user['role']);

        if (token == null || token.isEmpty) {
          responseError ??= const AuthApiException(
              'Token registrasi backend tidak ditemukan.');
          continue;
        }

        if (role == null || role.isEmpty) {
          responseError ??=
              const AuthApiException('Role user backend tidak ditemukan.');
          continue;
        }

        final session = AppAuthenticatedSession(
          baseUrl: baseUrl,
          token: token,
          role: role,
          userId: _asNullableInt(user['id']),
          name: _asNullableString(user['name']),
          email: _asNullableString(user['email']),
          avatarUrl: _asNullableString(user['avatar_url']),
        );

        await AppSessionService.instance.setSession(session);
        unawaited(_registerDeviceToken(session));
        return session;
      } on AuthApiException catch (error) {
        responseError ??= error;

        if (shouldStopAfterAuthError) {
          rethrow;
        }
      } catch (_) {
        // Keep probing fallback hosts only for transport/network failures.
      }
    }

    if (responseError != null) {
      throw responseError;
    }

    throw const AuthApiException(
      'App belum bisa menjangkau backend Laravel untuk registrasi.',
    );
  }

  bool _isAuthoritativeAuthStatus(int statusCode) {
    return statusCode == 400 ||
        statusCode == 401 ||
        statusCode == 403 ||
        statusCode == 422;
  }

  Future<void> _registerDeviceToken(AppAuthenticatedSession session) async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null || fcmToken.isEmpty) return;
      await DeviceTokenRegistrationService().register(
        baseUrl: session.baseUrl,
        authToken: session.token,
        fcmToken: fcmToken,
      );
    } catch (_) {
      // Login tetap berhasil bila layanan notifikasi belum siap.
    }
  }

  Map<String, dynamic> _decodeJson(String rawBody) {
    if (rawBody.isEmpty) {
      return const <String, dynamic>{};
    }

    final decoded = jsonDecode(rawBody);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw const AuthApiException('Response backend bukan JSON yang valid.');
  }

  String _extractMessage(
    Map<String, dynamic> payload, {
    required String fallback,
  }) {
    final errors = payload['errors'];
    if (errors is Map<String, dynamic>) {
      for (final value in errors.values) {
        if (value is List && value.isNotEmpty) {
          return value.first.toString();
        }

        if (value is String && value.isNotEmpty) {
          return value;
        }
      }
    }

    final message = _asNullableString(payload['message']);
    if (message != null && message.isNotEmpty) {
      return message;
    }

    return fallback;
  }

  static String? _asNullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    final stringValue = value.toString();
    return stringValue.isEmpty ? null : stringValue;
  }

  static int? _asNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
  }
}

class AuthApiException implements Exception {
  const AuthApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
