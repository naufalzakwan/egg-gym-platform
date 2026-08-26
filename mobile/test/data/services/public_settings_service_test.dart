import 'dart:convert';

import 'package:egg_gym/data/services/backend_api_config.dart';
import 'package:egg_gym/data/services/public_settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('parses dynamic brand and sorted membership payment channels', () {
    final settings = PublicAppSettings.fromJson({
      'gym': {
        'brand_name': 'Egg Gym Pontianak',
        'tagline': 'Lebih Kuat',
        'logo_path': 'branding/logo.webp',
        'logo_version': 9,
        'address': 'Jl. Merdeka',
        'city': 'Pontianak',
        'province': 'Kalimantan Barat',
        'phone': '0561',
      },
      'membership_payment_methods': [
        {
          'code': 'bri_va',
          'label': 'VA BRI',
          'description': 'BRI',
          'display_order': 20
        },
        {
          'code': 'qris',
          'label': 'QRIS',
          'description': 'QR',
          'display_order': 10
        },
      ],
    });

    expect(settings.brandName, 'Egg Gym Pontianak');
    expect(settings.tagline, 'Lebih Kuat');
    expect(settings.logoPath, 'branding/logo.webp');
    expect(settings.logoVersion, 9);
    expect(settings.location, 'Jl. Merdeka, Pontianak, Kalimantan Barat');
    expect(settings.phone, '0561');
    expect(
        settings.paymentChannels.map((item) => item.code), ['qris', 'bri_va']);
  });

  test('uses safe local brand fallback and ignores invalid payment entry', () {
    final settings = PublicAppSettings.fromJson({
      'gym': {'brand_name': '', 'tagline': ''},
      'membership_payment_methods': [
        {'label': 'Invalid without code'},
      ],
    });

    expect(settings.brandName, 'EggGym');
    expect(settings.tagline, 'Your Gym, Smarter');
    expect(settings.logoPath, isNull);
    expect(settings.paymentChannels, isEmpty);
  });

  test('hydrates cached public host before splash resolves logo path',
      () async {
    SharedPreferences.setMockInitialValues({
      'egg_gym_public_base_url_v1': 'http://cached-backend.test',
      'egg_gym_public_settings_v1': jsonEncode({
        'gym': {
          'brand_name': 'Cached Brand',
          'tagline': 'Cached Tagline',
          'logo_path': 'branding/cached.webp',
          'logo_version': 3,
        },
      }),
    });
    BackendApiConfig.activePublicBaseUrl = null;

    await PublicSettingsService.instance.hydrate();

    expect(BackendApiConfig.activePublicBaseUrl, 'http://cached-backend.test');
    expect(
        PublicSettingsService.instance.state.value, PublicSettingsState.ready);
    expect(PublicSettingsService.instance.settings.value.brandName,
        'Cached Brand');
    expect(PublicSettingsService.instance.settings.value.logoPath,
        'branding/cached.webp');
  });
}
