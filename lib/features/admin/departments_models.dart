/// Satu bahagian/jabatan organisasi (`departments`) - rujukan superadmin
/// urus, padanan corak `BlockedEmailDomain`.
class Department {
  const Department({
    required this.code,
    required this.name,
    required this.sortOrder,
    required this.createdAt,
  });

  final String code;
  final String name;
  final int sortOrder;
  final DateTime createdAt;

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      code: json['code'] as String,
      name: json['name'] as String,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}
