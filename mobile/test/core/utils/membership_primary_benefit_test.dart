import 'package:egg_gym/core/utils/membership_primary_benefit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the first non-empty real package feature', () {
    expect(
      membershipPrimaryBenefit(['  ', 'Akses Gym', 'Locker']),
      'Akses Gym',
    );
  });

  test('uses a neutral fallback when features are empty', () {
    expect(membershipPrimaryBenefit(const []), 'Benefit Paket');
    expect(membershipPrimaryBenefit(const [' ', '']), 'Benefit Paket');
  });
}
