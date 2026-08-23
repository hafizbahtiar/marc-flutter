import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Log pembangunan ringkas. Guna `dart:developer` (bukan `print`) supaya
/// keluar kemas dalam DevTools dan `flutter logs`, dan dimatikan terus
/// dalam release build.
///
/// Untuk aliran berbilang langkah yang senang gagal separuh jalan (upload
/// gambar → presign → PUT R2 → cipta post), log setiap peringkat: bila ia
/// gagal pada peranti pengguna, satu-satunya cara tahu peringkat MANA yang
/// putus ialah kalau peringkat sebelumnya ada meninggalkan jejak.
void appLog(String scope, String message) {
  if (!kDebugMode) return;
  developer.log(message, name: 'marc.$scope');
}

/// Log DioException dengan maklumat yang betul-betul berguna: jenis ralat,
/// status, dan badan respons.
///
/// Sebab wujud: mesej lalai DioException tak beritahu sama ada permintaan
/// itu langsung tak sampai, atau sampai dan ditolak dengan 403 - dua punca
/// yang berbeza sepenuhnya tapi nampak serupa pada pengguna.
void appLogDioError(String scope, String stage, DioException e) {
  if (!kDebugMode) return;
  final response = e.response;
  final buffer = StringBuffer('$stage GAGAL - ${e.type.name}')
    ..write(
      '\n  url: ${e.requestOptions.method} ${_safeUri(e.requestOptions.uri)}',
    );
  if (response != null) {
    buffer.write('\n  status: ${response.statusCode}');
    buffer.write('\n  body: ${_preview(response.data)}');
  } else {
    buffer.write('\n  (tiada respons - permintaan tak sampai/timeout)');
    buffer.write('\n  error: ${e.error}');
  }
  developer.log(buffer.toString(), name: 'marc.$scope', error: e);
}

/// Buang query string sebelum log.
///
/// URL presigned R2 bawa `X-Amz-Signature` dalam query - kredential
/// jangka pendek, tapi tetap kredential, dan log peranti bukan tempatnya.
/// Path dikekalkan sebab itulah yang berguna untuk nyahpepijat (kunci
/// objek mana yang gagal); tandatangan tak pernah berguna.
String _safeUri(Uri uri) {
  if (uri.query.isEmpty) return uri.toString();
  return '${uri.replace(query: '')}?<${uri.queryParameters.length} param disembunyikan>';
}

String _preview(Object? data) {
  final text = data.toString();
  return text.length <= 800 ? text : '${text.substring(0, 800)}…';
}

/// Diekspos untuk ujian sahaja - penapisan kredential berbaloi diuji,
/// dan fungsi peribadi tak boleh dicapai dari luar pustaka.
@visibleForTesting
String debugSafeUriForTest(Uri uri) => _safeUri(uri);
