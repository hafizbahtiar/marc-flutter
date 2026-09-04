import 'package:marc/shared/ui/map/map_tile_source.dart';

/// Lapisan tambahan yang dilukis di ATAS basemap.
///
/// Overlay tak pernah nampak jenis MapLibre - ia bercakap dengan
/// [MapStyleController], jadi ia boleh diuji dengan double yang merekod
/// panggilan, tanpa peta native.
///
/// Tiada `remove()` dengan sengaja: menukar jenis peta menukar
/// `styleString`, MapLibre buang SEMUA layer dan tembak semula
/// `onStyleLoadedCallback`, jadi pemasangan semula datang percuma. Laluan
/// perobohan akan jadi kod mati yang terpesong daripada kebenaran.
abstract interface class MapOverlay {
  String get id;

  /// Kredit penyedia data. `AppMap` cantumkannya dengan atribusi basemap,
  /// jadi ia muncul tepat bila overlay hidup.
  List<MapTileAttribution> get attributions;

  Future<void> install(MapStyleController style);
}

/// Apa yang overlay dibenarkan buat pada gaya. Sengaja sempit.
abstract interface class MapStyleController {
  Future<void> addGeoJsonSource(String id, Map<String, dynamic> geojson);

  Future<void> addLineLayer(
    String sourceId,
    String layerId,
    MapLineStyle style,
  );

  Future<void> addCircleLayer(
    String sourceId,
    String layerId,
    MapCircleStyle style,
  );

  Future<void> addSymbolLayer(
    String sourceId,
    String layerId,
    MapSymbolStyle style,
  );
}

/// Gaya sebagai data biasa. [color] dan sepertinya boleh jadi warna literal
/// (`'#ff0000'`) atau ungkapan dipacu data (`['get', 'color']`) - jenisnya
/// `Object` sebab MapLibre terima kedua-dua, dan memaksa `String` di sini
/// akan menghalang penggayaan dipacu data sepenuhnya.
class MapLineStyle {
  const MapLineStyle({
    this.color = '#000000',
    this.width = const [1],
    this.opacity = 1.0,
    this.minZoom,
  });

  final Object color;

  /// Pasangan rata `[zum, lebar, zum, lebar, ...]` untuk interpolasi. Satu
  /// nilai bermakna lebar tetap.
  final List<double> width;
  final double opacity;
  final double? minZoom;
}

class MapCircleStyle {
  const MapCircleStyle({
    this.color = '#ffffff',
    this.radius = const [4],
    this.strokeColor = '#000000',
    this.strokeWidth = 1.0,
    this.minZoom,
  });

  final Object color;

  /// Pasangan rata `[zum, jejari, ...]`, sama macam [MapLineStyle.width].
  final List<double> radius;
  final Object strokeColor;
  final double strokeWidth;
  final double? minZoom;
}

class MapSymbolStyle {
  const MapSymbolStyle({
    required this.textField,
    this.font = const ['Noto Sans Regular'],
    this.textSize = 11,
    this.color = '#000000',
    this.haloColor = '#ffffff',
    this.haloWidth = 1.2,
    this.offsetY = 1.2,
    this.minZoom,
  });

  /// Ungkapan MapLibre, cth `['get', 'name']`.
  final Object textField;

  /// Nama fontstack, dan ia MESTI wujud dalam glyph gaya itu. Lalai
  /// spesifikasi MapLibre ialah `Open Sans Regular` / `Arial Unicode MS
  /// Regular`, dan OpenFreeMap TIDAK menyajikan kedua-duanya - ia hanya ada
  /// Noto Sans Regular/Bold/Italic. Meninggalkan medan ni bermakna teks
  /// gagal senyap: layer dipasang, tiada ralat, tiada label.
  final List<String> font;

  final double textSize;
  final Object color;
  final Object haloColor;
  final double haloWidth;
  final double offsetY;
  final double? minZoom;
}
