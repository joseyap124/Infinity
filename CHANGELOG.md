# Catatan rilis Infinity

Setiap rilis mencatat apa yang **ditambah**, **diubah**, **dihapus**, dan **diperbaiki**.
Bagian *Berikutnya* berisi perubahan yang akan masuk rilis selanjutnya.

## Berikutnya (v5.5.3)

### Diperbaiki
- **Notifikasi uang masuk berbahasa Inggris dibaca sebagai pengeluaran.** Teks seperti "You received IDR 1,496,000.00 from ..." (Financial Diary myBCA di HP berbahasa Inggris) sekarang dikenali sebagai uang masuk, bukan pengeluaran. Kata lain yang ikut dikenali: "incoming transfer", "money received", "funds received", dan "credited".

## v5.5.2 (13 Okt 2026)

### Diperbaiki
- **Layar "Data belum bisa dibuka" saat membuka dari widget.** Gagal membaca kunci data sering hanya sesaat, jadi sekarang Infinity mencoba lagi sendiri sampai tiga kali (tiap 2,5 detik) sebelum menyerah, dan pembacaan kunci di awal dicoba empat kali dengan jeda makin panjang. Kalau tetap gagal, layar itu menampilkan baris kecil "Kode: ..." berisi penyebab teknisnya (mis. secure storage kosong atau dekripsi gagal) supaya masalahnya bisa dilacak. Datamu tidak diubah atau dihapus oleh langkah ini.

## v5.5.1 (13 Okt 2026)

### Diubah
- **Judul langsung bisa diketik.** Ketuk tulisan "+ Tambah judul atau catatan" di form transaksi, dan kolom Judul langsung aktif dengan keyboard terbuka, tanpa perlu mengetuk kolomnya lagi. Tombol "Catatan, struk, bagi" tetap membuka lembar tanpa keyboard, karena isinya juga foto struk dan acara.

## v5.5.0 (13 Okt 2026)

Widget layar utama sekarang ikut gaya dan maskot pilihanmu.

### Diubah
- **Widget ikut gaya.** Ketiga widget (4x2, 2x2, 2x1) memakai warna gaya yang kamu pilih: Malam Biru, Kuning Ceria, atau Merah Kafe, lengkap dengan garis tepi. Gaya Klasik tetap seperti sebelumnya (biru gelap kehijauan).
- **Widget ikut maskot.** Cincin di widget menampilkan Burung Hantu, Rubah, Gagak, atau gambar sendiri sesuai pilihan di Pengaturan, bukan lagi selalu maskot lama. Kalau gambarnya tidak terbaca, widget kembali ke maskot klasik.
- Motif latar (kabut, awan, lampu) belum ada di widget; hanya warna dan garis tepi.

## v5.4.1 (13 Okt 2026)

### Diubah
- **Bagian bawah Statistik lebih ringkas.** Daftar "Lainnya" yang berisi lima baris diganti satu baris empat tombol: Rekap bulan, Rekap tahun, Kalau..., dan Ekspor. Ekspor membuka pilihan Laporan PDF dan Bagikan ringkasan bulan. Di tampilan Minggu dan Tahun hanya Rekap tahun dan Kalau... yang tampil, karena rekap bulan, PDF, dan bagikan memang untuk satu bulan.

## v5.4.0 (13 Okt 2026)

Gaya tidak lagi polos: tiap gaya punya motif latar sendiri, dan ikon kategori serta menu bawah ikut gayanya.

### Ditambah
- **Motif latar di Beranda.** Malam Biru: pusaran, bulan sabit, dan bintang. Kuning Ceria: kabut dan awan putih. Merah Kafe: lampu gantung merah dengan cahaya hangat dan biji kopi. Motif juga tipis di kartu utama. Bisa dimatikan di Pengaturan, Tampilan, Motif latar.
- **Ikon per gaya.** 22 ikon kategori dan ikon menu bawah mengikuti gaya yang dipilih, dengan gambar yang sama gayanya dengan ikon Tagihan, Anggaran, Patungan, Utang, dan Target. Lima ikon pintasan itu tidak berubah. Gaya Klasik tetap memakai ikon lama.

### Diubah
- **Merah Panggung jadi Merah Kafe.** Palet baru: merah marun dan krem hangat, bukan lagi hitam dan merah tajam. Selalu gelap.

## v5.3.0 (13 Okt 2026)

Dua cara baru melihat uangmu: kalender pengeluaran dan simulasi "Kalau...". Semuanya dihitung dari data di HP.

### Ditambah
- **Kalender di Statistik.** Tab keempat setelah Kategori, Tren, dan Aset (tidak ada di tampilan Tahun). Tiap hari diwarnai dari hijau (hemat) sampai merah (boros), jadi hari yang jebol langsung kelihatan. Ketuk satu hari untuk melihat total, jumlah transaksi, kategori terbesar, dan selisihnya dari patokan. Patokannya jatah harian dari anggaranmu; kalau belum ada anggaran, rata-rata harian dari data sampai 90 hari terakhir, dan kalau data kurang dari seminggu, warna dibandingkan dengan hari paling boros di bulan itu. Di bawahnya ada ringkasan: berapa hari di bawah patokan dan hari paling boros.
- **Kalau...** Simulasi kebiasaan. Pilih Hemat harian, Tabung, atau Cicilan, lalu geser angka dengan tombol - dan +. Infinity menghitung kapan target tabunganmu tercapai atau cicilanmu lunas, dibanding kalau tidak ada perubahan. Sisa uang bulanan diambil dari rata-rata 3 periode terakhir dan bisa kamu ubah kalau tidak pas. Dibuka dari Statistik (bagian Lainnya) atau dari tab Cicilan dan Target di Rencana. Ini perkiraan, bukan janji.

