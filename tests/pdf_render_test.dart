// Membuat contoh laporan PDF di CI supaya tata letaknya bisa dilihat.
// Hasilnya ditulis ke folder sementara dan disalin workflow ke branch ci-out.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:infinity/main.dart';

Account _acc(String id, double initial) => Account(
    id: id,
    name: id.toUpperCase(),
    type: AccountType.bank,
    initialBalance: initial,
    color: 0xFF000000,
    currency: 'IDR');

Transaction _tx(String id, TxType type, double amount, String from,
        {String? cat, String title = '', required DateTime date}) =>
    Transaction(
        id: id,
        title: title,
        amount: amount,
        type: type,
        accountId: from,
        categoryId: cat,
        date: date);

Future<void> _loadRoboto() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  if (!dir.existsSync()) return;
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.split('/').last.startsWith('Roboto-'))
      .toList();
  if (files.isEmpty) return;
  final loader = FontLoader('Roboto');
  for (final f in files) {
    loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  }
  await loader.load();
  gPdfFont = 'Roboto';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('laporan PDF contoh dibuat dan valid', () async {
    await initializeDateFormatting('id_ID', null);
    await _loadRoboto();
    final cats = ['makan', 'transport', 'belanja', 'tagihan', 'hiburan'];
    final s = AppStore()
      ..accounts = [_acc('bca', 5000000), _acc('gopay', 100000)]
      ..categories = [
        for (final c in cats)
          TxCategory(
              id: c,
              name: c[0].toUpperCase() + c.substring(1),
              type: TxType.expense,
              icon: 'other',
              color: 0),
        const TxCategory(
            id: 'gaji',
            name: 'Gaji',
            type: TxType.income,
            icon: 'other',
            color: 0),
      ];
    final txs = <Transaction>[
      _tx('in1', TxType.income, 6750000, 'bca',
          cat: 'gaji', title: 'Gaji Oktober', date: DateTime(2026, 10, 1)),
    ];
    for (var i = 0; i < 75; i++) {
      txs.add(_tx('e$i', TxType.expense, 15000.0 + i * 3500, i.isEven ? 'bca' : 'gopay',
          cat: cats[i % cats.length],
          title: i % 7 == 0 ? '' : 'Catatan transaksi nomor ${i + 1} yang agak panjang sekali',
          date: DateTime(2026, 10, 1 + i % 28, 8 + i % 12)));
    }
    s.transactions = txs;
    final d = MonthReportData(s, DateTime(2026, 10, 1), DateTime(2026, 11, 3));
    final bytes = await buildMonthReportPdf(d);
    expect(String.fromCharCodes(bytes.sublist(0, 8)), startsWith('%PDF-1.4'));
    expect(bytes.length, greaterThan(2000));
    final tmp = Platform.environment['TMPDIR'] ?? '/tmp';
    File('$tmp/infinity_report.pdf').writeAsBytesSync(bytes);
    final short = await buildMonthReportPdf(d, withTransactions: false);
    File('$tmp/infinity_report_ringkas.pdf').writeAsBytesSync(short);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
