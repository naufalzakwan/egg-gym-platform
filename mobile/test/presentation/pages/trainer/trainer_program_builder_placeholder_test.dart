import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('create mode keeps program fields empty and examples as hints', () {
    final builder = File(
      'lib/presentation/pages/details/trainer_program_builder_page.dart',
    ).readAsStringSync();

    expect(
      builder,
      contains('_programNameController = TextEditingController();'),
    );
    expect(
      builder,
      contains('_descriptionController = TextEditingController();'),
    );
    expect(builder, isNot(contains("text: 'Hypertrophy Phase A'")));
    expect(
      builder,
      contains("hintText: 'Contoh: Hypertrophy Phase A'"),
    );
    expect(
      builder,
      contains(
        "'Contoh: Program 4 minggu untuk meningkatkan massa otot...'",
      ),
    );
  });

  test('new booking does not preload a previous member program', () {
    final builder = File(
      'lib/presentation/pages/details/trainer_program_builder_page.dart',
    ).readAsStringSync();

    expect(builder, isNot(contains('_loadExistingProgramSessions')));
    expect(builder, isNot(contains('p.memberProfileId == memberProfileId')));
    expect(builder, contains('c.backendId == _preSelectedMemberProfileId'));
  });

  test('create mode starts with no sessions or hidden session template', () {
    final builder = File(
      'lib/presentation/pages/details/trainer_program_builder_page.dart',
    ).readAsStringSync();
    final editor = File(
      'lib/presentation/pages/details/trainer_edit_training_session_page.dart',
    ).readAsStringSync();

    expect(builder, contains('_draftSessions = [];'));
    expect(builder, contains("title: ''"));
    expect(builder, contains('exercises: []'));
    expect(builder, contains('Belum ada sesi latihan'));
    expect(
      builder,
      contains('Tambahkan minimal 1 sesi latihan terlebih dahulu.'),
    );
    expect(editor, contains("title: ''"));
    expect(editor, contains('exercises: []'));

    for (final template in [
      'Chest & Triceps Focus',
      'Back Width Builder',
      'Push strength and pump finisher',
      'Lat activation and rowing quality',
      'Incline Barbell Press',
      'Cable Fly',
      'Barbell Back Squat',
    ]) {
      expect(builder, isNot(contains(template)), reason: template);
      expect(editor, isNot(contains(template)), reason: template);
    }
  });
}
