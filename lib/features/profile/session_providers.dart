import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/core/auth_state.dart';

/// Satu sesi log masuk aktif (satu baris `refresh_tokens` di backend) -
/// "device ni pernah log masuk dan masih boleh refresh token".
///
/// TIADA medan `is_current`: `/me/sessions` dipanggil dengan ACCESS
/// token, dan access token backend cuma bawa `sub` (tiada rujukan kepada
/// baris refresh token yang mengeluarkannya). Jadi server memang TAK
/// BOLEH beritahu sesi mana milik device ni tanpa mekanisme penjejakan
/// baharu. Senarai tanpa penanda "device ini" masih berguna; menekanya
/// ikut tekaan akan buat ahli log keluar device salah.
class SessionRow {
  const SessionRow({
    required this.id,
    this.userAgent,
    this.createdIp,
    required this.createdAt,
    required this.expiresAt,
  });

  final String id;

  /// Rentetan User-Agent mentah - TAK dihurai jadi label "iPhone/Chrome".
  /// Null utk sesi lama yang dicipta sebelum backend mula merakamnya.
  final String? userAgent;

  /// IP semasa sesi dicipta. Null atas sebab yang sama dgn [userAgent].
  final String? createdIp;

  final DateTime createdAt;
  final DateTime expiresAt;

  factory SessionRow.fromJson(Map<String, dynamic> json) {
    return SessionRow(
      id: json['id'] as String,
      userAgent: json['user_agent'] as String?,
      createdIp: json['created_ip'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }
}

/// Senarai sesi aktif ahli semasa.
final sessionsProvider = FutureProvider<List<SessionRow>>((ref) async {
  final isLoggedIn = ref.watch(
    authNotifierProvider.select((s) => s.isLoggedIn),
  );
  if (!isLoggedIn) return const [];

  final dio = ref.watch(dioProvider);
  final res = await dio.get('/me/sessions');
  return (res.data as List)
      .map((s) => SessionRow.fromJson(s as Map<String, dynamic>))
      .toList();
});

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(ref),
);

class SessionRepository {
  SessionRepository(this._ref);
  final Ref _ref;

  /// Log keluar SATU sesi (device). Adik-beradik satu-baris kepada
  /// `signOutAll` - sesi lain (termasuk device ni) kekal.
  ///
  /// Backend pulang 404 kalau id bukan milik ahli semasa (ownership
  /// dikuatkuasakan dalam query DELETE), jadi tiada semakan pemilikan
  /// perlu di sini.
  Future<void> revoke(String id) async {
    final dio = _ref.read(dioProvider);
    await dio.delete('/me/sessions/$id');
    _ref.invalidate(sessionsProvider);
  }

  /// Log keluar beberapa sesi sekaligus - POST /me/sessions/revoke.
  Future<void> revokeMany(List<String> ids) async {
    if (ids.isEmpty) return;
    final dio = _ref.read(dioProvider);
    await dio.post('/me/sessions/revoke', data: {'ids': ids});
    _ref.invalidate(sessionsProvider);
  }
}