## v5.2.0 (13 Okt 2026)

Statistik dan Rencana lebih ringan: satu ringkasan di atas, isi lainnya dibagi ke tab, tidak lagi menumpuk panjang ke bawah.

### Diubah
- **Statistik.** Di atas ada satu kartu ringkasan: pengeluaran periode ini, perbandingannya dengan periode sebelumnya (mis. "8% lebih hemat dari bulan lalu"), lalu Pemasukan, Selisih, dan Rata-rata/hari. Perbandingan untuk periode yang masih berjalan memakai jumlah hari yang sama dari periode sebelumnya, supaya adil. Isinya dibagi ke tiga tab: **Kategori** (donat, daftar kategori, Golongan pengeluaran), **Tren** (grafik dan perbandingan dengan bulan lalu), dan **Aset** (kekayaan bersih dan saldo per akun). Rekap dan saran bulan, Rekap tahun, Laporan PDF, dan Bagikan ringkasan pindah ke bagian Lainnya di bawah.
- **Rencana.** Anggaran tetap di atas. Saran jadi satu baris ("N saran untuk bulan ini") yang dibuka dengan sekali ketuk. Tagihan (termasuk kartu kredit), Cicilan, Target, dan Utang sekarang berupa empat tab, jadi hanya satu yang tampil sekaligus. Tab untuk fitur yang kamu matikan tidak muncul. Patungan dan Acara tetap di bawah.

## v5.1.0 (13 Okt 2026)

Tampilan Infinity bisa dipilih: tiga gaya baru dan tiga maskot hewan, semuanya opsional dan tetap offline.

### Ditambah
- **Gaya.** Di Pengaturan, Tampilan, pilih Gaya: Klasik (seperti biasa), Malam Biru (biru malam dengan garis neon cyan), Kuning Ceria (kuning cerah dengan garis hitam tebal), atau Merah Panggung (hitam dan merah tajam). Tiap gaya mengganti warna dasar, Terang atau Gelap, dan ikon pintasan Tagihan, Anggaran, Patungan, dan Utang di Beranda. Gaya selain Klasik mengatur Terang atau Gelap sendiri dan menggantikan Warna utama; pemasukan tetap hijau dan pengeluaran tetap merah.
- **Maskot.** Di Pengaturan, Tampilan, pilih Maskot: Klasik (maskot lama), Burung Hantu, Rubah, Gagak, atau Gambar sendiri dari galeri HP. Tiap hewan punya 6 ekspresi yang berganti sesuai sisa jatah harian (Senang, Aman, Hati-hati, Bahaya, Boros, Ngantuk). Gambar sendiri hanya tersimpan di HP ini dan dipakai untuk semua suasana, ditandai lewat warna cincin.

### Diubah
- Pilihan gaya dan maskot ikut tersimpan di backup dan tidak hilang saat reset data, seperti pilihan tampilan lainnya.
- Ukuran aplikasi bertambah sekitar 1 MB karena gambar maskot ikut dibundel.

## v5.0.5 (13 Okt 2026)

Judul transaksi dari notifikasi bank lebih jelas, sehingga kategorinya lebih mudah ditebak dari kebiasaanmu.

### Diubah
- **Judul dari notifikasi memakai nama tujuan.** "You spent IDR 10,000.00 at Account Transfer" sekarang berjudul "Account Transfer", "Pengeluaran sebesar IDR 25,000.00 di KOPI KENANGAN" berjudul "Kopi Kenangan", dan "Transferan sejumlah Rp1.000 ke MANDIRI" berjudul "Mandiri". Dulu judulnya "Transaksi myBCA" untuk semuanya, sehingga Infinity tidak bisa belajar kategori per tujuan. Kategori ditebak dari kebiasaanmu setelah judul yang sama dicatat minimal 2 kali dengan kategori yang sama. Nama yang disamarkan bank (mis. "A****** P****") tidak dipakai sebagai judul.

### Diperbaiki
- **Judul "Pembayaran ke X" ikut membawa nominal dan kalimat berikutnya**, mis. "Kopi Kenangan Rp25.000 berhasil. Sisa sa". Sekarang hanya nama tujuannya.

## v5.0.4 (13 Okt 2026)

Perbaikan pembacaan notifikasi BCA dan Mandiri.

### Diperbaiki
- **Notifikasi uang masuk dibaca sebagai pengeluaran.** Format "Pemasukan sebesar IDR 100,000.00 ..." (Catatan Finansial myBCA) dan "Dana Rp 1.000,00 masuk ke rek. ..." (Livin by Mandiri) sekarang dikenali sebagai uang masuk.
- **Nominal salah kalau kalimat berakhir tepat setelah angka**, mis. "Rp 1.000,00." sempat terbaca 100 kali lipat. Tanda baca di ujung angka sekarang diabaikan.

## v5.0.3 (13 Okt 2026)

Catat otomatis bisa ditelusuri, data lebih aman saat kunci gagal dibaca, dan laporan bulanan bisa diekspor ke PDF.

