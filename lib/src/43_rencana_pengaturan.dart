part of '../main.dart';

// =============================================================================
// v3.5: TAB RENCANA, ATUR BERANDA, PENGATURAN (satu pintu)
// =============================================================================

/// Kartu yang bisa dipilih untuk Beranda: id -> (judul, keterangan).
const Map<String, (String, String)> kHomeCards = {
  'week': ('Tinjauan mingguan', 'Ringkasan minggu lalu, Senin sampai Rabu'),
  'quick': ('Catat cepat', 'Tombol template sekali ketuk'),
  'upcoming': ('Tagihan & langganan', '3 yang paling dekat'),
  'budget': ('Anggaran', 'Sisa anggaran bulan ini'),
  'credit': ('Kartu kredit', 'Tagihan dan sisa limit'),
  'goals': ('Target tabungan', 'Progres target pertama'),
  'compare': ('Dibanding bulan lalu', 'Naik/turun per kategori'),
  'recent': ('Transaksi terakhir', '5 transaksi terbaru'),
};

/// Beranda bawaan: ringkas. Sisanya ada di tab Rencana dan Statistik.
const List<String> kDefaultHomeCards = ['week', 'quick', 'recent'];

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
                child: Text('Atur beranda',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              ),
              IconButton(
                tooltip: tr('Tutup'),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          Text(
              'Centang kartu yang mau tampil, tahan dan geser untuk mengubah urutan. Aman dibelanjakan, saldo, dan hal yang perlu dicek selalu tampil paling atas.',
              style: TextStyle(fontSize: 12.5, color: C.muted)),
          const SizedBox(height: 8),
          Text(tr('Baris di bawah kartu utama'),
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: C.muted)),
          CheckboxListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            controlAffinity: ListTileControlAffinity.trailing,
            activeColor: C.accentDark,
            title: Text(tr('Maskot'),
                style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(tr('Status singkat dan maskot')),
            value: widget.store.settings.homeMaskot,
            onChanged: (v) => setState(
                () => widget.store.updateSettings((s) => s.homeMaskot = v == true)),
          ),
          CheckboxListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            controlAffinity: ListTileControlAffinity.trailing,
            activeColor: C.accentDark,
            title: Text(tr('Ritme'),
                style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(tr('Anggaran terpakai dibanding hari di periode')),
            value: widget.store.settings.homeRitme,
            onChanged: (v) => setState(
                () => widget.store.updateSettings((s) => s.homeRitme = v == true)),
          ),
          const SizedBox(height: 4),
          Text(tr('Kartu di bawahnya'),
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: C.muted)),
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
              widget.store.updateSettings((s) {
                s.homeMaskot = true;
                s.homeRitme = true;
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

enum _PlanSub { tagihan, cicilan, target, utang }

class PlanTab extends StatefulWidget {
  const PlanTab({super.key, required this.store});
  final AppStore store;

  @override
  State<PlanTab> createState() => _PlanTabState();
}

class _PlanTabState extends State<PlanTab> {
  AppStore get store => widget.store;
  _PlanSub _sub = _PlanSub.tagihan;
  bool _tips = false;

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

  /// Satu baris saran. Ketuk untuk membuka kartu saran lengkap.
  Widget _tipsRow(int count) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: () => setState(() => _tips = !_tips),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline_rounded, color: C.amberDark, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(tr('{0} saran untuk bulan ini', [count]),
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 14)),
          ),
          Icon(_tips ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              color: C.muted),
        ],
      ),
    );
  }

  Widget _debtCard(BuildContext context, String Function(double) m,
      double owedToMe, double iOwe) {
    return AppCard(
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
            );
  }

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

    final subs = <_PlanSub>[
      _PlanSub.tagihan,
      if (store.feature('cicilan')) _PlanSub.cicilan,
      if (store.feature('target')) _PlanSub.target,
      if (store.feature('utang')) _PlanSub.utang,
    ];
    final sub = subs.contains(_sub) ? _sub : _PlanSub.tagihan;
    final tipCount = store
        .insights(now)
        .where((i) => kPlanInsights.contains(i.kind))
        .length;

    final List<Widget> body;
    switch (sub) {
      case _PlanSub.tagihan:
        body = [
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
        ];
      case _PlanSub.cicilan:
        body = [
          _section(context, 'Cicilan',
              action: store.installments.isEmpty ? null : 'Semua',
              onAction: () => _pushPage(context, InstallmentsPage(store: store))),
          if (store.activeInstallments.isEmpty)
            _empty(context, Icons.credit_score_rounded,
                'Belum ada cicilan 0%. Misalnya SPayLater atau Kredivo.',
                'Tambah', () => _pushPage(context, InstallmentsPage(store: store)))
          else
            InstallmentSummaryCard(store: store),
        ];
      case _PlanSub.target:
        body = [
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
        ];
      case _PlanSub.utang:
        body = [
          _section(context, 'Utang & piutang',
              action: 'Buka',
              onAction: () => _pushPage(context, DebtsPage(store: store))),
          if (owedToMe <= 0 && iOwe <= 0)
            _empty(context, Icons.handshake_rounded,
                'Tidak ada utang atau piutang yang belum lunas.', 'Catat',
                () => _pushPage(context, DebtsPage(store: store)))
          else
            _debtCard(context, m, owedToMe, iOwe),
        ];
    }

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        children: [
          const Text('Rencana',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(
              tr('{0}{1} · {2} hari lagi', [
                DateFormat('MMMM yyyy', gDateLoc).format(label),
                span.isEmpty ? '' : ' ($span)',
                daysLeft
              ]),
              style: TextStyle(fontSize: 12.5, color: C.muted)),
          _section(context, 'Anggaran',
              action: 'Atur',
              onAction: () => _pushPage(context, BudgetPage(store: store))),
          home._budgetCard(context),
          if (tipCount > 0) ...[
            const SizedBox(height: 10),
            _tipsRow(tipCount),
            if (_tips) ...[
              const SizedBox(height: 10),
              InsightStrip(
                  store: store,
                  onOpenCaptures: () {},
                  kinds: kPlanInsights,
                  title: 'Saran'),
            ],
          ],
          if (subs.length > 1) ...[
            const SizedBox(height: 16),
            Segmented<_PlanSub>(
              values: subs,
              selected: sub,
              labelOf: (t) => switch (t) {
                _PlanSub.tagihan => tr('Tagihan'),
                _PlanSub.cicilan => tr('Cicilan'),
                _PlanSub.target => tr('Target'),
                _PlanSub.utang => tr('Utang'),
              },
              dense: true,
              onChanged: (t) => setState(() => _sub = t),
            ),
          ],
          ...body,
          if (sub == _PlanSub.cicilan || sub == _PlanSub.target) ...[
            const SizedBox(height: 10),
            AppCard(
              onTap: () => _pushPage(context, WhatIfPage(store: store)),
              child: Row(
                children: [
                  CatIcon(icon: Icons.tune_rounded, color: C.income, size: 38),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('Simulasi'),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 14)),
                        Text(tr('Lihat efek hemat atau tabung ke target dan cicilan'),
                            style: TextStyle(fontSize: 12, color: C.muted)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: C.muted),
                ],
              ),
            ),
          ],
          if (store.feature('patungan') || store.feature('acara')) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (store.feature('patungan'))
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => showSheet<void>(
                          context, PatunganSheet(store: store)),
                      icon: const Icon(Icons.groups_rounded),
                      label: const Text('Patungan'),
                    ),
                  ),
                if (store.feature('patungan') && store.feature('acara'))
                  const SizedBox(width: 8),
                if (store.feature('acara'))
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _pushPage(context, EventsPage(store: store)),
                      icon: const Icon(Icons.celebration_rounded),
                      label: const Text('Acara'),
                    ),
                  ),
              ],
            ),
          ],
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
                      tr('{0} · huruf {1} · {2}', [tr(theme), tr(size), tr(C.accents[s.accentIndex].$1)]),
                      () => _pushPage(context, AppearancePage(store: store))),
                  _row(
                      context,
                      Icons.dashboard_customize_rounded,
                      C.blueDark,
                      'Atur beranda',
                      '${s.homeCards.length} kartu tampil',
                      () => showSheet<void>(
                          context, HomeCardsSheet(store: store))),
                  _row(
                      context,
                      Icons.toggle_on_rounded,
                      C.income,
                      'Fitur',
                      tr('{0} dari {1} menyala', [store.featuresOnCount, kFeatureList.length]),
                      () => _pushPage(context, FeaturesPage(store: store))),
                ]),
              ),
              const SizedBox(height: 14),
              const SmallLabel('Keuangan'),
              const SizedBox(height: 6),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(children: [
                  _row(
                      context,
                      Icons.event_repeat_rounded,
                      C.amberDark,
                      'Awal bulan keuangan',
                      s.periodStartDay == 1
                          ? 'Tanggal 1 (bulan kalender)'
                          : 'Tanggal ${s.periodStartDay} (gajian) · ${periodSpanText(periodLabelOf(DateTime.now()))}',
                      () => PeriodStartTile(store: store)._pick(context)),
                  _row(
                      context,
                      Icons.currency_exchange_rounded,
                      C.income,
                      'Mata uang & kurs',
                      at == null
                          ? 'Kurs bawaan'
                          : 'Diperbarui ${DateFormat('d MMM yyyy', gDateLoc).format(at)}',
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
                    if (s.stylePack == 'classic') ...[
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
                    ],
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
                    const SizedBox(height: 16),
                    const SmallLabel('Bahasa'),
                    const SizedBox(height: 8),
                    Segmented<String>(
                      values: const ['id', 'en', 'zh'],
                      selected: s.lang,
                      labelOf: (v) => langName(langOf(v)),
                      dense: true,
                      onChanged: (v) => store.updateSettings((x) => x.lang = v),
                    ),
                    const SizedBox(height: 6),
                    Text(
                        'English dan 简体中文 diterjemahkan bertahap. Yang belum diterjemahkan tetap tampil dalam bahasa Indonesia.',
                        style: TextStyle(fontSize: 12, color: C.muted)),
                    const SizedBox(height: 16),
                    const SmallLabel('Gaya ikon kategori'),
                    const SizedBox(height: 8),
                    Segmented<String>(
                      values: const ['cartoon', 'flat', 'classic', 'mono'],
                      selected: s.iconStyle,
                      labelOf: (v) => switch (v) {
                        'classic' => 'Klasik',
                        'flat' => 'Flat',
                        'mono' => 'Mono',
                        _ => 'Kartun',
                      },
                      dense: true,
                      onChanged: (v) =>
                          store.updateSettings((x) => x.iconStyle = v),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (final k in const [
                          'food',
                          'coffee',
                          'bag',
                          'pill',
                          'invest'
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: CatIcon(
                                icon: iconOf(k),
                                art: k,
                                color: C.accent,
                                size: 34),
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
                    const SmallLabel('Animasi pembuka'),
                    const SizedBox(height: 8),
                    Segmented<String>(
                      values: const ['once', 'always', 'off'],
                      selected: s.splashMode,
                      labelOf: (v) => switch (v) {
                        'always' => 'Tiap buka',
                        'off' => 'Mati',
                        _ => 'Sekali saja',
                      },
                      dense: true,
                      onChanged: (v) =>
                          store.updateSettings((x) => x.splashMode = v),
                    ),
                    const SizedBox(height: 6),
                    Text(
                        'Sekali saja: hanya saat pertama kali dibuka. Tiap buka: versi singkat sekitar 1 detik. Otomatis dilewati kalau "Kurangi animasi" di HP menyala.',
                        style: TextStyle(fontSize: 12, color: C.muted)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SmallLabel('Bentuk grafik kategori'),
                    const SizedBox(height: 8),
                    Segmented<String>(
                      values: const ['donut', 'pie'],
                      selected: s.chartShape,
                      labelOf: (v) => v == 'pie' ? 'Lingkaran penuh' : 'Cincin',
                      dense: true,
                      onChanged: (v) =>
                          store.updateSettings((x) => x.chartShape = v),
                    ),
                    const SizedBox(height: 6),
                    Text(
                        'Dipakai di grafik pengeluaran per kategori di Statistik.',
                        style: TextStyle(fontSize: 12, color: C.muted)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                onTap: () =>
                    showSheet<void>(context, StylePickerSheet(store: store)),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: C.accentDark),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Gaya',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w800)),
                          Text(
                              s.stylePack == 'classic'
                                  ? 'Klasik'
                                  : kStylePacks[s.stylePack]!.name,
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
                onTap: () =>
                    showSheet<void>(context, MascotPickerSheet(store: store)),
                child: Row(
                  children: [
                    ValueListenableBuilder<String>(
                      valueListenable: gMascotSkin,
                      builder: (context, skin, _) => Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                            color: mascotBase(skin), shape: BoxShape.circle),
                        alignment: Alignment.center,
                        clipBehavior: Clip.antiAlias,
                        child: mascotImage(skin, MascotMood.ok, 28,
                            s.mascotCustomPath),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Maskot',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w800)),
                          Text(
                              s.mascotSkin == 'auto'
                                  ? tr('Ikut paket ({0})', [
                                      tr(switch (effectiveMascotSkin(s)) {
                                        'owl' => 'Burung Hantu',
                                        'fox' => 'Rubah',
                                        'crow' => 'Gagak',
                                        _ => 'Klasik',
                                      })
                                    ])
                                  : switch (s.mascotSkin) {
                                      'owl' => 'Burung Hantu',
                                      'fox' => 'Rubah',
                                      'crow' => 'Gagak',
                                      'custom' => 'Gambar sendiri',
                                      _ => 'Klasik',
                                    },
                              style: TextStyle(fontSize: 12, color: C.muted)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: C.muted),
                  ],
                ),
              ),
              if (s.stylePack != 'classic') ...[
                const SizedBox(height: 12),
                AppCard(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: s.packMotif,
                    onChanged: (v) =>
                        store.updateSettings((x) => x.packMotif = v),
                    title: Text(tr('Motif latar'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14)),
                    subtitle: Text(
                        tr('Kabut, awan, atau lampu di belakang Beranda sesuai gaya. Matikan kalau terasa ramai.'),
                        style: TextStyle(fontSize: 12, color: C.muted)),
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: s.packTone,
                    onChanged: (v) =>
                        store.updateSettings((x) => x.packTone = v),
                    title: Text(tr('Nada kalimat ikut paket'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14)),
                    subtitle: Text(
                        tr('Kalimat di kartu Maskot mengikuti watak paket gaya. Matikan untuk kalimat netral seperti Klasik.'),
                        style: TextStyle(fontSize: 12, color: C.muted)),
                  ),
                ),
              ],
              if (s.stylePack == 'classic') ...[
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
              ],
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
