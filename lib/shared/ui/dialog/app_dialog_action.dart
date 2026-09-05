import 'package:flutter/material.dart';

/// Satu tindakan dalam [AppDialogShell] / [showAppDialog] / [AppFormSheet].
///
/// `isPrimary` = tindakan positif (Simpan/Padam/Ya) - dirender sebagai
/// butang elevated. Tindakan bukan primary jadi outlined.
class AppDialogAction {
  const AppDialogAction({
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
    this.isDestructive = false,
  });

  final String label;

  /// `null` = butang dimatikan (cth semasa borang tak sah).
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isDestructive;
}

/// Butang sebaris, lebar sama rata. Setiap butang dibalut Expanded supaya
/// dapat had lebar yang jelas - `filledButtonTheme` global kita set
/// `minimumSize: Size.fromHeight(54)`, iaitu lebar tak terhingga, yang
/// meletup dalam susun atur mendatar yang tak berhad.
///
/// Dikongsi dialog Material dan form sheet.
class AppDialogActionRow extends StatelessWidget {
  const AppDialogActionRow({super.key, required this.actions});

  final List<AppDialogAction> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: _actionButton(context, actions[i])),
        ],
      ],
    );
  }

  Widget _actionButton(BuildContext context, AppDialogAction a) {
    final scheme = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    const minimumSize = Size.fromHeight(48);
    final textStyle = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600);

    if (a.isPrimary) {
      return ElevatedButton(
        onPressed: a.onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: a.isDestructive ? scheme.error : scheme.primary,
          foregroundColor: a.isDestructive ? scheme.onError : scheme.onPrimary,
          minimumSize: minimumSize,
          shape: shape,
          textStyle: textStyle,
          elevation: 1,
        ),
        child: Text(a.label),
      );
    }

    return OutlinedButton(
      onPressed: a.onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: a.isDestructive ? scheme.error : scheme.onSurface,
        minimumSize: minimumSize,
        shape: shape,
        textStyle: textStyle,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Text(a.label),
    );
  }
}
