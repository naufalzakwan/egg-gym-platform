import 'dart:async';
import 'dart:convert';

import 'package:egg_gym/data/services/backend_api_config.dart';
import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:egg_gym/data/services/base_url_resolver.dart';
import 'package:http/http.dart' as http;

class SelfTrainingProgramData {
  const SelfTrainingProgramData({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    required this.totalSessions,
    required this.totalExercises,
    required this.completedExercises,
    required this.progressPercent,
    required this.sessions,
  });

  final int id;
  final String title;
  final String? description;
  final String status;
  final int totalSessions;
  final int totalExercises;
  final int completedExercises;
  final int progressPercent;
  final List<SelfTrainingSessionData> sessions;
}

class SelfTrainingSessionData {
  const SelfTrainingSessionData({
    required this.id,
    required this.sequenceOrder,
    required this.title,
    this.focus,
    this.durationMinutes,
    required this.status,
    required this.totalExercises,
    required this.completedExercises,
    required this.exercises,
  });

  final int id;
  final int sequenceOrder;
  final String title;
  final String? focus;
  final int? durationMinutes;
  final String status;
  final int totalExercises;
  final int completedExercises;
  final List<SelfTrainingExerciseData> exercises;
}

class SelfTrainingExerciseData {
  const SelfTrainingExerciseData({
    required this.id,
    required this.sequenceOrder,
    required this.name,
    this.targetMuscle,
    required this.sets,
    required this.reps,
    this.restSeconds,
    this.load,
    this.notes,
    this.equipmentId,
    this.equipmentName,
    this.equipmentMovementId,
    required this.isCompleted,
    this.completedAt,
  });

  final int id;
  final int sequenceOrder;
  final String name;
  final String? targetMuscle;
  final int sets;
  final int reps;
  final int? restSeconds;
  final String? load;
  final String? notes;
  final int? equipmentId;
  final String? equipmentName;
  final int? equipmentMovementId;
  final bool isCompleted;
  final String? completedAt;
}

class BackendSelfTrainingService {
  BackendSelfTrainingService({http.Client? client})
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

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<List<SelfTrainingProgramData>> getPrograms() async {
    final auth = _authenticate();
    final response = await sendWithBaseUrlFallback(
      activeBaseUrl: auth.baseUrl,
      send: (baseUrl) => _client
          .get(
            Uri.parse('$baseUrl/api/v1/member/self-training'),
            headers: _headers(auth.token),
          )
          .timeout(BackendApiConfig.requestTimeout),
    );

    final payload = _decodeJson(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(payload['message'] ?? 'Gagal memuat program.');
    }

    final data = payload['data'];
    if (data is! List) return [];

    return data.whereType<Map<String, dynamic>>().map(_mapProgram).toList();
  }

  Future<SelfTrainingProgramData> createProgram({
    required String title,
    String? description,
  }) async {
    final auth = _authenticate();
    final response = await _client
        .post(
          Uri.parse('${auth.baseUrl}/api/v1/member/self-training'),
          headers: _headers(auth.token),
          body: jsonEncode({
            'title': title,
            if (description != null) 'description': description,
          }),
        )
        .timeout(BackendApiConfig.requestTimeout);

    final payload = _decodeJson(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(payload['message'] ?? 'Gagal membuat program.');
    }

    return _mapProgram(payload['data']);
  }

  /// Update judul & deskripsi program. Endpoint PUT baru
  /// (SelfTrainingController::update). Validasi: title sometimes|required,
  /// description nullable -> aman mengirim description null.
  Future<SelfTrainingProgramData> updateProgram({
    required int programId,
    required String title,
    String? description,
  }) async {
    final auth = _authenticate();
    final response = await _client
        .put(
          Uri.parse('${auth.baseUrl}/api/v1/member/self-training/$programId'),
          headers: _headers(auth.token),
          body: jsonEncode({
            'title': title,
            'description': description,
          }),
        )
        .timeout(BackendApiConfig.requestTimeout);

    final payload = _decodeJson(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(payload['message'] ?? 'Gagal memperbarui program.');
    }

    return _mapProgram(payload['data']);
  }

