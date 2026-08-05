import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/features/auth/auth_service.dart';

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
      final e = _errorWithResponse(401, {'error': 'Email atau kata laluan salah'});
      expect(extractErrorMessage(e), 'Email atau kata laluan salah');
    });

    test('409 conflict → guna mesej dari backend', () {
      final e = _errorWithResponse(409, {'error': 'Email ini sudah berdaftar'});
      expect(extractErrorMessage(e), 'Email ini sudah berdaftar');
    });

    test('400 validation → guna mesej dari backend', () {
      final e = _errorWithResponse(
        400,
        {'error': 'Kata laluan diperlukan (minimum 6 aksara)'},
      );
      expect(
        extractErrorMessage(e),
        'Kata laluan diperlukan (minimum 6 aksara)',
      );
    });

    test('tiada response (connection error) → fallback', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/auth/login'),
        type: DioExceptionType.connectionError,
      );
      expect(extractErrorMessage(e), 'Sambungan gagal. Semak internet anda');
    });

    test('response tanpa field error → fallback', () {
      final e = _errorWithResponse(500, {'something': 'else'});
      expect(extractErrorMessage(e), 'Sambungan gagal. Semak internet anda');
    });
  });
}
