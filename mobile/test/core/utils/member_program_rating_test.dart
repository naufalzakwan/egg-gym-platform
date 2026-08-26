import 'package:egg_gym/core/utils/member_program_rating.dart';
import 'package:egg_gym/data/services/backend_member_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MemberProgramData program({
    bool canRate = true,
    bool programCompleted = true,
    bool alreadyRated = false,
  }) {
    return MemberProgramData(
      id: 1,
      title: 'Program',
      status: 'completed',
      progressPercent: 100,
      totalSessions: 4,
      completedSessions: 4,
      canRate: canRate,
      programCompleted: programCompleted,
      alreadyRated: alreadyRated,
    );
  }

  test('requires backend permission and completed unrated presentation state',
      () {
    expect(memberProgramNeedsRating(program()), isTrue);
    expect(memberProgramNeedsRating(program(canRate: false)), isFalse);
    expect(memberProgramNeedsRating(program(programCompleted: false)), isFalse);
    expect(memberProgramNeedsRating(program(alreadyRated: true)), isFalse);
  });
}
