import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/features/activities/activity_format.dart';
import 'package:marc/features/activities/checkin_qr.dart';
import 'package:marc/features/activities/activity_models.dart';
import 'package:marc/features/activities/activity_providers.dart';
import 'package:marc/features/checkout/checkout_page.dart';

/// Padan pola `_formatAmount` di `payment_history_page.dart`.
String _formatAmount(int cents, String currency) =>
    '${currency.toUpperCase()} ${(cents / 100).toStringAsFixed(2)}';

/// Aktiviti yang ahli ini sudah daftar, dengan QR check-in.
///
/// QR dilukis daripada `checkin_token` yang SUDAH tiba bersama
/// `GET /me/activities` - tiada permintaan rangkaian kedua untuk
/// memaparkannya. Liputan di gelanggang selalunya teruk; ahli yang
/// membuka skrin ini sebelum sampai mesti tetap boleh menunjukkan kodnya
/// tanpa isyarat.
class MyActivitiesPage extends ConsumerWidget {
  const MyActivitiesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registrations = ref.watch(myRegistrationsProvider);

    Future<void> refresh() async {
      ref.invalidate(myRegistrationsProvider);
      await ref.read(myRegistrationsProvider.future);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aktiviti Saya'),
        actions: [
          IconButton(
            tooltip: 'Daftar hadir sendiri (imbas QR venue)',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => context.push('/checkin'),
          ),
        ],
      ),
      body: SafeArea(
        child: registrations.when(
          loading: () => Skeletonizer(
            enabled: true,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (var i = 0; i < 3; i++)
                  _RegistrationCard(
                    registration: _placeholderRegistration,
                    showQr: false,
                    onTap: () {},
                  ),
              ],
            ),
          ),
          error: (e, _) => _ErrorState(onRetry: refresh),
          data: (rows) {
            final groups = groupRegistrations(rows);
            if (groups.isEmpty) {
              return RefreshIndicator.adaptive(
                onRefresh: refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 100,
                        horizontal: 28,
                      ),
                      child: Center(
                        child: Text(
                          'Anda belum mendaftar sebarang aktiviti.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator.adaptive(
              onRefresh: refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  if (groups.upcoming.isNotEmpty) ...[
                    const _SectionHeader('Akan Datang'),
                    for (final r in groups.upcoming)
                      _RegistrationCard(
                        registration: r,
                        showQr: r.canCheckInAt(DateTime.now()),
                        onTap: () =>
                            context.push('/activities/${r.activityId}'),
                      ),
                  ],
                  if (groups.past.isNotEmpty) ...[
                    const _SectionHeader('Lepas'),
                    for (final r in groups.past)
                      _RegistrationCard(
                        registration: r,
                        // Aktiviti yang sudah tamat tiada check-in untuk
                        // direkodkan - QR di sini hanya akan ditolak
                        // pengimbas dan mengelirukan.
                        showQr: false,
                        onTap: () =>
                            context.push('/activities/${r.activityId}'),
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

final _placeholderRegistration = MyRegistration(
  id: '0',
  activityId: '0',
  status: 'registered',
  checkinToken: '',
  registeredAt: DateTime.now(),
  title: 'Kejohanan Badminton Tahunan',
  startsAt: DateTime.now(),
  endsAt: DateTime.now(),
  activityStatus: 'published',
  categoryName: 'Sukan',
);

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Gagal memuat aktiviti anda.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Cuba lagi')),
          ],
        ),
      ),
    );
  }
}

class _RegistrationCard extends ConsumerWidget {
  const _RegistrationCard({
    required this.registration,
    required this.showQr,
    required this.onTap,
  });

  final MyRegistration registration;
  final bool showQr;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final r = registration;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.title,
                style: theme.textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.event_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      formatRange(r.startsAt, r.endsAt),
                      style: theme.textTheme.bodyMedium,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (r.categoryName.isNotEmpty) _Tag(label: r.categoryName),
                  if (r.isCancelled)
                    _Tag(label: 'Dibatalkan', color: theme.colorScheme.error),
                  // `not_required` (aktiviti percuma) sengaja tiada tag -
                  // kes biasa yang tak berbaloi bunyi bising visual.
                  if (r.feePaid)
                    _Tag(
                      label: 'Yuran dibayar',
                      color: theme.colorScheme.primary,
                      icon: Icons.check_circle_outline,
                    ),
                  if (r.feeUnpaid && !r.isCancelled)
                    _Tag(
                      label: 'Yuran belum dibayar',
                      color: theme.extension<AppSemanticColors>()!.warning,
                      icon: Icons.error_outline,
                    ),
                ],
              ),
              if (r.feeUnpaid && !r.isCancelled) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      // Baca repo SEKARANG, bukan dalam closure
                      // `onCheckout` yang dipanggil KEMUDIAN dalam
                      // `CheckoutPage` - lihat komen sama dalam
                      // `feed_page.dart` (Opus verify 2026-08-24).
                      final repo = ref.read(activityRepositoryProvider);
                      context.push(
                        '/checkout',
                        extra: CheckoutRequest(
                          title: 'Yuran Aktiviti',
                          description: r.title,
                          amountCents: r.feeCents,
                          currency: r.currency,
                          onCheckout: ({phone}) =>
                              repo.checkoutPayment(r.activityId, phone: phone),
                        ),
                      );
                    },
                    child: Text(
                      [
                        'Bayar Yuran Aktiviti',
                        if (r.feeCents != null)
                          _formatAmount(r.feeCents!, r.currency),
                      ].join(' '),
                    ),
                  ),
                ),
              ],
              if (showQr) ...[
                const SizedBox(height: 16),
                Center(child: CheckinQr(token: r.checkinToken)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.color, this.icon});

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = color ?? theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(label, style: theme.textTheme.labelMedium?.copyWith(color: fg)),
        ],
      ),
    );
  }
}
