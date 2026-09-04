import 'dart:async';
import 'dart:math' show Point;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:marc/shared/ui/map/map_overlay.dart';
import 'package:marc/shared/ui/map/map_tile_source.dart';
import 'package:url_launcher/url_launcher.dart';

export 'package:latlong2/latlong.dart' show LatLng;
export 'package:marc/shared/ui/map/map_tile_source.dart'
    show kMapUserAgentPackageName;

/// Pusat lalai: Kuala Lumpur. App MARC beroperasi di Malaysia, jadi peta
/// lalai tak patut buka di Eropah.
const kDefaultMapCenter = LatLng(3.1390, 101.6869);
const kDefaultMapZoom = 13.0;

/// Pitch maksimum yang MapLibre benarkan. Nilai lebih besar diapit senyap
/// oleh renderer native, jadi kita apit sendiri supaya keadaan Dart tak
/// terpesong daripada kamera sebenar.
const kMapMaxTilt = 60.0;

/// Pitch untuk pandangan "3D". Bukan maksimum: pada 60 darjah ufuk masuk
/// ke dalam frame dan jubin jauh jadi kabur, 50 masih condong dengan jelas
/// tanpa itu.
const kMapTilt3D = 50.0;

/// Jejari sasaran sentuh untuk ciri peta, dalam piksel logical. Kira-kira
/// separuh sasaran sentuh Material 48dp.
const kMapTapSlop = 22.0;

/// Ambang untuk membaca kamera sebagai 3D. Gesture dua jari boleh berhenti
/// pada nilai kecil bukan sifar; tanpa ambang, butang toggle akan tunjuk
/// "3D" untuk condongan yang mata pun tak nampak.
const kMapTilt3DThreshold = 5.0;

/// `View` Android mana yang peta dilukis ke dalamnya. Mesti dipanggil
/// sebelum `runApp`; peta yang sudah dibina kekal dengan mod asalnya.
/// Tiada kesan pada iOS.
///
/// `false` (lalai MapLibre) = `GLSurfaceView` melalui Virtual Display:
/// laluan render paling terus, tapi Flutter terpaksa memancarkan semula
/// MotionEvent ke dalam display maya itu, dan itulah punca lazim gesture
/// peta terasa lambat/berat pada Android.
///
/// `true` = `TextureView` yang Flutter komposit macam lapisan biasa. Kos
/// render lebih tinggi, dan ia **mematikan `onMapClick` sepenuhnya** pada
/// Android - disahkan atas peranti: sifar peristiwa klik sampai ke Dart
/// dengan `true`, setiap ketikan sampai dengan `false`. Pan dan zum kekal
/// berfungsi dalam kedua-dua mod, jadi kerosakan itu senyap.
///
/// Lalai `false` kerana itu: peta yang tak boleh diketik ialah peta yang
/// rosak, dan kelancaran gesture ialah keutamaan yang lebih rendah. Kalau
/// ia diflip semula untuk melicinkan gesture, tap MESTI diuji atas peranti
/// dalam pusingan yang sama.
void initMapPlatformView({bool useTextureView = false}) {
  ml.MapLibreMap.useHybridComposition = useTextureView;
}

bool get _inWidgetTest =>
    WidgetsBinding.instance.runtimeType.toString().contains('TestWidgets');

ml.LatLng _toMl(LatLng point) => ml.LatLng(point.latitude, point.longitude);

LatLng _fromMl(ml.LatLng point) => LatLng(point.latitude, point.longitude);

/// Permukaan peta dalam ujian widget. `MapLibreMap` ialah PlatformView
/// dan meletup tanpa method channel native (`_channel` uninitialized).
@visibleForTesting
class AppMapDebugHost extends StatelessWidget {
  const AppMapDebugHost({super.key, required this.styleString});

  final String styleString;

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

/// Penanda Flutter di atas peta. Widget kekal tegak bila kamera berputar
/// (bukan ikon dalam gaya MapLibre).
///
/// HAD: kedudukan skrin dikira lewat `toScreenLocation` - satu round-trip
/// async melalui platform channel - jadi penanda sentiasa satu frame atau
/// lebih di belakang peta native semasa pan/zoom. Ia nampak menggigil, dan
/// hilang sekejap bila unjuran gagal. Untuk apa-apa yang mesti melekat
/// tepat pada peta (lokasi peranti terutamanya) guna lapisan native:
/// [AppMap.showUserLocation] untuk titik pengguna, atau simbol dalam gaya
/// MapLibre. `AppMapMarker` sesuai untuk penanda statik yang boleh terima
/// sedikit lag.
class AppMapMarker {
  const AppMapMarker({
    required this.point,
    required this.child,
    this.width = 44,
    this.height = 44,
    this.alignment = Alignment.topCenter,
  });

