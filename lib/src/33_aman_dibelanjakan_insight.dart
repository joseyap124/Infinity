part of '../main.dart';

// =============================================================================
// AMAN DIBELANJAKAN HARI INI & INSIGHT (v1.9)
// =============================================================================

/// Hasil hitung "aman dibelanjakan hari ini".
class SafeSpend {
  const SafeSpend({
    required this.perDay,
    required this.spentToday,
    required this.daysLeft,
    required this.base,
    required this.fromBudget,
    required this.parts,
    required this.periodEnd,
    this.excluded = 0,
  });

  /// Saldo akun yang ditandai "jangan hitung" (dalam Rupiah).
  final double excluded;

  /// Jatah per hari mulai hari ini (belum dikurangi belanja hari ini).
  final double perDay;
  final double spentToday;
  final int daysLeft;

  /// Uang yang boleh dipakai sampai akhir periode (sebelum dibagi hari).
  final double base;

  /// true = dihitung dari anggaran, false = dari saldo akun harian.
  final bool fromBudget;

  /// Rincian: (keterangan, nominal; minus = mengurangi).
  final List<(String, double)> parts;
  final DateTime periodEnd;

  double get leftToday => perDay - spentToday;
  double get usedRatio =>
      perDay <= 0 ? (spentToday > 0 ? 1 : 0) : (spentToday / perDay).clamp(0.0, 1.0);
}

enum InsightKind { capture, recap, balance, projection, rates, event, debt, bill, subscription, unusual, goal, backup }

/// Saldo di notifikasi bank/e-wallet berbeda dengan hitungan Infinity.
class BalanceMismatch {
  const BalanceMismatch(this.accountId, this.reported, this.app, this.at);
  final String accountId;
  final double reported;
  final double app;
  final DateTime at;
  double get diff => reported - app;
}

class Insight {
  const Insight({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
    this.action,
    this.payload,
  });
  final String id;
  final InsightKind kind;
  final String title;
  final String body;
  final IconData icon;
  final Color color;
  final String? action;
  final Object? payload;
}

/// Langganan yang terdeteksi dari transaksi yang berulang tiap bulan.
class SubSuggestion {
  const SubSuggestion({
    required this.title,
    required this.amount,
    required this.day,
    required this.accountId,
    this.categoryId,
    required this.months,
  });
  final String title;
  final double amount;
  final int day;
  final String accountId;
  final String? categoryId;
  final int months;
}

