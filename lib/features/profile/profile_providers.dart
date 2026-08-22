import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/core/auth_state.dart';

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
    required this.telegramLinked,
    this.telegramUsername,
  });

  final String memberId;
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

  final bool telegramLinked;
  final String? telegramUsername;

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
      telegramLinked: telegramLinked ?? this.telegramLinked,
      telegramUsername: telegramUsername == _sentinel
          ? this.telegramUsername
          : telegramUsername as String?,
    );
  }

  static const _sentinel = Object();

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      memberId: json['member_id'] as String,
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
      telegramLinked: (json['telegram_linked'] as bool?) ?? false,
      telegramUsername: json['telegram_username'] as String?,
    );
  }
}

/// Profil user semasa. Reaktif pada status log masuk — jadi ia re-fetch
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

  /// Kemas kini display name & phone user semasa.
  Future<void> update({
    required String displayName,
    required String phone,
  }) async {
    final dio = _ref.read(dioProvider);
    await dio.patch('/me', data: {'display_name': displayName, 'phone': phone});

    _ref.invalidate(myProfileProvider);
    // membersProvider papar display_name yang sama — tanpa invalidate ni,
    // tab Ahli kekal papar nama lama sampai logout/restart (non-autoDispose,
    // cuma recompute bila isLoggedIn berubah).
    _ref.invalidate(membersProvider);
  }

  /// Luluskan pendaftaran ahli (Stage 11) — management sahaja, backend
  /// tolak 403 kalau bukan.
  Future<void> approveMember(String userId) async {
    final dio = _ref.read(dioProvider);
    await dio.post('/members/$userId/approve');
    _ref.invalidate(membersProvider);
    _ref.invalidate(pendingMembersProvider);
  }

  /// Tolak pendaftaran ahli (Stage 11) — row KEKAL di backend (bukan
  /// padam), boleh diluluskan semula lain kali.
  Future<void> rejectMember(String userId) async {
    final dio = _ref.read(dioProvider);
    await dio.post('/members/$userId/reject');
    _ref.invalidate(membersProvider);
    _ref.invalidate(pendingMembersProvider);
  }

  /// Tukar role ahli (Stage 12) — backend kuatkuasakan hierarki rank,
  /// client cuma hantar niat.
  Future<void> updateMemberRole(String userId, String roleKey) async {
    final dio = _ref.read(dioProvider);
    await dio.patch('/members/$userId/role', data: {'role_key': roleKey});
    _ref.invalidate(membersProvider);
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
  });

  final String userId;
  final String memberId;
  final String? displayName;

  /// `null` = backend sembunyikan (emel ahli lain cuma didedahkan kepada
  /// management). BUKAN bermakna ahli tu tiada emel — bezakan dua-dua,
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
  /// `ListVisibleProfiles`) — ahli biasa dapat null, sama pola dengan
  /// [email]. Ditambah 2026-08-15 supaya senarai kelulusan papar status
  /// bayaran sebelum management tekan Luluskan.
  final String? registrationPaymentStatus;

  factory MemberRow.fromJson(Map<String, dynamic> json) {
    return MemberRow(
      userId: json['user_id'] as String,
      memberId: json['member_id'] as String,
      displayName: json['display_name'] as String?,
      email: json['email'] as String?,
      roleKey: (json['role_key'] as String?) ?? 'ahli',
      roleName: (json['role_name'] as String?) ?? 'Ahli',
      roleRank: (json['role_rank'] as num?)?.toInt() ?? 0,
      category: (json['category'] as String?) ?? 'ahli',
      status: (json['status'] as String?) ?? 'pending',
      avatarUrl: json['avatar_url'] as String?,
      registrationPaymentStatus: json['registration_payment_status'] as String?,
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

/// Senarai role tersedia (Stage 12) — untuk UI edit role management.
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

/// Siling "superadmin sahaja" — dikira secara DINAMIK drpd `rolesProvider`
/// (bukan nombor rank digodam keras), padanan `isManagerOrAboveProvider`
/// (`manage_providers.dart`). Kemudahan UI SAHAJA — backend kuatkuasakan
/// sekatan sebenar sendiri (cth `authz.IsAtLeastRole(..., "superadmin")`
/// pada GET /admin/payments dan skrin domain disekat).
///
/// Diletak di sini (bukan feature-scoped macam `payment_providers.dart`
/// asalnya) — beberapa ciri "root system" (donation admin, domain emel
/// disekat) semua perlukan siling yang SAMA, jadi ia kekal satu tempat.
final isSuperAdminProvider = Provider<bool>((ref) {
  final profile = ref.watch(myProfileProvider).valueOrNull;
  if (profile == null) return false;

  // `/roles` (rolesProvider) SENGAJA tolak mana-mana role dengan rank
  // >= rank caller sendiri (backend `ListRoles`, skop utk pemilih "tukar
  // role"). superadmin ialah rank TERTINGGI, jadi ia TAK PERNAH muncul
  // dalam senarai SESIAPA (termasuk superadmin sendiri) — carian dinamik
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

/// Ahli status=pending sahaja (Stage 11) — untuk skrin approve/reject
/// management. Endpoint list ni sendiri TAK 403 untuk non-management
/// (backend pulangkan profil caller sendiri je) — access sebenar
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