  final LatLng point;
  final Widget child;
  final double width;
  final double height;

  /// Bahagian [child] yang duduk pada [point]. `topCenter` = hujung atas
  /// widget pada koordinat (ikon pin Material).
  final Alignment alignment;
}

/// Pengawal kamera. Wrap `MapLibreMapController` supaya pemanggil
/// `AppMap` tak perlu import MapLibre terus untuk gerakkan peta.
class AppMapController {
  AppMapController({
    LatLng initialCenter = kDefaultMapCenter,
    double initialZoom = kDefaultMapZoom,
  }) : _center = initialCenter,
       _zoom = initialZoom;

  ml.MapLibreMapController? _native;
  LatLng _center;
  double _zoom;
  double _bearing = 0;
  double _tilt = 0;
  LatLng? _userLocation;
  final _events = StreamController<void>.broadcast();

  Stream<void> get mapEventStream => _events.stream;

  LatLng get center => _center;

  double get zoom => _zoom;

  /// Darjah, ikut bearing MapLibre (jam dari utara). 0 = utara ke atas.
  double get rotation => _bearing;

  /// Pitch kamera dalam darjah. 0 = pandangan tegak dari atas (2D),
  /// makin besar makin condong (3D). MapLibre hadkan pada 60.
  double get tilt => _tilt;

  void _attach(ml.MapLibreMapController native) {
    _native = native;
    _syncFromNative(native.cameraPosition);
  }

  /// MapLibre memanggil `onCameraMove` SETIAP frame semasa gesture, dengan
  /// perubahan sekecil 0.001 darjah. Menyiarkan setiap satu bermakna setiap
  /// pendengar membina semula UI 60-120 kali sesaat untuk gerakan yang mata
  /// pun tak nampak - itulah sebab kawalan peta terasa berat semasa
  /// diseret. Kita simpan nilai terkini SENTIASA (supaya getter tak pernah
  /// basi), tapi hanya siarkan bila ada yang benar-benar berubah.
  void _onCamera(ml.CameraPosition? position) {
    if (_syncFromNative(position) && !_events.isClosed) _events.add(null);
  }

  /// Pulangkan true bila mana-mana paksi berubah melebihi ambang yang
  /// boleh dilihat.
  bool _syncFromNative(ml.CameraPosition? position) {
    if (position == null) return false;
    if (!position.zoom.isFinite ||
        !position.bearing.isFinite ||
        !position.tilt.isFinite ||
        !position.target.latitude.isFinite ||
        !position.target.longitude.isFinite) {
      return false;
    }
    final center = _fromMl(position.target);
    // ~0.1 m pada khatulistiwa: di bawah satu piksel pada zoom maksimum.
    final moved =
        (center.latitude - _center.latitude).abs() > 1e-6 ||
        (center.longitude - _center.longitude).abs() > 1e-6 ||
        (position.zoom - _zoom).abs() > 0.01 ||
        (position.bearing - _bearing).abs() > 0.25 ||
        (position.tilt - _tilt).abs() > 0.25;
    _center = center;
    _zoom = position.zoom;
    _bearing = position.bearing;
    _tilt = position.tilt;
    return moved;
  }

  /// Set [animate] false untuk lompat serta-merta. Fokus awal patut guna
  /// itu: menganimasi dari pusat lalai ke lokasi pengguna bermakna skrin
  /// dibuka dengan peta yang meluncur, dan orang sempat nampak ia bermula
  /// di tempat yang salah.
  Future<void> move(LatLng center, double zoom, {bool animate = true}) async {
    _center = center;
    _zoom = zoom;
    if (!_events.isClosed) _events.add(null);
    final native = _native;
    if (native == null) return;
    final update = ml.CameraUpdate.newLatLngZoom(_toMl(center), zoom);
    if (!animate) {
      await native.moveCamera(update);
      return;
    }
    await native.animateCamera(
      update,
      duration: const Duration(milliseconds: 220),
    );
  }

