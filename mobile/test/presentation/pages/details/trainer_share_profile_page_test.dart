import 'package:egg_gym/presentation/pages/details/trainer_share_profile_page.dart';
import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  tearDown(Get.reset);

  testWidgets('invalid share arguments show an explicit error', (tester) async {
    Get.testMode = true;
    await tester.pumpWidget(
      const GetMaterialApp(home: TrainerShareProfilePage()),
    );

    expect(find.byKey(const Key('invalid-trainer-share')), findsOneWidget);
    expect(find.textContaining('tidak valid'), findsOneWidget);
  });

  testWidgets('share preview uses the real trainer tier', (tester) async {
    const trainer = TrainerProfile(
      name: 'Real Trainer',
      specialty: 'Strength',
      bio: 'Real profile',
      rating: 0,
      reviewsCount: 0,
      tier: 'standard',
    );
    await tester.pumpWidget(
      GetMaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Get.to(
              () => const TrainerShareProfilePage(),
              arguments: trainer,
            ),
            child: const Text('Open share'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open share'));
    await tester.pumpAndSettle();

    expect(find.text('Real Trainer'), findsOneWidget);
    expect(find.text('BASIC'), findsOneWidget);
    expect(find.textContaining('Coach Adrian'), findsNothing);
  });
}
