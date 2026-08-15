/// Sahkan & normalisasi nombor telefon ikut negara — SATU fungsi setiap
/// negara (padanan `internal/phone` di backend Go). Tambah negara lain
/// kelak = tambah fungsi baharu (`normalizeSG`, dll), bukan ubah yang
/// sedia ada.
///
/// Buat masa ini cuma Malaysia (keputusan produk 2026-08-15).
library;

// '1' dikecualikan drpd kelas digit ketiga (bukan sekadar '5') — kalau
// tidak "011"+7 digit (10 digit) turut lulus cabang biasa, bertindih
// dgn cabang 011 di bawah yang sengaja 11 digit. Padan `myMobileRegex`
// backend Go (`internal/phone/phone.go`) — dua-dua kena sama supaya
// tiada kes klien terima tapi server tolak.
final _myMobileRegex = RegExp(r'^(01[02-46-9]\d{7}|011\d{8})$');

/// normalizeMY bersihkan (buang space/dash/kurungan) dan sahkan nombor
/// mudah alih Malaysia. Terima awalan `+60`, `60`, atau `0`. Pulang
/// bentuk TEMPATAN ternormal (`0XXXXXXXXX`), atau `null` kalau tak sah.
String? normalizeMY(String raw) {
  var s = raw.trim().replaceAll(RegExp(r'[\s\-()]'), '');

  if (s.startsWith('+60')) {
    s = '0${s.substring(3)}';
  } else if (s.startsWith('60') && s.length >= 11) {
    s = '0${s.substring(2)}';
  }

  if (!_myMobileRegex.hasMatch(s)) return null;
  return s;
}
