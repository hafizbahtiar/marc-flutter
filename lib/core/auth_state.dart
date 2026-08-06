import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/core/token_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

/// Status log masuk & access token semasa. Ini gantian
/// `Supabase.instance.client.auth` punya session/state stream — tapi
/// sumber kebenaran kita sekarang ialah token yang kita simpan sendiri.
class AuthState {
  const AuthState({this.isLoggedIn = false, this.accessToken});

  final bool isLoggedIn;
  final String? accessToken;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._storage) : super(const AuthState());

  final TokenStorage _storage;

  /// Baca token tersimpan (dipanggil sekali di startup, sebelum
  /// `runApp`, supaya redirect pertama GoRouter betul — elak "flicker"
  /// ke /login sebelum sempat tahu ada sesi tersimpan).
  Future<void> hydrate() async {
    final access = await _storage.readAccessToken();
    state = AuthState(isLoggedIn: access != null, accessToken: access);
  }

  Future<void> setTokens({
    required String access,
    required String refresh,
  }) async {
    await _storage.save(access: access, refresh: refresh);
    state = AuthState(isLoggedIn: true, accessToken: access);
  }

  Future<void> clear() async {
    await _storage.clear();
    state = const AuthState();
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.read(tokenStorageProvider)),
);
