import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/core/auth_state.dart';

class Profile {
  const Profile({
    required this.memberId,
    required this.email,
    required this.emailVerified,
    required this.displayName,
    required this.phone,
    required this.roleKey,
    required this.roleName,
    required this.category,
  });

  final String memberId;
  final String email;
  final bool emailVerified;
  final String? displayName;
  final String? phone;
  final String roleKey;
  final String roleName;
  final String category;

  bool get isManagement => category == 'management';

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      memberId: json['member_id'] as String,
      email: json['email'] as String,
      emailVerified: (json['email_verified'] as bool?) ?? false,
      displayName: json['display_name'] as String?,
      phone: json['phone'] as String?,
      roleKey: (json['role_key'] as String?) ?? 'ahli',
      roleName: (json['role_name'] as String?) ?? 'Ahli',
      category: (json['category'] as String?) ?? 'ahli',
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
}

class MemberRow {
  const MemberRow({
    required this.memberId,
    required this.displayName,
    required this.roleName,
    required this.category,
  });

  final String memberId;
  final String? displayName;
  final String roleName;
  final String category;

  factory MemberRow.fromJson(Map<String, dynamic> json) {
    return MemberRow(
      memberId: json['member_id'] as String,
      displayName: json['display_name'] as String?,
      roleName: (json['role_name'] as String?) ?? 'Ahli',
      category: (json['category'] as String?) ?? 'ahli',
    );
  }
}

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
