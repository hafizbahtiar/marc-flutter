import 'package:flutter/material.dart';

const _gap = 2.0;
const _radius = 14.0;

/// Susun atur grid gambar gaya Twitter (lama), diasingkan daripada
/// kandungan jubin.
///
/// Diekstrak supaya penggubah post dan feed berkongsi susunan yang SAMA:
/// apa yang penulis nampak semasa mengarang ialah apa yang dia dapat.
/// Sebelum ni penggubah papar jalur mendatar yang tak menyerupai hasil
/// akhir langsung.
///
/// Susunan ikut bilangan gambar - sebab tu ia bukan `GridView`:
///
///   1 -> satu jubin lebar penuh
///   2 -> dua lajur sama lebar
///   3 -> satu tinggi di kiri, dua bertindan di kanan
///   4 -> grid 2x2
class ImageGridLayout extends StatelessWidget {
  const ImageGridLayout({super.key, required this.tiles});

  /// Maksimum empat; selebihnya diabaikan (backend pun cap pada 4).
  final List<Widget> tiles;

  static double aspectRatioFor(int count) => switch (count) {
    1 => 16 / 10,
    2 => 16 / 9,
    _ => 3 / 2,
  };

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(_radius),
      child: AspectRatio(
        aspectRatio: aspectRatioFor(tiles.length),
        child: switch (tiles.length) {
          1 => tiles[0],
          2 => Row(
            // stretch: `Expanded` cuma mengekang paksi UTAMA. Tanpa ni
            // jubin bersaiz ikut kandungan sendiri pada paksi silang -
            // widget tanpa saiz intrinsik runtuh jadi sifar, dan gambar
            // besar melimpah keluar sel.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: tiles[0]),
              const SizedBox(width: _gap),
              Expanded(child: tiles[1]),
            ],
          ),
          3 => Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: tiles[0]),
              const SizedBox(width: _gap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: tiles[1]),
                    const SizedBox(height: _gap),
                    Expanded(child: tiles[2]),
                  ],
                ),
              ),
            ],
          ),
          _ => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: tiles[0]),
                    const SizedBox(width: _gap),
                    Expanded(child: tiles[1]),
                  ],
                ),
              ),
              const SizedBox(height: _gap),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: tiles[2]),
                    const SizedBox(width: _gap),
                    Expanded(child: tiles[3]),
                  ],
                ),
              ),
            ],
          ),
        },
      ),
    );
  }
}
