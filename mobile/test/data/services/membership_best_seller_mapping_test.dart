import 'dart:convert';

import 'package:egg_gym/data/services/backend_api_config.dart';
import 'package:egg_gym/data/services/backend_payment_service.dart';
import 'package:egg_gym/data/services/backend_public_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUp(() {
    BackendApiConfig.activePublicBaseUrl = 'http://public.test';
  });

  tearDown(() {
    BackendApiConfig.activePublicBaseUrl = null;
  });

  test('public mapper maps best seller independently from highlighted',
      () async {
    final plans =
        await BackendPublicService(client: _client()).getMembershipPlans();

    expect(plans[0].isBestSeller, isTrue);
    expect(plans[0].isHighlighted, isFalse);
    expect(plans[1].isBestSeller, isFalse);
    expect(plans[1].isHighlighted, isTrue);
  });

  test('payment mapper maps best seller independently from highlighted',
      () async {
    final plans = await BackendPaymentService(client: _client())
        .getPublicMembershipPlans();

    expect(plans[0].isBestSeller, isTrue);
    expect(plans[0].isHighlighted, isFalse);
    expect(plans[1].isBestSeller, isFalse);
    expect(plans[1].isHighlighted, isTrue);
  });
}

MockClient _client() => MockClient((request) async {
      expect(request.url.path, '/api/v1/public/membership-plans');
      return http.Response(
        jsonEncode({
          'success': true,
          'data': [
            {
              'id': 1,
              'name': 'Popular Basic',
              'slug': 'popular-basic',
              'price': 100000,
              'billing_period': 'monthly',
              'features': <String>[],
              'is_highlighted': false,
              'is_featured': false,
              'is_best_seller': true,
            },
            {
              'id': 2,
              'name': 'Elite Member',
              'slug': 'elite-member',
              'price': 200000,
              'billing_period': 'monthly',
              'features': <String>[],
              'is_highlighted': true,
              'is_featured': true,
              'is_best_seller': false,
            },
          ],
        }),
        200,
      );
    });
