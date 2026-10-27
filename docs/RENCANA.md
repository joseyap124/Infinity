# Infinity: rencana dan status

Daftar kerja yang bisa dicentang. Perbarui setiap rilis: pindahkan yang selesai ke "Selesai", tulis apa yang belum terbukti. Riwayat lengkap tiap rilis ada di [CHANGELOG](../CHANGELOG.md).

Terakhir diperbarui: setelah v6.6.0 (27 Okt 2026).

## Cara membaca status

- **Lolos CI** artinya terkompilasi dan semua tes hijau. Itu tidak membuktikan tampilannya benar.
- **Terlihat di HP** artinya Jose sudah melihatnya, biasanya lewat tangkapan layar. Hanya v6.3.2 yang sudah pernah dilihat sampai sekarang.

## Selesai (lolos CI, belum terlihat di HP kecuali disebut)

- [x] v6.3.1 sampai v6.3.3: form Catat gaya Infinity (kartu bulat, ikon bulat 4 kolom, tombol 54/22, warna sesuai jenis transaksi, chip nominal di panel keypad). v6.3.2 sudah terlihat di HP lewat tangkapan layar; v6.3.3 belum.
- [x] v6.4.0: saklar "Di luar jatah harian" di form pengeluaran.
- [x] v6.5.0: anggaran khusus (amplop) di halaman Anggaran, tampil di Beranda dan form Catat.
- [x] v6.6.0: Beranda lebih tenang saat lewat jatah, dua kalimat maskot dilembutkan.

## Perlu dicek di HP (urutkan dari yang paling mungkin meleset)

- [ ] v6.5.0: baris amplop di Beranda dan di form Catat; apakah penjelasannya cukup jelas tanpa dibaca dua kali.
- [ ] v6.6.0: apakah Beranda saat lewat jatah benar-benar terasa tenang. Gambar maskot Bahaya dan Boros **tidak diubah**; kalau tetap mengganggu, matikan maskot di Atur beranda atau matikan nada paket.
- [ ] v6.3.3: ruang kosong di atas keypad setelah nominal terisi, dan form yang bergeser sekitar 45 dp saat berpindah ke daftar kategori.
- [ ] v6.3.1: tinggi panel di layar kecil, nama kategori dua baris, kontras kartu isian di tema terang.

## Masalah terbuka

### 1. "Jatah hari ini" di Beranda tidak cocok dengan hitungan Jose

Penyebab belum diketahui. **Dugaan dari membaca kode, belum dibuktikan:** transaksi berulang yang jatuh tempo hari ini punya dua keadaan.

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

Ada 73 branch di remote; sebagian besar branch rilis lama (`v3`, `v5.x`, dan seterusnya) yang sudah digabung. Nilai membersihkannya kecil. Kalau dilakukan, cek dulu bahwa tiap branch sudah masuk `main`, dan jangan hapus `main`, `ci-logs`, `ci-out`.

## Ditunda sampai Jose menyetujui mockup

Aturan kerja: perubahan tampilan selalu mockup dulu, lalu kode.

- [ ] **Beranda baru**: tombol Catat di kartu utama, template cepat, strip kebiasaan mencatat 7 hari, maskot jadi ikon kecil. Mockup ada (artifact "Beranda Baru"), belum disetujui.
- [ ] **Merapikan fitur yang tumpang tindih**: tiga ukuran status (jatah, ritme, maskot), lima rekap, empat sistem ikon (kartun, flat, klasik, mono). Perlu keputusan mana yang dipertahankan sebelum ada yang dihapus. Hapus berarti data pengaturan lama harus tetap terbaca (lihat aturan kompatibilitas di [TEKNIS](TEKNIS.md)).

## Dokumentasi

- [x] Dokumen produk, teknis, rencana, dan aturan kerja AI (`CLAUDE.md`).
- [ ] README masih menyebut "14 warna", versi rilis `v1.6, v1.7, ...`, dan belum memuat fitur v5 sampai v6 (maskot, ritme, amplop, Rencana). Perlu disegarkan.
- [ ] Komentar pembuka `lib/main.dart` menyebut "single-file" dan "Flutter 3.38.1+", sudah tidak sesuai (sekarang banyak `part`, Flutter 3.47.6).
- [ ] `tool/i18n/README.md` menyebut `/tmp/claude-0/i18n` untuk import, dan contoh perintahnya hanya sampai `tr5` (sekarang sampai `tr35`); perlu disesuaikan.
