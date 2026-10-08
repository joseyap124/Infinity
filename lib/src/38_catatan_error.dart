part of '../main.dart';

// =============================================================================
// CATATAN ERROR (offline)
// Error dicatat ke file di folder pribadi app. Tidak dikirim ke mana pun;
// user bisa menyimpannya ke Download lalu mengirimkannya sendiri.
// =============================================================================

class ErrorLog {
  static File? _file;
  static final List<String> _memory = [];
  static const int _maxBytes = 200 * 1024;
  static const String appVersion =
      String.fromEnvironment('APP_VERSION', defaultValue: 'dev');

  static Future<void> init() async {
    try {
      final d = await getApplicationSupportDirectory();
      if (!d.existsSync()) d.createSync(recursive: true);
      _file = File('${d.path}/infinity_errors.log');
      if (_memory.isNotEmpty) {
        _file!.writeAsStringSync(_memory.join(), mode: FileMode.append);
        _memory.clear();
      }
    } catch (_) {
      _file = null; // mis. di web: tetap dicatat di memori
    }
  }

  static String _format(Object error, StackTrace? stack, String source) {
    final lines = (stack?.toString() ?? '')
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .take(25)
        .join('\n');
    String os;
    try {
      os = Platform.operatingSystemVersion;
    } catch (_) {
      os = 'web';
    }
    return '--- ${DateTime.now().toIso8601String()} · Infinity v$appVersion · $source · $os\n'
        '$error\n$lines\n\n';
  }

  static void record(Object error, StackTrace? stack, {String source = 'app'}) {
    final entry = _format(error, stack, source);
    final f = _file;
    if (f == null) {
      _memory.add(entry);
      if (_memory.length > 50) _memory.removeAt(0);
      return;
    }
    try {
      f.writeAsStringSync(entry, mode: FileMode.append, flush: true);
      final len = f.lengthSync();
      if (len > _maxBytes) {
        // Simpan setengah terakhir saja.
        final text = f.readAsStringSync();
        f.writeAsStringSync(text.substring(text.length - _maxBytes ~/ 2));
      }
    } catch (_) {}
  }

  static String read() {
    final f = _file;
    if (f == null) return _memory.join();
    try {
      return f.existsSync() ? f.readAsStringSync() : '';
    } catch (_) {
      return '';
    }
  }

  static int count() => RegExp(r'^--- ', multiLine: true).allMatches(read()).length;

  static void clear() {
    _memory.clear();
    try {
      final f = _file;
      if (f != null && f.existsSync()) f.writeAsStringSync('');
    } catch (_) {}
  }
}

/// Pengganti layar abu-abu bawaan Flutter saat satu bagian gagal digambar.
Widget friendlyErrorWidget(FlutterErrorDetails d) {
  return Container(
    margin: const EdgeInsets.all(8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0x1AE53935),
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Text(
      'Bagian ini gagal ditampilkan. Error sudah dicatat; kirim lewat Lainnya → Laporan error.',
      style: TextStyle(fontSize: 12.5, color: Color(0xFFC62828)),
    ),
  );
}

class ErrorLogPage extends StatefulWidget {
  const ErrorLogPage({super.key});

  @override
  State<ErrorLogPage> createState() => _ErrorLogPageState();
}

class _ErrorLogPageState extends State<ErrorLogPage> {
  @override
  Widget build(BuildContext context) {
    final text = ErrorLog.read();
    final n = ErrorLog.count();
    return Scaffold(
      appBar: pageBar('Laporan error'),
      body: ListView(
        padding: pagePad(context, 32),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                    n == 0
                        ? 'Tidak ada error tercatat. 👍'
                        : '$n error tercatat.',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 6),
                Text(
                    'Catatan ini hanya ada di HP ini dan tidak dikirim ke mana pun. Isinya teknis (bagian kode yang error), bukan data transaksimu. Kalau ada yang aneh di app, simpan lalu kirim filenya ke yang merawat Infinity.',
                    style: TextStyle(fontSize: 12.5, color: C.muted)),
                if (n > 0) ...[
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: 'Simpan ke Download',
                    icon: Icons.download_rounded,
                    onPressed: () async {
                      final stamp = DateFormat('yyyy-MM-dd_HHmm')
                          .format(DateTime.now());
                      final ok = await NativeBridge.saveDownload(
                          'infinity-error-$stamp.txt', text);
                      if (!context.mounted) return;
                      snack(
                          context,
                          ok
                              ? 'Tersimpan di Download/Infinity ✅'
                              : 'Gagal menyimpan. Coba Salin.');
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: text));
                            if (context.mounted) snack(context, 'Disalin');
                          },
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('Salin'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ErrorLog.clear();
                            setState(() {});
                          },
                          icon: Icon(Icons.delete_outline_rounded,
                              color: C.redDark),
                          label: Text('Hapus',
                              style: TextStyle(color: C.redDark)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (n > 0) ...[
            const SizedBox(height: 12),
            AppCard(
              child: SelectableText(
                text.length > 6000 ? text.substring(text.length - 6000) : text,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
