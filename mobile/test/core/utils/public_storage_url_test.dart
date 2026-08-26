import 'package:egg_gym/core/utils/public_storage_url.dart';
import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:egg_gym/data/services/backend_api_config.dart';
import 'package:egg_gym/presentation/widgets/common/equipment_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSessionService.instance.clear();
    BackendApiConfig.activePublicBaseUrl = 'http://public.test:8000';
  });

  tearDown(() async {
    await AppSessionService.instance.clear();
    BackendApiConfig.activePublicBaseUrl = null;
  });

  test('guest equipment image uses active public API host', () {
    expect(
      resolveEquipmentImageUrl('equipments/cable-station.jpg'),
      'http://public.test:8000/storage/equipments/cable-station.jpg',
    );
  });

  test('storage-prefixed paths are not prefixed twice', () {
    expect(
      resolvePublicStorageUrl('/storage/equipment/cable-station.jpg'),
      'http://public.test:8000/storage/equipment/cable-station.jpg',
    );
    expect(
      resolveEquipmentImageUrl('storage/equipment/cable-station.jpg'),
      'http://public.test:8000/storage/equipment/cable-station.jpg',
    );
  });

  test('absolute equipment image URLs remain unchanged', () {
    expect(
      resolveEquipmentImageUrl('https://cdn.test/equipment/cable.jpg'),
      'https://cdn.test/equipment/cable.jpg',
    );
  });

  test('member session host remains authoritative when authenticated',
      () async {
    await AppSessionService.instance.setSession(
      const AppAuthenticatedSession(
        baseUrl: 'http://member.test:8000',
        token: 'token',
        role: 'member',
        userId: 1,
        name: 'Member',
        email: 'member@test.local',
      ),
    );

    expect(
      resolveEquipmentImageUrl('equipments/cable-station.jpg'),
      'http://member.test:8000/storage/equipments/cable-station.jpg',
    );
  });
}
