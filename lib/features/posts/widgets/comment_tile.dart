import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/core/error_utils.dart';
import 'package:marc/features/posts/post_models.dart';
import 'package:marc/features/posts/post_providers.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/relative_time.dart';
import 'package:marc/shared/widgets/confirm_dialog.dart';
import 'package:marc/shared/widgets/edit_text_dialog.dart';
import 'package:marc/shared/widgets/my_snackbar.dart';

/// Satu comment top-level + reply-reply di bawahnya (indent sekali sahaja
/// — backend dah cap depth 2, jadi `replies` sentiasa leaf, tak recurse).
class CommentThread extends StatelessWidget {
  const CommentThread({
    super.key,
    required this.postId,
    required this.comment,
    required this.replies,
    required this.onReply,
  });

  final String postId;
  final Comment comment;
  final List<Comment> replies;
  final void Function(Comment parent) onReply;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CommentRow(
          postId: postId,
          comment: comment,
          onReply: () => onReply(comment),
        ),
        if (replies.isNotEmpty)
          Padding(
            // 14 (align stem bawah tengah avatar induk, radius 14) + 2
            // (lebar stem) + 24 (jarak sebelum avatar reply) = 40, sama
            // dgn indent asal — reply avatar kekal posisi sama, cuma
            // tambah garis dalam jarak yang dah ada.
            padding: const EdgeInsets.only(left: 14),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 2,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      children: [
                        for (final reply in replies)
                          _CommentRow(
                            postId: postId,
                            comment: reply,
                            onReply: () => onReply(
                              comment,
                            ), // reply kat reply -> attach kat root jua (flatten)
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _CommentRow extends ConsumerWidget {
  const _CommentRow({
    required this.postId,
    required this.comment,
    required this.onReply,
  });

  final String postId;
  final Comment comment;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final myProfile = ref.watch(myProfileProvider).valueOrNull;
    final isOwner = myProfile?.memberId == comment.author.memberId;
    final canDelete = isOwner || (myProfile?.isManagement ?? false);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: scheme.primary.withValues(alpha: 0.12),
            child: Text(
              comment.author.label.isNotEmpty
                  ? comment.author.label[0].toUpperCase()
                  : '?',
              style: TextStyle(
                color: scheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        comment.author.label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      relativeTime(comment.createdAt),
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    if (comment.isEdited) ...[
                      const SizedBox(width: 4),
                      Text(
                        '· disunting',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(comment.content, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    InkWell(
                      onTap: () async {
                        try {
                          await ref
                              .read(postRepositoryProvider)
                              .toggleCommentLike(
                                postId,
                                comment.id,
                                comment.likedByMe,
                              );
                        } catch (_) {
                          if (context.mounted) {
                            MySnackBar.error(context, 'Gagal like comment.');
                          }
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            comment.likedByMe
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 15,
                            color: comment.likedByMe
                                ? scheme.error
                                : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            comment.likeCount.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: comment.likedByMe
                                  ? scheme.error
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    InkWell(
                      onTap: onReply,
                      child: Text(
                        'Balas',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isOwner) ...[
                      const SizedBox(width: 16),
                      InkWell(
                        onTap: () async {
                          final newContent = await showEditTextDialog(
                            context,
                            title: 'Edit comment',
                            initialValue: comment.content,
                            maxLines: 3,
                          );
                          if (newContent == null) return;
                          try {
                            await ref
                                .read(postRepositoryProvider)
                                .editComment(postId, comment.id, newContent);
                          } catch (e) {
                            if (context.mounted) {
                              MySnackBar.error(
                                context,
                                e is DioException
                                    ? extractErrorMessage(e)
                                    : 'Gagal edit comment.',
                              );
                            }
                          }
                        },
                        child: Text(
                          'Edit',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    if (canDelete) ...[
                      const SizedBox(width: 16),
                      InkWell(
                        onTap: () async {
                          final ok = await showConfirmDialog(
                            context,
                            title: 'Padam comment',
                            message: 'Anda pasti mahu padam comment ini?',
                            confirmLabel: 'Padam',
                            isDestructive: true,
                          );
                          if (ok) {
                            try {
                              await ref
                                  .read(postRepositoryProvider)
                                  .deleteComment(postId, comment.id);
                            } catch (_) {
                              if (context.mounted) {
                                MySnackBar.error(
                                  context,
                                  'Gagal padam comment.',
                                );
                              }
                            }
                          }
                        },
                        child: Text(
                          'Padam',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
