import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:marc/shared/ui/form/mask_field.dart';
import 'package:marc/shared/ui/dialog/app_dialog_action.dart';
import 'package:marc/shared/ui/dialog/app_dialog_field.dart';
import 'package:marc/shared/ui/sheet/app_form_sheet.dart';

export 'package:marc/shared/ui/dialog/app_dialog_action.dart';

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
/// (shared/ui/widgets/confirm_dialog.dart) untuk kes confirm dua-butang,
/// [showAppAlertDialog] untuk kes info satu-butang. Medan input /
/// borang guna [showAppFormSheet] / [showAppInputDialog], bukan dialog.
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
      // AlertDialog balut content dengan Flexible. Widget yang suka
      // meregang (Column lalai MainAxisSize.max, TextField) akan isi
      // sisa tinggi skrin. heightFactor: 1 paksa shrink-wrap ke anak.
      content: body == null
          ? null
          : Align(alignment: Alignment.topLeft, heightFactor: 1, child: body),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      actions: [AppDialogActionRow(actions: actions)],
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

/// Papar satu medan teks dalam [AppFormSheet] (bukan dialog) - butang
/// positif mati sehingga [validator] lulus (lalai: tak boleh kosong
/// selepas trim).
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
  List<TextInputFormatter>? inputFormatters,
  String? mask,
  Map<String, RegExp>? maskFilter,
  bool maskEager = false,
  bool maskUpperCase = false,
  MaskConfig? maskPreset,
  String? prefixText,
  bool barrierDismissible = true,
}) {
  return showAppFormSheetRoute<String>(
    context,
    barrierDismissible: barrierDismissible,
    builder: (_) => _AppInputSheet(
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
      inputFormatters: inputFormatters,
      mask: mask,
      maskFilter: maskFilter,
      maskEager: maskEager,
      maskUpperCase: maskUpperCase,
      maskPreset: maskPreset,
      prefixText: prefixText,
    ),
  );
}

class _AppInputSheet extends StatefulWidget {
  const _AppInputSheet({
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
    required this.inputFormatters,
    required this.mask,
    required this.maskFilter,
    required this.maskEager,
    required this.maskUpperCase,
    required this.maskPreset,
    required this.prefixText,
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
  final List<TextInputFormatter>? inputFormatters;
  final String? mask;
  final Map<String, RegExp>? maskFilter;
  final bool maskEager;
  final bool maskUpperCase;
  final MaskConfig? maskPreset;
  final String? prefixText;

  @override
  State<_AppInputSheet> createState() => _AppInputSheetState();
}

class _AppInputSheetState extends State<_AppInputSheet> {
  /// StatefulWidget SEMATA-MATA sebab pemilikan controller. Versi lama
  /// cipta TextEditingController lalu `dispose()` dalam `finally` selepas
  /// `await showDialog` - Future siap bila `pop`, tapi route masih
  /// beranimasi keluar dan TextField masih dibina, jadi app crash dengan
  /// "A TextEditingController was used after being disposed".
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
    return AppFormSheet(
      title: widget.title,
      message: widget.message,
      content: AppDialogTextField(
        controller: _controller,
        hint: widget.hint,
        maxLines: widget.maxLines,
        maxLength: widget.maxLength,
        keyboardType: widget.keyboardType,
        textCapitalization: widget.textCapitalization,
        autofocus: true,
        onChanged: _onChanged,
        inputFormatters: widget.inputFormatters,
        mask: widget.mask,
        maskFilter: widget.maskFilter,
        maskEager: widget.maskEager,
        maskUpperCase: widget.maskUpperCase,
        maskPreset: widget.maskPreset,
        prefixText: widget.prefixText,
      ),
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
