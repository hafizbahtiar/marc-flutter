import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/core/auth_state.dart';
import 'package:marc/features/members/member_providers.dart';

class Profile {
  const Profile({
    required this.memberId,
    required this.email,
    required this.emailVerified,
    required this.status,
    required this.displayName,
    required this.phone,
    required this.roleKey,
    required this.roleName,
    required this.roleRank,
    required this.category,
    this.avatarUrl,
    this.registrationPaymentStatus,
    this.registrationFeeCents,
    required this.telegramLinked,
    this.telegramUsername,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.healthNotes,
    this.isActive = true,
    this.departmentCode,
    this.departmentName,
    this.position,
  });

  /// Null sehingga nombor staff disahkan - `generateMemberID` ditangguh
  /// ke `VerifyStaffID`. Papar "Belum disahkan" / "-" di UI, jangan
  /// andai sentiasa diisi.
  final String? memberId;
  final String email;
  final bool emailVerified;
  final String status;
  final String? displayName;
  final String? phone;
  final String roleKey;
  final String roleName;
  final int roleRank;
  final String category;

  /// null = tiada gambar profil.
  final String? avatarUrl;

  /// "pending"/"succeeded"/"failed", atau null kalau ahli tak pernah
  /// cuba bayar yuran pendaftaran langsung. Backend cuma isi bila
  /// `status != 'approved'` (lihat `profile.go` Me).
  final String? registrationPaymentStatus;

  /// Jumlah (sen) yuran pendaftaran SEMASA - cuma diisi bila
  /// `status != 'approved'` (lihat `profile.go` Me), padan skop
  /// [registrationPaymentStatus]. Papar ni SEBELUM ahli tekan bayar -
  /// checkout ToyyibPay sendiri tak dedah jumlah dalam app, cuma
  /// redirect ke halaman ToyyibPay.
  final int? registrationFeeCents;

  final bool telegramLinked;
  final String? telegramUsername;

  /// Nama waris/kenalan kecemasan - null = belum diisi.
  final String? emergencyContactName;

  /// No. telefon waris/kenalan kecemasan - null = belum diisi.
  final String? emergencyContactPhone;

  /// Nota tahap kesihatan (freeform) - null = belum diisi.
  final String? healthNotes;

  /// Status keahlian aktif/tak aktif - BUKAN status kelulusan ([status]
  /// pending/approved/rejected kekal berasingan). Management sahaja boleh
  /// tukar, via `PATCH /members/:id/active`.
  final bool isActive;

  /// Bahagian/jawatan - baca sahaja di sini, cuma manager ke atas boleh
  /// tukar (via `PATCH /members/:id/department`), BUKAN self-service.
  /// `departmentCode` = kod rujukan (`departments.code`), `departmentName`
  /// = nama penuh terjoin (papar, jangan pilih drpd ni). `null` = belum
  /// ditetapkan.
  final String? departmentCode;
  final String? departmentName;
  final String? position;

  bool get isManagement => category == 'management';

  bool get registrationPaymentFailed => registrationPaymentStatus == 'failed';
  bool get registrationPaymentSucceeded =>
      registrationPaymentStatus == 'succeeded';
  bool get registrationPaymentPending => registrationPaymentStatus == 'pending';

  Profile copyWith({
    Object? avatarUrl = _sentinel,
    bool? telegramLinked,
    Object? telegramUsername = _sentinel,
  }) {
    return Profile(
      memberId: memberId,
      email: email,
      emailVerified: emailVerified,
      status: status,
      displayName: displayName,
      phone: phone,
      roleKey: roleKey,
      roleName: roleName,
      roleRank: roleRank,
      category: category,
      avatarUrl: avatarUrl == _sentinel ? this.avatarUrl : avatarUrl as String?,
      registrationPaymentStatus: registrationPaymentStatus,
      registrationFeeCents: registrationFeeCents,
      telegramLinked: telegramLinked ?? this.telegramLinked,
      telegramUsername: telegramUsername == _sentinel
          ? this.telegramUsername
          : telegramUsername as String?,
      emergencyContactName: emergencyContactName,
      emergencyContactPhone: emergencyContactPhone,
      healthNotes: healthNotes,
      isActive: isActive,
      departmentCode: departmentCode,
      departmentName: departmentName,
      position: position,
    );
  }

