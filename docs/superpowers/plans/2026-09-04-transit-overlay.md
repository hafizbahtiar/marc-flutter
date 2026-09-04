# Klang Valley Transit Overlay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Draw the seven Klang Valley rail lines and their stations on the map in official Rapid KL colours, bound to the "Transport" tile type through a reusable overlay abstraction.

**Architecture:** A `dart run` tool distils the data.gov.my Prasarana GTFS feed into two bundled GeoJSON assets. At runtime a `MapOverlay` — which sees only our own `MapStyleController`, never a MapLibre type — installs GeoJSON sources and line/circle/symbol layers when the style loads. `MapTileSource.overlays` binds the transit overlay to the `transport` source; every other source returns an empty list.

**Tech Stack:** Dart/Flutter, `maplibre_gl` 0.27.0, `archive` (dev-only, for the build tool).

**Spec:** `docs/superpowers/specs/2026-09-04-transit-overlay-design.md`

## Global Constraints

- **Do not commit.** Stage changes with `git add` only. The working tree holds unrelated uncommitted work — stage only files this plan names.
- Code comments in Bahasa Malaysia, matching the surrounding module. Comments explain *why*, never restate *what*.
- `permission_handler` stays pinned at `12.0.3`; do not add any dependency that raises the Android compileSdk ceiling above 35. `archive` is pure Dart and dev-only, so it is safe.
- Assets are listed individually in `pubspec.yaml` — directory entries are **not** recursive.
- Route colours come from the feed verbatim. Never hand-type a colour.
- `annotationConsumeTapEvents` must stay at its default; `MapLibreMap` asserts `length > 0`.
- Never use `pumpAndSettle` on a widget test containing a map.

---

### Task 1: GTFS distillation tool

**Files:**
- Create: `tool/build_transit_assets.dart`
- Create: `test/tool/build_transit_assets_test.dart`
- Modify: `pubspec.yaml` (add `archive: ^4.0.9` to `dev_dependencies`)

**Interfaces:**
- Consumes: nothing.
- Produces: `TransitFeed.fromCsv({required String routes, required String trips, required String shapes, required String stops})` returning a `TransitFeed` with `String linesGeoJson` and `String stationsGeoJson`. Throws `TransitFeedException` when an interchange cluster spans > 300 m.

- [ ] **Step 1: Write the failing tests**

Pure-function tests over inline CSV — no network, no zip, no file IO.

```dart
// test/tool/build_transit_assets_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import '../../tool/build_transit_assets.dart';

const _routes =
    'route_id,agency_id,route_short_name,route_long_name,route_desc,route_type,route_color,route_text_color,category,status\n'
    'KJ,rapidrail,KJL,LRT Kelana Jaya Line,a ~ b,1,D50032,FFFFFF,LRT,valid\n'
    'MR,rapidrail,MRL,KL Monorail Line,c ~ d,1,84bd00,FFFFFF,MRL,valid\n'
    'BRT,rapidrail,BRT,BRT Sunway Line,e ~ f,0,115740,FFFFFF,BRT,valid\n';

const _trips = 'route_id,service_id,trip_id,trip_headsign,direction_id,shape_id\n'
    'KJ,MonFri,KJ_0,x,0,shp_KJ_0\n'
    'KJ,MonFri,KJ_1,y,1,shp_KJ_1\n'
    'MR,MonFri,MR_0,x,0,shp_MR_0\n'
    'BRT,MonFri,BRT_0,x,0,shp_BRT_0\n';

const _shapes = 'shape_id,shape_pt_lon,shape_pt_lat,shape_pt_sequence\n'
    'shp_KJ_0,101.10,3.10,1\n'
    'shp_KJ_0,101.20,3.20,2\n'
    'shp_KJ_1,101.20,3.20,1\n'
    'shp_KJ_1,101.10,3.10,2\n'
    'shp_MR_0,101.30,3.30,1\n'
    'shp_MR_0,101.40,3.40,2\n'
    'shp_BRT_0,101.50,3.50,1\n'
    'shp_BRT_0,101.60,3.60,2\n';

// TITIWANGSA muncul pada dua laluan ~15 m berbeza: kes pertukaran.
const _stops =
    'stop_id,stop_name,stop_lat,stop_lon,category,route_id,geometry,isOKU,status,search\n'
    'KJ1,TITIWANGSA,3.100000,101.100000,LRT,KJ,[object Object],true,valid,x\n'
    'MR1,TITIWANGSA,3.100100,101.100100,MRL,MR,[object Object],false,valid,x\n'
    'KJ2,BANGSAR,3.200000,101.200000,LRT,KJ,[object Object],true,valid,x\n'
    'KJ9,LAMA,3.900000,101.900000,LRT,KJ,[object Object],true,invalid,x\n'
    'BR1,SUNWAY,3.500000,101.500000,BRT,BRT,[object Object],true,valid,x\n';

TransitFeed build({String? stops}) => TransitFeed.fromCsv(
      routes: _routes,
      trips: _trips,
      shapes: _shapes,
      stops: stops ?? _stops,
    );

void main() {
  test('BRT dibuang - ia bas, bukan rel', () {
    final lines = jsonDecode(build().linesGeoJson) as Map<String, dynamic>;
    final ids = [
      for (final f in lines['features'] as List)
        (f as Map)['properties']['id'] as String,
    ];
    expect(ids, unorderedEquals(['KJ', 'MR']));
  });

  test('satu bentuk setiap laluan - arah 0, bukan kedua-dua', () {
    final lines = jsonDecode(build().linesGeoJson) as Map<String, dynamic>;
    final kj = (lines['features'] as List).firstWhere(
      (f) => (f as Map)['properties']['id'] == 'KJ',
    ) as Map;
    expect(
      kj['geometry']['coordinates'],
      [
        [101.1, 3.1],
        [101.2, 3.2],
      ],
      reason: 'arah 1 ialah bentuk yang sama terbalik - melukisnya '
          'bermakna setiap laluan dilukis dua kali bertindih',
    );
  });

  test('warna laluan diambil dari feed, dengan awalan hash', () {
    final lines = jsonDecode(build().linesGeoJson) as Map<String, dynamic>;
    final kj = (lines['features'] as List).firstWhere(
      (f) => (f as Map)['properties']['id'] == 'KJ',
    ) as Map;
    expect(kj['properties']['color'], '#D50032');
  });

  test('stesen pertukaran digabung, laluan dikumpul', () {
    final stations = jsonDecode(build().stationsGeoJson) as Map<String, dynamic>;
    final features = stations['features'] as List;
    expect(features.length, 2, reason: 'TITIWANGSA x2 -> 1, BANGSAR -> 1');

    final titi = features.firstWhere(
      (f) => (f as Map)['properties']['name'] == 'TITIWANGSA',
    ) as Map;
    expect(titi['properties']['routes'], ['KJ', 'MR']);
    expect(titi['properties']['colors'], ['#D50032', '#84bd00']);
    expect(titi['properties']['interchange'], isTrue);
    expect(
      (titi['geometry']['coordinates'] as List)[1],
      closeTo(3.10005, 1e-6),
      reason: 'kedudukan ialah sentroid baris yang digabung',
    );
  });

  test('stesen bukan-rel dan status tak sah dibuang', () {
    final stations = jsonDecode(build().stationsGeoJson) as Map<String, dynamic>;
    final names = [
      for (final f in stations['features'] as List)
        (f as Map)['properties']['name'] as String,
    ];
    expect(names, isNot(contains('SUNWAY')), reason: 'BRT bukan rel');
    expect(names, isNot(contains('LAMA')), reason: 'status != valid');
  });

  test('isOKU benar bila MANA-MANA peron gabungan boleh diakses', () {
    final stations = jsonDecode(build().stationsGeoJson) as Map<String, dynamic>;
    final titi = (stations['features'] as List).firstWhere(
      (f) => (f as Map)['properties']['name'] == 'TITIWANGSA',
    ) as Map;
    expect(
      titi['properties']['oku'],
      isTrue,
      reason: 'satu peron boleh diakses bermakna stesen itu boleh dicapai; '
          'melaporkan false akan menghalau orang yang sebenarnya boleh guna',
    );
  });

  test('gabungan yang merentangi lebih 300 m gagal dengan kuat', () {
    // Dua stesen BERLAINAN berkongsi nama. Gabungan senyap akan letak
    // stesen di tempat salah - lebih teruk daripada bina yang gagal.
    const far =
        'stop_id,stop_name,stop_lat,stop_lon,category,route_id,geometry,isOKU,status,search\n'
        'KJ1,KEMBAR,3.100000,101.100000,LRT,KJ,[object Object],true,valid,x\n'
        'MR1,KEMBAR,3.200000,101.200000,MRL,MR,[object Object],true,valid,x\n';
    expect(
      () => build(stops: far),
      throwsA(
        isA<TransitFeedException>().having(
          (e) => e.message,
          'message',
          contains('KEMBAR'),
        ),
      ),
    );
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/tool/build_transit_assets_test.dart`
Expected: FAIL — `tool/build_transit_assets.dart` does not exist.

