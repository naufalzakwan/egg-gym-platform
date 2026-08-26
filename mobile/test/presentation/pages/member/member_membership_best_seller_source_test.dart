import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('member membership card renders only the best seller badge', () {
    final source = File(
      'lib/presentation/pages/member/member_shell_page.dart',
    ).readAsStringSync();
    final cardStart = source.indexOf('..._displayPlans.map(');
    final membershipCard = source.substring(
      cardStart,
      source.indexOf("'Riwayat Transaksi'", cardStart),
    );

    expect(membershipCard, contains('if (plan.isBestSeller)'));
    expect(membershipCard, contains("'TERLARIS'"));
    expect(membershipCard, isNot(contains('BEST VALUE')));
    expect(membershipCard, isNot(contains('if (plan.badge')));
  });

  test('guest membership card uses the same bestseller flag and label', () {
    final source = File(
      'lib/presentation/pages/guest/guest_membership_tab_v2.dart',
    ).readAsStringSync();

    expect(source, contains('if (plan.isBestSeller)'));
    expect(source, contains("'TERLARIS'"));
    expect(source, isNot(contains("'BEST VALUE'")));
  });
}
