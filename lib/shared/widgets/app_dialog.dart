import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Satu tindakan dalam [AppDialogShell] / [showAppDialog].
///
/// `isPrimary` = tindakan positif (Simpan/Padam/Ya) - dirender sebagai
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

/// Rangka dialog adaptive yang boleh guna semula - CupertinoAlertDialog
/// di iOS/macOS, AlertDialog di platform lain.
///
/// Di Material, tindakan disusun **sebaris** dengan lebar sama rata:
/// outlined untuk tindakan negatif (kiri), elevated untuk yang positif
/// (kanan). Ini sengaja ganti OverflowBar default AlertDialog yang letak
/// butang teks kecil rapat di kanan - susah dicapai dengan ibu jari dan
/// keutamaan tindakan tak jelas. Di Cupertino, susunan asal platform
/// dikekalkan (dua tindakan memang dah sebaris).
///
/// Guna widget ni terus bila dialog perlu state sendiri; guna
/// [showAppDialog] untuk kes ringkas tanpa state, `showConfirmDialog`
/// (shared/widgets/confirm_dialog.dart) untuk kes confirm dua-butang,
/// [showAppAlertDialog] untuk kes info satu-butang, dan [showAppInputDialog]
/// bila perlu medan input (cth reason/description sebelum reject/cancel).
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

/// Papar dialog info/amaran satu-butang (cth "Sesi tamat", "Ralat rangkaian")
/// - tiada tindakan negatif kerana tiada apa nak dibatal.
Future<void> showAppAlertDialog(
  BuildContext context, {
  required String title,
  String? message,
  Widget? content,
  String buttonLabel = 'OK',
  bool barrierDismissible = true,
}) {
  return showAppDialog<void>(
    context,
    title: title,
    message: message,
    content: content,
    barrierDismissible: barrierDismissible,
    actions: (ctx) => [
      AppDialogAction(
        label: buttonLabel,
        isPrimary: true,
        onPressed: () => Navigator.pop(ctx),
      ),
    ],
  );
}

/// Papar dialog dengan satu medan teks (cth sebab penolakan/pembatalan,
/// description) - butang positif mati sehingga [validator] lulus (lalai:
/// tak boleh kosong selepas trim).
///
/// Pulang teks (trimmed) bila disahkan, `null` bila dibatal/ditutup.
///
/// Contoh:
/// ```dart
/// final reason = await showAppInputDialog(
///   context,
///   title: 'Batal aktiviti',
///   message: 'Sebab ini akan dipaparkan kepada peserta.',
///   positiveLabel: 'Sahkan batal',
///   hint: 'Sebab',
///   isDestructive: true,
/// );
/// if (reason != null) { ... }
/// ```
Future<String?> showAppInputDialog(
  BuildContext context, {
  required String title,
  String? message,
  required String positiveLabel,
  String negativeLabel = 'Batal',
  String? hint,
  String initialValue = '',
  int maxLines = 1,
  int? maxLength,
  TextInputType? keyboardType,
  TextCapitalization textCapitalization = TextCapitalization.sentences,
  bool isDestructive = false,
  bool Function(String value)? validator,
  bool barrierDismissible = true,
}) {
  return showAdaptiveDialog<String>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (_) => _AppInputDialog(
      title: title,
      message: message,
      positiveLabel: positiveLabel,
      negativeLabel: negativeLabel,
      hint: hint,
      initialValue: initialValue,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      isDestructive: isDestructive,
      validator: validator ?? (value) => value.trim().isNotEmpty,
    ),
  );
}

class _AppInputDialog extends StatefulWidget {
  const _AppInputDialog({
    required this.title,
    required this.message,
    required this.positiveLabel,
    required this.negativeLabel,
    required this.hint,
    required this.initialValue,
    required this.maxLines,
    required this.maxLength,
    required this.keyboardType,
    required this.textCapitalization,
    required this.isDestructive,
    required this.validator,
  });

  final String title;
  final String? message;
  final String positiveLabel;
  final String negativeLabel;
  final String? hint;
  final String initialValue;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool isDestructive;
  final bool Function(String value) validator;

  @override
  State<_AppInputDialog> createState() => _AppInputDialogState();
}

class _AppInputDialogState extends State<_AppInputDialog> {
  /// StatefulWidget, bukan controller tempatan dalam fungsi show*: lihat
  /// nota pemilikan controller dalam `edit_text_dialog.dart`.
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );
  late bool _valid = widget.validator(_controller.text);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final valid = widget.validator(value);
    if (valid != _valid) setState(() => _valid = valid);
  }

  void _submit() {
    if (!_valid) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final isApple =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.message != null) ...[
          Text(widget.message!),
          const SizedBox(height: 14),
        ],
        if (isApple)
          CupertinoTextField(
            controller: _controller,
            placeholder: widget.hint,
            maxLines: widget.maxLines,
            maxLength: widget.maxLength,
            keyboardType: widget.keyboardType,
            textCapitalization: widget.textCapitalization,
            autofocus: true,
            onChanged: _onChanged,
          )
        else
          TextField(
            controller: _controller,
            maxLines: widget.maxLines,
            maxLength: widget.maxLength,
            keyboardType: widget.keyboardType,
            textCapitalization: widget.textCapitalization,
            autofocus: true,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: widget.hint,
            ),
            onChanged: _onChanged,
          ),
      ],
    );

    return AppDialogShell(
      title: widget.title,
      content: body,
      actions: [
        AppDialogAction(
          label: widget.negativeLabel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppDialogAction(
          label: widget.positiveLabel,
          isPrimary: true,
          isDestructive: widget.isDestructive,
          onPressed: _valid ? _submit : null,
        ),
      ],
    );
  }
}

/// Butang sebaris, lebar sama rata. Setiap butang dibalut Expanded supaya
/// dapat had lebar yang jelas - `filledButtonTheme` global kita set
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
