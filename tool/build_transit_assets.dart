// Sula GTFS Rapid KL menjadi aset GeoJSON yang dibundel.
//
//   dart run tool/build_transit_assets.dart [--zip <path>]
//
// Ini alat, bukan sebahagian app - ia tak pernah berjalan pada peranti.
// Lihat test/shared/ui/map/docs/TRANSPORTATION.md untuk sumber data,
// perangkap feed, dan bila perlu jalankan semula.
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
/// terbenam; baris yang tak padan bilangan lajur header dilangkau, bukan
/// diteka maknanya.
List<Map<String, String>> _csv(String text) {
  // stop_times.txt datang dengan BOM UTF-8. Tanpa membuangnya, kunci lajur
  // pertama jadi '\uFEFFroute_id' dan setiap carian padanya pulangkan null
  // secara senyap.
  final lines = const LineSplitter()
      .convert(text.startsWith('\uFEFF') ? text.substring(1) : text)
      .where((l) => l.trim().isNotEmpty)
      .toList();
  if (lines.isEmpty) return const [];
  final header = lines.first.trim().split(',');
  final rows = <Map<String, String>>[];
  for (final line in lines.skip(1)) {
    final cells = line.split(',');
    if (cells.length != header.length) continue;
    rows.add({for (var i = 0; i < header.length; i++) header[i]: cells[i]});
  }
  return rows;
}

class TransitFeed {
  TransitFeed._(
    this.linesGeoJson,
    this.stationsGeoJson,
    this.routeCount,
    this.stationCount,
  );

  final String linesGeoJson;
  final String stationsGeoJson;
  final int routeCount;
  final int stationCount;

  static TransitFeed fromCsv({
    required String routes,
    required String trips,
    required String shapes,
    required String stops,
    String stopTimes = '',
    String frequencies = '',
  }) {
    // BRT ialah perkhidmatan bas walaupun ia dalam feed "rapid-rail".
    final rail = <String, Map<String, String>>{
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
      if (t['direction_id'] == '0') {
        shapeOf.putIfAbsent(id, () => t['shape_id']!);
      }
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
            for (final p in pts) [_round(p.$2), _round(p.$3)],
          ],
        },
      });
    }

    final schedules = _schedules(
      rail: rail,
      trips: trips,
      stops: stops,
      stopTimes: stopTimes,
      frequencies: frequencies,
    );

    // Gabung ikut nama: ada satu baris untuk setiap laluan yang berkhidmat,
    // jadi pertukaran berulang. Tanpa ini ia timbunan bulatan bertindih dan
    // tap memulangkan satu laluan rawak.
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
          // Nama penuh, bukan kod sahaja: 'AG' tak bermakna apa-apa kepada
          // orang yang jarang naik.
          'names': [for (final id in ids) rail[id]!['route_long_name']],
          'colors': [for (final id in ids) '#${rail[id]!['route_color']}'],
          // Warna skalar untuk penggayaan: ungkapan MapLibre bersarang ke
          // dalam array properties tak boleh diharap merentas platform.
          'color': '#${rail[ids.first]!['route_color']}',
          'interchange': ids.length > 1,
          // Satu peron boleh diakses bermakna stesen itu boleh dicapai;
          // melaporkan false akan menghalau orang yang sebenarnya boleh guna.
          'oku': rows.any((r) => r['isOKU'] == 'true'),
          if (schedules[entry.key] case final lines? when lines.isNotEmpty)
            'lines': lines,
        },
        'geometry': {
          'type': 'Point',
          'coordinates': [_round(lon), _round(lat)],
        },
      });
    }
    stationFeatures.sort(
      (a, b) => (a['properties']['name'] as String).compareTo(
        b['properties']['name'] as String,
      ),
    );

    String collection(List<Map<String, dynamic>> features) =>
        jsonEncode({'type': 'FeatureCollection', 'features': features});

    return TransitFeed._(
      collection(lineFeatures),
      collection(stationFeatures),
      lineFeatures.length,
      stationFeatures.length,
    );
  }
}

