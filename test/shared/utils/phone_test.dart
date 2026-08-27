import 'package:flutter_test/flutter_test.dart';
import 'package:marc/shared/utils/phone.dart';

void main() {
  group('normalizeMY', () {
    const validCases = {
      '0123456789': '0123456789',
      '012-345 6789': '0123456789',
      '+60123456789': '0123456789',
      '60123456789': '0123456789',
      '01112345678': '01112345678',
      '+601112345678': '01112345678',
    };

    for (final entry in validCases.entries) {
      test('${entry.key} -> ${entry.value}', () {
        expect(normalizeMY(entry.key), entry.value);
      });
    }

    const invalidCases = [
      '',
      '123456789',
      '0151234567',
      '012345',
      '0123456789012',
      'abcdefghij',
      '03-12345678',
      '0111234567', // "011"+7 digit (10 digit) - mesti tolak, lihat phone.dart
    ];

    for (final input in invalidCases) {
      test('$input tidak sah', () {
        expect(normalizeMY(input), isNull);
      });
    }
  });
}
