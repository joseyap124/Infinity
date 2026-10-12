part of '../main.dart';

// =============================================================================
// BAGIKAN RINGKASAN BULAN SEBAGAI GAMBAR (v4.4)
// Gambar dibuat di HP lalu dikirim lewat menu bagikan Android. Tidak ada yang
// diunggah oleh Infinity. Nominal disembunyikan secara bawaan.
// =============================================================================

/// Kartu ringkasan satu bulan, lebar tetap supaya hasilnya sama di semua HP.
class MonthShareCard extends StatelessWidget {
  const MonthShareCard(
      {super.key, required this.store, required this.recap, required this.hide});
  final AppStore store;
  final MonthRecap recap;

  /// Sembunyikan nominal rupiah. Persentase tetap tampil.
  final bool hide;

  static const double width = 360;

  @override
  Widget build(BuildContext context) {
    final r = recap;
    String m(double v) => hide ? 'Rp ••••' : money(v);
    final tier = r.tier;
    final rate = r.savingRate;
    final totalExp = r.expense;
    const ink = Color(0xFFFFFFFF);
    final soft = Colors.white.withValues(alpha: 0.72);

    Widget box(String label, String value, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(label), style: TextStyle(fontSize: 11.5, color: soft)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: color)),
                ),
              ],
            ),
          ),
        );

    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0E2F33), Color(0xFF13524B)],
          ),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('∞',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF6EE7B7))),
                const SizedBox(width: 6),
                const Text('Infinity',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: ink)),
                const Spacer(),
                Text(DateFormat('MMMM yyyy', gDateLoc).format(r.month),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: soft)),
              ],
            ),
            const SizedBox(height: 18),
            Text(tr('Ringkasan bulan'),
                style: TextStyle(fontSize: 12.5, color: soft)),
            const SizedBox(height: 2),
            if (rate != null && tier != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${(rate * 100).round()}%',
                      style: const TextStyle(
                          fontSize: 44,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                          color: ink)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Text(
                          rate >= 0
                              ? tr('pemasukan tersisa')
                              : tr('pemasukan terlampaui'),
                          style: TextStyle(fontSize: 13, color: soft)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('${tier.emoji} ${tr(tier.label)}',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6EE7B7))),
            ] else
              Text(m(r.expense),
                  style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: ink)),
            const SizedBox(height: 16),
            Row(
              children: [
                box('Pemasukan', m(r.income), const Color(0xFF6EE7B7)),
                const SizedBox(width: 10),
                box('Pengeluaran', m(r.expense), const Color(0xFFFCA5A5)),
              ],
            ),
            if (r.topCategories.isNotEmpty && totalExp > 0) ...[
              const SizedBox(height: 18),
              Text(tr('Kategori terbesar'),
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: soft)),
              const SizedBox(height: 8),
              for (final e in r.topCategories)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                                shortCategoryName(
                                    store.categoryById(e.key)?.name ??
                                        'Tanpa kategori'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: ink)),
                          ),
                          Text(
                              hide
                                  ? '${(e.value / totalExp * 100).round()}%'
                                  : '${money(e.value)} · ${(e.value / totalExp * 100).round()}%',
                              style: TextStyle(fontSize: 12.5, color: soft)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (e.value / totalExp).clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          valueColor: const AlwaysStoppedAnimation(
                              Color(0xFF6EE7B7)),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 16),
            Text(tr('Dibuat di HP dengan Infinity. Tidak ada yang diunggah.'),
                style: TextStyle(fontSize: 10.5, color: soft)),
          ],
        ),
      ),
    );
  }
}

/// Buka lembar bagikan untuk [month].
Future<void> showMonthShareSheet(
    BuildContext context, AppStore store, DateTime month) {
  return showSheet<void>(context, MonthShareSheet(store: store, month: month));
}

class MonthShareSheet extends StatefulWidget {
  const MonthShareSheet({super.key, required this.store, required this.month});
  final AppStore store;
  final DateTime month;

  @override
  State<MonthShareSheet> createState() => _MonthShareSheetState();
}

class _MonthShareSheetState extends State<MonthShareSheet> {
  final _boundary = GlobalKey();
  bool _hide = true;
  bool _busy = false;

  Future<Uint8List?> _png() async {
    final obj = _boundary.currentContext?.findRenderObject();
    if (obj is! RenderRepaintBoundary) return null;
    final img = await obj.toImage(pixelRatio: 3);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  String get _name =>
      'infinity-ringkasan-${DateFormat('yyyy-MM').format(widget.month)}${_hide ? '' : '-nominal'}.png';

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    final bytes = await _png();
    var ok = false;
    if (bytes != null) ok = await NativeBridge.shareImage(_name, bytes);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) snack(context, 'Tidak bisa membuka menu bagikan. Coba "Simpan ke HP".');
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    final bytes = await _png();
    var ok = false;
    if (bytes != null) {
      ok = await NativeBridge.saveDownloadBytes(_name, bytes, 'image/png');
    }
    if (!mounted) return;
    setState(() => _busy = false);
    snack(context,
        ok ? 'Gambar tersimpan di Download/Infinity 🖼️' : 'Gagal menyimpan gambar.');
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final recap = store.monthRecap(widget.month, DateTime.now());
    return SheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Bagikan ringkasan bulan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('Gambar dibuat di HP ini dan dikirim lewat menu bagikan Android. Tidak ada yang diunggah oleh Infinity.',
              style: TextStyle(fontSize: 12.5, color: C.muted)),
          const SizedBox(height: 12),
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: RepaintBoundary(
                key: _boundary,
                child: MonthShareCard(store: store, recap: recap, hide: _hide),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _hide,
            onChanged: (v) => setState(() => _hide = v),
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: const Text('Sembunyikan nominal',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            subtitle: Text(
                'Hanya persentase yang tampil, jumlah rupiah diganti ••••.',
                style: TextStyle(fontSize: 12.5, color: C.muted)),
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            label: _busy ? 'Menyiapkan...' : 'Bagikan gambar',
            icon: Icons.ios_share_rounded,
            onPressed: _busy ? null : _share,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _save,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Simpan ke HP'),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20))),
          ),
        ],
      ),
    );
  }
}
