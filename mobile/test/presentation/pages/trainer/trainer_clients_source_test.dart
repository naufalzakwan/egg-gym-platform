import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('clients render from dedicated client endpoint without pending reuse',
      () {
    final service = File(
      'lib/data/services/backend_trainer_service.dart',
    ).readAsStringSync();
    final shell = File(
      'lib/presentation/pages/trainer/trainer_shell_page.dart',
    ).readAsStringSync();

    expect(service, contains('/api/v1/trainer/clients'));
    expect(shell, contains('widget.backendService.getClients()'));
    expect(shell, contains('final visibleClients = clients.where'));
    expect(
      shell,
      isNot(contains('final visibleClients = activeClients.where')),
    );

    final activeToday = shell.substring(
      shell.indexOf('bool _isClientActiveToday'),
      shell.indexOf('@override', shell.indexOf('bool _isClientActiveToday')),
    );
    expect(activeToday, contains("'payment_verified'"));
    expect(activeToday, isNot(contains("'pending'")));
    expect(activeToday, isNot(contains("'payment_uploaded'")));
    expect(activeToday, isNot(contains("'completed'")));
    expect(activeToday, contains("reservation.status == 'reserved'"));

    expect(shell, contains('!program.isActiveControl'));
    expect(shell, contains('program.progressPercent >= 100'));
    expect(shell, contains("'Belum ada sesi hari ini'"));
    expect(
        shell, isNot(contains("if (session == null) return 'Sesi hari ini';")));
  });
}
