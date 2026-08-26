import 'dart:async';
import 'dart:convert';

import 'package:egg_gym/data/services/backend_api_config.dart';
import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:http/http.dart' as http;

class ProgramClient {
  const ProgramClient({
    required this.memberProfileId,
    required this.name,
    required this.memberCode,
    required this.goal,
    required this.bookingCount,
    this.heightCm,
    this.weightKg,
    this.medicalNote,
  });

  final int memberProfileId;
  final String name;
  final String memberCode;
  final String goal;
  final int bookingCount;
  final double? heightCm;
  final double? weightKg;
  final String? medicalNote;
}

class ProgramExercise {
  const ProgramExercise({
    this.exerciseLibraryId,
    required this.sequenceOrder,
    required this.name,
    required this.targetMuscle,
    required this.sets,
    required this.reps,
    this.restSeconds,
    this.cueText,
    this.equipmentId,
    this.equipmentName,
    this.equipmentMovementId,
  });

  final int? exerciseLibraryId;
  final int sequenceOrder;
  final String name;
  final String targetMuscle;
  final int sets;
  final int reps;
  final int? restSeconds;
  final String? cueText;
  final int? equipmentId;
  final String? equipmentName;
  final int? equipmentMovementId;
}

class ProgramSession {
  const ProgramSession({
    required this.sequenceOrder,
    required this.title,
    this.focus,
    this.durationMinutes,
    this.coachNote,
    this.exercises = const [],
  });

  final int sequenceOrder;
  final String title;
  final String? focus;
  final int? durationMinutes;
  final String? coachNote;
  final List<ProgramExercise> exercises;
}

class ProgramResult {
  const ProgramResult({
    required this.id,
    required this.title,
    required this.status,
  });

  final int id;
  final String title;
  final String status;
}

class ExerciseLibraryItem {
  const ExerciseLibraryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.targetMuscle,
  });

  final int id;
  final String name;
  final String category;
  final String targetMuscle;
}

class BackendProgramService {
  BackendProgramService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  ({String baseUrl, String token}) _authenticate() {
    final session = AppSessionService.instance;
    if (!session.isAuthenticated) {
      throw Exception('Sesi trainer belum aktif.');
    }
    final currentSession = session.currentSession;
    final token = currentSession?.token;
    final baseUrl = currentSession?.baseUrl;
    if (token == null || baseUrl == null) {
      throw Exception('Token atau base URL tidak tersedia.');
    }
    return (baseUrl: baseUrl, token: token);
  }

  Future<List<ProgramClient>> getTrainerClients() async {
    final auth = _authenticate();
    Object? lastError;

    for (final baseUrl in BackendApiConfig.candidateBaseUrls) {
      try {
        final response = await _client.get(
          Uri.parse('$baseUrl/api/v1/trainer/clients'),
          headers: <String, String>{
            'Accept': 'application/json',
            'Authorization': 'Bearer ${auth.token}',
          },
        ).timeout(BackendApiConfig.requestTimeout);

        if (response.statusCode < 200 || response.statusCode >= 300) {
          lastError = Exception('HTTP ${response.statusCode}');
          continue;
        }

        final payload = _decodeJson(response.body);
        final data = payload['data'];
        if (data is! List) {
          lastError = Exception('Response bukan list');
          continue;
        }

        return data.whereType<Map<String, dynamic>>().map((item) {
          final member = item['member'];
          final memberMap = member is Map<String, dynamic> ? member : item;
          return ProgramClient(
            memberProfileId:
                _asInt(memberMap['member_profile_id'] ?? item['id']) ?? 0,
            name: _asString(memberMap['name'] ?? item['name']) ?? '-',
            memberCode:
                _asString(memberMap['member_code'] ?? item['member_code']) ??
                    '-',
            goal: _asString(memberMap['fitness_goal'] ??
                    item['fitness_goal'] ??
                    item['goal']) ??
                '-',
            bookingCount:
                _asInt(item['bookings_count'] ?? item['booking_count']) ?? 0,
            heightCm: _asDouble(memberMap['height_cm'] ?? item['height_cm']),
            weightKg: _asDouble(memberMap['weight_kg'] ?? item['weight_kg']),
            medicalNote:
                _asString(memberMap['medical_note'] ?? item['medical_note']),
          );
        }).toList();
      } on TimeoutException {
        lastError = Exception('Timeout mengambil klien dari $baseUrl');
        continue;
      } catch (error) {
        lastError = error;
        continue;
      }
    }

    throw lastError ?? Exception('Tidak ada backend yang tersedia');
  }

