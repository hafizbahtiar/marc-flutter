import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/core/auth_state.dart';
import 'package:marc/features/posts/post_models.dart';

/// State feed: senarai post + cursor untuk load-more (infinite scroll).
class FeedState {
  const FeedState({
    this.posts = const [],
    this.nextCursor,
    this.isLoadingMore = false,
  });

  final List<Post> posts;
  final String? nextCursor;
  final bool isLoadingMore;

  bool get hasMore => nextCursor != null;

  FeedState copyWith({
    List<Post>? posts,
    String? Function()? nextCursor,
    bool? isLoadingMore,
  }) {
    return FeedState(
      posts: posts ?? this.posts,
      nextCursor: nextCursor != null ? nextCursor() : this.nextCursor,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class FeedNotifier extends AsyncNotifier<FeedState> {
  int _generation = 0;

  @override
  Future<FeedState> build() async {
    // Reaktif pada status log masuk — sama macam `membersProvider` — supaya
    // feed user lama tak kekal terpapar untuk user seterusnya pada peranti
    // sama (ProviderContainer dicipta sekali sahaja dalam main.dart).
    _generation++;
    final isLoggedIn = ref.watch(
      authNotifierProvider.select((s) => s.isLoggedIn),
    );
    if (!isLoggedIn) return const FeedState();

    return _fetchPage(cursor: null);
  }

  Future<FeedState> _fetchPage({required String? cursor}) async {
    final dio = ref.read(dioProvider);
    final res = await dio.get(
      '/posts',
      queryParameters: cursor != null ? {'cursor': cursor} : null,
    );
    final data = res.data as Map<String, dynamic>;
    final posts = (data['posts'] as List)
        .map((p) => Post.fromJson(p as Map<String, dynamic>))
        .toList();
    return FeedState(posts: posts, nextCursor: data['next_cursor'] as String?);
  }

  Future<void> refresh() async {
    final gen = ++_generation;
    // copyWithPrevious (isRefresh: true default) keeps the previous data
    // accessible via isRefreshing/valueOrNull so `feed.when(...)` in
    // feed_page.dart (skipLoadingOnRefresh: true by default in this
    // Riverpod version) skips the loading branch and keeps showing the
    // existing list instead of flashing a full-screen spinner + losing
    // scroll position during pull-to-refresh.
    state = AsyncLoading<FeedState>().copyWithPrevious(state);
    final result = await AsyncValue.guard(() => _fetchPage(cursor: null));
    if (gen != _generation) return;
    state = result;
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    final gen = _generation;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final next = await _fetchPage(cursor: current.nextCursor);
      if (gen != _generation) return;
      final latest = state.valueOrNull ?? current;
      state = AsyncData(
        latest.copyWith(
          posts: [...latest.posts, ...next.posts],
          nextCursor: () => next.nextCursor,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      if (gen != _generation) return;
      final latest = state.valueOrNull ?? current;
      state = AsyncData(latest.copyWith(isLoadingMore: false));
    }
  }

  /// Optimistic toggle — UI update serta-merta, revert kalau API gagal.
  Future<void> toggleLike(Post post) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final wasLiked = post.likedByMe;
    state = AsyncData(
      current.copyWith(
        posts: current.posts.map((p) {
          if (p.id != post.id) return p;
          return p.copyWith(
            likedByMe: !wasLiked,
            likeCount: p.likeCount + (wasLiked ? -1 : 1),
          );
        }).toList(),
      ),
    );

    try {
      final dio = ref.read(dioProvider);
      if (wasLiked) {
        await dio.delete('/posts/${post.id}/like');
      } else {
        await dio.post('/posts/${post.id}/like');
      }
    } catch (_) {
      final latest = state.valueOrNull;
      if (latest == null) return;
      state = AsyncData(
        latest.copyWith(
          posts: latest.posts.map((p) {
            if (p.id != post.id) return p;
            return p.copyWith(
              likedByMe: wasLiked,
              likeCount: p.likeCount + (wasLiked ? 1 : -1),
            );
          }).toList(),
        ),
      );
    }
  }

  void removePost(String postId) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        posts: current.posts.where((p) => p.id != postId).toList(),
      ),
    );
  }

  /// Ganti satu post dalam feed dengan versi terkini — dipanggil lepas
  /// mutation (like/edit/comment) dari post detail page berjaya, supaya
  /// feed sync balik tanpa perlu pull-to-refresh manual.
  void patchPost(Post updated) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        posts: current.posts
            .map((p) => p.id == updated.id ? updated : p)
            .toList(),
      ),
    );
  }
}

final feedProvider = AsyncNotifierProvider<FeedNotifier, FeedState>(
  FeedNotifier.new,
);

/// Post tunggal (halaman detail). Reaktif pada status log masuk — bukan
/// senarai, jadi takde "empty state" semula jadi macam `feedProvider`; kita
/// throw supaya `PostDetailPage` papar error state sedia ada ("Gagal memuat
/// post.") dan bukan cache post user lama. Route ni sepatutnya tak boleh
/// dicapai selepas logout pun (GoRouter redirect ke /login), jadi ini
/// defence-in-depth untuk senario sama-peranti/timing edge case.
final postDetailProvider = FutureProvider.family<Post, String>((
  ref,
  postId,
) async {
  final isLoggedIn = ref.watch(
    authNotifierProvider.select((s) => s.isLoggedIn),
  );
  if (!isLoggedIn) {
    throw StateError('Sesi tamat — sila log masuk semula.');
  }

  final dio = ref.watch(dioProvider);
  final res = await dio.get('/posts/$postId');
  return Post.fromJson(res.data as Map<String, dynamic>);
});

