import 'package:egg_gym/core/utils/physical_progress_history_sort.dart';
import 'package:egg_gym/data/services/backend_member_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('history sorts by recorded date newest first', () {
    final sorted = physicalProgressNewestFirst([
      _checkpoint(1, DateTime(2026, 7, 1)),
      _checkpoint(3, DateTime(2026, 7, 26)),
      _checkpoint(2, DateTime(2026, 7, 15)),
    ]);

    expect(sorted.map((item) => item.id), [3, 2, 1]);
  });

  test('same-date checkpoints use id newest first', () {
    final date = DateTime(2026, 7, 26);
    final sorted = physicalProgressNewestFirst([
      _checkpoint(2, date),
      _checkpoint(3, date),
      _checkpoint(1, date),
    ]);

    expect(sorted.map((item) => item.id), [3, 2, 1]);
  });

  test('preview takes only two newest checkpoints', () {
    final sorted = physicalProgressNewestFirst([
      _checkpoint(1, DateTime(2026, 7, 1)),
      _checkpoint(2, DateTime(2026, 7, 15)),
      _checkpoint(3, DateTime(2026, 7, 26)),
    ]);

    expect(sorted.take(2).map((item) => item.id), [3, 2]);
  });
}

MemberCheckpoint _checkpoint(int id, DateTime date) => MemberCheckpoint(
      id: id,
      recordedAt: date,
      weightKg: 60,
      heightCm: 170,
    );
