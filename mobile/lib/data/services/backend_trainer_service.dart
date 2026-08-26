import 'dart:async';
import 'dart:convert';

import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:egg_gym/core/utils/trainer_tier.dart';
import 'package:egg_gym/data/services/backend_api_config.dart';
import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:egg_gym/domain/entities/trainer_schedule.dart';
import 'package:egg_gym/domain/entities/trainer_schedule_date.dart';
import 'package:http/http.dart' as http;

class BackendTrainerService {
  BackendTrainerService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  Future<TrainerSchedule> getTrainerSchedule() async {
    final auth = _authenticate();
    final response = await _client.get(
      Uri.parse('${auth.baseUrl}/api/v1/trainer/schedule'),
      headers: <String, String>{
        'Accept': 'application/json',
        'Authorization': 'Bearer ${auth.token}',
      },
    ).timeout(BackendApiConfig.requestTimeout);
    final payload = _decodeJson(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TrainerApiException(
        _extractMessage(payload, fallback: 'Gagal mengambil jadwal aktif.'),
      );
    }

    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      throw const TrainerApiException('Response jadwal aktif tidak valid.');
    }
    try {
      return TrainerSchedule.fromJson(data);
    } on FormatException catch (error) {
      throw TrainerApiException(error.message);
    }
  }

  Future<TrainerSchedule> updateTrainerSchedule(
    TrainerSchedule schedule,
  ) async {
    final auth = _authenticate();
    final response = await _client
        .put(
          Uri.parse('${auth.baseUrl}/api/v1/trainer/schedule'),
          headers: <String, String>{
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${auth.token}',
          },
          body: jsonEncode(<String, dynamic>{
            'days': schedule.days
                .map((day) => day.toJson())
                .toList(growable: false),
          }),
        )
        .timeout(BackendApiConfig.requestTimeout);
    final payload = _decodeJson(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TrainerApiException(
        _extractMessage(payload, fallback: 'Gagal menyimpan jadwal aktif.'),
      );
    }

    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      throw const TrainerApiException('Response jadwal aktif tidak valid.');
    }
    try {
      return TrainerSchedule.fromJson(data);
    } on FormatException catch (error) {
      throw TrainerApiException(error.message);
    }
  }

  Future<TrainerScheduleMonth> getTrainerScheduleMonth([String? month]) async {
    final auth = _authenticate();
    final uri =
        Uri.parse('${auth.baseUrl}/api/v1/trainer/schedule-dates').replace(
      queryParameters: month == null ? null : <String, String>{'month': month},
    );
    final response = await _client.get(uri, headers: <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer ${auth.token}',
    }).timeout(BackendApiConfig.requestTimeout);
    final payload = _decodeJson(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TrainerApiException(_extractMessage(
        payload,
        fallback: 'Gagal mengambil jadwal per tanggal.',
      ));
    }
    return _parseScheduleMonth(payload);
  }

  Future<TrainerScheduleDate> updateTrainerScheduleDate({
    required String date,
    required String mode,
    required int lockVersion,
    List<TrainerScheduleDateShift> shifts = const [],
  }) async {
    final auth = _authenticate();
    final response = await _client
        .put(
          Uri.parse('${auth.baseUrl}/api/v1/trainer/schedule-dates/$date'),
          headers: <String, String>{
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${auth.token}',
          },
          body: jsonEncode(<String, dynamic>{
            'mode': mode,
            'lock_version': lockVersion,
            'shifts': shifts.map((shift) => shift.toJson()).toList(),
          }),
        )
        .timeout(BackendApiConfig.requestTimeout);
    final payload = _decodeJson(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TrainerApiException(_scheduleDateFailure(
        response.statusCode,
        payload,
        fallback: 'Gagal mengubah jadwal tanggal.',
      ));
    }
    return _parseScheduleDate(payload);
  }

  Future<TrainerScheduleDate> resetTrainerScheduleDate({
    required String date,
    required int lockVersion,
  }) async {
    final auth = _authenticate();
    final response = await _client
        .post(
          Uri.parse(
            '${auth.baseUrl}/api/v1/trainer/schedule-dates/$date/reset',
          ),
          headers: <String, String>{
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${auth.token}',
          },
          body: jsonEncode(<String, dynamic>{'lock_version': lockVersion}),
        )
        .timeout(BackendApiConfig.requestTimeout);
    final payload = _decodeJson(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TrainerApiException(_scheduleDateFailure(
        response.statusCode,
        payload,
        fallback: 'Gagal mereset jadwal tanggal.',
      ));
    }
    return _parseScheduleDate(payload);
  }

  TrainerScheduleMonth _parseScheduleMonth(Map<String, dynamic> payload) {
    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      throw const TrainerApiException(
        'Response jadwal per tanggal tidak valid.',
      );
    }
    try {
      return TrainerScheduleMonth.fromJson(data);
    } on FormatException catch (error) {
      throw TrainerApiException(error.message);
    }
  }

  TrainerScheduleDate _parseScheduleDate(Map<String, dynamic> payload) {
    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      throw const TrainerApiException(
        'Response perubahan jadwal tanggal tidak valid.',
      );
    }
    try {
      return TrainerScheduleDate.fromJson(data);
    } on FormatException catch (error) {
      throw TrainerApiException(error.message);
    }
  }

  String _scheduleDateFailure(
    int statusCode,
    Map<String, dynamic> payload, {
    required String fallback,
  }) {
    final statusFallback = switch (statusCode) {
      409 => 'Jadwal telah berubah. Muat ulang sebelum mencoba lagi.',
      422 => 'Perubahan jadwal tidak valid.',
      _ => fallback,
    };
    return _extractMessage(payload, fallback: statusFallback);
  }

  Future<TrainerLiveDashboardOverview> getDashboard() async {
    final auth = _authenticate();

    final response = await _client.get(
      Uri.parse('${auth.baseUrl}/api/v1/trainer/dashboard'),
      headers: <String, String>{
        'Accept': 'application/json',
        'Authorization': 'Bearer ${auth.token}',
      },
    ).timeout(BackendApiConfig.requestTimeout);

    final payload = _decodeJson(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TrainerApiException(
        _extractMessage(payload,
            fallback: 'Gagal mengambil dashboard trainer.'),
      );
    }

    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      throw const TrainerApiException(
          'Response dashboard trainer tidak valid.');
    }

    final agenda = data['today_agenda'];
    final agendaItems = agenda is List
        ? agenda
            .whereType<Map<String, dynamic>>()
            .map(_mapScheduleSession)
            .toList()
        : const <ScheduleSession>[];
    final verificationRequests = data['payment_verification_requests'];
    final verificationItems = verificationRequests is List
        ? verificationRequests
            .whereType<Map<String, dynamic>>()
            .map(_mapScheduleSession)
            .toList()
        : const <ScheduleSession>[];

    return TrainerLiveDashboardOverview(
      trainerName:
          _asNullableString(data['trainer_name']) ?? auth.name ?? 'Trainer',
      tier: mapTrainerTier(tier: data['tier'], legacyBadge: data['badge']),
      activeClients: _asNullableInt(data['active_clients']) ?? 0,
      todaySessions: _asNullableInt(data['today_sessions']) ?? 0,
      rating: _asNullableDouble(data['rating']) ?? 0,
      todayAgenda: agendaItems,
      paymentVerificationRequests: verificationItems,
      hasActiveSchedule: data['has_active_schedule'] == true,
    );
  }

  Future<List<ScheduleSession>> getScheduleSessions() async {
    final auth = _authenticate();

    final response = await _client.get(
      Uri.parse('${auth.baseUrl}/api/v1/trainer/sessions'),
      headers: <String, String>{
        'Accept': 'application/json',
        'Authorization': 'Bearer ${auth.token}',
      },
    ).timeout(BackendApiConfig.requestTimeout);

    final payload = _decodeJson(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TrainerApiException(
        _extractMessage(payload, fallback: 'Gagal mengambil jadwal trainer.'),
      );
    }

    final data = payload['data'];
    if (data is! List) {
      throw const TrainerApiException('Response jadwal trainer tidak valid.');
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(_mapScheduleSession)
        .toList();
  }

  Future<ScheduleSession> getBookingDetail(int bookingId) async {
    final auth = _authenticate();

    final response = await _client.get(
      Uri.parse('${auth.baseUrl}/api/v1/trainer/sessions/$bookingId'),
      headers: <String, String>{
        'Accept': 'application/json',
        'Authorization': 'Bearer ${auth.token}',
      },
    ).timeout(BackendApiConfig.requestTimeout);

    final payload = _decodeJson(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TrainerApiException(
        _extractMessage(payload, fallback: 'Gagal mengambil detail booking.'),
      );
    }

    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      throw const TrainerApiException(
        'Response detail booking tidak valid.',
      );
    }
    return _mapScheduleSession(data);
  }

  Future<List<ClientSummary>> getClients() async {
    final auth = _authenticate();

    final response = await _client.get(
      Uri.parse('${auth.baseUrl}/api/v1/trainer/clients'),
      headers: <String, String>{
        'Accept': 'application/json',
        'Authorization': 'Bearer ${auth.token}',
      },
    ).timeout(BackendApiConfig.requestTimeout);

    final payload = _decodeJson(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TrainerApiException(
        _extractMessage(payload,
            fallback: 'Gagal mengambil daftar klien trainer.'),
      );
    }

    final data = payload['data'];
    if (data is! List) {
      throw const TrainerApiException('Response klien trainer tidak valid.');
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => ClientSummary(
            backendId: _asNullableInt(item['id']),
            memberCode: _asNullableString(item['member_code']),
            name: _asNullableString(item['name']) ?? 'Klien Trainer',
            goal: _asNullableString(item['goal']) ?? 'General fitness',
            progressLabel: _asNullableString(item['progress_label']) ??
                'Belum ada progres',
            nextSession: _asNullableString(item['next_session']) ??
                'Belum ada sesi berikutnya',
            avatarUrl: _asNullableString(item['avatar_url']),
          ),
        )
        .toList();
  }

  Future<TrainerClientDetailSnapshot> getClientDetail(
      int memberProfileId) async {
    final auth = _authenticate();

    final response = await _client.get(
      Uri.parse('${auth.baseUrl}/api/v1/trainer/clients/$memberProfileId'),
      headers: <String, String>{
        'Accept': 'application/json',
        'Authorization': 'Bearer ${auth.token}',
      },
    ).timeout(BackendApiConfig.requestTimeout);

    final payload = _decodeJson(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TrainerApiException(
        _extractMessage(payload,
            fallback: 'Gagal mengambil detail klien trainer.'),
      );
    }

    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      throw const TrainerApiException(
          'Response detail klien trainer tidak valid.');
    }

    final summary = data['summary'];
    final summaryMap =
        summary is Map<String, dynamic> ? summary : const <String, dynamic>{};
    final activeMembership = data['active_membership'];
    final membershipMap = activeMembership is Map<String, dynamic>
        ? activeMembership
        : const <String, dynamic>{};
    final nextSession = data['next_session'];
    final recentSessions = data['recent_sessions'];
    final activeProgram = data['active_program'];
    final activeProgramMap = activeProgram is Map<String, dynamic>
        ? activeProgram
        : const <String, dynamic>{};
    final activeProgramSession = activeProgramMap['active_session'];
    final activeProgramSessionMap = activeProgramSession is Map<String, dynamic>
        ? activeProgramSession
        : const <String, dynamic>{};

    return TrainerClientDetailSnapshot(
      id: _asNullableInt(data['id']) ?? memberProfileId,
      memberCode: _asNullableString(data['member_code']),
      name: _asNullableString(data['name']) ?? 'Klien Trainer',
      avatarUrl: _asNullableString(data['avatar_url']),
      email: _asNullableString(data['email']),
      phone: _asNullableString(data['phone']),
      status: _asNullableString(data['status']),
      goal: _asNullableString(data['goal']),
      gender: _asNullableString(data['gender']),
      birthDate: _parseDateTime(data['birth_date']),
      heightCm: _asNullableDouble(data['height_cm']),
      weightKg: _asNullableDouble(data['weight_kg']),
      medicalNote: _asNullableString(data['medical_note']),
      joinedAt: _parseDateTime(data['joined_at']),
      totalSessions: _asNullableInt(summaryMap['total_sessions']) ?? 0,
      confirmedSessions: _asNullableInt(summaryMap['confirmed_sessions']) ?? 0,
      pendingSessions: _asNullableInt(summaryMap['pending_sessions']) ?? 0,
      rescheduledSessions:
          _asNullableInt(summaryMap['rescheduled_sessions']) ?? 0,
      activeMembershipPlanName: _asNullableString(membershipMap['plan_name']),
      activeMembershipStartDate: _parseDateTime(membershipMap['start_date']),
      activeMembershipEndDate: _parseDateTime(membershipMap['end_date']),
      activeProgramId: _asNullableInt(activeProgramMap['id']),
      activeProgramTitle: _asNullableString(activeProgramMap['title']),
      activeProgramStatus: _asNullableString(activeProgramMap['status']),
      activeProgramGoal: _asNullableString(activeProgramMap['goal']),
      activeProgramSessionId:
          _asNullableInt(activeProgramMap['training_program_session_id']),
      activeProgramTotalSessions:
          _asNullableInt(activeProgramMap['total_sessions']) ?? 0,
      activeProgramCompletedSessions:
          _asNullableInt(activeProgramMap['completed_sessions']) ?? 0,
      activeProgramProgressPercent:
          _asNullableInt(activeProgramMap['progress_percent']) ?? 0,
      activeProgramSession: activeProgramSessionMap.isNotEmpty
          ? TrainerProgramSessionSummary(
              id: _asNullableInt(activeProgramSessionMap['id']) ?? 0,
              sequenceOrder:
                  _asNullableInt(activeProgramSessionMap['sequence_order']) ??
                      0,
              title: _asNullableString(activeProgramSessionMap['title']) ??
                  'Sesi Program',
              status: _asNullableString(activeProgramSessionMap['status']) ??
                  'active',
              memberReady: activeProgramSessionMap['member_ready'] == true,
              memberReadyAt:
                  _asNullableString(activeProgramSessionMap['member_ready_at']),
            )
          : null,
      nextSessionLabel: _asNullableString(data['next_session_label']),
      nextSession: nextSession is Map<String, dynamic>
          ? _mapClientSessionSnapshot(nextSession)
          : null,
      recentSessions: recentSessions is List
          ? recentSessions
              .whereType<Map<String, dynamic>>()
              .map(_mapClientSessionSnapshot)
              .toList()
          : const <TrainerClientSessionSnapshot>[],
    );
  }

  Future<ScheduleSession> confirmBooking(int bookingId) async {
    final auth = _authenticate();

    final response = await _client.post(
      Uri.parse('${auth.baseUrl}/api/v1/trainer/sessions/$bookingId/confirm'),
      headers: <String, String>{
        'Accept': 'application/json',
        'Authorization': 'Bearer ${auth.token}',
      },
    ).timeout(BackendApiConfig.requestTimeout);

    final payload = _decodeJson(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TrainerApiException(
        _extractMessage(payload, fallback: 'Gagal mengkonfirmasi booking.'),
      );
    }

    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      throw const TrainerApiException(
          'Response konfirmasi booking tidak valid.');
    }

    return _mapScheduleSession(data);
  }

  Future<ScheduleSession> rejectBooking(int bookingId) async {
    final auth = _authenticate();

    final response = await _client.post(
      Uri.parse('${auth.baseUrl}/api/v1/trainer/sessions/$bookingId/reject'),
      headers: <String, String>{
        'Accept': 'application/json',
        'Authorization': 'Bearer ${auth.token}',
      },
    ).timeout(BackendApiConfig.requestTimeout);

    final payload = _decodeJson(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TrainerApiException(
        _extractMessage(payload, fallback: 'Gagal menolak booking.'),
      );
    }

    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      throw const TrainerApiException('Response tolak booking tidak valid.');
    }

    return _mapScheduleSession(data);
  }

  Future<ScheduleSession> rescheduleSession(
    int bookingId, {
    required String sessionDate,
    required String startTime,
    required String endTime,
    String reason = 'Penyesuaian jadwal oleh trainer',
  }) async {
    final auth = _authenticate();

    final response = await _client
        .post(
          Uri.parse(
            '${auth.baseUrl}/api/v1/trainer/sessions/$bookingId/reschedule',
          ),
          headers: <String, String>{
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${auth.token}',
          },
          body: jsonEncode(<String, dynamic>{
            'new_session_date': sessionDate,
            'new_start_time': startTime,
            'new_end_time': endTime,
            'reason': reason,
          }),
        )
        .timeout(BackendApiConfig.requestTimeout);

    final payload = _decodeJson(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TrainerApiException(
        _extractMessage(payload, fallback: 'Gagal menjadwalkan ulang sesi.'),
      );
    }

    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      throw const TrainerApiException(
        'Response reschedule sesi tidak valid.',
      );
    }
    return _mapScheduleSession(data);
  }

  Future<BookingRescheduleRequestData> createRescheduleRequest(
    int bookingId,
    int reservationId, {
    required String sessionDate,
    required String startTime,
    required String endTime,
    required String reasonType,
    String? reasonNote,
    bool asMember = false,
  }) async {
    final auth = _authenticateRescheduleRole(asMember: asMember);
    final prefix = asMember ? 'member/bookings' : 'trainer/sessions';
    final response = await _client
        .post(
          Uri.parse(
            '${auth.baseUrl}/api/v1/$prefix/$bookingId/reservations/$reservationId/reschedule-requests',
          ),
          headers: <String, String>{
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${auth.token}',
          },
          body: jsonEncode(<String, dynamic>{
            'proposed_session_date': sessionDate,
            'proposed_start_time': startTime,
            'proposed_end_time': endTime,
            'reason_type': reasonType,
            if (reasonNote != null && reasonNote.trim().isNotEmpty)
              'reason_note': reasonNote.trim(),
          }),
        )
        .timeout(BackendApiConfig.requestTimeout);
    final payload = _decodeJson(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TrainerApiException(
        _extractMessage(payload,
            fallback: 'Gagal mengirim permintaan reschedule.'),
      );
    }
    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      throw const TrainerApiException(
        'Response permintaan reschedule tidak valid.',
      );
    }
    return _mapRescheduleRequest(data);
  }

  Future<BookingRescheduleRequestData> respondRescheduleRequest(
    int requestId, {
    required String action,
    bool asMember = false,
    String? rejectionType,
    String? rejectionNote,
  }) async {
    final auth = _authenticateRescheduleRole(asMember: asMember);
    final role = asMember ? 'member' : 'trainer';
    final response = await _client
        .post(
          Uri.parse(
              '${auth.baseUrl}/api/v1/$role/reschedule-requests/$requestId/$action'),
          headers: <String, String>{
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${auth.token}',
          },
          body: jsonEncode(<String, dynamic>{
            if (rejectionType != null) 'rejected_reason_type': rejectionType,
            if (rejectionNote != null && rejectionNote.trim().isNotEmpty)
              'rejected_reason_note': rejectionNote.trim(),
          }),
        )
        .timeout(BackendApiConfig.requestTimeout);
    final payload = _decodeJson(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TrainerApiException(
        _extractMessage(payload, fallback: 'Gagal memproses reschedule.'),
      );
    }
    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      throw const TrainerApiException('Response reschedule tidak valid.');
    }
    return _mapRescheduleRequest(data);
  }

  Future<void> closeProgramEarly(int programId, String reason) async {
    final auth = _authenticate();
    final response = await _client
        .post(
          Uri.parse(
              '${auth.baseUrl}/api/v1/trainer/programs/$programId/close-early'),
          headers: <String, String>{
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${auth.token}',
          },
          body: jsonEncode({'reason': reason}),
        )
        .timeout(BackendApiConfig.requestTimeout);
    final payload = _decodeJson(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TrainerApiException(
        _extractMessage(payload, fallback: 'Gagal menutup program lebih awal.'),
      );
    }
  }

  Future<ScheduleSession> verifyPayment(
    int bookingId, {
    required bool verified,
    String? rejectionNote,
  }) async {
    final auth = _authenticate();

    final response = await _client
        .post(
          Uri.parse(
              '${auth.baseUrl}/api/v1/trainer/sessions/$bookingId/verify-payment'),
          headers: <String, String>{
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${auth.token}',
          },
          body: jsonEncode(<String, dynamic>{
            'verified': verified,
            if (rejectionNote != null && rejectionNote.trim().isNotEmpty)
              'rejection_note': rejectionNote.trim(),
          }),
        )
        .timeout(BackendApiConfig.requestTimeout);

    final payload = _decodeJson(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TrainerApiException(
        _extractMessage(payload,
            fallback: verified
                ? 'Gagal memverifikasi pembayaran.'
                : 'Gagal menolak pembayaran.'),
      );
    }

    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      throw const TrainerApiException(
          'Response verifikasi pembayaran tidak valid.');
    }

    return _mapScheduleSession(data);
  }

  Future<TrainerProgramDetailData> getProgramDetail(int programId) async {
    final auth = _authenticate();

    final response = await _client.get(
      Uri.parse('${auth.baseUrl}/api/v1/trainer/programs/$programId'),
      headers: <String, String>{
        'Accept': 'application/json',
        'Authorization': 'Bearer ${auth.token}',
      },
    ).timeout(BackendApiConfig.requestTimeout);

    final payload = _decodeJson(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TrainerApiException(
        _extractMessage(payload, fallback: 'Gagal mengambil detail program.'),
      );
    }

    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      throw const TrainerApiException('Response detail program tidak valid.');
    }

    return _mapProgramDetail(data);
  }

  TrainerProgramDetailData _mapProgramDetail(Map<String, dynamic> data) {
    final sessions = data['sessions'] as List? ?? [];
    final summary = data['summary'] as Map<String, dynamic>? ?? {};
    final member = data['member'] as Map<String, dynamic>? ?? {};

    return TrainerProgramDetailData(
      id: _asNullableInt(data['id']) ?? 0,
      title: _asNullableString(data['title']) ?? 'Program',
      description: _asNullableString(data['description']),
      goal: _asNullableString(data['goal']),
      status: _asNullableString(data['status']) ?? 'active',
      memberName: _asNullableString(member['name']),
      totalSessions: _asNullableInt(summary['total_sessions']) ?? 0,
      totalDurationMinutes:
          _asNullableInt(summary['total_duration_minutes']) ?? 0,
      sessions: sessions
          .whereType<Map<String, dynamic>>()
          .map(_mapProgramSessionDetail)
          .toList(),
    );
  }

  TrainerProgramSessionDetailData _mapProgramSessionDetail(
      Map<String, dynamic> data) {
    final exercises = data['exercises'] as List? ?? [];
    final reservation = data['reservation'] as Map<String, dynamic>?;

    return TrainerProgramSessionDetailData(
      id: _asNullableInt(data['id']) ?? 0,
      sequenceOrder: _asNullableInt(data['sequence_order']) ?? 0,
      title: _asNullableString(data['title']) ?? 'Sesi',
      focus: _asNullableString(data['focus']),
      durationMinutes: _asNullableInt(data['duration_minutes']),
      status: _asNullableString(data['status']) ?? 'locked',
      memberReady: data['member_ready'] == true,
      bookingSessionReservationId:
          _asNullableInt(data['booking_session_reservation_id']),
      reservationDate: _asNullableString(reservation?['session_date']),
      reservationStartTime: _asNullableString(reservation?['start_time']),
      reservationEndTime: _asNullableString(reservation?['end_time']),
      reservationStatus: _asNullableString(reservation?['status']),
      hasPendingReschedule: reservation?['has_pending_reschedule'] == true,
      exercises: exercises
          .whereType<Map<String, dynamic>>()
          .map(_mapProgramExerciseDetail)
          .toList(),
    );
  }

  TrainerProgramExerciseDetailData _mapProgramExerciseDetail(
      Map<String, dynamic> data) {
    final sets = _asNullableInt(data['sets']) ?? 0;
    final reps = _asNullableInt(data['reps']) ?? 0;
    final customName = _asNullableString(data['custom_name']);
    final targetMuscle = _asNullableString(data['custom_target_muscle']);
    final title = customName ?? _asNullableString(data['title']) ?? '-';
    final completedSets = _asNullableInt(data['completed_sets']) ?? 0;
    final totalSets = _asNullableInt(data['total_sets']) ?? sets;
    final subtitle = '$totalSets set x $reps reps';

    return TrainerProgramExerciseDetailData(
      id: _asNullableInt(data['id']) ?? 0,
      order: _asNullableInt(data['sequence_order']) ?? 0,
      title: title,
      subtitle: subtitle,
      targetMuscle: targetMuscle,
      equipmentId: _asNullableInt(data['equipment_id']),
      equipmentName: _asNullableString(data['equipment_name']),
      equipmentMovementId: _asNullableInt(data['gym_equipment_movement_id']),
      cue: _asNullableString(data['cue_text']),
      totalSets: totalSets,
      completedSets: completedSets,
      status: _asNullableString(data['status']) ?? 'pending',
    );
  }

  Future<TrainerSessionProgressSnapshot> getProgramSessionProgress(
    int trainingProgramSessionId,
  ) async {
    final auth = _authenticate();

    final response = await _client.get(
      Uri.parse(
        '${auth.baseUrl}/api/v1/trainer/program-sessions/$trainingProgramSessionId/progress',
      ),
      headers: <String, String>{
        'Accept': 'application/json',
        'Authorization': 'Bearer ${auth.token}',
      },
    ).timeout(BackendApiConfig.requestTimeout);

    final payload = _decodeJson(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TrainerApiException(
        _extractMessage(payload,
            fallback: 'Gagal mengambil progres sesi trainer.'),
      );
    }

    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      throw const TrainerApiException(
          'Response progres sesi trainer tidak valid.');
    }

    return _mapProgramSessionProgress(data);
  }

  Future<TrainerSessionProgressSnapshot> updateProgramSessionProgress({
    required int trainingProgramSessionId,
    required int exerciseId,
    required int completedSets,
    String? status,
    String? trainerNote,
  }) async {
    final auth = _authenticate();

    final body = <String, dynamic>{
      'exercise_id': exerciseId,
      'completed_sets': completedSets,
      if (status != null) 'status': status,
      if (trainerNote != null && trainerNote.trim().isNotEmpty)
        'trainer_note': trainerNote.trim(),
    };

    final response = await _client
        .post(
          Uri.parse(
            '${auth.baseUrl}/api/v1/trainer/program-sessions/$trainingProgramSessionId/progress',
          ),
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
      throw TrainerApiException(
        _extractMessage(payload,
            fallback: 'Gagal memperbarui progres sesi trainer.'),
      );
    }

    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      throw const TrainerApiException(
          'Response update progres sesi trainer tidak valid.');
    }

    return _mapProgramSessionProgress(data);
  }

  Future<TrainerSessionProgressSnapshot> completeProgramSessionProgress(
    int trainingProgramSessionId,
  ) async {
    final auth = _authenticate();

    final response = await _client.post(
      Uri.parse(
        '${auth.baseUrl}/api/v1/trainer/program-sessions/$trainingProgramSessionId/complete',
      ),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer ${auth.token}',
      },
    ).timeout(BackendApiConfig.requestTimeout);

    final payload = _decodeJson(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TrainerApiException(
        _extractMessage(payload, fallback: 'Gagal menyelesaikan sesi trainer.'),
      );
    }

    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      throw const TrainerApiException(
          'Response complete sesi trainer tidak valid.');
    }

    return _mapProgramSessionProgress(data);
  }

  AppAuthenticatedSession _authenticate() {
    final session = AppSessionService.instance.currentSession;

    if (session == null) {
      throw const TrainerApiException(
        'Masuk sebagai trainer dulu sebelum membuka dashboard trainer live.',
      );
    }

    if (session.role != 'trainer') {
      throw const TrainerApiException(
        'Dashboard trainer live hanya tersedia untuk akun trainer yang sedang login.',
      );
    }

    return session;
  }

  AppAuthenticatedSession _authenticateRescheduleRole({
    required bool asMember,
  }) {
    final session = AppSessionService.instance.currentSession;
    if (session == null) {
      throw const TrainerApiException(
        'Silakan masuk terlebih dahulu untuk memproses reschedule.',
      );
    }
    final expectedRole = asMember ? 'member' : 'trainer';
    if (session.role != expectedRole) {
      throw TrainerApiException(
        asMember
            ? 'Permintaan reschedule member hanya tersedia untuk akun member.'
            : 'Permintaan reschedule trainer hanya tersedia untuk akun trainer.',
      );
    }

    return session;
  }

  Map<String, dynamic> _decodeJson(String rawBody) {
    if (rawBody.isEmpty) {
      return const <String, dynamic>{};
    }

    final decoded = jsonDecode(rawBody);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw const TrainerApiException(
        'Response backend trainer bukan JSON yang valid.');
  }

  String _extractMessage(
    Map<String, dynamic> payload, {
    required String fallback,
  }) {
    final message = _asNullableString(payload['message']);
    if (message != null && message.isNotEmpty) {
      return message;
    }

    final errors = payload['errors'];
    if (errors is Map<String, dynamic>) {
      for (final value in errors.values) {
        if (value is List && value.isNotEmpty) {
          return value.first.toString();
        }

        if (value is String && value.isNotEmpty) {
          return value;
        }
      }
    }

    return fallback;
  }

  ScheduleSession _mapScheduleSession(Map<String, dynamic> item) {
    final member = item['member'];
    final memberMap =
        member is Map<String, dynamic> ? member : const <String, dynamic>{};
    final activeMembership = item['active_membership'];
    final activeMembershipMap = activeMembership is Map<String, dynamic>
        ? activeMembership
        : const <String, dynamic>{};
    final sessionDate = _asNullableString(item['session_date']);
    final startTime = _formatTime(item['start_time']);
    final endTime = _formatTime(item['end_time']);
    final timeRange = [
      if (sessionDate != null) _formatDate(sessionDate),
      if (startTime != null && endTime != null) '$startTime - $endTime',
    ].join(' | ');

    return ScheduleSession(
      backendId: _asNullableInt(item['id']),
      bookingNumber: _asNullableString(item['booking_number']),
      createdAt: _parseDateTime(item['created_at']),
      trainerProfileId: _asNullableInt(item['trainer_profile_id']) ??
          _asNullableInt((item['trainer'] as Map<String, dynamic>?)?['id']),
      trainerAvatarUrl: _asNullableString(
        (item['trainer'] as Map<String, dynamic>?)?['avatar_url'],
      ),
      trainerDisplayPhotoPath: _asNullableString(
        (item['trainer'] as Map<String, dynamic>?)?['display_photo_path'],
      ),
      memberProfileId: _asNullableInt(memberMap['id']) ??
          _asNullableInt(item['member_profile_id']),
      clientName: _asNullableString(memberMap['name']) ?? 'Klien Trainer',
      timeRange: timeRange.isEmpty ? '-' : timeRange,
      location: _asNullableString(item['location']) ?? 'Lokasi belum diatur',
      status: _mapStatusLabel(_asNullableString(item['status'])),
      note: _asNullableString(item['trainer_note']) ??
          _asNullableString(item['member_note']) ??
          'Belum ada catatan sesi.',
      sessionDate: sessionDate,
      paymentProofUrl: _resolveProofUrl(item),
      paymentVerifiedAt: _parseDateTime(item['payment_verified_at']),
      sessionCount: _asNullableInt(item['session_count']) ?? 1,
      pricePerSession: _asNullableDouble(item['price_per_session']),
      totalAmount: _asNullableDouble(item['total_amount']),
      reservations: (item['session_reservations'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((reservation) => BookingSessionReservation(
                id: _asNullableInt(reservation['id']),
                sequenceOrder:
                    _asNullableInt(reservation['sequence_order']) ?? 0,
                sessionDate:
                    _asNullableString(reservation['session_date']) ?? '-',
                startTime: _formatTime(reservation['start_time']) ?? '-',
                endTime: _formatTime(reservation['end_time']) ?? '-',
                status: _asNullableString(reservation['status']) ?? 'reserved',
                activeRescheduleRequest:
                    reservation['active_reschedule_request']
                            is Map<String, dynamic>
                        ? _mapRescheduleRequest(
                            reservation['active_reschedule_request'])
                        : null,
              ))
          .toList(growable: false),
      rawStatus: _asNullableString(item['status'])?.toLowerCase(),
      hasProgram: item['has_program'] == true,
      trainingProgramId: _asNullableInt(item['training_program_id']),
      activeProgramSessionId: _asNullableInt(item['active_program_session_id']),
      activeProgramSessionTitle:
          _asNullableString(item['active_program_session_title']),
      activeProgramSessionMemberReady:
          item['active_program_session_member_ready'] == true,
      activeProgramSessionReservationId:
          _asNullableInt(item['active_program_session_reservation_id']),
      executionBlockedByPendingReschedule:
          item['execution_blocked_by_pending_reschedule'] == true,
      sessionTitle: _asNullableString(item['session_title']),
      memberNote: _asNullableString(item['member_note']),
      memberGender: _asNullableString(memberMap['gender']),
      memberBirthDate: _asNullableString(memberMap['birth_date']),
      memberHeightCm: _asNullableDouble(memberMap['height_cm']),
      memberWeightKg: _asNullableDouble(memberMap['weight_kg']),
      memberFitnessGoal: _asNullableString(memberMap['fitness_goal']),
      memberMedicalNote: _asNullableString(memberMap['medical_note']),
      memberTier: _asNullableString(memberMap['tier']),
      memberEmail: _asNullableString(memberMap['email']),
      memberPhone: _asNullableString(memberMap['phone']),
      memberCode: _asNullableString(memberMap['member_code']),
      memberAvatarUrl: _asNullableString(memberMap['avatar_url']),
      activeMembership: activeMembershipMap.isEmpty
          ? null
          : ScheduleSessionActiveMembership(
              planName: _asNullableString(activeMembershipMap['plan_name']),
              startDate: _asNullableString(activeMembershipMap['start_date']),
              endDate: _asNullableString(activeMembershipMap['end_date']),
              status: _asNullableString(activeMembershipMap['status']),
              paymentStatus:
                  _asNullableString(activeMembershipMap['payment_status']),
            ),
      expiredAt: DateTime.tryParse(
        _asNullableString(item['expired_at']) ?? '',
      ),
      remainingSeconds: _asNullableInt(item['remaining_seconds']) ?? 0,
      expiryStage: _asNullableString(item['expiry_stage']),
      isExpired: item['is_expired'] == true,
      isPaymentVerificationOverdue:
          item['is_payment_verification_overdue'] == true,
      paymentVerificationOverdueSeconds:
          _asNullableInt(item['payment_verification_overdue_seconds']) ?? 0,
    );
  }

  BookingRescheduleRequestData _mapRescheduleRequest(
    Map<String, dynamic> data,
  ) {
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
      oldStartTime: _formatTime(old['start_time']) ?? '-',
      oldEndTime: _formatTime(old['end_time']) ?? '-',
      proposedDate: _asNullableString(proposed['date']) ?? '-',
      proposedStartTime: _formatTime(proposed['start_time']) ?? '-',
      proposedEndTime: _formatTime(proposed['end_time']) ?? '-',
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

  /// Bangun URL foto bukti pembayaran yang dapat dijangkau device.
  ///
  /// Backend mengirim `payment_proof_url` (berbasis APP_URL yang sering
  /// mengarah ke localhost/127.0.0.1 sehingga tidak bisa diakses emulator).
  /// Karena itu kita prioritaskan membangun URL dari baseUrl aktif yang
  /// terbukti bekerja + path relatif foto, dan hanya fallback ke URL bawaan
  /// backend bila path tidak tersedia.
  String? _resolveProofUrl(Map<String, dynamic> item) {
    final proofPath = _asNullableString(item['payment_proof_path']);
    final baseUrl = AppSessionService.instance.currentSession?.baseUrl;

    if (proofPath != null && baseUrl != null) {
      final normalizedBase = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;
      final normalizedPath =
          proofPath.startsWith('/') ? proofPath.substring(1) : proofPath;
      return '$normalizedBase/storage/$normalizedPath';
    }

    return _asNullableString(item['payment_proof_url']);
  }

  String _mapStatusLabel(String? rawStatus) {
    return switch ((rawStatus ?? '').toLowerCase()) {
      'pending' => 'Menunggu',
      'waiting_payment' => 'Menunggu Pembayaran',
      'payment_uploaded' => 'Menunggu Verifikasi',
      'payment_verified' => 'Terverifikasi',
      'confirmed' => 'Terkonfirmasi',
      'rescheduled' => 'Dijadwalkan Ulang',
      'cancelled' => 'Dibatalkan',
      'expired' => 'Kedaluwarsa',
      _ => rawStatus == null || rawStatus.isEmpty ? 'Sesi' : rawStatus,
    };
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) {
      return value;
    }

    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];

    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  String? _formatTime(dynamic value) {
    final raw = _asNullableString(value);
    if (raw == null || raw.length < 5) {
      return raw;
    }

    return raw.substring(0, 5);
  }

  TrainerClientSessionSnapshot _mapClientSessionSnapshot(
    Map<String, dynamic> item,
  ) {
    return TrainerClientSessionSnapshot(
      id: _asNullableInt(item['id']) ?? 0,
      sessionTitle: _asNullableString(item['session_title']) ?? 'Sesi Trainer',
      sessionDate: _parseDateTime(item['session_date']),
      startTime: _formatTime(item['start_time']),
      endTime: _formatTime(item['end_time']),
      location: _asNullableString(item['location']),
      status: _mapStatusLabel(_asNullableString(item['status'])),
      memberNote: _asNullableString(item['member_note']),
      trainerNote: _asNullableString(item['trainer_note']),
    );
  }

  TrainerSessionProgressSnapshot _mapProgramSessionProgress(
    Map<String, dynamic> data,
  ) {
    final progress = data['session_progress'];
    final progressMap =
        progress is Map<String, dynamic> ? progress : const <String, dynamic>{};
    final exercises = data['exercises'];

    return TrainerSessionProgressSnapshot(
      progressId: _asNullableInt(progressMap['id']) ?? 0,
      progressPercent: _asNullableDouble(progressMap['progress_percent']) ?? 0,
      status: _asNullableString(progressMap['status']) ?? 'active',
      currentExerciseOrder:
          _asNullableInt(progressMap['current_exercise_order']),
      trainerNote: _asNullableString(progressMap['trainer_note']),
      exercises: exercises is List
          ? exercises
              .whereType<Map<String, dynamic>>()
              .map(
                (item) => TrainerSessionProgressExerciseSnapshot(
                  id: _asNullableInt(item['id']) ?? 0,
                  order: _asNullableInt(item['order']) ?? 0,
                  title: _asNullableString(item['title']) ?? 'Exercise',
                  subtitle: _asNullableString(item['subtitle']) ?? '-',
                  cue: _asNullableString(item['cue']),
                  targetMuscle: _asNullableString(item['target_muscle']),
                  equipmentId: _asNullableInt(item['equipment_id']),
                  equipmentName: _asNullableString(item['equipment_name']),
                  equipmentMovementId:
                      _asNullableInt(item['gym_equipment_movement_id']),
                  totalSets: _asNullableInt(item['total_sets']) ?? 0,
                  completedSets: _asNullableInt(item['completed_sets']) ?? 0,
                  status: _asNullableString(item['status']) ?? 'locked',
                ),
              )
              .toList()
          : const <TrainerSessionProgressExerciseSnapshot>[],
    );
  }

  DateTime? _parseDateTime(dynamic value) {
    final raw = _asNullableString(value);
    if (raw == null) {
      return null;
    }

    return DateTime.tryParse(raw)?.toLocal();
  }

  static String? _asNullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    final stringValue = value.toString().trim();
    return stringValue.isEmpty ? null : stringValue;
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
}

class TrainerLiveDashboardOverview {
  const TrainerLiveDashboardOverview({
    required this.trainerName,
    this.tier,
    required this.activeClients,
    required this.todaySessions,
    required this.rating,
    required this.todayAgenda,
    required this.paymentVerificationRequests,
    required this.hasActiveSchedule,
  });

  final String trainerName;
  final String? tier;
  final int activeClients;
  final int todaySessions;
  final double rating;
  final List<ScheduleSession> todayAgenda;
  final List<ScheduleSession> paymentVerificationRequests;
  final bool hasActiveSchedule;
}

class TrainerClientDetailSnapshot {
  const TrainerClientDetailSnapshot({
    required this.id,
    required this.memberCode,
    required this.name,
    this.avatarUrl,
    required this.email,
    required this.phone,
    required this.status,
    required this.goal,
    required this.gender,
    required this.birthDate,
    required this.heightCm,
    required this.weightKg,
    required this.medicalNote,
    required this.joinedAt,
    required this.totalSessions,
    required this.confirmedSessions,
    required this.pendingSessions,
    required this.rescheduledSessions,
    required this.activeMembershipPlanName,
    required this.activeMembershipStartDate,
    required this.activeMembershipEndDate,
    required this.activeProgramId,
    required this.activeProgramTitle,
    required this.activeProgramStatus,
    required this.activeProgramGoal,
    required this.activeProgramSessionId,
    required this.activeProgramSession,
    this.activeProgramTotalSessions = 0,
    this.activeProgramCompletedSessions = 0,
    this.activeProgramProgressPercent = 0,
    required this.nextSessionLabel,
    required this.nextSession,
    required this.recentSessions,
  });

  final int id;
  final String? memberCode;
  final String name;

  /// Relative path avatar member (mis. "avatars/x.jpg") dari backend. Dirender
  /// via InitialAvatar(avatarPath:) -> baseUrl dinamis; null -> fallback inisial.
  final String? avatarUrl;
  final String? email;
  final String? phone;
  final String? status;
  final String? goal;
  final String? gender;
  final DateTime? birthDate;
  final double? heightCm;
  final double? weightKg;
  final String? medicalNote;
  final DateTime? joinedAt;
  final int totalSessions;
  final int confirmedSessions;
  final int pendingSessions;
  final int rescheduledSessions;
  final String? activeMembershipPlanName;
  final DateTime? activeMembershipStartDate;
  final DateTime? activeMembershipEndDate;
  final int? activeProgramId;
  final String? activeProgramTitle;
  final String? activeProgramStatus;
  final String? activeProgramGoal;
  final int? activeProgramSessionId;
  final TrainerProgramSessionSummary? activeProgramSession;
  final int activeProgramTotalSessions;
  final int activeProgramCompletedSessions;
  final int activeProgramProgressPercent;
  final String? nextSessionLabel;
  final TrainerClientSessionSnapshot? nextSession;
  final List<TrainerClientSessionSnapshot> recentSessions;
}

class TrainerProgramSessionSummary {
  const TrainerProgramSessionSummary({
    required this.id,
    required this.sequenceOrder,
    required this.title,
    required this.status,
    this.memberReady = false,
    this.memberReadyAt,
  });

  final int id;
  final int sequenceOrder;
  final String title;
  final String status;
  final bool memberReady;
  final String? memberReadyAt;
}

class TrainerClientSessionSnapshot {
  const TrainerClientSessionSnapshot({
    required this.id,
    required this.sessionTitle,
    required this.sessionDate,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.status,
    required this.memberNote,
    required this.trainerNote,
  });

  final int id;
  final String sessionTitle;
  final DateTime? sessionDate;
  final String? startTime;
  final String? endTime;
  final String? location;
  final String status;
  final String? memberNote;
  final String? trainerNote;
}

class TrainerSessionProgressSnapshot {
  const TrainerSessionProgressSnapshot({
    required this.progressId,
    required this.progressPercent,
    required this.status,
    required this.currentExerciseOrder,
    required this.trainerNote,
    required this.exercises,
  });

  final int progressId;
  final double progressPercent;
  final String status;
  final int? currentExerciseOrder;
  final String? trainerNote;
  final List<TrainerSessionProgressExerciseSnapshot> exercises;
}

class TrainerSessionProgressExerciseSnapshot {
  const TrainerSessionProgressExerciseSnapshot({
    required this.id,
    required this.order,
    required this.title,
    required this.subtitle,
    required this.cue,
    required this.totalSets,
    required this.completedSets,
    required this.status,
    this.targetMuscle,
    this.equipmentId,
    this.equipmentName,
    this.equipmentMovementId,
  });

  final int id;
  final int order;
  final String title;
  final String subtitle;
  final String? cue;
  final int totalSets;
  final int completedSets;
  final String status;
  final String? targetMuscle;
  final int? equipmentId;
  final String? equipmentName;
  final int? equipmentMovementId;
}

class TrainerProgramDetailData {
  const TrainerProgramDetailData({
    required this.id,
    required this.title,
    this.description,
    this.goal,
    required this.status,
    this.memberName,
    required this.totalSessions,
    required this.totalDurationMinutes,
    required this.sessions,
  });

  final int id;
  final String title;
  final String? description;
  final String? goal;
  final String status;
  final String? memberName;
  final int totalSessions;
  final int totalDurationMinutes;
  final List<TrainerProgramSessionDetailData> sessions;

  int get totalReservationDurationMinutes => sessions.fold<int>(
        0,
        (total, session) => total + session.reservationDurationMinutes,
      );

  double get completionPercent {
    if (totalSessions == 0) return 0;
    final completed = sessions.where((s) => s.isCompleted).length;
    return (completed / totalSessions) * 100;
  }
}

class TrainerProgramSessionDetailData {
  const TrainerProgramSessionDetailData({
    required this.id,
    required this.sequenceOrder,
    required this.title,
    this.focus,
    this.durationMinutes,
    required this.status,
    required this.exercises,
    this.memberReady = false,
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
  final List<TrainerProgramExerciseDetailData> exercises;

  /// Apakah member sudah menekan "Mulai Sesi" untuk sesi ini. Approval
  /// bersifat per-sesi; trainer baru boleh mencentang setelah ini true.
  final bool memberReady;
  final int? bookingSessionReservationId;
  final String? reservationDate;
  final String? reservationStartTime;
  final String? reservationEndTime;
  final String? reservationStatus;
  final bool hasPendingReschedule;

  int get reservationDurationMinutes {
    final start = _scheduleMinutes(reservationStartTime);
    final end = _scheduleMinutes(reservationEndTime);
    if (start == null || end == null || end <= start) return 0;

    return end - start;
  }

  bool get isCompleted => status == 'completed';
  bool get isActive => status == 'active';
  bool get isLocked => status == 'locked' || status == 'upcoming';

  double get completionPercent {
    if (exercises.isEmpty) return 0;
    final completedSets =
        exercises.fold<int>(0, (sum, e) => sum + e.completedSets);
    final totalSets = exercises.fold<int>(0, (sum, e) => sum + e.totalSets);
    if (totalSets == 0) return 0;
    return (completedSets / totalSets) * 100;
  }
}

int? _scheduleMinutes(String? value) {
  if (value == null) return null;
  final parts = value.trim().split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null ||
      minute == null ||
      hour < 0 ||
      hour > 23 ||
      minute < 0 ||
      minute > 59) {
    return null;
  }

  return hour * 60 + minute;
}

List<TrainerProgramSessionDetailData> sortTrainerProgramSessionsBySchedule(
  Iterable<TrainerProgramSessionDetailData> sessions,
) {
  final sorted = List<TrainerProgramSessionDetailData>.of(sessions);
  sorted.sort((a, b) {
    final aKey = _trainerProgramScheduleKey(
      a.reservationDate,
      a.reservationStartTime,
      a.reservationEndTime,
    );
    final bKey = _trainerProgramScheduleKey(
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

String? _trainerProgramScheduleKey(
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

class TrainerProgramExerciseDetailData {
  const TrainerProgramExerciseDetailData({
    required this.id,
    required this.order,
    required this.title,
    required this.subtitle,
    this.targetMuscle,
    this.equipmentId,
    this.equipmentName,
    this.equipmentMovementId,
    this.cue,
    required this.totalSets,
    required this.completedSets,
    required this.status,
  });

  final int id;
  final int order;
  final String title;
  final String subtitle;
  final String? targetMuscle;
  final int? equipmentId;
  final String? equipmentName;
  final int? equipmentMovementId;
  final String? cue;
  final int totalSets;
  final int completedSets;
  final String status;

  bool get isCompleted => status == 'completed';
  bool get isFullyCompleted => completedSets >= totalSets && totalSets > 0;
}

class TrainerApiException implements Exception {
  const TrainerApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
