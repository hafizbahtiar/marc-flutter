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
import 'package:marc/features/notifications/notifications_page.dart';
import 'package:marc/features/profile/profile_providers.dart';

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

ResponseBody _jsonResponse(Map<String, dynamic> body, {int status = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

const _member = Profile(
  memberId: 'MARC-001',
  email: 'ahli@example.com',
  emailVerified: true,
  status: 'approved',
  displayName: 'Ahli',
  phone: null,
  roleKey: 'member',
  roleName: 'Ahli',
  roleRank: 1,
  // Bukan `management` - kekalkan tab ni sebagai pengujian ahli biasa
  // (elak provider ahli pending disentuh langsung, padanan gate di
  // notifications_page.dart yang cuma `watch` provider itu bila
  // `isManagement`).
  category: 'member',
  telegramLinked: false,
);

/// Dua notifikasi: SATU berpelaku sebenar (`post_like`, seseorang lain
/// menyukai post ahli ini), SATU sistem (`activity_published`, actor_id
/// ialah pengurus yang menerbitkan - lihat nota `isPersonTriggeredNotification`
/// di notifications_page.dart). Kedua-dua ditanda `read: true` supaya
/// tiada panggilan `POST /notifications/:id/read` perlu dimock.
Map<String, dynamic> _notificationsJson() => {
  'notifications': [
    {
      'id': 'n1',
      'actor_id': 'actor-suka',
      'type': 'post_like',
      'post_id': 'p1',
      'comment_id': null,
      'activity_id': null,
      'certificate_id': null,
      'read': true,
      'created_at': '2026-08-20T00:00:00Z',
    },
    {
      'id': 'n2',
      'actor_id': 'pengurus-1',
      'type': 'activity_published',
      'post_id': null,
      'comment_id': null,
      'activity_id': 'a1',
      'certificate_id': null,
      'read': true,
      'created_at': '2026-08-19T00:00:00Z',
    },
  ],
  'next_cursor': null,
};

GoRouter _testRouter() {
  return GoRouter(
    initialLocation: '/notifications',
    routes: [
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsPage(),
      ),
      GoRoute(
        path: '/members/:userId',
        builder: (_, state) =>
            Scaffold(body: Text('profil-${state.pathParameters['userId']}')),
      ),
      GoRoute(
        path: '/activities/:id',
        builder: (_, state) =>
            Scaffold(body: Text('aktiviti-${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/posts/:id',
        builder: (_, state) =>
            Scaffold(body: Text('post-${state.pathParameters['id']}')),
      ),
      GoRoute(path: '/feed', builder: (_, _) => const Scaffold()),
    ],
  );
}

Widget _app(Dio dio, GoRouter router) {
  return ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(dio),
      authNotifierProvider.overrideWith((ref) => _LoggedInAuthNotifier()),
      myProfileProvider.overrideWith((ref) async => _member),
      routerProvider.overrideWithValue(router),
    ],
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
}

void main() {
  group('ketik ikon notifikasi berpelaku', () {
    testWidgets('navigasi ke profil ahli, bukan destinasi baris (post)', (
      tester,
    ) async {
      final dio = Dio(BaseOptions(baseUrl: 'https://test.local'));
      dio.httpClientAdapter = _FakeAdapter((options) async {
        if (options.path == '/notifications' && options.method == 'GET') {
          return _jsonResponse(_notificationsJson());
        }
        return _jsonResponse({'error': 'unexpected'}, status: 404);
      });

      final router = _testRouter();
      await tester.pumpWidget(_app(dio, router));
      await tester.pumpAndSettle();

      // `ListTile` sendiri turut bungkus SELURUH baris dalam `InkWell`
      // (destinasi utama baris) - cari sasaran ketuk ikon ni melalui
      // `Key` khususnya, bukan `find.byType(InkWell)` yang akan padan
      // KEDUA-DUA InkWell (baris + ikon).
      final iconTapTarget = find.byKey(const ValueKey('notif-actor-tap-n1'));
      expect(iconTapTarget, findsOneWidget);

      await tester.tap(iconTapTarget);
      await tester.pumpAndSettle();

      expect(find.text('profil-actor-suka'), findsOneWidget);
      // Ketuk ikon TAK patut turut buka post (destinasi utama baris) -
      // dua sasaran ketuk berasingan, padanan corak nama di
      // post_card.dart/comment_tile.dart.
      expect(find.text('post-p1'), findsNothing);
    });

    testWidgets(
      'jenis sistem (activity_published) - ikon TIDAK bawa ke profil ahli',
      (tester) async {
        final dio = Dio(BaseOptions(baseUrl: 'https://test.local'));
        dio.httpClientAdapter = _FakeAdapter((options) async {
          if (options.path == '/notifications' && options.method == 'GET') {
            return _jsonResponse(_notificationsJson());
          }
          return _jsonResponse({'error': 'unexpected'}, status: 404);
        });

        final router = _testRouter();
        await tester.pumpWidget(_app(dio, router));
        await tester.pumpAndSettle();

        // `activity_published` tak ada sasaran ketuk `Key`ed berasingan
        // bungkus ikonnya (tiada `notif-actor-tap-n2`) - ketukan pada
        // kawasan ikon jatuh terus ke `onTap` ListTile (destinasi baris
        // biasa), bukan profil `actor_id` (actor_id jenis ni ialah
        // pengurus yang menerbitkan, bukan "pelaku" yang bererti bagi
        // penerima).
        final eventIcon = find.byIcon(Icons.event_available_outlined);
        expect(eventIcon, findsOneWidget);
        expect(
          find.byKey(const ValueKey('notif-actor-tap-n2')),
          findsNothing,
          reason: 'jenis sistem tak patut ada sasaran ketuk profil berasingan',
        );

        await tester.tap(eventIcon);
        await tester.pumpAndSettle();

        expect(find.text('profil-pengurus-1'), findsNothing);
        expect(find.text('aktiviti-a1'), findsOneWidget);
      },
    );
  });
}
