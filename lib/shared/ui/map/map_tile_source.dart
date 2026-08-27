import 'package:flutter/material.dart';

/// User-Agent yang kenal pasti app. Dasar jubin OSM memblok
/// `com.example.app` / string generik — jubin kosong akan terpapar.
const kMapUserAgentPackageName = 'com.hafizbahtiar.marc';

/// Jenis jubin OSM yang disokong. `AppMap` tak kenal enum ni terus —
/// ia cuma terima [MapTileSource], jadi pemanggil boleh tukar
/// implementasi (OSM atau lain) tanpa sentuh widget peta.
enum MapTileType { standard, threeD, terrain, transport }

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
  String get attribution;

  /// Gaya MapLibre/OpenFreeMap. Null = raster sahaja.
  ///
  /// Vektor dilukis semula setiap frame: geometri peta berputar, teks
  /// dan ikon kekal tegak (macam Google Maps). Raster OSM membakar
  /// label ke dalam PNG, jadi teks ikut pusing.
  String? vectorStyleUri(Brightness brightness);
}

/// Katalog sumber jubin. Halaman ujian/pemanggil senarai variant
/// melalui interface ni, bukan senarai OSM hardcode.
abstract interface class MapTileCatalog {
  List<MapTileSource> get all;
  MapTileSource byType(MapTileType type);
}
