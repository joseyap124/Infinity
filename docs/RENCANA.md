# Infinity: rencana dan status

Daftar kerja yang bisa dicentang. Perbarui setiap rilis: pindahkan yang selesai ke "Selesai", tulis apa yang belum terbukti. Riwayat lengkap tiap rilis ada di [CHANGELOG](../CHANGELOG.md).

Terakhir diperbarui: v7.0.2 (1 Nov 2026).

## Cara membaca status

- **Lolos CI** artinya terkompilasi dan semua tes hijau. Itu tidak membuktikan tampilannya benar.
- **Terlihat di HP** artinya Jose sudah melihatnya, biasanya lewat tangkapan layar. Hanya v6.3.2 yang sudah pernah dilihat sampai sekarang.

## Selesai (lolos CI, belum terlihat di HP kecuali disebut)

- [x] v6.3.1 sampai v6.3.3: form Catat gaya Infinity (kartu bulat, ikon bulat 4 kolom, tombol 54/22, warna sesuai jenis transaksi, chip nominal di panel keypad). v6.3.2 sudah terlihat di HP lewat tangkapan layar; v6.3.3 belum.
- [x] v6.4.0: saklar "Di luar jatah harian" di form pengeluaran.
- [x] v6.5.0: anggaran khusus (amplop) di halaman Anggaran, tampil di Beranda dan form Catat.
- [x] v6.6.0: Beranda lebih tenang saat lewat jatah, dua kalimat maskot dilembutkan.
- [x] v6.7.0: tombol "Jangan tangkap app ini" di kartu Dari Notifikasi (Infinity menangkap notifikasi dari semua app yang memuat "Rp", bukan hanya bank). README bagian itu sudah dikoreksi.
- [x] v6.8.0: kartu utama menjelaskan Rp 0 saat anggaran habis; jejak simpan dirapikan; tes yang membuktikan lompatan sisa hari ini saat tagihan berulang diposting.
- [x] v7.0.0: Beranda baru dan navigasi baru. Ritme di kartu utama, maskot satu baris, header dan empat pintasan dihapus, mata dan gerigi di kartu utama, bar bawah empat tab dengan Catat di tengah, Lainnya jadi Pengaturan, daftar Perlu perhatian ringkas, kartu informasi cukup ditutup sekali, anggaran 174% dan warna kuning tua di Rencana, catatan golongan di Statistik, keterangan dipersingkat.
- [x] v7.0.1: form Catat boleh memilih tanggal sampai 60 hari ke depan (transaksi biasa, langsung masuk saldo). Opsi "jadwal sekali" (saldo naik di tanggalnya) sempat dimockup, tidak dipilih karena gaji berubah tiap bulan.
- [x] v7.0.2: pengenal app bank cocok per segmen nama paket (lenovo tidak lagi dianggap OVO, danamon bukan DANA); fungsi tak terpakai dihapus.

## Perlu dicek di HP (urutkan dari yang paling mungkin meleset)

- [ ] v7.0.0: seluruh tampilan baru belum pernah dilihat di HP. Paling mungkin meleset: bar bawah (tinggi, tombol Catat, label di layar sempit atau huruf besar), letak mata dan gerigi di kartu utama, baris Perlu perhatian, baris maskot, halaman Pengaturan.
- [ ] v6.7.0: tombol baru di baris Abaikan/Catat di layar sempit, dan apakah notifikasi app non-bank berhenti masuk setelah diabaikan.
- [ ] v6.5.0: baris amplop di Beranda dan di form Catat; apakah penjelasannya cukup jelas tanpa dibaca dua kali.
- [ ] v6.6.0: apakah Beranda saat lewat jatah benar-benar terasa tenang. Gambar maskot Bahaya dan Boros **tidak diubah**; kalau tetap mengganggu, matikan maskot di Atur beranda atau matikan nada paket.
- [ ] v6.3.3: ruang kosong di atas keypad setelah nominal terisi, dan form yang bergeser sekitar 45 dp saat berpindah ke daftar kategori.
- [ ] v6.3.1: tinggi panel di layar kecil, nama kategori dua baris, kontras kartu isian di tema terang.

## Masalah terbuka

### 1. "Jatah hari ini" di Beranda tidak cocok dengan hitungan Jose

Penyebab ditemukan di v6.8.0 lewat tes (CI hijau). **Terbukti:** transaksi berulang yang jatuh tempo hari ini punya dua keadaan.

