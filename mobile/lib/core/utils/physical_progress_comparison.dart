import 'package:egg_gym/data/services/backend_member_service.dart';

MemberCheckpoint? physicalProgressComparisonAfter(
  MemberPhysicalProgressSnapshot snapshot,
) {
  final count = snapshot.totalRecords > 0
      ? snapshot.totalRecords
      : snapshot.history.length;
  if (count < 2) return null;

  return snapshot.latest ??
      (snapshot.history.isNotEmpty ? snapshot.history.first : null);
}
