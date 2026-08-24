import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/core/auth_state.dart';
import 'package:marc/core/token_storage.dart';
import 'package:marc/features/activities/activity_providers.dart';

/// Harness sama dengan `activity_registration_test.dart`.
class _LoggedInAuthNotifier extends AuthNotifier {
  _LoggedInAuthNotifier() : super(TokenStorage()) {
    state = const AuthState(isLoggedIn: true, accessToken: 'test-token');
  }
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._onFetch);

  final Future<ResponseBody> Function(RequestOptions options) _onFetch;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => _onFetch(options);
}

ResponseBody _jsonResponse(Map<String, dynamic> body, {int status = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

Dio _dioWith(Future<ResponseBody> Function(RequestOptions options) onFetch) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.httpClientAdapter = _FakeAdapter(onFetch);
  return dio;
}

ProviderContainer _containerWith(Dio dio) {
  final c = ProviderContainer(
    overrides: [
      dioProvider.overrideWithValue(dio),
      authNotifierProvider.overrideWith((ref) => _LoggedInAuthNotifier()),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

/// Bentuk sebenar `certificateResponse` - lihat
/// internal/http/handlers/activity_certificates.go.
Map<String, dynamic> _certJson({bool fileReady = true}) => {
  'id': 'cert-1',
  'activity_id': 'a1',
  'serial': 'MARC-2026-000123',
  'verify_token': 'tok',
  'recipient_name': 'Ali bin Abu',
  'activity_title': 'Kejohanan Badminton',
  'category_name': 'Sukan',
  'activity_date': '2026-08-09',
  'issued_at': '2026-08-10T02:00:00Z',
  'file_ready': fileReady,
};

void main() {
  group('muat turun sijil', () {
    test('200 → URL bertandatangan dipulangkan', () async {
      final dio = _dioWith((options) async {
        if (options.path == '/me/certificates/cert-1/file') {
          return _jsonResponse({'url': 'https://r2.example/sijil.pdf?sig=x'});
        }
        throw StateError('Unexpected ${options.method} ${options.path}');
      });

      final result = await _containerWith(
        dio,
      ).read(certificateRepositoryProvider).fileUrl('cert-1');

      expect(result.isOk, isTrue);
      expect(result.url, 'https://r2.example/sijil.pdf?sig=x');
      expect(result.message, isNull);
    });

    test('409 → mesej "sedang disediakan", BUKAN ralat generik', () async {
      // Backend menghantar 409 semasa fasa 2 penerbitan belum siap.
      final dio = _dioWith((options) async {
        return _jsonResponse({
          'error': 'sijil sedang disediakan, cuba sebentar lagi',
        }, status: 409);
      });

      final result = await _containerWith(
        dio,
      ).read(certificateRepositoryProvider).fileUrl('cert-1');

      expect(result.isOk, isFalse);
      expect(result.message, certificatePendingMessage);
      expect(result.message, 'Sijil sedang disediakan. Cuba lagi sebentar.');
    });

    test('500 → mesej pelayan, BUKAN mesej "sedang disediakan"', () async {
      final dio = _dioWith((options) async {
        return _jsonResponse({
          'error': 'gagal sediakan pautan muat turun',
        }, status: 500);
      });

      final result = await _containerWith(
        dio,
      ).read(certificateRepositoryProvider).fileUrl('cert-1');

      expect(result.isOk, isFalse);
      expect(result.message, 'gagal sediakan pautan muat turun');
      expect(result.message, isNot(certificatePendingMessage));
    });

    test('404 (bukan milik anda / tiada) → mesej pelayan', () async {
      final dio = _dioWith((options) async {
        return _jsonResponse({'error': 'sijil tidak dijumpai'}, status: 404);
      });

      final result = await _containerWith(
        dio,
      ).read(certificateRepositoryProvider).fileUrl('cert-1');

      expect(result.isOk, isFalse);
      expect(result.message, 'sijil tidak dijumpai');
    });

    test('410 (ditarik balik) → senarai dibaca semula supaya baris basi '
        'hilang', () async {
      var listCalls = 0;
      final dio = _dioWith((options) async {
        if (options.path == '/me/certificates') {
          listCalls++;
          return _jsonResponse({
            'certificates': listCalls == 1 ? [_certJson()] : <dynamic>[],
          });
        }
        return _jsonResponse({
          'error': 'sijil ini telah ditarik balik',
        }, status: 410);
      });

      final container = _containerWith(dio);
      expect((await container.read(myCertificatesProvider.future)).length, 1);

      final result = await container
          .read(certificateRepositoryProvider)
          .fileUrl('cert-1');

      expect(result.isOk, isFalse);
      expect(result.message, 'sijil ini telah ditarik balik');
      expect(await container.read(myCertificatesProvider.future), isEmpty);
      expect(listCalls, 2, reason: 'senarai di-invalidate selepas 410');
    });

    test('200 tanpa medan url → gagal, tiada URL kosong dilancarkan', () async {
      final dio = _dioWith((options) async => _jsonResponse({}));

      final result = await _containerWith(
        dio,
      ).read(certificateRepositoryProvider).fileUrl('cert-1');

      expect(result.isOk, isFalse);
      expect(result.message, 'Gagal buka sijil.');
    });
  });

  group('senarai sijil', () {
    test('dihurai mengikut medan backend', () async {
      final dio = _dioWith(
        (options) async => _jsonResponse({
          'certificates': [_certJson(fileReady: false)],
        }),
      );

      final rows = await _containerWith(
        dio,
      ).read(myCertificatesProvider.future);

      final c = rows.single;
      expect(c.id, 'cert-1');
      expect(c.serial, 'MARC-2026-000123');
      expect(c.activityTitle, 'Kejohanan Badminton');
      expect(c.categoryName, 'Sukan');
      expect(c.fileReady, isFalse);
      // Tarikh kalendar - TIDAK ditukar zon, jadi 9 Ogos kekal 9 Ogos di
      // mana-mana peranti.
      expect(c.activityDate.year, 2026);
      expect(c.activityDate.month, 8);
      expect(c.activityDate.day, 9);
      expect(c.issuedAt.isUtc, isFalse);
    });
  });
}
