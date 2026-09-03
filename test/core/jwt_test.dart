import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:marc/core/jwt.dart';

String _jwt({int? exp, String sub = 'user-1'}) {
  final header = base64Url.encode(utf8.encode('{"alg":"none"}'));
  final payload = base64Url.encode(
    utf8.encode(jsonEncode({'sub': sub, 'exp': ?exp})),
  );
  return '$header.$payload.sig';
}

void main() {
  test('decodeJwtSubject baca sub', () {
    expect(decodeJwtSubject(_jwt(sub: 'abc')), 'abc');
  });

  test('isAccessTokenExpired true bila exp dah lepas', () {
    final past =
        DateTime.now()
            .toUtc()
            .subtract(const Duration(minutes: 2))
            .millisecondsSinceEpoch ~/
        1000;
    expect(isAccessTokenExpired(_jwt(exp: past)), isTrue);
  });

  test('isAccessTokenExpired false bila exp masih jauh', () {
    final future =
        DateTime.now()
            .toUtc()
            .add(const Duration(hours: 1))
            .millisecondsSinceEpoch ~/
        1000;
    expect(isAccessTokenExpired(_jwt(exp: future)), isFalse);
  });

  test('tiada exp → anggap belum luput (biar interceptor yang putuskan)', () {
    expect(isAccessTokenExpired(_jwt()), isFalse);
  });
}
