import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  final scheme = Theme.of(context).colorScheme;
  if (n.isLike || n.isMemberRejected) return scheme.error;
  return scheme.primary; // comment, member_pending, member_approved
}

String _titleFor(AppNotification n) {
  if (n.isLike) return 'Seseorang menyukai post anda';
  if (n.isComment) return 'Seseorang comment pada post anda';
  if (n.isMemberPending) return 'Ahli baru menunggu kelulusan anda';
  if (n.isMemberApproved) return 'Pendaftaran anda telah diluluskan.';
  return 'Pendaftaran anda tidak diluluskan.'; // isMemberRejected
}

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(notificationsProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
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
          data: (state) {
            if (state.items.isEmpty) {
              return RefreshIndicator.adaptive(
                onRefresh: () =>
                    ref.read(notificationsProvider.notifier).refresh(),
                child: ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 72),
                          Icon(
                            Icons.notifications_none,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tiada notifikasi buat masa ini.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator.adaptive(
              onRefresh: () =>
                  ref.read(notificationsProvider.notifier).refresh(),
              child: ListView.separated(
                controller: _scrollController,
                itemCount: state.items.length + (state.hasMore ? 1 : 0),
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  if (i >= state.items.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: CircularProgressIndicator.adaptive(),
                      ),
                    );
                  }

                  final n = state.items[i];
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
