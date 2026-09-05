import 'package:flutter/services.dart';
import 'package:marc/shared/ui/form/app_mask_formatter.dart';
import 'package:marc/shared/ui/form/app_masks.dart';

/// Format rasmi no. ahli: `MARC-{staff}/{tahun}-{kod}`
/// (cth `MARC-0110/2026-0001`, `MARC-0110/2026-SA`).
///
/// Format lama `MARC{YYYY}/{MM}/{seq}` (cth `MARC2026/08/0001`) dibiarkan
/// pada rekod sedia ada - editor mula semula dengan topeng baru.
final _newFormat = RegExp(r'^MARC-.+/\d{4}-.+$');
final _legacyFormat = RegExp(r'^MARC\d{4}/\d{2}/\d+$');

String _normalize(String raw) =>
    raw.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();

/// Buang ruang dan pemisah supaya carian `marc011020260001` padan
/// `MARC-0110/2026-0001`.
String unmaskMemberId(String raw) =>
    _normalize(raw).replaceAll(RegExp(r'[/\-]'), '');

/// Topeng nombor ahli - corak sama `PremiseLicenseFileNo` (ilms):
/// prefix `MARC-` di luar medan, body `****/####-****` auto semasa taip.
abstract final class MemberId {
  /// Satu sumber kebenaran untuk corak, hint dan awalan - medan borang
  /// terus guna `AppMasks.memberId`, bukan salin corak di sini.
  static const config = AppMasks.memberId;

  static String get prefix => config.prefixText!;
  static String get mask => config.mask;
  static String get hint => config.hint!;

  static final bodyFormat = RegExp(r'^[A-Z0-9]{4}/\d{4}-[A-Z0-9]{1,4}$');

  static String removePrefix(String? value) {
    if (value == null || value.isEmpty) return '';
    return value.trim().replaceFirst(
      RegExp(r'^MARC-?', caseSensitive: false),
      '',
    );
  }

  static TextEditingValue maskValue(String input) {
    return AppMaskTextInputFormatter(
      mask: config.mask,
      filter: config.filter,
      eager: config.eager,
      upperCase: config.upperCase,
    ).formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: input));
  }

  static String formatForSubmit(String? value) {
    if (value == null || value.trim().isEmpty) return '';
    final s = _normalize(value);
    if (_legacyFormat.hasMatch(s) || _newFormat.hasMatch(s)) return s;
    final body = maskValue(removePrefix(s)).text;
    if (body.isEmpty) return '';
    return '$prefix$body';
  }

  static String? validateBody(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nombor ahli diperlukan';
    }
    if (!bodyFormat.hasMatch(value.trim().toUpperCase())) {
      return 'Format: MARC-{staff}/{tahun}-{kod}';
    }
    return null;
  }
}

/// Susun ke format rasmi bila cukup maklumat; format lama tak diubah.
String maskMemberId(String raw) => MemberId.formatForSubmit(raw);

/// Null = sah. Terima format rasmi ATAU format lama (ahli sedia ada).
String? validateMemberId(String? value) {
  final s = value?.trim() ?? '';
  if (s.isEmpty) return 'Nombor ahli diperlukan';
  if (s.length > 128) return 'Nombor ahli tidak boleh lebih 128 aksara';
  final masked = maskMemberId(s);
  if (_newFormat.hasMatch(masked) || _legacyFormat.hasMatch(masked)) {
    return null;
  }
  return 'Format: MARC-{staff}/{tahun}-{kod}';
}

bool isLegacyMemberId(String? raw) {
  final s = raw?.trim() ?? '';
  return s.isNotEmpty && _legacyFormat.hasMatch(_normalize(s));
}

/// Medan editor: prefix `MARC-` di luar, [initialValue] ialah body topeng.
({String initialValue, String? message}) memberIdEditorSeed(String? current) {
  final s = current?.trim() ?? '';
  if (s.isEmpty) {
    return (initialValue: '', message: null);
  }
  if (isLegacyMemberId(s)) {
    return (
      initialValue: '',
      message: 'Format lama: $s. Isi format baru MARC-{staff}/{tahun}-{kod}.',
    );
  }
  final body = MemberId.maskValue(MemberId.removePrefix(s)).text;
  if (MemberId.bodyFormat.hasMatch(body)) {
    return (initialValue: body, message: null);
  }
  return (
    initialValue: '',
    message: 'Nombor semasa: $s. Isi semula ikut topeng.',
  );
}
