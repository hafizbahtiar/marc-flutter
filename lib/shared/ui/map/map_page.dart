import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:marc/shared/ui/map/app_map.dart';
import 'package:marc/shared/ui/map/map_tile_source.dart';
import 'package:marc/shared/ui/map/osm_tile_source.dart';

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

class _MapPageState extends State<MapPage> with SingleTickerProviderStateMixin {
  late MapTileSource _source;
  late final AppMapController _controller;
  late final ValueNotifier<double> _rotation;
  late final AnimationController _northAnim;
  StreamSubscription<MapEvent>? _events;
  bool _mapReady = false;
  Tween<double>? _northTween;

  @override
  void initState() {
    super.initState();
    _source = widget.catalog.byType(widget.initialType);
    _controller = AppMapController();
    _rotation = ValueNotifier(0);
    _northAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..addListener(_applyNorthTick);
  }

  @override
  void dispose() {
    _northAnim.removeListener(_applyNorthTick);
    _northAnim.dispose();
    unawaited(_events?.cancel());
    _rotation.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onMapReady() {
    _events = _controller.mapEventStream.listen((_) {
      _rotation.value = _normalizeDegrees(_controller.rotation);
    });
    if (mounted) setState(() => _mapReady = true);
  }

  void _applyNorthTick() {
    final tween = _northTween;
    if (tween == null) return;
    _controller.rotate(tween.evaluate(_northAnim));
  }

  Future<void> _resetNorth() async {
    if (!_mapReady) return;
    HapticFeedback.selectionClick();
    final from = _controller.rotation;
    var delta = -from;
    while (delta > 180) {
      delta -= 360;
    }
    while (delta < -180) {
      delta += 360;
    }
    _northTween = Tween<double>(begin: from, end: from + delta);
    _northAnim.reset();
    await _northAnim.forward();
    if (mounted) _controller.rotate(0);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Peta')),
      body: Stack(
        children: [
          AppMap(
            tileSource: _source,
            controller: _controller,
            onMapReady: _onMapReady,
            children: [
              MarkerLayer(
                rotate: true,
                markers: [
                  Marker(
                    point: kDefaultMapCenter,
                    width: 44,
                    height: 44,
                    alignment: Alignment.topCenter,
                    rotate: true,
                    child: Icon(
                      Icons.location_on,
                      color: scheme.primary,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 10,
            left: 12,
            right: 12,
            child: _LayerPicker(
              catalog: widget.catalog,
              selectedId: _source.id,
              onSelected: (source) => setState(() => _source = source),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 28,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<double>(
                  valueListenable: _rotation,
                  builder: (context, rotation, _) {
                    if (rotation.abs() < 2) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CompassButton(
                        rotation: rotation,
                        onPressed: _resetNorth,
                      ),
                    );
                  },
                ),
                FloatingActionButton.small(
                  heroTag: 'map-recenter',
                  tooltip: 'Pusat semula',
                  onPressed: !_mapReady
                      ? null
                      : () => _controller.move(
                          kDefaultMapCenter,
                          kDefaultMapZoom,
                        ),
                  child: const Icon(Icons.my_location_outlined),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LayerPicker extends StatelessWidget {
  const _LayerPicker({
    required this.catalog,
    required this.selectedId,
    required this.onSelected,
  });

  final MapTileCatalog catalog;
  final String selectedId;
  final ValueChanged<MapTileSource> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 3,
      color: scheme.surface,
      shadowColor: scheme.shadow.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(28),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: Row(
          children: [
            for (final source in catalog.all)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  avatar: Icon(source.icon, size: 18),
                  label: Text(source.label),
                  selected: selectedId == source.id,
                  onSelected: (_) => onSelected(source),
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  selectedColor: scheme.primary.withValues(alpha: 0.16),
                  side: selectedId == source.id
                      ? BorderSide(color: scheme.primary.withValues(alpha: 0.5))
                      : BorderSide(color: scheme.outlineVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Kompas Google-style: jarum ikut putaran peta, ketuk reset utara.
class _CompassButton extends StatelessWidget {
  const _CompassButton({required this.rotation, required this.onPressed});

  final double rotation;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 3,
      color: scheme.surface,
      shadowColor: scheme.shadow.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: 'Utara ke atas',
        onPressed: onPressed,
        icon: Transform.rotate(
          angle: rotation * math.pi / 180,
          child: Icon(Icons.navigation, color: scheme.primary),
        ),
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
