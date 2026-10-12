part of '../main.dart';

// Riwayat tangkapan notifikasi (v5.0.3): hasil tiap notifikasi uang yang
// sampai ke app dan alasannya, supaya "kenapa tidak muncul di Beranda" bisa
// dijawab dari layar. Hanya 40 terakhir, hanya di HP ini (tidak ikut backup).

const int kCaptureLogMax = 40;

/// Kode hasil. Yang diawali 'auto' dicatat otomatis, 'promo' dan 'noamount'
/// dibuang, sisanya masuk antrean "Dari Notifikasi".
enum CaptureOutcome { auto, queued, dropped }

CaptureOutcome captureOutcomeOf(String code) {
  if (code == 'auto') return CaptureOutcome.auto;
  if (code == 'promo' || code == 'noamount') return CaptureOutcome.dropped;
  return CaptureOutcome.queued;
}

class CaptureLogEntry {
  const CaptureLogEntry({
    required this.time,
    required this.pkg,
    required this.title,
    required this.snippet,
    required this.code,
    this.extra = '',
  });

  final DateTime time;
  final String pkg;
  final String title;
  final String snippet;
  final String code;

  /// Keterangan tambahan (mis. nama akun untuk 'auto').
  final String extra;

  CaptureOutcome get outcome => captureOutcomeOf(code);

  Map<String, dynamic> toJson() => {
        'time': time.toIso8601String(),
        'pkg': pkg,
        'title': title,
        'snippet': snippet,
        'code': code,
        if (extra.isNotEmpty) 'extra': extra,
      };

  factory CaptureLogEntry.fromJson(Map<String, dynamic> j) => CaptureLogEntry(
        time: DateTime.tryParse(_s(j['time']) ?? '') ?? DateTime.now(),
        pkg: _s(j['pkg']) ?? '',
        title: _s(j['title']) ?? '',
        snippet: _s(j['snippet']) ?? '',
        code: _s(j['code']) ?? '',
        extra: _s(j['extra']) ?? '',
      );
}

String captureReasonText(CaptureLogEntry e) {
  switch (e.code) {
    case 'auto':
      return tr('Dicatat otomatis ke {0}', [e.extra]);
    case 'mode':
      return tr('Mode "Tanya dulu": menunggu keputusanmu');
    case 'noacct':
      return tr('Akun tidak bisa ditebak. Beri nama akun yang memuat nama aplikasinya, mis. "BCA"');
    case 'nocat':
      return tr('Kategori tidak ditemukan');
    case 'dup':
      return tr('Mirip transaksi yang sudah ada (nominal dan akun sama dalam 10 menit)');
    case 'beforebal':
      return tr('Lebih lama dari saldo yang kamu atur manual');
    case 'topup':
      return tr('Isi saldo (top up), dicek dulu');
    case 'promo':
      return tr('Terdeteksi sebagai promo');
    case 'noamount':
      return tr('Nominal tidak terbaca dari teks notifikasi');
  }
  return e.code;
}

String _clip(String s, int n) {
  final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t.length <= n ? t : '${t.substring(0, n)}...';
}

extension CaptureLogStore on AppStore {
  void logCapture(CapturedNotif c, String code, [String extra = '']) {
    captureLog.add(CaptureLogEntry(
        time: c.time,
        pkg: c.pkg,
        title: _clip(c.title, 60),
        snippet: _clip(c.text, 110),
        code: code,
        extra: extra));
    if (captureLog.length > kCaptureLogMax) {
      captureLog = captureLog.sublist(captureLog.length - kCaptureLogMax);
    }
  }

  void clearCaptureLog() {
    captureLog = [];
    _commit();
  }
}

class CaptureLogPage extends StatelessWidget {
  const CaptureLogPage({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pageBar('Riwayat tangkapan'),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final items = store.captureLog.reversed.toList();
          return ListView(
            padding: pagePad(context, 32),
            children: [
              Text(
                  tr('Hasil tiap notifikasi uang yang sampai ke Infinity ({0} terakhir). Notifikasi tanpa nominal "Rp" tidak sampai ke sini, dan notifikasi yang sama dalam 3 menit hanya dihitung sekali.',
                      [kCaptureLogMax]),
                  style: TextStyle(fontSize: 12.5, color: C.muted)),
              const SizedBox(height: 12),
              if (items.isEmpty)
                AppCard(
                  child: Text(
                      tr('Belum ada notifikasi yang ditangkap. Kalau kamu sudah menerima notifikasi uang tapi daftar ini kosong, cek Akses notifikasi di halaman Catat otomatis.'),
                      style: TextStyle(fontSize: 13.5, color: C.muted)),
                ),
              for (final e in items) ...[
                _row(e),
                const SizedBox(height: 10),
              ],
              if (items.isNotEmpty)
                TextButton(
                  onPressed: store.clearCaptureLog,
                  style: TextButton.styleFrom(foregroundColor: C.redDark),
                  child: Text(tr('Kosongkan riwayat')),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(CaptureLogEntry e) {
    final (Color color, String label) = switch (e.outcome) {
      CaptureOutcome.auto => (C.green, tr('Dicatat')),
      CaptureOutcome.queued => (C.amberDark, tr('Antrean')),
      CaptureOutcome.dropped => (C.muted, tr('Dibuang')),
    };
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                    '${appLabelForPackage(e.pkg)} · ${DateFormat('d MMM HH:mm', gDateLoc).format(e.time)}',
                    style: TextStyle(fontSize: 12, color: C.muted)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10)),
                child: Text(label,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: color)),
              ),
            ],
          ),
          if (e.title.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(e.title,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800)),
          ],
          if (e.snippet.isNotEmpty)
            Text(e.snippet, style: TextStyle(fontSize: 13, color: C.muted)),
          const SizedBox(height: 6),
          Text(captureReasonText(e),
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}
