import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Payment Checkout UI contains no sandbox or environment copy', () {
    final source = File(
      'lib/presentation/pages/details/payment_checkout_page.dart',
    ).readAsStringSync();
    for (final copy in [
      'Checkout membership sekarang memakai sandbox',
      'Mode preview tetap bisa melihat paket',
      'Pastikan backend Laravel aktif',
    ]) {
      expect(source, isNot(contains(copy)));
    }
    expect(
      source,
      contains("const DetailScreenHeader(title: 'Payment Checkout')"),
    );
    expect(source, contains("const StatusChip(label: '1. Paket Dipilih')"));
  });
}
