/// Satu catatan jejak audit (`GET /audit-logs`).
class AuditLog {
  const AuditLog({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.actorMemberId,
    required this.actorRoleKey,
    required this.changedFields,
    required this.oldValues,
    required this.newValues,
    required this.createdAt,
  });

  final int id;
  final String entityType;
  final String entityId;
  final String action;

  /// Snapshot pada masa tindakan - bukan role semasa pelaku.
  final String? actorMemberId;
  final String? actorRoleKey;

  final List<String> changedFields;

  /// Delta sahaja untuk 'update'; snapshot penuh untuk 'delete'/'create'.
  /// `null` di sebelah yang tak berkenaan (create tiada old, delete tiada new).
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;

  final DateTime createdAt;

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: (json['id'] as num).toInt(),
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String,
      action: json['action'] as String,
      actorMemberId: json['actor_member_id'] as String?,
      actorRoleKey: json['actor_role_key'] as String?,
      changedFields:
          (json['changed_fields'] as List?)?.cast<String>() ?? const [],
      oldValues: (json['old_values'] as Map?)?.cast<String, dynamic>(),
      newValues: (json['new_values'] as Map?)?.cast<String, dynamic>(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Label BM untuk jenis entiti. Fallback kepada kunci mentah supaya
  /// entiti baharu di backend tetap boleh dibaca sebelum app dikemas kini.
  String get entityLabel => switch (entityType) {
    'post' => 'Post',
    'comment' => 'Comment',
    'profile' => 'Ahli',
    _ => entityType,
  };

  String get actionLabel => switch (action) {
    'create' => 'Dicipta',
    'update' => 'Dikemas kini',
    'delete' => 'Dipadam',
    _ => action,
  };
}
