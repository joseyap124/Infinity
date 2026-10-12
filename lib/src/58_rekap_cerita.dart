part of '../main.dart';

// =============================================================================
// REKAP BULANAN BERCERITA (v5.0)
// Lima slide: tabungan, uang masuk dan keluar, kategori terbesar, hari
// terboros, dibanding bulan lalu. Tiap slide bisa dibagikan sebagai gambar
// (nominal disembunyikan secara bawaan). Versi lengkap tetap ada di
// MonthRecapPage.
// =============================================================================

class MonthStory {
  const MonthStory({
    required this.month,
    required this.hasData,
    required this.income,
    required this.expense,
    required this.topCats,
    required this.peakDay,
    required this.peakAmount,
    required this.weekendExtraPct,
    required this.lastExpense,
    required this.catChanges,
  });

  final DateTime month;
  final bool hasData;
  final double income;
  final double expense;

  /// Tiga kategori terbesar: (id, jumlah, porsi dari semua pengeluaran 0..1).
  final List<(String, double, double)> topCats;
  final DateTime? peakDay;
  final double peakAmount;

  /// Rata-rata pengeluaran akhir pekan lebih besar sekian persen dari hari kerja.
  final double? weekendExtraPct;
  final double? lastExpense;

  /// Perubahan tiga kategori terbesar dibanding bulan lalu (persen); null kalau
  /// bulan lalu kosong untuk kategori itu.
  final List<(String, double?)> catChanges;

  /// Porsi pemasukan yang tersisa (bisa negatif); null kalau tidak ada pemasukan.
  double? get savingRate => income > 0 ? (income - expense) / income : null;

  double? get expenseChangePct => lastExpense != null && lastExpense! > 0
      ? (expense - lastExpense!) / lastExpense! * 100
      : null;
}

extension MonthStoryStore on AppStore {
  MonthStory monthStory(DateTime month, DateTime now) {
    final m = DateTime(month.year, month.month);
    final r = periodRange(m);
    final has = transactions.any((t) =>
        t.type != TxType.transfer && inRange(t.date, r));
    final income = sumIDR(TxType.income, r);
    final expense = sumIDR(TxType.expense, r);
    final cats = byTopCategory(TxType.expense, r).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = <(String, double, double)>[
      for (final e in cats.take(3))
        (e.key, e.value, expense > 0 ? e.value / expense : 0.0),
    ];

    // Pengeluaran per hari.
    final daily = <DateTime, double>{};
    for (final t in transactions) {
      if (t.type != TxType.expense || !inRange(t.date, r)) continue;
      final d = dayOnly(t.date);
      daily[d] = (daily[d] ?? 0) + amountIDR(t);
    }
    DateTime? peak;
    var peakAmt = 0.0;
    daily.forEach((d, v) {
      if (v > peakAmt) {
        peakAmt = v;
        peak = d;
      }
    });

    // Akhir pekan vs hari kerja, dihitung sampai hari ini kalau bulan berjalan.
    final last = r.end.subtract(const Duration(days: 1));
    final until = now.isBefore(last) ? dayOnly(now) : dayOnly(last);
    var weDays = 0, wdDays = 0;
    var weSum = 0.0, wdSum = 0.0;
    for (var d = dayOnly(r.start); !d.isAfter(until); d = DateTime(d.year, d.month, d.day + 1)) {
      final v = daily[d] ?? 0;
      if (d.weekday >= DateTime.saturday) {
        weDays++;
        weSum += v;
      } else {
        wdDays++;
        wdSum += v;
      }
    }
    double? weekendExtra;
    if (weDays >= 2 && wdDays >= 2 && wdSum > 0) {
      weekendExtra = ((weSum / weDays) / (wdSum / wdDays) - 1) * 100;
    }

    // Bulan lalu.
    final pr = periodRange(DateTime(m.year, m.month - 1));
    final prevHas = transactions.any((t) =>
        t.type != TxType.transfer && inRange(t.date, pr));
    double? lastExp;
    var changes = <(String, double?)>[];
    if (prevHas) {
      lastExp = sumIDR(TxType.expense, pr);
      final prevCats = byTopCategory(TxType.expense, pr);
      changes = [
        for (final (id, v, _) in top)
          (
            id,
            (prevCats[id] ?? 0) > 0 ? (v - prevCats[id]!) / prevCats[id]! * 100 : null
          ),
      ];
    }
    return MonthStory(
        month: m,
        hasData: has,
        income: income,
        expense: expense,
        topCats: top,
        peakDay: peak,
        peakAmount: peakAmt,
        weekendExtraPct: weekendExtra,
        lastExpense: lastExp,
        catChanges: changes);
  }
}

/// Kalimat di bawah angka tabungan slide 1.
String storySavingNote(double? rate) {
  if (rate == null) return 'Belum ada pemasukan tercatat bulan ini.';
  if (rate < 0) return 'Pengeluaran bulan ini lebih besar dari pemasukan.';
  if (rate >= 0.20) return 'Sudah di atas target sehat 20%.';
  if (rate >= 0.10) return 'Sedikit lagi ke target sehat 20%.';
  return 'Target sehat 20%. Mulai dari langkah kecil.';
}

