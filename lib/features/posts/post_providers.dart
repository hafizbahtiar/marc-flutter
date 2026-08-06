import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:marc/core/api_client.dart';
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
  @override
  Future<FeedState> build() => _fetchPage(cursor: null);

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
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchPage(cursor: null));
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final next = await _fetchPage(cursor: current.nextCursor);
      state = AsyncData(
        current.copyWith(
          posts: [...current.posts, ...next.posts],
          nextCursor: () => next.nextCursor,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
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
      state = AsyncData(current);
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
}

final feedProvider = AsyncNotifierProvider<FeedNotifier, FeedState>(
  FeedNotifier.new,
);

final postDetailProvider = FutureProvider.family<Post, String>((
  ref,
  postId,
) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/posts/$postId');
  return Post.fromJson(res.data as Map<String, dynamic>);
});

final commentsProvider = FutureProvider.family<List<Comment>, String>((
  ref,
  postId,
) async {
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
  }

  Future<void> editPost(String id, String content) async {
    await _ref
        .read(dioProvider)
        .patch('/posts/$id', data: {'content': content});
    _ref.invalidate(postDetailProvider(id));
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
  }

  Future<void> deleteComment(String postId, String commentId) async {
    await _ref.read(dioProvider).delete('/comments/$commentId');
    _ref.invalidate(commentsProvider(postId));
    _ref.invalidate(postDetailProvider(postId));
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
