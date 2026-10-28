# Infinity: dokumen teknis

Untuk siapa pun (termasuk AI) yang akan mengubah kode. Setiap klaim di sini sudah dicocokkan dengan kode pada v6.6.0. Kalau kode berubah dan dokumen ini tidak, percayai kodenya, lalu perbaiki dokumen ini.

## Bentuk proyek

Repo ini **tidak berisi proyek Flutter utuh**. Tidak ada `pubspec.yaml` dan tidak ada folder `android/`. CI membuatnya setiap kali lewat `tool/ci_setup.sh`:

1. `flutter create` proyek baru, lalu menyalin `tests/` menjadi `test/`.
2. `flutter pub add` paket dari `tool/versions.env`, lalu mengunci dependensi dengan `tool/pubspec.lock`.
3. `tool/setup_android.py` menyalin `android_overlay/` (Kotlin, manifest, widget, ikon) dan menyetel Gradle.

Versi terkunci: Flutter 3.47.6, Dart 3.13.5 (`tool/versions.env`).

Kode Dart adalah **satu library**: `lib/main.dart` memuat `lib/src/NN_nama.dart` sebagai `part`. Semua file bisa saling mengakses nama privat. Nomor file mengikuti urutan dibuatnya, bukan urutan ketergantungan. File baru ditambahkan dengan satu baris `part` di `main.dart`.

## Peta kode

| Perlu mengubah | Buka |
|---|---|
| Warna, token desain, `AppCard`, `PrimaryButton` | `01_design_tokens.dart`, `10_shared_ui.dart` |
| Enum jenis transaksi, akun, periode | `04_enums.dart` |
| Model data dan JSON-nya | `05_models.dart` |
| Penyimpanan terenkripsi, kunci, jembatan native | `06_platform_penyimpanan_terenkripsi_biometr.dart` |
| Logika bisnis (saldo, jumlah, simpan, gabung) | `07_store_seluruh_data_logika_bisnis.dart` (file terbesar) |
| Kerangka app, tab bawah, kunci PIN | `09_app_shell.dart`, `28_pin.dart` |
| Beranda | `13_tab_1_beranda.dart` |
| Form Catat (transaksi, berulang, template) | `17_form_transaksi_berulang_template.dart` |
| Daftar transaksi dan aksinya | `12_aksi_transaksi.dart`, `14_tab_2_riwayat.dart` |
| Anggaran | `22_halaman_anggaran.dart` |
| Jatah harian dan saran Beranda | `33_aman_dibelanjakan_insight.dart` |
| Maskot, ritme anggaran | `55_maskot.dart`, `56_ritme_budget.dart` |
| Saklar fitur | `53_fitur.dart`, `kFeatureDefaults` di `05_models.dart` |
| Panduan dan FAQ di app | `40_panduan_bantuan.dart` |
| Terjemahan | `47_bahasa.dart` (mesin), `48_terjemahan_en.dart` dan `49_terjemahan_zh.dart` (hasil generate, jangan diedit tangan) |
| Notifikasi bank dan e-wallet | `27_...catat_otomatis...dart`, `60_log_tangkapan.dart`, Kotlin `NotificationCaptureService.kt` |

Bar bawah (v7.0.0): empat tab (Beranda, Riwayat, Rencana, Statistik) dan tombol **Catat** bulat di tengah, widget `_BottomBar` di `09_app_shell.dart`. Pengaturan (dulu tab Lainnya, kelas `MoreTab` di `16_tab_4_lainnya.dart`) adalah halaman yang dibuka dari ikon gerigi di kartu utama Beranda; baris Preferensi di dalamnya membuka `SettingsPage` (`43_rencana_pengaturan.dart`).

Kartu informasi "Perlu perhatian" (`InsightStrip`, `33_...insight.dart`): id yang berawalan `kInsightDismissOnce` (recap, proj, event, bill, inst, cc, unusual) disembunyikan selamanya setelah ditutup; id lain (save_fail, pend_full, rates, debt, goal) muncul lagi besok. Aturannya di `insightHidden`; `pruneDismissedInsights` membuang catatan lebih dari 62 hari. Petunjuk Catat cepat dihitung di `AppSettings.quickHintSeen` (opsional, ditulis hanya kalau > 0).

## Data

### Penyimpanan

