part of '../main.dart';

// Kartu kesehatan backup di Beranda (v4.1): chip hijau kalau aman, kartu kuning
// kalau belum ada salinan di luar HP, kartu merah kalau backup sudah lama.

/// Teks relatif singkat: "baru saja", "5 menit lalu", "2 jam lalu", "9 hari lalu".
String agoLabel(DateTime at, DateTime now) {
  final d = now.difference(at);
  if (d.inMinutes < 1) return 'baru saja';
  if (d.inMinutes < 60) return '${d.inMinutes} menit lalu';
  if (d.inHours < 24) return '${d.inHours} jam lalu';
  return '${d.inDays} hari lalu';
}

enum BackupLevel {
  /// Terlalu sedikit data, atau backup dimatikan dan tidak ada yang perlu diingatkan.
  hidden,

  /// Aman: backup di HP baru dan salinan di luar HP tidak lama.
  ok,

  /// Backup di HP ada, tapi belum ada salinan di luar HP (atau sudah lama).
  offsite,

  /// Backup di HP sudah lama dan data sudah berubah sejak itu.
  stale,
}

class BackupStatus {
  const BackupStatus({
    required this.level,
    this.lastLocal,
    this.lastDrive,
    this.newTx = 0,
    this.upToDate = false,
  });
  final BackupLevel level;
  final DateTime? lastLocal;
  final DateTime? lastDrive;

  /// Transaksi bertanggal sesudah backup terakhir di HP.
  final int newTx;

  /// Isi data sama persis dengan backup terakhir di HP.
  final bool upToDate;
}

/// Hari sejak backup di HP dianggap lama (kalau datanya sudah berubah).
const int kBackupStaleDays = 7;

/// Hari sejak salinan di luar HP dianggap lama.
const int kOffsiteStaleDays = 7;

/// Jumlah transaksi minimal sebelum backup mulai diingatkan.
const int kBackupMinTx = 10;

extension BackupHealthStore on AppStore {
  BackupStatus backupStatus(DateTime now) {
    final local = settings.lastAutoBackup;
    final drive = settings.lastDriveSave;
    if (transactions.length < kBackupMinTx) {
      return BackupStatus(
          level: BackupLevel.hidden, lastLocal: local, lastDrive: drive);
    }
    final upToDate =
        local != null && settings.lastBackupSig == backupSignature();
    final newTx =
        local == null ? transactions.length : transactions.where((t) => t.date.isAfter(local)).length;
    // Backup di HP lama dan datanya berubah: paling mendesak.
    final localAge = local == null ? null : now.difference(local).inDays;
    if (!upToDate && (local == null || localAge! >= kBackupStaleDays)) {
      return BackupStatus(
          level: BackupLevel.stale,
          lastLocal: local,
          lastDrive: drive,
          newTx: newTx,
          upToDate: false);
    }
    final driveAge = drive == null ? null : now.difference(drive).inDays;
    if (drive == null || driveAge! >= kOffsiteStaleDays) {
      return BackupStatus(
          level: BackupLevel.offsite,
          lastLocal: local,
          lastDrive: drive,
          newTx: newTx,
          upToDate: upToDate);
    }
    return BackupStatus(
        level: BackupLevel.ok,
        lastLocal: local,
        lastDrive: drive,
        newTx: newTx,
        upToDate: upToDate);
  }
}

/// Kartu di atas Beranda. Tidak menampilkan apa pun kalau datanya masih sedikit.
class BackupHealthCard extends StatefulWidget {
  const BackupHealthCard({super.key, required this.store});
  final AppStore store;

  @override
  State<BackupHealthCard> createState() => _BackupHealthCardState();
}

class _BackupHealthCardState extends State<BackupHealthCard> {
  bool _busy = false;

  AppStore get store => widget.store;

