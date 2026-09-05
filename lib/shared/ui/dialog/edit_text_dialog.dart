import 'package:flutter/material.dart';
import 'package:marc/shared/ui/dialog/app_dialog.dart';

/// Borang edit satu medan teks (form sheet) - pulang teks baru (trimmed)
/// bila disimpan, `null` bila dibatal/ditutup tanpa simpan.
///
/// Pembungkus [showAppInputDialog]: medan adaptive, butang Simpan mati
/// sehingga ada teks (bukan pop `null` selepas tekan Simpan kosong).
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
  int? maxLength,
}) {
  return showAppInputDialog(
    context,
    title: title,
    initialValue: initialValue,
    maxLines: maxLines,
    maxLength: maxLength,
    positiveLabel: 'Simpan',
  );
}
