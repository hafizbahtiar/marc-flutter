import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:latlong2/latlong.dart';
import 'package:marc/shared/ui/map/map_tile_source.dart';
import 'package:marc/shared/ui/map/vector_style_cache.dart';

export 'package:latlong2/latlong.dart' show LatLng;
export 'package:marc/shared/ui/map/map_tile_source.dart'
    show kMapUserAgentPackageName;

/// Pusat lalai: Kuala Lumpur. App MARC beroperasi di Malaysia, jadi peta
/// lalai tak patut buka di Eropah (itu lalai flutter_map).
const kDefaultMapCenter = LatLng(3.1390, 101.6869);
const kDefaultMapZoom = 13.0;

bool get _inWidgetTest =>
    WidgetsBinding.instance.runtimeType.toString().contains('TestWidgets');

/// Pengawal kamera. Wrap `MapController` flutter_map supaya pemanggil
/// `AppMap` tak perlu import flutter_map terus untuk gerakkan peta.
class AppMapController {
  AppMapController() : _delegate = MapController();

  final MapController _delegate;

  Stream<MapEvent> get mapEventStream => _delegate.mapEventStream;

  bool move(LatLng center, double zoom) => _delegate.move(center, zoom);

  bool rotate(double degree) => _delegate.rotate(degree);

  LatLng get center => _delegate.camera.center;

  double get zoom => _delegate.camera.zoom;

  /// Darjah. 0 = utara ke atas.
  double get rotation => _delegate.camera.rotation;

  void dispose() => _delegate.dispose();
}

/// Peta OSM boleh guna semula. Sumber jubin dihantar sebagai
/// [MapTileSource] (interface).
///
/// Vektor (OpenFreeMap): geometri ikut putaran kamera, label dilukis
/// di ruang skrin — teks/ikon kekal tegak. Raster: fallback jika
/// gaya vektor gagal.
class AppMap extends StatefulWidget {
  const AppMap({
    super.key,
    required this.tileSource,
    this.controller,
    this.initialCenter = kDefaultMapCenter,
    this.initialZoom = kDefaultMapZoom,
    this.children = const [],
    this.onTap,
    this.onMapReady,
    this.showAttribution = true,
    this.showScalebar = true,
  });

  final MapTileSource tileSource;
  final AppMapController? controller;
  final LatLng initialCenter;
  final double initialZoom;

  /// Lapisan tambahan di atas jubin (penanda, polyline, dll).
  /// Untuk ikon kekal tegak bila peta diputar, set `Marker.rotate: true`
  /// (atau `MarkerLayer(rotate: true)`).
  final List<Widget> children;

  final void Function(LatLng point)? onTap;
  final VoidCallback? onMapReady;
  final bool showAttribution;
  final bool showScalebar;

  @override
  State<AppMap> createState() => _AppMapState();
}

class _AppMapState extends State<AppMap> {
  late final TileProvider _rasterProvider;
  vt.Style? _style;
  String? _loadedStyleUri;
  bool _loadingStyle = false;
  int _loadGen = 0;
  Brightness? _brightness;

  @override
  void initState() {
    super.initState();
    _rasterProvider = NetworkTileProvider(
      silenceExceptions: true,
      abortObsoleteRequests: true,
      cachingProvider: _inWidgetTest
          ? const DisabledMapCachingProvider()
          : null,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    if (_brightness != brightness) {
      _brightness = brightness;
      _loadStyle();
    }
  }

  @override
  void didUpdateWidget(AppMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tileSource.id != widget.tileSource.id) {
      _loadStyle();
    }
  }

  @override
  void dispose() {
    _rasterProvider.dispose();
    super.dispose();
  }

  Future<void> _loadStyle() async {
    final brightness = _brightness ?? Brightness.light;
    final uri = widget.tileSource.vectorStyleUri(brightness);
    if (uri == null) {
      if (mounted) {
        setState(() {
          _style = null;
          _loadedStyleUri = null;
          _loadingStyle = false;
        });
      }
      return;
    }
    if (uri == _loadedStyleUri && _style != null) return;

    final gen = ++_loadGen;
    setState(() => _loadingStyle = true);
    try {
      final style = await VectorStyleCache.instance.load(
        uri,
        cacheToDisk: !_inWidgetTest,
      );
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _style = style;
        _loadedStyleUri = uri;
        _loadingStyle = false;
      });
    } catch (_) {
      if (!mounted || gen != _loadGen) return;
      setState(() => _loadingStyle = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final source = widget.tileSource;
    final style = _style;
    final attribution = style != null && style.attributions.isNotEmpty
        ? style.attributions.map((a) => a.text).join(' · ')
        : source.attribution;

    return RepaintBoundary(
      child: Stack(
        children: [
          FlutterMap(
            mapController: widget.controller?._delegate,
            options: MapOptions(
              initialCenter: widget.initialCenter,
              initialZoom: widget.initialZoom,
              minZoom: 3,
              maxZoom: style != null ? 20 : source.maxZoom.toDouble(),
              backgroundColor: scheme.surface,
              onTap: widget.onTap == null
                  ? null
                  : (_, point) => widget.onTap!(point),
              onMapReady: widget.onMapReady,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
                enableMultiFingerGestureRace: true,
                rotationThreshold: 12,
              ),
            ),
            children: [
              if (style != null)
                vt.VectorTileLayer(
                  theme: style.theme,
                  tileProviders: style.providers,
                  rasterSources: style.rasterSources,
                  sprites: style.sprites,
                  showLabels: true,
                  concurrency: 3,
                  diskCacheMaximumSizeInBytes: _inWidgetTest
                      ? 0
                      : 50 * 1024 * 1024,
                  tileFadeDuration: const Duration(milliseconds: 120),
                  labelFadeDuration: const Duration(milliseconds: 120),
                )
              else
                TileLayer(
                  urlTemplate: source.urlTemplate,
                  subdomains: source.subdomains,
                  minNativeZoom: source.minZoom,
                  maxNativeZoom: source.maxZoom,
                  userAgentPackageName: kMapUserAgentPackageName,
                  tileProvider: _rasterProvider,
                  panBuffer: 1,
                  keepBuffer: 2,
                  tileDisplay: const TileDisplay.fadeIn(
                    duration: Duration(milliseconds: 100),
                  ),
                ),
              ...widget.children,
              if (widget.showScalebar)
                Scalebar(
                  alignment: Alignment.bottomLeft,
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 36),
                  textStyle:
                      Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurface,
                      ) ??
                      TextStyle(color: scheme.onSurface, fontSize: 11),
                  lineColor: scheme.onSurface,
                  strokeWidth: 1.5,
                ),
              if (widget.showAttribution)
                Align(
                  alignment: Alignment.bottomRight,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 260),
                        child: Material(
                          color: scheme.surface.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Text(
                              attribution,
                              style: Theme.of(context).textTheme.labelSmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (_loadingStyle)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }
}
