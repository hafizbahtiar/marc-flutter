/// Petak bento untuk skrin Utama.
///
/// Seluruh skrin diolah daripada DUA keluarga warna sahaja - `primary`
/// dan `secondary` beserta pasangan `*Container` masing-masing. Tiada
/// warna ketiga diperkenalkan: bento hidup atau mati atas kepelbagaian
/// SAIZ dan BERAT, bukan bilangan warna, dan palet sempit itulah yang
/// menghalangnya jadi tampalan tompok-tompok.
library;

import 'package:flutter/material.dart';

enum BentoTone {
  /// Latar kad biasa - kebanyakan petak.
  surface,

  /// Merah pekat. Dikhaskan untuk hero sahaja supaya ia kekal satu
  /// isyarat, bukan tekstur berulang.
  primary,

  /// Merah lembut - petak milik ahli sendiri.
  primarySoft,

  /// Navy pekat. Isyarat "perlu tindakan" pada skrin ini, kerana merah
  /// sudah dipakai oleh hero dan tidak lagi boleh membawa maksud itu.
  secondary,

  /// Navy lembut - petak berskop organisasi.
  secondarySoft,
}

/// Warna latar dan teks untuk setiap nada, diambil TERUS daripada
/// `ColorScheme` supaya mod gelap ikut sama tanpa senarai warna kedua.
({Color bg, Color fg, Color muted}) bentoColors(
  BuildContext context,
  BentoTone tone,
) {
  final s = Theme.of(context).colorScheme;
  return switch (tone) {
    BentoTone.surface => (
      bg: s.surface,
      fg: s.onSurface,
      muted: s.onSurfaceVariant,
    ),
    BentoTone.primary => (
      bg: s.primary,
      fg: s.onPrimary,
      muted: s.onPrimary.withValues(alpha: 0.75),
    ),
    BentoTone.primarySoft => (
      bg: s.primaryContainer,
      fg: s.onPrimaryContainer,
      muted: s.onPrimaryContainer.withValues(alpha: 0.75),
    ),
    BentoTone.secondary => (
      bg: s.secondary,
      fg: s.onSecondary,
      muted: s.onSecondary.withValues(alpha: 0.75),
    ),
    BentoTone.secondarySoft => (
      bg: s.secondaryContainer,
      fg: s.onSecondaryContainer,
      muted: s.onSecondaryContainer.withValues(alpha: 0.75),
    ),
  };
}

/// Satu petak bento. Ketinggian datang daripada kandungan; baris yang
/// memerlukan dua petak sama tinggi membalut dirinya dengan
/// `IntrinsicHeight` (lihat [BentoRow]) - tanpa itu, `stretch` dalam
/// senarai menegak meminta tinggi infiniti dan meranapkan susun atur.
class BentoTile extends StatelessWidget {
  const BentoTile({
    super.key,
    required this.child,
    this.tone = BentoTone.surface,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final BentoTone tone;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = bentoColors(context, tone);
    return Material(
      color: c.bg,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Baris petak bento yang sama tinggi.
class BentoRow extends StatelessWidget {
  const BentoRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final berjarak = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) berjarak.add(const SizedBox(width: 12));
      berjarak.add(Expanded(child: children[i]));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: berjarak,
        ),
      ),
    );
  }
}

/// Petak angka: satu nilai besar, satu label. Nilai dalam Fraunces
/// (`headlineSmall`) - angka serif memberi berat dan mengikat balik ke
/// wordmark logo.
class BentoStat extends StatelessWidget {
  const BentoStat({
    super.key,
    required this.label,
    required this.value,
    this.tone = BentoTone.surface,
    this.onTap,
    this.footnote,
    this.big = false,
  });

  final String label;

  /// Sudah diformat oleh pemanggil. Rentetan dan bukan `int` supaya
  /// "-", "RM 425.00" dan "72%" semuanya melalui petak yang sama.
  final String value;

  final BentoTone tone;
  final VoidCallback? onTap;
  final String? footnote;

  /// Petak penuh-lebar guna angka lebih besar.
  final bool big;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final c = bentoColors(context, tone);
    return BentoTile(
      tone: tone,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: textTheme.headlineSmall?.copyWith(
              fontSize: big ? 34 : 26,
              color: c.fg,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(fontSize: 13, color: c.muted),
          ),
          if (footnote case final note?) ...[
            const SizedBox(height: 8),
            Text(
              note,
              style: textTheme.bodyMedium?.copyWith(
                fontSize: 11,
                color: c.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