- [ ] **Step 3: Add the dev dependency**

In `pubspec.yaml` under `dev_dependencies:`, after `url_launcher_platform_interface`:

```yaml
  # Nyahzip GTFS dalam tool/build_transit_assets.dart. Dev sahaja - ia tak
  # pernah masuk APK, dan ia Dart tulen jadi ia tak sentuh siling
  # compileSdk yang dijaga oleh permission_handler di atas.
  archive: ^4.0.9
```

Run: `flutter pub get`

- [ ] **Step 4: Write the tool**

The file has two halves: a pure, testable `TransitFeed` and a `main()` that does IO. Only the pure half is imported by tests.

```dart
// tool/build_transit_assets.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:archive/archive.dart';

/// Ambang jarak untuk gabungan pertukaran. Kelompok paling teruk dalam feed
/// semasa menyimpang 147 m dari sentroidnya, jadi ini kira-kira 2x ruang
/// lega - ia pengawal, bukan formaliti.
const kMergeRadiusMetres = 300.0;

const kFeedUrl =
    'https://api.data.gov.my/gtfs-static/prasarana?category=rapid-rail-kl';

/// Feed memberi masalah yang manusia mesti selesaikan, bukan yang skrip
/// patut teka jalan keluarnya.
class TransitFeedException implements Exception {
  TransitFeedException(this.message);
  final String message;
  @override
  String toString() => 'TransitFeedException: $message';
}

/// Penghurai CSV minimum. GTFS Prasarana tiada medan berpetik atau koma
/// terbenam, jadi pemisahan mudah memadai - dan gagal dengan kuat kalau
/// andaian itu berubah.
List<Map<String, String>> _csv(String text) {
  final lines = const LineSplitter()
      .convert(text)
      .where((l) => l.trim().isNotEmpty)
      .toList();
  if (lines.isEmpty) return const [];
  final header = lines.first.split(',');
  return [
    for (final line in lines.skip(1))
      if (line.split(',') case final cells when cells.length == header.length)
        {for (var i = 0; i < header.length; i++) header[i]: cells[i]},
  ];
}

class TransitFeed {
  TransitFeed._(this.linesGeoJson, this.stationsGeoJson, this.routeCount,
      this.stationCount);

  final String linesGeoJson;
  final String stationsGeoJson;
  final int routeCount;
  final int stationCount;

  static TransitFeed fromCsv({
    required String routes,
    required String trips,
    required String shapes,
    required String stops,
  }) {
    // BRT ialah perkhidmatan bas walaupun ia dalam feed "rapid-rail".
    final rail = {
      for (final r in _csv(routes))
        if (r['category'] != 'BRT' && r['status'] != 'invalid')
          r['route_id']!: r,
    };
    if (rail.isEmpty) {
      throw TransitFeedException('tiada laluan rel dalam routes.txt');
    }

    // Arah 0 sahaja: arah 1 ialah bentuk sama terbalik, jadi melukis
    // kedua-dua bermakna setiap laluan dilukis dua kali bertindih.
    final shapeOf = <String, String>{};
    for (final t in _csv(trips)) {
      final id = t['route_id']!;
      if (!rail.containsKey(id)) continue;
      if (t['direction_id'] == '0') shapeOf.putIfAbsent(id, () => t['shape_id']!);
    }

    final points = <String, List<(int, double, double)>>{};
    for (final s in _csv(shapes)) {
      (points[s['shape_id']!] ??= []).add((
        int.parse(s['shape_pt_sequence']!),
        double.parse(s['shape_pt_lon']!),
        double.parse(s['shape_pt_lat']!),
      ));
    }

    final lineFeatures = <Map<String, dynamic>>[];
    for (final entry in rail.entries) {
      final shapeId = shapeOf[entry.key];
      if (shapeId == null) {
        throw TransitFeedException('laluan ${entry.key} tiada bentuk arah 0');
      }
      final pts = points[shapeId];
      if (pts == null || pts.length < 2) {
        throw TransitFeedException('bentuk $shapeId terlalu pendek');
      }
      pts.sort((a, b) => a.$1.compareTo(b.$1));
      lineFeatures.add({
        'type': 'Feature',
        'properties': {
          'id': entry.key,
          'name': entry.value['route_long_name'],
          'short': entry.value['route_short_name'],
          'category': entry.value['category'],
          'color': '#${entry.value['route_color']}',
        },
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            for (final p in pts) [p.$2, p.$3],
          ],
        },
      });
    }

    // Gabung ikut nama: satu baris setiap laluan yang berkhidmat, jadi
    // pertukaran berulang. Tanpa ini ia timbunan bulatan bertindih dan tap
    // memulangkan satu laluan rawak.
    final grouped = <String, List<Map<String, String>>>{};
    for (final s in _csv(stops)) {
      if (s['status'] != 'valid') continue;
      if (!rail.containsKey(s['route_id'])) continue;
      (grouped[s['stop_name']!.trim().toUpperCase()] ??= []).add(s);
    }

    final stationFeatures = <Map<String, dynamic>>[];
    for (final entry in grouped.entries) {
      final rows = entry.value;
      final lats = [for (final r in rows) double.parse(r['stop_lat']!)];
      final lons = [for (final r in rows) double.parse(r['stop_lon']!)];
      final lat = lats.reduce((a, b) => a + b) / lats.length;
      final lon = lons.reduce((a, b) => a + b) / lons.length;

      for (var i = 0; i < rows.length; i++) {
        final metres = _distance(lats[i], lons[i], lat, lon);
        if (metres > kMergeRadiusMetres) {
          throw TransitFeedException(
            'stesen "${entry.key}" merentangi ${metres.toStringAsFixed(0)} m - '
            'dua stesen berlainan mungkin berkongsi nama, dan gabungan senyap '
            'akan meletakkan satu daripadanya di tempat salah',
          );
        }
      }

      final ids = {for (final r in rows) r['route_id']!}.toList()..sort();
      stationFeatures.add({
        'type': 'Feature',
        'properties': {
          'name': rows.first['stop_name'],
          'routes': ids,
          'colors': [for (final id in ids) '#${rail[id]!['route_color']}'],
          'interchange': ids.length > 1,
          // Satu peron boleh diakses bermakna stesen itu boleh dicapai;
          // melaporkan false akan menghalau orang yang sebenarnya boleh guna.
          'oku': rows.any((r) => r['isOKU'] == 'true'),
        },
        'geometry': {
          'type': 'Point',
          'coordinates': [_round(lon), _round(lat)],
        },
      });
    }
    stationFeatures.sort(
      (a, b) => (a['properties']['name'] as String)
          .compareTo(b['properties']['name'] as String),
    );

    String fc(List<Map<String, dynamic>> f) =>
        jsonEncode({'type': 'FeatureCollection', 'features': f});

    return TransitFeed._(
      fc(lineFeatures),
      fc(stationFeatures),
      lineFeatures.length,
      stationFeatures.length,
    );
  }
}

/// 5 tempat perpuluhan ialah ~1 m - lebih daripada cukup untuk peta, dan
/// memangkas saiz aset berbanding perpuluhan penuh double.
double _round(double v) => (v * 100000).round() / 100000;

double _distance(double aLat, double aLon, double bLat, double bLon) {
  const metresPerDegree = 111320.0;
  final dy = (aLat - bLat) * metresPerDegree;
  final dx =
      (aLon - bLon) * metresPerDegree * math.cos(aLat * math.pi / 180);
  return math.sqrt(dx * dx + dy * dy);
}

Future<void> main(List<String> args) async {
  final zipArg = args.indexOf('--zip');
  final List<int> bytes;
  if (zipArg != -1 && zipArg + 1 < args.length) {
    bytes = await File(args[zipArg + 1]).readAsBytes();
  } else {
    stdout.writeln('Muat turun $kFeedUrl');
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse(kFeedUrl));
    final response = await request.close();
    if (response.statusCode != 200) {
      stderr.writeln('HTTP ${response.statusCode} dari data.gov.my');
      exit(1);
    }
    bytes = await response
        .fold<List<int>>([], (acc, chunk) => acc..addAll(chunk));
    client.close();
  }

  final zip = ZipDecoder().decodeBytes(bytes);
  String read(String name) {
    final file = zip.files.firstWhere(
      (f) => f.isFile && f.name.split('/').last == name,
      orElse: () => throw TransitFeedException('$name tiada dalam zip'),
    );
    return utf8.decode(file.content as List<int>);
  }

  final TransitFeed feed;
  try {
    feed = TransitFeed.fromCsv(
      routes: read('routes.txt'),
      trips: read('trips.txt'),
      shapes: read('shapes.txt'),
      stops: read('stops.txt'),
    );
  } on TransitFeedException catch (e) {
    stderr.writeln(e.message);
    exit(1);
  }

  final dir = Directory('assets/transit')..createSync(recursive: true);
  File('${dir.path}/rail_lines.geojson').writeAsStringSync(feed.linesGeoJson);
  File('${dir.path}/rail_stations.geojson')
      .writeAsStringSync(feed.stationsGeoJson);

  stdout.writeln(
    'Ditulis ${feed.routeCount} laluan, ${feed.stationCount} stesen ke '
    '${dir.path}/',
  );
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/tool/build_transit_assets_test.dart`
Expected: PASS (7 tests)

