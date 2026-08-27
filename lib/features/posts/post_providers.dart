import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/core/app_log.dart';
import 'package:marc/core/auth_state.dart';
import 'package:marc/features/posts/post_models.dart';
import 'package:marc/shared/data/local_drafts_repository.dart';

/// Kunci draf penggubah post baru - SATU sumber kebenaran, dikongsi
/// dengan `create_post_page.dart` (diimport dari sini, bukan disalin -
/// elak dua nilai berlainan berlanggar senyap-senyap).
const newPostDraftKey = 'new_post';

/// Wujud/tidak draf 'new_post' - digunakan oleh badge pada Feed FAB
/// (`feed_page.dart`) supaya user nampak isyarat "ada draf belum
/// dihantar" tanpa perlu buka penggubah dahulu. FutureProvider (bukan
/// autoDispose) - dibaca semula secara eksplisit lepas
/// `context.push('/posts/new')` resolve (lihat feed_page.dart), bukan
/// polling/stream, sebab draf hanya berubah semasa penggubah dibuka.
final hasNewPostDraftProvider = FutureProvider<bool>((ref) async {
  final draft = await ref.watch(draftRepositoryProvider).get(newPostDraftKey);
  return draft != null;
});

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
    // Reaktif pada status log masuk - sama macam `membersProvider` - supaya
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

  /// Optimistic toggle - UI update serta-merta, revert kalau API gagal.
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
      // postDetailProvider (FutureProvider.family, bukan autoDispose)
      // cache per post id tanpa had masa - kalau detail page post ni
      // pernah dibuka sebelum ni, cache lama tak refetch sendiri bila
      // like berubah dari list. Invalidate supaya lawatan detail
      // seterusnya fetch fresh (bukan force refetch serta-merta kalau
      // takde sesiapa watch sekarang).
      ref.invalidate(postDetailProvider(post.id));
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

  /// Ganti satu post dalam feed dengan versi terkini - dipanggil lepas
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

/// Post tunggal (halaman detail). Reaktif pada status log masuk - bukan
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
    throw StateError('Sesi tamat - sila log masuk semula.');
  }

  final dio = ref.watch(dioProvider);
  final res = await dio.get('/posts/$postId');
  return Post.fromJson(res.data as Map<String, dynamic>);
});

/// Comment untuk satu post. Sama rasional dengan `postDetailProvider` di
/// atas - throw bila logout supaya `PostDetailPage` guna error state
/// sedia ada ("Gagal memuat comment.") dan bukan papar comment user lama.
final commentsProvider = FutureProvider.family<List<Comment>, String>((
  ref,
  postId,
) async {
  final isLoggedIn = ref.watch(
    authNotifierProvider.select((s) => s.isLoggedIn),
  );
  if (!isLoggedIn) {
    throw StateError('Sesi tamat - sila log masuk semula.');
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

  /// Sniff bait sebenar fail untuk tentukan content-type - TIDAK boleh
  /// percaya extension nama fail sebab image_picker (imageQuality: 85)
  /// boleh re-encode gambar ke JPEG walaupun fail asal .png/.webp. Simetri
  /// dengan magic-byte check backend.
  Future<String> _contentTypeFor(XFile file) async {
    final chunks = await file.openRead(0, 12).toList();
    final bytes = chunks.expand((c) => c).toList();

    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    return 'image/jpeg'; // fallback - sepadan default picker app ini
  }

  /// Minta presigned URL dari backend, upload gambar TERUS ke R2 (bukan
  /// melalui backend kita), pulangkan r2_key untuk attach ke post.
  /// Upload satu gambar: presign (backend kita) → PUT terus ke R2.
  ///
  /// Dua peringkat, dua HOST berbeza, dua punca kegagalan yang berbeza
  /// sepenuhnya - sebab tu setiap peringkat dilog berasingan. "Post biasa
  /// jadi, post bergambar gagal" hampir sentiasa bermaksud peringkat R2
  /// yang putus, bukan backend.
  Future<String> uploadImage(XFile file) async {
    final contentType = await _contentTypeFor(file);
    final dio = _ref.read(dioProvider);

    appLog('upload', 'presign mula (content_type=$contentType)');
    late final Response<dynamic> presign;
    try {
      presign = await dio.post(
        '/uploads/presign',
        data: {'content_type': contentType},
      );
    } on DioException catch (e) {
      appLogDioError('upload', 'presign', e);
      rethrow;
    }

    final uploadUrl = presign.data['upload_url'] as String;
    final r2Key = presign.data['r2_key'] as String;
    appLog(
      'upload',
      'presign OK (r2_key=$r2Key, host=${Uri.parse(uploadUrl).host})',
    );

    final bytes = await file.readAsBytes();
    appLog('upload', 'PUT R2 mula (${bytes.length} bait)');

    try {
      // Dio baru (bukan yang ada auth interceptor) - presigned URL R2 bukan
      // endpoint backend kita, tak perlu/patut Bearer token. Timeout
      // ditetapkan eksplisit: Dio() kosong TIADA timeout langsung, jadi
      // upload yang tersekat akan tergantung selamanya dan bukan gagal
      // dengan ralat yang boleh dilihat.
      final res =
          await Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              sendTimeout: const Duration(seconds: 60),
              receiveTimeout: const Duration(seconds: 30),
            ),
          ).put(
            uploadUrl,
            data: bytes,
            options: Options(headers: {'Content-Type': contentType}),
          );
      appLog('upload', 'PUT R2 OK (status=${res.statusCode}, r2_key=$r2Key)');
    } on DioException catch (e) {
      appLogDioError('upload', 'PUT R2 (r2_key=$r2Key)', e);
      rethrow;
    }

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

  /// Untuk halaman detail (bukan feed list) - feed guna
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

  /// Refetch post terkini dari server dan patch ke dalam feed cache - best
  /// effort, tak boleh gagalkan mutation utama (like/edit/comment) yang dah
  /// pun berjaya.
  Future<void> _syncPostToFeed(String postId) async {
    try {
      final updated = await _ref.read(postDetailProvider(postId).future);
      _ref.read(feedProvider.notifier).patchPost(updated);
    } catch (_) {
      // Feed cuma tak sync sehingga pull-to-refresh seterusnya - bukan
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
