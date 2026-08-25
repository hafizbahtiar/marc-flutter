import 'dart:convert';

Map<String, dynamic>? _jwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  final decoded = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
  return jsonDecode(decoded) as Map<String, dynamic>;
}

/// Decode claim `sub` (user id) daripada JWT access token - cukup untuk
/// link identiti OneSignal (`OneSignal.login(userId)`). Signature verify
/// bukan tanggungjawab client, itu kerja server.
String? decodeJwtSubject(String token) {
  try {
    return _jwtPayload(token)?['sub'] as String?;
  } catch (_) {
    return null;
  }
}

/// `exp` (saat Unix UTC). Null kalau token cacat / tiada claim.
DateTime? decodeJwtExpiry(String token) {
  try {
    final exp = _jwtPayload(token)?['exp'];
    final seconds = switch (exp) {
      int v => v,
      num v => v.toInt(),
      _ => null,
    };
    if (seconds == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  } catch (_) {
    return null;
  }
}

/// Access dah luput (atau hampir, dalam [skew]) - masa untuk refresh
/// atau, kalau refresh pun mati, force ke /login.
bool isAccessTokenExpired(
  String token, {
  Duration skew = const Duration(seconds: 30),
}) {
  final exp = decodeJwtExpiry(token);
  if (exp == null) return false;
  return DateTime.now().toUtc().isAfter(exp.subtract(skew));
}
