part of '../main.dart';

// =============================================================================
// TINJAUAN MINGGUAN (v5.14)
// Ringkasan minggu lalu (Senin sampai Minggu) dibanding minggu sebelumnya,
// dengan tiga temuan. Semua dihitung di HP dari catatan yang ada.
// =============================================================================

/// Transaksi sampai nominal ini (Rupiah) dianggap "kecil".
const double kSmallTxMax = 50000;

/// Transaksi kecil dengan nama sama minimal sekian kali seminggu = berulang.
const int kSmallTxMinCount = 3;

/// Kenaikan kategori baru disebut kalau naik sekurangnya ini (Rupiah) dan
/// sekurangnya [kRiseMinRatio] dari minggu sebelumnya.
const double kRiseMin = 50000;
const double kRiseMinRatio = 0.2;

/// Kartu di Beranda tampil Senin sampai Rabu (sesudah itu tinjauan tetap bisa
/// dibuka dari Lainnya).
const int kWeekCardLastWeekday = DateTime.wednesday;

/// Hari catatan yang dibutuhkan sebelum tinjauan pertama (dua minggu penuh).
const int kWeekReviewNeedDays = 14;

class WeekRise {
  const WeekRise(this.categoryId, this.now, this.before);
  final String categoryId;
  final double now;
  final double before;
  double get diff => now - before;
  double? get ratio => before > 0 ? diff / before : null;
}

class SmallRepeat {
  const SmallRepeat(this.title, this.count, this.total, this.ids);
  final String title;
  final int count;
  final double total;

  /// Id transaksi yang dihitung (untuk daftar rinciannya).
  final List<String> ids;

  /// Perkiraan kasar setahun: total minggu itu dikali 52.
  double get perYear => total * 52;
}

class WeekPace {
  const WeekPace(this.used, this.elapsed, this.day, this.totalDays);

  /// Bagian anggaran global yang terpakai (bisa lebih dari 1).
  final double used;

  /// Bagian periode anggaran yang sudah berjalan, 0..1.
  final double elapsed;
  final int day;
  final int totalDays;

  /// Titik persen di bawah (negatif) atau di atas (positif) ritme.
  int get points => ((used - elapsed) * 100).round();
}

class WeekReview {
  const WeekReview({
    required this.range,
    required this.total,
    required this.prevTotal,
    required this.days,
    required this.dayCounts,
    this.rise,
    this.topCategoryId,
    this.topCategoryAmount = 0,
    this.small,
    this.pace,
  });

  /// Senin sampai Senin berikutnya (akhir eksklusif).
  final DateTimeRange range;
  final double total;
  final double prevTotal;

  /// Pengeluaran per hari, Senin sampai Minggu (Rupiah).
  final List<double> days;
  final List<int> dayCounts;
  final WeekRise? rise;

  /// Kategori terbesar minggu itu (dipakai kalau tidak ada kenaikan berarti).
  final String? topCategoryId;
  final double topCategoryAmount;
  final SmallRepeat? small;
  final WeekPace? pace;

  DateTime get lastDay =>
      DateTime(range.end.year, range.end.month, range.end.day - 1);

  /// Perubahan terhadap minggu sebelumnya (0.18 = naik 18%). Null kalau
  /// minggu sebelumnya kosong.
  double? get change => prevTotal > 0 ? (total - prevTotal) / prevTotal : null;

  int get peakDay {
    var best = 0;
    for (var i = 1; i < days.length; i++) {
      if (days[i] > days[best]) best = i;
    }
    return best;
  }
}

extension WeekReviewStore on AppStore {
  /// Minggu lalu (Senin sampai Minggu) relatif ke [now].
  DateTimeRange lastWeekRange(DateTime now) {
    final w = weekRange(now);
    return DateTimeRange(
        start: DateTime(w.start.year, w.start.month, w.start.day - 7),
        end: w.start);
  }

