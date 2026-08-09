import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Satu tindakan dalam [AppDialogShell] / [showAppDialog].
///
/// `isPrimary` = tindakan positif (Simpan/Padam/Ya) — dirender sebagai
/// butang elevated di Material, `isDefaultAction` di Cupertino. Tindakan
/// bukan primary jadi outlined.
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

/// Rangka dialog adaptive yang boleh guna semula — CupertinoAlertDialog
/// di iOS/macOS, AlertDialog di platform lain.
///
/// Di Material, tindakan disusun **sebaris** dengan lebar sama rata:
/// outlined untuk tindakan negatif (kiri), elevated untuk yang positif
/// (kanan). Ini sengaja ganti OverflowBar default AlertDialog yang letak
/// butang teks kecil rapat di kanan — susah dicapai dengan ibu jari dan
/// keutamaan tindakan tak jelas. Di Cupertino, susunan asal platform
/// dikekalkan (dua tindakan memang dah sebaris).
///
/// Guna widget ni terus bila dialog perlu state sendiri (cth
/// `showEditTextDialog` yang pegang TextEditingController); guna
/// [showAppDialog] untuk kes ringkas tanpa state.
class AppDialogShell extends StatelessWidget {
  const AppDialogShell({
    super.key,
    required this.title,
    this.message,
    this.content,
    required this.actions,
  }) : assert(
         message == null || content == null,
         'Beri message ATAU content, bukan dua-dua',
       );

  final String title;
  final String? message;

  /// Kandungan tersuai (cth medan teks) menggantikan [message].
  final Widget? content;
  final List<AppDialogAction> actions;

  @override
  Widget build(BuildContext context) {
    final body = content ?? (message != null ? Text(message!) : null);
    final platform = Theme.of(context).platform;
    final isApple =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

    if (isApple) {
      return CupertinoAlertDialog(
        title: Text(title),
        content: body == null
            ? null
            : Padding(padding: const EdgeInsets.only(top: 10), child: body),
        actions: [
          for (final a in actions)
            CupertinoDialogAction(
              onPressed: a.onPressed,
              isDefaultAction: a.isPrimary && !a.isDestructive,
              isDestructiveAction: a.isDestructive,
              child: Text(a.label),
            ),
        ],
      );
    }

    return AlertDialog(
      title: Text(title),
      content: body,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      actions: [_MaterialActionRow(actions: actions)],
    );
  }
}

/// Papar [AppDialogShell] sebagai dialog adaptive.
///
/// Contoh:
/// ```dart
/// final ok = await showAppDialog<bool>(
///   context,
///   title: 'Padam post',
///   message: 'Anda pasti?',
///   actions: (ctx) => [
///     AppDialogAction(label: 'Batal', onPressed: () => Navigator.pop(ctx, false)),
///     AppDialogAction(
///       label: 'Padam',
///       isPrimary: true,
///       isDestructive: true,
///       onPressed: () => Navigator.pop(ctx, true),
///     ),
///   ],
/// );
/// ```
Future<T?> showAppDialog<T>(
  BuildContext context, {
  required String title,
  String? message,
  Widget? content,
  required List<AppDialogAction> Function(BuildContext context) actions,
  bool barrierDismissible = true,
}) {
  return showAdaptiveDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => AppDialogShell(
      title: title,
      message: message,
      content: content,
      actions: actions(ctx),
    ),
  );
}

/// Butang sebaris, lebar sama rata. Setiap butang dibalut Expanded supaya
/// dapat had lebar yang jelas — `filledButtonTheme` global kita set
/// `minimumSize: Size.fromHeight(54)`, iaitu lebar tak terhingga, yang
/// meletup dalam susun atur mendatar yang tak berhad.
class _MaterialActionRow extends StatelessWidget {
  const _MaterialActionRow({required this.actions});

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
