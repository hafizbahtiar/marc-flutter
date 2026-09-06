class BannedMember {
  const BannedMember({
    required this.userId,
    this.memberId,
    this.displayName,
    required this.email,
    required this.roleKey,
    required this.bannedAt,
    this.expiresAt,
    required this.reason,
  });

  final String userId;
  final String? memberId;
  final String? displayName;
  final String email;
  final String roleKey;
  final DateTime bannedAt;
  final DateTime? expiresAt;
  final String reason;

  bool get isPermanent => expiresAt == null;

  factory BannedMember.fromJson(Map<String, dynamic> json) => BannedMember(
    userId: json['user_id'] as String,
    memberId: json['member_id'] as String?,
    displayName: json['display_name'] as String?,
    email: json['email'] as String? ?? '',
    roleKey: json['role_key'] as String? ?? '',
    bannedAt: DateTime.parse(json['banned_at'] as String),
    expiresAt: _dateOrNull(json['ban_expires_at'] as String?),
    reason: json['ban_reason'] as String? ?? '',
  );
}

DateTime? _dateOrNull(String? value) =>
    value == null ? null : DateTime.tryParse(value);