  static const _sentinel = Object();

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      memberId: switch (json['member_id']) {
        final String s when s.trim().isEmpty => null,
        final String s => s,
        _ => null,
      },
      email: json['email'] as String,
      emailVerified: (json['email_verified'] as bool?) ?? false,
      status: (json['status'] as String?) ?? 'pending',
      displayName: json['display_name'] as String?,
      phone: json['phone'] as String?,
      roleKey: (json['role_key'] as String?) ?? 'ahli',
      roleName: (json['role_name'] as String?) ?? 'Ahli',
      roleRank: (json['role_rank'] as num?)?.toInt() ?? 0,
      category: (json['category'] as String?) ?? 'ahli',
      avatarUrl: json['avatar_url'] as String?,
      registrationPaymentStatus: json['registration_payment_status'] as String?,
      registrationFeeCents: (json['registration_fee_cents'] as num?)?.toInt(),
      telegramLinked: (json['telegram_linked'] as bool?) ?? false,
      telegramUsername: json['telegram_username'] as String?,
      emergencyContactName: json['emergency_contact_name'] as String?,
      emergencyContactPhone: json['emergency_contact_phone'] as String?,
      healthNotes: json['health_notes'] as String?,
      isActive: (json['is_active'] as bool?) ?? true,
      departmentCode: json['department_code'] as String?,
      departmentName: json['department_name'] as String?,
      position: json['position'] as String?,
    );
  }
}

/// Profil user semasa. Reaktif pada status log masuk - jadi ia re-fetch
/// sebaik sahaja sesi wujud (tak perlu hot restart).
final myProfileProvider = FutureProvider<Profile?>((ref) async {
  final isLoggedIn = ref.watch(
    authNotifierProvider.select((s) => s.isLoggedIn),
  );
  if (!isLoggedIn) return null;

  final dio = ref.watch(dioProvider);
  final res = await dio.get('/me');
  return Profile.fromJson(res.data as Map<String, dynamic>);
});

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref),
);

class ProfileRepository {
  ProfileRepository(this._ref);
  final Ref _ref;

  /// Kemas kini display name, phone & medan waris/kesihatan user semasa.
  ///
  /// [emergencyContactName]/[emergencyContactPhone]/[healthNotes] opsyenal
  /// (pointer semantik padanan `display_name`/`phone`) - `null` = tak
  /// hantar medan tu langsung (backend tak ubah nilai sedia ada). Hantar
  /// string kosong utk buang nilai.
  Future<void> update({
    required String displayName,
    required String phone,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? healthNotes,
  }) async {
    final dio = _ref.read(dioProvider);
    await dio.patch(
      '/me',
      data: {
        'display_name': displayName,
        'phone': phone,
        'emergency_contact_name': ?emergencyContactName,
        'emergency_contact_phone': ?emergencyContactPhone,
        'health_notes': ?healthNotes,
      },
    );

    _ref.invalidate(myProfileProvider);
    // membersProvider papar display_name yang sama - tanpa invalidate ni,
    // tab Ahli kekal papar nama lama sampai logout/restart (non-autoDispose,
    // cuma recompute bila isLoggedIn berubah).
    _ref.invalidate(membersProvider);
  }

  /// Minta padam akaun - rekod permintaan sahaja (bukan padam serta-merta),
  /// pasukan MARC proses secara manual. Idempoten di server (panggil dua
  /// kali pulangkan rekod ASAL yang sama, bukan ralat).
  Future<void> requestAccountDeletion() async {
    final dio = _ref.read(dioProvider);
    await dio.post('/me/deletion-request');
  }

  /// Tukar status aktif/tak aktif ahli - management sahaja (backend
  /// kuatkuasakan hierarki rank, client cuma hantar niat), padanan pola
  /// [updateMemberRole].
  Future<void> updateMemberActive(String userId, bool isActive) async {
    final dio = _ref.read(dioProvider);
    await dio.patch('/members/$userId/active', data: {'is_active': isActive});
    _ref.invalidate(membersProvider);
    _ref.invalidate(memberDetailProvider(userId));
  }

