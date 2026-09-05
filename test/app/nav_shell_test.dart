import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marc/app/router.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/core/auth_state.dart';
import 'package:marc/core/token_storage.dart';
import 'package:marc/features/profile/profile_providers.dart';

import '../support/profile_fixtures.dart';

class _LoggedInAuthNotifier extends AuthNotifier {
  _LoggedInAuthNotifier() : super(TokenStorage()) {
    state = const AuthState(isLoggedIn: true, accessToken: 'test-token');
  }
}

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

// Urutan `destinations` dalam nav_shell.dart dan urutan `branches` dalam
// router.dart MESTI sepadan - go_router memilih branch mengikut INDEKS,
// jadi susunan yang tidak sepadan menghantar pengguna ke tab yang salah
// tanpa sebarang ralat. Ujian ini ialah satu-satunya benda yang
// menangkapnya.
// Payload kosong-tetapi-sah untuk setiap endpoint yang mana-mana tab
// mungkin panggil semasa ia dibina. Suis pada laluan, bukan satu jawapan
// untuk semua - tab yang menerima bentuk salah akan melontar semasa
// build dan menyembunyikan kegagalan navigasi sebenar.
ResponseBody _jawab(RequestOptions options) {
  final body = switch (options.path) {
    '/dashboard' => {
      'member': {
        'membership': {'status': 'approved'},
        'open_activities': [],
        'certificates_total': 0,
        'total_members': 0,
      },
      'admin': null,
    },
    '/posts' => {'posts': [], 'next_cursor': null},
    '/activities' => {'activities': [], 'next_cursor': null},
    '/notifications' => {'notifications': [], 'next_cursor': null},
    _ => <String, dynamic>{},
  };
  return ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

// Ujian ini memasang routerProvider yang SEBENAR (bukan router ujian
// seperti dalam dashboard_page_test.dart) - yang diuji ialah kandungan
// router itu sendiri, jadi menggantikannya akan menguji ketiadaan.
Future<GoRouter> _pumpApp(WidgetTester tester) async {
  final dio = Dio()..httpClientAdapter = _FakeAdapter((o) async => _jawab(o));
  late GoRouter router;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(dio),
        authNotifierProvider.overrideWith((ref) => _LoggedInAuthNotifier()),
        myProfileProvider.overrideWith((ref) async => approvedProfile),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          router = ref.watch(routerProvider);
          return MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('mengetuk setiap destinasi mendarat pada route yang sepadan', (
    tester,
  ) async {
    final router = await _pumpApp(tester);

    const dijangka = <(String, String)>[
      ('Utama', '/dashboard'),
      ('Hebahan', '/feed'),
      ('Aktiviti', '/activities'),
      ('Notifikasi', '/notifications'),
      ('Profil', '/profile'),
    ];

    for (final (label, laluan) in dijangka) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        router.state.matchedLocation,
        laluan,
        reason:
            'tab "$label" sepatutnya membuka $laluan - '
            'urutan branches dalam router.dart tidak sepadan dengan '
            'urutan destinations dalam nav_shell.dart',
      );
    }
  });

  testWidgets('log masuk mendarat pada /dashboard, bukan /feed', (
    tester,
  ) async {
    final router = await _pumpApp(tester);

    // routerProvider bermula pada /login; refresh redirect untuk pengguna
    // yang sudah log masuk menyelesaikan ke destinasi lalai.
    expect(router.state.matchedLocation, '/dashboard');
  });
}
