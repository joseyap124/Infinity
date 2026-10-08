part of '../main.dart';

// =============================================================================
// REKAP & SARAN BULANAN
// Aturan sederhana yang dihitung di HP (aturan 50/30/20, dana darurat 3–6
// bulan, perbandingan dengan rata-rata 3 bulan sebelumnya). Bukan nasihat
// keuangan profesional.
// =============================================================================

enum AdviceLevel { bad, warn, info, good }

class MonthAdvice {
  const MonthAdvice(this.level, this.icon, this.title, this.body);
  final AdviceLevel level;
  final IconData icon;
  final String title;
  final String body;

  bool get isPraise => level == AdviceLevel.good;

  Color get color {
    switch (level) {
      case AdviceLevel.bad:
        return C.redDark;
      case AdviceLevel.warn:
        return C.amberDark;
      case AdviceLevel.info:
        return C.blueDark;
      case AdviceLevel.good:
        return C.income;
    }
  }
}

/// 7 tingkat porsi pemasukan yang ditabung.
class SavingTier {
  const SavingTier(this.rank, this.label, this.emoji, this.level);
  final int rank; // 1 (terburuk) .. 7 (terbaik)
  final String label;
  final String emoji;
  final AdviceLevel level;
}

SavingTier savingTier(double rate) {
  if (rate < -0.10) return const SavingTier(1, 'Defisit besar', '🔴', AdviceLevel.bad);
  if (rate < 0) return const SavingTier(2, 'Tekor tipis', '🔴', AdviceLevel.bad);
  if (rate < 0.10) return const SavingTier(3, 'Baru mulai menabung', '🟠', AdviceLevel.warn);
  if (rate < 0.20) return const SavingTier(4, 'Lumayan', '🟡', AdviceLevel.info);
  if (rate < 0.30) return const SavingTier(5, 'Bagus!', '🟢', AdviceLevel.good);
  if (rate < 0.50) return const SavingTier(6, 'Luar biasa! 🎉', '🟢', AdviceLevel.good);
  return const SavingTier(7, 'Juara menabung! 🏆', '🏆', AdviceLevel.good);
}

/// Bulatkan ke angka yang enak dibaca (Rp50 rb di atas 1 juta, Rp10 rb di bawahnya).
double niceRound(double v) {
  final step = v.abs() >= 1000000 ? 50000.0 : 10000.0;
  return (v / step).round() * step;
}

class MonthRecap {
  const MonthRecap({
    required this.month,
    required this.isCurrent,
    required this.daysElapsed,
    required this.daysInMonth,
    required this.income,
    required this.expense,
    required this.projectedExpense,
    required this.prevMonths,
    required this.avgIncome,
    required this.avgExpense,
    required this.lastMonthExpense,
    required this.topCategories,
    required this.advice,
  });

  final DateTime month;
  final bool isCurrent;
  final int daysElapsed;
  final int daysInMonth;
  final double income;
  final double expense;

  /// Bulan berjalan: perkiraan akhir bulan dari laju sejauh ini.
  final double projectedExpense;

  /// Jumlah bulan sebelumnya (maks. 3) yang punya data.
  final int prevMonths;
  final double avgIncome;
  final double avgExpense;
  final double? lastMonthExpense;
  final List<MapEntry<String, double>> topCategories;
  final List<MonthAdvice> advice;

  double? get savingRate =>
      income > 0 ? (income - projectedExpense) / income : null;
  SavingTier? get tier => savingRate == null ? null : savingTier(savingRate!);
}

extension MonthRecapStore on AppStore {
  bool _hasData(DateTimeRange r) =>
      transactions.any((t) => t.type != TxType.transfer && inRange(t.date, r));

