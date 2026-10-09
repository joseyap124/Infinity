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

// ---------------------------------------------------------------------------
// PERIODE KEUANGAN (v3.3): "bulan" bisa mulai tanggal gajian, mis. 25.
// Diisi dari Pengaturan (AppSettings.periodStartDay) oleh AppStore.
// ---------------------------------------------------------------------------

/// Tanggal mulai periode bulanan (1 = bulan kalender biasa, maks. 28).
int gPeriodStartDay = 1;

/// Nama bulan sebuah periode. Mulai tanggal 2-15: dinamai bulan saat
/// periode mulai (5 Okt - 4 Nov = Oktober). Mulai 16-28: dinamai bulan saat
/// periode berakhir (25 Sep - 24 Okt = Oktober, gaji akhir bulan untuk bulan
/// berikutnya).
DateTime periodLabelOf(DateTime d, [int? startDay]) {
  final s = startDay ?? gPeriodStartDay;
  if (s <= 1) return DateTime(d.year, d.month);
  if (s <= 15) {
    return d.day >= s
        ? DateTime(d.year, d.month)
        : DateTime(d.year, d.month - 1);
  }
  return d.day >= s ? DateTime(d.year, d.month + 1) : DateTime(d.year, d.month);
}

/// Rentang periode untuk bulan bernama [label].
DateTimeRange periodRange(DateTime label, [int? startDay]) {
  final s = startDay ?? gPeriodStartDay;
  if (s <= 1) return monthRange(label);
  if (s <= 15) {
    return DateTimeRange(
        start: DateTime(label.year, label.month, s),
        end: DateTime(label.year, label.month + 1, s));
  }
  return DateTimeRange(
      start: DateTime(label.year, label.month - 1, s),
      end: DateTime(label.year, label.month, s));
}

/// Periode yang sedang berjalan pada tanggal [d].
DateTimeRange currentPeriod(DateTime d) => periodRange(periodLabelOf(d));

/// "25 Sep - 24 Okt" (kosong kalau periode = bulan kalender).
String periodSpanText(DateTime label) {
  if (gPeriodStartDay <= 1) return '';
  final r = periodRange(label);
  final last = r.end.subtract(const Duration(days: 1));
  return '${DateFormat('d MMM', 'id_ID').format(r.start)} - ${DateFormat('d MMM', 'id_ID').format(last)}';
}