  Future<void> deleteProgram(int programId) async {
    final auth = _authenticate();
    await _client
        .delete(
          Uri.parse('${auth.baseUrl}/api/v1/member/self-training/$programId'),
          headers: _headers(auth.token),
        )
        .timeout(BackendApiConfig.requestTimeout);
  }

  Future<SelfTrainingSessionData> createSession({
    required int programId,
    required String title,
    String? focus,
    int? durationMinutes,
  }) async {
    final auth = _authenticate();
    final response = await _client
        .post(
          Uri.parse(
              '${auth.baseUrl}/api/v1/member/self-training/$programId/sessions'),
          headers: _headers(auth.token),
          body: jsonEncode({
            'title': title,
            if (focus != null) 'focus': focus,
            if (durationMinutes != null) 'duration_minutes': durationMinutes,
          }),
        )
        .timeout(BackendApiConfig.requestTimeout);

    final payload = _decodeJson(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(payload['message'] ?? 'Gagal membuat sesi.');
    }

    return _mapSession(payload['data']);
  }

  /// Update judul & fokus sesi. Endpoint PUT sudah ada di backend
  /// (SelfTrainingController::updateSession). Validasi backend: title
  /// sometimes|required, focus nullable -> aman mengirim focus null.
  Future<SelfTrainingSessionData> updateSession({
    required int programId,
    required int sessionId,
    required String title,
    String? focus,
  }) async {
    final auth = _authenticate();
    final response = await _client
        .put(
          Uri.parse(
              '${auth.baseUrl}/api/v1/member/self-training/$programId/sessions/$sessionId'),
          headers: _headers(auth.token),
          body: jsonEncode({
            'title': title,
            'focus': focus,
          }),
        )
        .timeout(BackendApiConfig.requestTimeout);

    final payload = _decodeJson(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(payload['message'] ?? 'Gagal memperbarui sesi.');
    }

    return _mapSession(payload['data']);
  }

  Future<void> deleteSession(int programId, int sessionId) async {
    final auth = _authenticate();
    await _client
        .delete(
          Uri.parse(
              '${auth.baseUrl}/api/v1/member/self-training/$programId/sessions/$sessionId'),
          headers: _headers(auth.token),
        )
        .timeout(BackendApiConfig.requestTimeout);
  }

  Future<SelfTrainingExerciseData> addExercise({
    required int programId,
    required int sessionId,
    required String name,
    String? targetMuscle,
    required int sets,
    required int reps,
    int? restSeconds,
    String? load,
    String? notes,
    int? equipmentId,
    String? equipmentName,
    int? equipmentMovementId,
  }) async {
    final auth = _authenticate();
    final response = await _client
        .post(
          Uri.parse(
              '${auth.baseUrl}/api/v1/member/self-training/$programId/sessions/$sessionId/exercises'),
          headers: _headers(auth.token),
          body: jsonEncode({
            'name': name,
            'sets': sets,
            'reps': reps,
            if (targetMuscle != null) 'target_muscle': targetMuscle,
            if (restSeconds != null) 'rest_seconds': restSeconds,
            if (load != null) 'load': load,
            if (notes != null) 'notes': notes,
            if (equipmentId != null) 'equipment_id': equipmentId,
            if (equipmentName != null) 'equipment_name': equipmentName,
            if (equipmentMovementId != null)
              'gym_equipment_movement_id': equipmentMovementId,
          }),
        )
        .timeout(BackendApiConfig.requestTimeout);

    final payload = _decodeJson(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(payload['message'] ?? 'Gagal menambah latihan.');
    }

    return _mapExercise(payload['data']);
  }

  /// Update gerakan. Endpoint PUT sudah ada di backend
  /// (SelfTrainingController::updateExercise). Validasi: name/sets/reps
  /// sometimes|required, target_muscle/load nullable -> aman mengirim null.
  Future<SelfTrainingExerciseData> updateExercise({
    required int programId,
    required int sessionId,
    required int exerciseId,
    required String name,
    String? targetMuscle,
    required int sets,
    required int reps,
    String? load,
    int? equipmentId,
    String? equipmentName,
    int? equipmentMovementId,
  }) async {
    final auth = _authenticate();
    final response = await _client
        .put(
          Uri.parse(
              '${auth.baseUrl}/api/v1/member/self-training/$programId/sessions/$sessionId/exercises/$exerciseId'),
          headers: _headers(auth.token),
          body: jsonEncode({
            'name': name,
            'sets': sets,
            'reps': reps,
            'target_muscle': targetMuscle,
            'load': load,
            if (equipmentId != null) 'equipment_id': equipmentId,
            if (equipmentName != null) 'equipment_name': equipmentName,
            if (equipmentMovementId != null)
              'gym_equipment_movement_id': equipmentMovementId,
          }),
        )
        .timeout(BackendApiConfig.requestTimeout);

    final payload = _decodeJson(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(payload['message'] ?? 'Gagal memperbarui latihan.');
    }

    return _mapExercise(payload['data']);
  }

