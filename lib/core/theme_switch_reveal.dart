import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// Peralihan tema bergaya Telegram - tema baharu "terbit" dari titik jari
/// dalam bulatan yang membesar.
///
/// Cara kerja (penting utk kefahaman bila debug):
///  1. Tangkap SATU snapshot skrin tema LAMA (`RepaintBoundary.toImage`).
///  2. Letak snapshot tu sebagai overlay statik di atas app, kemudian
///     tukar tema - jadi tema baharu dah live di bawah, cuma tersorok.
///  3. Animasi potong LUBANG bulat yang membesar pada overlay tu.
///
/// Sebab pilih arah ni (snapshot lama di atas, bukan tema baharu di atas):
/// hanya satu imej statik + satu clip yang dianimasikan. Tiada rebuild
/// widget tree setiap frame dan tiada dua tema di-render serentak, jadi
/// tak ada stutter walaupun skrin di bawah kompleks.
class ThemeSwitchReveal extends StatefulWidget {
  const ThemeSwitchReveal({required this.child, super.key});

  final Widget child;

  /// Null kalau widget ni tak dipasang (cth. dalam test yang bina skrin
  /// secara berasingan) - pemanggil kena fallback tukar tema terus.
  static ThemeSwitchRevealState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<ThemeSwitchRevealState>();

  @override
  State<ThemeSwitchReveal> createState() => ThemeSwitchRevealState();
}

class ThemeSwitchRevealState extends State<ThemeSwitchReveal>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 450);

  final _boundaryKey = GlobalKey();
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOutCubic,
  );

  ui.Image? _snapshot;
  Offset _origin = Offset.zero;
  double _maxRadius = 0;

  /// Instrumentasi sementara - dinaikkan oleh painter setiap kali ia
  /// melukis, supaya kita boleh kira fps sebenar animasi.
  int _paintedFrames = 0;

  @override
  void dispose() {
    _controller.dispose();
    _snapshot?.dispose();
    super.dispose();
  }

  /// Tukar tema dgn animasi radial dari [globalPosition].
  ///
  /// [applyThemeChange] dipanggil SELEPAS snapshot siap ditangkap. Kalau
  /// snapshot gagal (cth. renderer perisian, atau animasi lain masih
  /// berjalan), ia tetap dipanggil - tema mesti tetap bertukar, cuma
  /// tanpa animasi.
  Future<void> reveal({
    required Offset globalPosition,
    required VoidCallback applyThemeChange,
  }) async {
    if (_snapshot != null) {
      applyThemeChange();
      return;
    }

    final boundary =
        _boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null || boundary.debugNeedsPaint) {
      applyThemeChange();
      return;
    }

    final ui.Image image;
    try {
      // `toImageSync` (BUKAN `toImage`) - `toImage` buat GPU readback:
      // ia salin seluruh framebuffer turun ke memori CPU dan menyekat
      // pipeline render, jadi ada jeda ketara sebelum animasi mula.
      // `toImageSync` kekalkan ia sebagai tekstur GPU tanpa readback,
      // dan segerak jadi tiada frame terlepas antara tangkap & tukar.
      image = boundary.toImageSync(
        pixelRatio: View.of(context).devicePixelRatio,
      );
    } catch (_) {
      applyThemeChange();
      return;
    }

    final origin = boundary.globalToLocal(globalPosition);
    setState(() {
      _snapshot = image;
      _origin = origin;
      _maxRadius = _farthestCornerDistance(origin, boundary.size);
    });
    applyThemeChange();

    // Tunggu frame ini habis dulu. Kos `toImage` + paint pertama tema
    // baharu jatuh dalam frame ni; kalau animasi start serentak, frame
    // pertama dia jadi janky. Ini punca stutter yang paling kerap.
    await SchedulerBinding.instance.endOfFrame;
    if (!mounted) return;

    _paintedFrames = 0;
    final animWatch = Stopwatch()..start();
    try {
      await _controller.forward(from: 0);
      animWatch.stop();
      final ms = animWatch.elapsedMilliseconds;
      final fps = ms == 0 ? 0.0 : _paintedFrames * 1000 / ms;
      debugPrint(
        '[theme-reveal] anim: $_paintedFrames frames in ${ms}ms '
        '= ${fps.toStringAsFixed(1)} fps',
      );
    } on TickerCanceled {
      // Widget dilupuskan pertengahan animasi - tiada apa nak bersihkan
      // selain di bawah.
    }
    if (!mounted) return;
    setState(() => _snapshot = null);
    image.dispose();
  }

  static double _farthestCornerDistance(Offset origin, Size size) {
    final dx = origin.dx > size.width / 2 ? origin.dx : size.width - origin.dx;
    final dy = origin.dy > size.height / 2
        ? origin.dy
        : size.height - origin.dy;
    return Offset(dx, dy).distance;
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(key: _boundaryKey, child: widget.child),
        if (snapshot != null)
          // Sekat input sepanjang animasi - elak double-toggle yang
          // akan batalkan snapshot di tengah jalan.
          Positioned.fill(
            child: AbsorbPointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _RevealPainter(
                    image: snapshot,
                    progress: _progress,
                    origin: _origin,
                    maxRadius: _maxRadius,
                    onPainted: () => _paintedFrames++,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RevealPainter extends CustomPainter {
  _RevealPainter({
    required this.image,
    required this.progress,
    required this.origin,
    required this.maxRadius,
    required this.onPainted,
    // `repaint` - repaint terus drpd controller, tanpa setState/rebuild
    // setiap frame.
  }) : super(repaint: progress);

  final ui.Image image;
  final Animation<double> progress;
  final Offset origin;
  final double maxRadius;
  final VoidCallback onPainted;

  @override
  void paint(Canvas canvas, Size size) {
    onPainted();
    // `PathFillType.evenOdd` - bulatan di dalam segi empat jadi LUBANG
    // ikut peraturan isian, tanpa `Path.combine`. `Path.combine` jalankan
    // penyelesai boolean Skia dan alokasi path baharu SETIAP frame; ini
    // cuma dua primitif dan satu bendera.
    final clip = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(
        Rect.fromCircle(center: origin, radius: maxRadius * progress.value),
      );
    canvas.save();
    canvas.clipPath(clip);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.low,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RevealPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.origin != origin ||
      oldDelegate.maxRadius != maxRadius;
}
