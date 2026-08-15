import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/features/payments/payment_models.dart';
import 'package:marc/features/payments/payment_providers.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/relative_time.dart';

// "RM" digodam keras sengaja — `payment_logs` TIADA lajur currency (log
// peristiwa, bukan jadual bayaran), dan setiap modul bayaran dalam app ni
// (donation, yuran pendaftaran, yuran aktiviti) MYR sahaja, tiada
// sokongan multi-currency di mana-mana. Kalau modul bukan-MYR ditambah
// kelak, lajur currency perlu ditambah ke payment_logs dahulu (Opus
// verify 2026-08-15 tandakan andaian ni).
String _formatAmount(int? cents) =>
    cents == null ? '—' : 'RM ${(cents / 100).toStringAsFixed(2)}';

/// Tinjauan bayaran merentas modul (donation/yuran pendaftaran/yuran
/// aktiviti) untuk pengurusan — `payment_logs`, log PERISTIWA (checkout,
/// webhook, reconcile), bukan senarai satu-baris-satu-bayaran. Satu
/// bayaran boleh muncul beberapa kali (setiap peristiwa) — ini sengaja,
/// padanan tujuan asal payment_logs (diagnosis/reconcile), bukan
/// pengganti "Sejarah Bayaran Saya" ahli.
class AdminPaymentsPage extends ConsumerStatefulWidget {
  const AdminPaymentsPage({super.key});

  @override
  ConsumerState<AdminPaymentsPage> createState() => _AdminPaymentsPageState();
}

class _AdminPaymentsPageState extends ConsumerState<AdminPaymentsPage> {
  final _scrollController = ScrollController();
  PaymentLogFilter _filter = const PaymentLogFilter();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(paymentLogsProvider(_filter).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Bezakan "masih memuat profil" daripada "bukan management" — padanan
    // audit_page.dart, elak kilasan "tiada akses" utk pengurus SAH semasa
    // /me masih dalam perjalanan.
    final profile = ref.watch(myProfileProvider);
    if (profile.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Semua Bayaran')),
        body: const SafeArea(
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
      );
    }
    if (!(profile.valueOrNull?.isManagement ?? false)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Semua Bayaran')),
        body: const SafeArea(
          child: Center(child: Text('Anda tiada akses ke skrin ini.')),
        ),
      );
    }

    final state = ref.watch(paymentLogsProvider(_filter));

    return Scaffold(
      appBar: AppBar(title: const Text('Semua Bayaran')),
      body: SafeArea(
        child: Column(
          children: [
            _FilterBar(
              filter: _filter,
              onChanged: (f) => setState(() => _filter = f),
              showDonation: ref.watch(isSuperAdminProvider),
            ),
            const Divider(height: 1),
            Expanded(
              child: state.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator.adaptive()),
                error: (e, _) => RefreshIndicator.adaptive(
                  onRefresh: () =>
                      ref.refresh(paymentLogsProvider(_filter).future),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 80),
                        child: Center(
                          child: Text('Gagal memuat senarai bayaran.'),
                        ),
                      ),
                    ],
                  ),
                ),
                data: (data) {
                  if (data.logs.isEmpty) {
                    return RefreshIndicator.adaptive(
                      onRefresh: () =>
                          ref.refresh(paymentLogsProvider(_filter).future),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 80),
                            child: Center(child: Text('Tiada catatan.')),
                          ),
                        ],
                      ),
                    );
                  }
                  return RefreshIndicator.adaptive(
                    onRefresh: () =>
                        ref.refresh(paymentLogsProvider(_filter).future),
                    child: ListView.separated(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount:
                          data.logs.length + (data.isLoadingMore ? 1 : 0),
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        if (i >= data.logs.length) {
                          return const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                              child: CircularProgressIndicator.adaptive(),
                            ),
                          );
                        }
                        return _PaymentLogTile(log: data.logs[i]);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.onChanged,
    required this.showDonation,
  });

  final PaymentLogFilter filter;
  final ValueChanged<PaymentLogFilter> onChanged;

  /// Derma cuma untuk superadmin (keputusan produk 2026-08-15) — cip
  /// disembunyikan drpd management biasa. Kemudahan UI sahaja; backend
  /// tolak `?module=donation` 403 utk sesiapa bukan superadmin walau
  /// diminta terus.
  final bool showDonation;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          for (final e in [
            (null, 'Semua'),
            ('registration_fee', 'Yuran Pendaftaran'),
            ('activity_fee', 'Yuran Aktiviti'),
            if (showDonation) ('donation', 'Derma'),
          ])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(e.$2),
                selected: filter.module == e.$1,
                onSelected: (_) => onChanged(filter.copyWith(module: e.$1)),
              ),
            ),
        ],
      ),
    );
  }
}

class _PaymentLogTile extends StatelessWidget {
  const _PaymentLogTile({required this.log});

  final PaymentLogEntry log;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isBad =
        log.status == 'failed' ||
        log.status == 'error' ||
        log.status == 'mismatch';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: (isBad ? scheme.error : scheme.primary).withValues(
          alpha: 0.12,
        ),
        child: Icon(
          isBad ? Icons.error_outline : Icons.check_circle_outline,
          size: 18,
          color: isBad ? scheme.error : scheme.primary,
        ),
      ),
      title: Text(
        '${log.moduleLabel} · ${log.event}',
        style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        [
          log.status,
          _formatAmount(log.amountCents),
          log.gateway,
          if (log.gatewayRef != null) 'ref=${log.gatewayRef}',
          relativeTime(log.createdAt),
          if (log.message != null) log.message!,
        ].join(' · '),
        style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
      isThreeLine: log.message != null,
    );
  }
}
