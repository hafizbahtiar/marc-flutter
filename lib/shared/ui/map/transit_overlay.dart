import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:marc/shared/ui/map/map_overlay.dart';
import 'package:marc/shared/ui/map/map_tile_source.dart';

/// Satu stesen rel, seperti yang disimpan dalam properties ciri GeoJSON.
class TransitStation {
  const TransitStation({
    required this.name,
    required this.routes,
    required this.colors,
    required this.interchange,
    required this.oku,
    this.names = const [],
    this.lines = const [],
  });

  /// `queryRenderedFeatures` memulangkan senarai sebagai String JSON pada
  /// sesetengah platform dan sebagai `List` pada yang lain, jadi kedua-dua
  /// bentuk mesti diterima - bukan andaikan satu.
  factory TransitStation.fromProperties(Map<String, dynamic> p) {
    return TransitStation(
      name: '${p['name'] ?? ''}',
      routes: _list(p['routes']),
      names: _list(p['names']),
      colors: _list(p['colors']),
      interchange: _bool(p['interchange']),
      oku: _bool(p['oku']),
      lines: _lines(p['lines']),
    );
  }

  final String name;

  /// Kod laluan, cth `AG`.
  final List<String> routes;

  /// Nama penuh sejajar dengan [routes], cth `LRT Ampang Line`.
  final List<String> names;
  final List<String> colors;
  final bool interchange;

  /// Satu entri setiap laluan+arah yang berhenti di sini.
  final List<TransitStationLine> lines;

  /// Akses OKU. Benar bila MANA-MANA peron gabungan boleh diakses.
  final bool oku;

  static List<String> _list(Object? value) => switch (value) {
    final List<dynamic> l => [for (final e in l) '$e'],
    final String s when s.startsWith('[') => [
      for (final e in jsonDecode(s) as List) '$e',
    ],
    _ => const [],
  };

  static bool _bool(Object? value) => value == true || value == 'true';

  static List<TransitStationLine> _lines(Object? value) {
    final raw = switch (value) {
      final List<dynamic> l => l,
      final String s when s.startsWith('[') => jsonDecode(s) as List,
      _ => const [],
    };
    return [
      for (final e in raw)
        if (e is Map) TransitStationLine.fromJson(Map<String, dynamic>.from(e)),
    ];
  }

  /// Warna bagi kod laluan, atau null bila tak dikenali.
  String? colorOf(String route) {
    final index = routes.indexOf(route);
    return index >= 0 && index < colors.length ? colors[index] : null;
  }

  /// Nama penuh bagi kod laluan, jatuh balik ke kod itu sendiri.
  String labelOf(String route) {
    final index = routes.indexOf(route);
    return index >= 0 && index < names.length ? names[index] : route;
  }
}

/// Satu arah satu laluan pada satu stesen.
class TransitStationLine {
  const TransitStationLine({
    required this.route,
    required this.terminus,
    required this.first,
    required this.last,
    required this.frequency,
  });

  factory TransitStationLine.fromJson(Map<String, dynamic> json) {
    return TransitStationLine(
      route: '${json['r'] ?? ''}',
      terminus: '${json['to'] ?? ''}',
      first: json['first'] as String?,
      last: {
        if (json['last'] case final Map<dynamic, dynamic> m)
          for (final e in m.entries) '${e.key}': '${e.value}',
      },
      frequency: {
        if (json['freq'] case final Map<dynamic, dynamic> m)
          for (final e in m.entries)
            if (e.value case final List<dynamic> v when v.length == 2)
              '${e.key}': (
                int.tryParse('${v[0]}') ?? 0,
                int.tryParse('${v[1]}') ?? 0,
              ),
      },
    );
  }

  final String route;

  /// Hentian akhir ke arah ni, cth `Sentul Timur`.
  final String terminus;

  /// `HH:MM`. Sama merentas jenis hari dalam feed ini.
  final String? first;

  /// service_id -> `HH:MM`. ANGGARAN: diterbitkan daripada masa tamat
  /// perkhidmatan di stesen asal campur masa perjalanan ke sini, jadi ia
  /// mesti dilabel sebagai anggaran di mana-mana ia dipapar.
  final Map<String, String> last;

  /// service_id -> (minit minimum, minit maksimum).
  final Map<String, (int, int)> frequency;
}

/// Laluan dan stesen rel Rapid KL, dari GTFS data.gov.my yang disula
/// menjadi aset oleh `tool/build_transit_assets.dart`.
///
/// Warna ditulis ke dalam setiap ciri masa bina, jadi penggayaan dipacu
/// data (`['get', 'color']`) dan masa jalan tak perlu jadual carian.
class TransitOverlay implements MapOverlay {
  const TransitOverlay({this.bundle});

  static const linesAsset = 'assets/transit/rail_lines.geojson';
  static const stationsAsset = 'assets/transit/rail_stations.geojson';

  static const linesSourceId = 'transit-lines-src';
  static const stationsSourceId = 'transit-stations-src';
  static const linesLayerId = 'transit-lines';
  static const stationsLayerId = 'transit-stations';
  static const labelsLayerId = 'transit-labels';

  /// Layer yang boleh dikenakan hit-test untuk tap stesen. Label tak
  /// disenarai: mengetik teks yang meleret jauh dari bulatannya akan
  /// membuka stesen yang pengguna tak tuju.
  static const stationLayerIds = [stationsLayerId];

  /// Null = `rootBundle`. Ujian menyuntik bundle dalam-ingatan.
  final AssetBundle? bundle;

  @override
  String get id => 'transit';

  @override
  List<MapTileAttribution> get attributions => const [
    MapTileAttribution('data.gov.my', url: 'https://data.gov.my/'),
    MapTileAttribution('Prasarana'),
  ];

  @override
  Future<void> install(MapStyleController style) async {
    final assets = bundle ?? rootBundle;
    final lines = jsonDecode(await assets.loadString(linesAsset));
    final stations = jsonDecode(await assets.loadString(stationsAsset));

    await style.addGeoJsonSource(linesSourceId, lines as Map<String, dynamic>);
    await style.addGeoJsonSource(
      stationsSourceId,
      stations as Map<String, dynamic>,
    );

    // Susunan penting: garis, bulatan, label. Terbalikkan dan stesen
    // tertimbus di bawah garisnya sendiri.
    await style.addLineLayer(
      linesSourceId,
      linesLayerId,
      const MapLineStyle(
        color: ['get', 'color'],
        // Lebih tebal daripada jalan pada zum rendah: seluruh sebab overlay
        // ni wujud ialah supaya rangkaian terbaca sebelum paras jalan.
        width: [9, 2, 13, 4, 17, 7],
        opacity: 0.9,
        minZoom: 8,
      ),
    );
    await style.addCircleLayer(
      stationsSourceId,
      stationsLayerId,
      const MapCircleStyle(
        color: '#ffffff',
        radius: [11, 3, 14, 5, 17, 7],
        // Skalar `color` (laluan pertama), bukan `colors[0]`: ungkapan
        // bersarang ke dalam array properties tak boleh diharap merentas
        // platform, jadi alat menulis skalar itu masa bina.
        strokeColor: ['get', 'color'],
        strokeWidth: 2.4,
        minZoom: 11,
      ),
    );
    await style.addSymbolLayer(
      stationsSourceId,
      labelsLayerId,
      const MapSymbolStyle(
        textField: ['get', 'name'],
        textSize: 11,
        color: '#1c1c1c',
        haloColor: '#ffffff',
        haloWidth: 1.4,
        offsetY: 1.3,
        minZoom: 13,
      ),
    );
  }
}
