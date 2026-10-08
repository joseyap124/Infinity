part of '../main.dart';

// =============================================================================
// TAB 3: STATISTIK
// =============================================================================

class StatsTab extends StatefulWidget {
  const StatsTab({super.key, required this.store});
  final AppStore store;

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  AppStore get store => widget.store;
  BudgetPeriod _mode = BudgetPeriod.monthly;
  DateTime _anchor = DateTime.now();
  TxType _type = TxType.expense;

  DateTimeRange get _range => _mode.range(_anchor);

  void _shift(int dir) {
    setState(() {
      switch (_mode) {
        case BudgetPeriod.weekly:
          _anchor = DateTime(_anchor.year, _anchor.month, _anchor.day + 7 * dir);
        case BudgetPeriod.monthly:
          _anchor = DateTime(_anchor.year, _anchor.month + dir, 1);
        case BudgetPeriod.yearly:
          _anchor = DateTime(_anchor.year + dir, 1, 1);
      }
    });
  }

  String _rangeLabel() {
    final r = _range;
    switch (_mode) {
      case BudgetPeriod.weekly:
        final last = r.end.subtract(const Duration(days: 1));
        return '${DateFormat('d MMM', 'id_ID').format(r.start)} - ${DateFormat('d MMM yyyy', 'id_ID').format(last)}';
      case BudgetPeriod.monthly:
        return DateFormat('MMMM yyyy', 'id_ID').format(r.start);
      case BudgetPeriod.yearly:
        return '${r.start.year}';
    }
  }

