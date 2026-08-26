import 'package:egg_gym/data/services/backend_member_service.dart';

({String before, String after}) physicalProgressWeightPreview(
  MemberPhysicalProgressSnapshot? snapshot,
) {
  return (
    before: _weightLabel(snapshot?.baseline?.weightKg),
    after: _weightLabel(snapshot?.latest?.weightKg),
  );
}

String _weightLabel(double? value) {
  if (value == null || value <= 0) return '-';
  final fraction = value == value.roundToDouble() ? 0 : 1;
  return '${value.toStringAsFixed(fraction)} kg';
}
