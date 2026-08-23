import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/features/checkout/checkout_page.dart';
import 'package:marc/features/registration_payment/registration_payment_providers.dart';

/// Skrin blok REUSABLE untuk ahli `pending`/`rejected` - dulu private
/// dalam `feed_page.dart`, sekarang dikongsi (`ProfilePage` guna sama,
/// 2026-08-24: "kalau tak bayar yuran, profile page pun tak boleh
/// access macam page lain"). Papar status + butang bayar (kalau
/// `pending`) + "Semak semula", dan [footer] pilihan untuk kandungan
/// tambahan khusus caller (cth butang "Log Keluar" di `ProfilePage` -
/// tanpanya, ahli yang skrin LAIN (termasuk Profile) turut diblok tiada
/// jalan keluar akaun langsung).
class PendingStatusView extends ConsumerWidget {
  const PendingStatusView({
    super.key,
    required this.status,
    required this.onRefresh,
    this.registrationPaymentStatus,
    this.registrationFeeCents,
    this.footer,
  });

  final String status;
  final Future<void> Function() onRefresh;

  /// "pending"/"succeeded"/"failed", atau null kalau tak pernah cuba
  /// bayar - lihat `Profile.registrationPaymentStatus`.
  final String? registrationPaymentStatus;

  /// Jumlah (sen) yuran pendaftaran SEMASA - lihat
  /// `Profile.registrationFeeCents`. Papar pada butang bayar SEBELUM
  /// ahli tekan, sebab checkout ToyyibPay sendiri tak dedah jumlah dalam
  /// app (cuma redirect ke halaman ToyyibPay).
  final int? registrationFeeCents;

  /// Kandungan tambahan di BAWAH butang "Semak semula" - pilihan, cth
  /// butang log keluar. `null` = tiada apa-apa tambahan (padan tingkah
  /// laku asal di `feed_page.dart`).
  final Widget? footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRejected = status == 'rejected';
    // Eksplisit 'pending' (bukan `!isRejected`) untuk butang bayar - kalau
    // status baharu ditambah kelak (bukan pending/rejected/approved), ia
    // jatuh ke cabang "sedang disemak" (isRejected=false) tapi TAK patut
    // automatik nampak butang bayar tanpa disemak dulu sama ada ia
    // relevan (Opus verify 2026-08-15).
    final isPending = status == 'pending';
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
                if (isPending && registrationPaymentStatus != null) ...[
                  const SizedBox(height: 12),
                  _PaymentStatusChip(status: registrationPaymentStatus!),
                ],
                const SizedBox(height: 20),
                // Butang bayar disembunyikan bila SUDAH succeeded - tiada
                // sebab bayar lagi, tinggal tunggu kelulusan pengurusan.
                // Kekal untuk 'failed'/'pending'/null (belum cuba) supaya
                // ahli boleh cuba/cuba semula.
                if (isPending && registrationPaymentStatus != 'succeeded') ...[
                  FilledButton(
                    onPressed: () {
                      // Baca repo SEKARANG (tapak butang ni pasti masih
                      // `mounted`), bukan dalam closure `onCheckout` yang
                      // dipanggil KEMUDIAN dalam `CheckoutPage` - `ref`
                      // milik widget ni boleh jadi invalid kalau
                      // `PendingStatusView` dibuang sebelum ahli tekan
                      // "Bayar Sekarang" di sana (cth status bertukar
                      // `approved` di latar). Objek repo sendiri tak
                      // terikat lifecycle widget, jadi selamat dipanggil
                      // lewat (Opus verify 2026-08-24).
                      final repo = ref.read(
                        registrationPaymentRepositoryProvider,
                      );
                      context.push(
                        '/checkout',
                        extra: CheckoutRequest(
                          title: 'Yuran Pendaftaran Ahli',
                          amountCents: registrationFeeCents,
                          currency: 'myr',
                          onCheckout: ({phone}) => repo.checkout(phone: phone),
                        ),
                      );
                    },
                    child: Text(
                      registrationPaymentStatus == 'failed'
                          ? 'Cuba Bayar Semula'
                          : 'Bayar Yuran Pendaftaran',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                OutlinedButton(
                  onPressed: onRefresh,
                  child: const Text('Semak semula'),
                ),
                if (footer != null) ...[const SizedBox(height: 12), footer!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Isyarat visual status bayaran yuran pendaftaran - `pending`/`succeeded`/
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
        'Bayaran diterima - menunggu kelulusan pengurusan.',
        theme.colorScheme.primary,
      ),
      'failed' => (
        Icons.error_outline,
        'Bayaran tidak berjaya. Sila cuba lagi.',
        theme.colorScheme.error,
      ),
      _ => (
        Icons.hourglass_top,
        'Bayaran sedang disahkan - boleh ambil masa beberapa minit.',
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
