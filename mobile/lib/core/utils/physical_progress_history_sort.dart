import 'package:egg_gym/data/services/backend_member_service.dart';

List<MemberCheckpoint> physicalProgressNewestFirst(
  Iterable<MemberCheckpoint> checkpoints,
) {
  final sorted = checkpoints.toList();
  sorted.sort((left, right) {
    final leftDate = left.recordedAt;
    final rightDate = right.recordedAt;
    if (leftDate != null && rightDate != null) {
      final dateComparison = rightDate.compareTo(leftDate);
      if (dateComparison != 0) return dateComparison;
    } else if (leftDate == null && rightDate != null) {
      return 1;
    } else if (leftDate != null && rightDate == null) {
      return -1;
    }

    return right.id.compareTo(left.id);
  });
  return sorted;
}
