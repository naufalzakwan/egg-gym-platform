import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('database picker uses backend equipment movements without dummy list',
      () {
    final editor = File(
      'lib/presentation/pages/details/trainer_edit_training_session_page.dart',
    ).readAsStringSync();
    final builder = File(
      'lib/presentation/pages/details/trainer_program_builder_page.dart',
    ).readAsStringSync();
    final service = File(
      'lib/data/services/backend_program_service.dart',
    ).readAsStringSync();
    final trainerService = File(
      'lib/data/services/backend_trainer_service.dart',
    ).readAsStringSync();
    final progress = File(
      'lib/presentation/pages/details/trainer_progress_control_page.dart',
    ).readAsStringSync();
    final picker = File(
      'lib/presentation/widgets/common/equipment_movement_exercise_picker.dart',
    ).readAsStringSync();

    expect(editor, contains('BackendPublicService().getEquipments()'));
    expect(editor, contains('pickEquipmentMovementExercise(context, equipments)'));
    expect(picker, contains('Pilih Alat Gym'));
    expect(picker, contains('Pilih gerakan'));
    expect(picker, contains('Atur Sets dan Reps'));
    expect(editor, contains('equipmentMovementId: selection.movement.id'));
    expect(editor, contains('equipmentName: selection.equipment.name'));
    expect(
      picker,
      contains("Key('equipment-movement-picker-header')"),
    );
    expect(
      picker,
      contains("Key('equipment-movement-picker-scroll-viewport')"),
    );
    expect(picker, contains("Key('movement-picker-list')"));
    expect(picker, contains('child: ClipRect('));
    expect(
      picker,
      contains('padding: const EdgeInsets.only(top: 12, bottom: 24)'),
    );
    expect(picker, contains('clipBehavior: Clip.hardEdge'));
    expect(editor, isNot(contains('_databaseSuggestions')));
    expect(editor, isNot(contains('Weighted Pull-Ups')));
    expect(editor, isNot(contains('Incline Dumbbell Press')));

    expect(builder, contains('equipmentId: exerciseEntry.value.equipmentId'));
    expect(builder, contains('exerciseEntry.value.equipmentMovementId'));
    expect(
        service, contains("'gym_equipment_movement_id': equipmentMovementId"));
    expect(service, contains("'equipment_id': equipmentId"));
    expect(
      trainerService,
      contains("equipmentName: _asNullableString(data['equipment_name'])"),
    );
    expect(
      trainerService,
      contains("equipmentName: _asNullableString(item['equipment_name'])"),
    );
    expect(progress, contains('if (exercise.equipmentName != null)'));
    expect(progress, contains('exercise.equipmentName!'));
    expect(progress, isNot(contains("'Gym Equipment'")));
    expect(progress, isNot(contains("'Tanpa alat'")));
  });
}
