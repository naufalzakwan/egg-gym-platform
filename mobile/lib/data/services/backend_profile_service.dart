import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:egg_gym/data/services/backend_api_config.dart';
import 'package:http/http.dart' as http;

class ProfileApiException implements Exception {
  const ProfileApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Service upload/hapus foto profil (avatar). REUSABLE untuk member & trainer
/// (endpoint berbasis user login). Backend menyimpan & mengembalikan RELATIVE
/// PATH; hasilnya disimpan ke session (updateAvatarUrl) supaya semua tempat
/// yang render InitialAvatar langsung konsisten.
class BackendProfileService {
  BackendProfileService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  ({String baseUrl, String token}) _authenticate() {
    final session = AppSessionService.instance;
    final current = session.currentSession;
    final token = current?.token;
    final baseUrl = current?.baseUrl;
    if (token == null || baseUrl == null) {
      throw const ProfileApiException('Sesi belum aktif.');
    }
    return (baseUrl: baseUrl, token: token);
  }

  /// Upload avatar (multipart). Mengembalikan relative path baru & langsung
  /// menyimpannya ke session. Lempar [ProfileApiException] bila gagal.
  Future<String> uploadAvatar(File file) async {
    final auth = _authenticate();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${auth.baseUrl}/api/v1/profile/avatar'),
    );
    request.headers['Authorization'] = 'Bearer ${auth.token}';
    request.headers['Accept'] = 'application/json';
    request.files.add(await http.MultipartFile.fromPath('avatar', file.path));

    final streamed = await request.send().timeout(
          BackendApiConfig.requestTimeout,
        );
    final body = await streamed.stream.bytesToString();
    final payload = _decodeJson(body);

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw ProfileApiException(
        payload['message']?.toString() ?? 'Gagal mengunggah foto profil.',
      );
    }

    final data = payload['data'];
    final avatarPath =
        data is Map<String, dynamic> ? data['avatar_url']?.toString() : null;
    if (avatarPath == null || avatarPath.isEmpty) {
      throw const ProfileApiException('Response avatar tidak valid.');
    }

    await AppSessionService.instance.updateAvatarUrl(avatarPath);
    return avatarPath;
  }

  /// Hapus avatar. Mengosongkan avatar_url di session (kembali ke inisial).
  Future<void> deleteAvatar() async {
    final auth = _authenticate();
    final response = await _client.delete(
      Uri.parse('${auth.baseUrl}/api/v1/profile/avatar'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer ${auth.token}',
      },
    ).timeout(BackendApiConfig.requestTimeout);

    final payload = _decodeJson(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ProfileApiException(
        payload['message']?.toString() ?? 'Gagal menghapus foto profil.',
      );
    }

    await AppSessionService.instance.updateAvatarUrl(null);
  }

  Map<String, dynamic> _decodeJson(String body) {
    if (body.isEmpty) return const {};
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return const {};
  }
}
