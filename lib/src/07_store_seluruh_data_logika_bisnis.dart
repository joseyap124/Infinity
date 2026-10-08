part of '../main.dart';

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
  List<Debt> debts = [];
  List<Goal> goals = [];
  AppSettings settings = AppSettings();

  int _idCounter = 0;
  String newId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${(_idCounter++).toRadixString(36)}${math.Random().nextInt(1 << 16).toRadixString(36)}';

  // ---------------------------------------------------------------- persist

  Future<void> load() async {
    String? raw;
    var fromLegacy = false;
    final fileOk = await DataFile.init();
    if (fileOk) {
      try {
        raw = await DataFile.read();
      } catch (_) {
        await DataFile.quarantine();
        loadWarning =
            'Data tersimpan tidak bisa dibaca. Salinannya sudah diamankan, aplikasi mulai dari data kosong.';
      }
    }
    if (raw == null && loadWarning == null) {
      // Versi lama (<=1.7) menyimpan semua data di secure storage.
      try {
        final legacy = await SecureStore.read(_key);
        if (legacy != null && legacy.isNotEmpty) {
          raw = legacy;
          fromLegacy = true;
        }
      } catch (_) {
        if (!fileOk) {
          _storageOk = false;
          loadWarning =
              'Penyimpanan terenkripsi tidak tersedia. Data hanya tersimpan selama aplikasi terbuka.';
        }
      }
    }
    _useFile = fileOk;
    if (raw == null) {
      _seedEmpty();
    } else {
      try {
        final decoded = jsonDecode(raw);
        _applyJson(Map<String, dynamic>.from(decoded as Map));
      } catch (_) {
        try {
          await SecureStore.write(
              '${_key}_rusak_${DateTime.now().millisecondsSinceEpoch}', raw);
        } catch (_) {}
        _seedEmpty();
        loadWarning =
            'Data tersimpan tidak bisa dibaca. Salinannya sudah diamankan, aplikasi mulai dari data kosong.';
      }
    }
    processRecurring(notify: false);
    loaded = true;
    await flush();
    if (fromLegacy && _useFile) {
      // Pindah ke file terenkripsi. Salinan lama baru dikosongkan setelah
      // file baru terbukti bisa dibaca ulang.
      try {
        final check = await DataFile.read();
        if (check != null && check.length > 10) {
          await SecureStore.write(_key, '');
        }
      } catch (_) {}
    }
    notifyListeners();
  }

  bool _useFile = false;
  Timer? _saveTimer;
  Future<void> _saving = Future.value();

  /// Simpan dengan jeda singkat supaya banyak perubahan beruntun cukup sekali
  /// tulis. [flush] memaksa simpan sekarang (dipanggil saat app ke latar).
  void _persist() {
    if (!_storageOk) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), () => unawaited(flush()));
  }

  Future<void> flush() {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (!_storageOk || !loaded) return _saving;
    final json = jsonEncode(toJson());
    _saving = _saving.then((_) => _write(json));
    return _saving;
  }

  Future<void> _write(String json) async {
    try {
      if (_useFile) {
        await DataFile.write(json);
      } else {
        await SecureStore.write(_key, json);
      }
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
        'debts': debts.map((d) => d.toJson()).toList(),
        'goals': goals.map((g) => g.toJson()).toList(),
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
    final dbt = _list(j['debts']).map(Debt.fromJson).toList();
    final gls = _list(j['goals']).map(Goal.fromJson).toList();

    final pend = _list(j['pendingCaptures']).map(CapturedNotif.fromJson).toList();
    final seen = j['seenCaptureKeys'] is List
        ? (j['seenCaptureKeys'] as List).whereType<String>().toList()
        : <String>[];

    accounts = acc;
    categories = cats;
    transactions = txs;
    recurring = rec;
    templates = tpl;
    debts = dbt;
    goals = gls;
    settings = st;
    pendingCaptures = pend;
    _seenCaptureKeys = seen;
  }

  /// Pengaturan keamanan tidak ikut terhapus/tertimpa saat reset atau impor.
  void _keepSecurity(AppSettings old) {
    settings.pin = old.pin;
    settings.biometric = old.biometric;
    settings.secureScreen = old.secureScreen;
    settings.themeMode = old.themeMode;
    settings.accentIndex = old.accentIndex;
    settings.autoBackup = old.autoBackup;
    settings.lastAutoBackup = old.lastAutoBackup;
    settings.displayName = old.displayName;
    settings.avatarPath = old.avatarPath;
    settings.greetingMode = old.greetingMode;
    settings.greetingText = old.greetingText;
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
    _seedEmpty();
    _keepSecurity(old);
    _commit();
  }

  /// Data awal: 3 akun dasar bersaldo 0 + kategori bawaan, tanpa transaksi.
  void _seedEmpty() {
    accounts = _defaultAccounts(demo: false);
    categories = _defaultCategories();
    transactions = [];
    recurring = [];
    templates = [];
    debts = [];
    goals = [];
    settings = AppSettings();
    pendingCaptures = [];
    _seenCaptureKeys = [];
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

  /// Hapus akun beserta transaksi, transaksi berulang, dan template yang
  /// memakainya. null = berhasil.
  String? deleteAccountWithData(String id) {
    if (accounts.length <= 1) return 'Minimal harus ada satu akun.';
    transactions.removeWhere((t) => t.accountId == id || t.toAccountId == id);
    recurring.removeWhere((r) => r.accountId == id || r.toAccountId == id);
    templates.removeWhere((t) => t.accountId == id || t.toAccountId == id);
    accounts.removeWhere((a) => a.id == id);
    _commit();
    return null;
  }

  /// Penyesuaian saldo ala "Modified Bal." Money Manager: dicatat sebagai
  /// pemasukan/pengeluaran supaya riwayat tetap jujur.
  void addBalanceAdjustment(Account a, double diff) {
    if (diff.abs() < 0.0005) return;
    final type = diff > 0 ? TxType.income : TxType.expense;
    transactions.add(Transaction(
      id: newId(),
      title: 'Penyesuaian saldo',
      amount: diff.abs(),
      type: type,
      categoryId: fallbackCategory(type),
      accountId: a.id,
      date: DateTime.now(),
      note: 'Saldo ${a.name} diubah manual',
    ));
    _commit();
  }

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

  /// Ganti isi template yang sudah ada (id dan urutannya tetap).
  void updateTemplate(TxTemplate t) {
    final i = templates.indexWhere((x) => x.id == t.id);
    if (i < 0) {
      templates.add(t);
    } else {
      templates[i] = t;
    }
    _commit();
  }

  void deleteTemplate(String id) {
    templates.removeWhere((t) => t.id == id);
    _commit();
  }

  // ---------------------------------------------------------------- setting

  void setRates(Map<String, double> rates, {DateTime? at}) {
    settings.rates = {...rates, 'IDR': 1};
    settings.ratesUpdatedAt = at ?? DateTime.now();
    _commit();
  }

  /// Umur kurs dalam hari kalau ada akun non-Rupiah dan kurs sudah > 30 hari
  /// (atau belum pernah diisi). Null = tidak perlu diingatkan.
  int? staleRatesDays(DateTime now) {
    if (!accounts.any((a) => a.currency != 'IDR')) return null;
    final at = settings.ratesUpdatedAt;
    if (at == null) return -1;
    final d = now.difference(at).inDays;
    return d > 30 ? d : null;
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

    if (s.notifDebt) {
      for (final d in debts) {
        final due = d.due;
        if (d.settled || due == null) continue;
        final amt = money(d.remaining);
        final what = d.theyOwe
            ? '${d.person} janji bayar'
            : 'Bayar utang ke ${d.person}';
        add(DateTime(due.year, due.month, due.day - 1, 19), '🤝 Besok: $what',
            hide ? 'Cek di Utang & Piutang.' : 'Sisa $amt. Cek di Utang & Piutang.');
        add(DateTime(due.year, due.month, due.day, 9), '🤝 Hari ini: $what',
            hide ? 'Cek di Utang & Piutang.' : 'Sisa $amt.');
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

  /// Catat cepat dari panel notifikasi ("25rb kopi"). Null kalau tidak ada
  /// nominal. Akun: yang disebut di teks, kalau tidak, akun pengeluaran terakhir.
  Transaction? quickExpense(String input) {
    final q = parseQuickInput(input);
    if (q == null) return null;
    final lower = input.toLowerCase();
    String? categoryId;
    for (final e in _categoryHints.entries) {
      final cat = categoryById(e.key);
      if (cat == null || cat.type != TxType.expense) continue;
      if (e.value.any(lower.contains)) {
        categoryId = e.key;
        break;
      }
    }
    categoryId ??= fallbackCategory(TxType.expense);
    String? accountId;
    for (final a in accounts) {
      if (lower.contains(a.name.toLowerCase())) {
        accountId = a.id;
        break;
      }
    }
    if (accountId == null) {
      final recent = transactions
          .where((t) =>
              t.type == TxType.expense && accountById(t.accountId) != null)
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      accountId =
          recent.isNotEmpty ? recent.first.accountId : accounts.first.id;
    }
    final title = q.title.isNotEmpty
        ? q.title
        : (categoryById(categoryId)?.name ?? 'Pengeluaran');
    final t = Transaction(
      id: newId(),
      title: title,
      amount: q.amount,
      type: TxType.expense,
      categoryId: categoryId,
      accountId: accountId,
      date: DateTime.now(),
      note: 'Dicatat dari panel notifikasi',
    );
    transactions.add(t);
    _commit();
    return t;
  }

  /// Akun bawaan untuk transaksi baru: pilihan user, kalau tidak ada akun
  /// paling atas.
  String get defaultAccountId {
    final d = settings.defaultAccountId;
    if (d != null && accountById(d) != null) return d;
    return accounts.first.id;
  }

  /// Saran teks dari yang pernah diketik: yang diawali kata ketikan dulu,
  /// lalu yang memuatnya; urut dari yang paling sering & terbaru.
  List<String> _suggest(Iterable<(String, DateTime)> items, String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return const [];
    final score = <String, (int, DateTime)>{};
    for (final (text, at) in items) {
      final t = text.trim();
      if (t.isEmpty || t.toLowerCase() == query) continue;
      final prev = score[t];
      score[t] = (
        (prev?.$1 ?? 0) + 1,
        prev == null || at.isAfter(prev.$2) ? at : prev.$2,
      );
    }
    final starts = <String>[], contains = <String>[];
    for (final t in score.keys) {
      final l = t.toLowerCase();
      if (l.startsWith(query) || l.split(' ').any((w) => w.startsWith(query))) {
        starts.add(t);
      } else if (l.contains(query)) {
        contains.add(t);
      }
    }
    int byUse(String a, String b) {
      final c = score[b]!.$1.compareTo(score[a]!.$1);
      return c != 0 ? c : score[b]!.$2.compareTo(score[a]!.$2);
    }
    starts.sort(byUse);
    contains.sort(byUse);
    return [...starts, ...contains].take(6).toList();
  }

  List<String> suggestTitles(String q, TxType type) => _suggest(
      transactions
          .where((t) => t.type == type)
          .map((t) => (t.title, t.date)),
      q);

  List<String> suggestNotes(String q) =>
      _suggest(transactions.map((t) => (t.note, t.date)), q);

  Transaction? lastWithTitle(String title, TxType type) {
    Transaction? best;
    for (final t in transactions) {
      if (t.type != type || t.title.trim() != title.trim()) continue;
      if (best == null || t.date.isAfter(best.date)) best = t;
    }
    return best;
  }

  /// Pindahkan akun (ReorderableListView: newIndex dihitung sebelum hapus).
  void moveAccount(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= accounts.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    final a = accounts.removeAt(oldIndex);
    accounts.insert(newIndex.clamp(0, accounts.length), a);
    _commit();
  }

  static const String _pwKey = 'infinity_backup_pw';

  /// Kata sandi backup disimpan terenkripsi (Keystore), terpisah dari data.
  Future<String?> backupPassword() async {
    try {
      final v = await SecureStore.read(_pwKey);
      return (v == null || v.isEmpty) ? null : v;
    } catch (_) {
      return null;
    }
  }

  Future<void> setBackupPassword(String? pw) async {
    try {
      await SecureStore.write(_pwKey, pw ?? '');
    } catch (_) {}
    notifyListeners();
  }

  /// Bytes foto struk yang dipakai transaksi (untuk backup).
  Map<String, List<int>> _photoBytes() {
    final out = <String, List<int>>{};
    for (final t in transactions) {
      for (final p in t.photos) {
        final f = Receipts.file(p);
        if (f != null && f.existsSync()) out[p] = f.readAsBytesSync();
      }
    }
    return out;
  }

  /// Backup ke folder Download. Kalau kata sandi backup sudah diatur, file
  /// .infb terenkripsi (ikut foto); kalau belum, JSON biasa.
  /// [force] = abaikan jadwal mingguan.
  Future<bool> backupToDownloads({bool force = false}) async {
    if (!force) {
      if (!settings.autoBackup || transactions.isEmpty) return false;
      final last = settings.lastAutoBackup;
      if (last != null && DateTime.now().difference(last).inDays < 7) {
        return false;
      }
    }
    final stamp = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
    final pw = await backupPassword();
    bool ok;
    if (pw != null) {
      final bytes = await SecureBackup.encrypt(exportJson(), _photoBytes(), pw);
      ok = await NativeBridge.saveDownloadBytes(
          'infinity-backup-$stamp.infb', bytes, 'application/octet-stream');
    } else {
      ok = await NativeBridge.saveDownload(
          'infinity-backup-$stamp.json', exportJson());
    }
    if (ok) updateSettings((x) => x.lastAutoBackup = DateTime.now());
    return ok;
  }

  /// Backup terenkripsi (.infb, ikut foto) untuk dikirim ke luar HP, mis.
  /// Google Drive. Null kalau kata sandi backup belum diatur.
  Future<Uint8List?> encryptedBackup() async {
    final pw = await backupPassword();
    if (pw == null) return null;
    return SecureBackup.encrypt(exportJson(), _photoBytes(), pw);
  }

  /// Pulihkan dari isi file .infb atau .json. Lempar FormatException.
  Future<int> restoreFromFile(List<int> bytes, {String? password}) async {
    if (SecureBackup.looksEncrypted(bytes)) {
      final (json, photos) = await SecureBackup.decrypt(bytes, password ?? '');
      for (final e in photos.entries) {
        await Receipts.write(e.key, e.value);
      }
      importJson(json);
      return photos.length;
    }
    importJson(utf8.decode(bytes));
    return 0;
  }

  TxDraft draftFromCapture(CapturedNotif c) {
    final p = parseReceipt(c.fullText, this);
    final type = p.type ?? TxType.expense;
    final target =
        p.accountId ?? accountForPackage(c.pkg) ?? accounts.first.id;
    if (p.isTopUp) {
      // Isi saldo e-wallet: uang pindah dari rekening ke e-wallet.
      return TxDraft(
        type: TxType.transfer,
        title: p.title ?? 'Isi saldo ${appLabelForPackage(c.pkg)}',
        amount: p.amount ?? 0,
        accountId: topUpSource(target),
        toAccountId: target,
        date: c.time,
        note: 'Dari notifikasi ${appLabelForPackage(c.pkg)}',
      );
    }
    return TxDraft(
      type: type,
      title: p.title ?? '',
      amount: p.amount ?? 0,
      categoryId: p.categoryId ?? fallbackCategory(type),
      accountId: target,
      date: c.time,
      note: 'Dari notifikasi ${appLabelForPackage(c.pkg)}',
    );
  }

  /// Rekening sumber isi saldo: akun default kalau rekening bank, kalau
  /// tidak, rekening bank pertama, kalau tidak ada, akun lain mana saja.
  String topUpSource(String target) {
    final def = accountById(defaultAccountId ?? '');
    if (def != null && def.id != target && def.type == AccountType.bank) {
      return def.id;
    }
    for (final a in accounts) {
      if (a.id != target && a.type == AccountType.bank) return a.id;
    }
    for (final a in accounts) {
      if (a.id != target) return a.id;
    }
    return target;
  }

  /// Simpan saldo yang disebut notifikasi kalau lebih baru dari yang ada.
  void _rememberReportedBalance(String accountId, double amount, DateTime at) {
    final prev = settings.reportedBalance[accountId];
    final prevAt =
        prev == null ? null : DateTime.tryParse(prev.split('|').last);
    if (prevAt != null && !at.isAfter(prevAt)) return;
    settings.reportedBalance = {
      ...settings.reportedBalance,
      accountId: '${amount.toStringAsFixed(2)}|${at.toIso8601String()}',
    };
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
      final accountId = p.accountId ?? accountForPackage(pkg);
      if (accountId != null && p.balanceAfter != null) {
        _rememberReportedBalance(accountId, p.balanceAfter!, time);
      }
      final amount = p.amount;
      if (amount == null) continue;
      final type = p.type ?? TxType.expense;
      final categoryId = p.categoryId ?? fallbackCategory(type);
      final looksDuplicate = accountId != null &&
          transactions.any((t) =>
              t.accountId == accountId &&
              (t.amount - amount).abs() < 0.5 &&
              t.date.difference(time).inMinutes.abs() <= 10);

      final setAt = accountId == null
          ? null
          : DateTime.tryParse(settings.balanceSetAt[accountId] ?? '');
      final beforeManualBalance = setAt != null && time.isBefore(setAt);
      if (settings.captureMode == 'auto' &&
          accountId != null &&
          categoryId != null &&
          !looksDuplicate &&
          !beforeManualBalance &&
          !p.isTopUp) {
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
          : 'Sisa anggaran Rp ${compactMoney(remaining)} ($pct%)';
    }
    return {
      'w_month': DateFormat('MMMM yyyy', 'id_ID').format(now),
      'w_balance': hide ? 'Rp ••••••' : money(netWorthIDR),
      // Ringkas (mis. "Rp 7,5 jt") supaya muat di widget kecil.
      'w_income': hide ? 'Masuk ••••' : 'Masuk Rp ${compactMoney(income)}',
      'w_expense': hide ? 'Keluar ••••' : 'Keluar Rp ${compactMoney(expense)}',
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
