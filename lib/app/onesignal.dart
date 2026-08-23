import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

/// Init OneSignal push notifications.
///
/// Lompat senyap kalau `ONESIGNAL_APP_ID` belum diisi dalam `.env`,
/// supaya app tetap boleh jalan waktu pembangunan tanpa kredential.
///
/// Sengaja TAK minta permission notifikasi di sini - itu prompt OS yang
/// boleh block tanpa had kalau user backgroundkan app sebelum jawab.
/// Panggil [requestNotificationPermission] berasingan LEPAS `runApp`
/// (fire-and-forget, jangan `await` sebelum UI pertama render).
Future<void> initOneSignal() async {
  final appId = dotenv.maybeGet('ONESIGNAL_APP_ID') ?? '';
  if (appId.isEmpty) return;

  OneSignal.Debug.setLogLevel(OSLogLevel.none);
  OneSignal.initialize(appId);
}

/// Minta kebenaran notifikasi (iOS prompt; Android 13+ prompt). No-op
/// senyap kalau OneSignal belum di-init (`ONESIGNAL_APP_ID` kosong).
Future<void> requestNotificationPermission() async {
  try {
    await OneSignal.Notifications.requestPermission(true);
  } catch (_) {}
}
