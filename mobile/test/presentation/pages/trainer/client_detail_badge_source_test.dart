import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('client detail profile card contains no internal backend badge', () {
    final source = File(
      'lib/presentation/pages/details/client_detail_page.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('TRAINER BACKEND')));
    expect(source, isNot(contains('ACTIVE CLIENT')));
    expect(source, isNot(contains('SYNCING')));
    expect(source, contains("title: 'Client Detail'"));
    expect(source, contains('histori sesi bersama trainer'));
    expect(source, contains("'Client Snapshot'"));
  });
}
