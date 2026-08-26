import 'package:egg_gym/data/services/backend_trainer_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('program header duration sums reservation time ranges', () {
    final program = TrainerProgramDetailData(
      id: 1,
      title: 'Untuk Bulking',
      status: 'active',
      totalSessions: 2,
      totalDurationMinutes: 145,
      sessions: [
        _session(1, '12:30:00', '13:30:00', plannedMinutes: 75),
        _session(2, '12:00:00', '13:00:00', plannedMinutes: 70),
      ],
    );

    expect(program.totalDurationMinutes, 145);
    expect(program.totalReservationDurationMinutes, 120);
  });

  test('missing or invalid reservation times do not use planned duration', () {
    final program = TrainerProgramDetailData(
      id: 1,
      title: 'Legacy Program',
      status: 'active',
      totalSessions: 3,
      totalDurationMinutes: 180,
      sessions: [
        _session(1, null, null, plannedMinutes: 60),
        _session(2, '13:30:00', '12:30:00', plannedMinutes: 60),
        _session(3, 'invalid', '14:00:00', plannedMinutes: 60),
      ],
    );

    expect(program.totalReservationDurationMinutes, 0);
  });
}

TrainerProgramSessionDetailData _session(
  int sequence,
  String? start,
  String? end, {
  required int plannedMinutes,
}) {
  return TrainerProgramSessionDetailData(
    id: sequence,
    sequenceOrder: sequence,
    title: 'Sesi $sequence',
    durationMinutes: plannedMinutes,
    status: sequence == 1 ? 'active' : 'locked',
    exercises: const [],
    reservationStartTime: start,
    reservationEndTime: end,
  );
}
