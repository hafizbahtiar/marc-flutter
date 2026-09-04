import 'package:flutter/material.dart';
import 'package:marc/shared/ui/map/map_overlay.dart';
import 'package:marc/shared/ui/map/map_tile_source.dart';
import 'package:marc/shared/ui/map/transit_overlay.dart';

/// Katalog OSM. Variant vektor = OpenFreeMap (data OSM, tanpa API key),
/// dilukis oleh MapLibre native.
final class OsmTileCatalog implements MapTileCatalog {
  const OsmTileCatalog();

  @override
  List<MapTileSource> get all => [
    for (final type in MapTileType.values) OsmMapTileSource(type),
  ];

  @override
  MapTileSource byType(MapTileType type) => OsmMapTileSource(type);
}

/// Satu sumber jubin OSM.
///
/// Gaya vektor OpenFreeMap dilukis oleh MapLibre (arrow satu-hala
/// ikut jalan; teks kekal tegak).
final class OsmMapTileSource implements MapTileSource {
  const OsmMapTileSource(this.type);

  final MapTileType type;

  @override
  String get id => type.name;

  @override
  String get label => switch (type) {
    MapTileType.standard => 'Standard',
    MapTileType.bright => 'Bright',
    MapTileType.terrain => 'Terrain',
    MapTileType.transport => 'Transport',
  };

  @override
  IconData get icon => switch (type) {
    MapTileType.standard => Icons.map_outlined,
    MapTileType.bright => Icons.location_city_outlined,
    MapTileType.terrain => Icons.terrain_outlined,
    MapTileType.transport => Icons.directions_bus_outlined,
  };

  @override
  String? vectorStyleUri(Brightness brightness) => switch (type) {
    MapTileType.standard =>
      brightness == Brightness.dark
          ? 'https://tiles.openfreemap.org/styles/dark'
          : 'https://tiles.openfreemap.org/styles/liberty',
    MapTileType.bright => 'https://tiles.openfreemap.org/styles/bright',
    MapTileType.terrain => 'https://tiles.openfreemap.org/styles/fiord',
    MapTileType.transport => 'https://tiles.openfreemap.org/styles/positron',
  };

  @override
  String get urlTemplate => switch (type) {
    MapTileType.standard => 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    MapTileType.bright =>
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
    MapTileType.terrain => 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
    MapTileType.transport =>
      'https://tileserver.memomaps.de/tilegen/{z}/{x}/{y}.png',
  };

  @override
  List<String> get subdomains => switch (type) {
    MapTileType.standard || MapTileType.transport => const [],
    MapTileType.bright => const ['a', 'b', 'c', 'd'],
    MapTileType.terrain => const ['a', 'b', 'c'],
  };

  @override
  int get minZoom => 0;

  @override
  int get maxZoom => switch (type) {
    MapTileType.terrain => 17,
    MapTileType.transport => 18,
    MapTileType.standard || MapTileType.bright => 19,
  };

  @override
  List<MapTileAttribution> get attributions => switch (type) {
    MapTileType.standard => const [
      MapTileAttribution(
        'OpenStreetMap contributors',
        url: 'https://www.openstreetmap.org/copyright',
      ),
      MapTileAttribution('OpenFreeMap', url: 'https://openfreemap.org/'),
    ],
    MapTileType.bright => const [
      MapTileAttribution(
        'OpenStreetMap contributors',
        url: 'https://www.openstreetmap.org/copyright',
      ),
      MapTileAttribution('CARTO', url: 'https://carto.com/attributions'),
      MapTileAttribution('OpenFreeMap', url: 'https://openfreemap.org/'),
    ],
    MapTileType.terrain => const [
      MapTileAttribution(
        'OpenStreetMap contributors',
        url: 'https://www.openstreetmap.org/copyright',
      ),
      MapTileAttribution('SRTM'),
      MapTileAttribution('OpenTopoMap', url: 'https://opentopomap.org'),
      MapTileAttribution('OpenFreeMap', url: 'https://openfreemap.org/'),
    ],
    MapTileType.transport => const [
      MapTileAttribution(
        'OpenStreetMap contributors',
        url: 'https://www.openstreetmap.org/copyright',
      ),
      MapTileAttribution('MeMoMaps', url: 'https://memomaps.de/'),
      MapTileAttribution('OpenFreeMap', url: 'https://openfreemap.org/'),
    ],
  };

  @override
  String get attribution => attributions.map((a) => a.text).join(', ');

  @override
  List<MapOverlay> get overlays => switch (type) {
    // Satu-satunya pengikatan antara jenis jubin dan overlaynya. Layer
    // `transport` ialah gaya positron - basemap kelabu yang melukis rel
    // `#dddddd` dan menyorok transit di bawah zum 16; overlay ni yang
    // menjadikan pilihan itu bermakna.
    MapTileType.transport => const [TransitOverlay()],
    _ => const [],
  };

  @override
  bool operator ==(Object other) =>
      other is OsmMapTileSource && other.type == type;

  @override
  int get hashCode => type.hashCode;
}
