import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marc/app/router.dart';
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

/// Label kumpulan tarikh ("Hari ini" / "Semalam" / "Lebih awal") — padanan
/// hari kalendar TEMPATAN, bukan selang 24 jam (notifikasi 11pm semalam
/// dan 1am hari ini tak patut sekumpulan).
String _dateBucket(DateTime createdAt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final local = createdAt.toLocal();
  final day = DateTime(local.year, local.month, local.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Hari ini';
  if (diff == 1) return 'Semalam';
  return 'Lebih awal';
}

/// Ratakan senarai notifikasi kepada label kumpulan + notifikasi tersusun
/// ikut tarikh, supaya `itemBuilder` tak perlu kira semula kumpulan bagi
/// setiap baris.
List<Object> _groupByDate(List<AppNotification> items) {
  final entries = <Object>[];
  String? lastBucket;
  for (final n in items) {
    final bucket = _dateBucket(n.createdAt);
    if (bucket != lastBucket) {
      entries.add(bucket);
      lastBucket = bucket;
    }
    entries.add(n);
  }
  return entries;
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

    final hasUnread =
        notifications.valueOrNull?.items.any((n) => !n.read) ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          TextButton(
            onPressed: hasUnread
                ? () async {
                    try {
                      await ref
                          .read(notificationRepositoryProvider)
                          .markAllRead();
                    } catch (_) {
                      if (context.mounted) {
                        MySnackBar.error(context, 'Gagal tanda semua dibaca.');
                      }
                    }
                  }
                : null,
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
            final entries = _groupByDate(state.items);

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
              child: ListView.builder(
                controller: _scrollController,
                itemCount:
                    headerOffset + entries.length + (state.hasMore ? 1 : 0),
                itemBuilder: (context, i) {
                  if (isManagement && i == 0) {
                    return _PendingMembersHeader(count: pendingCount);
                  }
                  final idx = i - headerOffset;

                  if (idx >= entries.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: CircularProgressIndicator.adaptive(),
                      ),
                    );
                  }

                  final entry = entries[idx];
                  if (entry is String) {
                    return _SectionHeader(entry);
                  }

                  final n = entry as AppNotification;
                  final scheme = Theme.of(context).colorScheme;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    tileColor: n.read ? null : scheme.surfaceContainerHighest,
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
                      // `ref.read(routerProvider)` terus, BUKAN
                      // `context.push` — baris ni bukan sinkron dengan
                      // ketukan: `await markRead` di atas boleh buat list
                      // notifikasi rebuild (bacaan berubah), dan context
                      // ListTile ni boleh jadi lapuk sebelum sampai sini.
                      // `GoRouter` instance tak bergantung pada context
                      // yang mana, padanan corak sama di
                      // `push_service.dart` untuk ketukan notifikasi OS.
                      if (destination != null) {
                        ref.read(routerProvider).push(destination);
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
      title: const Text('Ahli Pending'),
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

/// Label kumpulan tarikh ("Hari ini" / "Semalam" / "Lebih awal") — gaya
/// disalin (bukan dikongsi) daripada `_SectionHeader` di
/// `payment_history_page.dart`; kedua-dua widget itu private kepada fail
/// masing-masing.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
