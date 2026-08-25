import 'dart:async';

import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:marc/core/app_log.dart';
import 'package:marc/core/auth_state.dart';
import 'package:marc/core/error_utils.dart';
import 'package:marc/core/jwt.dart';
import 'package:marc/core/token_storage.dart';
import 'package:marc/features/notifications/push_service.dart';

/// Hasil operasi auth. `error` null kalau berjaya.
class AuthResult {
  const AuthResult({required this.success, this.error});
  final bool success;
  final String? error;
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
      await _setTokensWithStorageRetry(
        access: res.data['access_token'] as String,
        refresh: res.data['refresh_token'] as String,
      );
      return const AuthResult(success: true);
    } on DioException catch (e) {
      appLogDioError('auth', 'login', e);
      return AuthResult(success: false, error: extractErrorMessage(e));
    } on PlatformException catch (e) {
      return _storageCorruptResult(e);
    } catch (_) {
      // Ralat luar Dio (cth: .env tak dimuat, API_BASE_URL hilang) -
      // pastikan controller tetap dapat AsyncError, bukan throw tak
      // tertangkap yang buat butang submit stuck loading selama-lamanya.
      return const AuthResult(
        success: false,
        error: 'Ralat tidak dijangka. Cuba lagi.',
      );
    }
  }

  Future<AuthResult> signUp(String email, String password, String phone) async {
    try {
      final res = await _dio.post(
        '/auth/register',
        data: {'email': email, 'password': password, 'phone': phone},
      );
      await _setTokensWithStorageRetry(
        access: res.data['access_token'] as String,
        refresh: res.data['refresh_token'] as String,
      );
      return const AuthResult(success: true);
    } on DioException catch (e) {
      return AuthResult(success: false, error: extractErrorMessage(e));
    } on PlatformException catch (e) {
      return _storageCorruptResult(e);
    } catch (_) {
      return const AuthResult(
        success: false,
        error: 'Ralat tidak dijangka. Cuba lagi.',
      );
    }
  }

  /// Minta pautan reset kata laluan. Backend pulang 204 SENTIASA (tiada
  /// enumerasi akaun), jadi "berjaya" di sini bermakna "permintaan
  /// diterima" - BUKAN "akaun itu wujud". Mesej UI mesti kekal neutral.
  Future<AuthResult> requestPasswordReset(String email) async {
    try {
      await _dio.post('/auth/password-reset/request', data: {'email': email});
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

  /// Jana deep-link binding Telegram. Backend pulang 503 kalau ciri
  /// belum dikonfigur (TELEGRAM_BOT_TOKEN kosong) -- error itu
  /// diteruskan terus, BUKAN dineutralkan spt reset kata laluan (tiada
  /// isu enumerasi di sini -- binding perlukan auth, bukan endpoint awam).
  Future<({bool success, String? deepLink, String? error})>
  requestTelegramLinkToken() async {
    try {
      final res = await _dio.post('/me/telegram-link/token');
      return (
        success: true,
        deepLink: res.data['deep_link'] as String,
        error: null,
      );
    } on DioException catch (e) {
      return (success: false, deepLink: null, error: extractErrorMessage(e));
    } catch (_) {
      return (
        success: false,
        deepLink: null,
        error: 'Ralat tidak dijangka. Cuba lagi.',
      );
    }
  }

  Future<AuthResult> deleteTelegramLink() async {
    try {
      await _dio.delete('/me/telegram-link');
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

  /// Simpan token, tapi kalau secure storage rosak (cth: PlatformException
  /// sebab Keystore invalid lepas restore backup Android - lihat
  /// TokenStorage) buang SEMUA entri lama sekali sahaja dan cuba simpan
  /// balik, supaya login lepas ni tak asyik gagal dengan storage yang
  /// tak boleh ditulis.
  Future<void> _setTokensWithStorageRetry({
    required String access,
    required String refresh,
  }) async {
    try {
      await _authNotifier.setTokens(access: access, refresh: refresh);
    } on PlatformException {
      await _tokenStorage.deleteAll();
      await _authNotifier.setTokens(access: access, refresh: refresh);
    }
  }

  /// PlatformException lepas retry deleteAll+save pun masih gagal - log
  /// jelas (bukan hilang dalam catch generik) supaya kegagalan storage ni
  /// boleh didiagnosis, bukan nampak macam "ralat tak dijangka" biasa.
  AuthResult _storageCorruptResult(PlatformException e) {
    debugPrint('AuthService: secure storage rosak lepas retry - $e');
    return const AuthResult(
      success: false,
      error: 'Storan peranti bermasalah. Cuba log masuk semula.',
    );
  }

  /// Idle / resume: kalau access dah luput, GET /me supaya interceptor
  /// cuba refresh. Refresh 401 (token mati) → interceptor `clear()` →
  /// GoRouter hantar ke /login. Access masih sah → no-op (elak ping
  /// setiap kali app ke foreground).
  Future<void> ensureFreshSession() async {
    final access = await _tokenStorage.readAccessToken();
    if (access == null) return;
    if (!isAccessTokenExpired(access)) return;
    try {
      await _dio.get('/me');
    } on DioException {
      // Interceptor dah clear sesi kalau refresh ditolak. Jangan
      // longgarkan ralat ni ke UI - user akan nampak /login.
    }
  }

  /// Clear sesi tempatan SERTA-MERTA (router redirect ke /login jadi
  /// responsif) - tangkap access/refresh token dulu untuk 2 panggilan
  /// latar belakang (unlink device + revoke refresh token di server),
  /// KEDUA-DUA tak di-`await`, supaya butang "Log keluar" betul-betul
  /// tak block pada network perlahan/timeout macam yang comment ni
  /// dulu cakap (tapi kod sebenar tak buat - H1 punya sibling bug,
  /// dah fix di sini).
  Future<void> signOut() async {
    final access = await _tokenStorage.readAccessToken();
    final refresh = await _tokenStorage.readRefreshToken();

    await _authNotifier.clear();

    // Buang cache gambar (avatar/post) atas cakera & memori supaya akaun
    // seterusnya yang log masuk pada peranti KONGSI tak nampak gambar
    // akaun sebelum ni - AppNetworkImage muat semua gambar rangkaian
    // dengan `cache: true` (extended_image), tokens sahaja tak cukup.
    clearMemoryImageCache();
    unawaited(clearDiskCachedImages());

    if (access != null) {
      unawaited(_pushService.unlinkDevice(access));
    }

    if (refresh != null) {
      unawaited(
        _dio.post('/auth/logout', data: {'refresh_token': refresh}).catchError((
          _,
        ) {
          // Tak kisah kalau gagal revoke di server - sesi lokal dah clear.
          return Response(requestOptions: RequestOptions());
        }),
      );
    }
  }
}
