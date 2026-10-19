part of '../main.dart';

// =============================================================================
// UTANG-PIUTANG & TARGET TABUNGAN (v1.5)
// Pencatat terpisah: tidak mengubah saldo akun. Kalau uangnya memang
// berpindah, catat juga transaksinya seperti biasa.
// =============================================================================

class DebtPayment {
  const DebtPayment({required this.date, required this.amount});
  final DateTime date;
  final double amount;

  Map<String, dynamic> toJson() =>
      {'date': date.toIso8601String(), 'amount': amount};

  factory DebtPayment.fromJson(Map<String, dynamic> j) => DebtPayment(
        date: DateTime.tryParse(_s(j['date']) ?? '') ?? DateTime.now(),
        amount: _d(j['amount']),
      );
}

class Debt {
  Debt({
    required this.id,
    required this.person,
    required this.theyOwe,
    required this.amount,
    required this.date,
    this.due,
    this.note = '',
    this.holdAccountId,
    List<DebtPayment>? payments,
  }) : payments = payments ?? [];

  /// Akun penampung talangan (patungan). Kalau ada, pembayaran dari teman
  /// dipindah dari akun ini ke akun penerima supaya saldo tetap benar.
  final String? holdAccountId;

  final String id;
  String person;

  /// true = piutang (orang lain berutang ke kamu), false = utang kamu.
  bool theyOwe;
  double amount;
  DateTime date;
  DateTime? due;
  String note;
  final List<DebtPayment> payments;

  double get paid => payments.fold(0.0, (s, p) => s + p.amount);
  double get remaining => math.max(0, amount - paid);
  bool get settled => remaining < 0.0005;

  bool overdue(DateTime now) {
    final d = due;
    return !settled && d != null && dayOnly(d).isBefore(dayOnly(now));
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'person': person,
        'theyOwe': theyOwe,
        'amount': amount,
        'date': date.toIso8601String(),
        'due': due?.toIso8601String(),
        'note': note,
        if (holdAccountId != null) 'holdAccountId': holdAccountId,
        'payments': payments.map((p) => p.toJson()).toList(),
      };

  factory Debt.fromJson(Map<String, dynamic> j) => Debt(
        id: j['id'] as String,
        person: _s(j['person']) ?? '',
        theyOwe: j['theyOwe'] == true,
        amount: _d(j['amount']),
        date: DateTime.tryParse(_s(j['date']) ?? '') ?? DateTime.now(),
        due: DateTime.tryParse(_s(j['due']) ?? ''),
        note: _s(j['note']) ?? '',
        holdAccountId: _s(j['holdAccountId']),
        payments: _list(j['payments']).map(DebtPayment.fromJson).toList(),
      );
}

class Goal {
  Goal({
    required this.id,
    required this.name,
    required this.target,
    this.accountId,
    this.saved = 0,
    this.deadline,
    this.monthly,
    required this.color,
  });

  final String id;
  String name;
  double target;

  /// Kalau diisi, progres = saldo akun ini (mis. akun "Tabungan").
  String? accountId;

  /// Progres manual kalau tidak terhubung ke akun.
  double saved;
  DateTime? deadline;

  /// Rencana setoran tetap per bulan. Kalau diisi, tenggat tidak dipakai:
  /// kapan tercapai dihitung dari setoran ini (lihat [goalEta]).
  double? monthly;
  int color;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'target': target,
        'accountId': accountId,
        'saved': saved,
        'deadline': deadline?.toIso8601String(),
        if (monthly != null) 'monthly': monthly,
        'color': color,
      };

  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
        id: j['id'] as String,
        name: _s(j['name']) ?? 'Target',
        target: _d(j['target']),
        accountId: _s(j['accountId']),
        saved: _d(j['saved']),
        deadline: DateTime.tryParse(_s(j['deadline']) ?? ''),
        monthly: _d(j['monthly']) > 0 ? _d(j['monthly']) : null,
        color: _i(j['color'], kPalette.first),
      );
}

extension DebtsGoalsStore on AppStore {
  double debtTotal({required bool theyOwe}) => debts
      .where((d) => d.theyOwe == theyOwe && !d.settled)
      .fold(0.0, (s, d) => s + d.remaining);

  void upsertDebt(Debt d) {
    final i = debts.indexWhere((x) => x.id == d.id);
    if (i >= 0) {
      debts[i] = d;
    } else {
      debts.add(d);
    }
    _commit();
  }

