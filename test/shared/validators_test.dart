import 'package:flutter_test/flutter_test.dart';
import 'package:marc/shared/validators.dart';

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
}
