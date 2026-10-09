part of '../main.dart';

// =============================================================================
// v3.5: TAB RENCANA, ATUR BERANDA, PENGATURAN (satu pintu)
// =============================================================================

/// Kartu yang bisa dipilih untuk Beranda: id -> (judul, keterangan).
const Map<String, (String, String)> kHomeCards = {
  'quick': ('Catat cepat', 'Tombol template sekali ketuk'),
  'upcoming': ('Tagihan & langganan', '3 yang paling dekat'),
  'budget': ('Anggaran', 'Sisa anggaran bulan ini'),
  'credit': ('Kartu kredit', 'Tagihan dan sisa limit'),
  'goals': ('Target tabungan', 'Progres target pertama'),
  'compare': ('Dibanding bulan lalu', 'Naik/turun per kategori'),
  'recent': ('Transaksi terakhir', '5 transaksi terbaru'),
};

/// Beranda bawaan: ringkas. Sisanya ada di tab Rencana dan Statistik.
const List<String> kDefaultHomeCards = ['quick', 'recent'];

void _pushPage(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

// ----------------------------------------------------------------- Atur Beranda

class HomeCardsSheet extends StatefulWidget {
  const HomeCardsSheet({super.key, required this.store});
  final AppStore store;

  @override
  State<HomeCardsSheet> createState() => _HomeCardsSheetState();
}

class _HomeCardsSheetState extends State<HomeCardsSheet> {
  late List<String> _order;
  late Set<String> _on;

  @override
  void initState() {
    super.initState();
    final cur = widget.store.settings.homeCards;
    _on = {...cur};
    _order = [
      ...cur,
      for (final k in kHomeCards.keys)
        if (!cur.contains(k)) k,
    ];
  }

  void _save() {
    widget.store.updateSettings(
        (s) => s.homeCards = [for (final k in _order) if (_on.contains(k)) k]);
  }

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Atur Beranda',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              ),
              IconButton(
                tooltip: 'Tutup',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          Text(
              'Centang kartu yang mau tampil, tahan dan geser untuk mengubah urutan. Aman dibelanjakan, saldo, dan hal yang perlu dicek selalu tampil paling atas.',
              style: TextStyle(fontSize: 12.5, color: C.muted)),
          const SizedBox(height: 8),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: (a, b) {
              setState(() {
                final k = _order.removeAt(a);
                _order.insert(b, k);
              });
              _save();
            },
            children: [
              for (var i = 0; i < _order.length; i++)
                ListTile(
                  key: ValueKey(_order[i]),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: ReorderableDragStartListener(
                    index: i,
                    child: Icon(Icons.drag_indicator_rounded, color: C.muted),
                  ),
                  title: Text(kHomeCards[_order[i]]!.$1,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(kHomeCards[_order[i]]!.$2),
                  trailing: Checkbox(
                    value: _on.contains(_order[i]),
                    activeColor: C.accentDark,
                    onChanged: (v) {
                      setState(() => v == true
                          ? _on.add(_order[i])
                          : _on.remove(_order[i]));
                      _save();
                    },
                  ),
                  onTap: () {
                    setState(() => _on.contains(_order[i])
                        ? _on.remove(_order[i])
                        : _on.add(_order[i]));
                    _save();
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              setState(() {
                _order = [
                  ...kDefaultHomeCards,
                  for (final k in kHomeCards.keys)
                    if (!kDefaultHomeCards.contains(k)) k,
                ];
                _on = {...kDefaultHomeCards};
              });
              _save();
            },
            child: const Text('Kembalikan ke bawaan'),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- Tab Rencana

class PlanTab extends StatelessWidget {
  const PlanTab({super.key, required this.store});
  final AppStore store;

  Widget _section(BuildContext context, String title,
          {String? action, VoidCallback? onAction}) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 0, 6),
        child: Row(
          children: [
            Expanded(
              child: Text(title,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: C.carbon)),
            ),
            if (action != null)
              TextButton(onPressed: onAction, child: Text(action)),
          ],
        ),
      );

  Widget _empty(BuildContext context, IconData icon, String text,
          String button, VoidCallback onTap) =>
      AppCard(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: C.muted),
            const SizedBox(width: 12),
            Expanded(
                child: Text(text,
                    style: TextStyle(fontSize: 13, color: C.muted))),
            Text(button,
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: C.accentDark)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final label = periodLabelOf(now);
    final r = currentPeriod(now);
    final daysLeft = r.end.difference(dayOnly(now)).inDays;
    final span = periodSpanText(label);
    // Kartu yang sudah ada di Beranda dipakai ulang supaya tampilannya sama.
    final home = DashboardTab(store: store, onSeeAll: () {});
    final credits =
        store.accounts.where((a) => a.type == AccountType.credit).toList();
    final upcoming = store.recurring.where((x) => x.active).toList()
      ..sort((a, b) => a.nextDate.compareTo(b.nextDate));
    final soon = upcoming
        .where((x) => x.nextDate.isBefore(now.add(const Duration(days: 31))))
        .toList();
    final owedToMe = store.debtTotal(theyOwe: true);
    final iOwe = store.debtTotal(theyOwe: false);
    final hide = store.settings.hideBalance;
    String m(double v) => hide ? '••••' : money(v);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        children: [
          const Text('Rencana',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(
              '${DateFormat('MMMM yyyy', 'id_ID').format(label)}'
              '${span.isEmpty ? '' : ' ($span)'} · $daysLeft hari lagi',
              style: TextStyle(fontSize: 12.5, color: C.muted)),
          const SizedBox(height: 12),
          InsightStrip(
              store: store,
              onOpenCaptures: () {},
              kinds: kPlanInsights,
              title: 'Saran'),
          _section(context, 'Anggaran',
              action: 'Atur',
              onAction: () => _pushPage(context, BudgetPage(store: store))),
          home._budgetCard(context),
          _section(context, 'Tagihan & langganan',
              action: 'Semua',
              onAction: () => _pushPage(context, RecurringPage(store: store))),
          if (soon.isEmpty)
            _empty(context, Icons.event_repeat_rounded,
                'Belum ada tagihan atau langganan rutin 30 hari ke depan.',
                'Tambah', () => _pushPage(context, RecurringPage(store: store)))
          else
            home._upcomingCard(context, soon.take(6).toList()),
          if (credits.isNotEmpty) ...[
            _section(context, 'Kartu kredit'),
            home._creditCard(context, credits),
          ],
          _section(context, 'Target tabungan',
              action: store.goals.isEmpty ? null : 'Semua',
              onAction: () => _pushPage(context, GoalsPage(store: store))),
          if (store.goals.isEmpty)
            _empty(context, Icons.savings_rounded,
                'Belum ada target. Misalnya dana darurat atau liburan.',
                'Buat', () => _pushPage(context, GoalsPage(store: store)))
          else
            for (final g in store.goals.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GoalCard(store: store, goal: g, compact: true),
              ),
          _section(context, 'Utang & piutang',
              action: 'Buka',
              onAction: () => _pushPage(context, DebtsPage(store: store))),
          if (owedToMe <= 0 && iOwe <= 0)
            _empty(context, Icons.handshake_rounded,
                'Tidak ada utang atau piutang yang belum lunas.', 'Catat',
                () => _pushPage(context, DebtsPage(store: store)))
          else
            AppCard(
              onTap: () => _pushPage(context, DebtsPage(store: store)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Orang berutang ke kamu',
                            style: TextStyle(fontSize: 12, color: C.muted)),
                        Text(m(owedToMe),
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: C.income)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kamu berutang',
                            style: TextStyle(fontSize: 12, color: C.muted)),
                        Text(m(iOwe),
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: iOwe > 0 ? C.redDark : C.carbon)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: C.muted),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => showSheet<void>(
                      context, PatunganSheet(store: store)),
                  icon: const Icon(Icons.groups_rounded),
                  label: const Text('Patungan'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pushPage(context, EventsPage(store: store)),
                  icon: const Icon(Icons.celebration_rounded),
                  label: const Text('Acara'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- Pengaturan

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.store});
  final AppStore store;

  Widget _row(BuildContext context, IconData icon, Color color, String title,
          String subtitle, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
          child: Row(
            children: [
              CatIcon(icon: icon, color: color, size: 38),
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final s = store.settings;
        final theme = switch (s.themeMode) {
          'light' => 'Terang',
          'dark' => 'Gelap',
          _ => 'Ikut HP',
        };
        final size = s.textScale >= 1.3
            ? 'Sangat besar'
            : s.textScale >= 1.15
                ? 'Besar'
                : 'Normal';
        final at = s.ratesUpdatedAt;
        final mode = switch (s.captureMode) {
          'off' => 'Mati',
          'ask' => 'Tanya dulu',
          _ => 'Otomatis',
        };
        return Scaffold(
          appBar: pageBar('Pengaturan'),
          body: ListView(
            padding: pagePad(context, 32),
            children: [
              const SmallLabel('Tampilan'),
              const SizedBox(height: 6),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(children: [
                  _row(context, Icons.palette_rounded, C.accentDark, 'Tampilan',
                      '$theme · huruf $size · ${C.accents[s.accentIndex].$1}',
                      () => _pushPage(context, AppearancePage(store: store))),
                  _row(
                      context,
                      Icons.dashboard_customize_rounded,
                      C.blueDark,
                      'Atur Beranda',
                      '${s.homeCards.length} kartu tampil',
                      () => showSheet<void>(
                          context, HomeCardsSheet(store: store))),
                ]),
              ),
              const SizedBox(height: 14),
              const SmallLabel('Keuangan'),
              const SizedBox(height: 6),
              PeriodStartTile(store: store),
              const SizedBox(height: 8),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(children: [
                  _row(
                      context,
                      Icons.currency_exchange_rounded,
                      C.income,
                      'Mata uang & kurs',
                      at == null
                          ? 'Kurs bawaan'
                          : 'Diperbarui ${DateFormat('d MMM yyyy', 'id_ID').format(at)}',
                      () => _pushPage(context, CurrencyPage(store: store))),
                ]),
              ),
              const SizedBox(height: 14),
              const SmallLabel('Otomatis & pengingat'),
              const SizedBox(height: 6),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(children: [
                  _row(context, Icons.notifications_active_rounded, C.blueDark,
                      'Catat otomatis', 'Dari notifikasi bank: $mode',
                      () => _pushPage(context, AutoCapturePage(store: store))),
                  _row(context, Icons.alarm_rounded, C.amberDark, 'Notifikasi',
                      'Pengingat harian, tagihan, ringkasan',
                      () => _pushPage(context, NotificationsPage(store: store))),
                ]),
              ),
              const SizedBox(height: 14),
              const SmallLabel('Keamanan'),
              const SizedBox(height: 6),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: _row(
                    context,
                    Icons.lock_rounded,
                    C.redDark,
                    'Keamanan',
                    s.pin == null ? 'PIN belum diatur' : 'PIN aktif',
                    () => _pushPage(context, SecurityPage(store: store))),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Tema, ukuran huruf, dan warna utama.
class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final s = store.settings;
        return Scaffold(
          appBar: pageBar('Tampilan'),
          body: ListView(
            padding: pagePad(context, 32),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SmallLabel('Tema'),
                    const SizedBox(height: 8),
                    Segmented<String>(
                      values: const ['system', 'light', 'dark'],
                      selected: s.themeMode,
                      labelOf: (v) => switch (v) {
                        'light' => 'Terang',
                        'dark' => 'Gelap',
                        _ => 'Ikut HP',
                      },
                      dense: true,
                      onChanged: (v) =>
                          store.updateSettings((x) => x.themeMode = v),
                    ),
                    const SizedBox(height: 16),
                    const SmallLabel('Ukuran huruf'),
                    const SizedBox(height: 8),
                    Segmented<double>(
                      values: const [1.0, 1.15, 1.3],
                      selected: s.textScale,
                      labelOf: (v) => switch (v) {
                        1.15 => 'Besar',
                        1.3 => 'Sangat besar',
                        _ => 'Normal',
                      },
                      dense: true,
                      onChanged: (v) =>
                          store.updateSettings((x) => x.textScale = v),
                    ),
                    const SizedBox(height: 6),
                    Text(
                        'Dikalikan dengan ukuran huruf HP, dibatasi supaya tampilan tetap rapi.',
                        style: TextStyle(fontSize: 12, color: C.muted)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                onTap: () =>
                    showSheet<void>(context, AccentPickerSheet(store: store)),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                          color: C.accentDark, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Warna utama',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w800)),
                          Text(C.accents[s.accentIndex].$1,
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
                onTap: () => showSheet<void>(context, ProfileSheet(store: store)),
                child: Row(
                  children: [
                    Avatar(path: s.avatarPath, size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Nama, foto & sapaan',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w800)),
                          Text(s.displayName,
                              style: TextStyle(fontSize: 12, color: C.muted)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: C.muted),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
