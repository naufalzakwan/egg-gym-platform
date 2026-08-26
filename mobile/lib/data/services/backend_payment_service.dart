import 'dart:async';
import 'dart:convert';

import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:egg_gym/data/services/backend_api_config.dart';
import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:http/http.dart' as http;

class BackendPaymentService {
  final http.Client _client;

  BackendPaymentService({http.Client? client})
      : _client = client ?? http.Client();

  Future<PakasirCheckoutSession> createMembershipCheckout({
    required int membershipPlanId,
    required String paymentMethod,
  }) async {
    final auth = _authenticate();

    final response = await _client
        .post(
          Uri.parse('${auth.baseUrl}/api/v1/member/payments/checkout'),
          headers: <String, String>{
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${auth.token}',
          },
          body: jsonEncode(<String, dynamic>{
            'membership_plan_id': membershipPlanId,
            'payment_method': paymentMethod,
          }),
        )
        .timeout(BackendApiConfig.requestTimeout);

    final payload = _decodeJson(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PaymentApiException(
          _extractMessage(payload, fallback: 'Checkout Pakasir gagal dibuat.'));
    }

    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      throw const PaymentApiException('Response checkout backend tidak valid.');
    }

    return _parseCheckoutSession(data);
  }

  /// Parse response checkout/regenerate (bentuknya identik) jadi session.
  PakasirCheckoutSession _parseCheckoutSession(Map<String, dynamic> data) {
    final transaction = _expectMap(data['transaction'], 'transaction');
    final checkout = _expectMap(data['checkout'], 'checkout');

    return PakasirCheckoutSession(
      transactionId: _asInt(transaction['id']),
      referenceCode: _asString(transaction['reference_code']),
      paymentMethod: _asString(transaction['payment_method']),
      amount: _asDouble(transaction['amount']),
      fee: _asNullableDouble(transaction['fee']),
      totalPayment: _asNullableDouble(transaction['total_payment']),
      status: _asString(transaction['status']),
      providerName: _asString(checkout['provider_name']),
      providerMethod: _asString(checkout['provider_method']),
      paymentCode: _asNullableString(checkout['payment_code']) ?? '-',
      qrString: _asNullableString(checkout['qr_string']),
      expiredAt: _parseDateTime(checkout['expired_at']),
    );
  }

  /// Regenerate pembayaran untuk transaksi PENDING yang sudah EXPIRED.
  /// Backend menandai transaksi lama 'expired' lalu membuat transaksi baru
  /// (anti-duplikasi). Mengembalikan session checkout baru (QR/VA baru).
  Future<PakasirCheckoutSession> regeneratePendingPayment(
      String referenceCode) async {
    final auth = _authenticate();

    final response = await _client.post(
      Uri.parse(
          '${auth.baseUrl}/api/v1/member/payments/$referenceCode/regenerate'),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer ${auth.token}',
      },
    ).timeout(BackendApiConfig.requestTimeout);

    final payload = _decodeJson(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PaymentApiException(_extractMessage(payload,
          fallback: 'Gagal membuat ulang pembayaran.'));
    }

    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      throw const PaymentApiException('Response regenerate tidak valid.');
    }

    return _parseCheckoutSession(data);
  }

  /// Batalkan transaksi PENDING atas permintaan user. Backend mengubah status
  /// jadi 'cancelled' (tetap tercatat di riwayat, beda dari 'expired').
  Future<void> cancelPendingPayment(String referenceCode) async {
    final auth = _authenticate();

    final response = await _client.post(
      Uri.parse('${auth.baseUrl}/api/v1/member/payments/$referenceCode/cancel'),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer ${auth.token}',
      },
    ).timeout(BackendApiConfig.requestTimeout);

    final payload = _decodeJson(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PaymentApiException(
          _extractMessage(payload, fallback: 'Gagal membatalkan pesanan.'));
    }
  }

  /// [SANDBOX/DEV ONLY] Memicu simulasi pembayaran berhasil di backend.
  /// Backend menolak (403) bila environment production. Dipakai hanya oleh
  /// tombol testing di build non-release.
  Future<void> simulatePaymentSuccess(String referenceCode) async {
    final auth = _authenticate();

    final response = await _client.post(
      Uri.parse(
          '${auth.baseUrl}/api/v1/member/payments/$referenceCode/simulate-success'),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer ${auth.token}',
      },
    ).timeout(BackendApiConfig.requestTimeout);

    final payload = _decodeJson(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PaymentApiException(_extractMessage(payload,
          fallback: 'Simulasi pembayaran gagal diproses.'));
    }
  }

  Future<MemberTransactionSnapshot> getTransactionByReference(
      String referenceCode) async {
    final auth = _authenticate();

    final response = await _client.get(
      Uri.parse('${auth.baseUrl}/api/v1/member/transactions'),
      headers: <String, String>{
        'Accept': 'application/json',
        'Authorization': 'Bearer ${auth.token}',
      },
    ).timeout(BackendApiConfig.requestTimeout);

    final payload = _decodeJson(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PaymentApiException(
        _extractMessage(payload,
            fallback: 'Gagal mengambil status transaksi member.'),
      );
    }

    final data = payload['data'];
    if (data is! List) {
      throw const PaymentApiException('Response transaksi member tidak valid.');
    }

    final item = data.cast<dynamic>().firstWhere(
          (dynamic entry) =>
              entry is Map<String, dynamic> &&
              entry['reference_code'] == referenceCode,
          orElse: () => null,
        );

    if (item is! Map<String, dynamic>) {
      throw const PaymentApiException(
          'Transaksi checkout tidak ditemukan di histori member.');
    }

    final membershipPlan = item['membership_plan'];
    final membershipPlanName = membershipPlan is Map<String, dynamic>
        ? _asNullableString(membershipPlan['name'])
        : null;

    return MemberTransactionSnapshot(
      transactionId: _asInt(item['id']),
      referenceCode: _asString(item['reference_code']),
      title: _asString(item['title']),
      paymentMethod: _asString(item['payment_method']),
      amount: _asDouble(item['amount']),
      status: _asString(item['status']),
      paidAt: _parseDateTime(item['paid_at']),
      providerReference: _asNullableString(item['provider_reference']),
      membershipPlanName: membershipPlanName,
    );
  }

  Future<MemberMembershipOverview> getMembershipOverview() async {
    final auth = _authenticate();

    final response = await _client.get(
      Uri.parse('${auth.baseUrl}/api/v1/member/memberships'),
      headers: <String, String>{
        'Accept': 'application/json',
        'Authorization': 'Bearer ${auth.token}',
      },
    ).timeout(BackendApiConfig.requestTimeout);

    final payload = _decodeJson(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PaymentApiException(
        _extractMessage(payload,
            fallback: 'Gagal mengambil data membership member.'),
      );
    }

    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      throw const PaymentApiException(
          'Response membership member tidak valid.');
    }

    final activeMembership = data['active_membership'];
    if (activeMembership is! Map<String, dynamic>) {
      return const MemberMembershipOverview(activeMembership: null);
    }

    final plan = activeMembership['plan'];
    final planMap =
        plan is Map<String, dynamic> ? plan : const <String, dynamic>{};

    return MemberMembershipOverview(
      activeMembership: ActiveMembershipSummary(
        id: _asInt(activeMembership['id']),
        planId: _asNullableInt(planMap['id']),
        planName: _asNullableString(planMap['name']) ?? 'Membership Aktif',
        planSlug: _asNullableString(planMap['slug']),
        billingPeriod: _asNullableString(planMap['billing_period']),
        price: _asNullableDouble(planMap['price']),
        startDate: _parseDateTime(activeMembership['start_date']),
        endDate: _parseDateTime(activeMembership['end_date']),
        status: _asNullableString(activeMembership['status']) ?? 'active',
        paymentStatus:
            _asNullableString(activeMembership['payment_status']) ?? 'paid',
        remainingDays: _asNullableInt(activeMembership['remaining_days']) ?? 0,
        isActive: activeMembership['is_active'] == true,
      ),
    );
  }

  /// Ambil transaksi member. [limit] null = ambil SEMUA (dipakai halaman
  /// "Semua Transaksi"); default 5 untuk ringkasan di tab Membership.
  /// Endpoint backend mengembalikan seluruh transaksi berdasarkan created_at DESC.
  /// Client menegakkan urutan yang sama sebelum [limit] agar preview dan View All
  /// konsisten meskipun urutan response berubah.
  Future<List<MemberTransactionListItem>> getMemberTransactions({
    int? limit = 5,
  }) async {
    final auth = _authenticate();

    final response = await _client.get(
      Uri.parse('${auth.baseUrl}/api/v1/member/transactions'),
      headers: <String, String>{
        'Accept': 'application/json',
        'Authorization': 'Bearer ${auth.token}',
      },
    ).timeout(BackendApiConfig.requestTimeout);

    final payload = _decodeJson(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PaymentApiException(
        _extractMessage(payload, fallback: 'Gagal mengambil transaksi member.'),
      );
    }

    final data = payload['data'];
    if (data is! List) {
      throw const PaymentApiException('Response transaksi member tidak valid.');
    }

    final items =
        data.cast<dynamic>().whereType<Map<String, dynamic>>().where((item) {
      final plan = item['membership_plan'];
      return item['type'] == 'membership' &&
          plan is Map<String, dynamic> &&
          _asNullableInt(plan['id']) != null &&
          _asNullableString(plan['name']) != null;
    }).map(
      (item) {
        final plan = item['membership_plan'] as Map<String, dynamic>;
        return MemberTransactionListItem(
          id: _asInt(item['id']),
          title: _asNullableString(plan['name'])!,
          amount: _asDouble(item['amount']),
          status: _asNullableString(item['status']) ?? 'pending',
          paymentMethod: _asNullableString(item['payment_method']),
          referenceCode: _asNullableString(item['reference_code']),
          paidAt: _parseDateTime(item['paid_at']),
          createdAt: _parseDateTime(item['created_at']),
          // Field pending (hanya ada bila status pending di resource).
          qrString: _asNullableString(item['qr_string']),
          paymentNumber: _asNullableString(item['payment_number']),
          expiredAt: _parseDateTime(item['expired_at']),
          isExpired: item['is_expired'] == true,
        );
      },
    ).toList();
    items.sort(compareMemberTransactionsNewestFirst);

    return limit == null ? items : items.take(limit).toList();
  }

  Future<List<MembershipPlan>> getPublicMembershipPlans() async {
    Object? lastError;

    for (final baseUrl in BackendApiConfig.candidateBaseUrls) {
      try {
        final response = await _client.get(
          Uri.parse('$baseUrl/api/v1/public/membership-plans'),
          headers: const <String, String>{
            'Accept': 'application/json',
          },
        ).timeout(BackendApiConfig.requestTimeout);

        final payload = _decodeJson(response.body);

        if (response.statusCode < 200 || response.statusCode >= 300) {
          lastError = PaymentApiException(
            _extractMessage(
              payload,
              fallback: 'Gagal mengambil daftar paket membership dari backend.',
            ),
          );
          continue;
        }

        final data = payload['data'];
        if (data is! List) {
          lastError = const PaymentApiException(
            'Response paket membership backend tidak valid.',
          );
          continue;
        }

        return data
            .cast<dynamic>()
            .whereType<Map<String, dynamic>>()
            .map(_mapMembershipPlan)
            .toList();
      } on TimeoutException {
        lastError = PaymentApiException(
          'Aplikasi timeout saat mengambil paket membership dari backend.',
        );
      } catch (error) {
        lastError = error;
      }
    }

    if (lastError is PaymentApiException) {
      throw lastError;
    }

    throw const PaymentApiException(
      'App belum bisa mengambil daftar paket membership dari backend Laravel.',
    );
  }

  AppAuthenticatedSession _authenticate() {
    final session = AppSessionService.instance.currentSession;

    if (session == null) {
      throw const PaymentApiException(
        'Masuk sebagai member dulu sebelum membuka checkout atau status pembayaran.',
      );
    }

    if (session.role != 'member') {
      throw const PaymentApiException(
        'Checkout membership hanya tersedia untuk akun member yang sedang login.',
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

    throw const PaymentApiException(
        'Response backend bukan JSON object yang valid.');
  }

  Map<String, dynamic> _expectMap(dynamic value, String label) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    throw PaymentApiException(
        'Bagian $label pada response backend tidak valid.');
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

        if (value is Map<String, dynamic>) {
          final nested = _extractMessage(value, fallback: fallback);
          if (nested != fallback) {
            return nested;
          }
        }
      }
    }

    return fallback;
  }

  static int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.parse(value.toString());
  }

  static int? _asNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }

    return _asInt(value);
  }

  static double _asDouble(dynamic value) {
    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.parse(value.toString());
  }

  static double? _asNullableDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    return _asDouble(value);
  }

  static String _asString(dynamic value) {
    final stringValue = _asNullableString(value);
    if (stringValue == null || stringValue.isEmpty) {
      throw const PaymentApiException(
          'Response backend kehilangan string wajib.');
    }

    return stringValue;
  }

  static String? _asNullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    final stringValue = value.toString();
    return stringValue.isEmpty ? null : stringValue;
  }

  static DateTime? _parseDateTime(dynamic value) {
    final stringValue = _asNullableString(value);
    if (stringValue == null) {
      return null;
    }

    return DateTime.tryParse(stringValue)?.toLocal();
  }

  MembershipPlan _mapMembershipPlan(Map<String, dynamic> item) {
    final title = _asNullableString(item['name']) ??
        _asNullableString(item['title']) ??
        'Membership Plan';
    final slug = _asNullableString(item['slug']);
    final billingPeriod =
        _asNullableString(item['billing_period']) ?? 'monthly';
    final price = _asNullableDouble(item['price']) ?? 0;
    final features =
        _extractFeatures(item['features'] ?? item['features_json']);

    return MembershipPlan(
      backendId: _asNullableInt(item['id']),
      slug: slug,
      title: title,
      subtitle: '',
      priceLabel: _formatFullRupiah(price),
      periodLabel: _periodLabelForBillingPeriod(billingPeriod),
      priceValue: price,
      billingPeriod: billingPeriod,
      durationDays: _asNullableInt(item['duration_days']),
      features: features,
      badge: _resolvePlanBadge(item, slug, title),
      isHighlighted: item['is_featured'] == true ||
          title.toLowerCase().contains('elite') ||
          slug == 'elite-member',
      isBestSeller: item['is_best_seller'] == true,
    );
  }

  List<String> _extractFeatures(dynamic rawValue) {
    if (rawValue is List) {
      return rawValue
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    if (rawValue is String && rawValue.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawValue);
        if (decoded is List) {
          return decoded
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList();
        }
      } catch (_) {
        return const <String>[];
      }
    }

    return const <String>[];
  }

  String? _resolvePlanBadge(
    Map<String, dynamic> item,
    String? slug,
    String title,
  ) {
    final backendBadge =
        _asNullableString(item['badge']) ?? _asNullableString(item['label']);
    if (backendBadge != null && backendBadge.isNotEmpty) {
      return backendBadge;
    }

    if (item['is_featured'] == true ||
        title.toLowerCase().contains('elite') ||
        slug == 'elite-member') {
      return 'Best Deal';
    }

    return null;
  }

  String _periodLabelForBillingPeriod(String billingPeriod) {
    return switch (billingPeriod.toLowerCase()) {
      'yearly' => ' / Tahun',
      'weekly' => ' / Minggu',
      'daily' => ' / Hari',
      _ => ' / Bulan',
    };
  }

  // Format penuh dengan pemisah ribuan titik: 549000 -> "Rp 549.000".
  // Angka dari data backend (price), hanya cara formatnya yang diubah.
  String _formatFullRupiah(double value) {
    final whole = value.round().toString();
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
}