String _subKey(String title) =>
    title.toLowerCase().replaceAll(RegExp(r'[^a-z ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

extension InsightStore on AppStore {
  /// Jadwal transaksi berulang yang belum tercatat, dari sekarang sampai [end].
  double upcomingRecurring(TxType type, DateTime now, DateTime end) {
    var sum = 0.0;
    for (final r in recurring) {
      if (!r.active || r.type != type) continue;
      for (var k = 0; k < 400; k++) {
        final d = occurrence(r.start, r.frequency, r.generated + k);
        if (!d.isBefore(end)) break;
        if (d.isAfter(now)) sum += toIDR(r.amount, currencyOf(r.accountId));
      }
    }
    return sum;
  }

  SafeSpend safeToSpend(DateTime now) {
    final today = dayOnly(now);
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final spentToday =
        sumIDR(TxType.expense, DateTimeRange(start: today, end: tomorrow));
    final parts = <(String, double)>[];
    double base;
    DateTime end;
    final s = settings;
    final fromBudget = s.globalBudget > 0;
    var skipped = 0.0;
    if (fromBudget) {
      final r = s.budgetPeriod.range(now);
      end = r.end;
      final spentBefore = r.start.isBefore(today)
          ? sumIDR(TxType.expense, DateTimeRange(start: r.start, end: today))
          : 0.0;
      parts.add(('Anggaran ${s.budgetPeriod.label.toLowerCase()}', s.globalBudget));
      parts.add(('Sudah terpakai sebelum hari ini', -spentBefore));
      base = s.globalBudget - spentBefore;
    } else {
      end = currentPeriod(now).end;
      var liquid = 0.0;
      for (final a in accounts) {
        if (a.type == AccountType.credit || a.type == AccountType.investment) {
          continue;
        }
        if (a.excludeSafe) {
          skipped += toIDR(balanceOf(a.id), a.currency);
          continue;
        }
        liquid += toIDR(balanceOf(a.id), a.currency);
      }
      // Belanja hari ini dikembalikan dulu supaya jatah hari ini tidak ikut
      // mengecil karena belanja hari ini sendiri.
      parts.add(('Saldo e-wallet, tunai & bank', liquid));
      if (spentToday > 0) parts.add(('Belanja hari ini (dihitung terpisah)', spentToday));
      base = liquid + spentToday;
      final inc = upcomingRecurring(TxType.income, now, end);
      if (inc > 0) {
        parts.add(('Pemasukan berulang sebelum akhir bulan', inc));
        base += inc;
      }
      var card = 0.0;
      for (final a in accounts.where((a) => a.type == AccountType.credit)) {
        final bal = balanceOf(a.id);
        if (bal < 0 && nextDueDate(a.dueDay, now).isBefore(end)) {
          card += toIDR(-bal, a.currency);
        }
      }
      if (card > 0) {
        parts.add(('Tagihan kartu kredit jatuh tempo', -card));
        base -= card;
      }
      var owe = 0.0;
      for (final d in debts) {
        final due = d.due;
        if (!d.theyOwe && !d.settled && due != null && due.isBefore(end)) {
          owe += d.remaining;
        }
      }
      if (owe > 0) {
        parts.add(('Utang jatuh tempo', -owe));
        base -= owe;
      }
      var save = 0.0;
      for (final g in goals) {
        save += goalPerMonth(g, now) ?? 0;
      }
      if (save > 0) {
        parts.add(('Setoran target tabungan bulan ini', -save));
        base -= save;
      }
    }
    final upExp = upcomingRecurring(TxType.expense, now, end);
    if (upExp > 0) {
      parts.add(('Tagihan & langganan berulang', -upExp));
      base -= upExp;
    }
    final daysLeft = math.max(1, end.difference(today).inDays);
    final perDay = math.max(0.0, base) / daysLeft;
    return SafeSpend(
      perDay: perDay,
      spentToday: spentToday,
      daysLeft: daysLeft,
      base: base,
      fromBudget: fromBudget,
      parts: parts,
      periodEnd: end,
      excluded: fromBudget ? 0 : skipped,
    );
  }

  /// Pengeluaran dengan catatan yang sama muncul >= 3 bulan berbeda dalam
  /// 4 bulan terakhir, nominal mirip (±15%), dan belum jadi transaksi berulang.
  List<SubSuggestion> detectSubscriptions(DateTime now) {
    final since = DateTime(now.year, now.month - 4, now.day);
    final groups = <String, List<Transaction>>{};
    for (final t in transactions) {
      if (t.type != TxType.expense || t.recurringId != null) continue;
      if (t.date.isBefore(since)) continue;
      final k = _subKey(t.title);
      if (k.length < 3) continue;
      groups.putIfAbsent(k, () => []).add(t);
    }
    final existing = recurring.map((r) => _subKey(r.title)).toSet();
    final dismissed = settings.dismissedSubs.toSet();
    final out = <SubSuggestion>[];
    groups.forEach((k, list) {
      if (existing.contains(k) || dismissed.contains(k)) return;
      final months = list.map((t) => t.date.year * 12 + t.date.month).toSet();
      if (months.length < 3) return;
      final amounts = list.map(amountIDR).toList()..sort();
      final median = amounts[amounts.length ~/ 2];
      if (median <= 0) return;
      if (amounts.any((a) => (a - median).abs() > median * 0.15)) return;
      list.sort((a, b) => b.date.compareTo(a.date));
      final last = list.first;
      out.add(SubSuggestion(
        title: last.title,
        amount: median,
        day: last.date.day,
        accountId: last.accountId,
        categoryId: last.categoryId,
        months: months.length,
      ));
    });
    out.sort((a, b) => b.amount.compareTo(a.amount));
    return out;
  }

  /// Jadikan langganan terdeteksi sebagai transaksi berulang bulanan.
  void acceptSubscription(SubSuggestion s, DateTime now) {
    var start = DateTime(now.year, now.month, s.day, 9);
    if (!start.isAfter(now)) start = DateTime(now.year, now.month + 1, s.day, 9);
    recurring.add(RecurringRule(
      id: newId(),
      title: s.title,
      amount: s.amount,
      type: TxType.expense,
      categoryId: s.categoryId,
      accountId: accountById(s.accountId) != null ? s.accountId : accounts.first.id,
      frequency: Frequency.monthly,
      start: start,
    ));
    _commit();
  }

  void dismissSubscription(String title) {
    settings.dismissedSubs = [...settings.dismissedSubs, _subKey(title)];
    _commit();
  }

  /// Saldo akun menurut Infinity pada waktu [at] (transaksi sampai 1 menit
  /// setelahnya ikut dihitung, karena notifikasi transaksi dan saldo bisa
  /// datang berselisih beberapa detik).
  double balanceAsOf(String accountId, DateTime at) {
    final acc = accountById(accountId);
    if (acc == null) return 0;
    final limit = at.add(const Duration(minutes: 1));
    var b = acc.initialBalance;
    for (final t in transactions) {
      if (t.date.isAfter(limit)) continue;
      switch (t.type) {
        case TxType.income:
          if (t.accountId == accountId) b += t.amount;
        case TxType.expense:
          if (t.accountId == accountId) b -= t.amount;
        case TxType.transfer:
          if (t.accountId == accountId) b -= t.amount;
          if (t.toAccountId == accountId) b += t.receivedAmount;
      }
    }
    return b;
  }

  /// Akun yang saldonya di notifikasi beda dengan di Infinity. Dilewati kalau
  /// masih ada notifikasi akun itu yang menunggu dicek (bisa jadi itu
  /// penyebabnya), atau saldo sudah diubah manual setelah notifikasi.
  List<BalanceMismatch> balanceMismatches() {
    final out = <BalanceMismatch>[];
    settings.reportedBalance.forEach((accId, v) {
      final acc = accountById(accId);
      if (acc == null) return;
      final parts = v.split('|');
      if (parts.length != 2) return;
      final reported = double.tryParse(parts[0]);
      final at = DateTime.tryParse(parts[1]);
      if (reported == null || at == null) return;
      final setAt = DateTime.tryParse(settings.balanceSetAt[accId] ?? '');
      if (setAt != null && setAt.isAfter(at)) return;
      final waiting = pendingCaptures.any((c) {
        if (c.time.isAfter(at.add(const Duration(minutes: 1)))) return false;
        final p = parseReceipt(c.fullText, this);
        final a = p.accountId ?? accountForPackage(c.pkg);
        return a == accId || (p.isTopUp && a == null);
      });
      if (waiting) return;
      final app = balanceAsOf(accId, at);
      if ((reported - app).abs() >= 1) {
        out.add(BalanceMismatch(accId, reported, app, at));
      }
    });
    return out;
  }

  /// Samakan saldo dengan notifikasi: transaksi penyesuaian pada waktu
  /// notifikasi, jadi transaksi sesudahnya tetap dihitung.
  void reconcileBalance(BalanceMismatch m) {
    final acc = accountById(m.accountId);
    if (acc == null || m.diff.abs() < 0.0005) return;
    final type = m.diff > 0 ? TxType.income : TxType.expense;
    transactions.add(Transaction(
      id: newId(),
      title: 'Penyesuaian saldo',
      amount: m.diff.abs(),
      type: type,
      categoryId: fallbackCategory(type),
      accountId: acc.id,
      date: m.at,
      note: 'Disamakan dengan saldo di notifikasi',
    ));
    settings.balanceSetAt = {
      ...settings.balanceSetAt,
      acc.id: m.at.toIso8601String(),
    };
    _commit();
  }

  void ignoreReportedBalance(String accountId) {
    settings.reportedBalance = {...settings.reportedBalance}..remove(accountId);
    _commit();
  }

  void dismissInsight(String id) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    settings.dismissedInsights = {...settings.dismissedInsights, id: today};
    _commit();
  }

  /// Kategori induk yang 7 hari terakhir > 2x rata-rata mingguan 8 minggu
  /// sebelumnya (dan selisihnya minimal Rp50.000).
  List<(String, double, double)> unusualSpending(DateTime now) {
    final end = DateTime(now.year, now.month, now.day + 1);
    final weekStart = end.subtract(const Duration(days: 7));
    final histStart = weekStart.subtract(const Duration(days: 56));
    final week = <String, double>{}, hist = <String, double>{};
    for (final t in transactions) {
      if (t.type != TxType.expense) continue;
      if (t.recurringId != null) continue;
      for (final (cid, v) in categoryParts(t)) {
        if (cid == null) continue;
        final top = topCategoryId(cid);
        if (!t.date.isBefore(weekStart) && t.date.isBefore(end)) {
          week[top] = (week[top] ?? 0) + v;
        } else if (!t.date.isBefore(histStart) && t.date.isBefore(weekStart)) {
          hist[top] = (hist[top] ?? 0) + v;
        }
      }
    }
    final out = <(String, double, double)>[];
    week.forEach((cat, w) {
      final avg = (hist[cat] ?? 0) / 8;
      if (avg > 0 && w > avg * 2 && w - avg >= 50000) out.add((cat, w, avg));
    });
    out.sort((a, b) => (b.$2 - b.$3).compareTo(a.$2 - a.$3));
    return out;
  }

  List<Insight> insights(DateTime now) {
    final out = <Insight>[];
    final today = dayOnly(now);
    final todayKey = DateFormat('yyyy-MM-dd').format(now);
    bool hidden(String id) => settings.dismissedInsights[id] == todayKey;
    final df = DateFormat('d MMM', 'id_ID');
    final tf = DateFormat('d MMM HH:mm', 'id_ID');

    // Penyimpanan gagal: paling penting, tampil paling atas.
    if (!lastSaveOk) {
      out.add(Insight(
        id: 'save_fail',
        kind: InsightKind.backup,
        title: 'Perubahan terakhir gagal disimpan',
        body: 'Jangan tutup app dulu. Buat backup sekarang, lalu cek Laporan error.',
        icon: Icons.error_rounded,
        color: C.redDark,
        action: 'Backup',
      ));
    }
    // Antrean "Perlu dicek" hampir penuh.
    if (pendingCaptures.length >= kMaxPendingCaptures - 60 && !hidden('pend_full')) {
      out.add(Insight(
        id: 'pend_full',
        kind: InsightKind.capture,
        title: '${pendingCaptures.length} notifikasi menunggu dicek',
        body: 'Batasnya $kMaxPendingCaptures. Kalau lewat, yang paling lama terbuang. Cek atau abaikan sebagian.',
        icon: Icons.inbox_rounded,
        color: C.amberDark,
        action: 'Cek',
      ));
    }
    // Salinan backup ke luar HP (Google Drive) sudah lama.
    if (transactions.length >= 10 && !hidden('drive')) {
      final lastDrive = settings.lastDriveSave;
      final firstTx = transactions
          .map((t) => t.date)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      final days = lastDrive == null
          ? now.difference(firstTx).inDays
          : now.difference(lastDrive).inDays;
      if (days > 7) {
        out.add(Insight(
          id: 'drive',
          kind: InsightKind.backup,
          title: lastDrive == null
              ? 'Belum ada salinan backup di luar HP'
              : 'Salinan backup di Drive sudah $days hari',
          body: 'Kalau HP hilang atau rusak, data hanya bisa kembali dari salinan di luar HP. Simpan ke Google Drive, cukup seminggu sekali.',
          icon: Icons.add_to_drive_rounded,
          color: C.blueDark,
          action: 'Simpan',
        ));
      }
    }
    for (final m in balanceMismatches()) {
      final acc = accountById(m.accountId)!;
      out.add(Insight(
        id: 'bal_${m.accountId}',
        kind: InsightKind.balance,
        title: 'Saldo ${acc.name} beda ${money(m.diff.abs(), acc.currency)}',
        body: 'Menurut notifikasi (${tf.format(m.at)}) ${money(m.reported, acc.currency)}, '
            'di Infinity ${money(m.app, acc.currency)}. Ada transaksi yang belum dicatat?',
        icon: Icons.account_balance_wallet_rounded,
        color: C.amberDark,
        action: 'Samakan',
        payload: m,
      ));
    }
    // Awal bulan: rekap bulan lalu sudah siap.
    final curStart = currentPeriod(now).start;
    if (dayOnly(now).difference(curStart).inDays < 7) {
      final cur = periodLabelOf(now);
      final last = DateTime(cur.year, cur.month - 1);
      final id = 'recap_${last.year}_${last.month}';
      if (!hidden(id) &&
          transactions.any((t) =>
              t.type != TxType.transfer && inRange(t.date, periodRange(last)))) {
        final rc = monthRecap(last, now);
        final tier = rc.tier;
        final fixes = rc.advice.where((a) => !a.isPraise).length;
        out.add(Insight(
          id: id,
          kind: InsightKind.recap,
          title:
              'Rekap ${DateFormat('MMMM', 'id_ID').format(last)} siap ${tier?.emoji ?? '📋'}',
          body:
              '${tier == null ? '' : '${tier.label}. '}$fixes hal yang bisa diperbaiki bulan ini.',
          icon: Icons.fact_check_rounded,
          color: C.accentDark,
          action: 'Lihat',
          payload: last,
        ));
      }
    }
    for (final a in accounts) {
      if (a.type == AccountType.credit || a.id == kTalanganId) continue;
      final items = upcomingForAccount(a.id, now);
      if (items.isEmpty) continue;
      final proj = projectedMonthEnd(a.id, now);
      if (proj >= 0) continue;
      final id = 'proj_${a.id}_${now.month}';
      if (hidden(id)) continue;
      out.add(Insight(
        id: id,
        kind: InsightKind.projection,
        title: 'Saldo ${a.name} bisa minus',
        body: 'Perkiraan akhir bulan ${money(proj, a.currency)} setelah ${items.length} tagihan/transfer berulang. Isi saldonya dulu.',
        icon: Icons.warning_amber_rounded,
        color: C.redDark,
        action: 'Lihat',
        payload: a,
      ));
    }
    final stale = staleRatesDays(now);
    if (stale != null && !hidden('rates')) {
      out.add(Insight(
        id: 'rates',
        kind: InsightKind.rates,
        title: 'Kurs mata uang sudah lama',
        body: stale < 0
            ? 'Kurs belum pernah diperbarui, jadi total saldo akun asing bisa meleset.'
            : 'Terakhir diperbarui $stale hari lalu. Cek kurs terbaru supaya total saldo akurat.',
        icon: Icons.currency_exchange_rounded,
        color: C.amberDark,
        action: 'Perbarui',
      ));
    }
    for (final e in events) {
      if (e.budget <= 0 || !e.ongoing(now)) continue;
      final spent = eventSpent(e.id);
      if (spent < e.budget * 0.8) continue;
      final id = 'event_${e.id}_${spent >= e.budget ? 'over' : '80'}';
      if (hidden(id)) continue;
      out.add(Insight(
        id: id,
        kind: InsightKind.event,
        title: spent >= e.budget
            ? '${e.name}: lewat anggaran'
            : '${e.name}: anggaran tinggal ${money(e.budget - spent)}',
        body: 'Terpakai ${money(spent)} dari ${money(e.budget)} (${(spent / e.budget * 100).round()}%).',
        icon: Icons.local_activity_rounded,
        color: spent >= e.budget ? C.redDark : C.amberDark,
        action: 'Lihat',
        payload: e,
      ));
    }
    for (final d in debts) {
      final due = d.due;
      if (d.settled || due == null) continue;
      final days = dayOnly(due).difference(today).inDays;
      if (days > 3) continue;
      final id = 'debt_${d.id}';
      if (hidden(id)) continue;
      out.add(Insight(
        id: id,
        kind: InsightKind.debt,
        title: d.theyOwe ? '${d.person} janji bayar ${money(d.remaining)}' : 'Bayar utang ke ${d.person}',
        body: days < 0
            ? 'Lewat tenggat ${-days} hari (${df.format(due)}).'
            : days == 0
                ? 'Tenggat hari ini.'
                : 'Tenggat $days hari lagi (${df.format(due)}).',
        icon: Icons.handshake_rounded,
        color: days < 0 ? C.redDark : C.amberDark,
        action: 'Lihat',
        payload: d,
      ));
    }
    for (final r in recurring) {
      if (!r.active || r.type != TxType.expense) continue;
      final next = r.nextDate;
      final days = dayOnly(next).difference(today).inDays;
      if (days < 0 || days > 3) continue;
      final id = 'bill_${r.id}_${next.millisecondsSinceEpoch}';
      if (hidden(id)) continue;
      out.add(Insight(
        id: id,
        kind: InsightKind.bill,
        title: '${r.title} ${money(r.amount, currencyOf(r.accountId))}',
        body: days == 0 ? 'Jatuh tempo hari ini.' : 'Jatuh tempo $days hari lagi (${df.format(next)}).',
        icon: Icons.event_repeat_rounded,
        color: C.blueDark,
      ));
    }
    for (final a in accounts.where((a) => a.type == AccountType.credit)) {
      final bal = balanceOf(a.id);
      if (bal >= 0) continue;
      final due = nextDueDate(a.dueDay, now);
      final days = due.difference(today).inDays;
      if (days > 3) continue;
      final id = 'cc_${a.id}_${due.millisecondsSinceEpoch}';
      if (hidden(id)) continue;
      out.add(Insight(
        id: id,
        kind: InsightKind.bill,
        title: 'Tagihan ${a.name} ${money(-bal, a.currency)}',
        body: days == 0 ? 'Jatuh tempo hari ini.' : 'Jatuh tempo $days hari lagi.',
        icon: Icons.credit_card_rounded,
        color: C.redDark,
      ));
    }
    for (final (cat, w, avg) in unusualSpending(now).take(2)) {
      final id = 'unusual_$cat';
      if (hidden(id)) continue;
      final name = categoryById(cat)?.name ?? 'Pengeluaran';
      out.add(Insight(
        id: id,
        kind: InsightKind.unusual,
        title: '$name lagi tinggi',
        body: '7 hari terakhir ${money(w)}, biasanya ±${money(avg)} per minggu (${(w / avg).toStringAsFixed(1)}×).',
        icon: Icons.trending_up_rounded,
        color: C.redDark,
      ));
    }
    for (final s in detectSubscriptions(now).take(2)) {
      out.add(Insight(
        id: 'sub_${_subKey(s.title)}',
        kind: InsightKind.subscription,
        title: 'Langganan? ${s.title}',
        body: '±${money(s.amount)} muncul ${s.months} bulan berturut. Jadikan transaksi berulang tiap tgl ${s.day}?',
        icon: Icons.autorenew_rounded,
        color: C.accentDark,
        action: 'Jadikan berulang',
        payload: s,
      ));
    }
    for (final g in goals) {
      final d = g.deadline;
      if (d == null || goalProgress(g) >= g.target) continue;
      final days = dayOnly(d).difference(today).inDays;
      if (days > 30) continue;
      final id = 'goal_${g.id}';
      if (hidden(id)) continue;
      out.add(Insight(
        id: id,
        kind: InsightKind.goal,
        title: 'Target "${g.name}" tinggal $days hari',
        body: 'Kurang ${money(g.target - goalProgress(g))}.',
        icon: Icons.savings_rounded,
        color: Color(g.color),
        action: 'Lihat',
      ));
    }
    return out;
  }
}

/// Kartu utama Beranda: angka yang paling sering dibutuhkan saat app dibuka.
class SafeSpendCard extends StatelessWidget {
  const SafeSpendCard({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final s = store.safeToSpend(DateTime.now());
    final hide = store.settings.hideBalance;
    final left = s.leftToday;
    final over = left < 0;
    final color = over ? C.redDark : (s.usedRatio > 0.8 ? C.amberDark : C.income);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => showSheet<void>(context, SafeSpendSheet(store: store)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 58,
              height: 58,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 58,
                    height: 58,
                    child: CircularProgressIndicator(
                      value: s.usedRatio,
                      strokeWidth: 6,
                      strokeCap: StrokeCap.round,
                      backgroundColor: color.withValues(alpha: 0.15),
                      color: color,
                    ),
                  ),
                  Icon(over ? Icons.warning_amber_rounded : Icons.wallet_rounded,
                      color: color, size: 24),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(over ? 'Lewat jatah hari ini' : 'Aman dibelanjakan hari ini',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: C.muted)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                        hide ? 'Rp ••••••' : money(over ? -left : left),
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: over ? C.redDark : C.carbon)),
                  ),
                  Text(
                      hide
                          ? 'Ketuk untuk rincian'
                          : 'Jatah ${money(s.perDay)}/hari · ${s.daysLeft} hari lagi${s.spentToday > 0 ? ' · keluar hari ini ${money(s.spentToday)}' : ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: C.muted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: C.muted),
          ],
        ),
      ),
    );
  }
}

