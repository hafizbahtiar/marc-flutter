import 'package:flutter_test/flutter_test.dart';
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
  test('clear() lalai signedOut - log keluar sendiri, bukan sesi mati', () async {
    final notifier = AuthNotifier(_FakeTokenStorage());
    await notifier.setTokens(access: 'a', refresh: 'r');

    await notifier.clear();

    expect(notifier.state.isLoggedIn, isFalse);
    expect(notifier.state.endReason, AuthEndReason.signedOut);
  });

  test('clear(sessionEnded) tandakan sebab untuk dialog di /login', () async {
    final notifier = AuthNotifier(_FakeTokenStorage());
    await notifier.setTokens(access: 'a', refresh: 'r');

    await notifier.clear(reason: AuthEndReason.sessionEnded);

    expect(notifier.state.isLoggedIn, isFalse);
    expect(notifier.state.endReason, AuthEndReason.sessionEnded);
  });

  test('consumeEndReason buang isyarat supaya dialog tak ulang', () async {
    final notifier = AuthNotifier(_FakeTokenStorage());
    await notifier.clear(reason: AuthEndReason.sessionEnded);

    notifier.consumeEndReason();

    expect(notifier.state.endReason, AuthEndReason.none);
    expect(notifier.state.isLoggedIn, isFalse);
  });

  test('setTokens reset endReason', () async {
    final notifier = AuthNotifier(_FakeTokenStorage());
    await notifier.clear(reason: AuthEndReason.sessionEnded);

    await notifier.setTokens(access: 'a', refresh: 'r');

    expect(notifier.state.endReason, AuthEndReason.none);
    expect(notifier.state.isLoggedIn, isTrue);
  });
}
