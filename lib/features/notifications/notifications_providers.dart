import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/core/auth_state.dart';
import 'package:marc/features/posts/post_models.dart';

/// Senarai notifikasi. Reaktif pada status log masuk — sama macam
/// `membersProvider`/`myProfileProvider` — supaya tak papar data user lama
/// selepas logout/login semula (provider ni non-autoDispose).
final notificationsProvider = FutureProvider<List<AppNotification>>((
  ref,
) async {
  final isLoggedIn = ref.watch(
    authNotifierProvider.select((s) => s.isLoggedIn),
  );
  if (!isLoggedIn) return const [];

  final dio = ref.watch(dioProvider);
  final res = await dio.get('/notifications');
  final data = res.data as Map<String, dynamic>;
  return (data['notifications'] as List)
      .map((n) => AppNotification.fromJson(n as Map<String, dynamic>))
      .toList();
});

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref),
);

class NotificationRepository {
  NotificationRepository(this._ref);
  final Ref _ref;

  Future<void> markRead(String id) async {
    await _ref.read(dioProvider).post('/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await _ref.read(dioProvider).post('/notifications/read-all');
    _ref.invalidate(notificationsProvider);
  }
}
