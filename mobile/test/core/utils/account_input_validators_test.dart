import 'package:egg_gym/core/utils/account_input_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('full name accepts letters and spaces only', () {
    expect(AccountInputValidators.fullName('Naufal Zakwan'), isNull);
    expect(AccountInputValidators.fullName('Elena Rodriguez'), isNull);
    expect(
      AccountInputValidators.fullName('dsds123'),
      'Nama hanya boleh huruf dan spasi.',
    );
    expect(
      AccountInputValidators.fullName('Naufal!!!'),
      'Nama hanya boleh huruf dan spasi.',
    );
  });

  test('phone requires Indonesian prefix and ten to fifteen digits', () {
    expect(AccountInputValidators.phone('081234567890'), isNull);
    expect(AccountInputValidators.phone('6281234567890'), isNull);
    for (final invalid in [
      '08123',
      '0812345678901234',
      '+628123456789',
      '0812-3456-7890',
      '08abc123',
      '071234567890',
    ]) {
      expect(
        AccountInputValidators.phone(invalid),
        'Nomor HP 10–15 digit, awali 08/628.',
        reason: invalid,
      );
    }
  });

  test('password requires upper lower number symbol and confirmation', () {
    expect(AccountInputValidators.strongPassword('EggGym@123'), isNull);
    for (final invalid in [
      'password',
      'Password',
      'Password1',
      'password1!',
      'PASS123!',
      'Pa@1abc',
    ]) {
      expect(
        AccountInputValidators.strongPassword(invalid),
        'Password harus 8+ karakter, Aa, angka & simbol.',
        reason: invalid,
      );
    }
    expect(
      AccountInputValidators.confirmation('EggGym@124', 'EggGym@123'),
      'Konfirmasi password tidak sama.',
    );
  });
}
