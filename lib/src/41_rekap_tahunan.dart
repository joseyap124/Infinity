part of '../main.dart';

// =============================================================================
// REKAP TAHUNAN (Statistik → Rekap tahun ...)
// =============================================================================

class YearRecap {
  const YearRecap({
    required this.year,
    required this.income,
    required this.expense,
    required this.monthlyExpense,
    required this.monthlyIncome,
    required this.topCategories,
    required this.topTitles,
    required this.biggest,
    required this.txCount,
    required this.netWorthStart,
    required this.netWorthEnd,
    required this.days,
  });

  final int year;
  final double income;
  final double expense;
  final List<double> monthlyExpense; // 12 bulan
  final List<double> monthlyIncome;
  final List<MapEntry<String, double>> topCategories;
  final List<MapEntry<String, double>> topTitles;
  final Transaction? biggest;
  final int txCount;
  final double netWorthStart;
  final double netWorthEnd;

  /// Hari yang dihitung (tahun berjalan: sampai hari ini).
  final int days;

  double get net => income - expense;
  double? get savingRate => income > 0 ? net / income : null;
}

extension YearRecapStore on AppStore {
  /// Kekayaan bersih (Rupiah, kurs sekarang) dari transaksi sebelum [cutoff].
  double netWorthAt(DateTime cutoff) {
    final m = <String, double>{for (final a in accounts) a.id: a.initialBalance};
    for (final t in transactions) {
      if (!t.date.isBefore(cutoff)) continue;
      for (final a in accounts) {
        final d = accountDelta(t, a.id);
        if (d != 0) m[a.id] = m[a.id]! + d;
      }
    }
    var sum = 0.0;
    for (final a in accounts) {
      sum += m[a.id]! * rate(a.currency);
    }
    return sum;
  }

  /// Tahun yang punya transaksi, terbaru dulu (tahun ini selalu ada).
  List<int> recapYears(DateTime now) {
    final ys = {now.year, for (final t in transactions) t.date.year}.toList()
      ..sort((a, b) => b.compareTo(a));
    return ys;
  }

  YearRecap yearRecap(int year, DateTime now) {
    final start = DateTime(year);
    final end = DateTime(year + 1);
    final r = DateTimeRange(start: start, end: end);
    final me = List<double>.filled(12, 0);
    final mi = List<double>.filled(12, 0);
    final titles = <String, double>{};
    final titleLabel = <String, String>{};
    Transaction? biggest;
    var count = 0;
    for (final t in transactions) {
      if (!inRange(t.date, r)) continue;
      count++;
      final v = amountIDR(t);
      if (t.type == TxType.expense) {
        me[t.date.month - 1] += v;
        final k = t.title.trim().toLowerCase();
        if (k.isNotEmpty) {
          titles[k] = (titles[k] ?? 0) + v;
          titleLabel.putIfAbsent(k, () => t.title.trim());
        }
        if (biggest == null || v > amountIDR(biggest)) biggest = t;
      } else if (t.type == TxType.income) {
        mi[t.date.month - 1] += v;
      }
    }
    final cats = byTopCategory(TxType.expense, r).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final tt = titles.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final endCut = now.isBefore(end) ? now.add(const Duration(seconds: 1)) : end;
    // Hari dihitung sejak transaksi pertama kalau mulai pakai di tengah tahun,
    // supaya rata-rata per hari tidak terlalu kecil.
    var firstDay = start;
    if (transactions.isNotEmpty) {
      final first = dayOnly(transactions
          .map((t) => t.date)
          .reduce((a, b) => a.isBefore(b) ? a : b));
      if (first.isAfter(start) && first.isBefore(end)) firstDay = first;
    }
    final days = math.max(
        1,
        (now.isBefore(end) ? dayOnly(now).add(const Duration(days: 1)) : end)
            .difference(firstDay)
            .inDays);
    return YearRecap(
      year: year,
      income: mi.fold(0.0, (s, v) => s + v),
      expense: me.fold(0.0, (s, v) => s + v),
      monthlyExpense: me,
      monthlyIncome: mi,
      topCategories: cats.take(5).toList(),
      topTitles: [
        for (final e in tt.take(5)) MapEntry(titleLabel[e.key]!, e.value)
      ],
      biggest: biggest,
      txCount: count,
      netWorthStart: netWorthAt(start),
      netWorthEnd: netWorthAt(endCut),
      days: days,
    );
  }
}

class YearRecapPage extends StatefulWidget {
  const YearRecapPage({super.key, required this.store});
  final AppStore store;

