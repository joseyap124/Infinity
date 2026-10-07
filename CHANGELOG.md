# Catatan rilis Infinity

Setiap rilis mencatat apa yang **ditambah**, **diubah**, **dihapus**, dan **diperbaiki**.
Bagian *Berikutnya* berisi perubahan yang akan masuk rilis selanjutnya.

## Berikutnya

### Ditambah
- **Saran dari ketikan sebelumnya**: di kolom *Catatan* dan *Deskripsi*, ketik beberapa huruf (mis. "pot") dan muncul yang pernah kamu ketik ("Potong rambut"), diurutkan dari yang paling sering dipakai. Memilih saran Catatan juga mengisi kategori dan akun dari transaksi terakhir dengan catatan yang sama.

## v1.2 (7 Okt 2026)

### Ditambah
- **Kalkulator di Akun & Dompet**: kolom *Saldo sekarang* / *Tagihan* dan *Limit kartu* punya tombol kalkulator, sama seperti saat mencatat transaksi. Hasil hitungan langsung masuk ke kolom, dan kalau saldo berubah tetap ditanya mau dicatat sebagai transaksi atau ubah saldo awal saja.

## v1.1 (7 Okt 2026)

### Ditambah
- **Import dari Money Manager**: Lainnya → Import dari Money Manager, pilih file `.xlsx` hasil *Ekspor ke Excel*. Ada pratinjau dulu; akun dan kategori dicocokkan otomatis, yang belum ada dibuat. Import ulang file yang sama tidak membuat transaksi dobel.
- **Akun utama**: ketuk ☆ di Akun & Dompet, akun itu otomatis terpilih saat mencatat transaksi baru.
- **Urutkan akun**: tahan lama kartu akun atau tarik ikon ⠿ di Akun & Dompet.
- **Penyesuaian saldo ala Money Manager**: edit akun sekarang menampilkan *Saldo sekarang*. Kalau diubah, pilih *Catat transaksi* (masuk Riwayat sebagai "Penyesuaian saldo") atau *Ubah saldo awal* saja.
- **Mode gelap** (Ikut HP / Terang / Gelap) dan **warna utama**: 8 warna biasa + 6 pastel (Sage, Lavender, Rose, Peach, Langit, Mint).
- **Atur Beranda**: foto profil dari galeri, nama sendiri, dan kalimat di bawah nama (sapaan jam, tulis sendiri, atau motivasi harian).
- **Pintasan di panel notifikasi** ala Money Manager: Riwayat, Cari, Template, ＋.
- **Backup otomatis mingguan** ke `Download/Infinity`, plus tombol *Backup sekarang*.
- **Reset semua data** dengan konfirmasi mengetik `HAPUS`.
- Nomor versi tampil di bawah halaman Lainnya.

### Diubah
- **Form catat** dibuat seperti Money Manager: baris Tanggal, Jumlah, Kategori, Akun, Catatan, Deskripsi.
- **Panel kategori** muncul di bawah tanpa animasi, tingginya pas dengan isi, dan terbuka sendiri setelah nominal diisi. Kategori yang punya sub membelah layar (induk kiri, sub kanan).
- **Hapus dengan geser** harus digeser lebih jauh dan **selalu dikonfirmasi** dulu. Notifikasi *Transaksi dihapus* dengan tombol *Urungkan* dibuat lebih jelas.
- **Hapus akun** sekarang menampilkan saldo dan jumlah transaksi yang ikut terhapus sebelum dikonfirmasi.
- **Warna utama** dipilih lewat ketukan (tidak langsung menampilkan semua pilihan).
- Header Beranda dan kartu akun dibuat lebih ringkas.
- **Ikon app** jadi celengan babi dengan latar gelap; widget ikut mode gelap HP.
- **Screenshot** sekarang boleh dari awal (Mode layar aman bisa dinyalakan di Keamanan).
- Install baru mulai **kosong**, tanpa data demo.

### Dihapus
- Data demo bawaan dan tombol *Muat ulang data demo*.
- Fitur ketik nominal langsung di notifikasi (diganti pintasan 4 ikon).

### Diperbaiki
- Pintasan notifikasi tidak muncul di sebagian HP (Huawei/Honor/Xiaomi): sekarang tampil normal tanpa suara, terpisah dari saklar pengingat, dan muncul lagi setelah HP restart.
- Teks cepat seperti "25 rbu nasgor" terbaca Rp25: sekarang `rbu/rebu/ribuan/k` dibaca ribu, `jt/jta/juta` dibaca juta.

