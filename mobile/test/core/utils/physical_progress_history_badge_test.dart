import 'package:egg_gym/core/utils/physical_progress_history_badge.dart';
import 'package:egg_gym/data/services/backend_member_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('two checkpoints on the same date get baseline and latest badges', () {
    final baseline = _checkpoint(1, DateTime(2026, 7, 26));
    final latest = _checkpoint(2, DateTime(2026, 7, 26));

    expect(
      physicalProgressHistoryBadge(
        checkpoint: baseline,
        baseline: baseline,
        latest: latest,
      ),
      'BASELINE',
    );
    expect(
      physicalProgressHistoryBadge(
        checkpoint: latest,
        baseline: baseline,
        latest: latest,
      ),
      'TERBARU',
    );
  });

  test('middle checkpoint uses neutral checkpoint badge', () {
    final baseline = _checkpoint(1, DateTime(2026, 7, 1));
    final middle = _checkpoint(2, DateTime(2026, 7, 15));
    final latest = _checkpoint(3, DateTime(2026, 7, 26));

    expect(
      physicalProgressHistoryBadge(
        checkpoint: middle,
        baseline: baseline,
        latest: latest,
      ),
      'CHECKPOINT',
    );
  });

  test('single checkpoint remains baseline, not latest', () {
    final only = _checkpoint(1, DateTime(2026, 7, 26));

    expect(
      physicalProgressHistoryBadge(
        checkpoint: only,
        baseline: only,
        latest: only,
      ),
      'BASELINE',
    );
  });
}

MemberCheckpoint _checkpoint(int id, DateTime date) => MemberCheckpoint(
      id: id,
      recordedAt: date,
      weightKg: 60,
      heightCm: 170,
    );
