part of '../main.dart';

// =============================================================================
// ACARA / TAG (mis. "Trip Bali", "Lebaran 2027", "Nikahan Andi")
// Menjumlah pengeluaran satu acara lintas kategori & akun, dengan anggaran.
// =============================================================================

class TxEvent {
  TxEvent({
    required this.id,
    required this.name,
    required this.start,
    this.end,
    this.budget = 0,
    this.color = 0xFF7C4DFF,
    this.autoTag = true,
  });

  final String id;
  String name;
  DateTime start;

  /// Hari terakhir acara (inklusif). Null = belum ditentukan.
  DateTime? end;

  /// Anggaran dalam Rupiah. 0 = tanpa anggaran.
  double budget;
  int color;

  /// Transaksi baru selama acara berlangsung otomatis ditandai acara ini.
  bool autoTag;

  Color get colorValue => Color(color);

  bool ongoing(DateTime at) {
    final d = dayOnly(at);
    if (d.isBefore(dayOnly(start))) return false;
    final e = end;
    return e == null || !d.isAfter(dayOnly(e));
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'start': start.toIso8601String(),
        'end': end?.toIso8601String(),
        'budget': budget,
        'color': color,
        'autoTag': autoTag,
      };

  factory TxEvent.fromJson(Map<String, dynamic> j) => TxEvent(
        id: j['id'] as String,
        name: _s(j['name']) ?? 'Acara',
        start: DateTime.tryParse(_s(j['start']) ?? '') ?? DateTime.now(),
        end: DateTime.tryParse(_s(j['end']) ?? ''),
        budget: _d(j['budget']),
        color: _i(j['color'], 0xFF7C4DFF),
        autoTag: j['autoTag'] != false,
      );
}

extension EventsStore on AppStore {
  TxEvent? eventById(String? id) {
    if (id == null) return null;
    for (final e in events) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Acara yang sedang berlangsung dan menandai otomatis (yang mulai paling
  /// akhir menang kalau ada beberapa).
  TxEvent? autoEventFor(DateTime at) {
    TxEvent? best;
    for (final e in events) {
      if (!e.autoTag || !e.ongoing(at)) continue;
      if (best == null || e.start.isAfter(best.start)) best = e;
    }
    return best;
  }

  List<Transaction> eventTransactions(String eventId) =>
      transactions.where((t) => t.eventId == eventId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  /// Total pengeluaran acara (Rupiah). Transfer tidak dihitung; pemasukan
  /// (mis. refund) mengurangi.
  double eventSpent(String eventId) {
    var s = 0.0;
    for (final t in transactions) {
      if (t.eventId != eventId) continue;
      if (t.type == TxType.expense) s += amountIDR(t);
      if (t.type == TxType.income) s -= amountIDR(t);
    }
    return s;
  }

  Map<String, double> eventByCategory(String eventId) {
    final out = <String, double>{};
    for (final t in transactions) {
      if (t.eventId != eventId || t.type != TxType.expense) continue;
      for (final (cid, v) in categoryParts(t)) {
        final k = cid == null ? '' : topCategoryId(cid);
        out[k] = (out[k] ?? 0) + v;
      }
    }
    return out;
  }

  void upsertEvent(TxEvent e) {
    final i = events.indexWhere((x) => x.id == e.id);
    if (i >= 0) {
      events[i] = e;
    } else {
      events.add(e);
    }
    _commit();
  }

  /// Hapus acara; transaksinya tetap ada, hanya tandanya yang dilepas.
  void deleteEvent(String id) {
    events.removeWhere((e) => e.id == id);
    transactions = [
      for (final t in transactions) t.eventId == id ? t.withoutEvent() : t
    ];
    _commit();
  }
}

extension on Transaction {
  Transaction withoutEvent() => Transaction(
        id: id,
        title: title,
        amount: amount,
        toAmount: toAmount,
        type: type,
        categoryId: categoryId,
        accountId: accountId,
        toAccountId: toAccountId,
        date: date,
        note: note,
        recurringId: recurringId,
        photos: photos,
      );
}

/// Pilih acara untuk transaksi. Mengembalikan '' untuk "tanpa acara".
Future<String?> pickEvent(BuildContext context, AppStore store, String? current) {
  final list = [...store.events]..sort((a, b) => b.start.compareTo(a.start));
  return showSheet<String>(
    context,
    SheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Acara',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.block_rounded),
            title: const Text('Tanpa acara'),
            selected: current == null,
            onTap: () => Navigator.pop(context, ''),
          ),
          for (final e in list)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: e.colorValue.withValues(alpha: 0.18),
                  child: Icon(Icons.local_activity_rounded,
                      size: 16, color: e.colorValue)),
              title: Text(e.name,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(eventDates(e),
                  style: TextStyle(fontSize: 12, color: C.muted)),
              selected: current == e.id,
              onTap: () => Navigator.pop(context, e.id),
            ),
        ],
      ),
    ),
  );
}

