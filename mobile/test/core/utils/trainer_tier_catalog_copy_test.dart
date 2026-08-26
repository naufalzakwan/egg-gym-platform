import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('trainer catalog and active trainer UI contain no hardcoded tier copy',
      () {
    final files = <String>[
      'lib/presentation/pages/guest/guest_trainer_tab_v2.dart',
      'lib/presentation/pages/member/member_shell_page.dart',
      'lib/presentation/pages/trainer/trainer_home_dashboard.dart',
      'lib/presentation/pages/trainer/trainer_shell_page.dart',
    ];
    final forbidden = RegExp(
      r'''['"](?:ELITE TRAINER|CURATED ELITE[^'"]*|PRO TRAINER|TRAINER PRO)['"]''',
      caseSensitive: false,
    );

    for (final path in files) {
      expect(File(path).readAsStringSync(), isNot(matches(forbidden)),
          reason: path);
    }
  });
}
