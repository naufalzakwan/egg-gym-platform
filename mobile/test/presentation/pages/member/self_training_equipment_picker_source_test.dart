import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('self training reuses equipment movement picker and persists metadata',
      () {
    final builder = File(
      'lib/presentation/pages/details/self_training_builder_page.dart',
    ).readAsStringSync();
    final service = File(
      'lib/data/services/backend_self_training_service.dart',
    ).readAsStringSync();
    final picker = File(
      'lib/presentation/widgets/common/equipment_movement_exercise_picker.dart',
    ).readAsStringSync();
    final trainer = File(
      'lib/presentation/pages/details/trainer_edit_training_session_page.dart',
    ).readAsStringSync();
    final tile = File(
      'lib/presentation/widgets/common/self_training_exercise_tile.dart',
    ).readAsStringSync();

    expect(builder, contains("label: 'Pilih Database'"));
    expect(builder, contains("label: 'Tambah Manual'"));
    expect(builder, contains('BackendPublicService().getEquipments()'));
    expect(builder,
        contains('pickEquipmentMovementExercise(context, equipments)'));
    expect(builder, contains('equipmentName: selection.equipment.name'));
    expect(builder, contains('equipmentMovementId: selection.movement.id'));
    expect(builder, contains('if (exercise.equipmentName != null)'));
    expect(builder,
        contains('name.isEmpty || target.isEmpty || sets <= 0 || reps <= 0'));
    expect(
        service, contains("'gym_equipment_movement_id': equipmentMovementId"));
    expect(
        service, contains("equipmentName: _asString(data['equipment_name'])"));
    expect(tile, contains('if (exercise.equipmentName != null)'));

    expect(trainer,
        contains('pickEquipmentMovementExercise(context, equipments)'));
    expect(picker, contains('Pilih Alat Gym'));
    expect(picker, contains('Alat ini belum memiliki daftar gerakan'));
    expect(picker, contains('Atur Sets dan Reps'));
    expect(builder, isNot(contains('_showDatabasePicker')));
    expect(builder, isNot(contains('PILIH DARI DATABASE')));
  });
}
