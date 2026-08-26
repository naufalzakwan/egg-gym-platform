import 'package:egg_gym/core/utils/trainer_tier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes only supported trainer tiers', () {
    expect(normalizeTrainerTier('standard'), 'standard');
    expect(normalizeTrainerTier(' BASIC '), 'basic');
    expect(normalizeTrainerTier('Pro'), 'pro');
    expect(normalizeTrainerTier('ELITE'), 'elite');
    expect(normalizeTrainerTier(null), isNull);
    expect(normalizeTrainerTier('master'), isNull);
  });

  test('canonical labels collapse standard and basic to BASIC', () {
    expect(trainerTierLabel('standard'), 'BASIC');
    expect(trainerTierLabel('basic'), 'BASIC');
    expect(trainerTierLabel('pro'), 'PRO');
    expect(trainerTierLabel('elite'), 'ELITE');
    expect(trainerTierLabel(null), isNull);
    expect(trainerTierLabel('unknown'), isNull);
    expect(trainerTierDisplay(null), '-');
    expect(trainerTierDisplay('unknown'), '-');
    expect(trainerRoleLabel(null), 'TRAINER');
  });

  test('mapper gives a present tier precedence over legacy badge', () {
    expect(mapTrainerTier(tier: 'basic', legacyBadge: 'elite'), 'basic');
    expect(mapTrainerTier(tier: 'unknown', legacyBadge: 'pro'), isNull);
    expect(mapTrainerTier(tier: '', legacyBadge: 'pro'), 'pro');
    expect(mapTrainerTier(legacyBadge: 'elite'), 'elite');
  });
}
