/// Turning moments into text.
///
/// How a moment is written depends on how much of it is on screen: a one-second candle needs
/// seconds to be identifiable, while a daily one reading "14:32" would be noise.
library;

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _pad(int v) => v.toString().padLeft(2, '0');

/// `07 Mar 2026`
String day(DateTime t) => '${_pad(t.day)} ${_months[t.month - 1]} ${t.year}';

/// `07 Mar · 14:32`
String dayAndTime(DateTime t) =>
    '${_pad(t.day)} ${_months[t.month - 1]} · ${_pad(t.hour)}:${_pad(t.minute)}';

/// `14:32`
String time(DateTime t) => '${_pad(t.hour)}:${_pad(t.minute)}';

/// `14:32:05`
String timeWithSeconds(DateTime t) =>
    '${_pad(t.hour)}:${_pad(t.minute)}:${_pad(t.second)}';

/// Relative for anything recent, absolute once relative stops being useful. "43 days ago"
/// tells nobody anything a date would not tell them better.
String ago(DateTime t, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final minutes = reference.difference(t).inMinutes;
  if (minutes < 1) return 'Just now';
  if (minutes < 60) return '$minutes min ago';
  final hours = (minutes / 60).round();
  if (hours < 24) return '$hours h ago';
  final days = (hours / 24).round();
  if (days == 1) return 'Yesterday';
  if (days < 30) return '$days days ago';
  return day(t);
}
