import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/core/app_log.dart';

/// Had dimensi avatar semasa pilih gambar.
///
/// Jauh lebih kecil drpd gambar post (2048) sebab avatar dipapar dalam
/// bulatan 28–88dp. Backend kuatkuasakan semula pada 1024
/// (`MaxAvatarDimension`) — presigned URL benarkan client naikkan apa-apa
/// terus ke R2, jadi had di sini kemudahan, bukan sempadan keselamatan.
const avatarMaxDimension = 512.0;

/// Kualiti JPEG. Tinggi sengaja — matlamatnya kecilkan DIMENSI, bukan
/// hancurkan kualiti. Muka manusia menunjukkan artifak lebih ketara drpd
/// gambar biasa.
const avatarQuality = 95;

final avatarServiceProvider = Provider<AvatarService>(AvatarService.new);

/// Muat naik gambar profil: pilih → naik ke R2 (presigned) → `PATCH /me`.
///
/// Diasingkan drpd widget supaya aliran tiga langkah ni boleh diuji tanpa
/// membina UI, dan supaya halaman edit profil tak perlu tahu tentang
/// presign mahupun kunci R2.
class AvatarService {
  AvatarService(this._ref);
  final Ref _ref;

  final _picker = ImagePicker();

  /// Pilih gambar dari galeri. `null` kalau pengguna batal.
  ///
  /// Mengecilkan waktu pilih — bukan selepas — supaya bitmap resolusi
  /// penuh tak pernah masuk memori Dart.
  Future<XFile?> pick() {
    return _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: avatarMaxDimension,
      maxHeight: avatarMaxDimension,
      imageQuality: avatarQuality,
    );
  }

  /// Naik `bytes` ke R2 dan kaitkan sebagai avatar user semasa.
  ///
  /// Pulang URL awam avatar baharu.
  Future<String?> upload(Uint8List bytes) async {
    final dio = _ref.read(dioProvider);

    appLog('avatar', 'presign mula (${bytes.length} bait)');
    final presign = await dio.post(
      '/uploads/presign',
      data: {'content_type': 'image/jpeg'},
    );
    final uploadUrl = presign.data['upload_url'] as String;
    final r2Key = presign.data['r2_key'] as String;

    try {
      // Dio berasingan: URL presigned R2 bukan endpoint backend kita, jadi
      // ia tak sepatutnya bawa Bearer token kita. Timeout eksplisit —
      // Dio() kosong tiada timeout langsung.
      await Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 30),
        ),
      ).put(
        uploadUrl,
        data: bytes,
        options: Options(headers: {'Content-Type': 'image/jpeg'}),
      );
    } on DioException catch (e) {
      appLogDioError('avatar', 'PUT R2 (r2_key=$r2Key)', e);
      rethrow;
    }

    appLog('avatar', 'PUT R2 OK, kaitkan ke profil');
    final res = await dio.patch('/me', data: {'avatar_r2_key': r2Key});
    return (res.data as Map<String, dynamic>)['avatar_url'] as String?;
  }

  /// Buang gambar profil. Backend gilirkan objek lama untuk dipadam.
  Future<void> remove() async {
    await _ref.read(dioProvider).patch('/me', data: {'avatar_r2_key': ''});
  }
}
