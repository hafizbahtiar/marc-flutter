import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/core/auth_state.dart';
import 'package:marc/core/token_storage.dart';
import 'package:marc/features/posts/post_models.dart';
import 'package:marc/features/posts/post_providers.dart';

/// AuthNotifier subclass yang terus start dalam keadaan log masuk - elak
/// perlu panggil `hydrate()`/secure storage sebenar dalam unit test.
class _LoggedInAuthNotifier extends AuthNotifier {
  _LoggedInAuthNotifier() : super(TokenStorage()) {
    state = const AuthState(isLoggedIn: true, accessToken: 'test-token');
  }
}

/// HttpClientAdapter palsu - route request ke callback yang test sediakan,
/// supaya kita boleh kawal timing (guna Completer) untuk simulate race
/// condition antara `loadMore`/`refresh`/`toggleLike` tanpa network sebenar.
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
  ) {
    return _onFetch(options);
  }
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

Map<String, dynamic> _postJson(
  String id, {
  int likeCount = 0,
  bool likedByMe = false,
}) {
  return {
    'id': id,
    'type': 'normal',
    'content': 'content-$id',
    'created_at': '2026-01-01T00:00:00.000Z',
    'edited_at': null,
    'author': {'member_id': 'm1', 'display_name': 'Author'},
    'images': <String>[],
    'like_count': likeCount,
    'comment_count': 0,
    'liked_by_me': likedByMe,
  };
}

Dio _dioWith(Future<ResponseBody> Function(RequestOptions options) onFetch) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.httpClientAdapter = _FakeAdapter(onFetch);
  return dio;
}

