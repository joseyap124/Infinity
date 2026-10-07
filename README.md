<p align="center"><img src="docs/icon.png" width="96" alt="Infinity"></p>

# Infinity 🐷

Aplikasi catatan keuangan Android yang cara catatnya meniru **Money Manager** (baris Tanggal, Jumlah, Kategori, Akun, panel kategori 3 kolom), dengan tampilan bersih ala **Gojek**, plus fitur yang biasanya tidak ada: **catat otomatis dari notifikasi bank/e-wallet**, **import dari Money Manager**, widget, dan pintasan di panel notifikasi.

- **APK Android tanpa izin internet.** Data tidak bisa keluar dari HP, disimpan terenkripsi.
- Tampilan **Bahasa Indonesia**, **mode gelap**, dan **14 warna utama** (termasuk 6 pastel).
- Kategori bawaan mengikuti kategori Money Manager yang biasa dipakai, bisa diubah semua.

![Tampilan Infinity](docs/mockup-infinity.jpg)

> Gambar di atas adalah **mockup dengan data contoh** yang digambar ulang mengikuti tampilan app (lihat `tool/mockup/`), bukan screenshot dari HP.

## Pasang di Android (APK)

1. Buka halaman **[Releases](../../releases)** repo ini dari HP (login GitHub dulu, karena repo-nya private).
2. Unduh **`Infinity.apk`** dari rilis paling atas. `Infinity-hp-lama-32bit.apk` hanya untuk HP lama yang gagal memasang versi biasa.
3. Buka file itu. Kalau Android bertanya, izinkan **"Instal aplikasi tidak dikenal"** untuk browser/Files. Kalau Play Protect memperingatkan, pilih **Tetap instal** (wajar untuk APK di luar Play Store).
4. Pertama kali dibuka, izinkan notifikasi supaya pengingat dan pintasan muncul.

Setiap kali `main` diperbarui, GitHub Actions otomatis membangun APK baru dan menerbitkannya di Releases. Nomor versinya naik satu per rilis (v1.1, v1.2, ...), dan tiap rilis mencantumkan apa yang ditambah, diubah, dihapus, dan diperbaiki (sumbernya [CHANGELOG.md](CHANGELOG.md)).

### Update tanpa kehilangan data

