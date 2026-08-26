import 'dart:async';
import 'dart:convert';

import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:egg_gym/data/services/backend_api_config.dart';
import 'package:egg_gym/domain/entities/trainer_availability.dart';
import 'package:http/http.dart' as http;

class BackendTrainerAvailabilityService {
  BackendTrainerAvailabilityService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  Future<TrainerAvailability> getAvailability(int trainerProfileId) async {
    return _getAvailability(
      '/api/v1/public/trainers/$trainerProfileId/availability',
      authenticated: false,
    );
  }

  Future<TrainerAvailability> getRescheduleAvailability({
    required int bookingId,
    required int reservationId,
    required bool asMember,
  }) {
    final path = asMember
        ? '/api/v1/member/bookings/$bookingId/reservations/$reservationId/reschedule-availability'
        : '/api/v1/trainer/sessions/$bookingId/reservations/$reservationId/reschedule-availability';
    return _getAvailability(path, authenticated: true);
  }

  Future<TrainerAvailability> _getAvailability(
    String path, {
    required bool authenticated,
  }) async {
    Object? lastError;
    for (final baseUrl in _orderedBaseUrls()) {
      try {
        final response = await _client.get(
          Uri.parse(
            '$baseUrl$path',
          ),
          headers: <String, String>{
            'Accept': 'application/json',
            if (authenticated)
              'Authorization':
                  'Bearer ${AppSessionService.instance.currentSession?.token ?? ''}',
          },
        ).timeout(BackendApiConfig.requestTimeout);
        final payload = _decodeJson(response.body);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          lastError = Exception(
            payload['message'] ?? 'Gagal memuat jadwal trainer.',
          );
          continue;
        }
        final data = payload['data'];
        if (data is! Map<String, dynamic>) {
          lastError = Exception('Response jadwal trainer tidak valid.');
          continue;
        }
        await _persistRespondingBaseUrl(baseUrl);
        return TrainerAvailability.fromJson(data);
      } on TimeoutException {
        lastError = Exception('Timeout memuat jadwal trainer dari $baseUrl.');
      } catch (error) {
        lastError = error;
      }
    }
    throw lastError ?? Exception('Tidak ada backend yang tersedia.');
  }

  List<String> _orderedBaseUrls() {
    final active = AppSessionService.instance.currentSession?.baseUrl;
    return <String>{
      if (active != null && active.isNotEmpty) active,
      ...BackendApiConfig.candidateBaseUrls,
    }.toList(growable: false);
  }

  Future<void> _persistRespondingBaseUrl(String baseUrl) async {
    if (AppSessionService.instance.isAuthenticated) {
      await AppSessionService.instance.updateBaseUrl(baseUrl);
    }
  }

  Map<String, dynamic> _decodeJson(String body) {
    if (body.isEmpty) return const <String, dynamic>{};
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic>
        ? decoded
        : const <String, dynamic>{};
  }
}
