part of '../main.dart';

// =============================================================================
// CICILAN 0% (Shopee SPayLater, Kredivo, dst). Dicatat manual, tanpa bunga.
// =============================================================================

/// Satu barang yang dicicil. Bunga selalu 0%, jadi nominal per kali bayar
/// hanyalah total dibagi tenor (sisa pembulatan masuk ke cicilan terakhir).
class Installment {
  Installment({
    required this.id,
    required this.name,
    required this.total,
    required this.tenor,
    required this.dueDay,
    required this.firstDue,
    required this.accountId,
    this.categoryId,
    List<String>? paidTx,
  }) : paidTx = paidTx ?? [];

  final String id;
  final String name;
  final double total;

  /// Berapa kali bayar. 1 = dibayar sekali di tagihan berikutnya.
  final int tenor;

  /// Tanggal jatuh tempo tiap bulan (1..31). Bulan pendek dipotong ke hari terakhir.
  final int dueDay;

  /// Bulan tagihan pertama (hanya tahun dan bulan yang dipakai).
  final DateTime firstDue;
  final String accountId;
  final String? categoryId;

  /// Satu isi per cicilan yang sudah dibayar: id transaksi yang dibuat saat
  /// "Tandai dibayar", atau '' kalau dibayar sebelum dicatat di Infinity.
  final List<String> paidTx;

  int get paidCount => paidTx.length;
  bool get done => paidCount >= tenor;
  int get left => math.max(0, tenor - paidCount);

  double get _base => (total / tenor).roundToDouble();

  /// Nominal cicilan ke-[k] (mulai 0). Yang terakhir menyerap sisa pembulatan.
  double amountOf(int k) => k >= tenor - 1 ? total - _base * (tenor - 1) : _base;

  /// Nominal tiap bulan (untuk ditampilkan).
  double get perMonth => _base;

  DateTime dueOf(int k) {
    final m = firstDue.month - 1 + k;
    final y = firstDue.year + m ~/ 12;
    final mo = m % 12 + 1;
    final last = DateTime(y, mo + 1, 0).day;
    return DateTime(y, mo, math.min(dueDay, last));
  }

  DateTime? get nextDue => done ? null : dueOf(paidCount);
  DateTime get lastDue => dueOf(tenor - 1);

  double get paidAmount {
    var s = 0.0;
    for (var k = 0; k < paidCount && k < tenor; k++) {
      s += amountOf(k);
    }
    return s;
  }

  double get remaining => math.max(0.0, total - paidAmount);

  Installment copyWith({
    String? name,
    double? total,
    int? tenor,
    int? dueDay,
    DateTime? firstDue,
    String? accountId,
    String? categoryId,
    List<String>? paidTx,
  }) =>
      Installment(
        id: id,
        name: name ?? this.name,
        total: total ?? this.total,
        tenor: tenor ?? this.tenor,
        dueDay: dueDay ?? this.dueDay,
        firstDue: firstDue ?? this.firstDue,
        accountId: accountId ?? this.accountId,
        categoryId: categoryId ?? this.categoryId,
        paidTx: paidTx ?? List<String>.of(this.paidTx),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'total': total,
        'tenor': tenor,
        'dueDay': dueDay,
        'firstDue': firstDue.toIso8601String(),
        'accountId': accountId,
        'categoryId': categoryId,
        'paidTx': paidTx,
      };

  factory Installment.fromJson(Map<String, dynamic> j) {
    final tenor = math.max(1, _i(j['tenor']));
    final paid = j['paidTx'] is List
        ? (j['paidTx'] as List).map((e) => e is String ? e : '').toList()
        : <String>[];
    return Installment(
      id: j['id'] as String,
      name: _s(j['name']) ?? '',
      total: _d(j['total']),
      tenor: tenor,
      dueDay: _i(j['dueDay'], 1).clamp(1, 31),
      firstDue: DateTime.parse(j['firstDue'] as String),
      accountId: j['accountId'] as String,
      categoryId: _s(j['categoryId']),
      paidTx: paid.length > tenor ? paid.sublist(0, tenor) : paid,
    );
  }
}

/// Satu tagihan cicilan yang belum dibayar.
class InstallmentDue {
  const InstallmentDue(this.item, this.index, this.date, this.amount);
  final Installment item;
  final int index;
  final DateTime date;
  final double amount;
}

extension InstallmentStore on AppStore {
  List<Installment> get activeInstallments =>
      installments.where((x) => !x.done).toList();

