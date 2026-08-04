import 'package:supabase_flutter/supabase_flutter.dart';

/// Validator email — null = sah.
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

/// Validator kata laluan — null = sah.
String? validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Kata laluan diperlukan';
  }
  if (value.length < 6) {
    return 'Kata laluan mesti sekurangnya 6 aksara';
  }
  return null;
}

/// Petik AuthException ke mesej Melayu mesra.
String mapAuthErrorToMessage(AuthException e) {
  switch (e.code) {
    case 'invalid_credentials':
      return 'Email atau kata laluan salah';
    case 'email_not_confirmed':
      return 'Sila sahkan email anda dahulu';
    case 'user_already_exists':
    case 'email_exists':
      return 'Email ini sudah berdaftar';
    case 'weak_password':
      return 'Kata laluan terlalu lemah (minimum 6 aksara)';
    default:
      return e.message;
  }
}