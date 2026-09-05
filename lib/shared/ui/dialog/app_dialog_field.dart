import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:marc/shared/ui/form/mask_field.dart';
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
    this.maskUpperCase = false,
    this.maskPreset,
    this.maskController,
    this.onUnmaskedChanged,
    this.prefixText,
  }) : assert(
         maskPreset == null || mask == null,
         'maskPreset dan mask tak boleh sekali gus',
       );

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
  final bool maskUpperCase;

  /// Topeng siap pakai dari `AppMasks`; turut membekalkan [hint],
  /// [keyboardType] dan [prefixText]. Tak boleh sekali gus dengan [mask].
  final MaskConfig? maskPreset;

  /// Pegangan untuk baca teks tanpa topeng / status penuh dari luar.
  final MaskFieldController? maskController;

  /// Sama macam [onChanged] tapi tanpa pemisah topeng.
  final ValueChanged<String>? onUnmaskedChanged;
  final String? prefixText;

  @override
  State<AppDialogTextField> createState() => _AppDialogTextFieldState();
}

class _AppDialogTextFieldState extends State<AppDialogTextField> {
  final _mask = MaskFieldBinding();

  MaskConfig? get _maskConfig {
    if (widget.maskPreset != null) return widget.maskPreset;
    final mask = widget.mask;
    if (mask == null) return null;
    return MaskConfig(
      mask: mask,
      filter: widget.maskFilter,
      eager: widget.maskEager,
      upperCase: widget.maskUpperCase,
    );
  }

  @override
  void initState() {
    super.initState();
    _syncMask();
  }

  @override
  void didUpdateWidget(AppDialogTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.maskController != oldWidget.maskController) {
      oldWidget.maskController?.detach(_mask);
    }
    _syncMask();
  }

  @override
  void dispose() {
    widget.maskController?.detach(_mask);
    _mask.dispose();
    super.dispose();
  }

  void _syncMask() {
    _mask.update(config: _maskConfig, controller: widget.controller);
    widget.maskController?.attach(_mask);
  }

  void _handleChanged(String value) {
    _mask.syncText(value);
    widget.onChanged?.call(value);
    widget.onUnmaskedChanged?.call(_mask.unmask(value));
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
        maskUpperCase: widget.maskUpperCase,
        maskPreset: widget.maskPreset,
        maskController: widget.maskController,
        onUnmaskedChanged: widget.onUnmaskedChanged,
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
          placeholder: widget.hint ?? _maskConfig?.hint,
          prefix: (widget.prefixText ?? _maskConfig?.prefixText) == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text((widget.prefixText ?? _maskConfig!.prefixText)!),
                ),
          maxLines: widget.maxLines,
          maxLength: widget.maxLength,
          keyboardType: widget.keyboardType ?? _maskConfig?.keyboardType,
          textCapitalization: widget.textCapitalization,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          onChanged: _handleChanged,
          inputFormatters: _mask.formatters(widget.inputFormatters),
        ),
      ],
    );
  }
}
