import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/shared/ui/map/app_map.dart';
import 'package:marc/shared/ui/map/map_search_bar.dart';
import 'package:marc/shared/ui/map/place_search.dart';

/// Bentuk sebenar respons Photon untuk "klcc", dipendekkan. Ciri kedua
/// sengaja tiada geometri dan ciri ketiga tiada nama - Photon memulangkan
/// kedua-dua bentuk itu, dan penghurai tak boleh tersedak padanya.
const _photonKlcc = {
  'type': 'FeatureCollection',
  'features': [
    {
      'type': 'Feature',
      'properties': {
        'osm_key': 'railway',
        'osm_value': 'station',
        'name': 'KLCC',
        'street': 'Jalan Ampang',
        'district': 'Kampung Cendana',
        'city': 'Kuala Lumpur',
        'country': 'Malaysia',
      },
      'geometry': {
        'type': 'Point',
        'coordinates': [101.7133662, 3.1592469],
      },
    },
    {
      'type': 'Feature',
      'properties': {'name': 'Tanpa Geometri'},
    },
    {
      'type': 'Feature',
      'properties': {'city': 'Shah Alam', 'country': 'Malaysia'},
      'geometry': {
        'type': 'Point',
        'coordinates': [101.5, 3.07],
      },
    },
  ],
};

/// Adapter Dio palsu: merekod permintaan, memulangkan apa yang ujian mahu.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, {int status = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

PlaceSearchService serviceWith(FakeAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return PlaceSearchService(client: dio);
}

