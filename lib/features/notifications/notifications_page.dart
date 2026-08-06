import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/features/notifications/notifications_providers.dart';
import 'package:marc/shared/relative_time.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          TextButton(
            onPressed: () =>
                ref.read(notificationRepositoryProvider).markAllRead(),
            child: const Text('Tanda semua dibaca'),
          ),
        ],
      ),
      body: SafeArea(
        child: notifications.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Gagal memuat notifikasi.'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(notificationsProvider),
                    child: const Text('Cuba lagi'),
                  ),
                ],
              ),
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.notifications_none,
                        color: AppColors.muted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tiada notifikasi buat masa ini.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              );
            }

            return RefreshIndicator.adaptive(
              onRefresh: () => ref.refresh(notificationsProvider.future),
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final n = items[i];
                  return ListTile(
                    leading: Icon(
                      n.isLike ? Icons.favorite : Icons.mode_comment_outlined,
                      color: n.isLike
                          ? AppColors.error
                          : Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      n.isLike
                          ? 'Seseorang menyukai post anda'
                          : 'Seseorang comment pada post anda',
                      style: TextStyle(
                        fontWeight: n.read
                            ? FontWeight.normal
                            : FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(relativeTime(n.createdAt)),
                    trailing: n.read
                        ? null
                        : Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                    onTap: () {
                      if (!n.read) {
                        ref.read(notificationRepositoryProvider).markRead(n.id);
                      }
                      context.push('/posts/${n.postId}');
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
