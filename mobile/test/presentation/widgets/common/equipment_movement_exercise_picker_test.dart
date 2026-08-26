import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:egg_gym/presentation/widgets/common/equipment_movement_exercise_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const equipment = EquipmentInfo(
    id: 1,
    name: 'Olympic Power Rack',
    category: 'Strength',
    description: 'Power rack untuk latihan beban.',
    focus: 'Chest',
    movements: [
      GymEquipmentMovement(
        id: 10,
        movementName: 'Barbell Bench Press',
        targetArea: 'Chest',
        sortOrder: 1,
      ),
    ],
  );

  testWidgets('sets and reps can be edited and returned safely',
      (tester) async {
    EquipmentMovementExerciseSelection? selection;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                selection = await pickEquipmentMovementExercise(
                  context,
                  const [equipment],
                );
              },
              child: const Text('Pilih Database'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Pilih Database'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Olympic Power Rack'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Barbell Bench Press'));
    await tester.pumpAndSettle();

    expect(find.text('Atur Sets dan Reps'), findsOneWidget);
    expect(find.text('Chest · Olympic Power Rack'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('exercise-sets-field')),
      '4',
    );
    await tester.enterText(
      find.byKey(const Key('exercise-reps-field')),
      '12',
    );
    await tester.pump();

    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Tambah Latihan'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(selection, isNotNull);
    expect(selection!.equipment.name, 'Olympic Power Rack');
    expect(selection!.movement.movementName, 'Barbell Bench Press');
    expect(selection!.movement.targetArea, 'Chest');
    expect(selection!.sets, 4);
    expect(selection!.reps, 12);
  });

  testWidgets('empty values show validation and allow retry', (tester) async {
    EquipmentMovementExerciseSelection? selection;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                selection = await pickEquipmentMovementExercise(
                  context,
                  const [equipment],
                );
              },
              child: const Text('Pilih Database'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Pilih Database'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Olympic Power Rack'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Barbell Bench Press'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('exercise-sets-field')), '');
    await tester.enterText(find.byKey(const Key('exercise-reps-field')), '');
    await tester.tap(find.text('Tambah Latihan'));
    await tester.pump();

    expect(
      find.text('Sets dan reps wajib berupa angka minimal 1.'),
      findsOneWidget,
    );
    expect(selection, isNull);
    expect(tester.takeException(), isNull);

    await tester.enterText(
      find.byKey(const Key('exercise-sets-field')),
      '1',
    );
    await tester.enterText(
      find.byKey(const Key('exercise-reps-field')),
      '1',
    );
    await tester.tap(find.text('Tambah Latihan'));
    await tester.pumpAndSettle();

    expect(selection?.sets, 1);
    expect(selection?.reps, 1);
    expect(tester.takeException(), isNull);
  });
}
