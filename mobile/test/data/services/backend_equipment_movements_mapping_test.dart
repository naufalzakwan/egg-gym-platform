import 'dart:convert';

import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:egg_gym/data/services/backend_api_config.dart';
import 'package:egg_gym/data/services/backend_public_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSessionService.instance.clear();
    BackendApiConfig.activePublicBaseUrl = 'http://public.test';
  });

  tearDown(() => BackendApiConfig.activePublicBaseUrl = null);

  test('maps ordered equipment movements from public API', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/v1/public/equipment');
      return http.Response(
        jsonEncode({
          'success': true,
          'data': [
            {
              'id': 7,
              'name': 'Cable Station',
              'category': 'Functional',
              'status': 'available',
              'status_label': 'Tersedia',
              'description': 'Cable dari Admin',
              'image_path': 'equipments/cable-station.jpg',
              'focus': 'Full Body',
              'usage_window': '10-15 menit',
              'best_for': 'Latihan upper body',
              'difficulty': 'Menengah',
              'key_benefits': ['  Resistance stabil  ', ''],
              'usage_flow': ['Atur pin beban'],
              'safety_notes': ['Pastikan pin terkunci'],
              'suggested_movements': ['LEGACY DUMMY'],
              'movements': [
                {
                  'id': 52,
                  'movement_name': 'Lat Pulldown',
                  'target_area': 'Back',
                  'sort_order': 2,
                },
                {
                  'id': 51,
                  'movement_name': 'Cable Fly',
                  'target_area': 'Chest',
                  'sort_order': 1,
                },
                {
                  'id': 53,
                  'movement_name': '  ',
                  'target_area': 'Back',
                  'sort_order': 3,
                },
              ],
            },
          ],
        }),
        200,
      );
    });

    final equipments =
        await BackendPublicService(client: client).getEquipments();
    final equipment = equipments.single;

    expect(equipment.id, 7);
    expect(equipment.name, 'Cable Station');
    expect(equipment.movements.map((item) => item.id), [51, 52]);
    expect(
      equipment.movements.map((item) => item.movementName),
      ['Cable Fly', 'Lat Pulldown'],
    );
    expect(
        equipment.movements.map((item) => item.targetArea), ['Chest', 'Back']);
    expect(equipment.description, 'Cable dari Admin');
    expect(equipment.imagePath, 'equipments/cable-station.jpg');
    expect(equipment.focus, 'Full Body');
    expect(equipment.usageWindow, '10-15 menit');
    expect(equipment.bestFor, 'Latihan upper body');
    expect(equipment.difficulty, 'Menengah');
    expect(equipment.keyBenefits, ['Resistance stabil']);
    expect(equipment.usageFlow, ['Atur pin beban']);
    expect(equipment.safetyNotes, ['Pastikan pin terkunci']);
    expect(equipment.suggestedMovements, ['LEGACY DUMMY']);
  });

  test('maps compatible public equipment image field aliases', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/v1/public/equipment/9');
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'id': 9,
            'name': 'Public Equipment',
            'image_url': 'https://cdn.test/equipment.jpg',
            'image_path': 'equipments/ignored.jpg',
            'movements': [],
          },
        }),
        200,
      );
    });

    final equipment =
        await BackendPublicService(client: client).getEquipment(9);

    expect(equipment.imagePath, 'https://cdn.test/equipment.jpg');
  });

  test('keeps missing equipment detail fields empty without dummy fallback',
      () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/v1/public/equipment/8');
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'id': 8,
            'name': 'Empty Equipment',
            'movements': [],
          },
        }),
        200,
      );
    });

    final equipment =
        await BackendPublicService(client: client).getEquipment(8);

    expect(equipment.name, 'Empty Equipment');
    expect(equipment.category, isEmpty);
    expect(equipment.status, isEmpty);
    expect(equipment.statusLabel, isEmpty);
    expect(equipment.description, isEmpty);
    expect(equipment.focus, isEmpty);
    expect(equipment.keyBenefits, isEmpty);
    expect(equipment.usageFlow, isEmpty);
    expect(equipment.safetyNotes, isEmpty);
    expect(equipment.movements, isEmpty);
  });
}