- [ ] **Step 6: Generate the real assets**

Run: `dart run tool/build_transit_assets.dart`
Expected output: `Ditulis 7 laluan, 132 stesen ke assets/transit/`

Verify: `ls -l assets/transit/` shows `rail_lines.geojson` (~71 KB) and `rail_stations.geojson` (~20 KB).

- [ ] **Step 7: Register the assets**

In `pubspec.yaml`, in the `assets:` list after `- assets/splash/`:

```yaml
    # Laluan/stesen rel Rapid KL, disula dari GTFS data.gov.my oleh
    # `dart run tool/build_transit_assets.dart`. Lihat
    # test/shared/ui/map/docs/TRANSPORTATION.md.
    - assets/transit/rail_lines.geojson
    - assets/transit/rail_stations.geojson
```

Run: `flutter pub get`

- [ ] **Step 8: Stage**

```bash
git add pubspec.yaml pubspec.lock tool/build_transit_assets.dart \
  test/tool/build_transit_assets_test.dart assets/transit/
```

---

### Task 2: Overlay abstraction

**Files:**
- Create: `lib/shared/ui/map/map_overlay.dart`
- Create: `test/shared/ui/map/map_overlay_test.dart`
- Modify: `lib/shared/ui/map/map_tile_source.dart` (add `overlays` to `MapTileSource`)
- Modify: `lib/shared/ui/map/osm_tile_source.dart` (implement `overlays`)
- Modify: `test/shared/ui/map/app_map_test.dart` (`_FakeSource` gains `overlays`)

