import 'package:dio/dio.dart';

/// Petik ralat dari response backend Go (`{"error": "..."}` dalam
/// Bahasa Melayu) ke mesej mesra. Fallback kalau tiada sambungan.
String extractErrorMessage(DioException e) {
  final data = e.response?.data;
  if (data is Map && data['error'] is String) {
    return data['error'] as String;
  }
  return 'Sambungan gagal. Semak internet anda';
}
