import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/build_transit_assets.dart';

const _routes =
    'route_id,agency_id,route_short_name,route_long_name,route_desc,route_type,route_color,route_text_color,category,status\n'
    'KJ,rapidrail,KJL,LRT Kelana Jaya Line,a ~ b,1,D50032,FFFFFF,LRT,valid\n'
    'MR,rapidrail,MRL,KL Monorail Line,c ~ d,1,84bd00,FFFFFF,MRL,valid\n'
    'BRT,rapidrail,BRT,BRT Sunway Line,e ~ f,0,115740,FFFFFF,BRT,valid\n';

const _trips =
    'route_id,service_id,trip_id,trip_headsign,direction_id,shape_id\n'
    'KJ,MonFri,KJ_0,From a to b,0,shp_KJ_0\n'
    'KJ,MonFri,KJ_1,From b to a,1,shp_KJ_1\n'
    'MR,MonFri,MR_0,From c to d,0,shp_MR_0\n'
    'BRT,MonFri,BRT_0,From e to f,0,shp_BRT_0\n';

const _shapes =
    'shape_id,shape_pt_lon,shape_pt_lat,shape_pt_sequence\n'
    'shp_KJ_0,101.10,3.10,1\n'
    'shp_KJ_0,101.20,3.20,2\n'
    'shp_KJ_1,101.20,3.20,1\n'
    'shp_KJ_1,101.10,3.10,2\n'
    'shp_MR_0,101.30,3.30,1\n'
    'shp_MR_0,101.40,3.40,2\n'
    'shp_BRT_0,101.50,3.50,1\n'
    'shp_BRT_0,101.60,3.60,2\n';

/// TITIWANGSA muncul pada dua laluan ~15 m berbeza: kes pertukaran.
const _stops =
    'stop_id,stop_name,stop_lat,stop_lon,category,route_id,geometry,isOKU,status,search\n'
    'KJ1,TITIWANGSA,3.100000,101.100000,LRT,KJ,[object Object],true,valid,x\n'
    'MR1,TITIWANGSA,3.100100,101.100100,MRL,MR,[object Object],false,valid,x\n'
    'KJ2,BANGSAR,3.200000,101.200000,LRT,KJ,[object Object],true,valid,x\n'
    'KJ9,LAMA,3.900000,101.900000,LRT,KJ,[object Object],true,invalid,x\n'
    'BR1,SUNWAY,3.500000,101.500000,BRT,BRT,[object Object],true,valid,x\n';

/// BOM di hadapan, dan `route_id` guna nama PENDEK (KJL) sedangkan trips
/// guna id asas (KJ) - kedua-duanya betul-betul macam feed sebenar.
const _stopTimes =
    '\uFEFFroute_id,direction_id,trip_id,arrival_time,departure_time,stop_id,stop_sequence\n'
    'KJL,0,KJ_0,6:00:00,6:00:00,KJ1,1\n'
    'KJL,0,KJ_0,6:10:00,6:10:30,KJ2,2\n'
    'MRL,0,MR_0,7:00:00,7:00:00,MR1,1\n';

const _frequencies =
    'trip_id,start_time,end_time,headway_secs\n'
    'KJ_0,6:00:00,9:00:00,180\n'
    'KJ_0,9:00:00,23:00:00,600\n'
    'MR_0,7:00:00,24:00:00,300\n';

TransitFeed build({String? stops, bool schedule = true}) => TransitFeed.fromCsv(
  routes: _routes,
  trips: _trips,
  shapes: _shapes,
  stops: stops ?? _stops,
  stopTimes: schedule ? _stopTimes : '',
  frequencies: schedule ? _frequencies : '',
);

