part of '../main.dart';

// =============================================================================
// TAB 3: STATISTIK
// =============================================================================

enum _StatTab { kategori, tren, aset, kalender }

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
  bool _legendAll = false;
  _StatTab _tab = _StatTab.kategori;

  DateTimeRange get _range => _mode.range(_anchor);

  /// Periode sebelum yang sedang dilihat, untuk perbandingan.
  DateTimeRange get _prevRange {
    switch (_mode) {
      case BudgetPeriod.weekly:
        return weekRange(
            DateTime(_anchor.year, _anchor.month, _anchor.day - 7));
      case BudgetPeriod.monthly:
        final l = periodLabelOf(_anchor);
        return periodRange(DateTime(l.year, l.month - 1));
      case BudgetPeriod.yearly:
        return yearRange(DateTime(_anchor.year - 1, 1, 1));
    }
  }

  void _shift(int dir) {
    setState(() {
      switch (_mode) {
        case BudgetPeriod.weekly:
          _anchor = DateTime(_anchor.year, _anchor.month, _anchor.day + 7 * dir);
        case BudgetPeriod.monthly:
          final l = periodLabelOf(_anchor);
          _anchor = periodRange(DateTime(l.year, l.month + dir)).start;
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
        return '${DateFormat('d MMM', gDateLoc).format(r.start)} - ${DateFormat('d MMM yyyy', gDateLoc).format(last)}';
      case BudgetPeriod.monthly:
        final l = periodLabelOf(_anchor);
        final span = periodSpanText(l);
        return '${DateFormat('MMMM yyyy', gDateLoc).format(l)}${span.isEmpty ? '' : ' ($span)'}';
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
          out.add(TrendBucket(DateFormat('E', gDateLoc).format(d),
              store.sumIDR(TxType.income, r), store.sumIDR(TxType.expense, r)));
        }
      case BudgetPeriod.monthly:
        final l = periodLabelOf(_anchor);
        for (var i = 5; i >= 0; i--) {
          final d = DateTime(l.year, l.month - i);
          final r = periodRange(d);
          out.add(TrendBucket(DateFormat('MMM', gDateLoc).format(d),
              store.sumIDR(TxType.income, r), store.sumIDR(TxType.expense, r)));
        }
      case BudgetPeriod.yearly:
        for (var mo = 1; mo <= 12; mo++) {
          final d = DateTime(_anchor.year, mo, 1);
          final r = monthRange(d);
          out.add(TrendBucket(DateFormat('MMM', gDateLoc).format(d).substring(0, 1),
              store.sumIDR(TxType.income, r), store.sumIDR(TxType.expense, r)));
        }
    }
    return out;
  }

  /// Pembanding hero: pengeluaran periode ini dengan periode sebelumnya.
  /// Kalau periode masih berjalan, yang dibandingkan hanya jumlah hari yang
  /// sama dari periode sebelumnya, supaya tidak timpang.
  double? _expensePct(double expense) {
    final now = DateTime.now();
    final r = _range;
    final p = _prevRange;
    DateTimeRange pr = p;
    if (inRange(now, r)) {
      final days = now.difference(r.start).inDays + 1;
      var end = DateTime(p.start.year, p.start.month, p.start.day + days);
      if (end.isAfter(p.end)) end = p.end;
      pr = DateTimeRange(start: p.start, end: end);
    }
    final before = store.sumIDR(TxType.expense, pr);
    if (before <= 0) return null;
    return (expense - before) / before * 100;
  }

  Widget _hero(double income, double expense, double net, double avgDaily) {
    final pct = _expensePct(expense);
    final prevName = switch (_mode) {
      BudgetPeriod.weekly => tr('minggu lalu'),
      BudgetPeriod.monthly => tr('bulan lalu'),
      BudgetPeriod.yearly => tr('tahun lalu'),
    };
    Widget stat(String label, String value, Color color, CrossAxisAlignment al) =>
        Expanded(
          child: Column(
            crossAxisAlignment: al,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: C.muted)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: color)),
              ),
            ],
          ),
        );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('Pengeluaran'),
              style: TextStyle(fontSize: 12, color: C.muted)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(money(expense),
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: C.carbon)),
          ),
          if (pct != null) ...[
            const SizedBox(height: 6),
            Text(
                pct.abs() < 0.5
                    ? tr('Sama seperti {0}', [prevName])
                    : (pct < 0
                        ? tr('{0}% lebih hemat dari {1}',
                            [pct.abs().toStringAsFixed(0), prevName])
                        : tr('{0}% lebih boros dari {1}',
                            [pct.toStringAsFixed(0), prevName])),
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: pct.abs() < 0.5
                        ? C.muted
                        : (pct < 0 ? C.income : C.amberDark))),
          ],
          const SizedBox(height: 14),
          Divider(height: 1, color: C.line),
          const SizedBox(height: 12),
          Row(
            children: [
              stat(tr('Pemasukan'), money(income), C.income,
                  CrossAxisAlignment.start),
              stat(tr('Selisih'), net > 0 ? '+${money(net)}' : money(net),
                  net >= 0 ? C.income : C.redDark, CrossAxisAlignment.center),
              stat(tr('Rata-rata/hari'), money(avgDaily), C.carbon,
                  CrossAxisAlignment.end),
            ],
          ),
        ],
      ),
    );
  }

  Widget _moreRow(
      {required Widget leading,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14)),
                  Text(subtitle,
                      style: TextStyle(fontSize: 12, color: C.muted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: C.muted),
          ],
        ),
      ),
    );
  }

  Widget _moreTile(
      {required Widget leading,
      required String label,
      required VoidCallback onTap}) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
        onTap: onTap,
        child: Column(
          children: [
            leading,
            const SizedBox(height: 6),
            SizedBox(
              height: 30,
              child: Center(
                child: Text(label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                        height: 1.15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _exportSheet(BuildContext context, DateTime month) {
    showSheet<void>(
      context,
      SheetFrame(
        child: Builder(
          builder: (sheetCtx) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(tr('Ekspor'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900)),
              ),
              _moreRow(
                leading: CatIcon(
                    icon: Icons.picture_as_pdf_rounded,
                    color: C.redDark,
                    size: 38),
                title: tr('Laporan PDF'),
                subtitle: tr('Simpan atau kirim laporan bulan ini'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  showMonthPdfSheet(context, store, month);
                },
              ),
              _moreRow(
                leading: CatIcon(
                    icon: Icons.ios_share_rounded,
                    color: C.blueDark,
                    size: 38),
                title: tr('Bagikan ringkasan bulan'),
                subtitle: tr('Gambar ringkas untuk dikirim'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  showMonthShareSheet(context, store, month);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _more(BuildContext context) {
    final monthly = _mode == BudgetPeriod.monthly;
    final month = periodLabelOf(_anchor);
    final tiles = <Widget>[];
    if (monthly) {
      final tier = store.monthRecap(month, DateTime.now()).tier;
      tiles.add(_moreTile(
        leading: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: (tier == null ? C.blueDark : _tierColor(tier))
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(tier?.emoji ?? '📋', style: const TextStyle(fontSize: 18)),
        ),
        label: tr('Rekap bulan'),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => MonthStoryPage(store: store, month: month))),
      ));
    }
    tiles.add(_moreTile(
      leading: CatIcon(
          icon: Icons.auto_graph_rounded, color: C.accentDark, size: 34),
      label: tr('Rekap tahun'),
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => YearRecapPage(store: store))),
    ));
    tiles.add(_moreTile(
      leading: CatIcon(icon: Icons.tune_rounded, color: C.income, size: 34),
      label: tr('Simulasi'),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => WhatIfPage(store: store))),
    ));
    if (monthly) {
      tiles.add(_moreTile(
        leading: CatIcon(
            icon: Icons.more_horiz_rounded, color: C.muted, size: 34),
        label: tr('Ekspor'),
        onTap: () => _exportSheet(context, month),
      ));
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          tiles[i],
        ],
      ],
    );
  }

  Widget _trendCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(_mode == BudgetPeriod.monthly
              ? 'Tren 6 Bulan'
              : (_mode == BudgetPeriod.weekly
                  ? 'Tren harian'
                  : 'Tren Bulanan ${_anchor.year}')),
          const SizedBox(height: 16),
          TrendChart(buckets: _buckets()),
        ],
      ),
    );
  }

  Widget _categoryCard(BuildContext context,
      List<MapEntry<String, double>> byCat, double total, DateTimeRange r) {
    return AppCard(
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
                      title: tr('Belum ada {0} di periode ini', [tr(_type.label).toLowerCase()]))
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
                            pie: store.settings.chartShape == 'pie',
                          ),
                          child: store.settings.chartShape == 'pie'
                              ? null
                              : Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Total',
                                      style: TextStyle(
                                          fontSize: 12, color: C.muted)),
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
                  if (store.settings.chartShape == 'pie') ...[
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                          tr('Total {0}', [money(total)]),
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w900)),
                    ),
                  ],
                  const SizedBox(height: 12),
                  for (final e in (_legendAll || byCat.length <= 5
                      ? byCat
                      : byCat.take(4).toList()))
                    _legendRow(context, e.key, e.value, total, r),
                  if (byCat.length > 5)
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => setState(() => _legendAll = !_legendAll),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                  _legendAll
                                      ? 'Ringkas'
                                      : tr('{0} kategori lainnya · {1}%', [
                                          byCat.length - 4,
                                          (byCat.skip(4).fold(0.0, (a, e) => a + e.value) /
                                                  total *
                                                  100)
                                              .toStringAsFixed(1)
                                        ]),
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: C.accentDark)),
                            ),
                            Icon(
                                _legendAll
                                    ? Icons.expand_less_rounded
                                    : Icons.expand_more_rounded,
                                color: C.accentDark),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
          );
  }

  Widget _accountsCard() {
    return AppCard(
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
                        CatIcon(
                            icon: a.type.icon,
                            art: a.type.art,
                            color: a.colorValue,
                            size: 34),
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
                                      fontSize: 12, color: C.muted)),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
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
    final tab = (_tab == _StatTab.kalender && _mode == BudgetPeriod.yearly)
        ? _StatTab.kategori
        : _tab;

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
                  tooltip: tr('Sebelumnya'),
                  onPressed: () => _shift(-1),
                  icon: const Icon(Icons.chevron_left_rounded)),
              Expanded(
                child: Text(_rangeLabel(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16)),
              ),
              IconButton(
                  tooltip: tr('Berikutnya'),
                  onPressed: canNext ? () => _shift(1) : null,
                  icon: const Icon(Icons.chevron_right_rounded)),
            ],
          ),
          const SizedBox(height: 4),
          _hero(income, expense, net, avgDaily),
          const SizedBox(height: 14),
          Segmented<_StatTab>(
            values: [
              for (final t in _StatTab.values)
                if (t != _StatTab.kalender || _mode != BudgetPeriod.yearly) t
            ],
            selected: tab,
            labelOf: (t) => switch (t) {
              _StatTab.kategori => tr('Kategori'),
              _StatTab.tren => tr('Tren'),
              _StatTab.aset => tr('Aset'),
              _StatTab.kalender => tr('Kalender'),
            },
            dense: true,
            onChanged: (t) => setState(() => _tab = t),
          ),
          const SizedBox(height: 12),
          if (tab == _StatTab.kategori) ...[
            _categoryCard(context, byCat, total, r),
            const SizedBox(height: 12),
            SpendKindCard(store: store, range: r, prev: _prevRange),
          ] else if (tab == _StatTab.kalender) ...[
            SpendCalendar(store: store, range: r),
          ] else if (tab == _StatTab.tren) ...[
            _trendCard(),
            // Perbandingan dengan bulan lalu, hanya untuk bulan berjalan.
            if (_mode == BudgetPeriod.monthly &&
                periodLabelOf(_anchor) == periodLabelOf(DateTime.now())) ...[
              const SizedBox(height: 12),
              MonthCompareCard(store: store),
            ],
          ] else ...[
            NetWorthCard(store: store),
            const SizedBox(height: 12),
            _accountsCard(),
          ],
          const SizedBox(height: 14),
          _more(context),
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
                art: cat?.art,
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(money(value),
                            style: TextStyle(fontSize: 12, color: C.muted)),
                      ),
                      // Panah menandakan ada rincian; tidak perlu diulang
                      // dengan tulisan di tiap baris.
                      if (hasChildren)
                        Icon(Icons.chevron_right_rounded,
                            size: 18, color: C.muted),
                    ],
                  ),
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
              CatIcon(icon: top.iconData, art: top.art, color: top.colorValue, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Text(tr('Rincian {0}', [top.name]),
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
                                ? tr('{0} (umum)', [top.name])
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
