part of '../main.dart';

// =============================================================================
// FORMAT & PARSING
// =============================================================================

const List<String> kCurrencies = [
  'IDR', 'USD', 'SGD', 'MYR', 'CNY', 'TWD', 'AUD', 'EUR', 'JPY',
];

/// Kurs bawaan ke Rupiah: kurs tengah Bank Indonesia 7 Okt 2026 (rata-rata
/// kurs jual dan beli). TWD tidak ada di daftar BI, dihitung silang dari USD.
/// TIDAK update otomatis (app offline); ubah di menu Mata Uang & Kurs.
const Map<String, double> kDefaultRates = {
  'IDR': 1,
  'USD': 17910,
  'SGD': 14008,
  'MYR': 4383,
  'CNY': 2671,
  'TWD': 564,
  'AUD': 12496,
  'EUR': 20133,
  'JPY': 113.28,
};

/// Jumlah backup otomatis yang disimpan di Download/Infinity.
const int kKeepBackups = 8;

/// Tanggal kurs bawaan di atas.
final DateTime kDefaultRatesDate = DateTime(2026, 10, 7);

String currencySymbol(String c) {
  const symbols = {
    'IDR': 'Rp',
    'USD': 'US\$',
    'SGD': 'S\$',
    'MYR': 'RM',
    'CNY': 'CN¥',
    'TWD': 'NT\$',
    'AUD': 'A\$',
    'EUR': '€',
    'JPY': 'JP¥',
  };
  return symbols[c] ?? c;
}

/// Rupiah, Yen, dan Dolar Taiwan dipakai tanpa sen.
bool hasDecimals(String currency) =>
    currency != 'IDR' && currency != 'JPY' && currency != 'TWD';

final NumberFormat _plain = NumberFormat.decimalPattern('id_ID');
final NumberFormat _compact = NumberFormat.compact(locale: 'id_ID');
final Map<String, NumberFormat> _moneyFormats = {};

/// Format uang: Rp 1.250.000 / US$ 12,50 (minus di depan simbol).
String money(double v, [String currency = 'IDR']) {
  final f = _moneyFormats.putIfAbsent(
    currency,
    () => NumberFormat.currency(
      locale: 'id_ID',
      symbol: '${currencySymbol(currency)} ',
      decimalDigits: hasDecimals(currency) ? 2 : 0,
    ),
  );
  final s = f.format(v.abs());
  return (v < 0 && s != f.format(0)) ? '-$s' : s;
}

String compactMoney(double v) => _compact.format(v);

/// Teks input -> angka. Mode desimal memakai '.' atau ',' sebagai pemisah.
double parseAmount(String text, {bool decimals = false}) {
  if (decimals) {
    return double.tryParse(text.replaceAll(',', '.')) ?? 0;
  }
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return 0;
  return double.tryParse(digits) ?? 0;
}

/// Angka -> teks untuk diisi ke kolom input.
String amountToInput(double v, String currency) {
  if (!hasDecimals(currency)) return _plain.format(v.round());
  var s = v.toStringAsFixed(2);
  if (s.endsWith('.00')) s = s.substring(0, s.length - 3);
  return s;
}

class AmountFormatter extends TextInputFormatter {
  AmountFormatter({this.decimals = false});
  final bool decimals;

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (decimals) {
      var t = newValue.text
          .replaceAll(',', '.')
          .replaceAll(RegExp(r'[^0-9.]'), '');
      final dot = t.indexOf('.');
      if (dot >= 0) {
        final intPart = t.substring(0, dot);
        var dec = t.substring(dot + 1).replaceAll('.', '');
        if (dec.length > 2) dec = dec.substring(0, 2);
        t = '${intPart.isEmpty ? '0' : intPart}.$dec';
      }
      if (t.replaceAll('.', '').length > 14) return oldValue;
      return TextEditingValue(
          text: t, selection: TextSelection.collapsed(offset: t.length));
    }
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    if (digits.length > 13) return oldValue;
    final formatted = _plain.format(int.parse(digits));
    return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length));
  }
}
