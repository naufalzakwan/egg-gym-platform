import 'package:egg_gym/presentation/pages/details/trainer_profile_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  tearDown(Get.reset);

  testWidgets('invalid arguments show explicit state without fake trainer data',
      (tester) async {
    await tester.pumpWidget(
      const GetMaterialApp(home: TrainerProfileDetailPage()),
    );
    await tester.pump();

    expect(find.byKey(const Key('invalid-trainer-detail')), findsOneWidget);
    expect(find.text('Data trainer tidak valid.'), findsOneWidget);
    expect(find.text('Coach Adrian'), findsNothing);
    expect(find.textContaining('4.9'), findsNothing);
    expect(find.textContaining('320'), findsNothing);
  });
}