  void deleteDebt(String id) {
    debts.removeWhere((d) => d.id == id);
    _commit();
  }

  void payDebt(Debt d, double amount, {DateTime? at}) {
    if (amount <= 0) return;
    d.payments.add(DebtPayment(
        date: at ?? DateTime.now(), amount: math.min(amount, d.remaining)));
    _commit();
  }

  void settleDebt(Debt d) => payDebt(d, d.remaining);

  double goalProgress(Goal g) {
    final a = g.accountId;
    if (a != null && accountById(a) != null) {
      return math.max(0, toIDR(balanceOf(a), currencyOf(a)));
    }
    return math.max(0, g.saved);
  }

  /// Jumlah bulan dari [now] sampai bulan [d] (minimal 1: tenggat di bulan ini
  /// berarti semuanya harus masuk bulan ini).
  static int monthsUntil(DateTime d, DateTime now) =>
      math.max(1, (d.year - now.year) * 12 + d.month - now.month);

  /// Setoran per bulan. Rencana setoran tetap dipakai apa adanya; kalau tidak
  /// ada, dihitung dari sisa target dibagi bulan sampai tenggat. Null kalau
  /// tidak ada rencana atau sudah tercapai.
  double? goalPerMonth(Goal g, DateTime now) {
    final left = g.target - goalProgress(g);
    if (left <= 0) return null;
    final m = g.monthly;
    if (m != null && m > 0) return math.min(m, left);
    final d = g.deadline;
    if (d == null) return null;
    return left / monthsUntil(d, now);
  }

  /// Bulan target tercapai: tenggat yang dipilih, atau perkiraan dari
  /// rencana setoran tetap. Null kalau tidak ada rencana atau sudah tercapai.
  DateTime? goalEta(Goal g, DateTime now) {
    final left = g.target - goalProgress(g);
    if (left <= 0) return null;
    final m = g.monthly;
    if (m != null && m > 0) {
      return DateTime(now.year, now.month + (left / m).ceil());
    }
    return g.deadline;
  }

  /// Jumlah bulan sampai [goalEta].
  int? goalMonthsLeft(Goal g, DateTime now) {
    final e = goalEta(g, now);
    return e == null ? null : monthsUntil(e, now);
  }

  void upsertGoal(Goal g) {
    final i = goals.indexWhere((x) => x.id == g.id);
    if (i >= 0) {
      goals[i] = g;
    } else {
      goals.add(g);
    }
    _commit();
  }

  void deleteGoal(String id) {
    goals.removeWhere((g) => g.id == id);
    _commit();
  }

  void addToGoal(Goal g, double delta) {
    g.saved = math.max(0, g.saved + delta);
    _commit();
  }
}

// ------------------------------------------------------------- utang-piutang UI

class DebtsPage extends StatefulWidget {
  const DebtsPage({super.key, required this.store});
  final AppStore store;

  @override
  State<DebtsPage> createState() => _DebtsPageState();
}