  /// Tanggal transaksi tertua, null kalau belum ada catatan.
  DateTime? firstTxDay() {
    DateTime? first;
    for (final t in transactions) {
      if (first == null || t.date.isBefore(first)) first = t.date;
    }
    return first == null ? null : dayOnly(first);
  }

  /// Berapa hari (maks [kWeekReviewNeedDays]) catatan sudah berjalan.
  int weekReviewDays(DateTime now) {
    final f = firstTxDay();
    if (f == null) return 0;
    final d = dayOnly(now).difference(f).inDays + 1;
    return d.clamp(0, kWeekReviewNeedDays);
  }

  /// Tinjauan minggu lalu. Null kalau catatan belum mencakup dua minggu penuh
  /// (minggu lalu dan sebelumnya) atau minggu lalu tidak ada pengeluaran.
  WeekReview? weekReview(DateTime now) {
    final last = lastWeekRange(now);
    final prev = DateTimeRange(
        start: DateTime(last.start.year, last.start.month, last.start.day - 7),
        end: last.start);
    final first = firstTxDay();
    if (first == null || first.isAfter(prev.start)) return null;

    final days = List<double>.filled(7, 0);
    final counts = List<int>.filled(7, 0);
    var total = 0.0;
    final groups = <String, _SmallGroup>{};
    for (final t in transactions) {
      if (t.type != TxType.expense || !inRange(t.date, last)) continue;
      final v = amountIDR(t);
      total += v;
      final i = (t.date.weekday - 1).clamp(0, 6);
      days[i] += v;
      counts[i]++;
      final key = t.title.trim().toLowerCase();
      if (v <= kSmallTxMax && key.isNotEmpty) {
        final g = groups.putIfAbsent(key, () => _SmallGroup(t.title.trim()));
        g.total += v;
        g.ids.add(t.id);
      }
    }
    if (total <= 0) return null;
    final prevTotal = sumIDR(TxType.expense, prev);

    final cur = byTopCategory(TxType.expense, last);
    final before = byTopCategory(TxType.expense, prev);
    WeekRise? rise;
    String? topId;
    var topAmount = 0.0;
    for (final e in cur.entries) {
      if (e.key == '_none') continue;
      if (e.value > topAmount) {
        topAmount = e.value;
        topId = e.key;
      }
      final r = WeekRise(e.key, e.value, before[e.key] ?? 0);
      final ratio = r.ratio;
      final ok = r.diff >= kRiseMin && (ratio == null || ratio >= kRiseMinRatio);
      if (ok && (rise == null || r.diff > rise.diff)) rise = r;
    }

    SmallRepeat? small;
    for (final g in groups.values) {
      if (g.ids.length < kSmallTxMinCount) continue;
      if (small == null || g.total > small.total) {
        small = SmallRepeat(g.title, g.ids.length, g.total, g.ids);
      }
    }

    WeekPace? pace;
    final s = settings;
    if (s.globalBudget > 0) {
      final range = s.budgetPeriod.range(now);
      final spent = sumIDR(TxType.expense, range);
      final start = dayOnly(range.start);
      final end = dayOnly(range.end);
      pace = WeekPace(
          spent / s.globalBudget,
          periodElapsed(range, now),
          dayOnly(now).difference(start).inDays + 1,
          end.difference(start).inDays);
    }

    return WeekReview(
      range: last,
      total: total,
      prevTotal: prevTotal,
      days: days,
      dayCounts: counts,
      rise: rise,
      topCategoryId: topId,
      topCategoryAmount: topAmount,
      small: small,
      pace: pace,
    );
  }

  /// Awal minggu lalu sebagai kunci simpan ("2026-10-12").
  String weekKey(DateTime now) =>
      DateFormat('yyyy-MM-dd').format(lastWeekRange(now).start);