  MonthRecap monthRecap(DateTime month, DateTime now) {
    final m = DateTime(month.year, month.month);
    final r = monthRange(m);
    final isCurrent = inRange(now, r);
    final dim = DateTime(m.year, m.month + 1, 0).day;
    final elapsed = isCurrent ? now.day : dim;
    final frac = elapsed / dim;
    final income = sumIDR(TxType.income, r);
    final expense = sumIDR(TxType.expense, r);
    final proj = isCurrent && frac > 0 ? expense / frac : expense;

    // Rata-rata 3 bulan sebelumnya yang punya data.
    var n = 0;
    var sumInc = 0.0, sumExp = 0.0;
    final prevCat = <String, double>{};
    double? lastMonth;
    for (var i = 1; i <= 3; i++) {
      final pr = monthRange(DateTime(m.year, m.month - i));
      if (!_hasData(pr)) continue;
      n++;
      final e = sumIDR(TxType.expense, pr);
      if (i == 1) lastMonth = e;
      sumInc += sumIDR(TxType.income, pr);
      sumExp += e;
      byTopCategory(TxType.expense, pr).forEach((k, v) {
        prevCat[k] = (prevCat[k] ?? 0) + v;
      });
    }
    final avgInc = n > 0 ? sumInc / n : 0.0;
    final avgExp = n > 0 ? sumExp / n : 0.0;
    final cats = byTopCategory(TxType.expense, r);
    final top = cats.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final advice = <MonthAdvice>[];
    if (_hasData(r)) {
      _savingAdvice(advice, income, proj, isCurrent);
      _trendAdvice(advice, proj, avgExp, n, isCurrent);
      _categoryAdvice(advice, cats, prevCat, n, isCurrent ? frac : 1);
      _smallSpendAdvice(advice, r, expense);
      _budgetAdvice(advice, r, expense, proj, avgExp, n, isCurrent);
      if (isCurrent || !now.isAfter(DateTime(m.year, m.month + 2))) {
        _emergencyAdvice(advice, n > 0 ? avgExp : proj);
      }
      _recurringAdvice(advice, income > 0 ? income : avgInc);
      _debtAdvice(advice, now);
    }
    const order = [AdviceLevel.bad, AdviceLevel.warn, AdviceLevel.info, AdviceLevel.good];
    advice.sort((a, b) => order.indexOf(a.level).compareTo(order.indexOf(b.level)));

    return MonthRecap(
      month: m,
      isCurrent: isCurrent,
      daysElapsed: elapsed,
      daysInMonth: dim,
      income: income,
      expense: expense,
      projectedExpense: proj,
      prevMonths: n,
      avgIncome: avgInc,
      avgExpense: avgExp,
      lastMonthExpense: lastMonth,
      topCategories: top.take(5).toList(),
      advice: advice,
    );
  }

  String _catName(String id) => categoryById(id)?.name ?? 'Tanpa kategori';

  void _savingAdvice(
      List<MonthAdvice> out, double income, double proj, bool isCurrent) {
    if (income <= 0) {
      if (proj > 0 && !isCurrent) {
        out.add(MonthAdvice(AdviceLevel.info, Icons.help_outline_rounded,
            'Belum ada pemasukan tercatat',
            'Catat gaji atau pemasukan lain bulan ini supaya porsi tabungan bisa dihitung.'));
      }
      return;
    }
    final net = income - proj;
    final rate = net / income;
    final t = savingTier(rate);
    final pct = (rate * 100).round();
    final when = isCurrent ? 'Dengan laju sekarang, akhir bulan' : 'Bulan ini';
    final ideal = niceRound(income * 0.8);
    final cut = niceRound(proj - income * 0.8);
    String body;
    IconData icon;
    switch (t.rank) {
      case 1:
      case 2:
        icon = Icons.trending_down_rounded;
        body = '$when keluar ${money(proj)}, masuk ${money(income)}. Selisih ${money(-net)} diambil dari tabungan. '
            'Bulan depan target maksimal ${money(income)}, idealnya ${money(ideal)} supaya bisa menabung 20%.';
      case 3:
        icon = Icons.savings_outlined;
        body = 'Baru $pct% pemasukan yang tersisa. Target sehat minimal 20% (aturan 50/30/20): kurangi sekitar ${money(cut)} per bulan, '
            'atau langsung sisihkan di awal bulan sebelum terpakai.';
      case 4:
        icon = Icons.savings_rounded;
        body = 'Sudah $pct%, sedikit lagi ke 20%. Kurangi sekitar ${money(cut)}, atau pindahkan ${money(niceRound(income * 0.2))} ke tabungan tepat setelah gajian.';
      case 5:
        icon = Icons.thumb_up_alt_rounded;
        body = 'Di atas target 20%. Pindahkan ${money(niceRound(net))} ke tabungan/target sekarang sebelum terpakai.';
      case 6:
        icon = Icons.celebration_rounded;
        body = 'Jauh di atas rata-rata orang. Sebagian (mis. ${money(niceRound(net / 2))}) bisa ke dana darurat atau target jangka panjang.';
      default:
        icon = Icons.emoji_events_rounded;
        body = 'Lebih dari separuh pemasukan berhasil disimpan. Pertahankan, dan pastikan tabungannya punya tujuan (dana darurat, target, investasi).';
    }
    out.add(MonthAdvice(
        t.level,
        icon,
        rate < 0
            ? '${t.label}: tekor ${money(-net)}'
            : '${t.label} · ${isCurrent ? 'perkiraan ' : ''}$pct% pemasukan ditabung',
        body));
  }

