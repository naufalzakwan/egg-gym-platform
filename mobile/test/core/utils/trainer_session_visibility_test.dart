import 'package:egg_gym/core/utils/trainer_session_visibility.dart';
import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const date = '2026-07-27';
  final target = DateTime(2026, 7, 27);

  ScheduleSession session(String status, {DateTime? paymentVerifiedAt}) =>
      ScheduleSession(
        clientName: 'Member',
        timeRange: '10:00 - 11:00',
        location: 'Egg Gym',
        status: status,
        rawStatus: status,
        note: '-',
        sessionDate: date,
        paymentVerifiedAt: paymentVerifiedAt,
        reservations: const [
          BookingSessionReservation(
            sequenceOrder: 1,
            sessionDate: date,
            startTime: '10:00',
            endTime: '11:00',
            status: 'reserved',
          ),
        ],
      );

  test('only payment-ready bookings count as sessions for a date', () {
    for (final status in [
      'pending',
      'waiting_payment',
      'payment_uploaded',
      'payment_rejected',
      'expired',
      'rejected',
      'cancelled',
    ]) {
      expect(
        TrainerSessionVisibility.isActiveForDate(session(status), target),
        isFalse,
        reason: status,
      );
    }

    for (final status in ['payment_verified', 'confirmed', 'completed']) {
      expect(
        TrainerSessionVisibility.isActiveForDate(session(status), target),
        isTrue,
        reason: status,
      );
    }
    expect(
      TrainerSessionVisibility.isActiveForDate(session('rescheduled'), target),
      isFalse,
    );
    expect(
      TrainerSessionVisibility.isActiveForDate(
        session('rescheduled', paymentVerifiedAt: DateTime(2026, 7, 26)),
        target,
      ),
      isTrue,
    );
  });
}
