import 'package:dio/dio.dart';

/// Petik ralat dari response backend Go (`{"error": "..."}` dalam
/// Bahasa Melayu) ke mesej mesra.
///
/// PENTING - "Sambungan gagal" hanya untuk kegagalan sambungan SEBENAR.
///
/// Versi lama pulangkan "Sambungan gagal. Semak internet anda" untuk
/// SEMUA ralat yang badan responsnya bukan `Map` berkunci `error`. Itu
/// menyembunyikan satu kelas kegagalan penuh: PUT ke R2 yang ditolak
/// 403 AccessDenied pulangkan XML (String, bukan Map), jadi ralat
/// keizinan bucket dilaporkan kepada pengguna sebagai masalah internet -
/// dan tiada sesiapa pergi periksa Cloudflare, sebab mesejnya kata WiFi.
///
/// Sekarang: kalau ADA respons, permintaan itu sampai ke server dan
/// ditolak - sebut status kodnya. Hanya ketiadaan respons (timeout, DNS,
/// soket) yang berbaloi disalahkan pada internet.
String extractErrorMessage(DioException e) {
  final response = e.response;

  final data = response?.data;
  if (data is Map && data['error'] is String) {
    return data['error'] as String;
  }

  if (response != null) {
    return switch (response.statusCode) {
      401 => 'Sesi tamat. Sila log masuk semula.',
      403 => 'Akses ditolak oleh pelayan (403).',
      413 => 'Fail terlalu besar.',
      final int code when code >= 500 =>
        'Pelayan bermasalah ($code). Cuba lagi.',
      final int code => 'Permintaan gagal ($code).',
      _ => 'Permintaan gagal.',
    };
  }

  return switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => 'Sambungan terlalu perlahan. Cuba lagi.',
    DioExceptionType.cancel => 'Permintaan dibatalkan.',
    _ => 'Sambungan gagal. Semak internet anda',
  };
}
