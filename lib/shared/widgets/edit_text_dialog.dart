import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:marc/shared/widgets/app_dialog.dart';

/// Dialog untuk edit satu medan teks - pulang teks baru (trimmed) bila
/// disimpan, `null` bila dibatal/ditutup tanpa simpan.
///
/// Adaptive: CupertinoTextField dalam CupertinoAlertDialog di iOS/macOS,
/// TextField dalam AlertDialog di platform lain (lihat [showAppDialog]).
///
/// Contoh:
/// ```dart
/// final newContent = await showEditTextDialog(
///   context,
///   title: 'Edit post',
///   initialValue: post.content,
/// );
/// if (newContent != null) { ... }
/// ```
Future<String?> showEditTextDialog(
  BuildContext context, {
  required String title,
  required String initialValue,
  int maxLines = 5,
}) {
  // showAdaptiveDialog (bukan showDialog) supaya transisi/barrier pun ikut
  // platform, padan dengan rangka adaptive dalam AppDialogShell.
  return showAdaptiveDialog<String>(
    context: context,
    builder: (ctx) => _EditTextDialog(
      title: title,
      initialValue: initialValue,
      maxLines: maxLines,
    ),
  );
}

/// StatefulWidget (bukan controller tempatan dalam [showEditTextDialog])
/// SEMATA-MATA sebab pemilikan controller.
///
/// Versi lama cipta TextEditingController lalu `dispose()` dalam blok
/// `finally` selepas `await showDialog(...)`. Future showDialog selesai
/// sebaik `Navigator.pop` dipanggil, TAPI route masih beranimasi keluar
/// dan TextField masih dibina beberapa frame selepas itu - jadi ia guna
/// controller yang dah dibuang dan app crash dengan "A
/// TextEditingController was used after being disposed" setiap kali
/// Simpan/Batal ditekan.
///
/// Dengan State, controller hidup selagi widget hidup dan cuma dibuang
/// selepas animasi keluar tamat.
class _EditTextDialog extends StatefulWidget {
  const _EditTextDialog({
    required this.title,
    required this.initialValue,
    required this.maxLines,
  });

  final String title;
  final String initialValue;
  final int maxLines;

  @override
  State<_EditTextDialog> createState() => _EditTextDialogState();
}

class _EditTextDialogState extends State<_EditTextDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final text = _controller.text.trim();
    Navigator.of(context).pop(text.isEmpty ? null : text);
  }

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final isApple =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

    return AppDialogShell(
      title: widget.title,
      content: isApple
          ? CupertinoTextField(
              controller: _controller,
              maxLines: widget.maxLines,
              autofocus: true,
            )
          : TextField(
              controller: _controller,
              maxLines: widget.maxLines,
              autofocus: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
      actions: [
        AppDialogAction(
          label: 'Batal',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppDialogAction(label: 'Simpan', isPrimary: true, onPressed: _save),
      ],
    );
  }
}
