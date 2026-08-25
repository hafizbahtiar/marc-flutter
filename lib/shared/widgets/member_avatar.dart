import 'package:flutter/material.dart';
import 'package:marc/shared/widgets/app_network_image.dart';
// ignore: unused_import
import 'package:marc/shared/widgets/image_viewer_page.dart';

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
    this.heroTag,
  });

  /// Nama paparan (atau member id) - huruf pertama jadi fallback.
  final String label;

  final String? avatarUrl;
  final double radius;

  /// Bila diberi, avatar jadi boleh diketuk (cth untuk tukar gambar, atau
  /// buka [ImageViewerPage] untuk tengok gambar penuh - pemanggil pilih).
  final VoidCallback? onTap;

  /// Bila diberi (dan [avatarUrl] wujud), gambar dibalut `Hero` dengan tag
  /// ni - transisi kongsi-elemen yang licin ke [ImageViewerPage] kalau
  /// [onTap] membukanya dengan `heroTagBuilder` yang pulangkan tag SAMA.
  ///
  /// MESTI unik per widget kalau avatar orang yang sama boleh terpapar
  /// berbilang kali serentak dalam satu skrin (cth beberapa post oleh
  /// penulis sama dalam feed) - guna ID item (post/comment), BUKAN
  /// [avatarUrl] semata-mata, kalau tidak Flutter lontar ralat "multiple
  /// heroes share the same tag". Lihat [defaultImageViewerHeroTag].
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final diameter = radius * 2;

    final image = avatarUrl == null
        ? _Initial(label: label, radius: radius)
        : AppNetworkImage(
            url: avatarUrl!,
            // Nyahkod pada saiz paparan sebenar dalam piksel peranti.
            decodeWidth: (diameter * MediaQuery.devicePixelRatioOf(context))
                .round(),
          );

    final child = ClipOval(
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: avatarUrl != null && heroTag != null
            ? Hero(
                tag: heroTag!,
                // flightShuttleBuilder TANPA ni: penerbangan Hero lalai
                // terus papar child destinasi (gambar penuh segi empat,
                // ImageViewerPage) sepanjang penerbangan - jadi bentuk
                // "melompat" dari bulat ke segi empat SEJAK bingkai
                // pertama semasa buka (bukan beransur), dan bila tutup ia
                // kekal segi empat sehingga saat terakhir baru "snap"
                // bulat semula. Builder ni tambah ClipRRect yang
                // jejarinya beransur dari [radius] (bulat sempurna, sepadan
                // saiz kotak avatar semasa t=0) ke 0 (segi empat tajam,
                // sepadan gambar penuh skrin semasa t=1) - formula sama
                // utk push MAHUPUN pop sebab RectTween Hero sentiasa
                // memetakan t=0 -> hujung avatar, t=1 -> hujung pemapar,
                // tak kira arah penerbangan.
                flightShuttleBuilder:
                    (
                      flightContext,
                      animation,
                      flightDirection,
                      fromHeroContext,
                      toHeroContext,
                    ) {
                      final toHero = toHeroContext.widget as Hero;
                      return AnimatedBuilder(
                        animation: animation,
                        child: toHero.child,
                        builder: (context, child) => ClipRRect(
                          borderRadius: BorderRadius.circular(
                            radius * (1 - animation.value),
                          ),
                          child: child,
                        ),
                      );
                    },
                child: image,
              )
            : image,
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
