import 'dart:io';

import 'package:egg_gym/core/utils/physical_progress_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Profile card branches between first form and existing overview', () {
    final source = File(
      'lib/presentation/pages/member/member_shell_page.dart',
    ).readAsStringSync();
    final start = source.indexOf("title: 'Progress Fisik'");
    final end = source.indexOf("title: 'Peralatan Gym'", start);
    final cardSource = source.substring(start, end);

    expect(
      cardSource,
      contains('AppRoutes.memberPhysicalProgressForm'),
    );
    expect(cardSource, contains("'openOverviewAfterSave': true"));
    expect(cardSource, contains('AppRoutes.memberPhysicalProgress)'));
    expect(cardSource, contains('onPhysicalProgressUpdated?.call()'));
  });

  test('first checkpoint origin opens overview after save', () {
    expect(
      shouldOpenPhysicalProgressOverviewAfterSave(
        const {'openOverviewAfterSave': true},
      ),
      isTrue,
    );
  });

  test('overview origin keeps pop and refresh behavior', () {
    expect(shouldOpenPhysicalProgressOverviewAfterSave(null), isFalse);
    expect(shouldOpenPhysicalProgressOverviewAfterSave(const {}), isFalse);
  });
}
