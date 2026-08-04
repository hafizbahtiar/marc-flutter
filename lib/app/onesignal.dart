import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

/// Init OneSignal push notifications.
///
/// Lompat senyap kalau `ONESIGNAL_APP_ID` belum diisi dalam `.env`,
/// supaya app tetap boleh jalan waktu pembangunan tanpa kredential.
Future<void> initOneSignal() async {
  final appId = dotenv.maybeGet('ONESIGNAL_APP_ID') ?? '';
  if (appId.isEmpty) return;

  OneSignal.Debug.setLogLevel(OSLogLevel.none);
  OneSignal.initialize(appId);

  // Minta kebenaran notifikasi (iOS prompt; Android 13+ prompt).
  await OneSignal.Notifications.requestPermission(true);
}
