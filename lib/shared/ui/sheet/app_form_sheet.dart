import 'package:flutter/material.dart';
import 'package:marc/shared/ui/dialog/app_dialog_action.dart';
import 'package:marc/shared/ui/sheet/sheet_handle.dart';

/// Borang dalam modal bottom sheet - medan + tindakan, bukan senarai
/// pilihan ([showAppActionSheet]) dan bukan kad peta ([AppInfoSheet]).
///
/// Satu rupa di semua platform: form dalam [CupertinoActionSheet] salah
/// (HIG), jadi kita tak adaptive di sini. Confirm/alert kekal dialog.
class AppFormSheet extends StatelessWidget {
  const AppFormSheet({
    super.key,
    required this.title,
    this.message,
    required this.content,
    required this.actions,
  });

  final String title;
  final String? message;
  final Widget content;
  final List<AppDialogAction> actions;

  static const _fieldMaxFraction = 0.5;
  static const _radius = 28.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final media = MediaQuery.of(context);
    final fieldMax = media.size.height * _fieldMaxFraction;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Material(
        color: scheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(_radius)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.only(bottom: media.padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ModalSheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        message!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: fieldMax),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                  children: [content],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: AppDialogActionRow(actions: actions),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Papar [AppFormSheet] sebagai modal bottom sheet.
///
/// Contoh:
/// ```dart
/// final result = await showAppFormSheet<(String, String)>(
///   context,
///   title: 'Tambah Bahagian',
///   content: _DepartmentForm(key: formKey),
///   actions: (ctx) => [
///     AppDialogAction(label: 'Batal', onPressed: () => Navigator.pop(ctx)),
///     AppDialogAction(
///       label: 'Tambah',
///       isPrimary: true,
///       onPressed: () => formKey.currentState?.submit(),
///     ),
///   ],
/// );
/// ```
Future<T?> showAppFormSheet<T>(
  BuildContext context, {
  required String title,
  String? message,
  required Widget content,
  required List<AppDialogAction> Function(BuildContext context) actions,
  bool barrierDismissible = true,
}) {
  return showAppFormSheetRoute<T>(
    context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => AppFormSheet(
      title: title,
      message: message,
      content: content,
      actions: actions(ctx),
    ),
  );
}

/// Route sheet sahaja - untuk [AppFormSheet] yang dibina oleh
/// StatefulWidget (cth input: butang hidup/mati ikut medan).
Future<T?> showAppFormSheetRoute<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    isDismissible: barrierDismissible,
    enableDrag: barrierDismissible,
    builder: builder,
  );
}
