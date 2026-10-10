part of '../main.dart';

// =============================================================================
// TAB 1: BERANDA
// =============================================================================

// --------------------------------------------------------------- sapaan

const List<String> _motivations = [
  'Catat yang kecil, karena yang kecil itu yang sering bocor.',
  'Uang yang dicatat lebih gampang diatur daripada uang yang diingat-ingat.',
  'Hari ini hemat sedikit, akhir bulan napas lebih lega.',
  'Bukan soal pelit, tapi soal tahu uangmu pergi ke mana.',
  'Tabungan tumbuh dari kebiasaan, bukan dari sisa.',
  'Bayar dirimu dulu: sisihkan tabungan sebelum belanja.',
  'Jajan boleh, asal masih masuk anggaran.',
  'Satu transaksi dicatat, satu langkah lebih sadar.',
  'Dompet tenang dimulai dari catatan yang rapi.',
  'Bandingkan pengeluaranmu dengan bulan lalu, bukan dengan orang lain.',
  'Diskon bukan alasan beli kalau barangnya tidak dibutuhkan.',
  'Dana darurat itu bukan rencana cadangan, itu rencana utama.',
  'Konsisten sebulan lebih berharga daripada semangat sehari.',
  'Tunda belanja 24 jam, lihat apakah masih ingin.',
  'Utang kecil yang dibiarkan bisa jadi beban besar.',
  'Langganan yang jarang dipakai? Saatnya dicek ulang.',
  'Target jelas bikin menabung terasa ada artinya.',
  'Pemasukan naik tidak berarti gaya hidup harus ikut naik.',
  'Akhir pekan hemat, awal minggu lebih tenang.',
  'Pelan-pelan asal rutin, saldo akan ikut bertambah.',
  'Ngopi di rumah sesekali juga tetap enak.',
  'Cek saldo itu bukan menakutkan, itu menenangkan.',
  'Rencana belanja bulanan menyelamatkan dari belanja impulsif.',
  'Investasi terbaik pertama: kebiasaan mencatat.',
  'Uang receh yang terkumpul tetap uang.',
  'Sebelum checkout, tanya dulu: butuh atau ingin?',
  'Sedikit demi sedikit, lama-lama jadi dana liburan.',
  'Kamu tidak harus sempurna, cukup lebih baik dari kemarin.',
  'Gaji datang dan pergi, catatanmu yang bikin dia bertahan.',
  'Tetap semangat, tiap catatan hari ini membantu kamu bulan depan.',
];

String _timeGreeting() {
  final h = DateTime.now().hour;
  if (h < 11) return 'Selamat pagi! Yuk mulai catat cuanmu ☀️';
  if (h < 15) return 'Selamat siang! Udah makan belum? 🍜';
  if (h < 18) return 'Selamat sore! Cek dompet dulu yuk 👀';
  return 'Selamat malam! Rekap hari ini, yuk 🌙';
}

/// Kalimat di bawah nama: sesuai jam, teks sendiri, atau motivasi harian
/// (berganti tiap hari, sama sepanjang hari itu).
String greetingFor(AppSettings s) {
  switch (s.greetingMode) {
    case 'custom':
      final t = s.greetingText.trim();
      return t.isEmpty ? _timeGreeting() : t;
    case 'motivation':
      final now = DateTime.now();
      final day = now.difference(DateTime(now.year)).inDays + now.year * 7;
      return _motivations[day % _motivations.length];
    default:
      return _timeGreeting();
  }
}

/// Backup terenkripsi (.infb): ZIP berisi data.json + foto struk, dikunci
/// AES-256-GCM dengan kunci dari kata sandi (PBKDF2-SHA256).
/// Format: "INFB1" | salt(16) | nonce(12) | mac(16) | ciphertext.
class SecureBackup {
  static const String magic = 'INFB1';
  static const int iterations = 100000;