String eventDates(TxEvent e) {
  final df = DateFormat('d MMM yyyy', 'id_ID');
  final end = e.end;
  if (end == null) return 'Mulai ${df.format(e.start)}';
  if (dayOnly(end) == dayOnly(e.start)) return df.format(e.start);
  return '${DateFormat('d MMM', 'id_ID').format(e.start)} – ${df.format(end)}';
}

class EventsPage extends StatelessWidget {
  const EventsPage({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final now = DateTime.now();
        final list = [...store.events]..sort((a, b) {
            final ao = a.ongoing(now), bo = b.ongoing(now);
            if (ao != bo) return ao ? -1 : 1;
            return b.start.compareTo(a.start);
          });
        return Scaffold(
          appBar: pageBar('Acara'),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () =>
                showSheet<void>(context, EventEditorSheet(store: store)),
            backgroundColor: C.accentDark,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Acara baru'),
          ),
          body: ListView(
            padding: pagePad(context, 100),
            children: [
              Text(
                  'Untuk menjumlah pengeluaran satu acara lintas kategori dan akun, mis. liburan, Lebaran, atau nikahan. Selama acara berlangsung, transaksi baru otomatis ditandai (bisa diubah di form catat).',
                  style: TextStyle(color: C.muted, fontSize: 13)),
              const SizedBox(height: 12),
              if (list.isEmpty)
                const AppCard(
                    child: EmptyState(
                        icon: Icons.local_activity_rounded,
                        title: 'Belum ada acara'))
              else
                for (final e in list) _EventCard(store: store, event: e),
            ],
          ),
        );
      },
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard(
      {required this.store, required this.event, this.tappable = true});
  final AppStore store;
  final TxEvent event;
  final bool tappable;

  @override
  Widget build(BuildContext context) {
    final spent = store.eventSpent(event.id);
    final ratio = event.budget > 0 ? spent / event.budget : 0.0;
    final over = event.budget > 0 && spent > event.budget;
    final live = event.ongoing(DateTime.now());
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: tappable
            ? () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    EventDetailPage(store: store, eventId: event.id)))
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CatIcon(
                    icon: Icons.local_activity_rounded,
                    color: event.colorValue,
                    size: 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15)),
                      Text(
                          '${eventDates(event)}${live ? ' · berlangsung' : ''}',
                          style: TextStyle(fontSize: 12, color: C.muted)),
                    ],
                  ),
                ),
                Text(money(spent),
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: over ? C.redDark : C.carbon)),
              ],
            ),
            if (event.budget > 0) ...[
              const SizedBox(height: 10),
              FunProgressBar(
                  value: ratio.clamp(0.0, 1.0).toDouble(),
                  color: over
                      ? C.redDark
                      : (ratio >= 0.8 ? C.amberDark : event.colorValue),
                  height: 8),
              const SizedBox(height: 4),
              Text(
                  over
                      ? 'Lewat ${money(spent - event.budget)} dari anggaran ${money(event.budget)}'
                      : 'Sisa ${money(event.budget - spent)} dari ${money(event.budget)}',
                  style: TextStyle(
                      fontSize: 12, color: over ? C.redDark : C.muted)),
            ],
          ],
        ),
      ),
    );
  }
}

class EventDetailPage extends StatelessWidget {
  const EventDetailPage(
      {super.key, required this.store, required this.eventId});
  final AppStore store;
  final String eventId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final e = store.eventById(eventId);
        if (e == null) {
          return Scaffold(
              appBar: pageBar('Acara'),
              body: const Center(child: Text('Acara sudah dihapus.')));
        }
        final txs = store.eventTransactions(e.id);
        final byCat = store.eventByCategory(e.id).entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final catTotal = byCat.fold(0.0, (s, x) => s + x.value);
        return Scaffold(
          appBar: pageBar(e.name, actions: [
            IconButton(
              tooltip: 'Edit acara',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showSheet<void>(
                  context, EventEditorSheet(store: store, event: e)),
            ),
          ]),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => openTxForm(context, store,
                prefill: TxDraft(
                    type: TxType.expense,
                    accountId: store.defaultAccountId,
                    eventId: e.id)),
            backgroundColor: C.accentDark,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Catat'),
          ),
          body: ListView(
            padding: pagePad(context, 100),
            children: [
              _EventCard(store: store, event: e, tappable: false),
              if (byCat.isNotEmpty)
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionTitle('Per kategori'),
                      const SizedBox(height: 6),
                      for (final c in byCat)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                    store.categoryById(c.key)?.name ??
                                        'Tanpa kategori',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13)),
                              ),
                              Text(
                                  '${catTotal > 0 ? (c.value / catTotal * 100).round() : 0}%',
                                  style: TextStyle(
                                      fontSize: 12, color: C.muted)),
                              const SizedBox(width: 10),
                              Text(money(c.value),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              if (txs.isEmpty)
                const AppCard(
                    child: EmptyState(
                        icon: Icons.receipt_long_rounded,
                        title: 'Belum ada transaksi',
                        subtitle:
                            'Tandai transaksi lewat baris "Acara" di form catat.'))
              else
                for (final t in txs) txTile(context, store, t, showDate: true),
            ],
          ),
        );
      },
    );
  }
}

