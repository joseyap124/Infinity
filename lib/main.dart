// =============================================================================
// INFINITY - Personal Finance Manager (single-file Flutter app)
// -----------------------------------------------------------------------------
// Kebutuhan:
//   - Flutter 3.38.1+ (syarat flutter_local_notifications v22)
//   - flutter pub add intl flutter_secure_storage local_auth \
//       flutter_local_notifications timezone home_widget
//   - Setup Android (notifikasi, biometrik, catat otomatis, widget): README.md
//
// Fitur: multi-akun (e-wallet, tunai, bank, kartu kredit, investasi), multi mata
// uang, transfer antar akun, edit/hapus/duplikat transaksi, kategori & sub-
// kategori kustom, anggaran mingguan/bulanan/tahunan (global & per kategori),
// transaksi berulang, template, kalender, pencarian, kalkulator, statistik &
// tren, backup/restore JSON, kunci PIN + biometrik, penyimpanan terenkripsi,
// notifikasi pengingat, catat otomatis dari notifikasi bank/e-wallet, dan
// widget layar utama.
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// NOTIF-IMPORTS-BEGIN
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
// NOTIF-IMPORTS-END
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
// STORAGE-IMPORTS-BEGIN
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// STORAGE-IMPORTS-END
// BIO-IMPORTS-BEGIN
import 'package:local_auth/local_auth.dart' as la;
// BIO-IMPORTS-END
// WIDGET-IMPORTS-BEGIN
import 'package:home_widget/home_widget.dart';
// WIDGET-IMPORTS-END

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  runApp(const InfinityApp());
}

// =============================================================================
// DESIGN TOKENS
// =============================================================================

class C {
  static const Color green = Color(0xFF00AA13);
  static const Color greenDark = Color(0xFF007A0E); // untuk teks/isi di bawah teks putih
  static const Color red = Color(0xFFEE2737);
  static const Color redDark = Color(0xFFD61F2E);
  static const Color carbon = Color(0xFF1C1C1C);
  static const Color bg = Color(0xFFF8F9FA);
  static const Color blue = Color(0xFF00AED6);
  static const Color blueDark = Color(0xFF007A94);
  static const Color amber = Color(0xFFFFA000);
  static const Color amberDark = Color(0xFFA35A00);
  static const Color muted = Color(0xFF5B6270);
  static const Color line = Color(0xFFE9ECEF);
  static const Color warning = Color(0xFFF59E0B);
}

const List<int> kPalette = [
  0xFF00AED6,
  0xFF00AA13,
  0xFFFFA000,
  0xFFFB8C00,
  0xFFE91E63,
  0xFFEF5350,
  0xFF7C4DFF,
  0xFF5C6BC0,
  0xFF00897B,
  0xFF8D6E63,
  0xFF546E7A,
  0xFF1C1C1C,
];

const Map<String, IconData> kIcons = {
  'food': Icons.fastfood_rounded,
  'coffee': Icons.local_cafe_rounded,
  'bike': Icons.directions_bike_rounded,
  'car': Icons.directions_car_rounded,
  'fuel': Icons.local_gas_station_rounded,
  'bag': Icons.shopping_bag_rounded,
  'movie': Icons.movie_rounded,
  'bill': Icons.receipt_long_rounded,
  'health': Icons.local_hospital_rounded,
  'school': Icons.school_rounded,
  'gift': Icons.card_giftcard_rounded,
  'salary': Icons.account_balance_wallet_rounded,
  'invest': Icons.trending_up_rounded,
  'home': Icons.home_rounded,
  'phone': Icons.smartphone_rounded,
  'pet': Icons.pets_rounded,
  'travel': Icons.flight_rounded,
  'other': Icons.category_rounded,
};

IconData iconOf(String key) => kIcons[key] ?? Icons.category_rounded;

Color darken(Color c, [double amount = 0.12]) {
  final h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness - amount).clamp(0.0, 1.0)).toColor();
}

// =============================================================================
// FORMAT & PARSING
// =============================================================================

const List<String> kCurrencies = ['IDR', 'USD', 'SGD', 'MYR', 'CNY', 'EUR', 'JPY'];

/// Kurs bawaan ke Rupiah. HANYA PERKIRAAN, ubah di menu Mata Uang & Kurs.
const Map<String, double> kDefaultRates = {
  'IDR': 1,
  'USD': 16300,
  'SGD': 12600,
  'MYR': 3850,
  'CNY': 2280,
  'EUR': 17700,
  'JPY': 108,
};

String currencySymbol(String c) {
  const symbols = {
    'IDR': 'Rp',
    'USD': 'US\$',
    'SGD': 'S\$',
    'MYR': 'RM',
    'CNY': 'CN¥',
    'EUR': '€',
    'JPY': 'JP¥',
  };
  return symbols[c] ?? c;
}

bool hasDecimals(String currency) => currency != 'IDR' && currency != 'JPY';

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

// =============================================================================
// DATE HELPERS
// =============================================================================

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool inRange(DateTime d, DateTimeRange r) =>
    !d.isBefore(r.start) && d.isBefore(r.end);

DateTimeRange dayRange(DateTime d) => DateTimeRange(
    start: DateTime(d.year, d.month, d.day),
    end: DateTime(d.year, d.month, d.day + 1));

DateTimeRange weekRange(DateTime d) {
  final s = DateTime(d.year, d.month, d.day - (d.weekday - 1));
  return DateTimeRange(start: s, end: DateTime(s.year, s.month, s.day + 7));
}

DateTimeRange monthRange(DateTime d) => DateTimeRange(
    start: DateTime(d.year, d.month, 1), end: DateTime(d.year, d.month + 1, 1));

DateTimeRange yearRange(DateTime d) =>
    DateTimeRange(start: DateTime(d.year), end: DateTime(d.year + 1));

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String dayLabel(DateTime day) {
  final now = DateTime.now();
  if (sameDay(day, now)) return 'Hari Ini';
  if (sameDay(day, DateTime(now.year, now.month, now.day - 1))) {
    return 'Kemarin';
  }
  return DateFormat('EEEE, d MMM yyyy', 'id_ID').format(day);
}

DateTime nextDueDate(int dueDay, DateTime now) {
  final today = dayOnly(now);
  var d = DateTime(now.year, now.month, dueDay);
  if (d.isBefore(today)) d = DateTime(now.year, now.month + 1, dueDay);
  return d;
}

// =============================================================================
// ENUMS
// =============================================================================

enum TxType {
  expense('Pengeluaran', C.redDark, Icons.north_east_rounded),
  income('Pemasukan', C.greenDark, Icons.south_west_rounded),
  transfer('Transfer', C.blueDark, Icons.swap_horiz_rounded);

  const TxType(this.label, this.color, this.icon);
  final String label;
  final Color color;
  final IconData icon;
}

enum AccountType {
  ewallet('E-Wallet', Icons.account_balance_wallet_rounded),
  cash('Tunai', Icons.payments_rounded),
  bank('Rekening Bank', Icons.account_balance_rounded),
  credit('Kartu Kredit', Icons.credit_card_rounded),
  investment('Investasi', Icons.trending_up_rounded);

  const AccountType(this.label, this.icon);
  final String label;
  final IconData icon;
}

enum Frequency {
  daily('Harian'),
  weekly('Mingguan'),
  monthly('Bulanan'),
  yearly('Tahunan');

  const Frequency(this.label);
  final String label;
}

enum BudgetPeriod {
  weekly('Mingguan', 'Minggu', 'minggu ini'),
  monthly('Bulanan', 'Bulan', 'bulan ini'),
  yearly('Tahunan', 'Tahun', 'tahun ini');

  const BudgetPeriod(this.label, this.short, this.current);
  final String label;
  final String short;
  final String current;

  DateTimeRange range(DateTime d) {
    switch (this) {
      case BudgetPeriod.weekly:
        return weekRange(d);
      case BudgetPeriod.monthly:
        return monthRange(d);
      case BudgetPeriod.yearly:
        return yearRange(d);
    }
  }
}

enum FormMode { transaction, recurring, template }

enum BudgetStatus {
  safe('Aman Abis, Jajan Terus! 👌', C.greenDark),
  tight('Mulai Seret, Hati-hati! ⚠️', C.amberDark),
  broke('Waduh, Rem Dulu, Jebol! 🚨', C.redDark);

  const BudgetStatus(this.message, this.color);
  final String message;
  final Color color;

  /// remaining = sisa / limit. >50% aman, 10%-50% seret, <10% atau minus jebol.
  static BudgetStatus of(double remaining) {
    if (remaining > 0.5) return BudgetStatus.safe;
    if (remaining >= 0.1) return BudgetStatus.tight;
    return BudgetStatus.broke;
  }
}

/// Kalkulasi n-kali kejadian dari tanggal mulai (tanpa drift tanggal).
DateTime occurrence(DateTime start, Frequency f, int n) {
  switch (f) {
    case Frequency.daily:
      return DateTime(
          start.year, start.month, start.day + n, start.hour, start.minute);
    case Frequency.weekly:
      return DateTime(
          start.year, start.month, start.day + 7 * n, start.hour, start.minute);
    case Frequency.monthly:
      final m0 = start.month - 1 + n;
      final y = start.year + m0 ~/ 12;
      final m = m0 % 12 + 1;
      final dim = DateTime(y, m + 1, 0).day;
      return DateTime(y, m, math.min(start.day, dim), start.hour, start.minute);
    case Frequency.yearly:
      final y = start.year + n;
      final dim = DateTime(y, start.month + 1, 0).day;
      return DateTime(y, start.month, math.min(start.day, dim), start.hour,
          start.minute);
  }
}

// =============================================================================
// MODELS
// =============================================================================

double _d(Object? v, [double def = 0]) => v is num ? v.toDouble() : def;
int _i(Object? v, [int def = 0]) => v is num ? v.toInt() : def;
String? _s(Object? v) => v is String ? v : null;

List<Map<String, dynamic>> _list(Object? v) => v is List
    ? v.map((e) => Map<String, dynamic>.from(e as Map)).toList()
    : <Map<String, dynamic>>[];

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    this.currency = 'IDR',
    this.initialBalance = 0,
    required this.color,
    this.creditLimit = 0,
    this.dueDay = 25,
  });

  final String id;
  final String name;
  final AccountType type;
  final String currency;

  /// Saldo awal. Saldo berjalan selalu dihitung ulang dari saldo awal + semua
  /// transaksi, jadi edit/hapus otomatis konsisten. Kartu kredit: minus = utang.
  final double initialBalance;
  final int color;
  final double creditLimit;
  final int dueDay;

  Color get colorValue => Color(color);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'currency': currency,
        'initialBalance': initialBalance,
        'color': color,
        'creditLimit': creditLimit,
        'dueDay': dueDay,
      };

  factory Account.fromJson(Map<String, dynamic> j) => Account(
        id: j['id'] as String,
        name: j['name'] as String,
        type: AccountType.values.byName(j['type'] as String),
        currency: _s(j['currency']) ?? 'IDR',
        initialBalance: _d(j['initialBalance']),
        color: _i(j['color'], kPalette.first),
        creditLimit: _d(j['creditLimit']),
        dueDay: _i(j['dueDay'], 25),
      );
}

class TxCategory {
  const TxCategory({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    this.parentId,
  });

  final String id;
  final String name;
  final TxType type; // expense / income
  final String icon;
  final int color;
  final String? parentId;

  IconData get iconData => iconOf(icon);
  Color get colorValue => Color(color);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'icon': icon,
        'color': color,
        'parentId': parentId,
      };

  factory TxCategory.fromJson(Map<String, dynamic> j) => TxCategory(
        id: j['id'] as String,
        name: j['name'] as String,
        type: TxType.values.byName(j['type'] as String),
        icon: _s(j['icon']) ?? 'other',
        color: _i(j['color'], kPalette.last),
        parentId: _s(j['parentId']),
      );
}

class Transaction {
  const Transaction({
    required this.id,
    required this.title,
    required this.amount,
    this.toAmount,
    required this.type,
    this.categoryId,
    required this.accountId,
    this.toAccountId,
    required this.date,
    this.note = '',
    this.recurringId,
  });

  final String id;
  final String title;

  /// Selalu positif, dalam mata uang akun asal.
  final double amount;

  /// Khusus transfer beda mata uang: jumlah yang diterima akun tujuan.
  final double? toAmount;
  final TxType type;
  final String? categoryId;

  /// Akun asal. Pengeluaran: akun yang dipotong. Pemasukan: akun penerima.
  /// Transfer: akun pengirim.
  final String accountId;
  final String? toAccountId;
  final DateTime date;
  final String note;
  final String? recurringId;

  double get receivedAmount => toAmount ?? amount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'toAmount': toAmount,
        'type': type.name,
        'categoryId': categoryId,
        'accountId': accountId,
        'toAccountId': toAccountId,
        'date': date.toIso8601String(),
        'note': note,
        'recurringId': recurringId,
      };

  factory Transaction.fromJson(Map<String, dynamic> j) => Transaction(
        id: j['id'] as String,
        title: _s(j['title']) ?? '',
        amount: _d(j['amount']),
        toAmount: j['toAmount'] == null ? null : _d(j['toAmount']),
        type: TxType.values.byName(j['type'] as String),
        categoryId: _s(j['categoryId']),
        accountId: j['accountId'] as String,
        toAccountId: _s(j['toAccountId']),
        date: DateTime.parse(j['date'] as String),
        note: _s(j['note']) ?? '',
        recurringId: _s(j['recurringId']),
      );
}

class RecurringRule {
  RecurringRule({
    required this.id,
    required this.title,
    required this.amount,
    this.toAmount,
    required this.type,
    this.categoryId,
    required this.accountId,
    this.toAccountId,
    this.note = '',
    required this.frequency,
    required this.start,
    this.generated = 0,
    this.active = true,
  });

  final String id;
  final String title;
  final double amount;
  final double? toAmount;
  final TxType type;
  final String? categoryId;
  final String accountId;
  final String? toAccountId;
  final String note;
  final Frequency frequency;
  final DateTime start;
  int generated;
  bool active;

  DateTime get nextDate => occurrence(start, frequency, generated);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'toAmount': toAmount,
        'type': type.name,
        'categoryId': categoryId,
        'accountId': accountId,
        'toAccountId': toAccountId,
        'note': note,
        'frequency': frequency.name,
        'start': start.toIso8601String(),
        'generated': generated,
        'active': active,
      };

  factory RecurringRule.fromJson(Map<String, dynamic> j) => RecurringRule(
        id: j['id'] as String,
        title: _s(j['title']) ?? '',
        amount: _d(j['amount']),
        toAmount: j['toAmount'] == null ? null : _d(j['toAmount']),
        type: TxType.values.byName(j['type'] as String),
        categoryId: _s(j['categoryId']),
        accountId: j['accountId'] as String,
        toAccountId: _s(j['toAccountId']),
        note: _s(j['note']) ?? '',
        frequency: Frequency.values.byName(j['frequency'] as String),
        start: DateTime.parse(j['start'] as String),
        generated: _i(j['generated']),
        active: j['active'] != false,
      );
}

class TxTemplate {
  const TxTemplate({
    required this.id,
    required this.title,
    required this.amount,
    this.toAmount,
    required this.type,
    this.categoryId,
    required this.accountId,
    this.toAccountId,
    this.note = '',
  });

  final String id;
  final String title;
  final double amount;
  final double? toAmount;
  final TxType type;
  final String? categoryId;
  final String accountId;
  final String? toAccountId;
  final String note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'toAmount': toAmount,
        'type': type.name,
        'categoryId': categoryId,
        'accountId': accountId,
        'toAccountId': toAccountId,
        'note': note,
      };

  factory TxTemplate.fromJson(Map<String, dynamic> j) => TxTemplate(
        id: j['id'] as String,
        title: _s(j['title']) ?? '',
        amount: _d(j['amount']),
        toAmount: j['toAmount'] == null ? null : _d(j['toAmount']),
        type: TxType.values.byName(j['type'] as String),
        categoryId: _s(j['categoryId']),
        accountId: j['accountId'] as String,
        toAccountId: _s(j['toAccountId']),
        note: _s(j['note']) ?? '',
      );
}

/// Data sementara yang dipakai form (transaksi, berulang, template).
class TxDraft {
  TxDraft({
    required this.type,
    this.title = '',
    this.amount = 0,
    this.toAmount,
    this.categoryId,
    required this.accountId,
    this.toAccountId,
    DateTime? date,
    this.note = '',
  }) : date = date ?? DateTime.now();

  TxType type;
  String title;
  double amount;
  double? toAmount;
  String? categoryId;
  String accountId;
  String? toAccountId;
  DateTime date;
  String note;

  factory TxDraft.fromTransaction(Transaction t) => TxDraft(
        type: t.type,
        title: t.title,
        amount: t.amount,
        toAmount: t.toAmount,
        categoryId: t.categoryId,
        accountId: t.accountId,
        toAccountId: t.toAccountId,
        date: t.date,
        note: t.note,
      );

  factory TxDraft.fromTemplate(TxTemplate t) => TxDraft(
        type: t.type,
        title: t.title,
        amount: t.amount,
        toAmount: t.toAmount,
        categoryId: t.categoryId,
        accountId: t.accountId,
        toAccountId: t.toAccountId,
        note: t.note,
      );

  Transaction toTransaction(String id, {String? recurringId}) => Transaction(
        id: id,
        title: title,
        amount: amount,
        toAmount: type == TxType.transfer ? toAmount : null,
        type: type,
        categoryId: type == TxType.transfer ? null : categoryId,
        accountId: accountId,
        toAccountId: type == TxType.transfer ? toAccountId : null,
        date: date,
        note: note,
        recurringId: recurringId,
      );

  TxTemplate toTemplate(String id) => TxTemplate(
        id: id,
        title: title,
        amount: amount,
        toAmount: type == TxType.transfer ? toAmount : null,
        type: type,
        categoryId: type == TxType.transfer ? null : categoryId,
        accountId: accountId,
        toAccountId: type == TxType.transfer ? toAccountId : null,
        note: note,
      );
}

class FormResult {
  const FormResult(this.draft, {this.frequency, this.saveAsTemplate = false});
  final TxDraft draft;
  final Frequency? frequency;
  final bool saveAsTemplate;
}

class AppSettings {
  BudgetPeriod budgetPeriod = BudgetPeriod.monthly;
  double globalBudget = 0;
  Map<String, double> categoryBudgets = {};
  Map<String, double> rates = Map.of(kDefaultRates);
  String? pin;
  bool hideBalance = false;

  // Keamanan
  bool biometric = false;
  bool secureScreen = true;

  /// 'off' | 'ask' | 'auto' untuk pencatatan dari notifikasi bank/e-wallet.
  String captureMode = 'auto';

  // Notifikasi
  bool notifHideAmounts = true;
  bool notifEnabled = true;
  bool notifRecurring = true;
  bool notifCredit = true;
  bool notifBudget = true;
  bool dailyReminder = true;
  int reminderHour = 20;
  int reminderMinute = 0;

  /// [includeSecrets] false dipakai untuk ekspor backup (PIN tidak ikut).
  Map<String, dynamic> toJson({bool includeSecrets = true}) => {
        'budgetPeriod': budgetPeriod.name,
        'globalBudget': globalBudget,
        'categoryBudgets': categoryBudgets,
        'rates': rates,
        if (includeSecrets) 'pin': pin,
        'hideBalance': hideBalance,
        'biometric': biometric,
        'secureScreen': secureScreen,
        'captureMode': captureMode,
        'notifHideAmounts': notifHideAmounts,
        'notifEnabled': notifEnabled,
        'notifRecurring': notifRecurring,
        'notifCredit': notifCredit,
        'notifBudget': notifBudget,
        'dailyReminder': dailyReminder,
        'reminderHour': reminderHour,
        'reminderMinute': reminderMinute,
      };

  static AppSettings fromJson(Map<String, dynamic> j) {
    final s = AppSettings();
    s.budgetPeriod =
        BudgetPeriod.values.byName(_s(j['budgetPeriod']) ?? 'monthly');
    s.globalBudget = _d(j['globalBudget']);
    final cb = j['categoryBudgets'];
    if (cb is Map) {
      s.categoryBudgets = {
        for (final e in cb.entries) e.key.toString(): _d(e.value)
      };
    }
    final r = j['rates'];
    if (r is Map) {
      for (final e in r.entries) {
        final v = _d(e.value);
        if (v > 0) s.rates[e.key.toString()] = v;
      }
    }
    s.rates['IDR'] = 1;
    s.pin = _s(j['pin']);
    s.hideBalance = j['hideBalance'] == true;
    s.biometric = j['biometric'] == true;
    s.secureScreen = j['secureScreen'] != false;
    final mode = _s(j['captureMode']);
    s.captureMode =
        (mode == 'off' || mode == 'ask' || mode == 'auto') ? mode! : 'auto';
    s.notifHideAmounts = j['notifHideAmounts'] != false;
    s.notifEnabled = j['notifEnabled'] != false;
    s.notifRecurring = j['notifRecurring'] != false;
    s.notifCredit = j['notifCredit'] != false;
    s.notifBudget = j['notifBudget'] != false;
    s.dailyReminder = j['dailyReminder'] != false;
    s.reminderHour = _i(j['reminderHour'], 20).clamp(0, 23);
    s.reminderMinute = _i(j['reminderMinute'], 0).clamp(0, 59);
    return s;
  }
}

// =============================================================================
// PLATFORM: penyimpanan terenkripsi, biometrik, jembatan native Android
// =============================================================================

// STORAGE-IMPL-BEGIN
/// Penyimpanan terenkripsi (kunci di Android Keystore, data AES-GCM).
class SecureStore {
  static final FlutterSecureStorage _s = FlutterSecureStorage();
  static Future<String?> read(String key) => _s.read(key: key);
  static Future<void> write(String key, String value) =>
      _s.write(key: key, value: value);
}
// STORAGE-IMPL-END

// BIO-IMPL-BEGIN
/// Sidik jari / wajah lewat local_auth v3.
class Biometric {
  static final la.LocalAuthentication _auth = la.LocalAuthentication();

  static Future<bool> available() async {
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
          localizedReason: 'Buka Infinity', biometricOnly: true);
    } catch (_) {
      return false;
    }
  }
}
// BIO-IMPL-END

// WIDGET-IMPL-BEGIN
/// Widget layar utama (home_widget 0.10, provider Kotlin InfinityWidgetProvider).
class HomeWidgetBridge {
  static Future<void> update(Map<String, String> data) async {
    try {
      for (final e in data.entries) {
        await HomeWidget.saveWidgetData<String>(e.key, e.value);
      }
      await HomeWidget.updateWidget(androidName: 'InfinityWidgetProvider');
    } catch (_) {}
  }

  static Future<Uri?> initialLaunch() async {
    try {
      return await HomeWidget.initiallyLaunchedFromHomeWidget();
    } catch (_) {
      return null;
    }
  }

  static Stream<Uri?> clicks() {
    try {
      return HomeWidget.widgetClicked;
    } catch (_) {
      return const Stream<Uri?>.empty();
    }
  }
}
// WIDGET-IMPL-END

