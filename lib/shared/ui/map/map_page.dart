import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:marc/shared/ui/map/app_map.dart';
import 'package:marc/shared/ui/map/map_controls.dart';
import 'package:marc/shared/ui/map/map_tile_source.dart';
import 'package:marc/shared/ui/map/osm_tile_source.dart';
import 'package:marc/shared/ui/dialog/app_dialog.dart';
import 'package:marc/shared/ui/sheet/app_action_sheet.dart';
import 'package:marc/shared/ui/widgets/my_snackbar.dart';
import 'package:permission_handler/permission_handler.dart';

/// Halaman ujian peta: tukar variant jubin OSM dan pastikan `AppMap`
/// boleh diguna semula. Bukan skrin produk — pintu masuk dari Profil.
class MapPage extends StatefulWidget {
  const MapPage({
    super.key,
    this.catalog = const OsmTileCatalog(),
    this.initialType = MapTileType.standard,
  });

  final MapTileCatalog catalog;
  final MapTileType initialType;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static const _zoomStep = 1.0;

  /// Lebih rapat daripada [kDefaultMapZoom]: bila pengguna tekan "lokasi
  /// saya" dia mahu jalan sekeliling, bukan pandangan seluruh bandar.
  static const _userLocationZoom = 16.0;

  late MapTileSource _source;
  late final AppMapController _controller;

  /// Sudut jarum kompas dalam RADIAN. Ia berubah sepanjang gesture putar,
  /// jadi ia dihantar ke `MapControlButton` sebagai listenable dan hanya
  /// ikon di dalam yang dibina semula - bukan permukaan bayang kumpulan.
  late final ValueNotifier<double> _needle;

  /// Nilai boolean, bukan darjah/tilt mentah. Kamera berubah setiap frame
  /// semasa gesture; apa yang UI ni sebenarnya perlu cuma "kompas nampak?"
  /// dan "sedang 3D?", dan `ValueNotifier` tak maklum bila nilai sama.
  /// Jadi permukaan Material yang mahal dibina semula beberapa kali sesaat
  /// -> beberapa kali seumur skrin.
  late final ValueNotifier<bool> _compassVisible;
  late final ValueNotifier<bool> _is3D;

  StreamSubscription<void>? _events;
  bool _mapReady = false;

  /// Titik lokasi native hanya dihidupkan SELEPAS kebenaran diberi. Set
  /// `myLocationEnabled` dulu cuma menghasilkan peta tanpa titik pada
  /// Android, dan prompt sistem yang mengejut pada iOS.
  bool _locationGranted = false;

  /// Fokus sekali sahaja pada fix pertama bila kebenaran SUDAH ada masa
  /// skrin dibuka. Ia dilangsaikan sebaik kamera bergerak, supaya fix GPS
  /// kedua tak merentap peta balik dari tempat yang pengguna baru leret.
  bool _focusOnFirstFix = false;