### Ditambah
- **Riwayat tangkapan** (Lainnya > Catat otomatis): daftar 40 notifikasi uang terakhir yang sampai ke Infinity, tiap baris menunjukkan hasilnya (Dicatat, Antrean, atau Dibuang) beserta alasannya, misalnya akun tidak bisa ditebak, mirip transaksi yang sudah ada, atau terdeteksi promo. Gunanya menjawab "kenapa notifikasi ini tidak muncul di Beranda". Notifikasi tanpa nominal "Rp" tidak ikut tercatat di sini.
- **Laporan PDF** (Statistik > Laporan PDF): laporan bulan terpilih berukuran A4 berisi ringkasan (pemasukan, pengeluaran, selisih, rata-rata per hari), pengeluaran per kategori, pengeluaran terbesar, dan daftar transaksi (bisa dimatikan, maksimal 600 baris). Dibuat di HP, bisa disimpan ke Download/Infinity atau dibagikan. Teks di PDF berupa gambar, jadi tidak bisa diseleksi atau dicari.

### Diubah
- **Data yang tidak bisa dibuka tidak lagi diam-diam diganti data kosong.** Kalau file data ada tetapi kuncinya gagal dibaca, Infinity menampilkan layar "Data belum bisa dibuka" dengan tombol Coba lagi, dan Mulai dari awal dan pulihkan dari backup. File lama tidak dihapus. Kunci baru juga tidak lagi dibuat selama file data masih ada.

## v5.0.2 (12 Okt 2026)

### Diubah
- **Form catat transaksi**: setelah memilih kategori, kursor langsung pindah ke kolom Catatan (keyboard terbuka) kalau catatannya masih kosong.

## v5.0.1 (12 Okt 2026)

Perbaikan pengaman data: kunci enkripsi data tidak lagi hilang diam-diam.

### Diperbaiki
- **Data tiba-tiba "tidak bisa dibaca" lalu mulai kosong.** Kalau HP gagal membaca kunci enkripsi untuk sesaat, app dulu langsung membuat kunci baru sehingga data lama tidak bisa dibuka lagi. Sekarang app mencoba membaca kunci beberapa kali, memakai salinan kunci di folder privat app kalau secure storage gagal, dan mencoba membaca file data sekali lagi sebelum menyerah.

## v5.0 (12 Okt 2026)

Rilis besar: Beranda baru dengan maskot, kartu budget dengan penanda ritme, kalender peta panas, rekap bulanan bercerita, Tunda beli, ikon Flat dan Mono, widget baru, serta pengaturan Fitur.

### Ditambah
- **Beranda baru**: cincin jatah harian dengan maskot Infinity di tengahnya, total saldo (ketuk untuk daftar akun), dan 4 pintasan bulat (Tagihan, Anggaran, Patungan, Utang).
- **Maskot 6 suasana** sesuai sisa jatah hari ini: Senang (80% ke atas), Aman (50-80%), Hati-hati (30-50%), Bahaya (di bawah 30%), Boros (lewat jatah, maskot menangis), dan Ngantuk (3 hari tidak mencatat).
- **Kartu Budget dengan penanda ritme**: bar punya penanda putih "seharusnya sekarang", kalimat "Lebih cepat Rp... dari ritme", dan tanda per kategori (▲ Cepat, ● Pas, ▼ Hemat) sehingga statusnya terbaca tanpa bergantung warna.
- **Perkiraan uang habis** di lembar "Dari mana angka ini?": "Dengan kecepatan sekarang, uang habis sekitar ...". Di awal periode, kalimatnya menjelaskan bahwa datanya masih sedikit.
- **Kalender peta panas** di Riwayat: warna merah muda sesuai besar pengeluaran harian, titik hijau untuk uang masuk, titik oranye untuk jatuh tempo (tagihan berulang dan cicilan), garis tebal untuk hari paling boros, dan total Uang masuk/keluar di atas. Ketuk hari untuk melihat nominalnya.
- **Rekap bulanan bercerita**: 5 slide (tabungan, uang masuk dan keluar, kategori terbesar, hari terboros, dibanding bulan lalu). Tiap slide bisa dibagikan sebagai gambar, nominal tersembunyi secara bawaan. Versi Lengkap tetap ada lewat tombol "Lengkap".
- **Tunda beli** (mati bawaannya): daftar tunggu dengan masa tunggu per barang (bawaan 7 hari), "Jadi beli" membuka form transaksi terisi, "Batal beli" dihitung sebagai uang yang tidak jadi keluar bulan ini, dan satu pengingat setelah masa tunggu lewat.
- **Pengaturan > Fitur**: nyalakan atau matikan Cicilan, Utang, Target, Patungan, Acara, dan Tunda beli. Fitur yang dimatikan disembunyikan dan tidak dihitung, datanya tetap tersimpan.
- **Animasi pembuka** bisa dipilih: sekali saja, tiap buka, atau mati.
- **Gaya ikon**: Flat (59 ikon ilustrasi datar baru) dan Mono (satu warna), selain Kartun dan Klasik.
- **Bentuk grafik kategori** di Statistik bisa dipilih: Cincin atau Lingkaran penuh (Pengaturan > Tampilan).
- **Widget baru**: 4x2 dengan cincin dan maskot (suasananya mengikuti jatah), widget 2x2 baru, dan widget 2x1 dengan maskot dan tombol "+". Nominal jadi "Rp ••••" saat saldo disembunyikan.
- Terjemahan English dan 简体中文 untuk semua teks baru.

