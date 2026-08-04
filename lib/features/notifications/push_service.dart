import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final pushServiceProvider = Provider<PushService>(
  (ref) => PushService(Supabase.instance.client),
);

/// Segerakkan identiti OneSignal dengan sesi Supabase, dan simpan
/// subscription id setiap peranti ke jadual `device_tokens`.
///
/// Semua operasi dibalut try/catch — kalau OneSignal tak di-init
/// (`ONESIGNAL_APP_ID` kosong), ia jadi no-op senyap.
class PushService {
  PushService(this._supabase);

  final SupabaseClient _supabase;

  /// Dipanggil bila sesi auth wujud (log masuk / initial session).
  Future<void> onSignedIn(String userId) async {
    try {
      OneSignal.login(userId);
      await _upsertCurrent();
    } catch (_) {
      // OneSignal belum init — abaikan.
    }
  }

  /// Dipanggil bila log keluar.
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
        if (_supabase.auth.currentUser != null) {
          _upsertCurrent();
        }
      });
    } catch (_) {}
  }

  Future<void> _upsertCurrent() async {
    final id = OneSignal.User.pushSubscription.id;
    if (id == null || id.isEmpty) return;
    if (_supabase.auth.currentUser == null) return;
    await _supabase.rpc(
      'upsert_device_token',
      params: {'p_onesignal_id': id, 'p_platform': defaultTargetPlatform.name},
    );
  }
}
