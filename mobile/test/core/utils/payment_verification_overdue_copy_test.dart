import 'package:egg_gym/core/utils/payment_verification_overdue_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('overdue copy escalates PT without blaming member', () {
    expect(PaymentVerificationOverdueCopy.trainerBadge, 'VERIFIKASI TERLAMBAT');
    expect(PaymentVerificationOverdueCopy.trainerMessage,
        contains('periksa bukti pembayaran'));
    expect(PaymentVerificationOverdueCopy.memberMessage,
        contains('Admin telah diberitahu'));
    expect(PaymentVerificationOverdueCopy.memberMessage.toLowerCase(),
        isNot(contains('expired')));
    expect(PaymentVerificationOverdueCopy.memberMessage.toLowerCase(),
        isNot(contains('kedaluwarsa')));
  });
}
