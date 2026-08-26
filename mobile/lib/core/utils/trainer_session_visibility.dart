import 'package:egg_gym/domain/entities/demo_models.dart';

abstract final class TrainerSessionVisibility {
  static const readyStatuses = <String>{
    'payment_verified',
    'confirmed',
    'completed',
  };

  static DateTime get jakartaToday {
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    return DateTime(now.year, now.month, now.day);
  }

  static String rawStatus(ScheduleSession session) {
    final raw = session.rawStatus;
    if (raw != null && raw.isNotEmpty) return raw;
    return switch (session.status) {
      'Menunggu' => 'pending',
      'Menunggu Pembayaran' => 'waiting_payment',
      'Bukti Pembayaran Ditolak' => 'payment_rejected',
      'Menunggu Verifikasi' => 'payment_uploaded',
      'Terverifikasi' => 'payment_verified',
      'Terkonfirmasi' => 'confirmed',
      'Dijadwalkan Ulang' => 'rescheduled',
      _ => 'confirmed',
    };
  }

  static bool sameDay(DateTime? date, DateTime target) =>
      date != null &&
      date.year == target.year &&
      date.month == target.month &&
      date.day == target.day;

  static bool isActiveForDate(ScheduleSession session, DateTime date) {
    final status = rawStatus(session);
    if (!readyStatuses.contains(status) &&
        !(status == 'rescheduled' && session.paymentVerifiedAt != null)) {
      return false;
    }
    if (session.isExpired || session.programCompleted) return false;
    if (session.reservations.isNotEmpty) {
      return session.reservations.any(
        (reservation) =>
            sameDay(DateTime.tryParse(reservation.sessionDate), date) &&
            const {'reserved', 'completed'}
                .contains(reservation.status.toLowerCase()),
      );
    }
    return sameDay(DateTime.tryParse(session.sessionDate ?? ''), date);
  }

  static String timeForDate(ScheduleSession session, DateTime date) {
    for (final reservation in session.reservations) {
      if (sameDay(DateTime.tryParse(reservation.sessionDate), date)) {
        return '${reservation.startTime} - ${reservation.endTime}';
      }
    }
    return session.timeRange;
  }
}
