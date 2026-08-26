import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('membership package mapper ignores description fields completely', () {
    for (final path in [
      'lib/data/services/backend_payment_service.dart',
      'lib/data/services/backend_public_service.dart',
    ]) {
      final source = File(path).readAsStringSync();
      final membershipStart = source.indexOf('MembershipPlan(');
      expect(membershipStart, greaterThanOrEqualTo(0));
      final segment = source.substring(membershipStart, membershipStart + 1200);
      expect(segment, contains("subtitle: ''"));
      expect(segment, isNot(contains("item['description']")));
      expect(segment, isNot(contains("item['subtitle']")));
    }
  });

  test('membership presentation never renders package subtitle', () {
    for (final path in [
      'lib/presentation/pages/details/membership_packages_page.dart',
      'lib/presentation/pages/details/payment_checkout_page.dart',
      'lib/presentation/pages/member/member_shell_page.dart',
      'lib/presentation/pages/guest/guest_membership_tab_v2.dart',
      'lib/presentation/pages/guest/guest_cards_v2.dart',
      'lib/presentation/pages/guest/guest_feature_cards_v2.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('plan.subtitle')));
      expect(source, isNot(contains('selectedPlan.subtitle')));
      expect(source, isNot(contains('_selectedPlan.subtitle')));
    }
  });

  test('legacy narrative copy is absent from production Flutter source', () {
    const copies = [
      'Akses alat gym, locker',
      'basic guidance untuk pemula',
      'Full access, sauna',
      'prioritas private class',
      'Paket tahunan dengan akses premium',
      'harga paling hemat',
    ];
    final roots = [Directory('lib')];
    for (final root in roots) {
      for (final file in root.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final source = file.readAsStringSync();
        for (final copy in copies) {
          expect(source, isNot(contains(copy)), reason: file.path);
        }
      }
    }
  });
}
