/// Satu domain emel disekat (`blocked_email_domains`) - pelengkap kpd
/// senarai statik disposable-email terbenam di backend
/// (`internal/disposableemail`), tambahan management/superadmin.
class BlockedEmailDomain {
  const BlockedEmailDomain({required this.domain, required this.createdAt});

  final String domain;
  final DateTime createdAt;

  factory BlockedEmailDomain.fromJson(Map<String, dynamic> json) {
    return BlockedEmailDomain(
      domain: json['domain'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}
