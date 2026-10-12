part of '../main.dart';

// Kalender peta panas (v5.0): warna merah muda = besarnya pengeluaran harian,
// titik hijau = ada uang masuk, titik oranye = jatuh tempo (tagihan berulang
// dan cicilan yang belum dibayar), garis tebal = hari paling boros.

class CalendarMonth {
  CalendarMonth(
      {required this.income,
      required this.expense,
      required this.dueDays,
      required this.peakDay,
      required this.totalIn,
      required this.totalOut});

  /// Tanggal (1..31) ke jumlah Rupiah.
  final Map<int, double> income;
  final Map<int, double> expense;

  /// Tanggal yang punya tagihan jatuh tempo yang belum dibayar.
  final Set<int> dueDays;

  /// Tanggal pengeluaran terbesar; null kalau pengeluaran kurang dari 2 hari.
  final int? peakDay;
  final double totalIn;
  final double totalOut;

  double get maxExpense =>
      expense.values.fold(0.0, (a, b) => a > b ? a : b);
}

/// Tingkat warna 0..4 dari pengeluaran sehari dibanding hari terbesar bulan itu.
int heatLevel(double v, double max) {
  if (v <= 0 || max <= 0) return 0;
  final r = v / max;
  if (r > 0.75) return 4;
  if (r > 0.5) return 3;
  if (r > 0.25) return 2;
  return 1;
}

extension CalendarStore on AppStore {
  CalendarMonth calendarMonth(DateTime month) {
    final range = monthRange(month);
    final inc = <int, double>{};
    final exp = <int, double>{};
    var totalIn = 0.0;
    var totalOut = 0.0;
    for (final t in transactions) {
      if (!inRange(t.date, range)) continue;
      if (t.type == TxType.income) {
        final v = amountIDR(t);
        inc[t.date.day] = (inc[t.date.day] ?? 0) + v;
        totalIn += v;
      } else if (t.type == TxType.expense) {
        final v = amountIDR(t);
        exp[t.date.day] = (exp[t.date.day] ?? 0) + v;
        totalOut += v;
      }
    }
    final due = <int>{};
    for (final r in recurring) {
      if (!r.active || r.type != TxType.expense) continue;
      for (var k = 0; k < 400; k++) {
        final d = occurrence(r.start, r.frequency, r.generated + k);
        if (!d.isBefore(range.end)) break;
        if (inRange(d, range)) due.add(d.day);
      }
    }
    if (settings.feature('cicilan')) {
      for (final d in installmentsDueBefore(range.end)) {
        if (inRange(d.date, range)) due.add(d.date.day);
      }
    }
    int? peak;
    if (exp.length >= 2) {
      var best = 0.0;
      exp.forEach((day, v) {
        if (v > best) {
          best = v;
          peak = day;
        }
      });
    }
    return CalendarMonth(
        income: inc,
        expense: exp,
        dueDays: due,
        peakDay: peak,
        totalIn: totalIn,
        totalOut: totalOut);
  }
}

/// Warna kotak hari sesuai tingkat pengeluaran.
Color heatColor(int level) => switch (level) {
      0 => C.surface,
      1 => const Color(0xFFE9507A).withValues(alpha: 0.14),
      2 => const Color(0xFFE9507A).withValues(alpha: 0.28),
      3 => const Color(0xFFE9507A).withValues(alpha: 0.46),
      _ => const Color(0xFFE9507A).withValues(alpha: 0.66),
    };
