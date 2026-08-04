import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:marc_flutter/features/auth/auth_providers.dart';

class Profile {
  const Profile({
    required this.memberId,
    required this.emailVerified,
    required this.displayName,
    required this.phone,
    required this.roleKey,
    required this.roleName,
    required this.category,
  });

  final String memberId;
  final bool emailVerified;
  final String? displayName;
  final String? phone;
  final String roleKey;
  final String roleName;
  final String category;

  bool get isManagement => category == 'management';

  factory Profile.fromMap(Map<String, dynamic> map) {
    final role = map['roles'] as Map<String, dynamic>?;
    return Profile(
      memberId: map['member_id'] as String,
      emailVerified: (map['email_verified'] as bool?) ?? false,
      displayName: map['display_name'] as String?,
      phone: map['phone'] as String?,
      roleKey: (role?['key'] as String?) ?? 'ahli',
      roleName: (role?['name'] as String?) ?? 'Ahli',
      category: (role?['category'] as String?) ?? 'ahli',
    );
  }
}

/// Profil user semasa. Dimuat semula bila auth berubah / selepas edit.
final myProfileProvider = FutureProvider<Profile?>((ref) async {
  ref.watch(authStateProvider);

  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return null;

  final data = await client
      .from('profiles')
      .select('member_id, email_verified, display_name, phone, '
          'roles(key, name, category)')
      .eq('id', user.id)
      .maybeSingle();

  if (data == null) return null;
  return Profile.fromMap(data);
});

final profileRepositoryProvider =
    Provider<ProfileRepository>((ref) => ProfileRepository(ref));

class ProfileRepository {
  ProfileRepository(this._ref);
  final Ref _ref;

  /// Kemas kini display name & phone user semasa.
  Future<void> update({
    required String displayName,
    required String phone,
  }) async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) throw StateError('Tiada sesi');

    String? clean(String v) => v.trim().isEmpty ? null : v.trim();

    await client.from('profiles').update({
      'display_name': clean(displayName),
      'phone': clean(phone),
    }).eq('id', uid);

    _ref.invalidate(myProfileProvider);
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

  factory MemberRow.fromMap(Map<String, dynamic> map) {
    final role = map['roles'] as Map<String, dynamic>?;
    return MemberRow(
      memberId: map['member_id'] as String,
      displayName: map['display_name'] as String?,
      roleName: (role?['name'] as String?) ?? 'Ahli',
      category: (role?['category'] as String?) ?? 'ahli',
    );
  }
}

/// Senarai ahli. RLS tentukan siapa nampak apa:
/// management → semua; ahli biasa → diri sendiri sahaja.
final membersProvider = FutureProvider<List<MemberRow>>((ref) async {
  ref.watch(authStateProvider);

  final client = Supabase.instance.client;
  if (client.auth.currentUser == null) return const [];

  final data = await client
      .from('profiles')
      .select('member_id, display_name, roles(name, category)')
      .order('member_id');

  return (data as List)
      .map((m) => MemberRow.fromMap(m as Map<String, dynamic>))
      .toList();
});

