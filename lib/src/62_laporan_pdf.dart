part of '../main.dart';

// =============================================================================
// LAPORAN PDF BULANAN (v5.0.3)
// Halaman A4 digambar langsung di kanvas (tanpa package PDF), tiap halaman
// jadi gambar lalu dibungkus PDF sederhana. Dibuat di HP, tidak ada yang
// diunggah. Teksnya berupa gambar, jadi tidak bisa diseleksi.
// =============================================================================

/// Satu halaman: gambar RGB 8-bit yang sudah dikompres zlib (FlateDecode).
class PdfPageImage {
  const PdfPageImage(this.width, this.height, this.flate);
  final int width;
  final int height;
  final Uint8List flate;
}

String _pdfAscii(String s) {
  final b = StringBuffer();
  for (final c in s.codeUnits) {
    if (c == 0x28 || c == 0x29 || c == 0x5C) {
      b.writeCharCode(0x5C);
      b.writeCharCode(c);
    } else if (c >= 32 && c < 127) {
      b.writeCharCode(c);
    }
  }
  return b.toString();
}

/// PDF 1.4 satu gambar penuh per halaman. [pageW] x [pageH] dalam poin.
Uint8List buildImagePdf(List<PdfPageImage> pages,
    {String title = 'Infinity', double pageW = 595, double pageH = 842}) {
  final out = BytesBuilder();
  final n = pages.length;
  final total = 3 + 3 * n; // katalog, daftar halaman, 3 per halaman, info
  final offsets = List<int>.filled(total + 1, 0);
  void s(String t) => out.add(latin1.encode(t));
  void begin(int id) {
    offsets[id] = out.length;
    s('$id 0 obj\n');
  }

  s('%PDF-1.4\n');
  out.add(const [0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A]);
  begin(1);
  s('<< /Type /Catalog /Pages 2 0 R >>\nendobj\n');
  begin(2);
  s('<< /Type /Pages /Count $n /Kids [${[for (var i = 0; i < n; i++) '${3 + 3 * i} 0 R'].join(' ')}] >>\nendobj\n');
  for (var i = 0; i < n; i++) {
    final page = 3 + 3 * i, content = page + 1, image = page + 2;
    final p = pages[i];
    begin(page);
    s('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $pageW $pageH] '
        '/Resources << /XObject << /Im0 $image 0 R >> >> /Contents $content 0 R >>\nendobj\n');
    final draw = 'q $pageW 0 0 $pageH 0 0 cm /Im0 Do Q';
    begin(content);
    s('<< /Length ${draw.length} >>\nstream\n$draw\nendstream\nendobj\n');
    begin(image);
    s('<< /Type /XObject /Subtype /Image /Width ${p.width} /Height ${p.height} '
        '/ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /FlateDecode '
        '/Length ${p.flate.length} >>\nstream\n');
    out.add(p.flate);
    s('\nendstream\nendobj\n');
  }
  final info = total;
  begin(info);
  s('<< /Title (${_pdfAscii(title)}) /Producer (Infinity) >>\nendobj\n');
  final xref = out.length;
  s('xref\n0 ${total + 1}\n0000000000 65535 f \n');
  for (var id = 1; id <= total; id++) {
    s('${offsets[id].toString().padLeft(10, '0')} 00000 n \n');
  }
  s('trailer\n<< /Size ${total + 1} /Root 1 0 R /Info $info 0 R >>\nstartxref\n$xref\n%%EOF\n');
  return out.toBytes();
}

/// Isi laporan satu bulan (dipisah dari penggambaran supaya bisa dites).
class MonthReportData {
  MonthReportData(this.store, DateTime month, DateTime now)
      : month = DateTime(month.year, month.month),
        range = periodRange(DateTime(month.year, month.month)) {
    income = store.sumIDR(TxType.income, range);
    expense = store.sumIDR(TxType.expense, range);
    final dim = range.end.difference(range.start).inDays;
    days = inRange(now, range)
        ? dayOnly(now).difference(range.start).inDays + 1
        : dim;
    categories = store.byTopCategory(TxType.expense, range).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    transactions = store.transactions
        .where((t) => inRange(t.date, range))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  final AppStore store;
  final DateTime month;
  final DateTimeRange range;
  late final double income;
  late final double expense;
  late final int days;
  late final List<MapEntry<String, double>> categories;
  late final List<Transaction> transactions;

  double get net => income - expense;
  double get perDay => days > 0 ? expense / days : 0;
}

/// Nama font untuk teks PDF. Null = font bawaan HP. Dipakai tes CI untuk
/// memuat Roboto supaya hasilnya terbaca.
String? gPdfFont;

/// Batas baris transaksi di PDF supaya tetap ringan.
const int kPdfMaxTxRows = 600;

class _ReportPager {
  _ReportPager(this.footer, {this.scale = 2.0}) {
    _begin();
  }

