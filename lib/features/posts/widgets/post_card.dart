import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/features/posts/post_models.dart';
import 'package:marc/features/posts/widgets/content_action_sheet.dart';
import 'package:marc/features/posts/widgets/post_image_grid.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/relative_time.dart';
import 'package:marc/shared/widgets/edited_badge.dart';
import 'package:marc/shared/widgets/member_avatar.dart';

class PostCard extends ConsumerWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.onTap,
    required this.onToggleLike,
    this.onEdit,
    this.onDelete,
  });

  final Post post;
  final VoidCallback onTap;
  final VoidCallback onToggleLike;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final myProfile = ref.watch(myProfileProvider).valueOrNull;
    final isOwner = myProfile?.memberId == post.author.memberId;
    final isManagement = myProfile?.isManagement ?? false;
    final canDelete = isOwner || isManagement;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
          color: post.isAnnouncement
              ? scheme.primary.withValues(alpha: 0.05)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                MemberAvatar(
                  label: post.author.label,
                  avatarUrl: post.author.avatarUrl,
                  radius: 18,
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
                              post.author.label,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '· ${relativeTime(post.createdAt)}',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(fontSize: 13),
                          ),
                          if (post.isEdited) ...[
                            const SizedBox(width: 6),
                            const EditedBadge(),
                          ],
                        ],
                      ),
                      if (post.isAnnouncement)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'PENGUMUMAN',
                            style: TextStyle(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Dulu PopupMenuButton (menu kecil melekat di sudut kanan
                // atas). Sekarang sheet yang sama dengan comment — sasaran
                // sentuh lebih besar dan dua-dua tempat berkelakuan sama.
                if (canDelete)
                  IconButton(
                    icon: const Icon(Icons.more_vert, size: 20),
                    tooltip: 'Tindakan',
                    onPressed: () async {
                      final action = await showContentActionSheet(
                        context,
                        title: post.isAnnouncement ? 'Pengumuman' : 'Post',
                        canEdit: isOwner,
                        canDelete: canDelete,
                      );
                      switch (action) {
                        case ContentAction.edit:
                          onEdit?.call();
                        case ContentAction.delete:
                          onDelete?.call();
                        case null:
                          break;
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              post.content,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface,
                fontSize: 15,
              ),
            ),
            if (post.images.isNotEmpty) ...[
              const SizedBox(height: 10),
              PostImageGrid(urls: post.images),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                _ActionButton(
                  icon: post.likedByMe ? Icons.favorite : Icons.favorite_border,
                  color: post.likedByMe
                      ? scheme.error
                      : scheme.onSurfaceVariant,
                  label: post.likeCount.toString(),
                  onTap: onToggleLike,
                ),
                const SizedBox(width: 20),
                _ActionButton(
                  icon: Icons.mode_comment_outlined,
                  color: scheme.onSurfaceVariant,
                  label: post.commentCount.toString(),
                  onTap: onTap,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(color: color, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
