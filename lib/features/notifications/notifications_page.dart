import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marc/features/notifications/notifications_providers.dart';
import 'package:marc/features/posts/post_models.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/relative_time.dart';
import 'package:marc/shared/widgets/approval_gate.dart';
import 'package:marc/shared/widgets/my_snackbar.dart';

/// Teks sandaran untuk jenis notifikasi yang klien ini belum kenal.
///
/// Dahulu rantaian `if` di sini JATUH ke ayat `member_rejected`, jadi setiap
/// notifikasi aktiviti dibaca ahli sebagai "Pendaftaran anda tidak
/// diluluskan." Pemetaan kini menyeluruh: jenis baharu daripada server
/// mendarat di `default` — `assert` menjeritkannya semasa pembangunan/ujian,
/// dan pengguna nampak ayat neutral, bukan ayat orang lain.
const unknownNotificationTitle = 'Anda ada notifikasi baharu.';

IconData notificationIcon(AppNotification n) {
  switch (n.type) {
    case 'post_like':
      return Icons.favorite;
    case 'post_comment':
      return Icons.mode_comment_outlined;
    case 'member_pending':
      return Icons.person_add_alt_outlined;
    case 'member_approved':
      return Icons.check_circle_outline;
    case 'member_rejected':
      return Icons.cancel_outlined;
    case 'activity_published':
      return Icons.event_available_outlined;
    case 'activity_cancelled':
      return Icons.event_busy_outlined;
    case 'activity_reminder':
      return Icons.alarm_outlined;
    case 'certificate_ready':
      return Icons.workspace_premium_outlined;
    default:
      assert(false, 'jenis notifikasi tidak dikenali: ${n.type}');
      return Icons.notifications_none;
  }
}

Color notificationColor(BuildContext context, AppNotification n) {
  final scheme = Theme.of(context).colorScheme;
  switch (n.type) {
    case 'post_like':
    case 'member_rejected':
    case 'activity_cancelled':
      return scheme.error;
    case 'post_comment':
    case 'member_pending':
    case 'member_approved':
    case 'activity_published':
    case 'activity_reminder':
    case 'certificate_ready':
      return scheme.primary;
    default:
      assert(false, 'jenis notifikasi tidak dikenali: ${n.type}');
      return scheme.primary;
  }
}

String notificationTitle(AppNotification n) {
  switch (n.type) {
    case 'post_like':
      return 'Seseorang menyukai post anda';
    case 'post_comment':
      return 'Seseorang comment pada post anda';
    case 'member_pending':
      return 'Ahli baru menunggu kelulusan anda';
    case 'member_approved':
      return 'Pendaftaran anda telah diluluskan.';
    case 'member_rejected':
      return 'Pendaftaran anda tidak diluluskan.';
    case 'activity_published':
      return 'Aktiviti baharu telah dibuka untuk pendaftaran.';
    case 'activity_cancelled':
      return 'Satu aktiviti anda telah dibatalkan.';
    case 'activity_reminder':
      return 'Peringatan: aktiviti anda bermula tidak lama lagi.';
    case 'certificate_ready':
      return 'Sijil anda sudah sedia dimuat turun.';
    default:
      assert(false, 'jenis notifikasi tidak dikenali: ${n.type}');
      return unknownNotificationTitle;
  }
}

/// Ke mana ketukan pada notifikasi ini patut pergi — `null` bermakna tiada
/// destinasi (ketukan hanya menanda dibaca).
///
/// `certificate_ready` membawa KEDUA-DUA `certificate_id` dan `activity_id`,
/// jadi sijil diperiksa dahulu: penerimanya mahu failnya, bukan halaman
/// aktiviti.
String? notificationDestination(AppNotification n) {
  if (n.certificateId != null) return '/my-certificates';
  if (n.activityId != null) {
    return '/activities/${Uri.encodeComponent(n.activityId!)}';
  }
  if (n.postId != null) return '/posts/${Uri.encodeComponent(n.postId!)}';
  return null;
}

/// Gate `approved` + email disahkan (padanan `verified.GET("/notifications")`
/// backend) diletak DI LUAR isi kandungan sebenar — provider notifikasi
/// (dan panggilan API-nya) hanya di-watch bila `_NotificationsContent`
/// betul-betul dibina oleh Flutter, iaitu bila ApprovalGate lulus. Ahli
/// `pending` yang tekan tab Notifikasi TAK sampai cetus panggilan 403
/// langsung, bukan setakat sembunyikan ralatnya.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ApprovalGate(
      title: 'Notifikasi',
      requireVerifiedEmail: true,
      child: _NotificationsContent(),
    );
  }
}