  Future<SelfTrainingExerciseData> toggleExercise({
    required int programId,
    required int sessionId,
    required int exerciseId,
  }) async {
    final auth = _authenticate();
    final response = await _client
        .post(
          Uri.parse(
              '${auth.baseUrl}/api/v1/member/self-training/$programId/sessions/$sessionId/exercises/$exerciseId/toggle'),
          headers: _headers(auth.token),
        )
        .timeout(BackendApiConfig.requestTimeout);

    final payload = _decodeJson(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(payload['message'] ?? 'Gagal update latihan.');
    }

    return _mapExercise(payload['data']);
  }

  Future<void> deleteExercise({
    required int programId,
    required int sessionId,
    required int exerciseId,
  }) async {
    final auth = _authenticate();
    await _client
        .delete(
          Uri.parse(
              '${auth.baseUrl}/api/v1/member/self-training/$programId/sessions/$sessionId/exercises/$exerciseId'),
          headers: _headers(auth.token),
        )
        .timeout(BackendApiConfig.requestTimeout);
  }

  // Mappers
  SelfTrainingProgramData _mapProgram(Map<String, dynamic> data) {
    final sessions = data['sessions'] as List? ?? [];
    return SelfTrainingProgramData(
      id: _asInt(data['id']) ?? 0,
      title: _asString(data['title']) ?? 'Program',
      description: _asString(data['description']),
      status: _asString(data['status']) ?? 'active',
      totalSessions: _asInt(data['total_sessions']) ?? 0,
      totalExercises: _asInt(data['total_exercises']) ?? 0,
      completedExercises: _asInt(data['completed_exercises']) ?? 0,
      progressPercent: _asInt(data['progress_percent']) ?? 0,
      sessions:
          sessions.whereType<Map<String, dynamic>>().map(_mapSession).toList(),
    );
  }

  SelfTrainingSessionData _mapSession(Map<String, dynamic> data) {
    final exercises = data['exercises'] as List? ?? [];
    return SelfTrainingSessionData(
      id: _asInt(data['id']) ?? 0,
      sequenceOrder: _asInt(data['sequence_order']) ?? 0,
      title: _asString(data['title']) ?? 'Sesi',
      focus: _asString(data['focus']),
      durationMinutes: _asInt(data['duration_minutes']),
      status: _asString(data['status']) ?? 'active',
      totalExercises: _asInt(data['total_exercises']) ?? 0,
      completedExercises: _asInt(data['completed_exercises']) ?? 0,
      exercises: exercises
          .whereType<Map<String, dynamic>>()
          .map(_mapExercise)
          .toList(),
    );
  }

  SelfTrainingExerciseData _mapExercise(Map<String, dynamic> data) {
    return SelfTrainingExerciseData(
      id: _asInt(data['id']) ?? 0,
      sequenceOrder: _asInt(data['sequence_order']) ?? 0,
      name: _asString(data['name']) ?? '-',
      targetMuscle: _asString(data['target_muscle']),
      sets: _asInt(data['sets']) ?? 0,
      reps: _asInt(data['reps']) ?? 0,
      restSeconds: _asInt(data['rest_seconds']),
      load: _asString(data['load']),
      notes: _asString(data['notes']),
      equipmentId: _asInt(data['equipment_id']),
      equipmentName: _asString(data['equipment_name']),
      equipmentMovementId: _asInt(data['gym_equipment_movement_id']),
      isCompleted: data['is_completed'] == true,
      completedAt: _asString(data['completed_at']),
    );
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

  static String? _asString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }
}
