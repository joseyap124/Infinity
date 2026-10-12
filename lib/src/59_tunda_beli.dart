part of '../main.dart';

// =============================================================================
// TUNDA BELI (v5.0)
// Daftar tunggu sebelum membeli sesuatu yang tidak mendesak. Setelah masa
// tunggu lewat, Infinity mengingatkan sekali: masih mau? "Batal beli" dihitung
// sebagai uang yang tidak jadi keluar. Dimatikan secara bawaan (Pengaturan > Fitur).
// =============================================================================

/// Masa tunggu bawaan (hari).
const int kWaitDefaultDays = 7;

/// Pilihan masa tunggu di form.
const List<int> kWaitPresets = [3, 7, 14, 30];

class WaitItem {
  WaitItem({
    required this.id,
    required this.name,
    required this.price,
    required this.createdAt,
    this.waitDays = kWaitDefaultDays,
    this.status = 'waiting',
    this.decidedAt,
  });

  final String id;
  String name;
  double price;
  final DateTime createdAt;
  int waitDays;

  /// 'waiting' | 'bought' | 'canceled'
  String status;
  DateTime? decidedAt;

  bool get waiting => status == 'waiting';
  bool get canceled => status == 'canceled';

  /// Hari masa tunggu berakhir (awal hari).
  DateTime get readyAt {
    final c = dayOnly(createdAt);
    return DateTime(c.year, c.month, c.day + waitDays);
  }

  /// Sisa hari menunggu, 0 kalau sudah lewat.
  int daysLeft(DateTime now) {
    final d = readyAt.difference(dayOnly(now)).inDays;
    return d < 0 ? 0 : d;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'createdAt': createdAt.toIso8601String(),
        'waitDays': waitDays,
        'status': status,
        if (decidedAt != null) 'decidedAt': decidedAt!.toIso8601String(),
      };

