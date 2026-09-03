import 'package:flutter_test/flutter_test.dart';
import 'package:marc/shared/utils/validators.dart';

void main() {
  group('validateEmail', () {
    test('kosong tidak sah', () => expect(validateEmail(''), isNotNull));
    test(
      'format salah tidak sah',
      () => expect(validateEmail('abc'), isNotNull),
    );
    test('email sah lulus', () => expect(validateEmail('a@b.com'), isNull));
  });

  group('validatePassword', () {
    test('kosong tidak sah', () => expect(validatePassword(''), isNotNull));
    test('pendek tidak sah', () => expect(validatePassword('123'), isNotNull));
    test(
      'cukup panjang lulus',
      () => expect(validatePassword('123456'), isNull),
    );
  });

  group('validateStaffId', () {
    test('kosong tidak sah', () {
      expect(validateStaffId(''), 'Nombor staff wajib diisi');
      expect(validateStaffId('   '), 'Nombor staff wajib diisi');
      expect(validateStaffId(null), 'Nombor staff wajib diisi');
    });

    test('lebih 64 aksara tidak sah', () {
      expect(
        validateStaffId('x' * 65),
        'Nombor staff tidak boleh lebih 64 aksara',
      );
    });

    test('mengandungi slash tidak sah', () {
      expect(
        validateStaffId('EMP/001'),
        "Nombor staff tidak boleh mengandungi '/'",
      );
    });

    test('64 aksara dan dash lulus', () {
      expect(validateStaffId('x' * 64), isNull);
      expect(validateStaffId('EMP-001'), isNull);
    });
  });
}