  @override
  void initState() {
    super.initState();
    _source = widget.catalog.byType(widget.initialType);
    _controller = AppMapController();
    _needle = ValueNotifier(0);
    _compassVisible = ValueNotifier(false);
    _is3D = ValueNotifier(false);
    unawaited(_initLocation());
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    _needle.dispose();
    _compassVisible.dispose();
    _is3D.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onMapReady() {
    _events = _controller.mapEventStream.listen((_) {
      final degrees = _normalizeDegrees(_controller.rotation);
      _needle.value = degrees * math.pi / 180;
      _compassVisible.value = degrees.abs() >= 2;
      _is3D.value = _controller.tilt >= kMapTilt3DThreshold;
    });
    if (mounted) setState(() => _mapReady = true);
  }

  /// Fix GPS ditolak oleh lapisan native. Fokus awal digantung di sini,
  /// bukan pada `onMapReady`: masa peta sedia belum tentu ada fix lagi,
  /// dan menunggunya dengan polling `userLocation()` cuma round-trip
  /// channel berulang yang tetap tak tahu bila fix sampai.
  void _onUserLocation(LatLng point) {
    if (!_focusOnFirstFix) return;
    _focusOnFirstFix = false;
    // Lompat, bukan animasi: skrin baru dibuka, jadi tiada apa yang
    // perlu diikuti mata dari pusat lalai ke sini.
    unawaited(_controller.move(point, _userLocationZoom, animate: false));
  }

  /// `Permission.locationWhenInUse` memadai: peta hanya perlukan lokasi
  /// semasa skrin ni terbuka. Minta `location` penuh akan cetuskan prompt
  /// "sepanjang masa" yang tak dapat dibenarkan oleh apa yang app ni buat.
  ///
  /// Semak `status` DAHULU sebelum `request()`: bila kebenaran sudah ada,
  /// skrin patut terus fokus pada pengguna tanpa apa-apa dialog.
  Future<void> _initLocation() async {
    final PermissionStatus status;
    try {
      final existing = await Permission.locationWhenInUse.status;
      if (existing.isGranted || existing.isLimited) {
        if (!mounted) return;
        _focusOnFirstFix = true;
        setState(() => _locationGranted = true);
        return;
      }
      status = await Permission.locationWhenInUse.request();
    } on PlatformException {
      // Tiada plugin lokasi (ujian widget, platform tak disokong). Peta
      // masih berguna tanpa titik pengguna, jadi gagal senyap dan biar
      // `_locationGranted` kekal false - bukan biarkan initState campak
      // exception yang tak boleh ditangkap sesiapa.
      return;
    }
    if (!mounted) return;
    if (status.isGranted || status.isLimited) {
      // Baru diberi: fokus juga, sebab niat pengguna menekan "Benarkan"
      // ialah untuk nampak dirinya atas peta.
      _focusOnFirstFix = true;
      setState(() => _locationGranted = true);
      return;
    }
    if (status.isPermanentlyDenied) {
      final openSettings = await showAppDialog<bool>(
        context,
        title: 'Kebenaran lokasi diperlukan',
        message:
            'MARC perlukan akses lokasi untuk tunjuk kedudukan anda pada '
            'peta. Sila benarkan akses dalam Tetapan.',
        actions: (ctx) => [
          AppDialogAction(
            label: 'Batal',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          AppDialogAction(
            label: 'Buka Tetapan',
            isPrimary: true,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      );
      if (openSettings ?? false) await openAppSettings();
    }
  }

  Future<void> _resetNorth() async {
    if (!_mapReady) return;
    HapticFeedback.selectionClick();
    await _controller.rotate(0);
  }

  Future<void> _zoomBy(double delta) async {
    if (!_mapReady) return;
    HapticFeedback.selectionClick();
    await _controller.zoomBy(delta);
  }

  /// Toggle 2D <-> 3D. Membaca tilt SEBENAR kamera, bukan flag tempatan,
  /// supaya butang kekal betul selepas pengguna condongkan peta dengan
  /// gesture dua jari.
  Future<void> _toggleTilt() async {
    if (!_mapReady) return;
    HapticFeedback.selectionClick();
    final is3D = _controller.tilt >= kMapTilt3DThreshold;
    await _controller.tiltTo(is3D ? 0 : kMapTilt3D);
  }

  /// Pusat semula ke lokasi peranti. Jatuh balik ke pusat lalai cuma bila
  /// tiada fix - dan beritahu pengguna, sebab senyap-senyap melompat ke KL
  /// adalah tepat kelakuan yang buat pin nampak "tak tepat".
  Future<void> _recenter() async {
    if (!_mapReady) return;
    HapticFeedback.selectionClick();
    // Pengguna mengambil alih; jangan biar fokus-awal yang tertunggu
    // merentap kamera semula bila fix seterusnya tiba.
    _focusOnFirstFix = false;
    final here = _locationGranted ? await _controller.userLocation() : null;
    if (!mounted) return;
    if (here == null) {
      await _controller.move(kDefaultMapCenter, kDefaultMapZoom);
      if (!mounted) return;
      MySnackBar.error(
        context,
        _locationGranted
            ? 'Lokasi anda belum tersedia. Menunjukkan pusat lalai.'
            : 'Kebenaran lokasi ditolak. Menunjukkan pusat lalai.',
      );
      return;
    }
    await _controller.move(here, _userLocationZoom);
  }

  /// Guna `showAppActionSheet` yang dikongsi, bukan sheet grid sendiri:
  /// pemilih jenis peta ialah senarai pilihan bertanda semak, iaitu tepat
  /// apa yang komponen itu buat - termasuk `CupertinoActionSheet` di iOS,
  /// yang sheet grid tulisan tangan dulu tak pernah dapat.
  Future<void> _showLayerSheet() async {
    final chosen = await showAppActionSheet<MapTileSource>(
      context,
      title: 'Jenis Peta',
      actions: [
        for (final source in widget.catalog.all)
          AppSheetAction(
            value: source,
            label: source.label,
            icon: source.icon,
            isSelected: source.id == _source.id,
          ),
      ],
    );
    if (chosen != null && mounted) setState(() => _source = chosen);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Peta')),
      body: Stack(
        children: [
          // Tiada `markers:` di sini dengan sengaja. Kedudukan pengguna
          // dilukis oleh lapisan lokasi native MapLibre, bukan penanda
          // Flutter - penanda Flutter diunjur secara async jadi ia
          // ketinggalan di belakang peta dan menggigil semasa pan.
          AppMap(
            tileSource: _source,
            controller: _controller,
            onMapReady: _onMapReady,
            showUserLocation: _locationGranted,
            onUserLocation: _onUserLocation,
          ),
          Positioned(
            top: 12,
            right: 16,
            child: MapControlGroup(
              children: [
                MapControlButton(
                  icon: Icons.layers_outlined,
                  tooltip: 'Jenis peta',
                  onPressed: _showLayerSheet,
                ),
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // `child:` dibina SEKALI dan diguna semula. Builder cuma
                // memilih antara ia dan ruang kosong, jadi memutar peta
                // tak membina semula butang kompas berulang kali - jarum
                // di dalamnya dengar `_needle` sendiri.
                ValueListenableBuilder<bool>(
                  valueListenable: _compassVisible,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: MapControlGroup(
                      children: [
                        MapControlButton(
                          icon: Icons.navigation,
                          tooltip: 'Utara ke atas',
                          rotation: _needle,
                          onPressed: _resetNorth,
                        ),
                      ],
                    ),
                  ),
                  builder: (context, visible, child) =>
                      visible ? child! : const SizedBox.shrink(),
                ),
                // 3D dikumpul bersama zoom: ketiga-tiganya melaraskan
                // kamera yang sama.
                ValueListenableBuilder<bool>(
                  valueListenable: _is3D,
                  builder: (context, is3D, _) {
                    return MapControlGroup(
                      children: [
                        MapControlButton(
                          icon: Icons.add,
                          tooltip: 'Zoom masuk',
                          onPressed: !_mapReady
                              ? null
                              : () => _zoomBy(_zoomStep),
                        ),
                        MapControlButton(
                          icon: Icons.remove,
                          tooltip: 'Zoom keluar',
                          onPressed: !_mapReady
                              ? null
                              : () => _zoomBy(-_zoomStep),
                        ),
                        MapControlButton(
                          // Ikon menunjukkan apa yang AKAN berlaku bila
                          // ditekan, bukan keadaan semasa - itu cara ikon
                          // butang toggle Google Maps dibaca.
                          icon: is3D
                              ? Icons.map_outlined
                              : Icons.threed_rotation_outlined,
                          tooltip: is3D
                              ? 'Tukar ke pandangan 2D'
                              : 'Tukar ke pandangan 3D',
                          onPressed: !_mapReady ? null : _toggleTilt,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                MapControlGroup(
                  children: [
                    MapControlButton(
                      icon: _locationGranted
                          ? Icons.my_location
                          : Icons.location_disabled_outlined,
                      tooltip: 'Lokasi saya',
                      onPressed: !_mapReady ? null : _recenter,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

double _normalizeDegrees(double degrees) {
  var value = degrees % 360;
  if (value > 180) value -= 360;
  if (value <= -180) value += 360;
  return value;
}
