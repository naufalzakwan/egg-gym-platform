import 'package:egg_gym/app/routes/app_routes.dart';
import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:egg_gym/presentation/pages/details/equipment_detail_page.dart';
import 'package:egg_gym/presentation/pages/guest/guest_home_tab_v2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  tearDown(Get.reset);

  testWidgets('renders real equipment fields and relational movements',
      (tester) async {
    const equipment = EquipmentInfo(
      name: 'Cable Station',
      category: 'Functional',
      description: 'Deskripsi asli dari Web Admin.',
      focus: 'Back dan Chest',
      usageWindow: '10-15 menit',
      bestFor: 'Latihan upper body',
      difficulty: 'Menengah',
      keyBenefits: ['Resistance stabil'],
      usageFlow: ['Atur pin beban'],
      safetyNotes: ['Pastikan pin terkunci'],
      suggestedMovements: [
        'SEATED CABLE ROW',
        'CABLE FLY',
        'STRAIGHT-ARM PULLDOWN',
      ],
      movements: [
        GymEquipmentMovement(
          id: 1,
          movementName: 'Cable Chest Fly',
          targetArea: 'Chest',
          sortOrder: 1,
        ),
        GymEquipmentMovement(
          id: 2,
          movementName: 'Seated Cable Row',
          targetArea: 'Back',
          sortOrder: 2,
        ),
        GymEquipmentMovement(
          id: 3,
          movementName: 'Face Pull',
          targetArea: 'Shoulders',
          sortOrder: 3,
        ),
        GymEquipmentMovement(
          id: 4,
          movementName: 'Lat Pulldown',
          targetArea: 'Back',
          sortOrder: 4,
        ),
      ],
    );

    await _openDetail(tester, equipment);

    expect(find.text('Deskripsi asli dari Web Admin.'), findsOneWidget);
    expect(find.text('Back dan Chest'), findsOneWidget);
    expect(find.text('10-15 menit'), findsOneWidget);

    await _scrollUntilVisible(tester, find.text('Latihan upper body'));
    expect(find.text('Latihan upper body'), findsOneWidget);
    expect(find.text('Menengah'), findsOneWidget);

    await _scrollUntilVisible(tester, find.text('Resistance stabil'));
    expect(find.text('Resistance stabil'), findsOneWidget);

    await _scrollUntilVisible(tester, find.text('Atur pin beban'));
    expect(find.text('Atur pin beban'), findsOneWidget);

    await _scrollUntilVisible(tester, find.text('Pastikan pin terkunci'));
    expect(find.text('Pastikan pin terkunci'), findsOneWidget);

    await _scrollUntilVisible(
      tester,
      find.text('Gerakan yang Bisa Dilakukan'),
    );

    expect(find.text('Gerakan yang Bisa Dilakukan'), findsOneWidget);
    expect(find.text('Cable Chest Fly'), findsOneWidget);
    expect(find.text('Target: Chest'), findsOneWidget);
    expect(find.text('Seated Cable Row'), findsOneWidget);
    expect(find.text('Target: Back'), findsNWidgets(2));
    expect(find.text('Face Pull'), findsOneWidget);
    expect(find.text('Target: Shoulders'), findsOneWidget);
    expect(find.text('Lat Pulldown'), findsOneWidget);
    expect(find.text('Login untuk Lihat Semua Gerakan'), findsNothing);
    expect(find.text('Suggested Movements'), findsNothing);
    expect(find.text('CABLE FLY'), findsNothing);
    expect(find.text('STRAIGHT-ARM PULLDOWN'), findsNothing);
  });

  testWidgets('shows honest movement empty state without legacy suggestions',
      (tester) async {
    const equipment = EquipmentInfo(
      name: 'Cable Station',
      category: '',
      description: '',
      focus: '',
      status: '',
      statusLabel: '',
      suggestedMovements: ['CABLE FLY'],
    );

    await _openDetail(tester, equipment);
    await _scrollUntilVisible(
      tester,
      find.text('Belum ada gerakan untuk alat ini.'),
    );

    expect(find.text('Gerakan yang Bisa Dilakukan'), findsOneWidget);
    expect(find.text('Belum ada gerakan untuk alat ini.'), findsOneWidget);
    expect(find.text('Suggested Movements'), findsNothing);
    expect(find.text('CABLE FLY'), findsNothing);
    expect(find.text('FOCUS'), findsNothing);
    expect(find.text('USAGE'), findsNothing);
    expect(find.text('BEST FOR'), findsNothing);
    expect(find.text('LEVEL'), findsNothing);
    expect(find.text('Login untuk Mulai Latihan'), findsNothing);
  });

  testWidgets('guest shows only first three movements and gated login CTA',
      (tester) async {
    const equipment = EquipmentInfo(
      name: 'Cable Station',
      category: 'Functional',
      description: 'Data alat asli.',
      focus: 'Chest dan Back',
      movements: [
        GymEquipmentMovement(
          id: 1,
          movementName: 'Cable Chest Fly',
          targetArea: 'Chest',
          sortOrder: 1,
        ),
        GymEquipmentMovement(
          id: 2,
          movementName: 'Standing Cable Chest Press',
          targetArea: 'Chest',
          sortOrder: 2,
        ),
        GymEquipmentMovement(
          id: 3,
          movementName: 'Seated Cable Row',
          targetArea: 'Back',
          sortOrder: 3,
        ),
        GymEquipmentMovement(
          id: 4,
          movementName: 'Lat Pulldown',
          targetArea: 'Back',
          sortOrder: 4,
        ),
        GymEquipmentMovement(
          id: 5,
          movementName: 'Face Pull',
          targetArea: 'Shoulders',
          sortOrder: 5,
        ),
      ],
    );

    await _openDetail(tester, equipment, source: 'guest', includeLogin: true);
    await _scrollUntilVisible(
      tester,
      find.text('Login untuk Lihat Semua Gerakan'),
    );

    expect(find.text('Cable Chest Fly'), findsOneWidget);
    expect(find.text('Standing Cable Chest Press'), findsOneWidget);
    expect(find.text('Seated Cable Row'), findsOneWidget);
    expect(find.text('Lat Pulldown'), findsNothing);
    expect(find.text('Face Pull'), findsNothing);
    expect(
      find.text('Masuk sebagai member untuk melihat semua gerakan alat.'),
      findsOneWidget,
    );
    expect(find.text('Login untuk Lihat Semua Gerakan'), findsOneWidget);

    await tester.tap(find.text('Login untuk Lihat Semua Gerakan'));
    await tester.pumpAndSettle();
    expect(find.text('HALAMAN LOGIN'), findsOneWidget);
  });

  testWidgets(
      'guest home equipment card opens read-only detail without extra CTA',
      (tester) async {
    const equipment = EquipmentInfo(
      name: 'Cable Station',
      category: 'Functional',
      description: 'Data alat asli.',
      focus: 'Chest dan Back',
      movements: [
        GymEquipmentMovement(
          id: 1,
          movementName: 'Cable Chest Fly',
          targetArea: 'Chest',
          sortOrder: 1,
        ),
      ],
    );
    const showcase = GuestShowcaseData(
      plans: [],
      trainers: [],
      equipments: [equipment],
      operationHours: [],
    );

    await tester.pumpWidget(
      GetMaterialApp(
        home: GuestHomeTabV2(
          showcase: showcase,
          isLoading: false,
          loadError: null,
          onRetry: _noOpRefresh,
        ),
        getPages: [
          GetPage(
            name: AppRoutes.equipmentDetail,
            page: () => const EquipmentDetailPage(),
          ),
          GetPage(
            name: AppRoutes.login,
            page: () => const Scaffold(body: Text('HALAMAN LOGIN')),
          ),
        ],
      ),
    );

    await _scrollUntilVisible(tester, find.text('Alat Gym Unggulan'));
    await _scrollUntilVisible(tester, find.text('Cable Station'));
    await tester.tap(find.text('Cable Station'));
    await tester.pumpAndSettle();

    expect(find.text('Equipment Detail'), findsOneWidget);
    expect(find.text('Data alat asli.'), findsOneWidget);
    expect(find.text('Chest dan Back'), findsOneWidget);

    await _scrollUntilVisible(
      tester,
      find.text('Gerakan yang Bisa Dilakukan'),
    );
    expect(find.text('Cable Chest Fly'), findsOneWidget);
    expect(find.text('Target: Chest'), findsOneWidget);
    expect(find.text('Login untuk Lihat Semua Gerakan'), findsNothing);
    expect(find.text('Login untuk Mulai Latihan'), findsNothing);
  });
}

Future<void> _noOpRefresh() async {}

Future<void> _openDetail(
  WidgetTester tester,
  EquipmentInfo equipment, {
  String source = 'member',
  bool includeLogin = false,
}) async {
  await tester.pumpWidget(
    GetMaterialApp(
      home: Builder(
        builder: (context) => MaterialButton(
          onPressed: () => Get.toNamed(
            AppRoutes.equipmentDetail,
            arguments: <String, dynamic>{
              'equipment': equipment,
              'source': source,
            },
          ),
          child: const Text('Buka Detail'),
        ),
      ),
      getPages: [
        GetPage(
          name: AppRoutes.equipmentDetail,
          page: () => const EquipmentDetailPage(),
        ),
        if (includeLogin)
          GetPage(
            name: AppRoutes.login,
            page: () => const Scaffold(body: Text('HALAMAN LOGIN')),
          ),
      ],
    ),
  );
  await tester.tap(find.text('Buka Detail'));
  await tester.pumpAndSettle();
}

Future<void> _scrollUntilVisible(
  WidgetTester tester,
  Finder finder,
) async {
  await tester.scrollUntilVisible(
    finder,
    350,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}