  void _trendAdvice(List<MonthAdvice> out, double proj, double avg, int n,
      bool isCurrent) {
    if (n == 0 || avg <= 0) return;
    final change = proj / avg - 1;
    final diff = proj - avg;
    final pre = isCurrent ? 'Perkiraan akhir bulan' : 'Bulan ini';
    if (change >= 0.20 && diff >= 200000) {
      out.add(MonthAdvice(
          AdviceLevel.warn,
          Icons.trending_up_rounded,
          'Pengeluaran naik ${(change * 100).round()}% dari biasanya',
          '$pre ${money(proj)}, rata-rata $n bulan sebelumnya ${money(avg)}. Lihat kategori yang naik di bawah.'));
    } else if (change <= -0.10 && -diff >= 100000) {
      out.add(MonthAdvice(
          AdviceLevel.good,
          Icons.trending_down_rounded,
          'Pengeluaran turun ${(-change * 100).round()}% dari biasanya 👏',
          'Hemat sekitar ${money(-diff)} dibanding rata-rata $n bulan sebelumnya.'));
    }
  }

  void _categoryAdvice(List<MonthAdvice> out, Map<String, double> cur,
      Map<String, double> prevSum, int n, double frac) {
    if (n == 0) return;
    final ups = <(String, double, double)>[];
    final downs = <(String, double, double)>[];
    final keys = {...cur.keys, ...prevSum.keys};
    for (final k in keys) {
      final c = (cur[k] ?? 0) / (frac > 0 ? frac : 1);
      final a = (prevSum[k] ?? 0) / n;
      if (a > 0 && c / a - 1 >= 0.30 && c - a >= 150000) ups.add((k, c, a));
      if (a > 0 && c / a - 1 <= -0.30 && a - c >= 150000) downs.add((k, c, a));
      if (a == 0 && c >= 300000) ups.add((k, c, a));
    }
    ups.sort((x, y) => (y.$2 - y.$3).compareTo(x.$2 - x.$3));
    downs.sort((x, y) => (y.$3 - y.$2).compareTo(x.$3 - x.$2));
    for (final (k, c, a) in ups.take(2)) {
      final tip = _categoryTip(k);
      out.add(MonthAdvice(
          AdviceLevel.warn,
          Icons.category_rounded,
          a == 0
              ? '${_catName(k)} ${money(c)} (biasanya tidak ada)'
              : '${_catName(k)} naik ${((c / a - 1) * 100).round()}% (${money(c)}, biasanya ${money(a)})',
          '${a > 0 ? 'Pasang anggaran kategori ${_catName(k)} sekitar ${money(niceRound(a))} di menu Anggaran.' : 'Kalau ini pengeluaran sekali saja, tidak apa; kalau rutin, masukkan ke anggaran.'}${tip.isEmpty ? '' : ' $tip'}'));
    }
    for (final (k, c, a) in downs.take(1)) {
      out.add(MonthAdvice(
          AdviceLevel.good,
          Icons.check_circle_rounded,
          '${_catName(k)} turun ${((1 - c / a) * 100).round()}% 👍',
          '${money(c)} dibanding biasanya ${money(a)}. Pertahankan.'));
    }
  }

  String _categoryTip(String catId) {
    final name = '${categoryById(catId)?.name ?? ''} $catId'.toLowerCase();
    bool has(List<String> w) => w.any(name.contains);
    if (has(['makan', 'minum', 'kebutuhan', 'cafe', 'kopi', 'food'])) {
      return 'Masak atau bawa bekal 3 kali seminggu biasanya menghemat cukup banyak.';
    }
    if (has(['transport', 'bensin', 'ojol', 'parkir'])) {
      return 'Gabungkan perjalanan, atau sesekali pakai transportasi umum.';
    }
    if (has(['shop', 'belanja', 'gaya hidup', 'hiburan', 'ent'])) {
      return 'Coba aturan tunggu 48 jam sebelum checkout barang yang tidak mendesak.';
    }
    if (has(['bill', 'tagihan', 'listrik', 'pulsa', 'kuota'])) {
      return 'Cek paket/tarif yang bisa diturunkan.';
    }
    return '';
  }

