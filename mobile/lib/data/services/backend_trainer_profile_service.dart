import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:egg_gym/data/services/backend_api_config.dart';
import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:egg_gym/core/utils/trainer_tier.dart';
import 'package:http/http.dart' as http;

class TrainerProfileData {
  const TrainerProfileData({
    this.id,
    this.name,
    this.email,
    this.phone,
    this.specialty,
    this.specialtyLabel,
    this.specialties = const [],
    this.specialtyLabels = const [],
    this.bio,
    this.rating,
    this.experienceYears,
    this.certifications = const [],
    this.availabilityNote,
    this.tier,
    this.status,
    this.displayPhotoPath,
    this.bankName,
    this.bankAccountNumber,
    this.bankAccountName,
    this.danaNumber,
    this.danaAccountName,
    this.otherPaymentMethod,
    this.otherPaymentNumber,
    this.otherPaymentAccountName,
    this.pricePerSession,
  });

  final int? id;
  final String? name;
  final String? email;
  final String? phone;
  final String? specialty;
  final String? specialtyLabel;
  final List<String> specialties;
  final List<String> specialtyLabels;
  final String? bio;
  final double? rating;
  final int? experienceYears;
  final List<String> certifications;
  final String? availabilityNote;
  final String? tier;
  final String? status;
  final String? displayPhotoPath;
  final String? bankName;
  final String? bankAccountNumber;
  final String? bankAccountName;
  final String? danaNumber;
  final String? danaAccountName;
  final String? otherPaymentMethod;
  final String? otherPaymentNumber;
  final String? otherPaymentAccountName;
  final double? pricePerSession;
}

class BackendTrainerProfileService {
  BackendTrainerProfileService({http.Client? client})
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

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<TrainerProfileData> getProfile() async {
    final auth = _authenticate();
    final response = await _client
        .get(
          Uri.parse('${auth.baseUrl}/api/v1/trainer/profile'),
          headers: _headers(auth.token),
        )
        .timeout(BackendApiConfig.requestTimeout);

    final payload = _decodeJson(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(payload['message'] ?? 'Gagal mengambil profil trainer.');
    }

    return _mapProfile(payload['data']);
  }

  Future<TrainerProfileData> updateProfile({
    String? name,
    String? email,
    String? phone,
    List<String>? specialties,
    String? bio,
    int? experienceYears,
    List<String>? certifications,
    String? availabilityNote,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountName,
    String? danaNumber,
    String? danaAccountName,
    String? otherPaymentMethod,
    String? otherPaymentNumber,
    String? otherPaymentAccountName,
    double? pricePerSession,
    String? currentPassword,
    String? newPassword,
    String? newPasswordConfirmation,
  }) async {
    final auth = _authenticate();

    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (specialties != null) 'specialties': specialties,
      'bio': bio,
      'experience_years': experienceYears,
      if (certifications != null) 'certifications': certifications,
      'availability_note': availabilityNote,
      'bank_name': bankName,
      'bank_account_number': bankAccountNumber,
      'bank_account_name': bankAccountName,
      'dana_number': danaNumber,
      'dana_account_name': danaAccountName,
      'other_payment_method': otherPaymentMethod,
      'other_payment_number': otherPaymentNumber,
      'other_payment_account_name': otherPaymentAccountName,
      'price_per_session': pricePerSession,
      if (newPassword != null && newPassword.isNotEmpty) ...{
        'current_password': currentPassword,
        'new_password': newPassword,
        'new_password_confirmation': newPasswordConfirmation,
      },
    };

    final response = await _client
        .put(
          Uri.parse('${auth.baseUrl}/api/v1/trainer/profile'),
          headers: _headers(auth.token),
          body: jsonEncode(body),
        )
        .timeout(BackendApiConfig.requestTimeout);

    final payload = _decodeJson(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(
        payload,
        fallback: 'Gagal memperbarui profil trainer.',
      ));
    }

    final profile = _mapProfile(payload['data']);
    await AppSessionService.instance.updateIdentity(
      name: profile.name,
      email: profile.email,
    );
    return profile;
  }

  Future<String> uploadDisplayPhoto(File file) async {
    final auth = _authenticate();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${auth.baseUrl}/api/v1/trainer/profile/display-photo'),
    );
    request.headers['Authorization'] = 'Bearer ${auth.token}';
    request.headers['Accept'] = 'application/json';
    request.files.add(
      await http.MultipartFile.fromPath('display_photo', file.path),
    );

    final response =
        await request.send().timeout(BackendApiConfig.requestTimeout);
    final payload = _decodeJson(await response.stream.bytesToString());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        payload['message'] ?? 'Gagal mengunggah foto tampilan trainer.',
      );
    }
    final data = payload['data'];
    final path = data is Map<String, dynamic>
        ? _asString(data['display_photo_path'])
        : null;
    if (path == null) throw Exception('Response foto tampilan tidak valid.');
    return path;
  }

  Future<void> deleteDisplayPhoto() async {
    final auth = _authenticate();
    final response = await _client
        .delete(
          Uri.parse('${auth.baseUrl}/api/v1/trainer/profile/display-photo'),
          headers: _headers(auth.token),
        )
        .timeout(BackendApiConfig.requestTimeout);
    final payload = _decodeJson(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        payload['message'] ?? 'Gagal menghapus foto tampilan trainer.',
      );
    }
  }

  TrainerProfileData _mapProfile(Map<String, dynamic> data) {
    return TrainerProfileData(
      id: _asInt(data['id']),
      name: _asString(data['name']),
      email: _asString(data['email']),
      phone: _asString(data['phone']),
      specialty: _asString(data['specialty']),
      specialtyLabel: _asString(data['specialty_label']),
      specialties: _asStringList(data['specialties']),
      specialtyLabels: _asStringList(data['specialty_labels']),
      bio: _asString(data['bio']),
      rating: _asDouble(data['rating']),
      experienceYears: _asInt(data['experience_years']),
      certifications: _certificationList(data),
      availabilityNote: _asString(data['availability_note']),
      tier: mapTrainerTier(tier: data['tier'], legacyBadge: data['badge']),
      status: _asString(data['status']),
      displayPhotoPath: _asString(data['display_photo_path']),
      bankName: _asString(data['bank_name']),
      bankAccountNumber: _asString(data['bank_account_number']),
      bankAccountName: _asString(data['bank_account_name']),
      danaNumber: _asString(data['dana_number']),
      danaAccountName: _asString(data['dana_account_name']),
      otherPaymentMethod: _asString(data['other_payment_method']),
      otherPaymentNumber: _asString(data['other_payment_number']),
      otherPaymentAccountName: _asString(data['other_payment_account_name']),
      pricePerSession: _asDouble(data['price_per_session']),
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

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static List<String> _asStringList(dynamic value) => value is List
      ? value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false)
      : const [];

  static List<String> _certificationList(Map<String, dynamic> data) {
    final canonical = _asStringList(data['certifications_list']);
    if (canonical.isNotEmpty) return canonical;
    final legacy = _asString(data['certifications']);
    if (legacy == null || legacy.isEmpty) return const [];
    return legacy
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  static String _errorMessage(
    Map<String, dynamic> payload, {
    required String fallback,
  }) {
    final errors = payload['errors'];
    if (errors is Map<String, dynamic>) {
      for (final value in errors.values) {
        if (value is List && value.isNotEmpty) return value.first.toString();
        if (value is String && value.trim().isNotEmpty) return value;
      }
    }
    final message = payload['message'];
    return message is String && message.trim().isNotEmpty ? message : fallback;
  }

  static String? _asString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }
}
