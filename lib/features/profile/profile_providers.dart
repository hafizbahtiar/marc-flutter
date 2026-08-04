import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:marc_flutter/features/auth/auth_providers.dart';

class Profile {
  const Profile({required this.memberId, required this.emailVerified});

  final String memberId;
  final bool emailVerified;

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
        memberId: map['member_id'] as String,
        emailVerified: (map['email_verified'] as bool?) ?? false,
      );
}

/// Profil user semasa (member id + status verify email).
/// Dimuat semula bila auth berubah, dan boleh di-refresh manual.
final myProfileProvider = FutureProvider<Profile?>((ref) async {
  // Kaitkan dengan auth supaya re-fetch selepas log masuk / log keluar.
  ref.watch(authStateProvider);

  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return null;

  final data = await client
      .from('profiles')
      .select('member_id, email_verified')
      .eq('id', user.id)
      .maybeSingle();

  if (data == null) return null;
  return Profile.fromMap(data);
});

final emailVerificationProvider =
    Provider<EmailVerification>((ref) => EmailVerification(ref));

/// Aliran pengesahan email diuruskan sendiri menggunakan OTP email Supabase.
///
/// Nota: ini "soft nudge" UX, bukan gate keselamatan — login tidak
/// bergantung padanya.
class EmailVerification {
  EmailVerification(this._ref);

  final Ref _ref;
  SupabaseClient get _client => Supabase.instance.client;

  /// Email user semasa (untuk dipapar dalam sheet).
  String? get emailForDisplay => _client.auth.currentUser?.email;

  /// Hantar kod OTP ke email user semasa.
  Future<void> sendCode() async {
    final email = _client.auth.currentUser?.email;
    if (email == null) {
      throw const AuthException('Tiada email untuk disahkan');
    }
    await _client.auth.signInWithOtp(email: email, shouldCreateUser: false);
  }

  /// Sahkan kod. Kalau sah → tandakan profil sebagai verified & refresh.
  Future<void> verifyCode(String token) async {
    final email = _client.auth.currentUser?.email;
    if (email == null) {
      throw const AuthException('Tiada email untuk disahkan');
    }
    await _client.auth.verifyOTP(
      type: OtpType.email,
      email: email,
      token: token.trim(),
    );
    await _client.rpc('mark_email_verified');
    _ref.invalidate(myProfileProvider);
  }
}
