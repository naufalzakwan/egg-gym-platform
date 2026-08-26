import 'dart:convert';

import 'package:egg_gym/core/theme/app_theme.dart';
import 'package:egg_gym/app/routes/app_routes.dart';
import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:egg_gym/data/services/backend_trainer_service.dart';
import 'package:egg_gym/presentation/controllers/trainer_shell_controller.dart';
import 'package:egg_gym/presentation/pages/details/trainer_booking_detail_page.dart';
import 'package:egg_gym/presentation/pages/trainer/trainer_home_dashboard.dart';
import 'package:egg_gym/presentation/providers/workout_timer_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const baseUrl = 'http://home-pending.test';

  setUp(() async {
    Get.testMode = true;
    Get.put(TrainerShellController());
    SharedPreferences.setMockInitialValues({});
    await AppSessionService.instance.clear();
    await AppSessionService.instance.setSession(
      const AppAuthenticatedSession(
        baseUrl: baseUrl,
        token: 'token',
        role: 'trainer',
        userId: 1,
        name: 'Coach',
        email: 'coach@test.dev',
      ),
    );
  });

  tearDown(() async {
    Get.reset();
    await AppSessionService.instance.clear();
  });

  testWidgets(
      'pending request opens detail without rendering Home session agenda',
      (tester) async {
    var sessionListCalls = 0;
    final service = BackendTrainerService(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/dashboard')) {
          return http.Response(jsonEncode(_dashboardPayload), 200);
        }
        if (request.url.path.endsWith('/sessions')) {
          sessionListCalls++;
          return http.Response(jsonEncode(_sessionsPayload), 200);
        }
        return http.Response(jsonEncode(_detailPayload), 200);
      }),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => TrainerWorkoutTimerProvider(),
        child: GetMaterialApp(
          theme: AppTheme.dark(),
          getPages: [
            GetPage<void>(
              name: AppRoutes.trainerBookingDetail,
              page: () => const TrainerBookingDetailPage(),
            ),
            GetPage<void>(
              name: AppRoutes.trainerSessionDetail,
              page: () => const Scaffold(
                body: Text('Payment Verification Detail Target'),
              ),
            ),
          ],
          home: Scaffold(
            body: TrainerHomeDashboard(
              trainerName: 'Coach',
              tier: 'standard',
              backendService: service,
              onSeeAllSessions: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.byKey(const Key('trainer-home-pending-request')), findsOneWidget);
    expect(find.text('Permintaan Booking'), findsOneWidget);
    expect(find.text('Today\'s Sessions'), findsNothing);
    expect(find.text('Tidak ada sesi hari ini'), findsNothing);
    expect(
        find.text('Agenda backend untuk hari ini masih kosong.'), findsNothing);
    expect(find.text('0'), findsWidgets);
    await tester.scrollUntilVisible(
      find.byKey(const Key('trainer-home-payment-verification-43')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Verifikasi Pembayaran'), findsOneWidget);
    expect(find.text('LIHAT BUKTI'), findsOneWidget);
    expect(find.textContaining('Sisa waktu verifikasi:'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('trainer-home-payment-verification-43')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Payment Verification Detail Target'), findsOneWidget);
    Get.back();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('trainer-home-pending-request')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('trainer-home-pending-request')));
    await tester.pumpAndSettle();
    expect(find.text('Detail Permintaan Booking'), findsOneWidget);
    expect(find.text('Pending Member'), findsWidgets);

    Get.back();
    await tester.pumpAndSettle();
    expect(sessionListCalls, greaterThanOrEqualTo(2));
  });
}

const _dashboardPayload = <String, dynamic>{
  'data': <String, dynamic>{
    'trainer_name': 'Coach',
    'tier': 'standard',
    'active_clients': 0,
    'today_sessions': 0,
    'rating': 0,
    'today_agenda': <dynamic>[],
    'payment_verification_requests': <Map<String, dynamic>>[_paymentData],
    'has_active_schedule': true,
  },
};

const _pendingData = <String, dynamic>{
  'id': 42,
  'booking_number': 'BK-42',
  'created_at': '2026-07-26T10:15:00+07:00',
  'session_title': 'Pending Strength',
  'session_date': '2026-07-27',
  'start_time': '10:00:00',
  'end_time': '11:00:00',
  'location': 'Egg Gym',
  'status': 'pending',
  'member': <String, dynamic>{'id': 12, 'name': 'Pending Member'},
  'active_membership': null,
};

const _sessionsPayload = <String, dynamic>{
  'data': <Map<String, dynamic>>[_pendingData, _paymentData],
};

const _paymentData = <String, dynamic>{
  'id': 43,
  'session_title': 'Payment Strength',
  'session_date': '2026-07-27',
  'start_time': '12:00:00',
  'end_time': '13:00:00',
  'location': 'Egg Gym',
  'status': 'payment_uploaded',
  'expired_at': '2099-07-27T13:00:00+07:00',
  'member': <String, dynamic>{'id': 13, 'name': 'Payment Member'},
};

const _detailPayload = <String, dynamic>{'data': _pendingData};