/// Jembatan ke kode Kotlin (MainActivity.kt & NotificationCaptureService.kt).
/// Kalau kode native belum dipasang (misalnya di DartPad), semua jadi no-op.
class NativeBridge {
  static const MethodChannel _ch = MethodChannel('infinity/native');

  /// Sembunyikan isi app di daftar aplikasi terbaru & blokir screenshot.
  static Future<void> setSecure(bool on) async {
    try {
      await _ch.invokeMethod<void>('setSecure', {'on': on});
    } catch (_) {}
  }

  static Future<bool> isListenerEnabled() async {
    try {
      return (await _ch.invokeMethod<bool>('isListenerEnabled')) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openListenerSettings() async {
    try {
      await _ch.invokeMethod<void>('openListenerSettings');
    } catch (_) {}
  }

  static Future<void> openAppSettings() async {
    try {
      await _ch.invokeMethod<void>('openAppSettings');
    } catch (_) {}
  }

  /// Ambil (lalu kosongkan) antrean notifikasi uang yang ditangkap native.
  static Future<List<Map<String, dynamic>>> fetchCaptured() async {
    try {
      final s = await _ch.invokeMethod<String>('fetchCaptured');
      if (s == null || s.isEmpty) return [];
      final list = jsonDecode(s);
      if (list is! List) return [];
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

/// Notifikasi bank/e-wallet yang tertangkap dan menunggu dicek user.
class CapturedNotif {
  const CapturedNotif({
    required this.id,
    required this.pkg,
    required this.title,
    required this.text,
    required this.time,
  });

  final String id;
  final String pkg;
  final String title;
  final String text;
  final DateTime time;

  String get fullText => title.isEmpty ? text : '$title\n$text';

  Map<String, dynamic> toJson() => {
        'id': id,
        'pkg': pkg,
        'title': title,
        'text': text,
        'time': time.toIso8601String(),
      };

  factory CapturedNotif.fromJson(Map<String, dynamic> j) => CapturedNotif(
        id: j['id'] as String,
        pkg: _s(j['pkg']) ?? '',
        title: _s(j['title']) ?? '',
        text: _s(j['text']) ?? '',
        time: DateTime.tryParse(_s(j['time']) ?? '') ?? DateTime.now(),
      );
}

/// [kata di nama paket, nama tampilan, kata kunci nama akun]
const List<List<String>> _knownApps = [
  ['gopay', 'GoPay', 'gopay'],
  ['gojek', 'GoPay', 'gopay'],
  ['ovo', 'OVO', 'ovo'],
  ['dana', 'DANA', 'dana'],
  ['shopee', 'ShopeePay', 'shopee'],
  ['mybca', 'myBCA', 'bca'],
  ['bca', 'BCA', 'bca'],
  ['jago', 'Jago', 'jago'],
  ['brimo', 'BRImo', 'bri'],
  ['livin', 'Livin Mandiri', 'mandiri'],
  ['bmri', 'Livin Mandiri', 'mandiri'],
  ['bni', 'BNI', 'bni'],
  ['seabank', 'SeaBank', 'seabank'],
  ['linkaja', 'LinkAja', 'linkaja'],
  ['mwallet', 'LinkAja', 'linkaja'],
  ['blu', 'blu', 'blu'],
  ['flip', 'Flip', 'flip'],
];

List<String>? _appInfo(String pkg) {
  final p = pkg.toLowerCase();
  for (final e in _knownApps) {
    if (p.contains(e[0])) return e;
  }
  return null;
}

String appLabelForPackage(String pkg) {
  final info = _appInfo(pkg);
  if (info != null) return info[1];
  final parts = pkg.split('.');
  return parts.isEmpty ? pkg : parts.last;
}

const List<String> _promoWords = [
  'promo', 'diskon', 'voucher', 'gratis', 'hemat', 'dapatkan',
  'cashback hingga', 'hingga rp', 's.d. rp', 's/d rp', 'min. transaksi',
  'minimal transaksi', 'klaim', 'penawaran', 'spesial',
];

// =============================================================================
// STORE: seluruh data & logika bisnis (ChangeNotifier bawaan Flutter)
// =============================================================================

class AppStore extends ChangeNotifier {
  static const String _key = 'infinity_data_v1';

  bool _storageOk = true;
  bool loaded = false;
  String? loadWarning;

  /// Notifikasi bank/e-wallet yang menunggu dicek (mode "Tanya dulu").
  List<CapturedNotif> pendingCaptures = [];
  List<String> _seenCaptureKeys = [];

  List<Account> accounts = [];
  List<TxCategory> categories = [];
  List<Transaction> transactions = [];
  List<RecurringRule> recurring = [];
  List<TxTemplate> templates = [];
  AppSettings settings = AppSettings();

  int _idCounter = 0;
  String newId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${(_idCounter++).toRadixString(36)}${math.Random().nextInt(1 << 16).toRadixString(36)}';

  // ---------------------------------------------------------------- persist

  Future<void> load() async {
    String? raw;
    try {
      raw = await SecureStore.read(_key);
    } catch (_) {
      _storageOk = false;
      loadWarning =
          'Penyimpanan terenkripsi tidak tersedia. Data hanya tersimpan selama aplikasi terbuka.';
    }
    if (raw == null) {
      _seedDemo();
    } else {
      try {
        final decoded = jsonDecode(raw);
        _applyJson(Map<String, dynamic>.from(decoded as Map));
      } catch (_) {
        try {
          await SecureStore.write(
              '${_key}_rusak_${DateTime.now().millisecondsSinceEpoch}', raw);
        } catch (_) {}
        _seedDemo();
        loadWarning =
            'Data tersimpan tidak bisa dibaca. Salinannya sudah diamankan, aplikasi memakai data demo.';
      }
    }
    processRecurring(notify: false);
    loaded = true;
    _persist();
    notifyListeners();
  }

  void _persist() {
    if (!_storageOk) return;
    unawaited(_write(jsonEncode(toJson())));
  }

  Future<void> _write(String json) async {
    try {
      await SecureStore.write(_key, json);
    } catch (_) {}
  }

  void _commit() {
    notifyListeners();
    _persist();
  }

  /// [includeSecrets] false untuk ekspor backup: tanpa PIN dan tanpa isi
  /// notifikasi yang tertangkap.
  Map<String, dynamic> toJson({bool includeSecrets = true}) => {
        'app': 'Infinity',
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'accounts': accounts.map((a) => a.toJson()).toList(),
        'categories': categories.map((c) => c.toJson()).toList(),
        'transactions': transactions.map((t) => t.toJson()).toList(),
        'recurring': recurring.map((r) => r.toJson()).toList(),
        'templates': templates.map((t) => t.toJson()).toList(),
        'settings': settings.toJson(includeSecrets: includeSecrets),
        if (includeSecrets)
          'pendingCaptures': pendingCaptures.map((c) => c.toJson()).toList(),
        if (includeSecrets) 'seenCaptureKeys': _seenCaptureKeys,
      };

  /// Parse semuanya dulu, baru diganti (atomik). Lempar error kalau format salah.
  void _applyJson(Map<String, dynamic> j) {
    final acc = _list(j['accounts']).map(Account.fromJson).toList();
    if (acc.isEmpty) throw const FormatException('Data tidak berisi akun.');
    final ids = acc.map((a) => a.id).toSet();
    final cats = _list(j['categories']).map(TxCategory.fromJson).toList();
    final txs = _list(j['transactions'])
        .map(Transaction.fromJson)
        .where((t) =>
            ids.contains(t.accountId) &&
            (t.toAccountId == null || ids.contains(t.toAccountId)))
        .toList();
    final rec = _list(j['recurring'])
        .map(RecurringRule.fromJson)
        .where((r) => ids.contains(r.accountId))
        .toList();
    final tpl = _list(j['templates'])
        .map(TxTemplate.fromJson)
        .where((t) => ids.contains(t.accountId))
        .toList();
    final st = j['settings'] is Map
        ? AppSettings.fromJson(Map<String, dynamic>.from(j['settings'] as Map))
        : AppSettings();

    final pend = _list(j['pendingCaptures']).map(CapturedNotif.fromJson).toList();
    final seen = j['seenCaptureKeys'] is List
        ? (j['seenCaptureKeys'] as List).whereType<String>().toList()
        : <String>[];

    accounts = acc;
    categories = cats;
    transactions = txs;
    recurring = rec;
    templates = tpl;
    settings = st;
    pendingCaptures = pend;
    _seenCaptureKeys = seen;
  }

  /// Pengaturan keamanan tidak ikut terhapus/tertimpa saat reset atau impor.
  void _keepSecurity(AppSettings old) {
    settings.pin = old.pin;
    settings.biometric = old.biometric;
    settings.secureScreen = old.secureScreen;
  }

  String exportJson() => const JsonEncoder.withIndent('  ')
      .convert(toJson(includeSecrets: false));

  void importJson(String raw) {
    final decoded = jsonDecode(raw.trim());
    if (decoded is! Map) {
      throw const FormatException('Bukan data backup Infinity.');
    }
    final old = settings;
    final pend = pendingCaptures;
    final seen = _seenCaptureKeys;
    _applyJson(Map<String, dynamic>.from(decoded));
    _keepSecurity(old);
    pendingCaptures = pend;
    _seenCaptureKeys = seen;
    processRecurring(notify: false);
    _commit();
  }

  void resetDemo() {
    final old = settings;
    _seedDemo();
    _keepSecurity(old);
    processRecurring(notify: false);
    _commit();
  }

  void clearAll() {
    final old = settings;
    accounts = _defaultAccounts(demo: false);
    categories = _defaultCategories();
    transactions = [];
    recurring = [];
    templates = [];
    settings = AppSettings();
    _keepSecurity(old);
    pendingCaptures = [];
    _commit();
  }

  // ---------------------------------------------------------------- seed

  List<Account> _defaultAccounts({required bool demo}) => [
        Account(
            id: 'gopay',
            name: 'GoPay',
            type: AccountType.ewallet,
            initialBalance: demo ? 250000.0 : 0.0,
            color: 0xFF00AED6),
        Account(
            id: 'cash',
            name: 'Kantong Utama',
            type: AccountType.cash,
            initialBalance: demo ? 500000.0 : 0.0,
            color: 0xFF00AA13),
        Account(
            id: 'jago',
            name: 'Bank Jago',
            type: AccountType.bank,
            initialBalance: demo ? 2000000.0 : 0.0,
            color: 0xFFFFA000),
        if (demo)
          const Account(
              id: 'cc',
              name: 'Kartu Kredit',
              type: AccountType.credit,
              initialBalance: 0,
              color: 0xFF5C6BC0,
              creditLimit: 10000000,
              dueDay: 25),
        if (demo)
          const Account(
              id: 'usd',
              name: 'Tabungan USD',
              type: AccountType.bank,
              currency: 'USD',
              initialBalance: 150,
              color: 0xFF00897B),
      ];

  // Kategori bawaan = kategori Money Manager Jose (+ beberapa tambahan).
  // List biasa (bukan const) supaya bisa ditambah/dihapus user.
  List<TxCategory> _defaultCategories() => <TxCategory>[
        TxCategory(id: 'pokok', name: 'Kebutuhan Pokok 📅', type: TxType.expense, icon: 'home', color: 0xFFFB8C00),
        TxCategory(id: 'makan', name: 'Makan dan Minum 🍲', type: TxType.expense, icon: 'food', color: 0xFFFB8C00, parentId: 'pokok'),
        TxCategory(id: 'transport', name: 'Transportasi 🚕', type: TxType.expense, icon: 'car', color: 0xFF00AA13, parentId: 'pokok'),
        TxCategory(id: 'bills', name: 'Bills (Listrik, Air, Kuota) 💡', type: TxType.expense, icon: 'bill', color: 0xFF5C6BC0, parentId: 'pokok'),
        TxCategory(id: 'kos', name: 'Kos / Asrama 🏠', type: TxType.expense, icon: 'home', color: 0xFF8D6E63, parentId: 'pokok'),
        TxCategory(id: 'keperluan', name: 'Keperluan Rumah (Galon, Gas, Sabun Cuci) 🧺', type: TxType.expense, icon: 'home', color: 0xFF546E7A, parentId: 'pokok'),
        TxCategory(id: 'sehat', name: 'Kesehatan dan Kebersihan 🏥', type: TxType.expense, icon: 'health', color: 0xFFEF5350),
        TxCategory(id: 'health', name: 'Health (Obat, Vitamin, Medcheck) 💊', type: TxType.expense, icon: 'health', color: 0xFFEF5350, parentId: 'sehat'),
        TxCategory(id: 'care', name: 'Personal Care (Skincare, Shampoo, Sabun, Laundry) 🛀', type: TxType.expense, icon: 'other', color: 0xFF00897B, parentId: 'sehat'),
        TxCategory(id: 'olahraga', name: 'Olahraga 🏃', type: TxType.expense, icon: 'bike', color: 0xFF00AA13, parentId: 'sehat'),
        TxCategory(id: 'edu', name: 'Education 🏫', type: TxType.expense, icon: 'school', color: 0xFF5C6BC0),
        TxCategory(id: 'legal', name: 'Legal dan Document (Permit, Passport) 🛂', type: TxType.expense, icon: 'travel', color: 0xFF546E7A, parentId: 'edu'),
        TxCategory(id: 'buku', name: 'Buku 📖', type: TxType.expense, icon: 'school', color: 0xFF5C6BC0, parentId: 'edu'),
        TxCategory(id: 'course', name: 'Course Online 📚', type: TxType.expense, icon: 'phone', color: 0xFF7C4DFF, parentId: 'edu'),
        TxCategory(id: 'sosial', name: 'Social Dan Relasi 💑', type: TxType.expense, icon: 'gift', color: 0xFFE91E63),
        TxCategory(id: 'gift_out', name: 'Gift (Hadiah, Ulang Tahun) 🎂', type: TxType.expense, icon: 'gift', color: 0xFFE91E63, parentId: 'sosial'),
        TxCategory(id: 'donasi', name: 'Donasi 🧧', type: TxType.expense, icon: 'gift', color: 0xFFEF5350, parentId: 'sosial'),
        TxCategory(id: 'hiburan', name: 'Hiburan dan Gaya Hidup 🛍️', type: TxType.expense, icon: 'bag', color: 0xFFE91E63),
        TxCategory(id: 'ent', name: 'Entertainment (Subscription Film, Spotify, Game) 🎫', type: TxType.expense, icon: 'movie', color: 0xFF7C4DFF, parentId: 'hiburan'),
        TxCategory(id: 'shop', name: 'Shopping (Baju, Celana, Hobi) 🛍️', type: TxType.expense, icon: 'bag', color: 0xFFE91E63, parentId: 'hiburan'),
        TxCategory(id: 'cafe', name: 'Cafe / Restaurant ☕', type: TxType.expense, icon: 'coffee', color: 0xFF8D6E63, parentId: 'hiburan'),
        TxCategory(id: 'trip', name: 'Jalan-jalan / Liburan ✈️', type: TxType.expense, icon: 'travel', color: 0xFF00AED6, parentId: 'hiburan'),
        TxCategory(id: 'invest_out', name: 'Investasi 💰', type: TxType.expense, icon: 'invest', color: 0xFFFFA000),
        TxCategory(id: 'emas', name: 'Emas 🪙', type: TxType.expense, icon: 'invest', color: 0xFFFFA000, parentId: 'invest_out'),
        TxCategory(id: 'reksadana', name: 'Reksadana 💰', type: TxType.expense, icon: 'invest', color: 0xFF00897B, parentId: 'invest_out'),
        TxCategory(id: 'cicilan', name: 'Cicilan & Utang 💳', type: TxType.expense, icon: 'bill', color: 0xFF5C6BC0),
        TxCategory(id: 'darurat', name: 'Darurat / Lain lain 🆘', type: TxType.expense, icon: 'other', color: 0xFFEF5350),
        TxCategory(id: 'emergency', name: 'Emergency (HP Rusak, Ganti Baterai, Ban Bocor) 🆘', type: TxType.expense, icon: 'phone', color: 0xFFEF5350, parentId: 'darurat'),
        TxCategory(id: 'lain', name: 'Lain lain', type: TxType.expense, icon: 'other', color: 0xFF546E7A, parentId: 'darurat'),
        TxCategory(id: 'admin', name: 'Admin Bank 🏧', type: TxType.expense, icon: 'bill', color: 0xFF546E7A),
        TxCategory(id: 'main_inc', name: 'Main Income', type: TxType.income, icon: 'salary', color: 0xFFFFA000),
        TxCategory(id: 'gaji', name: 'Gaji', type: TxType.income, icon: 'salary', color: 0xFFFFA000, parentId: 'main_inc'),
        TxCategory(id: 'uang_saku', name: 'Uang Saku', type: TxType.income, icon: 'salary', color: 0xFFFFA000, parentId: 'main_inc'),
        TxCategory(id: 'untung', name: 'Untung', type: TxType.income, icon: 'invest', color: 0xFF00AA13, parentId: 'main_inc'),
        TxCategory(id: 'bonus', name: 'Bonus / THR', type: TxType.income, icon: 'gift', color: 0xFF7C4DFF, parentId: 'main_inc'),
        TxCategory(id: 'gift_in', name: 'Gift / Support', type: TxType.income, icon: 'gift', color: 0xFF7C4DFF),
        TxCategory(id: 'passive', name: 'Passive Income', type: TxType.income, icon: 'invest', color: 0xFF00897B),
        TxCategory(id: 'refund', name: 'Cashback / Refund', type: TxType.income, icon: 'other', color: 0xFF00AED6),
      ];

  void _seedDemo() {
    final now = DateTime.now();
    accounts = _defaultAccounts(demo: true);
    categories = _defaultCategories();
    transactions = [
      Transaction(id: newId(), title: 'Isi Saldo GoPay', amount: 300000, type: TxType.transfer, accountId: 'jago', toAccountId: 'gopay', date: now.subtract(const Duration(days: 3, hours: 2))),
      Transaction(id: newId(), title: 'Sepatu Lari', amount: 450000, type: TxType.expense, categoryId: 'shop', accountId: 'cc', date: now.subtract(const Duration(days: 4)), note: 'Diskon 11.11'),
      Transaction(id: newId(), title: 'Nonton Bioskop', amount: 120000, type: TxType.expense, categoryId: 'ent', accountId: 'jago', date: now.subtract(const Duration(days: 2)), note: 'Weekend sama teman'),
      Transaction(id: newId(), title: 'Nasi Padang', amount: 28000, type: TxType.expense, categoryId: 'makan', accountId: 'cash', date: now.subtract(const Duration(days: 1))),
      Transaction(id: newId(), title: 'GoRide ke Kantor', amount: 17000, type: TxType.expense, categoryId: 'transport', accountId: 'gopay', date: now.subtract(const Duration(minutes: 90))),
      Transaction(id: newId(), title: 'Kopi Susu Gula Aren', amount: 24000, type: TxType.expense, categoryId: 'cafe', accountId: 'gopay', date: now.subtract(const Duration(minutes: 30)), note: 'Less sugar'),
    ];
    recurring = [
      RecurringRule(id: 'r_gaji', title: 'Gaji Bulanan', amount: 7500000, type: TxType.income, categoryId: 'gaji', accountId: 'jago', frequency: Frequency.monthly, start: DateTime(now.year, now.month, 1, 8)),
      RecurringRule(id: 'r_spotify', title: 'Langganan Musik', amount: 54990, type: TxType.expense, categoryId: 'ent', accountId: 'cc', frequency: Frequency.monthly, start: DateTime(now.year, now.month, 15, 9)),
    ];
    templates = <TxTemplate>[
      TxTemplate(id: 't_kopi', title: 'Kopi Pagi', amount: 24000, type: TxType.expense, categoryId: 'cafe', accountId: 'gopay'),
      TxTemplate(id: 't_ojol', title: 'Ojol ke Kantor', amount: 17000, type: TxType.expense, categoryId: 'transport', accountId: 'gopay'),
    ];
    settings = AppSettings()
      ..budgetPeriod = BudgetPeriod.monthly
      ..globalBudget = 3000000
      ..categoryBudgets = {'pokok': 1600000, 'hiburan': 800000, 'sehat': 300000};
  }

  // ---------------------------------------------------------------- lookups

  Account? accountById(String? id) {
    if (id == null) return null;
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  String accountName(String? id) => accountById(id)?.name ?? 'Akun terhapus';

  TxCategory? categoryById(String? id) {
    if (id == null) return null;
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  String topCategoryId(String catId) => categoryById(catId)?.parentId ?? catId;

  List<TxCategory> topCategories(TxType type) =>
      categories.where((c) => c.type == type && c.parentId == null).toList();

  List<TxCategory> childrenOf(String id) =>
      categories.where((c) => c.parentId == id).toList();

  double rate(String currency) =>
      settings.rates[currency] ?? kDefaultRates[currency] ?? 1;

  double toIDR(double amount, String currency) => amount * rate(currency);

  String currencyOf(String? accountId) =>
      accountById(accountId)?.currency ?? 'IDR';

  double amountIDR(Transaction t) => toIDR(t.amount, currencyOf(t.accountId));

  IconData txIcon(Transaction t) => t.type == TxType.transfer
      ? Icons.swap_horiz_rounded
      : (categoryById(t.categoryId)?.iconData ?? Icons.category_rounded);

  Color txColor(Transaction t) => t.type == TxType.transfer
      ? C.blue
      : (categoryById(t.categoryId)?.colorValue ?? C.muted);

  String categoryLabel(Transaction t) {
    if (t.type == TxType.transfer) return 'Transfer';
    final c = categoryById(t.categoryId);
    if (c == null) return 'Tanpa kategori';
    final parent = categoryById(c.parentId);
    return parent == null ? c.name : '${parent.name} › ${c.name}';
  }

  // ---------------------------------------------------------------- saldo

  double balanceOf(String accountId, {String? excludeTxId}) {
    final acc = accountById(accountId);
    if (acc == null) return 0;
    var b = acc.initialBalance;
    for (final t in transactions) {
      if (t.id == excludeTxId) continue;
      switch (t.type) {
        case TxType.income:
          if (t.accountId == accountId) b += t.amount;
        case TxType.expense:
          if (t.accountId == accountId) b -= t.amount;
        case TxType.transfer:
          // Transfer hanya memindahkan dana, tidak dihitung pemasukan/pengeluaran.
          if (t.accountId == accountId) b -= t.amount;
          if (t.toAccountId == accountId) b += t.receivedAmount;
      }
    }
    return b;
  }

  double get netWorthIDR => accounts.fold(
      0.0, (s, a) => s + toIDR(balanceOf(a.id), a.currency));

  // ---------------------------------------------------------------- agregat

  double sumIDR(TxType type, DateTimeRange r, {String? topCategory}) {
    var s = 0.0;
    for (final t in transactions) {
      if (t.type != type || !inRange(t.date, r)) continue;
      if (topCategory != null) {
        final cid = t.categoryId;
        if (cid == null || topCategoryId(cid) != topCategory) continue;
      }
      s += amountIDR(t);
    }
    return s;
  }

  Map<String, double> byTopCategory(TxType type, DateTimeRange r) {
    final m = <String, double>{};
    for (final t in transactions) {
      if (t.type != type || !inRange(t.date, r)) continue;
      final key = t.categoryId == null ? '_none' : topCategoryId(t.categoryId!);
      m[key] = (m[key] ?? 0) + amountIDR(t);
    }
    return m;
  }

  Map<String, double> bySubCategory(String topId, TxType type, DateTimeRange r) {
    final m = <String, double>{};
    for (final t in transactions) {
      if (t.type != type || !inRange(t.date, r)) continue;
      final cid = t.categoryId;
      if (cid == null || topCategoryId(cid) != topId) continue;
      m[cid] = (m[cid] ?? 0) + amountIDR(t);
    }
    return m;
  }

  List<Transaction> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    final digits = q.replaceAll(RegExp(r'[^0-9]'), '');
    return transactions.where((t) {
      if (t.title.toLowerCase().contains(q)) return true;
      if (t.note.toLowerCase().contains(q)) return true;
      if (categoryLabel(t).toLowerCase().contains(q)) return true;
      if (accountName(t.accountId).toLowerCase().contains(q)) return true;
      if (t.toAccountId != null &&
          accountName(t.toAccountId).toLowerCase().contains(q)) {
        return true;
      }
      if (digits.length >= 3 &&
          t.amount.toStringAsFixed(0).contains(digits)) {
        return true;
      }
      return false;
    }).toList();
  }

  BudgetStatus? budgetStatusNow() {
    if (settings.globalBudget <= 0) return null;
    final spent = sumIDR(
        TxType.expense, settings.budgetPeriod.range(DateTime.now()));
    return BudgetStatus.of(
        (settings.globalBudget - spent) / settings.globalBudget);
  }

  // ---------------------------------------------------------------- transaksi

  void upsertTransaction(Transaction t) {
    final i = transactions.indexWhere((x) => x.id == t.id);
    if (i >= 0) {
      transactions[i] = t;
    } else {
      transactions.add(t);
    }
    _commit();
  }

  Transaction? deleteTransaction(String id) {
    final i = transactions.indexWhere((x) => x.id == id);
    if (i < 0) return null;
    final removed = transactions.removeAt(i);
    _commit();
    return removed;
  }

  void restoreTransaction(Transaction t) {
    if (transactions.any((x) => x.id == t.id)) return;
    transactions.add(t);
    _commit();
  }

  // ---------------------------------------------------------------- akun

  void upsertAccount(Account a) {
    final i = accounts.indexWhere((x) => x.id == a.id);
    if (i >= 0) {
      accounts[i] = a;
    } else {
      accounts.add(a);
    }
    _commit();
  }

  bool accountInUse(String id) =>
      transactions.any((t) => t.accountId == id || t.toAccountId == id) ||
      recurring.any((r) => r.accountId == id || r.toAccountId == id) ||
      templates.any((t) => t.accountId == id || t.toAccountId == id);

  /// null = berhasil, selain itu pesan error.
  String? deleteAccount(String id) {
    if (accounts.length <= 1) return 'Minimal harus ada satu akun.';
    if (accountInUse(id)) {
      return 'Akun ini masih dipakai transaksi, transaksi berulang, atau template. Hapus atau pindahkan dulu.';
    }
    accounts.removeWhere((a) => a.id == id);
    _commit();
    return null;
  }

  // ---------------------------------------------------------------- kategori

  void upsertCategory(TxCategory c) {
    final i = categories.indexWhere((x) => x.id == c.id);
    if (i >= 0) {
      categories[i] = c;
    } else {
      categories.add(c);
    }
    _commit();
  }

  String? deleteCategory(String id) {
    if (categories.any((c) => c.parentId == id)) {
      return 'Hapus sub-kategorinya dulu.';
    }
    final used = transactions.where((t) => t.categoryId == id).length;
    if (used > 0) return 'Kategori masih dipakai $used transaksi.';
    if (recurring.any((r) => r.categoryId == id) ||
        templates.any((t) => t.categoryId == id)) {
      return 'Kategori masih dipakai transaksi berulang atau template.';
    }
    final cat = categoryById(id);
    if (cat != null &&
        cat.parentId == null &&
        topCategories(cat.type).length <= 1) {
      return 'Minimal harus ada satu kategori ${cat.type.label.toLowerCase()}.';
    }
    categories.removeWhere((c) => c.id == id);
    settings.categoryBudgets.remove(id);
    _commit();
    return null;
  }

  // ---------------------------------------------------------------- budget

  void setBudget(BudgetPeriod period, double global, Map<String, double> perCat) {
    settings.budgetPeriod = period;
    settings.globalBudget = global;
    settings.categoryBudgets = perCat;
    _commit();
  }

  // ---------------------------------------------------------------- berulang

  void upsertRecurring(RecurringRule r) {
    final i = recurring.indexWhere((x) => x.id == r.id);
    if (i >= 0) {
      recurring[i] = r;
    } else {
      recurring.add(r);
    }
    _commit();
  }

  void deleteRecurring(String id) {
    recurring.removeWhere((r) => r.id == id);
    _commit();
  }

  void toggleRecurring(String id, bool active) {
    final today = dayOnly(DateTime.now());
    for (final r in recurring) {
      if (r.id != id) continue;
      r.active = active;
      if (active) {
        // Saat dilanjutkan, jadwal yang terlewat selama dijeda dilewati,
        // bukan dicatat sekaligus.
        var guard = 0;
        while (r.nextDate.isBefore(today) && guard < 2000) {
          r.generated++;
          guard++;
        }
      }
    }
    _commit();
  }

  /// Mencatat semua transaksi berulang yang sudah jatuh tempo.
  /// Mengembalikan jumlah transaksi baru.
  int processRecurring({bool notify = true}) {
    final now = DateTime.now();
    var created = 0;
    var changed = false;
    for (final r in recurring) {
      if (!r.active) continue;
      var guard = 0;
      while (guard < 500) {
        final due = r.nextDate;
        if (due.isAfter(now)) break;
        final id = 'rec_${r.id}_${due.millisecondsSinceEpoch}';
        if (!transactions.any((t) => t.id == id)) {
          transactions.add(Transaction(
            id: id,
            title: r.title,
            amount: r.amount,
            toAmount: r.toAmount,
            type: r.type,
            categoryId: r.categoryId,
            accountId: r.accountId,
            toAccountId: r.toAccountId,
            date: due,
            note: r.note,
            recurringId: r.id,
          ));
          created++;
        }
        r.generated++;
        changed = true;
        guard++;
      }
    }
    if (changed) {
      if (notify) {
        _commit();
      } else {
        _persist();
      }
    }
    return created;
  }

  // ---------------------------------------------------------------- template

  void addTemplate(TxTemplate t) {
    templates.add(t);
    _commit();
  }

  void deleteTemplate(String id) {
    templates.removeWhere((t) => t.id == id);
    _commit();
  }

  // ---------------------------------------------------------------- setting

  void setRates(Map<String, double> rates) {
    settings.rates = {...rates, 'IDR': 1};
    _commit();
  }

  void setPin(String? pin) {
    settings.pin = pin;
    _commit();
  }

  void updateSettings(void Function(AppSettings s) change) {
    change(settings);
    _commit();
  }

  /// Daftar pengingat yang perlu dijadwalkan ke sistem notifikasi Android.
  /// Dihitung ulang setiap kali data berubah.
  List<PlannedNotification> plannedNotifications() {
    final s = settings;
    final out = <PlannedNotification>[];
    if (!s.notifEnabled) return out;
    final now = DateTime.now();
    final hide = s.notifHideAmounts;
    var nextId = 1000;
    void add(DateTime when, String title, String body) {
      if (when.isAfter(now)) {
        out.add(PlannedNotification(
            id: nextId++, when: when, title: title, body: body));
      }
    }

    if (s.notifRecurring) {
      for (final r in recurring) {
        if (!r.active) continue;
        final amount = money(r.amount, currencyOf(r.accountId));
        // 3 jadwal ke depan, supaya tetap diingatkan walau app lama tidak dibuka.
        for (var k = 0; k < 3; k++) {
          final due = occurrence(r.start, r.frequency, r.generated + k);
          add(
              due,
              '🔁 ${r.title} jatuh tempo hari ini',
              hide
                  ? 'Buka Infinity supaya langsung tercatat.'
                  : '${r.type.label} $amount · ${accountName(r.accountId)}. Buka Infinity supaya langsung tercatat.');
          if (r.frequency == Frequency.monthly ||
              r.frequency == Frequency.yearly) {
            add(DateTime(due.year, due.month, due.day - 1, 19),
                '⏰ Besok: ${r.title}',
                hide
                    ? 'Pastikan saldonya cukup ya.'
                    : '$amount dari ${accountName(r.accountId)}. Pastikan saldonya cukup ya.');
          }
        }
      }
    }

    if (s.notifCredit) {
      for (final a in accounts.where((a) => a.type == AccountType.credit)) {
        final bal = balanceOf(a.id);
        if (bal >= 0) continue;
        final due = nextDueDate(a.dueDay, now);
        final debt = money(-bal, a.currency);
        add(DateTime(due.year, due.month, due.day - 3, 9),
            '💳 Tagihan ${a.name} 3 hari lagi',
            hide
                ? 'Jatuh tempo ${DateFormat('d MMM', 'id_ID').format(due)}. Cek nominalnya di Infinity.'
                : 'Tagihan $debt jatuh tempo ${DateFormat('d MMM', 'id_ID').format(due)}.');
        add(DateTime(due.year, due.month, due.day, 8),
            '💳 Hari ini jatuh tempo ${a.name}',
            hide
                ? 'Bayar tagihan hari ini supaya tidak kena denda.'
                : 'Bayar tagihan $debt hari ini supaya tidak kena denda.');
      }
    }

    if (s.dailyReminder) {
      var t = DateTime(
          now.year, now.month, now.day, s.reminderHour, s.reminderMinute);
      if (!t.isAfter(now)) {
        t = DateTime(now.year, now.month, now.day + 1, s.reminderHour,
            s.reminderMinute);
      }
      out.add(PlannedNotification(
          id: 1,
          when: t,
          title: '✍️ Sudah catat pengeluaran hari ini?',
          body: 'Catat sekarang biar saldo dan budget tetap akurat.',
          daily: true));
    }
    return out;
  }

  // ---------------------------------------------------------------- notifikasi bank

  String? accountForPackage(String pkg) {
    final info = _appInfo(pkg);
    if (info == null) return null;
    final kw = info[2];
    for (final a in accounts) {
      if (a.name.toLowerCase().contains(kw)) return a.id;
    }
    return null;
  }

  String? fallbackCategory(TxType type) {
    if (type == TxType.expense) {
      final lain = categoryById('lain');
      if (lain != null && lain.type == type) return lain.id;
    }
    final tops = topCategories(type);
    return tops.isEmpty ? null : tops.first.id;
  }

  TxDraft draftFromCapture(CapturedNotif c) {
    final p = parseReceipt(c.fullText, this);
    final type = p.type ?? TxType.expense;
    return TxDraft(
      type: type,
      title: p.title ?? '',
      amount: p.amount ?? 0,
      categoryId: p.categoryId ?? fallbackCategory(type),
      accountId:
          p.accountId ?? accountForPackage(c.pkg) ?? accounts.first.id,
      date: c.time,
      note: 'Dari notifikasi ${appLabelForPackage(c.pkg)}',
    );
  }

  /// Memproses notifikasi uang dari native. Mode "auto" langsung mencatat
  /// kalau akun bisa ditebak dan tidak terlihat dobel; sisanya masuk antrean.
  /// Mengembalikan jumlah transaksi yang langsung dicatat.
  int ingestCaptured(List<Map<String, dynamic>> raw) {
    if (raw.isEmpty || settings.captureMode == 'off') return 0;
    var auto = 0;
    var changed = false;
    for (final r in raw) {
      final pkg = _s(r['pkg']) ?? '';
      final title = (_s(r['title']) ?? '').trim();
      final text = (_s(r['text']) ?? '').trim();
      final time = DateTime.fromMillisecondsSinceEpoch(
          _i(r['time'], DateTime.now().millisecondsSinceEpoch));
      // Notifikasi yang sama sering dikirim ulang (update), jadi dedupe
      // berdasarkan isi dalam jendela 3 menit.
      final key = '$pkg|$title|$text@${time.millisecondsSinceEpoch ~/ 180000}';
      if (_seenCaptureKeys.contains(key)) continue;
      _seenCaptureKeys.add(key);
      changed = true;

      final lower = '$title $text'.toLowerCase();
      if (_promoWords.any(lower.contains)) continue;

      final c = CapturedNotif(
          id: newId(), pkg: pkg, title: title, text: text, time: time);
      final p = parseReceipt(c.fullText, this);
      final amount = p.amount;
      if (amount == null) continue;
      final type = p.type ?? TxType.expense;
      final accountId = p.accountId ?? accountForPackage(pkg);
      final categoryId = p.categoryId ?? fallbackCategory(type);
      final looksDuplicate = accountId != null &&
          transactions.any((t) =>
              t.accountId == accountId &&
              (t.amount - amount).abs() < 0.5 &&
              t.date.difference(time).inMinutes.abs() <= 10);

      if (settings.captureMode == 'auto' &&
          accountId != null &&
          categoryId != null &&
          !looksDuplicate) {
        transactions.add(Transaction(
          id: 'ntf_${time.millisecondsSinceEpoch}_${newId()}',
          title: p.title ?? 'Transaksi ${appLabelForPackage(pkg)}',
          amount: amount,
          type: type,
          categoryId: categoryId,
          accountId: accountId,
          date: time,
          note: 'Otomatis dari notifikasi ${appLabelForPackage(pkg)}',
        ));
        auto++;
      } else {
        pendingCaptures.add(c);
      }
    }
    if (_seenCaptureKeys.length > 600) {
      _seenCaptureKeys =
          _seenCaptureKeys.sublist(_seenCaptureKeys.length - 600);
    }
    if (pendingCaptures.length > 50) {
      pendingCaptures = pendingCaptures.sublist(pendingCaptures.length - 50);
    }
    if (changed) _commit();
    return auto;
  }

  /// Data teks untuk widget layar utama.
  Map<String, String> widgetData() {
    final now = DateTime.now();
    final s = settings;
    final hide = s.hideBalance;
    final month = monthRange(now);
    final income = sumIDR(TxType.income, month);
    final expense = sumIDR(TxType.expense, month);
    String budget = 'Anggaran belum diatur';
    if (s.globalBudget > 0) {
      final spent = sumIDR(TxType.expense, s.budgetPeriod.range(now));
      final remaining = s.globalBudget - spent;
      final pct = (remaining / s.globalBudget * 100).clamp(0, 100).round();
      budget = hide
          ? 'Sisa anggaran $pct%'
          : 'Sisa anggaran ${money(remaining)} ($pct%)';
    }
    return {
      'w_month': DateFormat('MMMM yyyy', 'id_ID').format(now),
      'w_balance': hide ? 'Rp ••••••' : money(netWorthIDR),
      'w_income': hide ? 'Masuk ••••' : 'Masuk ${money(income)}',
      'w_expense': hide ? 'Keluar ••••' : 'Keluar ${money(expense)}',
      'w_budget': budget,
    };
  }

  void dismissCapture(String id) {
    pendingCaptures.removeWhere((c) => c.id == id);
    _commit();
  }

  void clearCaptures() {
    pendingCaptures = [];
    _commit();
  }

  void toggleHideBalance() {
    settings.hideBalance = !settings.hideBalance;
    _commit();
  }
}

// =============================================================================
// NOTIFIKASI
// =============================================================================

class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.when,
    required this.title,
    required this.body,
    this.daily = false,
  });

  final int id;
  final DateTime when;
  final String title;
  final String body;

  /// true = diulang setiap hari di jam yang sama.
  final bool daily;
}

// NOTIF-IMPL-BEGIN
/// Pembungkus flutter_local_notifications (v22). Notifikasi dijadwalkan ke
/// sistem Android, jadi tetap muncul walau aplikasi ditutup.
class Notifier {
  Notifier._();
  static final Notifier instance = Notifier._();

  final fln.FlutterLocalNotificationsPlugin _plugin =
      fln.FlutterLocalNotificationsPlugin();
  bool _ready = false;

  bool get supported => _ready;

  static const fln.NotificationDetails _details = fln.NotificationDetails(
    android: fln.AndroidNotificationDetails(
      'infinity_reminder',
      'Pengingat Infinity',
      channelDescription:
          'Pengingat tagihan, transaksi berulang, anggaran, dan catatan harian',
      importance: fln.Importance.high,
      priority: fln.Priority.high,
      // Di layar kunci isi notifikasi disembunyikan (ikut setelan privasi HP).
      visibility: fln.NotificationVisibility.private,
    ),
  );

  Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        settings: const fln.InitializationSettings(
          android: fln.AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          fln.AndroidFlutterLocalNotificationsPlugin>();
      return (await android?.requestNotificationsPermission()) ?? true;
    } catch (_) {
      return false;
    }
  }

  Future<void> showNow(int id, String title, String body) async {
    if (!_ready) return;
    try {
      await _plugin.show(
          id: id, title: title, body: body, notificationDetails: _details);
    } catch (_) {}
  }

  /// Hapus semua jadwal lama lalu pasang jadwal baru.
  Future<void> replaceSchedule(List<PlannedNotification> items) async {
    if (!_ready) return;
    try {
      await _plugin.cancelAllPendingNotifications();
      for (final n in items) {
        await _plugin.zonedSchedule(
          id: n.id,
          title: n.title,
          body: n.body,
          // Waktu absolut (UTC) supaya tepat di zona waktu mana pun
          // (WIB/WITA/WIT) tanpa package zona waktu tambahan.
          scheduledDate: tz.TZDateTime.from(n.when.toUtc(), tz.UTC),
          notificationDetails: _details,
          // Inexact: tidak butuh izin "alarm tepat waktu", meleset beberapa menit.
          androidScheduleMode: fln.AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents:
              n.daily ? fln.DateTimeComponents.time : null,
        );
      }
    } catch (_) {}
  }
}
// NOTIF-IMPL-END

// =============================================================================
// APP SHELL
// =============================================================================

class InfinityApp extends StatelessWidget {
  const InfinityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Infinity',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: C.green,
          primary: C.greenDark,
          error: C.redDark,
        ),
        scaffoldBackgroundColor: C.bg,
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: C.carbon,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      home: const RootPage(),
    );
  }
}

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> with WidgetsBindingObserver {
  final AppStore store = AppStore();
  int _tab = 0;
  bool _locked = false;
  DateTime? _pausedAt;
  Timer? _notifDebounce;
  Timer? _capturePoll;
  StreamSubscription<Uri?>? _widgetSub;
  TxType? _pendingWidgetAction;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    await store.load();
    await Notifier.instance.init();
    if (store.settings.notifEnabled) {
      unawaited(Notifier.instance.requestPermission());
    }
    store.addListener(_scheduleNotifications);
    _scheduleNotifications();
    unawaited(NativeBridge.setSecure(store.settings.secureScreen));
    await _ingestCaptures(quiet: true);
    // Saat app terbuka, cek notifikasi bank/e-wallet baru setiap 20 detik.
    _capturePoll = Timer.periodic(
        const Duration(seconds: 20), (_) => _ingestCaptures());
    _widgetSub = HomeWidgetBridge.clicks().listen(_handleWidgetUri);
    final launch = await HomeWidgetBridge.initialLaunch();
    if (!mounted) return;
    setState(() => _locked = store.settings.pin != null);
    _handleWidgetUri(launch);
    final warning = store.loadWarning;
    if (warning != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) snack(context, warning);
      });
    }
  }

  /// Setiap data berubah (dengan jeda kecil): jadwal notifikasi, widget, dan
  /// mode layar aman diperbarui.
  void _scheduleNotifications() {
    _notifDebounce?.cancel();
    _notifDebounce = Timer(const Duration(milliseconds: 800), () {
      unawaited(
          Notifier.instance.replaceSchedule(store.plannedNotifications()));
      unawaited(HomeWidgetBridge.update(store.widgetData()));
      unawaited(NativeBridge.setSecure(store.settings.secureScreen));
    });
  }

  Future<void> _ingestCaptures({bool quiet = false}) async {
    if (!store.loaded || store.settings.captureMode == 'off') return;
    final raw = await NativeBridge.fetchCaptured();
    if (raw.isEmpty || !mounted) return;
    final before = store.pendingCaptures.length;
    final auto = store.ingestCaptured(raw);
    final waiting = store.pendingCaptures.length - before;
    if (!mounted || quiet && auto == 0 && waiting <= 0) return;
    if (auto > 0) {
      snack(context, '$auto transaksi tercatat otomatis dari notifikasi 🤖');
    } else if (waiting > 0) {
      snack(context,
          '$waiting transaksi dari notifikasi menunggu dicek di Beranda');
    }
  }

  /// Tombol widget: infinity://add?type=expense|income|transfer
  void _handleWidgetUri(Uri? uri) {
    if (uri == null || uri.host != 'add') return;
    final type = switch (uri.queryParameters['type']) {
      'income' => TxType.income,
      'transfer' => TxType.transfer,
      _ => TxType.expense,
    };
    if (_locked && store.settings.pin != null) {
      _pendingWidgetAction = type;
      return;
    }
    _openFromWidget(type);
  }

  void _openFromWidget(TxType type) {
    setState(() => _tab = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) openTxForm(context, store, type: type);
    });
  }

  void _unlock() {
    setState(() => _locked = false);
    final pending = _pendingWidgetAction;
    _pendingWidgetAction = null;
    if (pending != null) _openFromWidget(pending);
  }

  @override
  void dispose() {
    _notifDebounce?.cancel();
    _capturePoll?.cancel();
    _widgetSub?.cancel();
    store.removeListener(_scheduleNotifications);
    WidgetsBinding.instance.removeObserver(this);
    store.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final pausedAt = _pausedAt;
      _pausedAt = null;
      if (!store.loaded) return;
      final created = store.processRecurring();
      _scheduleNotifications();
      unawaited(_ingestCaptures());
      if (store.settings.pin != null &&
          pausedAt != null &&
          DateTime.now().difference(pausedAt).inSeconds >= 30) {
        setState(() => _locked = true);
      }
      if (created > 0 && mounted) {
        snack(context, '$created transaksi berulang otomatis tercatat');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        if (!store.loaded) return const SplashScreen();
        final pin = store.settings.pin;
        if (_locked && pin != null) {
          return PinLockScreen(
            pin: pin,
            biometric: store.settings.biometric,
            onUnlocked: _unlock,
          );
        }
        final pages = <Widget>[
          DashboardTab(store: store, onSeeAll: () => setState(() => _tab = 1)),
          HistoryTab(store: store),
          StatsTab(store: store),
          MoreTab(store: store),
        ];
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: (_tab == 0
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark)
              .copyWith(statusBarColor: Colors.transparent),
          child: Scaffold(
            backgroundColor: C.bg,
            body: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: IndexedStack(index: _tab, children: pages),
              ),
            ),
            floatingActionButton: _tab <= 1
                ? FloatingActionButton.extended(
                    onPressed: () => openTxForm(context, store),
                    backgroundColor: C.greenDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22)),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Catat',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  )
                : null,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              backgroundColor: Colors.white,
              indicatorColor: C.green.withValues(alpha: 0.18),
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: 'Beranda'),
                NavigationDestination(
                    icon: Icon(Icons.receipt_long_outlined),
                    selectedIcon: Icon(Icons.receipt_long_rounded),
                    label: 'Riwayat'),
                NavigationDestination(
                    icon: Icon(Icons.pie_chart_outline),
                    selectedIcon: Icon(Icons.pie_chart_rounded),
                    label: 'Statistik'),
                NavigationDestination(
                    icon: Icon(Icons.grid_view_outlined),
                    selectedIcon: Icon(Icons.grid_view_rounded),
                    label: 'Lainnya'),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: C.greenDark,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.all_inclusive_rounded, color: Colors.white, size: 64),
            SizedBox(height: 12),
            Text('Infinity',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900)),
            SizedBox(height: 24),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SHARED UI
