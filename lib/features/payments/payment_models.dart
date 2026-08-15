/// Satu percubaan yuran pendaftaran (`registration_payments`) — boleh
/// lebih drpd satu baris seorang ahli (percubaan gagal/cuba semula).
class RegistrationPaymentEntry {
  const RegistrationPaymentEntry({
    required this.id,
    required this.amountCents,
    required this.currency,
    required this.gateway,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final int amountCents;
  final String currency;
  final String gateway;

  /// "pending" / "succeeded" / "failed".
  final String status;
  final DateTime createdAt;

  factory RegistrationPaymentEntry.fromJson(Map<String, dynamic> json) {
    return RegistrationPaymentEntry(
      id: json['id'] as String,
      amountCents: (json['amount_cents'] as num).toInt(),
      currency: json['currency'] as String,
      gateway: json['gateway'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}

/// Satu pendaftaran aktiviti yang PERNAH perlukan bayaran
/// (`payment_status <> 'not_required'`) — TERMASUK yang telah dibatalkan,
/// beza drpd `MyRegistration` (activity_models.dart) yang kuasakan tab
/// "Aktiviti Saya" (aktif sahaja).
class ActivityPaymentEntry {
  const ActivityPaymentEntry({
    required this.registrationId,
    required this.activityId,
    required this.title,
    required this.feeCents,
    required this.currency,
    required this.startsAt,
    required this.registrationStatus,
    required this.paymentStatus,
    required this.registeredAt,
  });

  final String registrationId;
  final String activityId;
  final String title;
  final int feeCents;
  final String currency;
  final DateTime startsAt;

  /// Status PENDAFTARAN — "registered" / "cancelled" dll (bukan bayaran).
  final String registrationStatus;

  /// "pending" / "paid" / "refunded".
  final String paymentStatus;
  final DateTime registeredAt;

  factory ActivityPaymentEntry.fromJson(Map<String, dynamic> json) {
    return ActivityPaymentEntry(
      registrationId: json['registration_id'] as String,
      activityId: json['activity_id'] as String,
      title: json['title'] as String,
      feeCents: (json['fee_cents'] as num).toInt(),
      currency: json['currency'] as String,
      startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
      registrationStatus: json['registration_status'] as String,
      paymentStatus: json['payment_status'] as String,
      registeredAt: DateTime.parse(json['registered_at'] as String).toLocal(),
    );
  }
}

/// Sejarah bayaran seorang ahli (`GET /me/payments`) — dua senarai
/// berasingan, padanan bentuk respons backend.
class MyPaymentHistory {
  const MyPaymentHistory({
    required this.registrationFee,
    required this.activityFees,
  });

  final List<RegistrationPaymentEntry> registrationFee;
  final List<ActivityPaymentEntry> activityFees;

  factory MyPaymentHistory.fromJson(Map<String, dynamic> json) {
    return MyPaymentHistory(
      registrationFee: (json['registration_fee'] as List)
          .map(
            (e) => RegistrationPaymentEntry.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      activityFees: (json['activity_fees'] as List)
          .map((e) => ActivityPaymentEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Satu catatan `payment_logs` (`GET /admin/payments`) — tinjauan merentas
/// modul untuk pengurusan. SENGAJA tiada raw_payload (lihat komen backend
/// `paymentLogItem`) — payload gateway mentah boleh bawa PII, tak
/// didedahkan menerusi API ni.
class PaymentLogEntry {
  const PaymentLogEntry({
    required this.id,
    required this.module,
    required this.event,
    required this.status,
    required this.gateway,
    required this.gatewayRef,
    required this.amountCents,
    required this.userId,
    required this.relatedId,
    required this.message,
    required this.createdAt,
  });

  final int id;

  /// "donation" / "registration_fee" / "activity_fee".
  final String module;
  final String event;
  final String status;
  final String gateway;
  final String? gatewayRef;
  final int? amountCents;
  final String? userId;
  final String? relatedId;
  final String? message;
  final DateTime createdAt;

  factory PaymentLogEntry.fromJson(Map<String, dynamic> json) {
    return PaymentLogEntry(
      id: (json['id'] as num).toInt(),
      module: json['module'] as String,
      event: json['event'] as String,
      status: json['status'] as String,
      gateway: json['gateway'] as String,
      gatewayRef: json['gateway_ref'] as String?,
      amountCents: (json['amount_cents'] as num?)?.toInt(),
      userId: json['user_id'] as String?,
      relatedId: json['related_id'] as String?,
      message: json['message'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  String get moduleLabel => switch (module) {
    'donation' => 'Derma',
    'registration_fee' => 'Yuran Pendaftaran',
    'activity_fee' => 'Yuran Aktiviti',
    _ => module,
  };
}
