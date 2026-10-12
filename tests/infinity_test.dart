// Tes otomatis untuk logika uang Infinity. Dijalankan CI sebelum build APK.
import 'dart:convert';
import 'dart:io' show zlib;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
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
  setUpAll(() async {
    // Sama seperti main() app: format tanggal Indonesia.
    await initializeDateFormatting('id_ID', null);
  });

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

  group('v4.3 tombol notifikasi', () {
    const gopayTopUp =
        'Kamu berhasil isi saldo GO-PAY sebesar Rp250.000. Saldomu sekarang: Rp612.500.';
    AppStore setup() {
      final s = storeWith([
        acc('bca', initial: 1000000),
        acc('gopay', initial: 100000, type: AccountType.ewallet),
      ]);
      s.categories = [
        TxCategory(id: 'lain', name: 'Lain lain', type: TxType.expense, icon: 'other', color: 0),
        TxCategory(id: 'gaji', name: 'Gaji', type: TxType.income, icon: 'other', color: 0),
      ];
      s.settings.captureMode = 'ask';
      return s;
    }

    Map<String, dynamic> item(String decision,
            {DateTime? at,
            String pkg = 'com.bca.mybca.omni.android',
            String text = 'Transfer berhasil sebesar Rp 50.000,00',
            String qid = 'q1'}) =>
        {
          'pkg': pkg,
          'title': 'myBCA',
          'text': text,
          'time': (at ?? DateTime(2026, 10, 12, 9, 0)).millisecondsSinceEpoch,
          'qid': qid,
          'decision': decision,
        };

    test('Keluar mencatat pengeluaran', () {
      final s = setup();
      expect(s.applyCaptureDecisions([item('expense')]), (1, 0));
      final t = s.transactions.single;
      expect(t.type, TxType.expense);
      expect(t.accountId, 'bca');
      expect(t.amount, 50000);
      expect(t.note, startsWith('Dari notifikasi'));
      expect(s.balanceOf('bca'), 950000);
    });

    test('Masuk mencatat pemasukan walau teksnya tidak jelas', () {
      final s = setup();
      expect(s.applyCaptureDecisions([item('income')]), (1, 0));
      expect(s.transactions.single.type, TxType.income);
      expect(s.balanceOf('bca'), 1050000);
    });

    test('Abaikan tidak mencatat, dan tidak diproses dua kali', () {
      final s = setup();
      expect(s.applyCaptureDecisions([item('ignore')]), (0, 1));
      expect(s.transactions, isEmpty);
      // Notifikasi yang sama terkirim lagi, lalu user menekan Keluar.
      expect(s.applyCaptureDecisions([item('expense', qid: 'q2')]), (0, 0));
      expect(s.transactions, isEmpty);
    });

    test('pilihan yang sama dua kali hanya dicatat sekali', () {
      final s = setup();
      s.applyCaptureDecisions([item('expense'), item('expense', qid: 'q2')]);
      expect(s.transactions, hasLength(1));
    });

    test('pilihan menggantikan item di "Dari Notifikasi"', () {
      final s = setup();
      final at = DateTime(2026, 10, 12, 9, 0);
      s.ingestCaptured([
        {
          'pkg': 'com.bca.mybca.omni.android',
          'title': 'myBCA',
          'text': 'Transfer berhasil sebesar Rp 50.000,00',
          'time': at.millisecondsSinceEpoch,
        }
      ]);
      expect(s.pendingCaptures, hasLength(1));
      expect(s.applyCaptureDecisions([item('expense', at: at)]), (1, 0));
      expect(s.pendingCaptures, isEmpty);
      expect(s.transactions, hasLength(1));
    });

    test('akun yang tidak dikenal memakai akun utama', () {
      final s = setup();
      s.applyCaptureDecisions([
        item('expense', pkg: 'id.co.bankbaru', text: 'Pembayaran Rp 20.000 berhasil')
      ]);
      expect(s.transactions.single.accountId, s.defaultAccountId);
    });

    test('isi saldo e-wallet tetap menunggu dicek, bukan jadi pengeluaran', () {
      final s = setup();
      expect(
          s.applyCaptureDecisions(
              [item('expense', pkg: 'com.gojek.gopay', text: gopayTopUp)]),
          (0, 0));
      expect(s.transactions, isEmpty);
      expect(s.pendingCaptures, hasLength(1));
    });

    test('keputusan tak dikenal atau tanpa nominal dilewati', () {
      final s = setup();
      expect(
          s.applyCaptureDecisions([
            item('lainnya'),
            item('expense', text: 'Halo tanpa nominal', qid: 'q3'),
          ]),
          (0, 0));
      expect(s.transactions, isEmpty);
    });

    test('pengaturan native: nyala hanya kalau mode bukan mati dan saklar aktif', () {
      final s = setup();
      Map<String, dynamic> cfg() => jsonDecode(s.captureConfigJson());
      expect(cfg()['on'], true);
      s.settings.captureButtons = false;
      expect(cfg()['on'], false);
      s.settings.captureButtons = true;
      s.settings.captureMode = 'off';
      expect(cfg()['on'], false);
      s.settings.captureMode = 'auto';
      expect(cfg()['on'], true);
      expect((cfg()['pkgs'] as List), contains('seabank'));
      expect((cfg()['promo'] as List), contains('voucher'));
      expect(cfg()['out'], 'Keluar');
    });

    test('saklar tersimpan di pengaturan', () {
      final a = AppSettings()..captureButtons = false;
      expect(AppSettings.fromJson(a.toJson()).captureButtons, false);
      expect(AppSettings.fromJson(<String, dynamic>{}).captureButtons, true);
    });
  });

  group('v4.4 pilih banyak', () {
    AppStore setup() {
      final s = storeWith([
        acc('a', initial: 1000000),
        acc('b', initial: 500000),
        acc('usd', initial: 100, currency: 'USD'),
      ], [
        tx('e1', TxType.expense, 10000, 'a', cat: 'makan'),
        tx('e2', TxType.expense, 20000, 'a', cat: 'makan'),
        tx('i1', TxType.income, 300000, 'a', cat: 'gaji'),
        tx('t1', TxType.transfer, 50000, 'a', to: 'b'),
        tx('u1', TxType.expense, 5, 'usd', cat: 'makan'),
      ]);
      s.categories = [
        TxCategory(id: 'makan', name: 'Makan', type: TxType.expense, icon: 'food', color: 0),
        TxCategory(id: 'bensin', name: 'Bensin', type: TxType.expense, icon: 'fuel', color: 0),
        TxCategory(id: 'gaji', name: 'Gaji', type: TxType.income, icon: 'work', color: 0),
      ];
      return s;
    }

    Transaction byId(AppStore s, String id) =>
        s.transactions.firstWhere((t) => t.id == id);

    test('ubah kategori: hanya yang jenisnya sama, transfer dan jenis lain dilewati', () {
      final s = setup();
      final r = s.bulkSetCategory({'e1', 'e2', 'i1', 't1'}, 'bensin');
      expect(r, const BulkResult(2, 2));
      expect(byId(s, 'e1').categoryId, 'bensin');
      expect(byId(s, 'e2').categoryId, 'bensin');
      expect(byId(s, 'i1').categoryId, 'gaji');
      expect(byId(s, 't1').categoryId, isNull);
    });

    test('ubah kategori menggantikan pembagian (split)', () {
      final s = setup();
      final i = s.transactions.indexWhere((t) => t.id == 'e1');
      s.transactions[i] = s.transactions[i]
          .copyWith(splits: const [TxSplit('makan', 6000), TxSplit('bensin', 4000)]);
      s.bulkSetCategory({'e1'}, 'bensin');
      expect(byId(s, 'e1').splits, isEmpty);
      expect(byId(s, 'e1').categoryId, 'bensin');
    });

    test('ubah kategori ke kategori yang sama tidak dihitung berubah', () {
      final s = setup();
      expect(s.bulkSetCategory({'e1'}, 'makan'), const BulkResult(0, 0));
    });

    test('jenis kategori dari pilihan: transfer diabaikan', () {
      final s = setup();
      expect(s.categoryTypesOf({'e1', 't1'}), {TxType.expense});
      expect(s.categoryTypesOf({'e1', 'i1'}), {TxType.expense, TxType.income});
      expect(s.categoryTypesOf({'t1'}), isEmpty);
    });

    test('ubah akun: saldo ikut pindah; transfer dan beda mata uang dilewati', () {
      final s = setup();
      final r = s.bulkSetAccount({'e1', 'e2', 't1', 'u1'}, 'b');
      expect(r, const BulkResult(2, 2));
      expect(byId(s, 'e1').accountId, 'b');
      expect(byId(s, 'u1').accountId, 'usd');
      expect(byId(s, 't1').accountId, 'a');
      expect(s.balanceOf('b'), 500000 - 30000 + 50000);
    });

    test('hapus massal dan urungkan', () {
      final s = setup();
      final removed = s.bulkDelete({'e1', 'e2', 'tidak-ada'});
      expect(removed.map((t) => t.id), unorderedEquals(['e1', 'e2']));
      expect(s.transactions.any((t) => t.id == 'e1'), false);
      s.restoreTransactions(removed);
      expect(s.transactions.map((t) => t.id), containsAll(['e1', 'e2']));
      // Memulihkan dua kali tidak menggandakan.
      s.restoreTransactions(removed);
      expect(s.transactions.where((t) => t.id == 'e1'), hasLength(1));
    });

    test('urungkan ubah kategori mengembalikan isi semula', () {
      final s = setup();
      final before = s.transactionsByIds({'e1', 'e2'});
      s.bulkSetCategory({'e1', 'e2'}, 'bensin');
      s.restoreSnapshot(before);
      expect(byId(s, 'e1').categoryId, 'makan');
      expect(byId(s, 'e2').categoryId, 'makan');
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

  group('Notifikasi GoPay & cocokkan saldo', () {
    const topUp = 'Kamu berhasil isi saldo GO-PAY sebesar Rp250.000. Saldomu sekarang: Rp612.500.';
    AppStore setup({double gopay = 362500}) {
      final s = storeWith([
        acc('bca', initial: 2000000),
        acc('gopay', initial: gopay, type: AccountType.ewallet),
      ]);
      s.categories = [
        TxCategory(id: 'lain', name: 'Lain lain', type: TxType.expense, icon: 'other', color: 0),
      ];
      s.settings.captureMode = 'auto';
      return s;
    }

    Map<String, dynamic> n(String text, DateTime at) => {
          'pkg': 'com.gojek.app',
          'title': 'GoPay',
          'text': text,
          'time': at.millisecondsSinceEpoch,
        };

    test('nominal bukan angka saldo, isi saldo = transfer', () {
      final p = parseReceipt(topUp, setup());
      expect(p.amount, 250000);
      expect(p.balanceAfter, 612500);
      expect(p.isTopUp, isTrue);
      expect(p.type, TxType.transfer);
    });

    test('pembayaran dengan sisa saldo', () {
      final p = parseReceipt(
          'Pembayaran ke Kopi Kenangan Rp25.000 berhasil. Sisa saldo Rp150.000', setup());
      expect(p.amount, 25000);
      expect(p.balanceAfter, 150000);
      expect(p.isTopUp, isFalse);
    });

    test('email BCA berbahasa Inggris: "IDR 263,000.00" = 263000', () {
      final p = parseReceipt(
          'BCA Internet Transaction Journal\n'
          'Status : Successful\nTransaction Date : 11 Oct 2026 18:51:24\n'
          'Transfer Type : Transfer to BCA Virtual Account\n'
          'BCA Virtual Account No. : 7002785142784769\n'
          'Company/Product Name : DOMPET ANAK BANGSA PT / GoPay Transfer\n'
          'Bill Total : IDR 263,000.00\nTotal Payment : IDR 263,000.00',
          setup());
      expect(p.amount, 263000);
    });

    test('format angka Indonesia dan Inggris dibaca benar', () {
      double? amt(String t) => parseReceipt(t, setup()).amount;
      expect(amt('Pembayaran Rp1.250.000 berhasil'), 1250000);
      expect(amt('Pembayaran Rp1.250.000,00 berhasil'), 1250000);
      expect(amt('Pembayaran Rp 25.000 berhasil'), 25000);
      expect(amt('Payment IDR 1,250,000.50 done'), 1250000);
      expect(amt('Payment IDR 263000.00 done'), 263000);
      expect(amt('Payment IDR 25,000 done'), 25000);
    });

    test('promo diabaikan', () {
      final s = setup();
      s.ingestCaptured([n('Diskon Rp 5.000 di Kedai Boboko. Nikmati potongan harga senilai Rp 5.000', DateTime.now())]);
      expect(s.pendingCaptures, isEmpty);
      expect(s.transactions, isEmpty);
    });

    test('isi saldo masuk antrean sebagai transfer bank → GoPay', () {
      final s = setup();
      final at = DateTime.now().subtract(const Duration(minutes: 2));
      expect(s.ingestCaptured([n(topUp, at)]), 0);
      expect(s.pendingCaptures, hasLength(1));
      final d = s.draftFromCapture(s.pendingCaptures.single);
      expect(d.type, TxType.transfer);
      expect(d.amount, 250000);
      expect(d.accountId, 'bca');
      expect(d.toAccountId, 'gopay');
      // Selama masih menunggu dicek, belum dianggap selisih.
      expect(s.balanceMismatches(), isEmpty);
    });

    test('saldo cocok setelah isi saldo dicatat', () {
      final s = setup();
      final at = DateTime.now().subtract(const Duration(minutes: 2));
      s.ingestCaptured([n(topUp, at)]);
      final c = s.pendingCaptures.single;
      s.transactions.add(tx('t', TxType.transfer, 250000, 'bca', to: 'gopay', date: at));
      s.dismissCapture(c.id);
      expect(s.balanceMismatches(), isEmpty);
    });

    test('saldo beda lalu disamakan pada waktu notifikasi', () {
      final s = setup(gopay: 350000);
      final at = DateTime.now().subtract(const Duration(hours: 1));
      s.ingestCaptured([n(topUp, at)]);
      final c = s.pendingCaptures.single;
      s.transactions.add(tx('t', TxType.transfer, 250000, 'bca', to: 'gopay', date: at));
      s.dismissCapture(c.id);
      // Belanja sesudah notifikasi tidak boleh ikut dibandingkan.
      s.transactions.add(tx('k', TxType.expense, 20000, 'gopay', date: DateTime.now()));
      final m = s.balanceMismatches().single;
      expect(m.diff, 12500);
      s.reconcileBalance(m);
      expect(s.balanceMismatches(), isEmpty);
      expect(s.balanceOf('gopay'), 612500 - 20000);
    });
  });

  group('Aman dibelanjakan & insight', () {
    test('dari saldo: dibagi sisa hari, belanja hari ini terpisah', () {
      final now = DateTime(2026, 10, 22, 10);
      final s = storeWith([acc('a', initial: 3100000)], [
        tx('1', TxType.expense, 100000, 'a', date: DateTime(2026, 10, 22, 8)),
      ]);
      final r = s.safeToSpend(now);
      expect(r.fromBudget, isFalse);
      expect(r.daysLeft, 10);
      expect(r.perDay, closeTo(310000, 0.01));
      expect(r.leftToday, closeTo(210000, 0.01));
    });

    test('langganan terdeteksi dari 3 bulan berturut', () {
      final s = storeWith([acc('a', initial: 1000000)], [
        tx('1', TxType.expense, 54000, 'a', title: 'Netflix', date: DateTime(2026, 7, 5)),
        tx('2', TxType.expense, 54000, 'a', title: 'Netflix', date: DateTime(2026, 8, 5)),
        tx('3', TxType.expense, 54000, 'a', title: 'netflix ', date: DateTime(2026, 9, 5)),
        tx('4', TxType.expense, 30000, 'a', title: 'Bakso', date: DateTime(2026, 9, 6)),
      ]);
      final subs = s.detectSubscriptions(DateTime(2026, 10, 10));
      expect(subs, hasLength(1));
      expect(subs.single.amount, 54000);
      expect(subs.single.day, 5);
      s.dismissSubscription('Netflix');
      expect(s.detectSubscriptions(DateTime(2026, 10, 10)), isEmpty);
    });

    test('pengeluaran tidak biasa: 7 hari > 2x rata-rata', () {
      final now = DateTime(2026, 10, 22, 12);
      final s = storeWith([acc('a', initial: 5000000)], [
        for (var w = 1; w <= 8; w++)
          tx('h$w', TxType.expense, 50000, 'a', cat: 'makan', date: now.subtract(Duration(days: 7 * w + 1))),
        tx('n', TxType.expense, 200000, 'a', cat: 'makan', date: now.subtract(const Duration(days: 1))),
      ]);
      s.categories = [TxCategory(id: 'makan', name: 'Makan', type: TxType.expense, icon: 'food', color: 0)];
      final u = s.unusualSpending(now);
      expect(u.single.$1, 'makan');
      expect(u.single.$2, 200000);
    });
  });

  group('Splash', () {
    test('hanya saat pertama kali dibuka', () {
      expect(AppSettings().splashSeen, isFalse); // install baru
      expect(AppSettings().onboarded, isFalse); // install baru lihat panduan
      expect(AppSettings.fromJson({}).onboarded, isTrue); // pengguna lama tidak
      expect(AppSettings.fromJson({}).splashSeen, isTrue); // data versi lama
      final s = AppSettings()..splashSeen = true;
      expect(AppSettings.fromJson(s.toJson()).splashSeen, isTrue);
    });
  });

  group('Template', () {
    test('edit template tidak membuat template baru', () {
      final s = storeWith([acc('a')]);
      s.addTemplate(const TxTemplate(id: 't1', title: 'Kopi pagi', amount: 24000, type: TxType.expense, accountId: 'a'));
      s.addTemplate(const TxTemplate(id: 't2', title: 'Ojol', amount: 17000, type: TxType.expense, accountId: 'a'));
      s.updateTemplate(const TxTemplate(id: 't1', title: 'Kopi susu', amount: 28000, type: TxType.expense, accountId: 'a'));
      expect(s.templates, hasLength(2));
      expect(s.templates.first.title, 'Kopi susu');
      expect(s.templates.first.amount, 28000);
    });
  });

  group('Riwayat akun', () {
    test('saldo berjalan per akun, transfer masuk dan keluar', () {
      final s = storeWith([acc('sea', initial: 100000), acc('bca', initial: 500000)], [
        tx('1', TxType.expense, 20000, 'sea', date: DateTime(2026, 10, 1, 9)),
        tx('2', TxType.transfer, 50000, 'bca', to: 'sea', date: DateTime(2026, 10, 2, 9)),
        tx('3', TxType.income, 10000, 'bca', date: DateTime(2026, 10, 3, 9)),
        tx('4', TxType.transfer, 30000, 'sea', to: 'bca', date: DateTime(2026, 10, 4, 9)),
      ]);
      final l = s.accountLedger('sea');
      expect(l.map((e) => e.$1.id), ['1', '2', '4']);
      expect(l.map((e) => e.$2), [80000, 130000, 100000]);
      expect(l.last.$2, s.balanceOf('sea'));
      expect(s.accountDelta(l[1].$1, 'sea'), 50000);
      expect(s.accountLedger('bca').last.$2, s.balanceOf('bca'));
    });

    test('AUD tersedia dengan kurs awal', () {
      expect(kCurrencies, contains('AUD'));
      expect(kDefaultRates['AUD'], greaterThan(0));
      expect(hasDecimals('AUD'), isTrue);
      expect(currencySymbol('AUD'), 'A\$');
    });
  });

  group('Kurs & tabungan', () {
    test('kurs basi diingatkan hanya kalau ada akun asing', () {
      final now = DateTime(2026, 10, 8);
      final s = storeWith([acc('a')]);
      expect(s.staleRatesDays(now), isNull); // semua Rupiah
      s.accounts.add(acc('u', currency: 'USD'));
      expect(s.staleRatesDays(now), -1); // belum pernah diisi
      s.setRates({'USD': 17910}, at: DateTime(2026, 10, 1));
      expect(s.staleRatesDays(now), isNull);
      expect(s.staleRatesDays(DateTime(2026, 11, 15)), 45);
      expect(kDefaultRates['USD'], 17910);
    });

    test('akun tabungan tidak dihitung di aman dibelanjakan', () {
      final now = DateTime(2026, 10, 22, 10);
      final s = storeWith([
        acc('harian', initial: 1000000),
        const Account(id: 'tab', name: 'Tabungan', type: AccountType.bank, initialBalance: 9000000, color: 0, excludeSafe: true),
      ]);
      final r = s.safeToSpend(now);
      expect(r.perDay, closeTo(100000, 0.01)); // 1 juta / 10 hari
      expect(r.excluded, 9000000);
      final back = Account.fromJson(s.accounts[1].toJson());
      expect(back.excludeSafe, isTrue);
    });
  });

  group('Patungan', () {
    test('bagi rata dalam rupiah bulat, sisa ke bagian pertama', () {
      expect(splitEvenly(100000, 3), [33334, 33333, 33333]);
      expect(splitEvenly(300000, 4), [75000, 75000, 75000, 75000]);
    });

    test('saldo turun penuh, pengeluaran hanya bagianku, teman jadi piutang', () {
      final s = storeWith([acc('gopay', initial: 500000, type: AccountType.ewallet), acc('bca', initial: 0)]);
      s.categories = [TxCategory(id: 'makan', name: 'Makan', type: TxType.expense, icon: 'food', color: 0)];
      final n = s.recordSplit(
        title: 'Makan malam',
        payerAccountId: 'gopay',
        categoryId: 'makan',
        myShare: 75000,
        others: const [SplitShare('Andi', 75000), SplitShare('Budi', 75000), SplitShare('Cici', 75000)],
        date: DateTime(2026, 10, 8, 19),
      );
      expect(n, 3);
      expect(s.balanceOf('gopay'), 200000); // 500rb - 300rb
      expect(s.balanceOf(kTalanganId), 225000);
      expect(s.accountById(kTalanganId)!.excludeSafe, isTrue);
      final month = DateTimeRange(start: DateTime(2026, 10, 1), end: DateTime(2026, 11, 1));
      expect(s.sumIDR(TxType.expense, month), 75000); // hanya bagianku
      expect(s.debtTotal(theyOwe: true), 225000);

      // Andi bayar ke BCA: pindah dari Talangan ke BCA.
      final andi = s.debts.firstWhere((d) => d.person == 'Andi');
      s.receiveDebt(andi, 75000, toAccountId: 'bca');
      expect(andi.settled, isTrue);
      expect(s.balanceOf(kTalanganId), 150000);
      expect(s.balanceOf('bca'), 75000);
      expect(s.sumIDR(TxType.income, month), 0); // bukan pemasukan
      // Bayar lebih dari sisa tidak membuat saldo talangan minus.
      final budi = s.debts.firstWhere((d) => d.person == 'Budi');
      s.receiveDebt(budi, 999999, toAccountId: 'bca');
      expect(s.balanceOf(kTalanganId), 75000);
      final back = Debt.fromJson(budi.toJson());
      expect(back.holdAccountId, kTalanganId);
    });
  });

  group('Kekayaan bersih', () {
    test('saldo akhir tiap bulan, kartu kredit minus, akun asing dikurs', () {
      final s = storeWith([
        acc('bca', initial: 1000000),
        acc('cc', initial: 0, type: AccountType.credit),
        acc('usd', initial: 10, currency: 'USD'),
      ], [
        tx('1', TxType.income, 500000, 'bca', date: DateTime(2026, 8, 25)),
        tx('2', TxType.expense, 200000, 'cc', date: DateTime(2026, 9, 3)),
        tx('3', TxType.transfer, 100000, 'bca', to: 'cc', date: DateTime(2026, 10, 2)),
      ]);
      s.settings.rates['USD'] = 17000;
      final pts = s.netWorthHistory(DateTime(2026, 10, 8), months: 3);
      expect(pts.map((p) => p.month.month), [8, 9, 10]);
      expect(pts[0].value, 1500000 + 170000);
      expect(pts[1].value, 1300000 + 170000);
      // Transfer ke kartu kredit tidak mengubah kekayaan bersih.
      expect(pts[2].value, 1300000 + 170000);
    });
  });

  group('Acara', () {
    test('total acara, tandai otomatis, hapus acara melepas tanda', () {
      final s = storeWith([acc('a', initial: 5000000)]);
      final e = TxEvent(id: 'bali', name: 'Trip Bali', start: DateTime(2026, 12, 20), end: DateTime(2026, 12, 24), budget: 3000000);
      s.events.add(e);
      expect(s.autoEventFor(DateTime(2026, 12, 22, 10))?.id, 'bali');
      expect(s.autoEventFor(DateTime(2026, 12, 25, 0, 1)), isNull);
      s.transactions.addAll([
        Transaction(id: '1', title: 'Hotel', amount: 1500000, type: TxType.expense, accountId: 'a', date: DateTime(2026, 12, 20), eventId: 'bali'),
        Transaction(id: '2', title: 'Refund', amount: 200000, type: TxType.income, accountId: 'a', date: DateTime(2026, 12, 21), eventId: 'bali'),
        Transaction(id: '3', title: 'Lain', amount: 50000, type: TxType.expense, accountId: 'a', date: DateTime(2026, 12, 21)),
      ]);
      expect(s.eventSpent('bali'), 1300000);
      expect(Transaction.fromJson(s.transactions.first.toJson()).eventId, 'bali');
      expect(TxDraft.fromTransaction(s.transactions.first).toTransaction('x').eventId, 'bali');
      final back = TxEvent.fromJson(e.toJson());
      expect(back.budget, 3000000);
      expect(back.end, DateTime(2026, 12, 24));
      s.deleteEvent('bali');
      expect(s.events, isEmpty);
      expect(s.transactions.where((t) => t.eventId != null), isEmpty);
      expect(s.transactions, hasLength(3));
    });
  });

  group('Perkiraan akhir bulan', () {
    test('saldo sekarang + jadwal berulang yang belum tercatat', () {
      final now = DateTime(2026, 10, 8, 12);
      final s = storeWith([acc('bca', initial: 1000000), acc('gopay')]);
      s.recurring.addAll([
        RecurringRule(id: 'kos', title: 'Kos', amount: 1500000, type: TxType.expense, accountId: 'bca', frequency: Frequency.monthly, start: DateTime(2026, 10, 25, 8)),
        RecurringRule(id: 'isi', title: 'Isi GoPay', amount: 100000, type: TxType.transfer, accountId: 'bca', toAccountId: 'gopay', frequency: Frequency.weekly, start: DateTime(2026, 10, 10, 8)),
        RecurringRule(id: 'old', title: 'Lewat', amount: 999, type: TxType.expense, accountId: 'bca', frequency: Frequency.monthly, start: DateTime(2026, 11, 2, 8)),
      ]);
      final items = s.upcomingForAccount('bca', now);
      // Isi GoPay 10, 17, 24, 31 Okt + Kos 25 Okt. Jadwal November tidak ikut.
      expect(items, hasLength(5));
      expect(s.projectedMonthEnd('bca', now), 1000000 - 1500000 - 400000);
      expect(s.projectedMonthEnd('gopay', now), 400000);
    });
  });

  group('Catatan error', () {
    test('error dicatat dan bisa dihapus', () {
      ErrorLog.clear();
      expect(ErrorLog.count(), 0);
      ErrorLog.record(StateError('uji'), StackTrace.current, source: 'tes');
      expect(ErrorLog.count(), 1);
      expect(ErrorLog.read(), contains('Bad state: uji'));
      ErrorLog.clear();
      expect(ErrorLog.count(), 0);
    });
  });

  group('Kesehatan data & backup', () {
    test('dobel dan kategori hilang terdeteksi, kategori bisa diperbaiki', () {
      final s = storeWith([acc('a', initial: 100000)], [
        tx('1', TxType.expense, 25000, 'a', cat: 'kopi', title: 'Kopi', date: DateTime(2026, 10, 1, 9, 0)),
        tx('2', TxType.expense, 25000, 'a', cat: 'kopi', title: 'kopi ', date: DateTime(2026, 10, 1, 9, 1)),
        tx('3', TxType.expense, 25000, 'a', cat: 'kopi', title: 'Kopi', date: DateTime(2026, 10, 1, 12, 0)),
      ]);
      s.categories = [TxCategory(id: 'lain', name: 'Lain', type: TxType.expense, icon: 'other', color: 0)];
      expect(s.possibleDuplicates(), hasLength(1));
      final issues = s.healthCheck(DateTime(2026, 10, 8));
      final lost = issues.firstWhere((i) => i.title.contains('kategorinya sudah dihapus'));
      lost.fix!();
      expect(s.transactions.every((t) => t.categoryId == 'lain'), isTrue);
      expect(s.healthCheck(DateTime(2026, 10, 8)).any((i) => i.title.contains('kategorinya')), isFalse);
    });

    test('backup diverifikasi sebelum disimpan', () async {
      final s = storeWith([acc('a', initial: 1)]);
      final json = s.exportJson();
      final enc = await SecureBackup.encrypt(json, {}, 'rahasia1');
      expect(await s.verifyBackupBytes(enc, json, password: 'rahasia1'), isTrue);
      expect(await s.verifyBackupBytes(enc, json, password: 'salah'), isFalse);
      expect(await s.verifyBackupBytes(utf8.encode(json), json), isTrue);
      expect(await s.verifyBackupBytes(utf8.encode('{}'), json), isFalse);
    });
  });

  group('Data besar', () {
    test('20.000 transaksi 5 tahun tetap cepat dan saldo konsisten', () {
      final now = DateTime(2026, 10, 8, 12);
      final accs = [
        acc('bca', initial: 10000000),
        acc('gopay', type: AccountType.ewallet),
        acc('cash', type: AccountType.cash),
        acc('cc', type: AccountType.credit),
        acc('usd', currency: 'USD'),
        acc('tab', initial: 50000000),
      ];
      final ids = accs.map((a) => a.id).toList();
      final txs = <Transaction>[];
      for (var i = 0; i < 20000; i++) {
        final d = now.subtract(Duration(minutes: i * 131));
        final from = ids[i % ids.length];
        if (i % 10 == 0) {
          txs.add(tx('t$i', TxType.transfer, 50000, from, to: ids[(i + 1) % ids.length], date: d));
        } else if (i % 7 == 0) {
          txs.add(tx('t$i', TxType.income, 250000, from, cat: 'gaji', title: 'Gaji', date: d));
        } else {
          txs.add(tx('t$i', TxType.expense, 10000 + (i % 50) * 1000, from, cat: 'makan', title: 'Makan ${i % 40}', date: d));
        }
      }
      final s = storeWith(accs, txs);
      s.categories = [
        TxCategory(id: 'makan', name: 'Makan', type: TxType.expense, icon: 'food', color: 0),
        TxCategory(id: 'gaji', name: 'Gaji', type: TxType.income, icon: 'salary', color: 0),
      ];
      final sw = Stopwatch()..start();
      for (var k = 0; k < 50; k++) {
        for (final a in accs) {
          s.balanceOf(a.id);
        }
      }
      final tBal = sw.elapsedMilliseconds;
      s.safeToSpend(now);
      s.insights(now);
      final tIns = sw.elapsedMilliseconds - tBal;
      s.netWorthHistory(now);
      s.accountLedger('bca');
      s.healthCheck(now);
      s.detectSubscriptions(now);
      final total = sw.elapsedMilliseconds;
      // ignore: avoid_print
      print('20k tx: saldo x300 ${tBal}ms, insight ${tIns}ms, total ${total}ms');
      expect(total, lessThan(5000));
      // Cache sama dengan hitungan langsung.
      for (final a in accs) {
        expect(s.balanceOf(a.id), closeTo(s.balanceOf(a.id, excludeTxId: 'tidak-ada'), 0.001));
        expect(s.accountLedger(a.id).last.$2, closeTo(s.balanceOf(a.id), 0.001));
      }
      // Cache ikut berubah saat data berubah.
      final before = s.balanceOf('bca');
      s.addBalanceAdjustment(s.accounts.first, 1000);
      expect(s.balanceOf('bca'), closeTo(before + 1000, 0.001));
    });
  });

  group('Kalender & rekap tahunan', () {
    test('tanggal 31, 29 Februari, dan pergantian tahun', () {
      final jan31 = DateTime(2027, 1, 31, 9);
      expect(occurrence(jan31, Frequency.monthly, 1), DateTime(2027, 2, 28, 9));
      expect(occurrence(jan31, Frequency.monthly, 2), DateTime(2027, 3, 31, 9));
      expect(occurrence(DateTime(2028, 1, 31), Frequency.monthly, 1), DateTime(2028, 2, 29));
      final feb29 = DateTime(2028, 2, 29);
      expect(occurrence(feb29, Frequency.yearly, 1), DateTime(2029, 2, 28));
      expect(occurrence(feb29, Frequency.yearly, 4), DateTime(2032, 2, 29));
      expect(occurrence(DateTime(2026, 12, 15), Frequency.monthly, 1), DateTime(2027, 1, 15));
      expect(occurrence(DateTime(2026, 12, 29), Frequency.weekly, 1), DateTime(2027, 1, 5));
      expect(occurrence(DateTime(2026, 12, 31), Frequency.daily, 1), DateTime(2027, 1, 1));
    });

    test('rekap tahun: total, bulan paling boros, kekayaan awal-akhir', () {
      final s = storeWith([acc('a', initial: 1000000)], [
        tx('0', TxType.income, 500000, 'a', date: DateTime(2025, 12, 31, 23)),
        tx('1', TxType.income, 3000000, 'a', cat: 'gaji', date: DateTime(2026, 1, 25)),
        tx('2', TxType.expense, 400000, 'a', cat: 'makan', title: 'Makan', date: DateTime(2026, 2, 3)),
        tx('3', TxType.expense, 900000, 'a', cat: 'makan', title: 'makan', date: DateTime(2026, 3, 3)),
        tx('4', TxType.expense, 100000, 'a', cat: 'kopi', title: 'Kopi', date: DateTime(2026, 3, 9)),
        tx('5', TxType.expense, 50000, 'a', cat: 'kopi', title: 'Kopi', date: DateTime(2027, 1, 1, 0, 1)),
      ]);
      final r = s.yearRecap(2026, DateTime(2026, 12, 31, 12));
      expect(r.income, 3000000);
      expect(r.expense, 1400000);
      expect(r.txCount, 4);
      expect(r.monthlyExpense[2], 1000000); // Maret paling boros
      expect(r.biggest!.id, '3');
      expect(r.topTitles.first.key, 'Makan');
      expect(r.topTitles.first.value, 1300000);
      expect(r.netWorthStart, 1500000);
      expect(r.netWorthEnd, 1500000 + 3000000 - 1400000);
      expect(r.days, 365);
      expect(s.recapYears(DateTime(2026, 10, 8)), [2027, 2026, 2025]);
      // Mulai pakai di tengah tahun: hari dihitung sejak transaksi pertama.
      final baru = storeWith([acc('b')], [tx('x', TxType.expense, 30000, 'b', date: DateTime(2026, 10, 1, 9))]);
      expect(baru.yearRecap(2026, DateTime(2026, 10, 10, 12)).days, 10);
    });
  });

  group('Rekap & saran bulanan', () {
    test('7 tingkat menabung', () {
      expect(savingTier(-0.5).rank, 1);
      expect(savingTier(-0.05).rank, 2);
      expect(savingTier(0.05).rank, 3);
      expect(savingTier(0.15).rank, 4);
      expect(savingTier(0.25).rank, 5);
      expect(savingTier(0.40).rank, 6);
      expect(savingTier(0.60).rank, 7);
    });

    AppStore scenario({required double income, required double makan}) {
      final s = storeWith([acc('bca', initial: 5400000)]);
      s.categories = [
        TxCategory(id: 'makan', name: 'Makan', type: TxType.expense, icon: 'food', color: 0),
        TxCategory(id: 'transport', name: 'Transportasi', type: TxType.expense, icon: 'car', color: 0),
        TxCategory(id: 'gaji', name: 'Gaji', type: TxType.income, icon: 'salary', color: 0),
      ];
      var i = 0;
      // Juli–September: pemasukan 5,5 jt, makan 1,3 jt, transport 3,2 jt.
      for (final mo in [7, 8, 9]) {
        s.transactions.addAll([
          tx('g${i++}', TxType.income, 5500000, 'bca', cat: 'gaji', date: DateTime(2026, mo, 25)),
          tx('m${i++}', TxType.expense, 1300000, 'bca', cat: 'makan', title: 'Makan', date: DateTime(2026, mo, 10)),
          tx('t${i++}', TxType.expense, 3200000, 'bca', cat: 'transport', title: 'Bensin', date: DateTime(2026, mo, 12)),
        ]);
      }
      // Oktober.
      s.transactions.addAll([
        tx('g${i++}', TxType.income, income, 'bca', cat: 'gaji', date: DateTime(2026, 10, 25)),
        tx('m${i++}', TxType.expense, makan, 'bca', cat: 'makan', title: 'Makan', date: DateTime(2026, 10, 10)),
        tx('t${i++}', TxType.expense, 3200000, 'bca', cat: 'transport', title: 'Bensin', date: DateTime(2026, 10, 12)),
      ]);
      return s;
    }

    test('boros: tekor, kategori naik, belum ada anggaran, dana darurat kurang', () {
      final s = scenario(income: 5500000, makan: 3000000);
      final r = s.monthRecap(DateTime(2026, 10), DateTime(2026, 11, 3));
      expect(r.isCurrent, isFalse);
      expect(r.expense, 6200000);
      expect(r.prevMonths, 3);
      expect(r.avgExpense, 4500000);
      expect(r.tier!.rank, 1); // tekor 700 rb = -12,7%
      final titles = r.advice.map((a) => a.title).join(' | ');
      expect(titles, contains('tekor'));
      expect(titles, contains('Pengeluaran naik 38%'));
      expect(titles, contains('Makan naik'));
      expect(titles, contains('Belum ada anggaran bulanan'));
      expect(titles, contains('Dana darurat'));
      expect(r.advice.first.level, AdviceLevel.bad); // yang paling penting di atas
    });

    test('bulan berjalan: pengeluaran besar di awal bulan tidak meledakkan perkiraan', () {
      final s = scenario(income: 5500000, makan: 300000);
      // Hapus transport Oktober (tanggal 12) supaya hanya ada sewa besar tgl 2.
      s.transactions.removeWhere((t) => t.date.month == 10 && t.title == 'Bensin');
      s.transactions.add(tx('sewa', TxType.expense, 3000000, 'bca', cat: 'transport', title: 'Sewa', date: DateTime(2026, 10, 2)));
      final now = DateTime(2026, 10, 8, 12);
      final r = s.monthRecap(DateTime(2026, 10), now);
      expect(r.isCurrent, isTrue);
      // Perkiraan = 3,3 jt sejauh ini + 4,5 jt x (23/31), bukan 3,3 jt / (8/31).
      expect(r.projectedExpense, closeTo(3300000 + 4500000 * (23 / 31), 1));
      expect(r.projectedExpense, lessThan(7000000));
    });

    test('hemat: dipuji', () {
      final s = scenario(income: 9000000, makan: 900000);
      final r = s.monthRecap(DateTime(2026, 10), DateTime(2026, 11, 3));
      expect(r.tier!.rank, 7); // (9 jt - 4,1 jt) / 9 jt = 54%
      final titles = r.advice.map((a) => a.title).join(' | ');
      expect(titles, contains('Juara menabung'));
      expect(titles, contains('54% pemasukan ditabung'));
      expect(titles, contains('Makan turun 31%'));
      expect(r.advice.where((a) => a.isPraise).length, greaterThanOrEqualTo(2));
    });

    test('v4.5: saran bulanan ikut bahasa yang dipilih', () {
      addTearDown(() => gLang.value = AppLang.id);
      gLang.value = AppLang.en;
      final s = scenario(income: 5500000, makan: 3000000);
      final r = s.monthRecap(DateTime(2026, 10), DateTime(2026, 11, 3));
      final titles = r.advice.map((a) => a.title).join(' | ');
      final bodies = r.advice.map((a) => a.body).join(' | ');
      expect(titles, contains('short by'));
      expect(titles, contains('Spending is up 38% from usual'));
      expect(titles, contains('No monthly budget yet'));
      expect(titles, isNot(contains('Pengeluaran')));
      expect(bodies, isNot(contains('Sisihkan')));
      gLang.value = AppLang.zh;
      final z = s.monthRecap(DateTime(2026, 10), DateTime(2026, 11, 3));
      expect(z.advice.map((a) => a.title).join(' | '), contains('支出比平时增加了 38%'));
    });
  });

  group('v3.1', () {
    test('parseRate gaya Indonesia', () {
      expect(parseRate('17.910'), 17910);
      expect(parseRate('17910'), 17910);
      expect(parseRate('113,28'), 113.28);
      expect(parseRate('113.28'), 113.28);
      expect(parseRate('17.910,5'), 17910.5);
      expect(parseRate('1.234.567'), 1234567);
      expect(parseRate(''), 0);
      expect(rateToInput(17910), '17.910');
      expect(rateToInput(113.28), '113,28');
      for (final v in kDefaultRates.values) {
        expect(parseRate(rateToInput(v)), closeTo(v, 0.001));
      }
    });

    test('hapus piutang patungan merapikan Talangan', () {
      final s = storeWith([acc('gopay', initial: 500000, type: AccountType.ewallet), acc('bca', initial: 0)]);
      s.categories = [TxCategory(id: 'makan', name: 'Makan', type: TxType.expense, icon: 'food', color: 0)];
      s.recordSplit(
        title: 'Makan',
        payerAccountId: 'gopay',
        categoryId: 'makan',
        myShare: 50000,
        others: const [SplitShare('Andi', 50000), SplitShare('Budi', 50000)],
        date: DateTime(2026, 10, 8, 19),
      );
      expect(s.balanceOf('gopay'), 350000);
      final andi = s.debts.firstWhere((d) => d.person == 'Andi');
      final budi = s.debts.firstWhere((d) => d.person == 'Budi');
      expect(s.splitPayerOf(andi), 'gopay');

      // Andi bayar sebagian, lalu sisanya diputihkan.
      s.receiveDebt(andi, 20000, toAccountId: 'bca');
      s.deleteSplitDebt(andi);
      expect(s.balanceOf(kTalanganId), 50000); // tinggal punya Budi
      expect(s.debts.length, 1);

      // Budi salah catat: kembali ke GoPay.
      s.deleteSplitDebt(budi, returnTo: s.splitPayerOf(budi));
      expect(s.balanceOf(kTalanganId), 0);
      expect(s.balanceOf('gopay'), 400000);
      expect(s.debts, isEmpty);
      expect(s.healthCheck(DateTime(2026, 10, 8)).where((i) => i.title.startsWith('Talangan')), isEmpty);
    });
  });

  group('v3.2', () {
    test('sidik backup: abaikan waktu backup, berubah kalau data berubah', () {
      final s = storeWith([acc('bca', initial: 100000)]);
      final a = s.backupSignature();
      s.settings.lastAutoBackup = DateTime(2026, 10, 9, 8);
      s.settings.lastDriveSave = DateTime(2026, 10, 9, 9);
      s.settings.lastBackupSig = a;
      expect(s.backupSignature(), a);
      s.transactions.add(tx('x', TxType.expense, 5000, 'bca', date: DateTime(2026, 10, 9)));
      expect(s.backupSignature(), isNot(a));
    });

    test('antrean Perlu dicek: maksimal 300, yang terbuang dihitung', () {
      final s = storeWith([acc('bca', initial: 1000000)]);
      s.settings.captureMode = 'ask';
      final base = DateTime(2026, 10, 9, 8);
      s.ingestCaptured([
        for (var i = 0; i < 310; i++)
          {
            'pkg': 'com.bca.mybca.omni.android',
            'title': 'myBCA',
            'text': 'Transfer berhasil sebesar Rp ${1000 + i}',
            'time': base.add(Duration(minutes: i * 5)).millisecondsSinceEpoch,
          }
      ]);
      expect(s.pendingCaptures, hasLength(kMaxPendingCaptures));
      expect(s.settings.droppedCaptures, 10);
      // Yang tersisa adalah yang terbaru.
      expect(s.pendingCaptures.last.text, contains('Rp 1309'));
      final back = AppSettings.fromJson(s.settings.toJson());
      expect(back.droppedCaptures, 10);
      expect(s.healthCheck(DateTime(2026, 10, 9)).any((i) => i.title.contains('terbuang')), isTrue);
    });

    test('status backup: tersembunyi, lama, di luar HP, aman', () {
      final now = DateTime(2026, 10, 9, 12);
      List<Transaction> txs(int n) => [
            for (var i = 0; i < n; i++)
              tx('t$i', TxType.expense, 1000, 'bca', date: now.subtract(Duration(days: 60 - i * 3))),
          ];
      // Data masih sedikit: tidak diingatkan.
      var s = storeWith([acc('bca', initial: 100000)], txs(5));
      expect(s.backupStatus(now).level, BackupLevel.hidden);

      // Belum pernah backup.
      s = storeWith([acc('bca', initial: 100000)], txs(12));
      expect(s.backupStatus(now).level, BackupLevel.stale);
      expect(s.backupStatus(now).newTx, 12);

      // Belum pernah backup tapi datanya baru 10 hari: belum ditagih.
      final fresh = storeWith([acc('bca', initial: 100000)], [
        for (var i = 0; i < 12; i++)
          tx('f$i', TxType.expense, 1000, 'bca', date: now.subtract(Duration(days: 10 - (i ~/ 2)))),
      ]);
      expect(fresh.backupStatus(now).level, BackupLevel.ok);

      // Backup di HP baru dan isinya sama, belum pernah ada salinan di luar HP:
      // tidak ditagih.
      s.updateSettings((x) {
        x.lastAutoBackup = now.subtract(const Duration(hours: 2));
        x.lastBackupSig = s.backupSignature();
      });
      expect(s.backupStatus(now).level, BackupLevel.ok);
      expect(s.backupStatus(now).upToDate, isTrue);

      // Salinan di luar HP baru: aman.
      s.markDriveSaved(now.subtract(const Duration(days: 2)));
      expect(s.backupStatus(now).level, BackupLevel.ok);

      // Salinan di luar HP 29 hari: masih belum diingatkan; 31 hari: diingatkan.
      s.markDriveSaved(now.subtract(const Duration(days: 29)));
      expect(s.backupStatus(now).level, BackupLevel.ok);
      s.markDriveSaved(now.subtract(const Duration(days: 31)));
      expect(s.backupStatus(now).level, BackupLevel.offsite);

      // Backup di HP 20 hari lalu dan datanya berubah: belum diingatkan.
      s.updateSettings((x) {
        x.lastAutoBackup = now.subtract(const Duration(days: 20));
        x.lastBackupSig = 'lama';
      });
      expect(s.backupStatus(now).level, isNot(BackupLevel.stale));

      // Backup di HP 35 hari lalu dan datanya sudah berubah: paling mendesak.
      s.updateSettings((x) {
        x.lastAutoBackup = now.subtract(const Duration(days: 35));
        x.lastBackupSig = 'lama';
      });
      final st = s.backupStatus(now);
      expect(st.level, BackupLevel.stale);
      // Transaksi bertanggal setelah backup: hari ke-60-3i < 35 berarti i >= 9.
      expect(st.newTx, 3);

      // Backup 35 hari lalu tapi isinya masih sama persis: tidak dianggap lama.
      s.updateSettings((x) => x.lastBackupSig = s.backupSignature());
      expect(s.backupStatus(now).level, isNot(BackupLevel.stale));
    });

    test('agoLabel', () {
      final now = DateTime(2026, 10, 9, 12);
      expect(agoLabel(now.subtract(const Duration(seconds: 20)), now), 'baru saja');
      expect(agoLabel(now.subtract(const Duration(minutes: 5)), now), '5 menit lalu');
      expect(agoLabel(now.subtract(const Duration(hours: 2)), now), '2 jam lalu');
      expect(agoLabel(now.subtract(const Duration(days: 9)), now), '9 hari lalu');
    });
  });

  group('v3.3', () {
    tearDown(() => gPeriodStartDay = 1);

    test('periode gajian: label dan rentang', () {
      gPeriodStartDay = 25;
      expect(periodLabelOf(DateTime(2026, 10, 9)), DateTime(2026, 10));
      expect(periodLabelOf(DateTime(2026, 10, 27)), DateTime(2026, 11));
      final r = periodRange(DateTime(2026, 10));
      expect(r.start, DateTime(2026, 9, 25));
      expect(r.end, DateTime(2026, 10, 25));
      expect(periodSpanText(DateTime(2026, 10)), contains('25 Sep'));
      // Pergantian tahun.
      expect(periodRange(DateTime(2027, 1)).start, DateTime(2026, 12, 25));
      gPeriodStartDay = 5;
      expect(periodLabelOf(DateTime(2026, 10, 3)), DateTime(2026, 9));
      expect(periodRange(DateTime(2026, 10)).start, DateTime(2026, 10, 5));
      gPeriodStartDay = 1;
      expect(periodRange(DateTime(2026, 10)), monthRange(DateTime(2026, 10)));
      expect(periodSpanText(DateTime(2026, 10)), isEmpty);
    });

    test('anggaran dan rekap ikut tanggal gajian', () {
      final s = storeWith([acc('bca', initial: 1000000)], [
        tx('a', TxType.expense, 100000, 'bca', date: DateTime(2026, 9, 26)),
        tx('b', TxType.expense, 50000, 'bca', date: DateTime(2026, 10, 24)),
        tx('c', TxType.expense, 70000, 'bca', date: DateTime(2026, 10, 25)),
        tx('g', TxType.income, 5000000, 'bca', date: DateTime(2026, 9, 25)),
      ]);
      s.updateSettings((x) => x.periodStartDay = 25);
      expect(gPeriodStartDay, 25);
      final r = BudgetPeriod.monthly.range(DateTime(2026, 10, 9));
      expect(s.sumIDR(TxType.expense, r), 150000);
      final rc = s.monthRecap(DateTime(2026, 10), DateTime(2026, 11, 2));
      expect(rc.expense, 150000);
      expect(rc.income, 5000000);
      expect(rc.daysInMonth, 30);
      // Bersih lagi kalau dikembalikan ke tanggal 1.
      s.updateSettings((x) => x.periodStartDay = 1);
      expect(s.sumIDR(TxType.expense, BudgetPeriod.monthly.range(DateTime(2026, 10, 9))), 120000);
      final back = AppSettings.fromJson((AppSettings()..periodStartDay = 25).toJson());
      expect(back.periodStartDay, 25);
    });

    test('kategori pintar dari kebiasaan', () {
      final s = storeWith([acc('gopay', initial: 1000000, type: AccountType.ewallet)], [
        tx('1', TxType.expense, 24000, 'gopay', cat: 'kafe', title: 'Kopi Kenangan', date: DateTime(2026, 10, 1)),
        tx('2', TxType.expense, 26000, 'gopay', cat: 'kafe', title: 'kopi kenangan #2', date: DateTime(2026, 10, 3)),
        tx('3', TxType.expense, 30000, 'gopay', cat: 'makan', title: 'Bakso', date: DateTime(2026, 10, 3)),
        tx('4', TxType.expense, 30000, 'gopay', cat: 'jajan', title: 'Bakso', date: DateTime(2026, 10, 4)),
      ]);
      s.categories = [
        TxCategory(id: 'kafe', name: 'Kafe', type: TxType.expense, icon: 'cafe', color: 0),
        TxCategory(id: 'makan', name: 'Makan', type: TxType.expense, icon: 'food', color: 0),
        TxCategory(id: 'jajan', name: 'Jajan', type: TxType.expense, icon: 'food', color: 0),
      ];
      s.updateSettings((_) {});
      expect(s.learnedCategory('KOPI KENANGAN', TxType.expense), 'kafe');
      expect(s.learnedCategory('Bakso', TxType.expense), isNull); // 50:50
      expect(s.learnedCategory('Sate', TxType.expense), isNull);
      expect(s.learnedCategory('Kopi Kenangan', TxType.income), isNull);
    });

    test('pencarian: semua kata, nominal, jenis, waktu', () {
      final s = storeWith([acc('gopay', initial: 1000000, type: AccountType.ewallet), acc('bca')], [
        tx('1', TxType.expense, 24000, 'gopay', title: 'Kopi susu', date: DateTime(2026, 10, 1)),
        tx('2', TxType.expense, 55000, 'gopay', title: 'Kopi beans', date: DateTime(2026, 9, 1)),
        tx('3', TxType.expense, 1500000, 'bca', title: 'Sewa kos', date: DateTime(2026, 10, 2)),
        tx('4', TxType.income, 50000, 'bca', title: 'Kopi refund', date: DateTime(2026, 10, 3)),
      ]);
      Set<String> ids(List<Transaction> l) => l.map((t) => t.id).toSet();
      expect(ids(s.search('kopi gopay')), {'1', '2'});
      expect(ids(s.search('kopi >=50rb')), {'2', '4'});
      expect(ids(s.search('kopi >50rb')), {'2'});
      expect(ids(s.search('kopi >=50rb', type: TxType.expense)), {'2'});
      expect(ids(s.search('<30000')), {'1'});
      expect(ids(s.search('>=1,5jt')), {'3'});
      expect(ids(s.search('1,5jt')), {'3'});
      expect(ids(s.search('24.000')), {'1'});
      expect(ids(s.search('kopi', range: monthRange(DateTime(2026, 10)))), {'1', '4'});
      expect(AppStore.parseSearchAmount('50rb'), 50000);
      expect(AppStore.parseSearchAmount('abc'), isNull);
    });
  });

  group('v3.4', () {
    AppStore splitStore() {
      final s = storeWith([acc('gopay', initial: 1000000, type: AccountType.ewallet)], [
        Transaction(
          id: 'sp',
          title: 'Indomaret',
          amount: 150000,
          type: TxType.expense,
          categoryId: 'makan',
          accountId: 'gopay',
          date: DateTime(2026, 10, 9, 15),
          splits: const [TxSplit('makan', 90000), TxSplit('rumah', 40000), TxSplit('pulsa', 20000)],
        ),
        tx('k', TxType.expense, 24000, 'gopay', cat: 'makan', title: 'Kopi', date: DateTime(2026, 10, 9, 9)),
      ]);
      s.categories = [
        TxCategory(id: 'makan', name: 'Makan', type: TxType.expense, icon: 'food', color: 0),
        TxCategory(id: 'rumah', name: 'Rumah tangga', type: TxType.expense, icon: 'home', color: 0),
        TxCategory(id: 'pulsa', name: 'Pulsa', type: TxType.expense, icon: 'phone', color: 0),
      ];
      return s;
    }

    test('bagi kategori: saldo satu transaksi, statistik per kategori', () {
      final s = splitStore();
      final r = monthRange(DateTime(2026, 10));
      expect(s.balanceOf('gopay'), 1000000 - 150000 - 24000);
      expect(s.sumIDR(TxType.expense, r), 174000);
      final cats = s.byTopCategory(TxType.expense, r);
      expect(cats['makan'], 114000);
      expect(cats['rumah'], 40000);
      expect(cats['pulsa'], 20000);
      expect(s.sumIDR(TxType.expense, r, topCategory: 'rumah'), 40000);
      expect(s.categoryLabel(s.transactions.first), 'Makan + Rumah tangga + Pulsa');
      expect(s.search('pulsa').map((t) => t.id), ['sp']);
    });

    test('bagi kategori: simpan, buka lagi, ekspor', () {
      final s = splitStore();
      final t = s.transactions.first;
      final back = Transaction.fromJson(t.toJson());
      expect(back.splits.length, 3);
      expect(back.splits[1].categoryId, 'rumah');
      expect(back.splits[1].amount, 40000);
      // Transaksi biasa tidak menulis kolom splits.
      expect(s.transactions[1].toJson().containsKey('splits'), isFalse);
      // Draft: kurang dari 2 bagian = transaksi biasa.
      final d = TxDraft.fromTransaction(t);
      expect(d.splits.length, 3);
      d.splits = [const TxSplit('makan', 150000)];
      expect(d.toTransaction('x').splits, isEmpty);
      // Ekspor: satu baris per bagian.
      final rows = s.exportRows(null);
      final indo = rows.where((r) => r[4] == 'Indomaret').toList();
      expect(indo.length, 3);
      expect(indo.fold<double>(0, (a, r) => a + (r[5] as double)), 150000);
    });

    test('bagi kategori: kategori terhapus ikut diperbaiki', () {
      final s = splitStore();
      s.categories.removeWhere((c) => c.id == 'pulsa');
      s.categories.add(TxCategory(id: 'lain', name: 'Lain lain', type: TxType.expense, icon: 'other', color: 0));
      final issue = s.healthCheck(DateTime(2026, 10, 9)).firstWhere((i) => i.title.contains('kategorinya sudah dihapus'));
      issue.fix!();
      final t = s.transactions.firstWhere((t) => t.id == 'sp');
      expect(t.splits.any((x) => x.categoryId == 'pulsa'), isFalse);
      expect(t.splits.length, 3);
    });

    test('v4.5: tombol widget ikut bahasa', () {
      addTearDown(() => gLang.value = AppLang.id);
      final s = splitStore();
      expect(s.widgetData()['w_btn_expense'], '− Keluar');
      gLang.value = AppLang.en;
      expect(s.widgetData()['w_btn_income'], '+ In');
      gLang.value = AppLang.zh;
      expect(s.widgetData()['w_btn_transfer'], '⇄ 转账');
    });

    test('widget menampilkan aman dibelanjakan dengan tanggal', () {
      final s = splitStore();
      final w = s.widgetData();
      expect(w['w_safe_label'],
          anyOf(startsWith('Aman dibelanjakan · '), startsWith('Lewat jatah · ')));
      expect(w['w_safe'], startsWith('Rp '));
      expect(w['w_safe'], isNot(contains('•')));
      expect(w['w_balance'], contains('aldo'));
      s.settings.hideBalance = true;
      final h = s.widgetData();
      expect(h['w_safe'], contains('••••'));
      expect(h['w_balance'], contains('••••'));
      expect(h['w_perday'], '');
      expect(h['w_mood'], isNotEmpty);
    });

    test('v5.0 widget: suasana maskot dan cincin', () {
      final s = splitStore();
      final w = s.widgetData();
      expect(MascotMood.values.map((m) => m.name), contains(w['w_mood']));
      final ring = int.parse(w['w_ring']!);
      expect(ring, inInclusiveRange(0, 100));
      expect(w['w_perday'], contains('hari lagi'));
    });

    test('ukuran huruf tersimpan', () {
      final a = AppSettings()..textScale = 1.3;
      expect(AppSettings.fromJson(a.toJson()).textScale, 1.3);
      expect(AppSettings.fromJson(AppSettings().toJson()).textScale, 1.0);
    });
  });

  group('v3.5', () {
    test('kartu Beranda: bawaan ringkas, urutan tersimpan, id asing dibuang', () {
      expect(AppSettings().homeCards, kDefaultHomeCards);
      final j = AppSettings().toJson()..['homeCards'] = ['recent', 'budget', 'xx', 'recent'];
      expect(AppSettings.fromJson(j).homeCards, ['recent', 'budget']);
      final old = AppSettings().toJson()..remove('homeCards');
      expect(AppSettings.fromJson(old).homeCards, kDefaultHomeCards);
      for (final k in kDefaultHomeCards) {
        expect(kHomeCards.containsKey(k), isTrue);
      }
    });

    test('insight dibagi: Beranda vs Rencana', () {
      expect(kHomeInsights.contains(InsightKind.subscription), isFalse);
      expect(kPlanInsights.contains(InsightKind.subscription), isTrue);
      expect(kHomeInsights.contains(InsightKind.backup), isTrue);
      // Semua jenis tampil di salah satu tempat.
      for (final k in InsightKind.values) {
        expect(kHomeInsights.contains(k) || kPlanInsights.contains(k), isTrue, reason: k.name);
      }
    });
  });

  group('v3.5.3', () {
    AppStore full() {
      final s = storeWith([acc('bca', initial: 501000), acc('gopay')], [
        tx('1', TxType.expense, 450000, 'bca', cat: 'makan', date: DateTime(2026, 10, 3)),
        tx('2', TxType.transfer, 50000, 'bca', to: 'gopay', date: DateTime(2026, 10, 4)),
      ]);
      s.templates = [const TxTemplate(id: 't1', title: 'Kopi', amount: 24000, type: TxType.expense, accountId: 'bca')];
      s.recurring = [
        RecurringRule(id: 'kos', title: 'Kos', amount: 1500000, type: TxType.expense, accountId: 'bca', frequency: Frequency.monthly, start: DateTime(2099, 1, 1)),
      ];
      s.debts = [Debt(id: 'd', person: 'Ani', theyOwe: false, amount: 50000, date: DateTime(2026, 10, 1), payments: [DebtPayment(date: DateTime(2026, 10, 2), amount: 10000)])];
      s.goals = [Goal(id: 'g', name: 'HP baru', target: 4000000, color: 1, saved: 500000)];
      s.events = [TxEvent(id: 'bali', name: 'Trip Bali', start: DateTime(2026, 12, 20))];
      s.settings
        ..themeMode = 'dark'
        ..textScale = 1.3
        ..homeCards = ['goals', 'quick']
        ..accentIndex = 2
        ..displayName = 'Jose'
        ..greetingMode = 'custom'
        ..greetingText = 'Halo'
        ..pin = '1234'
        ..avatarPath = '/a/foto.jpg';
      return s;
    }

    test('semua koleksi dan saldo pulih sama persis', () {
      final s = full();
      final s2 = AppStore();
      s2.importJson(s.exportJson());
      expect(s2.balanceOf('bca'), 1000);
      expect(s2.balanceOf('gopay'), 50000);
      expect(s2.accounts.map((a) => a.id), ['bca', 'gopay']);
      expect(s2.transactions.length, 2);
      expect(s2.templates.single.title, 'Kopi');
      expect(s2.recurring.single.id, 'kos');
      expect(s2.debts.single.remaining, 40000);
      expect(s2.goals.single.saved, 500000);
      expect(s2.events.single.name, 'Trip Bali');
    });

    test('tampilan dan profil ikut pulih, keamanan tetap milik HP ini', () {
      final s2 = AppStore();
      s2.settings
        ..themeMode = 'light'
        ..textScale = 1.0
        ..accentIndex = 0
        ..pin = '9999'
        ..avatarPath = '/b/lain.jpg';
      s2.importJson(full().exportJson());
      expect(s2.settings.themeMode, 'dark');
      expect(s2.settings.textScale, 1.3);
      expect(s2.settings.homeCards, ['goals', 'quick']);
      expect(s2.settings.accentIndex, 2);
      expect(s2.settings.displayName, 'Jose');
      expect(s2.settings.greetingMode, 'custom');
      expect(s2.settings.greetingText, 'Halo');
      expect(s2.settings.pin, '9999');
      expect(s2.settings.avatarPath, '/b/lain.jpg');
    });

    test('backup lama tanpa kunci tampilan memakai nilai HP ini, bukan bawaan', () {
      final j = jsonDecode(full().exportJson()) as Map<String, dynamic>;
      final st = j['settings'] as Map<String, dynamic>;
      for (final k in ['themeMode', 'textScale', 'homeCards', 'accentIndex', 'displayName', 'greetingMode', 'greetingText']) {
        st.remove(k);
      }
      final s2 = AppStore();
      s2.settings
        ..themeMode = 'dark'
        ..textScale = 1.15
        ..homeCards = ['recent']
        ..accentIndex = 3
        ..displayName = 'Rumah'
        ..greetingMode = 'motivation';
      s2.importJson(jsonEncode(j));
      expect(s2.settings.themeMode, 'dark');
      expect(s2.settings.textScale, 1.15);
      expect(s2.settings.homeCards, ['recent']);
      expect(s2.settings.accentIndex, 3);
      expect(s2.settings.displayName, 'Rumah');
      expect(s2.settings.greetingMode, 'motivation');
      expect(s2.transactions.length, 2);
    });

    test('reset tetap mempertahankan tampilan dan keamanan', () {
      final s = full();
      s.clearAll();
      expect(s.settings.themeMode, 'dark');
      expect(s.settings.textScale, 1.3);
      expect(s.settings.pin, '1234');
      expect(s.transactions, isEmpty);
    });

    test('ringkasan isi backup untuk pratinjau', () {
      final s = full();
      final info = AppStore.peekJson(s.exportJson());
      expect(info.accounts, 2);
      expect(info.transactions, 2);
      expect(info.goals, 1);
      expect(info.debts, 1);
      expect(info.recurring, 1);
      expect(info.templates, 1);
      expect(info.events, 1);
      expect(info.lastTransaction, DateTime(2026, 10, 4));
      expect(info.exportedAt, isNotNull);
      final now = s.currentInfo();
      expect(now.transactions, 2);
      expect(now.lastTransaction, DateTime(2026, 10, 4));
      expect(() => AppStore.peekJson('bukan json'), throwsFormatException);
      expect(() => AppStore.peekJson('{"a":1}'), throwsFormatException);
    });

    test('ukuran huruf selalu ditulis di backup', () {
      expect(AppSettings().toJson().containsKey('textScale'), isTrue);
    });
  });

  group('v3.6 golongan pengeluaran', () {
    TxCategory c(String id, {String? parent}) => TxCategory(
        id: id,
        name: id,
        type: TxType.expense,
        icon: 'food',
        color: 0xFF000000,
        parentId: parent);

    AppStore withCats(List<Account> a, [List<Transaction> t = const []]) {
      final s = storeWith(a, t);
      s.categories = [
        c('pokok'),
        c('makan', parent: 'pokok'),
        c('sehat'),
        c('olahraga', parent: 'sehat'),
        c('edu'),
        c('buku', parent: 'edu'),
        c('sosial'),
        c('gift_out', parent: 'sosial'),
        c('donasi', parent: 'sosial'),
        c('hiburan'),
        c('cafe', parent: 'hiburan'),
        c('cicilan'),
        c('mine'),
      ];
      return s;
    }

    final oct = DateTimeRange(start: DateTime(2026, 10, 1), end: DateTime(2026, 11, 1));

    test('golongan bawaan: kategori sendiri, lalu induk, lalu belum digolongkan', () {
      final s = withCats([acc('bca')]);
      expect(s.kindOf('pokok'), SpendKind.need);
      expect(s.kindOf('makan'), SpendKind.need);
      expect(s.kindOf('olahraga'), SpendKind.grow);
      expect(s.kindOf('buku'), SpendKind.grow);
      expect(s.kindOf('gift_out'), SpendKind.want);
      expect(s.kindOf('donasi'), SpendKind.duty);
      expect(s.kindOf('cafe'), SpendKind.want);
      expect(s.kindOf('cicilan'), SpendKind.duty);
      expect(s.kindOf('mine'), SpendKind.other);
      expect(s.kindOf(null), SpendKind.other);
    });

    test('pilihan user menang, anak mengikuti induk, bisa dikembalikan', () {
      final s = withCats([acc('bca')]);
      s.setSpendKind('hiburan', SpendKind.need);
      expect(s.kindOf('cafe'), SpendKind.need);
      s.setSpendKind('cafe', SpendKind.save);
      expect(s.kindOf('cafe'), SpendKind.save);
      expect(s.kindOf('hiburan'), SpendKind.need);
      s.setSpendKind('cafe', null);
      s.setSpendKind('hiburan', null);
      expect(s.kindOf('cafe'), SpendKind.want);
      s.setSpendKind('mine', SpendKind.want);
      expect(s.kindOf('mine'), SpendKind.want);
    });

    test('total per golongan: biasa, dibagi, transfer ke akun tabungan', () {
      final bca = acc('bca', initial: 10000000);
      const sav = Account(
          id: 'sav',
          name: 'Tabungan',
          type: AccountType.bank,
          color: 0xFF000000,
          excludeSafe: true);
      final big = tx('3', TxType.expense, 100000, 'bca', cat: 'makan', date: DateTime(2026, 10, 6))
          .copyWith(splits: const [TxSplit('makan', 60000), TxSplit('cafe', 30000)]);
      final s = withCats([bca, sav], [
        tx('1', TxType.expense, 200000, 'bca', cat: 'makan', date: DateTime(2026, 10, 2)),
        tx('2', TxType.expense, 50000, 'bca', cat: 'cafe', date: DateTime(2026, 10, 3)),
        big,
        tx('4', TxType.transfer, 700000, 'bca', to: 'sav', date: DateTime(2026, 10, 7)),
        tx('5', TxType.expense, 999, 'bca', cat: 'cafe', date: DateTime(2026, 9, 30)),
        tx('6', TxType.income, 5000000, 'bca', date: DateTime(2026, 10, 1)),
      ]);
      final m = s.spendByKind(oct);
      // makan: 200000 + 60000 + sisa 10000 (induk) = 270000
      expect(m[SpendKind.need], 270000);
      // cafe: 50000 + 30000
      expect(m[SpendKind.want], 80000);
      expect(m[SpendKind.save], 700000);
      expect(m.containsKey(SpendKind.duty), isFalse);
    });

    test('transfer biasa antar akun harian tidak dihitung tabungan', () {
      final s = withCats([acc('bca', initial: 100000), acc('gopay')], [
        tx('1', TxType.transfer, 50000, 'bca', to: 'gopay', date: DateTime(2026, 10, 2)),
      ]);
      expect(s.spendByKind(oct), isEmpty);
    });

    test('pilihan golongan ikut backup dan pulih', () {
      final s = withCats([acc('bca')]);
      s.setSpendKind('cafe', SpendKind.need);
      final raw = s.exportJson();
      final s2 = withCats([acc('bca')]);
      s2.importJson(raw);
      s2.categories = s.categories;
      expect(s2.settings.spendKinds['cafe'], 'need');
      expect(s2.kindOf('cafe'), SpendKind.need);
      // Pengaturan tanpa pilihan tidak menulis kunci kosong.
      expect(AppSettings().toJson().containsKey('spendKinds'), isFalse);
    });

    test('jumlah transaksi periode ini untuk kartu Beranda', () {
      final s = withCats([acc('bca', initial: 1000)], [
        tx('1', TxType.expense, 10, 'bca', date: DateTime(2026, 10, 2)),
        tx('2', TxType.income, 10, 'bca', date: DateTime(2026, 10, 31, 23)),
        tx('3', TxType.expense, 10, 'bca', date: DateTime(2026, 11, 1)),
        tx('4', TxType.expense, 10, 'bca', date: DateTime(2026, 9, 30)),
      ]);
      expect(periodTxCount(s, oct), 2);
    });
  });
  group('v3.7 ikon kartun', () {
    Map<String, dynamic> backupWithOldIcons() {
      final s = AppStore()..clearAll();
      final j = jsonDecode(s.exportJson()) as Map<String, dynamic>;
      final old = {
        'care': 'other',
        'health': 'health',
        'olahraga': 'bike',
        'darurat': 'other',
        'emergency': 'phone',
        'donasi': 'gift',
        'cicilan': 'bill',
        'admin': 'bill',
      };
      for (final c in j['categories'] as List) {
        final id = (c as Map)['id'];
        if (old.containsKey(id)) c['icon'] = old[id];
      }
      (j['settings'] as Map).remove('iconsV37');
      return j;
    }

    test('setiap kunci ikon Material punya gambar kartun, dan sebaliknya', () {
      expect(kArtKeys.toSet(), {...kIcons.keys, ...kExtraArtKeys});
      expect(kExtraArtKeys.toSet().intersection(kIcons.keys.toSet()), isEmpty);
      for (final k in kArtKeys) {
        final b = artBytes(k);
        expect(b, isNotNull, reason: k);
        // tanda tangan PNG
        expect(b!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47], reason: k);
      }
      expect(artBytes('tidak-ada'), isNull);
      expect(artBytes(null), isNull);
    });

    test('setiap ikon Material di kFnArt mengarah ke gambar yang ada', () {
      expect(kFnArt, isNotEmpty);
      for (final e in kFnArt.entries) {
        expect(artBytes(e.value), isNotNull, reason: e.value);
      }
    });

    test('instans bytes dipakai ulang supaya cache gambar kena', () {
      expect(identical(artBytes('food'), artBytes('food')), isTrue);
    });

    test('semua kategori bawaan memakai kunci ikon yang dikenal', () {
      final s = AppStore()..clearAll();
      for (final c in s.categories) {
        expect(kIcons.containsKey(c.icon), isTrue, reason: c.id);
        expect(c.art, c.icon);
      }
    });

    test('gaya ikon: bawaan kartun, ikut tersimpan di backup', () {
      expect(AppSettings().iconStyle, 'cartoon');
      final s = AppStore()..clearAll();
      s.settings.iconStyle = 'classic';
      final s2 = AppStore();
      s2.importJson(s.exportJson());
      expect(s2.settings.iconStyle, 'classic');
      expect(AppSettings.fromJson({'iconStyle': 'aneh'}).iconStyle, 'cartoon');
    });

    test('backup lama tanpa iconStyle tidak mengubah gaya di HP ini', () {
      final j = backupWithOldIcons();
      (j['settings'] as Map).remove('iconStyle');
      final s = AppStore()..clearAll();
      s.settings.iconStyle = 'classic';
      s.importJson(jsonEncode(j));
      expect(s.settings.iconStyle, 'classic');
    });

    test('ikon bawaan lama dipindah ke ikon baru sekali saja', () {
      final s = AppStore()..clearAll();
      s.importJson(jsonEncode(backupWithOldIcons()));
      String icon(String id) => s.categoryById(id)!.icon;
      expect(icon('care'), 'care');
      expect(icon('health'), 'pill');
      expect(icon('olahraga'), 'sport');
      expect(icon('darurat'), 'sos');
      expect(icon('emergency'), 'sos');
      expect(icon('donasi'), 'charity');
      expect(icon('cicilan'), 'card');
      expect(icon('admin'), 'bank');
      expect(s.settings.iconsV37, isTrue);
    });

    test('ikon yang sudah diganti user tidak disentuh', () {
      final j = backupWithOldIcons();
      for (final c in j['categories'] as List) {
        if ((c as Map)['id'] == 'care') c['icon'] = 'pet';
      }
      final s = AppStore()..clearAll();
      s.importJson(jsonEncode(j));
      expect(s.categoryById('care')!.icon, 'pet');
      expect(s.categoryById('health')!.icon, 'pill');
    });

    test('setelah dipindah, ikon yang dipilih ulang user tidak dipindah lagi', () {
      final s = AppStore()..clearAll();
      s.importJson(jsonEncode(backupWithOldIcons()));
      final j = jsonDecode(s.exportJson()) as Map<String, dynamic>;
      for (final c in j['categories'] as List) {
        if ((c as Map)['id'] == 'health') c['icon'] = 'health';
      }
      final s2 = AppStore();
      s2.importJson(jsonEncode(j));
      expect(s2.categoryById('health')!.icon, 'health');
    });

    test('txArt: kategori ada kuncinya, transfer pakai ikon transfer', () {
      final s = AppStore()..clearAll();
      s.accounts = [acc('a', initial: 100), acc('b')];
      final e = tx('e', TxType.expense, 10, 'a', cat: 'makan');
      final t = tx('t', TxType.transfer, 10, 'a', to: 'b');
      expect(s.txArt(e), 'food');
      expect(s.txArt(t), 'transfer');
    });

    test('setiap tipe akun punya gambar kartun', () {
      for (final t in AccountType.values) {
        expect(artBytes(t.art), isNotNull, reason: t.name);
      }
    });
  });
  group('v3.7.2 kategori yang disarankan', () {
    final now = DateTime(2026, 10, 12, 12);
    AppStore withDefaults() => AppStore()..clearAll();

    test('belum ada riwayat: tidak ada saran', () {
      expect(withDefaults().suggestedCategory(TxType.expense, now: now), isNull);
    });

    test('kategori yang paling sering dipakai menang', () {
      final s = withDefaults();
      s.accounts = [acc('a', initial: 1000)];
      s.transactions = [
        tx('1', TxType.expense, 10, 'a', cat: 'makan', date: DateTime(2026, 10, 10)),
        tx('2', TxType.expense, 10, 'a', cat: 'makan', date: DateTime(2026, 10, 9)),
        tx('3', TxType.expense, 10, 'a', cat: 'cafe', date: DateTime(2026, 10, 8)),
      ];
      expect(s.suggestedCategory(TxType.expense, now: now), 'makan');
    });

    test('transaksi lebih dari 90 hari lalu dan tipe lain diabaikan', () {
      final s = withDefaults();
      s.accounts = [acc('a', initial: 1000)];
      s.transactions = [
        tx('1', TxType.expense, 10, 'a', cat: 'makan', date: DateTime(2026, 6, 1)),
        tx('2', TxType.income, 10, 'a', cat: 'gaji', date: DateTime(2026, 10, 1)),
        tx('3', TxType.expense, 10, 'a', cat: 'cafe', date: DateTime(2026, 10, 1)),
      ];
      expect(s.suggestedCategory(TxType.expense, now: now), 'cafe');
      expect(s.suggestedCategory(TxType.income, now: now), 'gaji');
    });

    test('kategori yang sudah dihapus tidak disarankan', () {
      final s = withDefaults();
      s.accounts = [acc('a', initial: 1000)];
      s.transactions = [
        tx('1', TxType.expense, 10, 'a', cat: 'hilang', date: DateTime(2026, 10, 1)),
        tx('2', TxType.expense, 10, 'a', cat: 'cafe', date: DateTime(2026, 10, 2)),
      ];
      expect(s.suggestedCategory(TxType.expense, now: now), 'cafe');
    });

    test('logo tersedia sebagai gambar', () {
      expect(artBytes('logo'), isNotNull);
      expect(kExtraArtKeys, contains('logo'));
    });
  });

  group('v4.0 catat satu layar', () {
    final now = DateTime(2026, 10, 12, 12);
    AppStore fresh() => AppStore()..clearAll();
    List<String> freq(AppStore s, TxType t, {String? ensure}) =>
        s.frequentCategories(t, now: now, ensure: ensure);

    test('tanpa riwayat: diisi kategori tanpa sub-kategori, maksimal 7', () {
      final s = fresh();
      final f = freq(s, TxType.expense);
      expect(f.length, AppStore.kFrequentSlots);
      expect(f.toSet().length, f.length);
      final parents = {for (final c in s.categories) c.parentId};
      for (final id in f) {
        expect(parents.contains(id), isFalse, reason: '$id punya sub-kategori');
        expect(s.categoryById(id)!.type, TxType.expense);
      }
    });

    test('pemasukan: semua kategori pemasukan bawaan muat', () {
      final s = fresh();
      final f = freq(s, TxType.income);
      expect(f, containsAll(['gaji', 'bonus', 'passive', 'refund']));
      expect(f.every((id) => s.categoryById(id)!.type == TxType.income), isTrue);
    });

    test('urut dari yang paling sering, seri dipecah yang terbaru', () {
      final s = fresh();
      s.accounts = [acc('a', initial: 1000)];
      s.transactions = [
        tx('1', TxType.expense, 10, 'a', cat: 'cafe', date: DateTime(2026, 10, 1)),
        tx('2', TxType.expense, 10, 'a', cat: 'makan', date: DateTime(2026, 10, 2)),
        tx('3', TxType.expense, 10, 'a', cat: 'makan', date: DateTime(2026, 10, 3)),
        tx('4', TxType.expense, 10, 'a', cat: 'transport', date: DateTime(2026, 10, 5)),
        tx('5', TxType.expense, 10, 'a', cat: 'cafe', date: DateTime(2026, 10, 4)),
      ];
      final f = freq(s, TxType.expense);
      // makan 2x, cafe 2x (lebih lama dari makan? cafe terakhir 4 Okt > makan 3 Okt)
      expect(f.take(3).toList(), ['cafe', 'makan', 'transport']);
    });

    test('yang dipin selalu di depan dan tidak bergeser', () {
      final s = fresh();
      s.accounts = [acc('a', initial: 1000)];
      s.transactions = [
        for (var i = 0; i < 5; i++)
          tx('m$i', TxType.expense, 10, 'a', cat: 'makan', date: DateTime(2026, 10, 1 + i)),
      ];
      expect(s.togglePin('kos'), isTrue);
      expect(s.togglePin('bills'), isTrue);
      final f = freq(s, TxType.expense);
      expect(f.take(3).toList(), ['kos', 'bills', 'makan']);
      expect(s.isPinned('kos'), isTrue);
      // Lepas pin satu: yang lain tetap di depan. Lepas semua: urutan otomatis.
      expect(s.togglePin('kos'), isTrue);
      expect(freq(s, TxType.expense).take(2).toList(), ['bills', 'makan']);
      expect(s.togglePin('bills'), isTrue);
      expect(freq(s, TxType.expense).first, 'makan');
    });

    test('pin kategori jenis lain atau yang sudah dihapus diabaikan', () {
      final s = fresh();
      s.togglePin('gaji');
      s.togglePin('hilang');
      final f = freq(s, TxType.expense);
      expect(f.contains('gaji'), isFalse);
      expect(f.contains('hilang'), isFalse);
      expect(freq(s, TxType.income).first, 'gaji');
    });

    test('pin maksimal 7', () {
      final s = fresh();
      final ids = s.categories
          .where((c) => c.type == TxType.expense)
          .map((c) => c.id)
          .take(8)
          .toList();
      for (final id in ids.take(7)) {
        expect(s.togglePin(id), isTrue);
      }
      expect(s.togglePin(ids[7]), isFalse);
      expect(s.settings.pinnedCats.length, 7);
    });

    test('disembunyikan dilewati, tapi pin menampilkannya lagi', () {
      final s = fresh();
      s.accounts = [acc('a', initial: 1000)];
      s.transactions = [
        tx('1', TxType.expense, 10, 'a', cat: 'makan', date: DateTime(2026, 10, 1)),
      ];
      expect(freq(s, TxType.expense).first, 'makan');
      s.hideFromFrequent('makan');
      expect(freq(s, TxType.expense).contains('makan'), isFalse);
      s.togglePin('makan');
      expect(freq(s, TxType.expense).first, 'makan');
      expect(s.settings.hiddenFreq.contains('makan'), isFalse);
      s.hideFromFrequent('makan');
      expect(s.isPinned('makan'), isFalse);
      s.showInFrequent('makan');
      expect(freq(s, TxType.expense).first, 'makan');
    });

    test('kategori yang sedang dipilih selalu ikut tampil', () {
      final s = fresh();
      final f = freq(s, TxType.expense);
      final other = s.categories
          .firstWhere((c) => c.type == TxType.expense && !f.contains(c.id) &&
              s.childrenOf(c.id).isEmpty)
          .id;
      final withSel = freq(s, TxType.expense, ensure: other);
      expect(withSel.length, AppStore.kFrequentSlots);
      expect(withSel.contains(other), isTrue);
    });

    test('jumlah pemakaian 90 hari', () {
      final s = fresh();
      s.accounts = [acc('a', initial: 1000)];
      s.transactions = [
        tx('1', TxType.expense, 10, 'a', cat: 'makan', date: DateTime(2026, 10, 1)),
        tx('2', TxType.expense, 10, 'a', cat: 'makan', date: DateTime(2026, 6, 1)),
        tx('3', TxType.expense, 10, 'a', cat: 'makan', date: DateTime(2026, 9, 1)),
      ];
      expect(s.categoryUseCount('makan', now: now), 2);
    });

    test('pin dan sembunyi ikut tersimpan di JSON', () {
      final s = fresh();
      s.togglePin('kos');
      s.hideFromFrequent('makan');
      final back = AppSettings.fromJson(
          jsonDecode(jsonEncode(s.settings.toJson())) as Map<String, dynamic>);
      expect(back.pinnedCats, ['kos']);
      expect(back.hiddenFreq, ['makan']);
      expect(AppSettings.fromJson({}).pinnedCats, isEmpty);
    });

    test('nama pendek untuk kotak kategori', () {
      expect(shortCategoryName('Bills (Listrik, Air, Kuota) 💡'), 'Bills');
      expect(shortCategoryName('Makan dan Minum 🍲'), 'Makan dan Minum');
      expect(shortCategoryName('Personal Care (Skincare, Shampoo) 🛀'), 'Personal Care');
      expect(shortCategoryName('Gaji'), 'Gaji');
      expect(shortCategoryName('🍲'), '🍲');
    });
  });

  group('v4.2 bahasa', () {
    tearDown(() => gLang.value = AppLang.id);

    test('bahasa Indonesia: teks apa adanya, isian {0} diisi', () {
      gLang.value = AppLang.id;
      expect(tr('Beranda'), 'Beranda');
      expect(tr('Saldo {0}', ['Rp 5']), 'Saldo Rp 5');
    });

    test('English dan 中文 memakai terjemahan, yang belum ada kembali ke Indonesia', () {
      gLang.value = AppLang.en;
      expect(tr('Beranda'), 'Home');
      expect(tr('Saldo {0}', ['Rp 5']), 'Balance Rp 5');
      expect(tr('Kalimat yang belum diterjemahkan'), 'Kalimat yang belum diterjemahkan');
      gLang.value = AppLang.zh;
      expect(tr('Beranda'), '首页');
      expect(tr('Simpan {0}', ['Rp 5']), '保存 Rp 5');
      expect(tr('Kalimat yang belum diterjemahkan'), 'Kalimat yang belum diterjemahkan');
    });

    test('isian bisa dipakai lebih dari sekali dan urutannya bebas', () {
      gLang.value = AppLang.en;
      expect(tr('Sisa limit {0} dari {1}', ['Rp 1', 'Rp 9']), 'Limit left Rp 1 of Rp 9');
      gLang.value = AppLang.zh;
      expect(tr('Sisa limit {0} dari {1}', ['Rp 1', 'Rp 9']), '额度剩余 Rp 1 / Rp 9');
      // Urutan isian di terjemahan boleh berbeda dari kalimat Indonesia.
      expect(tr('{0} Anggaran {1} hampir habis.', ['A', 'B']), 'A B预算快用完了。');
    });

    test('pola untuk teks berangka', () {
      gLang.value = AppLang.en;
      expect(tr('12 transaksi'), '12 transactions');
      gLang.value = AppLang.zh;
      expect(tr('12 transaksi'), '12 笔交易');
    });

    test('kamus English dan 中文 punya kunci yang sama dan isian yang sama', () {
      expect(kEnStrings.keys.toSet(), kZhStrings.keys.toSet());
      final ph = RegExp(r'\{\d+\}');
      for (final k in kEnStrings.keys) {
        final a = (ph.allMatches(k).map((m) => m.group(0)!).toList()..sort()).join();
        final b = (ph.allMatches(kEnStrings[k]!).map((m) => m.group(0)!).toList()..sort()).join();
        final c = (ph.allMatches(kZhStrings[k]!).map((m) => m.group(0)!).toList()..sort()).join();
        expect(b, a, reason: 'EN: $k');
        expect(c, a, reason: 'ZH: $k');
      }
    });

    test('nama kategori bawaan punya terjemahan', () {
      gLang.value = AppLang.en;
      expect(tr('Makan dan Minum 🍲'), 'Food & Drinks 🍲');
      expect(shortCategoryName('Makan dan Minum 🍲'), 'Food & Drinks');
      gLang.value = AppLang.id;
      expect(shortCategoryName('Makan dan Minum 🍲'), 'Makan dan Minum');
    });

    test('format tanggal mengikuti bahasa', () {
      gLang.value = AppLang.id;
      expect(gDateLoc, 'id_ID');
      gLang.value = AppLang.en;
      expect(gDateLoc, 'en_US');
      gLang.value = AppLang.zh;
      expect(gDateLoc, 'zh_CN');
    });

    test('v4.5: English tidak menulis "1 days" atau "11 days" salah', () {
      gLang.value = AppLang.en;
      expect(tr('Ubah kategori {0} transaksi', [1]), 'Change category of 1 transaction');
      expect(tr('Ubah kategori {0} transaksi', [2]), 'Change category of 2 transactions');
      expect(tr('Ubah kategori {0} transaksi', [11]), 'Change category of 11 transactions');
      expect(tr('Ubah kategori {0} transaksi', [21]), 'Change category of 21 transactions');
      expect(tr('{0} hari lalu', [1]), '1 day ago');
      expect(tr('{0} hari lalu', [3]), '3 days ago');
      expect(tr('Rata-rata {0} bln', [1]), 'Average of 1 mo');
      expect(tr('1 transaksi'), '1 transaction');
      gLang.value = AppLang.zh;
      expect(tr('{0} hari lalu', [1]), contains('天前'));
    });

    test('bahasa tersimpan di pengaturan, backup lama tanpa bahasa tetap Indonesia', () {
      final s = AppSettings()..lang = 'zh';
      expect(AppSettings.fromJson(s.toJson()).lang, 'zh');
      expect(AppSettings().toJson().containsKey('lang'), isFalse);
      expect(AppSettings.fromJson({}).lang, 'id');
      expect(AppSettings.fromJson({'lang': 'xx'}).lang, 'id');
      expect(langOf('en'), AppLang.en);
      expect(langOf(null), AppLang.id);
    });
  });

  group('Cicilan 0% (v4.6)', () {
    Installment inst({
      String id = 'i1',
      double total = 300000,
      int tenor = 3,
      int day = 1,
      DateTime? first,
      String account = 'a',
      List<String>? paid,
    }) =>
        Installment(
          id: id,
          name: 'Headset',
          total: total,
          tenor: tenor,
          dueDay: day,
          firstDue: first ?? DateTime(2026, 11, 1),
          accountId: account,
          paidTx: paid,
        );

    test('total dibagi tenor, sisa pembulatan masuk cicilan terakhir', () {
      final x = inst(total: 100001, tenor: 3);
      expect(x.amountOf(0), 33334);
      expect(x.amountOf(1), 33334);
      expect(x.amountOf(2), 33333);
      expect(x.amountOf(0) + x.amountOf(1) + x.amountOf(2), 100001);
      final once = inst(total: 131266, tenor: 1);
      expect(once.amountOf(0), 131266);
      expect(once.remaining, 131266);
    });

    test('jatuh tempo tanggal 31 dipotong ke akhir bulan pendek', () {
      final x = inst(tenor: 4, day: 31, first: DateTime(2027, 1, 1));
      expect(x.dueOf(0), DateTime(2027, 1, 31));
      expect(x.dueOf(1), DateTime(2027, 2, 28));
      expect(x.dueOf(2), DateTime(2027, 3, 31));
      expect(x.dueOf(3), DateTime(2027, 4, 30));
      expect(inst(tenor: 3, first: DateTime(2026, 11, 1)).lastDue, DateTime(2027, 1, 1));
    });

    test('sisa dan lunas mengikuti jumlah yang sudah dibayar', () {
      final x = inst(total: 300000, tenor: 3, paid: ['', '']);
      expect(x.paidCount, 2);
      expect(x.remaining, 100000);
      expect(x.nextDue, DateTime(2027, 1, 1));
      expect(x.done, isFalse);
      final y = inst(total: 300000, tenor: 3, paid: ['', '', '']);
      expect(y.done, isTrue);
      expect(y.remaining, 0);
      expect(y.nextDue, isNull);
    });

    test('Tandai dibayar mencatat pengeluaran, Urungkan membatalkannya', () {
      final s = storeWith([acc('a', initial: 1000000)]);
      s.installments = [inst()];
      final id = s.markInstallmentPaid('i1')!;
      expect(s.installments.single.paidCount, 1);
      expect(s.balanceOf('a'), 900000);
      final t = s.transactions.single;
      expect(t.id, id);
      expect(t.type, TxType.expense);
      expect(t.amount, 100000);
      s.undoInstallmentPayment('i1');
      expect(s.installments.single.paidCount, 0);
      expect(s.transactions, isEmpty);
      expect(s.balanceOf('a'), 1000000);
      // lunas: tidak bisa dibayar lagi
      s.installments = [inst(paid: ['', '', ''])];
      expect(s.markInstallmentPaid('i1'), isNull);
    });

    test('Aman dibelanjakan menyisihkan cicilan yang jatuh tempo tanggal 1', () {
      final now = DateTime(2026, 10, 22, 10);
      final s = storeWith([acc('a', initial: 3100000)]);
      s.installments = [inst(total: 131266, tenor: 1)];
      final r = s.safeToSpend(now);
      expect(r.installments, 131266);
      expect(r.installmentsOn, DateTime(2026, 11, 1));
      expect(r.perDay, closeTo((3100000 - 131266) / 10, 0.01));
      // jatuh tempo tanggal 2 sudah di luar jangkauan
      s.installments = [inst(total: 131266, tenor: 1, day: 2)];
      expect(s.safeToSpend(now).installments, 0);
      // yang sudah dibayar tidak disisihkan lagi
      s.installments = [inst(total: 131266, tenor: 1, paid: [''])];
      expect(s.safeToSpend(now).installments, 0);
    });

    test('cicilan yang lewat jatuh tempo dan belum dibayar tetap disisihkan', () {
      final now = DateTime(2026, 10, 22, 10);
      final s = storeWith([acc('a', initial: 3100000)]);
      s.installments = [inst(total: 200000, tenor: 2, first: DateTime(2026, 10, 1))];
      final dues = s.installmentsDueBefore(DateTime(2026, 11, 2));
      expect(dues.map((d) => d.date), [DateTime(2026, 10, 1), DateTime(2026, 11, 1)]);
      expect(s.safeToSpend(now).installments, 200000);
    });

    test('backup: tersimpan, terbaca, dan ikut terhapus bersama akunnya', () {
      final s = storeWith([acc('a', initial: 1000), acc('b')]);
      s.installments = [
        inst(paid: ['tx9']),
        inst(id: 'i2', account: 'b'),
      ];
      final json = s.exportJson();
      expect(AppStore.peekJson(json).installments, 2);
      expect(s.currentInfo().counts(), contains('2'));
      final s2 = AppStore();
      s2.importJson(json);
      expect(s2.installments.map((x) => x.id), ['i1', 'i2']);
      expect(s2.installments.first.paidTx, ['tx9']);
      expect(s2.installments.first.dueOf(1), DateTime(2026, 12, 1));
      expect(s2.accountInUse('b'), isTrue);
      s2.deleteAccountWithData('b');
      expect(s2.installments.map((x) => x.id), ['i1']);
      // backup lama tanpa cicilan tetap bisa dibuka
      final old = jsonDecode(json) as Map<String, dynamic>..remove('installments');
      final s3 = AppStore();
      s3.importJson(jsonEncode(old));
      expect(s3.installments, isEmpty);
    });

    test('kekayaan bersih setelah kewajiban: sisa cicilan dan utang dikurangkan', () {
      final s = storeWith([acc('a', initial: 1000000)]);
      expect(s.pendingLiabilitiesIDR, 0);
      s.installments = [inst(total: 300000, tenor: 3, paid: [''])];
      s.debts = [
        Debt(id: 'd1', person: 'Budi', theyOwe: false, amount: 50000, date: DateTime(2026, 10, 1)),
        Debt(id: 'd2', person: 'Sari', theyOwe: true, amount: 70000, date: DateTime(2026, 10, 1)),
      ];
      expect(s.pendingLiabilitiesIDR, 200000 + 50000);
      expect(s.netWorthIDR, 1000000);
      expect(s.netWorthAfterLiabilitiesIDR, 750000);
    });

    test('pengingat cicilan masuk daftar notifikasi', () {
      final s = storeWith([acc('a')]);
      s.settings.notifEnabled = true;
      s.settings.notifRecurring = true;
      final next = DateTime.now().add(const Duration(days: 10));
      s.installments = [
        inst(first: DateTime(next.year, next.month, 1), day: next.day),
      ];
      final titles = s.plannedNotifications().map((n) => n.title).toList();
      expect(titles.any((t) => t.contains('Headset')), isTrue);
    });
  });
  group('v5.0 maskot, fitur, ritme', () {
    final now = DateTime(2026, 10, 12, 12);
    MascotMood mood(double left, {double perDay = 100, DateTime? last, bool accounts = true}) =>
        mascotMoodFor(
            leftToday: left,
            perDay: perDay,
            lastTx: last ?? now,
            now: now,
            hasAccounts: accounts);

    test('suasana maskot mengikuti sisa jatah hari ini', () {
      expect(mood(100), MascotMood.happy);
      expect(mood(80), MascotMood.happy);
      expect(mood(79), MascotMood.ok);
      expect(mood(50), MascotMood.ok);
      expect(mood(49), MascotMood.warn);
      expect(mood(30), MascotMood.warn);
      expect(mood(29), MascotMood.danger);
      expect(mood(0), MascotMood.danger);
      expect(mood(-1), MascotMood.over);
    });

    test('maskot ngantuk setelah 3 hari tanpa catatan, mengalahkan yang lain', () {
      expect(mood(100, last: now.subtract(const Duration(days: 2))), MascotMood.happy);
      expect(mood(100, last: now.subtract(const Duration(days: 3))), MascotMood.sleepy);
      expect(mood(-50, last: now.subtract(const Duration(days: 5))), MascotMood.sleepy);
      expect(mascotMoodFor(leftToday: 100, perDay: 100, lastTx: null, now: now, hasAccounts: true),
          MascotMood.sleepy);
      // Belum punya akun: tidak ngantuk.
      expect(mascotMoodFor(leftToday: 100, perDay: 100, lastTx: null, now: now, hasAccounts: false),
          MascotMood.happy);
    });

    test('transaksi terakhir mengabaikan yang terjadwal di masa depan', () {
      final s = storeWith([acc('a')], [
        tx('1', TxType.expense, 1, 'a', date: DateTime(2026, 10, 10)),
        tx('2', TxType.expense, 1, 'a', date: DateTime(2026, 10, 20)),
      ]);
      expect(lastTransactionDate(s, now), DateTime(2026, 10, 10));
    });

    test('saklar fitur: bawaan, tersimpan, dan hanya menyimpan yang beda', () {
      final a = AppSettings();
      expect(a.feature('cicilan'), isTrue);
      expect(a.feature('tunda'), isFalse);
      a.features['cicilan'] = false;
      a.features['tunda'] = true;
      final back = AppSettings.fromJson(a.toJson());
      expect(back.feature('cicilan'), isFalse);
      expect(back.feature('tunda'), isTrue);
      expect(back.feature('utang'), isTrue);
      expect(AppSettings.fromJson(<String, dynamic>{}).features, isEmpty);
    });

    test('cicilan dimatikan: tidak dihitung, data tetap ada', () {
      final s = storeWith([acc('a', initial: 1000000)]);
      final next = DateTime.now().add(const Duration(days: 5));
      s.installments = [
        Installment(
            id: 'i1',
            name: 'Headset',
            total: 1200000,
            tenor: 3,
            firstDue: DateTime(next.year, next.month, 1),
            dueDay: next.day,
            accountId: 'a'),
      ];
      expect(s.installmentsRemaining, greaterThan(0));
      s.updateSettings((x) => x.features['cicilan'] = false);
      expect(s.installmentsRemaining, 0);
      expect(s.activeInstallments, isEmpty);
      expect(s.installments, hasLength(1));
      s.updateSettings((x) => x.features.remove('cicilan'));
      expect(s.installmentsRemaining, greaterThan(0));
    });

    test('mode animasi pembuka tersimpan', () {
      final a = AppSettings();
      expect(a.splashMode, 'once');
      a.splashMode = 'off';
      expect(AppSettings.fromJson(a.toJson()).splashMode, 'off');
      a.splashMode = 'always';
      expect(AppSettings.fromJson(a.toJson()).splashMode, 'always');
      expect(AppSettings.fromJson(<String, dynamic>{'splashMode': 'aneh'}).splashMode, 'once');
    });

    test('bentuk grafik kategori tersimpan', () {
      final a = AppSettings();
      expect(a.chartShape, 'donut');
      expect(a.toJson().containsKey('chartShape'), isFalse);
      a.chartShape = 'pie';
      expect(AppSettings.fromJson(a.toJson()).chartShape, 'pie');
      expect(AppSettings.fromJson(<String, dynamic>{'chartShape': 'aneh'}).chartShape, 'donut');
    });

    test('gaya ikon: flat dan mono diterima, yang aneh jadi kartun', () {
      for (final st in ['cartoon', 'flat', 'classic', 'mono']) {
        final a = AppSettings()..iconStyle = st;
        expect(AppSettings.fromJson(a.toJson()).iconStyle, st);
      }
      expect(AppSettings.fromJson(<String, dynamic>{'iconStyle': 'xx'}).iconStyle, 'cartoon');
    });

    test('ritme: bagian periode berjalan dan penanda kategori', () {
      final range = DateTimeRange(start: DateTime(2026, 10, 1), end: DateTime(2026, 11, 1));
      expect(periodElapsed(range, DateTime(2026, 10, 1, 9)), closeTo(1 / 31, 1e-9));
      expect(periodElapsed(range, DateTime(2026, 10, 31, 23)), 1.0);
      final half = periodElapsed(range, DateTime(2026, 10, 16)); // 16/31
      expect(paceTagFor(0.60 * 1000, 1000, half), PaceTag.even); // 60% vs 51.6%: masih pas
      expect(paceTagFor(0.70 * 1000, 1000, half), PaceTag.fast);
      expect(paceTagFor(0.40 * 1000, 1000, half), PaceTag.slow);
      expect(paceTagFor(0.50 * 1000, 1000, half), PaceTag.even);
      expect(paceTagFor(10, 0, half), PaceTag.even);
    });

    test('kalimat ritme', () {
      // Batas 3.000.000, hari ke-10 dari 30: seharusnya 1.000.000.
      expect(paceDiff(1400000, 3000000, 10 / 30), closeTo(400000, 1e-6));
      expect(paceSentence(1400000, 3000000, 10 / 30), contains('Lebih cepat'));
      expect(paceSentence(600000, 3000000, 10 / 30), contains('Lebih hemat'));
      expect(paceSentence(1000000, 3000000, 10 / 30), contains('Pas'));
    });

    test('perkiraan uang habis', () {
      final today = DateTime(2026, 10, 12);
      // Rata-rata 100rb/hari, sisa 500rb: habis 5 hari lagi.
      expect(runOutDate(remaining: 500000, spentSoFar: 1200000, daysElapsed: 12, today: today),
          DateTime(2026, 10, 17));
      expect(runOutDate(remaining: -1, spentSoFar: 1200000, daysElapsed: 12, today: today), today);
      expect(runOutDate(remaining: 500000, spentSoFar: 0, daysElapsed: 12, today: today), isNull);
    });
  });
  group('v5.0 kalender peta panas', () {
    test('tingkat warna dari pengeluaran harian', () {
      expect(heatLevel(0, 100), 0);
      expect(heatLevel(10, 0), 0);
      expect(heatLevel(25, 100), 1);
      expect(heatLevel(26, 100), 2);
      expect(heatLevel(51, 100), 3);
      expect(heatLevel(76, 100), 4);
      expect(heatLevel(100, 100), 4);
    });

    test('total bulan, hari paling boros, dan titik jatuh tempo', () {
      final s = storeWith([acc('a', initial: 5000000)], [
        tx('1', TxType.expense, 50000, 'a', date: DateTime(2026, 10, 3)),
        tx('2', TxType.expense, 70000, 'a', date: DateTime(2026, 10, 3)),
        tx('3', TxType.expense, 30000, 'a', date: DateTime(2026, 10, 9)),
        tx('4', TxType.income, 1000000, 'a', date: DateTime(2026, 10, 25)),
        tx('5', TxType.expense, 999, 'a', date: DateTime(2026, 9, 30)),
      ]);
      s.recurring = [
        RecurringRule(
            id: 'r1',
            title: 'Internet',
            amount: 300000,
            type: TxType.expense,
            accountId: 'a',
            frequency: Frequency.monthly,
            start: DateTime(2026, 10, 15)),
      ];
      s.installments = [
        Installment(
            id: 'i1',
            name: 'Headset',
            total: 300000,
            tenor: 3,
            dueDay: 20,
            firstDue: DateTime(2026, 10, 20),
            accountId: 'a'),
      ];
      final c = s.calendarMonth(DateTime(2026, 10, 1));
      expect(c.totalOut, 150000);
      expect(c.totalIn, 1000000);
      expect(c.expense[3], 120000);
      expect(c.peakDay, 3);
      expect(c.income[25], 1000000);
      expect(c.dueDays, containsAll(<int>[15, 20]));
      expect(c.dueDays, isNot(contains(3)));
      // Cicilan dimatikan: titiknya hilang.
      s.updateSettings((x) => x.features['cicilan'] = false);
      expect(s.calendarMonth(DateTime(2026, 10, 1)).dueDays, <int>{15});
    });

    test('hari paling boros tidak ditandai kalau pengeluaran hanya satu hari', () {
      final s = storeWith([acc('a')], [
        tx('1', TxType.expense, 50000, 'a', date: DateTime(2026, 10, 3)),
      ]);
      expect(s.calendarMonth(DateTime(2026, 10, 1)).peakDay, isNull);
    });
  });
  group('v5.0 rekap cerita', () {
    // Oktober 2026: 1 Okt = Kamis. Akhir pekan: 3, 4, 10, 11.
    final now = DateTime(2026, 10, 12, 12);
    AppStore data() => storeWith([acc('a', initial: 9000000)], [
          tx('i1', TxType.income, 5000000, 'a', date: DateTime(2026, 10, 1)),
          tx('e1', TxType.expense, 100000, 'a', cat: 'food', date: DateTime(2026, 10, 2)),
          tx('e2', TxType.expense, 100000, 'a', cat: 'food', date: DateTime(2026, 10, 5)),
          tx('e3', TxType.expense, 100000, 'a', cat: 'food', date: DateTime(2026, 10, 6)),
          tx('e4', TxType.expense, 300000, 'a', cat: 'bag', date: DateTime(2026, 10, 3)),
          tx('e5', TxType.expense, 300000, 'a', cat: 'bag', date: DateTime(2026, 10, 10)),
          tx('p1', TxType.expense, 500000, 'a', cat: 'food', date: DateTime(2026, 9, 10)),
          tx('p2', TxType.expense, 200000, 'a', cat: 'bag', date: DateTime(2026, 9, 12)),
        ]);

    test('angka dasar: tersisa, hari terboros, bulan lalu', () {
      final s = data().monthStory(DateTime(2026, 10), now);
      expect(s.hasData, isTrue);
      expect(s.income, 5000000);
      expect(s.expense, 900000);
      expect(s.savingRate, closeTo(0.82, 1e-9));
      expect(s.peakAmount, 300000);
      expect(s.lastExpense, 700000);
      expect(s.expenseChangePct, closeTo((900000 - 700000) / 700000 * 100, 1e-9));
      expect(s.topCats, isNotEmpty);
    });

    test('akhir pekan dibanding hari kerja', () {
      final s = data().monthStory(DateTime(2026, 10), now);
      // Akhir pekan sampai 12 Okt: 3,4,10,11 => 600rb / 4 = 150rb per hari.
      // Hari kerja: 1,2,5,6,7,8,9,12 => 300rb / 8 = 37,5rb per hari.
      expect(s.weekendExtraPct, closeTo((150000 / 37500 - 1) * 100, 1e-6));
    });

    test('tanpa data atau tanpa bulan lalu', () {
      final empty = storeWith([acc('a')]).monthStory(DateTime(2026, 10), now);
      expect(empty.hasData, isFalse);
      expect(empty.savingRate, isNull);
      expect(empty.lastExpense, isNull);
      final onlyThis = storeWith([acc('a')], [
        tx('1', TxType.expense, 1000, 'a', date: DateTime(2026, 10, 2)),
      ]).monthStory(DateTime(2026, 10), now);
      expect(onlyThis.lastExpense, isNull);
      expect(onlyThis.expenseChangePct, isNull);
    });

    test('teks pembantu', () {
      expect(storyDelta(60.4), '▲ 60%');
      expect(storyDelta(-8), '▼ 8%');
      expect(storyDelta(0.2), '● sama');
      expect(storyDelta(null), 'baru');
      expect(storySavingNote(0.25), contains('di atas'));
      expect(storySavingNote(0.15), contains('Sedikit lagi'));
      expect(storySavingNote(-0.1), contains('lebih besar'));
      expect(storySavingNote(null), contains('Belum ada pemasukan'));
    });
  });
  group('v5.0 tunda beli', () {
    final now = DateTime(2026, 10, 12, 12);
    WaitItem item(String id, double price,
            {int days = 7, DateTime? at, String status = 'waiting', DateTime? decided}) =>
        WaitItem(
            id: id,
            name: 'Barang $id',
            price: price,
            createdAt: at ?? DateTime(2026, 10, 9, 20),
            waitDays: days,
            status: status,
            decidedAt: decided);

    test('sisa hari menunggu', () {
      final w = item('a', 100, at: DateTime(2026, 10, 9, 20)); // siap 16 Okt
      expect(w.readyAt, DateTime(2026, 10, 16));
      expect(w.daysLeft(now), 4);
      expect(w.daysLeft(DateTime(2026, 10, 16, 8)), 0);
      expect(w.daysLeft(DateTime(2026, 11, 1)), 0);
    });

    test('tersimpan lewat JSON, termasuk keputusan', () {
      final s = storeWith([acc('a')]);
      s.waitItems = [
        item('a', 1200000),
        item('b', 450000, status: 'canceled', decided: DateTime(2026, 10, 11)),
      ];
      final s2 = AppStore();
      s2.importJson(s.exportJson());
      expect(s2.waitItems, hasLength(2));
      expect(s2.waitItems.first.waiting, isTrue);
      expect(s2.waitItems.last.canceled, isTrue);
      expect(s2.waitItems.last.decidedAt, DateTime(2026, 10, 11));
      // Tanpa daftar tunggu, kuncinya tidak ditulis.
      expect(storeWith([acc('a')]).toJson().containsKey('waitItems'), isFalse);
    });

    test('hanya tampil kalau fiturnya menyala, dan total batal bulan ini', () {
      final s = storeWith([acc('a', initial: 5000000)]);
      s.waitItems = [
        item('a', 1200000),
        item('b', 450000, status: 'canceled', decided: DateTime(2026, 10, 11)),
        item('c', 400000, status: 'canceled', decided: DateTime(2026, 10, 3)),
        item('d', 999000, status: 'canceled', decided: DateTime(2026, 9, 3)),
        item('e', 777000, status: 'bought', decided: DateTime(2026, 10, 4)),
      ];
      expect(s.waitingItems, isEmpty); // mati secara bawaan
      expect(s.canceledTotal(now), 850000);
      expect(s.canceledInPeriod(now), hasLength(2));
      s.updateSettings((x) => x.features['tunda'] = true);
      expect(s.waitingItems.map((w) => w.id), ['a']);
    });

    test('keputusan jadi beli atau batal tersimpan', () {
      final s = storeWith([acc('a')]);
      s.waitItems = [item('a', 100)];
      s.decideWait('a', 'canceled', now);
      expect(s.waitItems.single.canceled, isTrue);
      expect(s.waitItems.single.decidedAt, now);
      s.deleteWait('a');
      expect(s.waitItems, isEmpty);
    });

    test('pengingat sekali setelah masa tunggu lewat', () {
      final s = storeWith([acc('a')]);
      s.settings.notifEnabled = true;
      final soon = DateTime.now().subtract(const Duration(days: 3));
      s.waitItems = [item('a', 100, days: 7, at: soon)];
      s.updateSettings((x) => x.features['tunda'] = true);
      expect(s.plannedNotifications().any((n) => n.title.contains('Barang a')), isTrue);
      s.updateSettings((x) => x.features.remove('tunda'));
      expect(s.plannedNotifications().any((n) => n.title.contains('Barang a')), isFalse);
    });
  });
  group('v5.0 ikon Flat', () {
    test('semua ikon Flat punya padanan Kartun dan berupa PNG', () {
      final kartun = <String>{...kArtKeys, ...kExtraArtKeys};
      expect(kFlatB64.length, greaterThanOrEqualTo(55));
      for (final e in kFlatB64.entries) {
        expect(kartun, contains(e.key), reason: e.key);
        final b = base64Decode(e.value);
        expect(b.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47], reason: e.key);
      }
    });

    test('gaya Flat memakai gambar Flat, gaya lain tidak', () {
      addTearDown(() => gIconStyle.value = 'cartoon');
      gIconStyle.value = 'cartoon';
      final k = artBytes('food');
      gIconStyle.value = 'flat';
      final f = artBytes('food');
      expect(f, isNotNull);
      expect(f, isNot(equals(k)));
      gIconStyle.value = 'mono';
      expect(iconsArt('mono'), isFalse);
      expect(iconsArt('flat'), isTrue);
      expect(iconsArt('classic'), isFalse);
    });
  });

  group('v5.0.3 log tangkapan', () {
    AppStore setup() {
      final s = storeWith([acc('bca', initial: 1000000)]);
      s.categories = [
        TxCategory(id: 'lain', name: 'Lain lain', type: TxType.expense, icon: 'other', color: 0),
      ];
      s.settings.captureMode = 'auto';
      return s;
    }

    Map<String, dynamic> n(String text, DateTime at, {String title = 'myBCA'}) => {
          'pkg': 'com.bca.mybca.omni.android',
          'title': title,
          'text': text,
          'time': at.millisecondsSinceEpoch,
        };

    test('dicatat otomatis: tercatat dengan nama akun', () {
      final s = setup();
      s.ingestCaptured([n('Transfer berhasil sebesar Rp 50.000,00', DateTime.now())]);
      expect(s.captureLog, hasLength(1));
      expect(s.captureLog.single.code, 'auto');
      expect(s.captureLog.single.outcome, CaptureOutcome.auto);
      expect(s.captureLog.single.extra, 'BCA');
    });

    test('promo dan tanpa nominal dicatat sebagai dibuang', () {
      final s = setup();
      final t = DateTime.now();
      s.ingestCaptured([
        n('Diskon Rp 5.000 di Kedai Boboko. Nikmati potongan harga senilai Rp 5.000', t),
        n('Selamat datang kembali di myBCA', t.add(const Duration(minutes: 5)), title: 'Halo'),
      ]);
      expect(s.captureLog.map((e) => e.code), ['promo', 'noamount']);
      expect(s.captureLog.every((e) => e.outcome == CaptureOutcome.dropped), isTrue);
      expect(s.pendingCaptures, isEmpty);
    });

    test('mode bukan auto: masuk antrean dengan alasan mode', () {
      final s = setup();
      s.settings.captureMode = 'ask';
      s.ingestCaptured([n('Transfer berhasil sebesar Rp 50.000,00', DateTime.now())]);
      expect(s.pendingCaptures, hasLength(1));
      expect(s.captureLog.single.code, 'mode');
      expect(s.captureLog.single.outcome, CaptureOutcome.queued);
    });

    test('mirip transaksi yang sudah ada: antrean dengan alasan dup', () {
      final s = setup();
      final t = DateTime.now();
      s.ingestCaptured([n('Transfer berhasil sebesar Rp 50.000,00', t)]);
      s.ingestCaptured([n('Transfer berhasil sebesar Rp 50.000,00 ya', t.add(const Duration(minutes: 4)))]);
      expect(s.captureLog.map((e) => e.code), ['auto', 'dup']);
    });

    test('hanya 40 terakhir, dan alasan punya teks', () {
      final s = setup();
      s.settings.captureMode = 'ask';
      final t = DateTime(2026, 10, 12, 8);
      s.ingestCaptured([
        for (var i = 0; i < 45; i++)
          n('Pembayaran Rp ${(i + 1) * 1000} berhasil', t.add(Duration(minutes: i * 5))),
      ]);
      expect(s.captureLog, hasLength(kCaptureLogMax));
      expect(captureReasonText(s.captureLog.last), isNotEmpty);
      expect(s.captureLog.last.snippet, contains('45000'));
    });

    test('log ikut penyimpanan HP, tidak ikut backup, dan tidak hilang saat impor', () {
      final s = setup();
      s.ingestCaptured([n('Transfer berhasil sebesar Rp 50.000,00', DateTime.now())]);
      expect(s.exportJson().contains('captureLog'), isFalse);
      final saved = s.toJson(includeSecrets: true);
      expect(saved['captureLog'], isA<List>());
      final s2 = AppStore();
      s2.importJson(jsonEncode(saved));
      // Impor biasa mempertahankan log HP ini (kosong di sini).
      expect(s2.captureLog, isEmpty);
      s.importJson(s.exportJson());
      expect(s.captureLog, hasLength(1));
      s.clearCaptureLog();
      expect(s.captureLog, isEmpty);
    });
  });

  group('v5.0.3 laporan PDF', () {
    test('buildImagePdf: struktur dan daftar offset valid', () {
      final px = Uint8List.fromList(List.filled(2 * 2 * 3, 255));
      final page = PdfPageImage(2, 2, Uint8List.fromList(zlib.encode(px)));
      final bytes = buildImagePdf([page, page], title: 'Tes (a) é');
      final txt = latin1.decode(bytes);
      expect(txt.startsWith('%PDF-1.4'), isTrue);
      expect(txt.trimRight().endsWith('%%EOF'), isTrue);
      expect(txt.contains('/Count 2'), isTrue);
      expect(txt.contains('/Title (Tes \\(a\\) )'), isTrue);
      final sx = RegExp(r'startxref\n(\d+)').firstMatch(txt)!;
      expect(txt.substring(int.parse(sx.group(1)!)).startsWith('xref'), isTrue);
      final entries = RegExp(r'(\d{10}) 00000 n ').allMatches(txt).toList();
      expect(entries, hasLength(3 + 3 * 2));
      for (var i = 0; i < entries.length; i++) {
        final off = int.parse(entries[i].group(1)!);
        expect(txt.substring(off).startsWith('${i + 1} 0 obj'), isTrue, reason: 'objek ${i + 1}');
      }
    });

    test('MonthReportData: ringkasan, kategori terurut, transaksi terurut tanggal', () {
      final s = storeWith([acc('bca', initial: 1000000)], [
        tx('a', TxType.income, 1000000, 'bca', date: DateTime(2026, 10, 1)),
        tx('b', TxType.expense, 200000, 'bca', cat: 'makan', date: DateTime(2026, 10, 5)),
        tx('c', TxType.expense, 100000, 'bca', cat: 'transport', date: DateTime(2026, 10, 3)),
        tx('d', TxType.expense, 50000, 'bca', cat: 'makan', date: DateTime(2026, 11, 2)),
      ]);
      s.categories = [
        TxCategory(id: 'makan', name: 'Makan', type: TxType.expense, icon: 'other', color: 0),
        TxCategory(id: 'transport', name: 'Transport', type: TxType.expense, icon: 'other', color: 0),
      ];
      final d = MonthReportData(s, DateTime(2026, 10, 20), DateTime(2026, 11, 15));
      expect(d.income, 1000000);
      expect(d.expense, 300000);
      expect(d.net, 700000);
      expect(d.days, 31);
      expect(d.perDay, closeTo(300000 / 31, 0.01));
      expect(d.categories.first.value, 200000);
      expect(d.transactions.map((t) => t.id), ['a', 'c', 'b']);
    });
  });

  group('v5.0.4 format notifikasi BCA dan Mandiri', () {
    AppStore setup() {
      final s = storeWith([
        acc('bca', initial: 2000000),
        acc('mandiri', initial: 500000),
      ]);
      s.categories = [
        TxCategory(id: 'lain', name: 'Lain lain', type: TxType.expense, icon: 'other', color: 0),
        TxCategory(id: 'gaji', name: 'Gaji', type: TxType.income, icon: 'other', color: 0),
      ];
      s.settings.captureMode = 'auto';
      return s;
    }

    test('Catatan Finansial myBCA: "Pemasukan sebesar IDR 100,000.00" = uang masuk 100000', () {
      final p = parseReceipt('Catatan Finansial\nPemasukan sebesar IDR 100,000.00 dari A****** P****.', setup());
      expect(p.amount, 100000);
      expect(p.type, TxType.income);
    });

    test('pengeluaran myBCA tetap pengeluaran', () {
      final p = parseReceipt('Pengeluaran sebesar IDR 25,000.00 di KOPI KENANGAN.', setup());
      expect(p.amount, 25000);
      expect(p.type, TxType.expense);
    });

    test('Livin by Mandiri: "Dana Rp 1.000,00 masuk ke rek." = uang masuk 1000', () {
      final p = parseReceipt(
          'Ini Dia Transaksi Terbaru Anda\nDana Rp 1.000,00 masuk ke rek. ****8509. Login ke Livin\' by Mandiri untuk cek Mutasi Transaksi.',
          setup());
      expect(p.amount, 1000);
      expect(p.type, TxType.income);
    });

    test('titik di akhir kalimat tidak ikut jadi angka', () {
      expect(parseReceipt('Saldo bertambah Rp 1.000,00.', setup()).amount, 1000);
      expect(parseReceipt('Transfer Rp50.000.', setup()).amount, 50000);
      expect(parseReceipt('Payment IDR 100,000.00.', setup()).amount, 100000);
    });

    test('notifikasi myBCA dicatat otomatis sebagai pemasukan ke akun BCA', () {
      final s = setup();
      final at = DateTime.now().subtract(const Duration(minutes: 1));
      final n = s.ingestCaptured([
        {
          'pkg': 'com.bca.mybca.omni.android',
          'title': 'Catatan Finansial',
          'text': 'Pemasukan sebesar IDR 100,000.00 dari A****** P****.',
          'time': at.millisecondsSinceEpoch,
        }
      ]);
      expect(n, 1);
      final t = s.transactions.single;
      expect(t.type, TxType.income);
      expect(t.amount, 100000);
      expect(t.accountId, 'bca');
    });
  });
}