  static const double w = 595, h = 842, mx = 40, top = 44, bottom = 56;
  static const Color ink = Color(0xFF1F1B3A);
  static const Color soft = Color(0xFF6B7280);
  static const Color green = Color(0xFF0B7A33);
  static const Color red = Color(0xFFC62828);

  final String footer;
  final double scale;
  final List<Future<PdfPageImage>> _pages = [];
  ui.PictureRecorder? _rec;
  Canvas? _c;
  double y = top;
  int pageNo = 0;

  double get limit => h - bottom;

  void _begin() {
    pageNo++;
    _rec = ui.PictureRecorder();
    _c = Canvas(_rec!);
    _c!.scale(scale);
    _c!.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = Colors.white);
    y = top;
  }

  void newPage() {
    _end();
    _begin();
  }

  void _end() {
    y = h - 30;
    text('$footer · ${tr('hal.')} $pageNo', mx, w - mx * 2,
        size: 8, color: soft, align: TextAlign.center);
    final pic = _rec!.endRecording();
    _pages.add(_rasterize(pic));
    _rec = null;
    _c = null;
  }

  Future<PdfPageImage> _rasterize(ui.Picture pic) async {
    final img = await pic.toImage((w * scale).round(), (h * scale).round());
    final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    final wpx = img.width, hpx = img.height;
    final rgba = bd!.buffer.asUint8List();
    final px = wpx * hpx;
    final rgb = Uint8List(px * 3);
    var j = 0;
    for (var i = 0; i < px; i++) {
      final k = i * 4;
      rgb[j++] = rgba[k];
      rgb[j++] = rgba[k + 1];
      rgb[j++] = rgba[k + 2];
    }
    img.dispose();
    pic.dispose();
    return PdfPageImage(wpx, hpx, Uint8List.fromList(zlib.encode(rgb)));
  }

  /// Gambar teks di [y] dan kembalikan tingginya. [align] kanan/tengah dihitung
  /// dari lebar teks sebenarnya.
  double text(String s, double x, double maxW,
      {double size = 10,
      FontWeight weight = FontWeight.w400,
      Color color = ink,
      TextAlign align = TextAlign.left,
      int maxLines = 1,
      bool draw = true}) {
    final p = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(
              fontFamily: gPdfFont,
              fontSize: size,
              fontWeight: weight,
              color: color,
              height: 1.2)),
      textDirection: ui.TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: '...',
    )..layout(maxWidth: maxW);
    if (draw) {
      final dx = switch (align) {
        TextAlign.right => x + maxW - p.width,
        TextAlign.center => x + (maxW - p.width) / 2,
        _ => x,
      };
      p.paint(_c!, Offset(dx, y));
    }
    return p.height;
  }

  void rule({Color color = const Color(0xFFD9DCE3), double weight = 0.7}) {
    _c!.drawLine(Offset(mx, y), Offset(w - mx, y),
        Paint()
          ..color = color
          ..strokeWidth = weight);
  }

  void bar(double frac, {double height = 5, Color color = green}) {
    const width = w - mx * 2;
    _c!.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(mx, y, width, height), const Radius.circular(2)),
        Paint()..color = const Color(0xFFE8EBF0));
    final f = frac.clamp(0.0, 1.0);
    if (f > 0) {
      _c!.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(mx, y, width * f, height),
              const Radius.circular(2)),
          Paint()..color = color);
    }
  }

  void ensure(double need) {
    if (y + need > limit) newPage();
  }

  Future<List<PdfPageImage>> finish() async {
    _end();
    return Future.wait(_pages);
  }
}

