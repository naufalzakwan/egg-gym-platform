import 'package:egg_gym/core/utils/physical_progress_comparison.dart';
import 'package:egg_gym/data/services/backend_member_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('one checkpoint has no comparison after', () {
    final first = _checkpoint(1, 70);
    expect(
      physicalProgressComparisonAfter(
        MemberPhysicalProgressSnapshot(
          baseline: first,
          latest: first,
          history: [first],
          totalRecords: 1,
        ),
      ),
      isNull,
    );
  });

  test('two checkpoints use latest as comparison after', () {
    final before = _checkpoint(1, 70);
    final after = _checkpoint(2, 55);
    expect(
      physicalProgressComparisonAfter(
        MemberPhysicalProgressSnapshot(
          baseline: before,
          latest: after,
          history: [after, before],
          totalRecords: 2,
        ),
      )?.id,
      2,
    );
  });

  test('history length is safe fallback when summary count is absent', () {
    final before = _checkpoint(1, 70);
    final after = _checkpoint(2, 55);
    expect(
      physicalProgressComparisonAfter(
        MemberPhysicalProgressSnapshot(history: [after, before]),
      )?.id,
      2,
    );
  });
}

MemberCheckpoint _checkpoint(int id, double weight) => MemberCheckpoint(
      id: id,
      recordedAt: DateTime(2026, 7, id),
      weightKg: weight,
      heightCm: 170,
    );
