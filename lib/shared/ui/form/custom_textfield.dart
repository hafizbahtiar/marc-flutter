import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:marc/shared/ui/form/app_mask_formatter.dart';

/// Label di atas medan borang - bukan floating `InputDecoration.label`.
///
/// Dipakai oleh [CustomTextField], [CustomDateField], [CustomImageField]
/// supaya ketiga-tiga nampak satu keluarga.
class FormFieldLabel extends StatelessWidget {
  const FormFieldLabel(
    this.text, {
    super.key,
    this.enabled = true,
    this.padding = const EdgeInsets.only(bottom: 8),
  });

  final String text;
  final bool enabled;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: padding,
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 1.2,
          letterSpacing: 0,
          color: enabled
              ? scheme.onSurface
              : scheme.onSurface.withValues(alpha: 0.38),
        ),
      ),
    );
  }
}

/// Medan teks dengan label luar. Berfungsi dalam [Form] (`validator`)
/// dan di luar (controller + `onChanged` sahaja).
///
/// [label] null = tiada label (carian, medan dalam dialog yang dah ada
/// tajuk). Jangan guna floating `InputDecoration.labelText`.
class CustomTextField extends StatefulWidget {
  const CustomTextField({
    super.key,
    this.label,
    this.controller,
    this.initialValue,
    this.hint,
    this.validator,
    this.onChanged,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.mask,
    this.maskFilter,
    this.maskEager = false,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.enabled = true,
    this.autofocus = false,
    this.prefixIcon,
    this.prefixText,
    this.suffixIcon,
    this.onFieldSubmitted,
    this.focusNode,
  }) : assert(
         controller == null || initialValue == null,
         'controller dan initialValue tak boleh sekali gus',
       );

  final String? label;
  final TextEditingController? controller;
  final String? initialValue;
  final String? hint;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;

  /// Topeng tetap (cth `****/####-****`). Null = tiada topeng.
  /// Prefix kekal (cth `MARC-`) guna [prefixText], bukan dalam nilai.
  final String? mask;
  final Map<String, RegExp>? maskFilter;
  final bool maskEager;
  final bool obscureText;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final bool enabled;
  final bool autofocus;
  final IconData? prefixIcon;
  final String? prefixText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onFieldSubmitted;
  final FocusNode? focusNode;

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late bool _obscure = widget.obscureText;
  AppMaskTextInputFormatter? _maskFormatter;

  List<TextInputFormatter> get _formatters => [
    if (_maskFormatter != null) _maskFormatter!,
    ...?widget.inputFormatters,
  ];

  String? get _initialValue {
    final raw = widget.initialValue;
    if (raw == null || _maskFormatter == null || widget.controller != null) {
      return raw;
    }
    return _maskFormatter!
        .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: raw))
        .text;
  }

  @override
  void initState() {
    super.initState();
    _syncMaskFormatter();
    _applyMaskToController(widget.controller);
  }

  @override
  void didUpdateWidget(CustomTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.obscureText != oldWidget.obscureText) {
      _obscure = widget.obscureText;
    }
    if (widget.mask != oldWidget.mask ||
        widget.maskEager != oldWidget.maskEager) {
      _syncMaskFormatter(forceNew: true);
    }
    if (widget.mask != oldWidget.mask ||
        widget.maskEager != oldWidget.maskEager ||
        widget.controller != oldWidget.controller) {
      _applyMaskToController(widget.controller);
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
        initialText: widget.initialValue ?? widget.controller?.text,
      );
    }
  }

  void _applyMaskToController(TextEditingController? controller) {
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
    final scheme = Theme.of(context).colorScheme;
    final lines = widget.obscureText ? 1 : widget.maxLines;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null && widget.label!.isNotEmpty)
          FormFieldLabel(widget.label!, enabled: widget.enabled),
        TextFormField(
          controller: widget.controller,
          initialValue: widget.controller == null ? _initialValue : null,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          obscureText: _obscure,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          textCapitalization: widget.textCapitalization,
          inputFormatters: _formatters,
          validator: widget.validator,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onFieldSubmitted,
          maxLines: lines,
          minLines: widget.minLines,
          maxLength: widget.maxLength,
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixText: widget.prefixText,
            floatingLabelBehavior: FloatingLabelBehavior.never,
            prefixIcon: widget.prefixIcon == null
                ? null
                : Icon(
                    widget.prefixIcon,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
            suffixIcon: widget.obscureText
                ? IconButton(
                    tooltip: _obscure ? 'Tunjuk' : 'Sembunyi',
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                    onPressed: widget.enabled
                        ? () => setState(() => _obscure = !_obscure)
                        : null,
                  )
                : widget.suffixIcon,
          ),
        ),
      ],
    );
  }
}
