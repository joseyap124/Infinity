part of '../main.dart';

// =============================================================================
// KALENDER PENGELUARAN (tab di Statistik) dan SIMULASI "KALAU..."
// Semuanya dihitung dari data di HP, tanpa internet.
// =============================================================================

/// Ringkasan pengeluaran satu hari.
class DayStat {
  double total = 0;
  int count = 0;
  final Map<String, double> byCat = {};
}

/// Pengeluaran per hari di rentang [r] (transfer tidak dihitung).
Map<DateTime, DayStat> dayStatsOf(AppStore store, DateTimeRange r) {
  final out = <DateTime, DayStat>{};
  for (final t in store.transactions) {
    if (t.type != TxType.expense || !inRange(t.date, r)) continue;
    final d = out.putIfAbsent(dayOnly(t.date), DayStat.new);
    d.count++;
    for (final (cid, v) in store.categoryParts(t)) {
      d.total += v;
      final key = cid == null ? '_none' : store.topCategoryId(cid);
      d.byCat[key] = (d.byCat[key] ?? 0) + v;
    }
  }
  return out;
}

/// Jumlah hari di sebuah rentang (dibulatkan supaya aman dari pergeseran jam).
int daysInRange(DateTimeRange r) =>
    (r.end.difference(r.start).inHours / 24).round();

/// Patokan pengeluaran per hari untuk mewarnai kalender. Dari anggaran kalau
/// ada, kalau tidak dari rata-rata maksimal 90 hari terakhir. 0 = belum ada
/// patokan (data kurang dari seminggu).
({double value, bool fromBudget}) calendarRef(AppStore store, DateTime now) {
  final s = store.settings;
  if (s.globalBudget > 0) {
    final r = s.budgetPeriod.range(now);
    final n = daysInRange(r);
    if (n > 0) return (value: s.globalBudget / n, fromBudget: true);
  }
  final end = dayOnly(now);
  DateTime? first;
  for (final t in store.transactions) {
    if (t.type != TxType.expense) continue;
    final d = dayOnly(t.date);
    if (first == null || d.isBefore(first)) first = d;
  }
  if (first == null) return (value: 0.0, fromBudget: false);
  final span = math.min(90, end.difference(first).inDays);
  if (span < 7) return (value: 0.0, fromBudget: false);
  final start = DateTime(end.year, end.month, end.day - span);
  final spent =
      store.sumIDR(TxType.expense, DateTimeRange(start: start, end: end));
  return (value: spent / span, fromBudget: false);
}

class SpendCalendar extends StatefulWidget {
  const SpendCalendar({super.key, required this.store, required this.range});
  final AppStore store;
  final DateTimeRange range;

  @override
  State<SpendCalendar> createState() => _SpendCalendarState();
}

class _SpendCalendarState extends State<SpendCalendar> {
  DateTime? _sel;

  int _level(double v, double ref, double maxV) {
    if (ref > 0) {
      final x = v / ref;
      return x <= 0.5 ? 0 : (x <= 1 ? 1 : (x <= 2 ? 2 : 3));
    }
    if (maxV <= 0) return 0;
    final x = v / maxV;
    return x <= 0.25 ? 0 : (x <= 0.5 ? 1 : (x <= 0.75 ? 2 : 3));
  }

  Color _levelColor(int lv) {
    switch (lv) {
      case 0:
        return C.income.withValues(alpha: 0.28);
      case 1:
        return C.amberDark.withValues(alpha: 0.35);
      case 2:
        return const Color(0xFFFF8A65).withValues(alpha: 0.6);
      default:
        return C.redDark;
    }
  }

