import 'package:egg_gym/core/constants/trainer_specialties.dart';
import 'package:egg_gym/domain/entities/demo_models.dart';

abstract final class TrainerScheduleVisibility {
  static List<TrainerProfile> bookingEligible(
    Iterable<TrainerProfile> trainers,
  ) =>
      trainers
          .where((trainer) => trainer.hasActiveSchedule)
          .toList(growable: false);

  static List<TrainerProfile> filterMemberTrainers(
    Iterable<TrainerProfile> trainers, {
    String query = '',
    String? specialty,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    return trainers.where((trainer) {
      if (!trainer.hasActiveSchedule) return false;

      final specialties = trainer.specialtyLabels
          .map(TrainerSpecialties.displayLabel)
          .toList(growable: false);
      if (specialty != null && !specialties.contains(specialty)) return false;

      final matchesQuery = normalizedQuery.isEmpty ||
          trainer.name.toLowerCase().contains(normalizedQuery) ||
          specialties.join(' ').toLowerCase().contains(normalizedQuery);
      return matchesQuery;
    }).toList(growable: false);
  }
}
