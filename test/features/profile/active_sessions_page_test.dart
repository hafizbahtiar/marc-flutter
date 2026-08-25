import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/core/api_client.dart';
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
  String? userAgent = 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0)',
  String? createdIp = '203.0.113.7',
}) => SessionRow(
  id: id,
  userAgent: userAgent,
  createdIp: createdIp,
  createdAt: DateTime.now().subtract(const Duration(hours: 3)),
  expiresAt: DateTime.now().add(const Duration(days: 30)),
);

Widget _wrap({required List<SessionRow> rows, Dio? dio}) => ProviderScope(
  overrides: [
    sessionsProvider.overrideWith((ref) async => rows),
    if (dio != null) dioProvider.overrideWithValue(dio),
  ],
  child: MaterialApp(theme: AppTheme.light, home: const ActiveSessionsPage()),
);

void main() {
  testWidgets('papar user-agent, IP dan masa relatif setiap sesi', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(rows: [_row()]));
    await tester.pumpAndSettle();

    expect(
      find.text('Mozilla/5.0 (iPhone; CPU iPhone OS 18_0)'),
      findsOneWidget,
    );
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
}
