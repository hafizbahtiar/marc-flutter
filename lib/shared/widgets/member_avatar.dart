import 'package:flutter/material.dart';
import 'package:marc/shared/widgets/app_network_image.dart';

/// Avatar ahli - gambar profil kalau ada, huruf pertama nama kalau tiada.
///
/// SATU tempat untuk setiap avatar dalam app. Sebelum ni tujuh skrin
/// membina `CircleAvatar` sendiri-sendiri dengan radius, warna dan gaya
/// huruf yang berbeza-beza; menambah gambar profil pada tujuh salinan
/// bermakna tujuh peluang untuk terpesong.
///
/// `radius` bukan sekadar saiz lukisan - ia juga menentukan lebar nyahkod
/// gambar. Avatar comment (14) dan avatar header profil (44) beza empat
/// kali ganda dalam luas piksel; menyahkod kedua-duanya pada saiz sama
/// membazir memori pada senarai yang panjang.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.label,
    this.avatarUrl,
    this.radius = 20,
    this.onTap,
  });

  /// Nama paparan (atau member id) - huruf pertama jadi fallback.
  final String label;

  final String? avatarUrl;
  final double radius;

  /// Bila diberi, avatar jadi boleh diketuk (cth untuk tukar gambar).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final diameter = radius * 2;

    final child = ClipOval(
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: avatarUrl == null
            ? _Initial(label: label, radius: radius)
            : AppNetworkImage(
                url: avatarUrl!,
                // Nyahkod pada saiz paparan sebenar dalam piksel peranti.
                decodeWidth: (diameter * MediaQuery.devicePixelRatioOf(context))
                    .round(),
              ),
      ),
    );

    return Semantics(
      label: 'Gambar profil $label',
      image: avatarUrl != null,
      button: onTap != null,
      child: Material(
        color: scheme.primary.withValues(alpha: 0.12),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? child : InkWell(onTap: onTap, child: child),
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.label, required this.radius});

  final String label;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = label.trim().isEmpty ? '?' : label.trim()[0].toUpperCase();

    return Center(
      child: Text(
        initial,
        style: TextStyle(
          color: scheme.primary,
          // Skala dengan radius supaya huruf nampak sama betul pada avatar
          // comment 14px mahupun header profil 44px.
          fontSize: radius * 0.85,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }
}
