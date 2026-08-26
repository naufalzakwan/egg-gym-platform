import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('membership-required dialog uses a strong modal barrier', () {
    final source = File(
      'lib/presentation/pages/details/member_booking_form_page.dart',
    ).readAsStringSync();

    expect(
        source, contains('barrierColor: Colors.black.withValues(alpha: 0.94)'));
    expect(source, contains('useRootNavigator: true'));
    expect(source, contains('elevation: 24'));
    expect(source, contains('barrierDismissible: false'));
    expect(source, contains('body: SizedBox.expand()'));
  });

  test('back only closes the dialog and package action navigates afterward',
      () {
    final source = File(
      'lib/presentation/pages/details/member_booking_form_page.dart',
    ).readAsStringSync();
    final start = source.indexOf('Future<void> _showMembershipRequiredDialog');
    final end = source.indexOf('void didChangeAppLifecycleState', start);
    final dialog = source.substring(start, end);

    expect(dialog, contains('_MembershipRequiredAction.back'));
    expect(dialog, contains('_MembershipRequiredAction.viewPackages'));
    expect(
        dialog, contains('action == _MembershipRequiredAction.viewPackages'));
    expect(dialog, contains('AppRoutes.membershipPackages'));
    expect(dialog, contains('Get.back();'));
  });

  test('there is only one Membership Required UI implementation', () {
    final source = File(
      'lib/presentation/pages/details/member_booking_form_page.dart',
    ).readAsStringSync();

    expect(RegExp("'Membership Diperlukan'").allMatches(source).length, 1);
    expect(RegExp("'Lihat Paket Membership'").allMatches(source).length, 1);
    expect(source, isNot(contains('size: 64, color: AppColors.accent')));
  });
}
