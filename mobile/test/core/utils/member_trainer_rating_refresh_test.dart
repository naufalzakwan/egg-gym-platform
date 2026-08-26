import 'package:egg_gym/core/utils/member_trainer_rating_refresh.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('successful rating refreshes programs and trainer catalog', () async {
    var programRefreshes = 0;
    var trainerCatalogRefreshes = 0;

    await refreshMemberTrainerRatingData(
      reloadPrograms: () async => programRefreshes++,
      reloadTrainerCatalog: () async => trainerCatalogRefreshes++,
    );

    expect(programRefreshes, 1);
    expect(trainerCatalogRefreshes, 1);
  });
}
