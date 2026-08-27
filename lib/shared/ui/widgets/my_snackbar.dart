import 'package:flutter/material.dart';

/// Reusable SnackBar helper - floating as default.
///
/// Usage:
///   MySnackBar.show(context, 'Profil dikemas kini.');
///   MySnackBar.error(context, 'Gagal simpan. Cuba lagi.');
///   MySnackBar.success(context, 'Berjaya disimpan.');
class MySnackBar {
  MySnackBar._();

  static void show(
    BuildContext context,
    String message, {
    SnackBarBehavior behavior = SnackBarBehavior.floating,
    Duration duration = const Duration(seconds: 3),
    Color? background,
    Color? foreground,
    IconData? icon,
    SnackBarAction? action,
  }) {
    final scheme = Theme.of(context).colorScheme;
    // Background = inverseSurface (gelap), jadi foreground = onInverseSurface.
    final fg = foreground ?? scheme.onInverseSurface;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: fg),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(message, style: TextStyle(color: fg)),
              ),
            ],
          ),
          behavior: behavior,
          duration: duration,
          backgroundColor: background ?? scheme.inverseSurface,
          action: action,
        ),
      );
  }

  static void success(BuildContext context, String message) =>
      show(context, message, icon: Icons.check_circle_rounded);

  static void error(BuildContext context, String message) =>
      show(context, message, icon: Icons.error_outline_rounded);

  static void info(BuildContext context, String message) =>
      show(context, message, icon: Icons.info_outline_rounded);
}
