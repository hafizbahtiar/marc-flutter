import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/core/auth_state.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: dotenv.get('API_BASE_URL'),
      connectTimeout: const Duration(seconds: 12),
      sendTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
    ),
  );
  dio.interceptors.add(_AuthInterceptor(ref, dio));
  return dio;
});

/// Endpoint yang tak patut trigger auto-refresh-dan-retry bila dapat 401
/// - /auth/login memang boleh return 401 sebab password salah (bukan
/// sebab token luput), dan /auth/refresh sendiri tak boleh retry loop.
bool _isAuthFlowPath(String path) {
  return path.contains('/auth/login') ||
      path.contains('/auth/register') ||
      path.contains('/auth/refresh');
}

const _retriedFlag = 'retried_after_refresh';

/// Lampir `Authorization: Bearer` pada setiap request, dan cuba refresh
/// token sekali secara automatik bila dapat 401 (gantian macam mana
/// supabase_flutter auto-refresh session di belakang tabir).
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._ref, this._dio);

  final Ref _ref;
  final Dio _dio;

  /// Refresh call yang sedang berjalan (kalau ada). Beberapa request
  /// yang 401 serentak (cth: /me + /device-tokens waktu app baru start
  /// dengan access token dah luput) kongsi SATU refresh, bukan
  /// masing-masing panggil /auth/refresh sendiri - refresh token
  /// di-rotate sekali sahaja setiap panggilan, jadi refresh kedua yang
  /// terpisah akan gagal (token dah dipadam oleh refresh pertama) dan
  /// tersalah anggap sesi luput terus.
  Future<_RefreshOutcome>? _refreshing;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _ref.read(authNotifierProvider).accessToken;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final opts = err.requestOptions;
    final alreadyRetried = opts.extra[_retriedFlag] == true;

    if (err.response?.statusCode != 401 || _isAuthFlowPath(opts.path)) {
      handler.next(err);
      return;
    }

    // Retry lepas refresh pun masih 401 - token baru still ditolak
    // (bukan sekadar luput). Jangan cuba refresh lagi, terus anggap sesi
    // tak sah, elak infinite refresh-retry-401-refresh-retry loop.
    if (alreadyRetried) {
      await _ref.read(authNotifierProvider.notifier).clear();
      handler.next(err);
      return;
    }

    final tokenBeforeRefresh = _ref.read(authNotifierProvider).accessToken;
    final outcome = await _refreshOnce();

    if (outcome != _RefreshOutcome.success) {
      // _refreshOnce dedupe request yang benar-benar overlap, tapi tak
      // jamin SEMUA 401 serentak overlap sempurna (bergantung timing
      // network sebenar). Kalau refresh KITA gagal tapi access token dah
      // bertukar (sibling call lain berjaya refresh di antara masa tu),
      // sesi masih sah - retry dengan token terkini, jangan clear sesi
      // yang baru sahaja berjaya diperbaharui orang lain.
      final current = _ref.read(authNotifierProvider);
      if (current.isLoggedIn && current.accessToken != tokenBeforeRefresh) {
        await _retryWithToken(opts, current.accessToken!, handler);
        return;
      }
      if (outcome == _RefreshOutcome.rejected) {
        await _ref.read(authNotifierProvider.notifier).clear();
      }
      handler.next(err);
      return;
    }

    final token = _ref.read(authNotifierProvider).accessToken;
    await _retryWithToken(opts, token, handler);
  }

  Future<void> _retryWithToken(
    RequestOptions opts,
    String? token,
    ErrorInterceptorHandler handler,
  ) async {
    try {
      if (token != null) opts.headers['Authorization'] = 'Bearer $token';
      opts.extra[_retriedFlag] = true;
      final response = await _dio.fetch(opts);
      handler.resolve(response);
    } on DioException catch (retryErr) {
      handler.next(retryErr);
    }
  }

  Future<_RefreshOutcome> _refreshOnce() {
    return _refreshing ??= _tryRefresh().whenComplete(() => _refreshing = null);
  }

  Future<_RefreshOutcome> _tryRefresh() async {
    final storage = _ref.read(tokenStorageProvider);
    final String? refreshToken;
    try {
      refreshToken = await storage.readRefreshToken();
    } on PlatformException {
      // Secure storage tak boleh dibaca (cth: Keystore invalid lepas
      // restore backup Android) - anggap macam tiada sesi tersimpan,
      // bukan biar exception ni terlepas tak tertangkap.
      return _RefreshOutcome.rejected;
    }
    if (refreshToken == null) {
      // Tiada refresh token langsung tersimpan - sesi memang tak sah,
      // bukan sekadar gagal sambung.
      return _RefreshOutcome.rejected;
    }

    try {
      final response = await _dio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      await _ref
          .read(authNotifierProvider.notifier)
          .setTokens(
            access: response.data['access_token'] as String,
            refresh: response.data['refresh_token'] as String,
          );
      return _RefreshOutcome.success;
    } on DioException catch (e) {
      // 401 = server tolak refresh token (memang tak sah/luput/dah
      // dipakai). Selain tu (timeout, offline, 5xx) = gagal sambung -
      // refresh token masih boleh sah, cuma belum sempat dipakai.
      return e.response?.statusCode == 401
          ? _RefreshOutcome.rejected
          : _RefreshOutcome.networkFailure;
    } on PlatformException {
      // setTokens gagal simpan token baru (storage rosak) - anggap
      // gagal sambung, elak exception tak tertangkap merosakkan request
      // asal yang sedang di-retry.
      return _RefreshOutcome.networkFailure;
    }
  }
}

/// Hasil `_tryRefresh` - kenapa perlu enum (bukan `bool` + shared field):
/// outcome dipulangkan TERUS dari `_refreshOnce()` sebagai nilai LOCAL di
/// `onError`, jadi tak boleh tertimpa oleh panggilan refresh berasingan
/// (bukan-dedupe) yang selesai antara masa `_tryRefresh` siap dengan masa
/// continuation `onError` baca outcome tu.
enum _RefreshOutcome { success, rejected, networkFailure }
