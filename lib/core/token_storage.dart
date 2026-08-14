import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Simpan access/refresh token dalam secure storage (Keychain/Keystore),
/// gantian sesi Supabase yang dulu diuruskan supabase_flutter sendiri.
class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // encryptedSharedPreferences: true guna EncryptedSharedPreferences
            // (bukan FlutterSecureStorage.xml biasa) — tanpa ni, Android Auto
            // Backup upload fail XML terenkripsi tu ke cloud tapi BUKAN kunci
            // Keystore yang bungkus dia, jadi restore pada peranti baru bawa
            // blob yang tak boleh dinyahsulit langsung. resetOnError: true
            // buang entri rosak automatik bila ni berlaku (dan bila Keystore
            // invalid selepas restore/factory reset) supaya baca pulangkan
            // null macam "tiada token", bukan throw PlatformException.
            aOptions: AndroidOptions(
              encryptedSharedPreferences: true,
              resetOnError: true,
            ),
          );

  final FlutterSecureStorage _storage;

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  Future<void> save({required String access, required String refresh}) {
    return Future.wait([
      _storage.write(key: _accessKey, value: access),
      _storage.write(key: _refreshKey, value: refresh),
    ]);
  }

  Future<String?> readAccessToken() => _storage.read(key: _accessKey);
  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  Future<void> clear() {
    return Future.wait([
      _storage.delete(key: _accessKey),
      _storage.delete(key: _refreshKey),
    ]);
  }

  /// Buang SEMUA entri secure storage app ni (bukan sekadar access/refresh
  /// token) — dipanggil bila storage sendiri rosak (cth: PlatformException
  /// lepas Keystore invalid) supaya save berikutnya mula dari keadaan
  /// bersih, bukan cuba tulis atas entri yang dah corrupt.
  Future<void> deleteAll() => _storage.deleteAll();
}
