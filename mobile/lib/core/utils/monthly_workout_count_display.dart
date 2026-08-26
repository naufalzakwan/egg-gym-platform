String monthlyWorkoutCountDisplay(int? count, {required bool failed}) {
  return failed || count == null ? '-' : count.toString();
}
