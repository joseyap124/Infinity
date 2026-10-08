part of '../main.dart';

// =============================================================================
// PATUNGAN / SPLIT BILL
// Kamu bayar dulu, teman ganti belakangan.
// - Bagianmu dicatat sebagai pengeluaran (kategori pilihanmu).
// - Bagian teman dipindah (transfer) ke akun "Talangan Patungan", jadi saldo
//   akun pembayar turun penuh tapi statistik & anggaran hanya menghitung
//   bagianmu. Talangan tetap terhitung sebagai kekayaanmu.
// - Tiap teman jadi piutang. Saat dibayar, uang pindah dari Talangan ke akun
//   penerima.
// =============================================================================

const String kTalanganId = 'talangan';

class SplitShare {
  const SplitShare(this.person, this.amount);
  final String person;
  final double amount;
}

/// Bagi rata dalam rupiah bulat; sisa pembulatan masuk ke bagian pertama
/// (bagianmu kalau kamu ikut).
List<double> splitEvenly(double total, int people) {
  if (people <= 0) return const [];
  final each = (total / people).floorToDouble();
  final rest = total - each * people;
  return [for (var i = 0; i < people; i++) i == 0 ? each + rest : each];
}

extension PatunganStore on AppStore {
  /// Akun penampung talangan, dibuat otomatis saat patungan pertama.
  String ensureTalanganAccount() {
    if (accountById(kTalanganId) != null) return kTalanganId;
    accounts.add(const Account(
      id: kTalanganId,
      name: 'Talangan Patungan',
      type: AccountType.cash,
      color: 0xFFFF8F00,
      excludeSafe: true,
    ));
    return kTalanganId;
  }

  /// Catat patungan. Mengembalikan jumlah piutang yang dibuat.
  int recordSplit({
    required String title,
    required String payerAccountId,
    required String? categoryId,
    required double myShare,
    required List<SplitShare> others,
    DateTime? date,
  }) {
    final at = date ?? DateTime.now();
    final friends = others.where((o) => o.amount > 0).toList();
    final othersTotal = friends.fold(0.0, (s, o) => s + o.amount);
    if (myShare > 0) {
      transactions.add(Transaction(
        id: newId(),
        title: title,
        amount: myShare,
        type: TxType.expense,
        categoryId: categoryId,
        accountId: payerAccountId,
        date: at,
        note: friends.isEmpty
            ? ''
            : 'Patungan, bagianku. Total ${money(myShare + othersTotal, currencyOf(payerAccountId))}',
      ));
    }
    if (othersTotal > 0) {
      final hold = ensureTalanganAccount();
      transactions.add(Transaction(
        id: newId(),
        title: 'Talangan: $title',
        amount: othersTotal,
        type: TxType.transfer,
        accountId: payerAccountId,
        toAccountId: hold,
        date: at,
        note: friends.map((o) => '${o.person} ${money(o.amount)}').join(', '),
      ));
      for (final o in friends) {
        debts.add(Debt(
          id: newId(),
          person: o.person,
          theyOwe: true,
          amount: o.amount,
          date: at,
          note: 'Patungan: $title',
          holdAccountId: hold,
        ));
      }
    }
    _commit();
    return friends.length;
  }

  /// Akun yang dulu membayar talangan untuk piutang patungan [d] (dicari dari
  /// transfer "Talangan: ..." di waktu yang sama). Null kalau tidak ketemu.
  String? splitPayerOf(Debt d) {
    final hold = d.holdAccountId;
    if (hold == null) return null;
    for (final t in transactions) {
      if (t.type == TxType.transfer &&
          t.toAccountId == hold &&
          t.date == d.date &&
          accountById(t.accountId) != null) {
        return t.accountId;
      }
    }
    return null;
  }

  /// Hapus piutang patungan yang belum lunas sambil merapikan sisa uang di
  /// akun Talangan supaya saldonya tetap cocok:
  /// - [returnTo] null: teman tidak bayar, sisanya jadi pengeluaranmu.
  /// - [returnTo] diisi: salah catat, sisanya dikembalikan ke akun itu.
  void deleteSplitDebt(Debt d, {String? returnTo}) {
    final hold = d.holdAccountId;
    final left = d.remaining;
    if (hold != null && accountById(hold) != null && left > 0) {
      if (returnTo != null && accountById(returnTo) != null && returnTo != hold) {
        transactions.add(Transaction(
          id: newId(),
          title: 'Batal patungan: ${d.person}',
          amount: left,
          type: TxType.transfer,
          accountId: hold,
          toAccountId: returnTo,
          date: d.date,
          note: d.note,
        ));
      } else {
        transactions.add(Transaction(
          id: newId(),
          title: 'Patungan tidak dibayar: ${d.person}',
          amount: left,
          type: TxType.expense,
          categoryId: fallbackCategory(TxType.expense),
          accountId: hold,
          date: DateTime.now(),
          note: d.note,
        ));
      }
    }
    debts.removeWhere((x) => x.id == d.id);
    _commit();
  }