class SafeSpendSheet extends StatelessWidget {
  const SafeSpendSheet({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final s = store.safeToSpend(DateTime.now());
    final df = DateFormat('d MMM', 'id_ID');
    Widget line(String label, double v, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 13.5,
                          color: bold ? C.carbon : C.muted,
                          fontWeight: bold ? FontWeight.w800 : FontWeight.w400))),
              Text('${v < 0 ? '−' : ''}${money(v.abs())}',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
                      color: v < 0 ? C.redDark : C.carbon)),
            ],
          ),
        );
    return SheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Dari mana angka ini?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ),
              IconButton(
                tooltip: 'Tutup',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          Text(
              s.fromBudget
                  ? 'Dihitung dari anggaranmu sampai ${df.format(s.periodEnd.subtract(const Duration(days: 1)))}.'
                  : 'Dihitung dari saldo e-wallet, tunai & bank sampai akhir bulan. Atur anggaran bulanan supaya angkanya lebih pas dengan rencanamu.',
              style: TextStyle(fontSize: 12.5, color: C.muted)),
          const SizedBox(height: 10),
          for (final (label, v) in s.parts) line(label, v),
          if (s.excluded != 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                  'Tidak dihitung: ${money(s.excluded)} di akun yang ditandai "jangan hitung" (tabungan/dana darurat).',
                  style: TextStyle(fontSize: 12, color: C.muted)),
            ),
          Divider(color: C.line),
          line('Boleh dipakai sampai akhir periode', s.base, bold: true),
          line('Dibagi ${s.daysLeft} hari (termasuk hari ini)', s.perDay, bold: true),
          line('Sudah keluar hari ini', -s.spentToday),
          Divider(color: C.line),
          line(s.leftToday < 0 ? 'Lewat jatah hari ini' : 'Sisa jatah hari ini', s.leftToday, bold: true),
          const SizedBox(height: 10),
          Text(
              'Kalau hari ini hemat, jatah besok naik. Kalau boros, jatah hari-hari berikutnya otomatis mengecil.',
              style: TextStyle(fontSize: 12, color: C.muted)),
          if (!s.fromBudget) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => BudgetPage(store: store)));
              },
              icon: const Icon(Icons.track_changes_rounded),
              label: const Text('Atur anggaran bulanan'),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20))),
            ),
          ],
        ],
      ),
    );
  }
}