- Sebelum diposting, tagihan itu dikurangkan dari `base` lewat `upcomingRecurring`, jadi jatah hari ini turun sebesar tagihan dibagi sisa hari.
- Setelah diposting (`processRecurring`, saat app dibuka setelah jam jatuh tempo), tagihan itu masuk `spentToday` sebagai pengeluaran biasa, jadi sisa hari ini turun sebesar **seluruh** tagihan.

Dengan sisa hari D > 1, angka "sisa hari ini" lebih rendah sebesar tagihan × (1 - 1/D) setelah posting dibanding sebelumnya. Pengguna melihat angka melompat tanpa melakukan apa pun.

Cara membuktikan: tulis tes di grup `Aman dibelanjakan & insight` yang membuat satu aturan berulang bernilai jatuh tempo hari ini, hitung `safeToSpend` sebelum dan sesudah `processRecurring`, lalu bandingkan `leftToday`. Cara lain yang tidak butuh kode: Jose mengirim tangkapan layar Beranda dengan angka yang dianggap salah, bersama daftar transaksi hari itu dan transaksi berulang yang aktif.

Kalau dugaan ini benar, itu keputusan produk, bukan sekadar bug: apakah tagihan hari ini sebaiknya mengurangi sisa hari ini sepenuhnya, atau dibagi rata seperti sekarang sebelum diposting.

### 2. Dua penulis ke file data

Pernah teramati bahwa file data ditulis oleh dua proses sekaligus (bukan kesimpulan dari kode). Penyebab belum diketahui. Pengaman yang sudah ada: `_mergeForeign` dan `mergeThreeWay` menggabung tiga arah dan menyimpan salinan file lain. Belum diketahui apakah pengaman itu cukup di semua kasus.

### 3. Perbaikan v6.2.1 (error null check)

Belum dibuktikan di HP. Cara cek: ketuk widget atau pintasan *Catat pengeluaran*, lalu lihat apakah jumlah error di Laporan error bertambah.

### 4. Branch lama di remote

Per 1 Nov 2026 ada 80 branch di remote. 75 di antaranya sudah masuk `main` (diperiksa dengan `git merge-base --is-ancestor`), jadi menghapusnya tidak menghilangkan kode; commit-nya tetap ada di `main`. Dua branch belum masuk dan **tidak boleh dihapus tanpa keputusan Jose**: `teks-kategori` (v6.2.4, kategori di form Catat jadi chip teks dua kolom tanpa ikon) dan `v6.2.2` (hapus pintasan di ikon app; berbeda dari rilis v6.2.2 yang sebenarnya). Jangan hapus `main`, `ci-logs`, `ci-out`. Penghapusan massal lewat sesi AI diblokir oleh pemeriksa izin, jadi perlu dijalankan Jose atau diizinkan secara eksplisit.

## Ditunda sampai Jose menyetujui mockup

Aturan kerja: perubahan tampilan selalu mockup dulu, lalu kode.

- [x] **Beranda baru**: disetujui dan dikerjakan di v7.0.0. Yang ditolak atau ditunda: pemilih bank dan e-wallet (nilainya kecil, tidak boleh memakai logo asli), strip kebiasaan 7 hari, "mode sederhana", maskot jadi ikon kecil.
- [ ] **Merapikan fitur yang tumpang tindih**: tiga ukuran status (jatah, ritme, maskot), lima rekap, empat sistem ikon (kartun, flat, klasik, mono). Perlu keputusan mana yang dipertahankan sebelum ada yang dihapus. Hapus berarti data pengaturan lama harus tetap terbaca (lihat aturan kompatibilitas di [TEKNIS](TEKNIS.md)).

- [ ] **Keputusan Jose: tagihan berulang yang diposting hari ini.** Usulan: tagihan yang sudah dicadangkan tidak dihitung lagi sebagai belanja hari itu, supaya "sisa hari ini" tidak melompat (lihat Masalah terbuka 1). Mengubah hitungan jatah, jadi perlu persetujuan.

## Dokumentasi

- [x] Dokumen produk, teknis, rencana, dan aturan kerja AI (`CLAUDE.md`).
- [x] README disegarkan (v7.0.2+): navigasi baru, Rencana, Ritme dan Maskot, tanggal ke depan, jalur "Beranda → gerigi", backup harian (14 salinan). Catatan: klaim lama "README salah menyebut 14 warna" ternyata keliru, jumlahnya memang 14 (8 + 6 pastel).
- [x] Komentar pembuka `lib/main.dart` diperbarui (satu library dengan banyak `part`, Flutter 3.47.6).
- [x] `tool/i18n/README.md` diperbarui dengan perintah yang benar.