Future<Uint8List> buildMonthReportPdf(MonthReportData d,
    {bool withTransactions = true}) async {
  final store = d.store;
  final label = DateFormat('MMMM yyyy', gDateLoc).format(d.month);
  final pg = _ReportPager('Infinity · $label');
  const mx = _ReportPager.mx;
  const cw = _ReportPager.w - mx * 2;
  String dmy(DateTime x) => DateFormat('d MMM yyyy', gDateLoc).format(x);

  // Judul
  pg.y += pg.text(tr('Laporan keuangan'), mx, cw,
      size: 24, weight: FontWeight.w900);
  pg.y += 2;
  pg.y += pg.text(label, mx, cw,
      size: 14, weight: FontWeight.w700, color: _ReportPager.soft);
  if (gPeriodStartDay > 1) {
    pg.y += pg.text(
        '${dmy(d.range.start)} - ${dmy(d.range.end.subtract(const Duration(days: 1)))}',
        mx,
        cw,
        size: 10,
        color: _ReportPager.soft);
  }
  pg.y += 14;

  // Ringkasan
  void sumRow(String label, String value, Color color, {bool big = false}) {
    final hgt = pg.text(label, mx, cw * 0.5,
        size: big ? 13 : 11, weight: FontWeight.w600);
    pg.text(value, mx + cw * 0.5, cw * 0.5,
        size: big ? 15 : 12,
        weight: FontWeight.w900,
        color: color,
        align: TextAlign.right);
    pg.y += hgt + 7;
  }

  sumRow(tr('Pemasukan'), money(d.income), _ReportPager.green);
  sumRow(tr('Pengeluaran'), money(d.expense), _ReportPager.red);
  sumRow(tr('Selisih (net)'),
      '${d.net < 0 ? '-' : '+'}${money(d.net.abs())}',
      d.net < 0 ? _ReportPager.red : _ReportPager.green,
      big: true);
  sumRow(tr('Rata-rata keluar/hari'), money(d.perDay), _ReportPager.ink);
  pg.y += 6;

  // Per kategori
  void section(String title) {
    pg.ensure(60);
    pg.y += pg.text(title, mx, cw, size: 13, weight: FontWeight.w900);
    pg.y += 2;
    pg.rule();
    pg.y += 8;
  }

  section(tr('Pengeluaran per kategori'));
  if (d.categories.isEmpty || d.expense <= 0) {
    pg.y += pg.text(tr('Tidak ada pengeluaran bulan ini.'), mx, cw,
        size: 11, color: _ReportPager.soft);
    pg.y += 10;
  } else {
    for (final e in d.categories) {
      pg.ensure(34);
      final name = tr(store.categoryById(e.key)?.name ?? 'Tanpa kategori');
      final pct = (e.value / d.expense * 100).round();
      final hgt = pg.text(name, mx, cw * 0.55,
          size: 11, weight: FontWeight.w700);
      pg.text('${money(e.value)} · $pct%', mx + cw * 0.55, cw * 0.45,
          size: 11, align: TextAlign.right);
      pg.y += hgt + 3;
      pg.bar(e.value / d.expense);
      pg.y += 12;
    }
  }
  pg.y += 6;

  // Pengeluaran terbesar
  final bigTx = d.transactions.where((t) => t.type == TxType.expense).toList()
    ..sort((a, b) => store
        .toIDR(b.amount, store.currencyOf(b.accountId))
        .compareTo(store.toIDR(a.amount, store.currencyOf(a.accountId))));
  if (bigTx.isNotEmpty) {
    section(tr('Pengeluaran terbesar'));
    for (final t in bigTx.take(5)) {
      pg.ensure(22);
      final hgt = pg.text(
          '${DateFormat('d MMM', gDateLoc).format(t.date)}  ${t.title.isEmpty ? tr(store.categoryById(t.categoryId ?? '')?.name ?? 'Tanpa kategori') : t.title}',
          mx,
          cw * 0.65,
          size: 10.5);
      pg.text(money(t.amount, store.currencyOf(t.accountId)),
          mx + cw * 0.65, cw * 0.35,
          size: 10.5, weight: FontWeight.w800, align: TextAlign.right);
      pg.y += hgt + 5;
    }
    pg.y += 6;
  }

  // Daftar transaksi
  if (withTransactions && d.transactions.isNotEmpty) {
    const cDate = 48.0, cNote = 168.0, cCat = 112.0, cAcc = 70.0;
    const cAmt = cw - cDate - cNote - cCat - cAcc;
    const rowH = 16.0;
    void header() {
      pg.y += pg.text(tr('Daftar transaksi'), mx, cw,
          size: 13, weight: FontWeight.w900);
      pg.y += 2;
      pg.rule();
      pg.y += 5;
      const st = FontWeight.w800;
      pg.text(tr('Tanggal'), mx, cDate, size: 8.5, weight: st, color: _ReportPager.soft);
      pg.text(tr('Catatan'), mx + cDate, cNote, size: 8.5, weight: st, color: _ReportPager.soft);
      pg.text(tr('Kategori'), mx + cDate + cNote, cCat, size: 8.5, weight: st, color: _ReportPager.soft);
      pg.text(tr('Akun'), mx + cDate + cNote + cCat, cAcc, size: 8.5, weight: st, color: _ReportPager.soft);
      pg.text(tr('Jumlah'), mx + cDate + cNote + cCat + cAcc, cAmt, size: 8.5, weight: st, color: _ReportPager.soft, align: TextAlign.right);
      pg.y += 14;
    }

    pg.newPage();
    header();
    final rows = d.transactions.take(kPdfMaxTxRows).toList();
    for (final t in rows) {
      if (pg.y + rowH > pg.limit) {
        pg.newPage();
        header();
      }
      final isTransfer = t.type == TxType.transfer;
      final cat = isTransfer
          ? tr('Transfer')
          : tr(store.categoryById(t.categoryId ?? '')?.name ?? 'Tanpa kategori');
      final note = t.title.isNotEmpty ? t.title : cat;
      final color = switch (t.type) {
        TxType.income => _ReportPager.green,
        TxType.expense => _ReportPager.red,
        _ => _ReportPager.soft,
      };
      final cur = store.currencyOf(t.accountId);
      final sign = t.type == TxType.income ? '+' : (isTransfer ? '' : '-');
      pg.text(DateFormat('d/M', gDateLoc).format(t.date), mx, cDate, size: 8.5);
      pg.text(note, mx + cDate, cNote - 6, size: 8.5);
      pg.text(cat, mx + cDate + cNote, cCat - 6, size: 8.5, color: _ReportPager.soft);
      pg.text(store.accountName(t.accountId), mx + cDate + cNote + cCat, cAcc - 6, size: 8.5, color: _ReportPager.soft);
      pg.text('$sign${money(t.amount, cur)}', mx + cDate + cNote + cCat + cAcc, cAmt,
          size: 8.5, weight: FontWeight.w700, color: color, align: TextAlign.right);
      pg.y += rowH;
    }
    if (d.transactions.length > rows.length) {
      pg.ensure(20);
      pg.y += 4;
      pg.text(
          tr('Dan {0} transaksi lain tidak ditampilkan. Gunakan ekspor Excel untuk daftar lengkap.',
              [d.transactions.length - rows.length]),
          mx,
          cw,
          size: 9,
          color: _ReportPager.soft,
          maxLines: 2);
    }
  }

  final pages = await pg.finish();
  return buildImagePdf(pages,
      title: 'Infinity laporan ${DateFormat('yyyy-MM').format(d.month)}');
}

