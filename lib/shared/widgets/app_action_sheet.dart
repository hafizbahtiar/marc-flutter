import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Satu pilihan dalam [showAppActionSheet].
///
/// `value` ialah apa yang dipulangkan bila pilihan ditekan — biasanya
/// enum, supaya switch di pemanggil exhaustive.
class AppSheetAction<T> {
  const AppSheetAction({
    required this.value,
    required this.label,
    this.icon,
    this.subtitle,
    this.isDestructive = false,
    this.isSelected = false,
    this.enabled = true,
  });

  final T value;
  final String label;

  /// Diabaikan di Cupertino — action sheet iOS tak guna ikon.
  final IconData? icon;

  /// Baris kedua yang lebih perlahan. Material sahaja.
  final String? subtitle;

  final bool isDestructive;

  /// Papar tanda semak — untuk sheet yang berfungsi sebagai pemilih
  /// (cth pilih role ahli), bukan senarai tindakan.
  final bool isSelected;

  final bool enabled;
}

/// Bottom sheet pilihan tindakan yang boleh guna semula.
///
/// Adaptive: `CupertinoActionSheet` di iOS/macOS, modal bottom sheet
/// Material di platform lain. Pulang `value` pilihan yang ditekan, atau
/// `null` bila ditutup tanpa pilih.
///
/// Contoh:
/// ```dart
/// final action = await showAppActionSheet<ContentAction>(
///   context,
///   title: 'Comment anda',
///   actions: const [
///     AppSheetAction(value: ContentAction.edit, label: 'Edit', icon: Icons.edit_outlined),
///     AppSheetAction(
///       value: ContentAction.delete,
///       label: 'Padam',
///       icon: Icons.delete_outline,
///       isDestructive: true,
///     ),
///   ],
/// );
/// ```
Future<T?> showAppActionSheet<T>(
  BuildContext context, {
  String? title,
  String? message,
  required List<AppSheetAction<T>> actions,
  String cancelLabel = 'Batal',
}) {
  final platform = Theme.of(context).platform;
  final isApple =
      platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

  if (isApple) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: title == null ? null : Text(title),
        message: message == null ? null : Text(message),
        actions: [
          for (final a in actions)
            CupertinoActionSheetAction(
              onPressed: a.enabled
                  ? () => Navigator.of(ctx).pop(a.value)
                  : () {},
              isDestructiveAction: a.isDestructive,
              isDefaultAction: a.isSelected,
              child: Text(a.label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(cancelLabel),
        ),
      ),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    // showDragHandle: pengesahan visual yang sheet ni boleh dileret turun —
    // di Material tiada butang Batal (berbeza dengan iOS), jadi affordance
    // tutup mesti jelas.
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => _MaterialActionSheet<T>(
      title: title,
      message: message,
      actions: actions,
    ),
  );
}

class _MaterialActionSheet<T> extends StatelessWidget {
  const _MaterialActionSheet({
    required this.title,
    required this.message,
    required this.actions,
  });

  final String? title;
  final String? message;
  final List<AppSheetAction<T>> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null || message != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Text(
                      title!,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (message != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      message!,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          for (final a in actions)
            ListTile(
              enabled: a.enabled,
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: a.icon == null
                  ? null
                  : Icon(
                      a.icon,
                      color: a.isDestructive ? scheme.error : scheme.onSurface,
                    ),
              title: Text(
                a.label,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: a.isDestructive ? scheme.error : scheme.onSurface,
                ),
              ),
              subtitle: a.subtitle == null ? null : Text(a.subtitle!),
              trailing: a.isSelected
                  ? Icon(Icons.check, color: scheme.primary)
                  : null,
              onTap: a.enabled
                  ? () => Navigator.of(context).pop(a.value)
                  : null,
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
