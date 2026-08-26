import 'package:egg_gym/core/utils/physical_progress_weight_preview.dart';
import 'package:egg_gym/data/services/backend_member_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty snapshot displays honest dashes', () {
    final result = physicalProgressWeightPreview(null);
    expect(result.before, '-');
    expect(result.after, '-');
  });

  test('one checkpoint is both before and after', () {
    final checkpoint = _checkpoint(1, 70);
    final result = physicalProgressWeightPreview(
      MemberPhysicalProgressSnapshot(
        baseline: checkpoint,
        latest: checkpoint,
        history: [checkpoint],
        totalRecords: 1,
      ),
    );

    expect(result.before, '70 kg');
    expect(result.after, '70 kg');
  });

  test('multiple checkpoints use backend baseline and latest', () {
    final result = physicalProgressWeightPreview(
      MemberPhysicalProgressSnapshot(
        baseline: _checkpoint(1, 70),
        latest: _checkpoint(2, 55.5),
        history: [_checkpoint(2, 55.5), _checkpoint(1, 70)],
        totalRecords: 2,
      ),
    );

    expect(result.before, '70 kg');
    expect(result.after, '55.5 kg');
  });

  test('missing weights stay independent', () {
    final result = physicalProgressWeightPreview(
      MemberPhysicalProgressSnapshot(
        baseline: _checkpoint(1, 0),
        latest: _checkpoint(2, 55),
        totalRecords: 2,
      ),
    );

    expect(result.before, '-');
    expect(result.after, '55 kg');
  });
}

MemberCheckpoint _checkpoint(int id, double weight) => MemberCheckpoint(
      id: id,
      recordedAt: DateTime(2026, 7, id),
      weightKg: weight,
      heightCm: 170,
    );