class _DebtsPageState extends State<DebtsPage> {
  bool _theyOwe = true;
  bool _showSettled = false;
  AppStore get store => widget.store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final now = DateTime.now();
        final list = store.debts.where((d) => d.theyOwe == _theyOwe).toList();
        final open = list.where((d) => !d.settled).toList()
          ..sort((a, b) {
            final ad = a.due, bd = b.due;
            if (ad == null && bd == null) return b.date.compareTo(a.date);
            if (ad == null) return 1;
            if (bd == null) return -1;
            return ad.compareTo(bd);
          });
        final done = list.where((d) => d.settled).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        return Scaffold(
          appBar: pageBar('Utang & Piutang', actions: [
            TextButton.icon(
              onPressed: () =>
                  showSheet<void>(context, PatunganSheet(store: store)),
              icon: const Icon(Icons.groups_rounded),
              label: const Text('Patungan'),
            ),
          ]),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => showSheet<void>(context,
                DebtEditorSheet(store: store, theyOwe: _theyOwe)),
            backgroundColor: C.accentDark,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Catat'),
          ),
          body: ListView(
            padding: pagePad(context, 100),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _total('Orang berutang ke kamu',
                        store.debtTotal(theyOwe: true), C.income),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _total('Kamu berutang',
                        store.debtTotal(theyOwe: false), C.redDark),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Segmented<bool>(
                values: const [true, false],
                selected: _theyOwe,
                labelOf: (v) => v ? 'Piutang' : 'Utang',
                onChanged: (v) => setState(() => _theyOwe = v),
              ),
              const SizedBox(height: 6),
              Text(
                  _theyOwe
                      ? 'Uang yang kamu pinjamkan ke orang lain.'
                      : 'Uang yang kamu pinjam dari orang lain.',
                  style: TextStyle(fontSize: 12.5, color: C.muted)),
              const SizedBox(height: 10),
              if (open.isEmpty)
                AppCard(
                  child: EmptyState(
                    icon: Icons.handshake_rounded,
                    title: _theyOwe ? 'Tidak ada piutang' : 'Tidak ada utang',
                    subtitle: 'Ketuk "Catat" untuk menambah.',
                  ),
                ),
              for (final d in open) _tile(context, d, now),
              if (done.isNotEmpty) ...[
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: () => setState(() => _showSettled = !_showSettled),
                  icon: Icon(_showSettled
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded),
                  label: Text(tr('Sudah lunas ({0})', [done.length])),
                ),
                if (_showSettled)
                  for (final d in done) _tile(context, d, now),
              ],
              const SizedBox(height: 8),
              Text(
                  'Catatan ini tidak mengubah saldo akun. Kalau uangnya memang keluar/masuk rekening, catat juga transaksinya. Pengecualian: piutang dari Patungan, yang uangnya otomatis pindah dari akun Talangan saat dibayar.',
                  style: TextStyle(fontSize: 12, color: C.muted)),
            ],
          ),
        );
      },
    );
  }

  Widget _total(String label, double v, Color color) => AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: C.muted)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(money(v),
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: color)),
            ),
          ],
        ),
      );

  Widget _tile(BuildContext context, Debt d, DateTime now) {
    final color = d.theyOwe ? C.income : C.redDark;
    final due = d.due;
    final late = d.overdue(now);
    final ratio = d.amount <= 0 ? 1.0 : (d.paid / d.amount).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () => showSheet<void>(context, DebtDetailSheet(store: store, debt: d)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CatIcon(
                    art: d.settled ? null : 'debt',
                    icon: d.settled
                        ? Icons.check_circle_rounded
                        : Icons.person_rounded,
                    color: d.settled ? C.muted : color,
                    size: 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.person,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(
                          d.settled
                              ? 'Lunas'
                              : due == null
                                  ? (d.note.isNotEmpty ? d.note : 'Tanpa tenggat')
                                  : '${late ? 'Lewat tenggat' : 'Tenggat'} ${DateFormat('d MMM yyyy', gDateLoc).format(due)}',
                          style: TextStyle(
                              fontSize: 12,
                              color: late ? C.redDark : C.muted,
                              fontWeight:
                                  late ? FontWeight.w800 : FontWeight.w400)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(money(d.settled ? d.amount : d.remaining),
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: d.settled ? C.muted : color)),
                    if (!d.settled && d.paid > 0)
                      Text(tr('dari {0}', [money(d.amount)]),
                          style: TextStyle(fontSize: 12, color: C.muted)),
                  ],
                ),
              ],
            ),
            if (!d.settled && d.paid > 0) ...[
              const SizedBox(height: 8),
              FunProgressBar(value: ratio, color: color, height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class DebtDetailSheet extends StatelessWidget {
  const DebtDetailSheet({super.key, required this.store, required this.debt});
  final AppStore store;
  final Debt debt;

  /// Hapus piutang patungan yang belum lunas: tanya dulu sisanya diapakan,
  /// supaya saldo akun Talangan tetap cocok.
  Future<bool> _deleteSplit(BuildContext context) async {
    final payer = store.splitPayerOf(debt);
    final payerName = payer == null ? null : store.accountById(payer)?.name;
    final left = money(debt.remaining);
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Hapus piutang patungan?',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text(
            tr('Sisa {0} dari {1} masih di akun Talangan Patungan. Mau diapakan?', [left, debt.person])),
        actionsOverflowDirection: VerticalDirection.down,
        actionsOverflowButtonSpacing: 4,
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: C.redDark,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20))),
            onPressed: () => Navigator.pop(ctx, 'expense'),
            child: const Text('Tidak dibayar, jadi pengeluaranku'),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20))),
            onPressed: () => Navigator.pop(ctx, 'return'),
            child: Text(payerName == null
                ? 'Salah catat, kembalikan uangnya'
                : tr('Salah catat, kembalikan ke {0}', [payerName])),
          ),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        ],
      ),
    );
    if (r == null || !context.mounted) return false;
    if (r == 'expense') {
      store.deleteSplitDebt(debt);
      return true;
    }
    final to = payer ?? await pickReceiveAccount(context, store);
    if (to == null) return false;
    store.deleteSplitDebt(debt, returnTo: to);
    return true;
  }

  /// Piutang patungan: tanya uangnya masuk ke akun mana, lalu pindahkan dari
  /// akun Talangan. Piutang biasa: cukup catat pembayarannya.
  Future<bool> _receive(BuildContext context, double amount) async {
    if (debt.theyOwe && debt.holdAccountId != null) {
      final to = await pickReceiveAccount(context, store);
      if (to == null) return false;
      store.receiveDebt(debt, amount, toAccountId: to);
    } else {
      store.payDebt(debt, amount);
    }
    return true;
  }

  Future<void> _pay(BuildContext context) async {
    final ctrl = TextEditingController(text: amountToInput(debt.remaining, 'IDR'));
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(debt.theyOwe ? 'Terima pembayaran' : 'Bayar cicilan',
            style: const TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [AmountFormatter(decimals: false)],
          decoration: fieldDeco('Jumlah', prefix: 'Rp ',
              helper: 'Sisa ${money(debt.remaining)}'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, parseAmount(ctrl.text)),
            style: FilledButton.styleFrom(backgroundColor: C.accentDark),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (v == null || v <= 0 || !context.mounted) return;
    if (!await _receive(context, v)) return;
    if (context.mounted) {
      snack(context, debt.settled ? tr('{0}: lunas 🎉', [debt.person]) : 'Pembayaran dicatat');
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = debt.theyOwe ? C.income : C.redDark;
    final df = DateFormat('d MMM yyyy', gDateLoc);
    return SheetFrame(
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(debt.person,
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w900)),
                ),
                IconButton(
                  tooltip: tr('Edit'),
                  onPressed: () {
                    Navigator.pop(context);
                    showSheet<void>(context,
                        DebtEditorSheet(store: store, debt: debt));
                  },
                  icon: const Icon(Icons.edit_rounded),
                ),
                IconButton(
                  tooltip: tr('Tutup'),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Text(
                debt.theyOwe
                    ? tr('Piutang · dipinjam {0}', [df.format(debt.date)])
                    : tr('Utang · dipinjam {0}', [df.format(debt.date)]),
                style: TextStyle(color: C.muted)),
            const SizedBox(height: 12),
            Text(debt.settled ? 'Lunas' : 'Sisa',
                style: TextStyle(fontSize: 12, color: C.muted)),
            Text(money(debt.settled ? debt.amount : debt.remaining),
                style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w900, color: color)),
            if (debt.paid > 0 && !debt.settled)
              Text(tr('Sudah dibayar {0} dari {1}', [money(debt.paid), money(debt.amount)]),
                  style: TextStyle(fontSize: 12.5, color: C.muted)),
            if (debt.due != null)
              Text(tr('Tenggat {0}', [df.format(debt.due!)]),
                  style: TextStyle(
                      fontSize: 12.5,
                      color: debt.overdue(DateTime.now()) ? C.redDark : C.muted)),
            if (debt.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(debt.note),
            ],
            if (debt.payments.isNotEmpty) ...[
              const SizedBox(height: 14),
              const SmallLabel('Riwayat pembayaran'),
              const SizedBox(height: 6),
              for (final p in debt.payments.reversed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(df.format(p.date),
                              style: TextStyle(color: C.muted))),
                      Text(money(p.amount),
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 16),
            if (!debt.settled) ...[
              PrimaryButton(
                label: debt.theyOwe ? 'Terima pembayaran' : 'Bayar cicilan',
                icon: Icons.payments_rounded,
                onPressed: () => _pay(context),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () async {
                  if (!await _receive(context, debt.remaining)) return;
                  if (context.mounted) snack(context, tr('{0}: lunas 🎉', [debt.person]));
                },
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20))),
                child: const Text('Tandai lunas'),
              ),
            ],
            TextButton.icon(
              onPressed: () async {
                if (debt.holdAccountId != null && !debt.settled) {
                  final done = await _deleteSplit(context);
                  if (done && context.mounted) Navigator.pop(context);
                  return;
                }
                final ok = await confirmDialog(context,
                    title: 'Hapus catatan ini?',
                    message:
                        tr('{0} {1} {2} beserta riwayat pembayarannya akan dihapus.', [debt.theyOwe ? 'Piutang' : 'Utang', debt.person, money(debt.amount)]),
                    confirmLabel: 'Hapus',
                    destructive: true);
                if (!ok || !context.mounted) return;
                store.deleteDebt(debt.id);
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: C.redDark),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Hapus'),
            ),
          ],
        ),
      ),
    );
  }
}