/// Deretan kartu "Perlu perhatian" di Beranda (geser ke samping).
/// Insight yang mendesak/harian (tampil di Beranda).
const Set<InsightKind> kHomeInsights = {
  InsightKind.backup,
  InsightKind.capture,
  InsightKind.balance,
  InsightKind.bill,
  InsightKind.recap,
  InsightKind.rates,
  InsightKind.unusual,
};

/// Insight soal rencana (tampil di tab Rencana).
const Set<InsightKind> kPlanInsights = {
  InsightKind.subscription,
  InsightKind.projection,
  InsightKind.goal,
  InsightKind.debt,
  InsightKind.event,
  InsightKind.bill,
};

class InsightStrip extends StatelessWidget {
  const InsightStrip({
    super.key,
    required this.store,
    required this.onOpenCaptures,
    this.kinds,
    this.title = 'Perlu perhatian',
  });
  final AppStore store;
  final VoidCallback onOpenCaptures;

  /// Jenis insight yang ditampilkan (null = semua).
  final Set<InsightKind>? kinds;
  final String title;

  void _act(BuildContext context, Insight i) {
    switch (i.kind) {
      case InsightKind.capture:
        onOpenCaptures();
      case InsightKind.recap:
        final m = i.payload;
        if (m is DateTime) {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => MonthRecapPage(store: store, month: m)));
        }
      case InsightKind.projection:
        final a = i.payload;
        if (a is Account) openAccountHistory(context, store, a);
      case InsightKind.event:
        final e = i.payload;
        if (e is TxEvent) {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => EventDetailPage(store: store, eventId: e.id)));
        }
      case InsightKind.rates:
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => CurrencyPage(store: store)));
      case InsightKind.balance:
        final m = i.payload;
        if (m is BalanceMismatch) _confirmReconcile(context, m);
      case InsightKind.debt:
        final d = i.payload;
        if (d is Debt) {
          showSheet<void>(context, DebtDetailSheet(store: store, debt: d));
        }
      case InsightKind.subscription:
        final s = i.payload;
        if (s is SubSuggestion) {
          store.acceptSubscription(s, DateTime.now());
          snack(context, '${s.title} dijadikan transaksi berulang 🔁');
        }
      case InsightKind.goal:
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => GoalsPage(store: store)));
      case InsightKind.backup:
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => BackupPage(store: store)));
      case InsightKind.bill:
      case InsightKind.unusual:
        break;
    }
  }

  Future<void> _confirmReconcile(BuildContext context, BalanceMismatch m) async {
    final acc = store.accountById(m.accountId);
    if (acc == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Samakan saldo ${acc.name}?'),
        content: Text(
            'Infinity akan mencatat penyesuaian ${m.diff > 0 ? '+' : '-'}${money(m.diff.abs(), acc.currency)} '
            'pada waktu notifikasi, supaya saldo saat itu jadi ${money(m.reported, acc.currency)}. '
            'Kalau selisihnya karena transaksi yang lupa dicatat, lebih baik catat transaksinya saja.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Samakan')),
        ],
      ),
    );
    if (ok == true) {
      store.reconcileBalance(m);
      if (context.mounted) snack(context, 'Saldo ${acc.name} sudah disamakan');
    }
  }

  void _dismiss(Insight i) {
    final s = i.payload;
    final m = i.payload;
    if (i.kind == InsightKind.balance && m is BalanceMismatch) {
      store.ignoreReportedBalance(m.accountId);
      return;
    }
    if (i.kind == InsightKind.subscription && s is SubSuggestion) {
      store.dismissSubscription(s.title);
    } else {
      store.dismissInsight(i.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = kinds;
    final list = store
        .insights(DateTime.now())
        .where((i) => k == null || k.contains(i.kind))
        .toList();
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text('$title (${list.length})',
              style: TextStyle(fontWeight: FontWeight.w800, color: C.carbon)),
        ),
        SizedBox(
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, k) {
              final i = list[k];
              return Container(
                width: 262,
                padding: const EdgeInsets.fromLTRB(12, 10, 6, 8),
                decoration: BoxDecoration(
                  color: C.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: i.color.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(i.icon, color: i.color, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(i.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                  color: C.carbon)),
                        ),
                        if (i.kind != InsightKind.capture)
                          InkWell(
                            onTap: () => _dismiss(i),
                            customBorder: const CircleBorder(),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(Icons.close_rounded,
                                  size: 16, color: C.muted),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(i.body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: C.muted, height: 1.3)),
                    ),
                    if (i.action != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _act(context, i),
                          style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: i.color),
                          child: Text(i.action!,
                              style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
