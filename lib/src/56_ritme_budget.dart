part of '../main.dart';

// Ritme anggaran (v5.0): membandingkan pemakaian dengan posisi hari di periode,
// supaya status terbaca tanpa bergantung warna.

/// Penanda per kategori: lebih cepat, pas, atau lebih hemat dari ritme.
enum PaceTag { fast, even, slow }

/// Selisih (dalam titik persen dari batas) yang masih dianggap pas.
const double kPaceTolerance = 0.10;

/// Bagian periode yang sudah berjalan, 0..1. Hari ini dihitung penuh.
/// [range] berakhir eksklusif (awal periode berikutnya).
double periodElapsed(DateTimeRange range, DateTime now) {
  final start = DateTime(range.start.year, range.start.month, range.start.day);
  final end = DateTime(range.end.year, range.end.month, range.end.day);
  final total = end.difference(start).inDays;
  if (total <= 0) return 1.0;
  final today = DateTime(now.year, now.month, now.day);
  final done = today.difference(start).inDays + 1;
  return (done / total).clamp(0.0, 1.0).toDouble();
}

/// Pemakaian yang "seharusnya" sampai hari ini kalau merata sepanjang periode.
double expectedSpent(double limit, double elapsed) => limit * elapsed;

/// Selisih pemakaian nyata terhadap ritme (positif = lebih cepat).
double paceDiff(double spent, double limit, double elapsed) =>
    spent - expectedSpent(limit, elapsed);

PaceTag paceTagFor(double spent, double limit, double elapsed) {
  if (limit <= 0) return PaceTag.even;
  final d = spent / limit - elapsed;
  if (d > kPaceTolerance) return PaceTag.fast;
  if (d < -kPaceTolerance) return PaceTag.slow;
  return PaceTag.even;
}

extension PaceTagText on PaceTag {
  String get symbol => switch (this) {
        PaceTag.fast => '▲',
        PaceTag.even => '●',
        PaceTag.slow => '▼',
      };
  String get label => switch (this) {
        PaceTag.fast => 'Cepat',
        PaceTag.even => 'Pas',
        PaceTag.slow => 'Hemat',
      };
  Color get color => switch (this) {
        PaceTag.fast => C.amberDark,
        PaceTag.even => C.muted,
        PaceTag.slow => C.income,
      };
}

/// Baris Ritme di kartu utama Beranda (v6.9.0) disembunyikan hanya saat anggaran
/// sudah habis (>= 100%) dan jatah harian 0: catatan di kartu utama sudah
/// menyebut persennya. [usedWhenZero] = AppStore.budgetUsedWhenNoAllowance.
bool showRitmeInHero(double? usedWhenZero) =>
    usedWhenZero == null || usedWhenZero < 1;

/// Kalimat ritme untuk kartu budget: "▲ Lebih cepat Rp400.000 dari ritme".
/// Selisih di bawah 2% batas dianggap pas.
String paceSentence(double spent, double limit, double elapsed) {
  final d = paceDiff(spent, limit, elapsed);
  if (limit <= 0 || d.abs() < limit * 0.02) return '● Pas dengan ritme';
  return d > 0
      ? tr('▲ Lebih cepat {0} dari ritme', [money(d)])
      : tr('▼ Lebih hemat {0} dari ritme', [money(-d)]);
}

/// Bar sisa kuota dengan penanda putih "seharusnya sekarang".
class PaceBar extends StatelessWidget {
  const PaceBar(
      {super.key,
      required this.value,
      required this.color,
      required this.marker,
      this.height = 14});

  /// Isi bar (0..1): sisa kuota untuk kartu utama, terpakai untuk per kategori.
  final double value;
  final Color color;

  /// Posisi ritme pada bar, 0..1. Untuk bar sisa kuota: 1 - bagian berjalan;
  /// untuk bar terpakai: bagian berjalan.
  final double marker;
  final double height;

  @override
  Widget build(BuildContext context) {
    final m = marker.clamp(0.0, 1.0).toDouble();
    return Semantics(
      label: tr('Penanda ritme di {0}%', [(m * 100).round()]),
      child: LayoutBuilder(builder: (context, c) {
        final x = c.maxWidth * m;
        return SizedBox(
          height: height + 6,
          child: Stack(
            alignment: Alignment.center,
            children: [
              FunProgressBar(value: value, color: color, height: height),
              Positioned(
                left: (x - 1.5).clamp(0.0, c.maxWidth - 3),
                top: 0,
                bottom: 0,
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(
                        color: Colors.black.withValues(alpha: 0.35), width: 0.6),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// Hari-hari data minimal sebelum perkiraan "uang habis" ditampilkan.
const int kRunOutMinDays = 5;

/// Perkiraan kapan uang habis kalau pengeluaran harian rata-rata terus berlanjut.
/// [remaining] sisa uang setelah belanja hari ini; null kalau tidak ada rata-rata.
DateTime? runOutDate(
    {required double remaining,
    required double spentSoFar,
    required int daysElapsed,
    required DateTime today}) {
  if (daysElapsed <= 0 || spentSoFar <= 0) return null;
  final avg = spentSoFar / daysElapsed;
  if (remaining <= 0) return DateTime(today.year, today.month, today.day);
  final d = (remaining / avg).floor();
  return DateTime(today.year, today.month, today.day + d);
}

/// Kalimat perkiraan untuk lembar "Dari mana angka ini?".
String runOutSentence(AppStore store, SafeSpend s, DateTime now) {
  final start = s.fromBudget
      ? store.settings.budgetPeriod.range(now).start
      : DateTime(now.year, now.month, 1);
  final today = DateTime(now.year, now.month, now.day);
  final startDay = DateTime(start.year, start.month, start.day);
  final daysElapsed = today.difference(startDay).inDays + 1;
  if (daysElapsed < kRunOutMinDays) {
    return 'Data pengeluaran periode ini masih sedikit, perkiraan uang habis muncul setelah beberapa hari.';
  }
  final spent = store.sumIDR(TxType.expense, DateTimeRange(start: start, end: s.periodEnd));
  final out = runOutDate(
      remaining: s.base - s.spentTodayAll,
      spentSoFar: spent,
      daysElapsed: daysElapsed,
      today: today);
  final last = s.periodEnd.subtract(const Duration(days: 1));
  if (out == null || !out.isBefore(DateTime(last.year, last.month, last.day))) {
    return 'Dengan kecepatan sekarang, uangmu cukup sampai akhir periode.';
  }
  return tr('Dengan kecepatan sekarang, uang habis sekitar {0}.',
      [DateFormat('d MMM', gDateLoc).format(out)]);
}