**Interfaces:**
- Consumes: `MapTileAttribution` from `map_tile_source.dart`.
- Produces:
  - `abstract interface class MapOverlay { String get id; List<MapTileAttribution> get attributions; Future<void> install(MapStyleController style); }`
  - `abstract interface class MapStyleController` with `Future<void> addGeoJsonSource(String id, Map<String, dynamic> geojson)`, `Future<void> addLineLayer(String sourceId, String layerId, MapLineStyle style)`, `Future<void> addCircleLayer(String sourceId, String layerId, MapCircleStyle style)`, `Future<void> addSymbolLayer(String sourceId, String layerId, MapSymbolStyle style)`.
  - Value types `MapLineStyle`, `MapCircleStyle`, `MapSymbolStyle` — plain data, no MapLibre types.
  - `MapTileSource.overlays` returning `List<MapOverlay>`.

- [ ] **Step 1: Write the failing test**

```dart
// test/shared/ui/map/map_overlay_test.dart
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
  List<MapTileAttribution> get attributions =>
      const [MapTileAttribution('Test')];

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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/ui/map/map_overlay_test.dart`
Expected: FAIL — `map_overlay.dart` does not exist.

- [ ] **Step 3: Write `map_overlay.dart`**

```dart
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
  Future<void> addLineLayer(String sourceId, String layerId, MapLineStyle style);
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

/// Ungkapan MapLibre sebagai data. `color` dan sepertinya boleh jadi warna
/// literal ('#ff0000') atau ungkapan dipacu data (`['get', 'color']`).
class MapLineStyle {
  const MapLineStyle({
    this.color = '#000000',
    this.width = const [1.0],
    this.opacity = 1.0,
    this.minZoom,
  });

  final Object color;

  /// Pasangan [zum, lebar] untuk interpolasi. Satu nilai = lebar tetap.
  final List<double> width;
  final double opacity;
  final double? minZoom;
}

class MapCircleStyle {
  const MapCircleStyle({
    this.color = '#ffffff',
    this.radius = const [4.0],
    this.strokeColor = '#000000',
    this.strokeWidth = 1.0,
    this.minZoom,
  });

  final Object color;
  final List<double> radius;
  final Object strokeColor;
  final double strokeWidth;
  final double? minZoom;
}

class MapSymbolStyle {
  const MapSymbolStyle({
    required this.textField,
    this.textSize = 11,
    this.color = '#000000',
    this.haloColor = '#ffffff',
    this.haloWidth = 1.2,
    this.offsetY = 1.2,
    this.minZoom,
  });

  /// Ungkapan MapLibre, cth `['get', 'name']`.
  final Object textField;
  final double textSize;
  final Object color;
  final Object haloColor;
  final double haloWidth;
  final double offsetY;
  final double? minZoom;
}
```

- [ ] **Step 4: Add `overlays` to the tile-source contract**

In `lib/shared/ui/map/map_tile_source.dart`, add the import and the member:

```dart
import 'package:marc/shared/ui/map/map_overlay.dart';
```

Inside `abstract interface class MapTileSource`, after `vectorStyleUri`:

```dart
  /// Lapisan tambahan yang sumber ni mahu dipasang di atas basemap.
  ///
  /// Ini pengikatan antara jenis jubin dan overlaynya - satu baris, bukan
  /// komitmen. Menjadikan overlay satu toggle bebas kemudian bermakna
  /// hantar `overlays` terus ke `AppMap`; tiada apa dalam overlay berubah.
  List<MapOverlay> get overlays;
```

In `lib/shared/ui/map/osm_tile_source.dart`, add to `OsmMapTileSource`:

```dart
  @override
  List<MapOverlay> get overlays => const [];
```

(Task 3 changes `transport` to return the transit overlay.)

In `test/shared/ui/map/app_map_test.dart`, add to `_FakeSource`:

```dart
  @override
  List<MapOverlay> get overlays => const [];
```

with `import 'package:marc/shared/ui/map/map_overlay.dart';`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/shared/ui/map && flutter analyze lib/shared/ui/map`
Expected: all PASS, no analyzer issues.

- [ ] **Step 6: Stage**

```bash
git add lib/shared/ui/map/map_overlay.dart lib/shared/ui/map/map_tile_source.dart \
  lib/shared/ui/map/osm_tile_source.dart test/shared/ui/map/map_overlay_test.dart \
  test/shared/ui/map/app_map_test.dart
