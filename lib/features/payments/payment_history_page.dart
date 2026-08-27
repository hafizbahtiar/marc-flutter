import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/features/payments/payment_models.dart';
import 'package:marc/features/payments/payment_providers.dart';
import 'package:marc/shared/utils/relative_time.dart';
import 'package:marc/shared/ui/widgets/my_snackbar.dart';

// .toUpperCase() - backend tak konsisten kes currency antara modul
// (yuran pendaftaran simpan "myr", yuran aktiviti simpan "MYR"), jadi
// tanpa ni dua seksyen skrin ni papar kod currency berbeza kes untuk
// mata wang yang SAMA (Opus verify 2026-08-15).
String _formatAmount(int cents, String currency) =>
    '${currency.toUpperCase()} ${(cents / 100).toStringAsFixed(2)}';

/// Sejarah bayaran SENDIRI - yuran pendaftaran + yuran aktiviti. Terbuka
/// kepada semua ahli log masuk (bukan management-gated): setiap ahli boleh
/// tengok bayaran sendiri, backend (`GET /me/payments`) skop terus kepada
/// `middleware.UserID(c)`.
///
/// ConsumerStatefulWidget (bukan ConsumerWidget) - perlu `_busy` set utk
/// butang muat turun resit (padanan `MyCertificatesPage`): ketukan
/// berulang pada baris yang sama semasa panggilan pertama masih
/// berjalan tak sepatutnya hantar permintaan bertindih.
class PaymentHistoryPage extends ConsumerStatefulWidget {
  const PaymentHistoryPage({super.key});

  @override
  ConsumerState<PaymentHistoryPage> createState() => _PaymentHistoryPageState();
}

class _PaymentHistoryPageState extends ConsumerState<PaymentHistoryPage> {
  final _busy = <String>{};

  Future<void> _downloadReceipt(
    String id,
    Future<ReceiptBytesResult> Function(String) fetch,
  ) async {
    if (_busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      final result = await fetch(id);
      if (!mounted) return;

      if (!result.isOk) {
        MySnackBar.error(context, result.message!);
        return;
      }

      // Bait PDF terus dari backend (tiada URL R2 lagi, 2026-08-24) -
      // `Printing.layoutPdf` papar dialog preview native dgn pilihan
      // simpan/kongsi/cetak terbina, elak perlu path_provider+
      // open_filex+share_plus berasingan cuma utk "buka satu PDF".
      await Printing.layoutPdf(
        onLayout: (_) async => result.bytes!,
        name: result.filename ?? 'resit.pdf',
      );
    } catch (_) {
      if (mounted) MySnackBar.error(context, 'Gagal muat turun resit.');
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(myPaymentHistoryProvider);
    final receipts = ref.read(paymentReceiptRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sejarah Bayaran Saya')),
      body: SafeArea(
        child: history.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Gagal memuat sejarah bayaran.'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(myPaymentHistoryProvider),
                    child: const Text('Cuba lagi'),
                  ),
                ],
              ),
            ),
          ),
          data: (data) {
            if (data.registrationFee.isEmpty &&
                data.activityFees.isEmpty &&
                data.donations.isEmpty) {
              return RefreshIndicator.adaptive(
                onRefresh: () => ref.refresh(myPaymentHistoryProvider.future),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 80),
                      child: Center(child: Text('Tiada sejarah bayaran.')),
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator.adaptive(
              onRefresh: () => ref.refresh(myPaymentHistoryProvider.future),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  if (data.registrationFee.isNotEmpty) ...[
                    const _SectionHeader('Yuran Pendaftaran'),
                    for (final e in data.registrationFee)
                      _RegistrationFeeTile(
                        entry: e,
                        busy: _busy.contains(e.id),
                        onDownload: e.status == 'succeeded'
                            ? () => _downloadReceipt(
                                e.id,
                                receipts.registrationFee,
                              )
                            : null,
                      ),
                  ],
                  if (data.activityFees.isNotEmpty) ...[
                    const _SectionHeader('Yuran Aktiviti'),
                    for (final e in data.activityFees)
                      _ActivityFeeTile(
                        entry: e,
                        busy: _busy.contains(e.registrationId),
                        onDownload: e.paymentStatus == 'paid'
                            ? () => _downloadReceipt(
                                e.registrationId,
                                receipts.activityFee,
                              )
                            : null,
                      ),
                  ],
                  // Derma (backend L33, 2026-08-22). Diletak AKHIR
                  // sengaja: dua yang di atas ialah kewajipan keahlian,
                  // ini sokongan sukarela - turutan tu memadankan cara
                  // ahli memikirkannya.
                  if (data.donations.isNotEmpty) ...[
                    const _SectionHeader('Sokongan'),
                    for (final e in data.donations)
                      _DonationTile(
                        entry: e,
                        busy: _busy.contains(e.id),
                        onDownload: e.status == 'succeeded'
                            ? () => _downloadReceipt(e.id, receipts.donation)
                            : null,
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

/// Isyarat visual status bayaran - padanan `_PaymentStatusBadge` di
/// `pending_members_page.dart`, disalin (bukan dikongsi) sebab kedua-dua
/// widget itu private kepada fail masing-masing.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, label, color) = switch (status) {
      'succeeded' || 'paid' => (
        Icons.check_circle_outline,
        status == 'paid' ? 'Dibayar' : 'Berjaya',
        theme.colorScheme.primary,
      ),
      'failed' => (Icons.error_outline, 'Gagal', theme.colorScheme.error),
      'refunded' => (
        Icons.replay_outlined,
        'Dikembalikan',
        theme.colorScheme.onSurfaceVariant,
      ),
      _ => (
        Icons.hourglass_top,
        'Menunggu',
        theme.extension<AppSemanticColors>()!.warning,
      ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: color)),
      ],
    );
  }
}

