import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:marc/shared/ui/map/app_map.dart';

/// Photon direka khas untuk carian sambil-menaip, tak perlukan kunci API,
/// dan dibina atas data OSM.
///
/// Nominatim SENGAJA tidak digunakan: dasar OSMF menyenaraikan
/// "auto-complete search" di bawah Unacceptable Use - "strictly forbidden
/// and will get you banned". Ia hanya boleh dipakai untuk carian
/// tekan-enter, dan bukan itu yang skrin ni buat.
const kPhotonEndpoint = 'https://photon.komoot.io/api/';

/// Di bawah ni pertanyaan memadan terlalu banyak untuk berguna, dan Photon
/// meminta kita berlaku adil dengan penggunaannya.
/// Photon memulangkan **403** untuk User-Agent stok pustaka HTTP - Dio
/// pada Android menghantar `Dart/3.9 (dart:io)`, dan itu disekat. Diuji:
/// UA Dart = 403, curl/kosong/UA app = 200.
///
/// Menamakan app di sini juga betul dari segi kesopanan: penyedia geocoding
/// terbuka perlu tahu siapa yang memanggil supaya mereka boleh hubungi
/// pemilik dan bukan sekadar memblok IP.
const kPlaceSearchUserAgent = 'marc/1.0 (+com.hafizbahtiar.marc)';

const kPlaceSearchMinChars = 3;

const kPlaceSearchLimit = 8;

/// Cukup lama untuk mengelak satu permintaan setiap ketukan kekunci, cukup
/// pendek supaya senarai masih terasa hidup.
const kPlaceSearchDebounce = Duration(milliseconds: 350);

/// Sejauh mana hasil carian boleh berada dari stesen dan masih dianggap
/// stesen itu. Tanpa had ni, setiap carian akan membuka kad stesen rawak
/// yang kebetulan paling hampir.
const kStationMatchMetres = 150.0;

/// Kegagalan yang pemanggil boleh papar kepada pengguna.
///
/// Photon tak menjamin availability, jadi gagal ialah keadaan biasa dan
/// bukan kes tepi - setiap laluan gagal mesti berakhir dengan ayat yang
/// boleh dibaca, bukan pengecualian mentah.
class PlaceSearchException implements Exception {
  const PlaceSearchException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Satu tempat yang dipulangkan Photon.
class PlaceResult {
  const PlaceResult({
    required this.name,
    required this.point,
    this.subtitle,
    this.category,
    this.kind,
  });

  final String name;
  final LatLng point;

  /// Baris alamat yang sudah dicantum, atau null bila tiada apa-apa.
  final String? subtitle;

  /// `osm_key`, cth `railway`, `amenity`, `leisure`. Ikon perlukan
  /// kedua-duanya: `station` bermakna lain di bawah `railway` berbanding
  /// `aeroway`.
  final String? category;

  /// `osm_value`, cth `station`, `park`, `place_of_worship`.
  final String? kind;

  /// Nod pengangkutan - stesen, perhentian, peron.
  ///
  /// OSM memetakan satu stesen sebagai beberapa nod (station + stop +
  /// bus_stop + entrance), dan Photon memulangkan kesemuanya. Itu punca
  /// duplikat dalam hasil carian; lihat [dedupeTransportNodes].
  bool get isTransportNode =>
      const {'railway', 'highway', 'public_transport'}.contains(category) &&
      const {
        'station',
        'stop',
        'halt',
        'bus_stop',
        'tram_stop',
        'platform',
        'subway_entrance',
        'station_entrance',
      }.contains(kind);
}

/// Sejauh mana dua nod pengangkutan bernama sama boleh berpisah dan masih
/// dikira stesen yang sama.
///
/// Diukur pada data sebenar: empat nod "Batu Caves" terentang 4-263 m,
/// dan empat nod "KLCC" terentang 7-380 m.
const kTransportDedupeMetres = 400.0;

/// Runtuhkan nod pengangkutan bernama sama yang berdekatan kepada satu.
///
/// SENGAJA hanya untuk nod pengangkutan. Ambang jarak semata-mata akan
/// salah: lima cawangan "Starbucks" di Bangsar terpisah **105 m** pada
/// yang paling rapat, jadi apa-apa ambang yang cukup besar untuk
/// menggabungkan peron stesen juga akan menggabungkan dua kedai berbeza
/// dan menyembunyikan satu daripada pengguna.
///
/// Susunan Photon dikekalkan: entri pertama setiap kelompok memegang
/// tempatnya, dan yang paling spesifik menang isinya (station > stop >
/// perhentian bas).
List<PlaceResult> dedupeTransportNodes(List<PlaceResult> results) {
  const rank = {'station': 3, 'halt': 2, 'stop': 1};
  final out = <PlaceResult>[];
  final claimed = <int>{};

  for (var i = 0; i < results.length; i++) {
    if (claimed.contains(i)) continue;
    var best = results[i];
    if (best.isTransportNode) {
      final key = best.name.trim().toUpperCase();
      for (var j = i + 1; j < results.length; j++) {
        if (claimed.contains(j)) continue;
        final other = results[j];
        if (!other.isTransportNode) continue;
        if (other.name.trim().toUpperCase() != key) continue;
        if (_distanceMetres(best.point, other.point) > kTransportDedupeMetres) {
          continue;
        }
        claimed.add(j);
        if ((rank[other.kind] ?? 0) > (rank[best.kind] ?? 0)) best = other;
      }
    }
    out.add(best);
  }
  return out;
}

/// Satu stesen yang diketahui, dipetakan kepada kedudukannya. Cukup untuk
/// padanan jarak tanpa memuatkan keseluruhan model stesen.
class TransitStationPoint {
  const TransitStationPoint({required this.name, required this.point});

