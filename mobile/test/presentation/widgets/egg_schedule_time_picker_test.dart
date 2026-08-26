import 'package:egg_gym/presentation/widgets/common/egg_schedule_time_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> openPicker(
    WidgetTester tester, {
    required ValueChanged<String?> onResult,
    String initialValue = '12:00',
    int minMinutes = 0,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async => onResult(
                await showEggScheduleTimePicker(
                  context: context,
                  title: 'Pilih Waktu',
                  initialValue: initialValue,
                  minMinutes: minMinutes,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('cancel returns null without confirming convenience value',
      (tester) async {
    String? result = 'unchanged';
    await openPicker(
      tester,
      initialValue: '12:45',
      onResult: (value) => result = value,
    );

    await tester.tap(find.byKey(const ValueKey('cancel-schedule-time')));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('confirm returns locale-independent HH:mm', (tester) async {
    String? result;
    await openPicker(tester, onResult: (value) => result = value);

    await tester.tap(find.byKey(const ValueKey('confirm-schedule-time')));
    await tester.pumpAndSettle();

    expect(result, '12:00');
  });

  testWidgets('minute control offers only 00 and 30', (tester) async {
    await openPicker(tester, onResult: (_) {});

    await tester.tap(find.byKey(const ValueKey('schedule-minute')));
    await tester.pumpAndSettle();

    expect(find.text('00'), findsWidgets);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('45'), findsNothing);
  });

  testWidgets('minimum end excludes values before start plus 30 minutes',
      (tester) async {
    String? result;
    await openPicker(
      tester,
      initialValue: '12:00',
      minMinutes: 12 * 60 + 30,
      onResult: (value) => result = value,
    );

    await tester.tap(find.byKey(const ValueKey('confirm-schedule-time')));
    await tester.pumpAndSettle();

    expect(result, '12:30');
  });
}