  /// Kartu Beranda tampil: ada tinjauan, hari Senin sampai Rabu, dan belum
  /// dibuka atau ditutup untuk minggu ini.
  bool weekCardVisible(DateTime now) =>
      now.weekday <= kWeekCardLastWeekday &&
      settings.weekSeen != weekKey(now) &&
      weekReview(now) != null;

  void markWeekSeen(DateTime now) {
    final k = weekKey(now);
    if (settings.weekSeen == k) return;
    updateSettings((s) => s.weekSeen = k);
  }
}

class _SmallGroup {
  _SmallGroup(this.title);
  final String title;
  double total = 0;
  final List<String> ids = [];
}

// ----------------------------------------------------------------- teks

String _weekRangeLabel(DateTimeRange r) {
  final f = DateFormat('d MMM', gDateLoc);
  final last = DateTime(r.end.year, r.end.month, r.end.day - 1);
  return tr('{0} sampai {1}', [f.format(r.start), f.format(last)]);
}

String _changeLabel(WeekReview w) {
  final c = w.change;
  if (c == null) return tr('Minggu sebelumnya tanpa pengeluaran');
  final pct = (c.abs() * 100).round();
  if (pct == 0) return tr('sama dengan minggu sebelumnya');
  return c > 0
      ? tr('naik {0}% dari minggu sebelumnya', [pct])
      : tr('turun {0}% dari minggu sebelumnya', [pct]);
}

String _topCatName(AppStore store, String id) =>
    shortCategoryName(store.categoryById(id)?.name ?? 'Tanpa kategori');

// ----------------------------------------------------------------- batang harian

class WeekBars extends StatelessWidget {
  const WeekBars(
      {super.key, required this.review, required this.height, this.names = false});
  final WeekReview review;
  final double height;

  /// true: nama hari tiga huruf dan nominal puncak di atas batang.
  final bool names;

