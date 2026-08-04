import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc_flutter/features/auth/auth_providers.dart';
import 'package:marc_flutter/features/auth/auth_service.dart';

class _FakeAuthService implements AuthService {
  _FakeAuthService(this._result);
  final AuthResult _result;
  @override
  Future<AuthResult> signIn(String email, String password) async => _result;
  @override
  Future<AuthResult> signUp(String email, String password) async => _result;
  @override
  Future<void> signOut() async {}
}

ProviderContainer _containerWith(AuthResult result) {
  final c = ProviderContainer(overrides: [
    authServiceProvider.overrideWithValue(_FakeAuthService(result)),
  ]);
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
        const AuthResult(success: false, error: 'Email atau kata laluan salah'));
    await c.read(loginControllerProvider.notifier).submit('a@b.com', 'wrong1');
    final state = c.read(loginControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.error.toString(), contains('Email atau kata laluan salah'));
  });
}
