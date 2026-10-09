part of '../main.dart';

// =============================================================================
// PANDUAN PERTAMA KALI + BANTUAN / FAQ
// Untuk keluarga & teman yang memasang Infinity tanpa bisa bertanya langsung.
// =============================================================================

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.store, required this.onDone});
  final AppStore store;
  final VoidCallback onDone;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pages = PageController();
  int _index = 0;
  static const _count = 4;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  void _next() {
    if (_index == _count - 1) {
      widget.onDone();
    } else {
      _pages.nextPage(
          duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
    }
  }

  Widget _page({
    required IconData icon,
    required Color color,
    required String title,
    required String body,
    List<Widget> actions = const [],
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(22)),
            child: Icon(icon, size: 38, color: color),
          ),
          const SizedBox(height: 20),
          Text(title,
              style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w900, color: C.carbon)),
          const SizedBox(height: 12),
          Text(body,
              style: TextStyle(fontSize: 15, height: 1.45, color: C.muted)),
          const SizedBox(height: 20),
          for (final a in actions) ...[a, const SizedBox(height: 10)],
        ],
      ),
    );
  }

  Widget _action(String label, IconData icon, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          alignment: Alignment.centerLeft,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.onDone,
                child: const Text('Lewati'),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  _page(
                    icon: Icons.savings_rounded,
                    color: C.accentDark,
                    title: 'Selamat datang di Infinity',
                    body:
                        'Catatan keuangan yang sepenuhnya offline: data hanya ada di HP ini, terenkripsi, dan app tidak punya izin internet.\n\n'
                        'Catat pemasukan, pengeluaran, dan transfer antar akun. Beranda langsung menunjukkan berapa yang aman dibelanjakan hari ini dan hal yang perlu perhatian.',
                  ),
                  _page(
                    icon: Icons.account_balance_wallet_rounded,
                    color: C.blueDark,
                    title: 'Isi akun & saldo',
                    body:
                        'Buat akun sesuai dompetmu (mis. BCA, GoPay, Tunai) dan isi saldo sekarang. Semua angka dihitung dari saldo ini.\n\n'
                        'Tips: beri nama akun yang memuat nama aplikasinya ("GoPay", "BCA") supaya catat otomatis bisa menebak akunnya.',
                    actions: [
                      _action('Atur akun sekarang', Icons.edit_rounded,
                          () => _push(AccountsPage(store: store))),
                    ],
                  ),
                  _page(
                    icon: Icons.notifications_active_rounded,
                    color: C.amberDark,
                    title: 'Catat otomatis (opsional)',
                    body:
                        'Infinity bisa membaca notifikasi bank & e-wallet (GoPay, BCA, SeaBank, dll.) lalu mencatat transaksinya. Notifikasi dibaca di HP ini saja.\n\n'
                        'Di Android 13+, aktifkan sekali, lalu buka Info aplikasi → ⋮ → Izinkan setelan terbatas, dan aktifkan lagi. Panduannya ada di halaman Catat Otomatis.',
                    actions: [
                      _action('Buka Catat Otomatis', Icons.bolt_rounded,
                          () => _push(AutoCapturePage(store: store))),
                    ],
                  ),
                  _page(
                    icon: Icons.lock_rounded,
                    color: C.income,
                    title: 'Amankan & backup',
                    body:
                        'Pasang PIN (bisa pakai sidik jari). Atur kata sandi backup supaya backup harian di folder Download terkunci, lalu simpan salinannya ke Google Drive seminggu sekali.\n\n'
                        'Kalau app di-uninstall atau HP rusak, data hanya bisa kembali dari backup.',
                    actions: [
                      _action('Pasang PIN', Icons.pin_rounded,
                          () => _push(SecurityPage(store: store))),
                      _action('Atur kata sandi backup', Icons.backup_rounded,
                          () => _push(BackupPage(store: store))),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                children: [
                  for (var i = 0; i < _count; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 6),
                      width: i == _index ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _index ? C.accentDark : C.line,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _next,
                    style: FilledButton.styleFrom(
                        backgroundColor: C.accentDark,
                        minimumSize: const Size(120, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18))),
                    child: Text(_index == _count - 1 ? 'Mulai' : 'Lanjut'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Langkah pindah HP (dipakai di Bantuan dan Backup & Pulihkan).
const List<String> kMoveSteps = [
  'Di HP lama: Lainnya → Backup & Pulihkan. Atur kata sandi backup kalau belum, lalu tekan "Simpan backup ke Drive…" (atau "Backup sekarang" lalu kirim file .infb dari folder Download/Infinity ke HP baru).',
  'Di HP baru: pasang APK Infinity versi terbaru dari halaman Releases.',
  'Buka Infinity → Lainnya → Backup & Pulihkan → "Pulihkan dari file", pilih file .infb, masukkan kata sandi backup.',
  'Atur ulang PIN, sidik jari, dan izin Catat Otomatis di HP baru (setelan keamanan sengaja tidak ikut backup).',
  'Cek saldo tiap akun. Kalau sudah cocok, data di HP lama boleh dihapus.',
];

class _Faq {
  const _Faq(this.q, this.a);
  final String q;
  final String a;
}

const List<_Faq> _faqs = [
  _Faq('Apa arti "Aman dibelanjakan hari ini"?',
      'Kalau anggaran bulanan diatur: sisa anggaran dibagi sisa hari. Kalau belum: saldo e-wallet, tunai, dan bank, dikurangi tagihan kartu kredit, utang jatuh tempo, setoran target tabungan, dan tagihan berulang sampai akhir bulan keuangan, lalu dibagi sisa hari. Ketuk kartunya untuk melihat rinciannya. Akun tabungan bisa dikecualikan lewat edit akun.'),
  _Faq('Bulan mulai tanggal gajian',
      'Lainnya → Anggaran → Awal bulan keuangan. Misalnya gajian tanggal 25: "Oktober" dihitung 25 Sep sampai 24 Okt. Berlaku untuk anggaran, Aman dibelanjakan, Statistik bulanan, rekap & saran, dan filter "Bulan ini". Kalender di Riwayat tetap bulan kalender.'),
  _Faq('Kategori terisi sendiri',
      'Kalau judul yang sama (mis. "Kopi Kenangan") sudah minimal 2 kali kamu taruh di kategori yang sama, Infinity memilih kategori itu otomatis, termasuk untuk notifikasi. Kategori yang kamu pilih sendiri tidak pernah ditimpa.'),
  _Faq('Cara mencari transaksi',
      'Ketik beberapa kata sekaligus (semua harus cocok): "kopi gopay". Saring nominal dengan ">50rb", "<20000", ">=1jt". Pakai pilihan di bawah kolom cari untuk jenis dan waktu. Total hasil tampil di atas daftar.'),
  _Faq('Catat otomatis tidak jalan',
      '1) Pastikan izin akses notifikasi aktif (Lainnya → Catat Otomatis). Di Android 13+ perlu "Izinkan setelan terbatas" di Info aplikasi. 2) Di Xiaomi/Oppo/Vivo/Realme, atur Baterai Infinity ke "Tanpa batasan" dan izinkan Mulai otomatis. 3) Beri nama akun yang memuat nama aplikasinya ("GoPay", "BCA"). 4) Notifikasi yang tidak yakin akunnya masuk ke kartu "Dari Notifikasi" di Beranda untuk dicek.'),
  _Faq('Nominal dari notifikasi salah',
      'Pembacaan notifikasi memakai pola umum dan bisa meleset untuk format bank tertentu. Koreksi transaksinya, lalu kirim contoh teks notifikasinya (tanpa nomor rekening) ke yang merawat Infinity supaya polanya diperbaiki.'),
  _Faq('Bagaimana backup bekerja?',
      'Setiap hari (kalau ada perubahan) Infinity menyimpan backup ke Download/Infinity ($kKeepBackups terakhir disimpan). Dengan kata sandi backup, file berformat .infb terkunci AES-256 dan ikut menyimpan foto struk. Simpan juga salinan ke Google Drive lewat tombol "Simpan backup ke Drive…" seminggu sekali; Infinity mengingatkan kalau sudah lewat 7 hari. Tanpa kata sandi itu, backup .infb tidak bisa dibuka siapa pun.'),
  _Faq('Update app tanpa kehilangan data',
      'Pasang APK versi baru langsung di atas versi lama. Jangan uninstall dulu: uninstall menghapus semua data di HP.'),
  _Faq('Lupa PIN',
      'Kalau sidik jari/wajah aktif, pakai itu lalu ganti PIN di Keamanan. Kalau tidak, PIN tidak bisa dibuka; satu-satunya jalan adalah hapus data app (Info aplikasi → Penyimpanan → Hapus data) lalu pulihkan dari backup. Karena itu backup rutin penting.'),
  _Faq('Kurs mata uang asing',
      'Kurs tidak update otomatis karena Infinity tidak memakai internet. Cek kurs di app bank atau bi.go.id sebulan sekali, lalu ubah di Lainnya → Mata Uang & Kurs. Kalau kurs sudah lebih dari 30 hari, muncul pengingat di Beranda.'),
  _Faq('Apa itu akun "Talangan Patungan"?',
      'Dibuat otomatis saat pertama kali memakai Patungan. Saldonya adalah uang teman yang kamu talangi dan belum dibayar. Saat teman membayar, uangnya pindah dari akun ini ke akun penerima.'),
  _Faq('Kenapa tidak ada sinkron cloud atau login bank?',
      'Supaya data keuangan tidak pernah keluar dari HP. Untuk cadangan, pakai backup terkunci ke Google Drive.'),
  _Faq('Ada yang aneh atau error',
      'Buka Lainnya → Cek kesehatan data untuk mencari transaksi dobel atau kategori hilang. Untuk error, buka Lainnya → Laporan error, simpan ke Download, lalu kirim filenya.'),
];

class HelpPage extends StatelessWidget {
  const HelpPage({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pageBar('Bantuan'),
      body: ListView(
        padding: pagePad(context, 32),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionTitle('Pindah HP'),
                const SizedBox(height: 6),
                for (var i = 0; i < kMoveSteps.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 11,
                          backgroundColor: C.accent.withValues(alpha: 0.2),
                          child: Text('${i + 1}',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: C.accentDark)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(kMoveSteps[i],
                              style: const TextStyle(fontSize: 13, height: 1.35)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              children: [
                for (final f in _faqs)
                  Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      title: Text(f.q,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14)),
                      childrenPadding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.a,
                            style: TextStyle(
                                fontSize: 13, height: 1.4, color: C.muted)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => OnboardingPage(
                    store: store,
                    onDone: () => Navigator.of(context).pop()))),
            icon: const Icon(Icons.slideshow_rounded),
            label: const Text('Lihat lagi panduan awal'),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20))),
          ),
        ],
      ),
    );
  }
}
