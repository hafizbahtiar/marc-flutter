import 'package:flutter_test/flutter_test.dart';
import 'package:marc/shared/ui/map/map_overlay.dart';
import 'package:marc/shared/ui/map/map_tile_source.dart';

/// Merekod panggilan dan bukan bercakap dengan MapLibre. Inilah sebab
/// `MapStyleController` wujud: overlay boleh diuji tanpa peta native.
class RecordingStyle implements MapStyleController {
  final sources = <String>[];
  final layers = <String>[];

  @override
  Future<void> addGeoJsonSource(String id, Map<String, dynamic> geojson) async {
    sources.add(id);
  }

  @override
  Future<void> addLineLayer(String s, String id, MapLineStyle style) async {
    layers.add(id);
  }

  @override
  Future<void> addCircleLayer(String s, String id, MapCircleStyle style) async {
    layers.add(id);
  }

  @override
  Future<void> addSymbolLayer(String s, String id, MapSymbolStyle style) async {
    layers.add(id);
  }
}

class _Overlay implements MapOverlay {
  @override
  String get id => 'test';

  @override
  List<MapTileAttribution> get attributions => const [
    MapTileAttribution('Test'),
  ];

  @override
  Future<void> install(MapStyleController style) async {
    await style.addGeoJsonSource('src', const {'type': 'FeatureCollection'});
    await style.addLineLayer('src', 'lines', const MapLineStyle());
  }
}

void main() {
  test('overlay memasang melalui MapStyleController, bukan MapLibre', () async {
    final style = RecordingStyle();
    await _Overlay().install(style);

    expect(style.sources, ['src']);
    expect(style.layers, ['lines']);
  });
}
