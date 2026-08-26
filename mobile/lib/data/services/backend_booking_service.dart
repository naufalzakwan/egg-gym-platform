import 'dart:async';
import 'dart:convert';

import 'package:egg_gym/data/services/backend_api_config.dart';
import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:http/http.dart' as http;

class BookingResult {
  const BookingResult({
    required this.id,
    required this.sessionTitle,
    required this.sessionDate,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.status,
    required this.sessionCount,
    this.pricePerSession,
    this.totalAmount,
    this.reservations = const [],
  });

  final int id;
  final String sessionTitle;
  final String sessionDate;
  final String startTime;
  final String endTime;
  final String location;
  final String status;
  final int sessionCount;
  final double? pricePerSession;
  final double? totalAmount;
  final List<BookingSessionReservationResult> reservations;
}

class BookingSessionReservationResult {
  const BookingSessionReservationResult({
    required this.sequenceOrder,
    required this.sessionDate,
    required this.startTime,
    required this.endTime,
    required this.status,
  });

  final int sequenceOrder;
  final String sessionDate;
  final String startTime;
  final String endTime;
  final String status;
}

class BookingReservationSelection {
  const BookingReservationSelection({
    required this.sessionDate,
    required this.startTime,
    required this.endTime,
  });

  final String sessionDate;
  final String startTime;
  final String endTime;

  Map<String, dynamic> toJson() => {
        'session_date': sessionDate,
        'start_time': startTime,
        'end_time': endTime,
      };
}

class BackendBookingService {
  BackendBookingService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  ({String baseUrl, String token}) _authenticate() {
    final session = AppSessionService.instance;
    if (!session.isAuthenticated) {
      throw Exception('Sesi member belum aktif.');
    }
    final currentSession = session.currentSession;
    final token = currentSession?.token;
    final baseUrl = currentSession?.baseUrl;
    if (token == null || baseUrl == null) {
      throw Exception('Token atau base URL tidak tersedia.');
    }
    return (baseUrl: baseUrl, token: token);
  }

  Future<BookingResult> createBooking({
    required int trainerProfileId,
    required String sessionTitle,
    required String location,
    required int sessionCount,
    required List<BookingReservationSelection> reservations,
    String? memberNote,
  }) async {
    final auth = _authenticate();

    final body = <String, dynamic>{
      'trainer_profile_id': trainerProfileId,
      'session_title': sessionTitle,
      'location': location,
      'session_count': sessionCount,
      'reservations': reservations.map((item) => item.toJson()).toList(),
      if (memberNote != null && memberNote.trim().isNotEmpty)
        'member_note': memberNote.trim(),
    };

    Object? lastError;

    for (final baseUrl in BackendApiConfig.candidateBaseUrls) {
      try {
        final response = await _client
            .post(
              Uri.parse('$baseUrl/api/v1/member/bookings'),
              headers: <String, String>{
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Authorization': 'Bearer ${auth.token}',
              },
              body: jsonEncode(body),
            )
            .timeout(BackendApiConfig.requestTimeout);

        final payload = _decodeJson(response.body);

        if (response.statusCode == 422) {
          throw Exception(
            payload['message'] ?? 'Booking tidak dapat diproses.',
          );
        }

        if (response.statusCode == 409) {
          throw BookingConflictException(
            payload['message'] ??
                'Slot baru saja terisi. Silakan pilih jadwal lain.',
          );
        }

        if (response.statusCode == 401) {
          throw Exception('Sesi habis. Silakan login ulang.');
        }

        if (response.statusCode < 200 || response.statusCode >= 300) {
          lastError = Exception(
            payload['message'] ?? 'HTTP ${response.statusCode}',
          );
          continue;
        }

        final data = payload['data'];
        if (data is! Map<String, dynamic>) {
          throw Exception('Response booking tidak valid.');
        }

        return BookingResult(
          id: _asInt(data['id']) ?? 0,
          sessionTitle: _asString(data['session_title']) ?? sessionTitle,
          sessionDate:
              _asString(data['session_date']) ?? reservations.first.sessionDate,
          startTime:
              _asString(data['start_time']) ?? reservations.first.startTime,
          endTime: _asString(data['end_time']) ?? reservations.first.endTime,
          location: _asString(data['location']) ?? location,
          status: _asString(data['status']) ?? 'pending',
          sessionCount: _asInt(data['session_count']) ?? sessionCount,
          pricePerSession: _asDouble(data['price_per_session']),
          totalAmount: _asDouble(data['total_amount']),
          reservations: (data['session_reservations'] as List? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map((reservation) => BookingSessionReservationResult(
                    sequenceOrder: _asInt(reservation['sequence_order']) ?? 0,
                    sessionDate: _asString(reservation['session_date']) ?? '-',
                    startTime: _asString(reservation['start_time']) ?? '-',
                    endTime: _asString(reservation['end_time']) ?? '-',
                    status: _asString(reservation['status']) ?? 'reserved',
                  ))
              .toList(growable: false),
        );
      } on TimeoutException {
        lastError = Exception('Timeout mengirim booking ke $baseUrl');
        continue;
      } catch (error) {
        if (error is BookingConflictException) {
          rethrow;
        }
        if (error is Exception &&
            (error.toString().contains('Booking tidak dapat') ||
                error.toString().contains('Jadwal trainer sudah terisi') ||
                error.toString().contains('Slot baru saja terisi'))) {
          rethrow;
        }
        if (error is Exception && error.toString().contains('Sesi habis')) {
          rethrow;
        }
        lastError = error;
        continue;
      }
    }

    throw lastError ?? Exception('Tidak ada backend yang tersedia');
  }

  Future<bool> checkActiveMembership() async {
    final auth = _authenticate();

    for (final baseUrl in BackendApiConfig.candidateBaseUrls) {
      try {
        final response = await _client.get(
          Uri.parse('$baseUrl/api/v1/member/memberships'),
          headers: <String, String>{
            'Accept': 'application/json',
            'Authorization': 'Bearer ${auth.token}',
          },
        ).timeout(BackendApiConfig.requestTimeout);

        if (response.statusCode < 200 || response.statusCode >= 300) {
          continue;
        }

        final payload = _decodeJson(response.body);
        final data = payload['data'];
        if (data is Map<String, dynamic>) {
          final summary = data['summary'];
          if (summary is Map<String, dynamic>) {
            return summary['has_active_membership'] == true;
          }
        }

        return false;
      } on TimeoutException {
        continue;
      } catch (_) {
        continue;
      }
    }

    return false;
  }

  Map<String, dynamic> _decodeJson(String rawBody) {
    if (rawBody.isEmpty) return const <String, dynamic>{};
    final decoded = jsonDecode(rawBody);
    if (decoded is Map<String, dynamic>) return decoded;
    return const <String, dynamic>{};
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class BookingConflictException implements Exception {
  const BookingConflictException(this.message);

  final String message;

  @override
  String toString() => message;
}
