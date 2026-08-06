/// Format masa relatif ringkas (macam Twitter: "5m", "3j", "2h") — bukan
/// full timestamp, untuk feed yang padat.
String relativeTime(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);

  if (diff.inSeconds < 60) return 'baru';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}j';
  if (diff.inDays < 7) return '${diff.inDays}h';

  final months = [
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
  return '${dateTime.day} ${months[dateTime.month - 1]}';
}
