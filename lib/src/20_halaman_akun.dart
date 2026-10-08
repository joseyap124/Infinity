part of '../main.dart';

// =============================================================================
// HALAMAN: AKUN
// =============================================================================

class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key, required this.store});
  final AppStore store;

  Widget _item(BuildContext context, Account a, int index) {
    return Padding(
      key: ValueKey('acc_${a.id}'),
      padding: const EdgeInsets.only(bottom: 10),
      child: ReorderableDelayedDragStartListener(
        index: index,
        child: AppCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
          onTap: () => showSheet<void>(
              context, AccountEditorSheet(store: store, account: a)),
          child: Row(
            children: [
              CatIcon(icon: a.type.icon, color: a.colorValue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(a.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                        if (store.defaultAccountId == a.id) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: C.accent.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('Utama',
                                style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: C.accentDark)),
                          ),
                        ],
                      ],
                    ),
                    Text(
                        '${a.type.label} · ${a.currency}${a.type == AccountType.credit ? ' · jatuh tempo tgl ${a.dueDay}' : ''}',
                        style: TextStyle(fontSize: 12, color: C.muted)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(money(store.balanceOf(a.id), a.currency),
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: store.balanceOf(a.id) < 0
                              ? C.redDark
                              : C.carbon)),
                  if (a.currency != 'IDR')
                    Text(
                        '≈ ${money(store.toIDR(store.balanceOf(a.id), a.currency))}',
                        style: TextStyle(fontSize: 11, color: C.muted)),
                ],
              ),
              IconButton(
                tooltip: store.defaultAccountId == a.id
                    ? 'Akun utama'
                    : 'Jadikan akun utama',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  store.updateSettings((x) => x.defaultAccountId = a.id);
                  snack(context,
                      '${a.name} jadi akun utama untuk transaksi baru ⭐');
                },
                icon: Icon(
                    store.defaultAccountId == a.id
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: store.defaultAccountId == a.id
                        ? C.amber
                        : C.muted),
              ),
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Icon(Icons.drag_indicator_rounded, color: C.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pageBar('Akun & Dompet'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            showSheet<void>(context, AccountEditorSheet(store: store)),
        backgroundColor: C.accentDark,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Akun baru'),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
          buildDefaultDragHandles: false,
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                        child: Text('Total saldo bersih',
                            style: TextStyle(color: C.muted))),
                    Text(money(store.netWorthIDR),
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 16)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
                child: Row(
                  children: [
                    Icon(Icons.swap_vert_rounded, size: 16, color: C.muted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                          'Ketuk ☆ untuk jadikan akun utama (otomatis terpilih saat mencatat). Urutkan: tahan lama kartu atau tarik ⠿.',
                          style: TextStyle(fontSize: 12, color: C.muted)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          itemCount: store.accounts.length,
          onReorder: store.moveAccount,
          proxyDecorator: (child, _, __) => Material(
            color: Colors.transparent,
            elevation: 6,
            shadowColor: Colors.black38,
            borderRadius: BorderRadius.circular(24),
            child: child,
          ),
          itemBuilder: (context, i) => _item(context, store.accounts[i], i),
        ),
      ),
    );
  }
}

class AccountEditorSheet extends StatefulWidget {
  const AccountEditorSheet({super.key, required this.store, this.account});
  final AppStore store;
  final Account? account;

  @override
  State<AccountEditorSheet> createState() => _AccountEditorSheetState();
}

class _AccountEditorSheetState extends State<AccountEditorSheet> {
  AppStore get store => widget.store;
  final _nameCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController();
  final _limitCtrl = TextEditingController();
  late AccountType _type;
  late String _currency;
  late int _color;
  late int _dueDay;
  String? _error;
  bool _balTouched = false;

  /// Saldo minus (rekening tekor, atau kartu kredit kelebihan bayar).
  bool _negative = false;

