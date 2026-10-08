part of '../main.dart';

// =============================================================================
// DATE HELPERS
// =============================================================================

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool inRange(DateTime d, DateTimeRange r) =>
    !d.isBefore(r.start) && d.isBefore(r.end);

DateTimeRange dayRange(DateTime d) => DateTimeRange(
    start: DateTime(d.year, d.month, d.day),
    end: DateTime(d.year, d.month, d.day + 1));

DateTimeRange weekRange(DateTime d) {
  final s = DateTime(d.year, d.month, d.day - (d.weekday - 1));
  return DateTimeRange(start: s, end: DateTime(s.year, s.month, s.day + 7));
}

DateTimeRange monthRange(DateTime d) => DateTimeRange(
    start: DateTime(d.year, d.month, 1), end: DateTime(d.year, d.month + 1, 1));

DateTimeRange yearRange(DateTime d) =>
    DateTimeRange(start: DateTime(d.year), end: DateTime(d.year + 1));

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String dayLabel(DateTime day) {
  final now = DateTime.now();
  if (sameDay(day, now)) return 'Hari Ini';
  if (sameDay(day, DateTime(now.year, now.month, now.day - 1))) {
    return 'Kemarin';
  }
  return DateFormat('EEEE, d MMM yyyy', 'id_ID').format(day);
}

DateTime nextDueDate(int dueDay, DateTime now) {
  final today = dayOnly(now);
  var d = DateTime(now.year, now.month, dueDay);
  if (d.isBefore(today)) d = DateTime(now.year, now.month + 1, dueDay);
  return d;
}
