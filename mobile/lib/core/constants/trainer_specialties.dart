class TrainerSpecialtyOption {
  const TrainerSpecialtyOption({required this.value, required this.label});

  final String value;
  final String label;
}

abstract final class TrainerSpecialties {
  static const options = <TrainerSpecialtyOption>[
    TrainerSpecialtyOption(value: 'bodybuilding', label: 'Bodybuilding'),
    TrainerSpecialtyOption(value: 'muscle_gain', label: 'Muscle Gain'),
    TrainerSpecialtyOption(value: 'weight_loss', label: 'Weight Loss'),
    TrainerSpecialtyOption(
        value: 'strength_training', label: 'Strength Training'),
    TrainerSpecialtyOption(value: 'powerlifting', label: 'Powerlifting'),
    TrainerSpecialtyOption(
        value: 'functional_training', label: 'Functional Training'),
    TrainerSpecialtyOption(
        value: 'mobility_flexibility', label: 'Mobility & Flexibility'),
    TrainerSpecialtyOption(value: 'yoga', label: 'Yoga'),
    TrainerSpecialtyOption(
        value: 'cardio_endurance', label: 'Cardio & Endurance'),
    TrainerSpecialtyOption(value: 'fat_loss', label: 'Fat Loss'),
    TrainerSpecialtyOption(value: 'general_fitness', label: 'General Fitness'),
    TrainerSpecialtyOption(value: 'rehabilitation', label: 'Rehabilitation'),
    TrainerSpecialtyOption(
        value: 'sports_performance', label: 'Sports Performance'),
    TrainerSpecialtyOption(
        value: 'nutrition_coaching', label: 'Nutrition Coaching'),
  ];

  static const popularLabels = <String>[
    'Bodybuilding',
    'Muscle Gain',
    'Weight Loss',
    'Yoga',
    'Powerlifting',
    'General Fitness',
  ];

  static const _legacyLabels = <String, String>{
    'bodybuilding - nutrition': 'Bodybuilding',
    'yoga - flexibility': 'Yoga',
    'muscle gain specialist': 'Muscle Gain',
  };

  static bool isCanonical(String? value) => options.any(
        (option) => option.label.toLowerCase() == value?.trim().toLowerCase(),
      );

  static String displayLabel(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return '-';
    for (final option in options) {
      if (option.label.toLowerCase() == trimmed.toLowerCase()) {
        return option.label;
      }
    }
    return _legacyLabels[trimmed.toLowerCase()] ?? trimmed;
  }
}
