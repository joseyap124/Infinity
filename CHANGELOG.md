# Catatan rilis Infinity

Setiap rilis mencatat apa yang **ditambah**, **diubah**, **dihapus**, dan **diperbaiki**.
Bagian *Berikutnya* berisi perubahan yang akan masuk rilis selanjutnya.

## Berikutnya (v3.0)

Versi matang untuk dipakai lama tanpa update: fokusnya data aman, tahan HP Android baru, dan bisa dirawat tanpa bertanya.

### Ditambah
- **Panduan pertama kali**: install baru disambut 4 layar singkat (cara kerja Infinity, isi akun & saldo, aktifkan catat otomatis, pasang PIN & kata sandi backup) dengan tombol langsung ke halamannya. Pengguna lama tidak melihatnya; bisa dibuka lagi dari Bantuan.
- **Bantuan** (Lainnya → Bantuan): langkah pindah HP dan FAQ (arti "Aman dibelanjakan", catat otomatis tidak jalan, nominal salah, backup, update tanpa hapus data, lupa PIN, kurs, Talangan Patungan, laporan error).
- **Cek kesehatan data** (Lainnya): mencari kemungkinan transaksi dobel, transaksi yang kategorinya sudah dihapus (bisa diperbaiki sekali tekan), saldo minus yang tidak wajar, talangan patungan yang tidak cocok dengan piutangnya, transaksi bertanggal jauh ke depan, dan backup yang sudah lama.
- **Laporan error** (Lainnya): error app dicatat ke file di HP (tidak dikirim ke mana pun), bisa disimpan ke Download atau disalin untuk dikirim. Bagian layar yang gagal digambar sekarang menampilkan pesan yang jelas, bukan kotak abu-abu.
- **Rekap tahunan** (Statistik → Rekap tahun): pemasukan, pengeluaran, porsi yang ditabung, rata-rata keluar per hari, bulan paling boros & paling hemat, pengeluaran terbesar, kategori dan catatan dengan pengeluaran terbesar, grafik per bulan, serta kekayaan bersih awal vs akhir tahun. Tahun lain bisa dipilih.
- **Langkah pindah HP** juga ada di halaman Backup & Pulihkan.
- **Rekap & saran bulanan** (Statistik mode Bulan → *Rekap & saran*, atau kartu di Beranda pada awal bulan): angka bulan itu dibanding bulan lalu dan rata-rata 3 bulan, **tingkat menabung 1–7** (Defisit besar, Tekor tipis, Baru mulai menabung, Lumayan, Bagus!, Luar biasa! 🎉, Juara menabung! 🏆), lalu daftar **yang perlu diperbaiki** dan **yang sudah bagus** (dipuji). Sarannya dihitung dari datamu: pengeluaran lebih besar dari pemasukan, pengeluaran atau kategori yang naik (lengkap dengan saran anggaran dan tips), jajan kecil yang menumpuk, anggaran jebol atau terjaga, dana darurat (target 3–6 bulan pengeluaran), tagihan rutin terhadap pemasukan, piutang yang belum ditagih, dan utang jatuh tempo. Bulan berjalan memakai perkiraan dari laju sejauh ini.

### Diubah
- **Backup lebih aman**: backup otomatis menyimpan **8 backup terakhir** di Download/Infinity (yang lebih lama dihapus otomatis, hanya file buatan Infinity), dan setiap backup **dicoba dibuka dulu** sebelum disimpan supaya tidak ada backup rusak.
- **Lebih cepat untuk data besar**: saldo semua akun dihitung sekali jalan dan disimpan sampai data berubah. Diuji dengan 20.000 transaksi selama 5 tahun: semua hitungan Beranda, statistik, dan cek kesehatan selesai sekitar 0,1 detik.
- **Siap Android 15/16**: isi halaman tidak lagi tertutup tombol navigasi sistem (tampilan layar penuh/edge-to-edge), dan setiap build dicek bahwa library native rata 16 KB (syarat HP baru dengan halaman memori 16 KB).
- **Build dikunci**: versi Flutter (3.47.6) dan semua paket dikunci, jadi APK bisa dibangun ulang kapan pun dengan hasil yang sama walau paket di internet sudah berubah.

