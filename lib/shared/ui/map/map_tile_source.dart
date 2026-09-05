import 'package:flutter/material.dart';
import 'package:marc/shared/ui/map/map_overlay.dart';

/// User-Agent yang kenal pasti app. Dasar jubin OSM memblok
/// `com.example.app` / string generik - jubin kosong akan terpapar.
const kMapUserAgentPackageName = 'com.hafizbahtiar.marc';

/// Jenis jubin OSM yang disokong. `AppMap` tak kenal enum ni terus -
/// ia cuma terima [MapTileSource], jadi pemanggil boleh tukar
/// implementasi (OSM atau lain) tanpa sentuh widget peta.
/// `bright` dulunya bernama `threeD`. Nama itu mengelirukan - ia tak
/// pernah 3D: ia sentiasa cuma gaya Bright OpenFreeMap.
enum MapTileType { standard, bright, terrain, transport }

/// Kontrak sumber jubin. Widget peta cuma kenal interface ni; OSM
/// standard/3D/terrain/transport ialah implementasi, bukan hardcode
/// dalam `AppMap`.
abstract interface class MapTileSource {
  String get id;
  String get label;
  IconData get icon;

  /// Raster fallback (dan paparan awal) jika gaya vektor gagal dimuat.
  String get urlTemplate;
  List<String> get subdomains;
  int get minZoom;
  int get maxZoom;

  /// Teks ringkas (ujian, log). Paparan guna [attributions].
  String get attribution;

  /// Sumber atribusi dengan pautan. Dasar OSM/penyedia jubin mewajibkan
  /// ini nampak dan boleh diketik.
  List<MapTileAttribution> get attributions;

  /// Gaya MapLibre/OpenFreeMap. Null = raster sahaja.
  ///
  /// Gaya MapLibre (OpenFreeMap): geometri dan ikon sepanjang jalan
  /// ikut putaran kamera; teks kekal tegak.
  String? vectorStyleUri(Brightness brightness);

  /// Lapisan tambahan yang sumber ni mahu dipasang di atas basemap.
  ///
  /// Ini pengikatan antara jenis jubin dan overlaynya - satu baris, bukan
  /// komitmen. Menjadikan overlay satu toggle bebas kemudian bermakna
  /// hantar `overlays` terus ke `AppMap`; tiada apa dalam overlay berubah.
  List<MapOverlay> get overlays;
}

/// Katalog sumber jubin. Halaman ujian/pemanggil senarai variant
/// melalui interface ni, bukan senarai OSM hardcode.
abstract interface class MapTileCatalog {
  List<MapTileSource> get all;
  MapTileSource byType(MapTileType type);
}

/// Satu sumber atribusi peta. [url] null = teks biasa, bukan pautan.
final class MapTileAttribution {
  const MapTileAttribution(this.text, {this.url});

  final String text;
  final String? url;
}
