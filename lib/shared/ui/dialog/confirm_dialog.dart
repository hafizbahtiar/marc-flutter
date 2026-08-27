import 'package:flutter/material.dart';
import 'package:marc/shared/ui/dialog/app_dialog.dart';

/// Dialog pengesahan adaptive yang boleh guna semula.
///
/// Rangka + gaya butang datang dari [showAppDialog] (Cupertino di
/// iOS/macOS, Material sebaris di platform lain). Pulang `true` bila
/// disahkan, `false` bila dibatal atau ditutup.
///
/// Contoh:
/// ```dart
/// final ok = await showConfirmDialog(
///   context,
///   title: 'Log keluar',
///   message: 'Anda pasti mahu log keluar?',
///   confirmLabel: 'Log keluar',
///   isDestructive: true,
/// );
/// if (ok) { ... }
/// ```
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Ya',
  String cancelLabel = 'Batal',
  bool isDestructive = false,
}) async {
  final result = await showAppDialog<bool>(
    context,
    title: title,
    message: message,
    actions: (ctx) => [
      AppDialogAction(
        label: cancelLabel,
        onPressed: () => Navigator.of(ctx).pop(false),
      ),
      AppDialogAction(
        label: confirmLabel,
        isPrimary: true,
        isDestructive: isDestructive,
        onPressed: () => Navigator.of(ctx).pop(true),
      ),
    ],
  );
  return result ?? false;
}
