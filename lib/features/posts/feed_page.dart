import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/core/error_utils.dart';
import 'package:marc/features/posts/post_providers.dart';
import 'package:marc/features/posts/widgets/post_card.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/widgets/confirm_dialog.dart';
import 'package:marc/shared/widgets/edit_text_dialog.dart';
import 'package:marc/shared/widgets/my_snackbar.dart';
import 'package:marc/shared/widgets/pending_status_view.dart';

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> {
  final _scrollController = ScrollController();

  /// Tag Hero FAB - Object UNIK PER STATE (bukan String tetap). String
  /// tetap ('feed-fab') cukup untuk elak clash DENGAN FAB skrin lain,
  /// tapi tak elak clash dengan DIRINYA SENDIRI kalau `FeedPage` sempat
  /// termount dua kali serentak (cth semasa transisi push/pop go_router
  /// yang tindih dengan StatefulShellRoute.indexedStack) - dilihat
  /// (2026-08-25) sebagai "multiple heroes share the same tag: feed-fab"
  /// bila buka /edit-profile. Object() per State jamin setiap instance
  /// FeedPage, walau berapa banyak sekalipun wujud serentak, ada tag
  /// tersendiri.
  final _fabHeroTag = UniqueKey();

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
    // router redirect) sebab myProfileProvider async - lihat design spec
    // untuk rasional penuh. Fail-open kalau /me gagal fetch (error state)
    // - jangan block user approved sebab isu rangkaian sekejap.
    //
    // Backend (marc_go router.go) chains RequireApprovedStatus THEN
    // RequireVerifiedEmail on every Posts/comments/uploads/notifications
    // route - jadi client kena semak KEDUA-DUA status DAN emailVerified,
    // bukan status sahaja, atau ahli approved-tapi-belum-sahkan-email
    // terperangkap pada 403 generic tanpa jalan keluar.
    //
    // Guna .select dengan record supaya widget ni hanya rebuild bila
    // status ATAU emailVerified berubah - bukan pada sebarang field
    // Profile lain.
    final (
      status: profileStatus,
      emailVerified: profileEmailVerified,
      registrationPaymentStatus: profileRegistrationPaymentStatus,
      registrationFeeCents: profileRegistrationFeeCents,
      isInitialLoading: profileIsInitialLoading,
    ) = ref.watch(
      myProfileProvider.select(
        (p) => (
          status: p.valueOrNull?.status,
          emailVerified: p.valueOrNull?.emailVerified,
          registrationPaymentStatus: p.valueOrNull?.registrationPaymentStatus,
          registrationFeeCents: p.valueOrNull?.registrationFeeCents,
          // Muat pertama (belum PERNAH ada nilai) - beza dgn `hasError`
          // (rangkaian gagal SELEPAS cubaan pertama), yang kekal
          // fail-open sengaja (komen di atas). Tanpa semakan ni,
          // `profileStatus` null semasa loading pertama sama macam null
          // semasa error - gate di bawah (`profileStatus != null`) gagal
          // terbuka, Feed PENUH (dgn FAB tekan-boleh) terpapar sekejap
          // sebelum status sebenar ahli diketahui. Ditemui 2026-08-24
          // (hot restart sebagai ahli pending, sempat tekan FAB).
          isInitialLoading: p.isLoading && !p.hasValue,
        ),
      ),
    );

    if (profileIsInitialLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    if (profileStatus != null && profileStatus != 'approved') {
      return PendingStatusView(
        status: profileStatus,
        registrationPaymentStatus: profileRegistrationPaymentStatus,
        registrationFeeCents: profileRegistrationFeeCents,
        onRefresh: () async {
          try {
            final refreshed = await ref.refresh(myProfileProvider.future);
            if (refreshed?.status == 'approved') {
              ref.invalidate(feedProvider);
            }
          } catch (_) {
            if (context.mounted) {
              MySnackBar.error(context, 'Gagal semak status. Cuba lagi.');
            }
          }
        },
      );
    }

    if (profileStatus == 'approved' && profileEmailVerified == false) {
      return _EmailNotVerifiedView(
        onRefresh: () async {
          try {
            final _ = await ref.refresh(myProfileProvider.future);
          } catch (_) {
            if (context.mounted) {
              MySnackBar.error(context, 'Gagal semak status. Cuba lagi.');
            }
          }
        },
      );
    }

    final feed = ref.watch(feedProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('MARC')),
      floatingActionButton: FloatingActionButton(
        // heroTag unik WAJIB: StatefulShellRoute.indexedStack kekalkan
        // semua tab yang pernah dilawati tetap mounted (simpan state),
        // jadi FAB tab ni dan FAB ActivitiesPage (dua-dua default tag
        // sebelum ni) wujud serentak dalam tree → Flutter Hero animation
        // "multiple heroes share same tag" crash bila kedua-dua tab
        // pernah dilawati dalam satu sesi. Lihat nota [_fabHeroTag].
        heroTag: _fabHeroTag,
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
                  physics: const AlwaysScrollableScrollPhysics(),
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
                physics: const AlwaysScrollableScrollPhysics(),
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
                    key: ValueKey(post.id),
                    post: post,
                    onTap: () => context.push('/posts/${post.id}'),
                    onToggleLike: () =>
                        ref.read(feedProvider.notifier).toggleLike(post),
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
                        ref.read(feedProvider.notifier).removePost(post.id);
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

/// Gate untuk ahli yang approved tapi email belum disahkan. Backend
/// (RequireVerifiedEmail) 403 semua route Posts/comments/uploads/
/// notifications untuk kes ni - beri jalan keluar terus di sini (hantar
/// semula email pengesahan, atau semak semula status) supaya user tak
/// terperangkap pada Feed yang error generic.
class _EmailNotVerifiedView extends ConsumerStatefulWidget {
  const _EmailNotVerifiedView({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  ConsumerState<_EmailNotVerifiedView> createState() =>
      _EmailNotVerifiedViewState();
}

class _EmailNotVerifiedViewState extends ConsumerState<_EmailNotVerifiedView> {
  bool _sending = false;

  Future<void> _requestVerification() async {
    setState(() => _sending = true);
    try {
      await ref.read(dioProvider).post('/auth/verify-email/request');
      if (!mounted) return;
      MySnackBar.success(
        context,
        'Email pengesahan dihantar. Sila semak inbox anda.',
      );
    } catch (e) {
      if (!mounted) return;
      MySnackBar.error(
        context,
        e is DioException
            ? extractErrorMessage(e)
            : 'Gagal hantar email pengesahan. Cuba lagi.',
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  Icons.mark_email_unread_outlined,
                  size: 48,
                  color: Theme.of(
                    context,
                  ).extension<AppSemanticColors>()!.warning,
                ),
                const SizedBox(height: 16),
                Text(
                  'Sila sahkan email anda untuk teruskan.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      onPressed: _sending ? null : _requestVerification,
                      child: _sending
                          ? const SizedBox(
                              height: 14,
                              width: 14,
                              child: CircularProgressIndicator.adaptive(),
                            )
                          : const Text('Hantar semula'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: widget.onRefresh,
                      child: const Text('Semak semula'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
