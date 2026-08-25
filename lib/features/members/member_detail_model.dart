import 'package:marc/features/profile/address_providers.dart';

/// Profil SATU ahli (skrin view-only, `GET /members/:id`) - BUKAN
/// `/me`/`Profile`. Tiga peringkat keterlihatan medan dikuatkuasakan
/// SERVER-side: medan tier 2 (`email`/`phone`/`registrationPaymentStatus`)
/// dan tier 3 (`emergencyContact*`/`healthNotes`/`telegram*`/`addresses`)
/// bernilai `null` dalam JSON bila CALLER (bukan target) tak layak - client
/// TAK buat sembunyi/tunjuk sendiri berasaskan role, cuma render apa yang
/// response bagi. `null` = "disembunyikan", BUKAN "tiada nilai" - jangan
/// papar label+"-" untuk medan null, skip seksyen tu terus.
class MemberDetail {
  const MemberDetail({
    required this.userId,
    required this.memberId,
    required this.displayName,
    required this.avatarUrl,
    required this.roleKey,
    required this.roleName,
    required this.roleRank,
    required this.category,
    required this.status,
    required this.isActive,
    required this.departmentCode,
    required this.departmentName,
    required this.position,
    required this.email,
    required this.phone,
    required this.registrationPaymentStatus,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    required this.healthNotes,
    required this.telegramLinked,
    required this.telegramUsername,
    required this.addresses,
  });

  // Tier 1 - sentiasa hadir (nampak sesiapa dlm skop visibleRankCeiling).
  final String userId;
  final String memberId;
  final String? displayName;
  final String? avatarUrl;
  final String roleKey;
  final String roleName;
  final int roleRank;
  final String category;
  final String status;
  final bool isActive;
  final String? departmentCode;
  final String? departmentName;
  final String? position;

  // Tier 2 - management (supervisor/manager/superadmin) sahaja.
  final String? email;
  final String? phone;
  final String? registrationPaymentStatus;

  // Tier 3 - superadmin sahaja.
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? healthNotes;
  final bool? telegramLinked;
  final String? telegramUsername;

  /// `null` = caller tak layak (Tier 3 disembunyikan) - BEZA drpd `[]`
  /// (caller LAYAK, target cuma tiada alamat disimpan). Jangan gabung dua
  /// makna ni - seksyen Alamat wajib render utk `[]` (papar "Tiada
  /// alamat"), tapi terus tak wujud utk `null`.
  final List<AddressRow>? addresses;

  factory MemberDetail.fromJson(Map<String, dynamic> json) {
    return MemberDetail(
      userId: json['user_id'] as String,
      memberId: json['member_id'] as String,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      roleKey: (json['role_key'] as String?) ?? 'ahli',
      roleName: (json['role_name'] as String?) ?? 'Ahli',
      roleRank: (json['role_rank'] as num?)?.toInt() ?? 0,
      category: (json['category'] as String?) ?? 'ahli',
      status: (json['status'] as String?) ?? 'pending',
      isActive: (json['is_active'] as bool?) ?? true,
      departmentCode: json['department_code'] as String?,
      departmentName: json['department_name'] as String?,
      position: json['position'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      registrationPaymentStatus: json['registration_payment_status'] as String?,
      emergencyContactName: json['emergency_contact_name'] as String?,
      emergencyContactPhone: json['emergency_contact_phone'] as String?,
      healthNotes: json['health_notes'] as String?,
      telegramLinked: json['telegram_linked'] as bool?,
      telegramUsername: json['telegram_username'] as String?,
      addresses: json['addresses'] == null
          ? null
          : (json['addresses'] as List)
                .map((a) => AddressRow.fromJson(a as Map<String, dynamic>))
                .toList(),
    );
  }
}
