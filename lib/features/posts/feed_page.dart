import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/features/posts/post_providers.dart';
import 'package:marc/features/posts/widgets/post_card.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/widgets/confirm_dialog.dart';
import 'package:marc/shared/widgets/my_snackbar.dart';

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> {
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
      ref.read(feedProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Stage 11: user pending/rejected tak boleh akses Feed (backend 403
    // semua endpoint selain /me). Gate content-level di sini (bukan
    // router redirect) sebab myProfileProvider async — lihat design spec
    // untuk rasional penuh. Fail-open kalau /me gagal fetch (error state)
    // — jangan block user approved sebab isu rangkaian sekejap.
    final profileStatus = ref.watch(
      myProfileProvider.select((p) => p.valueOrNull?.status),
    );
    if (profileStatus != null && profileStatus != 'approved') {
      return _PendingStatusView(
        status: profileStatus,
        onRefresh: () => ref.refresh(myProfileProvider.future),
      );
    }

    final feed = ref.watch(feedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MARC'),
        actions: [
          IconButton(
            icon: const Icon(Icons.groups_outlined),
            tooltip: 'Ahli',
            onPressed: () => context.push('/members'),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notifikasi',
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/posts/new'),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: feed.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Gagal memuat feed.', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => ref.read(feedProvider.notifier).refresh(),
                    child: const Text('Cuba lagi'),
                  ),
                ],
              ),
            ),
          ),
          data: (state) {
            if (state.posts.isEmpty) {
              return RefreshIndicator.adaptive(
                onRefresh: () => ref.read(feedProvider.notifier).refresh(),
                child: ListView(
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 100),
                      child: Center(
                        child: Text('Tiada post lagi. Jadi yang pertama!'),
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator.adaptive(
              onRefresh: () => ref.read(feedProvider.notifier).refresh(),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: state.posts.length + (state.hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= state.posts.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: CircularProgressIndicator.adaptive(),
                      ),
                    );
                  }

                  final post = state.posts[index];
                  return PostCard(
                    post: post,
                    onTap: () => context.push('/posts/${post.id}'),
                    onToggleLike: () =>
                        ref.read(feedProvider.notifier).toggleLike(post),
                    onEdit: () => context.push('/posts/${post.id}'),
                    onDelete: () async {
                      final ok = await showConfirmDialog(
                        context,
                        title: 'Padam post',
                        message: 'Anda pasti mahu padam post ini?',
                        confirmLabel: 'Padam',
                        isDestructive: true,
                      );
                      if (!ok) return;
                      try {
                        await ref
                            .read(postRepositoryProvider)
                            .deletePost(post.id);
                        ref.read(feedProvider.notifier).removePost(post.id);
                      } catch (_) {
                        if (context.mounted) {
                          MySnackBar.error(context, 'Gagal padam post.');
                        }
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

class _PendingStatusView extends StatelessWidget {
  const _PendingStatusView({required this.status, required this.onRefresh});

  final String status;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final isRejected = status == 'rejected';
    return Scaffold(
      appBar: AppBar(title: const Text('MARC')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isRejected ? Icons.error_outline : Icons.hourglass_empty,
                  size: 48,
                  color: isRejected ? AppColors.error : AppColors.warning,
                ),
                const SizedBox(height: 16),
                Text(
                  isRejected
                      ? 'Pendaftaran anda tidak diluluskan. Sila hubungi pihak pengurusan MAIWP.'
                      : 'Pendaftaran anda sedang disemak oleh pihak pengurusan MAIWP.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: onRefresh,
                  child: const Text('Semak semula'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