### Diubah
- Pengingat backup di Beranda baru muncul setelah 30 hari tanpa backup (sebelumnya 7 hari). Saat aman, tidak ada kartu atau chip lagi di Beranda; statusnya tetap ada di Backup & Pulihkan. Salinan di luar HP hanya diingatkan kalau pernah dibuat lalu sudah lebih dari 30 hari.
- Kartu akun di Beranda dihapus; akun dibuka lewat baris Total saldo.
- Daftar kategori di Statistik menampilkan 4 teratas, sisanya di balik "N kategori lainnya".
- Widget 4x2 tidak lagi menampilkan baris Masuk/Keluar bulan ini.

## v4.7 (12 Okt 2026)

Kartu Kekayaan Bersih menunjukkan angka setelah kewajiban.

### Ditambah
- Di kartu **Kekayaan Bersih** (Statistik) muncul satu baris tambahan kalau ada sisa cicilan atau utang kamu ke orang lain: "Kalau sisa cicilan ... ikut dikurangi: ...". Angka utama dan grafiknya tidak berubah, karena utang di Utang & Piutang memang dicatat terpisah dari saldo akun. Baris ini tidak tampil saat nominal disembunyikan.
- Terjemahan English dan 简体中文 untuk baris itu.

### Akan datang
Rencana berikutnya, urutannya bisa bergeser:
- **Dipertimbangkan**: pendeteksi biaya yang bocor (langganan dan biaya kecil berulang) dan fitur "tunda beli".

## v4.6 (12 Okt 2026)

Cicilan 0%: catat barang yang kamu cicil (SPayLater, Kredivo, kartu kredit) supaya tagihannya tidak kelewat dan ikut dihitung di "Aman dibelanjakan".

### Ditambah
- **Cicilan** di tab Rencana (kartu baru) dan halaman **Cicilan**: nama barang, total harga, berapa kali bayar (**1x**, 3, 6, 12, atau jumlah sendiri), tanggal jatuh tempo tiap bulan, sudah dibayar berapa kali, dan akun yang dipakai bayar. Bunga selalu 0%, jadi cicilan per bulan adalah total dibagi jumlah kali bayar (sisa pembulatan masuk ke cicilan terakhir).
- **Tandai dibayar**: mencatat pengeluaran dari akun yang kamu pilih dan mengurangi sisa cicilan. Ada tombol **Urungkan** yang menghapus transaksi itu lagi. Menghapus cicilan juga bisa diurungkan; transaksi yang sudah tercatat tetap ada di Riwayat.
- **Aman dibelanjakan** menyisihkan cicilan yang jatuh tempo sampai sehari setelah periode berakhir (mis. tagihan tanggal 1 saat periode berakhir tanggal 31), termasuk yang sudah lewat tapi belum ditandai dibayar. Rinciannya muncul sebagai baris "Cicilan jatuh tempo", dan kartu di Beranda menunjukkan berapa yang sudah dikurangi.
- **Saran** di Beranda dan Rencana saat ada cicilan jatuh tempo dalam 3 hari atau sudah lewat.
- **Pengingat** lewat notifikasi pada hari jatuh tempo (08.00) dan sehari sebelumnya (19.00), mengikuti pengaturan notifikasi "berulang".
- Cicilan ikut backup dan pemulihan, dan ikut terhapus bersama akunnya kalau akun dihapus. Backup lama tanpa cicilan tetap bisa dipulihkan.
- Terjemahan English dan 简体中文 untuk semua teks baru.

### Catatan
- Infinity tidak mengambil data dari Shopee atau aplikasi lain. Cicilan diisi manual.
- Tanggal jatuh tempo 29 sampai 31 dipotong ke hari terakhir di bulan yang lebih pendek.
- Mengubah "sudah dibayar berapa kali" di form edit menghitung ulang jadwal dari hari ini, tanpa membuat atau menghapus transaksi.

## v4.5 (12 Okt 2026)

Bahasa tahap 2: hampir semua layar sekarang ikut pilihan bahasa.

### Ditambah
- **Terjemahan English dan 简体中文 untuk layar yang tadinya masih Indonesia**: Utang & Piutang, Target tabungan, Patungan, Acara, Riwayat akun, Kekayaan bersih, Rekap tahunan, Rekap & saran bulanan, Transaksi berulang, Template, Mata uang & kurs, Notifikasi, PIN dan keamanan, Import Money Manager, Cek kesehatan data, Laporan error, dan Panduan.
- **Saran bulanan** (rekap, tingkat tabungan, dana darurat, anggaran, kategori yang naik) ikut bahasa yang dipilih, termasuk kalimat yang disusun dari angka.
- Tombol di widget layar utama (Keluar, Masuk, Transfer) ikut bahasa. Widget diperbarui saat bahasa diganti.

### Diubah
- Teks yang kamu ketik sendiri (judul transaksi, catatan, nama akun, nama kategori yang kamu buat, nama orang di utang dan patungan) tetap apa adanya dan tidak diterjemahkan.

### Catatan
- English membedakan tunggal dan jamak untuk kata yang umum ("1 day", "2 days", "1 transaction"). Bahasa lain tidak punya bentuk jamak.
- Teks yang tidak ada di kamus tetap tampil dalam bahasa Indonesia, bukan kosong atau rusak.

## v4.4 (12 Okt 2026)

Pilih banyak transaksi sekaligus, dan bagikan ringkasan bulan sebagai gambar.

