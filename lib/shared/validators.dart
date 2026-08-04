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
