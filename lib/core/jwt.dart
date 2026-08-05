import 'dart:convert';

/// Decode claim `sub` (user id) daripada JWT access token — cukup untuk
/// link identiti OneSignal (`OneSignal.login(userId)`). Signature verify
/// bukan tanggungjawab client, itu kerja server.
String? decodeJwtSubject(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final decoded = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final map = jsonDecode(decoded) as Map<String, dynamic>;
    return map['sub'] as String?;
  } catch (_) {
    return null;
  }
}
