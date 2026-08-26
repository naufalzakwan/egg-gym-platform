class AccountInputValidators {
  const AccountInputValidators._();

  static final RegExp _namePattern = RegExp(r"^[A-Za-zÀ-ÿ\s]+$");
  static final RegExp _phonePattern = RegExp(r'^(08|628)[0-9]+$');
  static final RegExp _strongPassword = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$',
  );

  static String? fullName(String? raw, {bool required = true}) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return required ? 'Nama lengkap wajib diisi.' : null;
    if (!_namePattern.hasMatch(value)) {
      return 'Nama hanya boleh huruf dan spasi.';
    }
    return null;
  }

  static String? phone(String? raw, {bool required = true}) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return required ? 'Nomor HP wajib diisi.' : null;
    if (value.length < 10 ||
        value.length > 15 ||
        !_phonePattern.hasMatch(value)) {
      return 'Nomor HP 10–15 digit, awali 08/628.';
    }
    return null;
  }

  static String? strongPassword(String? raw, {bool required = true}) {
    final value = raw ?? '';
    if (value.isEmpty) return required ? 'Password wajib diisi.' : null;
    if (!_strongPassword.hasMatch(value)) {
      return 'Password harus 8+ karakter, Aa, angka & simbol.';
    }
    return null;
  }

  static String? confirmation(String? raw, String password,
      {bool required = true}) {
    final value = raw ?? '';
    if (value.isEmpty && required) return 'Konfirmasi password wajib diisi.';
    if (value != password) return 'Konfirmasi password tidak sama.';
    return null;
  }
}
