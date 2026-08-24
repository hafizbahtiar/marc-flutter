import 'package:flutter/material.dart';

/// Label kumpulan kecil di atas setiap [SettingsCard] — dikongsi antara
/// `profile_page.dart` dan `settings_page.dart` supaya kedua-dua skrin
/// (info profil + tindakan pengurusan) nampak satu sistem visual yang sama.
class SettingsGroupLabel extends StatelessWidget {
  const SettingsGroupLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Kad kumpulan `ListTile` bergaya sama — asal `_InfoCard` dalam
/// `profile_page.dart`, dikongsi supaya `settings_page.dart` konsisten
/// tanpa cipta gaya kad baharu.
class SettingsCard extends StatelessWidget {
  const SettingsCard({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Material (bukan Container+BoxDecoration) - ListTile lukis ink
    // splash pada Material ANCESTOR terdekat; kalau bg+radius kat
    // Container/DecoratedBox biasa, splash terlukis DI BAWAH decoration
    // tu (tersorok). Jadikan card ni sendiri Material elak isu tu.
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
            children[i],
          ],
        ],
      ),
    );
  }
}