Map<String, dynamic> stationNamed(TransitFeed feed, String name) {
  final stations = jsonDecode(feed.stationsGeoJson) as Map<String, dynamic>;
  return ((stations['features'] as List).firstWhere(
            (f) => (f as Map)['properties']['name'] == name,
          )
          as Map)['properties']
      as Map<String, dynamic>;
}

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
    final kj =
        (lines['features'] as List).firstWhere(
              (f) => (f as Map)['properties']['id'] == 'KJ',
            )
            as Map;
    expect(
      kj['geometry']['coordinates'],
      [
        [101.1, 3.1],
        [101.2, 3.2],
      ],
      reason:
          'arah 1 ialah bentuk yang sama terbalik - melukisnya '
          'bermakna setiap laluan dilukis dua kali bertindih',
    );
  });

  test('warna laluan diambil dari feed, dengan awalan hash', () {
    final lines = jsonDecode(build().linesGeoJson) as Map<String, dynamic>;
    final kj =
        (lines['features'] as List).firstWhere(
              (f) => (f as Map)['properties']['id'] == 'KJ',
            )
            as Map;
    expect(kj['properties']['color'], '#D50032');
  });

  test('stesen pertukaran digabung, laluan dikumpul', () {
    final stations =
        jsonDecode(build().stationsGeoJson) as Map<String, dynamic>;
    final features = stations['features'] as List;
    expect(features.length, 2, reason: 'TITIWANGSA x2 -> 1, BANGSAR -> 1');

    final titi =
        features.firstWhere(
              (f) => (f as Map)['properties']['name'] == 'TITIWANGSA',
            )
            as Map;
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
    final stations =
        jsonDecode(build().stationsGeoJson) as Map<String, dynamic>;
    final names = [
      for (final f in stations['features'] as List)
        (f as Map)['properties']['name'] as String,
    ];
    expect(names, isNot(contains('SUNWAY')), reason: 'BRT bukan rel');
    expect(names, isNot(contains('LAMA')), reason: 'status != valid');
  });

  test('isOKU benar bila MANA-MANA peron gabungan boleh diakses', () {
    final stations =
        jsonDecode(build().stationsGeoJson) as Map<String, dynamic>;
    final titi =
        (stations['features'] as List).firstWhere(
              (f) => (f as Map)['properties']['name'] == 'TITIWANGSA',
            )
            as Map;
    expect(
      titi['properties']['oku'],
      isTrue,
      reason:
          'satu peron boleh diakses bermakna stesen itu boleh dicapai; '
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

  test('nama penuh laluan disertakan, bukan kod sahaja', () {
    // 'KJ' tak bermakna apa-apa kepada orang yang jarang naik.
    expect(stationNamed(build(), 'BANGSAR')['names'], ['LRT Kelana Jaya Line']);
  });

  test('jadual disambung melalui trip_id, bukan route_id', () {
    // stop_times.route_id ialah 'KJL'; trips/routes guna 'KJ'. Menyambung
    // ikut route_id memulangkan sifar baris SECARA SENYAP, jadi jadual
    // kosong di sini bermakna perangkap itu kembali.
    final lines = stationNamed(build(), 'BANGSAR')['lines'] as List;
    expect(lines, hasLength(1));

    final line = lines.single as Map<String, dynamic>;
    expect(line['r'], 'KJ');
    expect(line['seq'], 2);
    expect(line['first'], '06:10', reason: 'masa berlepas di stesen ini');
    expect(line['to'], 'b', reason: 'hentian akhir dihurai dari headsign');
  });

  test(
    'tren terakhir ialah tamat perkhidmatan campur perjalanan dari asal',
    () {
      // Perkhidmatan tamat 23:00 di ASAL; BANGSAR 10.5 minit menyusur laluan.
      final line =
          (stationNamed(build(), 'BANGSAR')['lines'] as List).single
              as Map<String, dynamic>;
      expect((line['last'] as Map)['MonFri'], '23:10');
    },
  );

  test('kekerapan diringkas jadi julat min-maks setiap jenis hari', () {
    final line =
        (stationNamed(build(), 'BANGSAR')['lines'] as List).single
            as Map<String, dynamic>;
    expect((line['freq'] as Map)['MonFri'], [3, 10]);
  });

  test('masa lepas tengah malam dibalut, bukan dipapar sebagai 24:00', () {
    // MR_0 tamat 24:00:00 - GTFS benarkan jam >= 24 untuk perkhidmatan
    // lewat malam, dan penghurai masa biasa akan tersedak padanya.
    final line =
        (stationNamed(build(), 'TITIWANGSA')['lines'] as List).firstWhere(
              (l) => (l as Map)['r'] == 'MR',
            )
            as Map<String, dynamic>;
    expect((line['last'] as Map)['MonFri'], '00:00');
  });

  test('tiada stop_times bermakna tiada blok jadual, bukan ranap', () {
    expect(
      stationNamed(build(schedule: false), 'BANGSAR').containsKey('lines'),
      isFalse,
    );
  });
}
