import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/core/auth_state.dart';

/// Satu sesi log masuk aktif - SATU family refresh token (satu device).
/// Id ialah `family_id`, bukan hash token individu (refresh memutar hash
/// baru dalam family yang sama).
class SessionRow {
  const SessionRow({
    required this.id,
    this.userAgent,
    this.createdIp,
    required this.createdAt,
    required this.expiresAt,
    this.isCurrent = false,
  });

  final String id;

  /// Label peranti (`X-MARC-Device-Label`) atau User-Agent mentah.
  /// Null utk sesi lama yang dicipta sebelum backend mula merakamnya.
  final String? userAgent;

  /// IP semasa sesi dicipta. Null atas sebab yang sama dgn [userAgent].
  final String? createdIp;

  final DateTime createdAt;
  final DateTime expiresAt;

  /// True iff `sid` dalam access token JWT padan family ni - "peranti ini".
  final bool isCurrent;

  factory SessionRow.fromJson(Map<String, dynamic> json) {
    return SessionRow(
      id: json['id'] as String,
      userAgent: json['user_agent'] as String?,
      createdIp: json['created_ip'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      isCurrent: json['is_current'] as bool? ?? false,
    );
  }
}

/// Senarai sesi aktif ahli semasa. Peranti semasa di depan.
final sessionsProvider = FutureProvider<List<SessionRow>>((ref) async {
  final isLoggedIn = ref.watch(
    authNotifierProvider.select((s) => s.isLoggedIn),
  );
  if (!isLoggedIn) return const [];

  final dio = ref.watch(dioProvider);
  final res = await dio.get('/me/sessions');
  final rows = (res.data as List)
      .map((s) => SessionRow.fromJson(s as Map<String, dynamic>))
      .toList();
  rows.sort((a, b) {
    if (a.isCurrent != b.isCurrent) return a.isCurrent ? -1 : 1;
    return b.createdAt.compareTo(a.createdAt);
  });
  return rows;
});

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(ref),
);

class SessionRepository {
  SessionRepository(this._ref);
  final Ref _ref;

  /// Log keluar SATU sesi (device / family). Adik-beradik satu-baris
  /// kepada `signOutAll` - sesi lain kekal.
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
