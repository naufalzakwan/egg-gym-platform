const Set<String> _validTrainerTiers = <String>{
  'basic',
  'standard',
  'pro',
  'elite',
};

String? normalizeTrainerTier(Object? value) {
  final normalized = value?.toString().trim().toLowerCase();
  return _validTrainerTiers.contains(normalized) ? normalized : null;
}

String? mapTrainerTier({Object? tier, Object? legacyBadge}) {
  final tierValue = tier?.toString().trim();
  final source = tierValue?.isNotEmpty == true ? tier : legacyBadge;
  return normalizeTrainerTier(source);
}

String? trainerTierLabel(Object? tier) {
  return switch (normalizeTrainerTier(tier)) {
    'basic' || 'standard' => 'BASIC',
    'pro' => 'PRO',
    'elite' => 'ELITE',
    _ => null,
  };
}

String trainerTierDisplay(Object? tier) => trainerTierLabel(tier) ?? '-';

String trainerRoleLabel(Object? tier) {
  final label = trainerTierLabel(tier);
  return label == null ? 'TRAINER' : '$label TRAINER';
}
