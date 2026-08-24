import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/core/error_utils.dart';

DioException _errorWithResponse(int statusCode, Map<String, dynamic> data) {
  final requestOptions = RequestOptions(path: '/auth/login');
  return DioException(
    requestOptions: requestOptions,
    response: Response(
      requestOptions: requestOptions,
      statusCode: statusCode,
      data: data,
    ),
    type: DioExceptionType.badResponse,
  );
}

void main() {
  group('extractErrorMessage', () {
    test('response ada {"error": ...} → guna mesej dari backend', () {
      final e = _errorWithResponse(401, {
        'error': 'Email atau kata laluan salah',
      });
      expect(extractErrorMessage(e), 'Email atau kata laluan salah');
    });

    test('409 conflict → guna mesej dari backend', () {
      final e = _errorWithResponse(409, {'error': 'Email ini sudah berdaftar'});
      expect(extractErrorMessage(e), 'Email ini sudah berdaftar');
    });

    test('400 validation → guna mesej dari backend', () {
      final e = _errorWithResponse(400, {
        'error': 'Kata laluan diperlukan (minimum 6 aksara)',
      });
      expect(
        extractErrorMessage(e),
        'Kata laluan diperlukan (minimum 6 aksara)',
      );
    });

    test('tiada response (connection error) → salahkan internet', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/auth/login'),
        type: DioExceptionType.connectionError,
      );
      expect(extractErrorMessage(e), 'Sambungan gagal. Semak internet anda');
    });

    test('timeout dibezakan drpd tiada sambungan langsung', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/uploads'),
        type: DioExceptionType.sendTimeout,
      );
      expect(extractErrorMessage(e), 'Sambungan terlalu perlahan. Cuba lagi.');
    });

    // Regresi: dulu MANA-MANA respons tanpa `{"error": ...}` dilaporkan
    // sebagai masalah internet. Respons WUJUD bermakna permintaan sampai ke
    // server dan ditolak - menyalahkan WiFi menghantar orang menyiasat
    // perkara yang salah sama sekali.
    test('respons tanpa field error → sebut status, bukan internet', () {
      final e = _errorWithResponse(500, {'something': 'else'});
      expect(extractErrorMessage(e), 'Pelayan bermasalah (500). Cuba lagi.');
    });

    // Punca sebenar bug "post bergambar gagal": R2 tolak PUT dengan 403 dan
    // badan XML (String, bukan Map) - dilaporkan sebagai "semak internet".
    test('403 XML dari R2 → mesej akses ditolak, bukan internet', () {
      final requestOptions = RequestOptions(path: 'https://r2.example/obj');
      final e = DioException(
        requestOptions: requestOptions,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 403,
          data: '<?xml version="1.0"?><Error><Code>AccessDenied</Code></Error>',
        ),
        type: DioExceptionType.badResponse,
      );
      expect(extractErrorMessage(e), 'Akses ditolak oleh pelayan (403).');
    });
  });
}