  List<TrendBucket> _buckets() {
    final out = <TrendBucket>[];
    switch (_mode) {
      case BudgetPeriod.weekly:
        final s = _range.start;
        for (var i = 0; i < 7; i++) {
          final d = DateTime(s.year, s.month, s.day + i);
          final r = dayRange(d);
          out.add(TrendBucket(DateFormat('E', 'id_ID').format(d),
              store.sumIDR(TxType.income, r), store.sumIDR(TxType.expense, r)));
        }
      case BudgetPeriod.monthly:
        for (var i = 5; i >= 0; i--) {
          final d = DateTime(_anchor.year, _anchor.month - i, 1);
          final r = monthRange(d);
          out.add(TrendBucket(DateFormat('MMM', 'id_ID').format(d),
              store.sumIDR(TxType.income, r), store.sumIDR(TxType.expense, r)));
        }
      case BudgetPeriod.yearly:
        for (var mo = 1; mo <= 12; mo++) {
          final d = DateTime(_anchor.year, mo, 1);
          final r = monthRange(d);
          out.add(TrendBucket(DateFormat('MMM', 'id_ID').format(d).substring(0, 1),
              store.sumIDR(TxType.income, r), store.sumIDR(TxType.expense, r)));
        }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final r = _range;
    final income = store.sumIDR(TxType.income, r);
    final expense = store.sumIDR(TxType.expense, r);
    final net = income - expense;
    final byCat = store.byTopCategory(_type, r).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = byCat.fold(0.0, (s, e) => s + e.value);
    final now = DateTime.now();
    // Hanya boleh maju kalau periode yang dilihat sudah lewat seluruhnya.
    final canNext = !r.end.isAfter(now);
    final elapsedDays = inRange(now, r)
        ? now.difference(r.start).inDays + 1
        : r.end.difference(r.start).inDays;
    final avgDaily = elapsedDays > 0 ? expense / elapsedDays : 0.0;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const Text('Statistik',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Segmented<BudgetPeriod>(
            values: BudgetPeriod.values,
            selected: _mode,
            labelOf: (p) => p.short,
            dense: true,
            onChanged: (p) => setState(() {
              _mode = p;
              _anchor = DateTime.now();
            }),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                  tooltip: 'Sebelumnya',
                  onPressed: () => _shift(-1),
                  icon: const Icon(Icons.chevron_left_rounded)),
              Expanded(
                child: Text(_rangeLabel(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16)),
              ),
              IconButton(
                  tooltip: 'Berikutnya',
                  onPressed: canNext ? () => _shift(1) : null,
                  icon: const Icon(Icons.chevron_right_rounded)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                  child: _SummaryBox(
                      label: 'Pemasukan',
                      value: income,
                      color: C.income,
                      icon: Icons.south_west_rounded)),
              const SizedBox(width: 10),
              Expanded(
                  child: _SummaryBox(
                      label: 'Pengeluaran',
                      value: expense,
                      color: C.redDark,
                      icon: Icons.north_east_rounded)),
            ],
          ),
          const SizedBox(height: 10),
          AppCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Selisih (net)',
                          style: TextStyle(fontSize: 12, color: C.muted)),
                      Text(net > 0 ? '+${money(net)}' : money(net),
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: net >= 0 ? C.income : C.redDark)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Rata-rata keluar/hari',
                          style: TextStyle(fontSize: 12, color: C.muted)),
                      Text(money(avgDaily),
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_mode == BudgetPeriod.monthly) ...[
            const SizedBox(height: 12),
            MonthAdviceCard(store: store, month: r.start),
          ],
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Segmented<TxType>(
                  values: const [TxType.expense, TxType.income],
                  selected: _type,
                  labelOf: (t) => t.label,
                  colorOf: (t) => t.color,
                  dense: true,
                  onChanged: (t) => setState(() => _type = t),
                ),
                const SizedBox(height: 16),
                if (byCat.isEmpty)
                  EmptyState(
                      icon: Icons.donut_large_rounded,
                      title: 'Belum ada ${_type.label.toLowerCase()} di periode ini')
                else ...[
                  Center(
                    child: SizedBox(
                      width: 180,
                      height: 180,
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey('${_mode.name}-${_type.name}-$total-${r.start}'),
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (context, p, _) => CustomPaint(
                          painter: DonutChartPainter(
                            values: byCat.map((e) => e.value).toList(),
                            colors: byCat
                                .map((e) =>
                                    store.categoryById(e.key)?.colorValue ??
                                    C.muted)
                                .toList(),
                            progress: p,
                          ),
                          child: Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Total',
                                      style: TextStyle(
                                          fontSize: 11, color: C.muted)),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(money(total),
                                        style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final e in byCat) _legendRow(context, e.key, e.value, total, r),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(_mode == BudgetPeriod.monthly
                    ? 'Tren 6 Bulan'
                    : (_mode == BudgetPeriod.weekly
                        ? 'Tren Harian'
                        : 'Tren Bulanan ${_anchor.year}')),
                const SizedBox(height: 16),
                TrendChart(buckets: _buckets()),
              ],
            ),
          ),
          const SizedBox(height: 12),
          NetWorthCard(store: store),
          const SizedBox(height: 12),
          AppCard(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => YearRecapPage(store: store))),
            child: Row(
              children: [
                CatIcon(
                    icon: Icons.auto_graph_rounded,
                    color: C.accentDark,
                    size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rekap tahun ${DateTime.now().year}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15)),
                      Text('Total setahun, bulan paling boros, kategori terbesar',
                          style: TextStyle(fontSize: 12, color: C.muted)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: C.muted),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Saldo per Akun'),
                const SizedBox(height: 8),
                for (final a in store.accounts)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        CatIcon(icon: a.type.icon, color: a.colorValue, size: 34),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(a.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(money(store.balanceOf(a.id), a.currency),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 13)),
                            if (a.currency != 'IDR')
                              Text(
                                  '≈ ${money(store.toIDR(store.balanceOf(a.id), a.currency))}',
                                  style: TextStyle(
                                      fontSize: 11, color: C.muted)),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendRow(BuildContext context, String catId, double value,
      double total, DateTimeRange r) {
    final cat = store.categoryById(catId);
    final pct = total > 0 ? value / total : 0.0;
    final color = cat?.colorValue ?? C.muted;
    final hasChildren = cat != null && store.childrenOf(cat.id).isNotEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: hasChildren
          ? () => showSheet<void>(context,
              _SubCategorySheet(store: store, top: cat, type: _type, range: r))
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          children: [
            CatIcon(
                icon: cat?.iconData ?? Icons.help_outline_rounded,
                color: color,
                size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(cat?.name ?? 'Tanpa kategori',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w700)),
                      ),
                      Text('${(pct * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: darken(color))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  FunProgressBar(value: pct, color: color, height: 7),
                  const SizedBox(height: 2),
                  Text(
                      hasChildren
                          ? '${money(value)} · ketuk untuk rincian'
                          : money(value),
                      style: TextStyle(fontSize: 11, color: C.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubCategorySheet extends StatelessWidget {
  const _SubCategorySheet(
      {required this.store,
      required this.top,
      required this.type,
      required this.range});

  final AppStore store;
  final TxCategory top;
  final TxType type;
  final DateTimeRange range;

  @override
  Widget build(BuildContext context) {
    final data = store.bySubCategory(top.id, type, range).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = data.fold(0.0, (s, e) => s + e.value);
    return SheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CatIcon(icon: top.iconData, color: top.colorValue, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Rincian ${top.name}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final e in data)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                            e.key == top.id
                                ? '${top.name} (umum)'
                                : (store.categoryById(e.key)?.name ?? '-'),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                      Text(money(e.value),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  FunProgressBar(
                      value: total > 0 ? e.value / total : 0,
                      color: store.categoryById(e.key)?.colorValue ?? C.muted,
                      height: 7),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