Semua APK ditandatangani dengan **kunci yang sama** (secret `DEBUG_KEYSTORE_BASE64`), jadi versi baru cukup **dipasang di atas** versi lama. Data hilang hanya kalau app di-uninstall, HP di-reset, atau memasang APK yang ditandatangani kunci lain. Untuk jaga-jaga, lihat [Backup & pulihkan](#backup--pulihkan).

## Fitur

### Catat transaksi (ala Money Manager)
- Tab **Pemasukan · Pengeluaran · Transfer**, lalu baris **Tanggal, Jumlah, Kategori, Akun, Catatan, Deskripsi**.
- Selesai mengisi nominal, panel **kategori** langsung terbuka di bawah (dekat jempol, tanpa animasi). Grid 3 kolom; kategori yang punya sub membelah layar: induk di kiri, sub di kanan. Cukup 2 ketukan.
- **Kalkulator** di kolom Jumlah, **template catat cepat** (mis. "Kopi pagi"), dan **Tempel struk**: salin teks struk/notifikasi, nominal, akun, dan kategorinya ditebak otomatis.
- Setelah tersimpan: **edit, duplikat, salin teks transaksi**, atau hapus (geser) dengan tombol Urungkan.

### Akun & transfer
- Akun **E-Wallet, Tunai, Rekening Bank, Kartu Kredit** (limit + tanggal jatuh tempo), **Investasi**.
- **Transfer** antar akun, termasuk beda mata uang (IDR, USD, SGD, MYR, CNY, EUR, JPY) dengan kurs yang bisa diubah.
- Saldo dihitung ulang dari saldo awal + semua transaksi, jadi edit/hapus selalu konsisten.

### Kategori
Bawaannya kategori Money Manager yang biasa dipakai, misalnya Kebutuhan Pokok 📅 (Makan dan Minum, Transportasi, Bills, Kos, Keperluan Rumah), Kesehatan dan Kebersihan 🏥, Education 🏫, Social Dan Relasi 💑, Hiburan dan Gaya Hidup 🛍️, Investasi 💰, Cicilan & Utang 💳, Darurat / Lain lain 🆘, Admin Bank 🏧, dan sisi pemasukan (Main Income, Gift / Support, Passive Income, Cashback / Refund). Semua bisa ditambah, diubah, dan dihapus, lengkap dengan sub-kategori.

### Riwayat, kalender, statistik, anggaran
- **Riwayat**: cari, filter Hari Ini / Minggu Ini / Bulan Ini / Semua, total per hari.
- **Kalender**: pemasukan dan pengeluaran per tanggal.
- **Statistik**: mingguan/bulanan/tahunan, donut per kategori, selisih bersih, rata-rata pengeluaran per hari.
- **Anggaran**: total dan per kategori, dengan status *Aman*, *Mulai Seret*, atau *Jebol*.

### Transaksi berulang & notifikasi
Gaji, kos, langganan, cicilan: harian, mingguan, bulanan, tahunan. Tercatat otomatis saat jatuh tempo. Notifikasi (bisa diatur satu per satu):

| Notifikasi | Kapan |
|---|---|
| Transaksi berulang | sehari sebelum (bulanan/tahunan) dan saat jatuh tempo |
| Tagihan kartu kredit | 3 hari sebelum dan saat jatuh tempo |
| Peringatan anggaran | saat status berubah jadi Seret atau Jebol |
| Pengingat harian | setiap hari, jam bisa diatur (bawaan 20.00) |

Nominal di notifikasi disembunyikan secara bawaan.

### Catat otomatis dari notifikasi bank & e-wallet
Infinity membaca notifikasi yang berisi nominal "Rp" dari GoPay, OVO, DANA, ShopeePay, LinkAja, myBCA/BCA, Jago, BRImo, Livin Mandiri, BNI, SeaBank, blu, dan Flip, lalu:
- **Langsung catat** kalau akunnya bisa ditebak (beri nama akun yang memuat nama aplikasinya, mis. "GoPay", "BCA").
- Masuk ke kartu **Dari Notifikasi** di Beranda kalau akunnya tidak jelas atau sepertinya sudah kamu catat manual (nominal dan akun sama dalam 10 menit).
- Notifikasi promo diabaikan. Mode: Mati / Tanya dulu / Langsung catat.

Android 13+ memblokir akses notifikasi untuk APK di luar Play Store. Caranya: coba aktifkan sekali, lalu buka **Info aplikasi Infinity → ⋮ → Izinkan setelan terbatas**, dan aktifkan lagi. Panduannya ada di halaman Catat Otomatis.

### Pintasan & widget
- **Pintasan di panel notifikasi** (seperti Money Manager): ikon **Riwayat, Cari, Template, ＋**. Bisa dimatikan di Lainnya → Notifikasi.
- **Widget 4×2** di layar utama: saldo bersih, masuk/keluar bulan ini, sisa anggaran, dan tombol **Keluar · Masuk · Transfer**. Ikut mode gelap HP.

### Tampilan & Beranda
- **Ikut HP / Terang / Gelap**. Warna di mode gelap dihitung ulang supaya teks tetap terbaca (kontras teks minimal 4,5:1).
- **Warna utama**: Hijau, Tosca, Biru, Indigo, Ungu, Oranye, Pink, Grafit, dan pastel Sage, Lavender, Rose, Peach, Langit, Mint. Pemasukan tetap hijau dan pengeluaran tetap merah apa pun warnanya.
- **Atur Beranda** (ketuk logo/nama): foto dari galeri, nama, dan kalimat di bawah nama: sapaan sesuai jam, tulis sendiri, atau **motivasi harian** (30 kalimat, berganti tiap hari, tanpa internet).

### Import dari Money Manager
Lainnya → **Import dari Money Manager** → pilih file `.xlsx` hasil *Money Manager › Backup › Ekspor ke Excel*.
- Pratinjau dulu: rentang tanggal, jumlah pengeluaran/pemasukan/transfer, akun dan kategori baru.
- Akun dan kategori dicocokkan berdasarkan nama, tanpa peduli emoji, spasi, atau keterangan dalam kurung ("Health (Obat , Vitamin)💊" = "Health (Obat, Vitamin) 💊"). Yang belum ada dibuat otomatis.
- `Transfer-Out` jadi transfer antar akun. Import file yang sama dua kali **tidak** membuat transaksi dobel.
- File ekspor tidak berisi saldo awal, jadi setelah import cocokkan saldo awal tiap akun di **Akun & Dompet**.

## Keamanan

- **Tanpa izin INTERNET** di APK: secara teknis app tidak bisa mengirim data ke mana pun.
- Data disimpan terenkripsi (`flutter_secure_storage`, kunci di Android Keystore). `allowBackup` dimatikan.
- **PIN** + **sidik jari/wajah**. Diminta saat app dibuka dan saat kembali setelah 30 detik di latar belakang. Salah 5 kali = jeda 30 detik.
- **Mode layar aman** (opsional): sembunyikan isi app di daftar aplikasi terbaru dan blokir screenshot.
- Yang tetap perlu dijaga: file backup di folder Download **tidak terenkripsi**, dan file kunci `DEBUG_KEYSTORE_BASE64` jangan dibagikan.

## Backup & pulihkan

Lainnya → **Backup & Pulihkan**:
- **Backup otomatis mingguan** ke `Download/Infinity/infinity-backup-<tanggal>.json`. File ini tetap ada walau app di-uninstall. Bisa dimatikan, atau tekan **Backup sekarang**.
- **Salin backup**: data sebagai teks JSON ke clipboard (dihapus otomatis dari clipboard setelah 60 detik).
- **Pulihkan**: tempel isi JSON. PIN dan setelan keamanan tidak ikut ditimpa.
- **Reset semua data**: harus mengetik `HAPUS` dulu supaya tidak terpencet.

## Build sendiri

APK dibangun oleh `.github/workflows/build-apk.yml`:

1. `flutter create` proyek Android baru, pasang paket (`flutter pub add ...`).
2. `tool/setup_android.py` menyalin `android_overlay/` (Kotlin, manifest, widget, ikon, tema) dan menyetel Gradle (desugaring, minSdk 24, tanda tangan dari `INFINITY_KEYSTORE`).
3. `flutter analyze`, lalu `flutter build apk --release --split-per-abi`.
4. APK diterbitkan di Releases. Kalau gagal, log `analyze.txt`/`build.txt` disimpan di branch **`ci-logs`**.

Secret yang dipakai: **`DEBUG_KEYSTORE_BASE64`** (keystore dalam base64, alias `androiddebugkey`, password `android`). Tanpa secret ini APK tetap jadi, tapi tiap build punya tanda tangan berbeda.

Di PC: butuh Flutter 3.38.1+ dan Android SDK. Jalankan langkah yang sama seperti di workflow.

## Keputusan desain

- **Satu file `lib/main.dart`.** Spesifikasi awalnya meminta satu file; dipertahankan supaya mudah dibaca dan disalin.
- **Tanpa server dan tanpa login bank.** Sinkron bank langsung tidak realistis untuk pemakaian pribadi di Indonesia, jadi yang dipakai adalah pembacaan notifikasi.
- **Angka di bawah 1.000 tanpa satuan dianggap ribuan** saat membaca teks cepat ("25 nasgor" = Rp25.000), karena nominal Rupiah sekecil itu hampir tidak pernah dipakai.
- **Transfer-In dari Money Manager dilewati**, karena pasangannya (Transfer-Out) sudah dicatat sebagai satu transfer.
- **Pemilih file memakai pemilih bawaan Android** (bukan paket `file_picker`), karena `file_picker` 13 butuh Android SDK 37 yang belum didukung alat build Flutter.
- **Warna di mode gelap** dihitung ulang, bukan dibalik, supaya tombol berwarna dengan tulisan putih tetap terbaca.

## Belum dites di HP sungguhan

- Pembacaan notifikasi bank/e-wallet masih tebakan berdasarkan pola umum. Kalau ada notifikasi yang salah terbaca, kirim contoh teksnya.
- Tampilan widget dan pintasan notifikasi bisa sedikit berbeda antar merek HP (Xiaomi/Oppo/Vivo juga perlu Baterai: *Tanpa batasan* supaya pengingat tepat waktu).

## Struktur folder

```
lib/main.dart                     seluruh kode Dart (model, penyimpanan, UI, import Money Manager)
android_overlay/app/src/main/
  AndroidManifest.xml             izin, listener notifikasi, widget
  kotlin/.../MainActivity.kt      channel native: layar aman, akses notifikasi, simpan ke Download, pilih file
  kotlin/.../NotificationCaptureService.kt   tangkap notifikasi berisi "Rp"
  kotlin/.../QuickBar.kt          notifikasi pintasan 4 ikon
  kotlin/.../InfinityWidgetProvider.kt       widget 4x2
  res/                            layout widget & pintasan, ikon celengan, warna terang/gelap
tool/setup_android.py             pasang android_overlay ke proyek hasil flutter create
tool/make_icons.py                gambar ikon celengan (vector adaptif + PNG)
tool/mockup/                      generator gambar mockup di README
docs/                             ikon & mockup untuk README
.github/workflows/build-apk.yml   build APK + rilis + simpan log kegagalan
```
