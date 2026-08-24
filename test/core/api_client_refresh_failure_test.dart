import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/core/auth_state.dart';
import 'package:marc/core/token_storage.dart';

class _FakeTokenStorage implements TokenStorage {
  final _store = <String, String>{};

  @override
  Future<void> save({required String access, required String refresh}) async {
    _store['access'] = access;
    _store['refresh'] = refresh;
  }

  @override
  Future<String?> readAccessToken() async => _store['access'];

  @override
  Future<String?> readRefreshToken() async => _store['refresh'];

  @override
  Future<void> clear() async => _store.clear();

  @override
  Future<void> deleteAll() async => _store.clear();
}

void main() {
  test(
    '/me dapat 401, refresh gagal 500 (bukan 401 server-rejection) -> sesi TAK di-clear',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((req) {
        if (req.uri.path == '/me') {
          req.response
            ..statusCode = 401
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'error': 'token tidak sah'}))
            ..close();
        } else if (req.uri.path == '/auth/refresh') {
          // 500 = gagal di server (timeout DB, dsb) - BUKAN 401 (server
          // tolak refresh token secara definitif). Ini kes yang patut
          // TAK clear sesi (fix untuk finding #1).
          req.response
            ..statusCode = 500
            ..close();
        } else {
          req.response
            ..statusCode = 404
            ..close();
        }
      });

      dotenv.testLoad(
        fileInput:
            'API_BASE_URL=http://${server.address.address}:${server.port}\nONESIGNAL_APP_ID=x',
      );

      final fakeStorage = _FakeTokenStorage();
      final container = ProviderContainer(
        overrides: [tokenStorageProvider.overrideWithValue(fakeStorage)],
      );
      addTearDown(container.dispose);

      await container
          .read(authNotifierProvider.notifier)
          .setTokens(
            access: 'expired-access-token',
            refresh: 'still-valid-refresh-token',
          );

      final dio = container.read(dioProvider);

      try {
        await dio.get('/me');
        fail('sepatutnya throw - /me 401 dan refresh pun gagal 500');
      } on DioException catch (_) {
        // expected - request asal tetap gagal (refresh tak berjaya jadi
        // tak boleh retry), tapi itu bukan yang kita test kat sini.
      }

      expect(
        container.read(authNotifierProvider).isLoggedIn,
        isTrue,
        reason:
            'refresh gagal 500 (bukan 401) = server bermasalah sementara, '
            'BUKAN bukti refresh token tak sah. Sesi tak patut di-clear - '
            'user akan cuba lagi bila server/network pulih.',
      );
    },
  );

  test(
    '/me dapat 401, refresh pun dapat 401 (server TOLAK refresh token) -> sesi di-clear',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((req) {
        req.response
          ..statusCode = 401
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'error': 'tidak sah'}))
          ..close();
      });

      dotenv.testLoad(
        fileInput:
            'API_BASE_URL=http://${server.address.address}:${server.port}\nONESIGNAL_APP_ID=x',
      );

      final fakeStorage = _FakeTokenStorage();
      final container = ProviderContainer(
        overrides: [tokenStorageProvider.overrideWithValue(fakeStorage)],
      );
      addTearDown(container.dispose);

      await container
          .read(authNotifierProvider.notifier)
          .setTokens(
            access: 'expired-access-token',
            refresh: 'genuinely-invalid-refresh-token',
          );

      final dio = container.read(dioProvider);

      try {
        await dio.get('/me');
        fail('sepatutnya throw');
      } on DioException catch (_) {}

      expect(
        container.read(authNotifierProvider).isLoggedIn,
        isFalse,
        reason:
            'refresh token betul-betul ditolak server (401) - sesi '
            'memang tak sah, patut di-clear.',
      );
    },
  );
}
