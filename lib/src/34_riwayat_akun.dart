part of '../main.dart';

// =============================================================================
// RIWAYAT PER AKUN (ketuk SeaBank, BCA, dll. untuk melihat transaksinya)
// =============================================================================

extension AccountLedger on AppStore {
  /// Perubahan saldo akun karena satu transaksi (dalam mata uang akun).
  double accountDelta(Transaction t, String accountId) {
    switch (t.type) {
      case TxType.income:
        return t.accountId == accountId ? t.amount : 0;
      case TxType.expense:
        return t.accountId == accountId ? -t.amount : 0;
      case TxType.transfer:
        var d = 0.0;
        if (t.accountId == accountId) d -= t.amount;
        if (t.toAccountId == accountId) d += t.receivedAmount;
        return d;
    }
  }

  /// Semua transaksi akun, urut dari yang terlama, beserta saldo setelahnya
  /// (seperti buku tabungan / tampilan akun di Money Manager).
  List<(Transaction, double)> accountLedger(String accountId) {
    final acc = accountById(accountId);
    if (acc == null) return const [];
    final list = transactions
        .where((t) => t.accountId == accountId || t.toAccountId == accountId)
        .toList()
      ..sort((a, b) {
        final c = a.date.compareTo(b.date);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    var bal = acc.initialBalance;
    final out = <(Transaction, double)>[];
    for (final t in list) {
      bal += accountDelta(t, accountId);
      out.add((t, bal));
    }
    return out;
  }

  /// Transaksi berulang yang belum tercatat dari [now] sampai akhir bulan,
  /// dilihat dari sisi akun: (tanggal, judul, perubahan saldo).
  List<(DateTime, String, double)> upcomingForAccount(
      String accountId, DateTime now) {
    final end = DateTime(now.year, now.month + 1);
    final out = <(DateTime, String, double)>[];
    for (final r in recurring) {
      if (!r.active) continue;
      double delta;
      switch (r.type) {
        case TxType.income:
          delta = r.accountId == accountId ? r.amount : 0;
        case TxType.expense:
          delta = r.accountId == accountId ? -r.amount : 0;
        case TxType.transfer:
          delta = 0;
          if (r.accountId == accountId) delta -= r.amount;
          if (r.toAccountId == accountId) delta += r.toAmount ?? r.amount;
      }
      if (delta == 0) continue;
      for (var k = 0; k < 400; k++) {
        final d = occurrence(r.start, r.frequency, r.generated + k);
        if (!d.isBefore(end)) break;
        if (d.isAfter(now)) out.add((d, r.title, delta));
      }
    }
    out.sort((a, b) => a.$1.compareTo(b.$1));
    return out;
  }

  /// Perkiraan saldo akhir bulan = saldo sekarang + jadwal berulang.
  double projectedMonthEnd(String accountId, DateTime now) =>
      balanceOf(accountId) +
      upcomingForAccount(accountId, now).fold(0.0, (s, e) => s + e.$3);
}

void openAccountHistory(BuildContext context, AppStore store, Account a) {
  Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AccountHistoryPage(store: store, accountId: a.id)));
}

class AccountHistoryPage extends StatefulWidget {
  const AccountHistoryPage(
      {super.key, required this.store, required this.accountId});
  final AppStore store;
  final String accountId;

  @override
  State<AccountHistoryPage> createState() => _AccountHistoryPageState();
}

class _AccountHistoryPageState extends State<AccountHistoryPage> {
  AppStore get store => widget.store;
  late DateTime _month;

  /// true = tampilkan seluruh riwayat, bukan per bulan.
  bool _all = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  void _shift(int months) =>
      setState(() => _month = DateTime(_month.year, _month.month + months));

