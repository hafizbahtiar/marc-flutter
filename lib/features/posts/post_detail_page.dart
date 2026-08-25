import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marc/core/error_utils.dart';
import 'package:marc/features/posts/post_models.dart';
import 'package:marc/features/posts/post_providers.dart';
import 'package:marc/features/posts/widgets/comment_tile.dart';
import 'package:marc/features/posts/widgets/post_card.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/local_drafts_repository.dart';
import 'package:marc/shared/widgets/app_action_sheet.dart';
import 'package:marc/shared/widgets/confirm_dialog.dart';
import 'package:marc/shared/widgets/edit_text_dialog.dart';
import 'package:marc/shared/widgets/member_avatar.dart';
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
  void initState() {
    super.initState();
    _restoreDraft();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String get _draftKey => 'reply:${widget.postId}:${_replyingTo?.id ?? "root"}';

  bool get _hasUnsavedComment => _commentController.text.trim().isNotEmpty;

  Future<void> _handlePopAttempt(bool didPop, Object? result) async {
    if (didPop) return;
    final choice = await _confirmExitWithDraft(context);
    if (choice == null || !mounted) return;

    final repo = ref.read(draftRepositoryProvider);
    try {
      if (choice == _ExitDraftChoice.save) {
        await repo.save(
          _draftKey,
          kind: 'comment',
          content: _commentController.text.trim(),
        );
      } else {
        await repo.delete(_draftKey);
      }
    } catch (_) {
      // Draf ialah kemudahan best-effort - kegagalan storan tempatan
      // TIDAK sepatutnya memerangkap pengguna pada skrin ini.
      if (mounted) MySnackBar.error(context, 'Gagal simpan draf.');
    }
    if (mounted) Navigator.of(context).pop();
  }

  /// Cuba pulihkan draf bagi `_draftKey` SEMASA secara senyap.
  ///
  /// Dipanggil dari initState (target = root) dan setiap kali
  /// `_replyingTo` bertukar (onReply / butang tutup) - kunci draf
  /// bergantung pada target balasan, jadi bertukar target bermakna
  /// bertukar draf yang patut dipulihkan. Dikawal supaya TAK PERNAH
  /// menimpa teks yang belum dihantar sedang ditaip pengguna - hanya isi
  /// medan yang kosong.
  Future<void> _restoreDraft() async {
    final draft = await ref.read(draftRepositoryProvider).get(_draftKey);
    if (draft == null || !mounted) return;
    if (_commentController.text.trim().isNotEmpty) return;
    if (mounted) setState(() => _commentController.text = draft.content);
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
      await ref.read(draftRepositoryProvider).delete(_draftKey);
      setState(() => _replyingTo = null);
    } catch (e) {
      if (mounted) {
        MySnackBar.error(
          context,
          e is DioException ? extractErrorMessage(e) : 'Gagal hantar comment.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final postAsync = ref.watch(postDetailProvider(widget.postId));
    final commentsAsync = ref.watch(commentsProvider(widget.postId));
    final myProfile = ref.watch(myProfileProvider).valueOrNull;
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_hasUnsavedComment,
      onPopInvokedWithResult: _handlePopAttempt,
      child: Scaffold(
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
                            } catch (e) {
                              if (context.mounted) {
                                MySnackBar.error(
                                  context,
                                  e is DioException
                                      ? extractErrorMessage(e)
                                      : 'Gagal like post.',
                                );
                              }
                            }
                          },
                          onEdit: () async {
                            final newContent = await showEditTextDialog(
                              context,
                              title: 'Edit post',
                              initialValue: post.content,
                            );
                            if (newContent == null) return;
                            try {
                              await ref
                                  .read(postRepositoryProvider)
                                  .editPost(post.id, newContent);
                            } catch (e) {
                              if (context.mounted) {
                                MySnackBar.error(
                                  context,
                                  e is DioException
                                      ? extractErrorMessage(e)
                                      : 'Gagal edit post.',
                                );
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
                            } catch (e) {
                              if (context.mounted) {
                                MySnackBar.error(
                                  context,
                                  e is DioException
                                      ? extractErrorMessage(e)
                                      : 'Gagal padam post.',
                                );
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
                                child: Center(
                                  child: Text('Belum ada comment.'),
                                ),
                              );
                            }
                            final topLevel = comments
                                .where((c) => c.isTopLevel)
                                .toList();
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Column(
                                children: [
                                  for (final c in topLevel)
                                    CommentThread(
                                      postId: widget.postId,
                                      comment: c,
                                      replies: comments
                                          .where(
                                            (r) => r.parentCommentId == c.id,
                                          )
                                          .toList(),
                                      onReply: (parent) {
                                        setState(() => _replyingTo = parent);
                                        _restoreDraft();
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
                                onTap: () {
                                  setState(() => _replyingTo = null);
                                  _restoreDraft();
                                },
                                child: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          MemberAvatar(
                            label:
                                myProfile?.displayName ??
                                myProfile?.email ??
                                '',
                            avatarUrl: myProfile?.avatarUrl,
                            radius: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              // PopScope.canPop bergantung pada
                              // _hasUnsavedComment, yang baca terus dari
                              // controller - tanpa rebuild ni, canPop
                              // kekal nilai lama binaan sebelumnya.
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: 'Tulis comment...',
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide(
                                    color: scheme.primary,
                                    width: 1.6,
                                  ),
                                ),
                              ),
                              minLines: 1,
                              maxLines: 4,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: IconButton.filled(
                              style: IconButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: const CircleBorder(),
                              ),
                              onPressed: _sending ? null : _sendComment,
                              icon: _sending
                                  ? SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator.adaptive(
                                        valueColor: AlwaysStoppedAnimation(
                                          scheme.onPrimary,
                                        ),
                                      ),
                                    )
                                  : const Icon(Icons.send, size: 18),
                            ),
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
      ),
    );
  }
}

enum _ExitDraftChoice { save, discard }

/// "Batal" ialah cancelLabel lalai [showAppActionSheet] - leret
/// bawah/ketik luar sheet pun sama makna dengan Batal (pulang null).
Future<_ExitDraftChoice?> _confirmExitWithDraft(BuildContext context) {
  return showAppActionSheet<_ExitDraftChoice>(
    context,
    title: 'Simpan sebagai draf?',
    message: 'Anda ada comment belum dihantar.',
    actions: const [
      AppSheetAction(
        value: _ExitDraftChoice.save,
        label: 'Simpan draf',
        icon: Icons.bookmark_add_outlined,
      ),
      AppSheetAction(
        value: _ExitDraftChoice.discard,
        label: 'Buang',
        icon: Icons.delete_outline,
        isDestructive: true,
      ),
    ],
  );
}