### Ditambah
- **Pilih banyak transaksi di Riwayat**: tahan satu transaksi untuk mulai memilih, ketuk yang lain untuk menambah. Bilah di atas menunjukkan jumlah terpilih dengan tombol **Pilih semua**, **Ubah kategori**, **Ubah akun**, dan **Hapus**. Setelah mengubah atau menghapus ada tombol **Urungkan** beberapa detik. Selama memilih, geser-untuk-hapus dimatikan, dan tombol Kembali membatalkan pilihan dulu.
- Ubah kategori hanya berlaku untuk transaksi yang jenisnya sama (semua pengeluaran atau semua pemasukan). Transfer tidak punya kategori, jadi dilewati. Transaksi yang dibagi ke beberapa kategori menjadi satu kategori.
- Ubah akun melewati transfer dan transaksi yang mata uang akunnya beda, karena nominal tidak ikut dikonversi. Jumlah yang diubah dan dilewati ditampilkan setelahnya.
- **Bagikan ringkasan bulan sebagai gambar**: tombol bagikan di halaman Rekap bulanan, dan "Bagikan ringkasan bulan" di Statistik (mode bulan). Gambar berisi persentase yang tersisa dari pemasukan, pemasukan dan pengeluaran, serta 5 kategori terbesar. **Sembunyikan nominal** aktif secara bawaan, jadi hanya persentase yang tampil. Dikirim lewat menu bagikan Android, atau **Simpan ke HP** (Download/Infinity). Gambar dibuat di HP, tidak ada yang diunggah.

## v4.3 (12 Okt 2026)

Notifikasi bank atau e-wallet sekarang bisa langsung dijawab dari panel notifikasi.

### Ditambah
- **Notifikasi dengan tombol**: saat notifikasi bank atau e-wallet terdeteksi (mis. SeaBank Rp 15.000), Infinity memunculkan notifikasi "Transaksi terdeteksi" dengan tombol **Keluar**, **Masuk**, dan **Abaikan**. Keluar atau Masuk langsung menyiapkan transaksinya (akun dan kategori ditebak seperti biasa), Abaikan membuangnya. Di layar kunci, isi notifikasi disembunyikan.
- Pilihanmu **dicatat begitu Infinity dibuka berikutnya**, bukan saat tombol ditekan, karena data Infinity terenkripsi dan hanya app yang bisa menulisnya. Saldo dan "Aman dibelanjakan" baru berubah setelah itu.
- Saklar **Notifikasi dengan tombol** ada di Lainnya, Catat Otomatis (muncul kalau mode bukan Mati). Mode Mati, Tanya dulu, dan Langsung catat tetap seperti sebelumnya.
- Hanya aplikasi keuangan yang dikenali (GoPay, OVO, DANA, ShopeePay, BCA, Jago, BRImo, Livin, BNI, SeaBank, LinkAja, blu, Flip) yang memunculkan notifikasi bertombol, dan notifikasi promo dilewati. Saat Infinity sedang terbuka, notifikasi bertombol tidak muncul karena app membaca sendiri.
- Isi saldo e-wallet tetap menunggu di "Dari Notifikasi" karena itu transfer, bukan pengeluaran.

### Catatan
- Notifikasi bertombol memakai izin notifikasi Android yang sama dengan pengingat. Kalau tidak muncul, cek izin notifikasi Infinity di pengaturan HP.

## v4.2 (12 Okt 2026)

Pilihan bahasa: Indonesia, English, dan 简体中文.

### Ditambah
- **Bahasa**: Pengaturan, Tampilan, **Bahasa**. Pilihan Indonesia, English, atau 简体中文. Berlaku seketika tanpa menutup halaman yang sedang dibuka, dan ikut tersimpan di backup. Nama bulan dan hari di tanggal ikut bahasa yang dipilih.
- Yang sudah diterjemahkan di tahap ini: Beranda, Riwayat, form catat transaksi, Statistik, Rencana (anggaran dan tagihan), Akun, Pengaturan, Backup, notifikasi, kategori dan akun bawaan, serta pesan di layar.
- Tulisan yang kamu ketik sendiri (judul transaksi, nama akun, nama kategori yang kamu buat) tidak pernah diterjemahkan.

### Catatan
- Layar yang belum diterjemahkan tetap tampil Indonesia, bukan kosong. Yang belum: utang, target dan tabungan, patungan, acara, rekap dan saran bulanan, serta beberapa layar lain. Semuanya masuk tahap 2.
- Label tetap di widget layar utama (mis. "Masuk", "Keluar") masih Indonesia.

## v4.1 (12 Okt 2026)

Backup lebih terlihat, dan pintasan langsung dari ikon app.

### Ditambah
- **Kartu kesehatan backup di Beranda**: chip hijau "Backup aman" saat backup di HP baru dan ada salinan di luar HP. Kalau belum ada salinan di luar HP (Google Drive dll) muncul kartu kuning dengan tombol **Simpan ke Drive**. Kalau backup di HP sudah seminggu lebih dan datanya berubah, muncul kartu merah dengan tombol **Simpan sekarang**. Baru muncul setelah ada 10 transaksi. Kartu bisa ditutup untuk hari itu.
- **Status backup** di Lainnya, Backup & Pulihkan: kapan backup otomatis terakhir, kapan salinan di luar HP terakhir, dan apakah isi data masih sama dengan backup terakhir.
- **Pintasan ikon**: tahan ikon Infinity di layar utama untuk langsung Catat pengeluaran, Catat pemasukan, atau Transfer.

