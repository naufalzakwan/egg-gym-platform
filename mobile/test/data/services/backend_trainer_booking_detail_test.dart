import 'dart:convert';

import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:egg_gym/data/services/backend_trainer_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const baseUrl = 'http://trainer-detail.test';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSessionService.instance.clear();
    await AppSessionService.instance.setSession(
      const AppAuthenticatedSession(
        baseUrl: baseUrl,
        token: 'token',
        role: 'trainer',
        userId: 7,
        name: 'Coach Test',
        email: 'coach@test.dev',
      ),
    );
  });

  tearDown(() => AppSessionService.instance.clear());

  test('getBookingDetail uses show endpoint and maps complete detail data',
      () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.toString(), '$baseUrl/api/v1/trainer/sessions/42');
      expect(request.headers['Authorization'], 'Bearer token');
      return http.Response(jsonEncode(_detailPayload), 200);
    });

    final detail =
        await BackendTrainerService(client: client).getBookingDetail(42);

    expect(detail.backendId, 42);
    expect(detail.bookingNumber, 'BK-2026-0042');
    expect(detail.createdAt, DateTime(2026, 7, 26, 10, 15));
    expect(detail.memberEmail, 'member@test.dev');
    expect(detail.memberPhone, '08123456789');
    expect(detail.memberCode, 'MEM-0042');
    expect(detail.memberAvatarUrl, 'avatars/member.jpg');
    expect(detail.activeMembership?.planName, 'Elite Member');
    expect(detail.activeMembership?.endDate, '2026-12-31');
    expect(detail.reservations, hasLength(2));
    expect(detail.reservations.last.sequenceOrder, 2);
    expect(detail.pricePerSession, 150000);
    expect(detail.totalAmount, 300000);
  });
}

final _detailPayload = <String, dynamic>{
  'data': <String, dynamic>{
    'id': 42,
    'booking_number': 'BK-2026-0042',
    'created_at': '2026-07-26T10:15:00+07:00',
    'session_title': 'Upper Body Strength',
    'session_date': '2026-07-29',
    'start_time': '10:00:00',
    'end_time': '11:00:00',
    'location': 'Egg Gym Sudirman',
    'session_count': 2,
    'status': 'pending',
    'expired_at': '2099-07-27T10:00:00+07:00',
    'member_note': 'Fokus chest dan triceps',
    'price_per_session': 150000,
    'total_amount': 300000,
    'session_reservations': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 1,
        'sequence_order': 1,
        'session_date': '2026-07-29',
        'start_time': '10:00:00',
        'end_time': '11:00:00',
        'status': 'reserved',
      },
      <String, dynamic>{
        'id': 2,
        'sequence_order': 2,
        'session_date': '2026-08-01',
        'start_time': '10:00:00',
        'end_time': '11:00:00',
        'status': 'reserved',
      },
    ],
    'member': <String, dynamic>{
      'id': 12,
      'name': 'Member Test',
      'email': 'member@test.dev',
      'phone': '08123456789',
      'member_code': 'MEM-0042',
      'avatar_url': 'avatars/member.jpg',
      'fitness_goal': 'Build muscle',
    },
    'active_membership': <String, dynamic>{
      'plan_name': 'Elite Member',
      'start_date': '2026-01-01',
      'end_date': '2026-12-31',
      'status': 'active',
      'payment_status': 'paid',
    },
  },
};
