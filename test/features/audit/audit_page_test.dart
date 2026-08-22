import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/core/auth_state.dart';
import 'package:marc/core/token_storage.dart';
import 'package:marc/features/audit/audit_page.dart';
import 'package:marc/features/profile/profile_providers.dart';

Profile _profile({required bool management}) => Profile(
  memberId: 'MARC2026/08/0001',
  email: 'a@b.com',
  emailVerified: true,
  status: 'approved',
  displayName: 'Hafiz',
  phone: null,
  roleKey: management ? 'manager' : 'ahli',
  roleName: management ? 'Manager' : 'Ahli',
  roleRank: management ? 60 : 10,
  category: management ? 'management' : 'ahli',
  telegramLinked: false,
);

/// Dio palsu yang merekod query param setiap permintaan, supaya ujian
/// boleh sahkan pagination keyset menghantar `before_id` yang betul.
class _FakeDio with DioMixin implements Dio {
  _FakeDio(this.pages) {
    options = BaseOptions();
    httpClientAdapter = _NoopAdapter();
  }

  final List<List<Map<String, dynamic>>> pages;
  final List<Map<String, dynamic>> requests = [];
  int _call = 0;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    requests.add(Map<String, dynamic>.from(queryParameters ?? {}));
    final page = _call < pages.length ? pages[_call] : <Map<String, dynamic>>[];
    _call++;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: {'logs': page} as T,
    );
  }
}

class _NoopAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(o, s, f) async => ResponseBody.fromString('', 200);
}

Map<String, dynamic> _log(int id, {String action = 'update'}) => {
  'id': id,
  'entity_type': 'post',
  'entity_id': '11111111-1111-1111-1111-111111111111',
  'action': action,
  'actor_id': null,
  'actor_member_id': 'MARC2026/08/0009',
  'actor_role_key': 'manager',
  'changed_fields': ['content'],
  'old_values': {'content': 'lama $id'},
  'new_values': {'content': 'baru $id'},
  'created_at': DateTime.now().toIso8601String(),
};

/// Sesi log masuk — `auditLogsProvider` sengaja pulang kosong tanpa ni
/// (guard auth; lihat audit_auth_guard_test.dart).
class _LoggedInAuth extends AuthNotifier {
  _LoggedInAuth() : super(TokenStorage()) {
    state = const AuthState(isLoggedIn: true, accessToken: 'a');
  }
}

Widget _app(Dio dio, {required bool management}) => ProviderScope(
  overrides: [
    dioProvider.overrideWithValue(dio),
    authNotifierProvider.overrideWith((ref) => _LoggedInAuth()),
    myProfileProvider.overrideWith(
      (ref) async => _profile(management: management),
    ),
  ],
  child: MaterialApp(theme: AppTheme.light, home: const AuditPage()),
);

void main() {
  testWidgets('ahli biasa nampak mesej tiada akses, tiada panggilan API', (
    tester,
  ) async {
    final dio = _FakeDio([]);
    await tester.pumpWidget(_app(dio, management: false));
    await tester.pumpAndSettle();

    expect(find.text('Anda tiada akses ke skrin ini.'), findsOneWidget);
    expect(dio.requests, isEmpty);
  });

  testWidgets('management nampak catatan + diff lama/baru bila dibuka', (
    tester,
  ) async {
    final dio = _FakeDio([
      [_log(3), _log(2)],
    ]);
    await tester.pumpWidget(_app(dio, management: true));
    await tester.pumpAndSettle();

    expect(find.text('Post dikemas kini'), findsNWidgets(2));

    // Diff disorok sehingga baris dikembangkan.
    expect(find.text('lama 3'), findsNothing);
    await tester.tap(find.text('Post dikemas kini').first);
    await tester.pumpAndSettle();
    expect(find.text('lama 3'), findsOneWidget);
    expect(find.text('baru 3'), findsOneWidget);
  });

  testWidgets('tapis ikut entiti hantar entity_type ke backend', (
    tester,
  ) async {
    final dio = _FakeDio([
      [_log(1)],
      [_log(1)],
    ]);
    await tester.pumpWidget(_app(dio, management: true));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Comment'));
    await tester.pumpAndSettle();

    expect(dio.requests.last['entity_type'], 'comment');
  });

  // Pagination keyset: permintaan kedua MESTI bawa before_id = id terakhir
  // yang diterima. Kalau tidak, halaman kedua akan ulang halaman pertama.
  testWidgets('load more guna before_id catatan terakhir', (tester) async {
    final firstPage = [for (var i = 50; i >= 1; i--) _log(i)];
    final dio = _FakeDio([
      firstPage,
      [_log(0)],
    ]);

    await tester.pumpWidget(_app(dio, management: true));
    await tester.pumpAndSettle();

    expect(dio.requests.first.containsKey('before_id'), isFalse);

    await tester.drag(find.byType(ListView), const Offset(0, -4000));
    await tester.pumpAndSettle();

    expect(dio.requests.length, greaterThan(1));
    expect(dio.requests.last['before_id'], 1);
  });
}
