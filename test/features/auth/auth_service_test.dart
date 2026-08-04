import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:marc_flutter/features/auth/auth_service.dart';

void main() {
  group('mapAuthErrorToMessage', () {
    test('invalid_credentials → mesej Melayu', () {
      final e = AuthException('x', code: 'invalid_credentials');
      expect(mapAuthErrorToMessage(e), 'Email atau kata laluan salah');
    });

    test('email_not_confirmed → mesej Melayu', () {
      final e = AuthException('x', code: 'email_not_confirmed');
      expect(mapAuthErrorToMessage(e), 'Sila sahkan email anda dahulu');
    });

    test('user_already_exists → mesej Melayu', () {
      final e = AuthException('x', code: 'user_already_exists');
      expect(mapAuthErrorToMessage(e), 'Email ini sudah berdaftar');
    });

    test('weak_password → mesej Melayu', () {
      final e = AuthException('x', code: 'weak_password');
      expect(mapAuthErrorToMessage(e),
          'Kata laluan terlalu lemah (minimum 6 aksara)');
    });

    test('kod tidak diketahui → fallback ke mesej asal', () {
      final e = AuthException('Sesuatu berlaku', code: 'unknown_code');
      expect(mapAuthErrorToMessage(e), 'Sesuatu berlaku');
    });
  });
}