  void _smallSpendAdvice(
      List<MonthAdvice> out, DateTimeRange r, double expense) {
    if (expense <= 0) return;
    var count = 0;
    var total = 0.0;
    for (final t in transactions) {
      if (t.type != TxType.expense || !inRange(t.date, r)) continue;
      final v = amountIDR(t);
      if (v < 50000) {
        count++;
        total += v;
      }
    }
    if (count >= 15 && total >= expense * 0.10) {
      out.add(MonthAdvice(
          AdviceLevel.warn,
          Icons.local_cafe_rounded,
          'Jajan kecil $count kali, total ${money(total)}',
          'Transaksi di bawah Rp50 rb (${(total / expense * 100).round()}% pengeluaran). Kalau dikurangi setengahnya, hemat sekitar ${money(niceRound(total / 2))}.'));
    }
  }

  void _budgetAdvice(List<MonthAdvice> out, DateTimeRange r, double expense,
      double proj, double avgExp, int n, bool isCurrent) {
    final s = settings;
    if (s.globalBudget > 0 && s.budgetPeriod == BudgetPeriod.monthly) {
      final b = s.globalBudget;
      final used = isCurrent ? proj : expense;
      if (used > b) {
        out.add(MonthAdvice(
            AdviceLevel.bad,
            Icons.track_changes_rounded,
            '${isCurrent ? 'Anggaran bisa jebol' : 'Anggaran jebol'} ${money(used - b)}',
            '${isCurrent ? 'Perkiraan' : 'Terpakai'} ${money(used)} dari ${money(b)}. Kurangi kategori yang naik, atau sesuaikan anggaran supaya realistis.'));
      } else if (!isCurrent) {
        out.add(MonthAdvice(
            AdviceLevel.good,
            Icons.verified_rounded,
            'Anggaran terjaga, sisa ${money(b - used)} 👍',
            'Pindahkan sisanya ke tabungan supaya tidak terpakai bulan depan.'));
      }
    } else if (n > 0 && avgExp > 0) {
      out.add(MonthAdvice(
          AdviceLevel.info,
          Icons.track_changes_rounded,
          'Belum ada anggaran bulanan',
          'Dari $n bulan terakhir, anggaran yang realistis sekitar ${money(niceRound(avgExp))}. Pasang di Anggaran supaya "Aman dibelanjakan" ikut menjaga.'));
    }
  }

  void _emergencyAdvice(List<MonthAdvice> out, double monthlyExp) {
    if (monthlyExp <= 0) return;
    var liquid = 0.0;
    for (final a in accounts) {
      if (a.type == AccountType.bank ||
          a.type == AccountType.ewallet ||
          a.type == AccountType.cash) {
        if (a.id == kTalanganId) continue;
        liquid += toIDR(balanceOf(a.id), a.currency);
      }
    }
    final months = liquid / monthlyExp;
    final m1 = months.toStringAsFixed(1).replaceAll('.', ',');
    if (months < 3) {
      final target3 = niceRound(monthlyExp * 3);
      final perMonth = niceRound(math.max(0, target3 - liquid) / 12);
      out.add(MonthAdvice(
          months < 1 ? AdviceLevel.bad : AdviceLevel.warn,
          Icons.shield_rounded,
          'Dana darurat baru $m1 bulan pengeluaran',
          'Saldo kas, bank & tabungan ${money(liquid)}. Target aman 3–6 bulan: ${money(target3)}–${money(niceRound(monthlyExp * 6))}. '
              'Sisihkan sekitar ${money(perMonth)} per bulan di awal bulan (mis. lewat Target Tabungan) supaya tercapai dalam setahun.'));
    } else if (months >= 6) {
      out.add(MonthAdvice(AdviceLevel.good, Icons.shield_rounded,
          'Dana darurat aman ($m1 bulan) 💪',
          'Lebih dari 6 bulan pengeluaran. Kelebihannya bisa dipertimbangkan untuk tujuan lain.'));
    } else {
      out.add(MonthAdvice(AdviceLevel.good, Icons.shield_rounded,
          'Dana darurat cukup ($m1 bulan)',
          'Sudah di zona aman 3–6 bulan. Naikkan pelan-pelan ke 6 bulan.'));
    }
  }