### Diubah
- Pengingat salinan di luar HP pindah dari deretan "Perlu perhatian" ke kartu backup di atas, supaya tidak muncul dobel.

## v4.0 (12 Okt 2026)

Mencatat transaksi jadi satu layar, plus widget baru dan perapian tampilan.

### Diubah
- **Catat transaksi satu layar**: nominal besar di atas, kategori dipilih langsung dari kotak **Sering dipakai**, akun dan tanggal sebagai chip, lalu tombol angka bawaan app (1 sampai 9, 000, 0, hapus; tahan hapus untuk mengosongkan). Tombol Simpan menampilkan nominalnya, mis. "Simpan Rp 38.000". Tidak ada lagi keyboard sistem yang menutupi layar. Berlaku untuk Pengeluaran, Pemasukan, Transfer, dan edit transaksi.
- **Sering dipakai**: 7 kategori + "Semua" (untuk daftar lengkap dengan sub-kategori). Urutannya otomatis dari kategori yang paling sering kamu pakai 90 hari terakhir, terpisah untuk pengeluaran dan pemasukan. Kategori yang terpilih awal juga yang paling sering dipakai.
- **Pin**: tahan sebuah kategori untuk pin ke atas (maksimal 7), lepas pin, atau sembunyikan dari Sering dipakai. Kategori yang dipin tidak bergeser. Pin ikut tersimpan di backup.
- **Transfer**: akun asal dan tujuan dipilih lewat chip yang bisa digeser. Kalau beda mata uang, kolom "Diterima" muncul.
- **Judul, catatan, foto struk, acara, bagi kategori, tempel struk, dan template** dipindah ke satu layar "Detail transaksi" (tombol "Catatan, struk, bagi"), supaya layar utama tetap bersih. Kolom yang tadinya "Catatan" sekarang bernama **Judul**, dan "Deskripsi" menjadi **Catatan**.
- Transaksi berulang dan template tetap memakai form lama.
- **Widget baru**: kartu gelap seperti di Beranda dengan logo baru. Angka besarnya sekarang **Aman dibelanjakan hari ini** (sebelumnya total saldo), lalu Masuk dan Keluar bulan ini, total saldo, dan tombol Keluar/Masuk/Transfer. Tetap menyembunyikan angka kalau mode sembunyikan saldo aktif.
- **Beranda**: tombol Bills, Budget, Patungan, dan Utang ikut bergambar kartun. Saat belum ada transaksi, ada tombol "Catat transaksi pertama".
- **Avatar dan panduan awal** memakai logo baru, bukan celengan atau simbol ∞ polos lagi.

### Ditambah
- **Widget kecil 2x1**: sisa aman hari ini dan satu tombol "+" untuk langsung mencatat pengeluaran. Tambahkan lewat daftar widget di layar utama HP.

## v3.7.1 (12 Okt 2026)

### Ditambah
- **Ikon kartun untuk semua menu dan status**, bukan cuma kategori. Tiap tipe akun (E-Wallet, Tunai, Rekening Bank, Kartu Kredit, Investasi), transfer, utang, acara, dan target tabungan (piala saat tercapai) punya gambar sendiri. Menu Lainnya dan Pengaturan juga bergambar (gear, awan backup, petir template, perisai cek data, kutu laporan error, palet, lonceng, jam, gembok, kurs, kalender, dan lainnya), begitu pula saran bulanan, status PIN, status notifikasi, dan tombol Masuk/Keluar di Riwayat. 27 gambar baru.
- Semua ini mengikuti pilihan "Gaya ikon kategori" di Pengaturan, Tampilan. Di gaya Klasik semuanya tetap ikon lama.

## v3.7 (12 Okt 2026)

Logo baru dan ikon kategori bergambar kartun.

### Ditambah
- **Ikon kategori kartun**: 26 ikon bergambar (Makan, Kopi, Belanja, Obat, Investasi, Personal Care, Darurat, Donasi, dan lainnya) menggantikan ikon polos di Beranda, Riwayat, Statistik, Anggaran, Kategori, template, dan detail transaksi. Pilihan ikon saat membuat atau mengubah kategori ikut berubah jadi gambar.
- **Pilihan gaya ikon**: di Pengaturan, Tampilan, "Gaya ikon kategori": **Kartun** (baru, bawaan) atau **Klasik** (ikon lama). Bisa diganti kapan saja, dan ikut tersimpan di backup.
- **8 ikon baru** untuk kategori: Tabungan, Personal Care, Obat, Darurat, Donasi, Kartu/cicilan, Olahraga, dan Bank.

### Diubah
- **Logo baru**: pita ∞ hijau-tosca dengan koin Rp di latar krem, menggantikan celengan. Dipakai di ikon app (termasuk ikon tematik Android 13+), splash bawaan, splash animasi (pita tergambar, koin jatuh, lalu nama Infinity), dan ikon di status bar.
- Beberapa kategori bawaan memakai ikon yang lebih pas: Personal Care, Health (Obat), Olahraga, Darurat, Emergency, Donasi, Cicilan, dan Admin Bank. Hanya yang ikonnya belum pernah kamu ganti. Di gaya Klasik, kategori ini juga tampil dengan ikon Material yang baru.

## v3.6.2 (12 Okt 2026)

