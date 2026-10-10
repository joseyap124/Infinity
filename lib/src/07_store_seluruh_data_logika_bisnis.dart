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
  List<TxEvent> events = [];
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
  Future<bool> _saving = Future.value(true);
  bool _dirty = false;

  /// Hasil simpan terakhir; false kalau gagal menulis ke penyimpanan.
  bool lastSaveOk = true;

  /// Simpan segera setelah perubahan (di akhir event yang sedang berjalan,
  /// jadi banyak perubahan beruntun tetap cukup sekali tulis). Sebelum v3.2
  /// ada jeda 0,4 detik; kalau app ditutup paksa di jeda itu (mis. saat
  /// update), perubahan terakhir bisa hilang.
  void _persist() {
    if (!_storageOk) return;
    _dirty = true;
    _saveTimer ??= Timer(Duration.zero, () => unawaited(flush()));
  }

  /// Tulis semua perubahan yang belum tersimpan. Selesai = sudah di disk.
  /// Mengembalikan true kalau tulisan terakhir berhasil.
  Future<bool> flush() {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (!_storageOk || !loaded) return _saving;
    _dirty = true;
    _saving = _saving.then((_) async {
      var ok = lastSaveOk;
      // Tulis ulang selama masih ada perubahan baru selama menulis.
      while (_dirty) {
        _dirty = false;
        ok = await _write(jsonEncode(toJson()));
      }
      lastSaveOk = ok;
      return ok;
    });
    return _saving;
  }

  Future<bool> _write(String json) async {
    try {
      if (_useFile) {
        await DataFile.write(json);
      } else {
        await SecureStore.write(_key, json);
      }
      return true;
    } catch (e, st) {
      ErrorLog.record(e, st, source: 'simpan data');
      return false;
    }
  }

  /// Naik setiap data berubah; dipakai untuk cache saldo.
  int _rev = 0;
  Map<String, double>? _balCache;
  Object? _balSig;

  void _commit() {
    _rev++;
    gPeriodStartDay = settings.periodStartDay;
    notifyListeners();
    _persist();
  }

  /// Saldo semua akun dalam satu kali jalan (bukan satu jalan per akun).
  /// Dihitung ulang hanya kalau data berubah.
  Map<String, double> _balances() {
    final sig = (
      _rev,
      identityHashCode(transactions),
      transactions.length,
      identityHashCode(accounts),
      accounts.length,
    );
    final cached = _balCache;
    if (cached != null && _balSig == sig) return cached;
    final m = <String, double>{for (final a in accounts) a.id: a.initialBalance};
    for (final t in transactions) {
      switch (t.type) {
        case TxType.income:
          if (m.containsKey(t.accountId)) m[t.accountId] = m[t.accountId]! + t.amount;
        case TxType.expense:
          if (m.containsKey(t.accountId)) m[t.accountId] = m[t.accountId]! - t.amount;
        case TxType.transfer:
          if (m.containsKey(t.accountId)) m[t.accountId] = m[t.accountId]! - t.amount;
          final to = t.toAccountId;
          if (to != null && m.containsKey(to)) m[to] = m[to]! + t.receivedAmount;
      }
    }
    _balCache = m;
    _balSig = sig;
    return m;
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
        'events': events.map((e) => e.toJson()).toList(),
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
    final evs = _list(j['events']).map(TxEvent.fromJson).toList();

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
    events = evs;
    settings = st;
    gPeriodStartDay = st.periodStartDay;
    pendingCaptures = pend;
    _seenCaptureKeys = seen;
  }

  /// Yang selalu tetap milik HP ini, juga saat impor backup: keamanan (PIN,
  /// biometrik, layar aman), catatan backup otomatis, dan foto profil (file
  /// fotonya hanya ada di HP ini, tidak ikut backup).
  void _keepSecurity(AppSettings old) {
    settings.pin = old.pin;
    settings.biometric = old.biometric;
    settings.secureScreen = old.secureScreen;
    settings.autoBackup = old.autoBackup;
    settings.lastAutoBackup = old.lastAutoBackup;
    settings.lastBackupSig = old.lastBackupSig;
    settings.lastDriveSave = old.lastDriveSave;
    settings.droppedCaptures = old.droppedCaptures;
    settings.avatarPath = old.avatarPath;
  }

  /// Tampilan dan profil. Dipertahankan saat reset/hapus semua, tapi saat impor
  /// diambil dari file backup (lihat [_keepMissingAppearance]).
  void _keepAppearance(AppSettings old) {
    settings.themeMode = old.themeMode;
    settings.textScale = old.textScale;
    settings.homeCards = old.homeCards;
    settings.accentIndex = old.accentIndex;
    settings.displayName = old.displayName;
    settings.greetingMode = old.greetingMode;
    settings.greetingText = old.greetingText;
  }

  /// Backup lama (sebelum v3.5.3) tidak punya semua kunci tampilan. Yang tidak
  /// ada di file tetap memakai nilai di HP ini, bukan nilai bawaan.
  void _keepMissingAppearance(AppSettings old, Object? fileSettings) {
    final has = fileSettings is Map ? fileSettings : const {};
    if (!has.containsKey('themeMode')) settings.themeMode = old.themeMode;
    if (!has.containsKey('textScale')) settings.textScale = old.textScale;
    if (!has.containsKey('homeCards')) settings.homeCards = old.homeCards;
    if (!has.containsKey('accentIndex')) settings.accentIndex = old.accentIndex;
    if (!has.containsKey('displayName')) settings.displayName = old.displayName;
    if (!has.containsKey('greetingMode')) {
      settings.greetingMode = old.greetingMode;
      settings.greetingText = old.greetingText;
    }
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
    _keepMissingAppearance(old, decoded['settings']);
    pendingCaptures = pend;
    _seenCaptureKeys = seen;
    processRecurring(notify: false);
    _commit();
  }

  void resetDemo() {
    final old = settings;
    _seedDemo();
    _keepSecurity(old);
    _keepAppearance(old);
    processRecurring(notify: false);
    _commit();
  }

  void clearAll() {
    final old = settings;
    _seedEmpty();
    _keepSecurity(old);
    _keepAppearance(old);
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
    events = [];
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
    if (t.splits.isNotEmpty) {
      return t.splits
          .map((s) => categoryById(s.categoryId)?.name ?? 'Tanpa kategori')
          .join(' + ');
    }
    final c = categoryById(t.categoryId);
    if (c == null) return 'Tanpa kategori';
    final parent = categoryById(c.parentId);
    return parent == null ? c.name : '${parent.name} › ${c.name}';
  }

  // ---------------------------------------------------------------- saldo

  double balanceOf(String accountId, {String? excludeTxId}) {
    if (excludeTxId == null) return _balances()[accountId] ?? 0;
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

  /// Bagian per kategori dalam Rupiah. Transaksi biasa: satu bagian.
  /// Transaksi yang dibagi: satu bagian per kategori; selisih pembulatan
  /// masuk ke kategori utama.
  List<(String?, double)> categoryParts(Transaction t) {
    final total = amountIDR(t);
    if (t.splits.isEmpty) return [(t.categoryId, total)];
    final rate = t.amount == 0 ? 0.0 : total / t.amount;
    final out = <(String?, double)>[];
    var rest = t.amount;
    for (final s in t.splits) {
      out.add((s.categoryId, s.amount * rate));
      rest -= s.amount;
    }
    if (rest.abs() > 0.004) out.add((t.categoryId, rest * rate));
    return out;
  }

  double sumIDR(TxType type, DateTimeRange r, {String? topCategory}) {
    var s = 0.0;
    for (final t in transactions) {
      if (t.type != type || !inRange(t.date, r)) continue;
      if (topCategory != null) {
        for (final (cid, v) in categoryParts(t)) {
          if (cid != null && topCategoryId(cid) == topCategory) s += v;
        }
        continue;
      }
      s += amountIDR(t);
    }
    return s;
  }

  Map<String, double> byTopCategory(TxType type, DateTimeRange r) {
    final m = <String, double>{};
    for (final t in transactions) {
      if (t.type != type || !inRange(t.date, r)) continue;
      for (final (cid, v) in categoryParts(t)) {
        final key = cid == null ? '_none' : topCategoryId(cid);
        m[key] = (m[key] ?? 0) + v;
      }
    }
    return m;
  }

  Map<String, double> bySubCategory(String topId, TxType type, DateTimeRange r) {
    final m = <String, double>{};
    for (final t in transactions) {
      if (t.type != type || !inRange(t.date, r)) continue;
      for (final (cid, v) in categoryParts(t)) {
        if (cid == null || topCategoryId(cid) != topId) continue;
        m[cid] = (m[cid] ?? 0) + v;
      }
    }
    return m;
  }

  /// Nominal dari teks pencarian: "50rb" = 50000, "1,5jt" = 1500000,
  /// "25.000" = 25000. Null kalau bukan angka.
  static double? parseSearchAmount(String text) {
    final m = RegExp(r'^(\d[\d.,]*)(rb|ribu|k|jt|juta)?$').firstMatch(text);
    if (m == null) return null;
    final num = m.group(1)!;
    final suf = m.group(2);
    double? v;
    if (suf == null) {
      v = double.tryParse(num.replaceAll('.', '').replaceAll(',', ''));
    } else {
      v = double.tryParse(num.replaceAll('.', '').replaceAll(',', '.'));
      if (v != null) v *= (suf == 'jt' || suf == 'juta') ? 1000000 : 1000;
    }
    return v;
  }

  /// Cari transaksi. Semua kata harus cocok (judul, catatan, kategori, akun,
  /// atau nominal). Bisa pakai filter nominal: ">50rb", "<20000", ">=1jt".
  /// [type] dan [range] menyaring jenis dan tanggal.
  List<Transaction> search(String query,
      {TxType? type, DateTimeRange? range}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    double? minA, maxA;
    var minStrict = false, maxStrict = false;
    final words = <String>[];
    for (final tok in q.split(RegExp(r'\s+'))) {
      if (tok.isEmpty) continue;
      final m = RegExp(r'^(>=|<=|>|<)(.+)$').firstMatch(tok);
      final v = m == null ? null : parseSearchAmount(m.group(2)!);
      if (m != null && v != null) {
        final op = m.group(1)!;
        if (op.startsWith('>')) {
          minA = v;
          minStrict = op == '>';
        } else {
          maxA = v;
          maxStrict = op == '<';
        }
        continue;
      }
      words.add(tok);
    }
    bool wordMatches(Transaction t, String w) {
      if (t.title.toLowerCase().contains(w)) return true;
      if (t.note.toLowerCase().contains(w)) return true;
      if (categoryLabel(t).toLowerCase().contains(w)) return true;
      if (accountName(t.accountId).toLowerCase().contains(w)) return true;
      if (t.toAccountId != null &&
          accountName(t.toAccountId).toLowerCase().contains(w)) {
        return true;
      }
      final hasSuffix = RegExp(r'(rb|ribu|k|jt|juta)$').hasMatch(w);
      final v = parseSearchAmount(w);
      if (v != null && hasSuffix) return (t.amount - v).abs() < 0.5;
      final digits = w.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length >= 3 &&
          digits.length == w.replaceAll(RegExp(r'[.,]'), '').length &&
          t.amount.toStringAsFixed(0).contains(digits)) {
        return true;
      }
      return false;
    }

    return transactions.where((t) {
      if (type != null && t.type != type) return false;
      if (range != null && !inRange(t.date, range)) return false;
      final a = amountIDR(t);
      final lo = minA, hi = maxA;
      if (lo != null && (minStrict ? a <= lo : a < lo)) return false;
      if (hi != null && (maxStrict ? a >= hi : a > hi)) return false;
      for (final w in words) {
        if (!wordMatches(t, w)) return false;
      }
      return true;
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
    final used = transactions
        .where((t) =>
            t.categoryId == id || t.splits.any((s) => s.categoryId == id))
        .length;
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

  /// Kunci judul untuk mencocokkan kebiasaan: huruf kecil, tanpa angka dan
  /// tanda baca ("Kopi Kenangan #12" = "kopi kenangan").
  static String titleKey(String t) => t
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  Object? _learnSig;
  Map<String, List<(DateTime, String)>> _learnIdx = {};

  /// Kategori yang biasa dipakai untuk judul ini: dipakai minimal 2 kali dan
  /// minimal 60% dari 10 transaksi terakhir berjudul sama. Null kalau belum
  /// ada kebiasaan yang jelas.
  String? learnedCategory(String title, TxType type) {
    if (type == TxType.transfer) return null;
    final k = titleKey(title);
    if (k.length < 3) return null;
    final sig = (_rev, identityHashCode(transactions), transactions.length);
    if (sig != _learnSig) {
      final idx = <String, List<(DateTime, String)>>{};
      for (final t in transactions) {
        final c = t.categoryId;
        if (t.type == TxType.transfer || c == null || t.splits.isNotEmpty) {
          continue;
        }
        final tk = titleKey(t.title);
        if (tk.length < 3) continue;
        (idx['${t.type.name}|$tk'] ??= []).add((t.date, c));
      }
      _learnIdx = idx;
      _learnSig = sig;
    }
    final list = _learnIdx['${type.name}|$k'];
    if (list == null || list.length < 2) return null;
    final recent = [...list]..sort((a, b) => b.$1.compareTo(a.$1));
    final top = recent.take(10).where((e) => categoryById(e.$2) != null);
    final counts = <String, int>{};
    for (final e in top) {
      counts[e.$2] = (counts[e.$2] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    final best = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final n = top.length;
    if (best.value < 2 || best.value / n < 0.6) return null;
    return best.key;
  }

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

  /// Sidik isi data (tanpa catatan waktu backup) untuk mendeteksi apakah ada
  /// perubahan sejak backup terakhir. FNV-1a 32-bit, cukup untuk keperluan ini.
  String backupSignature() {
    final j = toJson(includeSecrets: false)..remove('exportedAt');
    final st = j['settings'];
    if (st is Map) {
      final m = Map<String, dynamic>.from(st)
        ..remove('lastAutoBackup')
        ..remove('lastBackupSig')
        ..remove('lastDriveSave')
        ..remove('dismissedInsights');
      j['settings'] = m;
    }
    final text = jsonEncode(j);
    var h = 0x811c9dc5;
    for (final c in text.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return '${text.length}:${h.toRadixString(16)}';
  }

  /// Catat bahwa salinan backup sudah disimpan ke luar HP.
  void markDriveSaved([DateTime? at]) =>
      updateSettings((x) => x.lastDriveSave = at ?? DateTime.now());

  /// Backup ke folder Download. Kalau kata sandi backup sudah diatur, file
  /// .infb terenkripsi (ikut foto); kalau belum, JSON biasa.
  /// [force] = abaikan jadwal mingguan.
  Future<bool> backupToDownloads({bool force = false}) async {
    final sig = backupSignature();
    if (!force) {
      if (!settings.autoBackup || transactions.isEmpty) return false;
      final last = settings.lastAutoBackup;
      if (last != null && DateTime.now().difference(last).inHours < 20) {
        return false;
      }
      // Tidak ada perubahan sejak backup terakhir: tidak perlu file baru.
      if (last != null && sig == settings.lastBackupSig) return false;
    }
    final stamp = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
    final pw = await backupPassword();
    final json = exportJson();
    bool ok;
    if (pw != null) {
      final bytes = await SecureBackup.encrypt(json, _photoBytes(), pw);
      // Pastikan backup bisa dibuka lagi sebelum disimpan.
      if (!await verifyBackupBytes(bytes, json, password: pw)) return false;
      ok = await NativeBridge.saveDownloadBytes(
          'infinity-backup-$stamp.infb', bytes, 'application/octet-stream');
    } else {
      if (!await verifyBackupBytes(utf8.encode(json), json)) return false;
      ok = await NativeBridge.saveDownload('infinity-backup-$stamp.json', json);
    }
    if (ok) {
      updateSettings((x) {
        x.lastAutoBackup = DateTime.now();
        x.lastBackupSig = sig;
      });
      await NativeBridge.pruneBackups(kKeepBackups);
    }
    return ok;
  }

  /// Ada data yang berarti di HP ini (bukan app yang masih kosong).
  bool get hasData =>
      transactions.isNotEmpty || goals.isNotEmpty || debts.isNotEmpty;

  /// Simpan data sekarang ke Download/Infinity sebelum dipulihkan dari backup
  /// lain. Namanya khusus ("infinity-sebelum-pulih-...") supaya tidak ikut
  /// dihapus rotasi backup otomatis. Mengembalikan nama file, atau null kalau
  /// gagal.
  Future<String?> backupBeforeRestore() async {
    try {
      final stamp = DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now());
      final pw = await backupPassword();
      final json = exportJson();
      if (pw != null) {
        final name = 'infinity-sebelum-pulih-$stamp.infb';
        final bytes = await SecureBackup.encrypt(json, _photoBytes(), pw);
        final ok = await NativeBridge.saveDownloadBytes(
            name, bytes, 'application/octet-stream');
        return ok ? name : null;
      }
      final name = 'infinity-sebelum-pulih-$stamp.json';
      final ok = await NativeBridge.saveDownload(name, json);
      return ok ? name : null;
    } catch (e, st) {
      ErrorLog.record(e, st, source: 'backup-sebelum-pulih');
      return null;
    }
  }

  /// Backup terenkripsi (.infb, ikut foto) untuk dikirim ke luar HP, mis.
  /// Google Drive. Null kalau kata sandi backup belum diatur.
  Future<Uint8List?> encryptedBackup() async {
    final pw = await backupPassword();
    if (pw == null) return null;
    return SecureBackup.encrypt(exportJson(), _photoBytes(), pw);
  }

  /// Cek backup bisa dibuka dan isinya sama dengan data sekarang.
  Future<bool> verifyBackupBytes(List<int> bytes, String expectedJson,
      {String? password}) async {
    try {
      String json;
      if (SecureBackup.looksEncrypted(bytes)) {
        final (j, _) = await SecureBackup.decrypt(bytes, password ?? '');
        json = j;
      } else {
        json = utf8.decode(bytes);
      }
      if (json != expectedJson) throw const FormatException('isi berbeda');
      final decoded = jsonDecode(json);
      if (decoded is! Map || decoded['accounts'] is! List) {
        throw const FormatException('format salah');
      }
      return true;
    } catch (e, st) {
      ErrorLog.record(e, st, source: 'backup-verify');
      return false;
    }
  }

  /// Ringkasan isi backup tanpa mengubah data apa pun. Lempar FormatException.
  static BackupInfo peekJson(String raw) {
    Object? d;
    try {
      d = jsonDecode(raw.trim());
    } on FormatException {
      throw const FormatException('Bukan data backup Infinity.');
    }
    if (d is! Map || d['accounts'] is! List) {
      throw const FormatException('Bukan data backup Infinity.');
    }
    int n(Object? v) => v is List ? v.length : 0;
    DateTime? last;
    final txs = d['transactions'];
    if (txs is List) {
      for (final t in txs) {
        if (t is! Map) continue;
        final dt = DateTime.tryParse('${t['date']}');
        if (dt != null && (last == null || dt.isAfter(last))) last = dt;
      }
    }
    return BackupInfo(
      exportedAt: DateTime.tryParse('${d['exportedAt']}'),
      accounts: n(d['accounts']),
      transactions: n(txs),
      lastTransaction: last,
      recurring: n(d['recurring']),
      templates: n(d['templates']),
      debts: n(d['debts']),
      goals: n(d['goals']),
      events: n(d['events']),
    );
  }

  /// Sama seperti [peekJson] untuk isi file .infb atau .json.
  Future<BackupInfo> peekFile(List<int> bytes, {String? password}) async {
    if (SecureBackup.looksEncrypted(bytes)) {
      final (json, _) = await SecureBackup.decrypt(bytes, password ?? '');
      return peekJson(json);
    }
    return peekJson(utf8.decode(bytes));
  }

  /// Ringkasan data yang sedang ada di HP ini, untuk dibandingkan.
  BackupInfo currentInfo() {
    DateTime? last;
    for (final t in transactions) {
      if (last == null || t.date.isAfter(last)) last = t.date;
    }
    return BackupInfo(
      accounts: accounts.length,
      transactions: transactions.length,
      lastTransaction: last,
      recurring: recurring.length,
      templates: templates.length,
      debts: debts.length,
      goals: goals.length,
      events: events.length,
    );
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
      categoryId: learnedCategory(p.title ?? '', type) ??
          p.categoryId ??
          fallbackCategory(type),
      accountId: target,
      date: c.time,
      note: 'Dari notifikasi ${appLabelForPackage(c.pkg)}',
    );
  }

  /// Rekening sumber isi saldo: akun default kalau rekening bank, kalau
  /// tidak, rekening bank pertama, kalau tidak ada, akun lain mana saja.
  String topUpSource(String target) {
    final def = accountById(defaultAccountId);
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
      final categoryId = learnedCategory(p.title ?? '', type) ??
          p.categoryId ??
          fallbackCategory(type);
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
    if (pendingCaptures.length > kMaxPendingCaptures) {
      final drop = pendingCaptures.length - kMaxPendingCaptures;
      settings.droppedCaptures += drop;
      pendingCaptures = pendingCaptures.sublist(drop);
    }
    if (changed) _commit();
    return auto;
  }

  /// Data teks untuk widget layar utama.
  Map<String, String> widgetData() {
    final now = DateTime.now();
    final s = settings;
    final hide = s.hideBalance;
    final month = currentPeriod(now);
    final income = sumIDR(TxType.income, month);
    final expense = sumIDR(TxType.expense, month);
    // Baris bawah: sisa aman dibelanjakan hari ini (ditandai tanggal, karena
    // widget tidak diperbarui tengah malam kalau app tidak dibuka).
    final day = DateFormat('d MMM', 'id_ID').format(now);
    final safe = safeToSpend(now);
    final left = safe.leftToday;
    String line = left >= 0
        ? 'Aman $day: ${hide ? '••••' : 'Rp ${compactMoney(left)}'}'
        : 'Lewat $day: ${hide ? '••••' : 'Rp ${compactMoney(-left)}'}';
    if (s.globalBudget > 0) {
      final spent = sumIDR(TxType.expense, s.budgetPeriod.range(now));
      final remaining = s.globalBudget - spent;
      final pct = (remaining / s.globalBudget * 100).clamp(0, 100).round();
      line = '$line · anggaran $pct%';
    }
    final label = periodLabelOf(now);
    return {
      'w_month': gPeriodStartDay > 1
          ? DateFormat('MMM yyyy', 'id_ID').format(label)
          : DateFormat('MMMM yyyy', 'id_ID').format(label),
      'w_balance': hide ? 'Rp ••••••' : money(netWorthIDR),
      // Ringkas (mis. "Rp 7,5 jt") supaya muat di widget kecil.
      'w_income': hide ? 'Masuk ••••' : 'Masuk Rp ${compactMoney(income)}',
      'w_expense': hide ? 'Keluar ••••' : 'Keluar Rp ${compactMoney(expense)}',
      'w_budget': line,
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

/// Isi sebuah backup (atau data sekarang) dalam angka, untuk pratinjau
/// sebelum memulihkan.
class BackupInfo {
  const BackupInfo({
    this.exportedAt,
    this.accounts = 0,
    this.transactions = 0,
    this.lastTransaction,
    this.recurring = 0,
    this.templates = 0,
    this.debts = 0,
    this.goals = 0,
    this.events = 0,
  });

  final DateTime? exportedAt;
  final int accounts;
  final int transactions;
  final DateTime? lastTransaction;
  final int recurring;
  final int templates;
  final int debts;
  final int goals;
  final int events;

  /// Satu baris angka: "3 kantong, 120 transaksi, 2 target, ...".
  String counts() => [
        '$accounts kantong',
        '$transactions transaksi',
        '$goals target',
        '$debts utang/piutang',
        '$recurring berulang',
        '$templates template',
        '$events acara',
      ].join(', ');
}
