import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reschedule slot uses Egg Gym Pontianak display location', () {
    final source = File(
      'lib/presentation/pages/details/booking_reschedule_page.dart',
    ).readAsStringSync();

    expect(
      source,
      contains("subtitle: const Text('Egg Gym Pontianak')"),
    );
    expect(source, isNot(contains('subtitle: Text(slot.location)')));
    expect(source, contains('startTime: slot.startTime'));
    expect(source, contains('endTime: slot.endTime'));
    expect(source, contains('avatarPath: session.trainerDisplayPhotoPath ??'));
    expect(source, contains('session.trainerAvatarUrl'));
  });
}
