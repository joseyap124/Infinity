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
    this.excludeSafe = false,
    this.reserve = 0,
  });

  final String id;
  final String name;
  final AccountType type;

  /// Tidak ikut dihitung di "Aman dibelanjakan" (mis. tabungan, dana darurat).
  final bool excludeSafe;

  /// Kalau > 0 (dan [excludeSafe] menyala): hanya sebesar ini yang disisihkan
  /// dari "Aman dibelanjakan", sisanya boleh dipakai. 0 = seluruh saldo
  /// disisihkan. Dalam mata uang akun.
  final double reserve;

  /// Akun untuk menyimpan, bukan belanja harian: bertipe Tabungan, Dana
  /// Darurat, atau Investasi, atau akun yang ditandai "jangan hitung di Aman dibelanjakan". Transfer ke akun
  /// seperti ini dihitung sebagai Tabungan di statistik.
  bool get isSavings => (excludeSafe && reserve <= 0) || type.isSavingsType;

  /// Bagian saldo [balance] yang disisihkan dari "Aman dibelanjakan"
  /// (mata uang akun). Saldo minus tidak pernah disisihkan.
  double heldOf(double balance) {
    if (!excludeSafe || balance <= 0) return 0;
    if (reserve <= 0) return balance;
    return reserve < balance ? reserve : balance;
  }
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
        if (excludeSafe) 'excludeSafe': true,
        if (excludeSafe && reserve > 0) 'reserve': reserve,
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
        excludeSafe: j['excludeSafe'] == true,
        reserve: _d(j['reserve']),
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

  /// Kunci gambar ikon kartun (sama dengan [icon]).
  String get art => icon;
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

/// Satu bagian transaksi yang dibagi ke beberapa kategori (v3.4).
/// [amount] dalam mata uang akun transaksi.
class TxSplit {
  const TxSplit(this.categoryId, this.amount);
  final String categoryId;
  final double amount;

  Map<String, dynamic> toJson() => {'c': categoryId, 'a': amount};

  static TxSplit? fromJson(Object? j) {
    if (j is! Map) return null;
    final c = _s(j['c']);
    if (c == null) return null;
    return TxSplit(c, _d(j['a']));
  }
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
    this.eventId,
    this.splits = const [],
    this.outside = false,
  });

  final String id;
  final String title;

  /// Pengeluaran yang disengaja dan tidak dihitung ke jatah harian hari itu
  /// (mis. self reward). Tetap masuk laporan dan sisa anggaran.
  final bool outside;

  /// Kalau tidak kosong: nominal dibagi ke beberapa kategori. [categoryId]
  /// berisi kategori bagian terbesar (untuk ikon dan tampilan ringkas).
  final List<TxSplit> splits;

  /// Acara/tag (mis. "Trip Bali") untuk menjumlah pengeluaran satu acara.
  final String? eventId;

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
        if (eventId != null) 'eventId': eventId,
        if (splits.isNotEmpty) 'splits': splits.map((s) => s.toJson()).toList(),
        if (outside) 'outside': true,
      };

  /// Salinan dengan beberapa kolom diganti.
  Transaction copyWith(
          {String? categoryId, List<TxSplit>? splits, String? accountId}) =>
      Transaction(
        id: id,
        title: title,
        amount: amount,
        toAmount: toAmount,
        type: type,
        categoryId: categoryId ?? this.categoryId,
        accountId: accountId ?? this.accountId,
        toAccountId: toAccountId,
        date: date,
        note: note,
        recurringId: recurringId,
        photos: photos,
        eventId: eventId,
        splits: splits ?? this.splits,
        outside: outside,
      );

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
        eventId: _s(j['eventId']),
        splits: j['splits'] is List
            ? List.unmodifiable((j['splits'] as List)
                .map(TxSplit.fromJson)
                .whereType<TxSplit>())
            : const [],
        outside: j['outside'] == true,
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

  /// Salinan dengan kategori diganti (dipakai saat kategori digabung).
  RecurringRule withCategory(String? categoryId) => RecurringRule(
        id: id,
        title: title,
        amount: amount,
        toAmount: toAmount,
        type: type,
        categoryId: categoryId,
        accountId: accountId,
        toAccountId: toAccountId,
        note: note,
        frequency: frequency,
        start: start,
        generated: generated,
        active: active,
      );

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

  /// Salinan dengan kategori diganti (dipakai saat kategori digabung).
  TxTemplate withCategory(String? categoryId) => TxTemplate(
        id: id,
        title: title,
        amount: amount,
        toAmount: toAmount,
        type: type,
        categoryId: categoryId,
        accountId: accountId,
        toAccountId: toAccountId,
        note: note,
      );

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
    this.eventId,
    List<TxSplit>? splits,
    this.outside = false,
  })  : date = date ?? DateTime.now(),
        photos = photos ?? [],
        splits = splits ?? [];

  /// Bagian per kategori (kosong = satu kategori biasa).
  List<TxSplit> splits;

  /// Di luar jatah harian (hanya berlaku untuk pengeluaran).
  bool outside;

  /// Acara/tag transaksi (boleh kosong).
  String? eventId;

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
        eventId: t.eventId,
        splits: [...t.splits],
        outside: t.outside,
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
        eventId: eventId,
        splits: type == TxType.transfer || splits.length < 2
            ? const []
            : List.unmodifiable(splits),
        outside: type == TxType.expense && outside,
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