class EventEditorSheet extends StatefulWidget {
  const EventEditorSheet({super.key, required this.store, this.event});
  final AppStore store;
  final TxEvent? event;

  @override
  State<EventEditorSheet> createState() => _EventEditorSheetState();
}

class _EventEditorSheetState extends State<EventEditorSheet> {
  final _name = TextEditingController();
  final _budget = TextEditingController();
  late DateTime _start;
  DateTime? _end;
  late int _color;
  bool _autoTag = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    final now = DateTime.now();
    _name.text = e?.name ?? '';
    _start = e?.start ?? dayOnly(now);
    _end = e?.end;
    _color = e?.color ??
        kPalette[widget.store.events.length % kPalette.length];
    _autoTag = e?.autoTag ?? true;
    if ((e?.budget ?? 0) > 0) _budget.text = amountToInput(e!.budget, 'IDR');
  }

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool end}) async {
    final initial = end ? (_end ?? _start) : _start;
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    setState(() {
      if (end) {
        _end = d;
      } else {
        _start = d;
        final e = _end;
        if (e != null && e.isBefore(d)) _end = d;
      }
    });
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Nama acara wajib diisi.');
      return;
    }
    final old = widget.event;
    widget.store.upsertEvent(TxEvent(
      id: old?.id ?? widget.store.newId(),
      name: name,
      start: _start,
      end: _end,
      budget: parseAmount(_budget.text),
      color: _color,
      autoTag: _autoTag,
    ));
    Navigator.pop(context);
    snack(context, old == null ? 'Acara dibuat 🎟️' : 'Acara diperbarui');
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM yyyy', 'id_ID');
    final old = widget.event;
    return SheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(old == null ? 'Acara Baru' : 'Edit Acara',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: fieldDeco('Nama (mis. Trip Bali)',
                icon: Icons.local_activity_rounded),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(end: false),
                  child: Text('Mulai: ${df.format(_start)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(end: true),
                  child: Text(_end == null
                      ? 'Selesai: belum'
                      : 'Selesai: ${df.format(_end!)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _budget,
            keyboardType: TextInputType.number,
            inputFormatters: [AmountFormatter()],
            decoration: fieldDeco('Anggaran (opsional)',
                icon: Icons.track_changes_rounded, prefix: 'Rp '),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _autoTag,
            onChanged: (v) => setState(() => _autoTag = v),
            title: const Text('Tandai otomatis selama acara',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            subtitle: Text(
                'Transaksi baru di tanggal acara langsung ditandai acara ini.',
                style: TextStyle(fontSize: 12, color: C.muted)),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in kPalette.take(10))
                GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(c),
                    child: _color == c
                        ? const Icon(Icons.check_rounded,
                            size: 18, color: Colors.white)
                        : null,
                  ),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            ErrorBox(_error!),
          ],
          const SizedBox(height: 14),
          PrimaryButton(label: 'Simpan Acara', onPressed: _save),
          if (old != null)
            TextButton.icon(
              onPressed: () async {
                final ok = await confirmDialog(context,
                    title: 'Hapus acara?',
                    message:
                        'Acara "${old.name}" dihapus. Transaksinya tetap ada, hanya tanda acaranya yang dilepas.',
                    confirmLabel: 'Hapus',
                    destructive: true);
                if (!ok || !context.mounted) return;
                widget.store.deleteEvent(old.id);
                Navigator.pop(context);
              },
              icon: Icon(Icons.delete_outline_rounded, color: C.redDark),
              label: Text('Hapus acara',
                  style: TextStyle(color: C.redDark)),
            ),
        ],
      ),
    );
  }
}
