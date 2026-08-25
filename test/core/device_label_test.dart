import 'package:flutter_test/flutter_test.dart';
import 'package:marc/core/device_label.dart';

void main() {
  group('sanitizeHttpHeaderValue', () {
    test('buang unicode · yang ditolak HTTP client Dart', () {
      expect(
        sanitizeHttpHeaderValue('Infinix X6833B · Android 14'),
        'Infinix X6833B Android 14',
      );
    });

    test('kekal ASCII biasa', () {
      expect(
        sanitizeHttpHeaderValue('Infinix X6833B - Android 14'),
        'Infinix X6833B - Android 14',
      );
    });

    test('buang emoji dari nama peranti iOS', () {
      expect(
        sanitizeHttpHeaderValue('iPhone Hafiz 📱 - iOS 18.0'),
        'iPhone Hafiz - iOS 18.0',
      );
    });
  });
}
