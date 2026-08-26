import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:egg_gym/data/services/backend_api_config.dart';
import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:http/http.dart' as http;

class BookingPaymentInfo {
  const BookingPaymentInfo({
    required this.bookingId,
    required this.status,
    this.trainerName,
    this.bankName,
    this.bankAccountNumber,
    this.bankAccountName,
    this.danaNumber,
    this.danaAccountName,
    this.otherPaymentMethod,
    this.otherPaymentNumber,
    this.otherPaymentAccountName,
    this.paymentProofPath,
    this.pricePerSession,
    this.totalAmount,
    this.sessionCount = 1,
    this.reservations = const [],
    this.expiredAt,
    this.remainingSeconds = 0,
    this.expiryStage,
    this.isExpired = false,
    this.isPaymentVerificationOverdue = false,
    this.paymentVerificationOverdueSeconds = 0,
  });

  final int bookingId;
  final String status;
  final String? trainerName;
  final String? bankName;
  final String? bankAccountNumber;
  final String? bankAccountName;
  final String? danaNumber;
  final String? danaAccountName;
  final String? otherPaymentMethod;
  final String? otherPaymentNumber;
  final String? otherPaymentAccountName;
  final String? paymentProofPath;

  /// Harga per sesi milik trainer (null jika trainer belum set harga).
  final double? pricePerSession;
  final double? totalAmount;

  /// Jumlah sesi yang tersimpan di booking (default 1).
  final int sessionCount;
  final List<BookingPaymentReservation> reservations;
  final DateTime? expiredAt;
  final int remainingSeconds;
  final String? expiryStage;
  final bool isExpired;
  final bool isPaymentVerificationOverdue;
  final int paymentVerificationOverdueSeconds;
}

class BookingPaymentReservation {
  const BookingPaymentReservation({
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

class BackendBookingPaymentService {
  BackendBookingPaymentService({http.Client? client})
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

  Future<BookingPaymentInfo> getPaymentInfo(int bookingId) async {
    final auth = _authenticate();
    final response = await _client.get(
      Uri.parse(
          '${auth.baseUrl}/api/v1/member/bookings/$bookingId/payment-info'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer ${auth.token}',
      },
    ).timeout(BackendApiConfig.requestTimeout);

    final payload = _decodeJson(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(payload['message'] ?? 'Gagal mengambil info pembayaran.');
    }

    final data = payload['data'];
    final trainer = data['trainer'] as Map<String, dynamic>? ?? {};

    return BookingPaymentInfo(
      bookingId: _asInt(data['booking_id']) ?? bookingId,
      status: _asString(data['status']) ?? 'unknown',
      trainerName: _asString(trainer['name']),
      bankName: _asString(trainer['bank_name']),
      bankAccountNumber: _asString(trainer['bank_account_number']),
      bankAccountName: _asString(trainer['bank_account_name']),
      danaNumber: _asString(trainer['dana_number']),
      danaAccountName: _asString(trainer['dana_account_name']),
      otherPaymentMethod: _asString(trainer['other_payment_method']),
      otherPaymentNumber: _asString(trainer['other_payment_number']),
      otherPaymentAccountName: _asString(trainer['other_payment_account_name']),
      paymentProofPath: _asString(data['payment_proof_path']),
      pricePerSession: _asDouble(data['price_per_session']) ??
          _asDouble(trainer['price_per_session']),
      totalAmount: _asDouble(data['total_amount']),
      sessionCount: _asInt(data['session_count']) ?? 1,
      reservations: (data['session_reservations'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((reservation) => BookingPaymentReservation(
                sequenceOrder: _asInt(reservation['sequence_order']) ?? 0,
                sessionDate: _asString(reservation['session_date']) ?? '-',
                startTime: _asString(reservation['start_time']) ?? '-',
                endTime: _asString(reservation['end_time']) ?? '-',
                status: _asString(reservation['status']) ?? 'reserved',
              ))
          .toList(growable: false),
      expiredAt: DateTime.tryParse(_asString(data['expired_at']) ?? ''),
      remainingSeconds: _asInt(data['remaining_seconds']) ?? 0,
      expiryStage: _asString(data['expiry_stage']),
      isExpired: data['is_expired'] == true,
      isPaymentVerificationOverdue:
          data['is_payment_verification_overdue'] == true,
      paymentVerificationOverdueSeconds:
          _asInt(data['payment_verification_overdue_seconds']) ?? 0,
    );
  }

  Future<void> uploadProof(int bookingId, File file) async {
    final auth = _authenticate();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
          '${auth.baseUrl}/api/v1/member/bookings/$bookingId/upload-proof'),
    );
    request.headers['Authorization'] = 'Bearer ${auth.token}';
    request.headers['Accept'] = 'application/json';
    request.files.add(await http.MultipartFile.fromPath(
      'payment_proof',
      file.path,
    ));

    final response = await request.send();
    final body = await response.stream.bytesToString();
    final payload = _decodeJson(body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(payload['message'] ?? 'Gagal upload bukti pembayaran.');
    }
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
}