class DebtEditorSheet extends StatefulWidget {
  const DebtEditorSheet(
      {super.key, required this.store, this.debt, this.theyOwe = true});
  final AppStore store;
  final Debt? debt;
  final bool theyOwe;

  @override
  State<DebtEditorSheet> createState() => _DebtEditorSheetState();
}

class _DebtEditorSheetState extends State<DebtEditorSheet> {
  final _person = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late bool _theyOwe;
  late DateTime _date;
  DateTime? _due;
  String? _error;

  @override
  void initState() {
    super.initState();
    final d = widget.debt;
    _theyOwe = d?.theyOwe ?? widget.theyOwe;
    _date = d?.date ?? DateTime.now();
    _due = d?.due;
    _person.text = d?.person ?? '';
    if (d != null) _amount.text = amountToInput(d.amount, 'IDR');
    _note.text = d?.note ?? '';
  }

  @override
  void dispose() {
    _person.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime initial) => showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100));

  Future<void> _calc() async {
    final v = await showSheet<double>(
        context, CalculatorSheet(initial: parseAmount(_amount.text)));
    if (v != null && mounted) {
      setState(() => _amount.text = v > 0 ? amountToInput(v, 'IDR') : '');
    }
  }

  void _save() {
    final person = _person.text.trim();
    final amount = parseAmount(_amount.text);
    if (person.isEmpty) {
      setState(() => _error = 'Isi nama orangnya.');
      return;
    }
    if (amount <= 0) {
      setState(() => _error = 'Nominal harus lebih dari 0.');
      return;
    }
    final old = widget.debt;
    widget.store.upsertDebt(Debt(
      id: old?.id ?? widget.store.newId(),
      person: person,
      theyOwe: _theyOwe,
      amount: amount,
      date: _date,
      due: _due,
      note: _note.text.trim(),
      holdAccountId: old?.holdAccountId,
      payments: old?.payments,
    ));
    Navigator.pop(context);
    snack(context, old == null ? 'Dicatat' : 'Diperbarui');
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM yyyy', gDateLoc);
    return SheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(widget.debt == null ? 'Catat utang/piutang' : 'Edit',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900)),
              ),
              IconButton(
                tooltip: tr('Tutup'),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Segmented<bool>(
            values: const [true, false],
            selected: _theyOwe,
            labelOf: (v) => v ? 'Saya meminjamkan' : 'Saya meminjam',
            onChanged: (v) => setState(() => _theyOwe = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _person,
            textCapitalization: TextCapitalization.words,
            decoration: fieldDeco(_theyOwe ? 'Dipinjam oleh' : 'Pinjam dari',
                icon: Icons.person_rounded),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [AmountFormatter(decimals: false)],
            decoration: fieldDeco('Nominal', icon: Icons.payments_rounded, prefix: 'Rp ')
                .copyWith(
              suffixIcon: IconButton(
                tooltip: tr('Kalkulator'),
                icon: Icon(Icons.calculate_rounded, color: C.accentDark),
                onPressed: _calc,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FormRow(
            label: 'Tanggal',
            accent: C.accentDark,
            onTap: () async {
              final v = await _pick(_date);
              if (v != null) setState(() => _date = v);
            },
            child: FormValue(df.format(_date)),
          ),
          FormRow(
            label: 'Tenggat',
            accent: C.accentDark,
            onTap: () async {
              final v = await _pick(_due ?? DateTime.now().add(const Duration(days: 30)));
              if (v != null) setState(() => _due = v);
            },
            child: Row(
              children: [
                Expanded(
                    child: FormValue(_due == null ? null : df.format(_due!),
                        placeholder: 'Opsional')),
                if (_due != null)
                  IconButton(
                    tooltip: tr('Hapus tenggat'),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _due = null),
                    icon: Icon(Icons.close_rounded, size: 18, color: C.muted),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            maxLength: 120,
            decoration: fieldDeco('Catatan (opsional)', icon: Icons.notes_rounded)
                .copyWith(counterText: ''),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            ErrorBox(_error!),
          ],
          const SizedBox(height: 14),
          PrimaryButton(label: 'Simpan', onPressed: _save),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ target tabungan UI

class GoalsPage extends StatelessWidget {
  const GoalsPage({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        appBar: pageBar('Target tabungan'),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () =>
              showSheet<void>(context, GoalEditorSheet(store: store)),
          backgroundColor: C.accentDark,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Target baru'),
        ),
        body: ListView(
          padding: pagePad(context, 100),
          children: [
            if (store.goals.isEmpty)
              const AppCard(
                child: EmptyState(
                  icon: Icons.savings_rounded,
                  title: 'Belum ada target',
                  subtitle:
                      'Misalnya "Dana darurat Rp10 juta". Progres bisa ikut saldo akun tabungan atau diisi manual.',
                ),
              ),
            for (final g in store.goals)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GoalCard(store: store, goal: g),
              ),
          ],
        ),
      ),
    );
  }
}

class GoalCard extends StatelessWidget {
  const GoalCard({super.key, required this.store, required this.goal, this.compact = false});
  final AppStore store;
  final Goal goal;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = store.goalProgress(goal);
    final ratio = goal.target <= 0 ? 0.0 : (p / goal.target).clamp(0.0, 1.0);
    final done = ratio >= 1;
    final now = DateTime.now();
    final per = store.goalPerMonth(goal, now);
    final eta = store.goalEta(goal, now);
    final nLeft = store.goalMonthsLeft(goal, now);
    final byMonthly = goal.monthly != null && goal.monthly! > 0;
    final color = Color(goal.color);
    final acc = goal.accountId == null ? null : store.accountById(goal.accountId!);
    return AppCard(
      onTap: () => showSheet<void>(context, GoalEditorSheet(store: store, goal: goal)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CatIcon(
                  art: done ? 'piala' : 'saving',
                  icon: done ? Icons.emoji_events_rounded : Icons.savings_rounded,
                  color: color,
                  size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(
                        acc != null
                            ? tr('Ikut saldo {0}', [acc.name])
                            : 'Diisi manual',
                        style: TextStyle(fontSize: 12, color: C.muted)),
                  ],
                ),
              ),
              Text('${(ratio * 100).floor()}%',
                  style: TextStyle(
                      fontWeight: FontWeight.w900, color: darken(color))),
            ],
          ),
          const SizedBox(height: 10),
          FunProgressBar(value: ratio, color: color, height: 10),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(tr('{0} dari {1}', [money(p), money(goal.target)]),
                    style: TextStyle(fontSize: 12.5, color: C.carbon)),
              ),
              if (eta != null && !done)
                Text(DateFormat('MMM yyyy', gDateLoc).format(eta),
                    style: TextStyle(fontSize: 12, color: C.muted)),
            ],
          ),
          if (per != null && eta != null && nLeft != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: compact
                  ? Text(tr('{0} / bulan', [money(per)]),
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800, color: darken(color)))
                  : Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('{0} / bulan', [money(per)]),
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: darken(color))),
                          const SizedBox(height: 1),
                          Text(
                              byMonthly
                                  ? tr('Estimasi tercapai {0} · {1} bulan lagi', [
                                      DateFormat('MMM yyyy', gDateLoc).format(eta),
                                      '$nLeft'
                                    ])
                                  : tr('Sampai {0} · {1} bulan lagi', [
                                      DateFormat('MMM yyyy', gDateLoc).format(eta),
                                      '$nLeft'
                                    ]),
                              style: TextStyle(fontSize: 12, color: C.carbon)),
                        ],
                      ),
                    ),
            ),
          if (done)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Tercapai! 🎉',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: C.income)),
            ),
          if (!compact && acc == null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _adjust(context, -1),
                    icon: const Icon(Icons.remove_rounded),
                    label: const Text('Ambil'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _adjust(context, 1),
                    style: FilledButton.styleFrom(backgroundColor: C.accentDark),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Setor'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _adjust(BuildContext context, int sign) async {
    final ctrl = TextEditingController();
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(sign > 0 ? tr('Setor ke {0}', [goal.name]) : tr('Ambil dari {0}', [goal.name]),
            style: const TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [AmountFormatter(decimals: false)],
          decoration: fieldDeco('Jumlah', prefix: 'Rp '),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, parseAmount(ctrl.text)),
            style: FilledButton.styleFrom(backgroundColor: C.accentDark),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (v == null || v <= 0) return;
    store.addToGoal(goal, sign * v);
  }
}