  /// Semua tagihan yang belum dibayar dan jatuh tempo sebelum [limit]
  /// (termasuk yang sudah lewat tapi belum ditandai dibayar).
  List<InstallmentDue> installmentsDueBefore(DateTime limit) {
    final out = <InstallmentDue>[];
    for (final x in installments) {
      for (var k = x.paidCount; k < x.tenor && k < x.paidCount + 24; k++) {
        final d = x.dueOf(k);
        if (!d.isBefore(limit)) break;
        out.add(InstallmentDue(x, k, d, x.amountOf(k)));
      }
    }
    out.sort((a, b) => a.date.compareTo(b.date));
    return out;
  }

  /// Tagihan terdekat tiap barang (satu per barang), urut tanggal.
  List<InstallmentDue> nextInstallmentDues() {
    final out = <InstallmentDue>[];
    for (final x in installments) {
      if (x.done) continue;
      out.add(InstallmentDue(x, x.paidCount, x.dueOf(x.paidCount), x.amountOf(x.paidCount)));
    }
    out.sort((a, b) => a.date.compareTo(b.date));
    return out;
  }

  double get installmentsRemaining =>
      installments.fold(0.0, (s, x) => s + x.remaining);

  void upsertInstallment(Installment x) {
    final i = installments.indexWhere((e) => e.id == x.id);
    if (i >= 0) {
      installments[i] = x;
    } else {
      installments.add(x);
    }
    _commit();
  }

  /// Hapus cicilan. Transaksi yang sudah tercatat tetap ada.
  Installment? deleteInstallment(String id) {
    final i = installments.indexWhere((e) => e.id == id);
    if (i < 0) return null;
    final removed = installments.removeAt(i);
    _commit();
    return removed;
  }

  void restoreInstallment(Installment x) {
    if (installments.any((e) => e.id == x.id)) return;
    installments.add(x);
    _commit();
  }

  /// Catat pembayaran cicilan berikutnya sebagai pengeluaran dari akunnya.
  /// Mengembalikan id transaksi, atau null kalau sudah lunas.
  String? markInstallmentPaid(String id) {
    final i = installments.indexWhere((e) => e.id == id);
    if (i < 0) return null;
    final x = installments[i];
    if (x.done) return null;
    final k = x.paidCount;
    final txId = newId();
    final title = x.tenor == 1
        ? tr('Cicilan {0}', [x.name])
        : tr('Cicilan {0} ({1}/{2})', [x.name, k + 1, x.tenor]);
    transactions.add(Transaction(
      id: txId,
      title: title,
      amount: x.amountOf(k),
      type: TxType.expense,
      categoryId: x.categoryId,
      accountId: x.accountId,
      date: DateTime.now(),
      note: tr('Cicilan 0%'),
    ));
    x.paidTx.add(txId);
    _commit();
    return txId;
  }

  /// Batalkan pembayaran terakhir: transaksinya dihapus, hitungan mundur satu.
  void undoInstallmentPayment(String id) {
    final i = installments.indexWhere((e) => e.id == id);
    if (i < 0) return;
    final x = installments[i];
    if (x.paidTx.isEmpty) return;
    final txId = x.paidTx.removeLast();
    if (txId.isNotEmpty) transactions.removeWhere((t) => t.id == txId);
    _commit();
  }
}

// ------------------------------------------------------------------- tanggal

/// Tanggal [day] terdekat pada atau setelah [today] (dipotong ke akhir bulan pendek).
DateTime _nextDayOnOrAfter(int day, DateTime today) {
  DateTime at(int y, int m) =>
      DateTime(y, m, math.min(day, DateTime(y, m + 1, 0).day));
  final a = at(today.year, today.month);
  return a.isBefore(today) ? at(today.year, today.month + 1) : a;
}

String _instDate(DateTime d) => DateFormat('d MMM yyyy', gDateLoc).format(d);
String _instDateShort(DateTime d) => DateFormat('d MMM', gDateLoc).format(d);

String _daysText(int days) {
  if (days < 0) return tr('lewat {0} hari', [-days]);
  if (days == 0) return tr('hari ini');
  return tr('{0} hari lagi', [days]);
}

String _kaliText(Installment x) => x.tenor == 1
    ? tr('Bayar sekali (1x)')
    : x.paidCount == 0
        ? tr('Belum ada yang dibayar')
        : tr('Sudah {0} dari {1} kali', [x.paidCount, x.tenor]);

// ------------------------------------------------------------ kartu di Rencana

