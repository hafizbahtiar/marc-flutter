/// Kandungan ahli biasa untuk `DashboardPage`. Setiap widget menerima
/// potongan model yang diperlukan sahaja (bukan seluruh `DashboardData`),
/// supaya setiap satu boleh diuji berasingan tanpa membina payload penuh.
///
/// Status keahlian dan kiraan ringkas TIDAK lagi di sini - kedua-duanya
/// berpindah ke `DashboardHero`. Kad "Aktiviti Saya" dibuang sepenuhnya:
/// ia mencerminkan tab Aktiviti dan `/my-activities` yang sudah wujud,
/// dan skrin Utama tidak sepatutnya jadi salinan kedua tab lain.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marc/features/activities/activity_format.dart';
import 'package:marc/features/checkout/checkout_page.dart';
import 'package:marc/features/dashboard/dashboard_models.dart';
import 'package:marc/features/dashboard/widgets/bento.dart';
import 'package:marc/features/registration_payment/registration_payment_providers.dart';

/// Padanan corak `my_activities_page.dart:13-14` - format sen mengikut
/// mata wang baris, bukan diandaikan RM.
String _formatAmount(int cents, String currency) =>
    '${currency.toUpperCase()} ${(cents / 100).toStringAsFixed(2)}';

/// Bilangan hari (kalendar, bukan 24j) sehingga `startsAt`.
///
/// Dikira di sini dan BUKAN dengan `relativeTime()`: pembantu itu dibina
/// untuk masa LEPAS dan memulangkan "baru" untuk setiap beza negatif,
/// jadi setiap aktiviti akan datang - termasuk satu enam bulan lagi -
/// akan terbaca "baru sahaja".
String _daysUntilLabel(DateTime startsAt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final start = startsAt.toLocal();
  final startDay = DateTime(start.year, start.month, start.day);
  final days = startDay.difference(today).inDays;
  if (days <= 0) return 'Hari ini';
  if (days == 1) return 'Esok';
  return '$days hari lagi';
}

/// Panggilan bertindak yuran tertunggak.
///
/// Navy (`secondary`) dan BUKAN merah: hero kini merah, jadi merah tidak
/// lagi boleh membawa maksud "ada yang perlu anda buat" - ia sudah jadi
/// latar skrin. Navy pekat ialah satu-satunya blok gelap di bawah hero,
/// jadi ia tetap perkara paling menonjol di kawasan itu. Kad ini hanya
/// wujud apabila ahli benar-benar berhutang; ia tidak dipapar kosong.
class OutstandingFeeCard extends ConsumerWidget {
  const OutstandingFeeCard({super.key, required this.feeCents});

  final int feeCents;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.secondary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Yuran pendaftaran belum dijelaskan',
            style: textTheme.titleMedium?.copyWith(color: scheme.onSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            _formatAmount(feeCents, 'myr'),
            style: textTheme.displaySmall?.copyWith(color: scheme.onSecondary),
          ),
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.onSecondary,
              foregroundColor: scheme.secondary,
            ),
            onPressed: () {
              // Baca repo SEKARANG (tapak butang ni pasti masih
              // `mounted`), bukan dalam closure `onCheckout` yang
              // dipanggil KEMUDIAN dalam `CheckoutPage` - `ref` milik
              // widget ni boleh jadi invalid kalau kad ini dibuang
              // sebelum ahli tekan "Bayar Sekarang" di sana. Padanan
              // corak `pending_status_view.dart:88-112`.
              final repo = ref.read(registrationPaymentRepositoryProvider);
              context.push(
                '/checkout',
                extra: CheckoutRequest(
                  title: 'Yuran Pendaftaran Ahli',
                  amountCents: feeCents,
                  currency: 'myr',
                  onCheckout: ({phone}) => repo.checkout(phone: phone),
                ),
              );
            },
            child: const Text('Bayar sekarang'),
          ),
        ],
      ),
    );
  }
}

/// Dua petak angka milik ahli sendiri. Nada lembut (`primarySoft` /
/// `secondarySoft`) supaya ia jelas kepunyaan sistem warna yang sama
/// dengan hero tanpa bersaing dengannya.
///
/// Notifikasi sengaja TIADA: ia sudah jadi tab bottom-nav dengan
/// lencananya sendiri. Nilai null memberi "-" dan bukan "0" - sifar
/// ialah kenyataan tentang data, dan semasa ralat kita tidak tahu
/// apa-apa lagi.
class MemberStatsBento extends StatelessWidget {
  const MemberStatsBento({
    super.key,
    required this.certificatesTotal,
    required this.totalMembers,
  });

  final int? certificatesTotal;
  final int? totalMembers;

  @override
  Widget build(BuildContext context) {
    return BentoRow(
      children: [
        BentoStat(
          label: 'Sijil saya',
          value: certificatesTotal?.toString() ?? '-',
          tone: BentoTone.primarySoft,
          onTap: () => context.push('/my-certificates'),
        ),
        BentoStat(
          label: 'Ahli berdaftar',
          value: totalMembers?.toString() ?? '-',
          tone: BentoTone.secondarySoft,
          onTap: () => context.push('/members'),
        ),
      ],
    );
  }
}

/// Senarai aktiviti terbuka untuk pendaftaran - satu-satunya blok
/// aktiviti yang tinggal pada skrin Utama, kerana ia menolak ahli ke
/// hadapan ("ada benda baharu boleh disertai") dan bukan sekadar
/// mencerminkan tab lain. Setiap baris mengetuk terus ke
/// `/activities/:id` guna `id` daripada payload.
class OpenActivitiesList extends StatelessWidget {
  const OpenActivitiesList({super.key, required this.activities});

  final List<OpenActivity> activities;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        child: Text(
          'Tiada aktiviti terbuka buat masa ini.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return Column(
      children: activities
          .map((a) => _ActivityRow(activity: a))
          .toList(growable: false),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity});

  final OpenActivity activity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final a = activity;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/activities/${a.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.title, style: textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(
                      '${formatDate(a.startsAt)} · ${_daysUntilLabel(a.startsAt)}',
                      style: textTheme.bodyMedium?.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (a.categoryName.isNotEmpty)
                          _Tag(label: a.categoryName),
                        _Tag(
                          label: a.feeCents > 0
                              ? _formatAmount(a.feeCents, a.currency)
                              : 'Percuma',
                        ),
                        _Tag(label: '${a.registrationCount} berdaftar'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tag kecil serupa `_Tag` dlm `activities_page.dart`, disalin di sini
/// sebab widget privat modul lain tidak boleh diimport terus.
class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
      ),
    );
  }
}
