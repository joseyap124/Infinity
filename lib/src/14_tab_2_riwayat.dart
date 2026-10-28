part of '../main.dart';

// =============================================================================
// TAB 2: RIWAYAT (daftar, filter, pencarian, kalender)
// =============================================================================

enum HistoryFilter {
  today('Hari ini'),
  week('Minggu ini'),
  month('Bulan ini'),
  all('Semua');

  const HistoryFilter(this.label);
  final String label;

  DateTimeRange? range(DateTime now) {
    switch (this) {
      case HistoryFilter.today:
        return dayRange(now);
      case HistoryFilter.week:
        return weekRange(now);
      case HistoryFilter.month:
        return currentPeriod(now);
      case HistoryFilter.all:
        return null;
    }
  }
}

enum HistoryView { list, calendar }

/// Dinaikkan saat tombol Cari di notifikasi pintasan ditekan.
final ValueNotifier<int> historySearchRequest = ValueNotifier<int>(0);

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key, required this.store});
  final AppStore store;

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  AppStore get store => widget.store;
  final _searchCtrl = TextEditingController();
  String _query = '';
  HistoryView _view = HistoryView.list;
  HistoryFilter _filter = HistoryFilter.month;
  DateTime _calMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDay = dayOnly(DateTime.now());
  final _searchFocus = FocusNode();

  /// Transaksi yang dipilih (tahan satu transaksi untuk mulai memilih).
  final Set<String> _sel = {};

  /// Transaksi yang sedang tampil, untuk "Pilih semua".
  List<Transaction> _shown = [];

  TxSelection get _selection => TxSelection(_sel, _toggleSel);

  void _toggleSel(Transaction t) {
    setState(() {
      if (!_sel.remove(t.id)) _sel.add(t.id);
    });
  }

  void _clearSel() => setState(_sel.clear);

  Future<void> _bulkCategory() async {
    final types = store.categoryTypesOf(_sel);
    if (types.isEmpty) {
      snack(context, 'Transfer tidak punya kategori.');
      return;
    }
    if (types.length > 1) {
      snack(context,
          'Pilih transaksi yang sama jenisnya: semua pengeluaran atau semua pemasukan.');
      return;
    }
    final id = await showSheet<String>(
        context,
        BulkCategorySheet(
            store: store, type: types.first, count: _sel.length));
    if (id == null || !mounted) return;
    final before = store.transactionsByIds(_sel);
    final r = store.bulkSetCategory({..._sel}, id);
    _clearSel();
    if (!mounted) return;
    bulkUndoSnack(
        context,
        r.skipped > 0
            ? tr('{0} diubah, {1} dilewati (transfer atau beda jenis).', [r.changed, r.skipped])
            : tr('{0} transaksi diubah kategorinya.', [r.changed]),
        () => store.restoreSnapshot(before));
  }

  Future<void> _bulkAccount() async {
    final id = await showSheet<String>(
        context, BulkAccountSheet(store: store, count: _sel.length));
    if (id == null || !mounted) return;
    final before = store.transactionsByIds(_sel);
    final r = store.bulkSetAccount({..._sel}, id);
    _clearSel();
    if (!mounted) return;
    bulkUndoSnack(
        context,
        r.skipped > 0
            ? tr('{0} dipindah, {1} dilewati (transfer atau beda mata uang).', [r.changed, r.skipped])
            : tr('{0} transaksi dipindah akunnya.', [r.changed]),
        () => store.restoreSnapshot(before));
  }

  Future<void> _bulkDelete() async {
    final list = store.transactionsByIds(_sel);
    if (list.isEmpty) return;
    if (!await confirmBulkDelete(context, store, list) || !mounted) return;
    final removed = store.bulkDelete({..._sel});
    _clearSel();
    if (!mounted) return;
    bulkUndoSnack(context, tr('{0} transaksi dihapus.', [removed.length]),
        () => store.restoreTransactions(removed));
  }

  /// Filter pencarian: null = semua jenis.
  TxType? _searchType;

  /// 'all' | 'month' | 'last' | 'year'
  String _searchRange = 'all';

  DateTimeRange? _searchRangeOf(DateTime now) {
    final cur = periodLabelOf(now);
    return switch (_searchRange) {
      'month' => periodRange(cur),
      'last' => periodRange(DateTime(cur.year, cur.month - 1)),
      'year' => yearRange(now),
      _ => null,
    };
  }

  Widget _searchFilters() {
    Widget chip(String label, bool on, VoidCallback tap) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ChoiceChip(
            label: Text(label),
            selected: on,
            visualDensity: VisualDensity.compact,
            onSelected: (_) => setState(tap),
          ),
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('Semua jenis', _searchType == null, () => _searchType = null),
          chip('Keluar', _searchType == TxType.expense,
              () => _searchType = TxType.expense),
          chip('Masuk', _searchType == TxType.income,
              () => _searchType = TxType.income),
          chip('Transfer', _searchType == TxType.transfer,
              () => _searchType = TxType.transfer),
          const SizedBox(width: 8),
          chip('Semua waktu', _searchRange == 'all', () => _searchRange = 'all'),
          chip('Bulan ini', _searchRange == 'month',
              () => _searchRange = 'month'),
          chip('Bulan lalu', _searchRange == 'last',
              () => _searchRange = 'last'),
          chip('Tahun ini', _searchRange == 'year', () => _searchRange = 'year'),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    historySearchRequest.addListener(_focusSearch);
  }

  void _focusSearch() {
    if (!mounted) return;
    setState(() => _view = HistoryView.list);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    historySearchRequest.removeListener(_focusSearch);
    _searchFocus.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searching = _query.trim().isNotEmpty;
    final List<Widget> body;
    if (searching) {
      final results = store.search(_query,
          type: _searchType, range: _searchRangeOf(DateTime.now()));
      var outSum = 0.0, inSum = 0.0;
      for (final t in results) {
        if (t.type == TxType.expense) outSum += store.amountIDR(t);
        if (t.type == TxType.income) inSum += store.amountIDR(t);
      }
      final hide = store.settings.hideBalance;
      body = [
        _searchFilters(),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(
              '${results.length} hasil'
              '${outSum > 0 ? ' · keluar ${hide ? '••••' : money(outSum)}' : ''}'
              '${inSum > 0 ? ' · masuk ${hide ? '••••' : money(inSum)}' : ''}',
              style: TextStyle(
                  color: C.carbon, fontSize: 13, fontWeight: FontWeight.w700)),
        ),
        if (results.isEmpty)
          const EmptyState(
              icon: Icons.search_off_rounded,
              title: 'Tidak ketemu',
              subtitle:
                  'Coba kata lain: judul, catatan, kategori, akun, atau nominal. Bisa juga ">50rb" atau "<20000" untuk menyaring nominal.')
        else
          ...groupedTxWidgets(context, store, results, sel: _selection),
      ];
      _shown = results;
    } else if (_view == HistoryView.list) {
      body = _listBody(context);
    } else {
      body = _calendarBody(context);
    }

    // Buang pilihan untuk transaksi yang sudah tidak ada.
    if (_sel.isNotEmpty) {
      final alive = {for (final t in store.transactions) t.id};
      _sel.removeWhere((id) => !alive.contains(id));
    }
    final selecting = _sel.isNotEmpty;

    final content = SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Riwayat',
                            style: TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w900)),
                      ),
                      if (!searching) _viewToggle(),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    onChanged: (v) => setState(() => _query = v),
                    textInputAction: TextInputAction.search,
                    decoration: fieldDeco('Cari, mis. kopi >20rb',
                            icon: Icons.search_rounded)
                        .copyWith(
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: tr('Hapus pencarian'),
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            sliver: SliverList(delegate: SliverChildListDelegate(body)),
          ),
        ],
      ),
    );

    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _clearSel();
      },
      child: Stack(
        children: [
          content,
          if (selecting)
            Positioned(
              left: 12,
              right: 12,
              top: 8,
              child: SafeArea(
                bottom: false,
                child: SelectionBar(
                  count: _sel.length,
                  onClose: _clearSel,
                  onSelectAll: () => setState(
                      () => _sel.addAll(_shown.map((t) => t.id))),
                  onCategory: _bulkCategory,
                  onAccount: _bulkAccount,
                  onDelete: _bulkDelete,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Dua ikon di sebelah judul: daftar atau kalender.
  Widget _viewToggle() {
    Widget btn(HistoryView v, IconData icon, String tip) {
      final on = _view == v;
      return Semantics(
        button: true,
        selected: on,
        label: tr(tip),
        child: Tooltip(
          message: tr(tip),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _view = v),
            child: Container(
              width: 44,
              height: 36,
              decoration: BoxDecoration(
                color: on ? C.toast : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 20, color: on ? Colors.white : C.muted),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: C.surface, borderRadius: BorderRadius.circular(17)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(HistoryView.list, Icons.view_list_rounded, 'Tampilan daftar'),
          btn(HistoryView.calendar, Icons.calendar_month_rounded,
              'Tampilan kalender'),
        ],
      ),
    );
  }

  List<Widget> _listBody(BuildContext context) {
    final range = _filter.range(DateTime.now());
    final list = range == null
        ? store.transactions
        : store.transactions.where((t) => inRange(t.date, range)).toList();
    _shown = list;
    var income = 0.0;
    var expense = 0.0;
    for (final t in list) {
      if (t.type == TxType.income) income += store.amountIDR(t);
      if (t.type == TxType.expense) expense += store.amountIDR(t);
    }
    return [
      Segmented<HistoryFilter>(
        values: HistoryFilter.values,
        selected: _filter,
        labelOf: (f) => f.label,
        dense: true,
        onChanged: (f) => setState(() => _filter = f),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
              child: _SummaryBox(
                  label: 'Pemasukan',
                  value: income,
                  color: C.accentDark,
                  icon: Icons.south_west_rounded)),
          const SizedBox(width: 10),
          Expanded(
              child: _SummaryBox(
                  label: 'Pengeluaran',
                  value: expense,
                  color: C.carbon,
                  icon: Icons.north_east_rounded)),
        ],
      ),
      const SizedBox(height: 4),
      if (list.isEmpty)
        EmptyState(
            icon: Icons.receipt_long_rounded,
            title: tr('Belum ada transaksi {0}', [tr(_filter.label).toLowerCase()]),
            subtitle: 'Ketuk tombol "Catat" buat mulai.')
      else
        ...groupedTxWidgets(context, store, list, sel: _selection),
    ];
  }

  List<Widget> _calendarBody(BuildContext context) {
    final y = _calMonth.year;
    final m = _calMonth.month;
    final cal = store.calendarMonth(_calMonth);
    final maxExp = cal.maxExpense;
    final hide = store.settings.hideBalance;
    String amt(double v) => hide ? 'Rp ••••' : money(v);
    final leading = DateTime(y, m, 1).weekday - 1;
    final days = DateTime(y, m + 1, 0).day;
    final cells = ((leading + days) / 7).ceil() * 7;
    final today = dayOnly(DateTime.now());
    final dayTx = store.transactions
        .where((t) => sameDay(t.date, _selectedDay))
        .toList();
    _shown = dayTx;
    const weekdays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

    Widget dot(Color c) => Container(
        width: 6,
        height: 6,
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        decoration: BoxDecoration(color: c, shape: BoxShape.circle));

    Widget cell(int index) {
      final dayNum = index - leading + 1;
      if (dayNum < 1 || dayNum > days) return const SizedBox(height: 50);
      final date = DateTime(y, m, dayNum);
      final selected = sameDay(date, _selectedDay);
      final isToday = sameDay(date, today);
      final i = cal.income[dayNum] ?? 0;
      final e = cal.expense[dayNum] ?? 0;
      final due = cal.dueDays.contains(dayNum);
      final peak = cal.peakDay == dayNum;
      final notes = <String>[
        if (e > 0) tr('ada pengeluaran'),
        if (i > 0) tr('ada uang masuk'),
        if (due) tr('jatuh tempo'),
        if (peak) tr('paling boros'),
      ];
      return Semantics(
        button: true,
        selected: selected,
        label: [DateFormat('d MMMM', gDateLoc).format(date), ...notes].join(', '),
        child: GestureDetector(
          onTap: () => setState(() => _selectedDay = date),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 50,
            margin: const EdgeInsets.all(2),
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
            decoration: BoxDecoration(
              color: heatColor(heatLevel(e, maxExp)),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: selected
                      ? C.accentDark
                      : peak
                          ? C.carbon
                          : (isToday ? C.accent.withValues(alpha: 0.6) : C.line),
                  width: selected || peak ? 2 : 1),
            ),
            child: Column(
              children: [
                Text('$dayNum',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: isToday || peak ? FontWeight.w900 : FontWeight.w700,
                        color: C.carbon)),
                // Jumlah pengeluaran hari itu, ringkas (mis. "25 rb").
                Expanded(
                  child: Center(
                    child: (e > 0 && !hide)
                        ? FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(compactMoney(e),
                                maxLines: 1,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: C.carbon)),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                SizedBox(
                  height: 8,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (i > 0) dot(C.income),
                      if (due) dot(C.amberDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget total(String label, double v, Color c) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: C.muted)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(amt(v),
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w900, color: c)),
              ),
            ],
          ),
        );

    Widget legend(Widget mark, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            mark,
            const SizedBox(width: 4),
            Text(text, style: TextStyle(fontSize: 11, color: C.muted)),
          ],
        );

    final selIn = cal.income[_selectedDay.day] ?? 0;
    final selOut = cal.expense[_selectedDay.day] ?? 0;
    final selInMonth = _selectedDay.year == y && _selectedDay.month == m;

    return [
      AppCard(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: tr('Bulan sebelumnya'),
                  onPressed: () =>
                      setState(() => _calMonth = DateTime(y, m - 1)),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                      DateFormat('MMMM yyyy', gDateLoc).format(_calMonth),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 16)),
                ),
                IconButton(
                  tooltip: tr('Bulan berikutnya'),
                  onPressed: () =>
                      setState(() => _calMonth = DateTime(y, m + 1)),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                children: [
                  total('Uang masuk', cal.totalIn, C.income),
                  total('Uang keluar', cal.totalOut, C.carbon),
                ],
              ),
            ),
            Row(
              children: [
                for (final w in weekdays)
                  Expanded(
                    child: Text(w,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: C.muted)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            for (var row = 0; row < cells ~/ 7; row++)
              Row(
                children: [
                  for (var col = 0; col < 7; col++)
                    Expanded(child: cell(row * 7 + col)),
                ],
              ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                legend(
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      for (final l in [1, 3, 4])
                        Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(right: 1),
                            decoration: BoxDecoration(
                                color: heatColor(l),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: C.line, width: 0.5))),
                    ]),
                    'Sedikit ke banyak'),
                legend(dot(C.income), 'Uang masuk'),
                legend(dot(C.amberDark), 'Jatuh tempo'),
                legend(
                    Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: C.carbon, width: 2))),
                    'Paling boros'),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 4),
      if (selInMonth && (selIn > 0 || selOut > 0))
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
          child: Text(
              tr('{0}: masuk {1} · keluar {2}',
                  [dayLabel(_selectedDay), amt(selIn), amt(selOut)]),
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w800, color: C.carbon)),
        ),
      if (dayTx.isEmpty)
        EmptyState(
            icon: Icons.event_available_rounded,
            title: 'Tidak ada transaksi',
            subtitle: dayLabel(_selectedDay))
      else
        ...groupedTxWidgets(context, store, dayTx, sel: _selection),
    ];
  }
}

class _SummaryBox extends StatelessWidget {
  const _SummaryBox(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});

  final String label;
  final double value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: C.surface, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          CatIcon(icon: icon, color: color, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 12, color: C.muted)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(money(value),
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: color)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
