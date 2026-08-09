import 'package:flutter/material.dart';
import 'package:marc/features/posts/widgets/image_viewer_page.dart';
import 'package:marc/shared/widgets/app_network_image.dart';

const _gap = 2.0;
const _radius = 14.0;

/// Grid gambar post gaya Twitter (lama).
///
/// Susunan ikut bilangan gambar — sebab tu ia grid tersuai dan bukan
/// `GridView`: 3 gambar perlukan satu jubin tinggi di kiri dan dua jubin
/// bertindan di kanan, yang bukan grid seragam.
///
///   1 -> satu jubin lebar penuh
///   2 -> dua lajur sama lebar
///   3 -> satu tinggi di kiri, dua bertindan di kanan
///   4 -> grid 2x2
///
/// Ketuk mana-mana jubin membuka pemapar skrin penuh pada gambar itu
/// (leret kiri/kanan antara gambar post yang sama, leret bawah untuk
/// tutup) — lihat [ImageViewerPage].
class PostImageGrid extends StatelessWidget {
  const PostImageGrid({super.key, required this.urls});

  final List<String> urls;

  /// Nisbah bekas keseluruhan. Twitter guna lebih tinggi untuk satu gambar
  /// dan lebih pendek untuk berbilang, supaya baris tak menolak kandungan
  /// seterusnya terlalu jauh ke bawah.
  double get _aspectRatio => switch (urls.length) {
    1 => 16 / 10,
    2 => 16 / 9,
    _ => 3 / 2,
  };

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(_radius),
      child: AspectRatio(
        aspectRatio: _aspectRatio,
        child: switch (urls.length) {
          1 => _tile(context, 0),
          2 => Row(
            children: [
              Expanded(child: _tile(context, 0)),
              const SizedBox(width: _gap),
              Expanded(child: _tile(context, 1)),
            ],
          ),
          3 => Row(
            children: [
              Expanded(child: _tile(context, 0)),
              const SizedBox(width: _gap),
              Expanded(
                child: Column(
                  children: [
                    Expanded(child: _tile(context, 1)),
                    const SizedBox(height: _gap),
                    Expanded(child: _tile(context, 2)),
                  ],
                ),
              ),
            ],
          ),
          _ => Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: _tile(context, 0)),
                    const SizedBox(width: _gap),
                    Expanded(child: _tile(context, 1)),
                  ],
                ),
              ),
              const SizedBox(height: _gap),
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: _tile(context, 2)),
                    const SizedBox(width: _gap),
                    Expanded(child: _tile(context, 3)),
                  ],
                ),
              ),
            ],
          ),
        },
      ),
    );
  }

  Widget _tile(BuildContext context, int index) {
    // Jubin tak pernah lebih lebar drpd lebar skrin, dan kebanyakannya
    // separuh daripada itu — nyahkod pada saiz tu, bukan pada 4608px
    // sumber. Ini yang mengekang penggunaan memori feed.
    final screenWidth = MediaQuery.sizeOf(context).width;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final tileFraction = urls.length == 1 ? 1.0 : 0.5;
    final decodeWidth = (screenWidth * tileFraction * dpr).round();

    return GestureDetector(
      onTap: () =>
          ImageViewerPage.open(context, urls: urls, initialIndex: index),
      child: Hero(
        tag: 'post-image-${urls[index]}',
        child: AppNetworkImage(url: urls[index], decodeWidth: decodeWidth),
      ),
    );
  }
}