/// Jadual per stesen, dikunci pada nama stesen huruf besar (sama macam
/// kunci gabungan pertukaran).
///
/// PERANGKAP: `stop_times.route_id` guna nama PENDEK (`AGL`, `KJL`, `SPL`)
/// sedangkan `trips.route_id` dan `routes.route_id` guna id asas (`AG`,
/// `KJ`, `PH`). Menyambung ikut `route_id` merentas fail itu memulangkan
/// sifar baris, secara senyap - jadi semuanya disambung melalui `trip_id`.
Map<String, List<Map<String, dynamic>>> _schedules({
  required Map<String, Map<String, String>> rail,
  required String trips,
  required String stops,
  required String stopTimes,
  required String frequencies,
}) {
  if (stopTimes.isEmpty) return const {};

  final trip = <String, Map<String, String>>{
    for (final t in _csv(trips))
      if (rail.containsKey(t['route_id'])) t['trip_id']!: t,
  };
  final stationOf = <String, String>{
    for (final s in _csv(stops))
      if (s['status'] == 'valid')
        s['stop_id']!: s['stop_name']!.trim().toUpperCase(),
  };

  final byTrip = <String, List<Map<String, String>>>{};
  for (final row in _csv(stopTimes)) {
    if (!trip.containsKey(row['trip_id'])) continue;
    (byTrip[row['trip_id']!] ??= []).add(row);
  }

  // Headway berbeza ikut ARAH pada MRT Putrajaya dan LRT Shah Alam, jadi ia
  // dikumpul per trip - bukan per laluan.
  final headways = <String, List<int>>{};
  final serviceEnd = <String, int>{};
  for (final f in _csv(frequencies)) {
    final id = f['trip_id']!;
    if (!trip.containsKey(id)) continue;
    (headways[id] ??= []).add(int.parse(f['headway_secs']!) ~/ 60);
    final end = _seconds(f['end_time']!);
    if (end != null && end > (serviceEnd[id] ?? 0)) serviceEnd[id] = end;
  }

  // (stesen, laluan, arah) -> satu entri per service_id.
  final rows = <String, Map<String, dynamic>>{};
  for (final entry in byTrip.entries) {
    final t = trip[entry.key]!;
    final stopRows = entry.value
      ..sort(
        (a, b) => int.parse(
          a['stop_sequence']!,
        ).compareTo(int.parse(b['stop_sequence']!)),
      );
    final origin = _seconds(stopRows.first['departure_time']!);
    if (origin == null) continue;

    final headsign = t['trip_headsign'] ?? '';
    final terminus = headsign.contains(' to ')
        ? headsign.split(' to ').last.trim()
        : headsign.trim();
    final service = t['service_id'] ?? '';
    final end = serviceEnd[entry.key];
    final hw = headways[entry.key];

    for (final row in stopRows) {
      final station = stationOf[row['stop_id']];
      final departure = _seconds(row['departure_time']!);
      if (station == null || departure == null) continue;

      final key = '$station|${t['route_id']}|${t['direction_id']}';
      final line = rows.putIfAbsent(
        key,
        () => <String, dynamic>{
          'station': station,
          'r': t['route_id'],
          'to': terminus,
          'seq': int.parse(row['stop_sequence']!),
          // Masa tren pertama sama merentas jenis hari dalam feed ini
          // (disemak: 0 daripada 374 entri berbeza), jadi ia disimpan
          // sekali dan bukan per hari.
          'first': _clock(departure),
          'last': <String, String>{},
          'freq': <String, List<int>>{},
        },
      );
      // Tren terakhir ANGGARAN: `frequencies.end_time` ialah bila
      // perkhidmatan tamat di stesen ASAL, jadi tren terakhir di sini
      // ialah masa itu campur perjalanan dari asal. Ia dilabel anggaran
      // dalam UI - bukan dibentang sebagai fakta.
      if (end != null) {
        (line['last'] as Map<String, String>)[service] = _clock(
          end + (departure - origin),
        );
      }
      if (hw != null && hw.isNotEmpty) {
        (line['freq'] as Map<String, List<int>>)[service] = [
          hw.reduce(math.min),
          hw.reduce(math.max),
        ];
      }
    }
  }

  final result = <String, List<Map<String, dynamic>>>{};
  for (final line in rows.values) {
    final station = line.remove('station') as String;
    (result[station] ??= []).add(line);
  }
  for (final list in result.values) {
    list.sort((a, b) {
      final byRoute = (a['r'] as String).compareTo(b['r'] as String);
      return byRoute != 0
          ? byRoute
          : (a['to'] as String).compareTo(b['to'] as String);
    });
  }
  return result;
}

/// `H:MM:SS` -> saat. GTFS benarkan jam melebihi 24 untuk perkhidmatan
/// lepas tengah malam, jadi ini tak boleh guna penghurai masa biasa.
int? _seconds(String value) {
  final parts = value.trim().split(':');
  if (parts.length != 3) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final sec = int.tryParse(parts[2]);
  if (h == null || m == null || sec == null) return null;
  return h * 3600 + m * 60 + sec;
}

/// Saat -> `HH:MM`, dibalut pada tengah malam supaya 24:23 jadi 00:23.
String _clock(int seconds) {
  final wrapped = seconds % 86400;
  final h = (wrapped ~/ 3600).toString().padLeft(2, '0');
  final m = ((wrapped % 3600) ~/ 60).toString().padLeft(2, '0');
  return '$h:$m';
}

/// 5 tempat perpuluhan ialah ~1 m - lebih daripada cukup untuk peta, dan
/// memangkas saiz aset berbanding perpuluhan penuh `double`.
double _round(double value) => (value * 100000).round() / 100000;

double _distance(double aLat, double aLon, double bLat, double bLon) {
  const metresPerDegree = 111320.0;
  final dy = (aLat - bLat) * metresPerDegree;
  final dx = (aLon - bLon) * metresPerDegree * math.cos(aLat * math.pi / 180);
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
    bytes = await response.fold<List<int>>(
      <int>[],
      (acc, chunk) => acc..addAll(chunk),
    );
    client.close();
  }

  final zip = ZipDecoder().decodeBytes(bytes);
  String read(String name) {
    for (final file in zip.files) {
      // Zip data.gov.my mengandungi direktori __MACOSX dengan fail bayangan
      // bernama sama; ambil yang di aras teratas sahaja.
      if (!file.isFile) continue;
      if (file.name.startsWith('__MACOSX')) continue;
      if (file.name.split('/').last == name) {
        return utf8.decode(file.content as List<int>);
      }
    }
    throw TransitFeedException('$name tiada dalam zip');
  }

  final TransitFeed feed;
  try {
    feed = TransitFeed.fromCsv(
      routes: read('routes.txt'),
      trips: read('trips.txt'),
      shapes: read('shapes.txt'),
      stops: read('stops.txt'),
      stopTimes: read('stop_times.txt'),
      frequencies: read('frequencies.txt'),
    );
  } on TransitFeedException catch (e) {
    stderr.writeln(e.message);
    exit(1);
  }

  final dir = Directory('assets/transit')..createSync(recursive: true);
  File('${dir.path}/rail_lines.geojson').writeAsStringSync(feed.linesGeoJson);
  File(
    '${dir.path}/rail_stations.geojson',
  ).writeAsStringSync(feed.stationsGeoJson);

  stdout.writeln(
    'Ditulis ${feed.routeCount} laluan, ${feed.stationCount} stesen ke '
    '${dir.path}/',
  );
}