- Seluruh data satu objek JSON di memori (`AppStore`, sebuah `ChangeNotifier`): `accounts`, `categories`, `transactions`, `recurring`, `installments`, `waitItems`, `templates`, `debts`, `goals`, `events`, `settings`.
- Disimpan ke `infinity_data.bin` di folder dukungan app. Isi file: nonce 12 byte, MAC 16 byte, lalu data, dienkripsi **AES-256-GCM** (`DataFile`).
- Kunci ada di Android Keystore lewat `flutter_secure_storage`, dengan salinan di `infinity_key.bak` di folder privat app. Kalau file ada tapi kunci tidak ditemukan, app **tidak membuat kunci baru** (itu membuat data lama tak terbuka) dan menampilkan layar "Data tidak bisa dibuka".
- Kalau data gagal dibuka (`dataLocked`), tidak ada yang ditulis sampai pengguna memilih.
- Setiap `_commit()` menaikkan `_rev`, memberi tahu UI, lalu `_persist()` menulis di akhir event yang sama. Satu tulis bisa menampung banyak perubahan beruntun.
- Kalau file diubah proses lain sejak dibaca (dua salinan app berjalan bersamaan), `flush()` memakai `_mergeForeign()` dan `mergeThreeWay()`, menyimpan salinan file itu dulu, lalu menulis hasil gabungan.

### Aturan kompatibilitas data (penting)

Data pengguna sudah ada di HP. Perubahan model harus tetap membuka data lama:

- Field baru **opsional** dengan nilai bawaan yang berarti "perilaku lama".
- Field baru ditulis ke JSON **hanya kalau bernilai bukan-bawaan**. Contoh: `Transaction.outside` ditulis sebagai `'outside': true` hanya saat true (`05_models.dart`), dan `AppSettings.specialBudget` hanya saat > 0.
- Membaca memakai `j['x'] == true` atau nilai bawaan, tidak pernah melempar karena field hilang.
- Setiap field baru butuh tes "data lama tanpa field ini tetap terbaca".

### Model utama

| Model | Hal yang perlu diingat |
|---|---|
| `Transaction` | `amount` selalu positif, dalam mata uang akun asal. `type` menentukan arah. Transfer beda mata uang memakai `toAmount`. `splits` membagi nominal ke beberapa kategori. `outside` menandai belanja di luar jatah harian. |
| `Account` | Tipe di `AccountType`. Saldo dihitung ulang dari saldo awal ditambah semua transaksi, jadi edit dan hapus selalu konsisten. |
| `RecurringRule` | Menghasilkan transaksi biasa (dengan `recurringId`) saat jatuh tempo lewat `processRecurring`. Transaksi hasilnya **tidak** bertanda `outside`. |
| `AppSettings` | Semua pengaturan, termasuk `globalBudget`, `specialBudget`, `budgetPeriod`, `periodStartDay`, tema, paket gaya, dan `features` (hanya pilihan yang berbeda dari `kFeatureDefaults`). |

Fitur yang bisa dimatikan (`kFeatureDefaults`): cicilan, utang, target, patungan, acara menyala bawaan; tunda beli mati bawaan. Data fitur yang mati tetap tersimpan, hanya disembunyikan dan tidak ikut hitungan.

## Rumus penting

### `safeToSpend(now)` di `33_aman_dibelanjakan_insight.dart`

Hasilnya `SafeSpend` dengan `perDay`, `spentToday`, `outsideToday`, `base`, `daysLeft`, `fromBudget`, `special`, `specialUsed`, dan daftar `parts` untuk rincian.

- `spentToday` = pengeluaran hari ini yang **tidak** bertanda `outside`. `outsideToday` = yang bertanda.
- `daysLeft = max(1, periodEnd - hari ini)`, jadi hari ini ikut dihitung. `perDay = max(0, base) / daysLeft`.
- `leftToday = perDay - spentToday`.

**Mode anggaran** (`globalBudget > 0`):
- Tanpa amplop: `base = anggaran - terpakai sebelum hari ini`.
- Dengan amplop (`specialBudget > 0`): `held = max(amplop, belanja outside sebelum hari ini)`, `base = anggaran - held - belanja biasa sebelum hari ini`.
- Dari `base` dikurangi lagi: transaksi berulang berjenis pengeluaran yang belum jatuh tempo sebelum akhir periode, dan cicilan yang jatuh tempo sampai sehari setelah periode berakhir.

**Mode saldo** (anggaran kosong):
- `base = saldo likuid + spentToday + outsideToday`. Belanja hari ini dikembalikan supaya jatah hari ini tidak mengecil oleh belanja hari ini.
- Akun kartu kredit dan investasi tidak dihitung. Tabungan dan dana darurat dilewati. Akun bertanda "jangan hitung" dikurangi sebesar yang ditahan.
- Ditambah pemasukan berulang sebelum akhir periode. Dikurangi tagihan kartu kredit jatuh tempo, utang jatuh tempo (fitur utang menyala), setoran target tabungan, tagihan berulang, dan cicilan.
- Amplop diabaikan di mode ini.

Akibat yang disengaja: jatah **hari ini** ditentukan oleh hari-hari sebelumnya; belanja hari ini hanya memperkecil jatah **besok**.

