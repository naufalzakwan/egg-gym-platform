import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'professional form uses hints and repeatable certifications without defaults',
      () {
    final source = File(
      'lib/presentation/pages/details/trainer_account_settings_page.dart',
    ).readAsStringSync();

    expect(
        source,
        contains(
            'final List<TextEditingController> _certificationControllers'));
    expect(source, contains("label: const Text('Tambah Sertifikasi')"));
    expect(source, contains("hintText: 'Contoh: NASM CPT'"));
    expect(source, contains(r"'${index + 1}'"));
    expect(source, contains('_certificationControllers.length >= 20'));
    expect(source, contains('maksimal 20 item'));
    expect(source,
        contains('_replaceCertificationControllers(profile.certifications)'));
    expect(source, contains(".where((value) => value.isNotEmpty)"));
    expect(source, isNot(contains('_certificationsController')));
    expect(source, isNot(contains("TextEditingController(text: 'NASM CPT")));
    expect(source, isNot(contains('Tersedia sore hari dan weekend.')));
    expect(
        source, contains('Contoh: Saya membantu member membangun massa otot'));
    expect(source, contains("hint: 'Contoh: 3'"));
    expect(source, isNot(contains('Catatan Ketersediaan')));
    expect(source, isNot(contains('Tersedia Senin-Jumat sore')));
    expect(source, isNot(contains('_availabilityController')));
    expect(source, isNot(contains('availabilityNote:')));
  });
}