  static Future<SecretKey> _key(String password, List<int> salt) =>
      Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iterations, bits: 256)
          .deriveKeyFromPassword(password: password, nonce: salt);

  static List<int> _random(int n) {
    final r = math.Random.secure();
    return List<int>.generate(n, (_) => r.nextInt(256));
  }

  static bool looksEncrypted(List<int> bytes) =>
      bytes.length > 5 && utf8.decode(bytes.sublist(0, 5), allowMalformed: true) == magic;

  /// ZIP data + foto lalu enkripsi.
  static Future<Uint8List> encrypt(
      String json, Map<String, List<int>> photos, String password) async {
    final arc = Archive();
    final data = utf8.encode(json);
    arc.addFile(ArchiveFile('data.json', data.length, data));
    photos.forEach((name, bytes) {
      arc.addFile(ArchiveFile('photos/$name', bytes.length, bytes));
    });
    final List<int>? zip = ZipEncoder().encode(arc);
    final salt = _random(16);
    final nonce = _random(12);
    final box = await AesGcm.with256bits().encrypt(zip!,
        secretKey: await _key(password, salt), nonce: nonce);
    return Uint8List.fromList([
      ...utf8.encode(magic),
      ...salt,
      ...nonce,
      ...box.mac.bytes,
      ...box.cipherText,
    ]);
  }

  /// Buka backup. Lempar [FormatException] kalau kata sandi salah/file rusak.
  static Future<(String, Map<String, List<int>>)> decrypt(
      List<int> bytes, String password) async {
    if (!looksEncrypted(bytes) || bytes.length < 5 + 16 + 12 + 16) {
      throw const FormatException('Bukan file backup Infinity (.infb).');
    }
    final salt = bytes.sublist(5, 21);
    final nonce = bytes.sublist(21, 33);
    final mac = bytes.sublist(33, 49);
    final cipher = bytes.sublist(49);
    List<int> zip;
    try {
      zip = await AesGcm.with256bits().decrypt(
          SecretBox(cipher, nonce: nonce, mac: Mac(mac)),
          secretKey: await _key(password, salt));
    } catch (_) {
      throw const FormatException('Kata sandi salah atau file rusak.');
    }
    final arc = ZipDecoder().decodeBytes(zip);
    String? json;
    final photos = <String, List<int>>{};
    for (final f in arc.files) {
      if (!f.isFile) continue;
      final content = f.content as List<int>;
      if (f.name == 'data.json') {
        json = utf8.decode(content);
      } else if (f.name.startsWith('photos/')) {
        final n = f.name.substring(7);
        if (n.isNotEmpty && !n.contains('/') && !n.contains('..')) {
          photos[n] = content;
        }
      }
    }
    if (json == null) throw const FormatException('Isi backup tidak lengkap.');
    return (json, photos);
  }
}

/// Foto struk disimpan di folder pribadi app: <dokumen>/receipts/<nama>.jpg.
class Receipts {
  static String? _dir;

  static Future<void> init() async {
    try {
      final d = await getApplicationDocumentsDirectory();
      final dir = Directory('${d.path}/receipts');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      _dir = dir.path;
    } catch (_) {
      _dir = null; // mis. versi web: foto struk tidak tersedia
    }
  }

  static bool get available => _dir != null;

  static File? file(String name) => _dir == null ? null : File('$_dir/$name');

  /// Ambil foto (kamera/galeri), kecilkan, simpan. Mengembalikan nama file.
  static Future<String?> add(ImageSource source) async {
    if (_dir == null) return null;
    final x = await ImagePicker().pickImage(
        source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 75);
    if (x == null) return null;
    final name = 'r_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(x.path).copy('$_dir/$name');
    return name;
  }

  /// Baca teks dari foto struk di HP (ML Kit, offline). Null kalau gagal.
  static Future<String?> readText(String name) async {
    final f = file(name);
    if (f == null || !f.existsSync()) return null;
    final r = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final res = await r.processImage(InputImage.fromFilePath(f.path));
      return res.text;
    } catch (_) {
      return null;
    } finally {
      unawaited(r.close());
    }
  }

  /// Simpan bytes (saat memulihkan backup).
  static Future<void> write(String name, List<int> bytes) async {
    if (_dir == null) return;
    await File('$_dir/$name').writeAsBytes(bytes, flush: true);
  }

  /// Hapus foto yang tidak lagi dipakai transaksi mana pun.
  static void cleanup(Iterable<Transaction> txs) {
    if (_dir == null) return;
    try {
      final used = {for (final t in txs) ...t.photos};
      for (final f in Directory(_dir!).listSync().whereType<File>()) {
        final name = f.uri.pathSegments.last;
        if (!used.contains(name)) f.deleteSync();
      }
    } catch (_) {}
  }
}

