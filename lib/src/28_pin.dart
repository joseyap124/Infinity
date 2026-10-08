part of '../main.dart';

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
          color: C.surface,
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
          Icon(Icons.all_inclusive_rounded, color: C.accentDark, size: 44),
          const SizedBox(height: 12),
          Text(widget.title,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(widget.subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(color: C.muted)),
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
                    color: i < _pin.length ? C.accentDark : Colors.transparent,
                    border: Border.all(color: C.accentDark, width: 2),
                  ),
                ),
            ],
          ),
          SizedBox(
            height: 32,
            child: Center(
              child: Text(_error ?? '',
                  style: TextStyle(
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
            padding: pagePad(context, 32),
            children: [
              AppCard(
                child: Row(
                  children: [
                    CatIcon(
                        icon: active
                            ? Icons.lock_rounded
                            : Icons.lock_open_rounded,
                        color: active ? C.accent : C.muted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(active ? 'PIN aktif' : 'PIN nonaktif',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 16)),
                          Text(
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
                              TextStyle(fontSize: 12.5, color: C.muted)),
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
                      subtitle: Text(
                          'Isi app disembunyikan di daftar aplikasi terbaru dan screenshot diblokir',
                          style: TextStyle(fontSize: 12.5, color: C.muted)),
                      onChanged: (v) =>
                          store.updateSettings((x) => x.secureScreen = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
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
