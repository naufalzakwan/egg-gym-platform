import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:egg_gym/presentation/pages/guest/guest_feature_cards_v2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TrainerProfile _trainer(String? tier) => TrainerProfile(
      name: 'Tier Test Trainer',
      specialty: 'Strength',
      bio: 'Bio',
      rating: 0,
      reviewsCount: 0,
      tier: tier,
    );

void main() {
  for (final entry in <String?, String?>{
    'standard': 'BASIC',
    'basic': 'BASIC',
    'pro': 'PRO',
    'elite': 'ELITE',
    null: null,
    'unknown': null,
  }.entries) {
    testWidgets('guest trainer card displays ${entry.key}', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 240,
              height: 360,
              child: TrainerMiniCard(trainer: _trainer(entry.key)),
            ),
          ),
        ),
      );

      if (entry.value == null) {
        expect(find.text('BASIC'), findsNothing);
        expect(find.text('PRO'), findsNothing);
        expect(find.text('ELITE'), findsNothing);
      } else {
        expect(find.text(entry.value!), findsOneWidget);
      }
    });
  }
}
