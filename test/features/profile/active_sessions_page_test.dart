import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/features/auth/auth_providers.dart';
import 'package:marc/features/auth/auth_service.dart';
import 'package:marc/features/profile/active_sessions_page.dart';
import 'package:marc/features/profile/session_providers.dart';

/// Padan pola `_FakeAdapter` di
/// `test/features/profile/profile_repository_invalidation_test.dart` -
/// duplikasi sengaja (helper test kecil, satu tapak panggilan setiap
/// fail), bukan diekstrak jadi kebergantungan silang-fail.
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

SessionRow _row({
  String id = 'sesi-1',
  String? userAgent = 'iPhone Hafiz - iOS 18.0',
  String? createdIp = '203.0.113.7',
  bool isCurrent = false,
}) => SessionRow(
  id: id,
  userAgent: userAgent,
  createdIp: createdIp,
  createdAt: DateTime.now().subtract(const Duration(hours: 3)),
  expiresAt: DateTime.now().add(const Duration(days: 30)),
  isCurrent: isCurrent,
);

class _RecordingAuthService implements AuthService {
  var signOutCalls = 0;

  @override
  Future<AuthResult> signIn(String email, String password) async =>
      const AuthResult(success: true);
  @override
  Future<AuthResult> signUp(
    String email,
    String password,
    String phone, {
    required String staffId,
  }) async => const AuthResult(success: true);
  @override
  Future<void> signOut() async => signOutCalls++;
  @override
  Future<void> ensureFreshSession() async {}
  @override
  Future<AuthResult> requestPasswordReset(String email) async =>
      const AuthResult(success: true);
  @override
  Future<({bool success, String? deepLink, String? error})>
  requestTelegramLinkToken() async =>
      (success: true, deepLink: null, error: null);
  @override
  Future<AuthResult> deleteTelegramLink() async =>
      const AuthResult(success: true);
}

Widget _wrap({
  required List<SessionRow> rows,
  Dio? dio,
  AuthService? authService,
}) => ProviderScope(
  overrides: [
    sessionsProvider.overrideWith((ref) async => rows),
    if (dio != null) dioProvider.overrideWithValue(dio),
    if (authService != null) authServiceProvider.overrideWithValue(authService),
  ],
  child: MaterialApp(theme: AppTheme.light, home: const ActiveSessionsPage()),
);

void main() {
  testWidgets('papar user-agent, IP dan masa relatif setiap sesi', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(rows: [_row()]));
    await tester.pumpAndSettle();

    expect(find.text('iPhone Hafiz - iOS 18.0'), findsOneWidget);
    // relativeTime(3 jam lepas) == '3j'
    expect(find.text('203.0.113.7 · 3j'), findsOneWidget);
    expect(find.byIcon(Icons.logout), findsOneWidget);
  });

  // Sesi lama (dicipta sebelum backend rakam metadata) pulang null -
  // baris mesti tetap muncul & boleh dilog keluar, bukan hilang.
  testWidgets('sesi tanpa metadata papar label tidak diketahui', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(rows: [_row(userAgent: null, createdIp: null)]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Peranti tidak diketahui'), findsOneWidget);
    expect(find.textContaining('IP tidak diketahui'), findsOneWidget);
    expect(find.byIcon(Icons.logout), findsOneWidget);
  });

  testWidgets('senarai kosong papar mesej tiada sesi', (tester) async {
    await tester.pumpWidget(_wrap(rows: const []));
    await tester.pumpAndSettle();

    expect(find.text('Tiada sesi aktif.'), findsOneWidget);
  });

  testWidgets('batal dialog pengesahan TAK hantar DELETE', (tester) async {
    final calls = <String>[];
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = _FakeAdapter((options) async {
        calls.add('${options.method} ${options.path}');
        return ResponseBody.fromString('', 204);
      });

    await tester.pumpWidget(_wrap(rows: [_row()], dio: dio));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();
    expect(find.text('Log keluar sesi'), findsOneWidget);

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(calls, isEmpty);
  });

  testWidgets('sahkan dialog hantar DELETE /me/sessions/:id', (tester) async {
    final calls = <String>[];
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = _FakeAdapter((options) async {
        calls.add('${options.method} ${options.path}');
        return ResponseBody.fromString('', 204);
      });

    await tester.pumpWidget(
      _wrap(
        rows: [_row(id: 'sesi-abc')],
        dio: dio,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();

    // Butang sahkan dialog Material ialah ElevatedButton (butang batal
    // OutlinedButton) - padanan `test/shared/app_dialog_test.dart`.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log keluar'));
    await tester.pumpAndSettle();

    expect(calls, ['DELETE /me/sessions/sesi-abc']);
  });

  testWidgets('mod pilih: pilih semua + log keluar hantar POST bulk revoke', (
    tester,
  ) async {
    final calls = <String>[];
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = _FakeAdapter((options) async {
        calls.add('${options.method} ${options.path}');
        return ResponseBody.fromString('{"deleted":2}', 200);
      });

    await tester.pumpWidget(
      _wrap(
        rows: [
          _row(id: 'sesi-a'),
          _row(id: 'sesi-b'),
        ],
        dio: dio,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Pilih sesi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih semua'));
    await tester.pumpAndSettle();

    expect(find.text('2 dipilih'), findsOneWidget);

    await tester.tap(find.byTooltip('Log keluar terpilih'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log keluar (2)'));
    await tester.pumpAndSettle();

    expect(calls, ['POST /me/sessions/revoke']);
  });

  testWidgets('sesi semasa bertanda Peranti ini', (tester) async {
    await tester.pumpWidget(
      _wrap(
        rows: [
          _row(isCurrent: true),
          _row(id: 'sesi-2'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Peranti ini'), findsOneWidget);
  });

  testWidgets('revoke peranti ini hantar DELETE kemudian signOut', (
    tester,
  ) async {
    final auth = _RecordingAuthService();
    final calls = <String>[];
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = _FakeAdapter((options) async {
        calls.add('${options.method} ${options.path}');
        return ResponseBody.fromString('', 204);
      });

    await tester.pumpWidget(
      _wrap(
        rows: [_row(id: 'family-ini', isCurrent: true)],
        dio: dio,
        authService: auth,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();
    expect(find.text('Log keluar peranti ini'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Log keluar'));
    await tester.pumpAndSettle();

    expect(calls, ['DELETE /me/sessions/family-ini']);
    expect(auth.signOutCalls, 1);
  });
}
