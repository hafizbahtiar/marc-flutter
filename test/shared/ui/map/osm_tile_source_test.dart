import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/shared/ui/map/map_tile_source.dart';
import 'package:marc/shared/ui/map/osm_tile_source.dart';

void main() {
  const catalog = OsmTileCatalog();

  test('setiap MapTileType ada sumber OSM tersendiri', () {
    final ids = catalog.all.map((s) => s.id).toSet();
    expect(ids, {'standard', 'threeD', 'terrain', 'transport'});
    expect(catalog.all, hasLength(MapTileType.values.length));
  });

  test('byType pulangkan sumber yang padan', () {
    for (final type in MapTileType.values) {
      final source = catalog.byType(type);
      expect(source, isA<OsmMapTileSource>());
      expect(source.id, type.name);
      expect((source as OsmMapTileSource).type, type);
    }
  });

  test('semua variant OSM nyatakan atribusi OpenStreetMap', () {
    for (final source in catalog.all) {
      expect(
        source.attribution.toLowerCase(),
        contains('openstreetmap'),
        reason: '${source.id} hilang atribusi OSM',
      );
      expect(source.urlTemplate, contains('{z}/{x}/{y}'));
    }
  });

  test('url jubin raster fallback tidak sama antara variant', () {
    final urls = catalog.all.map((s) => s.urlTemplate).toSet();
    expect(urls, hasLength(catalog.all.length));
  });

  test('3D/terrain guna subdomain raster, standard OSM tidak', () {
    expect(catalog.byType(MapTileType.standard).subdomains, isEmpty);
    expect(catalog.byType(MapTileType.threeD).subdomains, isNotEmpty);
    expect(catalog.byType(MapTileType.terrain).subdomains, isNotEmpty);
  });

  test('semua variant ada gaya vektor OpenFreeMap (label tegak)', () {
    for (final source in catalog.all) {
      final light = source.vectorStyleUri(Brightness.light);
      expect(light, isNotNull, reason: '${source.id} tiada gaya vektor');
      expect(light, contains('openfreemap.org'));
    }
  });

  test('standard bertukar gaya gelap ikut tema', () {
    final source = catalog.byType(MapTileType.standard);
    expect(
      source.vectorStyleUri(Brightness.light),
      isNot(source.vectorStyleUri(Brightness.dark)),
    );
    expect(source.vectorStyleUri(Brightness.dark), contains('/dark'));
  });
}