/// Comment untuk satu post. Sama rasional dengan `postDetailProvider` di
/// atas — throw bila logout supaya `PostDetailPage` guna error state
/// sedia ada ("Gagal memuat comment.") dan bukan papar comment user lama.
final commentsProvider = FutureProvider.family<List<Comment>, String>((
  ref,
  postId,
) async {
  final isLoggedIn = ref.watch(
    authNotifierProvider.select((s) => s.isLoggedIn),
  );
  if (!isLoggedIn) {
    throw StateError('Sesi tamat — sila log masuk semula.');
  }

  final dio = ref.watch(dioProvider);
  final res = await dio.get('/posts/$postId/comments');
  final data = res.data as Map<String, dynamic>;
  return (data['comments'] as List)
      .map((c) => Comment.fromJson(c as Map<String, dynamic>))
      .toList();
});

final postRepositoryProvider = Provider<PostRepository>(
  (ref) => PostRepository(ref),
);

class PostRepository {
  PostRepository(this._ref);
  final Ref _ref;

  String _contentTypeFor(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  /// Minta presigned URL dari backend, upload gambar TERUS ke R2 (bukan
  /// melalui backend kita), pulangkan r2_key untuk attach ke post.
  Future<String> uploadImage(XFile file) async {
    final contentType = _contentTypeFor(file.path);
    final dio = _ref.read(dioProvider);

    final presign = await dio.post(
      '/uploads/presign',
      data: {'content_type': contentType},
    );
    final uploadUrl = presign.data['upload_url'] as String;
    final r2Key = presign.data['r2_key'] as String;

    final bytes = await file.readAsBytes();
    // Dio baru (bukan yang ada auth interceptor) — presigned URL R2 bukan
    // endpoint backend kita, tak perlu/patut Bearer token.
    await Dio().put(
      uploadUrl,
      data: bytes,
      options: Options(headers: {'Content-Type': contentType}),
    );

    return r2Key;
  }

  Future<Post> createPost({
    required String content,
    String type = 'normal',
    List<String> r2Keys = const [],
  }) async {
    final res = await _ref
        .read(dioProvider)
        .post(
          '/posts',
          data: {'content': content, 'type': type, 'r2_keys': r2Keys},
        );
    return Post.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deletePost(String id) async {
    await _ref.read(dioProvider).delete('/posts/$id');
  }

  /// Untuk halaman detail (bukan feed list) — feed guna
  /// `FeedNotifier.toggleLike` (optimistic + revert dalam FeedState terus).
  Future<void> togglePostLike(String id, bool currentlyLiked) async {
    final dio = _ref.read(dioProvider);
    if (currentlyLiked) {
      await dio.delete('/posts/$id/like');
    } else {
      await dio.post('/posts/$id/like');
    }
    _ref.invalidate(postDetailProvider(id));
    await _syncPostToFeed(id);
  }

  Future<void> editPost(String id, String content) async {
    await _ref
        .read(dioProvider)
        .patch('/posts/$id', data: {'content': content});
    _ref.invalidate(postDetailProvider(id));
    await _syncPostToFeed(id);
  }

  Future<void> createComment(
    String postId,
    String content, {
    String? parentCommentId,
  }) async {
    await _ref
        .read(dioProvider)
        .post(
          '/posts/$postId/comments',
          data: {'content': content, 'parent_comment_id': ?parentCommentId},
        );
    _ref.invalidate(commentsProvider(postId));
    _ref.invalidate(postDetailProvider(postId));
    await _syncPostToFeed(postId);
  }

  Future<void> deleteComment(String postId, String commentId) async {
    await _ref.read(dioProvider).delete('/comments/$commentId');
    _ref.invalidate(commentsProvider(postId));
    _ref.invalidate(postDetailProvider(postId));
    await _syncPostToFeed(postId);
  }

  /// Refetch post terkini dari server dan patch ke dalam feed cache — best
  /// effort, tak boleh gagalkan mutation utama (like/edit/comment) yang dah
  /// pun berjaya.
  Future<void> _syncPostToFeed(String postId) async {
    try {
      final updated = await _ref.read(postDetailProvider(postId).future);
      _ref.read(feedProvider.notifier).patchPost(updated);
    } catch (_) {
      // Feed cuma tak sync sehingga pull-to-refresh seterusnya — bukan
      // kritikal, mutation utama (like/edit/comment) dah pun berjaya.
    }
  }

  Future<void> editComment(
    String postId,
    String commentId,
    String content,
  ) async {
    await _ref
        .read(dioProvider)
        .patch('/comments/$commentId', data: {'content': content});
    _ref.invalidate(commentsProvider(postId));
  }

  Future<void> toggleCommentLike(
    String postId,
    String commentId,
    bool currentlyLiked,
  ) async {
    final dio = _ref.read(dioProvider);
    if (currentlyLiked) {
      await dio.delete('/comments/$commentId/like');
    } else {
      await dio.post('/comments/$commentId/like');
    }
    _ref.invalidate(commentsProvider(postId));
  }
}
