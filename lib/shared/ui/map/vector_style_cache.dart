import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:marc/shared/ui/map/map_tile_source.dart';

/// Cache gaya vektor proses-lebar. `StyleReader.read()` mahal (style.json
/// + sprite + TileJSON); tanpa cache, tukar chip/rebuild `AppMap` unduh
/// semula. Gaya TAK di-dispose di sini — buka semula peta mesti instant.
final class VectorStyleCache {
  VectorStyleCache._();
  static final VectorStyleCache instance = VectorStyleCache._();

  final _inflight = <String, Future<vt.Style>>{};

  Future<vt.Style> load(String uri, {required bool cacheToDisk}) {
    return _inflight.putIfAbsent(uri, () async {
      try {
        return await vt.StyleReader(
          uri: uri,
          cache: cacheToDisk,
          headers: const {'User-Agent': kMapUserAgentPackageName},
        ).read();
      } catch (_) {
        _inflight.remove(uri);
        rethrow;
      }
    });
  }
}
