/// Pemformat tarikh/masa untuk modul Aktiviti.
///
/// `relativeTime` sedia ada ("2j", "3h") dibina untuk post LEPAS; aktiviti
/// kebanyakannya AKAN DATANG dan pengguna perlu tarikh sebenar untuk
/// merancang. Nama bulan Melayu diselaraskan dengan `shared/utils/relative_time.dart`.
library;

const _months = [
  'Jan',
  'Feb',
  'Mac',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Ogo',
  'Sep',
  'Okt',
  'Nov',
  'Dis',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// "5 Sep 2026"
String formatDate(DateTime dt) {
  final d = dt.toLocal();
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// "09:00"
String formatTime(DateTime dt) {
  final d = dt.toLocal();
  return '${_two(d.hour)}:${_two(d.minute)}';
}

/// "5 Sep 2026, 09:00"
String formatDateTime(DateTime dt) => '${formatDate(dt)}, ${formatTime(dt)}';

/// Julat satu sesi/aktiviti, dimampatkan bila kedua-dua hujung pada hari
/// yang sama: "5 Sep 2026, 09:00 – 12:00", jika tidak
/// "5 Sep 2026, 09:00 – 6 Sep 2026, 12:00".
String formatRange(DateTime start, DateTime end) {
  final s = start.toLocal();
  final e = end.toLocal();
  final sameDay = s.year == e.year && s.month == e.month && s.day == e.day;
  return sameDay
      ? '${formatDateTime(s)} – ${formatTime(e)}'
      : '${formatDateTime(s)} – ${formatDateTime(e)}';
}
