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
        padding: pagePad(context, 32),
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
          const SizedBox(height: 10),
          PeriodStartTile(store: store, onChanged: () => setState(() {})),
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


/// Pengaturan "Awal bulan keuangan" (tanggal gajian).
class PeriodStartTile extends StatelessWidget {
  const PeriodStartTile({super.key, required this.store, this.onChanged});
  final AppStore store;
  final VoidCallback? onChanged;

  Future<void> _pick(BuildContext context) async {
    final cur = store.settings.periodStartDay;
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Bulan keuangan mulai tanggal',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 4),
              Text(
                  'Pilih tanggal gajian. Anggaran, Statistik bulanan, Aman dibelanjakan, dan rekap dihitung dari tanggal ini sampai sehari sebelum tanggal yang sama bulan berikutnya.',
                  style: TextStyle(fontSize: 12.5, color: C.muted)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var d = 1; d <= 28; d++)
                    ChoiceChip(
                      label: Text('$d'),
                      selected: d == cur,
                      onSelected: (_) => Navigator.pop(ctx, d),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                  'Gajian tanggal 29-31? Pilih 28 atau tanggal yang selalu sudah gajian.',
                  style: TextStyle(fontSize: 12, color: C.muted)),
            ],
          ),
        ),
      ),
    );
    if (picked == null || picked == cur) return;
    store.updateSettings((x) => x.periodStartDay = picked);
    onChanged?.call();
    if (!context.mounted) return;
    final l = periodLabelOf(DateTime.now());
    snack(
        context,
        picked == 1
            ? 'Bulan keuangan kembali ke bulan kalender 📅'
            : 'Bulan ini: ${DateFormat('MMMM', 'id_ID').format(l)} (${periodSpanText(l)}) 📅');
  }

  @override
  Widget build(BuildContext context) {
    final d = store.settings.periodStartDay;
    final l = periodLabelOf(DateTime.now());
    return AppCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        onTap: () => _pick(context),
        leading: const Icon(Icons.event_repeat_rounded),
        title: const Text('Awal bulan keuangan',
            style: TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(d == 1
            ? 'Tanggal 1 (bulan kalender). Ketuk untuk pakai tanggal gajian.'
            : 'Tanggal $d. Bulan ini: ${periodSpanText(l)}'),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