## v2.7 (8 Okt 2026)

### Ditambah
- **Acara** (Lainnya → Acara): buat acara seperti "Trip Bali" atau "Lebaran" dengan tanggal mulai–selesai dan anggaran (opsional). Transaksi bisa ditandai lewat baris *Acara* di form catat; selama acara berlangsung, transaksi baru otomatis ditandai (bisa dimatikan per acara). Halaman acara menampilkan total, sisa anggaran, rincian per kategori, dan semua transaksinya. Refund yang ditandai acara mengurangi total. Kalau anggaran acara terpakai 80% atau lebih, muncul kartu di *Perlu perhatian*. Menghapus acara tidak menghapus transaksinya.
- **Kekayaan bersih per bulan** (Statistik): grafik total saldo semua akun di akhir tiap bulan selama 12 bulan terakhir, dengan selisih dari bulan lalu dan dalam 12 bulan. Kartu kredit dihitung minus; akun mata uang asing memakai kurs sekarang.
- **Perkiraan saldo akhir bulan per akun**: di riwayat akun (bulan berjalan) muncul *Perkiraan akhir bulan* dari transaksi berulang yang belum tercatat (gaji, kos, isi saldo rutin, dll.); ketuk untuk melihat jadwalnya. Kalau ada akun yang diperkirakan minus sebelum akhir bulan, muncul peringatan di *Perlu perhatian*.

### Diperbaiki
- **Patungan**: setelah menekan Enter di kolom nama teman, kursor tetap di kolom itu supaya bisa langsung mengetik teman berikutnya. Piutang dari patungan sekarang menampilkan keterangannya (mis. "Patungan: Makan malam").

## v2.6 (8 Okt 2026)

### Ditambah
- **Patungan / split bill** (Lainnya → Patungan, atau tombol *Patungan* di Utang & Piutang): isi total tagihan, akun yang dipakai bayar, dan nama teman. Dibagi rata (sisa pembulatan masuk bagianmu) atau atur bagian masing-masing. Bagianmu dicatat sebagai **pengeluaran**; bagian teman dipindah ke akun **Talangan Patungan** dan tiap teman jadi **piutang**. Jadi saldo akun pembayar turun sesuai yang benar-benar keluar, sementara statistik dan anggaran hanya menghitung bagianmu. Saat teman bayar (*Terima pembayaran* atau *Tandai lunas*), kamu pilih uangnya masuk ke akun mana, dan uangnya pindah dari Talangan ke akun itu.
- **Pilih bulan langsung di riwayat akun**: ketuk nama bulan untuk melompat ke bulan mana saja (lengkap dengan jumlah transaksinya), atau pilih **Semua** untuk melihat seluruh riwayat akun sekaligus.
- **Akun yang tidak dihitung di "Aman dibelanjakan"**: di edit akun ada saklar *Jangan hitung di "Aman dibelanjakan"* untuk rekening tabungan atau dana darurat. Saldonya tetap masuk total saldo, tapi tidak dianggap uang belanja. Rinciannya menyebut berapa yang tidak dihitung.
- **Pengingat kurs**: halaman Mata Uang & Kurs menampilkan kapan kurs terakhir diperbarui, plus tombol *Isi kurs BI 7 Okt 2026*. Kalau ada akun mata uang asing dan kurs belum diperbarui lebih dari 30 hari, muncul kartu di *Perlu perhatian*.

