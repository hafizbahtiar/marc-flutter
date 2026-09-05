/// Hero skrin Utama: jalur `primary` (merah jenama) penuh lebar.
///
/// TIADA jalur statistik terapung di sini lagi. Versi sebelum ini
/// meletakkan jalur setinggi ~76px pada `bottom: -30`, jadi ia menjulur
/// 46px ke dalam hero sedangkan padding bawah hero hanya 34px - baki
/// 12px menutup baris terakhir, iaitu nombor ahli. Tindihan itu dibuang
/// terus dan bukan ditala: angka kini hidup sebagai petak bento di bawah
/// hero, jadi tiada apa yang boleh menutup apa.
///
/// Kerana hero kini merah, merah TIDAK lagi boleh bermaksud "perlu
/// tindakan" di tempat lain pada skrin ini - peranan itu berpindah ke
/// `secondary` (navy). Lihat `BentoTone`.
library;

import 'package:flutter/material.dart';
import 'package:marc/features/dashboard/dashboard_models.dart';

class DashboardHero extends StatelessWidget {
  const DashboardHero({super.key, required this.displayName, this.membership});

  final String? displayName;

  /// Null semasa memuat atau bila muatan gagal - jalur tetap dipapar
  /// (ia identiti, bukan data), cuma pil status disembunyikan.
  final Membership? membership;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, topInset + 24, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selamat kembali,',
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onPrimary.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            displayName == null || displayName!.isEmpty
                ? 'Ahli MARC'
                : displayName!,
            style: textTheme.displaySmall?.copyWith(color: scheme.onPrimary),
          ),
          if (membership case final m?) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                _StatusPill(status: m.status),
                if (m.memberId case final id?) ...[
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      id,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onPrimary.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Pil status. Latar putih lut sinar dan bukan warna ketiga - seluruh
/// skrin diolah daripada `primary`/`secondary` sahaja.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = switch (status) {
      'approved' => 'Ahli diluluskan',
      'pending' => 'Menunggu kelulusan',
      'rejected' => 'Permohonan ditolak',
      _ => 'Status tidak diketahui',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.onPrimary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: scheme.onPrimary, fontSize: 13),
      ),
    );
  }
}

/// Tajuk seksyen. Fraunces huruf biasa - BUKAN label huruf besar
/// bertrek: itu tell paling biasa antara muka jana-AI, dan huruf biasa
/// lebih sepadan dengan app bar Fraunces di seluruh app ini.
class DashboardSectionHeading extends StatelessWidget {
  const DashboardSectionHeading({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 8, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontSize: 19),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}