  Widget _cell(DateTime d, DayStat? st, DateTime today, double ref,
      double maxV, bool selected) {
    final future = d.isAfter(today);
    Color? bg;
    var fg = C.carbon;
    if (future) {
      fg = C.muted.withValues(alpha: 0.5);
    } else {
      final lv = _level(st?.total ?? 0, ref, maxV);
      bg = _levelColor(lv);
      if (lv == 3) fg = Colors.white;
    }
    return Semantics(
      button: !future,
      label: future
          ? tr('Tanggal {0}, belum terjadi', [d.day])
          : tr('Tanggal {0}, {1}', [d.day, money(st?.total ?? 0)]),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: future ? null : () => setState(() => _sel = d),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: selected ? C.carbon : Colors.transparent, width: 2),
          ),
          child: Text('${d.day}',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800, color: fg)),
        ),
      ),
    );
  }

  Widget _legendBox(int lv) => Container(
        width: 16,
        height: 16,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
            color: _levelColor(lv), borderRadius: BorderRadius.circular(5)),
      );

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final r = widget.range;
    final now = DateTime.now();
    final today = dayOnly(now);
    final n = daysInRange(r);
    final days = <DateTime>[
      for (var i = 0; i < n; i++)
        DateTime(r.start.year, r.start.month, r.start.day + i)
    ];
    if (days.isEmpty) return const SizedBox.shrink();
    final stats = dayStatsOf(store, r);
    final ref = calendarRef(store, now);
    final past = days.where((d) => !d.isAfter(today)).toList();
    var maxV = 0.0;
    for (final d in past) {
      maxV = math.max(maxV, stats[d]?.total ?? 0);
    }
    DateTime sel = _sel ?? (past.isEmpty ? days.first : past.last);
    if (!days.contains(sel) || sel.isAfter(today)) {
      sel = past.isEmpty ? days.first : past.last;
    }
    final lead = r.start.weekday - 1;
    final cells = <Widget>[
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (final d in days)
        _cell(d, stats[d], today, ref.value, maxV, d == sel),
    ];
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox.shrink());
    }

    final st = stats[sel];
    final selTotal = st?.total ?? 0;
    String? topCat;
    var topAmt = 0.0;
    st?.byCat.forEach((k, v) {
      if (v > topAmt) {
        topAmt = v;
        topCat = k == '_none'
            ? tr('Tanpa kategori')
            : (store.categoryById(k)?.name ?? tr('Tanpa kategori'));
      }
    });
    final diff = selTotal - ref.value;

    var under = 0;
    DateTime? worstDay;
    var worst = 0.0;
    for (final d in past) {
      final v = stats[d]?.total ?? 0;
      if (ref.value > 0 && v <= ref.value) under++;
      if (v > worst) {
        worst = v;
        worstDay = d;
      }
    }

    Widget stat(String label, String value, Color color) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: C.muted)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: color)),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            children: [
              Row(
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Center(
                        child: Text(
                            DateFormat('E', gDateLoc)
                                .format(DateTime(2024, 1, 1 + i)),
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: C.muted)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              for (var i = 0; i < cells.length; i += 7)
                Row(
                  children: [
                    for (var j = i; j < i + 7; j++)
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: cells[j]),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(tr('Hemat'),
                      style: TextStyle(fontSize: 11, color: C.muted)),
                  const SizedBox(width: 4),
                  for (var lv = 0; lv < 4; lv++) _legendBox(lv),
                  const SizedBox(width: 4),
                  Text(tr('Boros'),
                      style: TextStyle(fontSize: 11, color: C.muted)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(DateFormat('EEEE, d MMM', gDateLoc).format(sel),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
                  Text(money(selTotal),
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 18)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                  topCat == null
                      ? tr('Tidak ada pengeluaran')
                      : tr('{0} transaksi · terbesar {1} {2}',
                          [st?.count ?? 0, topCat!, money(topAmt)]),
                  style: TextStyle(fontSize: 12, color: C.muted)),
              if (ref.value > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: (diff <= 0 ? C.income : C.redDark)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                      diff <= 0
                          ? tr('Hemat {0} dari patokan', [money(-diff)])
                          : tr('Lewat {0} dari patokan', [money(diff)]),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: diff <= 0 ? C.income : C.redDark)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              stat(
                  tr('Di bawah patokan'),
                  ref.value > 0
                      ? tr('{0} dari {1} hari', [under, past.length])
                      : '-',
                  C.income),
              stat(
                  tr('Paling boros'),
                  worstDay == null
                      ? '-'
                      : DateFormat('E d MMM', gDateLoc).format(worstDay),
                  C.redDark),
              stat(
                  ref.fromBudget
                      ? tr('Jatah harian')
                      : tr('Rata-rata harian'),
                  ref.value > 0 ? money(ref.value) : '-',
                  C.carbon),
            ],
          ),
        ),
        if (ref.value <= 0) ...[
          const SizedBox(height: 8),
          Text(
              tr('Warna dibandingkan dengan hari paling boros bulan ini, karena belum ada anggaran atau data cukup.'),
              style: TextStyle(fontSize: 11, color: C.muted)),
        ],
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// SIMULASI "KALAU..."
// -----------------------------------------------------------------------------

class WhatIfPage extends StatefulWidget {
  const WhatIfPage({super.key, required this.store});
  final AppStore store;

  @override
  State<WhatIfPage> createState() => _WhatIfPageState();
}

class _WhatIfPageState extends State<WhatIfPage> {
  AppStore get store => widget.store;
  int _tab = 0; // 0 hemat harian, 1 tabung, 2 cicilan
  final List<double> _v = [20000, 300000, 300000];
  String? _goalId;
  String? _instId;
  late double _base;

  static const _steps = [5000.0, 100000.0, 100000.0];
  static const _maxes = [100000.0, 5000000.0, 5000000.0];

  @override
  void initState() {
    super.initState();
    _base = _estimateSave();
  }

  /// Sisa uang rata-rata per bulan dari 3 periode terakhir yang sudah lewat.
  double _estimateSave() {
    final now = DateTime.now();
    final l = periodLabelOf(now);
    var sum = 0.0;
    var n = 0;
    for (var i = 1; i <= 3; i++) {
      final r = periodRange(DateTime(l.year, l.month - i));
      final inc = store.sumIDR(TxType.income, r);
      final ex = store.sumIDR(TxType.expense, r);
      if (inc <= 0 && ex <= 0) continue;
      sum += inc - ex;
      n++;
    }
    if (n == 0) return 0;
    return math.max(0.0, (sum / n / 10000).roundToDouble() * 10000);
  }

  String _monthText(int n) {
    if (n > 600) return tr('lebih dari 50 tahun');
    final now = DateTime.now();
    return DateFormat('MMM yyyy', gDateLoc)
        .format(DateTime(now.year, now.month + n));
  }

  Widget _round(IconData icon, VoidCallback? onTap, {bool filled = false}) =>
      InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? C.income : null,
            border: filled ? null : Border.all(color: C.line),
          ),
          child: Icon(icon,
              color: onTap == null
                  ? C.muted
                  : (filled ? Colors.white : C.carbon)),
        ),
      );

  Widget _bar(double frac, Color color) => ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 12,
          color: C.line,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: frac.clamp(0.04, 1.0),
            child: Container(color: color),
          ),
        ),
      );

  Widget _empty(String text) => AppCard(
        child: Text(text, style: TextStyle(fontSize: 13, color: C.muted)),
      );

  @override
  Widget build(BuildContext context) {
    final goals = store.goalsOn
        .where((g) => g.target - store.goalProgress(g) > 0)
        .toList();
    final insts = store.activeInstallments;
    Goal? goal;
    for (final g in goals) {
      if (g.id == _goalId) goal = g;
    }
    goal ??= goals.isEmpty ? null : goals.first;
    Installment? inst;
    for (final i in insts) {
      if (i.id == _instId) inst = i;
    }
    inst ??= insts.isEmpty ? null : insts.first;

    final tab = _tab;
    final v = _v[tab];
    final extra = tab == 0 ? v * 30 : v;
    final isInst = tab == 2;

    double remaining = 0;
    double perMonthBase = 0;
    int? baseMonths;
    int? newMonths;
    String title = '';
    if (isInst && inst != null) {
      remaining = inst.remaining;
      perMonthBase = inst.perMonth;
      baseMonths = inst.left;
      newMonths = math.max(1, (remaining / (perMonthBase + extra)).ceil());
      title = tr('{0}: sisa {1}, bayar {2} per bulan',
          [inst.name, money(remaining), money(perMonthBase)]);
    } else if (!isInst && goal != null) {
      remaining = goal.target - store.goalProgress(goal);
      perMonthBase = _base;
      if (perMonthBase > 0) baseMonths = (remaining / perMonthBase).ceil();
      if (perMonthBase + extra > 0) {
        newMonths = (remaining / (perMonthBase + extra)).ceil();
      }
      title = tr('Target {0}: kurang {1} dari {2}',
          [goal.name, money(remaining), money(goal.target)]);
    }
    final verb = isInst ? tr('Lunas') : tr('Tercapai');
    final gain = (baseMonths != null && newMonths != null)
        ? baseMonths - newMonths
        : (baseMonths == null && newMonths != null ? -1 : 0);

    final question = switch (tab) {
      0 => tr('Kalau jajan dan makan di luar turun...'),
      1 => tr('Kalau tiap bulan kamu sisihkan tambahan...'),
      _ => tr('Kalau cicilan kamu bayar lebih...'),
    };
    final unit = switch (tab) {
      0 => tr('turun per hari'),
      1 => tr('tambahan menabung per bulan'),
      _ => tr('tambahan bayar cicilan per bulan'),
    };
    final presets = switch (tab) {
      0 => const [10000.0, 20000.0, 30000.0],
      1 => const [200000.0, 300000.0, 500000.0],
      _ => const [200000.0, 300000.0, 600000.0],
    };
    final noData = isInst ? inst == null : goal == null;

    return Scaffold(
      appBar: pageBar('Kalau...'),
      body: ListView(
        padding: pagePad(context, 32),
        children: [
          Text(
              tr('Coba ubah kebiasaan, lihat efeknya ke target dan cicilan. Hanya perkiraan dari datamu.'),
              style: TextStyle(fontSize: 12.5, color: C.muted)),
          const SizedBox(height: 12),
          Segmented<int>(
            values: const [0, 1, 2],
            selected: tab,
            labelOf: (i) => switch (i) {
              0 => tr('Hemat harian'),
              1 => tr('Tabung'),
              _ => tr('Cicilan'),
            },
            dense: true,
            onChanged: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 12),
          if (noData)
            _empty(isInst
                ? tr('Belum ada cicilan aktif. Tambahkan dulu di Rencana, Cicilan.')
                : tr('Belum ada target yang belum tercapai. Buat dulu di Rencana, Target.'))
          else ...[
            if ((isInst ? insts.length : goals.length) > 1) ...[
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (isInst)
                    for (final i in insts)
                      ChoiceChip(
                        label: Text(i.name),
                        selected: i.id == inst!.id,
                        onSelected: (_) => setState(() => _instId = i.id),
                      )
                  else
                    for (final g in goals)
                      ChoiceChip(
                        label: Text(g.name),
                        selected: g.id == goal!.id,
                        onSelected: (_) => setState(() => _goalId = g.id),
                      ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(question,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: C.muted)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _round(
                          Icons.remove_rounded,
                          v <= 0
                              ? null
                              : () => setState(() => _v[tab] =
                                  math.max(0.0, v - _steps[tab]))),
                      Column(
                        children: [
                          Text(money(v),
                              style: const TextStyle(
                                  fontSize: 26, fontWeight: FontWeight.w900)),
                          Text(unit,
                              style:
                                  TextStyle(fontSize: 12, color: C.muted)),
                        ],
                      ),
                      _round(
                          Icons.add_rounded,
                          v >= _maxes[tab]
                              ? null
                              : () => setState(() => _v[tab] =
                                  math.min(_maxes[tab], v + _steps[tab])),
                          filled: true),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      for (final p in presets)
                        ChoiceChip(
                          label: Text(compactMoney(p)),
                          selected: v == p,
                          onSelected: (_) => setState(() => _v[tab] = p),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: C.muted)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(tr('Sekarang'),
                          style: TextStyle(fontSize: 12, color: C.muted)),
                      Text(
                          baseMonths == null
                              ? tr('Belum ada sisa uang bulanan')
                              : '$verb ${_monthText(baseMonths)} (${tr('{0} bln', [baseMonths])})',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _bar(1, C.muted.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(tr('Dengan perubahan'),
                          style: TextStyle(fontSize: 12, color: C.muted)),
                      Text(
                          newMonths == null
                              ? '-'
                              : '$verb ${_monthText(newMonths)} (${tr('{0} bln', [newMonths])})',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: C.income)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _bar(
                      (baseMonths != null && newMonths != null && baseMonths > 0)
                          ? newMonths / baseMonths
                          : 1,
                      C.income),
                  const SizedBox(height: 12),
                  if (gain > 0)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: C.income.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14)),
                      child: Text(
                          isInst
                              ? tr('{0} bulan lebih cepat. Cicilan 0% tidak menghemat bunga, tapi kamu bebas lebih awal.',
                                  [gain])
                              : tr('{0} bulan lebih cepat', [gain]),
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: C.income)),
                    )
                  else if (gain < 0)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: C.income.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14)),
                      child: Text(
                          tr('Dengan tambahan ini target mulai bisa tercapai.'),
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: C.income)),
                    )
                  else
                    Text(tr('Belum ada perubahan. Coba geser angkanya.'),
                        style: TextStyle(fontSize: 13, color: C.muted)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('Tambahan per bulan'),
                            style: TextStyle(fontSize: 11, color: C.muted)),
                        Text('+${money(extra)}',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('Tambahan setahun'),
                            style: TextStyle(fontSize: 11, color: C.muted)),
                        Text('+${money(extra * 12)}',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!isInst) ...[
              const SizedBox(height: 12),
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('Sisa uang per bulan sekarang'),
                              style:
                                  TextStyle(fontSize: 11, color: C.muted)),
                          Text(money(_base),
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w800)),
                          Text(tr('Rata-rata 3 bulan terakhir. Ubah kalau tidak pas.'),
                              style:
                                  TextStyle(fontSize: 11, color: C.muted)),
                        ],
                      ),
                    ),
                    IconButton(
                        tooltip: tr('Kurangi'),
                        onPressed: _base <= 0
                            ? null
                            : () => setState(
                                () => _base = math.max(0.0, _base - 100000)),
                        icon: const Icon(Icons.remove_circle_outline_rounded)),
                    IconButton(
                        tooltip: tr('Tambah'),
                        onPressed: () => setState(() => _base += 100000),
                        icon: const Icon(Icons.add_circle_outline_rounded)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
                tr('Dihitung dari target dan cicilan yang sudah kamu catat. Bukan janji: kalau pengeluaran naik lagi, hasilnya bergeser.'),
                style: TextStyle(fontSize: 11, color: C.muted, height: 1.5)),
          ],
        ],
      ),
    );
  }
}
