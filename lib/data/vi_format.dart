String _two(int n) => n.toString().padLeft(2, '0');

/// 30 · 10 · 2022
String dotDate(DateTime d) => '${_two(d.day)} · ${_two(d.month)} · ${d.year}';

/// tháng 10 · 2026
String monthLabel(DateTime d) => 'tháng ${d.month} · ${d.year}';

/// 1462 → 1.462
String thousands(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');

/// Whole calendar days from [from] to [to], ignoring time of day.
int daysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// The first date on or after [today] that falls on [date]'s day and month.
DateTime nextOccurrence(DateTime date, DateTime today) {
  final thisYear = DateTime(today.year, date.month, date.day);
  return daysBetween(today, thisYear) >= 0 ? thisYear : DateTime(today.year + 1, date.month, date.day);
}
