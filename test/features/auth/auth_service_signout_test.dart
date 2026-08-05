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
}

class _RecordingPushService implements PushService {
  bool wasLoggedInWhenUnlinkCalled = false;
  final AuthNotifier authNotifier;
  _RecordingPushService(this.authNotifier);

  @override
  Future<void> unlinkCurrentDevice() async {
    wasLoggedInWhenUnlinkCalled = authNotifier.state.isLoggedIn;
  }

  @override
  Future<void> onSignedIn(String userId) async {}
  @override
  Future<void> onSignedOut() async {}
  @override
  void startObserving() {}
}

void main() {
  test(
    'signOut: unlinkCurrentDevice dipanggil SEBELUM sesi clear (token masih ada)',
    () async {
      final storage = _FakeTokenStorage();
      final notifier = AuthNotifier(storage);
      await notifier.hydrate();
      expect(notifier.state.isLoggedIn, isTrue);

      final pushService = _RecordingPushService(notifier);
      // dio null-safe: signOut hanya guna _dio.post untuk revoke di
      // background (unawaited) — tak perlu network sebenar untuk assert
      // ordering ni, cuma perlu ia tak throw sebelum unawaited() dipanggil.
      final service = AuthService(_NoopDio(), notifier, storage, pushService);

      await service.signOut();

      expect(
        pushService.wasLoggedInWhenUnlinkCalled,
        isTrue,
        reason:
            'unlinkCurrentDevice mesti dipanggil SEBELUM clear() — '
            'kalau tidak, call DELETE /device-tokens tiada Authorization '
            'header (access token dah kosong) dan gagal 401',
      );
      expect(
        notifier.state.isLoggedIn,
        isFalse,
        reason: 'sesi patut clear lepas signOut selesai',
      );
    },
  );
}

// Dio palsu minimum — signOut() cuma panggil _dio.post(...).catchError(...)
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