class _NotificationsContent extends ConsumerStatefulWidget {
  const _NotificationsContent();

  @override
  ConsumerState<_NotificationsContent> createState() =>
      _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<_NotificationsContent> {
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
      ref.read(notificationsProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsProvider);
    // Ditambah 2026-08-15: pintasan "Ahli Pending" letak di kepala senarai
    // notifikasi, bukan cuma ikon dalam AppBar Ahli — ahli biasa langsung
    // tak `watch` pendingMembersProvider (elak panggilan API sia-sia),
    // management nampak kiraan terus tanpa kena pergi ke tab Ahli dahulu.
    final isManagement = ref.watch(
      myProfileProvider.select((p) => p.valueOrNull?.isManagement ?? false),
    );
    final pendingCount = isManagement
        ? ref.watch(pendingMembersProvider).valueOrNull?.length ?? 0
        : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await ref.read(notificationRepositoryProvider).markAllRead();
              } catch (_) {
                if (context.mounted) {
                  MySnackBar.error(context, 'Gagal tanda semua dibaca.');
                }
              }
            },
            child: const Text('Tanda semua dibaca'),
          ),
        ],
      ),
      body: SafeArea(
        child: notifications.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Gagal memuat notifikasi.'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(notificationsProvider),
                    child: const Text('Cuba lagi'),
                  ),
                ],
              ),
            ),
          ),
          data: (state) {
            final headerOffset = isManagement ? 1 : 0;

            if (state.items.isEmpty) {
              return RefreshIndicator.adaptive(
                onRefresh: () =>
                    ref.read(notificationsProvider.notifier).refresh(),
                child: ListView(
                  children: [
                    if (isManagement)
                      _PendingMembersHeader(count: pendingCount),
                    Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 72),
                          Icon(
                            Icons.notifications_none,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tiada notifikasi buat masa ini.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator.adaptive(
              onRefresh: () =>
                  ref.read(notificationsProvider.notifier).refresh(),
              child: ListView.separated(
                controller: _scrollController,
                itemCount:
                    headerOffset + state.items.length + (state.hasMore ? 1 : 0),
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  if (isManagement && i == 0) {
                    return _PendingMembersHeader(count: pendingCount);
                  }
                  final idx = i - headerOffset;

                  if (idx >= state.items.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: CircularProgressIndicator.adaptive(),
                      ),
                    );
                  }

                  final n = state.items[idx];
                  return ListTile(
                    leading: Icon(
                      notificationIcon(n),
                      color: notificationColor(context, n),
                    ),
                    title: Text(
                      notificationTitle(n),
                      style: TextStyle(
                        fontWeight: n.read
                            ? FontWeight.normal
                            : FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(relativeTime(n.createdAt)),
                    trailing: n.read
                        ? null
                        : Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                    onTap: () async {
                      if (!n.read) {
                        try {
                          await ref
                              .read(notificationRepositoryProvider)
                              .markRead(n.id);
                        } catch (_) {
                          if (context.mounted) {
                            MySnackBar.error(context, 'Gagal tanda dibaca.');
                          }
                        }
                      }
                      final destination = notificationDestination(n);
                      if (destination != null && context.mounted) {
                        context.push(destination);
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

/// Kepala kumpulan "Ahli Pending" — pintasan ke `/members/pending`,
/// management sahaja. Sengaja diletak SEBAGAI baris pertama senarai
/// notifikasi (bukan widget berasingan di luar list) supaya ia turut
/// gulung bersama & ikut RefreshIndicator yang sama. Nombor badge cuma
/// dipapar bila ada ahli menunggu — baris ini kekal kelihatan walau
/// kiraan sifar, jadi ia sentiasa jadi laluan pantas untuk management.
class _PendingMembersHeader extends StatelessWidget {
  const _PendingMembersHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(Icons.person_add_alt_outlined, color: scheme.primary),
      title: const Text('Ahli Menunggu Kelulusan'),
      trailing: count > 0
          ? Badge(
              label: Text('$count'),
              backgroundColor: scheme.error,
              textColor: scheme.onError,
            )
          : const Icon(Icons.chevron_right),
      onTap: () => context.push('/members/pending'),
    );
  }
}
