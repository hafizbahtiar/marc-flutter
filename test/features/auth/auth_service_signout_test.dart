import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/core/auth_state.dart';
import 'package:marc/core/token_storage.dart';
import 'package:marc/features/auth/auth_service.dart';
import 'package:marc/features/notifications/push_service.dart';

class _FakeTokenStorage implements TokenStorage {
  final _store = <String, String>{
    'access': 'seed-access',
    'refresh': 'seed-refresh',
  };

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

class _RecordingPushService implements PushService {
  String? tokenPassedToUnlinkDevice;

  @override
  Future<void> unlinkDevice(String accessToken) async {
    tokenPassedToUnlinkDevice = accessToken;
  }

  @override
  Future<void> onSignedIn(String userId) async {}
  @override
  Future<void> onSignedOut() async {}
  @override
  void startObserving() {}
}

void main() {
  // signOut() sekarang panggil clearMemoryImageCache() (extended_image) -
  // itu baca PaintingBinding.instance, yang perlu binding flutter_test
  // diinit dulu (bukan idle dalam test 'unit' murni macam sebelum ni).
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'signOut: tangkap access token SEBELUM clear() dan hantar ke '
    'unlinkDevice (bukan bergantung pada token tersimpan/state semasa)',
    () async {
      final storage = _FakeTokenStorage();
      final notifier = AuthNotifier(storage);
      await notifier.hydrate();
      expect(notifier.state.isLoggedIn, isTrue);

      final pushService = _RecordingPushService();
      // dio null-safe: signOut hanya guna _dio.post untuk revoke di
      // background (unawaited) - tak perlu network sebenar untuk assert
      // ordering ni, cuma perlu ia tak throw sebelum unawaited() dipanggil.
      final service = AuthService(_NoopDio(), notifier, storage, pushService);

      await service.signOut();

      // signOut() sepatutnya tak `await` unlinkDevice/logout - tapi
      // panggilan sync sebelum await pertama di dalam unlinkDevice tetap
      // jalan serta-merta bila unawaited() dipanggil, jadi assert ini sah
      // walaupun keseluruhan Future tak ditunggu.
      expect(
        pushService.tokenPassedToUnlinkDevice,
        'seed-access',
        reason:
            'access token mesti ditangkap SEBELUM clear() dan dihantar '
            'terus ke unlinkDevice() - bukan bergantung pada interceptor '
            'menarik token tersimpan yang dah tiada lepas clear()',
      );
      expect(
        notifier.state.isLoggedIn,
        isFalse,
        reason: 'sesi patut clear lepas signOut selesai',
      );
    },
  );

  test(
    'ensureFreshSession: ping /me walaupun access JWT belum luput '
    '(revoke device lain bunuh family, access masih nampak sah)',
    () async {
      final storage = _FakeTokenStorage();
      final notifier = AuthNotifier(storage);
      await notifier.hydrate();
      final dio = _RecordingDio();
      final service = AuthService(
        dio,
        notifier,
        storage,
        _RecordingPushService(),
      );

      await service.ensureFreshSession();

      expect(
        dio.paths,
        ['/me'],
        reason:
            'mesti ping /me pada resume walaupun token belum luput — '
            'itu yang tendang sesi lepas revoke dari web',
      );
    },
  );

  test('ensureFreshSession: tiada access → tak ping', () async {
    final storage = _FakeTokenStorage();
    await storage.clear();
    final notifier = AuthNotifier(storage);
    await notifier.hydrate();
    final dio = _RecordingDio();
    final service = AuthService(dio, notifier, storage, _RecordingPushService());

    await service.ensureFreshSession();

    expect(dio.paths, isEmpty);
  });
}

// Dio palsu minimum - signOut() cuma panggil _dio.post(...).catchError(...)
// dalam unawaited(), jadi ni tak perlu benar-benar network, cuma tak throw
// secara synchronous.
class _NoopDio implements Dio {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #post) {
      return Future<Response>.value(
        Response(requestOptions: RequestOptions(path: '/auth/logout')),
      );
    }
    return super.noSuchMethod(invocation);
  }
}

class _RecordingDio implements Dio {
  final paths = <String>[];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #get) {
      final path = invocation.positionalArguments.first as String;
      paths.add(path);
      return Future<Response>.value(
        Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
        ),
      );
    }
    return super.noSuchMethod(invocation);
  }
}