class PaymentApiException implements Exception {
  const PaymentApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PakasirCheckoutSession {
  const PakasirCheckoutSession({
    required this.transactionId,
    required this.referenceCode,
    required this.paymentMethod,
    required this.amount,
    required this.fee,
    required this.totalPayment,
    required this.status,
    required this.providerName,
    required this.providerMethod,
    required this.paymentCode,
    required this.qrString,
    required this.expiredAt,
  });

  final int transactionId;
  final String referenceCode;
  final String paymentMethod;
  final double amount;
  final double? fee;
  final double? totalPayment;
  final String status;
  final String providerName;
  final String providerMethod;
  final String paymentCode;
  final String? qrString;
  final DateTime? expiredAt;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'transactionId': transactionId,
      'referenceCode': referenceCode,
      'paymentMethod': paymentMethod,
      'amount': amount,
      'fee': fee,
      'totalPayment': totalPayment,
      'status': status,
      'providerName': providerName,
      'providerMethod': providerMethod,
      'paymentCode': paymentCode,
      'qrString': qrString,
      'expiredAt': expiredAt?.toIso8601String(),
    };
  }

  factory PakasirCheckoutSession.fromMap(Map<String, dynamic> map) {
    return PakasirCheckoutSession(
      transactionId: BackendPaymentService._asInt(map['transactionId']),
      referenceCode: BackendPaymentService._asString(map['referenceCode']),
      paymentMethod: BackendPaymentService._asString(map['paymentMethod']),
      amount: BackendPaymentService._asDouble(map['amount']),
      fee: BackendPaymentService._asNullableDouble(map['fee']),
      totalPayment:
          BackendPaymentService._asNullableDouble(map['totalPayment']),
      status: BackendPaymentService._asString(map['status']),
      providerName: BackendPaymentService._asString(map['providerName']),
      providerMethod: BackendPaymentService._asString(map['providerMethod']),
      paymentCode: BackendPaymentService._asString(map['paymentCode']),
      qrString: BackendPaymentService._asNullableString(map['qrString']),
      expiredAt: BackendPaymentService._parseDateTime(map['expiredAt']),
    );
  }
}

