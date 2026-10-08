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
  credit('Kartu Kredit', Icons.credit_card_rounded),
  investment('Investasi', Icons.trending_up_rounded);

  const AccountType(this.label, this.icon);
  final String label;
  final IconData icon;
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
        return monthRange(d);
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

  Color get color => switch (this) {
        BudgetStatus.safe => C.income,
        BudgetStatus.tight => C.amberDark,
        BudgetStatus.broke => C.redDark,
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