  /// Tukar bahagian/jawatan ahli - manager ke atas SAHAJA (backend
  /// kuatkuasakan "setaraf & ke bawah", BEZA drpd [updateMemberRole]/
  /// [updateMemberActive] yang "strictly lebih tinggi"). GANTI PENUH:
  /// `null`/kosong = kosongkan, kod/teks bukan-kosong = tetapkan.
  ///
  /// Backend benarkan self-assignment (tiada sekatan userId == caller) -
  /// invalidate [myProfileProvider] juga (bukan cuma [membersProvider]),
  /// kalau tidak profil sendiri kekal stale sehingga logout/restart.
  Future<void> updateMemberDepartment(
    String userId, {
    String? departmentCode,
    String? position,
  }) async {
    final dio = _ref.read(dioProvider);
    await dio.patch(
      '/members/$userId/department',
      data: {'department_code': departmentCode, 'position': position},
    );
    _ref.invalidate(membersProvider);
    _ref.invalidate(myProfileProvider);
    _ref.invalidate(memberDetailProvider(userId));
  }

  /// Luluskan pendaftaran ahli (Stage 11) - management sahaja, backend
  /// tolak 403 kalau bukan.
  ///
  /// [bypassReason] - langkau gate bayaran yuran pendaftaran untuk ahli
  /// lama yang dah bayar secara manual sebelum sistem digital wujud.
  /// Backend hakim sebenar: cuma admin/superadmin (rank >= "admin")
  /// dibenarkan, dan nota WAJIB bila bypass digunakan - client cuma
  /// hantar niat (lihat [isAdminOrAboveProvider]).
  Future<void> approveMember(String userId, {String? bypassReason}) async {
    final dio = _ref.read(dioProvider);
    await dio.post(
      '/members/$userId/approve',
      data: bypassReason == null
          ? null
          : {'bypass_payment': true, 'bypass_reason': bypassReason},
    );
    _ref.invalidate(membersProvider);
    _ref.invalidate(pendingMembersProvider);
  }

  /// Tolak pendaftaran ahli (Stage 11) - row KEKAL di backend (bukan
  /// padam), boleh diluluskan semula lain kali.
  Future<void> rejectMember(String userId) async {
    final dio = _ref.read(dioProvider);
    await dio.post('/members/$userId/reject');
    _ref.invalidate(membersProvider);
    _ref.invalidate(pendingMembersProvider);
  }

  /// Batalkan bil yuran pendaftaran 'pending' ahli - admin/superadmin
  /// sahaja. Supaya laluan langkau bayaran boleh digunakan selepas bil
  /// online tamat/dibatalkan (backend semak gateway dulu).
  Future<void> cancelRegistrationPayment(String userId) async {
    final dio = _ref.read(dioProvider);
    await dio.post('/members/$userId/cancel-registration-payment');
    _ref.invalidate(membersProvider);
    _ref.invalidate(pendingMembersProvider);
  }

  /// Sahkan nombor staff ahli pending (rank manager ke atas).
  /// [staffId] pilihan - betulkan salah taip semasa verify pertama.
  Future<void> verifyStaffID(String userId, {String? staffId}) async {
    final dio = _ref.read(dioProvider);
    await dio.post(
      '/members/$userId/verify-staff-id',
      data: staffId == null ? null : {'staff_id': staffId},
    );
    _ref.invalidate(membersProvider);
    _ref.invalidate(pendingMembersProvider);
    _ref.invalidate(memberDetailProvider(userId));
  }

  /// Betulkan nombor staff bila-bila masa (rank admin/superadmin).
  /// Tidak menyentuh status verified / member_id.
  Future<void> correctStaffID(String userId, String staffId) async {
    final dio = _ref.read(dioProvider);
    await dio.patch('/members/$userId/staff-id', data: {'staff_id': staffId});
    _ref.invalidate(membersProvider);
    _ref.invalidate(pendingMembersProvider);
    _ref.invalidate(memberDetailProvider(userId));
  }

  /// Tukar role ahli (Stage 12) - backend kuatkuasakan hierarki rank,
  /// client cuma hantar niat.
  Future<void> updateMemberRole(String userId, String roleKey) async {
    final dio = _ref.read(dioProvider);
    await dio.patch('/members/$userId/role', data: {'role_key': roleKey});
    _ref.invalidate(membersProvider);
    _ref.invalidate(memberDetailProvider(userId));
  }
}

