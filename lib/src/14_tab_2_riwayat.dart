part of '../main.dart';

// =============================================================================
// TAB 2: RIWAYAT (daftar, filter, pencarian, kalender)
// =============================================================================

enum HistoryFilter {
  today('Hari Ini'),
  week('Minggu Ini'),
  month('Bulan Ini'),
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
          ...groupedTxWidgets(context, store, results),
      ];
    } else if (_view == HistoryView.list) {
      body = _listBody(context);
    } else {
      body = _calendarBody(context);
    }

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Riwayat',
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w900)),
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
                              tooltip: 'Hapus pencarian',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                  ),
                  if (!searching) ...[
                    const SizedBox(height: 12),
                    Segmented<HistoryView>(
                      values: HistoryView.values,
                      selected: _view,
                      labelOf: (v) =>
                          v == HistoryView.list ? 'Daftar' : 'Kalender',
                      iconOf: (v) => v == HistoryView.list
                          ? Icons.view_list_rounded
                          : Icons.calendar_month_rounded,
                      colorOf: (_) => C.toast,
                      dense: true,
                      onChanged: (v) => setState(() => _view = v),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
            sliver: SliverList(delegate: SliverChildListDelegate(body)),
          ),
        ],
      ),
    );
  }

  List<Widget> _listBody(BuildContext context) {
    final range = _filter.range(DateTime.now());
    final list = range == null
        ? store.transactions
        : store.transactions.where((t) => inRange(t.date, range)).toList();
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
                  color: C.redDark,
                  icon: Icons.north_east_rounded)),
        ],
      ),
      const SizedBox(height: 4),
      if (list.isEmpty)
        EmptyState(
            icon: Icons.receipt_long_rounded,
            title: 'Belum ada transaksi ${_filter.label.toLowerCase()}',
            subtitle: 'Ketuk tombol "Catat" buat mulai.')
      else
        ...groupedTxWidgets(context, store, list),
    ];
  }

  List<Widget> _calendarBody(BuildContext context) {
    final y = _calMonth.year;
    final m = _calMonth.month;
    final mRange = monthRange(_calMonth);
    final inc = <int, double>{};
    final exp = <int, double>{};
    for (final t in store.transactions) {
      if (!inRange(t.date, mRange)) continue;
      if (t.type == TxType.income) {
        inc[t.date.day] = (inc[t.date.day] ?? 0) + store.amountIDR(t);
      } else if (t.type == TxType.expense) {
        exp[t.date.day] = (exp[t.date.day] ?? 0) + store.amountIDR(t);
      }
    }
    final leading = DateTime(y, m, 1).weekday - 1;
    final days = DateTime(y, m + 1, 0).day;
    final cells = ((leading + days) / 7).ceil() * 7;
    final today = dayOnly(DateTime.now());
    final dayTx = store.transactions
        .where((t) => sameDay(t.date, _selectedDay))
        .toList();
    const weekdays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

    Widget cell(int index) {
      final dayNum = index - leading + 1;
      if (dayNum < 1 || dayNum > days) return const SizedBox(height: 58);
      final date = DateTime(y, m, dayNum);
      final selected = sameDay(date, _selectedDay);
      final isToday = sameDay(date, today);
      final i = inc[dayNum] ?? 0;
      final e = exp[dayNum] ?? 0;
      return Semantics(
        button: true,
        selected: selected,
        label: DateFormat('d MMMM', 'id_ID').format(date),
        child: GestureDetector(
          onTap: () => setState(() => _selectedDay = date),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 58,
            margin: const EdgeInsets.all(2),
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            decoration: BoxDecoration(
              color: selected ? C.accent.withValues(alpha: 0.12) : C.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: selected
                      ? C.accentDark
                      : (isToday ? C.accent.withValues(alpha: 0.5) : C.line),
                  width: selected ? 2 : 1),
            ),
            child: Column(
              children: [
                Text('$dayNum',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isToday ? FontWeight.w900 : FontWeight.w700,
                        color: C.carbon)),
                const Spacer(),
                if (i > 0)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('+${compactMoney(i)}',
                        style: TextStyle(
                            fontSize: 9,
                            color: C.income,
                            fontWeight: FontWeight.w800)),
                  ),
                if (e > 0)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('-${compactMoney(e)}',
                        style: TextStyle(
                            fontSize: 9,
                            color: C.redDark,
                            fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return [
      AppCard(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Bulan sebelumnya',
                  onPressed: () =>
                      setState(() => _calMonth = DateTime(y, m - 1)),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                      DateFormat('MMMM yyyy', 'id_ID').format(_calMonth),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 16)),
                ),
                IconButton(
                  tooltip: 'Bulan berikutnya',
                  onPressed: () =>
                      setState(() => _calMonth = DateTime(y, m + 1)),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
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
          ],
        ),
      ),
      const SizedBox(height: 4),
      if (dayTx.isEmpty)
        EmptyState(
            icon: Icons.event_available_rounded,
            title: 'Tidak ada transaksi',
            subtitle: dayLabel(_selectedDay))
      else
        ...groupedTxWidgets(context, store, dayTx),
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
                    style: TextStyle(fontSize: 11, color: C.muted)),
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
