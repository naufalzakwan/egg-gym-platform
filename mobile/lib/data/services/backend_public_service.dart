import 'dart:async';
import 'dart:convert';

import 'package:egg_gym/data/services/backend_api_config.dart';
import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:egg_gym/core/constants/trainer_specialties.dart';
import 'package:egg_gym/core/utils/trainer_tier.dart';
import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:http/http.dart' as http;

class BackendPublicService {
  BackendPublicService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  Future<GuestShowcaseData> getGuestShowcase() async {
    final results = await Future.wait([
      getMembershipPlans(),
      getTrainers(),
      getEquipments(),
      getOperationHours(),
    ]);

    return GuestShowcaseData(
      plans: results[0] as List<MembershipPlan>,
      trainers: results[1] as List<TrainerProfile>,
      equipments: results[2] as List<EquipmentInfo>,
      operationHours: results[3] as List<OperationHour>,
    );
  }

  Future<List<MembershipPlan>> getMembershipPlans() async {
    final data = await _getPublicList('membership-plans');

    return data
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => MembershipPlan(
            backendId: _asNullableInt(item['id']),
            slug: _asNullableString(item['slug']),
            title: _asNullableString(item['name']) ?? 'Membership Plan',
            subtitle: '',
            priceLabel: _formatPrice(_asNullableDouble(item['price'])),
            periodLabel:
                _periodLabel(_asNullableString(item['billing_period'])),
            priceValue: _asNullableDouble(item['price']),
            billingPeriod: _asNullableString(item['billing_period']),
            durationDays: _asNullableInt(item['duration_days']),
            features: _parseStringList(item['features']),
            isHighlighted: item['is_highlighted'] == true,
            isBestSeller: item['is_best_seller'] == true,
          ),
        )
        .toList();
  }

  Future<List<TrainerProfile>> getTrainers() async {
    final data = await _getPublicList('trainers');

    return data.whereType<Map<String, dynamic>>().map(_mapTrainer).toList();
  }

  TrainerProfile _mapTrainer(Map<String, dynamic> item) {
    final reviewsCount = _asNullableInt(item['reviews_count']) ?? 0;
    return TrainerProfile(
      backendId: _asNullableInt(item['id']),
      name: _asNullableString(item['name']) ?? 'Trainer',
      specialty: TrainerSpecialties.displayLabel(
        _asNullableString(item['specialty']),
      ),
      bio: _asNullableString(item['bio']) ?? '-',
      rating: reviewsCount > 0 ? _asNullableDouble(item['rating']) ?? 0 : 0,
      reviewsCount: reviewsCount,
      tier: mapTrainerTier(tier: item['tier'], legacyBadge: item['badge']),
      isAvailable: item['is_available'] != false,
      hasActiveSchedule: item['has_active_schedule'] == true,
      activeMembers: _asNullableInt(item['active_members']) ?? 0,
      maxMembers: _asNullableInt(item['max_members']) ?? 2,
      experienceYears: _asNullableInt(item['experience_years']),
      certifications: _trainerCertificationList(item),
      servedClientsCount: _asNullableInt(item['served_clients_count']),
      pricePerSession: _asNullableDouble(item['price_per_session']),
      avatarUrl: _asNullableString(item['avatar_url']),
      displayPhotoPath: _asNullableString(item['display_photo_path']),
      specialties: _parseStringList(item['specialties']),
    );
  }

  Future<List<EquipmentInfo>> getEquipments() async {
    final data = await _getPublicList('equipment');

    return data.whereType<Map<String, dynamic>>().map(_mapEquipment).toList();
  }

  List<String> _trainerCertificationList(Map<String, dynamic> item) {
    if (item['certifications_list'] is List) {
      return _parseStringList(item['certifications_list']);
    }
    final legacy = _asNullableString(item['certifications']);
    if (legacy == null || legacy.isEmpty) return const [];
    return legacy
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  Future<EquipmentInfo> getEquipment(int id) async {
    final data = await _getPublicObject('equipment/$id');
    return _mapEquipment(data);
  }

  EquipmentInfo _mapEquipment(Map<String, dynamic> item) {
    final movements = (item['movements'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (movement) => GymEquipmentMovement(
            id: _asNullableInt(movement['id']) ?? 0,
            movementName: _asNullableString(movement['movement_name']) ?? '',
            targetArea: _asNullableString(movement['target_area']) ?? '',
            sortOrder: _asNullableInt(movement['sort_order']) ?? 0,
          ),
        )
        .where(
          (movement) =>
              movement.id > 0 &&
              movement.movementName.isNotEmpty &&
              movement.targetArea.isNotEmpty,
        )
        .toList()
      ..sort((left, right) {
        final order = left.sortOrder.compareTo(right.sortOrder);
        return order != 0 ? order : left.id.compareTo(right.id);
      });

    return EquipmentInfo(
      id: _asNullableInt(item['id']),
      code: _asNullableString(item['code']),
      name: _asNullableString(item['name']) ?? '',
      category: _asNullableString(item['category']) ?? '',
      status: _asNullableString(item['status']) ?? '',
      statusLabel: _asNullableString(item['status_label']) ?? '',
      description: _asNullableString(item['description']) ?? '',
      imagePath: _firstEquipmentImage(item),
      focus: _asNullableString(item['focus']) ?? '',
      stageLabel: _asNullableString(item['stage_label']),
      usageWindow: _asNullableString(item['usage_window']),
      bestFor: _asNullableString(item['best_for']),
      difficulty: _asNullableString(item['difficulty']),
      keyBenefits: _parseEquipmentTextList(item['key_benefits']),
      usageFlow: _parseEquipmentTextList(item['usage_flow']),
      safetyNotes: _parseEquipmentTextList(item['safety_notes']),
      suggestedMovements: _parseStringList(item['suggested_movements']),
      movements: movements,
      isActive: item['is_active'] != false,
    );
  }

  Future<List<OperationHour>> getOperationHours() async {
    final data = await _getPublicList('operation-hours');

    return data.whereType<Map<String, dynamic>>().map(
      (item) {
        final dayName = _asNullableString(item['day_name']) ?? '-';
        final isClosed = item['is_closed'] == true;
        final openTime = _formatTime(_asNullableString(item['open_time']));
        final closeTime = _formatTime(_asNullableString(item['close_time']));

        return OperationHour(
          day: dayName,
          hours: isClosed ? 'Tutup' : '$openTime - $closeTime',
        );
      },
    ).toList();
  }

  Future<Map<String, dynamic>> getPublicSettings() =>
      _getPublicObject('settings');

  Future<List<dynamic>> _getPublicList(String path) async {
    Object? lastError;

    for (final baseUrl in _orderedBaseUrls()) {
      try {
        final response = await _client.get(
          Uri.parse('$baseUrl/api/v1/public/$path'),
          headers: const <String, String>{
            'Accept': 'application/json',
          },
        ).timeout(BackendApiConfig.requestTimeout);

        if (response.statusCode < 200 || response.statusCode >= 300) {
          lastError = Exception('HTTP ${response.statusCode}');
          continue;
        }

        final payload = _decodeJson(response.body);

        if (payload['success'] != true) {
          lastError = Exception(payload['message'] ?? 'Request failed');
          continue;
        }

        final data = payload['data'];
        if (data is List) {
          await _persistRespondingBaseUrl(baseUrl);
          return data;
        }

        lastError = Exception('Response data bukan list');
        continue;
      } on TimeoutException {
        lastError = Exception('Timeout mengambil $path dari $baseUrl');
        continue;
      } catch (error) {
        lastError = error;
        continue;
      }
    }

    throw lastError ?? Exception('Tidak ada backend public API yang tersedia');
  }

  Future<Map<String, dynamic>> _getPublicObject(String path) async {
    Object? lastError;

    for (final baseUrl in _orderedBaseUrls()) {
      try {
        final response = await _client.get(
          Uri.parse('$baseUrl/api/v1/public/$path'),
          headers: const <String, String>{'Accept': 'application/json'},
        ).timeout(BackendApiConfig.requestTimeout);

        if (response.statusCode < 200 || response.statusCode >= 300) {
          lastError = Exception('HTTP ${response.statusCode}');
          continue;
        }

        final payload = _decodeJson(response.body);
        if (payload['success'] == true &&
            payload['data'] is Map<String, dynamic>) {
          await _persistRespondingBaseUrl(baseUrl);
          return payload['data'] as Map<String, dynamic>;
        }
        lastError =
            Exception(payload['message'] ?? 'Response detail tidak valid');
      } on TimeoutException {
        lastError = Exception('Timeout mengambil $path dari $baseUrl');
      } catch (error) {
        lastError = error;
      }
    }

    throw lastError ?? Exception('Tidak ada backend public API yang tersedia');
  }

  List<String> _orderedBaseUrls() {
    final active = AppSessionService.instance.currentSession?.baseUrl;
    return <String>{
      if (active != null && active.isNotEmpty) active,
      if (BackendApiConfig.activePublicBaseUrl?.isNotEmpty == true)
        BackendApiConfig.activePublicBaseUrl!,
      ...BackendApiConfig.candidateBaseUrls,
    }.toList(growable: false);
  }

  Future<void> _persistRespondingBaseUrl(String baseUrl) async {
    BackendApiConfig.activePublicBaseUrl = baseUrl;
    if (AppSessionService.instance.isAuthenticated) {
      await AppSessionService.instance.updateBaseUrl(baseUrl);
    }
  }

  Map<String, dynamic> _decodeJson(String rawBody) {
    if (rawBody.isEmpty) {
      return const <String, dynamic>{};
    }

    final decoded = jsonDecode(rawBody);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return const <String, dynamic>{};
  }

  // Format penuh dengan pemisah ribuan titik: 549000 -> "Rp 549.000".
  // Angka dari data backend (price), hanya cara formatnya yang diubah.
  String _formatPrice(double? price) {
    if (price == null) {
      return '-';
    }

    final whole = price.round().toString();
    final buffer = StringBuffer();
    for (var index = 0; index < whole.length; index++) {
      final reversedIndex = whole.length - index;
      buffer.write(whole[index]);
      if (reversedIndex > 1 && reversedIndex % 3 == 1) {
        buffer.write('.');
      }
    }
    return 'Rp $buffer';
  }

  // Label periode: " / Bulan", " / Tahun", dst (spasi + kapital di awal).
  String _periodLabel(String? billingPeriod) {
    return switch ((billingPeriod ?? 'monthly').toLowerCase()) {
      'yearly' => ' / Tahun',
      'weekly' => ' / Minggu',
      'daily' => ' / Hari',
      _ => ' / Bulan',
    };
  }

  String? _formatTime(String? raw) {
    if (raw == null || raw.length < 5) {
      return raw;
    }

    return raw.substring(0, 5).replaceAll(':', '.');
  }

  List<String> _parseStringList(dynamic value) {
    if (value is List) {
      return value
          .whereType<dynamic>()
          .map((e) => e.toString())
          .where((s) => s.isNotEmpty)
          .toList();
    }

    return const [];
  }

  List<String> _parseEquipmentTextList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  String? _firstEquipmentImage(Map<String, dynamic> item) {
    for (final key in const [
      'image_url',
      'imageUrl',
      'image_path',
      'image',
      'photo_url',
    ]) {
      final value = _asNullableString(item[key]);
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static int? _asNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
  }

  static double? _asNullableDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }

  static String? _asNullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    final stringValue = value.toString().trim();
    return stringValue.isEmpty ? null : stringValue;
  }
}
