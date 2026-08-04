import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Dialog pengesahan adaptive yang boleh guna semula.
///
/// Cupertino di iOS/macOS, Material di platform lain (guna
/// `AlertDialog.adaptive`). Pulang `true` bila disahkan, `false`/`null`
/// bila dibatal atau ditutup.
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
  final result = await showAdaptiveDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog.adaptive(
      title: Text(title),
      content: Text(message),
      actions: [
        _AdaptiveAction(
          label: cancelLabel,
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
        _AdaptiveAction(
          label: confirmLabel,
          isDefault: true,
          isDestructive: isDestructive,
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ],
    ),
  );
  return result ?? false;
}

class _AdaptiveAction extends StatelessWidget {
  const _AdaptiveAction({
    required this.label,
    required this.onPressed,
    this.isDefault = false,
    this.isDestructive = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isDefault;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final isApple =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

    if (isApple) {
      return CupertinoDialogAction(
        onPressed: onPressed,
        isDefaultAction: isDefault,
        isDestructiveAction: isDestructive,
        child: Text(label),
      );
    }

    return TextButton(
      onPressed: onPressed,
      style: isDestructive
          ? TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error)
          : null,
      child: Text(label),
    );
  }
}