  Future<List<ExerciseLibraryItem>> getExerciseLibrary() async {
    final auth = _authenticate();
    Object? lastError;

    for (final baseUrl in BackendApiConfig.candidateBaseUrls) {
      try {
        final response = await _client.get(
          Uri.parse('$baseUrl/api/v1/trainer/exercise-library'),
          headers: <String, String>{
            'Accept': 'application/json',
            'Authorization': 'Bearer ${auth.token}',
          },
        ).timeout(BackendApiConfig.requestTimeout);

        if (response.statusCode < 200 || response.statusCode >= 300) {
          lastError = Exception('HTTP ${response.statusCode}');
          continue;
        }

        final payload = _decodeJson(response.body);
        final data = payload['data'];
        if (data is! List) {
          lastError = Exception('Response bukan list');
          continue;
        }

        return data.whereType<Map<String, dynamic>>().map((item) {
          return ExerciseLibraryItem(
            id: _asInt(item['id']) ?? 0,
            name: _asString(item['name']) ?? '-',
            category: _asString(item['category']) ?? '-',
            targetMuscle:
                _asString(item['focus'] ?? item['target_muscle']) ?? '-',
          );
        }).toList();
      } on TimeoutException {
        lastError =
            Exception('Timeout mengambil exercise library dari $baseUrl');
        continue;
      } catch (error) {
        lastError = error;
        continue;
      }
    }

    throw lastError ?? Exception('Tidak ada backend yang tersedia');
  }

  Future<List<ProgramListItem>> getTrainerPrograms() async {
    final auth = _authenticate();

    final response = await _client.get(
      Uri.parse('${auth.baseUrl}/api/v1/trainer/programs'),
      headers: <String, String>{
        'Accept': 'application/json',
        'Authorization': 'Bearer ${auth.token}',
      },
    ).timeout(BackendApiConfig.requestTimeout);
    final payload = _decodeJson(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(payload['message'] ?? 'Gagal mengambil programs');
    }

    final data = payload['data'];
    if (data is! List) {
      throw Exception('Response programs bukan list');
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(ProgramListItem.fromMap)
        .toList();
  }

  Future<ProgramDetailData> getProgramDetail(int programId) async {
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
      throw Exception(payload['message'] ?? 'Gagal mengambil detail program');
    }

    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('Response detail program tidak valid');
    }

    final sessionsData = data['sessions'] as List? ?? [];
    final sessions =
        sessionsData.whereType<Map<String, dynamic>>().map((sessionData) {
      final exercisesData = sessionData['exercises'] as List? ?? [];
      final exercises =
          exercisesData.whereType<Map<String, dynamic>>().map((exerciseData) {
        return ProgramExerciseData(
          id: _asInt(exerciseData['id']) ?? 0,
          name:
              _asString(exerciseData['custom_name'] ?? exerciseData['name']) ??
                  '-',
          targetMuscle: _asString(exerciseData['custom_target_muscle'] ??
                  exerciseData['target_muscle']) ??
              '-',
          sets: _asInt(exerciseData['sets']) ?? 0,
          reps: _asInt(exerciseData['reps']) ?? 0,
          equipmentId: _asInt(exerciseData['equipment_id']),
          equipmentName: _asString(exerciseData['equipment_name']),
          equipmentMovementId:
              _asInt(exerciseData['gym_equipment_movement_id']),
        );
      }).toList();

      return ProgramSessionData(
        id: _asInt(sessionData['id']) ?? 0,
        title: _asString(sessionData['title']) ?? 'Sesi',
        focus: _asString(sessionData['focus']),
        durationMinutes: _asInt(sessionData['duration_minutes']),
        status: _asString(sessionData['status']) ?? 'locked',
        exercises: exercises,
      );
    }).toList();

