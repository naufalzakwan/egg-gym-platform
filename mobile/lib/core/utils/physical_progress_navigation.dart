bool shouldOpenPhysicalProgressOverviewAfterSave(Object? arguments) {
  return arguments is Map && arguments['openOverviewAfterSave'] == true;
}
