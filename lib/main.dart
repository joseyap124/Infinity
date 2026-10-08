// =============================================================================
// INFINITY - Personal Finance Manager (single-file Flutter app)
// -----------------------------------------------------------------------------
// Kebutuhan:
//   - Flutter 3.38.1+ (syarat flutter_local_notifications v22)
//   - flutter pub add intl flutter_secure_storage local_auth \
//       flutter_local_notifications timezone home_widget
//   - Setup Android (notifikasi, biometrik, catat otomatis, widget): README.md
//
// Fitur: multi-akun (e-wallet, tunai, bank, kartu kredit, investasi), multi mata
// uang, transfer antar akun, edit/hapus/duplikat transaksi, kategori & sub-
// kategori kustom, anggaran mingguan/bulanan/tahunan (global & per kategori),
// transaksi berulang, template, kalender, pencarian, kalkulator, statistik &
// tren, backup/restore JSON, kunci PIN + biometrik, penyimpanan terenkripsi,
// notifikasi pengingat, catat otomatis dari notifikasi bank/e-wallet, dan
// widget layar utama.
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
// NOTIF-IMPORTS-BEGIN
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
// NOTIF-IMPORTS-END
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
// STORAGE-IMPORTS-BEGIN
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// STORAGE-IMPORTS-END
// BIO-IMPORTS-BEGIN
import 'package:local_auth/local_auth.dart' as la;
// BIO-IMPORTS-END
// WIDGET-IMPORTS-BEGIN
import 'package:home_widget/home_widget.dart';

part 'src/01_design_tokens.dart';
part 'src/02_format_parsing.dart';
part 'src/03_date_helpers.dart';
part 'src/04_enums.dart';
part 'src/05_models.dart';
part 'src/06_platform_penyimpanan_terenkripsi_biometr.dart';
part 'src/07_store_seluruh_data_logika_bisnis.dart';
part 'src/08_notifikasi.dart';
part 'src/09_app_shell.dart';
part 'src/10_shared_ui.dart';
part 'src/11_salin_tempel_struk.dart';
part 'src/12_aksi_transaksi.dart';
part 'src/13_tab_1_beranda.dart';
part 'src/14_tab_2_riwayat.dart';
part 'src/15_tab_3_statistik.dart';
part 'src/16_tab_4_lainnya.dart';
part 'src/17_form_transaksi_berulang_template.dart';
part 'src/18_detail_transaksi.dart';
part 'src/19_kalkulator.dart';
part 'src/20_halaman_akun.dart';
part 'src/21_halaman_kategori.dart';
part 'src/22_halaman_anggaran.dart';
part 'src/23_halaman_transaksi_berulang.dart';
part 'src/24_halaman_template.dart';
part 'src/25_halaman_mata_uang_kurs.dart';
part 'src/26_halaman_notifikasi.dart';
part 'src/27_halaman_catat_otomatis_dari_notifikasi.dart';
part 'src/28_pin.dart';
part 'src/29_halaman_backup_pulihkan.dart';
part 'src/30_import_dari_money_manager.dart';
part 'src/31_utang_piutang_target_tabungan.dart';
part 'src/32_ekspor_excel_ringkasan_bulanan.dart';
part 'src/33_aman_dibelanjakan_insight.dart';
part 'src/34_riwayat_akun.dart';
// WIDGET-IMPORTS-END

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  runApp(const InfinityApp());
}
