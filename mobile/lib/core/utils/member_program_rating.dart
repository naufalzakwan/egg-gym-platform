import 'package:egg_gym/data/services/backend_member_service.dart';

bool memberProgramNeedsRating(MemberProgramData program) {
  return program.canRate && program.programCompleted && !program.alreadyRated;
}
