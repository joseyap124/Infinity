# Infinity: dokumen produk

Dokumen ini menjawab "apa yang dibuat, untuk siapa, dan apa yang sengaja tidak dibuat". Isinya diambil dari README, CHANGELOG, dan keputusan yang sudah dibuat di percakapan pengembangan. Daftar fitur lengkap ada di [README](../README.md), jadi tidak diulang di sini.

Terakhir disesuaikan dengan v6.6.0 (27 Okt 2026).

## Tujuan

1. **Mencatat uang secepat mungkin.** Target: nominal lalu kategori, dua ketukan.
2. **Menjawab satu pertanyaan setiap hari: berapa yang aman dibelanjakan hari ini.** Angka ini yang pertama terlihat di Beranda.
3. **Data tetap di HP.** APK tidak punya izin INTERNET, data dienkripsi.

## Pengguna

Pemakaian pribadi dan keluarga di Indonesia. Kode menyebut "HP keluarga" (pencatat error dibuat supaya bug di HP keluarga bisa dilacak), jadi app dipakai di lebih dari satu HP. Masukan produk di percakapan pengembangan datang dari Jose.

## Prinsip yang tidak ditawar

| Prinsip | Alasan | Di mana ditegakkan |
|---|---|---|
| Tanpa izin INTERNET | Data keuangan tidak boleh bisa keluar | CI menolak build yang punya izin itu (langkah aapt2 di `build-apk.yml`) |
| Data tidak hilang diam-diam | Kehilangan catatan uang paling merusak kepercayaan | `DataFile` tidak membuat kunci baru kalau file ada; layar "Data tidak bisa dibuka" menggantikan mulai dari kosong |
| Tanpa server dan tanpa login bank | Tidak realistis untuk pemakaian pribadi di Indonesia | Catat otomatis memakai pembacaan notifikasi |
| Tidak menghakimi pengeluaran | Rasa bersalah membuat orang malas mencatat, dan catatan yang kosong lebih buruk dari catatan yang boros | v6.4.0 sampai v6.6.0 (lihat bawah) |
| Warna jenis transaksi: pengeluaran merah, pemasukan hijau, transfer biru | Keputusan Jose setelah mencoba hijau untuk pengeluaran (v6.3.1 dibatalkan di v6.3.2). Nominal di daftar tetap netral supaya merah tidak muncul terus | `TxType.color` dan `TxType.amountColor` di `04_enums.dart` |
| Bahasa Indonesia dulu, ada English dan 中文 | Pemakai utama berbahasa Indonesia | `47_bahasa.dart`, `tool/i18n/` |
| Jujur soal yang belum dites | Tidak ada yang bisa dilihat langsung di HP selain lewat tangkapan layar dari Jose | Bagian "Belum terbukti" di tiap entri CHANGELOG |

## Yang sengaja tidak dibuat

- Server, akun, atau sinkronisasi cloud. Pindah HP lewat backup.
- Login atau sinkron langsung ke bank.
- Penerbitan di Play Store. APK dipasang dari halaman Releases.
- Aplikasi iOS. Ada prototipe web (`build-web.yml`) hanya untuk dicoba, tanpa fitur khusus Android.

## Aturan produk yang paling mudah salah paham

### Jatah harian

- Kalau anggaran diisi: (anggaran periode, dikurangi yang sudah terpakai **sebelum hari ini**, dikurangi tagihan berulang dan cicilan yang belum jatuh tempo) dibagi sisa hari, termasuk hari ini.
- Kalau anggaran kosong: dihitung dari saldo e-wallet, tunai, dan bank (tanpa kartu kredit dan investasi), dikurangi kewajiban yang jatuh tempo sebelum akhir periode.
- Jatah hari ini ditentukan oleh apa yang terjadi **sebelum** hari ini. Belanja hari ini mengurangi sisa hari ini, dan baru memperkecil jatah **besok**.

### Belanja yang disengaja (v6.4.0 dan v6.5.0)

- Saklar **Di luar jatah harian** di form pengeluaran. Transaksi tetap tercatat dan tetap mengurangi anggaran, tapi tidak membuat hari itu berstatus lewat jatah.
- **Anggaran khusus (amplop)** di halaman Anggaran: sejumlah uang di dalam batas total yang disisihkan lebih dulu untuk self reward. Belanja bertanda memakai amplop dan tidak menyentuh jatah harian. Kalau amplop habis, kelebihannya mengurangi jatah seperti belanja biasa.
- Tidak ada uang yang disembunyikan: total terpakai, laporan, dan status anggaran tetap menghitung semuanya.

### Nada saat lewat jatah (v6.6.0)

Label Beranda jadi "Melewati jatah hari ini", angka tidak merah, bar kuning tua, dan ada satu kalimat netral bahwa transaksi tercatat dan jatah besok dihitung ulang. Merah tidak diubah untuk warna jenis pengeluaran, anggaran per kategori yang jebol, dan peringatan lain.

## Masalah produk yang belum selesai

1. **Fitur menumpuk.** Ada tiga ukuran status yang tampil bersamaan (jatah, ritme anggaran, maskot), lima rekap, dan empat sistem ikon. Belum ada keputusan mana yang dipertahankan. Lihat [RENCANA](RENCANA.md).
2. **Beranda baru** (tombol Catat di kartu utama, template cepat, strip kebiasaan mencatat 7 hari, maskot jadi ikon kecil) sudah dibuat mockup-nya tapi belum disetujui, jadi belum dikerjakan.
3. **Belum ada ukuran sukses yang disepakati.** Usulan, bukan keputusan: berapa hari dalam seminggu Jose mencatat, dan apakah mencatat berhenti setelah hari lewat jatah. Datanya hanya bisa diambil dari pemakaian nyata.