```

---

### Task 3: Transit overlay

**Files:**
- Create: `lib/shared/ui/map/transit_overlay.dart`
- Create: `test/shared/ui/map/transit_overlay_test.dart`
- Modify: `lib/shared/ui/map/osm_tile_source.dart` (`transport` returns the overlay)
- Modify: `test/shared/ui/map/osm_tile_source_test.dart`

**Interfaces:**
- Consumes: `MapOverlay`, `MapStyleController`, `MapLineStyle`, `MapCircleStyle`, `MapSymbolStyle` from Task 2.
- Produces: `TransitOverlay({AssetBundle? bundle})` with `static const linesLayerId = 'transit-lines'`, `stationsLayerId = 'transit-stations'`, `labelsLayerId = 'transit-labels'`, and `static const stationLayerIds = [stationsLayerId]` for hit-testing in Task 5. Also `class TransitStation` with `String name`, `List<String> routes`, `List<String> colors`, `bool interchange`, `bool oku`, and `TransitStation.fromProperties(Map<String, dynamic>)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/shared/ui/map/transit_overlay_test.dart
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/shared/ui/map/map_overlay.dart';
import 'package:marc/shared/ui/map/transit_overlay.dart';

class _RecordingStyle implements MapStyleController {
  final sources = <String, Map<String, dynamic>>{};
  final layerOrder = <String>[];

  @override
  Future<void> addGeoJsonSource(String id, Map<String, dynamic> g) async {
    sources[id] = g;
  }

  @override
  Future<void> addLineLayer(String s, String id, MapLineStyle style) async {
    layerOrder.add(id);
  }

  @override
  Future<void> addCircleLayer(String s, String id, MapCircleStyle style) async {
    layerOrder.add(id);
  }

  @override
  Future<void> addSymbolLayer(String s, String id, MapSymbolStyle style) async {
    layerOrder.add(id);
  }
}

/// Bundle dalam-ingatan supaya ujian tak bergantung pada aset sebenar -
/// ujian ini tentang pemasangan, bukan tentang data Rapid KL.
class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.values);
  final Map<String, String> values;

  @override
  Future<ByteData> load(String key) async {
    final v = values[key];
    if (v == null) throw FlutterError('aset tiada: $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(v)));
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final v = values[key];
    if (v == null) throw FlutterError('aset tiada: $key');
    return v;
  }
}

const _lines = '{"type":"FeatureCollection","features":['
    '{"type":"Feature","properties":{"id":"KJ","color":"#D50032"},'
    '"geometry":{"type":"LineString","coordinates":[[101.1,3.1],[101.2,3.2]]}}]}';

