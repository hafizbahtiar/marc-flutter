import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/features/posts/post_models.dart';
import 'package:marc/features/posts/widgets/content_action_sheet.dart';
import 'package:marc/features/posts/widgets/post_image_grid.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/relative_time.dart';
import 'package:marc/shared/widgets/edited_badge.dart';
import 'package:marc/shared/widgets/image_viewer_page.dart';
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
                  // Tag disatukan dengan ID post (bukan URL avatar semata)
                  // - penulis sama boleh ada beberapa post kelihatan
                  // serentak dalam feed, jadi URL semata-mata berlanggar.
                  heroTag: 'avatar-post-${post.id}',
                  onTap: post.author.avatarUrl == null
                      ? null
                      : () => ImageViewerPage.open(
                          context,
                          urls: [post.author.avatarUrl!],
                          initialIndex: 0,
                          heroTagBuilder: (_, _) => 'avatar-post-${post.id}',
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
                          margin: const EdgeInsets.only(top: 3),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'PENGUMUMAN',
                            style: TextStyle(
                              color: scheme.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Dulu PopupMenuButton (menu kecil melekat di sudut kanan
                // atas). Sekarang sheet yang sama dengan comment - sasaran
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
                height: 1.35,
              ),
            ),
            if (post.images.isNotEmpty) ...[
              const SizedBox(height: 10),
              PostImageGrid(urls: post.images),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                _ActionButton(
                  icon: post.likedByMe ? Icons.favorite : Icons.favorite_border,
                  color: post.likedByMe
                      ? scheme.error
                      : scheme.onSurfaceVariant,
                  active: post.likedByMe,
                  bounceOnActive: true,
                  count: post.likeCount,
                  onTap: onToggleLike,
                ),
                const SizedBox(width: 4),
                _ActionButton(
                  icon: Icons.mode_comment_outlined,
                  color: scheme.onSurfaceVariant,
                  count: post.commentCount,
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

/// Butang aksi gaya Twitter - ikon dalam bulatan sentuh dengan tint
/// separa-lut bila `active` (cth. post yang dah di-like), dan splash tint
/// warna sama bila ditekan. Kiraan disembunyikan bila 0 (padanan gaya
/// Twitter yang tak papar "0"). [bounceOnActive] tambah "pop" gaya
/// Threads/Twitter pada ikon like: skala melantun sekali bila `active`
/// bertukar false → true (bukan pada setiap rebuild).
class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.count,
    required this.onTap,
    this.active = false,
    this.bounceOnActive = false,
  });

  final IconData icon;
  final Color color;
  final int count;
  final bool active;
  final bool bounceOnActive;
  final VoidCallback onTap;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
    with SingleTickerProviderStateMixin {
  // NULLABLE + dicipta dalam initState() (bukan `late final` malas) -
  // punca ralat "Looking up a deactivated widget's ancestor is unsafe"
  // yang dilaporkan: `late final` baca kali PERTAMA pada butang comment
  // (`bounceOnActive: false`, cabang `build()` tak pernah sentuh
  // `_scale`/`_controller`) berlaku dalam `dispose()` sendiri - bina
  // `AnimationController(vsync: this,...)` BAHARU semasa widget tengah
  // di-unmount, dan carian ancestor `TickerMode` di dalamnya gagal sebab
  // context dah tak aktif. Bina awal (initState, semasa masih mounted)
  // untuk butang yang betul-betul perlukannya sahaja mengelak isu ni.
  AnimationController? _controller;
  Animation<double>? _scale;

  @override
  void initState() {
    super.initState();
    if (widget.bounceOnActive) {
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 220),
      );
      _controller = controller;
      _scale = TweenSequence<double>([
        TweenSequenceItem(
          weight: 50,
          tween: Tween(
            begin: 1.0,
            end: 1.35,
          ).chain(CurveTween(curve: Curves.easeOut)),
        ),
        TweenSequenceItem(
          weight: 50,
          tween: Tween(
            begin: 1.35,
            end: 1.0,
          ).chain(CurveTween(curve: Curves.easeIn)),
        ),
      ]).animate(controller);
    }
  }

  @override
  void didUpdateWidget(_ActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bounceOnActive && !oldWidget.active && widget.active) {
      _controller?.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(widget.icon, color: widget.color, size: 18);
    final scale = _scale;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      splashColor: Colors.transparent,
      highlightColor: widget.color.withValues(alpha: 0.08),
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              child: scale != null
                  ? ScaleTransition(scale: scale, child: icon)
                  : icon,
            ),
            if (widget.count > 0)
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text(
                  widget.count.toString(),
                  style: TextStyle(
                    color: widget.color,
                    fontSize: 13,
                    fontWeight: widget.active
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