// =============================================================================

void snack(BuildContext context, String message, {SnackBarAction? action}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(content: Text(message), action: action));
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Ya',
  bool destructive = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal')),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: destructive ? C.redDark : C.greenDark,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20))),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return r ?? false;
}

PreferredSizeWidget pageBar(String title, {List<Widget>? actions}) => AppBar(
      title: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.w900, fontSize: 19, color: C.carbon)),
      backgroundColor: C.bg,
      foregroundColor: C.carbon,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      actions: actions,
    );

InputDecoration fieldDeco(String label,
    {IconData? icon, String? prefix, String? helper, Color accent = C.greenDark}) {
  return InputDecoration(
    labelText: label,
    helperText: helper,
    helperMaxLines: 3,
    prefixIcon: icon == null ? null : Icon(icon),
    prefixText: prefix,
    filled: true,
    fillColor: C.bg,
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: C.line)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: accent, width: 2)),
  );
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color = Colors.white,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class CatIcon extends StatelessWidget {
  const CatIcon(
      {super.key, required this.icon, required this.color, this.size = 44});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: darken(color), size: size * 0.5),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: C.carbon)),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class SmallLabel extends StatelessWidget {
  const SmallLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w800, color: C.carbon));
  }
}

class FunProgressBar extends StatelessWidget {
  const FunProgressBar(
      {super.key, required this.value, required this.color, this.height = 14});

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final target = (value.isNaN || value.isInfinite) ? 0.0 : value.clamp(0.0, 1.0);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: C.line,
        borderRadius: BorderRadius.circular(height),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: target),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: v,
            heightFactor: 1,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(height),
                gradient:
                    LinearGradient(colors: [color.withValues(alpha: 0.7), color]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Segmented control serbaguna dengan warna per item.
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.colorOf,
    this.iconOf,
    this.dense = false,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;
  final Color Function(T)? colorOf;
  final IconData Function(T)? iconOf;
  final bool dense;

  Widget _item(T v) {
    final isSel = v == selected;
    final fg = isSel ? Colors.white : C.muted;
    final bg = isSel ? (colorOf?.call(v) ?? C.greenDark) : Colors.transparent;
    final icon = iconOf?.call(v);
    return Expanded(
      child: Semantics(
        button: true,
        selected: isSel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(v);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: EdgeInsets.symmetric(vertical: dense ? 9 : 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 15, color: fg),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(labelOf(v),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: dense ? 12 : 12.5,
                          fontWeight: FontWeight.w800,
                          color: fg)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: C.line),
      ),
      child: Row(children: values.map(_item).toList()),
    );
  }
}

