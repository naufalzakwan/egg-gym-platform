import 'dart:convert';

import 'package:egg_gym/data/services/backend_api_config.dart';
import 'package:egg_gym/data/services/backend_public_service.dart';
import 'package:egg_gym/presentation/pages/guest/guest_membership_tab_v2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BackendApiConfig.activePublicBaseUrl = 'http://public.test';
  });

  tearDown(() {
    BackendApiConfig.activePublicBaseUrl = null;
  });

  testWidgets('maps and renders four arbitrary membership plans dynamically',
      (tester) async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/v1/public/membership-plans');
      return http.Response(
        jsonEncode({
          'success': true,
          'data': [
            _plan(11, 'Starter Drop', 'starter-drop', 7, ['Gym access']),
            _plan(12, 'Weekend Pass', 'weekend-pass', 14, ['Weekend access']),
            _plan(13, 'Night Owl', 'night-owl', 30, ['Night access']),
            _plan(14, 'Flash Sale', 'flash-sale', 10, [
              'Flash class access',
              'Locker access',
            ]),
          ],
        }),
        200,
      );
    });

    final plans =
        await BackendPublicService(client: client).getMembershipPlans();

    expect(plans, hasLength(4));
    expect(plans.map((plan) => plan.title), contains('Flash Sale'));
    expect(plans.last.durationDays, 10);
    expect(plans.last.features, ['Flash class access', 'Locker access']);

    await tester.binding.setSurfaceSize(const Size(800, 5000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GuestMembershipTabV2(
            plans: plans,
            isLoading: false,
            loadError: null,
            onRetry: () async {},
          ),
        ),
      ),
    );

    expect(find.byType(OutlinedButton), findsNWidgets(4));
    for (final plan in plans) {
      expect(find.text(plan.title), findsOneWidget);
    }
    expect(find.text('10 HARI'), findsOneWidget);
    expect(find.text('Flash class access'), findsOneWidget);
    expect(find.text('Locker access'), findsOneWidget);
  });
}

Map<String, Object> _plan(
  int id,
  String name,
  String slug,
  int durationDays,
  List<String> features,
) {
  return {
    'id': id,
    'name': name,
    'slug': slug,
    'price': id * 10000,
    'billing_period': 'monthly',
    'duration_days': durationDays,
    'features': features,
    'is_highlighted': false,
    'is_best_seller': false,
  };
}
