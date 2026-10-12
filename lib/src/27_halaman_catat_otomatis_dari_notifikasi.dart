part of '../main.dart';

// =============================================================================
// HALAMAN: CATAT OTOMATIS DARI NOTIFIKASI
// =============================================================================

/// Hasil membaca antrean notifikasi dari native.
class CaptureSyncResult {
  const CaptureSyncResult(
      {this.fetched = 0,
      this.auto = 0,
      this.waiting = 0,
      this.buttons = 0,
      this.ignored = 0});
  final int fetched;
  final int auto;
  final int waiting;

  /// Dicatat dari tombol Keluar / Masuk di notifikasi.
  final int buttons;
  final int ignored;
}

/// Pengaturan yang dikirim ke native untuk notifikasi bertombol.
extension CaptureNativeConfig on AppStore {
  String captureConfigJson() => jsonEncode({
        'on': settings.captureButtons && settings.captureMode != 'off',
        'pkgs': [for (final e in _knownApps) e[0]],
        'promo': _promoWords,
        'channel': tr('Transaksi terdeteksi'),
        'hiddenTitle': tr('Transaksi terdeteksi'),
        'out': tr('Keluar'),
        'inn': tr('Masuk'),
        'ignore': tr('Abaikan'),
        'doneOut': tr('Pengeluaran'),
        'doneIn': tr('Pemasukan'),
        'doneNote': tr('Dicatat saat Infinity dibuka.'),
      });

  /// Baca pilihan tombol dan notifikasi baru dari native, simpan, lalu
  /// kosongkan antrean native setelah datanya benar-benar tertulis.
  Future<CaptureSyncResult> syncNativeCaptures() async {
    if (!loaded || settings.captureMode == 'off') {
      return const CaptureSyncResult();
    }
    final decisions = await NativeBridge.fetchDecisions();
    final raw = await NativeBridge.fetchCaptured();
    if (raw.isEmpty && decisions.isEmpty) return const CaptureSyncResult();
    final (buttons, ignored) = applyCaptureDecisions(decisions);
    final before = pendingCaptures.length;
    final auto = ingestCaptured(raw);
    final waiting = pendingCaptures.length - before;
    if (await flush()) {
      await NativeBridge.ackCaptured([
        for (final r in raw)
          if (r['qid'] is String) r['qid'] as String
      ]);
      await NativeBridge.ackDecisions([
        for (final r in decisions)
          if (r['qid'] is String) r['qid'] as String
      ]);
    }
    return CaptureSyncResult(
        fetched: raw.length + decisions.length,
        auto: auto,
        waiting: waiting < 0 ? 0 : waiting,
        buttons: buttons,
        ignored: ignored);
  }
}

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
    final r = await store.syncNativeCaptures();
    if (!mounted) return;
    snack(
        context,
        r.fetched == 0
            ? 'Belum ada notifikasi uang baru.'
            : tr('{0} dicatat otomatis, {1} dari tombol notifikasi, {2} menunggu dicek.',
                [r.auto, r.buttons, r.waiting]));
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
              decoration: BoxDecoration(
                  color: C.accentDark, shape: BoxShape.circle),
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
            padding: pagePad(context, 32),
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
                          Text(
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
                  style: TextStyle(fontSize: 12.5, color: C.muted)),
              if (mode != 'off') ...[
                const SizedBox(height: 12),
                AppCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: SwitchListTile(
                    value: store.settings.captureButtons,
                    onChanged: (v) {
                      store.updateSettings((x) => x.captureButtons = v);
                      if (v) unawaited(Notifier.instance.requestPermission());
                    },
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    title: const Text('Notifikasi dengan tombol',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14)),
                    subtitle: Text(
                        'Saat notifikasi bank atau e-wallet terdeteksi, Infinity memunculkan notifikasi dengan tombol Keluar, Masuk, dan Abaikan. Pilihanmu dicatat begitu Infinity dibuka berikutnya.',
                        style: TextStyle(fontSize: 12.5, color: C.muted)),
                  ),
                ),
              ],
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
                    Text(
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
                      tr('Kosongkan antrean ({0})', [store.pendingCaptures.length])),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