class GoalEditorSheet extends StatefulWidget {
  const GoalEditorSheet({super.key, required this.store, this.goal});
  final AppStore store;
  final Goal? goal;

  @override
  State<GoalEditorSheet> createState() => _GoalEditorSheetState();
}

class _GoalEditorSheetState extends State<GoalEditorSheet> {
  final _name = TextEditingController();
  final _target = TextEditingController();
  final _monthly = TextEditingController();
  String? _accountId;
  DateTime? _deadline;
  // 'deadline' = tentukan tenggat, hitung setoran; 'monthly' = tentukan setoran, hitung kapan tercapai.
  String _plan = 'deadline';
  late int _color;
  String? _error;

  @override
  void initState() {
    super.initState();
    final g = widget.goal;
    _name.text = g?.name ?? '';
    if (g != null) _target.text = amountToInput(g.target, 'IDR');
    _accountId = g?.accountId;
    _deadline = g?.deadline;
    if (g?.monthly != null) {
      _plan = 'monthly';
      _monthly.text = amountToInput(g!.monthly!, 'IDR');
    }
    _color = g?.color ?? kPalette[widget.store.goals.length % kPalette.length];
    // Kartu hasil ikut berubah saat angka diketik.
    _target.addListener(_refresh);
    _monthly.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _monthly.dispose();
    super.dispose();
  }

