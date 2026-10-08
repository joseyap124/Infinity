part of '../main.dart';

// =============================================================================
// EKSPOR EXCEL & RINGKASAN BULANAN (v1.6)
// =============================================================================

String _xmlEsc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    // Karakter kontrol tidak boleh ada di XML.
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

String _colName(int i) {
  var n = i + 1;
  var out = '';
  while (n > 0) {
    final r = (n - 1) % 26;
    out = String.fromCharCode(65 + r) + out;
    n = (n - 1) ~/ 26;
  }
  return out;
}

/// File .xlsx minimal (satu sheet, teks inline) tanpa paket Excel.
List<int> buildXlsx(String sheetName, List<List<Object?>> rows) {
  final sb = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<sheetData>');
  for (var r = 0; r < rows.length; r++) {
    sb.write('<row r="${r + 1}">');
    for (var c = 0; c < rows[r].length; c++) {
      final v = rows[r][c];
      final ref = '${_colName(c)}${r + 1}';
      if (v == null) continue;
      if (v is num) {
        sb.write('<c r="$ref"><v>$v</v></c>');
      } else {
        sb.write('<c r="$ref" t="inlineStr"><is><t xml:space="preserve">'
            '${_xmlEsc(v.toString())}</t></is></c>');
      }
    }
    sb.write('</row>');
  }
  sb.write('</sheetData></worksheet>');

  final files = <String, String>{
    '[Content_Types].xml':
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
            '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
            '<Default Extension="xml" ContentType="application/xml"/>'
            '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
            '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
            '</Types>',
    '_rels/.rels': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
        '</Relationships>',
    'xl/workbook.xml': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<sheets><sheet name="${_xmlEsc(sheetName)}" sheetId="1" r:id="rId1"/></sheets></workbook>',
    'xl/_rels/workbook.xml.rels':
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
            '</Relationships>',
    'xl/worksheets/sheet1.xml': sb.toString(),
  };
  final arc = Archive();
  files.forEach((name, text) {
    final b = utf8.encode(text);
    arc.addFile(ArchiveFile(name, b.length, b));
  });
  final List<int>? zip = ZipEncoder().encode(arc);
  return zip!;
}

extension ExportSummaryStore on AppStore {
  /// Baris Excel berformat ekspor Money Manager (bisa diimpor ulang ke
  /// Infinity). Transfer ditulis "Transfer-Out" dengan Category = akun tujuan.
  List<List<Object?>> exportRows(DateTimeRange? range) {
    final rows = <List<Object?>>[
      ['Date', 'Account', 'Category', 'Subcategory', 'Note', 'IDR',
        'Income/Expense', 'Description', 'Amount', 'Currency'],
    ];
    final txs = transactions
        .where((t) => range == null || inRange(t.date, range))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final df = DateFormat('MM/dd/yyyy HH:mm:ss');
    for (final t in txs) {
      String cat = '', sub = '';
      if (t.type == TxType.transfer) {
        cat = accountName(t.toAccountId);
      } else {
        final c = categoryById(t.categoryId);
        if (c != null) {
          final pid = c.parentId;
          final p = pid == null ? null : categoryById(pid);
          if (p != null) {
            cat = p.name;
            sub = c.name;
          } else {
            cat = c.name;
          }
        }
      }
      rows.add([
        df.format(t.date),
        accountName(t.accountId),
        cat,
        sub,
        t.title,
        amountIDR(t),
        switch (t.type) {
          TxType.expense => 'Expense',
          TxType.income => 'Income',
          TxType.transfer => 'Transfer-Out',
        },
        t.note,
        t.amount,
        currencyOf(t.accountId),
      ]);
    }
    return rows;
  }

  /// Bulan ini (s.d. hari ini) vs periode yang sama bulan lalu.
  MonthCompare monthCompare(DateTime now) {
    final thisStart = DateTime(now.year, now.month, 1);
    final thisEnd = DateTime(now.year, now.month, now.day + 1);
    final lastStart = DateTime(now.year, now.month - 1, 1);
    final lastMonthDays = DateTime(now.year, now.month, 0).day;
    final lastEnd = DateTime(
        now.year, now.month - 1, math.min(now.day, lastMonthDays) + 1);
    final cur = DateTimeRange(start: thisStart, end: thisEnd);
    final prev = DateTimeRange(start: lastStart, end: lastEnd);

    Map<String, double> byCat(DateTimeRange r) {
      final m = <String, double>{};
      for (final t in transactions) {
        if (t.type != TxType.expense || !inRange(t.date, r)) continue;
        final cid = t.categoryId;
        final top = cid == null ? '' : topCategoryId(cid);
        m[top] = (m[top] ?? 0) + amountIDR(t);
      }
      return m;
    }

    final a = byCat(cur), b = byCat(prev);
    final changes = <(String, double, double)>[];
    for (final k in {...a.keys, ...b.keys}) {
      changes.add((k, a[k] ?? 0, b[k] ?? 0));
    }
    changes.sort((x, y) => (y.$2 - y.$3).compareTo(x.$2 - x.$3));
    return MonthCompare(
      expenseNow: a.values.fold(0.0, (s, v) => s + v),
      expenseBefore: b.values.fold(0.0, (s, v) => s + v),
      incomeNow: sumIDR(TxType.income, cur),
      incomeBefore: sumIDR(TxType.income, prev),
      day: now.day,
      changes: changes,
    );
  }

