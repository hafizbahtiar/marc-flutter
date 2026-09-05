import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:marc/shared/ui/form/app_mask_formatter.dart';
import 'package:marc/shared/ui/form/custom_textfield.dart';

/// Medan teks dalam dialog adaptive: [CupertinoTextField] di iOS/macOS,
/// [CustomTextField] di platform lain.
///
/// Label kekal di luar medan (bukan floating) pada kedua-dua platform
/// supaya borang berbilang medan (bahagian, kategori) nampak satu keluarga.
class AppDialogTextField extends StatefulWidget {
  const AppDialogTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.enabled = true,
    this.autofocus = false,
    this.onChanged,
    this.inputFormatters,
    this.mask,
    this.maskFilter,
    this.maskEager = false,
    this.prefixText,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool enabled;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final String? mask;
  final Map<String, RegExp>? maskFilter;
  final bool maskEager;
  final String? prefixText;

  @override
  State<AppDialogTextField> createState() => _AppDialogTextFieldState();
}

class _AppDialogTextFieldState extends State<AppDialogTextField> {
  AppMaskTextInputFormatter? _maskFormatter;

  List<TextInputFormatter> get _formatters => [
    if (_maskFormatter != null) _maskFormatter!,
    ...?widget.inputFormatters,
  ];

  @override
  void initState() {
    super.initState();
    _syncMaskFormatter();
    _applyMaskToController();
  }

  @override
  void didUpdateWidget(AppDialogTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mask != oldWidget.mask ||
        widget.maskEager != oldWidget.maskEager) {
      _syncMaskFormatter(forceNew: true);
    }
    if (widget.mask != oldWidget.mask ||
        widget.maskEager != oldWidget.maskEager ||
        widget.controller != oldWidget.controller) {
      _applyMaskToController();
    }
  }

  void _syncMaskFormatter({bool forceNew = false}) {
    if (widget.mask == null) {
      _maskFormatter = null;
      return;
    }
    if (_maskFormatter == null || forceNew) {
      _maskFormatter = AppMaskTextInputFormatter(
        mask: widget.mask!,
        filter: widget.maskFilter,
        eager: widget.maskEager,
        initialText: widget.controller?.text,
      );
    }
  }

  void _applyMaskToController() {
    final controller = widget.controller;
    if (_maskFormatter == null ||
        controller == null ||
        controller.text.isEmpty) {
      return;
    }
    final next = _maskFormatter!.formatEditUpdate(
      TextEditingValue.empty,
      controller.value,
    );
    if (next.text != controller.text) {
      controller.value = next;
    }
  }

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final isApple =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

    if (!isApple) {
      return CustomTextField(
        controller: widget.controller,
        label: widget.label,
        hint: widget.hint,
        maxLines: widget.maxLines,
        maxLength: widget.maxLength,
        keyboardType: widget.keyboardType,
        textCapitalization: widget.textCapitalization,
        enabled: widget.enabled,
        autofocus: widget.autofocus,
        onChanged: widget.onChanged,
        inputFormatters: widget.inputFormatters,
        mask: widget.mask,
        maskFilter: widget.maskFilter,
        maskEager: widget.maskEager,
        prefixText: widget.prefixText,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.label != null && widget.label!.isNotEmpty)
          FormFieldLabel(widget.label!, enabled: widget.enabled),
        CupertinoTextField(
          controller: widget.controller,
          placeholder: widget.hint,
          prefix: widget.prefixText == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(widget.prefixText!),
                ),
          maxLines: widget.maxLines,
          maxLength: widget.maxLength,
          keyboardType: widget.keyboardType,
          textCapitalization: widget.textCapitalization,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          onChanged: widget.onChanged,
          inputFormatters: _formatters,
        ),
      ],
    );
  }
}