  /// Target sementara dari isian saat ini, untuk pratinjau hasil hitungan.
  Goal _draft() => Goal(
        id: widget.goal?.id ?? 'draft',
        name: _name.text,
        target: parseAmount(_target.text),
        accountId: _accountId,
        saved: widget.goal?.saved ?? 0,
        deadline: _plan == 'deadline' ? _deadline : null,
        monthly: _plan == 'monthly' && parseAmount(_monthly.text) > 0
            ? parseAmount(_monthly.text)
            : null,
        color: _color,
      );

  void _save() {
    final name = _name.text.trim();
    final target = parseAmount(_target.text);
    if (name.isEmpty) {
      setState(() => _error = 'Isi nama targetnya.');
      return;
    }
    if (target <= 0) {
      setState(() => _error = 'Target harus lebih dari 0.');
      return;
    }
    final monthly = parseAmount(_monthly.text);
    if (_plan == 'monthly' && monthly <= 0) {
      setState(() => _error = 'Isi setoran per bulan, atau pilih Tentukan tenggat.');
      return;
    }
    final old = widget.goal;
    widget.store.upsertGoal(Goal(
      id: old?.id ?? widget.store.newId(),
      name: name,
      target: target,
      accountId: _accountId,
      saved: old?.saved ?? 0,
      // Dua mode saling menggantikan: yang tidak dipakai dikosongkan.
      deadline: _plan == 'deadline' ? _deadline : null,
      monthly: _plan == 'monthly' ? monthly : null,
      color: _color,
    ));
    Navigator.pop(context);
  }