    return ProgramDetailData(
      id: _asInt(data['id']) ?? 0,
      title: _asString(data['title']) ?? 'Program',
      description: _asString(data['description']),
      sessions: sessions,
    );
  }

  Future<ProgramResult> createProgram({
    required int memberProfileId,
    required String title,
    String? description,
    String? goal,
    int? bookingId,
  }) async {
    final auth = _authenticate();

    final body = <String, dynamic>{
      'member_profile_id': memberProfileId,
      'title': title,
      'status': 'active',
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (goal != null && goal.trim().isNotEmpty) 'goal': goal.trim(),
      if (bookingId != null) 'booking_id': bookingId,
    };

    final response = await _client
        .post(
          Uri.parse('${auth.baseUrl}/api/v1/trainer/programs'),
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
      throw Exception(payload['message'] ?? 'Gagal membuat program');
    }

    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('Response program tidak valid');
    }

    return ProgramResult(
      id: _asInt(data['id']) ?? 0,
      title: _asString(data['title']) ?? title,
      status: _asString(data['status']) ?? 'draft',
    );
  }

  Future<void> addSession({
    required int programId,
    required int sequenceOrder,
    required String title,
    String? focus,
    int? durationMinutes,
    String? coachNote,
  }) async {
    final auth = _authenticate();

    final body = <String, dynamic>{
      'sequence_order': sequenceOrder,
      'title': title,
      if (focus != null && focus.trim().isNotEmpty) 'focus': focus.trim(),
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
      if (coachNote != null && coachNote.trim().isNotEmpty)
        'coach_note': coachNote.trim(),
    };

    final response = await _client
        .post(
          Uri.parse(
              '${auth.baseUrl}/api/v1/trainer/programs/$programId/sessions'),
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
      throw Exception(payload['message'] ?? 'Gagal menambah sesi');
    }
  }

  Future<void> addExercise({
    required int sessionId,
    required int sequenceOrder,
    required String name,
    required String targetMuscle,
    required int sets,
    required int reps,
    int? exerciseLibraryId,
    int? restSeconds,
    String? cueText,
    int? equipmentId,
    String? equipmentName,
    int? equipmentMovementId,
  }) async {
    final auth = _authenticate();

    final body = <String, dynamic>{
      'sequence_order': sequenceOrder,
      'sets': sets,
      'reps': reps,
      if (exerciseLibraryId != null) 'exercise_library_id': exerciseLibraryId,
      if (exerciseLibraryId == null) ...{
        'custom_name': name,
        'custom_target_muscle': targetMuscle,
      },
      if (restSeconds != null) 'rest_seconds': restSeconds,
      if (cueText != null && cueText.trim().isNotEmpty)
        'cue_text': cueText.trim(),
      if (equipmentId != null) 'equipment_id': equipmentId,
      if (equipmentName != null && equipmentName.trim().isNotEmpty)
        'equipment_name': equipmentName.trim(),
      if (equipmentMovementId != null)
        'gym_equipment_movement_id': equipmentMovementId,
    };

    final response = await _client
        .post(
          Uri.parse(
              '${auth.baseUrl}/api/v1/trainer/program-sessions/$sessionId/exercises'),
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
      throw Exception(payload['message'] ?? 'Gagal menambah latihan');
    }
  }

  Future<ProgramResult> createFullProgram({
    required int memberProfileId,
    required String title,
    String? description,
    String? goal,
    required List<ProgramSession> sessions,
    int? bookingId,
  }) async {
    final auth = _authenticate();

    final program = await createProgram(
      memberProfileId: memberProfileId,
      title: title,
      description: description,
      goal: goal,
      bookingId: bookingId,
    );

    // Create sessions and exercises sequentially
    for (int i = 0; i < sessions.length; i++) {
      final session = sessions[i];
      // First session should be 'active', rest should be 'locked'
      final sessionStatus = i == 0 ? 'active' : 'locked';

      // First create the session to get its ID
      final sessionResponse = await _client
          .post(
            Uri.parse(
                '${auth.baseUrl}/api/v1/trainer/programs/${program.id}/sessions'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer ${auth.token}',
            },
            body: jsonEncode({
              'sequence_order': session.sequenceOrder,
              'title': session.title,
              'status': sessionStatus,
              if (session.focus != null && session.focus!.trim().isNotEmpty)
                'focus': session.focus!.trim(),
              if (session.durationMinutes != null)
                'duration_minutes': session.durationMinutes,
              if (session.coachNote != null &&
                  session.coachNote!.trim().isNotEmpty)
                'coach_note': session.coachNote!.trim(),
            }),
          )
          .timeout(BackendApiConfig.requestTimeout);

      final sessionPayload = _decodeJson(sessionResponse.body);
      if (sessionResponse.statusCode < 200 ||
          sessionResponse.statusCode >= 300) {
        throw Exception(sessionPayload['message'] ?? 'Gagal menambah sesi');
      }

      // Get the session ID from response
      final sessionData = sessionPayload['data'];
      final sessionId = _asInt(sessionData?['id']);
      if (sessionId == null) {
        throw Exception('ID sesi tidak ditemukan dari response');
      }

      // Now add exercises to this session
      for (final exercise in session.exercises) {
        await addExercise(
          sessionId: sessionId,
          sequenceOrder: exercise.sequenceOrder,
          name: exercise.name,
          targetMuscle: exercise.targetMuscle,
          sets: exercise.sets,
          reps: exercise.reps,
          exerciseLibraryId: exercise.exerciseLibraryId,
          restSeconds: exercise.restSeconds,
          cueText: exercise.cueText,
          equipmentId: exercise.equipmentId,
          equipmentName: exercise.equipmentName,
          equipmentMovementId: exercise.equipmentMovementId,
        );
      }
    }

    return program;
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

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }
}

