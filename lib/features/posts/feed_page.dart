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
import 'package:marc/features/registration_payment/registration_payment_providers.dart';
import 'package:marc/shared/phone.dart';
import 'package:marc/shared/validators.dart';
import 'package:marc/shared/widgets/confirm_dialog.dart';
import 'package:marc/shared/widgets/edit_text_dialog.dart';
import 'package:marc/shared/widgets/my_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';

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
    //
    // Backend (marc_go router.go) chains RequireApprovedStatus THEN
    // RequireVerifiedEmail on every Posts/comments/uploads/notifications
    // route — jadi client kena semak KEDUA-DUA status DAN emailVerified,
    // bukan status sahaja, atau ahli approved-tapi-belum-sahkan-email
    // terperangkap pada 403 generic tanpa jalan keluar.
    //
    // Guna .select dengan record supaya widget ni hanya rebuild bila
    // status ATAU emailVerified berubah — bukan pada sebarang field
    // Profile lain.
    final (
      status: profileStatus,
      emailVerified: profileEmailVerified,
      registrationPaymentStatus: profileRegistrationPaymentStatus,
    ) = ref.watch(
      myProfileProvider.select(
        (p) => (
          status: p.valueOrNull?.status,
          emailVerified: p.valueOrNull?.emailVerified,
          registrationPaymentStatus: p.valueOrNull?.registrationPaymentStatus,
        ),
      ),
    );

    if (profileStatus != null && profileStatus != 'approved') {
      return _PendingStatusView(
        status: profileStatus,
        registrationPaymentStatus: profileRegistrationPaymentStatus,
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
        // pernah dilawati dalam satu sesi.
        heroTag: 'feed-fab',
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

class _PendingStatusView extends ConsumerStatefulWidget {
  const _PendingStatusView({
    required this.status,
    required this.onRefresh,
    this.registrationPaymentStatus,
  });

  final String status;
  final Future<void> Function() onRefresh;

  /// "pending"/"succeeded"/"failed", atau null kalau tak pernah cuba
  /// bayar — lihat `Profile.registrationPaymentStatus`.
  final String? registrationPaymentStatus;

  @override
  ConsumerState<_PendingStatusView> createState() => _PendingStatusViewState();
}

class _PendingStatusViewState extends ConsumerState<_PendingStatusView> {
  bool _submitting = false;

  /// Papar dialog minta nombor telefon (ahli `pending` yang daftar
  /// SEBELUM phone jadi wajib — lihat [PhoneRequiredException]). Pulang
  /// nombor TERNORMAL (padanan `register_page.dart`) atau `null` kalau
  /// dibatal/tak sah — caller MESTI berhenti (bukan cuba checkout lagi)
  /// bila `null`.
  Future<String?> _promptPhone() async {
    final raw = await showEditTextDialog(
      context,
      title: 'Nombor Telefon',
      initialValue: '',
      maxLines: 1,
    );
    if (raw == null) return null; // dibatal
    final error = validatePhone(raw);
    if (error != null) {
      if (!mounted) return null;
      MySnackBar.error(context, error);
      return null;
    }
    return normalizeMY(raw);
  }

  Future<void> _payRegistrationFee() async {
    setState(() => _submitting = true);
    try {
      String url;
      try {
        url = await ref.read(registrationPaymentRepositoryProvider).checkout();
      } on PhoneRequiredException {
        if (!mounted) return;
        final phone = await _promptPhone();
        if (phone == null) return;
        if (!mounted) return;
        url = await ref
            .read(registrationPaymentRepositoryProvider)
            .checkout(phone: phone);
      }

      // Padanan corak `RedirectCheckoutHandler.handle()`
      // (`lib/features/donation/donation_gateway.dart`): `Uri.tryParse`
      // (bukan `Uri.parse`, elak `FormatException` tak ditangkap), skim
      // dihadkan `https` sahaja, `launchUrl` external + semak nilai bool.
      final uri = Uri.tryParse(url);
      if (uri == null || uri.scheme != 'https') {
        if (!mounted) return;
        MySnackBar.error(context, 'Pautan pembayaran tidak sah.');
        return;
      }
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        if (!mounted) return;
        MySnackBar.error(context, 'Gagal buka laman pembayaran.');
        return;
      }

      if (!mounted) return;
      MySnackBar.success(
        context,
        'Selesaikan pembayaran dalam pelayar, kemudian tekan "Semak semula" di sini.',
      );
    } catch (e) {
      if (!mounted) return;
      MySnackBar.error(
        context,
        e is DioException
            ? extractErrorMessage(e)
            : 'Gagal proses pembayaran. Cuba lagi.',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRejected = widget.status == 'rejected';
    // Eksplisit 'pending' (bukan `!isRejected`) untuk butang bayar — kalau
    // status baharu ditambah kelak (bukan pending/rejected/approved), ia
    // jatuh ke cabang "sedang disemak" (isRejected=false) tapi TAK patut
    // automatik nampak butang bayar tanpa disemak dulu sama ada ia
    // relevan (Opus verify 2026-08-15).
    final isPending = widget.status == 'pending';
    final theme = Theme.of(context);
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
                  color: isRejected
                      ? theme.colorScheme.error
                      : theme.extension<AppSemanticColors>()!.warning,
                ),
                const SizedBox(height: 16),
                Text(
                  isRejected
                      ? 'Pendaftaran anda tidak diluluskan. Sila hubungi pihak pengurusan MARC.'
                      : 'Pendaftaran anda sedang disemak oleh pihak pengurusan MARC.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (isPending && widget.registrationPaymentStatus != null) ...[
                  const SizedBox(height: 12),
                  _PaymentStatusChip(status: widget.registrationPaymentStatus!),
                ],
                const SizedBox(height: 20),
                // Butang bayar disembunyikan bila SUDAH succeeded — tiada
                // sebab bayar lagi, tinggal tunggu kelulusan pengurusan.
                // Kekal untuk 'failed'/'pending'/null (belum cuba) supaya
                // ahli boleh cuba/cuba semula.
                if (isPending &&
                    widget.registrationPaymentStatus != 'succeeded') ...[
                  FilledButton(
                    onPressed: _submitting ? null : _payRegistrationFee,
                    child: _submitting
                        ? const SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator.adaptive(),
                          )
                        : Text(
                            widget.registrationPaymentStatus == 'failed'
                                ? 'Cuba Bayar Semula'
                                : 'Bayar Yuran Pendaftaran',
                          ),
                  ),
                  const SizedBox(height: 12),
                ],
                OutlinedButton(
                  onPressed: widget.onRefresh,
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

/// Isyarat visual status bayaran yuran pendaftaran — `pending`/`succeeded`/
/// `failed`. Ditambah 2026-08-15: webhook ToyyibPay dah rekod hasil bayaran
/// BETUL dalam DB sejak awal (gagal direkod gagal, berjaya direkod
/// berjaya), tapi client tak pernah papar apa-apa, jadi ahli nampak
/// "tiada apa berlaku" tak kira hasil sebenar.
class _PaymentStatusChip extends StatelessWidget {
  const _PaymentStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, label, color) = switch (status) {
      'succeeded' => (
        Icons.check_circle_outline,
        'Bayaran diterima — menunggu kelulusan pengurusan.',
        theme.colorScheme.primary,
      ),
      'failed' => (
        Icons.error_outline,
        'Bayaran tidak berjaya. Sila cuba lagi.',
        theme.colorScheme.error,
      ),
      _ => (
        Icons.hourglass_top,
        'Bayaran sedang disahkan — boleh ambil masa beberapa minit.',
        theme.extension<AppSemanticColors>()!.warning,
      ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// Gate untuk ahli yang approved tapi email belum disahkan. Backend
/// (RequireVerifiedEmail) 403 semua route Posts/comments/uploads/
/// notifications untuk kes ni — beri jalan keluar terus di sini (hantar
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
