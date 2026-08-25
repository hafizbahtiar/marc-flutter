import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/features/auth/auth_providers.dart';
import 'package:marc/features/auth/auth_service.dart';

class _FakeAuthService implements AuthService {
  _FakeAuthService(this._result);
  final AuthResult _result;
  @override
  Future<AuthResult> signIn(String email, String password) async => _result;
  @override
  Future<AuthResult> signUp(
    String email,
    String password,
    String phone,
  ) async => _result;
  @override
  Future<void> signOut() async {}
  @override
  Future<void> ensureFreshSession() async {}
  @override
  Future<AuthResult> requestPasswordReset(String email) async => _result;
  @override
  Future<({bool success, String? deepLink, String? error})>
  requestTelegramLinkToken() async =>
      (success: _result.success, deepLink: null, error: _result.error);
  @override
  Future<AuthResult> deleteTelegramLink() async => _result;
}

ProviderContainer _containerWith(AuthResult result) {
  final c = ProviderContainer(
    overrides: [
      authServiceProvider.overrideWithValue(_FakeAuthService(result)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('login berjaya → state AsyncData', () async {
    final c = _containerWith(const AuthResult(success: true));
    await c.read(loginControllerProvider.notifier).submit('a@b.com', '123456');
    expect(c.read(loginControllerProvider).hasError, isFalse);
    expect(c.read(loginControllerProvider).isLoading, isFalse);
  });

  test('login gagal → state AsyncError dengan mesej', () async {
    final c = _containerWith(
      const AuthResult(success: false, error: 'Email atau kata laluan salah'),
    );
    await c.read(loginControllerProvider.notifier).submit('a@b.com', 'wrong1');
    final state = c.read(loginControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.error.toString(), contains('Email atau kata laluan salah'));
  });
}