void main() {
  test('menghurai ciri Photon jadi hasil boleh papar', () async {
    final adapter = FakeAdapter((_) async => _json(_photonKlcc));
    final results = await serviceWith(adapter).search('klcc');

    // Ciri tanpa geometri digugurkan - hasil tanpa koordinat tak boleh
    // diterbangkan kamera kepadanya, jadi ia bukan hasil.
    expect(results.length, 2);

    final first = results.first;
    expect(first.name, 'KLCC');
    expect(first.point.latitude, closeTo(3.1592469, 1e-6));
    expect(first.point.longitude, closeTo(101.7133662, 1e-6));
    expect(first.subtitle, 'Jalan Ampang, Kampung Cendana, Kuala Lumpur');
  });

  test('ciri tanpa nama jatuh balik ke bahagian alamatnya', () async {
    final adapter = FakeAdapter((_) async => _json(_photonKlcc));
    final results = await serviceWith(adapter).search('klcc');

    // Memaparkan baris kosong lebih teruk daripada memaparkan bandar.
    expect(results.last.name, 'Shah Alam');
    expect(
      results.last.subtitle,
      isNull,
      reason:
          '"Malaysia" pada setiap baris ialah bunyi bising - app ni '
          'beroperasi di Malaysia',
    );
  });

  test(
    'pertanyaan condong ke pusat peta supaya hasil berdekatan naik',
    () async {
      final adapter = FakeAdapter((_) async => _json(_photonKlcc));
      await serviceWith(adapter).search('klcc', near: const LatLng(3.1, 101.6));

      final query = adapter.requests.single.queryParameters;
      expect(query['q'], 'klcc');
      expect(query['lat'], 3.1);
      expect(query['lon'], 101.6);
      expect(query['limit'], kPlaceSearchLimit);
    },
  );

  test('pertanyaan terlalu pendek tak memukul rangkaian langsung', () async {
    final adapter = FakeAdapter((_) async => _json(_photonKlcc));
    final results = await serviceWith(adapter).search('kl');

    expect(results, isEmpty);
    expect(
      adapter.requests,
      isEmpty,
      reason:
          'dua aksara memadan terlalu banyak untuk berguna, dan Photon '
          'meminta kita berlaku adil',
    );
  });

  test('kegagalan rangkaian jadi ralat berpesan, bukan ranap', () async {
    final adapter = FakeAdapter(
      (options) async => throw DioException.connectionTimeout(
        timeout: const Duration(seconds: 1),
        requestOptions: options,
      ),
    );

    // Photon tak menjamin availability, jadi gagal ialah keadaan biasa -
    // pemanggil mesti dapat sesuatu untuk dipapar, bukan pengecualian mentah.
    await expectLater(
      serviceWith(adapter).search('klcc'),
      throwsA(isA<PlaceSearchException>()),
    );
  });

  test('throttle daripada Photon disebut sebagai throttle', () async {
    final adapter = FakeAdapter(
      (_) async => _json(const {'message': 'too many'}, status: 429),
    );

    await expectLater(
      serviceWith(adapter).search('klcc'),
      throwsA(
        isA<PlaceSearchException>().having(
          (e) => e.message,
          'message',
          contains('Terlalu banyak'),
        ),
      ),
    );
  });

  group('padanan stesen ikut jarak', () {
    const stations = [
      TransitStationPoint(name: 'KLCC', point: LatLng(3.15925, 101.71337)),
      TransitStationPoint(name: 'AMPANG PARK', point: LatLng(3.16, 101.72)),
    ];

    test('hasil atas sebuah stesen padan dengannya', () {
      final match = matchStation(const LatLng(3.15930, 101.71340), stations);
      expect(match?.name, 'KLCC');
    });

    test('hasil jauh dari mana-mana stesen tak padan', () {
      // Tanpa had jarak, setiap carian akan membuka kad stesen rawak
      // yang kebetulan paling hampir.
      final match = matchStation(const LatLng(3.05, 101.5), stations);
      expect(match, isNull);
    });
  });

  group('MapSearchController', () {
    MapSearchController controllerWith(FakeAdapter adapter) {
      final c = MapSearchController(
        service: serviceWith(adapter),
        debounce: const Duration(milliseconds: 10),
      );
      addTearDown(c.dispose);
      return c;
    }

    test(
      'taipan pantas hasilkan SATU permintaan, bukan satu per kekunci',
      () async {
        final adapter = FakeAdapter((_) async => _json(_photonKlcc));
        final controller = controllerWith(adapter);

        for (final text in ['klc', 'klcc', 'klcc ', 'klcc t']) {
          controller.query(text);
        }
        await Future<void>.delayed(const Duration(milliseconds: 60));

        expect(adapter.requests.length, 1);
        expect(adapter.requests.single.queryParameters['q'], 'klcc t');
        expect(controller.value, isA<MapSearchResults>());
      },
    );

    test(
      'pertanyaan di bawah minimum kembali ke idle tanpa rangkaian',
      () async {
        final adapter = FakeAdapter((_) async => _json(_photonKlcc));
        final controller = controllerWith(adapter);

        controller.query('klcc');
        await Future<void>.delayed(const Duration(milliseconds: 40));
        expect(controller.value, isA<MapSearchResults>());

        controller.query('kl');
        await Future<void>.delayed(const Duration(milliseconds: 40));

        expect(controller.value, isA<MapSearchIdle>());
        expect(adapter.requests.length, 1, reason: 'padam tak patut mencari');
      },
    );

    test('kegagalan jadi keadaan gagal berpesan', () async {
      final adapter = FakeAdapter(
        (options) async => throw DioException.connectionError(
          requestOptions: options,
          reason: 'tiada rangkaian',
        ),
      );
      final controller = controllerWith(adapter);

      controller.query('klcc');
      await Future<void>.delayed(const Duration(milliseconds: 40));

      final state = controller.value;
      expect(state, isA<MapSearchFailed>());
      expect((state as MapSearchFailed).message, isNotEmpty);
    });

    test('jawapan lewat untuk pertanyaan lama tak menimpa yang baru', () async {
      // Tanpa pengawal generasi, respons perlahan untuk "kl..." boleh
      // mendarat selepas "klcc" dan menggantikan apa yang pengguna lihat.
      var call = 0;
      final adapter = FakeAdapter((_) async {
        call++;
        if (call == 1) {
          await Future<void>.delayed(const Duration(milliseconds: 120));
          return _json(const {'type': 'FeatureCollection', 'features': []});
        }
        return _json(_photonKlcc);
      });
      final controller = controllerWith(adapter);

      controller.query('klc');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      controller.query('klcc');
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final state = controller.value;
      expect(state, isA<MapSearchResults>());
      expect((state as MapSearchResults).results, isNotEmpty);
    });
  });

  test('menghantar User-Agent yang mengenal pasti app', () async {
    // Photon pulangkan 403 untuk UA stok pustaka HTTP - Dio pada Android
    // menghantar 'Dart/3.9 (dart:io)'. Diuji: UA Dart = 403, UA app = 200.
    // Ini punca sebenar "perkhidmatan carian tidak tersedia".
    final adapter = FakeAdapter((_) async => _json(_photonKlcc));
    await serviceWith(adapter).search('klcc');

    final ua = adapter.requests.single.headers['User-Agent'];
    expect(ua, kPlaceSearchUserAgent);
    expect(
      ua.toString().toLowerCase(),
      isNot(startsWith('dart/')),
      reason: 'UA stok pustaka disekat oleh Photon',
    );
  });

  test('status bukan-200 dinamakan dalam ralat, bukan disembunyikan', () async {
    final adapter = FakeAdapter((_) async => _json(const {}, status: 403));

    await expectLater(
      serviceWith(adapter).search('klcc'),
      throwsA(
        isA<PlaceSearchException>().having(
          (e) => e.message,
          'message',
          contains('403'),
        ),
      ),
    );
  });

  group('nyahduplikasi nod pengangkutan', () {
    PlaceResult node(String name, double lat, double lon, String k, String v) =>
        PlaceResult(name: name, point: LatLng(lat, lon), category: k, kind: v);

    test('stesen + perhentian bernama sama runtuh jadi satu', () {
      // Data sebenar: empat nod "Batu Caves" terentang 4-263 m.
      final results = dedupeTransportNodes([
        node('Batu Caves', 3.2379, 101.6841, 'railway', 'stop'),
        node('Batu Caves', 3.23791, 101.68411, 'railway', 'station'),
        node('Batu Caves', 3.2381, 101.6843, 'railway', 'stop'),
      ]);

      expect(results.length, 1);
      expect(
        results.single.kind,
        'station',
        reason: 'yang paling spesifik menang - station mengatasi stop',
      );
    });

    test('kedai bernama sama 105 m berasingan KEKAL berasingan', () {
      // Inilah sebab nyahduplikasi dihadkan pada nod pengangkutan. Lima
      // "Starbucks" di Bangsar terpisah 105 m pada yang paling rapat;
      // ambang jarak semata-mata akan menyembunyikan cawangan sebenar.
      final results = dedupeTransportNodes([
        node('Starbucks', 3.1300, 101.6700, 'amenity', 'cafe'),
        node('Starbucks', 3.13094, 101.6700, 'amenity', 'cafe'),
      ]);

      expect(results.length, 2);
    });

    test('nod pengangkutan yang jauh tak digabung', () {
      final results = dedupeTransportNodes([
        node('Sentral', 3.1300, 101.6700, 'railway', 'station'),
        node('Sentral', 3.1500, 101.6900, 'railway', 'station'),
      ]);

      expect(results.length, 2);
    });

    test('susunan Photon dikekalkan', () {
      final results = dedupeTransportNodes([
        node('Taman', 3.1, 101.6, 'leisure', 'park'),
        node('KLCC', 3.1592, 101.7133, 'railway', 'stop'),
        node('KLCC', 3.15921, 101.71331, 'railway', 'station'),
        node('Bangsar', 3.12, 101.67, 'amenity', 'cafe'),
      ]);

      expect(results.map((r) => r.name), ['Taman', 'KLCC', 'Bangsar']);
    });

    test('isTransportNode tak menangkap tempat biasa', () {
      expect(node('P', 3.1, 101.6, 'leisure', 'park').isTransportNode, isFalse);
      expect(
        node('S', 3.1, 101.6, 'railway', 'station').isTransportNode,
        isTrue,
      );
      expect(
        node('B', 3.1, 101.6, 'highway', 'bus_stop').isTransportNode,
        isTrue,
      );
      // `highway/residential` ialah jalan, bukan perhentian.
      expect(
        node('J', 3.1, 101.6, 'highway', 'residential').isTransportNode,
        isFalse,
      );
    });
  });
}
