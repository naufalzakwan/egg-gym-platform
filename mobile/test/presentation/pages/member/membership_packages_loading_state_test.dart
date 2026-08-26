import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('initial package fetch renders loading instead of premature checkout',
      () {
    final source = File(
      'lib/presentation/pages/details/membership_packages_page.dart',
    ).readAsStringSync();

    expect(source, contains('bool _plansLoaded = false;'));
    expect(source, contains('if (!_plansLoaded && plans.isEmpty)'));
    expect(source, contains("'Memuat paket membership...'"));
    expect(source, contains('else if (_plansError != null && plans.isEmpty)'));
    expect(source, contains('else if (_plansLoaded && plans.isEmpty)'));
    expect(source, contains("'Belum ada paket membership yang tersedia.'"));
  });

  test('member entry performs one navigation to the packages page', () {
    final source = File(
      'lib/presentation/pages/member/member_shell_page.dart',
    ).readAsStringSync();
    final start = source.indexOf("label: 'Pilih / Perpanjang Paket'");
    final end = source.indexOf('// Judul section Pilihan Paket', start);
    final action = source.substring(start, end);

    expect(
      RegExp('AppRoutes\\.membershipPackages').allMatches(action).length,
      1,
    );
  });
}
