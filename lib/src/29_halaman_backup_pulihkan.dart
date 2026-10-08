part of '../main.dart';

// =============================================================================
// HALAMAN: BACKUP & PULIHKAN
// =============================================================================

class BackupPage extends StatefulWidget {
  const BackupPage({super.key, required this.store});
  final AppStore store;

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  AppStore get store => widget.store;
  final _importCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    store.removeListener(_refresh);
    _importCtrl.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    final json = store.exportJson();
    await Clipboard.setData(ClipboardData(text: json));
    // Hapus dari clipboard setelah 60 detik supaya tidak terbaca app lain.
    unawaited(Future<void>.delayed(const Duration(seconds: 60), () async {
      try {
        final cur = await Clipboard.getData(Clipboard.kTextPlain);
        if (cur?.text == json) {
          await Clipboard.setData(const ClipboardData(text: ''));
        }
      } catch (_) {}
    }));
    if (!mounted) return;
    snack(context,
        'Backup (${(json.length / 1024).toStringAsFixed(1)} KB, tanpa PIN) disalin. Tempel dalam 60 detik, setelah itu clipboard dikosongkan.');
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    setState(() => _importCtrl.text = data?.text ?? '');
  }

  Future<void> _restore() async {
    if (_importCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Tempel data backup dulu.');
      return;
    }
    final ok = await confirmDialog(context,
        title: 'Pulihkan backup?',
        message:
            'Semua data sekarang akan DIGANTI dengan isi backup. Salin backup data sekarang dulu kalau masih perlu.',
        confirmLabel: 'Pulihkan',
        destructive: true);
    if (!ok || !mounted) return;
    try {
      store.importJson(_importCtrl.text);
      setState(() {
        _error = null;
        _importCtrl.clear();
      });
      snack(context, 'Data berhasil dipulihkan ✅');
    } catch (e) {
      setState(() => _error =
          'Gagal memulihkan: pastikan yang ditempel adalah backup Infinity yang utuh. ($e)');
    }
  }

  Future<void> _clear() => confirmResetAll(context, store);

  bool _hasPw = false;

  @override
  void initState() {
    super.initState();
    store.addListener(_refresh);
    _refresh();
  }

  void _refresh() {
    store.backupPassword().then((pw) {
      if (mounted) setState(() => _hasPw = pw != null);
    });
  }

  Future<String?> _askPassword({required bool confirm, String? title}) {
    final a = TextEditingController();
    final b = TextEditingController();
    String? err;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(title ?? 'Kata sandi backup',
              style: const TextStyle(fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: a,
                obscureText: true,
                autofocus: true,
                decoration: fieldDeco('Kata sandi', icon: Icons.key_rounded),
              ),
              if (confirm) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: b,
                  obscureText: true,
                  decoration:
                      fieldDeco('Ulangi kata sandi', icon: Icons.key_rounded),
                ),
                const SizedBox(height: 8),
                Text(
                    'Minimal 6 karakter. Catat di tempat aman: kalau lupa, backup tidak bisa dibuka.',
                    style: TextStyle(fontSize: 12, color: C.muted)),
              ],
              if (err != null) ...[
                const SizedBox(height: 8),
                Text(err!, style: TextStyle(color: C.redDark, fontSize: 12.5)),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal')),
            FilledButton(
              onPressed: () {
                if (confirm && a.text.length < 6) {
                  setLocal(() => err = 'Kata sandi minimal 6 karakter.');
                } else if (confirm && a.text != b.text) {
                  setLocal(() => err = 'Kedua kata sandi tidak sama.');
                } else if (a.text.isEmpty) {
                  setLocal(() => err = 'Isi kata sandinya.');
                } else {
                  Navigator.pop(ctx, a.text);
                }
              },
              style: FilledButton.styleFrom(
                  backgroundColor: C.accentDark,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18))),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setPassword() async {
    final pw = await _askPassword(confirm: true);
    if (pw == null || !mounted) return;
    await store.setBackupPassword(pw);
    if (mounted) {
      snack(context, 'Kata sandi backup disimpan. Backup berikutnya terenkripsi 🔒');
    }
  }

  /// Simpan backup terenkripsi lewat layar "Simpan sebagai" Android. Google
  /// Drive muncul di sana kalau app-nya terpasang; upload dikerjakan Drive.
  Future<void> _saveToDrive() async {
    if (!_hasPw) {
      final go = await confirmDialog(context,
          title: 'Atur kata sandi dulu',
          message:
              'Backup yang dikirim ke Google Drive selalu dikunci kata sandi, supaya isinya tidak bisa dibaca siapa pun selain kamu.',
          confirmLabel: 'Atur kata sandi');
      if (!go || !mounted) return;
      final pw = await _askPassword(confirm: true);
      if (pw == null || !mounted) return;
      await store.setBackupPassword(pw);
      if (!mounted) return;
    }
    final bytes = await store.encryptedBackup();
    if (bytes == null || !mounted) return;
    final stamp = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
    try {
      final name = await NativeBridge.saveAs(
          'infinity-backup-$stamp.infb', bytes, 'application/octet-stream');
      if (name == null || !mounted) return;
      snack(context, 'Tersimpan: $name ✅');
    } catch (e) {
      if (mounted) snack(context, 'Gagal menyimpan: $e');
    }
  }

  Future<void> _restoreFile() async {
    final picked = await NativeBridge.pickFile();
    if (picked == null || !mounted) return;
    String? pw;
    if (SecureBackup.looksEncrypted(picked.bytes)) {
      pw = await _askPassword(
          confirm: false, title: 'Kata sandi untuk ${picked.name}');
      if (pw == null || !mounted) return;
    }
    final ok = await confirmDialog(context,
        title: 'Pulihkan backup?',
        message:
            'Semua data sekarang akan DIGANTI dengan isi ${picked.name}. Backup data sekarang dulu kalau masih perlu.',
        confirmLabel: 'Pulihkan',
        destructive: true);
    if (!ok || !mounted) return;
    try {
      final n = await store.restoreFromFile(picked.bytes, password: pw);
      if (!mounted) return;
      setState(() => _error = null);
      snack(context,
          'Data berhasil dipulihkan${n > 0 ? ' (+$n foto struk)' : ''} ✅');
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Gagal memulihkan: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pageBar('Backup & Pulihkan'),
      body: ListView(
        padding: pagePad(context, 32),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionTitle('Backup'),
                const SizedBox(height: 6),
                Text(
                    '${store.transactions.length} transaksi, ${store.accounts.length} akun, ${store.categories.length} kategori. Data disalin sebagai teks JSON, simpan di tempat aman (catatan, email ke diri sendiri, Google Drive).',
                    style: TextStyle(fontSize: 13, color: C.muted)),
                const SizedBox(height: 12),
                PrimaryButton(
                    label: 'Salin backup',
                    icon: Icons.copy_rounded,
                    onPressed: _copy),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionTitle('Backup ke folder Download'),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: store.settings.autoBackup,
                  onChanged: (v) =>
                      store.updateSettings((x) => x.autoBackup = v),
                  title: const Text('Otomatis tiap minggu',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                      store.settings.lastAutoBackup == null
                          ? 'Belum pernah'
                          : 'Terakhir: ${DateFormat('d MMM yyyy, HH.mm', 'id_ID').format(store.settings.lastAutoBackup!)}',
                      style: TextStyle(fontSize: 12.5, color: C.muted)),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                      _hasPw ? Icons.lock_rounded : Icons.lock_open_rounded,
                      color: _hasPw ? C.income : C.amberDark),
                  title: Text(
                      _hasPw
                          ? 'Terenkripsi dengan kata sandi'
                          : 'Belum terenkripsi',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                      _hasPw
                          ? 'File .infb, ikut foto struk. Tanpa kata sandi ini, backup tidak bisa dibuka (juga oleh kamu).'
                          : 'File JSON bisa dibaca siapa saja yang memegang file-nya. Atur kata sandi supaya terkunci.',
                      style: TextStyle(fontSize: 12.5, color: C.muted)),
                  trailing: TextButton(
                    onPressed: _setPassword,
                    child: Text(_hasPw ? 'Ganti' : 'Atur'),
                  ),
                ),
                Text(
                    'Disimpan di Download/Infinity dan tetap ada walau app di-uninstall. Disimpan $kKeepBackups backup terakhir; yang lebih lama dihapus otomatis. Setiap backup dicek dulu bisa dibuka sebelum disimpan. Pulihkan lewat tombol "Pulihkan dari file" di bawah.',
                    style: TextStyle(fontSize: 12.5, color: C.muted)),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await store.backupToDownloads(force: true);
                    if (!context.mounted) return;
                    snack(
                        context,
                        ok
                            ? 'Backup tersimpan di Download/Infinity ✅'
                            : 'Gagal menyimpan ke Download.');
                  },
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Backup sekarang'),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionTitle('Simpan ke Google Drive'),
                const SizedBox(height: 6),
                Text(
                    'Di layar simpan, pilih Google Drive (atau tempat lain). Upload dikerjakan app Drive, Infinity tetap tanpa internet. Yang dikirim selalu backup terkunci kata sandi (.infb), jadi Google tidak bisa membaca isinya. Untuk memulihkan, pakai "Pulihkan dari file" lalu pilih dari Drive.',
                    style: TextStyle(fontSize: 12.5, color: C.muted)),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _saveToDrive,
                  icon: const Icon(Icons.cloud_upload_rounded),
                  label: const Text('Simpan backup ke Drive…'),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionTitle('Pindah HP'),
                const SizedBox(height: 6),
                for (var i = 0; i < kMoveSteps.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text('${i + 1}. ${kMoveSteps[i]}',
                        style: TextStyle(fontSize: 12.5, color: C.muted, height: 1.35)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ExportExcelCard(store: store),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionTitle('Pulihkan'),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _restoreFile,
                  icon: const Icon(Icons.folder_open_rounded),
                  label: const Text('Pulihkan dari file (.infb / .json)'),
                  style: FilledButton.styleFrom(
                      backgroundColor: C.accentDark,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20))),
                ),
                const SizedBox(height: 12),
                Text('atau tempel teks JSON:',
                    style: TextStyle(fontSize: 12.5, color: C.muted)),
                const SizedBox(height: 6),
                TextField(
                  controller: _importCtrl,
                  maxLines: 6,
                  minLines: 4,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  decoration: fieldDeco('Tempel data backup di sini'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _paste,
                        icon: const Icon(Icons.content_paste_rounded),
                        label: const Text('Tempel'),
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20))),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _restore,
                        icon: const Icon(Icons.restore_rounded),
                        label: const Text('Pulihkan'),
                        style: FilledButton.styleFrom(
                            backgroundColor: C.accentDark,
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20))),
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  ErrorBox(_error!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionTitle('Zona Bahaya'),
                const SizedBox(height: 8),
                Text(
                    'Hapus semua data dan mulai dari nol. Harus mengetik HAPUS dulu supaya tidak terpencet.',
                    style: TextStyle(fontSize: 13, color: C.muted)),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _clear,
                  style: OutlinedButton.styleFrom(
                      foregroundColor: C.redDark,
                      side: BorderSide(color: C.redDark),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20))),
                  child: const Text('Reset semua data'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