/// Lihat foto struk layar penuh, bisa dicubit untuk zoom.
void showReceipt(BuildContext context, String name) {
  final f = Receipts.file(name);
  if (f == null || !f.existsSync()) {
    snack(context, 'Foto tidak ditemukan.');
    return;
  }
  showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => Stack(
      children: [
        Positioned.fill(
          child: InteractiveViewer(
            maxScale: 5,
            child: Center(child: Image.file(f)),
          ),
        ),
        Positioned(
          top: MediaQuery.paddingOf(ctx).top + 8,
          right: 8,
          child: IconButton.filled(
            onPressed: () => Navigator.pop(ctx),
            style: IconButton.styleFrom(backgroundColor: Colors.black54),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
        ),
      ],
    ),
  );
}

class ReceiptThumb extends StatelessWidget {
  const ReceiptThumb(
      {super.key, required this.name, this.size = 56, this.onRemove});
  final String name;
  final double size;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final f = Receipts.file(name);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () => showReceipt(context, name),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: size,
              height: size,
              color: C.bg,
              child: f != null && f.existsSync()
                  ? Image.file(f,
                      fit: BoxFit.cover,
                      cacheWidth: (size * 3).round(),
                      errorBuilder: (_, __, ___) =>
                          Icon(Icons.broken_image_rounded, color: C.muted))
                  : Icon(Icons.broken_image_rounded, color: C.muted),
            ),
          ),
        ),
        if (onRemove != null)
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                    color: C.redDark, shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded,
                    size: 14, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.path, this.size = 40});
  final String? path;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = path;
    final file = p == null ? null : File(p);
    final has = file != null && file.existsSync();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: has
          ? Image.file(file, key: ValueKey(p), fit: BoxFit.cover,
              width: size, height: size,
              errorBuilder: (_, __, ___) => Icon(Icons.person_rounded,
                  color: C.accentDark, size: size * 0.6))
          : Icon(Icons.all_inclusive_rounded,
              color: C.accentDark, size: size * 0.6),
    );
  }
}

/// Ambil foto dari galeri, kecilkan, simpan di folder app. Null kalau batal.
Future<String?> pickAvatarImage() async {
  final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85);
  if (x == null) return null;
  final dir = await getApplicationDocumentsDirectory();
  final dest =
      '${dir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
  await File(x.path).copy(dest);
  return dest;
}

void _deleteFileQuiet(String? path) {
  if (path == null) return;
  try {
    final f = File(path);
    if (f.existsSync()) f.deleteSync();
  } catch (_) {}
}

class ProfileSheet extends StatefulWidget {
  const ProfileSheet({super.key, required this.store});
  final AppStore store;

  @override
  State<ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<ProfileSheet> {
  late final TextEditingController _name;
  late final TextEditingController _text;
  late String _mode;
  String? _avatar;
  bool _busy = false;

  AppSettings get _s => widget.store.settings;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
        text: _s.displayName == 'Infinity' ? '' : _s.displayName);
    _text = TextEditingController(text: _s.greetingText);
    _mode = _s.greetingMode;
    _avatar = _s.avatarPath;
  }

  @override
  void dispose() {
    _name.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() => _busy = true);
    try {
      final p = await pickAvatarImage();
      if (p != null && mounted) setState(() => _avatar = p);
    } catch (_) {
      if (mounted) snack(context, 'Gagal mengambil foto.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _save() {
    final old = _s.avatarPath;
    if (old != _avatar) _deleteFileQuiet(old);
    final name = _name.text.trim();
    widget.store.updateSettings((x) {
      x.displayName = name.isEmpty ? 'Infinity' : name;
      x.avatarPath = _avatar;
      x.greetingMode = _mode;
      x.greetingText = _text.text.trim();
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final preview = AppSettings()
      ..greetingMode = _mode
      ..greetingText = _text.text;
    return SheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Atur Beranda',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ),
              IconButton(
                tooltip: 'Tutup',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration:
                    BoxDecoration(color: C.accentDark, shape: BoxShape.circle),
                child: Avatar(path: _avatar, size: 64),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _busy ? null : _pick,
                      icon: const Icon(Icons.photo_library_rounded),
                      label: Text(_avatar == null ? 'Pilih foto' : 'Ganti foto'),
                    ),
                    if (_avatar != null)
                      TextButton(
                        onPressed: () => setState(() => _avatar = null),
                        child: const Text('Pakai logo'),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            maxLength: 30,
            decoration: fieldDeco('Nama di Beranda', icon: Icons.badge_rounded)
                .copyWith(hintText: 'Infinity', counterText: ''),
          ),
          const SizedBox(height: 14),
          const SmallLabel('Kalimat di bawah nama'),
          const SizedBox(height: 8),
          Segmented<String>(
            values: const ['time', 'custom', 'motivation'],
            selected: _mode,
            labelOf: (v) => switch (v) {
              'custom' => 'Tulis sendiri',
              'motivation' => 'Motivasi',
              _ => 'Sapaan jam',
            },
            dense: true,
            onChanged: (v) => setState(() => _mode = v),
          ),
          if (_mode == 'custom') ...[
            const SizedBox(height: 10),
            TextField(
              controller: _text,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: fieldDeco('Kalimatmu', icon: Icons.edit_rounded)
                  .copyWith(hintText: 'mis. Semangat nabung buat nikah 💍'),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: C.bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: C.line),
            ),
            child: Text(
                _mode == 'motivation'
                    ? 'Contoh hari ini: "${greetingFor(preview)}"\nBerganti otomatis setiap hari.'
                    : greetingFor(preview),
                style: TextStyle(fontSize: 13, color: C.muted)),
          ),
          const SizedBox(height: 16),
          PrimaryButton(label: 'Simpan', onPressed: _save),
        ],
      ),
    );
  }
}

