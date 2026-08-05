import 'dart:async';

import 'package:dio/dio.dart';
import 'package:marc/core/auth_state.dart';
import 'package:marc/core/token_storage.dart';
import 'package:marc/features/notifications/push_service.dart';

/// Hasil operasi auth. `error` null kalau berjaya.
class AuthResult {
  const AuthResult({required this.success, this.error});
  final bool success;
  final String? error;
}

/// Petik ralat dari response backend Go (`{"error": "..."}` dalam
/// Bahasa Melayu) ke mesej mesra. Fallback kalau tiada sambungan.
String extractErrorMessage(DioException e) {
  final data = e.response?.data;
  if (data is Map && data['error'] is String) {
    return data['error'] as String;
  }
  return 'Sambungan gagal. Semak internet anda';
}

/// Wrapper sekitar API auth backend Go (gantian Supabase Auth).
class AuthService {
  AuthService(
    this._dio,
    this._authNotifier,
    this._tokenStorage,
    this._pushService,
  );

  final Dio _dio;
  final AuthNotifier _authNotifier;
  final TokenStorage _tokenStorage;
  final PushService _pushService;

  Future<AuthResult> signIn(String email, String password) async {
    try {
      final res = await _dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      await _authNotifier.setTokens(
        access: res.data['access_token'] as String,
        refresh: res.data['refresh_token'] as String,
      );
      return const AuthResult(success: true);
    } on DioException catch (e) {
      return AuthResult(success: false, error: extractErrorMessage(e));
    } catch (_) {
      // Ralat luar Dio (cth: .env tak dimuat, API_BASE_URL hilang) —
      // pastikan controller tetap dapat AsyncError, bukan throw tak
      // tertangkap yang buat butang submit stuck loading selama-lamanya.
      return const AuthResult(
        success: false,
        error: 'Ralat tidak dijangka. Cuba lagi.',
      );
    }
  }

  Future<AuthResult> signUp(String email, String password) async {
    try {
      final res = await _dio.post(
        '/auth/register',
        data: {'email': email, 'password': password},
      );
      await _authNotifier.setTokens(
        access: res.data['access_token'] as String,
        refresh: res.data['refresh_token'] as String,
      );
      return const AuthResult(success: true);
    } on DioException catch (e) {
      return AuthResult(success: false, error: extractErrorMessage(e));
    } catch (_) {
      return const AuthResult(
        success: false,
        error: 'Ralat tidak dijangka. Cuba lagi.',
      );
    }
  }

  /// Clear sesi tempatan SERTA-MERTA (router redirect ke /login jadi
  /// responsif), lepas tu baru cuba revoke refresh token di server dalam
  /// latar belakang — tak `await`, supaya butang "Log keluar" tak nampak
  /// mati bertahun-tahun kalau network perlahan/timeout.
  Future<void> signOut() async {
    final refresh = await _tokenStorage.readRefreshToken();
    // Kena sebelum clear() — lepas clear, access token dah takde utk
    // authorize call unlink ni.
    await _pushService.unlinkCurrentDevice();
    await _authNotifier.clear();

    if (refresh != null) {
      unawaited(
        _dio.post('/auth/logout', data: {'refresh_token': refresh}).catchError((
          _,
        ) {
          // Tak kisah kalau gagal revoke di server — sesi lokal dah clear.
          return Response(requestOptions: RequestOptions());
        }),
      );
    }
  }
}