class MemberTransactionSnapshot {
  const MemberTransactionSnapshot({
    required this.transactionId,
    required this.referenceCode,
    required this.title,
    required this.paymentMethod,
    required this.amount,
    required this.status,
    required this.paidAt,
    required this.providerReference,
    required this.membershipPlanName,
  });

  final int transactionId;
  final String referenceCode;
  final String title;
  final String paymentMethod;
  final double amount;
  final String status;
  final DateTime? paidAt;
  final String? providerReference;
  final String? membershipPlanName;
}

class MemberMembershipOverview {
  const MemberMembershipOverview({
    required this.activeMembership,
  });

  final ActiveMembershipSummary? activeMembership;
}

class ActiveMembershipSummary {
  const ActiveMembershipSummary({
    required this.id,
    required this.planId,
    required this.planName,
    required this.planSlug,
    required this.billingPeriod,
    required this.price,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.paymentStatus,
    required this.remainingDays,
    required this.isActive,
  });

  final int id;
  final int? planId;
  final String planName;
  final String? planSlug;
  final String? billingPeriod;
  final double? price;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status;
  final String paymentStatus;
  final int remainingDays;
  final bool isActive;
}

class MemberTransactionListItem {
  const MemberTransactionListItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.status,
    required this.paymentMethod,
    required this.referenceCode,
    required this.paidAt,
    this.createdAt,
    this.qrString,
    this.paymentNumber,
    this.expiredAt,
    this.isExpired = false,
  });

  final int id;
  final String title;
  final double amount;
  final String status;
  final String? paymentMethod;
  final String? referenceCode;
  final DateTime? paidAt;
  // Waktu transaksi dibuat (created_at) -- dipakai untuk tampilan tanggal/waktu
  // semua status (termasuk pending/cancelled/expired yang tak punya paid_at).
  final DateTime? createdAt;
  // Data pembayaran PENDING (dari resource, hanya untuk status pending).
  // qr_string: untuk QRIS; paymentNumber: kode QR/VA; isExpired dihitung SERVER.
  final String? qrString;
  final String? paymentNumber;
  final DateTime? expiredAt;
  final bool isExpired;
}

int compareMemberTransactionsNewestFirst(
  MemberTransactionListItem left,
  MemberTransactionListItem right,
) {
  final dateComparison =
      _transactionChronology(right).compareTo(_transactionChronology(left));
  if (dateComparison != 0) return dateComparison;

  return right.id.compareTo(left.id);
}

DateTime _transactionChronology(MemberTransactionListItem item) =>
    item.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