  void _recurringAdvice(List<MonthAdvice> out, double income) {
    var monthly = 0.0;
    for (final r in recurring) {
      if (!r.active || r.type != TxType.expense) continue;
      final v = toIDR(r.amount, currencyOf(r.accountId));
      switch (r.frequency) {
        case Frequency.daily:
          monthly += v * 30;
        case Frequency.weekly:
          monthly += v * 52 / 12;
        case Frequency.monthly:
          monthly += v;
        case Frequency.yearly:
          monthly += v / 12;
      }
    }
    if (monthly <= 0 || income <= 0) return;
    final p = (monthly / income * 100).round();
    out.add(MonthAdvice(
        p > 30 ? AdviceLevel.warn : AdviceLevel.info,
        Icons.autorenew_rounded,
        'Tagihan & langganan rutin ${money(monthly)}/bulan ($p% pemasukan)',
        p > 30
            ? 'Cukup berat. Cek langganan atau tagihan yang bisa diturunkan atau dihentikan.'
            : 'Masih wajar. Sesekali cek langganan yang jarang dipakai.'));
  }

  void _debtAdvice(List<MonthAdvice> out, DateTime now) {
    final old = debts
        .where((d) =>
            d.theyOwe && !d.settled && now.difference(d.date).inDays >= 14)
        .toList();
    if (old.isNotEmpty) {
      final total = old.fold(0.0, (s, d) => s + d.remaining);
      final names = old.map((d) => d.person).toSet().take(3).join(', ');
      out.add(MonthAdvice(
          AdviceLevel.info,
          Icons.handshake_rounded,
          'Piutang belum kembali ${money(total)} ($names)',
          'Ada yang sudah lebih dari 2 minggu. Waktunya ditagih.'));
    }
    final end = DateTime(now.year, now.month + 1);
    final due = debts.where((d) {
      final dd = d.due;
      return !d.theyOwe && !d.settled && dd != null && dd.isBefore(end);
    }).toList();
    if (due.isNotEmpty) {
      final total = due.fold(0.0, (s, d) => s + d.remaining);
      out.add(MonthAdvice(
          AdviceLevel.warn,
          Icons.event_busy_rounded,
          'Utang jatuh tempo bulan ini ${money(total)}',
          'Siapkan dananya dulu sebelum belanja lain.'));
    }
  }
}

/// Kartu ringkas di Statistik (mode bulan).
class MonthAdviceCard extends StatelessWidget {
  const MonthAdviceCard({super.key, required this.store, required this.month});
  final AppStore store;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final r = store.monthRecap(month, DateTime.now());
    final fixes = r.advice.where((a) => !a.isPraise).length;
    final praise = r.advice.where((a) => a.isPraise).length;
    final tier = r.tier;
    return AppCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => MonthRecapPage(store: store, month: month))),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (tier == null ? C.blueDark : _tierColor(tier))
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(tier?.emoji ?? '📋',
                style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Rekap & saran ${DateFormat('MMMM', 'id_ID').format(r.month)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
                Text(
                    r.advice.isEmpty
                        ? 'Belum cukup data'
                        : '${tier == null ? '' : '${tier.label} · '}$fixes perlu diperbaiki · $praise sudah bagus',
                    style: TextStyle(fontSize: 12, color: C.muted)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: C.muted),
        ],
      ),
    );
  }
}

Color _tierColor(SavingTier t) {
  switch (t.level) {
    case AdviceLevel.bad:
      return C.redDark;
    case AdviceLevel.warn:
      return C.amberDark;
    case AdviceLevel.info:
      return C.blueDark;
    case AdviceLevel.good:
      return C.income;
  }
}

class MonthRecapPage extends StatefulWidget {
  const MonthRecapPage({super.key, required this.store, required this.month});
  final AppStore store;
  final DateTime month;

  @override
  State<MonthRecapPage> createState() => _MonthRecapPageState();
}