  @override
  State<YearRecapPage> createState() => _YearRecapPageState();
}

class _YearRecapPageState extends State<YearRecapPage> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final now = DateTime.now();
    final years = store.recapYears(now);
    final r = store.yearRecap(_year, now);
    final hide = store.settings.hideBalance;
    String m(double v) => hide ? '••••' : money(v);
    final monthNames = [
      for (var i = 1; i <= 12; i++)
        DateFormat('MMMM', 'id_ID').format(DateTime(_year, i))
    ];
    int? maxMonth, minMonth;
    for (var i = 0; i < 12; i++) {
      if (r.monthlyExpense[i] <= 0) continue;
      if (maxMonth == null || r.monthlyExpense[i] > r.monthlyExpense[maxMonth]) {
        maxMonth = i;
      }
      if (minMonth == null || r.monthlyExpense[i] < r.monthlyExpense[minMonth]) {
        minMonth = i;
      }
    }
    final nwDiff = r.netWorthEnd - r.netWorthStart;

    Widget stat(String label, String value, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: C.muted)),
                const SizedBox(height: 2),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 15, color: color)),
              ],
            ),
          ),
        );

    Widget line(String a, String b, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Expanded(
                  child: Text(a,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5))),
              Text(b,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: color ?? C.carbon)),
            ],
          ),
        );

    return Scaffold(
      appBar: pageBar('Rekap $_year'),
      body: ListView(
        padding: pagePad(context, 32),
        children: [
          if (years.length > 1)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final y in years)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('$y'),
                        selected: y == _year,
                        onSelected: (_) => setState(() => _year = y),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          if (r.txCount == 0)
            const AppCard(
                child: EmptyState(
                    icon: Icons.insights_rounded,
                    title: 'Belum ada transaksi di tahun ini'))
          else ...[
            Row(
              children: [
                stat('Pemasukan', m(r.income), C.income),
                const SizedBox(width: 10),
                stat('Pengeluaran', m(r.expense), C.redDark),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                stat('Selisih', m(r.net), r.net >= 0 ? C.income : C.redDark),
                const SizedBox(width: 10),
                stat(
                    'Porsi ditabung',
                    r.savingRate == null
                        ? '-'
                        : '${(r.savingRate! * 100).round()}%',
                    C.blueDark),
              ],
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionTitle('Ringkasan'),
                  const SizedBox(height: 4),
                  line('Jumlah transaksi', '${r.txCount}'),
                  line(r.days < 365 ? 'Rata-rata keluar per hari (${r.days} hari)' : 'Rata-rata keluar per hari', m(r.expense / r.days)),
                  if (maxMonth != null)
                    line('Bulan paling boros',
                        '${monthNames[maxMonth]} · ${m(r.monthlyExpense[maxMonth])}',
                        color: C.redDark),
                  if (minMonth != null && minMonth != maxMonth)
                    line('Bulan paling hemat',
                        '${monthNames[minMonth]} · ${m(r.monthlyExpense[minMonth])}',
                        color: C.income),
                  if (r.biggest != null)
                    line('Pengeluaran terbesar',
                        '${r.biggest!.title} · ${m(store.amountIDR(r.biggest!))}'),
                  const Divider(),
                  line('Kekayaan bersih awal tahun', m(r.netWorthStart)),
                  line(
                      _year == now.year
                          ? 'Kekayaan bersih sekarang'
                          : 'Kekayaan bersih akhir tahun',
                      m(r.netWorthEnd)),
                  line('Perubahan',
                      hide ? '••••' : '${nwDiff >= 0 ? '+' : '−'}${money(nwDiff.abs())}',
                      color: nwDiff >= 0 ? C.income : C.redDark),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionTitle('Pemasukan & pengeluaran per bulan'),
                  const SizedBox(height: 12),
                  TrendChart(buckets: [
                    for (var i = 0; i < 12; i++)
                      TrendBucket(monthNames[i].substring(0, 1),
                          r.monthlyIncome[i], r.monthlyExpense[i]),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (r.topCategories.isNotEmpty)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionTitle('Kategori terbesar'),
                    const SizedBox(height: 4),
                    for (final e in r.topCategories)
                      line(store.categoryById(e.key)?.name ?? 'Tanpa kategori',
                          '${m(e.value)} · ${r.expense > 0 ? (e.value / r.expense * 100).round() : 0}%'),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            if (r.topTitles.isNotEmpty)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionTitle('Pengeluaran terbesar per catatan'),
                    const SizedBox(height: 4),
                    for (final e in r.topTitles) line(e.key, m(e.value)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
