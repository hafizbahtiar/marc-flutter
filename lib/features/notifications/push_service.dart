import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/core/auth_state.dart';

final pushServiceProvider = Provider<PushService>((ref) => PushService(ref));

/// Segerakkan identiti OneSignal dengan sesi backend, dan simpan
/// subscription id setiap peranti ke `POST /device-tokens`.
///
/// Semua operasi dibalut try/catch — kalau OneSignal tak di-init
/// (`ONESIGNAL_APP_ID` kosong), ia jadi no-op senyap.
class PushService {
  PushService(this._ref);

  final Ref _ref;

  /// Dipanggil bila sesi auth wujud (log masuk / initial session).
  Future<void> onSignedIn(String userId) async {
    try {
      OneSignal.login(userId);
      await _upsertCurrent();
    } catch (_) {
      // OneSignal belum init — abaikan.
    }
  }

  /// Buang pautan device token daripada user semasa di server, guna
  /// access token yang DAH DITANGKAP awal (sebelum sesi di-clear) —
  /// benarkan panggilan ni jalan unawaited SELEPAS clear() tanpa
  /// bergantung pada token tersimpan yang dah tiada. Tak kritikal kalau
  /// gagal — token lama akan di-overwrite lagipun bila user seterusnya
  /// upsert dengan onesignal_id yang sama.
  Future<void> unlinkDevice(String accessToken) async {
    final id = OneSignal.User.pushSubscription.id;
    if (id == null || id.isEmpty) return;

    try {
      await _ref
          .read(dioProvider)
          .delete(
            '/device-tokens/by-onesignal/$id',
            options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
          );
    } catch (_) {}
  }

  /// Dipanggil bila log keluar (reaktif, selepas sesi clear) — OneSignal
  /// SDK logout je; unlink server kena dah siap awal via
  /// [unlinkDevice] (dipanggil unawaited dalam `AuthService.signOut`).
  Future<void> onSignedOut() async {
    try {
      await OneSignal.logout();
    } catch (_) {}
  }

  /// Dengar perubahan subscription id. Selepas permission diberi, id
  /// selalunya belum sedia serta-merta; observer ini tangkap bila ia masuk.
  void startObserving() {
    try {
      OneSignal.User.pushSubscription.addObserver((_) {
        if (_ref.read(authNotifierProvider).isLoggedIn) {
          _upsertCurrent();
        }
      });
    } catch (_) {}
  }

  Future<void> _upsertCurrent() async {
    final id = OneSignal.User.pushSubscription.id;
    if (id == null || id.isEmpty) return;
    if (!_ref.read(authNotifierProvider).isLoggedIn) return;

    try {
      await _ref
          .read(dioProvider)
          .post(
            '/device-tokens',
            data: {'onesignal_id': id, 'platform': defaultTargetPlatform.name},
          );
    } catch (_) {
      // Gagal simpan token — tak kritikal, cuba lagi bila observer trigger semula.
    }
  }
}