/// Fitur yang bisa dimatikan di Pengaturan > Fitur (id -> menyala secara bawaan).
/// Yang dimatikan disembunyikan dan tidak ikut dihitung; datanya tetap tersimpan.
const Map<String, bool> kFeatureDefaults = {
  'cicilan': true,
  'utang': true,
  'target': true,
  'patungan': true,
  'acara': true,
  'tunda': false,
};

class AppSettings {
  BudgetPeriod budgetPeriod = BudgetPeriod.monthly;

  /// Tanggal mulai "bulan" keuangan (1 = bulan kalender; 25 = mulai tanggal
  /// gajian 25). Maks. 28 supaya ada di setiap bulan.
  int periodStartDay = 1;
  double globalBudget = 0;

  /// Anggaran khusus (amplop) di dalam [globalBudget], per periode anggaran.
  /// Belanja "di luar jatah harian" memakai ini dulu dan tidak menyentuh jatah
  /// harian. 0 = tidak dipakai.
  double specialBudget = 0;
  Map<String, double> categoryBudgets = {};
  Map<String, double> rates = Map.of(kDefaultRates);
  String? pin;
  bool hideBalance = false;

  /// Kartu Maskot dan Ritme di bawah kartu utama Beranda (v5.11).
  bool homeMaskot = true;
  bool homeRitme = true;

  /// Minggu (awal minggu lalu, "yyyy-MM-dd") yang tinjauannya sudah dibuka
  /// atau ditutup, supaya kartu di Beranda tidak muncul lagi (v5.14).
  String? weekSeen;

  /// Kartu Tinjauan mingguan sudah ditawarkan sekali ke daftar kartu Beranda
  /// yang tersimpan (v5.14). Bawaan true: pengaturan baru sudah memuatnya.
  bool weekOffered = true;

  /// 'system' | 'light' | 'dark'
  String themeMode = 'system';

  /// Ukuran huruf di dalam app (dikali ukuran huruf HP): 1.0 / 1.15 / 1.3.
  double textScale = 1.0;

  /// Kartu yang tampil di Beranda, berurutan (lihat [kHomeCards]).
  List<String> homeCards = [...kDefaultHomeCards];

  /// Golongan pengeluaran yang diubah user: id kategori -> nama SpendKind.
  Map<String, String> spendKinds = {};
  int accentIndex = 0;

  /// Paket gaya: 'classic' | 'malam' | 'kuning' | 'merah' (lihat [kStylePacks]).
  String stylePack = 'classic';

  /// Motif latar (kabut, awan, lampu) di Beranda untuk gaya selain Klasik.
  bool packMotif = true;

  /// Maskot di Beranda: 'classic' | 'owl' | 'fox' | 'crow' | 'custom'.
  String mascotSkin = 'classic';