### Diubah
- **Kurs bawaan diperbarui** ke kurs tengah Bank Indonesia 7 Okt 2026: USD Rp17.910, SGD Rp14.008, MYR Rp4.383, CNY Rp2.671, AUD Rp12.496, EUR Rp20.133, JPY Rp113,28 (TWD tetap Rp564). Sebelumnya USD masih Rp16.300. Kurs yang sudah tersimpan di HP tidak berubah sendiri; pakai tombol *Isi kurs BI* lalu *Simpan Kurs*.

## v2.5 (8 Okt 2026)

### Ditambah
- **Riwayat per akun**: ketuk akun (mis. SeaBank, BCA) di Beranda atau di Kelola Akun untuk melihat semua transaksinya per bulan, dikelompokkan per hari, lengkap dengan saldo setelah tiap transaksi (seperti buku tabungan). Di atasnya ada saldo sekarang serta total masuk dan keluar bulan itu. Transfer ditampilkan dari sisi akun: keluar minus, masuk plus. Edit akun lewat tombol ✏️ di pojok kanan atas, dan tombol *Catat* langsung memakai akun itu.
- **Dolar Australia (AUD, A$)** sebagai mata uang akun dan transfer. Kurs awal 1 AUD = Rp12.460 (kurs 7 Okt 2026), bisa diubah di Lainnya → Mata Uang & Kurs.

### Diubah
- Ketuk akun di Beranda sekarang membuka riwayatnya, bukan langsung form edit.

## v2.4 (8 Okt 2026)

### Diubah
- **Catat Cepat di Beranda lebih rapi**: template tampil sebagai tombol 2 kolom dengan lebar sama (ikon, nama, nominal), bukan lagi chip yang lebarnya mengikuti panjang teks sehingga sisi kanannya bolong. Maksimal 6 tombol; sisanya lewat *Semua*.
- Jarak antar bagian di bawah Beranda diseragamkan.
- **Halaman Template lebih lega**: tombol edit dan hapus digabung ke menu ⋮, nama panjang tidak lagi turun baris, dan menghapus template sekarang minta konfirmasi dulu.

## v2.3 (8 Okt 2026)

### Ditambah
- **Simpan backup ke Google Drive** (Backup & Pulihkan): membuka layar simpan Android, lalu pilih Google Drive. Upload dikerjakan app Drive, jadi Infinity tetap tanpa izin internet dan tanpa login Google. Yang dikirim selalu backup terkunci kata sandi (`.infb`), jadi isinya tidak bisa dibaca Google. Memulihkan cukup lewat *Pulihkan dari file* lalu pilih dari Drive.

## v2.2 (8 Okt 2026)

### Diubah
- **Template catat cepat bisa diedit**: di Lainnya → Template ada tombol ✏️ untuk mengubah nama, nominal, kategori, dan akun template tanpa harus menghapus lalu membuat baru.

## v2.1 (8 Okt 2026)

### Diubah
- **Splash animasi koin cuma sekali**: diputar hanya saat app pertama kali dibuka setelah dipasang. Setelah itu app langsung masuk ke Beranda (atau PIN). Yang sudah memakai versi sebelumnya tidak akan melihatnya lagi.

## v2.0 (8 Okt 2026)

