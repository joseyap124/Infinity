part of '../main.dart';

// Terjemahan English. Kunci = teks Indonesia di kode. {0}, {1} = isian.
const Map<String, String> kEnStrings = {
  'Pengeluaran': 'Expense',
  'Pemasukan': 'Income',
};

/// Pola untuk teks berangka. $1, $2 diisi dari grup yang cocok.
const List<_Pat> kPatterns = [
  _Pat(r'(\d+) transaksi', r'$1 transactions', r'$1 笔交易'),
];
