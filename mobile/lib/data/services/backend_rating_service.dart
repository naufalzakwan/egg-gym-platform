import 'dart:async';
import 'dart:convert';

import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:egg_gym/data/services/backend_api_config.dart';
import 'package:http/http.dart' as http;

/// Satu testimoni/ulasan dari member untuk seorang trainer.
class TrainerRatingData {
  const TrainerRatingData({
    required this.id,
    required this.memberName,
    required this.rating,
    this.testimonial,
    this.createdAt,
  });

  final int id;
  final String memberName;
  final int rating;
  final String? testimonial;
  final DateTime? createdAt;
}

/// Ringkasan ulasan seorang trainer: rata-rata, jumlah, dan daftar testimoni.
class TrainerRatingSummary {
  const TrainerRatingSummary({
    required double averageRating,
    required int reviewsCount,
    required this.reviews,
  })  : reviewsCount = reviewsCount > 0 &&
                averageRating > 0 &&
                averageRating <= 5 &&
                averageRating != double.infinity &&
                averageRating != double.negativeInfinity
            ? reviewsCount
            : 0,
        averageRating = reviewsCount > 0 &&
                averageRating > 0 &&
                averageRating <= 5 &&
                averageRating != double.infinity &&
                averageRating != double.negativeInfinity
            ? averageRating
            : 0;

  final double averageRating;
  final int reviewsCount;
  final List<TrainerRatingData> reviews;
}

class BackendRatingService {
  BackendRatingService({http.Client? client, String? publicBaseUrl})
      : _client = client ?? http.Client(),
        _publicBaseUrl = publicBaseUrl;

  final http.Client _client;
  final String? _publicBaseUrl;

  ({String baseUrl, String token}) _authenticate() {
    final session = AppSessionService.instance;
    if (!session.isAuthenticated) {
      throw Exception('Sesi belum aktif.');
    }
    final currentSession = session.currentSession;
    final token = currentSession?.token;
    final baseUrl = currentSession?.baseUrl;
    if (token == null || baseUrl == null) {
      throw Exception('Token atau base URL tidak tersedia.');
    }
    return (baseUrl: baseUrl, token: token);
  }

  /// Kirim rating (1-5) + testimoni opsional untuk program yang sudah selesai.
  /// Backend menolak bila program belum selesai / sudah dirating.
  Future<void> submitRating({
    required int trainingProgramId,
    required int rating,
    String? testimonial,
  }) async {
    if (trainingProgramId <= 0) {
      throw ArgumentError.value(
        trainingProgramId,
        'trainingProgramId',
        'must be positive',
      );
    }
    if (rating < 1 || rating > 5) {
      throw ArgumentError.value(rating, 'rating', 'must be between 1 and 5');
    }
    final auth = _authenticate();

    final response = await _client
        .post(
          Uri.parse('${auth.baseUrl}/api/v1/member/ratings'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${auth.token}',
          },
          body: jsonEncode(<String, dynamic>{
            'training_program_id': trainingProgramId,
            'rating': rating,
            if (testimonial != null && testimonial.trim().isNotEmpty)
              'testimonial': testimonial.trim(),
          }),
        )
        .timeout(BackendApiConfig.requestTimeout);

    final payload = _decodeJson(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(payload['message'] ?? 'Gagal mengirim rating.');
    }
  }

  /// Ambil ringkasan + daftar testimoni publik untuk seorang trainer.
  Future<TrainerRatingSummary> getTrainerRatings(int trainerProfileId) async {
    if (trainerProfileId <= 0) {
      throw ArgumentError.value(
        trainerProfileId,
        'trainerProfileId',
        'must be positive',
      );
    }

    http.Response? response;
    Object? lastError;
    for (final baseUrl in _orderedPublicBaseUrls()) {
      try {
        final candidate = await _client.get(
          Uri.parse(
            '$baseUrl/api/v1/public/trainers/$trainerProfileId/ratings',
          ),
          headers: const {'Accept': 'application/json'},
        ).timeout(BackendApiConfig.requestTimeout);
        if (candidate.statusCode >= 200 && candidate.statusCode < 300) {
          response = candidate;
          BackendApiConfig.activePublicBaseUrl = baseUrl;
          break;
        }
        lastError = Exception('HTTP ${candidate.statusCode}');
      } catch (error) {
        lastError = error;
      }
    }

    if (response == null) {
      throw lastError ?? Exception('Gagal mengambil ulasan trainer.');
    }

    final payload = _decodeJson(response.body);
    final data = payload['data'] as Map<String, dynamic>? ?? const {};
    final reviewsRaw = data['reviews'] as List? ?? const [];
    final reviewsCount = _asInt(data['reviews_count']) ?? 0;

    return TrainerRatingSummary(
      averageRating:
          reviewsCount > 0 ? _asDouble(data['average_rating']) ?? 0 : 0,
      reviewsCount: reviewsCount,
      reviews: reviewsRaw
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => TrainerRatingData(
              id: _asInt(item['id']) ?? 0,
              memberName: _asString(item['member_name']) ?? 'Member',
              rating: _asInt(item['rating']) ?? 0,
              testimonial: _asString(item['testimonial']),
              createdAt: _asDate(item['created_at']),
            ),
          )
          .toList(),
    );
  }

  List<String> _orderedPublicBaseUrls() {
    final sessionBaseUrl = AppSessionService.instance.currentSession?.baseUrl;
    return <String>{
      if (_publicBaseUrl?.isNotEmpty == true) _publicBaseUrl!,
      if (sessionBaseUrl?.isNotEmpty == true) sessionBaseUrl!,
      if (BackendApiConfig.activePublicBaseUrl?.isNotEmpty == true)
        BackendApiConfig.activePublicBaseUrl!,
      ...BackendApiConfig.candidateBaseUrls,
    }.toList(growable: false);
  }

  Map<String, dynamic> _decodeJson(String body) {
    if (body.isEmpty) return const {};
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    return const {};
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static String? _asString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static DateTime? _asDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString())?.toLocal();
  }
}
