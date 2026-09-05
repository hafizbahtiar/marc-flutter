import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:marc/shared/ui/map/app_map.dart';
import 'package:marc/shared/ui/map/map_controls.dart';
import 'package:marc/shared/ui/map/map_search_bar.dart';
import 'package:marc/shared/ui/map/place_search.dart';
import 'package:marc/shared/ui/map/map_tile_source.dart';
import 'package:marc/shared/ui/map/osm_tile_source.dart';
import 'package:marc/shared/ui/map/transit_overlay.dart';
import 'package:marc/shared/ui/map/transit_station_card.dart';
import 'package:marc/shared/ui/sheet/app_info_sheet.dart';
import 'package:marc/shared/ui/dialog/app_dialog.dart';
import 'package:marc/shared/ui/sheet/app_action_sheet.dart';
import 'package:marc/shared/ui/widgets/my_snackbar.dart';
import 'package:permission_handler/permission_handler.dart';

/// Halaman ujian peta: tukar variant jubin OSM dan pastikan `AppMap`
/// boleh diguna semula. Bukan skrin produk - pintu masuk dari Profil.
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

  /// Cukup rapat untuk melihat hasil dalam konteks, cukup luas untuk
  /// nampak apa di sekelilingnya.
  static const _searchResultZoom = 16.0;

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

  /// Kad terbuka, atau null. Ia keadaan halaman dan bukan route Navigator
  /// sebab `AppInfoSheet` mesti duduk dalam Stack yang sama dengan peta -
  /// itu yang membolehkan peta terus dileret di belakangnya.
  TransitStation? _station;
  List<MapTileAttribution>? _attributions;
  PlaceResult? _place;

  late final MapSearchController _search;
  late final TextEditingController _searchText;

  /// Stesen yang diketahui, dimuat sekali dari aset yang sama yang overlay
  /// guna. Ia yang membolehkan hasil Photon di atas sebuah stesen membuka
  /// kad jadual penuh dan bukan kad tempat generik.
  List<TransitStationPoint> _stationPoints = const [];

  /// Properties penuh setiap stesen, dikunci pada nama. Disimpan semasa
  /// memuat dan bukan disoal semula dari peta: menyoal selepas kamera
  /// bergerak berlumba dengan renderer, dan gagal bila layer belum sempat
  /// dilukis.
  Map<String, Map<String, dynamic>> _stationProps = const {};

  @override
  void initState() {
    super.initState();
    _source = widget.catalog.byType(widget.initialType);
    _controller = AppMapController();
    _search = MapSearchController();
    _searchText = TextEditingController();
    _needle = ValueNotifier(0);
    _compassVisible = ValueNotifier(false);
    _is3D = ValueNotifier(false);
    unawaited(_initLocation());
    unawaited(_loadStationPoints());
  }

  /// Baca aset stesen sekali untuk padanan jarak. Gagal senyap: carian
  /// masih berguna tanpa kad stesen yang lebih kaya.
  Future<void> _loadStationPoints() async {
    try {
      final raw = await rootBundle.loadString(TransitOverlay.stationsAsset);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final points = <TransitStationPoint>[];
      final props = <String, Map<String, dynamic>>{};
      for (final feature in decoded['features'] as List) {
        final properties = Map<String, dynamic>.from(
          (feature as Map)['properties'] as Map,
        );
        final coordinates = (feature['geometry'] as Map)['coordinates'] as List;
        final name = '${properties['name']}';
        points.add(
          TransitStationPoint(
            name: name,
            point: LatLng(
              (coordinates[1] as num).toDouble(),
              (coordinates[0] as num).toDouble(),
            ),
          ),
        );
        props[name] = properties;
      }
      if (!mounted) return;
      setState(() {
        _stationPoints = points;
        _stationProps = props;
      });
    } catch (error) {
      debugPrint('[map] aset stesen gagal dimuat: $error');
    }
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    _search.dispose();
    _searchText.dispose();
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

  /// Layer stesen hanya wujud bila overlay transit terpasang, jadi ini
  /// senyap pada basemap lain - tiada semakan jenis jubin diperlukan.
  void _onStationTap(Map<String, dynamic> properties) {
    if (!mounted) return;
    setState(() {
      _attributions = null;
      _station = TransitStation.fromProperties(properties);
    });
  }

  void _onAttributionTap(List<MapTileAttribution> attributions) {
    setState(() {
      _station = null;
      _place = null;
      // Carian tempat menyajikan data OSM melalui Photon, jadi kreditnya
      // tergolong bersama kredit peta - bukan disorok kerana ia datang
      // dari perkhidmatan lain.
      _attributions = [
        ...attributions,
        const MapTileAttribution('Photon', url: 'https://photon.komoot.io/'),
      ];
    });
  }

  void _closeSheet() {
    if (_station == null && _attributions == null && _place == null) return;
    setState(() {
      _station = null;
      _attributions = null;
      _place = null;
    });
  }

  bool get _sheetOpen =>
      _station != null || _attributions != null || _place != null;

  void _onSearchChanged(String text) =>
      _search.query(text, near: _mapReady ? _controller.center : null);

  void _clearSearch() {
    _searchText.clear();
    _search.clear();
  }

  /// Hasil Photon ialah tempat OSM, bukan objek stesen kita - jadi ia
  /// dipadankan semula ikut jarak. Dalam [kStationMatchMetres] sebuah
  /// stesen, kad jadual penuh lebih berguna daripada nama dan alamat.
  Future<void> _onPlaceSelected(PlaceResult result) async {
    FocusScope.of(context).unfocus();
    _clearSearch();

    final match = matchStation(result.point, _stationPoints);
    final properties = match == null ? null : _stationProps[match.name];

    setState(() {
      _attributions = null;
      _station = properties == null
          ? null
          : TransitStation.fromProperties(properties);
      _place = properties == null ? result : null;
    });

    await _controller.move(result.point, _searchResultZoom);
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
    return PopScope(
      // Kad bukan route, jadi back takkan menutupnya sendiri - tanpa ni,
      // back meninggalkan halaman sementara kad masih terbuka di skrin.
      canPop: !_sheetOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeSheet();
      },
      child: Scaffold(
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
              tapLayerIds: TransitOverlay.stationLayerIds,
              onFeatureTap: _onStationTap,
              onAttributionTap: _onAttributionTap,
              // Ketikan pada peta kosong menutup kad, macam Google Maps.
              onTap: (_) => _closeSheet(),
            ),
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: MapSearchBar(
                      controller: _search,
                      textController: _searchText,
                      onQueryChanged: _onSearchChanged,
                      onSelected: _onPlaceSelected,
                      onClear: _clearSearch,
                    ),
                  ),
                  const SizedBox(width: 12),
                  MapControlGroup(
                    children: [
                      MapControlButton(
                        icon: Icons.layers_outlined,
                        tooltip: 'Jenis peta',
                        onPressed: _showLayerSheet,
                      ),
                    ],
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
            // Terakhir dalam Stack supaya ia di atas kawalan. Tiada barrier:
            // peta di belakangnya kekal boleh dileret dan dizum.
            if (_station case final station?)
              TransitStationCard(station: station, onClose: _closeSheet),
            if (_place case final place?)
              AppInfoSheet(
                title: place.name,
                subtitle: place.subtitle,
                onClose: _closeSheet,
                peekSize: 0.26,
                children: [
                  Text(
                    '${place.point.latitude.toStringAsFixed(5)}, '
                    '${place.point.longitude.toStringAsFixed(5)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            if (_attributions case final attributions?)
              _AttributionCard(
                attributions: attributions,
                onClose: _closeSheet,
              ),
          ],
        ),
      ),
    );
  }
}

/// Kredit penyedia dalam sheet yang sama macam butiran stesen. Baris cip
/// inline dalam peta jadi sempit sebaik ada lebih daripada dua penyedia,
/// dan overlay menjadikan itu perkara biasa.
class _AttributionCard extends StatelessWidget {
  const _AttributionCard({required this.attributions, required this.onClose});

  final List<MapTileAttribution> attributions;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppInfoSheet(
      title: 'Sumber data',
      subtitle: 'Peta ini dibina daripada data terbuka',
      onClose: onClose,
      peekSize: 0.3,
      children: [
        for (final attribution in attributions)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(attribution.text),
            trailing: attribution.url == null
                ? null
                : Icon(Icons.open_in_new, size: 18, color: scheme.primary),
            onTap: attribution.url == null
                ? null
                : () => unawaited(openMapAttribution(attribution.url!)),
          ),
      ],
    );
  }
}

double _normalizeDegrees(double degrees) {
  var value = degrees % 360;
  if (value > 180) value -= 360;
  if (value <= -180) value += 360;
  return value;
}