class ProgramListItem {
  const ProgramListItem({
    required this.id,
    required this.title,
    required this.memberProfileId,
    required this.status,
    this.memberName,
    this.sessionsCount = 0,
    this.completedSessionsCount = 0,
    this.progressPercent = 0,
    this.isActiveControl = false,
    this.totalDurationMinutes = 0,
    this.exercisesCount = 0,
    this.nextSession,
  });

  final int id;
  final String title;
  final int memberProfileId;
  final String status;
  final String? memberName;
  final int sessionsCount;
  final int completedSessionsCount;
  final int progressPercent;
  final bool isActiveControl;
  final int totalDurationMinutes;
  final int exercisesCount;
  final ProgramNextSession? nextSession;

  factory ProgramListItem.fromMap(Map<String, dynamic> map) {
    final nextSession = map['next_session'];

    return ProgramListItem(
      id: _int(map['id']) ?? 0,
      title: _string(map['title']) ?? 'Program',
      memberProfileId: _int(map['member_profile_id']) ?? 0,
      status: _string(map['status']) ?? 'draft',
      memberName: _string(map['member_name']),
      sessionsCount: _int(map['sessions_count']) ?? 0,
      completedSessionsCount: _int(map['completed_sessions_count']) ?? 0,
      progressPercent: _int(map['progress_percent']) ?? 0,
      isActiveControl: map['is_active_control'] == true ||
          map['is_active_control'] == 1 ||
          map['is_active_control']?.toString().toLowerCase() == 'true',
      totalDurationMinutes: _int(map['total_duration_minutes']) ?? 0,
      exercisesCount: _int(map['exercises_count']) ?? 0,
      nextSession: nextSession is Map<String, dynamic>
          ? ProgramNextSession.fromMap(nextSession)
          : null,
    );
  }

  static int? _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static String? _string(dynamic value) {
    final string = value?.toString().trim() ?? '';
    return string.isEmpty ? null : string;
  }
}

class ProgramNextSession {
  const ProgramNextSession({
    this.sessionDate,
    this.startTime,
    this.endTime,
    this.status,
  });

  final String? sessionDate;
  final String? startTime;
  final String? endTime;
  final String? status;

  factory ProgramNextSession.fromMap(Map<String, dynamic> map) {
    return ProgramNextSession(
      sessionDate: ProgramListItem._string(map['session_date']),
      startTime: ProgramListItem._string(map['start']),
      endTime: ProgramListItem._string(map['end']),
      status: ProgramListItem._string(map['status']),
    );
  }
}

class ProgramDetailData {
  const ProgramDetailData({
    required this.id,
    required this.title,
    this.description,
    required this.sessions,
  });

  final int id;
  final String title;
  final String? description;
  final List<ProgramSessionData> sessions;
}

class ProgramSessionData {
  const ProgramSessionData({
    required this.id,
    required this.title,
    this.focus,
    this.durationMinutes,
    required this.status,
    required this.exercises,
  });

  final int id;
  final String title;
  final String? focus;
  final int? durationMinutes;
  final String status;
  final List<ProgramExerciseData> exercises;
}

class ProgramExerciseData {
  const ProgramExerciseData({
    required this.id,
    required this.name,
    required this.targetMuscle,
    required this.sets,
    required this.reps,
    this.equipmentId,
    this.equipmentName,
    this.equipmentMovementId,
  });

  final int id;
  final String name;
  final String targetMuscle;
  final int sets;
  final int reps;
  final int? equipmentId;
  final String? equipmentName;
  final int? equipmentMovementId;
}
