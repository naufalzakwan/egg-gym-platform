String membershipPrimaryBenefit(Iterable<String> features) {
  for (final feature in features) {
    final value = feature.trim();
    if (value.isNotEmpty) return value;
  }
  return 'Benefit Paket';
}
