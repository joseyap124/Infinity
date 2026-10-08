part of '../main.dart';

// =============================================================================
// IMPORT DARI MONEY MANAGER (file Excel hasil "Ekspor ke Excel")
// Kolom: Date | Account | Category | Subcategory | Note | IDR | Income/Expense
//        | Description | Amount | Currency | Account
// Transfer ditulis sebagai "Transfer-Out" dengan Category = akun tujuan.
// =============================================================================

class MmRow {
  const MmRow({
    required this.date,
    required this.account,
    required this.category,
    required this.subcategory,
    required this.note,
    required this.description,
    required this.kind,
    required this.amount,
    required this.currency,
  });

  final DateTime date;
  final String account;
  final String category;
  final String subcategory;
  final String note;
  final String description;
  final String kind; // Expense | Income | Transfer-Out | Transfer-In | ...
  final double amount;
  final String currency;
}

String _xmlText(String s) => s
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAllMapped(RegExp(r'&#(x?)([0-9A-Fa-f]+);'), (m) {
      final code = int.tryParse(m.group(2)!, radix: m.group(1) == 'x' ? 16 : 10);
      return code == null ? '' : String.fromCharCode(code);
    })
    .replaceAll('&amp;', '&');

/// Pembaca .xlsx minimal (tanpa paket Excel) khusus format Money Manager.
List<MmRow> parseMoneyManagerXlsx(List<int> bytes) {
  final arc = ZipDecoder().decodeBytes(bytes);
  String? read(String name) {
    final f = arc.findFile(name);
    if (f == null) return null;
    return utf8.decode(f.content as List<int>, allowMalformed: true);
  }

  final sheetFile = arc.files
      .where((f) => f.name.startsWith('xl/worksheets/sheet') && f.name.endsWith('.xml'))
      .map((f) => f.name)
      .toList()
    ..sort();
  if (sheetFile.isEmpty) {
    throw const FormatException('Bukan file Excel (.xlsx) yang valid.');
  }
  final sheet = read(sheetFile.first)!;

  final shared = <String>[];
  final sst = read('xl/sharedStrings.xml');
  if (sst != null) {
    for (final si in RegExp(r'<si>(.*?)</si>', dotAll: true).allMatches(sst)) {
      final buf = StringBuffer();
      for (final t in RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true)
          .allMatches(si.group(1)!)) {
        buf.write(_xmlText(t.group(1)!));
      }
      shared.add(buf.toString());
    }
  }

  int colIndex(String letters) {
    var n = 0;
    for (final c in letters.codeUnits) {
      n = n * 26 + (c - 64);
    }
    return n - 1;
  }

  final table = <List<Object?>>[];
  final cellRe = RegExp(
      r'<c r="([A-Z]+)\d+"([^>]*?)(?:/>|>(.*?)</c>)',
      dotAll: true);
  for (final row in RegExp(r'<row[^>]*>(.*?)</row>', dotAll: true)
      .allMatches(sheet)) {
    final cells = <Object?>[];
    for (final c in cellRe.allMatches(row.group(1)!)) {
      final idx = colIndex(c.group(1)!);
      while (cells.length <= idx) {
        cells.add(null);
      }
      final attrs = c.group(2) ?? '';
      final inner = c.group(3) ?? '';
      final t = RegExp(r't="([^"]+)"').firstMatch(attrs)?.group(1) ?? 'n';
      final v = RegExp(r'<v>(.*?)</v>', dotAll: true).firstMatch(inner)?.group(1);
      Object? value;
      if (t == 's' && v != null) {
        final i = int.tryParse(v);
        value = (i != null && i < shared.length) ? shared[i] : '';
      } else if (t == 'inlineStr') {
        value = RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true)
            .allMatches(inner)
            .map((m) => _xmlText(m.group(1)!))
            .join();
      } else if (t == 'str') {
        value = _xmlText(v ?? '');
      } else {
        value = v == null ? null : double.tryParse(v);
      }
      cells[idx] = value;
    }
    table.add(cells);
  }
  if (table.isEmpty) throw const FormatException('File kosong.');

  final header = table.first.map((e) => (e ?? '').toString().trim()).toList();
  int col(String name) => header.indexOf(name);
  final cDate = col('Date'),
      cAcc = col('Account'),
      cCat = col('Category'),
      cSub = col('Subcategory'),
      cNote = col('Note'),
      cIdr = col('IDR'),
      cKind = col('Income/Expense'),
      cDesc = col('Description'),
      cAmt = col('Amount'),
      cCur = col('Currency');
  if (cDate < 0 || cAcc < 0 || cCat < 0 || cKind < 0 || (cAmt < 0 && cIdr < 0)) {
    throw const FormatException(
        'Kolom tidak dikenali. Pastikan file dari Money Manager > Ekspor ke Excel.');
  }

  Object? at(List<Object?> r, int i) => (i >= 0 && i < r.length) ? r[i] : null;
  String str(List<Object?> r, int i) {
    final v = at(r, i);
    if (v == null) return '';
    if (v is double) return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
    return v.toString().trim();
  }

  DateTime? date(Object? v) {
    if (v is double) {
      // Nomor seri Excel (hari sejak 30 Des 1899), waktu lokal.
      return DateTime(1899, 12, 30)
          .add(Duration(milliseconds: (v * 86400000).round()));
    }
    if (v is String) {
      final m = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{4})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?')
          .firstMatch(v);
      if (m != null) {
        return DateTime(
            int.parse(m.group(3)!),
            int.parse(m.group(1)!),
            int.parse(m.group(2)!),
            int.tryParse(m.group(4) ?? '') ?? 12,
            int.tryParse(m.group(5) ?? '') ?? 0,
            int.tryParse(m.group(6) ?? '') ?? 0);
      }
      return DateTime.tryParse(v);
    }
    return null;
  }

  double amount(List<Object?> r) {
    for (final i in [cAmt, cIdr]) {
      final v = at(r, i);
      if (v is double && v > 0) return v;
      if (v is String) {
        final d = double.tryParse(v.replaceAll(',', ''));
        if (d != null && d > 0) return d;
      }
    }
    return 0;
  }

  final out = <MmRow>[];
  for (final r in table.skip(1)) {
    final d = date(at(r, cDate));
    final a = amount(r);
    final kind = str(r, cKind);
    if (d == null || a <= 0 || kind.isEmpty) continue;
    out.add(MmRow(
      date: d,
      account: str(r, cAcc),
      category: str(r, cCat),
      subcategory: str(r, cSub),
      note: str(r, cNote),
      description: str(r, cDesc),
      kind: kind,
      amount: a,
      currency: str(r, cCur).isEmpty ? 'IDR' : str(r, cCur).toUpperCase(),
    ));
  }
  return out;
}

