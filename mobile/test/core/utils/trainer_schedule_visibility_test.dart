import 'package:egg_gym/core/utils/trainer_schedule_visibility.dart';
import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TrainerProfile trainer({
    required String name,
    required bool hasActiveSchedule,
    bool isAvailable = true,
    String specialty = 'Strength & Conditioning',
  }) {
    return TrainerProfile(
      name: name,
      specialty: specialty,
      bio: '-',
      rating: 0,
      reviewsCount: 0,
      hasActiveSchedule: hasActiveSchedule,
      isAvailable: isAvailable,
    );
  }

  test('member eligibility uses schedule independently from quota', () {
    final quotaFullWithSchedule = trainer(
      name: 'Scheduled Full',
      hasActiveSchedule: true,
      isAvailable: false,
    );
    final quotaOpenWithoutSchedule = trainer(
      name: 'Unscheduled Open',
      hasActiveSchedule: false,
      isAvailable: true,
    );

    expect(
      TrainerScheduleVisibility.bookingEligible([
        quotaFullWithSchedule,
        quotaOpenWithoutSchedule,
      ]),
      [quotaFullWithSchedule],
    );
  });

  test('search and specialty are applied after schedule eligibility', () {
    final strength = trainer(name: 'Ari', hasActiveSchedule: true);
    final yoga = trainer(
      name: 'Bela',
      hasActiveSchedule: true,
      specialty: 'Yoga',
    );
    final hidden = trainer(
      name: 'Ari Hidden',
      hasActiveSchedule: false,
    );

    expect(
      TrainerScheduleVisibility.filterMemberTrainers(
        [strength, yoga, hidden],
        query: 'ari',
        specialty: 'Strength & Conditioning',
      ),
      [strength],
    );
  });
}