class MemberRow {
  const MemberRow({
    required this.userId,
    required this.memberId,
    required this.displayName,
    required this.email,
    required this.roleKey,
    required this.roleName,
    required this.roleRank,
    required this.category,
    required this.status,
    this.avatarUrl,
    this.registrationPaymentStatus,
    this.isActive = true,
    this.departmentCode,
    this.departmentName,
    this.position,
    this.staffId,
    this.staffIdVerifiedAt,
  });

  final String userId;

  /// Null untuk ahli pending yang belum diverify nombor staff.
  final String? memberId;
  final String? displayName;

  /// `null` = backend sembunyikan (emel ahli lain cuma didedahkan kepada
  /// management). BUKAN bermakna ahli tu tiada emel - bezakan dua-dua,
  /// jangan papar ruang kosong.
  final String? email;
  final String roleKey;
  final String roleName;
  final int roleRank;
  final String category;
  final String status;

  /// null = tiada gambar profil.
  final String? avatarUrl;

  /// "pending"/"succeeded"/"failed", atau null. Backend cuma isi nilai
  /// sebenar untuk management (lihat `registration_payment_status` di
  /// `ListVisibleProfiles`) - ahli biasa dapat null, sama pola dengan
  /// [email]. Ditambah 2026-08-15 supaya senarai kelulusan papar status
  /// bayaran sebelum management tekan Luluskan.
  final String? registrationPaymentStatus;

  /// Status keahlian aktif/tak aktif - default `true` kalau backend tak
  /// hantar (lihat komen [Profile.isActive]).
  final bool isActive;

  /// Bahagian/jawatan - padanan [Profile.departmentCode]/[Profile.position].
  final String? departmentCode;
  final String? departmentName;
  final String? position;

  /// Nombor staff organisasi. Wajib pada daftar; `null` cuma bila backend
  /// lama belum hantar kunci (deploy berperingkat).
  final String? staffId;

  /// Bila nombor staff disahkan. `null` = belum verified - Luluskan
  /// mesti disorok/dimatikan sampai medan ni diisi.
  final DateTime? staffIdVerifiedAt;

  factory MemberRow.fromJson(Map<String, dynamic> json) {
    return MemberRow(
      userId: json['user_id'] as String,
      memberId: switch (json['member_id']) {
        final String s when s.trim().isEmpty => null,
        final String s => s,
        _ => null,
      },
      displayName: json['display_name'] as String?,
      email: json['email'] as String?,
      roleKey: (json['role_key'] as String?) ?? 'ahli',
      roleName: (json['role_name'] as String?) ?? 'Ahli',
      roleRank: (json['role_rank'] as num?)?.toInt() ?? 0,
      category: (json['category'] as String?) ?? 'ahli',
      status: (json['status'] as String?) ?? 'pending',
      avatarUrl: json['avatar_url'] as String?,
      registrationPaymentStatus: json['registration_payment_status'] as String?,
      isActive: (json['is_active'] as bool?) ?? true,
      departmentCode: json['department_code'] as String?,
      departmentName: json['department_name'] as String?,
      position: json['position'] as String?,
      staffId: json['staff_id'] as String?,
      staffIdVerifiedAt: json['staff_id_verified_at'] != null
          ? DateTime.parse(json['staff_id_verified_at'] as String)
          : null,
    );
  }
}

class RoleOption {
  const RoleOption({required this.key, required this.name, required this.rank});

  final String key;
  final String name;
  final int rank;

  factory RoleOption.fromJson(Map<String, dynamic> json) {
    return RoleOption(
      key: json['key'] as String,
      name: json['name'] as String,
      rank: (json['rank'] as num).toInt(),
    );
  }
}

/// Senarai role tersedia (Stage 12) - untuk UI edit role management.
final rolesProvider = FutureProvider<List<RoleOption>>((ref) async {
  final isManagement =
      ref.watch(myProfileProvider).valueOrNull?.isManagement ?? false;
  if (!isManagement) return const [];

  final dio = ref.watch(dioProvider);
  final res = await dio.get('/roles');
  return (res.data as List)
      .map((r) => RoleOption.fromJson(r as Map<String, dynamic>))
      .toList();
});