/// Butang muat turun resit - `null` [onDownload] bermakna belum
/// tersedia (bayaran belum berjaya), jadi ikon disembunyikan terus
/// (bukan dipapar dimatikan) supaya baris tak sesak dengan butang yang
/// tak boleh diketuk.
class _ReceiptButton extends StatelessWidget {
  const _ReceiptButton({required this.busy, required this.onDownload});

  final bool busy;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    if (onDownload == null) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Muat turun resit',
      onPressed: busy ? null : onDownload,
      icon: busy
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2),
            )
          : const Icon(Icons.download_outlined),
    );
  }
}

class _RegistrationFeeTile extends StatelessWidget {
  const _RegistrationFeeTile({
    required this.entry,
    required this.busy,
    required this.onDownload,
  });

  final RegistrationPaymentEntry entry;
  final bool busy;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: const Icon(Icons.card_membership_outlined),
      title: Text(_formatAmount(entry.amountCents, entry.currency)),
      subtitle: Text(relativeTime(entry.createdAt)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusBadge(status: entry.status),
          _ReceiptButton(busy: busy, onDownload: onDownload),
        ],
      ),
    );
  }
}

/// Satu derma. Bentuknya sengaja padan `_RegistrationFeeTile` (jumlah
/// sebagai tajuk, masa sebagai subtajuk) - kedua-duanya bayaran sekali
/// tanpa entiti berkaitan untuk dinamakan, tak macam yuran aktiviti yang
/// tajuknya ialah nama aktiviti.
class _DonationTile extends StatelessWidget {
  const _DonationTile({
    required this.entry,
    required this.busy,
    required this.onDownload,
  });

  final DonationPaymentEntry entry;
  final bool busy;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: const Icon(Icons.favorite_outline),
      title: Text(_formatAmount(entry.amountCents, entry.currency)),
      subtitle: Text(relativeTime(entry.createdAt)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusBadge(status: entry.status),
          _ReceiptButton(busy: busy, onDownload: onDownload),
        ],
      ),
    );
  }
}

class _ActivityFeeTile extends StatelessWidget {
  const _ActivityFeeTile({
    required this.entry,
    required this.busy,
    required this.onDownload,
  });

  final ActivityPaymentEntry entry;
  final bool busy;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: const Icon(Icons.event_available_outlined),
      title: Text(entry.title),
      subtitle: Text(
        '${_formatAmount(entry.feeCents, entry.currency)} · '
        '${relativeTime(entry.registeredAt)}'
        '${entry.registrationStatus == 'cancelled' ? ' · Dibatalkan' : ''}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusBadge(status: entry.paymentStatus),
          _ReceiptButton(busy: busy, onDownload: onDownload),
        ],
      ),
    );
  }
}
