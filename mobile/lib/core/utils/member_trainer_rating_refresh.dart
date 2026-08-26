Future<void> refreshMemberTrainerRatingData({
  required Future<void> Function() reloadPrograms,
  required Future<void> Function() reloadTrainerCatalog,
}) async {
  await Future.wait([reloadPrograms(), reloadTrainerCatalog()]);
}
