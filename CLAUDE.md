# Aturan kerja untuk AI di repo Infinity

Infinity adalah aplikasi catatan keuangan Android (Flutter) yang berjalan offline. Tampilan dalam Bahasa Indonesia, dengan English dan 中文. Pemilik proyek: Jose.

Baca dulu sesuai kebutuhan, jangan semuanya:
- [docs/PRODUK.md](docs/PRODUK.md): apa yang dibuat dan apa yang sengaja tidak.
- [docs/TEKNIS.md](docs/TEKNIS.md): peta kode, data, rumus jatah harian, CI, alur rilis.
- [docs/RENCANA.md](docs/RENCANA.md): status, masalah terbuka, yang ditunda.

## Cara bicara dengan Jose

- Jawab dalam bahasa Indonesia, panggil "Jose". Profesional tapi santai. Tanpa tanda pisah panjang (em dash) dan tanpa kata-kata promosi.
- Jose menyukai sikap skeptis: periksa di kode sebelum menyimpulkan, cari sumber kalau soal fakta di luar kode, dan akui kesalahan. Jose juga bisa keliru. Kalau tidak setuju, katakan beserta buktinya.
- Beri kabar singkat saat pekerjaan panjang. Jangan menceritakan tiap langkah.
- Jujur soal bukti: **CI adalah satu-satunya yang menjalankan kode.** Tidak ada Dart atau Flutter di lingkungan kerja, dan AI tidak bisa melihat app di HP. "Lolos CI" tidak sama dengan "tampilannya benar". Tampilan baru terbukti kalau Jose melihatnya.

## Aturan yang tidak boleh dilanggar

1. **Perubahan tampilan: mockup dulu, kode sesudah Jose setuju.** Termasuk perubahan kecil pada tata letak, warna, atau urutan. Mockup dibuat sebagai halaman HTML, bukan langsung di kode Flutter.
2. **Jangan menambah izin INTERNET** dan jangan menambah paket di luar `tool/versions.env`. CI menolak build yang punya izin INTERNET.
3. **Jangan membuat data pengguna tak terbuka.** Field baru opsional, ditulis ke JSON hanya kalau bukan nilai bawaan, dan wajib ada tes "data lama tetap terbaca". Jangan menyentuh `DataFile`, pembuatan kunci, atau format file tanpa alasan kuat dan tes.
4. **Jangan membuang uang dari hitungan.** Fitur seperti "Di luar jatah harian" boleh mengubah cara uang dibagi ke hari-hari, tidak boleh menyembunyikannya dari total, laporan, atau saldo.
5. **Jangan menyentuh secret** (`DEBUG_KEYSTORE_BASE64`) atau kunci tanda tangan. Kunci yang berbeda membuat APK baru tidak bisa dipasang di atas yang lama.

## Setiap perubahan kode

1. Kerjakan di branch, bukan di `main`. Satu pokok perubahan per rilis.
2. Tambahkan tes di `tests/infinity_test.dart` (grup yang sesuai). Logika baru tanpa tes tidak dianggap selesai.
3. Teks baru di UI: tambahkan terjemahan di `tool/i18n/trN.py` baru (lanjutkan nomor terakhir), lalu generate ulang. Perintahnya ada di bagian "Terjemahan" di [docs/TEKNIS.md](docs/TEKNIS.md).
4. Tambahkan bagian `## Berikutnya (vX.Y.Z)` di paling atas `CHANGELOG.md` dengan *Ditambah / Diubah / Dihapus / Diperbaiki* dan **selalu** satu bagian *Belum terbukti* yang menyebut apa yang belum dilihat di HP.
5. Kalau perilaku yang dilihat pengguna berubah, tambahkan atau perbarui entri di `40_panduan_bantuan.dart`.
6. Tunggu `Tes branch (tanpa rilis)` hijau pada **commit yang sama persis** dengan yang akan digabung (cocokkan `headSha` dan nama job). Jangan melaporkan hijau dari commit lain.
7. Gabung ke `main`, tunggu `Build APK Infinity` hijau, lalu ganti judul heading CHANGELOG jadi `## vX.Y.Z (tanggal)` dalam satu commit khusus dokumen.
8. Perbarui [docs/RENCANA.md](docs/RENCANA.md) kalau status berubah, dan [docs/TEKNIS.md](docs/TEKNIS.md) kalau rumus, model, atau alur berubah.

## Perintah yang berguna

```bash
# status CI sebuah branch
gh run list --branch NAMA --json headSha,status,conclusion,name
# detail rilis (GraphQL diblokir di lingkungan kerja AI, jadi jangan pakai gh release list)
gh api repos/joseyap124/Infinity/releases/tags/vX.Y.Z
# terjemahan
cd tool/i18n && python3 gen.py $(ls tr*.py | sed 's/\.py//' | sort -V | tr '\n' ' ')
```

## Perubahan dokumen

Perubahan yang hanya menyentuh `README.md`, `CHANGELOG.md`, `CLAUDE.md`, dan `docs/**` tidak memicu build APK. Jangan menambahkan berkas lain di root repo tanpa memeriksa `paths-ignore` di `.github/workflows/build-apk.yml`, karena berkas yang tidak masuk daftar itu akan memicu rilis baru.