Future<void> showMonthPdfSheet(
    BuildContext context, AppStore store, DateTime month) {
  return showSheet<void>(context, MonthPdfSheet(store: store, month: month));
}

class MonthPdfSheet extends StatefulWidget {
  const MonthPdfSheet({super.key, required this.store, required this.month});
  final AppStore store;
  final DateTime month;

  @override
  State<MonthPdfSheet> createState() => _MonthPdfSheetState();
}

class _MonthPdfSheetState extends State<MonthPdfSheet> {
  bool _withTx = true;
  bool _busy = false;

  String get _name =>
      'infinity-laporan-${DateFormat('yyyy-MM').format(widget.month)}.pdf';

  Future<Uint8List?> _build() async {
    try {
      final d = MonthReportData(widget.store, widget.month, DateTime.now());
      return await buildMonthReportPdf(d, withTransactions: _withTx);
    } catch (_) {
      return null;
    }
  }

  Future<void> _save({required bool pick}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final bytes = await _build();
    var msg = 'Gagal membuat PDF.';
    if (bytes != null) {
      try {
        if (pick) {
          final saved = await NativeBridge.saveAs(_name, bytes, 'application/pdf');
          msg = saved == null ? '' : 'PDF tersimpan 📄';
        } else {
          final ok =
              await NativeBridge.saveDownloadBytes(_name, bytes, 'application/pdf');
          msg = ok ? 'PDF tersimpan di Download/Infinity 📄' : 'Gagal menyimpan PDF.';
        }
      } catch (_) {
        msg = 'Gagal menyimpan PDF.';
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (msg.isNotEmpty) snack(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('MMMM yyyy', gDateLoc).format(widget.month);
    return SheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Ekspor laporan PDF',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
              tr('Laporan {0}: ringkasan, pengeluaran per kategori, dan daftar transaksi. Dibuat di HP ini, tidak ada yang diunggah.',
                  [label]),
              style: TextStyle(fontSize: 12.5, color: C.muted)),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _withTx,
            onChanged: _busy ? null : (v) => setState(() => _withTx = v),
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: const Text('Sertakan daftar transaksi',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            subtitle: Text(
                tr('Maksimal {0} baris. Teks di PDF berupa gambar, tidak bisa diseleksi.',
                    [kPdfMaxTxRows]),
                style: TextStyle(fontSize: 12.5, color: C.muted)),
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            label: _busy ? 'Membuat PDF...' : 'Simpan ke Download',
            icon: Icons.picture_as_pdf_rounded,
            onPressed: _busy ? null : () => _save(pick: false),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy ? null : () => _save(pick: true),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20))),
            child: const Text('Simpan sebagai... (mis. Google Drive)'),
          ),
        ],
      ),
    );
  }
}
