import 'dart:convert';

import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:egg_gym/data/services/backend_payment_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSessionService.instance.clear();
    await AppSessionService.instance.setSession(
      const AppAuthenticatedSession(
        baseUrl: 'http://member.test',
        token: 'token',
        role: 'member',
        userId: 1,
        name: 'Member',
        email: 'member@example.test',
      ),
    );
  });

  tearDown(() => AppSessionService.instance.clear());

  test('preview and full list keep only real membership transactions',
      () async {
    final service = BackendPaymentService(
      client: MockClient((request) async => http.Response(
            jsonEncode({
              'data': [
                _transaction(3, 'Elite Member', '2026-07-26T12:18:00+07:00'),
                {
                  'id': 4,
                  'type': null,
                  'title': 'Protein Supplement Kit',
                  'amount': 425000,
                  'status': 'paid',
                  'created_at': '2026-07-27T12:18:00+07:00',
                  'membership_plan': null,
                },
                _transaction(2, 'Starter Pack', '2026-07-23T14:32:00+07:00'),
              ],
            }),
            200,
          )),
    );

    final preview = await service.getMemberTransactions(limit: 1);
    final all = await service.getMemberTransactions(limit: null);

    expect(preview.map((item) => item.title), ['Elite Member']);
    expect(all.map((item) => item.title), ['Elite Member', 'Starter Pack']);
    expect(all.any((item) => item.title.contains('Protein')), isFalse);
  });
}

Map<String, dynamic> _transaction(int id, String plan, String createdAt) => {
      'id': id,
      'type': 'membership',
      'title': 'Ignored free-form title',
      'amount': 299000,
      'status': 'success',
      'created_at': createdAt,
      'membership_plan': {
        'id': id,
        'name': plan,
        'slug': plan.toLowerCase().replaceAll(' ', '-'),
      },
    };