  /// Terima pembayaran piutang. Kalau piutang dari patungan, uangnya pindah
  /// dari akun Talangan ke [toAccountId].
  void receiveDebt(Debt d, double amount, {String? toAccountId, DateTime? at}) {
    final paid = math.min(amount, d.remaining);
    if (paid <= 0) return;
    final hold = d.holdAccountId;
    if (hold != null &&
        toAccountId != null &&
        toAccountId != hold &&
        accountById(hold) != null &&
        accountById(toAccountId) != null) {
      transactions.add(Transaction(
        id: newId(),
        title: 'Bayar patungan: ${d.person}',
        amount: paid,
        type: TxType.transfer,
        accountId: hold,
        toAccountId: toAccountId,
        date: at ?? DateTime.now(),
        note: d.note,
      ));
    }
    payDebt(d, paid, at: at);
  }
}

/// Pilih akun penerima untuk pembayaran patungan.
Future<String?> pickReceiveAccount(BuildContext context, AppStore store) {
  final options =
      store.accounts.where((a) => a.id != kTalanganId).toList();
  return showSheet<String>(
    context,
    SheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Uangnya masuk ke akun mana?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          for (final a in options)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CatIcon(icon: a.type.icon, color: a.colorValue, size: 34),
              title: Text(a.name,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              trailing: store.defaultAccountId == a.id
                  ? Text('Utama', style: TextStyle(color: C.muted))
                  : null,
              onTap: () => Navigator.pop(context, a.id),
            ),
        ],
      ),
    ),
  );
}

class PatunganSheet extends StatefulWidget {
  const PatunganSheet({super.key, required this.store});
  final AppStore store;

  @override
  State<PatunganSheet> createState() => _PatunganSheetState();
}

class _PatunganSheetState extends State<PatunganSheet> {
  AppStore get store => widget.store;
  final _title = TextEditingController();
  final _total = TextEditingController();
  final _person = TextEditingController();
  final _personFocus = FocusNode();
  final List<String> _people = [];
  final Map<String, TextEditingController> _shareCtrls = {};
  bool _includeMe = true;
  bool _custom = false;
  late String _payer;
  String? _category;
  String? _error;

  @override
  void initState() {
    super.initState();
    _payer = store.accountById(store.defaultAccountId)?.id ??
        store.accounts.firstWhere((a) => a.id != kTalanganId,
            orElse: () => store.accounts.first).id;
    final cats = _expenseCats();
    _category = cats.any((c) => c.id == 'makan')
        ? 'makan'
        : (cats.isEmpty ? null : cats.first.id);
  }

