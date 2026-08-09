import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/core/auth_state.dart';
import 'package:marc/core/token_storage.dart';
import 'package:marc/features/audit/audit_providers.dart';

class _StubDio with DioMixin implements Dio {
  _StubDio() {
    options = BaseOptions();
    httpClientAdapter = _NoopAdapter();
  }

  int calls = 0;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    calls++;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data:
          {
                'logs': [
                  {
                    'id': 1,
                    'entity_type': 'profile',
                    'entity_id': '11111111-1111-1111-1111-111111111111',
                    'action': 'update',
                    'actor_id': null,
                    'actor_member_id': 'MARC2026/08/0009',
                    'actor_role_key': 'manager',
                    'changed_fields': ['status'],
                    'old_values': {'status': 'pending'},
                    'new_values': {'status': 'approved'},
                    'created_at': DateTime.now().toIso8601String(),
                  },
                ],
              }
              as T,
    );
  }
}

class _NoopAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(o, s, f) async => ResponseBody.fromString('', 200);
}

void main() {
  // Jejak audit ialah data paling sensitif dalam app (siapa ubah apa, ID
  // ahli, kandungan post). Provider mesti kosong sebaik sesi tamat —
  // pattern sama yang dikuatkuasakan pada feed/notifications/comments
  // selepas audit 2026-08-07.
  test(
    'auditLogsProvider kosong bila tak log masuk, tanpa panggil API',
    () async {
      final dio = _StubDio();
      final container = ProviderContainer(
        overrides: [
          dioProvider.overrideWithValue(dio),
          authNotifierProvider.overrideWith(
            (ref) => _FakeAuth(loggedIn: false),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = await container.read(
        auditLogsProvider(const AuditFilter()).future,
      );

      expect(state.logs, isEmpty);
      expect(state.hasMore, isFalse);
      expect(dio.calls, 0, reason: 'tak patut panggil API tanpa sesi');
    },
  );

  test('auditLogsProvider muat data bila log masuk', () async {
    final dio = _StubDio();
    final container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(dio),
        authNotifierProvider.overrideWith((ref) => _FakeAuth(loggedIn: true)),
      ],
    );
    addTearDown(container.dispose);

    final state = await container.read(
      auditLogsProvider(const AuditFilter()).future,
    );

    expect(state.logs, hasLength(1));
    expect(dio.calls, 1);
  });

  // Inti isu: selepas logout, state yang dicache MESTI dibuang, bukan
  // kekal tersedia untuk sesiapa yang guna peranti tu seterusnya.
  test('logout kosongkan jejak yang dah dicache', () async {
    final dio = _StubDio();
    final auth = _FakeAuth(loggedIn: true);
    final container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(dio),
        authNotifierProvider.overrideWith((ref) => auth),
      ],
    );
    addTearDown(container.dispose);

    final loaded = await container.read(
      auditLogsProvider(const AuditFilter()).future,
    );
    expect(loaded.logs, hasLength(1));

    auth.logOut();
    await container.pump();

    final after = await container.read(
      auditLogsProvider(const AuditFilter()).future,
    );
    expect(
      after.logs,
      isEmpty,
      reason: 'jejak audit user sebelum masih tersedia selepas logout',
    );
  });
}

/// TokenStorage sebenar tak pernah disentuh — state ditetapkan terus.
class _FakeAuth extends AuthNotifier {
  _FakeAuth({required bool loggedIn}) : super(TokenStorage()) {
    state = AuthState(isLoggedIn: loggedIn, accessToken: loggedIn ? 'a' : null);
  }

  void logOut() => state = const AuthState();
}
