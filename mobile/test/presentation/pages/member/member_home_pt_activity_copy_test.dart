import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Member Home uses PT activity copy and honest empty state', () {
    final source = File(
      'lib/presentation/pages/member/member_shell_page.dart',
    ).readAsStringSync();

    expect(source, contains("'Aktivitas PT'"));
    expect(source, isNot(contains("'Lihat Semua'")));
    expect(source, contains("'Belum ada aktivitas PT'"));
    expect(source, contains('if (_hasPtActivity)'));
    expect(source, contains('dashboard.nextSession.backendId'));
    expect(
      source,
      contains('dashboard.nextSession.trainerDisplayPhotoPath ??'),
    );
    expect(source, contains('dashboard.nextSession.trainerAvatarUrl'));
    expect(source, contains('InitialAvatar('));
    expect(source, isNot(contains("'Next PT Session'")));
  });

  test('Member Home keeps rejected payment actionable', () {
    final source = File(
      'lib/presentation/pages/member/member_shell_page.dart',
    ).readAsStringSync();

    expect(source, contains("case 'payment_rejected':"));
    expect(source, contains("return 'PEMBAYARAN DITOLAK';"));
    expect(
      source,
      contains(
        'Bukti pembayaran ditolak. Silakan upload ulang bukti transfer.',
      ),
    );
    expect(source, contains("? 'Upload Ulang Bukti'"));
    expect(source, contains('AppRoutes.bookingPayment'));
    expect(source, contains("'bookingId': dashboard.nextSession.backendId"));
  });

  test('Member Program timeline header has no decorative filter action', () {
    final source = File(
      'lib/presentation/pages/member/member_shell_page.dart',
    ).readAsStringSync();
    final timeline = source.substring(
      source.indexOf('// ── SESSION TIMELINE'),
      source.indexOf('Widget body;', source.indexOf('// ── SESSION TIMELINE')),
    );

    expect(timeline, contains("'Session Timeline'"));
    expect(timeline, isNot(contains('Icons.tune_rounded')));
    expect(timeline, isNot(contains('MainAxisAlignment.spaceBetween')));
  });
}
