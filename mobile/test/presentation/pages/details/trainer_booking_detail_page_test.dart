import 'dart:async';
import 'dart:convert';

import 'package:egg_gym/core/theme/app_theme.dart';
import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:egg_gym/data/services/backend_trainer_service.dart';
import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:egg_gym/presentation/pages/details/trainer_booking_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const baseUrl = 'http://detail-widget.test';
  const initial = ScheduleSession(
    backendId: 42,
    clientName: 'Initial Member',
    timeRange: '-',
    location: '-',
    status: 'Menunggu',
    note: '-',
    rawStatus: 'pending',
  );

  setUp(() async {
    Get.testMode = true;
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

  testWidgets('loads fresh pending detail and renders action buttons',
      (tester) async {
    final service = BackendTrainerService(
      client: MockClient(
          (request) async => http.Response(jsonEncode(_detailPayload), 200)),
    );

    await tester.pumpWidget(GetMaterialApp(
      theme: AppTheme.dark(),
      home: TrainerBookingDetailPage(
        initialSession: initial,
        backendService: service,
      ),
    ));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('Detail Permintaan Booking'), findsOneWidget);
    expect(find.text('BK-2026-0042'), findsOneWidget);
    expect(find.text('Fresh Member'), findsOneWidget);
    expect(find.text('MENUNGGU KONFIRMASI'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Jadwal yang Diajukan (2 sesi)'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Jadwal yang Diajukan (2 sesi)'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Build strength'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Build strength'), findsOneWidget);
    expect(find.text('12 April 1997'), findsOneWidget);
    expect(find.text('Konfirmasi'), findsOneWidget);
    expect(find.text('Tolak'), findsOneWidget);
    expect(find.text('BookingConfirmationPage'), findsNothing);
  });

  testWidgets('shows honest fetch error and retries', (tester) async {
    var calls = 0;
    final service = BackendTrainerService(
      client: MockClient((request) async {
        calls++;
        if (calls == 1) {
          return http.Response(
              jsonEncode({'message': 'Detail tidak tersedia'}), 500);
        }
        return http.Response(jsonEncode(_detailPayload), 200);
      }),
    );
    await tester.pumpWidget(GetMaterialApp(
      theme: AppTheme.dark(),
      home: TrainerBookingDetailPage(
        initialSession: initial,
        backendService: service,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Detail tidak tersedia'), findsOneWidget);

    await tester.tap(find.byKey(const Key('retry-booking-detail-button')));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Fresh Member'), findsOneWidget);
  });

  testWidgets('verified repeat booking without program shows create action',
      (tester) async {
    final payload = <String, dynamic>{
      'data': <String, dynamic>{
        ...(_detailPayload['data']! as Map<String, dynamic>),
        'status': 'payment_verified',
        'session_count': 3,
        'has_program': false,
        'training_program_id': null,
      },
    };
    final service = BackendTrainerService(
      client: MockClient(
        (request) async => http.Response(jsonEncode(payload), 200),
      ),
    );

    await tester.pumpWidget(GetMaterialApp(
      theme: AppTheme.dark(),
      home: TrainerBookingDetailPage(
        initialSession: initial,
        backendService: service,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('create-program-button')), findsOneWidget);
    expect(find.text('Buat Program Dulu'), findsOneWidget);
    expect(find.text('Konfirmasi'), findsNothing);
  });

  testWidgets('waiting payment booking does not show create program action',
      (tester) async {
    final payload = <String, dynamic>{
      'data': <String, dynamic>{
        ...(_detailPayload['data']! as Map<String, dynamic>),
        'status': 'waiting_payment',
        'has_program': false,
        'training_program_id': null,
      },
    };
    final service = BackendTrainerService(
      client: MockClient(
        (request) async => http.Response(jsonEncode(payload), 200),
      ),
    );

    await tester.pumpWidget(GetMaterialApp(
      theme: AppTheme.dark(),
      home: TrainerBookingDetailPage(
        initialSession: initial,
        backendService: service,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('create-program-button')), findsNothing);
    expect(find.text('Buat Program Dulu'), findsNothing);
    expect(find.text('Konfirmasi'), findsNothing);
  });

  testWidgets('legacy confirmed booking does not show create program action',
      (tester) async {
    final payload = <String, dynamic>{
      'data': <String, dynamic>{
        ...(_detailPayload['data']! as Map<String, dynamic>),
        'status': 'confirmed',
        'has_program': false,
        'training_program_id': null,
      },
    };
    final service = BackendTrainerService(
      client: MockClient(
        (request) async => http.Response(jsonEncode(payload), 200),
      ),
    );

    await tester.pumpWidget(GetMaterialApp(
      theme: AppTheme.dark(),
      home: TrainerBookingDetailPage(
        initialSession: initial,
        backendService: service,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('create-program-button')), findsNothing);
    expect(find.text('Buat Program Dulu'), findsNothing);
    expect(find.text('Konfirmasi'), findsNothing);
  });

  testWidgets('confirm prevents duplicate requests and returns confirmed',
      (tester) async {
    final confirmation = Completer<http.Response>();
    var confirmCalls = 0;
    final service = BackendTrainerService(
      client: MockClient((request) async {
        if (request.method == 'POST') {
          confirmCalls++;
          return confirmation.future;
        }
        return http.Response(jsonEncode(_detailPayload), 200);
      }),
    );
    String? result;
    await tester.pumpWidget(GetMaterialApp(
      theme: AppTheme.dark(),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await Get.to<String>(() => TrainerBookingDetailPage(
                  initialSession: initial,
                  backendService: service,
                ));
          },
          child: const Text('Open'),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final button = find.byKey(const Key('confirm-booking-button'));
    await tester.tap(button);
    await tester.tap(button);
    await tester.pump();
    expect(confirmCalls, 1);

    confirmation.complete(http.Response(jsonEncode(_confirmedPayload), 200));
    await tester.pumpAndSettle();
    expect(result, 'confirmed');
  });
}

final _detailPayload = <String, dynamic>{
  'data': <String, dynamic>{
    'id': 42,
    'booking_number': 'BK-2026-0042',
    'created_at': '2026-07-26T10:15:00+07:00',
    'session_title': 'Strength Session',
    'session_date': '2026-07-29',
    'start_time': '10:00:00',
    'end_time': '11:00:00',
    'location': 'Egg Gym',
    'status': 'pending',
    'session_count': 2,
    'member_note': null,
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
      'name': 'Fresh Member',
      'birth_date': '1997-04-12',
      'fitness_goal': 'Build strength',
    },
    'active_membership': null,
  },
};

final _confirmedPayload = <String, dynamic>{
  'data': <String, dynamic>{
    ...(_detailPayload['data']! as Map<String, dynamic>),
    'status': 'waiting_payment',
  },
};
