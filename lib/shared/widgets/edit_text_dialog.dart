import 'package:flutter/material.dart';

/// Dialog ringkas untuk edit satu medan teks — pulang teks baru (trimmed)
/// bila disimpan, `null` bila dibatal/ditutup tanpa simpan.
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
}) async {
  final controller = TextEditingController(text: initialValue);
  try {
    return await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: maxLines,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              Navigator.of(ctx).pop(text.isEmpty ? null : text);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  } finally {
    controller.dispose();
  }
}
