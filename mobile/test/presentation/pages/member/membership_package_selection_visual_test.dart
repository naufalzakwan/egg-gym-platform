import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('package selection card visuals depend only on selected state', () {
    final source = File(
      'lib/presentation/pages/details/membership_packages_page.dart',
    ).readAsStringSync();
    final start = source.indexOf('class _MembershipPackageCard');
    final card = source.substring(start);

    expect(card, contains('final highlighted = selected;'));
    expect(card, isNot(contains('isBestDeal')));
    expect(card, isNot(contains('plan.isHighlighted')));
    expect(card, contains('if (plan.isBestSeller)'));
    expect(card, contains("label: 'TERLARIS'"));
  });

  test('Member and Guest catalog cards stay neutral regardless of highlight',
      () {
    final member = File(
      'lib/presentation/pages/member/member_shell_page.dart',
    ).readAsStringSync();
    final guest = File(
      'lib/presentation/pages/guest/guest_membership_tab_v2.dart',
    ).readAsStringSync();

    expect(member, contains('highlight: false'));
    expect(guest, isNot(contains('plan.isHighlighted')));
    expect(guest, isNot(contains('final highlighted = plan.isHighlighted')));

    for (final path in [
      'lib/presentation/pages/guest/guest_cards_v2.dart',
      'lib/presentation/pages/guest/guest_feature_cards_v2.dart',
    ]) {
      final legacy = File(path).readAsStringSync();
      expect(legacy, isNot(contains('highlight: plan.isHighlighted')));
    }
  });
}