  void _openBackup({bool driveSave = false}) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BackupPage(store: store, startDriveSave: driveSave)));
  }

  Future<void> _saveNow() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await store.backupToDownloads(force: true);
    if (!mounted) return;
    setState(() => _busy = false);
    snack(context,
        ok ? 'Backup tersimpan di Download/Infinity ✅' : 'Gagal menyimpan ke Download.');
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final st = store.backupStatus(now);
    final today = DateFormat('yyyy-MM-dd').format(now);
    switch (st.level) {
      case BackupLevel.hidden:
        return const SizedBox.shrink();
      case BackupLevel.ok:
        final last = st.lastLocal;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: _openBackup,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 5, 12, 5),
                decoration: BoxDecoration(
                  color: C.income.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ArtIcon(Icons.shield_rounded, color: C.income, size: 18, art: 'perisai'),
                    const SizedBox(width: 6),
                    Text(
                        last == null
                            ? 'Backup aman'
                            : tr('Backup aman · {0}', [agoLabel(last, now)]),
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: C.income)),
                  ],
                ),
              ),
            ),
          ),
        );
      case BackupLevel.offsite:
      case BackupLevel.stale:
        final stale = st.level == BackupLevel.stale;
        final id = stale ? 'backup_stale' : 'backup_offsite';
        if (store.settings.dismissedInsights[id] == today) {
          return const SizedBox.shrink();
        }
        final color = stale ? C.redDark : C.amberDark;
        final String title;
        final String body;
        if (stale) {
          final last = st.lastLocal;
          title = last == null
              ? 'Belum ada backup'
              : 'Backup terakhir ${now.difference(last).inDays} hari lalu';
          body = last == null
              ? 'Data hanya ada di HP ini. Simpan backup supaya aman kalau terjadi sesuatu.'
              : st.newTx > 0
                  ? 'Ada ${st.newTx} transaksi baru sejak itu.'
                  : 'Ada perubahan data sejak itu.';
        } else {
          final d = st.lastDrive;
          title = d == null
              ? 'Belum ada salinan di luar HP'
              : 'Salinan di luar HP ${now.difference(d).inDays} hari lalu';
          body = d == null
              ? 'Backup otomatis ada, tapi hanya di HP ini. Kalau HP hilang, data ikut hilang.'
              : 'Kalau HP hilang atau rusak, data hanya kembali dari salinan di luar HP.';
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ArtIcon(
                        stale ? Icons.shield_rounded : Icons.backup_rounded,
                        color: color,
                        size: 30,
                        art: stale ? 'perisai' : 'cloud'),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                  color: C.carbon)),
                          const SizedBox(height: 2),
                          Text(body,
                              style: TextStyle(
                                  fontSize: 12.5, color: C.muted, height: 1.3)),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => store.dismissInsight(id),
                      customBorder: const CircleBorder(),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(Icons.close_rounded, size: 18, color: C.muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilledButton(
                    onPressed: _busy
                        ? null
                        : stale
                            ? _saveNow
                            : () => _openBackup(driveSave: true),
                    style: FilledButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18))),
                    child: Text(
                        _busy
                            ? 'Menyimpan...'
                            : stale
                                ? 'Simpan sekarang'
                                : 'Simpan ke Drive',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }
}

/// Ringkasan status backup di halaman Backup & Pulihkan (selalu tampil).
class BackupStatusCard extends StatelessWidget {
  const BackupStatusCard({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final s = store.settings;
    final local = s.lastAutoBackup;
    final drive = s.lastDriveSave;
    final upToDate = local != null && s.lastBackupSig == store.backupSignature();

    Widget row(String label, String value, Color color) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              Expanded(
                  child: Text(label,
                      style: TextStyle(fontSize: 13.5, color: C.carbon))),
              Text(value,
                  style: TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
        );

    final localColor = local == null
        ? C.redDark
        : now.difference(local).inDays >= kBackupStaleDays && !upToDate
            ? C.redDark
            : C.income;
    final driveColor = drive == null
        ? C.amberDark
        : now.difference(drive).inDays >= kOffsiteStaleDays
            ? C.amberDark
            : C.income;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('Status backup'),
          row('Otomatis (Download/Infinity)',
              local == null ? 'Belum pernah' : agoLabel(local, now), localColor),
          Divider(height: 1, color: C.line),
          row('Salinan di luar HP',
              drive == null ? 'Belum pernah' : agoLabel(drive, now), driveColor),
          Divider(height: 1, color: C.line),
          row(
              'Data vs backup terakhir',
              local == null
                  ? '-'
                  : upToDate
                      ? 'Cocok'
                      : 'Ada perubahan',
              local == null
                  ? C.muted
                  : upToDate
                      ? C.income
                      : C.amberDark),
        ],
      ),
    );
  }
}