  final String name;
  final LatLng point;
}

/// Stesen dalam [kStationMatchMetres] daripada [point], atau null.
TransitStationPoint? matchStation(
  LatLng point,
  List<TransitStationPoint> stations,
) {
  TransitStationPoint? best;
  var bestMetres = double.infinity;
  for (final station in stations) {
    final metres = _distanceMetres(point, station.point);
    if (metres < bestMetres) {
      bestMetres = metres;
      best = station;
    }
  }
  return bestMetres <= kStationMatchMetres ? best : null;
}

double _distanceMetres(LatLng a, LatLng b) {
  const metresPerDegree = 111320.0;
  final dy = (a.latitude - b.latitude) * metresPerDegree;
  final dx =
      (a.longitude - b.longitude) *
      metresPerDegree *
      math.cos(a.latitude * math.pi / 180);
  return math.sqrt(dx * dx + dy * dy);
}

class PlaceSearchService {
  /// [client] SENGAJA instance Dio tersendiri dan bukan `api_client.dart`.
  /// Klien itu membawa interceptor auth; menggunakannya semula di sini akan
  /// menghantar token sesi pengguna ke komoot pada setiap ketukan kekunci.
  PlaceSearchService({Dio? client})
    : _dio =
          client ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 6),
              receiveTimeout: const Duration(seconds: 8),
              headers: const {'User-Agent': kPlaceSearchUserAgent},
            ),
          );

  final Dio _dio;

  Future<List<PlaceResult>> search(
    String query, {
    LatLng? near,
    CancelToken? cancelToken,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < kPlaceSearchMinChars) return const [];

    final Response<dynamic> response;
    try {
      response = await _dio.get<dynamic>(
        kPhotonEndpoint,
        cancelToken: cancelToken,
        queryParameters: {
          'q': trimmed,
          'limit': kPlaceSearchLimit,
          'lang': 'en',
          if (near != null) 'lat': near.latitude,
          if (near != null) 'lon': near.longitude,
        },
        options: Options(
          validateStatus: (_) => true,
          headers: const {'User-Agent': kPlaceSearchUserAgent},
        ),
      );
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) return const [];
      debugPrint('[map] carian Photon gagal: ${error.type} ${error.message}');
      throw const PlaceSearchException(
        'Tidak dapat menghubungi perkhidmatan carian. Semak sambungan anda.',
      );
    }

    final status = response.statusCode ?? 0;
    if (status == 429) {
      throw const PlaceSearchException(
        'Terlalu banyak carian buat masa ni. Cuba sebentar lagi.',
      );
    }
    if (status != 200) {
      // Kod status masuk log: "tidak tersedia" sahaja ialah jalan buntu
      // untuk pengguna DAN untuk sesiapa yang menyahpepijatnya kemudian.
      debugPrint('[map] carian Photon pulangkan HTTP $status');
      throw PlaceSearchException(
        'Perkhidmatan carian menolak permintaan (HTTP $status).',
      );
    }

    final data = response.data;
    if (data is! Map || data['features'] is! List) {
      throw const PlaceSearchException('Jawapan carian tidak difahami.');
    }

    final results = <PlaceResult>[];
    for (final feature in data['features'] as List) {
      final parsed = _parse(feature);
      if (parsed != null) results.add(parsed);
    }
    return dedupeTransportNodes(results);
  }
}

PlaceResult? _parse(Object? feature) {
  if (feature is! Map) return null;
  final properties = feature['properties'];
  final geometry = feature['geometry'];
  if (properties is! Map || geometry is! Map) return null;

  // Tiada koordinat bermakna kamera tak boleh terbang ke sana, jadi ia
  // bukan hasil - Photon memang memulangkan ciri sebegini.
  final coordinates = geometry['coordinates'];
  if (coordinates is! List || coordinates.length < 2) return null;
  final lon = (coordinates[0] as num?)?.toDouble();
  final lat = (coordinates[1] as num?)?.toDouble();
  if (lon == null || lat == null) return null;

  String? text(String key) {
    final value = properties[key];
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  // Negara disertakan hanya bila ia BUKAN Malaysia. App ni beroperasi di
  // Malaysia, jadi "Malaysia" pada setiap baris ialah bunyi bising yang
  // menolak keluar bahagian yang benar-benar membezakan hasil - tapi
  // hasil luar negara masih perlu dibezakan.
  final country = text('country');
  final parts = [
    text('street'),
    text('district'),
    text('city'),
    text('state'),
    if (country != null && country.toLowerCase() != 'malaysia') country,
  ].whereType<String>().toList();

  // Memaparkan baris kosong lebih teruk daripada memaparkan bandar, jadi
  // nama jatuh balik ke bahagian alamat pertama dan bukan kekal kosong.
  final name = text('name') ?? (parts.isEmpty ? null : parts.removeAt(0));
  if (name == null) return null;

  return PlaceResult(
    name: name,
    point: LatLng(lat, lon),
    subtitle: parts.isEmpty ? null : parts.join(', '),
    category: text('osm_key'),
    kind: text('osm_value'),
  );
}
