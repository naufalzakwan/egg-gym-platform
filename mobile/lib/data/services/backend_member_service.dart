import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:egg_gym/core/formatters/app_date_formatter.dart';
import 'package:egg_gym/data/services/backend_api_config.dart';
import 'package:egg_gym/data/services/base_url_resolver.dart';
import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

class BackendMemberService {
  BackendMemberService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  ({String baseUrl, String token}) _authenticate() {
    final session = AppSessionService.instance;
    if (!session.isAuthenticated) {
      throw MemberApiException('Sesi member belum aktif.');
    }
    final currentSession = session.currentSession;
    final token = currentSession?.token;
    final baseUrl = currentSession?.baseUrl;
    if (token == null || baseUrl == null) {
      throw MemberApiException('Token atau base URL tidak tersedia.');
    }
    return (baseUrl: baseUrl, token: token);
  }

  /// Delegasi tipis ke resolver bersama [sendWithBaseUrlFallback] agar logika
  /// auto-fallback base URL tidak diduplikasi antar service.
  Future<http.Response> _sendWithBaseUrlFallback(
    Future<http.Response> Function(String baseUrl) send,
  ) {
    final auth = _authenticate();
    return sendWithBaseUrlFallback(activeBaseUrl: auth.baseUrl, send: send);
  }

  /// GET /api/v1/member/dashboard
  Future<MemberLiveDashboardData> getDashboard() async {
    final auth = _authenticate();
    Object? lastError;

    for (final baseUrl in BackendApiConfig.candidateBaseUrls) {
      try {
        final response = await _client.get(
          Uri.parse('$baseUrl/api/v1/member/dashboard'),
          headers: <String, String>{
            'Accept': 'application/json',
            'Authorization': 'Bearer ${auth.token}',
          },
        ).timeout(BackendApiConfig.requestTimeout);

        final payload = _decodeJson(response.body);

        if (response.statusCode < 200 || response.statusCode >= 300) {
          if (response.statusCode == 401 || response.statusCode == 403) {
            throw MemberApiException(
              _extractMessage(payload,
                  fallback: 'Sesi habis. Silakan login ulang.'),
            );
          }
          throw MemberApiException(
            _extractMessage(payload,
                fallback: 'Gagal mengambil dashboard member.'),
          );
        }

        final data = payload['data'];
        if (data is! Map<String, dynamic>) {
          throw const MemberApiException(
              'Response dashboard member tidak valid.');
        }

        return _mapDashboardData(data);
      } on MemberApiException {
        rethrow;
      } catch (error) {
        lastError = error;
      }
    }

    throw MemberApiException(
      lastError?.toString() ?? 'Gagal terhubung ke backend.',
    );
  }

  /// GET /api/v1/member/profile
  Future<MemberProfileData> getProfile() async {
    final auth = _authenticate();
    Object? lastError;

    // INSTRUMENTASI TIMING: ukur latency round-trip asli yang dirasakan user.
    // getProfile mencoba tiap candidate URL berurutan; kalau URL benar ada di
    // urutan belakang & yang di depan tidak terjangkau (hang sampai timeout),
    // total waktu bisa membengkak. Log per-percobaan + total agar penyebab
    // pasti terlihat (kontensi server vs URL mati yang hang).
    final totalSw = Stopwatch()..start();
    debugPrint(
        '[getProfile] START — ${BackendApiConfig.candidateBaseUrls.length} candidate URL, timeout ${BackendApiConfig.requestTimeout.inSeconds}s/URL');

    for (final baseUrl in BackendApiConfig.candidateBaseUrls) {
      final attemptSw = Stopwatch()..start();
      try {
        final response = await _client.get(
          Uri.parse('$baseUrl/api/v1/member/profile'),
          headers: <String, String>{
            'Accept': 'application/json',
            'Authorization': 'Bearer ${auth.token}',
          },
        ).timeout(BackendApiConfig.requestTimeout);

        attemptSw.stop();

        final payload = _decodeJson(response.body);

        if (response.statusCode < 200 || response.statusCode >= 300) {
          debugPrint(
              '[getProfile] $baseUrl -> HTTP ${response.statusCode} in ${attemptSw.elapsedMilliseconds}ms');
          if (response.statusCode == 401 || response.statusCode == 403) {
            throw MemberApiException(
              _extractMessage(payload,
                  fallback: 'Sesi habis. Silakan login ulang.'),
            );
          }
          throw MemberApiException(
            _extractMessage(payload,
                fallback: 'Gagal mengambil profil member.'),
          );
        }

        final data = payload['data'];
        if (data is! Map<String, dynamic>) {
          throw const MemberApiException('Response profil member tidak valid.');
        }

        totalSw.stop();
        debugPrint(
            '[getProfile] SUCCESS via $baseUrl — attempt ${attemptSw.elapsedMilliseconds}ms | TOTAL round-trip ${totalSw.elapsedMilliseconds}ms');
        return _mapProfileData(data);
      } on MemberApiException {
        rethrow;
      } catch (error) {
        attemptSw.stop();
        // Log tiap URL yang gagal + berapa lama (URL mati yang hang tampak di sini).
        debugPrint(
            '[getProfile] FAIL  $baseUrl — ${attemptSw.elapsedMilliseconds}ms — ${error.runtimeType}');
        lastError = error;
      }
    }

    totalSw.stop();
    debugPrint(
        '[getProfile] ALL CANDIDATES FAILED — TOTAL ${totalSw.elapsedMilliseconds}ms');
    throw MemberApiException(
      lastError?.toString() ?? 'Gagal terhubung ke backend.',
    );
  }

