part of '../main.dart';

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
      await HomeWidget.updateWidget(androidName: 'InfinityQuickWidgetProvider');
      await HomeWidget.updateWidget(androidName: 'InfinityMiniWidgetProvider');
    } catch (_) {}
  }

  static Future<Uri?> initialLaunch() async {
    if (kIsWeb) return null; // widget hanya ada di Android
    try {
      return await HomeWidget.initiallyLaunchedFromHomeWidget();
    } catch (_) {
      return null;
    }
  }

  static Stream<Uri?> clicks() {
    if (kIsWeb) return const Stream<Uri?>.empty();
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

  /// Simpan teks ke Download/Infinity (Android 10+). False kalau gagal.
  static Future<bool> saveDownload(String name, String text) async {
    try {
      return (await _ch.invokeMethod<bool>(
              'saveDownload', {'name': name, 'text': text})) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Buka pemilih file Android. Null kalau dibatalkan.
  static Future<({String name, Uint8List bytes})?> pickFile() async {
    final r = await _ch.invokeMapMethod<String, Object?>('pickFile');
    if (r == null) return null;
    final bytes = r['bytes'];
    if (bytes is! Uint8List) return null;
    return (name: (r['name'] as String?) ?? 'file', bytes: bytes);
  }

  /// Simpan file biner ke Download/Infinity. False kalau gagal.
  static Future<bool> saveDownloadBytes(
      String name, Uint8List bytes, String mime) async {
    try {
      return (await _ch.invokeMethod<bool>('saveDownloadBytes',
              {'name': name, 'bytes': bytes, 'mime': mime})) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Buka menu bagikan Android untuk gambar PNG. False kalau gagal.
  static Future<bool> shareImage(String name, Uint8List bytes) async {
    try {
      return (await _ch.invokeMethod<bool>(
              'shareImage', {'name': name, 'bytes': bytes})) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Layar "Simpan sebagai" Android (bisa pilih Google Drive). Mengembalikan
  /// nama file yang disimpan, null kalau dibatalkan. Lempar kalau gagal.
  static Future<String?> saveAs(String name, Uint8List bytes, String mime) async {
    try {
      return await _ch.invokeMethod<String>(
          'saveAs', {'name': name, 'bytes': bytes, 'mime': mime});
    } on PlatformException catch (e) {
      throw Exception(e.message ?? e.code);
    }
  }

  /// Hapus backup lama di Download/Infinity, sisakan [keep] terbaru.
  static Future<int> pruneBackups(int keep) async {
    try {
      return await _ch.invokeMethod<int>('pruneBackups', {'keep': keep}) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Notifikasi pintasan 4 ikon (native, gaya Money Manager).
  static Future<void> showQuickBar() async {
    try {
      await _ch.invokeMethod<void>('showQuickBar');
    } catch (_) {}
  }

  static Future<void> hideQuickBar() async {
    try {
      await _ch.invokeMethod<void>('hideQuickBar');
    } catch (_) {}
  }

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

  /// Status layanan penangkap notifikasi: connected, connectedAt, lastSeen,
  /// lastSeenPkg, lastMoney, lastMoneyPkg (waktu dalam milidetik).
  static Future<Map<String, dynamic>> captureHealth() async {
    try {
      final s = await _ch.invokeMethod<String>('captureHealth');
      if (s == null || s.isEmpty) return {};
      final m = jsonDecode(s);
      return m is Map ? Map<String, dynamic>.from(m) : {};
    } catch (_) {
      return {};
    }
  }

  /// Minta Android menyambungkan lagi layanan penangkap notifikasi.
  static Future<void> rebindListener() async {
    try {
      await _ch.invokeMethod<void>('rebindListener');
    } catch (_) {}
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

  /// Lihat antrean notifikasi uang yang ditangkap native. Antrean baru
  /// dikosongkan lewat [ackCaptured] setelah isinya tersimpan.
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

  /// Hapus item antrean (berdasarkan qid) yang sudah tersimpan di Infinity.
  static Future<void> ackCaptured(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      await _ch.invokeMethod('ackCaptured', {'ids': ids});
    } catch (_) {}
  }

  /// Pilihan dari tombol Keluar / Masuk / Abaikan di notifikasi. Tiap item
  /// berisi isi notifikasi plus 'decision' (expense | income | ignore).
  static Future<List<Map<String, dynamic>>> fetchDecisions() async {
    try {
      final s = await _ch.invokeMethod<String>('fetchDecisions');
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

  static Future<void> ackDecisions(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      await _ch.invokeMethod('ackDecisions', {'ids': ids});
    } catch (_) {}
  }

  /// Kirim pengaturan notifikasi bertombol ke native (JSON).
  static Future<void> setCaptureConfig(String json) async {
    try {
      await _ch.invokeMethod('setCaptureConfig', {'json': json});
    } catch (_) {}
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

/// Data utama disimpan di file terenkripsi (AES-256-GCM) di folder pribadi
/// app. Kuncinya acak dan disimpan di Android Keystore lewat secure storage.
/// Menggantikan penyimpanan lama (<=1.7) yang menaruh seluruh data di secure
/// storage, yang melambat saat datanya besar.
class DataFile {
  static const String _keyName = 'infinity_file_key_v1';
  static File? _file;
  static SecretKey? _key;

  static List<int> _random(int n) {
    final r = math.Random.secure();
    return List<int>.generate(n, (_) => r.nextInt(256));
  }

  static const String _keyBakFile = 'infinity_key.bak';
  static File? _keyBak;
  static SecretKey? _alt;

  /// File data ada tetapi kuncinya hilang (lihat [init]).
  static bool keyLost = false;

  /// Alasan terakhir data tidak bisa dibuka (teknis, ditampilkan kecil di layar
  /// "Data belum bisa dibuka" supaya penyebabnya bisa dilacak).
  static String lastFailure = '';
  static String _ssErr = '';

  static String _short(Object e) {
    final t = e.toString().replaceAll(RegExp(r'\s+'), ' ');
    return '${e.runtimeType}: ${t.length > 90 ? t.substring(0, 90) : t}';
  }

  static Future<String?> _readKeyOnce() async {
    try {
      final k = await SecureStore.read(_keyName);
      _ssErr = '';
      return (k == null || k.isEmpty) ? null : k;
    } catch (e) {
      _ssErr = _short(e);
      return null;
    }
  }

  static Future<bool> init() async {
    try {
      final d = await getApplicationSupportDirectory();
      if (!d.existsSync()) d.createSync(recursive: true);
      _cleanStaleTmp(d);
      _file = File('${d.path}/infinity_data.bin');
      _keyBak = File('${d.path}/$_keyBakFile');
      _alt = null;
      // Secure storage kadang gagal membaca kunci sesaat (mis. setelah app
      // dimatikan sistem). Coba beberapa kali dulu, dan jangan langsung
      // membuat kunci baru: kunci baru membuat data lama tidak bisa dibuka.
      String? k;
      for (var i = 0; i < 4 && k == null; i++) {
        k = await _readKeyOnce();
        if (k == null && i < 3) {
          await Future<void>.delayed(Duration(milliseconds: 300 * (i + 1)));
        }
      }
      // Salinan kunci di folder privat app (tidak ikut backup, tidak bisa
      // dibuka app lain). Dipakai kalau secure storage gagal.
      String? bak;
      try {
        if (_keyBak!.existsSync()) {
          final t = (await _keyBak!.readAsString()).trim();
          if (t.isNotEmpty) bak = t;
        }
      } catch (_) {}
      if (k == null && bak != null) {
        k = bak;
        try {
          await SecureStore.write(_keyName, k);
        } catch (_) {}
      } else if (k != null && bak != null && bak != k) {
        try {
          _alt = SecretKey(base64Decode(bak));
        } catch (_) {}
      }
      if (k == null) {
        if (_file!.existsSync()) {
          // File data ada tapi kunci tidak ditemukan di mana pun. Jangan buat
          // kunci baru (itu menimpa kunci lama dan data tidak akan terbuka
          // lagi): biarkan, dan tampilkan layar "Data tidak bisa dibuka".
          keyLost = true;
          jot('kunci hilang, file ada');
          _key = null;
          lastFailure =
              'kunci tidak ditemukan; secure storage: ${_ssErr.isEmpty ? 'kosong' : _ssErr}; salinan kunci: tidak ada';
          return true;
        }
        k = base64Encode(_random(32));
        await SecureStore.write(_keyName, k);
      }
      keyLost = false;
      _key = SecretKey(base64Decode(k));
      jot('init ok, folder=${_file!.parent.path}, file ada=${_file!.existsSync()}, kunci ${bak == null ? 'tanpa salinan' : (bak == k ? 'sama dgn salinan' : 'BEDA dgn salinan')}');
      if (bak != k) {
        try {
          await _keyBak!.writeAsString(k, flush: true);
        } catch (_) {}
      }
      return true;
    } catch (e) {
      _file = null;
      _key = null;
      lastFailure = 'init gagal: ${_short(e)}';
      jot(lastFailure);
      return false;
    }
  }

  static Future<String> _decrypt(List<int> b, SecretKey key) async {
    final clear = await AesGcm.with256bits().decrypt(
        SecretBox(b.sublist(28), nonce: b.sublist(0, 12), mac: Mac(b.sublist(12, 28))),
        secretKey: key);
    return utf8.decode(clear);
  }

  /// Null kalau belum ada file. Lempar kalau file rusak / kunci salah.
  static Future<String?> read() async {
    final f = _file, key = _key;
    if (f != null && key == null && keyLost && f.existsSync()) {
      throw const FormatException('Kunci data tidak ditemukan');
    }
    if (f == null || key == null || !f.existsSync()) return null;
    final sigBefore = _statSig();
    final b = await f.readAsBytes();
    _sig = sigBefore;
    if (b.length < 28) {
      lastFailure = 'file data terlalu pendek (${b.length} byte)';
      throw const FormatException('File data terlalu pendek');
    }
    try {
      return await _decrypt(b, key);
    } catch (e) {
      // Kunci di secure storage tidak cocok: coba salinan kunci di folder app.
      final alt = _alt;
      if (alt == null) {
        lastFailure =
            'dekripsi gagal (${_short(e)}); salinan kunci berbeda: tidak ada';
        rethrow;
      }
      final r = await _decrypt(b, alt);
      _key = alt;
      try {
        final enc = base64Encode(await alt.extractBytes());
        await SecureStore.write(_keyName, enc);
      } catch (_) {}
      return r;
    }
  }

  /// Ciri file (waktu ubah + ukuran) sejak terakhir kita baca atau tulis.
  /// Kalau berbeda, ada jendela/proses lain yang menulis file ini.
  static String? _sig;

  static String? _statSig() {
    try {
      final f = _file;
      if (f == null || !f.existsSync()) return null;
      final st = f.statSync();
      return '${st.modified.microsecondsSinceEpoch}:${st.size}';
    } catch (_) {
      return null;
    }
  }

  /// True kalau file diubah pihak lain sejak terakhir kita baca/tulis.
  static bool get changedByOther {
    final now = _statSig();
    return now != null && now != _sig;
  }

  /// Simpan salinan file saat ini (versi dari pihak lain) sebelum ditimpa.
  /// Hanya 3 salinan terbaru yang disimpan.
  static Future<void> keepForeignCopy() async {
    final f = _file;
    if (f == null || !f.existsSync()) return;
    try {
      await f.copy('${f.path}.timpa_${DateTime.now().millisecondsSinceEpoch}');
      final d = f.parent;
      final keep = d
          .listSync()
          .whereType<File>()
          .where((e) => e.path.split('/').last.startsWith('infinity_data.bin.timpa_'))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      for (final old in keep.skip(3)) {
        try {
          old.deleteSync();
        } catch (_) {}
      }
    } catch (_) {}
  }

  // ---- Salinan harian (v5.13): salinan file data terenkripsi, satu per hari,
  // disimpan di folder app. Dibuat dari file yang baru saja terbaca utuh,
  // sebelum ada tulisan hari itu. Tidak menyentuh jalur tulis data.
  static const String _snapPrefix = 'infinity_data.bin.snap_';
  static const int kKeepSnapshots = 7;

  static String snapFileName(DateTime d) =>
      '$_snapPrefix${d.year.toString().padLeft(4, '0')}'
      '${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  /// Tanggal dari nama file salinan harian; null kalau bukan salinan.
  static DateTime? snapFileDay(String name) {
    final n = name.split('/').last;
    if (!n.startsWith(_snapPrefix)) return null;
    final t = n.substring(_snapPrefix.length);
    if (t.length != 8) return null;
    final y = int.tryParse(t.substring(0, 4));
    final m = int.tryParse(t.substring(4, 6));
    final d = int.tryParse(t.substring(6, 8));
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  /// Nama salinan yang perlu dihapus supaya tersisa [keep] yang terbaru.
  static List<String> snapsToPrune(List<String> names, int keep) {
    final snaps = names.where((n) => snapFileDay(n) != null).toList()
      ..sort((a, b) => snapFileDay(b)!.compareTo(snapFileDay(a)!));
    return snaps.skip(keep).toList();
  }

  /// Buat salinan hari ini kalau belum ada. Aman dipanggil berkali-kali.
  static Future<void> snapshotToday() async {
    final f = _file;
    if (f == null || !f.existsSync()) return;
    try {
      if (f.lengthSync() < 28) return;
      final dir = f.parent;
      final dest = File('${dir.path}/${snapFileName(DateTime.now())}');
      if (!dest.existsSync()) {
        await f.copy('${dest.path}.tmp');
        await File('${dest.path}.tmp').rename(dest.path);
        jot('salinan harian dibuat: ${dest.path.split('/').last}');
      }
      final names = dir.listSync().whereType<File>().map((e) => e.path).toList();
      for (final old in snapsToPrune(names, kKeepSnapshots)) {
        try {
          File(old).deleteSync();
        } catch (_) {}
      }
    } catch (e) {
      jot('salinan harian GAGAL: ${_short(e)}');
    }
  }

  /// Salinan harian yang ada, terbaru dulu.
  static List<File> snapshots() {
    final f = _file;
    if (f == null) return const [];
    try {
      final l = f.parent
          .listSync()
          .whereType<File>()
          .where((e) => snapFileDay(e.path) != null)
          .toList()
        ..sort((a, b) => snapFileDay(b.path)!.compareTo(snapFileDay(a.path)!));
      return l;
    } catch (_) {
      return const [];
    }
  }

  /// Isi salinan harian sebagai teks JSON. Lempar kalau tidak bisa dibuka.
  static Future<String> readSnapshot(File snap) async {
    final b = await snap.readAsBytes();
    if (b.length < 28) throw const FormatException('Salinan terlalu pendek');
    final key = _key;
    if (key != null) {
      try {
        return await _decrypt(b, key);
      } catch (_) {}
    }
    final alt = _alt;
    if (alt != null) return _decrypt(b, alt);
    throw const FormatException('Salinan tidak bisa dibuka');
  }

  // ---- Jejak penyimpanan: catatan singkat tiap muat/simpan, untuk melacak
  // kenapa perubahan kadang tidak bertahan setelah app dibuka ulang.
  static File? _jf;
  static final List<String> _jmem = [];

  static void jot(String msg) {
    final t = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final line =
        '${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}:${two(t.second)}.${t.millisecond.toString().padLeft(3, '0')} $msg\n';
    try {
      var f = _jf;
      if (f == null) {
        final d = _file?.parent;
        if (d != null) f = _jf = File('${d.path}/infinity_persist.log');
      }
      if (f == null) {
        _jmem.add(line);
        if (_jmem.length > 80) _jmem.removeAt(0);
        return;
      }
      if (_jmem.isNotEmpty) {
        f.writeAsStringSync(_jmem.join(), mode: FileMode.append);
        _jmem.clear();
      }
      f.writeAsStringSync(line, mode: FileMode.append);
      if (f.lengthSync() > 30000) {
        final all = f.readAsStringSync();
        f.writeAsStringSync(all.substring(all.length - 15000));
      }
    } catch (_) {}
  }

  /// Jejak terbaru di atas, maksimal [max] baris.
  static String journalText({int max = 120}) {
    try {
      final f = _jf;
      final raw = (f != null && f.existsSync())
          ? f.readAsStringSync()
          : _jmem.join();
      final lines = raw.split('\n').where((l) => l.trim().isNotEmpty).toList();
      // Catatan peluncuran dari sisi Android (jendela dibuat/ditutup) digabung
      // berdasarkan jam, supaya urutannya terbaca bersama jejak simpan.
      final dir = _file?.parent;
      if (dir != null) {
        final nf = File('${dir.path}/infinity_launch.log');
        if (nf.existsSync()) {
          lines.addAll(nf
              .readAsStringSync()
              .split('\n')
              .where((l) => l.trim().isNotEmpty));
          lines.sort();
        }
      }
      return lines.reversed.take(max).join('\n');
    } catch (_) {
      return '';
    }
  }

  static int _wseq = 0;

  /// Tulis atomik: ke file sementara dulu, lalu ganti nama. Nama file
  /// sementara unik di setiap tulisan, supaya dua penulis bersamaan (mis. dua
  /// jendela Infinity sekaligus) tidak saling mengambil file sementara
  /// ("Cannot rename file ... .tmp: No such file or directory").
  static Future<void> write(String json) async {
    final f = _file, key = _key;
    if (f == null || key == null) return;
    final nonce = _random(12);
    final box = await AesGcm.with256bits()
        .encrypt(utf8.encode(json), secretKey: key, nonce: nonce);
    final bytes = [...nonce, ...box.mac.bytes, ...box.cipherText];
    final tag = _random(4).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    for (var attempt = 0; attempt < 2; attempt++) {
      final tmp = File(
          '${f.path}.${DateTime.now().microsecondsSinceEpoch}_${_wseq++}_$tag.tmp');
      try {
        await tmp.writeAsBytes(bytes, flush: true);
        // Ciri file dihitung dari file sementara SEBELUM diganti nama (ganti
        // nama tidak mengubah waktu ubah dan ukuran), supaya tulisan salinan
        // lain tepat sesudahnya tidak terbaca sebagai tulisan kita sendiri.
        final ts = tmp.statSync();
        final mySig = '${ts.modified.microsecondsSinceEpoch}:${ts.size}';
        await tmp.rename(f.path);
        _sig = mySig;
        final len = f.existsSync() ? f.lengthSync() : -1;
        jot('tulis ok ${bytes.length}B, file $len B${len == bytes.length ? '' : ' (UKURAN BEDA)'}');
        return;
      } on FileSystemException catch (e) {
        jot('tulis GAGAL percobaan ${attempt + 1}: ${_short(e)}');
        // Berkas sementara hilang di tengah jalan: bersihkan lalu coba sekali
        // lagi dengan nama baru. Gagal lagi: lempar supaya tercatat.
        try {
          if (tmp.existsSync()) tmp.deleteSync();
        } catch (_) {}
        if (attempt == 1) rethrow;
      }
    }
  }

  /// Hapus sisa file sementara lama (dari tulisan yang terputus).
  static void _cleanStaleTmp(Directory d) {
    try {
      final now = DateTime.now();
      for (final e in d.listSync()) {
        final n = e.path.split('/').last;
        if (e is File &&
            n.startsWith('infinity_data.bin.') &&
            n.endsWith('.tmp') &&
            now.difference(e.lastModifiedSync()).inMinutes >= 2) {
          e.deleteSync();
        }
      }
    } catch (_) {}
  }

  /// Mulai dari awal: file data yang tidak terbaca disimpan terpisah (tidak
  /// dihapus), lalu dibuat kunci baru.
  static Future<void> freshStart() async {
    await quarantine();
    final k = base64Encode(_random(32));
    try {
      await SecureStore.write(_keyName, k);
    } catch (_) {}
    try {
      await _keyBak?.writeAsString(k, flush: true);
    } catch (_) {}
    _key = SecretKey(base64Decode(k));
    _alt = null;
    keyLost = false;
  }

  /// Amankan file yang tidak bisa dibaca supaya tidak tertimpa.
  static Future<void> quarantine() async {
    final f = _file;
    if (f == null || !f.existsSync()) return;
    try {
      await f.rename('${f.path}.rusak_${DateTime.now().millisecondsSinceEpoch}');
    } catch (_) {}
  }
}