  @override
  void dispose() {
    _title.dispose();
    _total.dispose();
    _person.dispose();
    _personFocus.dispose();
    for (final c in _shareCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<TxCategory> _expenseCats() =>
      store.categories.where((c) => c.type == TxType.expense).toList();

  String _catLabel(TxCategory c) {
    final p = store.categoryById(c.parentId);
    return p == null ? c.name : '${p.name} › ${c.name}';
  }

  double get _totalValue => parseAmount(_total.text);

  /// Bagian tiap teman (rata atau diisi sendiri) dan bagianku = sisanya.
  (double, List<SplitShare>) _shares() {
    final total = _totalValue;
    if (_custom) {
      final others = [
        for (final p in _people)
          SplitShare(p, parseAmount(_shareCtrls[p]?.text ?? '')),
      ];
      final sum = others.fold(0.0, (s, o) => s + o.amount);
      return (_includeMe ? total - sum : 0, others);
    }
    final n = _people.length + (_includeMe ? 1 : 0);
    final parts = splitEvenly(total, n);
    if (parts.isEmpty) return (0, const []);
    if (_includeMe) {
      return (
        parts.first,
        [for (var i = 0; i < _people.length; i++) SplitShare(_people[i], parts[i + 1])]
      );
    }
    // Kamu tidak ikut: sisa pembulatan masuk ke orang pertama.
    return (0, [for (var i = 0; i < _people.length; i++) SplitShare(_people[i], parts[i])]);
  }

  void _addPerson() {
    final name = _person.text.trim();
    if (name.isEmpty) return;
    if (_people.any((p) => p.toLowerCase() == name.toLowerCase())) {
      setState(() => _error = '$name sudah ada.');
      return;
    }
    setState(() {
      _people.add(name);
      _shareCtrls[name] = TextEditingController();
      _person.clear();
      _error = null;
    });
    // Tetap di kolom nama supaya bisa langsung ketik teman berikutnya.
    _personFocus.requestFocus();
  }

  void _removePerson(String p) {
    setState(() {
      _people.remove(p);
      _shareCtrls.remove(p)?.dispose();
    });
  }

  void _save() {
    final title = _title.text.trim().isEmpty ? 'Patungan' : _title.text.trim();
    final total = _totalValue;
    if (total <= 0) {
      setState(() => _error = 'Isi total tagihannya.');
      return;
    }
    if (_people.isEmpty) {
      setState(() => _error = 'Tambahkan minimal satu teman.');
      return;
    }
    final (mine, others) = _shares();
    final sum = mine + others.fold(0.0, (s, o) => s + o.amount);
    if (mine < 0 || (sum - total).abs() > 0.5) {
      setState(() => _error =
          'Jumlah bagian (${money(sum)}) tidak sama dengan total (${money(total)}).');
      return;
    }
    final n = store.recordSplit(
      title: title,
      payerAccountId: _payer,
      categoryId: _category,
      myShare: mine,
      others: others,
    );
    Navigator.pop(context);
    snack(context, 'Patungan dicatat: $n piutang 🤝');
  }

  @override
  Widget build(BuildContext context) {
    final (mine, others) = _shares();
    final cats = _expenseCats();
    final payers = store.accounts.where((a) => a.id != kTalanganId).toList();
    return SheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Patungan',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              ),
              IconButton(
                tooltip: 'Tutup',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          Text(
              'Kamu bayar dulu, teman ganti belakangan. Bagianmu jadi pengeluaran, bagian teman jadi piutang.',
              style: TextStyle(fontSize: 12.5, color: C.muted)),
          const SizedBox(height: 14),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: fieldDeco('Untuk apa (mis. Makan malam)',
                icon: Icons.restaurant_rounded),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _total,
            keyboardType: TextInputType.number,
            inputFormatters: [AmountFormatter()],
            onChanged: (_) => setState(() {}),
            decoration: fieldDeco('Total tagihan',
                icon: Icons.receipt_long_rounded, prefix: 'Rp '),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _payer,
            isExpanded: true,
            decoration: fieldDeco('Dibayar dari',
                icon: Icons.account_balance_wallet_rounded),
            items: [
              for (final a in payers)
                DropdownMenuItem(value: a.id, child: Text(a.name)),
            ],
            onChanged: (v) => setState(() => _payer = v ?? _payer),
          ),
          const SizedBox(height: 10),
          if (cats.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: _category,
              isExpanded: true,
              decoration:
                  fieldDeco('Kategori bagianmu', icon: Icons.category_rounded),
              items: [
                for (final c in cats)
                  DropdownMenuItem(
                      value: c.id,
                      child: Text(_catLabel(c),
                          overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _category = v),
            ),
          const SizedBox(height: 14),
          const SmallLabel('Ikut patungan'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _person,
                  focusNode: _personFocus,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  // Ganti perilaku bawaan (pindah fokus) dengan tambah teman.
                  onEditingComplete: _addPerson,
                  decoration: fieldDeco('Nama teman',
                      icon: Icons.person_add_alt_rounded),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Tambah',
                onPressed: _addPerson,
                style: IconButton.styleFrom(backgroundColor: C.accentDark),
                icon: const Icon(Icons.add_rounded, color: Colors.white),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _includeMe,
            onChanged: (v) => setState(() => _includeMe = v),
            title: const Text('Aku ikut makan / pakai',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            subtitle: Text(
                _includeMe
                    ? 'Bagianmu dicatat sebagai pengeluaran.'
                    : 'Kamu cuma menalangi; semua jadi piutang.',
                style: TextStyle(fontSize: 12, color: C.muted)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _custom,
            onChanged: (v) => setState(() {
              _custom = v;
              if (v) {
                // Mulai dari pembagian rata supaya tinggal diubah.
                final (_, even) = _shares();
                for (final o in even) {
                  _shareCtrls[o.person]?.text =
                      o.amount > 0 ? amountToInput(o.amount, 'IDR') : '';
                }
              }
            }),
            title: const Text('Atur bagian masing-masing',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            subtitle: Text('Mati = dibagi rata.',
                style: TextStyle(fontSize: 12, color: C.muted)),
          ),
          if (_people.isNotEmpty) ...[
            const SizedBox(height: 4),
            if (_includeMe)
              _row('Aku', mine, null, mine < 0 ? C.redDark : C.carbon),
            for (final o in others)
              _custom
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _shareCtrls[o.person],
                              keyboardType: TextInputType.number,
                              inputFormatters: [AmountFormatter()],
                              onChanged: (_) => setState(() {}),
                              decoration:
                                  fieldDeco(o.person, prefix: 'Rp '),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Hapus ${o.person}',
                            onPressed: () => _removePerson(o.person),
                            icon: Icon(Icons.close_rounded, color: C.muted),
                          ),
                        ],
                      ),
                    )
                  : _row(o.person, o.amount, () => _removePerson(o.person),
                      C.income),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            ErrorBox(_error!),
          ],
          const SizedBox(height: 14),
          PrimaryButton(label: 'Simpan Patungan', onPressed: _save),
        ],
      ),
    );
  }

  Widget _row(String name, double amount, VoidCallback? onRemove, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.person_rounded, size: 18, color: C.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(name,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          Text(money(amount),
              style: TextStyle(fontWeight: FontWeight.w900, color: color)),
          if (onRemove != null)
            IconButton(
              tooltip: 'Hapus $name',
              visualDensity: VisualDensity.compact,
              onPressed: onRemove,
              icon: Icon(Icons.close_rounded, size: 18, color: C.muted),
            )
          else
            const SizedBox(width: 40),
        ],
      ),
    );
  }
}