  Future<bool> exportExcel(DateTimeRange? range, String label) async {
    final bytes = buildXlsx('Infinity', exportRows(range));
    final stamp = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
    return NativeBridge.saveDownloadBytes(
        'infinity-$label-$stamp.xlsx',
        Uint8List.fromList(bytes),
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  }
}

class MonthCompare {
  const MonthCompare({
    required this.expenseNow,
    required this.expenseBefore,
    required this.incomeNow,
    required this.incomeBefore,
    required this.day,
    required this.changes,
  });
  final double expenseNow, expenseBefore, incomeNow, incomeBefore;
  final int day;

  /// (id kategori induk, bulan ini, bulan lalu), urut kenaikan terbesar.
  final List<(String, double, double)> changes;

  double? get expensePct =>
      expenseBefore <= 0 ? null : (expenseNow - expenseBefore) / expenseBefore * 100;
}

/// Kartu Beranda: pengeluaran bulan ini dibanding bulan lalu (hari yang sama).
class MonthCompareCard extends StatelessWidget {
  const MonthCompareCard({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final m = store.monthCompare(DateTime.now());
    if (m.expenseNow <= 0 && m.expenseBefore <= 0) return const SizedBox.shrink();
    final pct = m.expensePct;
    final up = m.expenseNow > m.expenseBefore;
    final color = up ? C.redDark : C.income;
    final rising = m.changes.where((c) => c.$2 - c.$3 > 0).take(3).toList();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Dibanding bulan lalu',
                    style: TextStyle(fontWeight: FontWeight.w800, color: C.carbon)),
              ),
              Text('s.d. tgl ${m.day}',
                  style: TextStyle(fontSize: 12, color: C.muted)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pengeluaran bulan ini',
                        style: TextStyle(fontSize: 12, color: C.muted)),
                    Text(money(m.expenseNow),
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: C.carbon)),
                    Text('Bulan lalu ${money(m.expenseBefore)}',
                        style: TextStyle(fontSize: 12, color: C.muted)),
                  ],
                ),
              ),
              if (pct != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                          up
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          size: 18,
                          color: color),
                      const SizedBox(width: 4),
                      Text('${pct.abs().toStringAsFixed(0)}%',
                          style: TextStyle(
                              fontWeight: FontWeight.w900, color: color)),
                    ],
                  ),
                ),
            ],
          ),
          if (rising.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Naik paling banyak',
                style: TextStyle(fontSize: 12, color: C.muted)),
            const SizedBox(height: 4),
            for (final c in rising)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                          store.categoryById(c.$1)?.name ?? 'Tanpa kategori',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: C.carbon)),
                    ),
                    Text('+${money(c.$2 - c.$3)}',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: C.redDark)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Kartu di halaman Backup: ekspor transaksi ke Excel (Download/Infinity).
class ExportExcelCard extends StatefulWidget {
  const ExportExcelCard({super.key, required this.store});
  final AppStore store;

  @override
  State<ExportExcelCard> createState() => _ExportExcelCardState();
}

class _ExportExcelCardState extends State<ExportExcelCard> {
  String _range = 'month';
  bool _busy = false;

  Future<void> _export() async {
    final now = DateTime.now();
    final (DateTimeRange? r, String label) = switch (_range) {
      'month' => (monthRange(now), DateFormat('yyyy-MM').format(now)),
      'year' => (yearRange(now), '${now.year}'),
      _ => (null, 'semua'),
    };
    setState(() => _busy = true);
    final ok = await widget.store.exportExcel(r, label);
    if (!mounted) return;
    setState(() => _busy = false);
    snack(context,
        ok ? 'Excel tersimpan di Download/Infinity 📊' : 'Gagal menyimpan file Excel.');
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('Ekspor ke Excel'),
          const SizedBox(height: 4),
          Text(
              'Kolom sama seperti ekspor Money Manager, jadi bisa dibuka di Excel/Google Sheets atau diimpor ulang ke Infinity.',
              style: TextStyle(fontSize: 12.5, color: C.muted)),
          const SizedBox(height: 10),
          Segmented<String>(
            values: const ['month', 'year', 'all'],
            selected: _range,
            labelOf: (v) => switch (v) {
              'month' => 'Bulan ini',
              'year' => 'Tahun ini',
              _ => 'Semua',
            },
            dense: true,
            onChanged: (v) => setState(() => _range = v),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : _export,
            icon: const Icon(Icons.table_view_rounded),
            label: Text(_busy ? 'Menyimpan...' : 'Ekspor .xlsx'),
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
