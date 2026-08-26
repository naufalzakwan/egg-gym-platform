String? realEquipmentCode(String? value) {
  final code = value?.trim();
  if (code == null || code.isEmpty) return null;

  final normalized = code.toLowerCase();
  if (normalized == '-' ||
      normalized == 'tanpa kode' ||
      normalized == 'no code') {
    return null;
  }

  return code;
}