  @override
  Widget build(BuildContext context) {
    final mx = review.days.fold<double>(0, (a, b) => b > a ? b : a);
    final peak = review.peakDay;
    final labels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    final short = ['S', 'S', 'R', 'K', 'J', 'S', 'M'];
    return Semantics(
      label: tr('Pengeluaran per hari. Terbesar hari {0}, {1}.',
          [labels[peak], money(review.days[peak])]),
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (names)
                      SizedBox(
                        height: 18,
                        child: i == peak && mx > 0
                            ? Text(compactMoney(review.days[i]),
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: C.carbon))
                            : null,
                      ),
                    Container(
                      height: mx <= 0
                          ? 6
                          : (review.days[i] / mx * height).clamp(6.0, height),
                      decoration: BoxDecoration(
                        color: i == peak ? C.accentDark : C.line,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(5), bottom: Radius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(names ? labels[i] : short[i],
                        style: TextStyle(
                            fontSize: 12,
                            color: i == peak ? C.carbon : C.muted,
                            fontWeight:
                                i == peak ? FontWeight.w700 : FontWeight.w400)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- kartu Beranda

class WeekReviewCard extends StatelessWidget {
  const WeekReviewCard({super.key, required this.store, required this.onOpen});
  final AppStore store;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final w = store.weekReview(now);
    if (w == null || !store.weekCardVisible(now)) return const SizedBox.shrink();
    final c = w.change;
    final pct = c == null ? 0 : (c.abs() * 100).round();
    final headline = c == null || pct == 0
        ? money(w.total)
        : (c > 0
            ? tr('{0}, naik {1}%', [money(w.total), pct])
            : tr('{0}, turun {1}%', [money(w.total), pct]));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: C.surface,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.only(left: 14, right: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: C.line),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: C.accentDark.withValues(alpha: 0.12),
                    shape: BoxShape.circle),
                child: Icon(Icons.trending_up_rounded,
                    size: 22, color: C.accentDark),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onOpen,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('Tinjauan minggu lalu'),
                            style: TextStyle(fontSize: 12.5, color: C.muted)),
                        const SizedBox(height: 1),
                        Text(headline,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: C.carbon)),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: tr('Sembunyikan tinjauan minggu ini'),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed: () => store.markWeekSeen(now),
                icon: Icon(Icons.close_rounded, size: 20, color: C.muted),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onOpen,
                child: SizedBox(
                  width: 28,
                  height: 44,
                  child: Icon(Icons.chevron_right_rounded, color: C.muted),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- halaman detail

class WeekReviewPage extends StatefulWidget {
  const WeekReviewPage({super.key, required this.store});
  final AppStore store;

  @override
  State<WeekReviewPage> createState() => _WeekReviewPageState();
}

class _WeekReviewPageState extends State<WeekReviewPage> {
  AppStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    // Dibuka = sudah dilihat, kartu di Beranda tidak perlu muncul lagi.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => store.markWeekSeen(DateTime.now()));
  }

  Widget _finding(
      {required IconData icon,
      required String title,
      required String body,
      String? action,
      VoidCallback? onAction}) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: C.accentDark.withValues(alpha: 0.12),
                      shape: BoxShape.circle),
                  child: Icon(icon, size: 22, color: C.accentDark),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: C.carbon,
                              height: 1.3)),
                      const SizedBox(height: 4),
                      Text(body,
                          style: TextStyle(
                              fontSize: 13.5, color: C.muted, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
            if (action != null)
              Padding(
                padding: const EdgeInsets.only(left: 40),
                child: TextButton(
                  style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: C.accentDark,
                      textStyle: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700)),
                  onPressed: onAction,
                  child: Text(action),
                ),
              )
            else
              const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showSmall(SmallRepeat s) {
    final list = [
      for (final id in s.ids)
        for (final t in store.transactions)
          if (t.id == id) t
    ]..sort((a, b) => b.date.compareTo(a.date));
    showSheet<void>(
      context,
      SheetFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr('{0}, {1} kali', [s.title, s.count]),
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            for (final t in list) txTile(context, store, t, showDate: true),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pageBar('Tinjauan minggu lalu'),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final now = DateTime.now();
          final w = store.weekReview(now);
          if (w == null) return _empty(now);
          final dayNames = [
            'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
          ];
          final pk = w.peakDay;
          final findings = <Widget>[];
          final rise = w.rise;
          if (rise != null) {
            final name = _topCatName(store, rise.categoryId);
            final ratio = rise.ratio;
            findings.add(_finding(
              icon: Icons.restaurant_rounded,
              title: tr('{0} naik {1}', [name, money(rise.diff)]),
              body: ratio == null
                  ? tr('{0} minggu lalu, sebelumnya belum ada pengeluaran di kategori ini.',
                      [money(rise.now)])
                  : tr('{0} minggu lalu, minggu sebelumnya {1} (naik {2}%).',
                      [money(rise.now), money(rise.before), (ratio * 100).round()]),
              action: tr('Atur anggaran kategori ini'),
              onAction: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => BudgetPage(store: store))),
            ));
          } else if (w.topCategoryId != null) {
            findings.add(_finding(
              icon: Icons.pie_chart_rounded,
              title: tr('Terbesar: {0}', [_topCatName(store, w.topCategoryId!)]),
              body: tr('{0} minggu lalu. Tidak ada kategori yang naik berarti dibanding minggu sebelumnya.',
                  [money(w.topCategoryAmount)]),
            ));
          }
          final small = w.small;
          if (small != null) {
            findings.add(_finding(
              icon: Icons.local_cafe_rounded,
              title: tr('{0} {1} kali, total {2}',
                  [small.title, small.count, money(small.total)]),
              body: tr('Transaksi kecil yang berulang. Kalau pola ini jalan sepanjang tahun, jumlahnya sekitar {0} (perkiraan kasar: total minggu ini dikali 52).',
                  [money(small.perYear)]),
              action: tr('Lihat transaksinya'),
              onAction: () => _showSmall(small),
            ));
          }
          final pace = w.pace;
          if (pace != null) {
            final used = (pace.used * 100).round();
            final el = (pace.elapsed * 100).round();
            final pts = pace.points;
            final per = tr(store.settings.budgetPeriod.current);
            findings.add(_finding(
              icon: Icons.speed_rounded,
              title: pts.abs() <= 10
                  ? tr('Ritme {0} pas dengan kalender', [per])
                  : (pts > 0
                      ? tr('Ritme {0} lebih cepat dari kalender', [per])
                      : tr('Ritme {0} lebih pelan dari kalender', [per])),
              body: tr('Anggaran terpakai {0}%, hari ke-{1} dari {2} ({3}%). Selisihnya {4} poin {5} ritme.',
                  [
                    used,
                    pace.day,
                    pace.totalDays,
                    el,
                    pts.abs(),
                    pts >= 0 ? tr('di atas') : tr('di bawah')
                  ]),
            ));
          }
          return ListView(
            padding: pagePad(context, 40),
            children: [
              AppCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        tr('{0} sampai {1}', [
                          DateFormat('EEEE d MMM', gDateLoc).format(w.range.start),
                          DateFormat('EEEE d MMM', gDateLoc).format(w.lastDay)
                        ]),
                        style: TextStyle(fontSize: 12.5, color: C.muted)),
                    const SizedBox(height: 2),
                    Text(money(w.total),
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: C.carbon)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (w.change != null)
                          Icon(
                              w.change! >= 0
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              size: 16,
                              color: C.carbon),
                        if (w.change != null) const SizedBox(width: 4),
                        Flexible(
                          child: Text(_changeLabel(w),
                              style: TextStyle(fontSize: 13.5, color: C.carbon)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    WeekBars(review: w, height: 72, names: true),
                    const SizedBox(height: 10),
                    Text(
                        tr('{0}Hari terbesar: {1}, {2} dalam {3} transaksi.', [
                          w.prevTotal > 0
                              ? tr('Minggu sebelumnya {0}. ', [money(w.prevTotal)])
                              : '',
                          tr(dayNames[pk]),
                          money(w.days[pk]),
                          w.dayCounts[pk]
                        ]),
                        style: TextStyle(
                            fontSize: 12.5, color: C.muted, height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Yang layak dilihat',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ...findings,
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                    tr('Dihitung di HP dari catatanmu, tanpa internet. Transfer antar akunmu tidak dihitung sebagai pengeluaran. Kartu di Beranda bisa dimatikan lewat Atur Beranda.'),
                    style: TextStyle(fontSize: 12.5, color: C.muted, height: 1.4)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _empty(DateTime now) {
    final n = store.weekReviewDays(now);
    final has = store.transactions.isNotEmpty;
    return ListView(
      padding: pagePad(context, 40),
      children: [
        const SizedBox(height: 24),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            children: [
              Text(
                  has && n >= kWeekReviewNeedDays
                      ? tr('Minggu lalu tanpa pengeluaran')
                      : tr('Belum cukup catatan'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                  has && n >= kWeekReviewNeedDays
                      ? tr('Tidak ada pengeluaran tercatat di minggu lalu, jadi belum ada yang bisa ditinjau.')
                      : tr('Tinjauan butuh dua minggu penuh supaya bisa membandingkan. Kartunya muncul di Beranda hari Senin setelah itu.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, color: C.muted, height: 1.45)),
              if (!(has && n >= kWeekReviewNeedDays)) ...[
                const SizedBox(height: 18),
                FunProgressBar(
                    value: n / kWeekReviewNeedDays,
                    color: C.accentDark,
                    height: 6),
                const SizedBox(height: 8),
                Text(tr('{0} dari {1} hari tercatat', [n, kWeekReviewNeedDays]),
                    style: TextStyle(fontSize: 12.5, color: C.muted)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
