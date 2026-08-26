String membershipDurationLabel({
  int? durationDays,
  String? billingPeriod,
}) {
  if (durationDays != null && durationDays > 0) {
    if (durationDays % 365 == 0) {
      final years = durationDays ~/ 365;
      return years == 1 ? 'Tahun' : '$years Tahun';
    }
    if (durationDays % 30 == 0) {
      final months = durationDays ~/ 30;
      return months == 1 ? 'Bulan' : '$months Bulan';
    }
    if (durationDays % 7 == 0) {
      final weeks = durationDays ~/ 7;
      return weeks == 1 ? 'Minggu' : '$weeks Minggu';
    }
    return '$durationDays Hari';
  }

  return switch (billingPeriod?.toLowerCase()) {
    'yearly' => 'Tahun',
    'weekly' => 'Minggu',
    'daily' => 'Hari',
    _ => 'Bulan',
  };
}