/// Wadah bottom sheet bersudut membulat yang aman dari keyboard.
class SheetFrame extends StatelessWidget {
  const SheetFrame({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Align(
      alignment: Alignment.bottomCenter,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: C.line,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<T?> showSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => child,
  );
}

class ErrorBox extends StatelessWidget {
  const ErrorBox(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: C.redDark, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    color: C.redDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.color = C.greenDark,
      this.icon});

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 54,
      decoration: BoxDecoration(
        color: onPressed == null ? C.muted : color,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onPressed,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key, required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: C.green.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: C.greenDark, size: 30),
          ),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: C.carbon)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: C.muted, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

/// Pemilih akun horizontal (bisa banyak akun).
class AccountPicker extends StatelessWidget {
  const AccountPicker({
    super.key,
    required this.store,
    required this.selectedId,
    required this.onSelected,
    required this.accent,
    this.disabledId,
    this.excludeTxId,
  });

  final AppStore store;
  final String selectedId;
  final String? disabledId;
  final String? excludeTxId;
  final Color accent;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: store.accounts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final a = store.accounts[i];
          final sel = a.id == selectedId;
          final disabled = a.id == disabledId;
          final bal = store.balanceOf(a.id, excludeTxId: excludeTxId);
          return Opacity(
            opacity: disabled ? 0.35 : 1,
            child: GestureDetector(
              onTap: disabled ? null : () => onSelected(a.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 128,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: sel ? accent.withValues(alpha: 0.1) : C.bg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: sel ? accent : C.line, width: sel ? 2 : 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(a.type.icon, color: darken(a.colorValue), size: 18),
                        const Spacer(),
                        if (sel)
                          Icon(Icons.check_circle_rounded,
                              color: accent, size: 16),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(a.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: C.carbon)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(money(bal, a.currency),
                          style: TextStyle(
                              fontSize: 11,
                              color: bal < 0 ? C.redDark : C.muted)),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class DonutChartPainter extends CustomPainter {
  DonutChartPainter(
      {required this.values, required this.colors, required this.progress});

  final List<double> values;
  final List<Color> colors;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 22.0;
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - stroke / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = C.line
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke);

    final total = values.fold(0.0, (s, v) => s + v);
    if (total <= 0) return;

    const gap = 0.03;
    final useGap = values.length > 1;
    var start = -math.pi / 2;
    final full = 2 * math.pi * progress;
    for (var i = 0; i < values.length; i++) {
      final sweep = full * (values[i] / total);
      final draw = useGap ? math.max(0.0, sweep - gap) : sweep;
      if (draw > 0) {
        canvas.drawArc(
            rect,
            start,
            draw,
            false,
            Paint()
              ..color = colors[i]
              ..style = PaintingStyle.stroke
              ..strokeWidth = stroke
              ..strokeCap = StrokeCap.butt);
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter old) {
    if (old.progress != progress || old.values.length != values.length) {
      return true;
    }
    for (var i = 0; i < values.length; i++) {
      if (old.values[i] != values[i] || old.colors[i] != colors[i]) return true;
    }
    return false;
  }
}

class TrendBucket {
  const TrendBucket(this.label, this.income, this.expense);
  final String label;
  final double income;
  final double expense;
}

class TrendChart extends StatelessWidget {
  const TrendChart({super.key, required this.buckets, this.height = 150});
  final List<TrendBucket> buckets;
  final double height;

  Widget _bar(double v, double maxV, Color c, double width) {
    final target = maxV <= 0 ? 0.0 : v / maxV;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, f, _) => Container(
        width: width,
        height: math.max(f * height, v > 0 ? 3.0 : 0.0),
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(width / 2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxV = buckets.fold(
        0.0, (m, b) => math.max(m, math.max(b.income, b.expense)));
    final barW = buckets.length > 8 ? 7.0 : 11.0;
    return Column(
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final b in buckets)
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _bar(b.income, maxV, C.green, barW),
                      const SizedBox(width: 2),
                      _bar(b.expense, maxV, C.red, barW),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final b in buckets)
              Expanded(
                child: Text(b.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: const TextStyle(fontSize: 10, color: C.muted)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendDot(color: C.green, label: 'Pemasukan'),
            SizedBox(width: 16),
            _LegendDot(color: C.red, label: 'Pengeluaran'),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: C.muted)),
      ],
    );
  }
}

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

// =============================================================================
// AKSI TRANSAKSI (dipakai banyak layar)
// =============================================================================

String _defaultTitle(AppStore store, TxDraft d) {
  if (d.type == TxType.transfer) {
    return 'Transfer ke ${store.accountName(d.toAccountId)}';
  }
  return store.categoryById(d.categoryId)?.name ?? d.type.label;
}

Future<FormResult?> showTxForm(
  BuildContext context,
  AppStore store, {
  required TxDraft draft,
  FormMode mode = FormMode.transaction,
  String? excludeTxId,
  bool isEditing = false,
  Frequency? frequency,
}) {
  return showSheet<FormResult>(
    context,
    TxFormSheet(
      store: store,
      draft: draft,
      mode: mode,
      excludeTxId: excludeTxId,
      isEditing: isEditing,
      frequency: frequency,
    ),
  );
}

/// Mengembalikan true kalau transaksi disimpan.
Future<bool> openTxForm(
  BuildContext context,
  AppStore store, {
  TxType type = TxType.expense,
  TxTemplate? template,
  TxDraft? prefill,
  bool keepPrefillDate = false,
  String? toAccountId,
  double? amount,
}) async {
  TxDraft draft;
  if (prefill != null) {
    if (!keepPrefillDate) prefill.date = DateTime.now();
    draft = prefill;
  } else if (template != null) {
    draft = TxDraft.fromTemplate(template);
  } else {
    var from = store.accounts.first.id;
    if (toAccountId != null) {
      from = store.accounts
          .firstWhere(
              (a) => a.id != toAccountId && a.type != AccountType.credit,
              orElse: () => store.accounts.first)
          .id;
    }
    draft = TxDraft(
        type: type,
        accountId: from,
        toAccountId: toAccountId,
        amount: amount ?? 0);
  }
  final r = await showTxForm(context, store, draft: draft);
  if (r == null || !context.mounted) return false;
  final before = store.budgetStatusNow();
  final t = r.draft.toTransaction(store.newId());
  store.upsertTransaction(t);
  if (r.saveAsTemplate) store.addTemplate(r.draft.toTemplate(store.newId()));

  final status = store.budgetStatusNow();
  final st = store.settings;
  if (t.type == TxType.expense &&
      st.notifEnabled &&
      st.notifBudget &&
      status != null &&
      status != BudgetStatus.safe &&
      status != before) {
    final spent =
        store.sumIDR(TxType.expense, st.budgetPeriod.range(DateTime.now()));
    unawaited(Notifier.instance.showNow(
        2,
        'Anggaran ${st.budgetPeriod.current}: ${status.message}',
        st.notifHideAmounts
            ? 'Buka Infinity untuk lihat sisa anggaran.'
            : 'Sisa ${money(st.globalBudget - spent)} dari ${money(st.globalBudget)}.'));
  }
  if (t.type == TxType.expense && status == BudgetStatus.broke) {
    snack(context,
        '${BudgetStatus.broke.message} Anggaran ${store.settings.budgetPeriod.current} hampir habis.');
  } else {
    snack(context,
        '${t.type.label} ${money(t.amount, store.currencyOf(t.accountId))} tercatat ✅');
  }
  return true;
}

Future<void> editTx(BuildContext context, AppStore store, Transaction t) async {
  final r = await showTxForm(context, store,
      draft: TxDraft.fromTransaction(t), excludeTxId: t.id, isEditing: true);
  if (r == null || !context.mounted) return;
  store.upsertTransaction(
      r.draft.toTransaction(t.id, recurringId: t.recurringId));
  snack(context, 'Transaksi diperbarui ✏️');
}

void deleteWithUndo(BuildContext context, AppStore store, Transaction t) {
  final removed = store.deleteTransaction(t.id);
  if (removed == null) return;
  snack(
    context,
    '"${t.title}" dihapus',
    action: SnackBarAction(
      label: 'URUNGKAN',
      textColor: const Color(0xFF7CFC8A),
      onPressed: () => store.restoreTransaction(removed),
    ),
  );
}

enum _DetailAction { edit, duplicate, copy, delete }

Future<void> openTxDetail(
    BuildContext context, AppStore store, Transaction t) async {
  final action = await showSheet<_DetailAction>(
      context, TransactionDetailSheet(store: store, transaction: t));
  if (action == null || !context.mounted) return;
  switch (action) {
    case _DetailAction.edit:
      await editTx(context, store, t);
    case _DetailAction.duplicate:
      await openTxForm(context, store, prefill: TxDraft.fromTransaction(t));
    case _DetailAction.copy:
      await Clipboard.setData(ClipboardData(text: txShareText(store, t)));
      if (context.mounted) snack(context, 'Teks transaksi disalin 📋');
    case _DetailAction.delete:
      deleteWithUndo(context, store, t);
  }
}

Future<void> openRecurringForm(BuildContext context, AppStore store,
    {RecurringRule? rule}) async {
  final draft = rule == null
      ? TxDraft(
          type: TxType.expense,
          accountId: store.accounts.first.id,
          date: DateTime.now())
      : TxDraft(
          type: rule.type,
          title: rule.title,
          amount: rule.amount,
          toAmount: rule.toAmount,
          categoryId: rule.categoryId,
          accountId: rule.accountId,
          toAccountId: rule.toAccountId,
          note: rule.note,
          date: rule.nextDate);
  final r = await showTxForm(context, store,
      draft: draft,
      mode: FormMode.recurring,
      frequency: rule?.frequency ?? Frequency.monthly,
      isEditing: rule != null);
  if (r == null || !context.mounted) return;
  final d = r.draft;
  store.upsertRecurring(RecurringRule(
    id: rule?.id ?? store.newId(),
    title: d.title,
    amount: d.amount,
    toAmount: d.type == TxType.transfer ? d.toAmount : null,
    type: d.type,
    categoryId: d.type == TxType.transfer ? null : d.categoryId,
    accountId: d.accountId,
    toAccountId: d.type == TxType.transfer ? d.toAccountId : null,
    note: d.note,
    frequency: r.frequency ?? Frequency.monthly,
    start: d.date,
    active: rule?.active ?? true,
  ));
  final created = store.processRecurring();
  snack(
      context,
      created > 0
          ? 'Tersimpan. $created transaksi yang sudah jatuh tempo langsung dicatat.'
          : 'Transaksi berulang tersimpan 🔁');
}

Future<void> openTemplateForm(BuildContext context, AppStore store) async {
  final r = await showTxForm(context, store,
      draft: TxDraft(type: TxType.expense, accountId: store.accounts.first.id),
      mode: FormMode.template);
  if (r == null || !context.mounted) return;
  store.addTemplate(r.draft.toTemplate(store.newId()));
  snack(context, 'Template tersimpan ⚡');
}

/// Baris transaksi gaya Gojek + swipe kiri untuk hapus.
Widget txTile(BuildContext context, AppStore store, Transaction t,
    {bool showDate = false}) {
  final cur = store.currencyOf(t.accountId);
  final String amountText;
  final Color amountColor;
  switch (t.type) {
    case TxType.expense:
      amountText = '-${money(t.amount, cur)}';
      amountColor = C.redDark;
    case TxType.income:
      amountText = '+${money(t.amount, cur)}';
      amountColor = C.greenDark;
    case TxType.transfer:
      amountText = money(t.amount, cur);
      amountColor = C.blueDark;
  }
  final accountText = t.type == TxType.transfer
      ? '${store.accountName(t.accountId)} → ${store.accountName(t.toAccountId)}'
      : store.accountName(t.accountId);
  final when = showDate
      ? DateFormat('d MMM · HH:mm', 'id_ID').format(t.date)
      : DateFormat('HH:mm').format(t.date);

  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Dismissible(
      key: ValueKey('tx_${t.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: C.redDark,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Hapus',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
            SizedBox(width: 8),
            Icon(Icons.delete_rounded, color: Colors.white),
          ],
        ),
      ),
      onDismissed: (_) => deleteWithUndo(context, store, t),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => openTxDetail(context, store, t),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CatIcon(icon: store.txIcon(t), color: store.txColor(t)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(t.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: C.carbon)),
                          ),
                          if (t.recurringId != null) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.repeat_rounded,
                                size: 14, color: C.muted),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text('$accountText · $when',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(fontSize: 12, color: C.muted)),
                      if (t.note.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('“${t.note}”',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  fontStyle: FontStyle.italic,
                                  color: C.muted)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(amountText,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: amountColor)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Daftar transaksi dikelompokkan per hari (dengan net harian dalam IDR).
List<Widget> groupedTxWidgets(
    BuildContext context, AppStore store, List<Transaction> list) {
  final sorted = [...list]..sort((a, b) => b.date.compareTo(a.date));
  final groups = <DateTime, List<Transaction>>{};
  for (final t in sorted) {
    groups.putIfAbsent(dayOnly(t.date), () => []).add(t);
  }
  final widgets = <Widget>[];
  groups.forEach((day, items) {
    var net = 0.0;
    for (final t in items) {
      if (t.type == TxType.income) net += store.amountIDR(t);
      if (t.type == TxType.expense) net -= store.amountIDR(t);
    }
    widgets.add(Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(dayLabel(day),
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800, color: C.muted)),
          ),
          Text(net > 0 ? '+${money(net)}' : money(net),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: net > 0
                      ? C.greenDark
                      : (net < 0 ? C.redDark : C.muted))),
        ],
      ),
    ));
    for (final t in items) {
      widgets.add(txTile(context, store, t));
    }
  });
  return widgets;
}