class AccentPickerSheet extends StatelessWidget {
  const AccentPickerSheet({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final sel = store.settings.accentIndex;
    Widget swatch(int i) => Semantics(
          button: true,
          selected: i == sel,
          label: C.accents[i].$1,
          child: GestureDetector(
            onTap: () {
              store.updateSettings((x) => x.accentIndex = i);
              Navigator.pop(context);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: C.isDark ? C.accents[i].$4 : C.accents[i].$3,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: i == sel ? C.carbon : Colors.transparent,
                        width: 3),
                  ),
                  child: i == sel
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 22)
                      : null,
                ),
                const SizedBox(height: 4),
                Text(C.accents[i].$1,
                    style: TextStyle(
                        fontSize: 11.5,
                        color: C.muted,
                        fontWeight:
                            i == sel ? FontWeight.w800 : FontWeight.w500)),
              ],
            ),
          ),
        );
    Widget group(String title, Iterable<int> idx) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SmallLabel(title),
            const SizedBox(height: 10),
            Wrap(spacing: 14, runSpacing: 12, children: [
              for (final i in idx) swatch(i),
            ]),
          ],
        );
    return SheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Warna utama',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ),
              IconButton(
                tooltip: 'Tutup',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          group('Biasa', Iterable<int>.generate(8)),
          const SizedBox(height: 18),
          group('Pastel', Iterable<int>.generate(C.accents.length - 8, (k) => k + 8)),
          const SizedBox(height: 12),
          Text('Pemasukan tetap hijau dan pengeluaran tetap merah.',
              style: TextStyle(fontSize: 12, color: C.muted)),
        ],
      ),
    );
  }
}

/// Jumlah transaksi pada rentang (dipakai kartu utama Beranda).
int periodTxCount(AppStore store, DateTimeRange r) =>
    store.transactions.where((t) => inRange(t.date, r)).length;

class DashboardTab extends StatelessWidget {
  const DashboardTab(
      {super.key, required this.store, required this.onSeeAll, this.onOpenPlan});
  final AppStore store;
  final VoidCallback onSeeAll;

  /// Pindah ke tab Rencana.
  final VoidCallback? onOpenPlan;

