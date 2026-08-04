import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:marc_flutter/features/auth/auth_providers.dart';

class Profile {
  const Profile({required this.memberId});

  final String memberId;

  factory Profile.fromMap(Map<String, dynamic> map) =>
      Profile(memberId: map['member_id'] as String);
}

/// Profil user semasa (termasuk member id). Dimuat semula bila auth berubah.
final myProfileProvider = FutureProvider<Profile?>((ref) async {
  // Kaitkan dengan auth supaya re-fetch selepas log masuk / log keluar.
  ref.watch(authStateProvider);

  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return null;

  final data = await client
      .from('profiles')
      .select('member_id')
      .eq('id', user.id)
      .maybeSingle();

  if (data == null) return null;
  return Profile.fromMap(data);
});