### Ditambah
- **Aman dibelanjakan hari ini**: angka utama di Beranda. Kalau anggaran diatur, sisa anggaran dibagi sisa hari periode. Kalau belum, dihitung dari saldo e-wallet, tunai, dan bank, ditambah pemasukan berulang, dikurangi tagihan kartu kredit, utang yang jatuh tempo, setoran target tabungan, serta tagihan dan langganan berulang sampai akhir bulan. Ketuk kartunya untuk melihat rinciannya.
- **Perlu perhatian**: deretan kartu di Beranda untuk hal yang butuh tindakan, yaitu utang/piutang dan tagihan berulang yang jatuh tempo ≤3 hari, tagihan kartu kredit, target tabungan yang tenggatnya dekat, dan pengeluaran yang sedang tidak biasa. Kartu bisa ditutup (muncul lagi besok kalau masih relevan).
- **Deteksi langganan**: pengeluaran dengan catatan sama yang muncul 3 bulan berturut dengan nominal mirip (mis. Netflix) ditawarkan untuk dijadikan transaksi berulang. Bisa ditolak dan tidak akan ditawarkan lagi.
- **Pengeluaran tidak biasa**: kategori yang 7 hari terakhir lebih dari 2× rata-rata mingguan 2 bulan sebelumnya (dan selisihnya minimal Rp50.000) ditandai.
- **Cocokkan saldo dari notifikasi**: notifikasi yang menyebut saldo (mis. GoPay "Saldomu sekarang: Rp612.500", "Sisa saldo Rp…") disimpan. Kalau saldo di Infinity pada jam itu berbeda, muncul kartu dengan tombol *Samakan*. Penyesuaiannya dicatat pada jam notifikasi, jadi transaksi sesudahnya tetap benar.

### Diubah
- **Beranda disusun ulang**: yang pertama terlihat adalah *Aman dibelanjakan hari ini*, lalu total saldo dan akun, lalu *Perlu perhatian*.
- **Isi saldo e-wallet** (mis. "berhasil isi saldo GO-PAY sebesar Rp250.000") tidak lagi dicatat otomatis sebagai pengeluaran. Notifikasinya masuk ke *Dari Notifikasi* sebagai transfer dari rekening bank ke e-wallet untuk dicek dulu.

### Diperbaiki
- **Nominal salah dari notifikasi yang menyebut saldo**: angka saldo akhir (mis. "Saldomu sekarang: Rp612.500") tidak lagi terbaca sebagai nominal transaksi. Angka setelah "sebesar" sekarang didahulukan.

## v1.7.1 (8 Okt 2026)

### Diperbaiki
- **Izin internet dibuang lagi**: library baca struk (Google ML Kit) diam-diam menambah izin INTERNET untuk mengirim log pemakaian ke Google. Izin itu sekarang dibuang, jadi Infinity kembali 100% offline. Baca struk tetap jalan karena modelnya ada di dalam app. Setiap build sekarang dicek otomatis dan gagal kalau izin INTERNET muncul lagi.

## v1.7 (8 Okt 2026)

> ⚠️ Pakai **v1.7.1**. APK v1.7 tidak sengaja membawa izin internet dari library ML Kit.

### Ditambah
- **Baca struk otomatis (offline)**: saat menambah foto struk dan nominal masih kosong, Infinity membaca fotonya langsung di HP (Google ML Kit, tanpa internet) lalu mengisi nominal total, nama toko sebagai catatan, dan kategori kalau tertebak. Baris *Subtotal*, *Total item*, *Diskon*, dan *Tunai/Kembali* diabaikan. Hasilnya tebakan, jadi tetap dicek sebelum simpan.
- **Splash animasi**: saat app dibuka, koin jatuh masuk ke celengan, celengan memantul, lalu tulisan Infinity muncul. Splash bawaan Android juga dibuat gelap dengan celengan supaya menyambung. Kalau *Kurangi animasi* di HP aktif, animasi dilewati.

### Diubah
- **Penyimpanan data baru**: data dipindah dari secure storage ke **file terenkripsi AES-256** di folder pribadi app (kuncinya tetap di Android Keystore). Jauh lebih cepat untuk data besar, misalnya hasil import Money Manager bertahun-tahun. Pindahnya otomatis saat update; data lama baru dihapus setelah file baru terbukti bisa dibaca.
- Penyimpanan sekarang dikumpulkan (sekali tulis untuk beberapa perubahan beruntun) dan langsung disimpan saat app ditutup.
- Kode app dipecah dari satu file 13 ribu baris menjadi 32 file per bagian, supaya lebih mudah dirawat.

## v1.6 (8 Okt 2026)