/// Teks perubahan dengan tanda, mis. "▲ 60%" atau "▼ 8%".
String storyDelta(double? pct) {
  if (pct == null) return 'baru';
  final v = pct.abs().round();
  if (v == 0) return '● sama';
  return '${pct > 0 ? '▲' : '▼'} $v%';
}

class MonthStoryPage extends StatefulWidget {
  const MonthStoryPage({super.key, required this.store, required this.month});
  final AppStore store;
  final DateTime month;

  @override
  State<MonthStoryPage> createState() => _MonthStoryPageState();
}

class _MonthStoryPageState extends State<MonthStoryPage> {
  static const int _count = 5;
  final _boundary = GlobalKey();
  int _page = 0;
  bool _show = false;
  bool _busy = false;

  AppStore get store => widget.store;

  bool get _hide => !_show || store.settings.hideBalance;

  void _go(int d) {
    final n = (_page + d).clamp(0, _count - 1);
    if (n != _page) setState(() => _page = n);
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    Uint8List? bytes;
    final obj = _boundary.currentContext?.findRenderObject();
    if (obj is RenderRepaintBoundary) {
      final img = await obj.toImage(pixelRatio: 3);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      bytes = data?.buffer.asUint8List();
    }
    var ok = false;
    if (bytes != null) {
      ok = await NativeBridge.shareImage(
          'infinity-cerita-${DateFormat('yyyy-MM').format(widget.month)}-${_page + 1}${_hide ? '' : '-nominal'}.png',
          bytes);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) snack(context, 'Tidak bisa membuka menu bagikan.');
  }

