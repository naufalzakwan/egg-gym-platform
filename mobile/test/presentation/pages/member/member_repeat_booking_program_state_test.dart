import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'member program tab distinguishes a verified booking waiting for program',
      () {
    final shell = File(
      'lib/presentation/pages/member/member_shell_page.dart',
    ).readAsStringSync();
    final service = File(
      'lib/data/services/backend_member_service.dart',
    ).readAsStringSync();

    expect(shell, contains('_waitingForTrainerProgram'));
    expect(shell, contains("'Menunggu program dari PT'"));
    expect(
      shell,
      contains(
        'Pembayaran sesi sudah diverifikasi. Personal Trainer sedang menyiapkan program untuk booking ini.',
      ),
    );
    expect(service, contains("data['session_count']"));
    expect(service, contains("data['session_reservations']"));
  });
}
