import 'package:egg_gym/data/services/backend_member_service.dart';

String physicalProgressHistoryBadge({
  required MemberCheckpoint checkpoint,
  required MemberCheckpoint baseline,
  required MemberCheckpoint latest,
}) {
  if (checkpoint.id == baseline.id) return 'BASELINE';
  if (checkpoint.id == latest.id) return 'TERBARU';
  if (checkpoint.isMilestone) return 'MILESTONE';
  return 'CHECKPOINT';
}
