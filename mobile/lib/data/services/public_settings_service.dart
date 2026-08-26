import 'dart:convert';

import 'package:egg_gym/data/services/backend_api_config.dart';
import 'package:egg_gym/data/services/backend_public_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MembershipPaymentChannel {
  const MembershipPaymentChannel(
      {required this.code,
      required this.label,
      required this.description,
      required this.order});

  final String code;
  final String label;
  final String description;
  final int order;

  factory MembershipPaymentChannel.fromJson(Map<String, dynamic> json) =>
      MembershipPaymentChannel(
        code: json['code']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        order: int.tryParse(json['display_order']?.toString() ?? '') ?? 0,
      );
}

class PublicAppSettings {
  const PublicAppSettings(
      {required this.brandName,
      required this.tagline,
      required this.logoPath,
      required this.logoVersion,
      required this.location,
      required this.phone,
      required this.whatsapp,
      required this.email,
      required this.instagram,
      required this.paymentChannels});

  static const fallback = PublicAppSettings(
    brandName: 'EggGym',
    tagline: 'Your Gym, Smarter',
    logoPath: null,
    logoVersion: 1,
    location: '',
    phone: '',
    whatsapp: '',
    email: '',
    instagram: '',
    paymentChannels: [],
  );

  final String brandName;
  final String tagline;
  final String? logoPath;
  final int logoVersion;
  final String location;
  final String phone;
  final String whatsapp;
  final String email;
  final String instagram;
  final List<MembershipPaymentChannel> paymentChannels;

  factory PublicAppSettings.fromJson(Map<String, dynamic> json) {
    final gym = json['gym'] is Map<String, dynamic>
        ? json['gym'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final methods = json['membership_payment_methods'] is List
        ? json['membership_payment_methods'] as List
        : const [];
    return PublicAppSettings(
      brandName: gym['brand_name']?.toString().trim().isNotEmpty == true
          ? gym['brand_name'].toString()
          : fallback.brandName,
      tagline: gym['tagline']?.toString().trim().isNotEmpty == true
          ? gym['tagline'].toString()
          : fallback.tagline,
      logoPath: gym['logo_path']?.toString(),
      logoVersion: int.tryParse(gym['logo_version']?.toString() ?? '') ?? 1,
      location: [gym['address'], gym['city'], gym['province']]
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .join(', '),
      phone: gym['phone']?.toString() ?? '',
      whatsapp: gym['whatsapp']?.toString() ?? '',
      email: gym['email']?.toString() ?? '',
      instagram: gym['instagram']?.toString() ?? '',
      paymentChannels: methods
          .whereType<Map<String, dynamic>>()
          .map(MembershipPaymentChannel.fromJson)
          .where((item) => item.code.isNotEmpty)
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order)),
    );
  }
}

enum PublicSettingsState { initial, ready, failed }

class PublicSettingsService {
  PublicSettingsService._();
  static final instance = PublicSettingsService._();
  static const _cacheKey = 'egg_gym_public_settings_v1';
  static const _baseUrlCacheKey = 'egg_gym_public_base_url_v1';

  final ValueNotifier<PublicAppSettings> settings =
      ValueNotifier(PublicAppSettings.fallback);
  final ValueNotifier<bool> loading = ValueNotifier(false);
  final ValueNotifier<PublicSettingsState> state =
      ValueNotifier(PublicSettingsState.initial);

  Future<void> hydrate() async {
    final preferences = await SharedPreferences.getInstance();
    final cachedBaseUrl = preferences.getString(_baseUrlCacheKey)?.trim();
    if (cachedBaseUrl != null && cachedBaseUrl.isNotEmpty) {
      BackendApiConfig.activePublicBaseUrl = cachedBaseUrl;
    }

    final raw = preferences.getString(_cacheKey);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw);
      if (json is Map<String, dynamic>) {
        settings.value = PublicAppSettings.fromJson(json);
        state.value = PublicSettingsState.ready;
      }
    } catch (_) {
      await (await SharedPreferences.getInstance()).remove(_cacheKey);
      state.value = PublicSettingsState.initial;
    }
  }

  Future<void> refresh() async {
    if (loading.value) return;
    loading.value = true;
    try {
      final json = await BackendPublicService().getPublicSettings();
      settings.value = PublicAppSettings.fromJson(json);
      state.value = PublicSettingsState.ready;
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_cacheKey, jsonEncode(json));
      final activeBaseUrl = BackendApiConfig.activePublicBaseUrl;
      if (activeBaseUrl != null && activeBaseUrl.isNotEmpty) {
        await preferences.setString(_baseUrlCacheKey, activeBaseUrl);
      }
    } catch (_) {
      if (state.value != PublicSettingsState.ready) {
        state.value = PublicSettingsState.failed;
      }
      rethrow;
    } finally {
      loading.value = false;
    }
  }
}
