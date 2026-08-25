import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Label peranti mesra pengguna utk skrin "sesi aktif".
///
/// Dihantar sebagai header `X-MARC-Device-Label` semasa login/register/
/// refresh supaya backend simpan label ni (bukan User-Agent Dio mentah).
/// Nilai dicache dalam proses - maklumat peranti tak berubah semasa app
/// hidup.
String? _cachedLabel;

/// Label yang sudah dicache - selamat dibaca secara sync (cth. dalam
/// interceptor Dio) tanpa menunggu platform channel.
String? get cachedDeviceLabel => _cachedLabel;

/// HTTP header values mesti ASCII printable (RFC 7230). Nama peranti
/// pengguna boleh ada unicode; aksara macam `·` (U+00B7) pula ditolak
/// oleh client Dart walaupun nampak "huruf biasa" - lihat FormatException
/// pada `X-MARC-Device-Label` semasa login.
@visibleForTesting
String sanitizeHttpHeaderValue(String raw) {
  final buf = StringBuffer();
  for (final codeUnit in raw.runes) {
    if (codeUnit >= 0x20 && codeUnit <= 0x7E) {
      buf.writeCharCode(codeUnit);
    }
  }
  return buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

Future<String?> getDeviceLabel() async {
  if (_cachedLabel != null) return _cachedLabel;
  if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return null;

  try {
    final plugin = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      final manufacturer = info.manufacturer.trim();
      final model = info.model.trim();
      final deviceName = manufacturer.isEmpty
          ? model
          : model.toLowerCase().startsWith(manufacturer.toLowerCase())
          ? model
          : '$manufacturer $model';
      _cachedLabel = sanitizeHttpHeaderValue(
        '$deviceName - Android ${info.version.release}',
      );
    } else {
      final info = await plugin.iosInfo;
      // `name` = nama peranti pengguna ("iPhone Hafiz"); `model` terlalu
      // generik ("iPhone") untuk dibezakan device.
      _cachedLabel = sanitizeHttpHeaderValue(
        '${info.name} - iOS ${info.systemVersion}',
      );
    }
  } catch (_) {
    return null;
  }
  if (_cachedLabel!.isEmpty) return null;
  return _cachedLabel;
}

/// Ujian sahaja - reset cache supaya label boleh diuji semula.
@visibleForTesting
void resetDeviceLabelCacheForTest() => _cachedLabel = null;