ProviderContainer _containerWith(Dio dio) {
  final c = ProviderContainer(
    overrides: [
      dioProvider.overrideWithValue(dio),
      authNotifierProvider.overrideWith((ref) => _LoggedInAuthNotifier()),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

/// Small helper - spin the microtask queue until [check] becomes true, so
/// we can synchronize with a request that just started without relying on
/// real wall-clock delays.
Future<void> _waitUntil(bool Function() check) async {
  while (!check()) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('M2: like gagal SELEPAS loadMore tambah post baru → hanya post yang '
      'di-like di-revert, post baru dari loadMore kekal (bukan clobber whole '
      'state)', () async {
    final likeGate = Completer<void>();
    var likeRequested = false;

    final dio = _dioWith((options) async {
      if (options.method == 'GET' && options.path == '/posts') {
        final cursor = options.queryParameters['cursor'] as String?;
        if (cursor == null) {
          return _jsonResponse({
            'posts': [_postJson('p1'), _postJson('p2')],
            'next_cursor': 'c1',
          });
        }
        if (cursor == 'c1') {
          return _jsonResponse({
            'posts': [_postJson('p3')],
            'next_cursor': null,
          });
        }
      }
      if (options.method == 'POST' && options.path == '/posts/p1/like') {
        likeRequested = true;
        await likeGate.future;
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      }
      throw StateError('Unexpected request ${options.method} ${options.path}');
    });

    final container = _containerWith(dio);

    // Initial build: p1, p2, cursor c1.
    await container.read(feedProvider.future);
    final notifier = container.read(feedProvider.notifier);
    final p1 = container
        .read(feedProvider)
        .value!
        .posts
        .firstWhere((p) => p.id == 'p1');
    expect(p1.likedByMe, isFalse);

    // Kick off optimistic like - request gated, won't resolve yet.
    final likeFuture = notifier.toggleLike(p1);
    await _waitUntil(() => likeRequested);

    // Optimistic update should be visible immediately.
    final afterOptimistic = container.read(feedProvider).value!;
    expect(
      afterOptimistic.posts.firstWhere((p) => p.id == 'p1').likedByMe,
      isTrue,
    );

    // While the like request is still in flight, loadMore() completes
    // fully and appends p3.
    await notifier.loadMore();
    final afterLoadMore = container.read(feedProvider).value!;
    expect(afterLoadMore.posts.map((p) => p.id), ['p1', 'p2', 'p3']);

    // Now let the like request fail.
    likeGate.complete();
    await likeFuture;

    final finalState = container.read(feedProvider).value!;
    // p3 (added by loadMore while the like call was in flight) must NOT
    // be wiped out by the like-failure revert.
    expect(finalState.posts.map((p) => p.id), ['p1', 'p2', 'p3']);
    final finalP1 = finalState.posts.firstWhere((p) => p.id == 'p1');
    expect(finalP1.likedByMe, isFalse);
    expect(finalP1.likeCount, 0);
  });

  test('M3: loadMore selesai SELEPAS refresh dah selesai → refresh punya data '
      'tak di-overwrite oleh loadMore yang stale (generation guard)', () async {
    final loadMoreGate = Completer<void>();
    var loadMoreRequested = false;
    var noCursorCallCount = 0;

    final dio = _dioWith((options) async {
      if (options.method == 'GET' && options.path == '/posts') {
        final cursor = options.queryParameters['cursor'] as String?;
        if (cursor == null) {
          noCursorCallCount++;
          if (noCursorCallCount == 1) {
            // build()
            return _jsonResponse({
              'posts': [_postJson('p1'), _postJson('p2')],
              'next_cursor': 'c1',
            });
          }
          // refresh() - resolves immediately, ahead of the gated
          // loadMore next-page request below.
          return _jsonResponse({
            'posts': [_postJson('r1'), _postJson('r2')],
            'next_cursor': null,
          });
        }
        if (cursor == 'c1') {
          loadMoreRequested = true;
          await loadMoreGate.future;
          return _jsonResponse({
            'posts': [_postJson('p3')],
            'next_cursor': null,
          });
        }
      }
      throw StateError('Unexpected request ${options.method} ${options.path}');
    });

    final container = _containerWith(dio);
    await container.read(feedProvider.future);
    final notifier = container.read(feedProvider.notifier);
    expect(container.read(feedProvider).value!.posts.map((p) => p.id), [
      'p1',
      'p2',
    ]);

    // Start loadMore() - its next-page request is gated, won't resolve
    // until we signal.
    final loadMoreFuture = notifier.loadMore();
    await _waitUntil(() => loadMoreRequested);

    // While loadMore is in flight, refresh() runs to completion first.
    await notifier.refresh();
    final afterRefresh = container.read(feedProvider).value!;
    expect(afterRefresh.posts.map((p) => p.id), ['r1', 'r2']);

    // Now let loadMore's stale next-page response resolve.
    loadMoreGate.complete();
    await loadMoreFuture;

    final finalState = container.read(feedProvider).value!;
    // loadMore must NOT resurrect stale p1/p2 or clobber the refreshed
    // r1/r2 with its now-stale result.
    expect(finalState.posts.map((p) => p.id), ['r1', 'r2']);
  });

  test('FeedNotifier.patchPost menggantikan satu post sahaja dengan versi '
      'baru - post lain dalam feed tak terjejas', () async {
    final dio = _dioWith((options) async {
      if (options.method == 'GET' && options.path == '/posts') {
        return _jsonResponse({
          'posts': [_postJson('p1'), _postJson('p2')],
          'next_cursor': null,
        });
      }
      throw StateError('Unexpected request ${options.method} ${options.path}');
    });

    final container = _containerWith(dio);
    await container.read(feedProvider.future);
    final notifier = container.read(feedProvider.notifier);

    final updatedP1 = Post.fromJson(
      _postJson('p1', likeCount: 5, likedByMe: true),
    );
    notifier.patchPost(updatedP1);

    final finalState = container.read(feedProvider).value!;
    final p1 = finalState.posts.firstWhere((p) => p.id == 'p1');
    final p2 = finalState.posts.firstWhere((p) => p.id == 'p2');
    expect(p1.likeCount, 5);
    expect(p1.likedByMe, isTrue);
    // p2 must remain the original, untouched instance.
    expect(p2.likeCount, 0);
    expect(p2.likedByMe, isFalse);
  });

  test('M8: togglePostLike (dari post detail) sync balik ke feed cache '
      'tanpa perlu pull-to-refresh manual', () async {
    var likeCount = 0;
    var likedByMe = false;

    final dio = _dioWith((options) async {
      if (options.method == 'GET' && options.path == '/posts') {
        return _jsonResponse({
          'posts': [
            _postJson('p1', likeCount: likeCount, likedByMe: likedByMe),
            _postJson('p2'),
          ],
          'next_cursor': null,
        });
      }
      if (options.method == 'GET' && options.path == '/posts/p1') {
        return _jsonResponse(
          _postJson('p1', likeCount: likeCount, likedByMe: likedByMe),
        );
      }
      if (options.method == 'POST' && options.path == '/posts/p1/like') {
        likeCount = 1;
        likedByMe = true;
        return _jsonResponse({});
      }
      throw StateError('Unexpected request ${options.method} ${options.path}');
    });

    final container = _containerWith(dio);
    // Feed's cached view of p1 starts unliked, count 0.
    await container.read(feedProvider.future);
    final before = container
        .read(feedProvider)
        .value!
        .posts
        .firstWhere((p) => p.id == 'p1');
    expect(before.likedByMe, isFalse);
    expect(before.likeCount, 0);

    // Simulate: user opened p1 from feed, liked it from the detail page.
    await container.read(postRepositoryProvider).togglePostLike('p1', false);

    // Feed card for p1 must now reflect the server-confirmed state,
    // without a manual pull-to-refresh.
    final after = container
        .read(feedProvider)
        .value!
        .posts
        .firstWhere((p) => p.id == 'p1');
    expect(after.likedByMe, isTrue);
    expect(after.likeCount, 1);
    // p2 untouched.
    expect(
      container
          .read(feedProvider)
          .value!
          .posts
          .firstWhere((p) => p.id == 'p2')
          .likedByMe,
      isFalse,
    );
  });
}
