import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/core/auth_state.dart';
import 'package:marc/features/auth/auth_service.dart';

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(
    ref.watch(dioProvider),
    ref.watch(authNotifierProvider.notifier),
    ref.watch(tokenStorageProvider),
  ),
);

class LoginController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit(String email, String password) async {
    state = const AsyncLoading();
    final result = await ref.read(authServiceProvider).signIn(email, password);
    if (result.success) {
      state = const AsyncData(null);
    } else {
      state = AsyncError(result.error ?? 'Log masuk gagal', StackTrace.current);
    }
  }
}

final loginControllerProvider = AsyncNotifierProvider<LoginController, void>(
  LoginController.new,
);

class RegisterController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Pulang true kalau berjaya (page boleh navigasi + tunjuk mesej).
  Future<bool> submit(String email, String password) async {
    state = const AsyncLoading();
    final result = await ref.read(authServiceProvider).signUp(email, password);
    if (result.success) {
      state = const AsyncData(null);
      return true;
    }
    state = AsyncError(result.error ?? 'Pendaftaran gagal', StackTrace.current);
    return false;
  }
}

final registerControllerProvider =
    AsyncNotifierProvider<RegisterController, void>(RegisterController.new);
