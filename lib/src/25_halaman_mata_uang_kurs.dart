part of '../main.dart';

// =============================================================================
// HALAMAN: MATA UANG & KURS
// =============================================================================

class CurrencyPage extends StatefulWidget {
  const CurrencyPage({super.key, required this.store});
  final AppStore store;

  @override
  State<CurrencyPage> createState() => _CurrencyPageState();
}

class _CurrencyPageState extends State<CurrencyPage> {
  final Map<String, TextEditingController> _ctrls = {};

  @override
  void initState() {
    super.initState();
    for (final c in kCurrencies) {
      if (c == 'IDR') continue;
      final r = widget.store.rate(c);
      var s = r.toStringAsFixed(2);
      if (s.endsWith('.00')) s = s.substring(0, s.length - 3);
      _ctrls[c] = TextEditingController(text: s);
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final rates = <String, double>{};
    for (final e in _ctrls.entries) {
      final v = parseAmount(e.value.text, decimals: true);
      rates[e.key] = v > 0 ? v : (kDefaultRates[e.key] ?? 1);
    }
    widget.store.setRates(rates);
    Navigator.of(context).pop();
    snack(context, 'Kurs disimpan 💱');
  }

  @override
  Widget build(BuildContext context) {
    final used = widget.store.accounts.map((a) => a.currency).toSet();
    return Scaffold(
      appBar: pageBar('Mata Uang & Kurs'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: C.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Kurs bawaan hanya perkiraan dan TIDAK update otomatis. Isi sesuai kurs terbaru supaya total saldo, anggaran, dan statistik akurat.',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: C.amberDark),
            ),
          ),
          const SizedBox(height: 16),
          for (final e in _ctrls.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: e.value,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [AmountFormatter(decimals: true)],
                decoration: fieldDeco(
                  '1 ${e.key} = ... Rupiah${used.contains(e.key) ? ' (dipakai)' : ''}',
                  icon: Icons.currency_exchange_rounded,
                  prefix: 'Rp ',
                ),
              ),
            ),
          const SizedBox(height: 8),
          PrimaryButton(label: 'Simpan Kurs', onPressed: _save),
        ],
      ),
    );
  }
}
