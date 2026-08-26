import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('membership package flow contains no demo or sandbox copy', () {
    final source = File(
      'lib/presentation/pages/details/membership_packages_page.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('Ringkasan Demo')));
    expect(source, isNot(contains('Pakasir sandbox')));
    expect(source, isNot(contains('PT Access')));
    expect(source, isNot(contains('DemoRepository')));
    expect(source, contains("'Lanjut ke Pembayaran'"));
    expect(source, contains('membershipPrimaryBenefit'));
  });
}
