part of '../main.dart';

// Layar "Data tidak bisa dibuka" (v5.0.3). Muncul kalau file data ada di HP
// tetapi gagal dibuka (mis. kunci enkripsi tidak terbaca). Tidak ada yang
// ditulis atau dihapus sampai user memilih.

class DataLockedScreen extends StatefulWidget {
  const DataLockedScreen({super.key, required this.onRetry, required this.onFresh});
  final Future<void> Function() onRetry;
  final Future<void> Function() onFresh;

  @override
  State<DataLockedScreen> createState() => _DataLockedScreenState();
}

class _DataLockedScreenState extends State<DataLockedScreen> {
  bool _busy = false;
  String? _note;
  Timer? _auto;
  int _autoTries = 0;

  @override
  void initState() {
    super.initState();
    _scheduleAuto();
  }

  @override
  void dispose() {
    _auto?.cancel();
    super.dispose();
  }

  /// Gagal baca kunci sering hanya sesaat (mis. app baru dibuka dari widget
  /// atau baru dihidupkan sistem), jadi coba lagi diam-diam beberapa kali.
  void _scheduleAuto() {
    if (_autoTries >= 3) return;
    _auto = Timer(const Duration(milliseconds: 2500), () async {
      if (!mounted || _busy) return;
      _autoTries++;
      await widget.onRetry();
      if (mounted) {
        setState(() {});
        _scheduleAuto();
      }
    });
  }

  Future<void> _retry() async {
    setState(() {
      _busy = true;
      _note = null;
    });
    await widget.onRetry();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _note = tr('Masih belum bisa dibuka. Coba lagi nanti, atau mulai dari awal lalu pulihkan dari backup.');
    });
  }

  Future<void> _fresh() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Mulai dari awal?')),
        content: Text(tr(
            'Infinity akan mulai kosong. File data yang tidak bisa dibuka disimpan terpisah di HP ini, tidak dihapus. Setelah itu pulihkan dari file backup lewat Lainnya, Backup & pindah HP, Pulihkan.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('Batal'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('Mulai dari awal'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    await widget.onFresh();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
          children: [
            Icon(Icons.lock_outline_rounded, size: 56, color: C.amberDark),
            const SizedBox(height: 16),
            Text(tr('Data belum bisa dibuka'),
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Text(
                tr('Infinity gagal membaca kunci data di HP ini. Datamu belum diubah dan masih tersimpan. Coba lagi dulu, kegagalan seperti ini sering hanya sesaat.'),
                style: TextStyle(fontSize: 15, height: 1.4, color: C.muted)),
            const SizedBox(height: 10),
            Text(
                tr('Kalau tetap gagal, kamu bisa mulai dari awal lalu memulihkan dari file backup di Download/Infinity.'),
                style: TextStyle(fontSize: 15, height: 1.4, color: C.muted)),
            if (_note != null) ...[
              const SizedBox(height: 14),
              Text(_note!,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: C.redDark)),
            ],
            if (DataFile.lastFailure.isNotEmpty) ...[
              const SizedBox(height: 14),
              SelectableText('Kode: ${DataFile.lastFailure}',
                  style: TextStyle(fontSize: 11.5, height: 1.35, color: C.muted)),
            ],
            const SizedBox(height: 24),
            PrimaryButton(
              label: _busy ? 'Memeriksa...' : 'Coba lagi',
              icon: Icons.refresh_rounded,
              onPressed: _busy ? null : _retry,
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _busy ? null : _fresh,
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20))),
              child: Text(tr('Mulai dari awal dan pulihkan dari backup')),
            ),
          ],
        ),
      ),
    );
  }
}