  Future<void> zoomBy(double delta) async {
    _zoom += delta;
    if (!_events.isClosed) _events.add(null);
    final native = _native;
    if (native == null) return;
    await native.animateCamera(
      ml.CameraUpdate.zoomBy(delta),
      duration: const Duration(milliseconds: 220),
    );
  }

  Future<void> rotate(double degree) async {
    _bearing = degree;
    if (!_events.isClosed) _events.add(null);
    final native = _native;
    if (native == null) return;
    await native.animateCamera(
      ml.CameraUpdate.bearingTo(degree),
      duration: const Duration(milliseconds: 280),
    );
  }

  /// Condongkan kamera ke [degree] (0 = 2D, `kMapTilt3D` = 3D). Nilai
  /// diapit pada julat yang MapLibre terima supaya nilai luar julat tak
  /// senyap-senyap jadi no-op.
  Future<void> tiltTo(double degree) async {
    final target = degree.clamp(0.0, kMapMaxTilt).toDouble();
    _tilt = target;
    if (!_events.isClosed) _events.add(null);
    final native = _native;
    if (native == null) return;
    await native.animateCamera(
      ml.CameraUpdate.tiltTo(target),
      duration: const Duration(milliseconds: 280),
    );
  }

  /// Fix terakhir yang ditolak oleh lapisan lokasi native. `null` sehingga
  /// fix pertama sampai.
  LatLng? get lastKnownUserLocation => _userLocation;

  void _onUserLocation(LatLng point) {
    _userLocation = point;
    if (!_events.isClosed) _events.add(null);
  }

  /// Lokasi peranti mengikut lapisan lokasi native. `null` bila
  /// [AppMap.showUserLocation] false, kebenaran ditolak, atau belum ada
  /// fix GPS lagi - jadi pemanggil mesti kendalikan null, bukan anggap
  /// koordinat sentiasa ada.
  ///
  /// Fix yang ditolak native diutamakan berbanding `requestMyLocationLatLng`:
  /// yang kedua itu round-trip platform channel, dan menunggunya sebelum
  /// menggerakkan kamera membuatkan butang "Lokasi saya" terasa lambat.
  Future<LatLng?> userLocation() async {
    final cached = _userLocation;
    if (cached != null) return cached;
    final native = _native;
    if (native == null) return null;
    final point = await native.requestMyLocationLatLng();
    if (point == null) return null;
    return _userLocation = _fromMl(point);
  }

  /// Suap satu kedudukan kamera macam MapLibre buat. Ujian perlukan ini
  /// untuk mengesahkan penapisan siaran tanpa peta native.
  @visibleForTesting
  void debugSyncCamera({
    required LatLng center,
    required double zoom,
    required double bearing,
    required double tilt,
  }) {
    _onCamera(
      ml.CameraPosition(
        target: _toMl(center),
        zoom: zoom,
        bearing: bearing,
        tilt: tilt,
      ),
    );
  }

  void dispose() {
    _native = null;
    _events.close();
  }
}

/// Peta OSM boleh guna semula. Sumber jubin dihantar sebagai
/// [MapTileSource] (interface).
///
/// Renderer: MapLibre native. Gaya OpenFreeMap (spesifikasi MapLibre)
/// termasuk ikon sepanjang jalan (arrow satu-hala) yang ikut geometri.
class AppMap extends StatefulWidget {
  const AppMap({
    super.key,
    required this.tileSource,
    this.controller,
    this.initialCenter = kDefaultMapCenter,
    this.initialZoom = kDefaultMapZoom,
    this.children = const [],
    this.markers = const [],
    this.onTap,
    this.onMapReady,
    this.showAttribution = true,
    this.showScalebar = true,
    this.showUserLocation = false,
    this.onUserLocation,
    this.rotateGesturesEnabled = true,
    this.tiltGesturesEnabled = true,
    this.tapLayerIds = const [],
    this.onFeatureTap,
    this.onAttributionTap,
  });

  final MapTileSource tileSource;
  final AppMapController? controller;
  final LatLng initialCenter;
  final double initialZoom;

  /// Overlay Flutter di atas peta (bukan lapisan MapLibre).
  final List<Widget> children;

  /// Penanda yang diunjur ke koordinat peta. Ikon kekal tegak.
  final List<AppMapMarker> markers;

  final void Function(LatLng point)? onTap;
  final VoidCallback? onMapReady;
  final bool showAttribution;

