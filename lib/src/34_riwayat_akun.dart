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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  void _shift(int months) =>
      setState(() => _month = DateTime(_month.year, _month.month + months));

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
            if (!e.$1.date.isBefore(_month) && e.$1.date.isBefore(next)) e
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
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Bulan sebelumnya',
                          onPressed: () => _shift(-1),
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Expanded(
                          child: Text(
                              DateFormat('MMMM yyyy', 'id_ID').format(_month),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800)),
                        ),
                        IconButton(
                          tooltip: 'Bulan berikutnya',
                          onPressed: isCurrent ? null : () => _shift(1),
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
                      subtitle: 'Tidak ada transaksi akun ini di bulan ini.'),
                )
              else
                for (final day in days.keys) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                    child: Text(
                        DateFormat('EEEE, d MMM', 'id_ID').format(day),
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
