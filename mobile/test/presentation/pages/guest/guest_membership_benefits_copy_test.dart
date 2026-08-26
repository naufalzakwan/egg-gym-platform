import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('guest membership benefits mention only implemented Egg Gym features',
      () {
    final source = File(
      'lib/presentation/pages/guest/guest_program_tab_v2.dart',
    ).readAsStringSync();

    expect(source, contains('KENAPA MEMBERSHIP?'));
    expect(source, contains('Latihan Lebih Terarah\\ndengan EGG GYM'));
    expect(source, contains('Akses fasilitas gym sesuai paket aktif'));
    expect(source, contains('Booking sesi Personal Trainer'));
    expect(source, contains('Pantau program latihan dan progres fisik'));
    expect(source, contains('PROGRAM TERARAH'));

    expect(source, isNot(contains('Kurikulum latihan bulanan yang terukur')));
    expect(
        source, isNot(contains('Video tutorial teknik angkatan yang benar')));
    expect(source, isNot(contains('Tracker nutrisi & kalori terintegrasi')));
  });
}
