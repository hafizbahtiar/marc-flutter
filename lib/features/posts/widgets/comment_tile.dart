import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marc/core/error_utils.dart';
import 'package:marc/features/posts/post_models.dart';
import 'package:marc/features/posts/post_providers.dart';
import 'package:marc/features/posts/widgets/content_action_sheet.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/utils/relative_time.dart';
import 'package:marc/shared/ui/dialog/confirm_dialog.dart';
import 'package:marc/shared/ui/dialog/edit_text_dialog.dart';
import 'package:marc/shared/ui/widgets/edited_badge.dart';
import 'package:marc/shared/ui/media/image_viewer_page.dart';
import 'package:marc/shared/ui/widgets/my_snackbar.dart';
import 'package:marc/shared/ui/widgets/member_avatar.dart';

/// Satu comment top-level + reply-reply di bawahnya (indent sekali sahaja
/// - backend dah cap depth 2, jadi `replies` sentiasa leaf, tak recurse).
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
            // dgn indent asal - reply avatar kekal posisi sama, cuma
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

  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    final myProfile = ref.read(myProfileProvider).valueOrNull;
    final isOwner =
        myProfile?.memberId != null &&
        myProfile!.memberId == comment.author.memberId;

    final action = await showContentActionSheet(
      context,
      title: 'Comment ${comment.author.label}',
      canEdit: isOwner,
      canDelete: isOwner || (myProfile?.isManagement ?? false),
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case ContentAction.edit:
        await _edit(context, ref);
      case ContentAction.delete:
        await _delete(context, ref);
    }
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
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
          e is DioException ? extractErrorMessage(e) : 'Gagal edit comment.',
        );
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Padam comment',
      message: 'Anda pasti mahu padam comment ini?',
      confirmLabel: 'Padam',
      isDestructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(postRepositoryProvider).deleteComment(postId, comment.id);
    } catch (_) {
      if (context.mounted) {
        MySnackBar.error(context, 'Gagal padam comment.');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final myProfile = ref.watch(myProfileProvider).valueOrNull;
    final isOwner =
        myProfile?.memberId != null &&
        myProfile!.memberId == comment.author.memberId;
    final canDelete = isOwner || (myProfile?.isManagement ?? false);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MemberAvatar(
            label: comment.author.label,
            avatarUrl: comment.author.avatarUrl,
            radius: 14,
            heroTag: 'avatar-comment-${comment.id}',
            onTap: comment.author.avatarUrl == null
                ? null
                : () => ImageViewerPage.open(
                    context,
                    urls: [comment.author.avatarUrl!],
                    initialIndex: 0,
                    heroTagBuilder: (_, _) => 'avatar-comment-${comment.id}',
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
                      // Nama sahaja yang buka profil - avatar di atas
                      // kekal buka gambar penuh (dua destinasi berbeza).
                      child: GestureDetector(
                        onTap: () =>
                            context.push('/members/${comment.author.userId}'),
                        child: Text(
                          comment.author.label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
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
                      const SizedBox(width: 6),
                      const EditedBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(comment.content, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      splashColor: scheme.error.withValues(alpha: 0.15),
                      highlightColor: scheme.error.withValues(alpha: 0.08),
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
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: comment.likedByMe
                                    ? scheme.error.withValues(alpha: 0.12)
                                    : null,
                              ),
                              child: Icon(
                                comment.likedByMe
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 14,
                                color: comment.likedByMe
                                    ? scheme.error
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                            if (comment.likeCount > 0)
                              Padding(
                                padding: const EdgeInsets.only(left: 2),
                                child: Text(
                                  comment.likeCount.toString(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: comment.likedByMe
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: comment.likedByMe
                                        ? scheme.error
                                        : scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
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
                    // Edit/Padam dulu dua butang teks berasingan dalam
                    // baris ni - padat, senang tersalah tekan, dan
                    // 'Padam' merah sentiasa terpampang. Sekarang satu
                    // titik masuk yang buka sheet tindakan.
                    if (isOwner || canDelete) ...[
                      const SizedBox(width: 12),
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _showActions(context, ref),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Icon(
                            Icons.more_horiz,
                            size: 16,
                            color: scheme.onSurfaceVariant,
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
