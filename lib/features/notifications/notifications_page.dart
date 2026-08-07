import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/features/notifications/notifications_providers.dart';
import 'package:marc/features/posts/post_models.dart';
import 'package:marc/shared/relative_time.dart';
import 'package:marc/shared/widgets/my_snackbar.dart';

IconData _iconFor(AppNotification n) {
  if (n.isLike) return Icons.favorite;
  if (n.isComment) return Icons.mode_comment_outlined;
  if (n.isMemberPending) return Icons.person_add_alt_outlined;
  if (n.isMemberApproved) return Icons.check_circle_outline;
  return Icons.cancel_outlined; // isMemberRejected
}

Color _colorFor(BuildContext context, AppNotification n) {
  if (n.isLike || n.isMemberRejected) return AppColors.error;
  if (n.isMemberApproved) return AppColors.accent;
  return Theme.of(context).colorScheme.primary; // comment, member_pending
}

String _titleFor(AppNotification n) {
  if (n.isLike) return 'Seseorang menyukai post anda';
  if (n.isComment) return 'Seseorang comment pada post anda';
  if (n.isMemberPending) return 'Ahli baru menunggu kelulusan anda';
  if (n.isMemberApproved) return 'Pendaftaran anda telah diluluskan.';
  return 'Pendaftaran anda tidak diluluskan.'; // isMemberRejected
}

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
            onPressed: () async {
              try {
                await ref.read(notificationRepositoryProvider).markAllRead();
              } catch (_) {
                if (context.mounted) {
                  MySnackBar.error(context, 'Gagal tanda semua dibaca.');
                }
              }
            },
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
                    leading: Icon(_iconFor(n), color: _colorFor(context, n)),
                    title: Text(
                      _titleFor(n),
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
                    onTap: () async {
                      if (!n.read) {
                        try {
                          await ref
                              .read(notificationRepositoryProvider)
                              .markRead(n.id);
                        } catch (_) {
                          if (context.mounted) {
                            MySnackBar.error(context, 'Gagal tanda dibaca.');
                          }
                        }
                      }
                      if (n.postId != null && context.mounted) {
                        context.push('/posts/${n.postId}');
                      }
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