### Maskot (`mascotMoodFor`, `55_maskot.dart`)

Berurutan: mengantuk bila tidak ada transaksi `kSleepyDays` hari (dan ada akun); `over` bila `leftToday < 0`; lalu rasio `leftToday / perDay`: ≥ 0,8 senang, ≥ 0,5 aman, ≥ 0,3 hati-hati, selain itu bahaya. Belanja bertanda `outside` tidak masuk `spentToday`, jadi tidak menurunkan suasana.

## Terjemahan (EN dan 中文)

- Teks di kode ditulis dalam bahasa Indonesia dan jadi kunci. `Text` buatan app (menutupi `Text` Flutter) menerjemahkan teks literal otomatis. Teks dinamis harus lewat `tr('...')`.
- Kamus ditulis di `tool/i18n/trN.py` dengan `t('Indonesia','English','中文')`. Isian `{0}` harus sama di ketiga bahasa.
- Membuat ulang: `cd tool/i18n && python3 gen.py $(ls tr*.py | sed 's/\.py//' | sort -V | tr '\n' ' ')`. Ini menimpa `48_terjemahan_en.dart` dan `49_terjemahan_zh.dart`.
- `missing.py` tidak bisa dipercaya sepenuhnya (kadang menampilkan teks yang sudah diterjemahkan). Cara memeriksa yang lebih aman: cari teks barunya langsung di `tr*.py`.
- Teks tanpa terjemahan tampil dalam bahasa Indonesia, jadi kekurangan terjemahan tidak merusak layar.

## Tes dan CI

CI (GitHub Actions) adalah **satu-satunya** tempat kode dikompilasi dan dites. Tidak ada Dart atau Flutter di lingkungan kerja AI. Artinya: kode belum terbukti benar sampai CI hijau, dan tampilan belum terbukti bagus sampai Jose melihatnya di HP.

| Workflow | Kapan | Isinya |
|---|---|---|
| `Tes branch (tanpa rilis)` | push ke branch selain `main`, `ci-logs`, `ci-out` | tes, analyze, kompilasi web; hasil disimpan di branch `ci-out` |
| `Build APK Infinity` | push ke `main` (kecuali perubahan dokumen, lihat bawah) | tes, analyze, build APK, cek library 16 KB dan tanda tangan v1 (`tool/check_apk.py`), cek tanpa izin INTERNET (aapt2), rilis; kalau gagal, log ke branch `ci-logs` |
| `Sinkron catatan rilis` | `CHANGELOG.md` berubah di `main` | menyalin teks CHANGELOG ke halaman rilis |
| `Build prototipe web (iPhone)` | `lib/**` berubah di `main` | prototipe web; langkah publish pernah gagal sekali di v6.3.1 (hanya penerbitan) |

Hal yang menentukan hasil:
- **Tes memblokir**. `flutter analyze` tidak memblokir untuk warning dan info (`--no-fatal-infos --no-fatal-warnings`).
- Semua tes ada di satu berkas, `tests/infinity_test.dart` (266 tes saat ini), dikelompokkan dengan `group(...)`. Tes jatah harian ada di grup `Aman dibelanjakan & insight`.
- Perubahan hanya di `README.md`, `CHANGELOG.md`, `docs/**`, dan beberapa berkas pendukung **tidak** memicu build APK (`paths-ignore` di `build-apk.yml`).

## Alur rilis

1. Kerjakan di branch. Tunggu `Tes branch` hijau pada commit yang sama persis (cocokkan `headSha`).
2. Tambahkan bagian `## Berikutnya (vX.Y.Z)` di paling atas CHANGELOG, lengkap dengan "Belum terbukti".
3. Gabung ke `main`. Workflow `Build APK Infinity` mengambil versi dari heading itu. Kalau heading tidak ada, nomor dihitung dari tag dua bagian terakhir (`vA.B`), padahal rilis terbaru bertag tiga bagian, jadi nomornya bisa salah.
4. Setelah rilis terbit, ganti judul heading jadi `## vX.Y.Z (tanggal)` lewat satu commit khusus dokumen. Ini dilakukan manual, bukan oleh workflow.

Catatan lingkungan kerja AI: kueri GraphQL (`gh release list`) diblokir. Pakai `gh api repos/joseyap124/Infinity/releases/tags/vX.Y.Z`. Untuk menunggu CI, gunakan `gh run list --branch X --json headSha,status,conclusion,name`.

## Jebakan Flutter yang sudah pernah kena

- `Container(alignment: ...)` membuat anak melebar penuh.
- Anak `Stack` yang tidak `Positioned` menempel di kiri atas.
- Panel keypad yang tinggi menutupi chip dan form; tinggi keypad dibatasi 282 dp (v6.3.3).
- Penerusan deep link dimatikan lewat manifest.