  /// Skala native MapLibre (web sahaja). Tiada kesan pada Android/iOS.
  final bool showScalebar;

  /// Titik lokasi peranti, dilukis oleh MapLibre DALAM peta native.
  ///
  /// Sengaja bukan [AppMapMarker]: penanda Flutter diunjur melalui
  /// platform channel async, jadi ia ketinggalan di belakang peta dan
  /// menggigil. Titik native bergerak dalam frame yang sama dengan jubin.
  ///
  /// Pemanggil bertanggungjawab minta kebenaran lokasi DAHULU. Set flag ni
  /// true tanpa kebenaran cuma menghasilkan peta tanpa titik (Android) atau
  /// prompt sistem yang tak dijangka (iOS).
  final bool showUserLocation;

  /// Fix GPS ditolak oleh native bila ia tiba. Ini cara yang betul untuk
  /// tahu bila lokasi jadi tersedia - tinjau `userLocation()` berulang kali
  /// membazir round-trip channel dan tetap tak tahu bila fix pertama
  /// sampai.
  final void Function(LatLng point)? onUserLocation;

  /// Putar kamera dengan gesture dua jari (pusing).
  final bool rotateGesturesEnabled;

  /// Bila diberi, butang hak cipta memanggil ini dengan atribusi tergabung
  /// dan bukan mengembang jadi baris cip dalam peta. Senarai itu dikira di
  /// sini supaya logik gabung basemap+overlay kekal di satu tempat.
  final void Function(List<MapTileAttribution> attributions)? onAttributionTap;

  /// Id layer yang dikenakan hit-test bila peta diketik.
  final List<String> tapLayerIds;

  /// Properties ciri teratas pada titik yang diketik. Widget ni tak tahu
  /// apa properties itu bermakna - pemanggil yang tafsirkannya, jadi
  /// `AppMap` kekal umum dan tak tahu apa-apa tentang transit.
  final void Function(Map<String, dynamic> properties)? onFeatureTap;

  /// Condongkan kamera dengan gesture dua jari (seret menegak).
  ///
  /// Pada Android kedua-dua gesture ini dikesan daripada pointer yang sama,
  /// jadi seretan yang tak betul-betul menegak sering didaftar sebagai
  /// putaran juga. Skrin yang mengutamakan 3D boleh matikan
  /// [rotateGesturesEnabled] untuk hilangkan pertembungan itu.
  final bool tiltGesturesEnabled;

  @override
  State<AppMap> createState() => _AppMapState();
}

class _AppMapState extends State<AppMap> {
  ml.MapLibreMapController? _native;
  List<Offset?> _markerScreens = const [];
  int _projectGen = 0;
  bool _readyNotified = false;

