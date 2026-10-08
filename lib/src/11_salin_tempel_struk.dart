part of '../main.dart';

// =============================================================================
// SALIN & TEMPEL STRUK
// =============================================================================

/// Teks transaksi untuk disalin (misalnya dikirim ke teman saat patungan).
String txShareText(AppStore store, Transaction t) {
  final cur = store.currencyOf(t.accountId);
  final sign =
      t.type == TxType.expense ? '-' : (t.type == TxType.income ? '+' : '');
  final b = StringBuffer()
    ..writeln(t.title)
    ..writeln('$sign${money(t.amount, cur)} · ${t.type.label}')
    ..writeln(t.type == TxType.transfer
        ? '${store.accountName(t.accountId)} → ${store.accountName(t.toAccountId)}'
        : 'Akun: ${store.accountName(t.accountId)}')
    ..writeln('Kategori: ${store.categoryLabel(t)}')
    ..write(DateFormat('EEEE, d MMM yyyy · HH:mm', 'id_ID').format(t.date));
  if (t.note.isNotEmpty) b.write('\nCatatan: ${t.note}');
  return b.toString();
}

class ParsedReceipt {
  const ParsedReceipt(
      {this.amount, this.type, this.accountId, this.title, this.categoryId});
  final double? amount;
  final TxType? type;
  final String? accountId;
  final String? title;
  final String? categoryId;
}

/// Angka gaya Indonesia: "1.250.000", "1.250.000,00", "25000", "25,000".
double? _parseIdNumber(String raw) {
  var s = raw.trim();
  s = s.replaceAll(RegExp(r',\d{1,2}$'), ''); // buang desimal ",00"
  s = s.replaceAll(RegExp(r'[.,\s]'), '');
  return double.tryParse(s);
}

/// Total belanja dari teks struk hasil foto (OCR). Mengutamakan baris
/// "TOTAL"/"GRAND TOTAL"/"TOTAL BAYAR" (bukan subtotal/total item/diskon);
/// angkanya boleh di baris yang sama atau baris berikutnya. Null kalau tidak
/// ketemu. Hasilnya tebakan: tetap dicek user.
double? receiptTotal(String text) {
  final lines = text
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  final numRe = RegExp(r'(\d{1,3}(?:[.,]\d{3})+|\d{4,})(?:[.,]\d{2})?');
  const skip = ['sub', 'item', 'qty', 'disc', 'diskon', 'hemat', 'pajak', 'ppn', 'tax', 'poin', 'point'];
  double? best;
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i].toLowerCase();
    if (!RegExp(r'\btotal\b').hasMatch(l) || skip.any(l.contains)) continue;
    var m = numRe.firstMatch(lines[i]);
    if (m == null && i + 1 < lines.length) m = numRe.firstMatch(lines[i + 1]);
    final v = m == null ? null : _parseIdNumber(m.group(0)!);
    if (v != null && v >= 100 && (best == null || v > best)) best = v;
  }
  return best;
}

/// Nama toko: biasanya baris pertama struk yang berisi huruf.
String? receiptMerchant(String text) {
  for (final raw in text.split('\n').take(4)) {
    final l = raw.trim();
    if (l.length >= 3 &&
        l.length <= 32 &&
        RegExp(r'[A-Za-z]{3}').hasMatch(l) &&
        !RegExp(r'\d{4,}').hasMatch(l)) {
      return l
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
          .join(' ');
    }
  }
  return null;
}

const Map<String, List<String>> _categoryHints = {
  'cafe': ['kopi', 'coffee', 'cafe', 'kafe', 'starbucks', 'janji jiwa', 'kenangan'],
  'makan': ['gofood', 'grabfood', 'shopeefood', 'makan', 'resto', 'warung', 'bakso', 'nasi', 'ayam'],
  'transport': ['goride', 'gocar', 'grabbike', 'grabcar', 'gojek', 'grab', 'maxim', 'parkir', 'jalan tol', 'krl', 'mrt', 'bensin', 'pertamina'],
  'bills': ['pln', 'listrik', 'pdam', 'pulsa', 'kuota', 'paket data', 'indihome', 'token'],
  'shop': ['shopee', 'tokopedia', 'tokped', 'lazada', 'blibli', 'tiktok shop', 'alfamart', 'indomaret', 'uniqlo'],
  'ent': ['netflix', 'spotify', 'youtube premium', 'disney', 'steam', 'bioskop', 'cgv', 'xxi'],
  'health': ['apotek', 'kimia farma', 'guardian', 'obat', 'klinik', 'halodoc'],
  'admin': ['biaya admin', 'admin fee', 'biaya transfer'],
  'refund': ['cashback', 'refund'],
  'gaji': ['gaji', 'salary', 'payroll'],
};

const List<String> _genericAccountWords = [
  'bank', 'kartu', 'kredit', 'utama', 'kantong', 'tabungan', 'dompet', 'rekening',
];

/// Membaca teks struk/notifikasi (GoPay, m-banking, e-commerce) yang disalin
/// user, lalu menebak nominal, tipe, akun, judul, dan kategori. Hasilnya
/// tebakan: user tetap mengecek sebelum menyimpan.
ParsedReceipt parseReceipt(String text, AppStore store) {
  final lower = text.toLowerCase();

  // Nominal: utamakan angka setelah kata "total", kalau tidak ada ambil
  // nominal Rp terbesar.
  double? amount;
  final tm = RegExp(r'\btotal[^0-9\n]{0,25}?(?:rp\.?|idr)?\s*([0-9][0-9.,]*)',
          caseSensitive: false)
      .firstMatch(text);
  if (tm != null) amount = _parseIdNumber(tm.group(1)!);
  if (amount == null || amount <= 0) {
    amount = null;
    for (final m in RegExp(r'(?:rp\.?|idr)\s*([0-9][0-9.,]*)',
            caseSensitive: false)
        .allMatches(text)) {
      final v = _parseIdNumber(m.group(1)!);
      if (v != null && v > 0 && (amount == null || v > amount)) amount = v;
    }
  }

  const incomeWords = [
    'diterima', 'dana masuk', 'transfer masuk', 'uang masuk', 'refund',
    'cashback', 'pengembalian', 'gaji',
  ];
  final type =
      incomeWords.any(lower.contains) ? TxType.income : TxType.expense;

  String? accountId;
  for (final a in store.accounts) {
    if (lower.contains(a.name.toLowerCase())) {
      accountId = a.id;
      break;
    }
  }
  if (accountId == null) {
    for (final a in store.accounts) {
      final words = a.name
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .where((w) => w.length >= 4 && !_genericAccountWords.contains(w));
      if (words.any(lower.contains)) {
        accountId = a.id;
        break;
      }
    }
  }

  String? title;
  final mt = RegExp(
          r'\b(?:pembayaran ke|bayar ke|transfer ke|kirim ke|merchant|penerima|tujuan)\b\s*[:\-]?\s*([A-Za-z0-9][^\n,]{2,40})',
          caseSensitive: false)
      .firstMatch(text);
  if (mt != null) title = mt.group(1)!.trim();

  String? categoryId;
  for (final e in _categoryHints.entries) {
    final cat = store.categoryById(e.key);
    if (cat == null || cat.type != type) continue;
    if (e.value.any(lower.contains)) {
      categoryId = e.key;
      break;
    }
  }

  return ParsedReceipt(
      amount: amount,
      type: type,
      accountId: accountId,
      title: title,
      categoryId: categoryId);
}
