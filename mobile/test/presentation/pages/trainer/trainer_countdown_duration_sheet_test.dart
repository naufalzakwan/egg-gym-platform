import 'package:egg_gym/presentation/pages/trainer/trainer_countdown_duration_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> openSheet(
    WidgetTester tester, {
    required ValueChanged<int?> onResult,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final result = await showModalBottomSheet<int>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const TrainerCountdownDurationSheet(
                    presets: [15, 30, 45],
                    selectedMinutes: 45,
                  ),
                );
                onResult(result);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atur Sendiri'));
    await tester.pumpAndSettle();
  }

  testWidgets('custom 10 returns safely after sheet closes', (tester) async {
    int? result;
    await openSheet(tester, onResult: (value) => result = value);

    await tester.enterText(
      find.byKey(const ValueKey('custom-duration-input')),
      '10',
    );
    await tester.tap(find.byKey(const ValueKey('use-custom-duration')));
    await tester.pumpAndSettle();

    expect(result, 10);
    expect(find.text('Durasi Countdown'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom duration rejects values outside 1 to 120',
      (tester) async {
    int? result;
    await openSheet(tester, onResult: (value) => result = value);
    final input = find.byKey(const ValueKey('custom-duration-input'));
    final submit = find.byKey(const ValueKey('use-custom-duration'));

    await tester.enterText(input, '0');
    await tester.tap(submit);
    await tester.pump();
    expect(
        find.text('Durasi harus antara 1 sampai 120 menit.'), findsOneWidget);

    await tester.enterText(input, '121');
    await tester.tap(submit);
    await tester.pump();
    expect(
        find.text('Durasi harus antara 1 sampai 120 menit.'), findsOneWidget);
    expect(result, isNull);
    expect(find.text('Durasi Countdown'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
