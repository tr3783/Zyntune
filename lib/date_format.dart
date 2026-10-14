// The app's standard way to show dates: "October 14, 2026".
// Use these everywhere a date is shown so formats stay consistent.

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
const _weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/// "October 14, 2026"
String formatFullDate(DateTime date) => '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';

/// "Wednesday, October 14, 2026"
String formatFullDateWithWeekday(DateTime date) => '${_weekdayNames[date.weekday - 1]}, ${formatFullDate(date)}';

/// "October 14, 2026" for dates stored as text, e.g. "2026-10-14",
/// "2026-10-14 09:30" or "2026-10-4". Returns the text unchanged if it isn't
/// a date.
String formatStoredDate(String raw) {
  final match = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(raw.trim());
  if (match == null) return raw;
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  if (month < 1 || month > 12 || day < 1 || day > 31) return raw;
  return '${_monthNames[month - 1]} $day, ${match.group(1)}';
}
