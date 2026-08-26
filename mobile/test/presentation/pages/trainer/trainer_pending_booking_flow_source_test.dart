import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Schedule pending card has independent info and detail tap wiring', () {
    final source = File(
      'lib/presentation/pages/trainer/trainer_shell_page.dart',
    ).readAsStringSync();

    expect(source, contains("ValueKey('pending-info-\${session.backendId}')"));
    final pendingActions = source.substring(
      source.indexOf("if (status == 'pending')"),
      source.indexOf('if (requestCard)'),
    );
    expect(pendingActions, isNot(contains("label: 'Lihat Detail'")));
    expect(pendingActions, contains("label: 'Konfirmasi'"));
    expect(pendingActions, contains("label: 'Tolak'"));
    expect(source, contains("result == 'confirmed'"));
    expect(source, contains('widget.onBookingConfirmed?.call()'));
    expect(
      source,
      contains(
        'Booking berhasil dikonfirmasi. Menunggu bukti pembayaran dari member.',
      ),
    );
    expect(
      source,
      isNot(
        contains(
          'Silakan buat program latihan di menu Program.',
        ),
      ),
    );
  });

  test('Schedule gates payment and program actions by booking status', () {
    final source = File(
      'lib/presentation/pages/trainer/trainer_shell_page.dart',
    ).readAsStringSync();

    expect(
      source,
      contains("if (const {'waiting_payment', 'confirmed'}.contains(status))"),
    );
    expect(source, contains("if (status == 'payment_uploaded')"));
    expect(
      source,
      contains("if (status == 'payment_verified' && !session.hasProgram)"),
    );
    expect(
      source,
      isNot(
        contains(
          "if (const {'payment_verified', 'confirmed'}.contains(status) &&\n        !session.hasProgram)",
        ),
      ),
    );
  });

  test('Schedule filter badges count only trainer-actionable bookings', () {
    final source = File(
      'lib/presentation/pages/trainer/trainer_shell_page.dart',
    ).readAsStringSync();

    expect(source, contains("if (status == 'payment_uploaded') return true;"));
    expect(
      source,
      contains("if (status == 'payment_verified' && !session.hasProgram)"),
    );
    expect(source, contains('request.isIncoming'));
    expect(source, contains('(request.canAccept || request.canReject)'));
    expect(
      source,
      contains("final pendingActionCount = _requestActionCount('Menunggu'"),
    );
    expect(
      source,
      contains(
        "final confirmedActionCount = _requestActionCount('Dikonfirmasi'",
      ),
    );
    expect(source, contains("'Menunggu' => pendingActionCount"));
    expect(source, contains("'Dikonfirmasi' => confirmedActionCount"));
    expect(source, contains("_ => 0"));
    expect(source, contains("Colors.red.shade600"));
    expect(source, contains("count > 99 ? '99+' : '\$count'"));
    expect(
      source,
      contains("ValueKey('schedule-filter-badge-\$label')"),
    );
  });

  test(
      'trainer detail route uses service-backed page without confirmation page',
      () {
    final routes = File('lib/app/routes/app_pages.dart').readAsStringSync();
    final detail = File(
      'lib/presentation/pages/details/trainer_booking_detail_page.dart',
    ).readAsStringSync();
    final home = File(
      'lib/presentation/pages/trainer/trainer_home_dashboard.dart',
    ).readAsStringSync();

    expect(routes, contains('name: AppRoutes.trainerBookingDetail'));
    expect(routes, contains('TrainerBookingDetailPage()'));
    expect(detail, contains('getBookingDetail(backendId)'));
    expect(detail, isNot(contains('BookingConfirmationPage')));
    expect(home, contains("AppRoutes.trainerBookingDetail"));
    expect(home, contains("Key('trainer-home-pending-request')"));
    expect(home, isNot(contains('BookingConfirmationPage')));
  });
}