class InstallmentSummaryCard extends StatelessWidget {
  const InstallmentSummaryCard({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final hide = store.settings.hideBalance;
    String m(double v) => hide ? '••••' : money(v);
    final today = dayOnly(DateTime.now());
    final nexts = store.nextInstallmentDues();
    final first = nexts.first.date;
    final dueNow = store.installmentsDueBefore(first.add(const Duration(days: 1)));
    final sum = dueNow.fold(0.0, (v, d) => v + d.amount);
    final days = first.difference(today).inDays;
    final active = store.activeInstallments;
    var lastAll = active.first.lastDue;
    for (final x in active) {
      if (x.lastDue.isAfter(lastAll)) lastAll = x.lastDue;
    }
    return AppCard(
      onTap: () => _pushPage(context, InstallmentsPage(store: store)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        tr('Jatuh tempo {0} ({1})', [_instDateShort(first), _daysText(days)]),
                        style: TextStyle(
                            fontSize: 12.5,
                            color: days < 0 ? C.redDark : C.muted,
                            fontWeight: days < 0 ? FontWeight.w800 : FontWeight.w400)),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(m(sum),
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: C.income.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: Text('Bunga 0%',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: C.income)),
              ),
            ],
          ),
          const Divider(height: 20),
          for (final d in nexts.take(4))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(d.item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                      d.item.tenor == 1
                          ? tr('{0} · bayar 1x', [m(d.amount)])
                          : tr('{0} · {1} dari {2}', [m(d.amount), d.index + 1, d.item.tenor]),
                      style: TextStyle(fontSize: 13, color: C.muted)),
                ],
              ),
            ),
          if (nexts.length > 4)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(tr('+{0} lainnya', [nexts.length - 4]),
                  style: TextStyle(fontSize: 12.5, color: C.muted)),
            ),
          const SizedBox(height: 6),
          Text(
              tr('Sisa seluruh cicilan {0}. Lunas semua {1}.',
                  [m(store.installmentsRemaining), _instDate(lastAll)]),
              style: TextStyle(fontSize: 12.5, color: C.muted)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------- daftar

class InstallmentsPage extends StatefulWidget {
  const InstallmentsPage({super.key, required this.store});
  final AppStore store;

  @override
  State<InstallmentsPage> createState() => _InstallmentsPageState();
}

class _InstallmentsPageState extends State<InstallmentsPage> {
  bool _showDone = false;
  AppStore get store => widget.store;

  void _pay(Installment x) {
    final k = x.paidCount;
    final amount = x.amountOf(k);
    final txId = store.markInstallmentPaid(x.id);
    if (txId == null || !mounted) return;
    snack(
      context,
      tr('Cicilan {0} dicatat {1}', [x.name, money(amount)]),
      action: SnackBarAction(
        label: tr('Urungkan'),
        onPressed: () => store.undoInstallmentPayment(x.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final hide = store.settings.hideBalance;
        String m(double v) => hide ? '••••' : money(v);
        final today = dayOnly(DateTime.now());
        final active = store.activeInstallments
          ..sort((a, b) => a.nextDue!.compareTo(b.nextDue!));
        final done = store.installments.where((x) => x.done).toList();
        final nexts = store.nextInstallmentDues();
        final first = nexts.isEmpty ? null : nexts.first.date;
        final dueNow = first == null
            ? 0.0
            : store
                .installmentsDueBefore(first.add(const Duration(days: 1)))
                .fold(0.0, (v, d) => v + d.amount);
        final reserved = store.safeToSpend(DateTime.now()).installments;
        return Scaffold(
          appBar: pageBar('Cicilan'),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () =>
                showSheet<void>(context, InstallmentEditorSheet(store: store)),
            backgroundColor: C.accentDark,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Tambah'),
          ),
          body: ListView(
            padding: pagePad(context, 100),
            children: [
              if (active.isEmpty)
                AppCard(
                  child: EmptyState(
                    icon: Icons.credit_score_rounded,
                    title: 'Belum ada cicilan',
                    subtitle:
                        'Catat barang yang kamu cicil 0% (SPayLater, Kredivo, kartu kredit) supaya tagihannya tidak kelewat.',
                  ),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: _tile(
                          first == null
                              ? tr('Tagihan terdekat')
                              : tr('Tagihan {0}', [_instDateShort(first)]),
                          m(dueNow),
                          C.carbon),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _tile('Sisa seluruhnya', m(store.installmentsRemaining),
                          C.redDark),
                    ),
                  ],
                ),
                if (first != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: C.amberDark.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        Icon(Icons.schedule_rounded, color: C.amberDark),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                              tr('Jatuh tempo {0}, {1}.', [_instDateShort(first), _daysText(first.difference(today).inDays)]) +
                                  (reserved > 0 && !hide
                                      ? ' ${tr('{0} sudah dicadangkan di "Aman dibelanjakan".', [money(reserved)])}'
                                      : ''),
                              style: TextStyle(
                                  fontSize: 13.5, height: 1.35, color: C.carbon)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                for (final x in active) _card(context, x, today, m),
              ],
              if (done.isNotEmpty) ...[
                TextButton.icon(
                  onPressed: () => setState(() => _showDone = !_showDone),
                  icon: Icon(_showDone
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded),
                  label: Text(tr('Sudah lunas ({0})', [done.length])),
                ),
                if (_showDone)
                  for (final x in done) _card(context, x, today, m),
              ],
              const SizedBox(height: 8),
              Text(
                  'Infinity tidak mengambil data dari Shopee atau aplikasi lain. Kamu yang mengisi, dan app mengingatkan tiap jatuh tempo. "Tandai dibayar" mencatat pengeluaran dari akun yang kamu pilih.',
                  style: TextStyle(fontSize: 12, color: C.muted)),
            ],
          ),
        );
      },
    );
  }

  Widget _tile(String label, String value, Color color) => AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: C.muted)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900, color: color)),
            ),
          ],
        ),
      );

  Widget _card(BuildContext context, Installment x, DateTime today,
      String Function(double) m) {
    final next = x.nextDue;
    final late = next != null && next.isBefore(today);
    final ratio = x.total <= 0 ? 1.0 : (x.paidAmount / x.total).clamp(0.0, 1.0);
    final acc = store.accountById(x.accountId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () =>
            showSheet<void>(context, InstallmentEditorSheet(store: store, item: x)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(x.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 8),
                Text(m(x.perMonth),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
            if (x.tenor > 1) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 8,
                  backgroundColor: C.line,
                  color: x.done ? C.muted : C.income,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text('${_kaliText(x)} · ${tr('bunga 0%')}',
                      style: TextStyle(fontSize: 12.5, color: C.muted)),
                ),
                Text(
                    x.done
                        ? tr('Lunas')
                        : tr('Lunas {0}', [_instDate(x.lastDue)]),
                    style: TextStyle(fontSize: 12.5, color: C.muted)),
              ],
            ),
            const SizedBox(height: 6),
            if (x.done)
              Text(
                  acc == null
                      ? tr('Total {0}', [m(x.total)])
                      : tr('Total {0} · akun {1}', [m(x.total), acc.name]),
                  style: TextStyle(fontSize: 12.5, color: C.muted))
            else
              Row(
                children: [
                  Expanded(
                    child: Text(
                        late
                            ? tr('Lewat jatuh tempo {0} · sisa {1}', [_instDateShort(next), m(x.remaining)])
                            : x.paidCount == 0 && x.tenor > 1
                                ? tr('Sisa {0} · tagihan pertama {1}', [m(x.remaining), _instDateShort(next!)])
                                : tr('Sisa {0} · akun {1}', [m(x.remaining), acc?.name ?? '-']),
                        style: TextStyle(
                            fontSize: 12.5,
                            color: late ? C.redDark : C.muted,
                            fontWeight: late ? FontWeight.w800 : FontWeight.w400)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => _pay(x),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        foregroundColor: C.accentDark,
                        side: BorderSide(color: C.accentDark, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22))),
                    child: const Text('Tandai dibayar',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- form

class InstallmentEditorSheet extends StatefulWidget {
  const InstallmentEditorSheet({super.key, required this.store, this.item});
  final AppStore store;
  final Installment? item;

  @override
  State<InstallmentEditorSheet> createState() => _InstallmentEditorSheetState();
}

class _InstallmentEditorSheetState extends State<InstallmentEditorSheet> {
  final _name = TextEditingController();
  final _total = TextEditingController();
  final _day = TextEditingController(text: '1');
  final _paid = TextEditingController(text: '0');
  final _custom = TextEditingController();
  static const _presets = [1, 3, 6, 12];
  int _tenor = 3;
  bool _other = false;
  late String _accountId;
  String? _categoryId;
  String? _error;

  AppStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    final x = widget.item;
    _accountId = x?.accountId ?? store.accounts.first.id;
    if (x != null) {
      _name.text = x.name;
      _total.text = amountToInput(x.total, 'IDR');
      _day.text = '${x.dueDay}';
      _paid.text = '${x.paidCount}';
      _tenor = x.tenor;
      _other = !_presets.contains(x.tenor);
      if (_other) _custom.text = '${x.tenor}';
      _categoryId = x.categoryId;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _total.dispose();
    _day.dispose();
    _paid.dispose();
    _custom.dispose();
    super.dispose();
  }

  int _num(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  /// Cicilan sementara dari isi form (null kalau belum lengkap).
  Installment? _draft() {
    final total = parseAmount(_total.text);
    final tenor = _other ? _num(_custom) : _tenor;
    final day = _num(_day);
    final paid = _num(_paid);
    if (total <= 0 || tenor < 1 || tenor > 120 || day < 1 || day > 31) return null;
    if (paid < 0 || paid > tenor) return null;
    final old = widget.item;
    final today = dayOnly(DateTime.now());
    DateTime firstDue;
    List<String> paidTx;
    if (old != null && old.paidCount == paid) {
      firstDue = old.firstDue;
      paidTx = List<String>.of(old.paidTx);
    } else {
      final base = _nextDayOnOrAfter(day, today);
      firstDue = DateTime(base.year, base.month - paid, 1);
      paidTx = old != null && old.paidCount > paid
          ? old.paidTx.sublist(0, paid)
          : [
              ...?old?.paidTx,
              ...List<String>.filled(paid - (old?.paidCount ?? 0), ''),
            ];
    }
    return Installment(
      id: old?.id ?? 'draft',
      name: _name.text.trim(),
      total: total,
      tenor: tenor,
      dueDay: day,
      firstDue: firstDue,
      accountId: _accountId,
      categoryId: _categoryId,
      paidTx: paidTx,
    );
  }

  void _save() {
    final name = _name.text.trim();
    final total = parseAmount(_total.text);
    final tenor = _other ? _num(_custom) : _tenor;
    final day = _num(_day);
    final paid = _num(_paid);
    String? err;
    if (name.isEmpty) {
      err = 'Isi nama barangnya.';
    } else if (total <= 0) {
      err = 'Total harga harus lebih dari 0.';
    } else if (tenor < 1 || tenor > 120) {
      err = 'Jumlah kali bayar harus antara 1 dan 120.';
    } else if (day < 1 || day > 31) {
      err = 'Tanggal jatuh tempo harus antara 1 dan 31.';
    } else if (paid < 0 || paid > tenor) {
      err = 'Yang sudah dibayar tidak boleh lebih dari jumlah kali bayar.';
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    final d = _draft()!;
    final old = widget.item;
    store.upsertInstallment(Installment(
      id: old?.id ?? store.newId(),
      name: d.name,
      total: d.total,
      tenor: d.tenor,
      dueDay: d.dueDay,
      firstDue: d.firstDue,
      accountId: d.accountId,
      categoryId: d.categoryId,
      paidTx: d.paidTx,
    ));
    Navigator.pop(context);
    snack(context, old == null ? 'Cicilan disimpan' : 'Diperbarui');
  }

  Future<void> _delete() async {
    final x = widget.item!;
    final ok = await confirmDialog(context,
        title: tr('Hapus cicilan {0}?', [x.name]),
        message:
            'Transaksi yang sudah tercatat dari cicilan ini tetap ada di Riwayat.',
        confirmLabel: 'Hapus',
        destructive: true);
    if (!ok || !mounted) return;
    final removed = store.deleteInstallment(x.id);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    if (removed != null) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Text(tr('Cicilan {0} dihapus', [x.name])),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
            label: tr('Urungkan'), onPressed: () => store.restoreInstallment(removed)),
      ));
    }
  }

  Future<void> _pickCategory() async {
    FocusScope.of(context).unfocus();
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      sheetAnimationStyle: AnimationStyle.noAnimation,
      builder: (_) => CategoryPanel(
          store: store,
          type: TxType.expense,
          selectedId: _categoryId,
          accent: C.redDark),
    );
    if (id == null || !mounted) return;
    setState(() => _categoryId = id);
  }

  Widget _pill(String label, bool selected, VoidCallback onTap) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? C.accentDark : C.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: selected ? C.accentDark : C.line, width: 1.5),
              ),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                      color: selected ? Colors.white : C.carbon)),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final d = _draft();
    final cat = store.categoryById(_categoryId);
    return SheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(widget.item == null ? 'Tambah cicilan' : 'Edit cicilan',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900)),
              ),
              if (widget.item != null)
                IconButton(
                  tooltip: tr('Hapus'),
                  onPressed: _delete,
                  icon: Icon(Icons.delete_outline_rounded, color: C.redDark),
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
            textCapitalization: TextCapitalization.words,
            maxLength: 60,
            onChanged: (_) => setState(() => _error = null),
            decoration: fieldDeco('Nama barang', icon: Icons.shopping_bag_rounded)
                .copyWith(counterText: ''),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _total,
            keyboardType: TextInputType.number,
            inputFormatters: [AmountFormatter(decimals: false)],
            onChanged: (_) => setState(() => _error = null),
            decoration:
                fieldDeco('Total harga', icon: Icons.payments_rounded, prefix: 'Rp '),
          ),
          const SizedBox(height: 14),
          Text('Berapa kali bayar (tenor)',
              style: TextStyle(fontSize: 13, color: C.muted)),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final t in _presets)
                _pill(t == 1 ? '1x' : '$t', !_other && _tenor == t, () {
                  FocusScope.of(context).unfocus();
                  setState(() {
                    _other = false;
                    _tenor = t;
                    _error = null;
                  });
                }),
              _pill(tr('Lain'), _other, () => setState(() {
                    _other = true;
                    _error = null;
                  })),
            ],
          ),
          if (_other) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _custom,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 3,
              onChanged: (_) => setState(() => _error = null),
              decoration: fieldDeco('Jumlah kali bayar', icon: Icons.repeat_rounded)
                  .copyWith(counterText: ''),
            ),
          ],
          const SizedBox(height: 4),
          Text(
              'Pilih 1x kalau dibayar sekali di tagihan berikutnya. Atau ketuk Lain untuk jumlah sendiri.',
              style: TextStyle(fontSize: 12, color: C.muted)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
                color: C.income.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          d != null && d.tenor == 1
                              ? tr('Dibayar sekali (bunga 0%)')
                              : tr('Cicilan per bulan (bunga 0%)'),
                          style: TextStyle(fontSize: 12.5, color: C.income)),
                      const SizedBox(height: 2),
                      Text(d == null ? '-' : money(d.perMonth),
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: C.income)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Total dibayar',
                        style: TextStyle(fontSize: 12.5, color: C.income)),
                    Text(d == null ? '-' : money(d.total),
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: C.income)),
                  ],
                ),
              ],
            ),
          ),
          if (d != null && d.tenor > 1 && d.amountOf(d.tenor - 1) != d.perMonth)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                  tr('Cicilan terakhir {0} (menyerap pembulatan).', [money(d.amountOf(d.tenor - 1))]),
                  style: TextStyle(fontSize: 12, color: C.muted)),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _day,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 2,
                  onChanged: (_) => setState(() => _error = null),
                  decoration: fieldDeco('Jatuh tempo tiap tanggal')
                      .copyWith(counterText: ''),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _paid,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 3,
                  onChanged: (_) => setState(() => _error = null),
                  decoration: fieldDeco('Sudah dibayar berapa kali')
                      .copyWith(counterText: ''),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Dibayar dari akun',
              style: TextStyle(fontSize: 13, color: C.muted)),
          const SizedBox(height: 6),
          AccountPicker(
            store: store,
            selectedId: _accountId,
            accent: C.accentDark,
            onSelected: (id) => setState(() => _accountId = id),
          ),
          const SizedBox(height: 4),
          FormRow(
            label: 'Kategori',
            accent: C.accentDark,
            onTap: _pickCategory,
            child: FormValue(cat == null ? null : tr(cat.name), placeholder: 'Opsional'),
          ),
          const SizedBox(height: 8),
          if (d != null)
            Text(
                d.tenor == 1
                    ? tr('Tagihan {0}.', [_instDate(d.dueOf(0))])
                    : tr('Tagihan pertama {0}, lunas {1}.', [_instDate(d.dueOf(0)), _instDate(d.lastDue)]),
                style: TextStyle(fontSize: 12.5, height: 1.4, color: C.muted)),
          Text(
              'Infinity tidak mengambil data dari Shopee. Kamu yang mengisi, dan app mengingatkan tiap jatuh tempo.',
              style: TextStyle(fontSize: 12.5, height: 1.4, color: C.muted)),
          if (_error != null) ...[
            const SizedBox(height: 8),
            ErrorBox(_error!),
          ],
          const SizedBox(height: 14),
          PrimaryButton(label: 'Simpan cicilan', onPressed: _save),
        ],
      ),
    );
  }
}
