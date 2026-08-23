import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pemapar gambar skrin penuh: cubit-untuk-zum, leret kiri/kanan antara
/// gambar dalam post yang sama, leret ke bawah untuk tutup.
///
/// Dibuka melalui [open] dan bukan `GoRouter`: laluan ni MESTI legap-palsu
/// (`opaque: false`) supaya latar boleh pudar mengikut leretan tutup -
/// itulah keseluruhan kesan "tarik untuk tutup". Laluan GoRouter biasa
/// legap dan akan memaparkan kotak hitam di belakang, bukan feed.
class ImageViewerPage extends StatefulWidget {
  const ImageViewerPage({
    super.key,
    required this.urls,
    required this.initialIndex,
  });

  final List<String> urls;
  final int initialIndex;

  static Future<void> open(
    BuildContext context, {
    required List<String> urls,
    required int initialIndex,
  }) {
    // rootNavigator: true WAJIB. `/feed` tinggal dalam StatefulShellRoute
    // (shell dengan bottom navigation bar), manakala `/posts/:id` ialah
    // route peringkat atas - jadi `Navigator.of(context)` tanpa flag ni
    // menyelesai ke navigator YANG BERBEZA bergantung dari mana pemapar
    // dibuka. Dari feed ia ditolak DALAM shell: bar navigasi bawah kekal
    // kelihatan, tinggi yang ada mengecil, dan SafeArea beralih - sebab
    // tu kaunter/butang tutup duduk di tempat berlainan berbanding bila
    // dibuka dari post detail. Root navigator = skrin penuh sebenar,
    // sama di kedua-dua tempat.
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (_, _, _) =>
            ImageViewerPage(urls: urls, initialIndex: initialIndex),
      ),
    );
  }

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  // ExtendedPageController (bukan PageController biasa) - itu yang
  // ExtendedImageGesturePageView terima, dan ia yang menyelaraskan
  // leretan halaman dengan pan semasa dizum.
  late final ExtendedPageController _controller = ExtendedPageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Pemapar sentiasa berlatar gelap, jadi ikon bar status MESTI cerah -
    // kalau tidak ia hilang terus dalam mod terang (ikon gelap atas
    // latar hitam). AnnotatedRegion pulihkan gaya asal sendiri bila
    // laluan ni ditutup.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: _buildViewer(context),
    );
  }

  Widget _buildViewer(BuildContext context) {
    return ExtendedImageSlidePage(
      slideAxis: SlideAxis.vertical,
      slideType: SlideType.onlyImage,
      // Latar pudar mengikut jarak leretan - maklum balas yang buat gerak
      // isyarat tutup terasa langsung dan bukan bertukar tiba-tiba.
      slidePageBackgroundHandler: (offset, size) {
        final progress = (offset.dy.abs() / (size.height * 0.5)).clamp(
          0.0,
          1.0,
        );
        return Colors.black.withValues(alpha: 1 - progress);
      },
      // Material (lut sinar) WAJIB. Laluan ni PageRouteBuilder mentah
      // tanpa Scaffold, jadi tiada moyang Material - dan `Text` tanpa
      // Material mewarisi DefaultTextStyle fallback Flutter, yang membawa
      // garis bawah BERGANDA KUNING. Menetapkan `color` pada TextStyle tak
      // membuangnya: `decoration` diwarisi berasingan. MaterialType
      // .transparency supaya tiada latar dilukis (gambar mesti kekal
      // kelihatan) sambil tetap menyediakan gaya teks + ink yang betul.
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            ExtendedImageGesturePageView.builder(
              controller: _controller,
              itemCount: widget.urls.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                return ExtendedImage.network(
                  widget.urls[i],
                  fit: BoxFit.contain,
                  cache: true,
                  // Tiada cacheWidth di sini - zum memerlukan piksel sebenar,
                  // dan cuma satu gambar aktif pada satu masa (berbeza dgn
                  // feed yang boleh pegang berpuluh).
                  enableSlideOutPage: true,
                  mode: ExtendedImageMode.gesture,
                  heroBuilderForSlidingPage: (widgetChild) => Hero(
                    tag: 'post-image-${widget.urls[i]}',
                    child: widgetChild,
                  ),
                  initGestureConfigHandler: (state) => GestureConfig(
                    minScale: 1,
                    maxScale: 4,
                    animationMaxScale: 5,
                    // Bila dizum, leretan mengalihkan gambar; bila tidak, ia
                    // diserahkan kepada PageView supaya tukar gambar kekal
                    // berfungsi.
                    inPageView: true,
                    initialAlignment: InitialAlignment.center,
                  ),
                  loadStateChanged: (state) =>
                      switch (state.extendedImageLoadState) {
                        LoadState.loading => const Center(
                          child: CircularProgressIndicator.adaptive(),
                        ),
                        LoadState.failed => Center(
                          child: IconButton(
                            icon: const Icon(
                              Icons.refresh,
                              color: Colors.white,
                              size: 36,
                            ),
                            onPressed: state.reLoadImage,
                          ),
                        ),
                        LoadState.completed => null,
                      },
                );
              },
            ),
            // Skrim kecerunan. Kawalan putih di atas gambar sembarangan tak
            // boleh dibaca sebaik gambar itu cerah - skrim ni jaminan
            // kontras tanpa menggelapkan gambar keseluruhan. IgnorePointer
            // supaya ia tak makan gerak isyarat zum/leret.
            const IgnorePointer(child: _TopScrim()),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      _GlassButton(
                        icon: Icons.close,
                        tooltip: 'Tutup',
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      if (widget.urls.length > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${_index + 1} / ${widget.urls.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopScrim extends StatelessWidget {
  const _TopScrim();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent],
          ),
        ),
      ),
    );
  }
}

/// Butang bulat separa lut sinar - sasaran sentuh 40dp dan kekal nampak
/// atas gambar cerah mahupun gelap.
class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}