const _stations = '{"type":"FeatureCollection","features":['
    '{"type":"Feature","properties":{"name":"BANGSAR","routes":["KJ"],'
    '"colors":["#D50032"],"interchange":false,"oku":true},'
    '"geometry":{"type":"Point","coordinates":[101.1,3.1]}}]}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  _RecordingStyle install() {
    final style = _RecordingStyle();
    return style;
  }

  test('memasang sumber dan layer dari aset', () async {
    final style = install();
    await TransitOverlay(
      bundle: _FakeBundle({
        TransitOverlay.linesAsset: _lines,
        TransitOverlay.stationsAsset: _stations,
      }),
    ).install(style);

    expect(style.sources.keys, containsAll(['transit-lines-src', 'transit-stations-src']));
    expect(
      style.layerOrder,
      [
        TransitOverlay.linesLayerId,
        TransitOverlay.stationsLayerId,
        TransitOverlay.labelsLayerId,
      ],
      reason: 'garis dahulu, kemudian bulatan, kemudian label - kalau tidak '
          'stesen tertimbus di bawah garisnya sendiri',
    );
  });

  test('atribusi menamakan penyedia data', () {
    final texts = TransitOverlay().attributions.map((a) => a.text);
    expect(texts, containsAll(['data.gov.my', 'Prasarana']));
  });

  test('TransitStation dihurai dari properties ciri', () {
    final station = TransitStation.fromProperties(const {
      'name': 'TITIWANGSA',
      'routes': ['AG', 'MR'],
      'colors': ['#e57200', '#84bd00'],
      'interchange': true,
      'oku': false,
    });

    expect(station.name, 'TITIWANGSA');
    expect(station.routes, ['AG', 'MR']);
    expect(station.colors, ['#e57200', '#84bd00']);
    expect(station.interchange, isTrue);
    expect(station.oku, isFalse);
  });

  test('TransitStation menerima properties berkod JSON', () {
    // queryRenderedFeatures memulangkan senarai sebagai String JSON pada
    // sesetengah platform, bukan List Dart.
    final station = TransitStation.fromProperties(const {
      'name': 'BANGSAR',
      'routes': '["KJ"]',
      'colors': '["#D50032"]',
      'interchange': false,
      'oku': true,
    });

    expect(station.routes, ['KJ']);
    expect(station.colors, ['#D50032']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/ui/map/transit_overlay_test.dart`
Expected: FAIL — `transit_overlay.dart` does not exist.

- [ ] **Step 3: Write `transit_overlay.dart`**

```dart
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
  });

  final String name;
  final List<String> routes;
  final List<String> colors;
  final bool interchange;

  /// Akses OKU. Benar bila MANA-MANA peron gabungan boleh diakses.
  final bool oku;

  /// `queryRenderedFeatures` memulangkan senarai sebagai String JSON pada
  /// sesetengah platform dan sebagai List pada yang lain, jadi kedua-dua
  /// bentuk mesti diterima - bukan andaikan satu.
  static List<String> _list(Object? value) => switch (value) {
        final List<dynamic> l => [for (final e in l) '$e'],
        final String s when s.startsWith('[') =>
          [for (final e in jsonDecode(s) as List) '$e'],
        _ => const [],
      };

  factory TransitStation.fromProperties(Map<String, dynamic> p) {
    return TransitStation(
      name: '${p['name'] ?? ''}',
      routes: _list(p['routes']),
      colors: _list(p['colors']),
      interchange: p['interchange'] == true || p['interchange'] == 'true',
      oku: p['oku'] == true || p['oku'] == 'true',
    );
  }
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

  /// Layer yang boleh dikenakan hit-test untuk tap stesen.
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
        width: [9, 2.0, 13, 4.0, 17, 7.0],
        opacity: 0.9,
        minZoom: 8,
      ),
    );
    await style.addCircleLayer(
      stationsSourceId,
      stationsLayerId,
      const MapCircleStyle(
        color: '#ffffff',
        // Pertukaran lebih besar - stesen empat laluan tak patut dibaca
        // sama macam hujung talian.
        radius: [11, 3.0, 14, 5.0, 17, 7.0],
        strokeColor: ['get', ['at', 0, ['get', 'colors']]],
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
```

> **Note for the implementer:** `strokeColor` above uses a nested
> expression. If MapLibre rejects `['at', 0, ['get', 'colors']]` at
> runtime, fall back to writing a scalar `color` property per station in
> Task 1's tool (first route's colour) and use `['get', 'color']` here.
> Verify on device in Task 6 and take the fallback if the stroke renders
> black.

- [ ] **Step 4: Bind the overlay to `transport`**

In `lib/shared/ui/map/osm_tile_source.dart`, replace the `overlays` getter added in Task 2:

```dart
  @override
  List<MapOverlay> get overlays => switch (type) {
    // Satu-satunya pengikatan antara jenis jubin dan overlaynya.
    MapTileType.transport => const [TransitOverlay()],
    _ => const [],
  };
```

Add `import 'package:marc/shared/ui/map/transit_overlay.dart';`.

- [ ] **Step 5: Add the tile-source test**

Append to `test/shared/ui/map/osm_tile_source_test.dart`:

```dart
  test('hanya transport membawa overlay transit', () {
    const catalog = OsmTileCatalog();
    for (final source in catalog.all) {
      final ids = source.overlays.map((o) => o.id);
      if (source.id == MapTileType.transport.name) {
        expect(ids, ['transit']);
      } else {
        expect(ids, isEmpty, reason: '${source.id} tak patut ada overlay');
      }
    }
  });
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/shared/ui/map && flutter analyze lib/shared/ui/map`
Expected: all PASS.

- [ ] **Step 7: Stage**

```bash
git add lib/shared/ui/map/transit_overlay.dart lib/shared/ui/map/osm_tile_source.dart \
  test/shared/ui/map/transit_overlay_test.dart test/shared/ui/map/osm_tile_source_test.dart
```

---

### Task 4: Wire overlays into AppMap

**Files:**
- Modify: `lib/shared/ui/map/app_map.dart`
- Modify: `test/shared/ui/map/map_page_test.dart`

**Interfaces:**
- Consumes: `MapOverlay`, `MapStyleController` and the style value types (Task 2); `MapTileSource.overlays` (Task 2).
- Produces: `_MapLibreStyleController implements MapStyleController` (private, in `app_map.dart`); `AppMap` installs `widget.tileSource.overlays` on style load and merges their attributions into `MapAttribution`.

- [ ] **Step 1: Write the failing test**

Append to `test/shared/ui/map/map_page_test.dart`:

```dart
  testWidgets('atribusi overlay muncul hanya bila transport dipilih', (
    tester,
  ) async {
    await pumpMap(tester);

    List<String> attributionTexts() => tester
        .widget<MapAttribution>(find.byType(MapAttribution))
        .attributions
        .map((a) => a.text)
        .toList();

    expect(
      attributionTexts(),
      isNot(contains('data.gov.my')),
      reason: 'Standard tak guna data transit, jadi jangan kreditkannya',
    );

    await tester.tap(find.byTooltip('Jenis peta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transport'));
    await tester.pumpAndSettle();

    expect(attributionTexts(), containsAll(['data.gov.my', 'Prasarana']));
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/ui/map/map_page_test.dart`
Expected: FAIL — `data.gov.my` not found in attributions.

- [ ] **Step 3: Merge overlay attributions in `AppMap.build`**

In `lib/shared/ui/map/app_map.dart`, replace the `MapAttribution` construction inside `build`:

```dart
          if (widget.showAttribution)
            Positioned(
              left: 12,
              bottom: 12,
              child: MapAttribution(attributions: _attributions()),
            ),
```

and add the method to `_AppMapState`:

```dart
  /// Kredit basemap DAN setiap overlay terpasang. Lesen penyedia data
  /// mewajibkan kredit nampak; menggabungnya di sini bermakna ia muncul
  /// tepat bila overlay hidup dan hilang bersamanya.
  List<MapTileAttribution> _attributions() => [
    ...widget.tileSource.attributions,
    for (final overlay in widget.tileSource.overlays) ...overlay.attributions,
  ];
```

- [ ] **Step 4: Add the style controller and install on style load**

Add to `lib/shared/ui/map/app_map.dart` (imports: `map_overlay.dart`):

```dart
/// Menterjemah nilai [MapStyleController] kepada panggilan MapLibre.
///
/// Ini satu-satunya tempat ungkapan gaya bertemu jenis native, jadi overlay
/// kekal boleh diuji tanpa peta.
class _MapLibreStyleController implements MapStyleController {
  _MapLibreStyleController(this._native);

  final ml.MapLibreMapController _native;

  /// `[z1, v1, z2, v2, ...]` jadi interpolasi linear; satu nilai jadi
  /// pemalar.
  static Object _stops(List<double> values) {
    if (values.length < 4) return values.first;
    return [
      'interpolate',
      ['linear'],
      ['zoom'],
      ...values,
    ];
  }

  @override
  Future<void> addGeoJsonSource(String id, Map<String, dynamic> geojson) =>
      _native.addGeoJsonSource(id, geojson);

  @override
  Future<void> addLineLayer(String sourceId, String layerId, MapLineStyle s) =>
      _native.addLineLayer(
        sourceId,
        layerId,
        ml.LineLayerProperties(
          lineColor: s.color,
          lineWidth: _stops(s.width),
          lineOpacity: s.opacity,
          lineJoin: 'round',
          lineCap: 'round',
        ),
        minzoom: s.minZoom,
      );

  @override
  Future<void> addCircleLayer(
    String sourceId,
    String layerId,
    MapCircleStyle s,
  ) => _native.addCircleLayer(
    sourceId,
    layerId,
    ml.CircleLayerProperties(
      circleColor: s.color,
      circleRadius: _stops(s.radius),
      circleStrokeColor: s.strokeColor,
      circleStrokeWidth: s.strokeWidth,
    ),
    minzoom: s.minZoom,
  );

  @override
  Future<void> addSymbolLayer(
    String sourceId,
    String layerId,
    MapSymbolStyle s,
  ) => _native.addSymbolLayer(
    sourceId,
    layerId,
    ml.SymbolLayerProperties(
      textField: s.textField,
      textSize: s.textSize,
      textColor: s.color,
      textHaloColor: s.haloColor,
      textHaloWidth: s.haloWidth,
      textOffset: [0, s.offsetY],
      textAnchor: 'top',
      textFont: const ['Noto Sans Regular'],
      textAllowOverlap: false,
    ),
    minzoom: s.minZoom,
  );
}
```

Then replace `_onStyleLoaded`:

```dart
  Future<void> _onStyleLoaded() async {
    unawaited(_projectMarkers());
    await _installOverlays();
  }

  /// Dipasang di sini, bukan `onMapCreated`: sumber dan layer perlukan gaya
  /// yang sudah dimuat. Menukar jenis peta menukar `styleString`, yang
  /// membuatkan MapLibre buang semua layer dan tembak semula callback ni -
  /// jadi pemasangan semula datang percuma dan tiada perobohan diperlukan.
  Future<void> _installOverlays() async {
    final native = _native;
    if (native == null) return;
    final style = _MapLibreStyleController(native);
    for (final overlay in widget.tileSource.overlays) {
      try {
        await overlay.install(style);
      } catch (error, stack) {
        // Satu overlay rosak tak patut menjatuhkan peta - basemap masih
        // berguna tanpanya.
        debugPrint('[map] overlay ${overlay.id} gagal dipasang: $error\n$stack');
      }
    }
  }
```

Change the `onStyleLoadedCallback` wiring to `onStyleLoadedCallback: () => unawaited(_onStyleLoaded())`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/shared/ui/map && flutter analyze lib/shared/ui/map`
Expected: all PASS.

- [ ] **Step 6: Stage**

```bash
git add lib/shared/ui/map/app_map.dart test/shared/ui/map/map_page_test.dart
```

---

### Task 5: Station tap sheet

**Files:**
- Create: `lib/shared/ui/map/transit_station_sheet.dart`
- Create: `test/shared/ui/map/transit_station_sheet_test.dart`
- Modify: `lib/shared/ui/map/app_map.dart` (expose `onFeatureTap`)
- Modify: `lib/shared/ui/map/map_page.dart` (open the sheet)

**Interfaces:**
- Consumes: `TransitStation` (Task 3); `TransitOverlay.stationLayerIds` (Task 3).
- Produces: `Future<void> showTransitStationSheet(BuildContext, TransitStation)`; `AppMap.onFeatureTap` of type `void Function(List<String> layerIds, Map<String, dynamic> properties)` — actually `AppMap.onStationTap` of type `void Function(TransitStation station)` is too specific for a generic widget, so `AppMap` exposes `queryLayers` + `onFeatureTap`:
  - `final List<String> tapLayerIds;`
  - `final void Function(Map<String, dynamic> properties)? onFeatureTap;`

- [ ] **Step 1: Write the failing test**

```dart
// test/shared/ui/map/transit_station_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/shared/ui/map/transit_overlay.dart';
import 'package:marc/shared/ui/map/transit_station_sheet.dart';

Future<void> show(WidgetTester tester, TransitStation station) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => showTransitStationSheet(context, station),
            child: const Text('buka'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('buka'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('papar nama dan setiap laluan yang berkhidmat', (tester) async {
    await show(
      tester,
      const TransitStation(
        name: 'TITIWANGSA',
        routes: ['AG', 'MR'],
        colors: ['#e57200', '#84bd00'],
        interchange: true,
        oku: true,
      ),
    );

    expect(find.text('TITIWANGSA'), findsOneWidget);
    expect(find.text('AG'), findsOneWidget);
    expect(find.text('MR'), findsOneWidget);
  });

  testWidgets('status OKU dinyatakan kedua-dua arah', (tester) async {
    await show(
      tester,
      const TransitStation(
        name: 'X',
        routes: ['KJ'],
        colors: ['#D50032'],
        interchange: false,
        oku: false,
      ),
    );

    // Ketiadaan tanda tak boleh bermakna "tak diketahui" DAN "tiada akses"
    // serentak - orang yang perlukannya kena dapat jawapan jelas.
    expect(find.textContaining('Tiada akses OKU'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/ui/map/transit_station_sheet_test.dart`
Expected: FAIL — `transit_station_sheet.dart` does not exist.

- [ ] **Step 3: Write the sheet**

```dart
import 'package:flutter/material.dart';
import 'package:marc/shared/ui/map/transit_overlay.dart';

/// Kad butiran stesen.
///
/// Sengaja BUKAN `showAppActionSheet`: komponen itu senarai tindakan yang
/// pengguna pilih antaranya, dan ini kad maklumat tanpa tindakan. Guna
/// semula ia bermakna melawan kontraknya.
Future<void> showTransitStationSheet(
  BuildContext context,
  TransitStation station,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => _StationCard(station: station),
  );
}

class _StationCard extends StatelessWidget {
  const _StationCard({required this.station});

  final TransitStation station;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              station.name,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (station.interchange) ...[
              const SizedBox(height: 2),
              Text(
                'Stesen pertukaran',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < station.routes.length; i++)
                  _RouteChip(
                    label: station.routes[i],
                    color: i < station.colors.length
                        ? _parseColor(station.colors[i])
                        : scheme.primary,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  station.oku ? Icons.accessible : Icons.not_accessible,
                  size: 18,
                  color: station.oku ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                // Dinyatakan kedua-dua arah: ketiadaan tanda tak boleh
                // bermakna "tak diketahui" dan "tiada akses" serentak.
                Text(
                  station.oku ? 'Akses OKU tersedia' : 'Tiada akses OKU',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteChip extends StatelessWidget {
  const _RouteChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: _onColor(color),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

Color _parseColor(String hex) {
  final value = hex.replaceFirst('#', '');
  return Color(int.parse('ff$value', radix: 16));
}

/// Warna laluan Rapid KL merangkumi kuning cerah (Putrajaya `#FFCD00`) dan
/// merah gelap (Sri Petaling `#76232f`), jadi teks putih tetap akan hilang
/// pada sebahagiannya.
Color _onColor(Color background) =>
    background.computeLuminance() > 0.5 ? Colors.black : Colors.white;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/shared/ui/map/transit_station_sheet_test.dart`
Expected: PASS

- [ ] **Step 5: Add feature tap to `AppMap`**

In `lib/shared/ui/map/app_map.dart`, add constructor params and fields:

```dart
    this.tapLayerIds = const [],
    this.onFeatureTap,
```

```dart
  /// Id layer yang boleh dikenakan hit-test bila peta diketik.
  final List<String> tapLayerIds;

  /// Properties ciri teratas pada titik yang diketik. Widget ni tak tahu
  /// apa properties itu bermakna - pemanggil yang tafsirkannya.
  final void Function(Map<String, dynamic> properties)? onFeatureTap;
```

Replace the `onMapClick` wiring:

```dart
      onMapClick: (widget.onTap == null && widget.onFeatureTap == null)
          ? null
          : (point, latLng) => unawaited(_onClick(point, latLng)),
```

and add:

```dart
  Future<void> _onClick(math.Point<double> point, ml.LatLng latLng) async {
    final native = _native;
    final onFeature = widget.onFeatureTap;
    if (native != null && onFeature != null && widget.tapLayerIds.isNotEmpty) {
      // Kotak kecil, bukan satu piksel: sasaran sentuh jari jauh lebih
      // besar daripada bulatan stesen, dan menuntut ketepatan piksel
      // bermakna kebanyakan tap terlepas.
      const slop = 12.0;
      final features = await native.queryRenderedFeaturesInRect(
        Rect.fromCenter(
          center: Offset(point.x.toDouble(), point.y.toDouble()),
          width: slop * 2,
          height: slop * 2,
        ),
        widget.tapLayerIds,
        null,
      );
      if (features.isNotEmpty) {
        final properties = (features.first as Map)['properties'];
        if (properties is Map) {
          onFeature(Map<String, dynamic>.from(properties));
          return;
        }
      }
    }
    widget.onTap?.call(_fromMl(latLng));
  }
```

Add `import 'dart:math' as math;` if not present.

- [ ] **Step 6: Wire it in `map_page.dart`**

```dart
          AppMap(
            tileSource: _source,
            controller: _controller,
            onMapReady: _onMapReady,
            showUserLocation: _locationGranted,
            onUserLocation: _onUserLocation,
            tapLayerIds: TransitOverlay.stationLayerIds,
            onFeatureTap: _onStationTap,
          ),
```

```dart
  void _onStationTap(Map<String, dynamic> properties) {
    if (!mounted) return;
    showTransitStationSheet(
      context,
      TransitStation.fromProperties(properties),
    );
  }
```

with imports for `transit_overlay.dart` and `transit_station_sheet.dart`.

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test test/shared/ui/map && flutter analyze lib`
Expected: all PASS, no analyzer issues.

- [ ] **Step 8: Stage**

```bash
git add lib/shared/ui/map/transit_station_sheet.dart lib/shared/ui/map/app_map.dart \
  lib/shared/ui/map/map_page.dart test/shared/ui/map/transit_station_sheet_test.dart
```

---

### Task 6: Verify on device

**Files:** none — this task changes nothing unless it finds a defect.

- [ ] **Step 1: Full suite**

Run: `flutter test`
Expected: PASS except the pre-existing `about_page_test.dart` failure ("En. Ezri"), which comes from unrelated uncommitted work in the tree.

- [ ] **Step 2: Build and install**

```bash
flutter build apk --debug --flavor prod
/opt/homebrew/share/android-commandlinetools/platform-tools/adb install -r \
  build/app/outputs/flutter-apk/app-prod-debug.apk
```

(`flutter build apk` prints "Gradle build failed to produce an .apk file" because of product flavors; the APK is nevertheless written. See `test/shared/ui/map/docs/STACK.md`.)

- [ ] **Step 3: Check on device**

Open Peta → layer button → Transport. Confirm:
- seven coloured lines, each in its Rapid KL colour;
- station circles from ~z11 with **coloured strokes, not black** — a black stroke means the nested `['at', 0, ['get','colors']]` expression was rejected, so take the fallback documented in Task 3 Step 3;
- station labels from ~z13;
- tapping a station opens the sheet with the right lines;
- the attribution button lists data.gov.my and Prasarana;
- switching to Standard and back re-installs the layers.

- [ ] **Step 4: Stage any fixes**

```bash
git add -u lib/shared/ui/map test/shared/ui/map
```

---

## Self-Review

**Spec coverage.** Build pipeline → Task 1. Asset registration → Task 1 Step 7. Overlay abstraction and `MapTileSource.overlays` → Task 2. Transit overlay, rendering, and the transport binding → Task 3. Lifecycle and attribution merging → Task 4. Station tap → Task 5. Device verification → Task 6. The KTM gap and the licence question are documented, not implemented, as the spec states.

**Placeholder scan.** No TBD/TODO. The one conditional in Task 3 Step 3 names the exact fallback and the exact symptom that triggers it, and Task 6 Step 3 checks for that symptom.

**Type consistency.** `MapStyleController`'s four methods keep identical signatures across Tasks 2, 3 and 4. `TransitOverlay.stationLayerIds` is defined in Task 3 and consumed in Task 5. `TransitStation.fromProperties` is defined in Task 3, tested there, and consumed in Task 5. `AppMap.tapLayerIds` / `onFeatureTap` are declared and consumed within Task 5.
