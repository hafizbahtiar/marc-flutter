import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/core/token_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

/// Kenapa sesi tempatan habis. [none] = belum/tiada isyarat (buka app
/// tanpa token, atau dah di-consume). [signedOut] = user tekan Log
/// keluar. [sessionEnded] = server tolak refresh (revoke, logout-all,
/// tukar password, token luput) — /login papar dialog.
enum AuthEndReason { none, signedOut, sessionEnded }

const sessionEndedTitle = 'Sesi tamat';
const sessionEndedMessage =
    'Sesi anda telah tamat atau dilog keluar dari peranti lain. Sila log masuk semula.';

/// Status log masuk & access token semasa. Ini gantian
/// `Supabase.instance.client.auth` punya session/state stream - tapi
/// sumber kebenaran kita sekarang ialah token yang kita simpan sendiri.
class AuthState {
  const AuthState({
    this.isLoggedIn = false,
    this.accessToken,
    this.endReason = AuthEndReason.none,
  });

  final bool isLoggedIn;
  final String? accessToken;
  final AuthEndReason endReason;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._storage) : super(const AuthState());

  final TokenStorage _storage;

  /// Baca token tersimpan (dipanggil sekali di startup, sebelum
  /// `runApp`, supaya redirect pertama GoRouter betul - elak "flicker"
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

  /// Padam token. [reason] lalai [AuthEndReason.signedOut] supaya tekan
  /// Log keluar tak papar dialog "Sesi tamat". Interceptor hantar
  /// [AuthEndReason.sessionEnded] bila server tolak refresh.
  Future<void> clear({AuthEndReason reason = AuthEndReason.signedOut}) async {
    await _storage.clear();
    state = AuthState(endReason: reason);
  }

  /// Dialog di /login dah baca isyarat — buang supaya rebuild/rotate
  /// tak papar semula.
  void consumeEndReason() {
    if (state.endReason == AuthEndReason.none) return;
    state = AuthState(
      isLoggedIn: state.isLoggedIn,
      accessToken: state.accessToken,
    );
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.read(tokenStorageProvider)),
);
