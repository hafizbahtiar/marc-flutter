import 'dart:typed_data';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// Potong gambar profil kepada segi empat sama sebelum dinaikkan.
///
/// Kenapa perlu: avatar dipapar dalam bulatan. Tanpa potong, gambar
/// landskap jadi muka terkerat di tepi - pengguna tak dapat kawal bahagian
/// mana yang kekal. Nisbah dikunci 1:1 supaya apa yang dipilih ialah tepat
/// apa yang dipapar.
///
/// Guna editor `extended_image` yang memang dah jadi kebergantungan untuk
/// pemapar gambar post - tiada pakej crop tambahan diperlukan.
class AvatarCropPage extends StatefulWidget {
  const AvatarCropPage({super.key, required this.bytes});

  final Uint8List bytes;

  /// Pulang bait JPEG yang dah dipotong, atau null kalau dibatalkan.
  static Future<Uint8List?> open(BuildContext context, Uint8List bytes) {
    return Navigator.of(context, rootNavigator: true).push<Uint8List>(
      MaterialPageRoute(builder: (_) => AvatarCropPage(bytes: bytes)),
    );
  }

  @override
  State<AvatarCropPage> createState() => _AvatarCropPageState();
}

class _AvatarCropPageState extends State<AvatarCropPage> {
  final _editorKey = GlobalKey<ExtendedImageEditorState>();
  bool _processing = false;

  Future<void> _confirm() async {
    final state = _editorKey.currentState;
    if (state == null || _processing) return;
    setState(() => _processing = true);
    try {
      final cropped = _crop(state);
      if (!mounted) return;
      Navigator.of(context).pop(cropped);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  /// Potong dalam Dart guna pakej `image`.
  ///
  /// Selamat untuk dilakukan di thread utama HANYA sebab gambar dah
  /// dikecilkan kepada ≤512px semasa dipilih - menyahkod dan memotong
  /// gambar sensor penuh di sini akan membekukan UI.
  Uint8List _crop(ExtendedImageEditorState state) {
    final rect = state.getCropRect();
    final raw = state.rawImageData;
    if (rect == null) return raw;

    final decoded = img.decodeImage(raw);
    if (decoded == null) return raw;

    final cropped = img.copyCrop(
      decoded,
      x: rect.left.round().clamp(0, decoded.width),
      y: rect.top.round().clamp(0, decoded.height),
      width: rect.width.round().clamp(1, decoded.width),
      height: rect.height.round().clamp(1, decoded.height),
    );
    return Uint8List.fromList(img.encodeJpg(cropped, quality: 95));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Potong gambar'),
        actions: [
          TextButton(
            onPressed: _processing ? null : _confirm,
            child: _processing
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  )
                : const Text('Guna', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ExtendedImage.memory(
        widget.bytes,
        fit: BoxFit.contain,
        mode: ExtendedImageMode.editor,
        extendedImageEditorKey: _editorKey,
        initEditorConfigHandler: (_) => EditorConfig(
          maxScale: 4,
          cropRectPadding: const EdgeInsets.all(24),
          hitTestSize: 20,
          // 1:1 dikunci - avatar sentiasa bulat, jadi membenarkan nisbah
          // lain cuma menjanjikan kawalan yang UI takkan hormati.
          cropAspectRatio: CropAspectRatios.ratio1_1,
        ),
      ),
    );
  }
}
