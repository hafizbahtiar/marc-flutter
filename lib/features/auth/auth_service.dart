import 'package:supabase_flutter/supabase_flutter.dart';

/// Petik AuthException ke mesej Melayu mesra.
String mapAuthErrorToMessage(AuthException e) {
  switch (e.code) {
    case 'invalid_credentials':
      return 'Email atau kata laluan salah';
    case 'email_not_confirmed':
      return 'Sila sahkan email anda dahulu';
    case 'user_already_exists':
    case 'email_exists':
      return 'Email ini sudah berdaftar';
    case 'weak_password':
      return 'Kata laluan terlalu lemah (minimum 6 aksara)';
    default:
      return e.message;
  }
}

/// Hasil operasi auth. `error` null kalau berjaya.
class AuthResult {
  const AuthResult({required this.success, this.error});
  final bool success;
  final String? error;
}

/// Wrapper sekitar Supabase Auth. Boleh inject `SupabaseClient` untuk testing.
class AuthService {
  AuthService([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  Future<AuthResult> signIn(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      return const AuthResult(success: true);
    } on AuthException catch (e) {
      return AuthResult(success: false, error: mapAuthErrorToMessage(e));
    } on Exception catch (_) {
      return const AuthResult(
        success: false,
        error: 'Sambungan gagal. Semak internet anda',
      );
    }
  }

  Future<AuthResult> signUp(String email, String password) async {
    try {
      await _client.auth.signUp(email: email, password: password);
      return const AuthResult(success: true);
    } on AuthException catch (e) {
      return AuthResult(success: false, error: mapAuthErrorToMessage(e));
    } on Exception catch (_) {
      return const AuthResult(
        success: false,
        error: 'Sambungan gagal. Semak internet anda',
      );
    }
  }

  Future<void> signOut() => _client.auth.signOut();
}
