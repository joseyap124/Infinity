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

  static Future<bool> init() async {
    try {
      final d = await getApplicationSupportDirectory();
      if (!d.existsSync()) d.createSync(recursive: true);
      _file = File('${d.path}/infinity_data.bin');
      var k = await SecureStore.read(_keyName);
      if (k == null || k.isEmpty) {
        k = base64Encode(_random(32));
        await SecureStore.write(_keyName, k);
      }
      _key = SecretKey(base64Decode(k));
      return true;
    } catch (_) {
      _file = null;
      _key = null;
      return false;
    }
  }

  /// Null kalau belum ada file. Lempar kalau file rusak / kunci salah.
  static Future<String?> read() async {
    final f = _file, key = _key;
    if (f == null || key == null || !f.existsSync()) return null;
    final b = await f.readAsBytes();
    if (b.length < 28) throw const FormatException('File data terlalu pendek');
    final clear = await AesGcm.with256bits().decrypt(
        SecretBox(b.sublist(28), nonce: b.sublist(0, 12), mac: Mac(b.sublist(12, 28))),
        secretKey: key);
    return utf8.decode(clear);
  }

  /// Tulis atomik: ke file sementara dulu, lalu ganti nama.
  static Future<void> write(String json) async {
    final f = _file, key = _key;
    if (f == null || key == null) return;
    final nonce = _random(12);
    final box = await AesGcm.with256bits()
        .encrypt(utf8.encode(json), secretKey: key, nonce: nonce);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsBytes([...nonce, ...box.mac.bytes, ...box.cipherText], flush: true);
    await tmp.rename(f.path);
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

