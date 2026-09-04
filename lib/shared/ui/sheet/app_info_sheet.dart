import 'package:flutter/material.dart';

/// Panel maklumat yang duduk DI ATAS kandungan, bukan di hadapan barrier.
///
/// Berbeza daripada `showAppActionSheet`: yang itu senarai tindakan dan ia
/// route Navigator. Ini kad maklumat, dan ia widget dalam `Stack` halaman -
/// sebab itulah peta di belakangnya kekal boleh dileret semasa kad terbuka.
///
/// Kerana ia bukan route, ia tak muncul dalam timbunan Navigator: pemanggil
/// bertanggungjawab mengendalikan back sendiri (lihat `PopScope` dalam
/// `map_page.dart`).
class AppInfoSheet extends StatefulWidget {
  const AppInfoSheet({
    super.key,
    required this.title,
    required this.children,
    required this.onClose,
    this.subtitle,
    this.peekSize = 0.32,
    this.halfSize = 0.58,
    this.maxSize = 1,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final VoidCallback onClose;

  /// Saiz rehat - tajuk dan beberapa baris pertama, dengan kebanyakan peta
  /// masih nampak.
  final double peekSize;

  /// Hentian tengah. Tiga hentian, bukan dua: langsung dari peek ke penuh
  /// bermakna melihat sedikit lagi butiran memaksa menyerahkan seluruh
  /// skrin.
  final double halfSize;

  /// Penuh bermakna penuh kawasan peta, bukan penuh skrin: sheet ialah
  /// widget dalam `body` Scaffold, jadi ia tak boleh menutupi AppBar. Bar
  /// itu kekal sebagai jalan keluar, dan pemegang seret yang disemat kekal
  /// sebagai jalan turun.
  final double maxSize;

  /// Di bawah pecahan [peekSize] ni, leret turun dibaca sebagai buang.
  static const _dismissFraction = 0.72;

  /// Sudut mula merata di sini, dan hilang sepenuhnya pada [maxSize].
  static const _flattenFrom = 0.9;

  static const _restRadius = 28.0;

  @override
  State<AppInfoSheet> createState() => _AppInfoSheetState();
}

class _AppInfoSheetState extends State<AppInfoSheet> {
  /// Nilai, bukan setState: sambungan berubah setiap frame semasa seretan,
  /// dan membina semula seluruh sheet pada setiap satu akan menjadikan
  /// seretan itu sendiri tersekat-sekat.
  late final ValueNotifier<double> _extent = ValueNotifier(widget.peekSize);

  @override
  void dispose() {
    _extent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final topInset = MediaQuery.paddingOf(context).top;
    final minSize = widget.peekSize * 0.55;

    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        _extent.value = notification.extent;
        // Ditutup semasa seretan masih berjalan, bukan bila dilepaskan:
        // `DraggableScrollableSheet` tak melaporkan lepas-jari, dan
        // menunggu snap selesai bermakna kad tersentak balik ke atas dulu
        // sebelum hilang.
        if (notification.extent <
            widget.peekSize * AppInfoSheet._dismissFraction) {
          widget.onClose();
        }
        return false;
      },
      child: DraggableScrollableSheet(
        initialChildSize: widget.peekSize,
        minChildSize: minSize,
        maxChildSize: widget.maxSize,
        snap: true,
        snapSizes: [widget.peekSize, widget.halfSize],
        builder: (context, scrollController) {
          return ValueListenableBuilder<double>(
            valueListenable: _extent,
            builder: (context, extent, child) {
              // Merata secara berperingkat, bukan bertukar serta-merta:
              // pertukaran mendadak semasa seretan nampak seperti kerosakan.
              final t =
                  ((extent - AppInfoSheet._flattenFrom) /
                          (widget.maxSize - AppInfoSheet._flattenFrom))
                      .clamp(0.0, 1.0);
              final radius = AppInfoSheet._restRadius * (1 - t);
              return Material(
                color: scheme.surface,
                elevation: 8,
                shadowColor: scheme.shadow.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(radius),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                // Bila ia menutupi bar status, kandungan mesti turun ke
                // bawahnya - kalau tidak tajuk duduk di bawah jam.
                child: Padding(
                  padding: EdgeInsets.only(top: topInset * t),
                  child: child,
                ),
              );
            },
            child: CustomScrollView(
              controller: scrollController,
              slivers: [
                // Disemat: bila sheet dibuka penuh dan kandungan ditatal,
                // tajuk tanpa sematan akan hanyut keluar dan meninggalkan
                // baris pertama terpotong separuh di bahagian atas.
                // Pemegang seret duduk di dalamnya supaya sheet kekal boleh
                // ditarik turun dari mana-mana kedudukan tatal.
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SheetHeader(
                    title: widget.title,
                    onClose: widget.onClose,
                    surface: scheme.surface,
                    divider: scheme.outlineVariant,
                    titleStyle: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    8,
                    20,
                    24 + MediaQuery.paddingOf(context).bottom,
                  ),
                  sliver: SliverList.list(
                    children: [
                      if (widget.subtitle case final text?) ...[
                        Text(
                          text,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      ...widget.children,
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Tajuk yang kekal nampak sepanjang tatalan.
///
/// Garis pemisah hanya muncul selepas kandungan mula bergerak di bawahnya -
/// pada kedudukan rehat ia akan jadi hiasan, bukan maklumat.
class _SheetHeader extends SliverPersistentHeaderDelegate {
  const _SheetHeader({
    required this.title,
    required this.onClose,
    required this.surface,
    required this.divider,
    required this.titleStyle,
  });

  final String title;
  final VoidCallback onClose;
  final Color surface;
  final Color divider;
  final TextStyle? titleStyle;

  static const _height = 76.0;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return Material(
      color: surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Handle(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: titleStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Butang tutup eksplisit di samping leret-turun: leret tak
                  // dapat ditemui sendiri, dan ia mustahil dilakukan dengan
                  // satu tangan pada telefon besar.
                  IconButton(
                    tooltip: 'Tutup',
                    icon: const Icon(Icons.close),
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
          ),
          if (overlaps) Divider(height: 1, thickness: 1, color: divider),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_SheetHeader old) =>
      old.title != title ||
      old.surface != surface ||
      old.divider != divider ||
      old.titleStyle != titleStyle;
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(2),
          ),
          child: const SizedBox(width: 36, height: 4),
        ),
      ),
    );
  }
}