  /// Pilih bulan langsung (bulan yang ada transaksinya) atau "Semua".
  Future<void> _pickMonth(List<(Transaction, double)> ledger) async {
    final now = DateTime.now();
    final counts = <DateTime, int>{};
    for (final (t, _) in ledger) {
      final m = DateTime(t.date.year, t.date.month);
      counts[m] = (counts[m] ?? 0) + 1;
    }
    counts.putIfAbsent(DateTime(now.year, now.month), () => 0);
    final months = counts.keys.toList()..sort((a, b) => b.compareTo(a));
    final fmt = DateFormat('MMMM yyyy', 'id_ID');
    final picked = await showSheet<DateTime>(
      context,
      SheetFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Pilih bulan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ),

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.all_inclusive_rounded),
                title: const Text('Semua',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                trailing: Text('${ledger.length} transaksi',
                    style: TextStyle(color: C.muted, fontSize: 12.5)),
                selected: _all,
                onTap: () => Navigator.pop(context, DateTime(0)),
              ),
              for (final m in months)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month_rounded),
                  title: Text(fmt.format(m)),
                  trailing: Text('${counts[m]} transaksi',
                      style: TextStyle(color: C.muted, fontSize: 12.5)),
                  selected: !_all && m == _month,
                  onTap: () => Navigator.pop(context, m),
                ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (picked.year == 0) {
        _all = true;
      } else {
        _all = false;
        _month = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final a = store.accountById(widget.accountId);
        if (a == null) {
          return Scaffold(
              appBar: pageBar('Riwayat'),
              body: const Center(child: Text('Akun sudah dihapus.')));
        }
        final hide = store.settings.hideBalance;
        final ledger = store.accountLedger(a.id);
        final next = DateTime(_month.year, _month.month + 1);
        final inMonth = [
          for (final e in ledger)
            if (_all ||
                (!e.$1.date.isBefore(_month) && e.$1.date.isBefore(next)))
              e
        ].reversed.toList();
        var inSum = 0.0, outSum = 0.0;
        for (final (t, _) in inMonth) {
          final d = store.accountDelta(t, a.id);
          if (d >= 0) {
            inSum += d;
          } else {
            outSum -= d;
          }
        }
        final bal = store.balanceOf(a.id);
        String m(double v) => hide ? '••••' : money(v, a.currency);

        // Kelompokkan per hari, terbaru di atas.
        final days = <DateTime, List<(Transaction, double)>>{};
        for (final e in inMonth) {
          days.putIfAbsent(dayOnly(e.$1.date), () => []).add(e);
        }
        final now = DateTime.now();
        final isCurrent = _month.year == now.year && _month.month == now.month;

        return Scaffold(
          appBar: pageBar(a.name, actions: [
            IconButton(
              tooltip: 'Edit akun',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showSheet<void>(
                  context, AccountEditorSheet(store: store, account: a)),
            ),
          ]),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => openTxForm(context, store,
                prefill: TxDraft(type: TxType.expense, accountId: a.id)),
            backgroundColor: C.accentDark,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Catat'),
          ),
          body: ListView(
            padding: pagePad(context, 100),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CatIcon(icon: a.type.icon, color: a.colorValue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Saldo sekarang',
                                  style:
                                      TextStyle(fontSize: 12.5, color: C.muted)),
                              Text(m(bal),
                                  style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: bal < 0 ? C.redDark : C.carbon)),
                              if (a.currency != 'IDR' && !hide)
                                Text('≈ ${money(store.toIDR(bal, a.currency))}',
                                    style: TextStyle(
                                        fontSize: 12, color: C.muted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (!_all && isCurrent) _projection(context, a),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Bulan sebelumnya',
                          onPressed: _all ? null : () => _shift(-1),
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _pickMonth(ledger),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                      _all
                                          ? 'Semua transaksi'
                                          : DateFormat('MMMM yyyy', 'id_ID')
                                              .format(_month),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(width: 4),
                                  Icon(Icons.expand_more_rounded,
                                      size: 20, color: C.muted),
                                ],
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Bulan berikutnya',
                          onPressed:
                              (_all || isCurrent) ? null : () => _shift(1),
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                            child: _stat('Masuk', m(inSum), C.income)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _stat('Keluar', m(outSum), C.redDark)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (inMonth.isEmpty)
                const AppCard(
                  child: EmptyState(
                      icon: Icons.receipt_long_rounded,
                      title: 'Belum ada transaksi',
                      subtitle: 'Tidak ada transaksi akun ini di periode ini.'),
                )
              else
                for (final day in days.keys) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                    child: Text(
                        DateFormat(_all ? 'EEEE, d MMM yyyy' : 'EEEE, d MMM',
                                'id_ID')
                            .format(day),
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: C.muted)),
                  ),
                  for (final (t, after) in days[day]!)
                    txTile(context, store, t,
                        forAccount: a.id, balanceAfter: hide ? null : after),
                ],
            ],
          ),
        );
      },
    );
  }

  /// "Perkiraan akhir bulan" dari transaksi berulang yang belum tercatat.
  Widget _projection(BuildContext context, Account a) {
    final now = DateTime.now();
    final items = store.upcomingForAccount(a.id, now);
    if (items.isEmpty) return const SizedBox.shrink();
    final proj = store.projectedMonthEnd(a.id, now);
    final hide = store.settings.hideBalance;
    final df = DateFormat('d MMM', 'id_ID');
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showSheet<void>(
          context,
          SheetFrame(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Jadwal sampai akhir bulan',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('Dari transaksi berulang yang belum tercatat.',
                    style: TextStyle(fontSize: 12.5, color: C.muted)),
                const SizedBox(height: 10),
                for (final (d, title, delta) in items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        SizedBox(
                            width: 56,
                            child: Text(df.format(d),
                                style: TextStyle(
                                    fontSize: 12.5, color: C.muted))),
                        Expanded(
                            child: Text(title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700))),
                        Text(
                            '${delta >= 0 ? '+' : '−'}${money(delta.abs(), a.currency)}',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: delta >= 0 ? C.income : C.redDark)),
                      ],
                    ),
                  ),
                Divider(color: C.line),
                Row(
                  children: [
                    const Expanded(
                        child: Text('Perkiraan saldo akhir bulan',
                            style: TextStyle(fontWeight: FontWeight.w800))),
                    Text(money(proj, a.currency),
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: proj < 0 ? C.redDark : C.carbon)),
                  ],
                ),
              ],
            ),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: (proj < 0 ? C.redDark : C.blueDark).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(Icons.event_note_rounded,
                  size: 18, color: proj < 0 ? C.redDark : C.blueDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    'Perkiraan akhir bulan: ${hide ? '••••' : money(proj, a.currency)} · ${items.length} jadwal',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: proj < 0 ? C.redDark : C.carbon)),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: C.muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: C.muted)),
          const SizedBox(height: 2),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}
