import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';

/// Satu-satunya tempat app ni muat gambar rangkaian.
///
/// Dibina atas `extended_image` sebab ia beri cache cakera DAN gerak isyarat
/// zum/tutup daripada satu pakej — dua cache berasingan untuk gambar yang
/// sama bermakna setiap gambar dimuat turun dua kali, dan bucket kita atas
/// URL r2.dev yang dikadar-hadkan.
///
/// **`cacheWidth` bukan pilihan.** Gambar dimuat naik pada resolusi sensor
/// penuh (`image_picker.imageQuality` cuma kualiti JPEG, bukan dimensi) —
/// log peranti pernah tunjuk sumber 3456x4608. Dinyahkod ke ARGB itu ~64MB
/// untuk SATU gambar, sedangkan `ImageCache` lalai Flutter 100MB dan satu
/// post boleh bawa empat. Tanpa had ni, menatal feed akan
/// mengasak/membunuh proses pada peranti RAM rendah — saiz fail tak
/// memberi amaran, sebab memori bergantung pada piksel bukan bait.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.decodeWidth,
    this.borderRadius,
  });

  final String url;
  final BoxFit fit;

  /// Lebar nyahkod dalam piksel PERANTI. `null` = penuh (guna untuk
  /// pemapar skrin penuh sahaja, di mana zum perlukan piksel sebenar).
  final int? decodeWidth;

  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget image = ExtendedImage.network(
      url,
      fit: fit,
      cache: true,
      // Muat semula sendiri bila cache gagal dibaca — tanpa ni satu
      // kegagalan rangkaian sementara jadi kotak rosak kekal sehingga
      // widget dibina semula.
      retries: 2,
      cacheWidth: decodeWidth,
      loadStateChanged: (state) => switch (state.extendedImageLoadState) {
        LoadState.loading => ColoredBox(
          color: scheme.surfaceContainerHighest,
          child: const Center(child: CircularProgressIndicator.adaptive()),
        ),
        LoadState.failed => GestureDetector(
          // Ketuk untuk cuba lagi — kegagalan rangkaian biasanya sementara.
          onTap: state.reLoadImage,
          child: ColoredBox(
            color: scheme.surfaceContainerHighest,
            child: Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        LoadState.completed => null,
      },
    );

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }
}
