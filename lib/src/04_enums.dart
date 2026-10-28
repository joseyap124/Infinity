part of '../main.dart';

// =============================================================================
// ENUMS
// =============================================================================

enum TxType {
  expense('Pengeluaran', Icons.north_east_rounded),
  income('Pemasukan', Icons.south_west_rounded),
  transfer('Transfer', Icons.swap_horiz_rounded);

  const TxType(this.label, this.icon);
  final String label;
  final IconData icon;

  /// Warna nominal di daftar dan detail. Pengeluaran biasa netral supaya
  /// merah hanya muncul untuk peringatan (anggaran jebol, saldo minus).
  Color get amountColor => switch (this) {
        TxType.expense => C.carbon,
        TxType.income => C.income,
        TxType.transfer => C.blueDark,
      };

  Color get color => switch (this) {
        TxType.expense => C.redDark,
        TxType.income => C.income,
        TxType.transfer => C.blueDark,
      };
}

enum AccountType {
  ewallet('E-Wallet', Icons.account_balance_wallet_rounded),
  cash('Tunai', Icons.payments_rounded),
  bank('Rekening Bank', Icons.account_balance_rounded),
  savings('Tabungan', Icons.savings_rounded),
  emergency('Dana Darurat', Icons.health_and_safety_rounded),
  credit('Kartu kredit', Icons.credit_card_rounded),
  investment('Investasi', Icons.trending_up_rounded);

  const AccountType(this.label, this.icon);
  final String label;
  final IconData icon;

  /// Jenis akun untuk menyimpan, bukan belanja harian. Transfer ke akun
  /// seperti ini dihitung sebagai Tabungan di statistik.
  bool get isSavingsType =>
      this == savings || this == emergency || this == investment;

  /// Kunci ikon kartun (lihat 45_ikon_kartun.dart).
  String get art => switch (this) {
        AccountType.ewallet => 'dompet',
        AccountType.cash => 'cash',
        AccountType.bank => 'bank',
        AccountType.savings => 'saving',
        AccountType.emergency => 'saving',
        AccountType.credit => 'card',
        AccountType.investment => 'invest',
      };
}

enum Frequency {
  daily('Harian'),
  weekly('Mingguan'),
  monthly('Bulanan'),
  yearly('Tahunan');

  const Frequency(this.label);
  final String label;
}

enum BudgetPeriod {
  weekly('Mingguan', 'Minggu', 'minggu ini'),
  monthly('Bulanan', 'Bulan', 'bulan ini'),
  yearly('Tahunan', 'Tahun', 'tahun ini');

  const BudgetPeriod(this.label, this.short, this.current);
  final String label;
  final String short;
  final String current;

  DateTimeRange range(DateTime d) {
    switch (this) {
      case BudgetPeriod.weekly:
        return weekRange(d);
      case BudgetPeriod.monthly:
        return currentPeriod(d);
      case BudgetPeriod.yearly:
        return yearRange(d);
    }
  }
}

enum FormMode { transaction, recurring, template }

enum BudgetStatus {
  safe('Aman Abis, Jajan Terus! 👌'),
  tight('Mulai Seret, Hati-hati! ⚠️'),
  broke('Waduh, Rem Dulu, Jebol! 🚨');

  const BudgetStatus(this.message);
  final String message;

  /// Label pendek untuk chip di kartu anggaran.
  String get shortLabel => switch (this) {
        BudgetStatus.safe => 'Aman',
        BudgetStatus.tight => 'Mulai seret',
        BudgetStatus.broke => 'Jebol',
      };

  Color get color => switch (this) {
        BudgetStatus.safe => C.income,
        BudgetStatus.tight => C.amberDark,
        // Jebol bukan alarm: kuning tua seperti jatah harian (v7.0.0).
        BudgetStatus.broke => C.amberDark,
      };

  /// remaining = sisa / limit. >50% aman, 10%-50% seret, <10% atau minus jebol.
  static BudgetStatus of(double remaining) {
    if (remaining > 0.5) return BudgetStatus.safe;
    if (remaining >= 0.1) return BudgetStatus.tight;
    return BudgetStatus.broke;
  }
}

/// Kalkulasi n-kali kejadian dari tanggal mulai (tanpa drift tanggal).
DateTime occurrence(DateTime start, Frequency f, int n) {
  switch (f) {
    case Frequency.daily:
      return DateTime(
          start.year, start.month, start.day + n, start.hour, start.minute);
    case Frequency.weekly:
      return DateTime(
          start.year, start.month, start.day + 7 * n, start.hour, start.minute);
    case Frequency.monthly:
      final m0 = start.month - 1 + n;
      final y = start.year + m0 ~/ 12;
      final m = m0 % 12 + 1;
      final dim = DateTime(y, m + 1, 0).day;
      return DateTime(y, m, math.min(start.day, dim), start.hour, start.minute);
    case Frequency.yearly:
      final y = start.year + n;
      final dim = DateTime(y, start.month + 1, 0).day;
      return DateTime(y, start.month, math.min(start.day, dim), start.hour,
          start.minute);
  }
}
