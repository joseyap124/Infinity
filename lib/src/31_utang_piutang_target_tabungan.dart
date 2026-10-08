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
  int color;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'target': target,
        'accountId': accountId,
        'saved': saved,
        'deadline': deadline?.toIso8601String(),
        'color': color,
      };

  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
        id: j['id'] as String,
        name: _s(j['name']) ?? 'Target',
        target: _d(j['target']),
        accountId: _s(j['accountId']),
        saved: _d(j['saved']),
        deadline: DateTime.tryParse(_s(j['deadline']) ?? ''),
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

  /// Setoran per bulan yang dibutuhkan supaya tercapai di tenggat. Null kalau
  /// tidak ada tenggat atau sudah tercapai.
  double? goalPerMonth(Goal g, DateTime now) {
    final d = g.deadline;
    final left = g.target - goalProgress(g);
    if (d == null || left <= 0) return null;
    final months = (d.year - now.year) * 12 + d.month - now.month;
    return left / math.max(1, months);
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
                  label: Text('Sudah lunas (${done.length})'),
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
                                  : '${late ? 'Lewat tenggat' : 'Tenggat'} ${DateFormat('d MMM yyyy', 'id_ID').format(due)}',
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
                      Text('dari ${money(d.amount)}',
                          style: TextStyle(fontSize: 11, color: C.muted)),
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
      snack(context, debt.settled ? '${debt.person}: lunas 🎉' : 'Pembayaran dicatat');
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = debt.theyOwe ? C.income : C.redDark;
    final df = DateFormat('d MMM yyyy', 'id_ID');
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
                  tooltip: 'Edit',
                  onPressed: () {
                    Navigator.pop(context);
                    showSheet<void>(context,
                        DebtEditorSheet(store: store, debt: debt));
                  },
                  icon: const Icon(Icons.edit_rounded),
                ),
                IconButton(
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Text(
                debt.theyOwe
                    ? 'Piutang · dipinjam ${df.format(debt.date)}'
                    : 'Utang · dipinjam ${df.format(debt.date)}',
                style: TextStyle(color: C.muted)),
            const SizedBox(height: 12),
            Text(debt.settled ? 'Lunas' : 'Sisa',
                style: TextStyle(fontSize: 12, color: C.muted)),
            Text(money(debt.settled ? debt.amount : debt.remaining),
                style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w900, color: color)),
            if (debt.paid > 0 && !debt.settled)
              Text('Sudah dibayar ${money(debt.paid)} dari ${money(debt.amount)}',
                  style: TextStyle(fontSize: 12.5, color: C.muted)),
            if (debt.due != null)
              Text('Tenggat ${df.format(debt.due!)}',
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
                  if (context.mounted) snack(context, '${debt.person}: lunas 🎉');
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
                final ok = await confirmDialog(context,
                    title: 'Hapus catatan ini?',
                    message:
                        '${debt.theyOwe ? 'Piutang' : 'Utang'} ${debt.person} ${money(debt.amount)} beserta riwayat pembayarannya akan dihapus.',
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
    final df = DateFormat('d MMM yyyy', 'id_ID');
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
                tooltip: 'Tutup',
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
                tooltip: 'Kalkulator',
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
                    tooltip: 'Hapus tenggat',
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
        appBar: pageBar('Target Tabungan'),
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
    final per = store.goalPerMonth(goal, DateTime.now());
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
                            ? 'Ikut saldo ${acc.name}'
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
                child: Text('${money(p)} dari ${money(goal.target)}',
                    style: TextStyle(fontSize: 12.5, color: C.carbon)),
              ),
              if (goal.deadline != null)
                Text(DateFormat('MMM yyyy', 'id_ID').format(goal.deadline!),
                    style: TextStyle(fontSize: 12, color: C.muted)),
            ],
          ),
          if (!compact && per != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                  'Perlu ±${money(per)} per bulan supaya tercapai tepat waktu.',
                  style: TextStyle(fontSize: 12, color: C.muted)),
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
        title: Text(sign > 0 ? 'Setor ke ${goal.name}' : 'Ambil dari ${goal.name}',
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
  String? _accountId;
  DateTime? _deadline;
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
    _color = g?.color ?? kPalette[widget.store.goals.length % kPalette.length];
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

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
    final old = widget.goal;
    widget.store.upsertGoal(Goal(
      id: old?.id ?? widget.store.newId(),
      name: name,
      target: target,
      accountId: _accountId,
      saved: old?.saved ?? 0,
      deadline: _deadline,
      color: _color,
    ));
    Navigator.pop(context);
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
                tooltip: 'Tutup',
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
                .copyWith(hintText: 'mis. Dana darurat'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _target,
            keyboardType: TextInputType.number,
            inputFormatters: [AmountFormatter(decimals: false)],
            decoration: fieldDeco('Target', icon: Icons.savings_rounded, prefix: 'Rp '),
          ),
          const SizedBox(height: 4),
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
                          : DateFormat('d MMM yyyy', 'id_ID').format(_deadline!),
                      placeholder: 'Opsional'),
                ),
                if (_deadline != null)
                  IconButton(
                    tooltip: 'Hapus tenggat',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _deadline = null),
                    icon: Icon(Icons.close_rounded, size: 18, color: C.muted),
                  ),
              ],
            ),
          ),
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
                  label: Text('Saldo ${a.name}'),
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
                    message: 'Target "${widget.goal!.name}" akan dihapus. Saldo akun tidak berubah.',
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
