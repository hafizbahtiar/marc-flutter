import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Saiz setiap kawalan peta. 48dp ialah sasaran sentuh minimum Material -
/// `FloatingActionButton.small` (40dp) yang diguna sebelum ini di bawah
/// had itu.
const double kMapControlSize = 48;

/// Satu permukaan mengandungi beberapa [MapControlButton] bertindan
/// menegak, dipisah garis rambut - macam pil zoom Google Maps.
///
/// Pengumpulan ialah sifat STRUKTUR di sini, bukan padding yang diulang
/// pada setiap butang: butang dalam kumpulan yang sama berkongsi satu
/// permukaan dan satu bayang, jadi ia dibaca sebagai satu kawalan.
/// Butang tunggal pun melalui widget ni supaya bentuk, elevation dan
/// warnanya tak boleh terpesong antara satu sama lain.
class MapControlGroup extends StatelessWidget {
  const MapControlGroup({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 3,
      shadowColor: scheme.shadow.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: 8,
                endIndent: 8,
                color: scheme.outlineVariant,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Satu butang kawalan peta. Sentiasa [kMapControlSize] persegi.
///
/// Guna dalam [MapControlGroup] - butang ni sengaja tak bawa permukaan
/// atau bayang sendiri, supaya mustahil terhasil dua bahasa visual pada
/// skrin peta yang sama.
class MapControlButton extends StatelessWidget {
  const MapControlButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.rotation,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Sudut jarum dalam radian, untuk kompas. `null` untuk setiap butang
  /// lain - mereka tak dapat `Transform` langsung.
  ///
  /// Sengaja `ValueListenable`, bukan `double`: bearing kamera berubah
  /// sepanjang gesture putar, dan menghantarnya sebagai nilai biasa
  /// bermakna pemanggil mesti bina semula SELURUH butang - Tooltip,
  /// InkWell, permukaan bayang kumpulan - untuk setiap sudut baru. Dengan
  /// listenable, hanya ikon di dalam yang dibina semula.
  final ValueListenable<double>? rotation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    final glyph = Icon(
      icon,
      size: 22,
      color: enabled
          ? scheme.onSurface
          : scheme.onSurface.withValues(alpha: 0.38),
    );
    final rotation = this.rotation;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: kMapControlSize,
          height: kMapControlSize,
          child: Center(
            child: rotation == null
                ? glyph
                : ValueListenableBuilder<double>(
                    valueListenable: rotation,
                    child: glyph,
                    builder: (context, angle, child) =>
                        Transform.rotate(angle: angle, child: child),
                  ),
          ),
        ),
      ),
    );
  }
}