  /// Kartu hasil hitungan dua arah, ikut berubah saat isian berubah.
  Widget _planResult() {
    final store = widget.store;
    final g = _draft();
    final now = DateTime.now();
    final color = darken(Color(_color));
    Widget box(List<Widget> kids) => AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Color(_color).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: kids),
        );
    if (g.target <= 0) {
      return box([
        Text('Isi target dulu, hasil hitungan muncul di sini.',
            style: TextStyle(fontSize: 12.5, color: C.muted)),
      ]);
    }
    final have = store.goalProgress(g);
    final left = g.target - have;
    if (left <= 0) {
      return box([
        Text('Tercapai! 🎉',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
      ]);
    }
    final per = store.goalPerMonth(g, now);
    final eta = store.goalEta(g, now);
    final n = store.goalMonthsLeft(g, now);
    final String big;
    final String sub;
    if (per == null || eta == null || n == null) {
      big = '-';
      sub = _plan == 'monthly'
          ? 'Isi setoran per bulan untuk melihat kapan tercapai.'
          : 'Pilih tenggat untuk melihat setoran per bulan.';
    } else if (_plan == 'monthly') {
      big = tr('Tercapai {0}', [DateFormat('MMM yyyy', gDateLoc).format(eta)]);
      sub = tr('Dengan {0} per bulan, {1} bulan lagi.', [money(per), '$n']);
    } else {
      big = tr('Perlu {0} per bulan', [money(per)]);
      sub = tr('{0} bulan sampai {1}', [
        '$n',
        DateFormat('MMM yyyy', gDateLoc).format(eta),
      ]);
    }
    return box([
      Text(big, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
      const SizedBox(height: 2),
      Text(sub, style: TextStyle(fontSize: 12.5, color: C.carbon)),
      const SizedBox(height: 8),
      Text(tr('Terkumpul {0} · kurang {1}', [money(have), money(left)]),
          style: TextStyle(fontSize: 12, color: C.muted)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return SheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(widget.goal == null ? 'Target baru' : 'Edit target',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900)),
              ),
              IconButton(
                tooltip: tr('Tutup'),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: fieldDeco('Nama target', icon: Icons.flag_rounded)
                .copyWith(hintText: tr('mis. Dana darurat')),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _target,
            keyboardType: TextInputType.number,
            inputFormatters: [AmountFormatter(decimals: false)],
            decoration: fieldDeco('Target', icon: Icons.savings_rounded, prefix: 'Rp '),
          ),
          const SizedBox(height: 14),
          const SmallLabel('Rencana menabung'),
          const SizedBox(height: 8),
          Segmented<String>(
            values: const ['deadline', 'monthly'],
            selected: _plan,
            labelOf: (v) => v == 'monthly' ? 'Tentukan setoran' : 'Tentukan tenggat',
            iconOf: (v) => v == 'monthly' ? Icons.payments_rounded : Icons.event_rounded,
            dense: true,
            onChanged: (v) => setState(() => _plan = v),
          ),
          const SizedBox(height: 10),
          if (_plan == 'deadline') ...[
            FormRow(
              label: 'Tenggat',
              accent: C.accentDark,
              onTap: () async {
                final v = await showDatePicker(
                    context: context,
                    initialDate:
                        _deadline ?? DateTime.now().add(const Duration(days: 180)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100));
                if (v != null) setState(() => _deadline = v);
              },
              child: Row(
                children: [
                  Expanded(
                    child: FormValue(
                        _deadline == null
                            ? null
                            : DateFormat('d MMM yyyy', gDateLoc).format(_deadline!),
                        placeholder: 'Opsional'),
                  ),
                  if (_deadline != null)
                    IconButton(
                      tooltip: tr('Hapus tenggat'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => _deadline = null),
                      icon: Icon(Icons.close_rounded, size: 18, color: C.muted),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final m in const [6, 12, 24])
                  ActionChip(
                    label: Text(m == 12
                        ? '1 tahun'
                        : m == 24
                            ? '2 tahun'
                            : '$m bulan'),
                    onPressed: () {
                      final n = DateTime.now();
                      setState(() => _deadline = DateTime(n.year, n.month + m, n.day));
                    },
                  ),
              ],
            ),
          ] else
            TextField(
              controller: _monthly,
              keyboardType: TextInputType.number,
              inputFormatters: [AmountFormatter(decimals: false)],
              decoration:
                  fieldDeco('Setoran per bulan', icon: Icons.payments_rounded, prefix: 'Rp '),
            ),
          const SizedBox(height: 10),
          _planResult(),
          const SizedBox(height: 12),
          const SmallLabel('Progres dihitung dari'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Isi manual'),
                selected: _accountId == null,
                onSelected: (_) => setState(() => _accountId = null),
              ),
              for (final a in store.accounts)
                ChoiceChip(
                  label: Text(tr('Saldo {0}', [a.name])),
                  selected: _accountId == a.id,
                  onSelected: (_) => setState(() => _accountId = a.id),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const SmallLabel('Warna'),
          const SizedBox(height: 8),
          _ColorPicker(
              selected: _color, onSelected: (c) => setState(() => _color = c)),
          if (_error != null) ...[
            const SizedBox(height: 8),
            ErrorBox(_error!),
          ],
          const SizedBox(height: 14),
          PrimaryButton(label: 'Simpan', onPressed: _save),
          if (widget.goal != null)
            TextButton.icon(
              onPressed: () async {
                final ok = await confirmDialog(context,
                    title: 'Hapus target?',
                    message: tr('Target "{0}" akan dihapus. Saldo akun tidak berubah.', [widget.goal!.name]),
                    confirmLabel: 'Hapus',
                    destructive: true);
                if (!ok || !context.mounted) return;
                store.deleteGoal(widget.goal!.id);
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: C.redDark),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Hapus target'),
            ),
        ],
      ),
    );
  }
}