  /// Kalimat maskot memakai nada paket gaya (Malam Biru tenang, Kuning Ceria
  /// ceria, Merah Kafe tegas). Paket Klasik tetap netral.
  bool packTone = true;

  /// Gambar maskot pilihan sendiri (dipakai kalau [mascotSkin] == 'custom').
  String? mascotCustomPath;

  /// Pilihan fitur yang berbeda dari bawaannya (lihat [kFeatureDefaults]).
  Map<String, bool> features = {};

  bool feature(String id) => features[id] ?? (kFeatureDefaults[id] ?? true);

  /// Animasi pembuka: 'once' (sekali saja) | 'always' (tiap buka) | 'off'.
  String splashMode = 'once';

  /// Bentuk grafik kategori di Statistik: 'donut' (cincin) atau 'pie' (lingkaran penuh).
  String chartShape = 'donut';

  /// Gaya ikon kategori: 'cartoon' | 'flat' | 'classic' | 'mono'.
  String iconStyle = 'cartoon';

  /// Bahasa tampilan: 'id' | 'en' | 'zh'.
  String lang = 'id';

  /// Ikon kategori bawaan sudah dipindah ke ikon kartun (sekali saja).
  bool iconsV37 = false;

  /// Kategori yang dipin ke bagian "Sering dipakai" di layar catat (urut),
  /// dan yang disembunyikan dari sana.
  List<String> pinnedCats = [];
  List<String> hiddenFreq = [];

  /// Akun yang otomatis terpilih saat mencatat transaksi baru.
  String? defaultAccountId;

  /// Kapan saldo tiap akun terakhir diubah manual (id akun -> waktu).
  /// Notifikasi bank yang lebih lama dari waktu ini tidak dicatat otomatis,
  /// karena saldo yang diketik user sudah termasuk transaksi itu.
  Map<String, String> balanceSetAt = {};

  /// Langganan terdeteksi yang ditolak user (kunci judul).
  List<String> dismissedSubs = [];

  /// Nama paket app yang notifikasinya tidak ditangkap lagi (dipilih user dari
  /// kartu "Dari Notifikasi"). Hanya untuk app yang bukan bank/e-wallet dikenal.
  List<String> ignoredCapturePkgs = [];

  /// Berapa kali petunjuk "Catat cepat" sudah ditampilkan (v7.0.0).
  int quickHintSeen = 0;

  /// Insight yang ditutup (id -> yyyy-MM-dd). Kartu yang terikat satu kejadian
  /// tetap tersembunyi; yang lain muncul lagi besok (lihat [insightHidden]).
  Map<String, String> dismissedInsights = {};

  /// Saldo terakhir yang disebut notifikasi bank/e-wallet
  /// (id akun -> "nominal|waktu ISO"), untuk mencocokkan saldo.
  Map<String, String> reportedBalance = {};

  /// Kapan kurs terakhir disimpan user (null = belum pernah).
  DateTime? ratesUpdatedAt;

  /// Backup otomatis ke Download/Infinity tiap hari (kalau ada perubahan).
  bool autoBackup = true;
  DateTime? lastAutoBackup;

  /// Sidik isi data saat backup otomatis terakhir (untuk melewati backup
  /// kalau tidak ada perubahan).
  String? lastBackupSig;

  /// Kapan terakhir menyimpan salinan backup ke luar HP (Google Drive dll).
  DateTime? lastDriveSave;

  /// Jumlah notifikasi "Perlu dicek" lama yang terbuang karena antrean penuh.
  int droppedCaptures = 0;

  // Header Beranda
  String displayName = 'Infinity';
  String? avatarPath;

  /// 'time' (sapaan sesuai jam) | 'custom' | 'motivation'
  String greetingMode = 'time';
  String greetingText = '';

  // Keamanan
  bool biometric = false;
  bool secureScreen = false;

  /// Splash animasi koin hanya diputar sekali, saat app pertama kali dibuka.
  bool splashSeen = false;

  /// Panduan pertama kali sudah dilewati.
  bool onboarded = false;

