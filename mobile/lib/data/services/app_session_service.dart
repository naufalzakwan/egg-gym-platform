import 'dart:async';
import 'dart:convert';

import 'package:egg_gym/data/services/device_token_registration_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSessionService extends ChangeNotifier {
  AppSessionService._();

  static final AppSessionService instance = AppSessionService._();
  static const _storageKey = 'egg_gym_app_session';

  AppAuthenticatedSession? _session;
  bool _isHydrated = false;

  AppAuthenticatedSession? get currentSession => _session;

  bool get isAuthenticated => _session != null;
  bool get isMemberAuthenticated => _session?.role == 'member';
  bool get isTrainerAuthenticated => _session?.role == 'trainer';

  Future<void> hydrate() async {
    if (_isHydrated) {
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    final rawSession = preferences.getString(_storageKey);

    if (rawSession == null || rawSession.isEmpty) {
      _isHydrated = true;
      return;
    }

    try {
      final decoded = jsonDecode(rawSession);
      if (decoded is Map<String, dynamic>) {
        _session = AppAuthenticatedSession.fromMap(decoded);
      }
    } catch (_) {
      _session = null;
      await preferences.remove(_storageKey);
    } finally {
      _isHydrated = true;
    }
  }

  Future<void> setSession(AppAuthenticatedSession session) async {
    final previousIdentity = _sessionIdentity(_session);
    _session = session;
    _isHydrated = true;

    if (previousIdentity != _sessionIdentity(session)) {
      notifyListeners();
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, jsonEncode(session.toMap()));
  }

  /// Perbarui hanya baseUrl aktif (mis. saat IP laptop berubah & auto-fallback
  /// menemukan host hidup baru), lalu persist. Tidak mengubah token/role dsb.
  /// No-op bila tidak ada sesi aktif atau baseUrl sama.
  Future<void> updateBaseUrl(String baseUrl) async {
    final current = _session;
    if (current == null || current.baseUrl == baseUrl) {
      return;
    }
    await setSession(current.copyWith(baseUrl: baseUrl));
  }

  /// Perbarui avatar_url (relative path) aktif + persist. Dipakai setelah
  /// upload/hapus foto profil agar SEMUA tempat yang baca session langsung
  /// konsisten. [avatarUrl] null = hapus foto (kembali ke inisial).
  Future<void> updateAvatarUrl(String? avatarUrl) async {
    final current = _session;
    if (current == null) return;
    await setSession(
        current.copyWith(avatarUrl: avatarUrl, clearAvatar: avatarUrl == null));
  }

  Future<void> updateIdentity({String? name, String? email}) async {
    final current = _session;
    if (current == null) return;
    await setSession(current.copyWith(name: name, email: email));
  }

  Future<void> clear() async {
    final previousSession = _session;
    if (previousSession != null) {
      unawaited(DeviceTokenRegistrationService().unregisterIfRegistered(
        baseUrl: previousSession.baseUrl,
        authToken: previousSession.token,
      ));
    }
    final hadSession = _session != null;
    _session = null;
    _isHydrated = true;

    if (hadSession) {
      notifyListeners();
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey);
  }

  String? _sessionIdentity(AppAuthenticatedSession? session) => session == null
      ? null
      : '${session.baseUrl}|${session.role}|${session.userId}|${session.token}';
}

class AppAuthenticatedSession {
  const AppAuthenticatedSession({
    required this.baseUrl,
    required this.token,
    required this.role,
    required this.userId,
    required this.name,
    required this.email,
    this.avatarUrl,
  });

  final String baseUrl;
  final String token;
  final String role;
  final int? userId;
  final String? name;
  final String? email;

  /// Relative path foto profil (mis. "avatars/abc.jpg"). Null = belum ada
  /// (tampil inisial). Dipakai semua tempat yg render avatar via InitialAvatar.
  final String? avatarUrl;

  AppAuthenticatedSession copyWith({
    String? baseUrl,
    String? name,
    String? email,
    String? avatarUrl,
    bool clearAvatar = false,
  }) {
    return AppAuthenticatedSession(
      baseUrl: baseUrl ?? this.baseUrl,
      token: token,
      role: role,
      userId: userId,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'baseUrl': baseUrl,
      'token': token,
      'role': role,
      'userId': userId,
      'name': name,
      'email': email,
      'avatarUrl': avatarUrl,
    };
  }

  factory AppAuthenticatedSession.fromMap(Map<String, dynamic> map) {
    return AppAuthenticatedSession(
      baseUrl: map['baseUrl']?.toString() ?? '',
      token: map['token']?.toString() ?? '',
      role: map['role']?.toString() ?? '',
      userId: map['userId'] is int
          ? map['userId'] as int
          : int.tryParse(map['userId']?.toString() ?? ''),
      name: map['name']?.toString(),
      email: map['email']?.toString(),
      avatarUrl: map['avatarUrl']?.toString(),
    );
  }
}
