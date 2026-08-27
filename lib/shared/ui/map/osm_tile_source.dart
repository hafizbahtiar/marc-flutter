import 'package:flutter/material.dart';
import 'package:marc/shared/ui/map/map_tile_source.dart';

/// Katalog OSM. Variant vektor = OpenFreeMap (data OSM, tanpa API key).
/// Raster kekal sebagai fallback jika gaya vektor gagal dimuat.
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
/// Gaya vektor OpenFreeMap: label dilukis di ruang skrin (teks kekal
/// tegak bila peta diputar). "3D" di sini ialah gaya Bright (bangunan/
/// guna tanah lebih ketara) — OpenFreeMap tak sediakan style.json 3D
/// extrusion untuk flutter_map.
final class OsmMapTileSource implements MapTileSource {
  const OsmMapTileSource(this.type);

  final MapTileType type;

  @override
  String get id => type.name;

  @override
  String get label => switch (type) {
    MapTileType.standard => 'Standard',
    MapTileType.threeD => '3D',
    MapTileType.terrain => 'Terrain',
    MapTileType.transport => 'Transport',
  };

  @override
  IconData get icon => switch (type) {
    MapTileType.standard => Icons.map_outlined,
    MapTileType.threeD => Icons.view_in_ar_outlined,
    MapTileType.terrain => Icons.terrain_outlined,
    MapTileType.transport => Icons.directions_bus_outlined,
  };

  @override
  String? vectorStyleUri(Brightness brightness) => switch (type) {
    MapTileType.standard =>
      brightness == Brightness.dark
          ? 'https://tiles.openfreemap.org/styles/dark'
          : 'https://tiles.openfreemap.org/styles/liberty',
    MapTileType.threeD => 'https://tiles.openfreemap.org/styles/bright',
    MapTileType.terrain => 'https://tiles.openfreemap.org/styles/fiord',
    MapTileType.transport => 'https://tiles.openfreemap.org/styles/positron',
  };

  @override
  String get urlTemplate => switch (type) {
    MapTileType.standard => 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    MapTileType.threeD =>
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
    MapTileType.terrain => 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
    MapTileType.transport =>
      'https://tileserver.memomaps.de/tilegen/{z}/{x}/{y}.png',
  };

  @override
  List<String> get subdomains => switch (type) {
    MapTileType.standard || MapTileType.transport => const [],
    MapTileType.threeD => const ['a', 'b', 'c', 'd'],
    MapTileType.terrain => const ['a', 'b', 'c'],
  };

  @override
  int get minZoom => 0;

  @override
  int get maxZoom => switch (type) {
    MapTileType.terrain => 17,
    MapTileType.transport => 18,
    MapTileType.standard || MapTileType.threeD => 19,
  };

  @override
  String get attribution => 'OpenStreetMap, OpenFreeMap';

  @override
  bool operator ==(Object other) =>
      other is OsmMapTileSource && other.type == type;

  @override
  int get hashCode => type.hashCode;
}
