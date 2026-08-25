import 'package:flutter/material.dart';
import 'package:marc/shared/widgets/app_network_image.dart';
import 'package:marc/shared/widgets/image_grid_layout.dart';
import 'package:marc/shared/widgets/image_viewer_page.dart';

/// Grid gambar post gaya Twitter (lama).
///
/// Susun atur datang daripada [ImageGridLayout], yang dikongsi dengan
/// penggubah post - jadi pratonton semasa mengarang padan dengan hasil.
///
/// Ketuk mana-mana jubin membuka pemapar skrin penuh pada gambar itu
/// (leret kiri/kanan antara gambar post yang sama, leret bawah untuk
/// tutup) - lihat [ImageViewerPage].
class PostImageGrid extends StatelessWidget {
  const PostImageGrid({super.key, required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    return ImageGridLayout(
      tiles: [for (var i = 0; i < urls.length && i < 4; i++) _tile(context, i)],
    );
  }

  Widget _tile(BuildContext context, int index) {
    // Jubin tak pernah lebih lebar drpd lebar skrin, dan kebanyakannya
    // separuh daripada itu - nyahkod pada saiz tu, bukan pada 4608px
    // sumber. Ini yang mengekang penggunaan memori feed.
    final screenWidth = MediaQuery.sizeOf(context).width;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final tileFraction = urls.length == 1 ? 1.0 : 0.5;
    final decodeWidth = (screenWidth * tileFraction * dpr).round();

    return GestureDetector(
      onTap: () =>
          ImageViewerPage.open(context, urls: urls, initialIndex: index),
      child: Hero(
        tag: defaultImageViewerHeroTag(urls[index], index),
        child: AppNetworkImage(url: urls[index], decodeWidth: decodeWidth),
      ),
    );
  }
}
