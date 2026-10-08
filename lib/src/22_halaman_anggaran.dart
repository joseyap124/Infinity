part of '../main.dart';

// =============================================================================
// HALAMAN: ANGGARAN
// =============================================================================

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key, required this.store});
  final AppStore store;

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  AppStore get store => widget.store;
  late BudgetPeriod _period;
  final _globalCtrl = TextEditingController();
  final Map<String, TextEditingController> _catCtrls = {};

  static String _init(double v) => v > 0 ? _plain.format(v.round()) : '';

  @override
  void initState() {
    super.initState();
    final s = store.settings;
    _period = s.budgetPeriod;
    _globalCtrl.text = _init(s.globalBudget);
    for (final c in store.topCategories(TxType.expense)) {
      _catCtrls[c.id] =
          TextEditingController(text: _init(s.categoryBudgets[c.id] ?? 0));
    }
  }

  @override
  void dispose() {
    _globalCtrl.dispose();
    for (final c in _catCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _sumCats =>
      _catCtrls.values.fold(0.0, (s, c) => s + parseAmount(c.text));

  void _save() {
    final per = <String, double>{};
    _catCtrls.forEach((id, ctrl) {
      final v = parseAmount(ctrl.text);
      if (v > 0) per[id] = v;
    });
    store.setBudget(_period, parseAmount(_globalCtrl.text), per);
    Navigator.of(context).pop();
    snack(context, 'Anggaran ${_period.label.toLowerCase()} disimpan 🎯');
  }

  @override
  Widget build(BuildContext context) {
    final global = parseAmount(_globalCtrl.text);
    final over = global > 0 && _sumCats > global;
    return Scaffold(
      appBar: pageBar('Anggaran'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Text(
              'Semua batas dalam Rupiah. Transaksi mata uang lain dikonversi pakai kurs di menu Mata Uang & Kurs. Kosongkan kolom untuk menonaktifkan.',
              style: TextStyle(color: C.muted, fontSize: 13)),
          const SizedBox(height: 14),
          const SmallLabel('Periode anggaran'),
          const SizedBox(height: 8),
          Segmented<BudgetPeriod>(
            values: BudgetPeriod.values,
            selected: _period,
            labelOf: (p) => p.label,
            onChanged: (p) => setState(() => _period = p),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _globalCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [AmountFormatter()],
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontWeight: FontWeight.w800),
            decoration: fieldDeco('Batas total ${_period.label.toLowerCase()}',
                icon: Icons.account_balance_wallet_rounded, prefix: 'Rp '),
          ),
          const SizedBox(height: 18),
          const SmallLabel('Batas per kategori'),
          const SizedBox(height: 10),
          for (final c in store.topCategories(TxType.expense))
            if (_catCtrls[c.id] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    CatIcon(icon: c.iconData, color: c.colorValue, size: 40),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _catCtrls[c.id],
                        keyboardType: TextInputType.number,
                        inputFormatters: [AmountFormatter()],
                        onChanged: (_) => setState(() {}),
                        decoration: fieldDeco(c.name, prefix: 'Rp '),
                      ),
                    ),
                  ],
                ),
              ),
          if (over)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: C.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Total per kategori (${money(_sumCats)}) melebihi batas total (${money(global)}). Boleh disimpan, tapi cek lagi ya ⚠️',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: C.amberDark),
              ),
            ),
          const SizedBox(height: 16),
          PrimaryButton(label: 'Simpan Anggaran', onPressed: _save),
        ],
      ),
    );
  }
}
