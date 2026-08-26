import 'package:egg_gym/domain/entities/trainer_schedule_date.dart';
import 'package:egg_gym/presentation/pages/trainer/trainer_schedule_dates_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TrainerScheduleDate dateWithShift(String startTime, String endTime) =>
      TrainerScheduleDate(
        date: '2026-07-25',
        dayOfWeek: 6,
        dayName: 'Sabtu',
        state: TrainerScheduleDateState.open,
        source: TrainerScheduleDateSource.manual,
        lockVersion: 1,
        shifts: [
          TrainerScheduleDateShift(
            startTime: startTime,
            endTime: endTime,
          ),
        ],
        templateShifts: const [],
      );

  Future<void> pumpSheet(
    WidgetTester tester, {
    required TrainerScheduleDate date,
    required Future<bool> Function(List<TrainerScheduleDateShift>) onSave,
  }) =>
      tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: TrainerScheduleDateOverrideSheet(
              date: date,
              onSave: onSave,
            ),
          ),
        ),
      );

  testWidgets(
      'failed concrete-date override save keeps sheet and selected draft',
      (tester) async {
    final attempts = <List<TrainerScheduleDateShift>>[];
    await pumpSheet(
      tester,
      date: dateWithShift('09:00', '11:00'),
      onSave: (shifts) async {
        attempts.add(shifts);
        return false;
      },
    );

    await tester.tap(find.text('09:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('schedule-hour')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-schedule-time')));
    await tester.pumpAndSettle();

    expect(find.text('10:00'), findsOneWidget);

    await tester.tap(find.text('Simpan Override'));
    await tester.pumpAndSettle();

    expect(find.text('Ubah Shift'), findsOneWidget);
    expect(find.text('Jadwal diperbarui'), findsNothing);
    expect(
      find.text('Gagal menyimpan. Perubahan Anda tetap tersedia.'),
      findsOneWidget,
    );
    expect(find.text('10:00'), findsOneWidget);
    expect(attempts, hasLength(1));
    expect(attempts.single.single.startTime, '10:00');

    await tester.tap(find.text('Simpan Override'));
    await tester.pumpAndSettle();

    expect(attempts, hasLength(2));
    expect(attempts.last.single.startTime, '10:00');
  });

  testWidgets('legacy off-grid value stays displayed until picker is confirmed',
      (tester) async {
    await pumpSheet(
      tester,
      date: dateWithShift('09:45', '11:00'),
      onSave: (_) async => true,
    );

    expect(find.text('09:45'), findsOneWidget);
    await tester.tap(find.text('09:45'));
    await tester.pumpAndSettle();

    expect(find.text('09:45'), findsOneWidget);
    expect(find.text('09:30'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('cancel-schedule-time')));
    await tester.pumpAndSettle();

    expect(find.text('09:45'), findsOneWidget);
    expect(find.text('09:30'), findsNothing);

    await tester.tap(find.text('09:45'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-schedule-time')));
    await tester.pumpAndSettle();

    expect(find.text('09:45'), findsNothing);
    expect(find.text('09:30'), findsOneWidget);
  });
}