// =============================================================================
// TAB 1: BERANDA
// =============================================================================

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key, required this.store, required this.onSeeAll});
  final AppStore store;
  final VoidCallback onSeeAll;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 11) return 'Selamat pagi! Yuk mulai catat cuanmu ☀️';
    if (h < 15) return 'Selamat siang! Udah makan belum? 🍜';
    if (h < 18) return 'Selamat sore! Cek dompet dulu yuk 👀';
    return 'Selamat malam! Rekap hari ini, yuk 🌙';
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final credits = store.accounts
        .where((a) => a.type == AccountType.credit)
        .toList();
    final upcoming = store.recurring.where((r) => r.active).toList()
      ..sort((a, b) => a.nextDate.compareTo(b.nextDate));
    final recent = [...store.transactions]
      ..sort((a, b) => b.date.compareTo(a.date));

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _header(context)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (store.pendingCaptures.isNotEmpty) ...[
                _capturesCard(context),
                const SizedBox(height: 12),
              ],
              if (credits.isNotEmpty) ...[
                _creditCard(context, credits),
                const SizedBox(height: 12),
              ],
              _budgetCard(context),
              const SizedBox(height: 12),
              if (store.templates.isNotEmpty) ...[
                _templatesCard(context),
                const SizedBox(height: 12),
              ],
              if (upcoming.isNotEmpty) ...[
                _upcomingCard(context, upcoming.take(3).toList()),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
              SectionTitle('Transaksi Terakhir',
                  trailing: TextButton(
                      onPressed: onSeeAll, child: const Text('Lihat semua'))),
              const SizedBox(height: 4),
              if (recent.isEmpty)
                const AppCard(
                  child: EmptyState(
                      icon: Icons.receipt_long_rounded,
                      title: 'Belum ada transaksi',
                      subtitle: 'Ketuk tombol "Catat" buat mulai.'),
                )
              else
                for (final t in recent.take(5))
                  txTile(context, store, t, showDate: true),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context) {
    final total = store.netWorthIDR;
    final hide = store.settings.hideBalance;
    return Container(
      decoration: const BoxDecoration(
        color: C.greenDark,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.paddingOf(context).top + 14, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.all_inclusive_rounded,
                    color: C.greenDark, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Infinity',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900)),
                    Text(_greeting(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                onPressed: store.toggleHideBalance,
                tooltip: hide ? 'Tampilkan saldo' : 'Sembunyikan saldo',
                icon: Icon(
                    hide
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 8)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: C.blue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Total Saldo Bersih',
                          style: TextStyle(
                              color: C.blueDark,
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () =>
                          _push(context, AccountsPage(store: store)),
                      child: const Text('Kelola akun'),
                    ),
                  ],
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    hide ? 'Rp ••••••••' : money(total),
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: total < 0 ? C.redDark : C.carbon),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: store.accounts.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) =>
                        _accountTile(context, store.accounts[i], hide),
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: C.line),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _quickAction(Icons.north_east_rounded, 'Bayar', C.redDark,
                        () => openTxForm(context, store)),
                    _quickAction(Icons.south_west_rounded, 'Terima',
                        C.greenDark,
                        () => openTxForm(context, store, type: TxType.income)),
                    _quickAction(Icons.swap_horiz_rounded, 'Transfer',
                        C.blueDark,
                        () => openTxForm(context, store,
                            type: TxType.transfer)),
                    _quickAction(Icons.track_changes_rounded, 'Budget',
                        C.amberDark,
                        () => _push(context, BudgetPage(store: store))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountTile(BuildContext context, Account a, bool hide) {
    final bal = store.balanceOf(a.id);
    return GestureDetector(
      onTap: () => showSheet<void>(
          context, AccountEditorSheet(store: store, account: a)),
      child: Container(
        width: 136,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: a.colorValue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CatIcon(icon: a.type.icon, color: a.colorValue, size: 28),
                const Spacer(),
                if (a.currency != 'IDR')
                  Text(a.currency,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: C.muted)),
              ],
            ),
            const SizedBox(height: 6),
            Text(a.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11, color: C.muted, fontWeight: FontWeight.w600)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(hide ? '•••••' : money(bal, a.currency),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: bal < 0 ? C.redDark : C.carbon)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(16)),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 6),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: C.carbon)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _capturesCard(BuildContext context) {
    final items = store.pendingCaptures.reversed.take(3).toList();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle('Dari Notifikasi (${store.pendingCaptures.length})',
              trailing: TextButton(
                  onPressed: () =>
                      _push(context, AutoCapturePage(store: store)),
                  child: const Text('Atur'))),
          for (final c in items) _captureRow(context, c),
        ],
      ),
    );
  }

  Widget _captureRow(BuildContext context, CapturedNotif c) {
    final p = parseReceipt(c.fullText, store);
    final amount = p.amount ?? 0;
    final isIncome = (p.type ?? TxType.expense) == TxType.income;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CatIcon(
                  icon: Icons.notifications_active_rounded,
                  color: C.amber,
                  size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${appLabelForPackage(c.pkg)} · ${DateFormat('d MMM HH:mm', 'id_ID').format(c.time)}',
                        style: const TextStyle(
                            fontSize: 12,
                            color: C.muted,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(c.fullText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text('${isIncome ? '+' : '-'}${money(amount)}',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: isIncome ? C.greenDark : C.redDark)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => store.dismissCapture(c.id),
                child: const Text('Abaikan'),
              ),
              const SizedBox(width: 4),
              FilledButton.tonal(
                onPressed: () async {
                  final saved = await openTxForm(context, store,
                      prefill: store.draftFromCapture(c),
                      keepPrefillDate: true);
                  if (saved) store.dismissCapture(c.id);
                },
                child: const Text('Catat'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _creditCard(BuildContext context, List<Account> cards) {
    final now = DateTime.now();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Kartu Kredit'),
          const SizedBox(height: 8),
          for (final a in cards) ...[
            Builder(builder: (context) {
              final bal = store.balanceOf(a.id);
              final debt = bal < 0 ? -bal : 0.0;
              final due = nextDueDate(a.dueDay, now);
              final days = due.difference(dayOnly(now)).inDays;
              final used = a.creditLimit > 0 ? debt / a.creditLimit : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CatIcon(
                            icon: Icons.credit_card_rounded,
                            color: a.colorValue,
                            size: 38),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14)),
                              Text(
                                debt > 0
                                    ? 'Jatuh tempo ${DateFormat('d MMM', 'id_ID').format(due)} · ${days == 0 ? 'hari ini' : '$days hari lagi'}'
                                    : 'Tidak ada tagihan 🎉',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: debt > 0 && days <= 3
                                        ? C.redDark
                                        : C.muted,
                                    fontWeight: debt > 0 && days <= 3
                                        ? FontWeight.w800
                                        : FontWeight.w400),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Tagihan',
                                style:
                                    TextStyle(fontSize: 11, color: C.muted)),
                            Text(money(debt, a.currency),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: C.redDark)),
                          ],
                        ),
                      ],
                    ),
                    if (a.creditLimit > 0) ...[
                      const SizedBox(height: 8),
                      FunProgressBar(
                          value: used,
                          color: used > 0.9
                              ? C.redDark
                              : (used > 0.5 ? C.amberDark : C.blueDark),
                          height: 8),
                      const SizedBox(height: 4),
                      Text(
                          'Sisa limit ${money(a.creditLimit - debt, a.currency)} dari ${money(a.creditLimit, a.currency)}',
                          style:
                              const TextStyle(fontSize: 11.5, color: C.muted)),
                    ],
                    if (debt > 0)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => openTxForm(context, store,
                              type: TxType.transfer,
                              toAccountId: a.id,
                              amount: debt),
                          icon: const Icon(Icons.payments_rounded, size: 18),
                          label: const Text('Bayar tagihan'),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _budgetCard(BuildContext context) {
    final s = store.settings;
    final now = DateTime.now();
    final range = s.budgetPeriod.range(now);
    final spent = store.sumIDR(TxType.expense, range);
    final hasBudget = s.globalBudget > 0;
    final remaining = s.globalBudget - spent;
    final ratio = hasBudget ? remaining / s.globalBudget : 0.0;
    final status = hasBudget ? BudgetStatus.of(ratio) : null;
    final catRows = s.categoryBudgets.entries
        .where((e) => e.value > 0 && store.categoryById(e.key) != null)
        .toList();

    String periodText;
    switch (s.budgetPeriod) {
      case BudgetPeriod.weekly:
        periodText =
            '${DateFormat('d MMM', 'id_ID').format(range.start)} - ${DateFormat('d MMM yyyy', 'id_ID').format(range.end.subtract(const Duration(days: 1)))}';
      case BudgetPeriod.monthly:
        periodText = DateFormat('MMMM yyyy', 'id_ID').format(now);
      case BudgetPeriod.yearly:
        periodText = 'Tahun ${now.year}';
    }

    return AppCard(
      onTap: () => _push(context, BudgetPage(store: store)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.track_changes_rounded, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Anggaran ${s.budgetPeriod.label}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                    Text(periodText,
                        style: const TextStyle(fontSize: 12, color: C.muted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: C.muted),
            ],
          ),
          const SizedBox(height: 12),
          if (status == null)
            const Text(
                'Belum ada batas anggaran. Ketuk kartu ini untuk pasang rem 🛑',
                style: TextStyle(color: C.muted, fontSize: 13))
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: status.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(status.message,
                  style: TextStyle(
                      color: status.color,
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sisa kuota',
                          style: TextStyle(fontSize: 12, color: C.muted)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(money(remaining),
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: remaining < 0 ? C.redDark : C.carbon)),
                      ),
                    ],
                  ),
                ),
                Text('${(ratio.clamp(0.0, 1.0) * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: status.color)),
              ],
            ),
            const SizedBox(height: 8),
            FunProgressBar(value: ratio, color: status.color),
            const SizedBox(height: 8),
            Text('Terpakai ${money(spent)} dari ${money(s.globalBudget)}',
                style: const TextStyle(fontSize: 12, color: C.muted)),
          ],
          if (catRows.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: C.line),
            const SizedBox(height: 10),
            const SmallLabel('Per Kategori'),
            const SizedBox(height: 6),
            for (final e in catRows) _catBudgetRow(e.key, e.value, range),
          ],
        ],
      ),
    );
  }

  Widget _catBudgetRow(String catId, double limit, DateTimeRange range) {
    final cat = store.categoryById(catId)!;
    final spent = store.sumIDR(TxType.expense, range, topCategory: catId);
    final st = BudgetStatus.of((limit - spent) / limit);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CatIcon(icon: cat.iconData, color: cat.colorValue, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(cat.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ),
                    Text('${money(spent)} / ${money(limit)}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: st == BudgetStatus.broke
                                ? C.redDark
                                : C.muted)),
                  ],
                ),
                const SizedBox(height: 6),
                FunProgressBar(
                    value: spent / limit, color: st.color, height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _templatesCard(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle('Catat Cepat',
              trailing: TextButton(
                  onPressed: () =>
                      _push(context, TemplatesPage(store: store)),
                  child: const Text('Kelola'))),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in store.templates)
                ActionChip(
                  avatar: Icon(
                      t.type == TxType.transfer
                          ? Icons.swap_horiz_rounded
                          : (store.categoryById(t.categoryId)?.iconData ??
                              Icons.bolt_rounded),
                      size: 18,
                      color: t.type.color),
                  label: Text(
                      '${t.title} · ${money(t.amount, store.currencyOf(t.accountId))}'),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  side: const BorderSide(color: C.line),
                  backgroundColor: C.bg,
                  onPressed: () => openTxForm(context, store, template: t),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _upcomingCard(BuildContext context, List<RecurringRule> rules) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle('Akan Datang',
              trailing: TextButton(
                  onPressed: () =>
                      _push(context, RecurringPage(store: store)),
                  child: const Text('Kelola'))),
          for (final r in rules)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  CatIcon(
                      icon: r.type == TxType.transfer
                          ? Icons.swap_horiz_rounded
                          : (store.categoryById(r.categoryId)?.iconData ??
                              Icons.repeat_rounded),
                      color: r.type == TxType.transfer
                          ? C.blue
                          : (store.categoryById(r.categoryId)?.colorValue ??
                              C.muted),
                      size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 13.5)),
                        Text(
                            '${r.frequency.label} · ${DateFormat('EEE, d MMM', 'id_ID').format(r.nextDate)}',
                            style: const TextStyle(
                                fontSize: 12, color: C.muted)),
                      ],
                    ),
                  ),
                  Text(
                      '${r.type == TxType.expense ? '-' : (r.type == TxType.income ? '+' : '')}${money(r.amount, store.currencyOf(r.accountId))}',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: r.type.color)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// TAB 2: RIWAYAT (daftar, filter, pencarian, kalender)
// =============================================================================

enum HistoryFilter {
  today('Hari Ini'),
  week('Minggu Ini'),
  month('Bulan Ini'),
  all('Semua');

  const HistoryFilter(this.label);
  final String label;

  DateTimeRange? range(DateTime now) {
    switch (this) {
      case HistoryFilter.today:
        return dayRange(now);
      case HistoryFilter.week:
        return weekRange(now);
      case HistoryFilter.month:
        return monthRange(now);
      case HistoryFilter.all:
        return null;
    }
  }
}