  /// 'off' | 'ask' | 'auto' untuk pencatatan dari notifikasi bank/e-wallet.
  String captureMode = 'auto';

  /// Notifikasi dengan tombol Keluar / Masuk / Abaikan saat notifikasi
  /// bank atau e-wallet terdeteksi (berlaku kalau [captureMode] bukan 'off').
  bool captureButtons = true;

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
        if (periodStartDay != 1) 'periodStartDay': periodStartDay,
        'globalBudget': globalBudget,
        if (specialBudget > 0) 'specialBudget': specialBudget,
        'categoryBudgets': categoryBudgets,
        'rates': rates,
        if (includeSecrets) 'pin': pin,
        'hideBalance': hideBalance,
        if (!homeMaskot) 'homeMaskot': false,
        if (!homeRitme) 'homeRitme': false,
        if (weekSeen != null) 'weekSeen': weekSeen,
        'weekOffered': true,
        'themeMode': themeMode,
        'textScale': textScale,
        'homeCards': homeCards,
        if (spendKinds.isNotEmpty) 'spendKinds': spendKinds,
        'accentIndex': accentIndex,
        if (stylePack != 'classic') 'stylePack': stylePack,
        if (!packMotif) 'packMotif': false,
        if (mascotSkin != 'classic') 'mascotSkin': mascotSkin,
        if (!packTone) 'packTone': false,
        if (mascotCustomPath != null) 'mascotCustomPath': mascotCustomPath,
        'iconStyle': iconStyle,
        if (features.isNotEmpty) 'features': features,
        if (splashMode != 'once') 'splashMode': splashMode,
        if (chartShape != 'donut') 'chartShape': chartShape,
        if (lang != 'id') 'lang': lang,
        if (iconsV37) 'iconsV37': true,
        if (pinnedCats.isNotEmpty) 'pinnedCats': pinnedCats,
        if (hiddenFreq.isNotEmpty) 'hiddenFreq': hiddenFreq,
        'defaultAccountId': defaultAccountId,
        'balanceSetAt': balanceSetAt,
        'dismissedSubs': dismissedSubs,
        if (ignoredCapturePkgs.isNotEmpty) 'ignoredCapturePkgs': ignoredCapturePkgs,
        'dismissedInsights': dismissedInsights,
        'reportedBalance': reportedBalance,
        'autoBackup': autoBackup,
        'lastAutoBackup': lastAutoBackup?.toIso8601String(),
        if (lastBackupSig != null) 'lastBackupSig': lastBackupSig,
        'lastDriveSave': lastDriveSave?.toIso8601String(),
        if (droppedCaptures > 0) 'droppedCaptures': droppedCaptures,
        if (quickHintSeen > 0) 'quickHintSeen': quickHintSeen,
        'ratesUpdatedAt': ratesUpdatedAt?.toIso8601String(),
        'displayName': displayName,
        'avatarPath': avatarPath,
        'greetingMode': greetingMode,
        'greetingText': greetingText,
        'biometric': biometric,
        'secureScreenV2': secureScreen,
        'splashSeen': splashSeen,
        'onboarded': onboarded,
        'captureMode': captureMode,
        'captureButtons': captureButtons,
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
    s.periodStartDay = _i(j['periodStartDay'], 1).clamp(1, 28);
    s.globalBudget = _d(j['globalBudget']);
    s.specialBudget = _d(j['specialBudget']);
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
    s.homeMaskot = j['homeMaskot'] != false;
    s.homeRitme = j['homeRitme'] != false;
    s.weekSeen = _s(j['weekSeen']);
    s.textScale = _d(j['textScale'] ?? 1.0).clamp(0.85, 1.3);
    if (j['homeCards'] is List) {
      s.homeCards = (j['homeCards'] as List)
          .whereType<String>()
          .where(kHomeCards.containsKey)
          .toSet()
          .toList();
    }
    // Daftar kartu lama belum punya Tinjauan mingguan: tawarkan sekali, di atas.
    if (j['homeCards'] is List && j['weekOffered'] != true) {
      if (!s.homeCards.contains('week')) s.homeCards.insert(0, 'week');
    }
    if (j['spendKinds'] is Map) {
      s.spendKinds = {
        for (final e in (j['spendKinds'] as Map).entries)
          if (e.value is String) e.key.toString(): e.value as String
      };
    }
    final tm = _s(j['themeMode']);
    s.themeMode = (tm == 'light' || tm == 'dark') ? tm! : 'system';
    s.accentIndex = _i(j['accentIndex'], 0).clamp(0, C.accents.length - 1);
    final sp = _s(j['stylePack']);
    s.stylePack = (sp != null && kStylePacks.containsKey(sp)) ? sp : 'classic';
    s.packMotif = j['packMotif'] != false;
    final ms = _s(j['mascotSkin']);
    s.mascotSkin = (ms == 'owl' ||
            ms == 'fox' ||
            ms == 'crow' ||
            ms == 'custom' ||
            ms == 'auto')
        ? ms!
        : 'classic';
    s.packTone = j['packTone'] != false;
    s.mascotCustomPath = _s(j['mascotCustomPath']);
    final isv = _s(j['iconStyle']);
    s.iconStyle =
        (isv == 'classic' || isv == 'mono' || isv == 'flat') ? isv! : 'cartoon';
    if (j['features'] is Map) {
      s.features = {
        for (final e in (j['features'] as Map).entries)
          if (e.value is bool && kFeatureDefaults.containsKey(e.key.toString()))
            e.key.toString(): e.value as bool
      };
    }
    final spm = _s(j['splashMode']);
    s.splashMode = (spm == 'always' || spm == 'off') ? spm! : 'once';
    s.chartShape = _s(j['chartShape']) == 'pie' ? 'pie' : 'donut';
    s.lang = const ['en', 'zh'].contains(_s(j['lang'])) ? _s(j['lang'])! : 'id';
    s.iconsV37 = j['iconsV37'] == true;
    if (j['pinnedCats'] is List) {
      s.pinnedCats = (j['pinnedCats'] as List).whereType<String>().toList();
    }
    if (j['hiddenFreq'] is List) {
      s.hiddenFreq = (j['hiddenFreq'] as List).whereType<String>().toList();
    }
    s.autoBackup = j['autoBackup'] != false;
    s.defaultAccountId = _s(j['defaultAccountId']);
    final ds = j['dismissedSubs'];
    if (ds is List) s.dismissedSubs = ds.whereType<String>().toList();
    final ic = j['ignoredCapturePkgs'];
    if (ic is List) s.ignoredCapturePkgs = ic.whereType<String>().toList();
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
    s.lastBackupSig = _s(j['lastBackupSig']);
    s.lastDriveSave = DateTime.tryParse(_s(j['lastDriveSave']) ?? '');
    s.droppedCaptures = _i(j['droppedCaptures'], 0);
    s.quickHintSeen = _i(j['quickHintSeen'], 0);
    s.ratesUpdatedAt = DateTime.tryParse(_s(j['ratesUpdatedAt']) ?? '');
    final dn = _s(j['displayName'])?.trim();
    s.displayName = (dn == null || dn.isEmpty) ? 'Infinity' : dn;
    s.avatarPath = _s(j['avatarPath']);
    final gm = _s(j['greetingMode']);
    s.greetingMode = (gm == 'custom' || gm == 'motivation') ? gm! : 'time';
    s.greetingText = _s(j['greetingText']) ?? '';
    s.biometric = j['biometric'] == true;
    // V2: bawaan sekarang mati (screenshot boleh). Setelan lama diabaikan.
    s.secureScreen = j['secureScreenV2'] == true;
    // Data lama (sudah pernah buka app) dianggap sudah melihat splash.
    s.splashSeen = j['splashSeen'] != false;
    s.onboarded = j['onboarded'] != false;
    final mode = _s(j['captureMode']);
    s.captureMode =
        (mode == 'off' || mode == 'ask' || mode == 'auto') ? mode! : 'auto';
    s.captureButtons = j['captureButtons'] != false;
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
