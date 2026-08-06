import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marc/features/posts/post_providers.dart';
import 'package:marc/features/posts/widgets/post_card.dart';
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
