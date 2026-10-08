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
      _ctrls[c] = TextEditingController(text: rateToInput(widget.store.rate(c)))
        ..addListener(() => setState(() {}));
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
      final v = parseRate(e.value.text);
      rates[e.key] = v > 0 ? v : (kDefaultRates[e.key] ?? 1);
    }
    widget.store.setRates(rates);
    Navigator.of(context).pop();
    snack(context, 'Kurs disimpan 💱');
  }

  void _fillDefaults() {
    setState(() {
      for (final e in _ctrls.entries) {
        e.value.text = rateToInput(kDefaultRates[e.key] ?? 1);
      }
    });
    snack(context, 'Diisi kurs BI ${DateFormat('d MMM yyyy', 'id_ID').format(kDefaultRatesDate)}. Tekan Simpan Kurs.');
  }

  @override
  Widget build(BuildContext context) {
    final used = widget.store.accounts.map((a) => a.currency).toSet();
    final at = widget.store.settings.ratesUpdatedAt;
    final days = at == null ? null : DateTime.now().difference(at).inDays;
    return Scaffold(
      appBar: pageBar('Mata Uang & Kurs'),
      body: ListView(
        padding: pagePad(context, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: C.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kurs TIDAK update otomatis (Infinity tanpa internet). Cek kurs terbaru di app bank atau bi.go.id sebulan sekali supaya total saldo, anggaran, dan statistik akurat.',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: C.amberDark),
                ),
                const SizedBox(height: 6),
                Text(
                  at == null
                      ? 'Kurs belum pernah kamu perbarui.'
                      : 'Terakhir diperbarui ${DateFormat('d MMM yyyy', 'id_ID').format(at)} (${days == 0 ? 'hari ini' : '$days hari lalu'}).',
                  style: TextStyle(fontSize: 12.5, color: C.carbon),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _fillDefaults,
            icon: const Icon(Icons.account_balance_rounded),
            label: Text(
                'Isi kurs BI ${DateFormat('d MMM yyyy', 'id_ID').format(kDefaultRatesDate)}'),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20))),
          ),
          const SizedBox(height: 16),
          for (final e in _ctrls.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: e.value,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [RateFormatter()],
                    decoration: fieldDeco(
                      '1 ${e.key} = ... Rupiah${used.contains(e.key) ? ' (dipakai)' : ''}',
                      icon: Icons.currency_exchange_rounded,
                      prefix: 'Rp ',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 14, top: 4),
                    child: Text(
                      parseRate(e.value.text) > 0
                          ? 'Terbaca: 1 ${e.key} = Rp ${rateToInput(parseRate(e.value.text))}'
                          : 'Kosong: pakai kurs bawaan',
                      style: TextStyle(fontSize: 11.5, color: C.muted),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          PrimaryButton(label: 'Simpan Kurs', onPressed: _save),
        ],
      ),
    );
  }
}
