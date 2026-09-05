import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:marc/shared/ui/form/mask_field.dart';

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
    this.maskUpperCase = false,
    this.maskPreset,
    this.maskController,
    this.maskRequiredMessage,
    this.onUnmaskedChanged,
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
       ),
       assert(
         maskPreset == null || mask == null,
         'maskPreset dan mask tak boleh sekali gus',
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
  ///
  /// Untuk topeng yang dipakai lebih daripada sekali, guna [maskPreset]
  /// (`AppMasks.icMY`, dll) supaya corak, hint dan papan kekunci datang
  /// sekali gus.
  final String? mask;
  final Map<String, RegExp>? maskFilter;
  final bool maskEager;

  /// Aksara data auto huruf besar (cth kod ahli).
  final bool maskUpperCase;

  /// Topeng siap pakai dari `AppMasks`. Ia turut membekalkan [hint],
  /// [keyboardType] dan [prefixText] bila yang berkenaan tak diberi.
  /// Tak boleh sekali gus dengan [mask].
  final MaskConfig? maskPreset;

  /// Pegangan untuk baca teks tanpa topeng / status penuh dari luar.
  final MaskFieldController? maskController;

  /// Mesej ralat bila topeng belum penuh. Null = tiada semakan.
  /// [validator] sendiri diutamakan bila kedua-duanya gagal.
  final String? maskRequiredMessage;

  /// Sama macam [onChanged] tapi tanpa pemisah topeng (`011020260001`).
  final ValueChanged<String>? onUnmaskedChanged;
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

  String? get _initialValue {
    final raw = widget.initialValue;
    if (raw == null || widget.controller != null) return raw;
    return _mask.maskInitial(raw);
  }

  @override
  void initState() {
    super.initState();
    _syncMask();
  }

  @override
  void didUpdateWidget(CustomTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.obscureText != oldWidget.obscureText) {
      _obscure = widget.obscureText;
    }
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
    if (widget.controller == null) {
      _mask.syncText(_initialValue ?? '');
    }
  }

  void _handleChanged(String value) {
    _mask.syncText(value);
    widget.onChanged?.call(value);
    widget.onUnmaskedChanged?.call(_mask.unmask(value));
  }

  String? _validate(String? value) {
    final own = widget.validator?.call(value);
    if (own != null) return own;
    final message = widget.maskRequiredMessage;
    if (message != null && !_mask.isFillText(value ?? '')) return message;
    return null;
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
          keyboardType: widget.keyboardType ?? _maskConfig?.keyboardType,
          textInputAction: widget.textInputAction,
          textCapitalization: widget.textCapitalization,
          inputFormatters: _mask.formatters(widget.inputFormatters),
          validator:
              widget.validator == null && widget.maskRequiredMessage == null
              ? null
              : _validate,
          onChanged: _handleChanged,
          onFieldSubmitted: widget.onFieldSubmitted,
          maxLines: lines,
          minLines: widget.minLines,
          maxLength: widget.maxLength,
          decoration: InputDecoration(
            hintText: widget.hint ?? _maskConfig?.hint,
            prefixText: widget.prefixText ?? _maskConfig?.prefixText,
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