  @override
  Widget build(BuildContext context) {
    final story = store.monthStory(widget.month, DateTime.now());
    return Scaffold(
      appBar: pageBar('Cerita bulan ini', actions: [
        TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  MonthRecapPage(store: store, month: widget.month))),
          child: const Text('Lengkap'),
        ),
      ]),
      body: SafeArea(
        child: ListView(
          padding: pagePad(context, 24),
          children: [
            Row(
              children: [
                for (var i = 0; i < _count; i++)
                  Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i <= _page ? C.accentDark : C.line,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: LayoutBuilder(builder: (context, c) {
                final w = math.min(c.maxWidth, StoryCard.width);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => _go(d.localPosition.dx > w / 2 ? 1 : -1),
                  child: SizedBox(
                    width: w,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: RepaintBoundary(
                        key: _boundary,
                        child: StoryCard(
                            store: store,
                            story: story,
                            page: _page,
                            hide: _hide),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                  _page == _count - 1
                      ? tr('Sampai jumpa di rekap bulan depan.')
                      : tr('Ketuk kanan untuk lanjut, kiri untuk kembali'),
                  style: TextStyle(fontSize: 12, color: C.muted)),
            ),
            const SizedBox(height: 10),
            if (!store.settings.hideBalance)
              SwitchListTile(
                value: _show,
                onChanged: (v) => setState(() => _show = v),
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: const Text('Tampilkan nominal',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                subtitle: Text(
                    'Nominal disembunyikan secara bawaan, termasuk di gambar yang dibagikan.',
                    style: TextStyle(fontSize: 12, color: C.muted)),
              ),
            const SizedBox(height: 6),
            PrimaryButton(
              label: _busy ? 'Menyiapkan...' : 'Bagikan sebagai gambar',
              icon: Icons.ios_share_rounded,
              onPressed: _busy ? null : _share,
            ),
          ],
        ),
      ),
    );
  }
}

/// Satu slide cerita, lebar tetap supaya gambar hasil bagikan sama di semua HP.
class StoryCard extends StatelessWidget {
  const StoryCard(
      {super.key,
      required this.store,
      required this.story,
      required this.page,
      required this.hide});
  final AppStore store;
  final MonthStory story;
  final int page;
  final bool hide;

  static const double width = 340;
  static const double height = 480;

  static const _bg = Color(0xFF1F1B3A);
  static const _ink = Colors.white;

  String _m(double v) => hide ? 'Rp ••••••' : money(v);
  Color get _soft => Colors.white.withValues(alpha: 0.72);

  Widget _big(String t, {double size = 44}) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(t,
            style: TextStyle(
                color: _ink, fontSize: size, fontWeight: FontWeight.w900, height: 1.05)),
      );

  Widget _label(String t) => Text(t,
      style: TextStyle(color: _soft, fontSize: 15, fontWeight: FontWeight.w700));

  Widget _body() {
    final s = story;
    if (!s.hasData) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _big('Belum ada catatan bulan ini', size: 26),
          const SizedBox(height: 8),
          _label('Catat dulu beberapa transaksi, lalu ceritanya muncul di sini.'),
        ],
      );
    }
    switch (page) {
      case 0:
        final rate = s.savingRate;
        final saved = rate == null ? 0.0 : math.max(0.0, s.income - s.expense);
        final spent = rate == null ? 1.0 : math.min(s.expense, s.income);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Bulan ini kamu menyisihkan'),
            const SizedBox(height: 6),
            _big(rate == null ? '-' : '${(rate * 100).round()}%', size: 72),
            const SizedBox(height: 2),
            _label('dari pemasukanmu'),
            const SizedBox(height: 18),
            Center(
              child: SizedBox(
                width: 130,
                height: 130,
                child: CustomPaint(
                  painter: DonutChartPainter(
                      values: [saved, spent],
                      colors: const [Color(0xFF3CCB7F), Color(0xFFE9507A)],
                      progress: 1),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _label(tr('tersisa {0}', [_m(math.max(0.0, s.income - s.expense))]))),
                Expanded(child: _label(tr('keluar {0}', [_m(s.expense)]))),
              ],
            ),
            const Spacer(),
            Text(tr(storySavingNote(rate)),
                style: const TextStyle(
                    color: _ink, fontSize: 15, fontWeight: FontWeight.w800)),
          ],
        );
      case 1:
        final share = s.income > 0 ? (s.expense / s.income * 100).round() : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _big('Uang masuk dan keluar', size: 26),
            const SizedBox(height: 26),
            _label('Masuk'),
            _big(_m(s.income), size: 36),
            const SizedBox(height: 18),
            _label('Keluar'),
            _big(_m(s.expense), size: 36),
            const Spacer(),
            Text(
                share == null
                    ? tr('Belum ada pemasukan tercatat bulan ini.')
                    : tr('Keluarmu {0}% dari pemasukan.', [share]),
                style: const TextStyle(
                    color: _ink, fontSize: 15, fontWeight: FontWeight.w800)),
          ],
        );
      case 2:
        if (s.topCats.isEmpty) {
          return _big('Belum ada pengeluaran', size: 26);
        }
        String name(String id) => tr(store.categoryById(id)?.name ?? 'Tanpa kategori');
        final first = s.topCats.first;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Uangmu paling banyak ke'),
            const SizedBox(height: 6),
            _big(name(first.$1), size: 52),
            const SizedBox(height: 4),
            _label(tr('{0}% dari semua pengeluaran', [(first.$3 * 100).round()])),
            const SizedBox(height: 26),
            for (final c in s.topCats.skip(1))
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(name(c.$1),
                          style: const TextStyle(
                              color: _ink, fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                    Text('${(c.$3 * 100).round()}%',
                        style: const TextStyle(
                            color: _ink, fontSize: 18, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
          ],
        );
      case 3:
        final d = s.peakDay;
        if (d == null) {
          return _big('Belum ada hari terboros', size: 26);
        }
        final we = s.weekendExtraPct;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Hari terboros bulan ini'),
            const SizedBox(height: 6),
            _big(DateFormat('EEEE, d MMM', gDateLoc).format(d), size: 34),
            const SizedBox(height: 8),
            _label(tr('{0} dalam sehari', [_m(s.peakAmount)])),
            const Spacer(),
            if (we != null && we.abs() >= 5)
              Text(
                  we > 0
                      ? tr('Akhir pekan rata-rata {0}% lebih boros dari hari kerja.', [we.round()])
                      : tr('Akhir pekan rata-rata {0}% lebih hemat dari hari kerja.', [(-we).round()]),
                  style: const TextStyle(
                      color: _ink, fontSize: 15, fontWeight: FontWeight.w800)),
          ],
        );
      default:
        final pct = s.expenseChangePct;
        if (pct == null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Dibanding bulan lalu'),
              const SizedBox(height: 8),
              _big('Belum ada data bulan lalu', size: 26),
              const SizedBox(height: 8),
              _label('Perbandingan muncul begitu ada dua bulan yang tercatat.'),
            ],
          );
        }
        final v = pct.abs().round();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Dibanding bulan lalu'),
            const SizedBox(height: 6),
            _big(
                v == 0
                    ? tr('Keluar sama')
                    : (pct > 0
                        ? tr('Keluar naik {0}%', [v])
                        : tr('Keluar turun {0}%', [v])),
                size: 34),
            const SizedBox(height: 26),
            for (final (id, p) in s.catChanges)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(tr(store.categoryById(id)?.name ?? 'Tanpa kategori'),
                          style: const TextStyle(
                              color: _ink, fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                    Text(tr(storyDelta(p)),
                        style: const TextStyle(
                            color: _ink, fontSize: 18, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MascotView(mood: MascotMood.happy, size: 34),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    tr('Rekap bulan {0}', [DateFormat('MMMM yyyy', gDateLoc).format(story.month)]),
                    style: TextStyle(
                        color: _soft, fontSize: 13, fontWeight: FontWeight.w800)),
              ),
              Text('${page + 1}/5',
                  style: TextStyle(
                      color: _soft, fontSize: 12, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 22),
          Expanded(child: _body()),
        ],
      ),
    );
  }
}
