import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DeviceTokenRegistrationService {
  DeviceTokenRegistrationService({http.Client? client})
      : _client = client ?? http.Client();

  static const _deviceIdKey = 'egg_gym_device_id';
  final http.Client _client;

  Future<bool> register({
    required String baseUrl,
    required String authToken,
    required String fcmToken,
  }) async {
    if (baseUrl.isEmpty || authToken.isEmpty || fcmToken.isEmpty) return false;
    final deviceId = await _deviceId();

    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/v1/auth/device-token'),
            headers: <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode(<String, dynamic>{
              'device_id': deviceId,
              'fcm_token': fcmToken,
              'platform': 'android',
              'device_name': 'Egg Gym Android',
            }),
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<bool> unregisterIfRegistered({
    required String baseUrl,
    required String authToken,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final deviceId = preferences.getString(_deviceIdKey);
    if (deviceId == null || deviceId.isEmpty) return false;

    try {
      final request = http.Request(
        'DELETE',
        Uri.parse('$baseUrl/api/v1/auth/device-token'),
      )
        ..headers.addAll(<String, String>{
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        })
        ..body = jsonEncode(<String, dynamic>{'device_id': deviceId});
      final response =
          await _client.send(request).timeout(const Duration(seconds: 10));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<String> _deviceId() async {
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final generated = List<int>.generate(16, (_) => random.nextInt(256))
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    await preferences.setString(_deviceIdKey, generated);
    return generated;
  }
}