  /// PUT /api/v1/member/profile
  Future<MemberProfileData> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? gender,
    String? birthDate,
    double? heightCm,
    double? weightKg,
    String? fitnessGoal,
    String? medicalNote,
    String? currentPassword,
    String? newPassword,
    String? newPasswordConfirmation,
  }) async {
    final auth = _authenticate();

    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (gender != null) 'gender': gender,
      if (birthDate != null) 'birth_date': birthDate,
      if (heightCm != null) 'height_cm': heightCm,
      if (weightKg != null) 'weight_kg': weightKg,
      if (fitnessGoal != null) 'fitness_goal': fitnessGoal,
      if (medicalNote != null) 'medical_note': medicalNote,
      if (currentPassword != null && currentPassword.isNotEmpty)
        'current_password': currentPassword,
      if (newPassword != null && newPassword.isNotEmpty)
        'new_password': newPassword,
      if (newPasswordConfirmation != null && newPasswordConfirmation.isNotEmpty)
        'new_password_confirmation': newPasswordConfirmation,
    };

    final response = await _client
        .put(
          Uri.parse('${auth.baseUrl}/api/v1/member/profile'),
          headers: <String, String>{
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${auth.token}',
          },
          body: jsonEncode(body),
        )
        .timeout(BackendApiConfig.requestTimeout);

    final payload = _decodeJson(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MemberApiException(
        _extractMessage(payload, fallback: 'Gagal memperbarui profil member.'),
      );
    }

    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      throw const MemberApiException('Response update profil tidak valid.');
    }

    return _mapProfileData(data);
  }

  /// GET /api/v1/member/memberships
  Future<List<MemberMembershipData>> getMemberships() async {
    final auth = _authenticate();
    Object? lastError;

    for (final baseUrl in BackendApiConfig.candidateBaseUrls) {
      try {
        final response = await _client.get(
          Uri.parse('$baseUrl/api/v1/member/memberships'),
          headers: <String, String>{
            'Accept': 'application/json',
            'Authorization': 'Bearer ${auth.token}',
          },
        ).timeout(BackendApiConfig.requestTimeout);

        final payload = _decodeJson(response.body);

        if (response.statusCode < 200 || response.statusCode >= 300) {
          if (response.statusCode == 401 || response.statusCode == 403) {
            throw MemberApiException(
              _extractMessage(payload,
                  fallback: 'Sesi habis. Silakan login ulang.'),
            );
          }
          throw MemberApiException(
            _extractMessage(payload,
                fallback: 'Gagal mengambil data membership.'),
          );
        }

        final data = payload['data'];
        if (data is! Map<String, dynamic>) {
          throw const MemberApiException('Response membership tidak valid.');
        }

        final memberships = data['memberships'] as List? ?? [];
        return memberships
            .whereType<Map<String, dynamic>>()
            .map(_mapMembershipData)
            .toList();
      } on MemberApiException {
        rethrow;
      } catch (error) {
        lastError = error;
      }
    }

    throw MemberApiException(
      lastError?.toString() ?? 'Gagal terhubung ke backend.',
    );
  }

  /// GET /api/v1/member/transactions
  Future<List<MemberTransactionData>> getTransactions() async {
    final auth = _authenticate();
    Object? lastError;

    for (final baseUrl in BackendApiConfig.candidateBaseUrls) {
      try {
        final response = await _client.get(
          Uri.parse('$baseUrl/api/v1/member/transactions'),
          headers: <String, String>{
            'Accept': 'application/json',
            'Authorization': 'Bearer ${auth.token}',
          },
        ).timeout(BackendApiConfig.requestTimeout);

        final payload = _decodeJson(response.body);

        if (response.statusCode < 200 || response.statusCode >= 300) {
          if (response.statusCode == 401 || response.statusCode == 403) {
            throw MemberApiException(
              _extractMessage(payload,
                  fallback: 'Sesi habis. Silakan login ulang.'),
            );
          }
          throw MemberApiException(
            _extractMessage(payload,
                fallback: 'Gagal mengambil histori transaksi.'),
          );
        }

        final data = payload['data'];
        if (data is! Map<String, dynamic>) {
          throw const MemberApiException('Response transaksi tidak valid.');
        }

        final transactions = data['transactions'] as List? ?? [];
        return transactions
            .whereType<Map<String, dynamic>>()
            .map(_mapTransactionData)
            .toList();
      } on MemberApiException {
        rethrow;
      } catch (error) {
        lastError = error;
      }
    }

    throw MemberApiException(
      lastError?.toString() ?? 'Gagal terhubung ke backend.',
    );
  }

  /// GET /api/v1/member/bookings
  Future<List<MemberBookingData>> getBookings() async {
    final auth = _authenticate();
    Object? lastError;

    for (final baseUrl in BackendApiConfig.candidateBaseUrls) {
      try {
        final response = await _client.get(
          Uri.parse('$baseUrl/api/v1/member/bookings'),
          headers: <String, String>{
            'Accept': 'application/json',
            'Authorization': 'Bearer ${auth.token}',
          },
        ).timeout(BackendApiConfig.requestTimeout);

        final payload = _decodeJson(response.body);

        if (response.statusCode < 200 || response.statusCode >= 300) {
          if (response.statusCode == 401 || response.statusCode == 403) {
            throw MemberApiException(
              _extractMessage(payload,
                  fallback: 'Sesi habis. Silakan login ulang.'),
            );
          }
          throw MemberApiException(
            _extractMessage(payload,
                fallback: 'Gagal mengambil daftar booking.'),
          );
        }

        final data = payload['data'];
        if (data is! Map<String, dynamic>) {
          throw const MemberApiException('Response booking tidak valid.');
        }

        final bookings = data['bookings'] as List? ?? [];
        return bookings
            .whereType<Map<String, dynamic>>()
            .map(_mapBookingData)
            .toList();
      } on MemberApiException {
        rethrow;
      } catch (error) {
        lastError = error;
      }
    }

    throw MemberApiException(
      lastError?.toString() ?? 'Gagal terhubung ke backend.',
    );
  }

  /// GET /api/v1/member/physical-progress
  Future<MemberPhysicalProgressSnapshot> getPhysicalProgress() async {
    final auth = _authenticate();
    Object? lastError;

    for (final baseUrl in BackendApiConfig.candidateBaseUrls) {
      try {
        final response = await _client.get(
          Uri.parse('$baseUrl/api/v1/member/physical-progress'),
          headers: <String, String>{
            'Accept': 'application/json',
            'Authorization': 'Bearer ${auth.token}',
          },
        ).timeout(BackendApiConfig.requestTimeout);

        final payload = _decodeJson(response.body);

        if (response.statusCode < 200 || response.statusCode >= 300) {
          if (response.statusCode == 401 || response.statusCode == 403) {
            throw MemberApiException(
              _extractMessage(payload,
                  fallback: 'Sesi habis. Silakan login ulang.'),
            );
          }
          throw MemberApiException(
            _extractMessage(payload,
                fallback: 'Gagal mengambil progres fisik.'),
          );
        }

        final data = payload['data'];
        if (data is! Map<String, dynamic>) {
          throw const MemberApiException('Response progres fisik tidak valid.');
        }

        return _mapPhysicalProgressSnapshot(data);
      } on MemberApiException {
        rethrow;
      } catch (error) {
        lastError = error;
      }
    }

    throw MemberApiException(
      lastError?.toString() ?? 'Gagal terhubung ke backend.',
    );
  }

  /// POST /api/v1/member/physical-progress (multipart).
  ///
  /// Upload checkpoint baru + foto per-pose ([photosByPose] key 'Front'/'Side'/
  /// 'Back' -> File) sesuai struktur store() backend (photos[<pose>]).
  /// [recordedAt] format YYYY-MM-DD. Setelah sukses, pemanggil sebaiknya
  /// re-fetch getPhysicalProgress() untuk data terbaru (store mengembalikan
  /// 1 record, bukan snapshot penuh).
  Future<void> createPhysicalProgress({
    required double weightKg,
    required double heightCm,
    required String recordedAt,
    String? note,
    bool isMilestone = false,
    Map<String, File> photosByPose = const {},
  }) async {
    final auth = _authenticate();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${auth.baseUrl}/api/v1/member/physical-progress'),
    );
    request.headers['Authorization'] = 'Bearer ${auth.token}';
    request.headers['Accept'] = 'application/json';

    request.fields['weight_kg'] = weightKg.toString();
    request.fields['height_cm'] = heightCm.toString();
    request.fields['recorded_at'] = recordedAt;
    request.fields['is_milestone'] = isMilestone ? '1' : '0';
    if (note != null && note.trim().isNotEmpty) {
      request.fields['note'] = note.trim();
    }

    for (final entry in photosByPose.entries) {
      request.files.add(await http.MultipartFile.fromPath(
        // Key 'photos[Front]' dst -> backend loop $photoType => $file.
        'photos[${entry.key}]',
        entry.value.path,
      ));
    }

    final streamed =
        await request.send().timeout(BackendApiConfig.requestTimeout);
    final body = await streamed.stream.bytesToString();
    final payload = _decodeJson(body);

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw MemberApiException(
        _extractMessage(payload, fallback: 'Gagal menyimpan progres fisik.'),
      );
    }
  }

  /// GET /api/v1/member/programs
  Future<List<MemberProgramData>> getPrograms() async {
    final auth = _authenticate();
    Object? lastError;

    for (final baseUrl in BackendApiConfig.candidateBaseUrls) {
      try {
        final response = await _client.get(
          Uri.parse('$baseUrl/api/v1/member/programs'),
          headers: <String, String>{
            'Accept': 'application/json',
            'Authorization': 'Bearer ${auth.token}',
          },
        ).timeout(BackendApiConfig.requestTimeout);

        final payload = _decodeJson(response.body);

        if (response.statusCode < 200 || response.statusCode >= 300) {
          if (response.statusCode == 401 || response.statusCode == 403) {
            throw MemberApiException(
              _extractMessage(payload,
                  fallback: 'Sesi habis. Silakan login ulang.'),
            );
          }
          throw MemberApiException(
            _extractMessage(payload,
                fallback: 'Gagal mengambil program latihan.'),
          );
        }

        final data = payload['data'];
        if (data is! List) {
          throw const MemberApiException('Response program tidak valid.');
        }

        return data
            .whereType<Map<String, dynamic>>()
            .map(_mapProgramData)
            .toList();
      } on MemberApiException {
        rethrow;
      } catch (error) {
        lastError = error;
      }
    }

    throw MemberApiException(
      lastError?.toString() ?? 'Gagal terhubung ke backend.',
    );
  }

  /// GET /api/v1/member/programs/{id}
  Future<MemberProgramDetailData> getProgramDetail(int programId) async {
    final auth = _authenticate();

    final response = await _sendWithBaseUrlFallback(
      (baseUrl) => _client.get(
        Uri.parse('$baseUrl/api/v1/member/programs/$programId'),
        headers: <String, String>{
          'Accept': 'application/json',
          'Authorization': 'Bearer ${auth.token}',
        },
      ).timeout(BackendApiConfig.requestTimeout),
    );

    final payload = _decodeJson(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MemberApiException(
        _extractMessage(payload, fallback: 'Gagal mengambil detail program.'),
      );
    }

    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      throw const MemberApiException('Response detail program tidak valid.');
    }

    return _mapProgramDetailData(data);
  }

  /// POST /api/v1/member/programs/{programId}/sessions/{sessionId}/ready
  Future<MemberProgramSessionData> markSessionReady({
    required int programId,
    required int sessionId,
  }) async {
    final auth = _authenticate();

    final response = await _sendWithBaseUrlFallback(
      (baseUrl) => _client.post(
        Uri.parse(
            '$baseUrl/api/v1/member/programs/$programId/sessions/$sessionId/ready'),
        headers: <String, String>{
          'Accept': 'application/json',
          'Authorization': 'Bearer ${auth.token}',
        },
      ).timeout(BackendApiConfig.requestTimeout),
    );

    final payload = _decodeJson(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MemberApiException(
        _extractMessage(payload, fallback: 'Gagal menandai sesi sebagai siap.'),
      );
    }

    // Reload program detail to get updated session data
    final programDetail = await getProgramDetail(programId);
    final updatedSession =
        programDetail.sessions.where((s) => s.id == sessionId).firstOrNull;

    if (updatedSession == null) {
      throw const MemberApiException('Sesi tidak ditemukan setelah update.');
    }

    return updatedSession;
  }

  MemberProgramDetailData _mapProgramDetailData(Map<String, dynamic> data) {
    final sessions = data['sessions'] as List? ?? [];
    final summary = data['summary'] as Map<String, dynamic>? ?? {};

    return MemberProgramDetailData(
      id: _asNullableInt(data['id']) ?? 0,
      title: _asNullableString(data['title']) ?? 'Program',
      description: _asNullableString(data['description']),
      goal: _asNullableString(data['goal']),
      status: _asNullableString(data['status']) ?? 'active',
      trainerName: _asNullableString(data['trainer_name']),
      progressPercent: _asNullableDouble(data['progress_percent']) ?? 0,
      activeSessionTitle: _asNullableString(data['active_session_title']),
      totalSessions: _asNullableInt(summary['total_sessions']) ?? 0,
      completedSessions: _asNullableInt(summary['completed_sessions']) ?? 0,
      activeSessions: _asNullableInt(summary['active_sessions']) ?? 0,
      lockedSessions: _asNullableInt(summary['locked_sessions']) ?? 0,
      sessions: sessions
          .whereType<Map<String, dynamic>>()
          .map(_mapProgramSessionData)
          .toList(),
    );
  }

  MemberProgramSessionData _mapProgramSessionData(Map<String, dynamic> data) {
    final exercises = data['exercises'] as List? ?? [];
    final reservation = data['reservation'] as Map<String, dynamic>?;

    return MemberProgramSessionData(
      id: _asNullableInt(data['id']) ?? 0,
      sequenceOrder: _asNullableInt(data['sequence_order']) ?? 0,
      title: _asNullableString(data['title']) ?? 'Sesi',
      focus: _asNullableString(data['focus']),
      durationMinutes: _asNullableInt(data['duration_minutes']),
      status: _asNullableString(data['status']) ?? 'locked',
      exercises: exercises
          .whereType<Map<String, dynamic>>()
          .map(_mapMemberExerciseData)
          .toList(),
      memberReady: data['member_ready'] == true,
      memberReadyAt: _asNullableString(data['member_ready_at']),
      bookingSessionReservationId:
          _asNullableInt(data['booking_session_reservation_id']),
      reservationDate: _asNullableString(reservation?['session_date']),
      reservationStartTime: _asNullableString(reservation?['start_time']),
      reservationEndTime: _asNullableString(reservation?['end_time']),
      reservationStatus: _asNullableString(reservation?['status']),
      hasPendingReschedule: reservation?['has_pending_reschedule'] == true,
    );
  }

  MemberExerciseData _mapMemberExerciseData(Map<String, dynamic> data) {
    return MemberExerciseData(
      id: _asNullableInt(data['id']) ?? 0,
      order: _asNullableInt(data['order']) ?? 0,
      title: _asNullableString(data['title']) ?? '-',
      subtitle: _asNullableString(data['subtitle']) ?? '-',
      cue: _asNullableString(data['cue']),
      totalSets: _asNullableInt(data['total_sets']) ?? 0,
      completedSets: _asNullableInt(data['completed_sets']) ?? 0,
      status: _asNullableString(data['status']) ?? 'pending',
    );
  }

  // ==================== MAPPERS ====================

  MemberLiveDashboardData _mapDashboardData(Map<String, dynamic> data) {
    final nextSession = data['next_session'] as Map<String, dynamic>?;

    return MemberLiveDashboardData(
      memberName: _asNullableString(data['member_name']) ?? 'Member',
      currentTier: _asNullableString(data['current_tier']) ?? 'Member Status',
      packageName: _asNullableString(data['package_name']) ?? 'Belum Ada Paket',
      validUntil: _asNullableString(data['valid_until']) ?? '-',
      remainingDays: _asNullableInt(data['remaining_days']) ?? 0,
      nextSession: nextSession != null ? _mapNextSession(nextSession) : null,
      totalPrograms: _asNullableInt(data['total_programs']) ?? 0,
      totalSessions: _asNullableInt(data['total_sessions']) ?? 0,
      hasActivePtEngagement: data['has_active_pt_engagement'] == true,
      activePtTrainerName: _asNullableString(data['active_pt_trainer_name']),
      activePtStatus: _asNullableString(data['active_pt_status']),
      profileComplete: data['profile_complete'] == true,
    );
  }

  ScheduleSession _mapNextSession(Map<String, dynamic> data) {
    return ScheduleSession(
      backendId: _asNullableInt(data['id']),
      trainerProfileId: _asNullableInt(data['trainer_profile_id']),
      trainerAvatarUrl: _asNullableString(data['trainer_avatar_url']),
      trainerDisplayPhotoPath:
          _asNullableString(data['trainer_display_photo_path']),
      clientName: _asNullableString(data['trainer_name']) ?? 'Trainer',
      timeRange:
          '${AppDateFormatter.date(_asNullableString(data['date']))} | ${_asNullableString(data['time_range']) ?? '-'}',
      location: _asNullableString(data['location']) ?? '-',
      status: _asNullableString(data['status']) ?? 'Dijadwalkan',
      rawStatus: _asNullableString(data['status'])?.toLowerCase(),
      note: _asNullableString(data['note']) ?? '',
      sessionCount: _asNullableInt(data['session_count']) ??
          ((data['session_reservations'] as List?)?.length ?? 1),
      hasProgram: data['has_program'] == true,
      programCompleted: data['program_completed'] == true,
      expiredAt: DateTime.tryParse(
        _asNullableString(data['expired_at']) ?? '',
      ),
      remainingSeconds: _asNullableInt(data['remaining_seconds']) ?? 0,
      expiryStage: _asNullableString(data['expiry_stage']),
      isExpired: _asNullableString(data['status']) == 'expired',
      isPaymentVerificationOverdue:
          data['is_payment_verification_overdue'] == true,
      paymentVerificationOverdueSeconds:
          _asNullableInt(data['payment_verification_overdue_seconds']) ?? 0,
      reservations: (data['session_reservations'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((reservation) => BookingSessionReservation(
                id: _asNullableInt(reservation['id']),
                sequenceOrder:
                    _asNullableInt(reservation['sequence_order']) ?? 0,
                sessionDate:
                    _asNullableString(reservation['session_date']) ?? '-',
                startTime: _shortTime(reservation['start_time']),
                endTime: _shortTime(reservation['end_time']),
                status: _asNullableString(reservation['status']) ?? 'reserved',
                activeRescheduleRequest:
                    reservation['active_reschedule_request']
                            is Map<String, dynamic>
                        ? _mapRescheduleRequest(
                            reservation['active_reschedule_request'])
                        : null,
              ))
          .toList(growable: false),
    );
  }

  BookingRescheduleRequestData _mapRescheduleRequest(
      Map<String, dynamic> data) {
    final old = data['old_schedule'] as Map<String, dynamic>? ?? const {};
    final proposed =
        data['proposed_schedule'] as Map<String, dynamic>? ?? const {};
    final rejection = data['rejection'] as Map<String, dynamic>?;
    return BookingRescheduleRequestData(
      id: _asNullableInt(data['id']) ?? 0,
      bookingId: _asNullableInt(data['booking_id']) ?? 0,
      reservationId: _asNullableInt(data['reservation_id']) ?? 0,
      requestedByRole: _asNullableString(data['requested_by_role']) ?? '-',
      requestedByName: _asNullableString(data['requested_by_name']) ?? '-',
      status: _asNullableString(data['status']) ?? 'pending',
      oldDate: _asNullableString(old['date']) ?? '-',
      oldStartTime: _shortTime(old['start_time']),
      oldEndTime: _shortTime(old['end_time']),
      proposedDate: _asNullableString(proposed['date']) ?? '-',
      proposedStartTime: _shortTime(proposed['start_time']),
      proposedEndTime: _shortTime(proposed['end_time']),
      reasonType: _asNullableString(data['reason_type']) ?? '-',
      reasonNote: _asNullableString(data['reason_note']),
      expiredAt: DateTime.tryParse(_asNullableString(data['expired_at']) ?? ''),
      isIncoming: data['is_incoming'] == true,
      canAccept: data['can_accept'] == true,
      canReject: data['can_reject'] == true,
      canCancel: data['can_cancel'] == true,
      rejectedReasonType: _asNullableString(rejection?['reason_type']),
      rejectedReasonNote: _asNullableString(rejection?['reason_note']),
    );
  }

  String _shortTime(dynamic value) {
    final text = _asNullableString(value) ?? '-';
    return text.length >= 5 ? text.substring(0, 5) : text;
  }

  MemberProfileData _mapProfileData(Map<String, dynamic> data) {
    // MemberProfileResource mengembalikan struktur FLAT (name/email/phone/
    // member_code/current_tier di root), dengan active_membership nested.
    final membership = data['active_membership'] as Map<String, dynamic>?;

    return MemberProfileData(
      name: _asNullableString(data['name']) ?? 'Member',
      email: _asNullableString(data['email']) ?? '-',
      phone: _asNullableString(data['phone']),
      memberCode: _asNullableString(data['member_code']),
      gender: _asNullableString(data['gender']),
      birthDate: _asNullableString(data['birth_date']),
      heightCm: _asNullableDouble(data['height_cm']),
      weightKg: _asNullableDouble(data['weight_kg']),
      fitnessGoal: _asNullableString(data['fitness_goal']),
      medicalNote: _asNullableString(data['medical_note']),
      joinedAt: _asNullableString(data['joined_at']),
      membershipTier: _asNullableString(data['current_tier']),
      membershipStatus:
          membership != null ? _asNullableString(membership['status']) : null,
      workoutsThisMonth: _asNullableInt(data['workouts_this_month']),
    );
  }

  MemberMembershipData _mapMembershipData(Map<String, dynamic> data) {
    return MemberMembershipData(
      id: _asNullableInt(data['id']) ?? 0,
      planName: _asNullableString(data['plan_name']) ?? 'Membership',
      tier: _asNullableString(data['tier']) ?? 'Standard',
      startDate: _asNullableString(data['start_date']) ?? '-',
      endDate: _asNullableString(data['end_date']) ?? '-',
      status: _asNullableString(data['status']) ?? 'unknown',
      paymentStatus: _asNullableString(data['payment_status']) ?? 'unknown',
    );
  }

  MemberTransactionData _mapTransactionData(Map<String, dynamic> data) {
    return MemberTransactionData(
      id: _asNullableInt(data['id']) ?? 0,
      referenceCode: _asNullableString(data['reference_code']) ?? '-',
      title: _asNullableString(data['title']) ?? 'Transaksi',
      paymentMethod: _asNullableString(data['payment_method']) ?? '-',
      amount: _asNullableDouble(data['amount']) ?? 0,
      status: _asNullableString(data['status']) ?? 'pending',
      paidAt: _parseDateTime(_asNullableString(data['paid_at'])),
      createdAt: _parseDateTime(_asNullableString(data['created_at'])),
    );
  }

  MemberBookingData _mapBookingData(Map<String, dynamic> data) {
    final trainer = data['trainer'] as Map<String, dynamic>?;
    return MemberBookingData(
      id: _asNullableInt(data['id']) ?? 0,
      trainerName: _asNullableString(trainer?['name']) ?? 'Trainer',
      trainerAvatarUrl: _asNullableString(trainer?['avatar_url']),
      trainerDisplayPhotoPath:
          _asNullableString(trainer?['display_photo_path']),
      sessionTitle: _asNullableString(data['session_title']) ?? 'PT Session',
      sessionDate: _asNullableString(data['session_date']) ?? '-',
      startTime: _asNullableString(data['start_time']) ?? '-',
      endTime: _asNullableString(data['end_time']) ?? '-',
      location: _asNullableString(data['location']) ?? '-',
      status: _asNullableString(data['status']) ?? 'pending',
      sessionCount: _asNullableInt(data['session_count']) ?? 1,
      pricePerSession: _asNullableDouble(data['price_per_session']),
      totalAmount: _asNullableDouble(data['total_amount']),
      reservations: (data['session_reservations'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((reservation) => MemberBookingReservationData(
                sequenceOrder:
                    _asNullableInt(reservation['sequence_order']) ?? 0,
                sessionDate:
                    _asNullableString(reservation['session_date']) ?? '-',
                startTime: _asNullableString(reservation['start_time']) ?? '-',
                endTime: _asNullableString(reservation['end_time']) ?? '-',
                status: _asNullableString(reservation['status']) ?? 'reserved',
              ))
          .toList(growable: false),
      memberNote: _asNullableString(data['member_note']),
      trainerNote: _asNullableString(data['trainer_note']),
    );
  }

  MemberProgramData _mapProgramData(Map<String, dynamic> data) {
    final progressPercent = _asNullableDouble(data['progress_percent']) ?? 0;

    return MemberProgramData(
      id: _asNullableInt(data['id']) ?? 0,
      title: _asNullableString(data['title']) ?? 'Program',
      description: _asNullableString(data['description']),
      goal: _asNullableString(data['goal']),
      status: _asNullableString(data['status']) ?? 'active',
      trainerName: _asNullableString(data['trainer_name']),
      trainerAvatarUrl: _asNullableString(data['trainer_avatar_url']),
      displayPhotoPath: _asNullableString(data['trainer_display_photo_path']),
      trainerProfileId: _asNullableInt(data['trainer_profile_id']),
      bookingId: _asNullableInt(data['booking_id']),
      progressPercent: progressPercent,
      totalSessions: _asNullableInt(data['total_sessions']) ?? 0,
      completedSessions: _asNullableInt(data['completed_sessions']) ?? 0,
      activeSessionTitle: _asNullableString(data['active_session_title']),
      startedAt: _asNullableString(data['started_at']),
      endedAt: _asNullableString(data['ended_at']),
      programCompleted: data['program_completed'] == true,
      alreadyRated: data['already_rated'] == true,
      rating: _asNullableInt(data['rating']),
      ratedAt: _asNullableString(data['rated_at']),
      canRate: data['can_rate'] == true,
      lastSessionDate: _asNullableString(data['last_session_date']),
      completedAt: _asNullableString(data['completed_at']),
      lastSessionDurationMinutes:
          _asNullableInt(data['last_session_duration_minutes']),
    );
  }

  // Mapping SESUAI response backend nyata (MemberPhysicalProgressController):
  // data.latest_progress / data.baseline_progress / data.history[] /
  // data.summary.{total_records, latest_weight_kg, latest_height_cm,
  // first_recorded_at, last_recorded_at}. Tiap entry: recorded_at, weight_kg,
  // height_cm, note, is_milestone, photos[]{photo_type, photo_url(relative)}.
  MemberPhysicalProgressSnapshot _mapPhysicalProgressSnapshot(
    Map<String, dynamic> data,
  ) {
    final latest = data['latest_progress'] as Map<String, dynamic>?;
    final baseline = data['baseline_progress'] as Map<String, dynamic>?;
    final history = data['history'] as List? ?? [];
    final summary = data['summary'] as Map<String, dynamic>? ?? const {};

    return MemberPhysicalProgressSnapshot(
      latest: latest != null ? _mapCheckpoint(latest) : null,
      baseline: baseline != null ? _mapCheckpoint(baseline) : null,
      history: history
          .whereType<Map<String, dynamic>>()
          .map(_mapCheckpoint)
          .toList(),
      totalRecords: _asNullableInt(summary['total_records']) ?? history.length,
      latestWeightKg: _asNullableDouble(summary['latest_weight_kg']),
      latestHeightCm: _asNullableDouble(summary['latest_height_cm']),
      firstRecordedAt: _parseDate(summary['first_recorded_at']),
      lastRecordedAt: _parseDate(summary['last_recorded_at']),
    );
  }

  MemberCheckpoint _mapCheckpoint(Map<String, dynamic> data) {
    final photos = data['photos'] as List? ?? [];
    return MemberCheckpoint(
      id: _asNullableInt(data['id']) ?? 0,
      recordedAt: _parseDate(data['recorded_at']),
      weightKg: _asNullableDouble(data['weight_kg']) ?? 0,
      heightCm: _asNullableDouble(data['height_cm']) ?? 0,
      note: _asNullableString(data['note']),
      isMilestone: data['is_milestone'] == true,
      photos: photos
          .whereType<Map<String, dynamic>>()
          .map((p) => MemberCheckpointPhoto(
                type: _asNullableString(p['photo_type']) ?? '-',
                path: _asNullableString(p['photo_url']) ?? '',
              ))
          .where((p) => p.path.isNotEmpty)
          .toList(),
    );
  }

  DateTime? _parseDate(dynamic value) {
    final s = _asNullableString(value);
    if (s == null) return null;
    return DateTime.tryParse(s);
  }

  // ==================== HELPERS ====================

  Map<String, dynamic> _decodeJson(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  String _extractMessage(Map<String, dynamic> payload,
      {required String fallback}) {
    final errors = payload['errors'];
    if (errors is Map<String, dynamic>) {
      for (final value in errors.values) {
        if (value is List && value.isNotEmpty) return value.first.toString();
        if (value is String && value.trim().isNotEmpty) return value;
      }
    }
    final message = payload['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message;
    }
    return fallback;
  }

  String? _asNullableString(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    return str.isEmpty ? null : str;
  }

  int? _asNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString());
  }

  double? _asNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  DateTime? _parseDateTime(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}

// ==================== DATA CLASSES ====================

class MemberLiveDashboardData {
  const MemberLiveDashboardData({
    required this.memberName,
    required this.currentTier,
    required this.packageName,
    required this.validUntil,
    required this.remainingDays,
    required this.nextSession,
    required this.totalPrograms,
    required this.totalSessions,
    this.hasActivePtEngagement = false,
    this.activePtTrainerName,
    this.activePtStatus,
    this.profileComplete = false,
  });

  final String memberName;
  final String currentTier;
  final String packageName;
  final String validUntil;
  final int remainingDays;
  final ScheduleSession? nextSession;
  final int totalPrograms;
  final int totalSessions;
  final bool hasActivePtEngagement;
  final String? activePtTrainerName;
  final String? activePtStatus;
  final bool profileComplete;
}

class MemberProfileData {
  const MemberProfileData({
    required this.name,
    required this.email,
    this.phone,
    this.memberCode,
    this.gender,
    this.birthDate,
    this.heightCm,
    this.weightKg,
    this.fitnessGoal,
    this.medicalNote,
    this.joinedAt,
    this.membershipTier,
    this.membershipStatus,
    this.workoutsThisMonth,
  });

  final String name;
  final String email;
  final String? phone;
  final String? memberCode;
  final String? gender;
  final String? birthDate;
  final double? heightCm;
  final double? weightKg;
  final String? fitnessGoal;
  final String? medicalNote;
  final String? joinedAt;
  final String? membershipTier;
  final String? membershipStatus;
  final int? workoutsThisMonth;
}

class MemberMembershipData {
  const MemberMembershipData({
    required this.id,
    required this.planName,
    required this.tier,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.paymentStatus,
  });

  final int id;
  final String planName;
  final String tier;
  final String startDate;
  final String endDate;
  final String status;
  final String paymentStatus;
}

class MemberTransactionData {
  const MemberTransactionData({
    required this.id,
    required this.referenceCode,
    required this.title,
    required this.paymentMethod,
    required this.amount,
    required this.status,
    this.paidAt,
    this.createdAt,
  });

  final int id;
  final String referenceCode;
  final String title;
  final String paymentMethod;
  final double amount;
  final String status;
  final DateTime? paidAt;
  final DateTime? createdAt;
}

class MemberBookingData {
  const MemberBookingData({
    required this.id,
    required this.trainerName,
    this.trainerAvatarUrl,
    this.trainerDisplayPhotoPath,
    required this.sessionTitle,
    required this.sessionDate,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.status,
    this.sessionCount = 1,
    this.pricePerSession,
    this.totalAmount,
    this.reservations = const [],
    this.memberNote,
    this.trainerNote,
  });

  final int id;
  final String trainerName;
  final String? trainerAvatarUrl;
  final String? trainerDisplayPhotoPath;
  final String sessionTitle;
  final String sessionDate;
  final String startTime;
  final String endTime;
  final String location;
  final String status;
  final int sessionCount;
  final double? pricePerSession;
  final double? totalAmount;
  final List<MemberBookingReservationData> reservations;
  final String? memberNote;
  final String? trainerNote;
}

class MemberBookingReservationData {
  const MemberBookingReservationData({
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

class MemberCheckpointPhoto {
  const MemberCheckpointPhoto({required this.type, required this.path});

  /// Front / Side / Back
  final String type;

  /// RELATIVE PATH (mis. "member-progress/x.jpg"). Flutter rangkai baseUrl.
  final String path;
}

class MemberCheckpoint {
  const MemberCheckpoint({
    required this.id,
    required this.recordedAt,
    required this.weightKg,
    required this.heightCm,
    this.note,
    this.isMilestone = false,
    this.photos = const [],
  });

  final int id;
  final DateTime? recordedAt;
  final double weightKg;
  final double heightCm;
  final String? note;
  final bool isMilestone;
  final List<MemberCheckpointPhoto> photos;
}

class MemberPhysicalProgressSnapshot {
  const MemberPhysicalProgressSnapshot({
    this.latest,
    this.baseline,
    this.history = const [],
    this.totalRecords = 0,
    this.latestWeightKg,
    this.latestHeightCm,
    this.firstRecordedAt,
    this.lastRecordedAt,
  });

  final MemberCheckpoint? latest;
  final MemberCheckpoint? baseline;
  final List<MemberCheckpoint> history;
  final int totalRecords;
  final double? latestWeightKg;
  final double? latestHeightCm;
  final DateTime? firstRecordedAt;
  final DateTime? lastRecordedAt;

  bool get hasCheckpoint => totalRecords > 0 || history.isNotEmpty;
}

class MemberProgramData {
  const MemberProgramData({
    required this.id,
    required this.title,
    this.description,
    this.goal,
    required this.status,
    this.trainerName,
    this.trainerAvatarUrl,
    this.displayPhotoPath,
    this.trainerProfileId,
    this.bookingId,
    required this.progressPercent,
    required this.totalSessions,
    required this.completedSessions,
    this.activeSessionTitle,
    this.startedAt,
    this.endedAt,
    this.programCompleted = false,
    this.alreadyRated = false,
    this.rating,
    this.ratedAt,
    this.canRate = false,
    this.lastSessionDate,
    this.completedAt,
    this.lastSessionDurationMinutes,
  });

  final int id;
  final String title;
  final String? description;
  final String? goal;
  final String status;
  final String? trainerName;
  final String? trainerAvatarUrl;
  final String? displayPhotoPath;
  final int? trainerProfileId;
  final int? bookingId;
  final double progressPercent;
  final int totalSessions;
  final int completedSessions;
  final String? activeSessionTitle;
  final String? startedAt;
  final String? endedAt;
  final bool programCompleted;
  final bool alreadyRated;
  final int? rating;
  final String? ratedAt;
  final bool canRate;
  final String? lastSessionDate;
  final String? completedAt;
  final int? lastSessionDurationMinutes;
}

class MemberProgramDetailData {
  const MemberProgramDetailData({
    required this.id,
    required this.title,
    this.description,
    this.goal,
    required this.status,
    this.trainerName,
    required this.progressPercent,
    this.activeSessionTitle,
    required this.totalSessions,
    required this.completedSessions,
    required this.activeSessions,
    required this.lockedSessions,
    required this.sessions,
  });

  final int id;
  final String title;
  final String? description;
  final String? goal;
  final String status;
  final String? trainerName;
  final double progressPercent;
  final String? activeSessionTitle;
  final int totalSessions;
  final int completedSessions;
  final int activeSessions;
  final int lockedSessions;
  final List<MemberProgramSessionData> sessions;
}

class MemberProgramSessionData {
  const MemberProgramSessionData({
    required this.id,
    required this.sequenceOrder,
    required this.title,
    this.focus,
    this.durationMinutes,
    required this.status,
    required this.exercises,
    this.memberReady = false,
    this.memberReadyAt,
    this.bookingSessionReservationId,
    this.reservationDate,
    this.reservationStartTime,
    this.reservationEndTime,
    this.reservationStatus,
    this.hasPendingReschedule = false,
  });

  final int id;
  final int sequenceOrder;
  final String title;
  final String? focus;
  final int? durationMinutes;
  final String status;
  final List<MemberExerciseData> exercises;
  final bool memberReady;
  final String? memberReadyAt;
  final int? bookingSessionReservationId;
  final String? reservationDate;
  final String? reservationStartTime;
  final String? reservationEndTime;
  final String? reservationStatus;
  final bool hasPendingReschedule;

  bool get isCompleted => status == 'completed';
  bool get isActive => status == 'active';
  bool get isLocked => status == 'locked' || status == 'upcoming';
}

List<MemberProgramSessionData> sortMemberProgramSessionsBySchedule(
  Iterable<MemberProgramSessionData> sessions,
) {
  final sorted = List<MemberProgramSessionData>.of(sessions);
  sorted.sort((a, b) {
    final aKey = _programScheduleKey(
      a.reservationDate,
      a.reservationStartTime,
      a.reservationEndTime,
    );
    final bKey = _programScheduleKey(
      b.reservationDate,
      b.reservationStartTime,
      b.reservationEndTime,
    );
    if (aKey == null && bKey != null) return 1;
    if (aKey != null && bKey == null) return -1;
    final scheduleComparison = (aKey ?? '').compareTo(bKey ?? '');
    if (scheduleComparison != 0) return scheduleComparison;
    final sequenceComparison = a.sequenceOrder.compareTo(b.sequenceOrder);
    return sequenceComparison != 0 ? sequenceComparison : a.id.compareTo(b.id);
  });
  return sorted;
}

String? _programScheduleKey(
  String? date,
  String? startTime,
  String? endTime,
) {
  if (date == null ||
      date.isEmpty ||
      startTime == null ||
      startTime.isEmpty ||
      endTime == null ||
      endTime.isEmpty) {
    return null;
  }
  final start = startTime.length >= 8 ? startTime.substring(0, 8) : startTime;
  final end = endTime.length >= 8 ? endTime.substring(0, 8) : endTime;
  return '$date $start $end';
}

class MemberExerciseData {
  const MemberExerciseData({
    required this.id,
    required this.order,
    required this.title,
    required this.subtitle,
    this.cue,
    required this.totalSets,
    required this.completedSets,
    required this.status,
  });

  final int id;
  final int order;
  final String title;
  final String subtitle;
  final String? cue;
  final int totalSets;
  final int completedSets;
  final String status;

  bool get isCompleted => status == 'completed';
  bool get isFullyCompleted => completedSets >= totalSets && totalSets > 0;
}

class MemberApiException implements Exception {
  const MemberApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
