import 'package:marc/shared/utils/phone.dart';

/// Validator email - null = sah.
String? validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Email diperlukan';
  }
  final regex = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
  if (!regex.hasMatch(value.trim())) {
    return 'Format email tidak sah';
  }
  return null;
}

/// Validator nombor telefon - null = sah. Malaysia sahaja buat masa ini
/// (padanan `phone.NormalizeMY` di backend) - lihat `shared/utils/phone.dart`
/// untuk cara tambah negara lain kelak.
String? validatePhone(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Nombor telefon diperlukan';
  }
  if (normalizeMY(value) == null) {
    return 'Format nombor telefon Malaysia tidak sah';
  }
  return null;
}

/// Validator kata laluan - null = sah.
String? validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Kata laluan diperlukan';
  }
  if (value.length < 6) {
    return 'Kata laluan mesti sekurangnya 6 aksara';
  }
  return null;
}

/// Validator nombor staff - null = sah. Tiada semakan format organisasi
/// (rentetan legap) - wajib, trim, maksimum 64 aksara, dan `/` ditolak
/// kerana ia pemisah struktur `member_id` (`MARC-{staff_id}/{tahun}-{kod}`).
String? validateStaffId(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return 'Nombor staff wajib diisi';
  }
  if (trimmed.length > 64) {
    return 'Nombor staff tidak boleh lebih 64 aksara';
  }
  if (trimmed.contains('/')) {
    return "Nombor staff tidak boleh mengandungi '/'";
  }
  return null;
}