class _MonthRecapPageState extends State<MonthRecapPage> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.month.year, widget.month.month);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final now = DateTime.now();
    final r = store.monthRecap(_month, now);
    final hide = store.settings.hideBalance;
    String m(double v) => hide ? '••••' : money(v);
    final fixes = r.advice.where((a) => !a.isPraise).toList();
    final praise = r.advice.where((a) => a.isPraise).toList();
    final tier = r.tier;
    final isNow = _month.year == now.year && _month.month == now.month;

    Widget adviceTile(MonthAdvice a) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CatIcon(icon: a.icon, color: a.color, size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.title,
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: a.color)),
                      const SizedBox(height: 4),
                      Text(a.body,
                          style: TextStyle(
                              fontSize: 13, height: 1.4, color: C.carbon)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

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

    return Scaffold(
      appBar: pageBar('Rekap bulanan'),
      body: ListView(
        padding: pagePad(context, 32),
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Bulan sebelumnya',
                onPressed: () => setState(
                    () => _month = DateTime(_month.year, _month.month - 1)),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(DateFormat('MMMM yyyy', 'id_ID').format(_month),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16)),
              ),
              IconButton(
                tooltip: 'Bulan berikutnya',
                onPressed: isNow
                    ? null
                    : () => setState(() =>
                        _month = DateTime(_month.year, _month.month + 1)),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          if (r.isCurrent)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                  'Bulan berjalan (hari ke-${r.daysElapsed} dari ${r.daysInMonth}): angka pengeluaran dan saran memakai perkiraan dari laju sejauh ini.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: C.muted)),
            ),
          if (r.advice.isEmpty && r.income == 0 && r.expense == 0)
            const AppCard(
                child: EmptyState(
                    icon: Icons.insights_rounded,
                    title: 'Belum ada transaksi di bulan ini'))
          else ...[
            if (tier != null)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(tier.emoji, style: const TextStyle(fontSize: 30)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tier.label,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                      color: _tierColor(tier))),
                              Text(
                                  'Tingkat ${tier.rank} dari 7 · ${(r.savingRate! * 100).round()}% pemasukan ${r.savingRate! >= 0 ? 'tersisa' : 'tekor'}',
                                  style: TextStyle(
                                      fontSize: 12.5, color: C.muted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        children: [
                          for (var i = 1; i <= 7; i++)
                            Expanded(
                              child: Container(
                                height: 8,
                                margin: const EdgeInsets.only(right: 2),
                                color: i <= tier.rank
                                    ? _tierColor(tier)
                                    : C.line,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                stat('Pemasukan', m(r.income), C.income),
                const SizedBox(width: 10),
                stat(r.isCurrent ? 'Keluar (sejauh ini)' : 'Pengeluaran',
                    m(r.expense), C.redDark),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                stat(
                    'Bulan lalu',
                    r.lastMonthExpense == null ? '-' : m(r.lastMonthExpense!),
                    C.muted),
                const SizedBox(width: 10),
                stat(
                    r.prevMonths > 0
                        ? 'Rata-rata ${r.prevMonths} bln'
                        : 'Rata-rata',
                    r.prevMonths > 0 ? m(r.avgExpense) : '-',
                    C.blueDark),
              ],
            ),
            if (r.isCurrent && r.expense > 0) ...[
              const SizedBox(height: 6),
              Text('Perkiraan pengeluaran akhir bulan: ${m(r.projectedExpense)}',
                  style: TextStyle(fontSize: 12.5, color: C.muted)),
            ],
            const SizedBox(height: 16),
            if (fixes.isNotEmpty) ...[
              Text('Yang perlu diperbaiki (${fixes.length})',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 8),
              for (final a in fixes) adviceTile(a),
            ],
            if (praise.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Yang sudah bagus (${praise.length})',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 8),
              for (final a in praise) adviceTile(a),
            ],
            if (r.topCategories.isNotEmpty)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionTitle('Kategori terbesar'),
                    const SizedBox(height: 4),
                    for (final e in r.topCategories)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Expanded(
                                child: Text(
                                    store.categoryById(e.key)?.name ??
                                        'Tanpa kategori',
                                    style: const TextStyle(fontSize: 13.5))),
                            Text(m(e.value),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Text(
                'Saran dihitung otomatis dari datamu dengan aturan umum (50/30/20, dana darurat 3–6 bulan, dibanding rata-rata 3 bulan). Bukan nasihat keuangan profesional.',
                style: TextStyle(fontSize: 11.5, color: C.muted)),
          ],
        ],
      ),
    );
  }
}