### Diperbaiki
- **Nominal salah dari notifikasi atau email bank berbahasa Inggris**: "IDR 263,000.00" sebelumnya terbaca Rp 26.300.000. Sekarang format Inggris ("263,000.00", "1,250,000.50") dan Indonesia ("1.250.000,00") sama-sama dibaca benar. Berlaku juga untuk teks struk yang ditempel.
- **Notifikasi bank tidak masuk ke Beranda setelah update**: layanan pembaca notifikasi di sebagian HP terputus setelah app diperbarui. Infinity sekarang meminta Android menyambungkannya lagi saat dibuka, dan saat layanan terputus.

## v3.6.1 (10 Okt 2026)

### Diubah
- **Beranda tanpa warna di belakang**: tidak ada lagi blok hijau atau warna aksen di latar atas. Latar sama dengan halaman lain; nama, sapaan, dan ikon status bar mengikuti tema. Kartu gelap sekarang berisi juga Total saldo dan "Kelola akun". Akun dan tombol Bills/Budget/Patungan/Utang jadi kartu putih polos bergaris tipis (akun diberi titik warna kecil), bukan lagi kotak berwarna di dalam satu kartu besar.

## v3.6 (10 Okt 2026)

Beranda baru, statistik kebutuhan/keinginan/tabungan, dan backup yang lebih aman.

### Ditambah
- **Beranda baru**: kartu gelap berisi "Aman dibelanjakan hari ini", Masuk dan Keluar periode ini dengan bar perbandingan, dan "N transaksi periode ini" yang membuka daftar transaksi. Di bawahnya total saldo, akun dalam grid 2 kolom (maksimal 4, sisanya lewat "Semua akun"), dan empat tombol: **Bills** (tagihan dan langganan), **Budget**, **Patungan**, **Utang**. Tombol "Catat" di kanan bawah tetap ada.
- **Catat cepat** jadi satu baris chip kecil yang bisa digeser, supaya Beranda fokus ke informasi dan transaksi terakhir.
- **Statistik golongan pengeluaran** (Statistik): berapa persen pemasukan periode ini yang jadi Kebutuhan, Keinginan, Tabungan, Investasi diri, dan Kewajiban, dibanding periode sebelumnya. Murni statistik, tidak membatasi apa pun. Golongan tiap kategori bisa diubah (Atur golongan), kategori anak mengikuti induknya. Transfer ke akun yang ditandai "jangan hitung" (tabungan, dana darurat) dihitung sebagai Tabungan.
- **Cadangan otomatis sebelum memulihkan**: data di HP disimpan dulu ke Download/Infinity (`infinity-sebelum-pulih-...`), jadi salah pilih file backup bisa dikembalikan.
- **Pratinjau backup sebelum memulihkan**: dialog menampilkan isi file (tanggal dibuat, jumlah kantong, transaksi, target, utang/piutang, berulang, template, acara) di samping data di HP sekarang, plus peringatan kalau data sekarang lebih baru atau lebih banyak. Kata sandi file .infb ditanya dan diperiksa sebelum dialog ini.

### Diubah
- **Pulihkan backup sekarang memulihkan semua pengaturan**, termasuk tema, ukuran huruf, warna, susunan kartu Beranda, nama, sapaan, dan golongan pengeluaran. Yang tetap milik HP ini hanya PIN, biometrik, layar aman, catatan backup otomatis, dan foto profil (filenya tidak ikut backup). Backup lama yang tidak punya pengaturan tampilan tidak menimpa tampilan HP ini dengan nilai bawaan.
- Ukuran huruf sekarang selalu ditulis di backup (sebelumnya dilewati kalau normal).
- Reset dan hapus semua tetap mempertahankan tampilan seperti biasa.
- Tombol pintas "Bayar / Terima / Transfer / Rencana" di Beranda diganti Bills / Budget / Patungan / Utang. Mencatat tetap lewat tombol "Catat".

## v3.5.2 (9 Okt 2026)

### Diperbaiki
- **Gagal pasang di HP Vivo** ("App not installed as package appears to be invalid" / "APK is missing the developer certificate"): APK sekarang punya tanda tangan model lama (v1) selain v2 dan v3, karena installer beberapa HP masih memeriksanya. Sertifikatnya tetap sama, jadi tetap bisa dipasang di atas versi lama tanpa hapus data. CI menolak rilis yang tidak punya tanda tangan v1.

## v3.5.1 (9 Okt 2026)

### Diperbaiki
- **Transfer beda mata uang**: simbol mata uang di kolom "diterima" tetap tampil walau kolomnya kosong.
- **Urutan akun**: geser urutan di halaman Akun memakai cara baru Flutter (cara lama akan dihapus Flutter). Tidak ada perubahan yang terlihat.

## v3.5 (9 Okt 2026)

Tampilan baru: Beranda lebih lega, rencana keuangan punya tab sendiri, dan semua setelan jadi satu.

### Ditambah
- **Tab Rencana** (menu bawah): anggaran, tagihan & langganan 30 hari ke depan, kartu kredit, target tabungan, utang & piutang, plus saran langganan dan proyeksi saldo. Ada pintasan Patungan dan Acara.
- **Atur Beranda**: pilih kartu yang tampil di Beranda (catat cepat, tagihan, anggaran, kartu kredit, target, dibanding bulan lalu, transaksi terakhir) dan urutannya. Tombolnya di bawah Beranda dan di Pengaturan.
- **Pengaturan** (Lainnya → Pengaturan): Tampilan (tema, ukuran huruf, warna, nama & foto), Atur Beranda, awal bulan keuangan, mata uang & kurs, catat otomatis, notifikasi, keamanan dalam satu halaman.