  String _greeting() => greetingFor(store.settings);

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
              InsightStrip(
                  store: store,
                  onOpenCaptures: () {},
                  kinds: kHomeInsights),
              const SizedBox(height: 12),
              if (store.pendingCaptures.isNotEmpty) ...[
                _capturesCard(context),
                const SizedBox(height: 12),
              ],
              // Kartu pilihan user (Lainnya → Pengaturan → Atur Beranda).
              for (final id in store.settings.homeCards)
                ..._homeCard(context, id, credits, upcoming, recent),
              Center(
                child: TextButton.icon(
                  onPressed: () => showSheet<void>(
                      context, HomeCardsSheet(store: store)),
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('Atur Beranda'),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  /// Satu kartu Beranda berdasarkan id-nya (kosong kalau tidak relevan).
  List<Widget> _homeCard(BuildContext context, String id, List<Account> credits,
      List<RecurringRule> upcoming, List<Transaction> recent) {
    const gap = SizedBox(height: 12);
    switch (id) {
      case 'quick':
        if (store.templates.isEmpty) return const [];
        return [_templatesCard(context), gap];
      case 'upcoming':
        if (upcoming.isEmpty) return const [];
        return [_upcomingCard(context, upcoming.take(3).toList()), gap];
      case 'budget':
        return [_budgetCard(context), gap];
      case 'credit':
        if (credits.isEmpty) return const [];
        return [_creditCard(context, credits), gap];
      case 'goals':
        if (store.goals.isEmpty) return const [];
        return [
          SectionTitle('Target Tabungan',
              trailing: TextButton(
                  onPressed: () => _push(context, GoalsPage(store: store)),
                  child: const Text('Lihat semua'))),
          const SizedBox(height: 4),
          GoalCard(store: store, goal: store.goals.first, compact: true),
          gap,
        ];
      case 'compare':
        return [MonthCompareCard(store: store), gap];
      case 'recent':
        return [
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
          gap,
        ];
    }
    return const [];
  }

  Widget _header(BuildContext context) {
    final hide = store.settings.hideBalance;
    // Tanpa pita warna: latar Beranda sama dengan latar app (v3.6.1).
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.paddingOf(context).top + 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => showSheet<void>(
                      context, ProfileSheet(store: store)),
                  child: Row(
                    children: [
                      Avatar(path: store.settings.avatarPath, size: 38),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(store.settings.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: C.carbon,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900)),
                            Text(_greeting(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: C.muted,
                                    fontSize: 11.5,
                                    height: 1.25)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: store.toggleHideBalance,
                tooltip: hide ? 'Tampilkan saldo' : 'Sembunyikan saldo',
                icon: Icon(
                    hide
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: C.carbon),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _heroCard(context),
          const SizedBox(height: 10),
          _accountsCard(context),
        ],
      ),
    );
  }

  /// Kartu gelap: aman dibelanjakan hari ini, masuk/keluar periode ini, dan
  /// jumlah transaksi periode ini (v3.6).
  Widget _heroCard(BuildContext context) {
    final hide = store.settings.hideBalance;
    final now = DateTime.now();
    final s = store.safeToSpend(now);
    final range = currentPeriod(now);
    final income = store.sumIDR(TxType.income, range);
    final expense = store.sumIDR(TxType.expense, range);
    final count = periodTxCount(store, range);
    final left = s.leftToday;
    final over = left < 0;
    const inColor = Color(0xFF4ADE80);
    const outColor = Color(0xFFFB7185);
    final top = C.isDark ? const Color(0xFF1F2E34) : const Color(0xFF0E2733);
    final bottom = C.isDark ? const Color(0xFF243C3C) : const Color(0xFF153F3E);
    final totalFlow = income + expense;
    final inShare = totalFlow <= 0 ? 0.5 : income / totalFlow;
    final netWorth = store.netWorthIDR;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [top, bottom]),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () =>
                  showSheet<void>(context, SafeSpendSheet(store: store)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              over
                                  ? 'Lewat jatah hari ini'
                                  : 'Aman dibelanjakan hari ini',
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white70)),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                                hide
                                    ? 'Rp ••••••'
                                    : money(over ? -left : left),
                                style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: over ? outColor : Colors.white)),
                          ),
                          Text(
                              hide
                                  ? 'Ketuk untuk rincian'
                                  : 'Jatah ${money(s.perDay)}/hari · ${s.daysLeft} hari lagi${s.spentToday > 0 ? ' · keluar hari ini ${money(s.spentToday)}' : ''}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11.5, color: Colors.white60)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: Colors.white54),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _flow('Masuk', income, inColor,
                        Icons.south_west_rounded, hide)),
                Expanded(
                    child: _flow('Keluar', expense, outColor,
                        Icons.north_east_rounded, hide)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 6,
                child: Row(
                  children: [
                    Expanded(
                        flex: (inShare * 1000).round().clamp(1, 999),
                        child: const ColoredBox(color: inColor)),
                    const SizedBox(width: 2),
                    Expanded(
                        flex: ((1 - inShare) * 1000).round().clamp(1, 999),
                        child: const ColoredBox(color: outColor)),
                  ],
                ),
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _push(context, AccountsPage(store: store)),
              child: Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Row(
                  children: [
                    const Text('Total saldo ',
                        style:
                            TextStyle(fontSize: 12.5, color: Colors.white60)),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(hide ? 'Rp ••••••••' : money(netWorth),
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                    ),
                    const Text('Kelola akun',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white70)),
                    const Icon(Icons.chevron_right_rounded,
                        size: 18, color: Colors.white54),
                  ],
                ),
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onSeeAll,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                          count == 0
                              ? 'Belum ada transaksi periode ini'
                              : '$count transaksi periode ini',
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white70)),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        size: 18, color: Colors.white54),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _flow(
      String label, double v, Color color, IconData icon, bool hide) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11.5, color: Colors.white60)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(hide ? 'Rp ••••' : money(v),
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: color)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Akun dalam grid 2 kolom (maks 4) dan 4 tombol pintas, semuanya kartu
  /// putih polos di atas latar halaman (tanpa blok warna di belakang).
  Widget _accountsCard(BuildContext context) {
    final hide = store.settings.hideBalance;
    final shown = store.accounts.take(4).toList();
    final more = store.accounts.length - shown.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(builder: (context, box) {
          const gap = 10.0;
          final w = (box.maxWidth - gap) / 2;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final a in shown)
                SizedBox(width: w, child: _accountTile(context, a, hide)),
            ],
          );
        }),
        if (more > 0)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _push(context, AccountsPage(store: store)),
              style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: Text('Semua akun (${store.accounts.length}) ›',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: C.accentDark)),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            _quickAction(Icons.receipt_long_rounded, 'Bills', C.amberDark,
                () => _push(context, RecurringPage(store: store))),
            const SizedBox(width: 10),
            _quickAction(Icons.track_changes_rounded, 'Budget', C.redDark,
                () => _push(context, BudgetPage(store: store))),
            const SizedBox(width: 10),
            _quickAction(Icons.groups_rounded, 'Patungan', C.blueDark,
                () => showSheet<void>(context, PatunganSheet(store: store))),
            const SizedBox(width: 10),
            _quickAction(Icons.handshake_rounded, 'Utang', C.income,
                () => _push(context, DebtsPage(store: store))),
          ],
        ),
      ],
    );
  }

  Widget _accountTile(BuildContext context, Account a, bool hide) {
    final bal = store.balanceOf(a.id);
    return Material(
      color: C.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => openAccountHistory(context, store, a),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: C.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                        color: a.colorValue, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                        a.currency == 'IDR' ? a.name : '${a.name} · ${a.currency}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: C.muted,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(hide ? '•••••' : money(bal, a.currency),
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: bal < 0 ? C.redDark : C.carbon)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickAction(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: C.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: C.line),
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 4),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: C.carbon)),
              ],
            ),
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
                        style: TextStyle(
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
                      color: isIncome ? C.income : C.redDark)),
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
                            Text('Tagihan',
                                style:
                                    TextStyle(fontSize: 11, color: C.muted)),
                            Text(money(debt, a.currency),
                                style: TextStyle(
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
                              TextStyle(fontSize: 11.5, color: C.muted)),
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
                        style: TextStyle(fontSize: 12, color: C.muted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: C.muted),
            ],
          ),
          const SizedBox(height: 12),
          if (status == null)
            Text(
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
                      Text('Sisa kuota',
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
                style: TextStyle(fontSize: 12, color: C.muted)),
          ],
          if (catRows.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: C.line),
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

  /// Catat Cepat: satu baris chip kecil yang bisa digeser (v3.6), supaya
  /// Beranda tetap fokus ke info dan transaksi terakhir.
  Widget _templatesCard(BuildContext context) {
    final list = store.templates.take(8).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Catat cepat',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: C.muted)),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _push(context, TemplatesPage(store: store)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                    store.templates.length > list.length
                        ? 'Semua (${store.templates.length})'
                        : 'Kelola',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: C.accentDark)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) => _templateButton(context, list[i]),
          ),
        ),
      ],
    );
  }

  Widget _templateButton(BuildContext context, TxTemplate t) {
    final color = t.type == TxType.transfer
        ? C.blue
        : (store.categoryById(t.categoryId)?.colorValue ?? t.type.color);
    final icon = t.type == TxType.transfer
        ? Icons.swap_horiz_rounded
        : (store.categoryById(t.categoryId)?.iconData ?? Icons.bolt_rounded);
    return Material(
      color: C.surface,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: () => openTxForm(context, store, template: t),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 190),
          padding: const EdgeInsets.fromLTRB(6, 0, 12, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: C.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    shape: BoxShape.circle),
                child: Icon(icon, size: 15, color: color),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(t.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: C.carbon)),
              ),
              const SizedBox(width: 6),
              Text(compactMoney(t.amount),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: t.type.color)),
            ],
          ),
        ),
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
                            style: TextStyle(
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