enum HistoryView { list, calendar }

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key, required this.store});
  final AppStore store;

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  AppStore get store => widget.store;
  final _searchCtrl = TextEditingController();
  String _query = '';
  HistoryView _view = HistoryView.list;
  HistoryFilter _filter = HistoryFilter.month;
  DateTime _calMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDay = dayOnly(DateTime.now());

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searching = _query.trim().isNotEmpty;
    final List<Widget> body;
    if (searching) {
      final results = store.search(_query);
      body = [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Text('${results.length} hasil untuk "${_query.trim()}"',
              style: const TextStyle(color: C.muted, fontSize: 13)),
        ),
        if (results.isEmpty)
          const EmptyState(
              icon: Icons.search_off_rounded,
              title: 'Tidak ketemu',
              subtitle: 'Coba kata kunci lain: judul, catatan, kategori, akun, atau nominal.')
        else
          ...groupedTxWidgets(context, store, results),
      ];
    } else if (_view == HistoryView.list) {
      body = _listBody(context);
    } else {
      body = _calendarBody(context);
    }

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Riwayat',
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                    textInputAction: TextInputAction.search,
                    decoration: fieldDeco('Cari transaksi',
                            icon: Icons.search_rounded)
                        .copyWith(
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Hapus pencarian',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                  ),
                  if (!searching) ...[
                    const SizedBox(height: 12),
                    Segmented<HistoryView>(
                      values: HistoryView.values,
                      selected: _view,
                      labelOf: (v) =>
                          v == HistoryView.list ? 'Daftar' : 'Kalender',
                      iconOf: (v) => v == HistoryView.list
                          ? Icons.view_list_rounded
                          : Icons.calendar_month_rounded,
                      colorOf: (_) => C.carbon,
                      dense: true,
                      onChanged: (v) => setState(() => _view = v),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
            sliver: SliverList(delegate: SliverChildListDelegate(body)),
          ),
        ],
      ),
    );
  }

  List<Widget> _listBody(BuildContext context) {
    final range = _filter.range(DateTime.now());
    final list = range == null
        ? store.transactions
        : store.transactions.where((t) => inRange(t.date, range)).toList();
    var income = 0.0;
    var expense = 0.0;
    for (final t in list) {
      if (t.type == TxType.income) income += store.amountIDR(t);
      if (t.type == TxType.expense) expense += store.amountIDR(t);
    }
    return [
      Segmented<HistoryFilter>(
        values: HistoryFilter.values,
        selected: _filter,
        labelOf: (f) => f.label,
        dense: true,
        onChanged: (f) => setState(() => _filter = f),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
              child: _SummaryBox(
                  label: 'Pemasukan',
                  value: income,
                  color: C.greenDark,
                  icon: Icons.south_west_rounded)),
          const SizedBox(width: 10),
          Expanded(
              child: _SummaryBox(
                  label: 'Pengeluaran',
                  value: expense,
                  color: C.redDark,
                  icon: Icons.north_east_rounded)),
        ],
      ),
      const SizedBox(height: 4),
      if (list.isEmpty)
        EmptyState(
            icon: Icons.receipt_long_rounded,
            title: 'Belum ada transaksi ${_filter.label.toLowerCase()}',
            subtitle: 'Ketuk tombol "Catat" buat mulai.')
      else
        ...groupedTxWidgets(context, store, list),
    ];
  }

  List<Widget> _calendarBody(BuildContext context) {
    final y = _calMonth.year;
    final m = _calMonth.month;
    final mRange = monthRange(_calMonth);
    final inc = <int, double>{};
    final exp = <int, double>{};
    for (final t in store.transactions) {
      if (!inRange(t.date, mRange)) continue;
      if (t.type == TxType.income) {
        inc[t.date.day] = (inc[t.date.day] ?? 0) + store.amountIDR(t);
      } else if (t.type == TxType.expense) {
        exp[t.date.day] = (exp[t.date.day] ?? 0) + store.amountIDR(t);
      }
    }
    final leading = DateTime(y, m, 1).weekday - 1;
    final days = DateTime(y, m + 1, 0).day;
    final cells = ((leading + days) / 7).ceil() * 7;
    final today = dayOnly(DateTime.now());
    final dayTx = store.transactions
        .where((t) => sameDay(t.date, _selectedDay))
        .toList();
    const weekdays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

    Widget cell(int index) {
      final dayNum = index - leading + 1;
      if (dayNum < 1 || dayNum > days) return const SizedBox(height: 58);
      final date = DateTime(y, m, dayNum);
      final selected = sameDay(date, _selectedDay);
      final isToday = sameDay(date, today);
      final i = inc[dayNum] ?? 0;
      final e = exp[dayNum] ?? 0;
      return Semantics(
        button: true,
        selected: selected,
        label: DateFormat('d MMMM', 'id_ID').format(date),
        child: GestureDetector(
          onTap: () => setState(() => _selectedDay = date),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 58,
            margin: const EdgeInsets.all(2),
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            decoration: BoxDecoration(
              color: selected ? C.green.withValues(alpha: 0.12) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: selected
                      ? C.greenDark
                      : (isToday ? C.green.withValues(alpha: 0.5) : C.line),
                  width: selected ? 2 : 1),
            ),
            child: Column(
              children: [
                Text('$dayNum',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isToday ? FontWeight.w900 : FontWeight.w700,
                        color: C.carbon)),
                const Spacer(),
                if (i > 0)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('+${compactMoney(i)}',
                        style: const TextStyle(
                            fontSize: 9,
                            color: C.greenDark,
                            fontWeight: FontWeight.w800)),
                  ),
                if (e > 0)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('-${compactMoney(e)}',
                        style: const TextStyle(
                            fontSize: 9,
                            color: C.redDark,
                            fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return [
      AppCard(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Bulan sebelumnya',
                  onPressed: () =>
                      setState(() => _calMonth = DateTime(y, m - 1)),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                      DateFormat('MMMM yyyy', 'id_ID').format(_calMonth),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 16)),
                ),
                IconButton(
                  tooltip: 'Bulan berikutnya',
                  onPressed: () =>
                      setState(() => _calMonth = DateTime(y, m + 1)),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            Row(
              children: [
                for (final w in weekdays)
                  Expanded(
                    child: Text(w,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: C.muted)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            for (var row = 0; row < cells ~/ 7; row++)
              Row(
                children: [
                  for (var col = 0; col < 7; col++)
                    Expanded(child: cell(row * 7 + col)),
                ],
              ),
          ],
        ),
      ),
      const SizedBox(height: 4),
      if (dayTx.isEmpty)
        EmptyState(
            icon: Icons.event_available_rounded,
            title: 'Tidak ada transaksi',
            subtitle: dayLabel(_selectedDay))
      else
        ...groupedTxWidgets(context, store, dayTx),
    ];
  }
}

class _SummaryBox extends StatelessWidget {
  const _SummaryBox(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});

  final String label;
  final double value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          CatIcon(icon: icon, color: color, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 11, color: C.muted)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(money(value),
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: color)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// TAB 3: STATISTIK
// =============================================================================

class StatsTab extends StatefulWidget {
  const StatsTab({super.key, required this.store});
  final AppStore store;

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  AppStore get store => widget.store;
  BudgetPeriod _mode = BudgetPeriod.monthly;
  DateTime _anchor = DateTime.now();
  TxType _type = TxType.expense;

  DateTimeRange get _range => _mode.range(_anchor);

  void _shift(int dir) {
    setState(() {
      switch (_mode) {
        case BudgetPeriod.weekly:
          _anchor = DateTime(_anchor.year, _anchor.month, _anchor.day + 7 * dir);
        case BudgetPeriod.monthly:
          _anchor = DateTime(_anchor.year, _anchor.month + dir, 1);
        case BudgetPeriod.yearly:
          _anchor = DateTime(_anchor.year + dir, 1, 1);
      }
    });
  }

  String _rangeLabel() {
    final r = _range;
    switch (_mode) {
      case BudgetPeriod.weekly:
        final last = r.end.subtract(const Duration(days: 1));
        return '${DateFormat('d MMM', 'id_ID').format(r.start)} - ${DateFormat('d MMM yyyy', 'id_ID').format(last)}';
      case BudgetPeriod.monthly:
        return DateFormat('MMMM yyyy', 'id_ID').format(r.start);
      case BudgetPeriod.yearly:
        return '${r.start.year}';
    }
  }

  List<TrendBucket> _buckets() {
    final out = <TrendBucket>[];
    switch (_mode) {
      case BudgetPeriod.weekly:
        final s = _range.start;
        for (var i = 0; i < 7; i++) {
          final d = DateTime(s.year, s.month, s.day + i);
          final r = dayRange(d);
          out.add(TrendBucket(DateFormat('E', 'id_ID').format(d),
              store.sumIDR(TxType.income, r), store.sumIDR(TxType.expense, r)));
        }
      case BudgetPeriod.monthly:
        for (var i = 5; i >= 0; i--) {
          final d = DateTime(_anchor.year, _anchor.month - i, 1);
          final r = monthRange(d);
          out.add(TrendBucket(DateFormat('MMM', 'id_ID').format(d),
              store.sumIDR(TxType.income, r), store.sumIDR(TxType.expense, r)));
        }
      case BudgetPeriod.yearly:
        for (var mo = 1; mo <= 12; mo++) {
          final d = DateTime(_anchor.year, mo, 1);
          final r = monthRange(d);
          out.add(TrendBucket(DateFormat('MMM', 'id_ID').format(d).substring(0, 1),
              store.sumIDR(TxType.income, r), store.sumIDR(TxType.expense, r)));
        }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final r = _range;
    final income = store.sumIDR(TxType.income, r);
    final expense = store.sumIDR(TxType.expense, r);
    final net = income - expense;
    final byCat = store.byTopCategory(_type, r).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = byCat.fold(0.0, (s, e) => s + e.value);
    final now = DateTime.now();
    // Hanya boleh maju kalau periode yang dilihat sudah lewat seluruhnya.
    final canNext = !r.end.isAfter(now);
    final elapsedDays = inRange(now, r)
        ? now.difference(r.start).inDays + 1
        : r.end.difference(r.start).inDays;
    final avgDaily = elapsedDays > 0 ? expense / elapsedDays : 0.0;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const Text('Statistik',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Segmented<BudgetPeriod>(
            values: BudgetPeriod.values,
            selected: _mode,
            labelOf: (p) => p.short,
            dense: true,
            onChanged: (p) => setState(() {
              _mode = p;
              _anchor = DateTime.now();
            }),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                  tooltip: 'Sebelumnya',
                  onPressed: () => _shift(-1),
                  icon: const Icon(Icons.chevron_left_rounded)),
              Expanded(
                child: Text(_rangeLabel(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16)),
              ),
              IconButton(
                  tooltip: 'Berikutnya',
                  onPressed: canNext ? () => _shift(1) : null,
                  icon: const Icon(Icons.chevron_right_rounded)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                  child: _SummaryBox(
                      label: 'Pemasukan',
                      value: income,
                      color: C.greenDark,
                      icon: Icons.south_west_rounded)),
              const SizedBox(width: 10),
              Expanded(
                  child: _SummaryBox(
                      label: 'Pengeluaran',
                      value: expense,
                      color: C.redDark,
                      icon: Icons.north_east_rounded)),
            ],
          ),
          const SizedBox(height: 10),
          AppCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Selisih (net)',
                          style: TextStyle(fontSize: 12, color: C.muted)),
                      Text(net > 0 ? '+${money(net)}' : money(net),
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: net >= 0 ? C.greenDark : C.redDark)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Rata-rata keluar/hari',
                          style: TextStyle(fontSize: 12, color: C.muted)),
                      Text(money(avgDaily),
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Segmented<TxType>(
                  values: const [TxType.expense, TxType.income],
                  selected: _type,
                  labelOf: (t) => t.label,
                  colorOf: (t) => t.color,
                  dense: true,
                  onChanged: (t) => setState(() => _type = t),
                ),
                const SizedBox(height: 16),
                if (byCat.isEmpty)
                  EmptyState(
                      icon: Icons.donut_large_rounded,
                      title: 'Belum ada ${_type.label.toLowerCase()} di periode ini')
                else ...[
                  Center(
                    child: SizedBox(
                      width: 180,
                      height: 180,
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey('${_mode.name}-${_type.name}-$total-${r.start}'),
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (context, p, _) => CustomPaint(
                          painter: DonutChartPainter(
                            values: byCat.map((e) => e.value).toList(),
                            colors: byCat
                                .map((e) =>
                                    store.categoryById(e.key)?.colorValue ??
                                    C.muted)
                                .toList(),
                            progress: p,
                          ),
                          child: Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Total',
                                      style: TextStyle(
                                          fontSize: 11, color: C.muted)),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(money(total),
                                        style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final e in byCat) _legendRow(context, e.key, e.value, total, r),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(_mode == BudgetPeriod.monthly
                    ? 'Tren 6 Bulan'
                    : (_mode == BudgetPeriod.weekly
                        ? 'Tren Harian'
                        : 'Tren Bulanan ${_anchor.year}')),
                const SizedBox(height: 16),
                TrendChart(buckets: _buckets()),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Saldo per Akun'),
                const SizedBox(height: 8),
                for (final a in store.accounts)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        CatIcon(icon: a.type.icon, color: a.colorValue, size: 34),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(a.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(money(store.balanceOf(a.id), a.currency),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 13)),
                            if (a.currency != 'IDR')
                              Text(
                                  '≈ ${money(store.toIDR(store.balanceOf(a.id), a.currency))}',
                                  style: const TextStyle(
                                      fontSize: 11, color: C.muted)),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendRow(BuildContext context, String catId, double value,
      double total, DateTimeRange r) {
    final cat = store.categoryById(catId);
    final pct = total > 0 ? value / total : 0.0;
    final color = cat?.colorValue ?? C.muted;
    final hasChildren = cat != null && store.childrenOf(cat.id).isNotEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: hasChildren
          ? () => showSheet<void>(context,
              _SubCategorySheet(store: store, top: cat!, type: _type, range: r))
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          children: [
            CatIcon(
                icon: cat?.iconData ?? Icons.help_outline_rounded,
                color: color,
                size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(cat?.name ?? 'Tanpa kategori',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w700)),
                      ),
                      Text('${(pct * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: darken(color))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  FunProgressBar(value: pct, color: color, height: 7),
                  const SizedBox(height: 2),
                  Text(
                      hasChildren
                          ? '${money(value)} · ketuk untuk rincian'
                          : money(value),
                      style: const TextStyle(fontSize: 11, color: C.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubCategorySheet extends StatelessWidget {
  const _SubCategorySheet(
      {required this.store,
      required this.top,
      required this.type,
      required this.range});

  final AppStore store;
  final TxCategory top;
  final TxType type;
  final DateTimeRange range;

  @override
  Widget build(BuildContext context) {
    final data = store.bySubCategory(top.id, type, range).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = data.fold(0.0, (s, e) => s + e.value);
    return SheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CatIcon(icon: top.iconData, color: top.colorValue, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Rincian ${top.name}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final e in data)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                            e.key == top.id
                                ? '${top.name} (umum)'
                                : (store.categoryById(e.key)?.name ?? '-'),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                      Text(money(e.value),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  FunProgressBar(
                      value: total > 0 ? e.value / total : 0,
                      color: store.categoryById(e.key)?.colorValue ?? C.muted,
                      height: 7),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// TAB 4: LAINNYA
// =============================================================================

class MoreTab extends StatelessWidget {
  const MoreTab({super.key, required this.store});
  final AppStore store;

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Widget _tile(BuildContext context,
      {required IconData icon,
      required Color color,
      required String title,
      String? subtitle,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            CatIcon(icon: icon, color: color, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14)),
                  if (subtitle != null)
                    Text(subtitle,
                        style: const TextStyle(fontSize: 12, color: C.muted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: C.muted),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = store.settings;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const Text('Lainnya',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              children: [
                _tile(context,
                    icon: Icons.account_balance_wallet_rounded,
                    color: C.blue,
                    title: 'Akun & Dompet',
                    subtitle: '${store.accounts.length} akun',
                    onTap: () => _push(context, AccountsPage(store: store))),
                _tile(context,
                    icon: Icons.category_rounded,
                    color: Colors.pink,
                    title: 'Kategori',
                    subtitle: '${store.categories.length} kategori & sub-kategori',
                    onTap: () => _push(context, CategoriesPage(store: store))),
                _tile(context,
                    icon: Icons.track_changes_rounded,
                    color: C.amber,
                    title: 'Anggaran',
                    subtitle: s.globalBudget > 0
                        ? '${s.budgetPeriod.label} · ${money(s.globalBudget)}'
                        : 'Belum diatur',
                    onTap: () => _push(context, BudgetPage(store: store))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              children: [
                _tile(context,
                    icon: Icons.repeat_rounded,
                    color: C.green,
                    title: 'Transaksi Berulang',
                    subtitle:
                        '${store.recurring.where((r) => r.active).length} aktif',
                    onTap: () => _push(context, RecurringPage(store: store))),
                _tile(context,
                    icon: Icons.bolt_rounded,
                    color: Colors.deepPurple,
                    title: 'Template Catat Cepat',
                    subtitle: '${store.templates.length} template',
                    onTap: () => _push(context, TemplatesPage(store: store))),
                _tile(context,
                    icon: Icons.currency_exchange_rounded,
                    color: Colors.teal,
                    title: 'Mata Uang & Kurs',
                    subtitle: 'Konversi ke Rupiah',
                    onTap: () => _push(context, CurrencyPage(store: store))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              children: [
                _tile(context,
                    icon: Icons.auto_awesome_rounded,
                    color: Colors.deepOrange,
                    title: 'Catat Otomatis',
                    subtitle: switch (s.captureMode) {
                      'off' => 'Mati',
                      'ask' => 'Tanya dulu',
                      _ => 'Langsung catat dari notifikasi bank/e-wallet',
                    },
                    onTap: () =>
                        _push(context, AutoCapturePage(store: store))),
                _tile(context,
                    icon: Icons.notifications_rounded,
                    color: C.amber,
                    title: 'Notifikasi',
                    subtitle: s.notifEnabled ? 'Aktif' : 'Nonaktif',
                    onTap: () =>
                        _push(context, NotificationsPage(store: store))),
                _tile(context,
                    icon: Icons.lock_rounded,
                    color: C.carbon,
                    title: 'Keamanan',
                    subtitle: s.pin == null
                        ? 'PIN nonaktif'
                        : (s.biometric ? 'PIN + sidik jari aktif' : 'PIN aktif'),
                    onTap: () => _push(context, SecurityPage(store: store))),
                _tile(context,
                    icon: Icons.backup_rounded,
                    color: Colors.indigo,
                    title: 'Backup & Pulihkan',
                    subtitle: 'Ekspor/impor data JSON',
                    onTap: () => _push(context, BackupPage(store: store))),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Column(
              children: [
                Icon(Icons.all_inclusive_rounded, color: C.muted),
                SizedBox(height: 4),
                Text('Infinity · data tersimpan di perangkat ini',
                    style: TextStyle(fontSize: 12, color: C.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// FORM TRANSAKSI / BERULANG / TEMPLATE (Bottom Sheet)
// =============================================================================

class TxFormSheet extends StatefulWidget {
  const TxFormSheet({
    super.key,
    required this.store,
    required this.draft,
    required this.mode,
    this.excludeTxId,
    this.isEditing = false,
    this.frequency,
  });

  final AppStore store;
  final TxDraft draft;
  final FormMode mode;
  final String? excludeTxId;
  final bool isEditing;
  final Frequency? frequency;

  @override
  State<TxFormSheet> createState() => _TxFormSheetState();
}

class _TxFormSheetState extends State<TxFormSheet> {
  AppStore get store => widget.store;

  late TxType _type;
  String? _categoryId;
  late String _fromId;
  late String _toId;
  late DateTime _date;
  late Frequency _frequency;
  bool _saveTemplate = false;
  bool _toTouched = false;
  String? _error;
  String? _info;

  final _amountCtrl = TextEditingController();
  final _toAmountCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  String get _fromCur => store.currencyOf(_fromId);
  String get _toCur => store.currencyOf(_toId);
  bool get _crossCurrency => _type == TxType.transfer && _fromCur != _toCur;

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    _type = d.type;
    _fromId = store.accountById(d.accountId) != null
        ? d.accountId
        : store.accounts.first.id;
    final to = d.toAccountId;
    _toId = (to != null && store.accountById(to) != null && to != _fromId)
        ? to
        : _otherAccount(_fromId);
    _categoryId = (d.categoryId != null && store.categoryById(d.categoryId) != null)
        ? d.categoryId
        : _defaultCategory(_type);
    _date = d.date;
    _frequency = widget.frequency ?? Frequency.monthly;
    if (d.amount > 0) _amountCtrl.text = amountToInput(d.amount, _fromCur);
    final ta = d.toAmount;
    if (ta != null && _crossCurrency) {
      _toAmountCtrl.text = amountToInput(ta, _toCur);
      _toTouched = true;
    } else {
      _syncToAmount();
    }
    _titleCtrl.text = d.title;
    _noteCtrl.text = d.note;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _toAmountCtrl.dispose();
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String _otherAccount(String id) => store.accounts
      .firstWhere((a) => a.id != id, orElse: () => store.accounts.first)
      .id;

  String? _defaultCategory(TxType t) {
    if (t == TxType.transfer) return null;
    final tops = store.topCategories(t);
    return tops.isEmpty ? null : tops.first.id;
  }

  double get _amount =>
      parseAmount(_amountCtrl.text, decimals: hasDecimals(_fromCur));

  void _syncToAmount() {
    if (!_crossCurrency || _toTouched) return;
    final a = _amount;
    if (a <= 0) {
      _toAmountCtrl.text = '';
      return;
    }
    final converted = a * store.rate(_fromCur) / store.rate(_toCur);
    _toAmountCtrl.text = amountToInput(converted, _toCur);
  }

  void _changeType(TxType t) {
    if (t == _type) return;
    setState(() {
      _type = t;
      _categoryId = _defaultCategory(t);
      _error = null;
      if (t == TxType.transfer && _toId == _fromId) {
        _toId = _otherAccount(_fromId);
      }
      _toTouched = false;
      _syncToAmount();
    });
  }

  void _selectFrom(String id) {
    final oldCur = _fromCur;
    final value = parseAmount(_amountCtrl.text, decimals: hasDecimals(oldCur));
    setState(() {
      _fromId = id;
      _error = null;
      if (_type == TxType.transfer && _toId == id) _toId = _otherAccount(id);
      if (oldCur != _fromCur) {
        _amountCtrl.text = value > 0 ? amountToInput(value, _fromCur) : '';
      }
      _toTouched = false;
      _syncToAmount();
    });
  }

  void _selectTo(String id) {
    setState(() {
      _toId = id;
      _error = null;
      _toTouched = false;
      _syncToAmount();
    });
  }

  void _applyTemplate(TxTemplate t) {
    setState(() {
      _type = t.type;
      _fromId = store.accountById(t.accountId) != null
          ? t.accountId
          : store.accounts.first.id;
      final to = t.toAccountId;
      _toId = (to != null && store.accountById(to) != null && to != _fromId)
          ? to
          : _otherAccount(_fromId);
      _categoryId = store.categoryById(t.categoryId) != null
          ? t.categoryId
          : _defaultCategory(t.type);
      _amountCtrl.text = amountToInput(t.amount, _fromCur);
      _titleCtrl.text = t.title;
      _noteCtrl.text = t.note;
      _error = null;
      _toTouched = false;
      final ta = t.toAmount;
      if (ta != null && _crossCurrency) {
        _toAmountCtrl.text = amountToInput(ta, _toCur);
        _toTouched = true;
      } else {
        _syncToAmount();
      }
    });
  }

  /// Isi form dari teks struk/notifikasi yang disalin user.
  Future<void> _pasteReceipt() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      setState(() {
        _info = null;
        _error =
            'Clipboard kosong. Salin dulu teks struk atau notifikasi transaksinya.';
      });
      return;
    }
    final p = parseReceipt(text, store);
    final amount = p.amount;
    if (amount == null) {
      setState(() {
        _info = null;
        _error = 'Tidak ketemu nominal (Rp ...) di teks yang disalin.';
      });
      return;
    }
    setState(() {
      final type = p.type ?? TxType.expense;
      if (type != _type) {
        _type = type;
        _categoryId = _defaultCategory(type);
      }
      final acc = p.accountId;
      if (acc != null) {
        _fromId = acc;
        if (_toId == _fromId) _toId = _otherAccount(_fromId);
      }
      final cat = p.categoryId;
      if (cat != null) _categoryId = cat;
      _amountCtrl.text = amountToInput(amount, _fromCur);
      final title = p.title;
      if (title != null) _titleCtrl.text = title;
      _error = null;
      _info =
          'Terisi dari struk: ${money(amount, _fromCur)}${title != null ? ' · $title' : ''}. Cek akun dan kategori sebelum simpan.';
    });
  }

  Future<void> _openCalculator() async {
    final v = await showSheet<double>(context, CalculatorSheet(initial: _amount));
    if (v == null || !mounted) return;
    setState(() {
      _amountCtrl.text = amountToInput(v, _fromCur);
      _error = null;
      _syncToAmount();
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 10);
    final last = widget.mode == FormMode.recurring
        ? DateTime(now.year + 5)
        : now;
    var initial = _date;
    if (initial.isAfter(last)) initial = last;
    if (initial.isBefore(first)) initial = first;
    final picked = await showDatePicker(
        context: context, initialDate: initial, firstDate: first, lastDate: last);
    if (picked != null) setState(() => _date = picked);
  }

  void _submit() {
    final amount = _amount;
    String? err;
    double? toAmount;

    if (amount <= 0) {
      err = 'Nominal harus lebih dari 0 ya 🙏';
    } else if (_type == TxType.transfer && _fromId == _toId) {
      err = 'Akun asal dan tujuan tidak boleh sama. Tambah akun lain dulu kalau baru punya satu.';
    } else if (_type != TxType.transfer && _categoryId == null) {
      err = 'Pilih kategori dulu.';
    } else if (widget.mode == FormMode.transaction && _type != TxType.income) {
      final acc = store.accountById(_fromId)!;
      final bal = store.balanceOf(_fromId, excludeTxId: widget.excludeTxId);
      if (acc.type == AccountType.credit) {
        if (acc.creditLimit > 0 && bal - amount < -acc.creditLimit - 0.001) {
          err =
              'Melebihi limit ${acc.name} (sisa limit ${money(acc.creditLimit + bal, acc.currency)}).';
        }
      } else if (amount > bal + 0.001) {
        err =
            'Saldo ${acc.name} tidak cukup (sisa ${money(bal, acc.currency)}).';
      }
    }
    if (err == null && _crossCurrency) {
      toAmount =
          parseAmount(_toAmountCtrl.text, decimals: hasDecimals(_toCur));
      if (toAmount <= 0) err = 'Isi jumlah yang diterima di akun tujuan.';
    }
    if (err != null) {
      HapticFeedback.mediumImpact();
      setState(() => _error = err);
      return;
    }

    final now = DateTime.now();
    DateTime date;
    if (widget.mode == FormMode.recurring) {
      date = DateTime(_date.year, _date.month, _date.day, 8);
    } else if (widget.isEditing) {
      final orig = widget.draft.date;
      date = DateTime(
          _date.year, _date.month, _date.day, orig.hour, orig.minute, orig.second);
    } else {
      date = DateTime(_date.year, _date.month, _date.day, now.hour, now.minute,
          now.second);
    }

    final draft = TxDraft(
      type: _type,
      amount: amount,
      toAmount: _crossCurrency ? toAmount : null,
      categoryId: _type == TxType.transfer ? null : _categoryId,
      accountId: _fromId,
      toAccountId: _type == TxType.transfer ? _toId : null,
      date: date,
      note: _noteCtrl.text.trim(),
    );
    final title = _titleCtrl.text.trim();
    draft.title = title.isEmpty ? _defaultTitle(store, draft) : title;

    Navigator.of(context).pop(FormResult(
      draft,
      frequency: widget.mode == FormMode.recurring ? _frequency : null,
      saveAsTemplate: _saveTemplate,
    ));
  }

  String get _heading {
    switch (widget.mode) {
      case FormMode.transaction:
        return widget.isEditing ? 'Edit Transaksi' : 'Catat ${_type.label}';
      case FormMode.recurring:
        return widget.isEditing ? 'Edit Transaksi Berulang' : 'Transaksi Berulang';
      case FormMode.template:
        return 'Template Baru';
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _type.color;
    final isTransfer = _type == TxType.transfer;
    final mode = widget.mode;
    final showQuickRow = mode == FormMode.transaction && !widget.isEditing;
    final tops = store.topCategories(_type);
    final selectedTop =
        _categoryId == null ? null : store.topCategoryId(_categoryId!);
    final subs = selectedTop == null
        ? <TxCategory>[]
        : store.childrenOf(selectedTop);
    final fromDecimals = hasDecimals(_fromCur);

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(primary: accent),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: accent,
          selectionHandleColor: accent,
          selectionColor: accent.withValues(alpha: 0.25),
        ),
      ),
      child: SheetFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                      mode == FormMode.recurring
                          ? Icons.repeat_rounded
                          : (mode == FormMode.template
                              ? Icons.bolt_rounded
                              : _type.icon),
                      color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_heading,
                      style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: C.carbon)),
                ),
                IconButton(
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Segmented<TxType>(
              values: TxType.values,
              selected: _type,
              labelOf: (t) => t.label,
              iconOf: (t) => t.icon,
              colorOf: (t) => t.color,
              onChanged: _changeType,
            ),
            if (showQuickRow) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ActionChip(
                      avatar: Icon(Icons.content_paste_rounded,
                          size: 16, color: accent),
                      label: const Text('Tempel struk',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      side: BorderSide(color: accent),
                      onPressed: _pasteReceipt,
                    ),
                    for (final t in store.templates) ...[
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(Icons.bolt_rounded, size: 16),
                        label: Text(t.title),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        side: const BorderSide(color: C.line),
                        onPressed: () => _applyTemplate(t),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (_info != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: C.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: C.greenDark, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_info!,
                          style: const TextStyle(
                              color: C.greenDark,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Nominal
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nominal (${_fromCur})',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: accent)),
                        TextField(
                          controller: _amountCtrl,
                          autofocus: !widget.isEditing,
                          keyboardType: TextInputType.numberWithOptions(
                              decimal: fromDecimals),
                          inputFormatters: [
                            AmountFormatter(decimals: fromDecimals)
                          ],
                          onChanged: (_) => setState(() {
                            _error = null;
                            _syncToAmount();
                          }),
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: accent),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            prefixText: '${currencySymbol(_fromCur)} ',
                            prefixStyle: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: accent),
                            hintText: '0',
                            hintStyle: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: accent.withValues(alpha: 0.3)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Kalkulator',
                    onPressed: _openCalculator,
                    icon: const Icon(Icons.calculate_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _titleCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: fieldDeco(
                  mode == FormMode.template
                      ? 'Nama template (opsional)'
                      : 'Judul (opsional)',
                  icon: Icons.edit_note_rounded,
                  accent: accent),
            ),

            // Kategori + sub-kategori
            if (!isTransfer) ...[
              const SizedBox(height: 16),
              const SmallLabel('Kategori'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in tops)
                    _CategoryChip(
                      label: c.name,
                      icon: c.iconData,
                      color: c.colorValue,
                      selected: c.id == selectedTop,
                      onTap: () => setState(() {
                        _categoryId = c.id;
                        _error = null;
                      }),
                    ),
                ],
              ),
              if (subs.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _CategoryChip(
                      label: 'Umum',
                      icon: Icons.subdirectory_arrow_right_rounded,
                      color: C.muted,
                      small: true,
                      selected: _categoryId == selectedTop,
                      onTap: () => setState(() => _categoryId = selectedTop),
                    ),
                    for (final c in subs)
                      _CategoryChip(
                        label: c.name,
                        icon: c.iconData,
                        color: c.colorValue,
                        small: true,
                        selected: c.id == _categoryId,
                        onTap: () => setState(() => _categoryId = c.id),
                      ),
                  ],
                ),
              ],
            ],

            // Akun
            const SizedBox(height: 16),
            SmallLabel(isTransfer
                ? 'Dari Akun'
                : (_type == TxType.income ? 'Masuk ke Akun' : 'Bayar Pakai')),
            const SizedBox(height: 8),
            AccountPicker(
              store: store,
              selectedId: _fromId,
              accent: accent,
              excludeTxId: widget.excludeTxId,
              onSelected: _selectFrom,
            ),
            if (isTransfer) ...[
              const SizedBox(height: 10),
              const SmallLabel('Ke Akun'),
              const SizedBox(height: 8),
              AccountPicker(
                store: store,
                selectedId: _toId,
                disabledId: _fromId,
                accent: accent,
                excludeTxId: widget.excludeTxId,
                onSelected: _selectTo,
              ),
              if (_crossCurrency) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _toAmountCtrl,
                  keyboardType: TextInputType.numberWithOptions(
                      decimal: hasDecimals(_toCur)),
                  inputFormatters: [
                    AmountFormatter(decimals: hasDecimals(_toCur))
                  ],
                  onChanged: (_) => setState(() {
                    _toTouched = true;
                    _error = null;
                  }),
                  decoration: fieldDeco('Jumlah diterima ($_toCur)',
                      icon: Icons.currency_exchange_rounded,
                      prefix: '${currencySymbol(_toCur)} ',
                      helper:
                          'Dihitung otomatis dari kurs. Ubah kalau kurs bank/e-wallet berbeda.',
                      accent: accent),
                ),
              ],
            ],

            // Frekuensi (khusus berulang)
            if (mode == FormMode.recurring) ...[
              const SizedBox(height: 16),
              const SmallLabel('Ulangi setiap'),
              const SizedBox(height: 8),
              Segmented<Frequency>(
                values: Frequency.values,
                selected: _frequency,
                labelOf: (f) => f.label,
                colorOf: (_) => accent,
                dense: true,
                onChanged: (f) => setState(() => _frequency = f),
              ),
            ],

            // Tanggal
            if (mode != FormMode.template) ...[
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: C.bg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: C.line),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, color: C.muted),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (mode == FormMode.recurring)
                              const Text('Mulai / jatuh tempo berikutnya',
                                  style:
                                      TextStyle(fontSize: 11, color: C.muted)),
                            Text(
                              sameDay(_date, DateTime.now())
                                  ? 'Hari ini, ${DateFormat('d MMMM yyyy', 'id_ID').format(_date)}'
                                  : DateFormat('EEEE, d MMMM yyyy', 'id_ID')
                                      .format(_date),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: C.carbon),
                            ),
                          ],
                        ),
                      ),
                      Text('Ubah',
                          style: TextStyle(
                              color: accent, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              decoration: fieldDeco('Catatan ringkas (opsional)',
                      icon: Icons.sticky_note_2_rounded, accent: accent)
                  .copyWith(counterText: ''),
            ),
            if (mode == FormMode.transaction && !widget.isEditing)
              CheckboxListTile(
                value: _saveTemplate,
                onChanged: (v) => setState(() => _saveTemplate = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Simpan juga sebagai template catat cepat',
                    style: TextStyle(fontSize: 13.5)),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              ErrorBox(_error!),
            ],
            const SizedBox(height: 14),
            PrimaryButton(
              label: widget.isEditing ? 'Simpan Perubahan' : 'Simpan',
              color: accent,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
    this.small = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final bool small;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
              horizontal: small ? 10 : 12, vertical: small ? 7 : 9),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.15) : C.bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? darken(color) : C.line,
                width: selected ? 2 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: small ? 15 : 18, color: darken(color)),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: small ? 12 : 12.5,
                      fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w600,
                      color: C.carbon)),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// DETAIL TRANSAKSI
// =============================================================================

class TransactionDetailSheet extends StatelessWidget {
  const TransactionDetailSheet(
      {super.key, required this.store, required this.transaction});

  final AppStore store;
  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final cur = store.currencyOf(t.accountId);
    final sign =
        t.type == TxType.expense ? '-' : (t.type == TxType.income ? '+' : '');

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: Text(label,
                    style: const TextStyle(color: C.muted, fontSize: 13)),
              ),
              Expanded(
                child: Text(value,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ],
          ),
        );

    return SheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
              child: CatIcon(
                  icon: store.txIcon(t), color: store.txColor(t), size: 64)),
          const SizedBox(height: 12),
          Text(t.title,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('$sign${money(t.amount, cur)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: t.type.color)),
          if (cur != 'IDR')
            Text('≈ ${money(store.amountIDR(t))}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: C.muted)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
                color: C.bg, borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                row('Tipe', t.type.label),
                row('Kategori', store.categoryLabel(t)),
                if (t.type == TxType.transfer) ...[
                  row('Dari Akun', store.accountName(t.accountId)),
                  row('Ke Akun', store.accountName(t.toAccountId)),
                  if (t.toAmount != null)
                    row('Diterima',
                        money(t.receivedAmount, store.currencyOf(t.toAccountId))),
                ] else
                  row('Akun', store.accountName(t.accountId)),
                row('Tanggal',
                    DateFormat('EEEE, d MMM yyyy · HH:mm', 'id_ID')
                        .format(t.date)),
                if (t.recurringId != null) row('Sumber', 'Transaksi berulang'),
                if (t.note.isNotEmpty) row('Catatan', t.note),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pop(_DetailAction.duplicate),
                  icon: const Icon(Icons.library_add_rounded),
                  label: const Text('Duplikat'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pop(_DetailAction.copy),
                  icon: const Icon(Icons.content_copy_rounded),
                  label: const Text('Salin teks'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(_DetailAction.edit),
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Edit'),
            style: FilledButton.styleFrom(
              backgroundColor: C.greenDark,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(_DetailAction.delete),
            icon: const Icon(Icons.delete_rounded),
            label: const Text('Hapus Transaksi',
                style: TextStyle(fontWeight: FontWeight.w800)),
            style: OutlinedButton.styleFrom(
              foregroundColor: C.redDark,
              side: const BorderSide(color: C.redDark, width: 1.5),
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
          ),
          const SizedBox(height: 6),
          const Text('Tip: geser item ke kiri di riwayat untuk hapus cepat.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: C.muted)),
        ],
      ),
    );
  }
}

// =============================================================================
// KALKULATOR
// =============================================================================

/// Evaluasi ekspresi sederhana dengan prioritas ×/÷ sebelum +/−.
double? evalExpression(String expr) {
  if (expr.isEmpty) return null;
  const ops = '+−×÷';
  final nums = <double>[];
  final opList = <String>[];
  var buf = '';
  for (final ch in expr.split('')) {
    if (ops.contains(ch)) {
      final v = double.tryParse(buf);
      if (v == null) return null;
      nums.add(v);
      opList.add(ch);
      buf = '';
    } else {
      buf += ch;
    }
  }
  if (buf.isEmpty) {
    if (opList.isEmpty) return null;
    opList.removeLast();
  } else {
    final v = double.tryParse(buf);
    if (v == null) return null;
    nums.add(v);
  }
  final n2 = <double>[nums.first];
  final o2 = <String>[];
  for (var i = 0; i < opList.length; i++) {
    final op = opList[i];
    final v = nums[i + 1];
    if (op == '×') {
      n2[n2.length - 1] = n2.last * v;
    } else if (op == '÷') {
      if (v == 0) return null;
      n2[n2.length - 1] = n2.last / v;
    } else {
      o2.add(op);
      n2.add(v);
    }
  }
  var r = n2.first;
  for (var i = 0; i < o2.length; i++) {
    r = o2[i] == '+' ? r + n2[i + 1] : r - n2[i + 1];
  }
  return r;
}

class CalculatorSheet extends StatefulWidget {
  const CalculatorSheet({super.key, this.initial = 0});
  final double initial;

  @override
  State<CalculatorSheet> createState() => _CalculatorSheetState();
}

class _CalculatorSheetState extends State<CalculatorSheet> {
  late String _expr;
  String? _error;

  static const _ops = '+−×÷';

  static String _fmt(double v) {
    if (v == v.roundToDouble()) return v.round().toString();
    var s = v.toStringAsFixed(2);
    while (s.endsWith('0')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return s;
  }

  @override
  void initState() {
    super.initState();
    _expr = widget.initial > 0 ? _fmt(widget.initial) : '';
  }

  String get _currentNumber {
    var i = _expr.length - 1;
    while (i >= 0 && !_ops.contains(_expr[i])) {
      i--;
    }
    return _expr.substring(i + 1);
  }

  void _press(String k) {
    HapticFeedback.selectionClick();
    setState(() {
      _error = null;
      if (k == 'C') {
        _expr = '';
      } else if (k == '⌫') {
        if (_expr.isNotEmpty) _expr = _expr.substring(0, _expr.length - 1);
      } else if (k == '=') {
        final v = evalExpression(_expr);
        if (v == null) {
          _error = 'Ekspresi belum lengkap';
        } else {
          _expr = _fmt(v);
        }
      } else if (_ops.contains(k)) {
        if (_expr.isEmpty) return;
        if (_ops.contains(_expr[_expr.length - 1])) {
          _expr = _expr.substring(0, _expr.length - 1) + k;
        } else {
          _expr += k;
        }
      } else if (k == '.') {
        if (_currentNumber.contains('.')) return;
        _expr += _currentNumber.isEmpty ? '0.' : '.';
      } else {
        if (_expr.length < 40) _expr += k;
      }
    });
  }

  void _use() {
    final v = evalExpression(_expr);
    if (v == null || v <= 0) {
      setState(() => _error = 'Hasil harus lebih dari 0');
      return;
    }
    Navigator.of(context).pop(v);
  }

  Widget _key(String k, {Color? bg, Color? fg, int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Material(
          color: bg ?? C.bg,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _press(k),
            child: SizedBox(
              height: 56,
              child: Center(
                child: Text(k,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: fg ?? C.carbon)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = evalExpression(_expr);
    final opBg = C.green.withValues(alpha: 0.15);
    return SheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Kalkulator',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: C.bg, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_expr.isEmpty ? '0' : _expr,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                    _error ??
                        (preview == null ? ' ' : '= ${_plain.format(preview)}'),
                    style: TextStyle(
                        fontSize: 14,
                        color: _error != null ? C.redDark : C.muted,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            _key('C', fg: C.redDark),
            _key('⌫'),
            _key('÷', bg: opBg, fg: C.greenDark),
            _key('×', bg: opBg, fg: C.greenDark),
          ]),
          Row(children: [
            _key('7'),
            _key('8'),
            _key('9'),
            _key('−', bg: opBg, fg: C.greenDark),
          ]),
          Row(children: [
            _key('4'),
            _key('5'),
            _key('6'),
            _key('+', bg: opBg, fg: C.greenDark),
          ]),
          Row(children: [
            _key('1'),
            _key('2'),
            _key('3'),
            _key('.'),
          ]),
          Row(children: [
            _key('0'),
            _key('000'),
            _key('=', bg: C.carbon, fg: Colors.white, flex: 2),
          ]),
          const SizedBox(height: 10),
          PrimaryButton(label: 'Pakai hasil', onPressed: _use),
        ],
      ),
    );
  }
}

// =============================================================================
// HALAMAN: AKUN
// =============================================================================

class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pageBar('Akun & Dompet'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            showSheet<void>(context, AccountEditorSheet(store: store)),
        backgroundColor: C.greenDark,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Akun baru'),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
          children: [
            AppCard(
              child: Row(
                children: [
                  const Expanded(
                      child: Text('Total saldo bersih',
                          style: TextStyle(color: C.muted))),
                  Text(money(store.netWorthIDR),
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (final a in store.accounts)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  onTap: () => showSheet<void>(
                      context, AccountEditorSheet(store: store, account: a)),
                  child: Row(
                    children: [
                      CatIcon(icon: a.type.icon, color: a.colorValue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                            Text(
                                '${a.type.label} · ${a.currency}${a.type == AccountType.credit ? ' · jatuh tempo tgl ${a.dueDay}' : ''}',
                                style: const TextStyle(
                                    fontSize: 12, color: C.muted)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(money(store.balanceOf(a.id), a.currency),
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: store.balanceOf(a.id) < 0
                                      ? C.redDark
                                      : C.carbon)),
                          if (a.currency != 'IDR')
                            Text(
                                '≈ ${money(store.toIDR(store.balanceOf(a.id), a.currency))}',
                                style: const TextStyle(
                                    fontSize: 11, color: C.muted)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AccountEditorSheet extends StatefulWidget {
  const AccountEditorSheet({super.key, required this.store, this.account});
  final AppStore store;
  final Account? account;

  @override
  State<AccountEditorSheet> createState() => _AccountEditorSheetState();
}

class _AccountEditorSheetState extends State<AccountEditorSheet> {
  AppStore get store => widget.store;
  final _nameCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController();
  final _limitCtrl = TextEditingController();
  late AccountType _type;
  late String _currency;
  late int _color;
  late int _dueDay;
  String? _error;

  bool get _editing => widget.account != null;

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _type = a?.type ?? AccountType.bank;
    _currency = a?.currency ?? 'IDR';
    _color = a?.color ?? kPalette[store.accounts.length % kPalette.length];
    _dueDay = a?.dueDay ?? 25;
    _nameCtrl.text = a?.name ?? '';
    if (a != null) {
      final initial =
          a.type == AccountType.credit ? -a.initialBalance : a.initialBalance;
      if (initial != 0) _balanceCtrl.text = amountToInput(initial.abs(), _currency);
      if (a.creditLimit > 0) {
        _limitCtrl.text = amountToInput(a.creditLimit, _currency);
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    _limitCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Nama akun wajib diisi.');
      return;
    }
    final dec = hasDecimals(_currency);
    final bal = parseAmount(_balanceCtrl.text, decimals: dec);
    final isCredit = _type == AccountType.credit;
    store.upsertAccount(Account(
      id: widget.account?.id ?? store.newId(),
      name: name,
      type: _type,
      currency: _currency,
      initialBalance: isCredit ? -bal : bal,
      color: _color,
      creditLimit: isCredit ? parseAmount(_limitCtrl.text, decimals: dec) : 0,
      dueDay: _dueDay,
    ));
    Navigator.of(context).pop();
    snack(context, _editing ? 'Akun diperbarui' : 'Akun "$name" ditambahkan');
  }

  Future<void> _delete() async {
    final a = widget.account!;
    final ok = await confirmDialog(context,
        title: 'Hapus akun?',
        message: 'Akun "${a.name}" akan dihapus permanen.',
        confirmLabel: 'Hapus',
        destructive: true);
    if (!ok || !mounted) return;
    final err = store.deleteAccount(a.id);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isCredit = _type == AccountType.credit;
    final dec = hasDecimals(_currency);
    final hasTx = _editing && store.accountInUse(widget.account!.id);
    return SheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_editing ? 'Edit Akun' : 'Akun Baru',
              style:
                  const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: fieldDeco('Nama akun', icon: Icons.badge_rounded),
          ),
          const SizedBox(height: 14),
          const SmallLabel('Jenis'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in AccountType.values)
                ChoiceChip(
                  label: Text(t.label),
                  avatar: Icon(t.icon, size: 16),
                  selected: _type == t,
                  onSelected: (_) => setState(() => _type = t),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const SmallLabel('Mata uang'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in kCurrencies)
                ChoiceChip(
                  label: Text(c),
                  selected: _currency == c,
                  onSelected: (_) => setState(() {
                    final old = parseAmount(_balanceCtrl.text,
                        decimals: hasDecimals(_currency));
                    _currency = c;
                    _balanceCtrl.text =
                        old > 0 ? amountToInput(old, _currency) : '';
                  }),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
            ],
          ),
          if (hasTx && _currency != widget.account!.currency)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                  'Catatan: transaksi lama tidak dikonversi otomatis, nominalnya akan dibaca dalam mata uang baru.',
                  style: TextStyle(fontSize: 12, color: C.amberDark)),
            ),
          const SizedBox(height: 14),
          TextField(
            controller: _balanceCtrl,
            keyboardType: TextInputType.numberWithOptions(decimal: dec),
            inputFormatters: [AmountFormatter(decimals: dec)],
            decoration: fieldDeco(
                isCredit ? 'Tagihan awal (opsional)' : 'Saldo awal',
                icon: Icons.savings_rounded,
                prefix: '${currencySymbol(_currency)} ',
                helper: isCredit
                    ? 'Isi kalau kartu sudah punya tagihan sebelum mulai dicatat.'
                    : 'Saldo saat akun mulai dicatat. Saldo berjalan dihitung otomatis.'),
          ),
          if (isCredit) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _limitCtrl,
              keyboardType: TextInputType.numberWithOptions(decimal: dec),
              inputFormatters: [AmountFormatter(decimals: dec)],
              decoration: fieldDeco('Limit kartu',
                  icon: Icons.speed_rounded,
                  prefix: '${currencySymbol(_currency)} '),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: SmallLabel('Tanggal jatuh tempo')),
                DropdownButton<int>(
                  value: _dueDay,
                  borderRadius: BorderRadius.circular(16),
                  items: [
                    for (var d = 1; d <= 28; d++)
                      DropdownMenuItem(value: d, child: Text('Tanggal $d')),
                  ],
                  onChanged: (v) => setState(() => _dueDay = v ?? _dueDay),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          const SmallLabel('Warna'),
          const SizedBox(height: 8),
          _ColorPicker(
              selected: _color, onSelected: (c) => setState(() => _color = c)),
          if (_error != null) ...[
            const SizedBox(height: 12),
            ErrorBox(_error!),
          ],
          const SizedBox(height: 16),
          PrimaryButton(label: 'Simpan Akun', onPressed: _save),
          if (_editing) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _delete,
              style: TextButton.styleFrom(foregroundColor: C.redDark),
              icon: const Icon(Icons.delete_rounded),
              label: const Text('Hapus akun'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.selected, required this.onSelected});
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final c in kPalette)
          Semantics(
            button: true,
            selected: c == selected,
            label: 'Warna',
            child: GestureDetector(
              onTap: () => onSelected(c),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: c == selected ? C.carbon : Colors.white,
                      width: 3),
                ),
                child: c == selected
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 18)
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

// =============================================================================
// HALAMAN: KATEGORI
// =============================================================================

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Builder(builder: (context) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Kategori',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19)),
            backgroundColor: C.bg,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            bottom: const TabBar(
              labelColor: C.greenDark,
              indicatorColor: C.greenDark,
              tabs: [Tab(text: 'Pengeluaran'), Tab(text: 'Pemasukan')],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              final idx = DefaultTabController.of(context).index;
              showSheet<void>(
                  context,
                  CategoryEditorSheet(
                      store: store,
                      type: idx == 0 ? TxType.expense : TxType.income));
            },
            backgroundColor: C.greenDark,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Kategori baru'),
          ),
          body: ListenableBuilder(
            listenable: store,
            builder: (context, _) => TabBarView(
              children: [
                _list(context, TxType.expense),
                _list(context, TxType.income),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _list(BuildContext context, TxType type) {
    final tops = store.topCategories(type);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        for (final c in tops) ...[
          _row(context, c, false),
          for (final s in store.childrenOf(c.id)) _row(context, s, true),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, TxCategory c, bool isChild) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8, left: isChild ? 28 : 0),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        onTap: () => showSheet<void>(context,
            CategoryEditorSheet(store: store, type: c.type, category: c)),
        child: Row(
          children: [
            if (isChild)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.subdirectory_arrow_right_rounded,
                    color: C.muted, size: 18),
              ),
            CatIcon(icon: c.iconData, color: c.colorValue, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Text(c.name,
                  style: TextStyle(
                      fontWeight: isChild ? FontWeight.w600 : FontWeight.w800)),
            ),
            const Icon(Icons.edit_rounded, size: 18, color: C.muted),
          ],
        ),
      ),
    );
  }
}

class CategoryEditorSheet extends StatefulWidget {
  const CategoryEditorSheet(
      {super.key, required this.store, required this.type, this.category});
  final AppStore store;
  final TxType type;
  final TxCategory? category;

  @override
  State<CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends State<CategoryEditorSheet> {
  AppStore get store => widget.store;
  final _nameCtrl = TextEditingController();
  late String _icon;
  late int _color;
  String? _parentId;
  String? _error;

  bool get _editing => widget.category != null;

  @override
  void initState() {
    super.initState();
    final c = widget.category;
    _nameCtrl.text = c?.name ?? '';
    _icon = c?.icon ?? 'other';
    _color = c?.color ?? kPalette[3];
    _parentId = c?.parentId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Nama kategori wajib diisi.');
      return;
    }
    store.upsertCategory(TxCategory(
      id: widget.category?.id ?? store.newId(),
      name: name,
      type: widget.type,
      icon: _icon,
      color: _color,
      parentId: _parentId,
    ));
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final c = widget.category!;
    final ok = await confirmDialog(context,
        title: 'Hapus kategori?',
        message: 'Kategori "${c.name}" akan dihapus.',
        confirmLabel: 'Hapus',
        destructive: true);
    if (!ok || !mounted) return;
    final err = store.deleteCategory(c.id);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final selfId = widget.category?.id;
    final hasChildren =
        selfId != null && store.childrenOf(selfId).isNotEmpty;
    final parents = store
        .topCategories(widget.type)
        .where((c) => c.id != selfId)
        .toList();
    return SheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CatIcon(icon: iconOf(_icon), color: Color(_color), size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                    _editing
                        ? 'Edit Kategori'
                        : 'Kategori ${widget.type.label} Baru',
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: fieldDeco('Nama kategori', icon: Icons.label_rounded),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(child: SmallLabel('Induk kategori')),
              DropdownButton<String?>(
                value: _parentId,
                borderRadius: BorderRadius.circular(16),
                onChanged: hasChildren
                    ? null
                    : (v) => setState(() => _parentId = v),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('Tidak ada (utama)')),
                  for (final p in parents)
                    DropdownMenuItem<String?>(value: p.id, child: Text(p.name)),
                ],
              ),
            ],
          ),
          if (hasChildren)
            const Text('Kategori ini punya sub-kategori, jadi tetap kategori utama.',
                style: TextStyle(fontSize: 12, color: C.muted)),
          const SizedBox(height: 14),
          const SmallLabel('Ikon'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in kIcons.entries)
                Semantics(
                  button: true,
                  selected: e.key == _icon,
                  label: e.key,
                  child: GestureDetector(
                    onTap: () => setState(() => _icon = e.key),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: e.key == _icon
                            ? Color(_color).withValues(alpha: 0.18)
                            : C.bg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: e.key == _icon
                                ? darken(Color(_color))
                                : C.line,
                            width: e.key == _icon ? 2 : 1),
                      ),
                      child: Icon(e.value,
                          color: e.key == _icon
                              ? darken(Color(_color))
                              : C.muted),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const SmallLabel('Warna'),
          const SizedBox(height: 8),
          _ColorPicker(
              selected: _color, onSelected: (c) => setState(() => _color = c)),
          if (_error != null) ...[
            const SizedBox(height: 12),
            ErrorBox(_error!),
          ],
          const SizedBox(height: 16),
          PrimaryButton(label: 'Simpan Kategori', onPressed: _save),
          if (_editing) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _delete,
              style: TextButton.styleFrom(foregroundColor: C.redDark),
              icon: const Icon(Icons.delete_rounded),
              label: const Text('Hapus kategori'),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// HALAMAN: ANGGARAN
// =============================================================================

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key, required this.store});
  final AppStore store;

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  AppStore get store => widget.store;
  late BudgetPeriod _period;
  final _globalCtrl = TextEditingController();
  final Map<String, TextEditingController> _catCtrls = {};

  static String _init(double v) => v > 0 ? _plain.format(v.round()) : '';

  @override
  void initState() {
    super.initState();
    final s = store.settings;
    _period = s.budgetPeriod;
    _globalCtrl.text = _init(s.globalBudget);
    for (final c in store.topCategories(TxType.expense)) {
      _catCtrls[c.id] =
          TextEditingController(text: _init(s.categoryBudgets[c.id] ?? 0));
    }
  }

  @override
  void dispose() {
    _globalCtrl.dispose();
    for (final c in _catCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _sumCats =>
      _catCtrls.values.fold(0.0, (s, c) => s + parseAmount(c.text));

  void _save() {
    final per = <String, double>{};
    _catCtrls.forEach((id, ctrl) {
      final v = parseAmount(ctrl.text);
      if (v > 0) per[id] = v;
    });
    store.setBudget(_period, parseAmount(_globalCtrl.text), per);
    Navigator.of(context).pop();
    snack(context, 'Anggaran ${_period.label.toLowerCase()} disimpan 🎯');
  }

  @override
  Widget build(BuildContext context) {
    final global = parseAmount(_globalCtrl.text);
    final over = global > 0 && _sumCats > global;
    return Scaffold(
      appBar: pageBar('Anggaran'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          const Text(
              'Semua batas dalam Rupiah. Transaksi mata uang lain dikonversi pakai kurs di menu Mata Uang & Kurs. Kosongkan kolom untuk menonaktifkan.',
              style: TextStyle(color: C.muted, fontSize: 13)),
          const SizedBox(height: 14),
          const SmallLabel('Periode anggaran'),
          const SizedBox(height: 8),
          Segmented<BudgetPeriod>(
            values: BudgetPeriod.values,
            selected: _period,
            labelOf: (p) => p.label,
            onChanged: (p) => setState(() => _period = p),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _globalCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [AmountFormatter()],
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontWeight: FontWeight.w800),
            decoration: fieldDeco('Batas total ${_period.label.toLowerCase()}',
                icon: Icons.account_balance_wallet_rounded, prefix: 'Rp '),
          ),
          const SizedBox(height: 18),
          const SmallLabel('Batas per kategori'),
          const SizedBox(height: 10),
          for (final c in store.topCategories(TxType.expense))
            if (_catCtrls[c.id] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    CatIcon(icon: c.iconData, color: c.colorValue, size: 40),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _catCtrls[c.id],
                        keyboardType: TextInputType.number,
                        inputFormatters: [AmountFormatter()],
                        onChanged: (_) => setState(() {}),
                        decoration: fieldDeco(c.name, prefix: 'Rp '),
                      ),
                    ),
                  ],
                ),
              ),
          if (over)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: C.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Total per kategori (${money(_sumCats)}) melebihi batas total (${money(global)}). Boleh disimpan, tapi cek lagi ya ⚠️',
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: C.amberDark),
              ),
            ),
          const SizedBox(height: 16),
          PrimaryButton(label: 'Simpan Anggaran', onPressed: _save),
        ],
      ),
    );
  }
}

// =============================================================================
// HALAMAN: TRANSAKSI BERULANG
// =============================================================================

class RecurringPage extends StatelessWidget {
  const RecurringPage({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pageBar('Transaksi Berulang'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openRecurringForm(context, store),
        backgroundColor: C.greenDark,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah'),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final rules = [...store.recurring]
            ..sort((a, b) => a.nextDate.compareTo(b.nextDate));
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            children: [
              const Text(
                  'Gaji, langganan, cicilan, atau kiriman rutin dicatat otomatis setiap kali aplikasi dibuka dan sudah jatuh tempo.',
                  style: TextStyle(color: C.muted, fontSize: 13)),
              const SizedBox(height: 12),
              if (rules.isEmpty)
                const AppCard(
                    child: EmptyState(
                        icon: Icons.repeat_rounded,
                        title: 'Belum ada transaksi berulang'))
              else
                for (final r in rules)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      onTap: () => openRecurringForm(context, store, rule: r),
                      child: Row(
                        children: [
                          CatIcon(
                              icon: r.type == TxType.transfer
                                  ? Icons.swap_horiz_rounded
                                  : (store.categoryById(r.categoryId)?.iconData ??
                                      Icons.repeat_rounded),
                              color: r.type == TxType.transfer
                                  ? C.blue
                                  : (store
                                          .categoryById(r.categoryId)
                                          ?.colorValue ??
                                      C.muted)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800)),
                                Text(
                                    '${money(r.amount, store.currencyOf(r.accountId))} · ${r.frequency.label}',
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: r.type.color)),
                                Text(
                                    r.active
                                        ? 'Berikutnya ${DateFormat('EEE, d MMM yyyy', 'id_ID').format(r.nextDate)}'
                                        : 'Dijeda',
                                    style: const TextStyle(
                                        fontSize: 12, color: C.muted)),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              Switch(
                                value: r.active,
                                activeTrackColor: C.greenDark,
                                onChanged: (v) {
                                  store.toggleRecurring(r.id, v);
                                  if (v) {
                                    final n = store.processRecurring();
                                    if (n > 0) {
                                      snack(context,
                                          '$n transaksi jatuh tempo hari ini langsung dicatat');
                                    }
                                  }
                                },
                              ),
                              IconButton(
                                tooltip: 'Hapus',
                                icon: const Icon(Icons.delete_outline_rounded,
                                    color: C.redDark),
                                onPressed: () async {
                                  final ok = await confirmDialog(context,
                                      title: 'Hapus transaksi berulang?',
                                      message:
                                          'Transaksi yang sudah tercatat tetap ada. Hanya jadwal ke depan yang dihapus.',
                                      confirmLabel: 'Hapus',
                                      destructive: true);
                                  if (ok) store.deleteRecurring(r.id);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

// =============================================================================
// HALAMAN: TEMPLATE
// =============================================================================

class TemplatesPage extends StatelessWidget {
  const TemplatesPage({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pageBar('Template Catat Cepat'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openTemplateForm(context, store),
        backgroundColor: C.greenDark,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Template baru'),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
          children: [
            const Text(
                'Untuk pengeluaran yang sering diulang. Ketuk template untuk langsung mencatat.',
                style: TextStyle(color: C.muted, fontSize: 13)),
            const SizedBox(height: 12),
            if (store.templates.isEmpty)
              const AppCard(
                  child: EmptyState(
                      icon: Icons.bolt_rounded, title: 'Belum ada template'))
            else
              for (final t in store.templates)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    onTap: () => openTxForm(context, store, template: t),
                    child: Row(
                      children: [
                        CatIcon(
                            icon: t.type == TxType.transfer
                                ? Icons.swap_horiz_rounded
                                : (store.categoryById(t.categoryId)?.iconData ??
                                    Icons.bolt_rounded),
                            color: t.type == TxType.transfer
                                ? C.blue
                                : (store.categoryById(t.categoryId)?.colorValue ??
                                    C.muted)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                              Text(
                                  '${t.type.label} · ${store.accountName(t.accountId)}',
                                  style: const TextStyle(
                                      fontSize: 12, color: C.muted)),
                            ],
                          ),
                        ),
                        Text(money(t.amount, store.currencyOf(t.accountId)),
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: t.type.color)),
                        IconButton(
                          tooltip: 'Hapus template',
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: C.redDark),
                          onPressed: () => store.deleteTemplate(t.id),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

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
            child: const Text(
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

// =============================================================================
// HALAMAN: NOTIFIKASI
// =============================================================================

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key, required this.store});
  final AppStore store;

  Future<void> _pickTime(BuildContext context) async {
    final s = store.settings;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: s.reminderHour, minute: s.reminderMinute),
    );
    if (t == null) return;
    store.updateSettings((x) {
      x.reminderHour = t.hour;
      x.reminderMinute = t.minute;
    });
  }

  Widget _switch(
      {required String title,
      required String subtitle,
      required bool value,
      required ValueChanged<bool>? onChanged}) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12.5, color: C.muted)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pageBar('Notifikasi'),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final s = store.settings;
          final on = s.notifEnabled;
          final planned = store.plannedNotifications();
          final time = TimeOfDay(hour: s.reminderHour, minute: s.reminderMinute)
              .format(context);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              if (!Notifier.instance.supported)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: ErrorBox(
                      'Notifikasi tidak tersedia di versi ini (misalnya DartPad atau izin belum diberikan).'),
                ),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: _switch(
                  title: 'Aktifkan notifikasi',
                  subtitle: on
                      ? '${planned.length} pengingat terjadwal'
                      : 'Semua pengingat mati',
                  value: on,
                  onChanged: (v) {
                    store.updateSettings((x) => x.notifEnabled = v);
                    if (v) unawaited(Notifier.instance.requestPermission());
                  },
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(
                  children: [
                    _switch(
                      title: 'Sembunyikan nominal',
                      subtitle: 'Notifikasi tidak menampilkan jumlah uang',
                      value: s.notifHideAmounts,
                      onChanged: on
                          ? (v) =>
                              store.updateSettings((x) => x.notifHideAmounts = v)
                          : null,
                    ),
                    _switch(
                      title: 'Transaksi berulang',
                      subtitle:
                          'Sehari sebelum (bulanan/tahunan) dan saat jatuh tempo',
                      value: s.notifRecurring,
                      onChanged: on
                          ? (v) =>
                              store.updateSettings((x) => x.notifRecurring = v)
                          : null,
                    ),
                    _switch(
                      title: 'Tagihan kartu kredit',
                      subtitle: '3 hari sebelum dan saat jatuh tempo',
                      value: s.notifCredit,
                      onChanged: on
                          ? (v) =>
                              store.updateSettings((x) => x.notifCredit = v)
                          : null,
                    ),
                    _switch(
                      title: 'Peringatan anggaran',
                      subtitle: 'Saat status berubah jadi Seret atau Jebol',
                      value: s.notifBudget,
                      onChanged: on
                          ? (v) =>
                              store.updateSettings((x) => x.notifBudget = v)
                          : null,
                    ),
                    _switch(
                      title: 'Pengingat harian',
                      subtitle: 'Setiap hari jam $time',
                      value: s.dailyReminder,
                      onChanged: on
                          ? (v) =>
                              store.updateSettings((x) => x.dailyReminder = v)
                          : null,
                    ),
                    if (on && s.dailyReminder)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _pickTime(context),
                          icon: const Icon(Icons.schedule_rounded),
                          label: Text('Ubah jam ($time)'),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (on && planned.isNotEmpty)
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('Pengingat terdekat'),
                      const SizedBox(height: 6),
                      for (final n in ([...planned]
                            ..sort((a, b) => a.when.compareTo(b.when)))
                          .take(5))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 92,
                                child: Text(
                                    DateFormat('d MMM HH:mm', 'id_ID')
                                        .format(n.when),
                                    style: const TextStyle(
                                        fontSize: 12, color: C.muted)),
                              ),
                              Expanded(
                                child: Text(n.title,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Kirim notifikasi tes',
                icon: Icons.notifications_active_rounded,
                onPressed: on
                    ? () {
                        unawaited(Notifier.instance.showNow(3,
                            '🔔 Notifikasi Infinity aktif',
                            'Pengingat tagihan dan transaksi berulang akan muncul di sini.'));
                        snack(context,
                            'Notifikasi tes dikirim. Kalau tidak muncul, cek izin notifikasi di pengaturan HP.');
                      }
                    : null,
              ),
              const SizedBox(height: 12),
              const Text(
                  'Catatan: pengingat dijadwalkan ke sistem Android, jadi tetap muncul walau aplikasi ditutup. Beberapa HP (Xiaomi, Oppo, Vivo) membatasi aplikasi di latar belakang. Kalau pengingat tidak muncul, matikan penghemat baterai untuk Infinity.',
                  style: TextStyle(fontSize: 12.5, color: C.muted)),
            ],
          );
        },
      ),
    );
  }
}

// =============================================================================
// HALAMAN: CATAT OTOMATIS DARI NOTIFIKASI
// =============================================================================

class AutoCapturePage extends StatefulWidget {
  const AutoCapturePage({super.key, required this.store});
  final AppStore store;

  @override
  State<AutoCapturePage> createState() => _AutoCapturePageState();
}

class _AutoCapturePageState extends State<AutoCapturePage>
    with WidgetsBindingObserver {
  AppStore get store => widget.store;
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kembali dari Pengaturan Android: cek ulang izinnya.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final ok = await NativeBridge.isListenerEnabled();
    if (mounted) setState(() => _enabled = ok);
  }

  Future<void> _checkNow() async {
    final raw = await NativeBridge.fetchCaptured();
    if (!mounted) return;
    final before = store.pendingCaptures.length;
    final auto = store.ingestCaptured(raw);
    final waiting = store.pendingCaptures.length - before;
    snack(
        context,
        raw.isEmpty
            ? 'Belum ada notifikasi uang baru.'
            : '$auto dicatat otomatis, ${waiting < 0 ? 0 : waiting} menunggu dicek.');
  }

  Widget _step(String n, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                  color: C.greenDark, shape: BoxShape.circle),
              child: Text(n,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Text(text,
                    style: const TextStyle(fontSize: 13, height: 1.35))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pageBar('Catat Otomatis'),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final mode = store.settings.captureMode;
          final enabled = _enabled;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              AppCard(
                child: Row(
                  children: [
                    CatIcon(
                        icon: enabled == true
                            ? Icons.check_circle_rounded
                            : Icons.notifications_off_rounded,
                        color: enabled == true ? C.green : C.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              enabled == null
                                  ? 'Mengecek izin...'
                                  : (enabled
                                      ? 'Akses notifikasi aktif'
                                      : 'Akses notifikasi belum diizinkan'),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 15)),
                          const Text(
                              'Infinity hanya mengambil notifikasi yang berisi nominal "Rp". Semua diproses di HP ini.',
                              style: TextStyle(fontSize: 12.5, color: C.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (enabled != true) ...[
                const SizedBox(height: 12),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionTitle('Cara mengaktifkan'),
                      const SizedBox(height: 8),
                      _step('1',
                          'Tekan "Buka pengaturan" di bawah, cari Infinity, lalu aktifkan.'),
                      _step('2',
                          'Kalau muncul "Setelan terbatas" (Android 13+, karena app di-install dari APK): buka Info aplikasi Infinity, tekan menu ⋮ di kanan atas, pilih "Izinkan setelan terbatas", lalu ulangi langkah 1.'),
                      _step('3',
                          'Di Xiaomi/Oppo/Vivo: atur Baterai Infinity ke "Tanpa batasan" supaya tidak dimatikan sistem.'),
                      const SizedBox(height: 12),
                      PrimaryButton(
                        label: 'Buka pengaturan akses notifikasi',
                        icon: Icons.open_in_new_rounded,
                        onPressed: NativeBridge.openListenerSettings,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: NativeBridge.openAppSettings,
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20))),
                        child: const Text('Buka Info aplikasi Infinity'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const SmallLabel('Mode pencatatan'),
              const SizedBox(height: 8),
              Segmented<String>(
                values: const ['off', 'ask', 'auto'],
                selected: mode,
                labelOf: (m) => switch (m) {
                  'off' => 'Mati',
                  'ask' => 'Tanya dulu',
                  _ => 'Langsung catat',
                },
                onChanged: (m) =>
                    store.updateSettings((x) => x.captureMode = m),
              ),
              const SizedBox(height: 8),
              Text(
                  switch (mode) {
                    'off' => 'Notifikasi bank/e-wallet diabaikan.',
                    'ask' =>
                      'Setiap notifikasi masuk ke kartu "Dari Notifikasi" di Beranda. Kamu tinggal tekan Catat atau Abaikan.',
                    _ =>
                      'Langsung dicatat kalau akun bisa ditebak. Kalau akun tidak jelas atau sepertinya sudah kamu catat manual (nominal & akun sama dalam 10 menit), masuk ke "Dari Notifikasi" dulu.',
                  },
                  style: const TextStyle(fontSize: 12.5, color: C.muted)),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle('Yang dikenali'),
                    const SizedBox(height: 6),
                    const Text(
                        'GoPay, OVO, DANA, ShopeePay, LinkAja, myBCA/BCA mobile, Jago, BRImo, Livin Mandiri, BNI, SeaBank, blu, Flip, dan aplikasi lain yang notifikasinya menyebut "Rp".',
                        style: TextStyle(fontSize: 13)),
                    const SizedBox(height: 8),
                    const Text(
                        'Supaya akun tertebak, beri nama akun yang memuat nama aplikasinya, misalnya "GoPay", "BCA", atau "Bank Jago". Notifikasi promo (diskon, voucher, cashback hingga...) diabaikan.',
                        style: TextStyle(fontSize: 12.5, color: C.muted)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Cek notifikasi sekarang',
                icon: Icons.refresh_rounded,
                onPressed: _checkNow,
              ),
              if (store.pendingCaptures.isNotEmpty) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: store.clearCaptures,
                  style: TextButton.styleFrom(foregroundColor: C.redDark),
                  child: Text(
                      'Kosongkan antrean (${store.pendingCaptures.length})'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// =============================================================================
// PIN
// =============================================================================

/// Keypad PIN 4 digit. [onComplete] mengembalikan pesan error atau null (lolos).
class PinPad extends StatefulWidget {
  const PinPad(
      {super.key,
      required this.title,
      this.subtitle,
      required this.onComplete});

  final String title;
  final String? subtitle;
  final String? Function(String pin) onComplete;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _pin = '';
  String? _error;

  void _tap(String k) {
    HapticFeedback.selectionClick();
    if (k == '⌫') {
      if (_pin.isNotEmpty) {
        setState(() => _pin = _pin.substring(0, _pin.length - 1));
      }
      return;
    }
    if (_pin.length >= 4) return;
    setState(() {
      _pin += k;
      _error = null;
    });
    if (_pin.length == 4) {
      final entered = _pin;
      final err = widget.onComplete(entered);
      if (!mounted) return;
      if (err != null) HapticFeedback.heavyImpact();
      setState(() {
        _pin = '';
        _error = err;
      });
    }
  }

  Widget _key(String k) {
    if (k.isEmpty) return const Expanded(child: SizedBox(height: 64));
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _tap(k),
            child: SizedBox(
              height: 64,
              child: Center(
                child: k == '⌫'
                    ? const Icon(Icons.backspace_outlined,
                        semanticLabel: 'Hapus')
                    : Text(k,
                        style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.all_inclusive_rounded, color: C.greenDark, size: 44),
          const SizedBox(height: 12),
          Text(widget.title,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(widget.subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: C.muted)),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 4; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _pin.length ? C.greenDark : Colors.transparent,
                    border: Border.all(color: C.greenDark, width: 2),
                  ),
                ),
            ],
          ),
          SizedBox(
            height: 32,
            child: Center(
              child: Text(_error ?? '',
                  style: const TextStyle(
                      color: C.redDark, fontWeight: FontWeight.w700)),
            ),
          ),
          for (final r in rows) Row(children: [for (final k in r) _key(k)]),
        ],
      ),
    );
  }
}

class PinLockScreen extends StatefulWidget {
  const PinLockScreen({
    super.key,
    required this.pin,
    required this.onUnlocked,
    this.biometric = false,
  });
  final String pin;
  final VoidCallback onUnlocked;
  final bool biometric;

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  int _wrong = 0;
  DateTime? _lockedUntil;
  bool _bioAvailable = false;

  @override
  void initState() {
    super.initState();
    if (widget.biometric) _initBio();
  }

  Future<void> _initBio() async {
    final ok = await Biometric.available();
    if (!mounted) return;
    setState(() => _bioAvailable = ok);
    if (ok) await _tryBio();
  }

  Future<void> _tryBio() async {
    final ok = await Biometric.authenticate();
    if (ok && mounted) widget.onUnlocked();
  }

  /// Maksimal 5 kali salah, lalu jeda 30 detik.
  String? _check(String p) {
    final until = _lockedUntil;
    if (until != null && DateTime.now().isBefore(until)) {
      final sec = until.difference(DateTime.now()).inSeconds + 1;
      return 'Terlalu banyak salah. Coba lagi dalam $sec detik.';
    }
    if (p == widget.pin) {
      widget.onUnlocked();
      return null;
    }
    _wrong++;
    if (_wrong >= 5) {
      _wrong = 0;
      _lockedUntil = DateTime.now().add(const Duration(seconds: 30));
      return 'Salah 5 kali. Tunggu 30 detik.';
    }
    return 'PIN salah (${5 - _wrong} kesempatan lagi)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PinPad(
                  title: 'Masukkan PIN',
                  subtitle: 'Infinity terkunci',
                  onComplete: _check,
                ),
                if (_bioAvailable) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _tryBio,
                    icon: const Icon(Icons.fingerprint_rounded, size: 28),
                    label: const Text('Pakai sidik jari / wajah',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PinSetupPage extends StatefulWidget {
  const PinSetupPage({super.key});

  @override
  State<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends State<PinSetupPage> {
  String? _first;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pageBar('Atur PIN'),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: PinPad(
            title: _first == null ? 'Buat PIN baru' : 'Ulangi PIN',
            subtitle: _first == null
                ? '4 angka, jangan pakai tanggal lahir'
                : 'Masukkan PIN yang sama sekali lagi',
            onComplete: (p) {
              if (_first == null) {
                setState(() => _first = p);
                return null;
              }
              if (p != _first) {
                setState(() => _first = null);
                return 'PIN tidak sama, ulangi dari awal';
              }
              Navigator.of(context).pop(p);
              return null;
            },
          ),
        ),
      ),
    );
  }
}

class PinVerifyPage extends StatelessWidget {
  const PinVerifyPage({super.key, required this.pin});
  final String pin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pageBar('Verifikasi PIN'),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: PinPad(
            title: 'Masukkan PIN lama',
            onComplete: (p) {
              if (p == pin) {
                Navigator.of(context).pop(true);
                return null;
              }
              return 'PIN salah';
            },
          ),
        ),
      ),
    );
  }
}

class SecurityPage extends StatelessWidget {
  const SecurityPage({super.key, required this.store});
  final AppStore store;

  Future<bool> _verify(BuildContext context) async {
    final pin = store.settings.pin;
    if (pin == null) return true;
    final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => PinVerifyPage(pin: pin)));
    return ok == true;
  }

  Future<void> _setPin(BuildContext context) async {
    if (!await _verify(context)) return;
    if (!context.mounted) return;
    final p = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const PinSetupPage()));
    if (p == null || !context.mounted) return;
    store.setPin(p);
    snack(context, 'PIN aktif 🔒');
  }

  Future<void> _removePin(BuildContext context) async {
    if (!await _verify(context)) return;
    if (!context.mounted) return;
    store.setPin(null);
    snack(context, 'PIN dinonaktifkan');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pageBar('Keamanan'),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final active = store.settings.pin != null;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              AppCard(
                child: Row(
                  children: [
                    CatIcon(
                        icon: active
                            ? Icons.lock_rounded
                            : Icons.lock_open_rounded,
                        color: active ? C.green : C.muted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(active ? 'PIN aktif' : 'PIN nonaktif',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 16)),
                          const Text(
                              'Aplikasi minta PIN saat dibuka, dan saat kembali setelah 30 detik di latar belakang.',
                              style: TextStyle(fontSize: 12.5, color: C.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(
                  children: [
                    SwitchListTile(
                      value: store.settings.biometric && active,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      title: const Text('Buka dengan sidik jari / wajah',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14)),
                      subtitle: Text(
                          active
                              ? 'PIN tetap bisa dipakai sebagai cadangan'
                              : 'Pasang PIN dulu untuk mengaktifkan',
                          style:
                              const TextStyle(fontSize: 12.5, color: C.muted)),
                      onChanged: active
                          ? (v) async {
                              if (v) {
                                if (!await Biometric.available()) {
                                  if (context.mounted) {
                                    snack(context,
                                        'Sidik jari/wajah belum terdaftar di HP ini, atau tidak didukung.');
                                  }
                                  return;
                                }
                                if (!await Biometric.authenticate()) return;
                              }
                              store.updateSettings((x) => x.biometric = v);
                            }
                          : null,
                    ),
                    SwitchListTile(
                      value: store.settings.secureScreen,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      title: const Text('Mode layar aman',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14)),
                      subtitle: const Text(
                          'Isi app disembunyikan di daftar aplikasi terbaru dan screenshot diblokir',
                          style: TextStyle(fontSize: 12.5, color: C.muted)),
                      onChanged: (v) =>
                          store.updateSettings((x) => x.secureScreen = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                  'Data keuangan disimpan terenkripsi di HP ini (kunci di Android Keystore). PIN ikut tersimpan di penyimpanan terenkripsi itu dan tidak ikut ke file backup. Tidak ada data yang dikirim ke internet.',
                  style: TextStyle(fontSize: 12.5, color: C.muted)),
              const SizedBox(height: 16),
              PrimaryButton(
                label: active ? 'Ganti PIN' : 'Pasang PIN',
                icon: Icons.lock_rounded,
                onPressed: () => _setPin(context),
              ),
              if (active) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _removePin(context),
                  style: TextButton.styleFrom(foregroundColor: C.redDark),
                  child: const Text('Nonaktifkan PIN'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// =============================================================================
// HALAMAN: BACKUP & PULIHKAN
// =============================================================================

class BackupPage extends StatefulWidget {
  const BackupPage({super.key, required this.store});
  final AppStore store;

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  AppStore get store => widget.store;
  final _importCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _importCtrl.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    final json = store.exportJson();
    await Clipboard.setData(ClipboardData(text: json));
    // Hapus dari clipboard setelah 60 detik supaya tidak terbaca app lain.
    unawaited(Future<void>.delayed(const Duration(seconds: 60), () async {
      try {
        final cur = await Clipboard.getData(Clipboard.kTextPlain);
        if (cur?.text == json) {
          await Clipboard.setData(const ClipboardData(text: ''));
        }
      } catch (_) {}
    }));
    if (!mounted) return;
    snack(context,
        'Backup (${(json.length / 1024).toStringAsFixed(1)} KB, tanpa PIN) disalin. Tempel dalam 60 detik, setelah itu clipboard dikosongkan.');
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    setState(() => _importCtrl.text = data?.text ?? '');
  }

  Future<void> _restore() async {
    if (_importCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Tempel data backup dulu.');
      return;
    }
    final ok = await confirmDialog(context,
        title: 'Pulihkan backup?',
        message:
            'Semua data sekarang akan DIGANTI dengan isi backup. Salin backup data sekarang dulu kalau masih perlu.',
        confirmLabel: 'Pulihkan',
        destructive: true);
    if (!ok || !mounted) return;
    try {
      store.importJson(_importCtrl.text);
      setState(() {
        _error = null;
        _importCtrl.clear();
      });
      snack(context, 'Data berhasil dipulihkan ✅');
    } catch (e) {
      setState(() => _error =
          'Gagal memulihkan: pastikan yang ditempel adalah backup Infinity yang utuh. ($e)');
    }
  }

  Future<void> _resetDemo() async {
    final ok = await confirmDialog(context,
        title: 'Muat ulang data demo?',
        message: 'Semua data sekarang akan diganti dengan data contoh.',
        confirmLabel: 'Ganti',
        destructive: true);
    if (!ok || !mounted) return;
    store.resetDemo();
    snack(context, 'Data demo dimuat');
  }

  Future<void> _clear() async {
    final ok = await confirmDialog(context,
        title: 'Hapus semua data?',
        message:
            'Semua transaksi, akun tambahan, template, dan jadwal berulang akan dihapus permanen. Akun dan kategori dasar dibuat ulang dengan saldo 0.',
        confirmLabel: 'Hapus semua',
        destructive: true);
    if (!ok || !mounted) return;
    store.clearAll();
    snack(context, 'Semua data dihapus. Mulai dari nol 🌱');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pageBar('Backup & Pulihkan'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionTitle('Backup'),
                const SizedBox(height: 6),
                Text(
                    '${store.transactions.length} transaksi, ${store.accounts.length} akun, ${store.categories.length} kategori. Data disalin sebagai teks JSON, simpan di tempat aman (catatan, email ke diri sendiri, Google Drive).',
                    style: const TextStyle(fontSize: 13, color: C.muted)),
                const SizedBox(height: 12),
                PrimaryButton(
                    label: 'Salin backup',
                    icon: Icons.copy_rounded,
                    onPressed: _copy),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionTitle('Pulihkan'),
                const SizedBox(height: 10),
                TextField(
                  controller: _importCtrl,
                  maxLines: 6,
                  minLines: 4,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  decoration: fieldDeco('Tempel data backup di sini'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _paste,
                        icon: const Icon(Icons.content_paste_rounded),
                        label: const Text('Tempel'),
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20))),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _restore,
                        icon: const Icon(Icons.restore_rounded),
                        label: const Text('Pulihkan'),
                        style: FilledButton.styleFrom(
                            backgroundColor: C.greenDark,
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20))),
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  ErrorBox(_error!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionTitle('Zona Bahaya'),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _resetDemo,
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20))),
                  child: const Text('Muat ulang data demo'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _clear,
                  style: OutlinedButton.styleFrom(
                      foregroundColor: C.redDark,
                      side: const BorderSide(color: C.redDark),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20))),
                  child: const Text('Hapus semua data'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