### Diubah
- **Beranda** bawaan sekarang hanya: Aman dibelanjakan & saldo, hal yang perlu dicek, catat cepat, dan transaksi terakhir. Tombol "Budget" di atas jadi "Rencana".
- **Dibanding bulan lalu** pindah ke Statistik (bulan berjalan). Tetap bisa ditampilkan di Beranda lewat Atur Beranda.
- **Lainnya** dirapikan: profil, Pengaturan, Backup, lalu Kelola data dan Bantuan.

## v3.4 (9 Okt 2026)

### Ditambah
- **Satu transaksi, beberapa kategori**: di form transaksi, ketuk "Bagi" di sebelah kategori. Misalnya belanja Indomaret Rp 150.000 dibagi ke Makan, Rumah tangga, dan Pulsa. Baris pertama otomatis berisi sisanya, jadi total selalu pas. Riwayat tetap menampilkan satu transaksi; Statistik, Anggaran, rekap, Acara, dan ekspor Excel menghitung per kategori.
- **Ukuran huruf** (Lainnya → Tampilan): Normal, Besar, Sangat besar. Dikalikan dengan ukuran huruf HP, dibatasi supaya tampilan tetap rapi.

### Diubah
- **Widget layar utama** menampilkan "Aman dibelanjakan" hari ini (dengan tanggalnya) dan sisa anggaran, serta nama bulan keuangan kalau memakai tanggal gajian.

## v3.3 (9 Okt 2026)

Mencatat lebih cepat dan bulan keuangan bisa ikut tanggal gajian.

### Ditambah
- **Awal bulan keuangan** (Lainnya → Anggaran): misalnya gajian tanggal 25, "Oktober" dihitung 25 Sep sampai 24 Okt. Berlaku untuk anggaran, Aman dibelanjakan, Statistik bulanan, rekap & saran, perbandingan dengan bulan lalu, widget, dan filter "Bulan ini". Kalender di Riwayat dan kekayaan bersih tetap pakai bulan kalender.
- **Kategori pintar**: judul yang sudah minimal 2 kali kamu taruh di kategori yang sama (mis. "Kopi Kenangan" → Kafe) otomatis masuk kategori itu, baik saat mengetik maupun dari notifikasi. Kategori yang kamu pilih sendiri tidak pernah ditimpa.
- **Pencarian lebih lengkap**: semua kata harus cocok ("kopi gopay"), saring nominal (">50rb", "<20000", ">=1jt"), pilihan jenis (keluar/masuk/transfer) dan waktu (bulan ini, bulan lalu, tahun ini), serta total hasil.

### Diubah
- **Saran judul** sekarang menampilkan nominal, kategori, dan akun terakhir. Memilih saran ikut mengisi nominal kalau masih kosong.

## v3.2 (9 Okt 2026)

Fokus keandalan: data tidak mudah hilang. Data lama aman, cukup pasang di atas versi sebelumnya.

### Diubah
- **Simpan langsung**: perubahan ditulis ke penyimpanan begitu selesai (sebelumnya ada jeda 0,4 detik). Kalau app ditutup paksa, misalnya saat update, transaksi terakhir tidak ikut hilang.
- **Backup otomatis harian**: setiap hari kalau ada perubahan (sebelumnya seminggu sekali). Disimpan 14 file terakhir (sebelumnya 8).
- **Antrean "Perlu dicek"** sekarang menampung 300 notifikasi (sebelumnya 50). Kalau tinggal 60 lagi penuh, muncul peringatan di Beranda.

### Ditambah
- **Pengingat simpan ke Google Drive** di Beranda kalau salinan terakhir sudah lebih dari 7 hari.
- **Cek kesehatan data** memberi tahu kalau ada notifikasi lama yang terbuang karena antrean penuh, salinan Drive sudah lama, atau penyimpanan gagal.
- **Peringatan kalau penyimpanan gagal** paling atas di Beranda (sebelumnya gagal diam-diam).

### Diperbaiki
- **Notifikasi bank tidak bisa hilang saat app ditutup paksa**: antrean notifikasi baru dikosongkan setelah isinya benar-benar tersimpan.
- **Keamanan build**: action GitHub dikunci ke kode commit tertentu, jadi tidak bisa diganti diam-diam oleh pihak lain.

## v3.1 (8 Okt 2026)

Perbaikan kecil setelah v3.0. Data lama aman, cukup pasang di atas versi sebelumnya.

### Diperbaiki
- **Input kurs**: "17.910" sekarang terbaca 17.910 Rupiah (sebelumnya terbaca 17,91). Kolom kurs memakai format Indonesia: titik untuk ribuan, koma untuk desimal (JPY 113,28). Di bawah tiap kolom ada keterangan "Terbaca: 1 USD = Rp 17.910" supaya bisa dicek sebelum disimpan.
- **Hapus piutang patungan**: kalau piutangnya belum lunas, Infinity bertanya dulu sisanya diapakan: *tidak dibayar* (sisa jadi pengeluaranmu) atau *salah catat* (sisa dikembalikan ke akun yang dulu membayar). Saldo Talangan Patungan tetap cocok, tidak ada uang "nyangkut".
- **Halaman Kategori**: item paling bawah tidak lagi tertutup bar navigasi gestur di HP Android 15/16.

## v3.0 (8 Okt 2026)

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

