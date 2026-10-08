part of '../main.dart';

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
    this.photos = const [],
  });

  final String id;
  final String title;

  /// Nama file foto struk di folder pribadi app (lihat [Receipts]).
  final List<String> photos;

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
        if (photos.isNotEmpty) 'photos': photos,
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
        photos: j['photos'] is List
            ? (j['photos'] as List).whereType<String>().toList()
            : const [],
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
    List<String>? photos,
  })  : date = date ?? DateTime.now(),
        photos = photos ?? [];

  /// Foto struk (nama file).
  List<String> photos;

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
        photos: [...t.photos],
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
        photos: List.unmodifiable(photos),
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

  /// 'system' | 'light' | 'dark'
  String themeMode = 'system';
  int accentIndex = 0;

  /// Akun yang otomatis terpilih saat mencatat transaksi baru.
  String? defaultAccountId;

  /// Kapan saldo tiap akun terakhir diubah manual (id akun -> waktu).
  /// Notifikasi bank yang lebih lama dari waktu ini tidak dicatat otomatis,
  /// karena saldo yang diketik user sudah termasuk transaksi itu.
  Map<String, String> balanceSetAt = {};

  /// Langganan terdeteksi yang ditolak user (kunci judul).
  List<String> dismissedSubs = [];

  /// Insight yang ditutup hari ini (id -> yyyy-MM-dd).
  Map<String, String> dismissedInsights = {};

  /// Saldo terakhir yang disebut notifikasi bank/e-wallet
  /// (id akun -> "nominal|waktu ISO"), untuk mencocokkan saldo.
  Map<String, String> reportedBalance = {};

  /// Backup JSON otomatis ke Download/Infinity tiap 7 hari.
  bool autoBackup = true;
  DateTime? lastAutoBackup;

  // Header Beranda
  String displayName = 'Infinity';
  String? avatarPath;

  /// 'time' (sapaan sesuai jam) | 'custom' | 'motivation'
  String greetingMode = 'time';
  String greetingText = '';

  // Keamanan
  bool biometric = false;
  bool secureScreen = false;

  /// 'off' | 'ask' | 'auto' untuk pencatatan dari notifikasi bank/e-wallet.
  String captureMode = 'auto';

  // Notifikasi
  bool notifHideAmounts = true;
  bool notifEnabled = true;
  bool notifRecurring = true;
  bool notifCredit = true;
  bool notifBudget = true;
  bool notifDebt = true;
  bool dailyReminder = true;
  /// Notifikasi menetap berisi tombol pintasan (seperti Money Manager).
  bool quickBar = true;
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
        'themeMode': themeMode,
        'accentIndex': accentIndex,
        'defaultAccountId': defaultAccountId,
        'balanceSetAt': balanceSetAt,
        'dismissedSubs': dismissedSubs,
        'dismissedInsights': dismissedInsights,
        'reportedBalance': reportedBalance,
        'autoBackup': autoBackup,
        'lastAutoBackup': lastAutoBackup?.toIso8601String(),
        'displayName': displayName,
        'avatarPath': avatarPath,
        'greetingMode': greetingMode,
        'greetingText': greetingText,
        'biometric': biometric,
        'secureScreenV2': secureScreen,
        'captureMode': captureMode,
        'notifHideAmounts': notifHideAmounts,
        'notifEnabled': notifEnabled,
        'notifRecurring': notifRecurring,
        'notifCredit': notifCredit,
        'notifBudget': notifBudget,
        'notifDebt': notifDebt,
        'dailyReminder': dailyReminder,
        'quickBar': quickBar,
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
    final tm = _s(j['themeMode']);
    s.themeMode = (tm == 'light' || tm == 'dark') ? tm! : 'system';
    s.accentIndex = _i(j['accentIndex'], 0).clamp(0, C.accents.length - 1);
    s.autoBackup = j['autoBackup'] != false;
    s.defaultAccountId = _s(j['defaultAccountId']);
    final ds = j['dismissedSubs'];
    if (ds is List) s.dismissedSubs = ds.whereType<String>().toList();
    final di = j['dismissedInsights'];
    if (di is Map) {
      s.dismissedInsights = {
        for (final e in di.entries)
          if (e.value is String) e.key.toString(): e.value as String
      };
    }
    final rb = j['reportedBalance'];
    if (rb is Map) {
      s.reportedBalance = {
        for (final e in rb.entries)
          if (e.value is String) e.key.toString(): e.value as String
      };
    }
    final bsa = j['balanceSetAt'];
    if (bsa is Map) {
      s.balanceSetAt = {
        for (final e in bsa.entries)
          if (e.value is String) e.key.toString(): e.value as String
      };
    }
    s.lastAutoBackup = DateTime.tryParse(_s(j['lastAutoBackup']) ?? '');
    final dn = _s(j['displayName'])?.trim();
    s.displayName = (dn == null || dn.isEmpty) ? 'Infinity' : dn;
    s.avatarPath = _s(j['avatarPath']);
    final gm = _s(j['greetingMode']);
    s.greetingMode = (gm == 'custom' || gm == 'motivation') ? gm! : 'time';
    s.greetingText = _s(j['greetingText']) ?? '';
    s.biometric = j['biometric'] == true;
    // V2: bawaan sekarang mati (screenshot boleh). Setelan lama diabaikan.
    s.secureScreen = j['secureScreenV2'] == true;
    final mode = _s(j['captureMode']);
    s.captureMode =
        (mode == 'off' || mode == 'ask' || mode == 'auto') ? mode! : 'auto';
    s.notifHideAmounts = j['notifHideAmounts'] != false;
    s.notifEnabled = j['notifEnabled'] != false;
    s.notifRecurring = j['notifRecurring'] != false;
    s.notifCredit = j['notifCredit'] != false;
    s.notifBudget = j['notifBudget'] != false;
    s.notifDebt = j['notifDebt'] != false;
    s.dailyReminder = j['dailyReminder'] != false;
    s.quickBar = j['quickBar'] != false;
    s.reminderHour = _i(j['reminderHour'], 20).clamp(0, 23);
    s.reminderMinute = _i(j['reminderMinute'], 0).clamp(0, 59);
    return s;
  }
}
