class AccountDeletionRow {
  const AccountDeletionRow({
    required this.userId,
    this.memberId,
    this.displayName,
    required this.email,
    required this.roleKey,
    required this.accountStatus,
    required this.status,
    required this.requestedAt,
    this.completedAt,
  });

  final String userId;
  final String? memberId;
  final String? displayName;
  final String email;
  final String roleKey;
  final String accountStatus;
  final String status;
  final DateTime requestedAt;
  final DateTime? completedAt;

  factory AccountDeletionRow.fromJson(Map<String, dynamic> json) {
    return AccountDeletionRow(
      userId: json['user_id'] as String,
      memberId: json['member_id'] as String?,
      displayName: json['display_name'] as String?,
      email: json['email'] as String? ?? '',
      roleKey: json['role_key'] as String? ?? '',
      accountStatus: json['account_status'] as String? ?? '',
      status: json['status'] as String? ?? '',
      requestedAt: DateTime.parse(json['requested_at'] as String),
      completedAt: _dateOrNull(json['completed_at'] as String?),
    );
  }
}

DateTime? _dateOrNull(String? value) =>
    value == null ? null : DateTime.tryParse(value);
