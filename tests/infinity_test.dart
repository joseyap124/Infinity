// Tes otomatis untuk logika uang Infinity. Dijalankan CI sebelum build APK.
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinity/main.dart';

Account acc(String id, {double initial = 0, AccountType type = AccountType.bank, String currency = 'IDR'}) =>
    Account(id: id, name: id.toUpperCase(), type: type, initialBalance: initial, color: 0xFF000000, currency: currency);

Transaction tx(String id, TxType type, double amount, String from,
        {String? to, double? toAmount, String? cat, String title = 'x', DateTime? date}) =>
    Transaction(
        id: id,
        title: title,
        amount: amount,
        type: type,
        accountId: from,
        toAccountId: to,
        toAmount: toAmount,
        categoryId: cat,
        date: date ?? DateTime(2026, 10, 1, 12));

AppStore storeWith(List<Account> accounts, [List<Transaction> txs = const []]) {
  final s = AppStore();
  s.accounts = [...accounts];
  s.transactions = [...txs];
  return s;
}

void main() {
  group('Saldo', () {
    test('pemasukan, pengeluaran, transfer', () {
      final s = storeWith([acc('a', initial: 100000), acc('b')], [
        tx('1', TxType.income, 50000, 'a'),
        tx('2', TxType.expense, 30000, 'a'),
        tx('3', TxType.transfer, 20000, 'a', to: 'b'),
      ]);
      expect(s.balanceOf('a'), 100000);
      expect(s.balanceOf('b'), 20000);
    });

    test('transfer beda mata uang memakai jumlah diterima', () {
      final s = storeWith([acc('idr', initial: 1000000), acc('usd', currency: 'USD')], [
        tx('1', TxType.transfer, 163000, 'idr', to: 'usd', toAmount: 10),
      ]);
      expect(s.balanceOf('idr'), 837000);
      expect(s.balanceOf('usd'), 10);
    });

    test('excludeTxId mengabaikan transaksi yang sedang diedit', () {
      final s = storeWith([acc('a', initial: 100)], [tx('1', TxType.expense, 40, 'a')]);
      expect(s.balanceOf('a', excludeTxId: '1'), 100);
    });

    test('penyesuaian saldo dicatat sebagai transaksi', () {
      final s = storeWith([acc('a', initial: 100000)]);
      s.addBalanceAdjustment(s.accounts.first, -25000);
      expect(s.balanceOf('a'), 75000);
      expect(s.transactions.single.type, TxType.expense);
      s.addBalanceAdjustment(s.accounts.first, 5000);
      expect(s.balanceOf('a'), 80000);
    });
  });

  group('Akun', () {
    test('urutkan akun (aturan ReorderableListView)', () {
      final s = storeWith([acc('a'), acc('b'), acc('c')]);
      s.moveAccount(0, 3); // a ke paling bawah
      expect(s.accounts.map((a) => a.id), ['b', 'c', 'a']);
      s.moveAccount(2, 0);
      expect(s.accounts.map((a) => a.id), ['a', 'b', 'c']);
    });

    test('hapus akun ikut menghapus transaksinya', () {
      final s = storeWith([acc('a', initial: 10), acc('b')], [
        tx('1', TxType.expense, 1, 'a'),
        tx('2', TxType.transfer, 1, 'b', to: 'a'),
        tx('3', TxType.expense, 1, 'b'),
      ]);
      expect(s.deleteAccountWithData('a'), isNull);
      expect(s.transactions.map((t) => t.id), ['3']);
    });

    test('akun utama dipakai sebagai bawaan', () {
      final s = storeWith([acc('a'), acc('b')]);
      expect(s.defaultAccountId, 'a');
      s.settings.defaultAccountId = 'b';
      expect(s.defaultAccountId, 'b');
      s.settings.defaultAccountId = 'hilang';
      expect(s.defaultAccountId, 'a');
    });
  });

  group('Catat otomatis', () {
    AppStore setup() {
      final s = storeWith([acc('bca', initial: 1000000)]);
      s.categories = [
        TxCategory(id: 'lain', name: 'Lain lain', type: TxType.expense, icon: 'other', color: 0),
      ];
      s.settings.captureMode = 'auto';
      return s;
    }

    Map<String, dynamic> notif(DateTime at) => {
          'pkg': 'com.bca.mybca.omni.android',
          'title': 'myBCA',
          'text': 'Transfer berhasil sebesar Rp 50.000,00',
          'time': at.millisecondsSinceEpoch,
        };

    test('notifikasi baru langsung dicatat', () {
      final s = setup();
      expect(s.ingestCaptured([notif(DateTime.now())]), 1);
      expect(s.balanceOf('bca'), 950000);
    });

    test('notifikasi sebelum saldo diubah manual tidak mengubah saldo', () {
      final s = setup();
      final at = DateTime.now().subtract(const Duration(minutes: 5));
      s.settings.balanceSetAt['bca'] = DateTime.now().toIso8601String();
      expect(s.ingestCaptured([notif(at)]), 0);
      expect(s.balanceOf('bca'), 1000000);
      expect(s.pendingCaptures, hasLength(1));
    });
  });

  group('Utang & target', () {
    test('cicilan utang dan lunas', () {
      final s = storeWith([acc('a')]);
      final d = Debt(id: 'd', person: 'Budi', theyOwe: true, amount: 500000, date: DateTime(2026, 10, 1));
      s.upsertDebt(d);
      s.payDebt(d, 200000);
      expect(d.remaining, 300000);
      expect(s.debtTotal(theyOwe: true), 300000);
      s.payDebt(d, 999999); // tidak boleh lebih dari sisa
      expect(d.settled, isTrue);
      expect(d.paid, 500000);
      expect(s.debtTotal(theyOwe: true), 0);
    });

    test('lewat tenggat', () {
      final d = Debt(id: 'd', person: 'X', theyOwe: false, amount: 1, date: DateTime(2026, 1, 1), due: DateTime(2026, 2, 1));
      expect(d.overdue(DateTime(2026, 2, 2)), isTrue);
      expect(d.overdue(DateTime(2026, 2, 1, 23)), isFalse);
    });

    test('target ikut saldo akun atau manual', () {
      final s = storeWith([acc('tab', initial: 2500000)]);
      final linked = Goal(id: 'g1', name: 'Darurat', target: 10000000, accountId: 'tab', color: 0);
      final manual = Goal(id: 'g2', name: 'Liburan', target: 3000000, color: 0, deadline: DateTime(2027, 1, 15));
      expect(s.goalProgress(linked), 2500000);
      s.addToGoal(manual, 1000000);
      s.addToGoal(manual, -5000000); // tidak boleh minus
      expect(s.goalProgress(manual), 0);
      s.addToGoal(manual, 1200000);
      expect(s.goalPerMonth(manual, DateTime(2026, 10, 8)), closeTo(600000, 0.01));
    });

    test('tersimpan dan terbaca ulang lewat JSON', () {
      final s = storeWith([acc('a')]);
      s.debts = [Debt(id: 'd', person: 'Ani', theyOwe: false, amount: 50000, date: DateTime(2026, 10, 1), payments: [DebtPayment(date: DateTime(2026, 10, 2), amount: 10000)])];
      s.goals = [Goal(id: 'g', name: 'HP baru', target: 4000000, color: 1, saved: 500000)];
      final s2 = AppStore();
      s2.importJson(s.exportJson());
      expect(s2.debts.single.remaining, 40000);
      expect(s2.goals.single.saved, 500000);
    });
  });

  group('Ekspor Excel', () {
    test('ekspor lalu impor ulang menghasilkan transaksi yang sama', () {
      final s = storeWith([acc('bca', initial: 100), acc('gopay')], [
        tx('1', TxType.expense, 25000, 'bca', cat: 'makan', title: 'Nasi & teh <manis>', date: DateTime(2026, 10, 3, 12, 30)),
        tx('2', TxType.transfer, 50000, 'bca', to: 'gopay', date: DateTime(2026, 10, 4, 9)),
        tx('3', TxType.income, 7000000, 'bca', title: 'Gaji', date: DateTime(2026, 10, 1, 8)),
      ]);
      s.categories = [
        TxCategory(id: 'pokok', name: 'Kebutuhan Pokok', type: TxType.expense, icon: 'home', color: 0),
        TxCategory(id: 'makan', name: 'Makan', type: TxType.expense, icon: 'food', color: 0, parentId: 'pokok'),
      ];
      final rows = parseMoneyManagerXlsx(buildXlsx('Infinity', s.exportRows(null)));
      expect(rows, hasLength(3));
      final makan = rows.firstWhere((r) => r.kind == 'Expense');
      expect(makan.category, 'Kebutuhan Pokok');
      expect(makan.subcategory, 'Makan');
      expect(makan.note, 'Nasi & teh <manis>');
      expect(makan.date, DateTime(2026, 10, 3, 12, 30));
      final tf = rows.firstWhere((r) => r.kind == 'Transfer-Out');
      expect(tf.category, 'GOPAY');
      final fresh = storeWith([acc('bca'), acc('gopay')]);
      fresh.categories = s.categories;
      final plan = fresh.planMoneyManagerImport(rows);
      expect(plan.transactions, hasLength(3));
      expect(plan.newAccounts, isEmpty);
    });

    test('ringkasan bulan ini vs bulan lalu (hari yang sama)', () {
      final s = storeWith([acc('a')], [
        tx('1', TxType.expense, 100000, 'a', cat: 'x', date: DateTime(2026, 10, 5)),
        tx('2', TxType.expense, 50000, 'a', cat: 'x', date: DateTime(2026, 9, 4)),
        tx('3', TxType.expense, 999999, 'a', cat: 'x', date: DateTime(2026, 9, 20)), // setelah tgl 8, tidak dihitung
      ]);
      final m = s.monthCompare(DateTime(2026, 10, 8, 10));
      expect(m.expenseNow, 100000);
      expect(m.expenseBefore, 50000);
      expect(m.expensePct, closeTo(100, 0.001));
    });
  });

  group('Struk (OCR)', () {
    test('total di baris yang sama, abaikan subtotal & total item', () {
      const text = 'INDOMARET\nJL MERDEKA 1\nRoti 12.500\nSusu 18.900\nSUBTOTAL 31.400\nTOTAL ITEM 2\nTOTAL 31.400\nTUNAI 50.000\nKEMBALI 18.600';
      expect(receiptTotal(text), 31400);
      expect(receiptMerchant(text), 'Indomaret');
    });
    test('angka total di baris berikutnya', () {
      const text = 'Kopi Kenangan\nGRAND TOTAL\nRp 48.000';
      expect(receiptTotal(text), 48000);
    });
    test('tanpa kata total = null', () {
      expect(receiptTotal('Parkir 5000'), isNull);
    });
  });

  group('Teks cepat', () {
    const cases = {
      '25rb kopi': 25000.0,
      '25 rbu nasgor': 25000.0,
      'kopi 25.000': 25000.0,
      '1,5jt hp': 1500000.0,
      '2 jta motor': 2000000.0,
      '12k ojek': 12000.0,
      '15000 parkir': 15000.0,
      '25 nasgor': 25000.0,
    };
    cases.forEach((input, want) {
      test(input, () => expect(parseQuickInput(input)?.amount, want));
    });
    test('tanpa angka = null', () => expect(parseQuickInput('kopi'), isNull));
  });

  group('Saran ketikan', () {
    test('awal kata, paling sering di atas', () {
      final s = storeWith([acc('a')], [
        tx('1', TxType.expense, 1, 'a', title: 'Potong rambut'),
        tx('2', TxType.expense, 1, 'a', title: 'Potong rambut'),
        tx('3', TxType.expense, 1, 'a', title: 'Pulsa'),
        tx('4', TxType.expense, 1, 'a', title: 'Pot bunga'),
      ]);
      expect(s.suggestTitles('pot', TxType.expense).first, 'Potong rambut');
      expect(s.suggestTitles('ram', TxType.expense), ['Potong rambut']);
      expect(s.suggestTitles('pot', TxType.income), isEmpty);
    });
  });

  group('Import Money Manager', () {
    test('kunci nama mengabaikan emoji, spasi, kurung', () {
      expect(mmKey('Health (Obat , Vitamin, Medcheck)💊'), mmKey('Health (Obat, Vitamin) 💊'));
      expect(mmKey('Darurat/Lain lain 🆘'), mmKey('Darurat / Lain lain 🆘'));
    });

    test('rencana import: akun baru, transfer, anti-dobel', () {
      final s = storeWith([acc('bca')]);
      s.categories = [
        TxCategory(id: 'pokok', name: 'Kebutuhan Pokok 📅', type: TxType.expense, icon: 'home', color: 0),
        TxCategory(id: 'makan', name: 'Makan dan Minum 🍲', type: TxType.expense, icon: 'food', color: 0, parentId: 'pokok'),
      ];
      final rows = [
        MmRow(date: DateTime(2026, 10, 6, 20, 34), account: 'BCA', category: 'Kebutuhan Pokok 📅', subcategory: 'Makan dan Minum 🍲', note: 'market', description: '', kind: 'Expense', amount: 36900, currency: 'IDR'),
        MmRow(date: DateTime(2026, 10, 6, 8, 45), account: 'Seabank', category: 'BCA', subcategory: '', note: '', description: '', kind: 'Transfer-Out', amount: 28000, currency: 'IDR'),
        MmRow(date: DateTime(2026, 10, 5), account: 'BCA', category: 'Hiburan', subcategory: 'Jajan 🌮', note: '', description: '', kind: 'Expense', amount: 18000, currency: 'IDR'),
        MmRow(date: DateTime(2026, 10, 5), account: 'BCA', category: 'Seabank', subcategory: '', note: '', description: '', kind: 'Transfer-In', amount: 5, currency: 'IDR'),
      ];
      final plan = s.planMoneyManagerImport(rows);
      expect(plan.expense, 2);
      expect(plan.transfer, 1);
      expect(plan.skipped, 1);
      expect(plan.newAccounts.map((a) => a.name), ['Seabank']);
      expect(plan.transactions.first.categoryId, 'makan');
      s.applyMoneyManagerImport(plan);
      final again = s.planMoneyManagerImport(rows);
      expect(again.transactions, isEmpty);
      expect(again.duplicates, 3);
    });

    test('baca xlsx (shared strings + tanggal seri Excel)', () {
      String x(String body) => '<?xml version="1.0"?>$body';
      final strings = ['Date', 'Account', 'Category', 'Subcategory', 'Note', 'IDR', 'Income/Expense', 'Description', 'Amount', 'Currency', 'BCA', 'Makan &amp; Minum', 'Expense', '36900.0'];
      final sst = x('<sst>${strings.map((t) => '<si><t>$t</t></si>').join()}</sst>');
      String c(String ref, int idx) => '<c r="$ref" t="s"><v>$idx</v></c>';
      final sheet = x('<worksheet><sheetData>'
          '<row r="1">${List.generate(10, (i) => c('${String.fromCharCode(65 + i)}1', i)).join()}</row>'
          '<row r="2"><c r="A2" s="2" t="n"><v>46301.5</v></c>${c('B2', 10)}${c('C2', 11)}<c r="D2" t="s"><v>4</v></c><c r="F2" t="n"><v>36900.0</v></c>${c('G2', 12)}${c('I2', 13)}<c r="J2" t="inlineStr"><is><t>IDR</t></is></c></row>'
          '</sheetData></worksheet>');
      final arc = Archive()
        ..addFile(ArchiveFile('xl/sharedStrings.xml', utf8.encode(sst).length, utf8.encode(sst)))
        ..addFile(ArchiveFile('xl/worksheets/sheet1.xml', utf8.encode(sheet).length, utf8.encode(sheet)));
      final List<int>? zip = ZipEncoder().encode(arc);
      final rows = parseMoneyManagerXlsx(zip!);
      expect(rows, hasLength(1));
      expect(rows.first.account, 'BCA');
      expect(rows.first.category, 'Makan & Minum');
      expect(rows.first.amount, 36900);
      expect(rows.first.date, DateTime(2026, 10, 6, 12));
    });
  });

  group('Backup terenkripsi', () {
    test('enkripsi lalu buka kembali', () async {
      final enc = await SecureBackup.encrypt('{"a":1}', {'r_1.jpg': [1, 2, 3]}, 'rahasia123');
      expect(SecureBackup.looksEncrypted(enc), isTrue);
      expect(utf8.decode(enc, allowMalformed: true).contains('"a"'), isFalse);
      final (json, photos) = await SecureBackup.decrypt(enc, 'rahasia123');
      expect(json, '{"a":1}');
      expect(photos['r_1.jpg'], [1, 2, 3]);
    });

    test('kata sandi salah ditolak', () async {
      final enc = await SecureBackup.encrypt('{}', {}, 'benar123');
      await expectLater(SecureBackup.decrypt(enc, 'salah123'), throwsFormatException);
    });
  });
}
