import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marc/features/posts/post_models.dart';
import 'package:marc/features/posts/post_providers.dart';
import 'package:marc/features/posts/widgets/comment_tile.dart';
import 'package:marc/features/posts/widgets/post_card.dart';
import 'package:marc/shared/widgets/confirm_dialog.dart';
import 'package:marc/shared/widgets/my_snackbar.dart';

class PostDetailPage extends ConsumerStatefulWidget {
  const PostDetailPage({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends ConsumerState<PostDetailPage> {
  final _commentController = TextEditingController();
  Comment? _replyingTo;
  bool _sending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _sending = true);
    try {
      await ref
          .read(postRepositoryProvider)
          .createComment(
            widget.postId,
            content,
            parentCommentId: _replyingTo?.id,
          );
      _commentController.clear();
      setState(() => _replyingTo = null);
    } catch (_) {
      if (mounted) MySnackBar.error(context, 'Gagal hantar comment.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final postAsync = ref.watch(postDetailProvider(widget.postId));
    final commentsAsync = ref.watch(commentsProvider(widget.postId));

    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: postAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator.adaptive()),
                error: (e, _) =>
                    const Center(child: Text('Gagal memuat post.')),
                data: (post) {
                  return ListView(
                    children: [
                      PostCard(
                        post: post,
                        onTap: () {},
                        onToggleLike: () async {
                          try {
                            await ref
                                .read(postRepositoryProvider)
                                .togglePostLike(post.id, post.likedByMe);
                          } catch (_) {
                            if (context.mounted) {
                              MySnackBar.error(context, 'Gagal like post.');
                            }
                          }
                        },
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
                            if (context.mounted) context.pop();
                          } catch (_) {
                            if (context.mounted) {
                              MySnackBar.error(context, 'Gagal padam post.');
                            }
                          }
                        },
                      ),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      commentsAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: CircularProgressIndicator.adaptive(),
                          ),
                        ),
                        error: (e, _) => const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Gagal memuat comment.'),
                        ),
                        data: (comments) {
                          if (comments.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: Text('Belum ada comment.')),
                            );
                          }
                          final topLevel = comments
                              .where((c) => c.isTopLevel)
                              .toList();
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: [
                                for (final c in topLevel)
                                  CommentThread(
                                    postId: widget.postId,
                                    comment: c,
                                    replies: comments
                                        .where((r) => r.parentCommentId == c.id)
                                        .toList(),
                                    onReply: (parent) {
                                      setState(() => _replyingTo = parent);
                                    },
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_replyingTo != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Text(
                              'Membalas ${_replyingTo!.author.label}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const Spacer(),
                            InkWell(
                              onTap: () => setState(() => _replyingTo = null),
                              child: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            decoration: const InputDecoration(
                              hintText: 'Tulis comment...',
                            ),
                            minLines: 1,
                            maxLines: 4,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _sending ? null : _sendComment,
                          icon: _sending
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator.adaptive(),
                                )
                              : const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