  @override
  void initState() {
    super.initState();
    if (_inWidgetTest) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _notifyReady());
    }
  }

  @override
  void didUpdateWidget(AppMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.markers != widget.markers) {
      unawaited(_projectMarkers());
    }
  }

  @override
  void dispose() {
    _native = null;
    super.dispose();
  }

  void _notifyReady() {
    if (_readyNotified || !mounted) return;
    _readyNotified = true;
    widget.onMapReady?.call();
  }

  void _onMapCreated(ml.MapLibreMapController native) {
    _native = native;
    widget.controller?._attach(native);
    _notifyReady();
  }

  void _onStyleLoaded() {
    unawaited(_projectMarkers());
    unawaited(_installOverlays());
  }

  /// Dipasang di sini, bukan `onMapCreated`: sumber dan layer perlukan gaya
  /// yang sudah dimuat. Menukar jenis peta menukar `styleString`, yang
  /// membuatkan MapLibre buang semua layer dan tembak semula callback ni -
  /// jadi pemasangan semula datang percuma dan tiada perobohan diperlukan.
  Future<void> _installOverlays() async {
    final native = _native;
    if (native == null) return;
    final style = _MapLibreStyleController(native);
    for (final overlay in widget.tileSource.overlays) {
      try {
        await overlay.install(style);
      } catch (error, stack) {
        // Satu overlay rosak tak patut menjatuhkan peta - basemap masih
        // berguna tanpanya.
        debugPrint(
          '[map] overlay ${overlay.id} gagal dipasang: $error\n$stack',
        );
      }
    }
  }

  /// Kredit basemap DAN setiap overlay terpasang. Lesen penyedia data
  /// mewajibkan kredit nampak; menggabungnya di sini bermakna ia muncul
  /// tepat bila overlay hidup dan hilang bersamanya.
  List<MapTileAttribution> _attributions() => [
    ...widget.tileSource.attributions,
    for (final overlay in widget.tileSource.overlays) ...overlay.attributions,
  ];

  void _onCamera(ml.CameraPosition? position) {
    widget.controller?._onCamera(position);
    // Dipanggil setiap frame semasa gesture. Tanpa penanda tiada apa nak
    // diunjur, jadi jangan pun mulakan async body - itu satu Future
    // dibuang setiap frame untuk tiada hasil.
    if (widget.markers.isEmpty) return;
    unawaited(_projectMarkers());
  }

  Future<void> _onClick(Point<double> point, ml.LatLng latLng) async {
    final native = _native;
    final onFeature = widget.onFeatureTap;
    if (native != null && onFeature != null && widget.tapLayerIds.isNotEmpty) {
      // Sasaran sentuh jari jauh lebih besar daripada bulatan stesen;
      // menuntut ketepatan piksel bermakna kebanyakan tap terlepas.
      //
      // UNIT PENTING: koordinat yang MapLibre hantar dalam `onMapClick`
      // ialah piksel VIEW native - piksel FIZIKAL pada Android, mata
      // logical pada iOS. Disahkan pada peranti 480dpi: x mencecah 426
      // pada skrin yang hanya 360dp lebar. Nilai tetap 12 jadi ~4dp di
      // sana, iaitu kotak lebih kecil daripada bulatan yang cuba dikenai.
      final slop =
          kMapTapSlop *
          (defaultTargetPlatform == TargetPlatform.android
              ? MediaQuery.devicePixelRatioOf(context)
              : 1.0);
      try {
        final features = await native.queryRenderedFeaturesInRect(
          Rect.fromCenter(
            center: Offset(point.x.toDouble(), point.y.toDouble()),
            width: slop * 2,
            height: slop * 2,
          ),
          widget.tapLayerIds,
          null,
        );
        if (features.isNotEmpty) {
          final properties = (features.first as Map)['properties'];
          if (properties is Map) {
            onFeature(Map<String, dynamic>.from(properties));
            return;
          }
        }
      } catch (error) {
        // Layer belum wujud (gaya baru bertukar) - jatuh ke onTap biasa
        // dan bukan menelan ketikan itu terus.
        debugPrint('[map] query ciri gagal: $error');
      }
    }
    widget.onTap?.call(_fromMl(latLng));
  }

  void _onUserLocation(ml.UserLocation location) {
    final point = _fromMl(location.position);
    widget.controller?._onUserLocation(point);
    widget.onUserLocation?.call(point);
  }

  Future<void> _projectMarkers() async {
    final native = _native;
    final markers = widget.markers;
    if (native == null || markers.isEmpty) {
      if (mounted && _markerScreens.isNotEmpty) {
        setState(() => _markerScreens = const []);
      }
      return;
    }
    final gen = ++_projectGen;
    final screens = <Offset?>[];
    for (final marker in markers) {
      try {
        final point = await native.toScreenLocation(_toMl(marker.point));
        screens.add(Offset(point.x.toDouble(), point.y.toDouble()));
      } catch (_) {
        screens.add(null);
      }
    }
    if (!mounted || gen != _projectGen) return;
    setState(() => _markerScreens = screens);
  }

  String _styleString(BuildContext context) {
    return widget.tileSource.vectorStyleUri(Theme.of(context).brightness) ??
        ml.MapLibreStyles.openfreemapLiberty;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final styleString = _styleString(context);
    final initial = widget.controller == null
        ? ml.CameraPosition(
            target: _toMl(widget.initialCenter),
            zoom: widget.initialZoom,
          )
        : ml.CameraPosition(
            target: _toMl(widget.controller!.center),
            zoom: widget.controller!.zoom,
            bearing: widget.controller!.rotation,
            tilt: widget.controller!.tilt,
          );

    return RepaintBoundary(
      child: Stack(
        children: [
          _mapSurface(scheme, styleString, initial),
          ..._projectedMarkers(),
          ...widget.children,
          if (widget.showAttribution)
            Positioned(
              left: 12,
              bottom: 12,
              child: MapAttribution(
                attributions: _attributions(),
                onTap: widget.onAttributionTap == null
                    ? null
                    : () => widget.onAttributionTap!(_attributions()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _mapSurface(
    ColorScheme scheme,
    String styleString,
    ml.CameraPosition initial,
  ) {
    if (_inWidgetTest) return AppMapDebugHost(styleString: styleString);
    return ml.MapLibreMap(
      styleString: styleString,
      initialCameraPosition: initial,
      onMapCreated: _onMapCreated,
      onStyleLoadedCallback: _onStyleLoaded,
      trackCameraPosition: true,
      compassEnabled: false,
      logoEnabled: false,
      // Seret dua jari menegak = condong (2D <-> 3D). Default MapLibre
      // memang true, tapi ia dinyatakan di sini supaya gesture itu jadi
      // sebahagian kontrak AppMap dan tak boleh hilang tanpa disedari.
      tiltGesturesEnabled: widget.tiltGesturesEnabled,
      rotateGesturesEnabled: widget.rotateGesturesEnabled,
      myLocationEnabled: widget.showUserLocation,
      onUserLocationUpdated: _onUserLocation,
      // Kosong = MapLibre langkau pengurus anotasi sepenuhnya, yang doknya
      // sendiri panggil "a big performance boost for android". Peta ni guna
      // penanda Flutter dan lapisan lokasi native, bukan anotasi, jadi
      // pengurus itu kerja untuk apa-apa yang tiada.
      // (`annotationConsumeTapEvents` sengaja dibiar default - MapLibreMap
      // ada `assert(length > 0)` untuknya.)
      annotationOrder: const [],
      // `compass`, bukan `normal`: pada iOS hanya render mode ni yang
      // benar-benar memaparkan titik pengguna (lihat doc MyLocationRenderMode).
      myLocationRenderMode: widget.showUserLocation
          ? ml.MyLocationRenderMode.compass
          : ml.MyLocationRenderMode.normal,
      attributionButtonPosition: ml.AttributionButtonPosition.bottomRight,
      scaleControlEnabled: widget.showScalebar,
      minMaxZoomPreference: ml.MinMaxZoomPreference(
        3,
        widget.tileSource.maxZoom.toDouble(),
      ),
      foregroundLoadColor: scheme.surface,
      onCameraMove: _onCamera,
      onCameraIdle: () => _onCamera(_native?.cameraPosition),
      onMapClick: (widget.onTap == null && widget.onFeatureTap == null)
          ? null
          : (point, latLng) => unawaited(_onClick(point, latLng)),
    );
  }

  Iterable<Widget> _projectedMarkers() {
    final markers = widget.markers;
    if (markers.isEmpty) return const [];
    return [
      for (var i = 0; i < markers.length; i++)
        _markerAt(
          markers[i],
          i < _markerScreens.length ? _markerScreens[i] : null,
        ),
    ];
  }

  Widget _markerAt(AppMapMarker marker, Offset? screen) {
    final child = SizedBox(
      width: marker.width,
      height: marker.height,
      child: marker.child,
    );
    if (screen == null) {
      if (_inWidgetTest) return Center(child: child);
      return const SizedBox.shrink();
    }
    final ax = (marker.alignment.x + 1) / 2;
    final ay = (marker.alignment.y + 1) / 2;
    return Positioned(
      left: screen.dx - marker.width * ax,
      top: screen.dy - marker.height * ay,
      child: IgnorePointer(child: child),
    );
  }
}

/// Menterjemah nilai [MapStyleController] kepada panggilan MapLibre.
///
/// Ini satu-satunya tempat gaya overlay bertemu jenis native, jadi overlay
/// kekal boleh diuji tanpa peta.
class _MapLibreStyleController implements MapStyleController {
  _MapLibreStyleController(this._native);

  final ml.MapLibreMapController _native;

  /// `[z1, v1, z2, v2, ...]` jadi interpolasi linear ikut zum; satu nilai
  /// jadi pemalar.
  static Object _stops(List<double> values) {
    if (values.length < 4) return values.first;
    return [
      'interpolate',
      ['linear'],
      ['zoom'],
      ...values,
    ];
  }

  @override
  Future<void> addGeoJsonSource(String id, Map<String, dynamic> geojson) =>
      _native.addGeoJsonSource(id, geojson);

  /// `enableInteraction: false` pada SETIAP layer, dan ia bukan pengoptimuman.
  ///
  /// Lalainya `true`, yang mendaftarkan layer ke dalam
  /// `interactiveFeatureLayerIds` Android. Bila ketikan mengenai layer
  /// begitu, native menembak `feature#onTap` dan **melangkau
  /// `map#onMapClick` sepenuhnya** (`featureTapsTriggersMapClick` lalainya
  /// false). Jadi tap yang mengenai stesen tak pernah sampai ke sini,
  /// sementara tap yang TERLEPAS sampai dan betul-betul memulangkan sifar
  /// ciri - kegagalan yang kelihatan tepat seperti hit-test yang rosak.
  ///
  /// Kita buat hit-test sendiri melalui `queryRenderedFeaturesInRect`, jadi
  /// pemintasan itu cuma merampas ketikan yang kita perlukan.
  @override
  Future<void> addLineLayer(String sourceId, String layerId, MapLineStyle s) =>
      _native.addLineLayer(
        sourceId,
        layerId,
        ml.LineLayerProperties(
          lineColor: s.color,
          lineWidth: _stops(s.width),
          lineOpacity: s.opacity,
          lineJoin: 'round',
          lineCap: 'round',
        ),
        minzoom: s.minZoom,
        enableInteraction: false,
      );

  @override
  Future<void> addCircleLayer(
    String sourceId,
    String layerId,
    MapCircleStyle s,
  ) => _native.addCircleLayer(
    sourceId,
    layerId,
    ml.CircleLayerProperties(
      circleColor: s.color,
      circleRadius: _stops(s.radius),
      circleStrokeColor: s.strokeColor,
      circleStrokeWidth: s.strokeWidth,
    ),
    minzoom: s.minZoom,
    enableInteraction: false,
  );

  @override
  Future<void> addSymbolLayer(
    String sourceId,
    String layerId,
    MapSymbolStyle s,
  ) => _native.addSymbolLayer(
    sourceId,
    layerId,
    ml.SymbolLayerProperties(
      textField: s.textField,
      textFont: s.font,
      textSize: s.textSize,
      textColor: s.color,
      textHaloColor: s.haloColor,
      textHaloWidth: s.haloWidth,
      textOffset: [0, s.offsetY],
      textAnchor: 'top',
      textAllowOverlap: false,
    ),
    minzoom: s.minZoom,
    enableInteraction: false,
  );
}

/// Atribusi OSM/penyedia. Teks boleh diketik; butang kembang/tutup.
class MapAttribution extends StatefulWidget {
  const MapAttribution({super.key, required this.attributions, this.onTap});

  final List<MapTileAttribution> attributions;

  /// Bila diberi, butang menyerahkan paparan kepada pemanggil dan tak
  /// mengembang sendiri. Baris cip inline jadi sempit sebaik ada lebih
  /// daripada dua penyedia, dan overlay menjadikan itu perkara biasa.
  final VoidCallback? onTap;

  @override
  State<MapAttribution> createState() => _MapAttributionState();
}

class _MapAttributionState extends State<MapAttribution> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface.withValues(alpha: 0.92),
      elevation: 2,
      shadowColor: scheme.shadow.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: _open && widget.onTap == null ? _expanded(scheme) : _collapsed(),
    );
  }

  Widget _collapsed() {
    return IconButton(
      tooltip: 'Attributions',
      visualDensity: VisualDensity.compact,
      icon: const Icon(Icons.copyright, size: 18),
      onPressed: widget.onTap ?? () => setState(() => _open = true),
    );
  }

  Widget _expanded(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Wrap(
              spacing: 6,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (var i = 0; i < widget.attributions.length; i++) ...[
                  if (i > 0)
                    Text('·', style: TextStyle(color: scheme.onSurfaceVariant)),
                  _AttributionChip(attribution: widget.attributions[i]),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Attributions',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _open = false),
          ),
        ],
      ),
    );
  }
}

class _AttributionChip extends StatelessWidget {
  const _AttributionChip({required this.attribution});

  final MapTileAttribution attribution;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    if (attribution.url == null) {
      return Text(attribution.text, style: style);
    }
    return GestureDetector(
      onTap: () => unawaited(openMapAttribution(attribution.url!)),
      child: Text(
        attribution.text,
        style: style?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}

/// Buka pautan penyedia dalam pelayar. Awam supaya sheet atribusi dalam
/// `map_page` guna laluan yang sama dan bukan menduanya.
Future<void> openMapAttribution(String url) {
  return launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
