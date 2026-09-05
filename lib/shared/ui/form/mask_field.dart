import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:marc/shared/ui/form/app_mask_formatter.dart';

/// Satu topeng lengkap — corak, penapis, dan cadangan UI yang pergi
/// bersamanya. Dipakai terus sebagai `maskPreset` pada medan borang,
/// atau dibina di tempat untuk topeng sekali guna.
///
/// Bandingkan nilai (bukan identiti) supaya `didUpdateWidget` tak bina
/// formatter baharu setiap kali widget dibina semula.
@immutable
class MaskConfig {
  const MaskConfig({
    required this.mask,
    this.filter,
    this.eager = false,
    this.upperCase = false,
    this.hint,
    this.keyboardType,
    this.prefixText,
  });

  /// Corak topeng, cth `****/####-****`.
  final String mask;

  /// Slot tambahan/ganti. Null = lalai (`#` digit, `*` huruf/digit).
  final Map<String, RegExp>? filter;

  /// Literal masuk terus lepas slot penuh.
  final bool eager;

  /// Aksara data auto huruf besar.
  final bool upperCase;

  /// Cadangan `hint` medan (cth `0110/2026-0001`).
  final String? hint;

  /// Papan kekunci yang sesuai (cth [TextInputType.number]).
  final TextInputType? keyboardType;

  /// Awalan kekal di luar nilai medan (cth `MARC-`).
  final String? prefixText;

  MaskConfig copyWith({String? hint, String? prefixText}) => MaskConfig(
    mask: mask,
    filter: filter,
    eager: eager,
    upperCase: upperCase,
    hint: hint ?? this.hint,
    keyboardType: keyboardType,
    prefixText: prefixText ?? this.prefixText,
  );

  static bool _sameFilter(Map<String, RegExp>? a, Map<String, RegExp>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null || a.length != b.length) return false;
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null || other.pattern != entry.value.pattern) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is MaskConfig &&
      other.mask == mask &&
      other.eager == eager &&
      other.upperCase == upperCase &&
      other.hint == hint &&
      other.keyboardType == keyboardType &&
      other.prefixText == prefixText &&
      _sameFilter(other.filter, filter);

  @override
  int get hashCode => Object.hash(
    mask,
    eager,
    upperCase,
    hint,
    keyboardType,
    prefixText,
    // RegExp tiada `==` yang berguna — guna corak supaya padan `_sameFilter`.
    Object.hashAllUnordered(
      filter?.entries.map((e) => Object.hash(e.key, e.value.pattern)) ??
          const <int>[],
    ),
  );
}

/// Kitaran hayat topeng untuk satu medan teks: bina formatter bila config
/// berubah, topeng teks controller (termasuk yang ditetapkan dari luar),
/// dan dedah teks tanpa topeng kepada pemanggil.
///
/// Dikongsi oleh `CustomTextField` dan `AppDialogTextField` supaya
/// kelakuan topeng sama pada Material dan Cupertino.
/// Pegangan awam untuk pemanggil: baca teks mentah dan status topeng
/// medan tanpa perlu simpan `TextEditingController` sendiri.
///
/// ```dart
/// final memberId = MaskFieldController();
/// CustomTextField(maskPreset: AppMasks.memberId, maskController: memberId);
/// // ...
/// if (memberId.isFill) submit(memberId.unmaskedText);
/// ```
class MaskFieldController {
  MaskFieldBinding? _binding;

  /// Dipanggil oleh medan borang; bukan untuk pemanggil biasa.
  void attach(MaskFieldBinding binding) => _binding = binding;

  /// Dipanggil oleh medan borang bila ia dilupuskan.
  void detach(MaskFieldBinding binding) {
    if (identical(_binding, binding)) _binding = null;
  }

  /// `''` kalau tiada medan aktif.
  String get maskedText => _binding?.maskedText ?? '';

  /// `''` kalau tiada medan aktif.
  String get unmaskedText => _binding?.unmaskedText ?? '';

  /// `false` kalau tiada medan aktif.
  bool get isFill => _binding?.isFill ?? false;
}

class MaskFieldBinding {
  MaskConfig? _config;
  AppMaskTextInputFormatter? _formatter;
  TextEditingController? _controller;
  String _text = '';
  bool _applying = false;

  AppMaskTextInputFormatter? get formatter => _formatter;

  MaskConfig? get config => _config;

  /// Teks medan seperti dipaparkan (cth `0110/2026-0001`).
  String get maskedText => _text;

  /// Teks medan tanpa pemisah topeng (cth `011020260001`).
  String get unmaskedText => unmask(_text);

  /// Semua slot topeng terisi?
  bool get isFill => isFillText(_text);

  /// Medan tanpa controller sendiri (cth `TextFormField` dengan
  /// `initialValue`) lapor teks terkini melalui `onChanged`.
  void syncText(String text) => _text = text;

  String unmask(String text) => _formatter?.unmaskText(text) ?? text;

  /// Tanpa topeng, apa-apa teks dikira lengkap.
  bool isFillText(String text) =>
      _formatter == null || _formatter!.isFillText(text);

  /// Topeng nilai awal (cth `initialValue` widget) tanpa ubah keadaan
  /// formatter aktif.
  String maskInitial(String raw) => _formatter?.maskText(raw) ?? raw;

  List<TextInputFormatter> formatters(List<TextInputFormatter>? extra) => [
    ?_formatter,
    ...?extra,
  ];

  /// Panggil dari `initState` dan `didUpdateWidget`. Selamat dipanggil
  /// berulang — formatter dibina semula hanya bila [config] berubah nilai.
  void update({
    required MaskConfig? config,
    TextEditingController? controller,
  }) {
    final configChanged = config != _config;
    if (configChanged) {
      _config = config;
      _formatter = config == null
          ? null
          : AppMaskTextInputFormatter(
              mask: config.mask,
              filter: config.filter,
              eager: config.eager,
              upperCase: config.upperCase,
            );
    }

    final controllerChanged = !identical(controller, _controller);
    if (controllerChanged) {
      _controller?.removeListener(_onControllerChanged);
      _controller = controller;
      _controller?.addListener(_onControllerChanged);
    }
    if (controllerChanged) _text = controller?.text ?? '';
    if (configChanged || controllerChanged) _applyToController();
  }

  void dispose() {
    _controller?.removeListener(_onControllerChanged);
    _controller = null;
  }

  void _onControllerChanged() {
    _applyToController();
    _text = _controller?.text ?? '';
  }

  void _applyToController() {
    final controller = _controller;
    final formatter = _formatter;
    if (controller == null || formatter == null || _applying) return;
    if (controller.text.isEmpty) return;

    _applying = true;
    try {
      final next = formatter.formatEditUpdate(
        TextEditingValue.empty,
        controller.value,
      );
      if (next.text != controller.text) controller.value = next;
      _text = controller.text;
    } finally {
      _applying = false;
    }
  }
}
