import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/core/auth_state.dart';
import 'package:marc/features/posts/post_models.dart';

/// State notifikasi: senarai + cursor untuk load-more (infinite scroll) -
/// sama struktur macam `FeedState`.
class NotificationsState {
  const NotificationsState({
    this.items = const [],
    this.nextCursor,
    this.isLoadingMore = false,
  });

  final List<AppNotification> items;
  final String? nextCursor;
  final bool isLoadingMore;

  bool get hasMore => nextCursor != null;

  NotificationsState copyWith({
    List<AppNotification>? items,
    String? Function()? nextCursor,
    bool? isLoadingMore,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      nextCursor: nextCursor != null ? nextCursor() : this.nextCursor,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// Reaktif pada status log masuk - sama macam `FeedNotifier` - supaya
/// notifikasi user lama tak kekal terpapar untuk user seterusnya pada
/// peranti sama. Generation counter guard sama sebab (race loadMore vs
/// refresh) macam FeedNotifier.
class NotificationsNotifier extends AsyncNotifier<NotificationsState> {
  int _generation = 0;

  @override
  Future<NotificationsState> build() async {
    _generation++;
    final isLoggedIn = ref.watch(
      authNotifierProvider.select((s) => s.isLoggedIn),
    );
    if (!isLoggedIn) return const NotificationsState();

    return _fetchPage(cursor: null);
  }

  Future<NotificationsState> _fetchPage({required String? cursor}) async {
    final dio = ref.read(dioProvider);
    final res = await dio.get(
      '/notifications',
      queryParameters: cursor != null ? {'cursor': cursor} : null,
    );
    final data = res.data as Map<String, dynamic>;
    final items = (data['notifications'] as List)
        .map((n) => AppNotification.fromJson(n as Map<String, dynamic>))
        .toList();
    return NotificationsState(
      items: items,
      nextCursor: data['next_cursor'] as String?,
    );
  }

  Future<void> refresh() async {
    final gen = ++_generation;
    state = AsyncLoading<NotificationsState>().copyWithPrevious(state);
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
          items: [...latest.items, ...next.items],
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

  /// Patch satu notification jadi `read` secara lokal - dipanggil lepas
  /// `NotificationRepository.markRead` berjaya, elak full refetch (yang
  /// akan reset kedudukan scroll pengguna).
  void patchRead(String id) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        items: current.items
            .map((n) => n.id == id ? n.copyWith(read: true) : n)
            .toList(),
      ),
    );
  }

  /// Patch SEMUA notification jadi `read` secara lokal - lepas
  /// `markAllRead` berjaya.
  void patchAllRead() {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        items: current.items.map((n) => n.copyWith(read: true)).toList(),
      ),
    );
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, NotificationsState>(
      NotificationsNotifier.new,
    );

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref),
);

class NotificationRepository {
  NotificationRepository(this._ref);
  final Ref _ref;

  Future<void> markRead(String id) async {
    await _ref.read(dioProvider).post('/notifications/$id/read');
    _ref.read(notificationsProvider.notifier).patchRead(id);
  }

  Future<void> markAllRead() async {
    await _ref.read(dioProvider).post('/notifications/read-all');
    _ref.read(notificationsProvider.notifier).patchAllRead();
  }
}