/// Kunci pencocokan nama: huruf kecil, tanpa emoji/tanda baca/keterangan
/// dalam kurung. "Health (Obat, Vitamin) 💊" -> "health".
String mmKey(String name) {
  final noParen = name.replaceAll(RegExp(r'\(.*?\)'), '');
  return noParen.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

class MmImportPlan {
  MmImportPlan();
  final List<Account> newAccounts = [];
  final List<TxCategory> newCategories = [];
  final List<Transaction> transactions = [];
  int expense = 0, income = 0, transfer = 0, skipped = 0, duplicates = 0;
  DateTime? from, to;
}

extension MoneyManagerImport on AppStore {
  /// Susun rencana import tanpa mengubah data (untuk pratinjau).
  MmImportPlan planMoneyManagerImport(List<MmRow> rows) {
    final plan = MmImportPlan();
    final accByKey = <String, Account>{
      for (final a in accounts) a.name.trim().toLowerCase(): a,
    };
    var colorIdx = accounts.length;

    Account accountFor(String rawName, String currency) {
      final name = rawName.trim().isEmpty ? 'Tanpa Akun' : rawName.trim();
      final k = name.toLowerCase();
      final found = accByKey[k];
      if (found != null) return found;
      final lower = name.toLowerCase();
      final isWallet = lower.contains('gopay') ||
          lower.contains('ovo') ||
          lower.contains('dana') ||
          lower.contains('shopeepay') ||
          lower.contains('linkaja') ||
          lower.contains('flip') ||
          lower.contains('wepay');
      final isCash = lower.contains('cash') || lower.contains('tunai') || lower.contains('dompet');
      final isInvest = lower.contains('emas') || lower.contains('reksa') || lower.contains('saham') || lower.contains('tabung');
      final a = Account(
        id: 'mm_acc_${newId()}',
        name: name,
        type: isWallet
            ? AccountType.ewallet
            : isCash
                ? AccountType.cash
                : isInvest
                    ? AccountType.investment
                    : AccountType.bank,
        currency: currency,
        color: kPalette[colorIdx++ % kPalette.length],
      );
      accByKey[k] = a;
      plan.newAccounts.add(a);
      return a;
    }

    // Kategori yang ada + yang baru dibuat selama rencana.
    final allCats = [...categories];
    TxCategory? findCat(TxType type, String name, String? parentId) {
      final k = mmKey(name);
      if (k.isEmpty) return null;
      for (final c in allCats) {
        if (c.type == type && c.parentId == parentId && mmKey(c.name) == k) {
          return c;
        }
      }
      return null;
    }

    String categoryFor(TxType type, String catName, String subName) {
      final cat = catName.trim().isEmpty ? 'Lain lain' : catName.trim();
      var top = findCat(type, cat, null);
      if (top == null) {
        top = TxCategory(
          id: 'mm_cat_${newId()}',
          name: cat,
          type: type,
          icon: 'other',
          color: kPalette[allCats.length % kPalette.length],
        );
        allCats.add(top);
        plan.newCategories.add(top);
      }
      final sub = subName.trim();
      if (sub.isEmpty) return top.id;
      var child = findCat(type, sub, top.id);
      if (child == null) {
        child = TxCategory(
          id: 'mm_cat_${newId()}',
          name: sub,
          type: type,
          icon: top.icon,
          color: top.color,
          parentId: top.id,
        );
        allCats.add(child);
        plan.newCategories.add(child);
      }
      return child.id;
    }

    final existingIds = transactions.map((t) => t.id).toSet();
    for (final r in rows) {
      final kind = r.kind.toLowerCase();
      final TxType type;
      if (kind.startsWith('exp')) {
        type = TxType.expense;
      } else if (kind.startsWith('inc')) {
        type = TxType.income;
      } else if (kind == 'transfer-out') {
        type = TxType.transfer;
      } else {
        // Transfer-In = pasangan Transfer-Out (sudah tercatat), atau jenis lain.
        plan.skipped++;
        continue;
      }
      final from = accountFor(r.account, r.currency);
      final id =
          'mm_${r.date.millisecondsSinceEpoch}_${r.amount.round()}_${type.name}';
      if (existingIds.contains(id)) {
        plan.duplicates++;
        continue;
      }
      existingIds.add(id);

      String? catId;
      String? toId;
      String title;
      if (type == TxType.transfer) {
        final to = accountFor(r.category, r.currency);
        if (to.id == from.id) {
          plan.skipped++;
          continue;
        }
        toId = to.id;
        title = r.note.isNotEmpty ? r.note : 'Transfer ke ${to.name}';
        plan.transfer++;
      } else {
        catId = categoryFor(type, r.category, r.subcategory);
        title = r.note.isNotEmpty
            ? r.note
            : (r.subcategory.isNotEmpty ? r.subcategory : r.category);
        type == TxType.expense ? plan.expense++ : plan.income++;
      }
      plan.transactions.add(Transaction(
        id: id,
        title: title,
        amount: r.amount,
        type: type,
        categoryId: catId,
        accountId: from.id,
        toAccountId: toId,
        date: r.date,
        note: r.description,
      ));
      final f = plan.from, t = plan.to;
      if (f == null || r.date.isBefore(f)) plan.from = r.date;
      if (t == null || r.date.isAfter(t)) plan.to = r.date;
    }
    return plan;
  }

  void applyMoneyManagerImport(MmImportPlan plan) {
    accounts.addAll(plan.newAccounts);
    categories.addAll(plan.newCategories);
    transactions.addAll(plan.transactions);
    _commit();
  }
}

class MoneyManagerImportPage extends StatefulWidget {
  const MoneyManagerImportPage({super.key, required this.store});
  final AppStore store;

  @override
  State<MoneyManagerImportPage> createState() => _MoneyManagerImportPageState();
}

class _MoneyManagerImportPageState extends State<MoneyManagerImportPage> {
  AppStore get store => widget.store;
  MmImportPlan? _plan;
  String? _fileName;
  String? _error;
  bool _busy = false;
  bool _done = false;

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Pemilih file bawaan Android (tanpa paket tambahan).
      final picked = await NativeBridge.pickFile();
      if (picked == null) return;
      final bytes = picked.bytes;
      final rows = parseMoneyManagerXlsx(bytes);
      if (rows.isEmpty) {
        throw const FormatException('Tidak ada transaksi di file ini.');
      }
      setState(() {
        _fileName = picked.name;
        _plan = store.planMoneyManagerImport(rows);
        _done = false;
      });
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error =
          'Gagal membaca file. Pilih file .xlsx hasil Ekspor ke Excel dari Money Manager. ($e)');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _import() {
    final p = _plan;
    if (p == null) return;
    store.applyMoneyManagerImport(p);
    setState(() => _done = true);
    snack(context, '${p.transactions.length} transaksi diimpor ✅');
  }

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
                child: Text(label,
                    style: TextStyle(fontSize: 13.5, color: C.muted))),
            Text(value,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: C.carbon)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = _plan;
    final df = DateFormat('d MMM yyyy', 'id_ID');
    return Scaffold(
      appBar: pageBar('Import Money Manager'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionTitle('Cara ekspor dari Money Manager'),
                const SizedBox(height: 6),
                Text(
                    '1. Buka Money Manager > Lainnya > Backup > Ekspor ke Excel.\n'
                    '2. Pilih rentang tanggal, simpan file .xlsx.\n'
                    '3. Kembali ke sini, tekan Pilih file.\n\n'
                    'Akun dan kategori dicocokkan otomatis berdasarkan nama. Yang belum ada akan dibuat. Import file yang sama dua kali aman: transaksi yang sudah ada dilewati.',
                    style: TextStyle(fontSize: 13, color: C.muted, height: 1.4)),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: _busy ? 'Membaca file...' : 'Pilih file Excel',
                  icon: Icons.upload_file_rounded,
                  onPressed: _busy ? null : _pick,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  ErrorBox(_error!),
                ],
              ],
            ),
          ),
          if (p != null) ...[
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionTitle(_done ? 'Selesai diimpor' : 'Pratinjau'),
                  if (_fileName != null)
                    Text(_fileName!,
                        style: TextStyle(fontSize: 12, color: C.muted)),
                  const SizedBox(height: 8),
                  if (p.from != null && p.to != null)
                    _line('Rentang', '${df.format(p.from!)} - ${df.format(p.to!)}'),
                  _line('Pengeluaran', '${p.expense}'),
                  _line('Pemasukan', '${p.income}'),
                  _line('Transfer', '${p.transfer}'),
                  if (p.duplicates > 0)
                    _line('Sudah ada (dilewati)', '${p.duplicates}'),
                  if (p.skipped > 0) _line('Dilewati', '${p.skipped}'),
                  if (p.newAccounts.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Akun baru: ${p.newAccounts.map((a) => a.name).join(', ')}',
                        style: TextStyle(fontSize: 13, color: C.carbon)),
                  ],
                  if (p.newCategories.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                        'Kategori baru: ${p.newCategories.map((c) => c.name).join(', ')}',
                        style: TextStyle(fontSize: 13, color: C.carbon)),
                  ],
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: C.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                        'Saldo akun dihitung dari transaksi yang diimpor saja. Setelah import, cocokkan saldo tiap akun di Akun & Dompet (ubah saldo awal) supaya sama dengan Money Manager.',
                        style: TextStyle(fontSize: 12.5, color: C.carbon)),
                  ),
                  const SizedBox(height: 12),
                  if (!_done)
                    PrimaryButton(
                      label: 'Import ${p.transactions.length} transaksi',
                      icon: Icons.download_done_rounded,
                      onPressed: p.transactions.isEmpty ? null : _import,
                    )
                  else
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => AccountsPage(store: store))),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20))),
                      child: const Text('Cocokkan saldo di Akun & Dompet'),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