  bool get _editing => widget.account != null;

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _type = a?.type ?? AccountType.bank;
    _currency = a?.currency ?? 'IDR';
    _color = a?.color ?? kPalette[store.accounts.length % kPalette.length];
    _dueDay = a?.dueDay ?? 25;
    _nameCtrl.text = a?.name ?? '';
    if (a != null) {
      // Saat edit, yang ditampilkan saldo SEKARANG (seperti Money Manager).
      final cur = store.balanceOf(a.id);
      final shown = a.type == AccountType.credit ? -cur : cur;
      _negative = shown < 0;
      if (shown != 0) _balanceCtrl.text = amountToInput(shown.abs(), _currency);
      if (a.creditLimit > 0) {
        _limitCtrl.text = amountToInput(a.creditLimit, _currency);
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    _limitCtrl.dispose();
    super.dispose();
  }

  /// Kalkulator yang sama seperti di form transaksi.
  Future<void> _calc(TextEditingController ctrl, {bool balance = false}) async {
    final dec = hasDecimals(_currency);
    final v = await showSheet<double>(
        context, CalculatorSheet(initial: parseAmount(ctrl.text, decimals: dec)));
    if (v == null || !mounted) return;
    setState(() {
      ctrl.text = v.abs() > 0 ? amountToInput(v.abs(), _currency) : '';
      if (balance) _balTouched = true;
    });
  }

  /// 'tx' = catat sebagai transaksi, 'initial' = ubah saldo awal saja.
  Future<String?> _askAdjust(double from, double to) {
    final cur = _currency;
    final diff = to - from;
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Saldo berubah',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${money(from, cur)}  →  ${money(to, cur)}',
                style: TextStyle(fontWeight: FontWeight.w800, color: C.carbon)),
            Text(
                'Selisih ${diff > 0 ? '+' : '-'}${money(diff.abs(), cur)}',
                style: TextStyle(
                    color: diff > 0 ? C.income : C.redDark,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text(
                'Mau dicatat sebagai transaksi "Penyesuaian saldo" (masuk Riwayat & Statistik), atau cukup ubah saldo awal tanpa transaksi?',
                style: TextStyle(fontSize: 13, color: C.muted)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'initial'),
              child: const Text('Ubah saldo awal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'tx'),
            style: FilledButton.styleFrom(
                backgroundColor: C.accentDark,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18))),
            child: const Text('Catat transaksi'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Nama akun wajib diisi.');
      return;
    }
    final dec = hasDecimals(_currency);
    final raw = parseAmount(_balanceCtrl.text, decimals: dec);
    // Kolom hanya menerima angka positif; tanda minus diatur saklar terpisah.
    final input = _negative ? -raw : raw;
    final isCredit = _type == AccountType.credit;
    final old = widget.account;
    var initial = isCredit ? -input : input;
    double adjust = 0;
    if (old != null) {
      initial = old.initialBalance;
      if (_balTouched) {
        final curBal = store.balanceOf(old.id);
        final newBal = isCredit ? -input : input;
        final diff = newBal - curBal;
        if (diff.abs() >= 0.0005) {
          final choice = await _askAdjust(curBal, newBal);
          if (choice == null || !mounted) return;
          if (choice == 'initial') {
            initial = old.initialBalance + diff;
          } else {
            adjust = diff;
          }
        }
      }
    }
    final acc = Account(
      id: old?.id ?? store.newId(),
      name: name,
      type: _type,
      currency: _currency,
      initialBalance: initial,
      color: _color,
      creditLimit: isCredit ? parseAmount(_limitCtrl.text, decimals: dec) : 0,
      dueDay: _dueDay,
    );
    store.upsertAccount(acc);
    if (adjust != 0) store.addBalanceAdjustment(acc, adjust);
    if (old != null && _balTouched) {
      // Notifikasi bank sebelum saat ini sudah termasuk di saldo yang diketik.
      store.updateSettings((x) => x.balanceSetAt[acc.id] =
          DateTime.now().toIso8601String());
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    snack(context, _editing ? 'Akun diperbarui' : 'Akun "$name" ditambahkan');
  }

  Future<void> _delete() async {
    final a = widget.account!;
    final bal = store.balanceOf(a.id);
    final txCount = store.transactions
        .where((t) => t.accountId == a.id || t.toAccountId == a.id)
        .length;
    final inUse = store.accountInUse(a.id);
    final notes = <String>[
      if (bal.abs() >= 0.0005)
        'Saldo sekarang ${money(bal, a.currency)}. Saldo ini ikut hilang dari total saldo.',
      if (txCount > 0)
        '$txCount transaksi di akun ini (termasuk transfer) ikut terhapus.',
      if (inUse && txCount == 0)
        'Transaksi berulang/template yang memakai akun ini ikut terhapus.',
    ];
    final ok = await confirmDialog(context,
        title: 'Hapus akun "${a.name}"?',
        message: notes.isEmpty
            ? 'Akun kosong, aman dihapus.'
            : '${notes.join('\n\n')}\n\nTidak bisa dibatalkan. Salin backup dulu kalau ragu.',
        confirmLabel: txCount > 0 ? 'Hapus semua' : 'Hapus',
        destructive: true);
    if (!ok || !mounted) return;
    final err = store.deleteAccountWithData(a.id);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isCredit = _type == AccountType.credit;
    final dec = hasDecimals(_currency);
    final hasTx = _editing && store.accountInUse(widget.account!.id);
    return SheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_editing ? 'Edit Akun' : 'Akun Baru',
              style:
                  const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: fieldDeco('Nama akun', icon: Icons.badge_rounded),
          ),
          const SizedBox(height: 14),
          const SmallLabel('Jenis'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in AccountType.values)
                ChoiceChip(
                  label: Text(t.label),
                  avatar: Icon(t.icon, size: 16),
                  selected: _type == t,
                  onSelected: (_) => setState(() => _type = t),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const SmallLabel('Mata uang'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in kCurrencies)
                ChoiceChip(
                  label: Text(c),
                  selected: _currency == c,
                  onSelected: (_) => setState(() {
                    final old = parseAmount(_balanceCtrl.text,
                        decimals: hasDecimals(_currency));
                    _currency = c;
                    _balanceCtrl.text =
                        old > 0 ? amountToInput(old, _currency) : '';
                  }),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
            ],
          ),
          if (hasTx && _currency != widget.account!.currency)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                  'Catatan: transaksi lama tidak dikonversi otomatis, nominalnya akan dibaca dalam mata uang baru.',
                  style: TextStyle(fontSize: 12, color: C.amberDark)),
            ),
          const SizedBox(height: 14),
          TextField(
            controller: _balanceCtrl,
            keyboardType: TextInputType.numberWithOptions(decimal: dec),
            inputFormatters: [AmountFormatter(decimals: dec)],
            onChanged: (_) => _balTouched = true,
            decoration: fieldDeco(
                _editing
                    ? (isCredit ? 'Tagihan sekarang' : 'Saldo sekarang')
                    : (isCredit ? 'Tagihan awal (opsional)' : 'Saldo awal'),
                icon: Icons.savings_rounded,
                prefix: '${currencySymbol(_currency)} ',
                helper: _editing
                    ? 'Ubah kalau beda dengan saldo asli. Nanti ditanya: catat sebagai transaksi atau ubah saldo awal saja.'
                    : isCredit
                        ? 'Isi kalau kartu sudah punya tagihan sebelum mulai dicatat.'
                        : 'Saldo saat akun mulai dicatat. Saldo berjalan dihitung otomatis.').copyWith(
              suffixIcon: IconButton(
                tooltip: 'Kalkulator',
                icon: Icon(Icons.calculate_rounded, color: C.accentDark),
                onPressed: () => _calc(_balanceCtrl, balance: true),
              ),
            ),
          ),
          Row(
            children: [
              Checkbox(
                value: _negative,
                onChanged: (v) => setState(() {
                  _negative = v ?? false;
                  _balTouched = true;
                }),
              ),
              Expanded(
                child: Text(
                    isCredit
                        ? 'Kelebihan bayar (tagihan minus)'
                        : 'Saldo minus (rekening tekor)',
                    style: TextStyle(fontSize: 13, color: C.muted)),
              ),
            ],
          ),
          if (isCredit) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _limitCtrl,
              keyboardType: TextInputType.numberWithOptions(decimal: dec),
              inputFormatters: [AmountFormatter(decimals: dec)],
              decoration: fieldDeco('Limit kartu',
                      icon: Icons.speed_rounded,
                      prefix: '${currencySymbol(_currency)} ')
                  .copyWith(
                suffixIcon: IconButton(
                  tooltip: 'Kalkulator',
                  icon: Icon(Icons.calculate_rounded, color: C.accentDark),
                  onPressed: () => _calc(_limitCtrl),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: SmallLabel('Tanggal jatuh tempo')),
                DropdownButton<int>(
                  value: _dueDay,
                  borderRadius: BorderRadius.circular(16),
                  items: [
                    for (var d = 1; d <= 28; d++)
                      DropdownMenuItem(value: d, child: Text('Tanggal $d')),
                  ],
                  onChanged: (v) => setState(() => _dueDay = v ?? _dueDay),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          const SmallLabel('Warna'),
          const SizedBox(height: 8),
          _ColorPicker(
              selected: _color, onSelected: (c) => setState(() => _color = c)),
          if (_error != null) ...[
            const SizedBox(height: 12),
            ErrorBox(_error!),
          ],
          const SizedBox(height: 16),
          PrimaryButton(label: 'Simpan Akun', onPressed: _save),
          if (_editing) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _delete,
              style: TextButton.styleFrom(foregroundColor: C.redDark),
              icon: const Icon(Icons.delete_rounded),
              label: const Text('Hapus akun'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.selected, required this.onSelected});
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final c in kPalette)
          Semantics(
            button: true,
            selected: c == selected,
            label: 'Warna',
            child: GestureDetector(
              onTap: () => onSelected(c),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: c == selected ? C.carbon : Colors.white,
                      width: 3),
                ),
                child: c == selected
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 18)
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}