### Ditambah
- **Ekspor ke Excel** (Backup & Pulihkan): bulan ini, tahun ini, atau semua, disimpan sebagai `.xlsx` di Download/Infinity. Kolomnya sama seperti ekspor Money Manager, jadi bisa dibuka di Excel/Google Sheets atau diimpor ulang.
- **Ringkasan bulanan** di Beranda: pengeluaran bulan ini dibanding bulan lalu pada tanggal yang sama (naik/turun berapa persen) dan 3 kategori yang naik paling banyak.

## v1.5 (8 Okt 2026)

### Ditambah
- **Utang & Piutang** (Lainnya): catat siapa meminjam berapa, tanggal dan tenggat, cicilan pembayaran, lalu tandai lunas. Total piutang dan utang tampil di atas, yang lewat tenggat ditandai merah. Pengingat sehari sebelum dan saat tenggat (bisa dimatikan di Notifikasi). Catatan ini tidak mengubah saldo akun.
- **Target Tabungan** (Lainnya): mis. "Dana darurat Rp10 juta". Progres bisa ikut saldo akun (mis. akun Tabungan) atau diisi manual dengan *Setor* / *Ambil*. Kalau ada tenggat, ditampilkan berapa yang perlu disisihkan per bulan. Target pertama juga tampil di Beranda.

## v1.4 (8 Okt 2026)

### Ditambah
- **Foto struk di transaksi**: di form catat ada baris *Foto*. Ambil dari kamera atau galeri, bisa lebih dari satu. Foto disimpan di folder pribadi Infinity (offline), tampil di detail transaksi dan bisa diperbesar.
- **Backup terenkripsi**: atur *kata sandi backup* di Backup & Pulihkan. Backup mingguan dan *Backup sekarang* lalu disimpan sebagai file `.infb` yang terkunci (AES-256) dan ikut menyimpan foto struk.
- **Pulihkan dari file**: pilih file `.infb` (diminta kata sandi) atau `.json` lama langsung dari HP, tanpa salin-tempel.
- **Saldo minus** bisa diisi saat edit akun (centang *Saldo minus* / *Kelebihan bayar*).
- **Tes otomatis** untuk hitungan saldo, transfer beda mata uang, penyesuaian saldo, urutan akun, teks cepat, saran ketikan, import Money Manager, dan backup terenkripsi. APK baru hanya terbit kalau semua tes lolos.

### Diperbaiki
- **Saldo berubah lagi setelah diubah manual**: notifikasi bank/e-wallet yang terjadi *sebelum* saldo diubah manual tidak lagi dicatat otomatis (saldo yang kamu ketik sudah termasuk transaksi itu). Notifikasi seperti itu masuk ke kartu *Dari Notifikasi* untuk dicek.
- **Saldo minus terbaca plus** saat membuka edit akun yang saldonya minus, sehingga menyimpan bisa mengubah saldo. Sekarang tanda minus dipertahankan.
- Notifikasi **Urungkan** setelah menghapus sekarang hilang sendiri dalam 3 detik.

## v1.3.2 (8 Okt 2026)

### Diperbaiki
- **Widget terpotong** di sebagian HP: tata letak widget disusun ulang supaya tombol Keluar · Masuk · Transfer selalu terlihat utuh di bawah, dan teks di tengah menyesuaikan tinggi widget. Nominal masuk/keluar/sisa anggaran di widget ditulis ringkas (mis. "Rp 7,5 jt") supaya muat. Widget juga tidak bisa dikecilkan sampai terpotong.

## v1.3.1 (7 Okt 2026)

### Ditambah
- **Dolar Taiwan (TWD, NT$)** sebagai mata uang akun dan transfer. Kurs awal 1 TWD = Rp564 (kurs 6 Okt 2026), bisa diubah di Lainnya → Mata Uang & Kurs. Nominal TWD tanpa sen, seperti Rupiah dan Yen.

## v1.3 (7 Okt 2026)

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