  static WaitItem fromJson(Map<String, dynamic> j) {
    final st = '${j['status']}';
    return WaitItem(
      id: '${j['id']}',
      name: '${j['name'] ?? ''}',
      price: (j['price'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.now(),
      waitDays: ((j['waitDays'] as num?)?.toInt() ?? kWaitDefaultDays).clamp(1, 365),
      status: (st == 'bought' || st == 'canceled') ? st : 'waiting',
      decidedAt: DateTime.tryParse('${j['decidedAt']}'),
    );
  }
}

extension WaitlistStore on AppStore {
  /// Yang masih menunggu, urut dari yang paling cepat lewat masa tunggu.
  List<WaitItem> get waitingItems {
    if (!settings.feature('tunda')) return const <WaitItem>[];
    return waitItems.where((w) => w.waiting).toList()
      ..sort((a, b) => a.readyAt.compareTo(b.readyAt));
  }

  /// Barang yang dibatalkan pada periode (bulan) yang memuat [now].
  List<WaitItem> canceledInPeriod(DateTime now) {
    final r = periodRange(periodLabelOf(now));
    return waitItems
        .where((w) => w.canceled && w.decidedAt != null && inRange(w.decidedAt!, r))
        .toList();
  }

  double canceledTotal(DateTime now) =>
      canceledInPeriod(now).fold(0.0, (s, w) => s + w.price);

  /// Berapa jatah harian berkurang kalau barang ini dibeli sekarang.
  double waitDailyHit(WaitItem w, DateTime now) {
    final days = safeToSpend(now).daysLeft;
    return days < 1 ? w.price : w.price / days;
  }

  void upsertWait(WaitItem w) {
    final i = waitItems.indexWhere((e) => e.id == w.id);
    if (i >= 0) {
      waitItems[i] = w;
    } else {
      waitItems.add(w);
    }
    _commit();
  }

  void decideWait(String id, String status, DateTime at) {
    final i = waitItems.indexWhere((e) => e.id == id);
    if (i < 0) return;
    waitItems[i]
      ..status = status
      ..decidedAt = at;
    _commit();
  }

  void deleteWait(String id) {
    waitItems.removeWhere((e) => e.id == id);
    _commit();
  }
}

class WaitlistPage extends StatelessWidget {
  const WaitlistPage({super.key, required this.store});
  final AppStore store;

  Future<void> _buy(BuildContext context, WaitItem w) async {
    final saved = await openTxForm(context, store,
        prefill: TxDraft(
            type: TxType.expense,
            title: w.name,
            amount: w.price,
            accountId: store.defaultAccountId));
    if (saved) store.decideWait(w.id, 'bought', DateTime.now());
  }

  void _cancel(BuildContext context, WaitItem w) {
    store.decideWait(w.id, 'canceled', DateTime.now());
    snack(
      context,
      tr('Tidak jadi beli {0}. Hemat {1}', [w.name, money(w.price)]),
      action: SnackBarAction(
        label: tr('Urungkan'),
        onPressed: () {
          final i = store.waitItems.indexWhere((e) => e.id == w.id);
          if (i < 0) return;
          store.waitItems[i]
            ..status = 'waiting'
            ..decidedAt = null;
          store.upsertWait(store.waitItems[i]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final now = DateTime.now();
        final hide = store.settings.hideBalance;
        String m(double v) => hide ? 'Rp ••••' : money(v);
        final items = store.waitingItems;
        final canceled = store.canceledInPeriod(now);
        return Scaffold(
          appBar: pageBar('Tunda beli'),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () =>
                showSheet<void>(context, WaitEditorSheet(store: store)),
            backgroundColor: C.accentDark,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Tambah'),
          ),
          body: ListView(
            padding: pagePad(context, 100),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Batal beli bulan ini',
                        style: TextStyle(fontSize: 12, color: C.muted)),
                    Text(m(store.canceledTotal(now)),
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: C.income)),
                    Text(
                        canceled.isEmpty
                            ? 'Belum ada yang dibatalkan'
                            : tr('{0} barang tidak jadi dibeli', [canceled.length]),
                        style: TextStyle(fontSize: 12.5, color: C.muted)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                AppCard(
                  child: EmptyState(
                    icon: Icons.hourglass_bottom_rounded,
                    title: 'Daftar tunggu kosong',
                    subtitle:
                        'Lagi pengin beli sesuatu? Taruh di sini dulu, tunggu beberapa hari, lalu putuskan.',
                  ),
                )
              else
                for (final w in items) ...[
                  _tile(context, w, now, m),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 4),
              Text(
                  'Masa tunggu bawaan 7 hari, bisa diubah per barang. Setelah lewat, Infinity mengingatkan sekali: masih mau? "Jadi beli" membuka form transaksi yang sudah terisi.',
                  style: TextStyle(fontSize: 12, color: C.muted, height: 1.4)),
            ],
          ),
        );
      },
    );
  }

  Widget _tile(BuildContext context, WaitItem w, DateTime now,
      String Function(double) m) {
    final left = w.daysLeft(now);
    return AppCard(
      onTap: () => showSheet<void>(context, WaitEditorSheet(store: store, item: w)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(w.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
              ),
              Text(m(w.price),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
              left > 0
                  ? tr('⏳ Tunggu {0} hari lagi', [left])
                  : '✓ ${tr('Sudah lewat masa tunggu')}',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: left > 0 ? C.muted : C.accentDark)),
          const SizedBox(height: 2),
          Text(
              store.settings.hideBalance
                  ? tr('Jatah harian berkurang kalau dibeli sekarang')
                  : tr('Jatah harian -{0}', [money(store.waitDailyHit(w, now))]),
              style: TextStyle(fontSize: 12, color: C.muted)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => _buy(context, w),
                  style: FilledButton.styleFrom(
                      backgroundColor: C.accentDark,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18))),
                  child: const Text('Jadi beli',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _cancel(context, w),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18))),
                  child: const Text('Batal beli',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class WaitEditorSheet extends StatefulWidget {
  const WaitEditorSheet({super.key, required this.store, this.item});
  final AppStore store;
  final WaitItem? item;

  @override
  State<WaitEditorSheet> createState() => _WaitEditorSheetState();
}

class _WaitEditorSheetState extends State<WaitEditorSheet> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  int _days = kWaitDefaultDays;
  String? _error;

  @override
  void initState() {
    super.initState();
    final w = widget.item;
    if (w != null) {
      _name.text = w.name;
      _price.text = amountToInput(w.price, 'IDR');
      _days = w.waitDays;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final price = parseAmount(_price.text);
    if (name.isEmpty) {
      setState(() => _error = 'Isi nama barangnya.');
      return;
    }
    if (price <= 0) {
      setState(() => _error = 'Isi harganya.');
      return;
    }
    final old = widget.item;
    final store = widget.store;
    if (old != null) {
      old
        ..name = name
        ..price = price
        ..waitDays = _days;
      store.upsertWait(old);
    } else {
      store.upsertWait(WaitItem(
          id: store.newId(),
          name: name,
          price: price,
          createdAt: DateTime.now(),
          waitDays: _days));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(widget.item == null ? 'Tunda beli' : 'Edit barang',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900)),
              ),
              if (widget.item != null)
                IconButton(
                  tooltip: tr('Hapus'),
                  onPressed: () {
                    widget.store.deleteWait(widget.item!.id);
                    Navigator.pop(context);
                  },
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
            controller: _price,
            keyboardType: TextInputType.number,
            inputFormatters: [AmountFormatter(decimals: false)],
            onChanged: (_) => setState(() => _error = null),
            decoration:
                fieldDeco('Harga', icon: Icons.payments_rounded, prefix: 'Rp '),
          ),
          const SizedBox(height: 14),
          Text('Masa tunggu', style: TextStyle(fontSize: 13, color: C.muted)),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final d in kWaitPresets)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: InkWell(
                      onTap: () => setState(() => _days = d),
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 44),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _days == d ? C.accentDark : C.surface,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                              color: _days == d ? C.accentDark : C.line,
                              width: 1.5),
                        ),
                        child: Text(tr('{0} hari', [d]),
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _days == d ? Colors.white : C.carbon)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(tr(_error!),
                style: TextStyle(color: C.redDark, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 16),
          PrimaryButton(label: 'Simpan', onPressed: _save),
        ],
      ),
    );
  }
}
