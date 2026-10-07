# Infinity — proyek Flutter

Aplikasi pengelola keuangan pribadi. Isi folder ini:

```
lib/main.dart                  semua kode Dart aplikasi
android_overlay/               file native Android (Kotlin, manifest, widget, tema)
tool/setup_android.py          memasang android_overlay ke proyek hasil flutter create
.github/workflows/build-apk.yml   build APK otomatis di GitHub
```

Butuh **Flutter 3.38.1 atau lebih baru**.

---

## Cara A — Build otomatis di GitHub (tanpa install apa pun di PC)

1. Buat repo **privat** baru di GitHub, unggah seluruh isi folder ini (termasuk folder `.github`).
2. Buka tab **Actions** di repo, tunggu workflow "Build APK Infinity" selesai (±10 menit).
3. Klik run yang berhasil, unduh artifact **infinity-apk**, ekstrak, lalu install `app-release.apk` di HP.

**Penting, sekali saja:** isi secret `DEBUG_KEYSTORE_BASE64` (Settings > Secrets and variables > Actions) supaya setiap update bisa langsung di-install tanpa uninstall. Tanpa itu, update harus uninstall dulu dan **data di HP ikut hilang** (backup dulu lewat menu Backup). Claude bisa membantu membuatkan keystore-nya.

## Cara B — Build sendiri di PC

```bash
flutter create --org com.jose --project-name infinity --platforms android infinity_app
cd infinity_app
# salin lib/main.dart, android_overlay/, dan tool/ dari folder ini ke infinity_app/
rm -rf test
flutter pub add intl flutter_secure_storage local_auth flutter_local_notifications timezone home_widget
python3 tool/setup_android.py
flutter run            # HP tersambung USB, USB debugging aktif
flutter build apk      # hasil: build/app/outputs/flutter-apk/app-release.apk
```

`setup_android.py` otomatis:
- menyalin manifest (izin notifikasi, biometrik, layanan pembaca notifikasi, widget) — manifest lama disimpan sebagai `.bak`
- menyalin `MainActivity.kt` (FlutterFragmentActivity + mode layar aman), `NotificationCaptureService.kt`, `InfinityWidgetProvider.kt`, layout widget, dan tema AppCompat
- menyesuaikan nama package Kotlin dengan proyekmu
- mengatur `build.gradle.kts`: desugaring, `minSdk = 24`, multidex, dependency `desugar_jdk_libs` + `appcompat`
- memperingatkan kalau Android Gradle Plugin di bawah 8.11.1

Tidak punya Python? Lakukan langkah di atas manual: salin isi `android_overlay/` ke `android/`, lalu edit `android/app/build.gradle.kts` sesuai daftar di atas.

---

## Setelah install

| Fitur | Yang perlu dilakukan |
|---|---|
| Notifikasi pengingat | Pilih **Izinkan** saat diminta. Tes di Lainnya > Notifikasi > Kirim notifikasi tes. |
| Catat otomatis dari notifikasi bank/e-wallet | Lainnya > Catat Otomatis > Buka pengaturan akses notifikasi > aktifkan Infinity. Android 13+: kalau muncul **"Setelan terbatas"**, buka Info aplikasi Infinity > menu ⋮ > **Izinkan setelan terbatas**, lalu ulangi. |
| Sidik jari / wajah | Lainnya > Keamanan > pasang PIN, lalu aktifkan "Buka dengan sidik jari / wajah". |
| Widget | Tekan lama layar utama > Widget > Infinity. |
| Xiaomi / Oppo / Vivo / Realme | Info aplikasi > Baterai > **Tanpa batasan** (dan **Mulai otomatis** kalau ada), supaya pengingat & catat otomatis tidak dimatikan sistem. |

## Keamanan, ringkas
- Data disimpan **terenkripsi** di HP (flutter_secure_storage: kunci di Android Keystore, AES-GCM). Tidak ada server, tidak ada internet.
- PIN ada di penyimpanan terenkripsi dan **tidak ikut** file backup. Salah 5 kali = jeda 30 detik.
- Mode layar aman (default aktif): isi app tersembunyi di daftar aplikasi terbaru, screenshot diblokir.
- Notifikasi pengingat default **tanpa nominal**, dan isinya disembunyikan di layar kunci.
- Backup JSON yang disalin otomatis dihapus dari clipboard setelah 60 detik. File backup sendiri **tidak terenkripsi**: simpan di tempat pribadi.
- Data widget (teks saldo) tersimpan tanpa enkripsi karena dibaca sistem Android. Kalau saldo disembunyikan di app, widget ikut menampilkan "••••".
- Antrean notifikasi yang tertangkap disimpan sementara tanpa enkripsi di penyimpanan privat app sampai Infinity dibuka.