/// Siling "superadmin sahaja" - dikira secara DINAMIK drpd `rolesProvider`
/// (bukan nombor rank digodam keras), padanan `isManagerOrAboveProvider`
/// (`manage_providers.dart`). Kemudahan UI SAHAJA - backend kuatkuasakan
/// sekatan sebenar sendiri (cth `authz.IsAtLeastRole(..., "superadmin")`
/// pada GET /admin/payments dan skrin domain disekat).
///
/// Diletak di sini (bukan feature-scoped macam `payment_providers.dart`
/// asalnya) - beberapa ciri "root system" (donation admin, domain emel
/// disekat) semua perlukan siling yang SAMA, jadi ia kekal satu tempat.
final isSuperAdminProvider = Provider<bool>((ref) {
  final profile = ref.watch(myProfileProvider).valueOrNull;
  if (profile == null) return false;

  // `/roles` (rolesProvider) SENGAJA tolak mana-mana role dengan rank
  // >= rank caller sendiri (backend `ListRoles`, skop utk pemilih "tukar
  // role"). superadmin ialah rank TERTINGGI, jadi ia TAK PERNAH muncul
  // dalam senarai SESIAPA (termasuk superadmin sendiri) - carian dinamik
  // di bawah sentiasa gagal jumpa (Opus verify 2026-08-15). Jalan pintas
  // kes ni sebelum cuba dinamik.
  if (profile.roleKey == 'superadmin') return true;

  final roles = ref.watch(rolesProvider).valueOrNull;
  if (roles == null) return false;

  int? superAdminRank;
  for (final r in roles) {
    if (r.key == 'superadmin') {
      superAdminRank = r.rank;
      break;
    }
  }
  if (superAdminRank == null) return false;

  return profile.roleRank >= superAdminRank;
});

/// Siling "admin ke atas" (admin/superadmin, BUKAN supervisor/manager) -
/// sama pola dgn [isSuperAdminProvider] di atas. Kemudahan UI SAHAJA
/// (papar/sembunyi butang langkau bayaran di skrin kelulusan ahli) -
/// backend kuatkuasakan sekatan sebenar guna
/// `authz.IsAtLeastRole(..., "admin")` pada `ApproveMember`.
final isAdminOrAboveProvider = Provider<bool>((ref) {
  final profile = ref.watch(myProfileProvider).valueOrNull;
  if (profile == null) return false;

  // Jalan pintas laluan literal - lihat komen [isSuperAdminProvider] untuk
  // sebab carian dinamik di bawah tak boleh dipercayai bagi role sendiri
  // (`/roles` tolak mana-mana rank >= rank caller, termasuk rank sendiri).
  if (profile.roleKey == 'admin' || profile.roleKey == 'superadmin') {
    return true;
  }

  final roles = ref.watch(rolesProvider).valueOrNull;
  if (roles == null) return false;

  int? adminRank;
  for (final r in roles) {
    if (r.key == 'admin') {
      adminRank = r.rank;
      break;
    }
  }
  if (adminRank == null) return false;

  return profile.roleRank >= adminRank;
});

/// Senarai ahli. Backend tentukan siapa nampak apa: management → semua;
/// ahli biasa → diri sendiri sahaja.
final membersProvider = FutureProvider<List<MemberRow>>((ref) async {
  final isLoggedIn = ref.watch(
    authNotifierProvider.select((s) => s.isLoggedIn),
  );
  if (!isLoggedIn) return const [];

  final dio = ref.watch(dioProvider);
  final res = await dio.get('/members');
  return (res.data as List)
      .map((m) => MemberRow.fromJson(m as Map<String, dynamic>))
      .toList();
});

/// Ahli status=pending sahaja (Stage 11) - untuk skrin approve/reject
/// management. Endpoint list ni sendiri TAK 403 untuk non-management
/// (backend pulangkan profil caller sendiri je) - access sebenar
/// dikawal di client (lihat guard `isManagement` dalam
/// PendingMembersPage) dan di backend pada endpoint approve/reject
/// (yang memang 403 kalau caller bukan management).
final pendingMembersProvider = FutureProvider<List<MemberRow>>((ref) async {
  final isLoggedIn = ref.watch(
    authNotifierProvider.select((s) => s.isLoggedIn),
  );
  if (!isLoggedIn) return const [];

  final dio = ref.watch(dioProvider);
  final res = await dio.get('/members', queryParameters: {'status': 'pending'});
  return (res.data as List)
      .map((m) => MemberRow.fromJson(m as Map<String, dynamic>))
      .toList();
});
