part of '../main.dart';

// =============================================================================
// PILIH BANYAK TRANSAKSI (v4.4): tahan satu transaksi di Riwayat, pilih yang
// lain, lalu ubah kategori, ubah akun, atau hapus sekaligus.
// =============================================================================

/// Status pilihan di daftar transaksi. Null di layar yang tidak mendukung.
class TxSelection {
  const TxSelection(this.ids, this.toggle);
  final Set<String> ids;
  final void Function(Transaction t) toggle;

  /// Mode pilih aktif kalau sudah ada yang terpilih.
  bool get active => ids.isNotEmpty;
}

/// Hasil operasi massal: [changed] berubah, [skipped] dilewati karena tidak cocok.
class BulkResult {
  const BulkResult(this.changed, this.skipped);
  final int changed;
  final int skipped;

  @override
  bool operator ==(Object other) =>
      other is BulkResult && other.changed == changed && other.skipped == skipped;

  @override
  int get hashCode => Object.hash(changed, skipped);

  @override
  String toString() => 'BulkResult($changed, $skipped)';
}

extension BulkTransactionStore on AppStore {
  List<Transaction> transactionsByIds(Set<String> ids) =>
      transactions.where((t) => ids.contains(t.id)).toList();

  /// Jenis (keluar/masuk) dari transaksi terpilih yang punya kategori.
  /// Transfer tidak punya kategori, jadi diabaikan.
  Set<TxType> categoryTypesOf(Set<String> ids) => {
        for (final t in transactionsByIds(ids))
          if (t.type != TxType.transfer) t.type
      };

  /// Pasang [categoryId] ke transaksi terpilih. Hanya yang jenisnya sama
  /// dengan kategori; transfer dan jenis lain dilewati. Pembagian kategori
  /// (split) diganti jadi satu kategori.
  BulkResult bulkSetCategory(Set<String> ids, String categoryId) {
    final cat = categoryById(categoryId);
    if (cat == null) return BulkResult(0, ids.length);
    var changed = 0;
    var skipped = 0;
    for (var i = 0; i < transactions.length; i++) {
      final t = transactions[i];
      if (!ids.contains(t.id)) continue;
      if (t.type == TxType.transfer || t.type != cat.type) {
        skipped++;
        continue;
      }
      if (t.categoryId == categoryId && t.splits.isEmpty) continue;
      transactions[i] = t.copyWith(categoryId: categoryId, splits: const []);
      changed++;
    }
    if (changed > 0) _commit();
    return BulkResult(changed, skipped);
  }

  /// Pindahkan transaksi terpilih ke [accountId]. Transfer dilewati
  /// (ada dua akun), begitu juga yang mata uang akunnya beda, karena
  /// nominalnya tidak ikut dikonversi.
  BulkResult bulkSetAccount(Set<String> ids, String accountId) {
    final target = accountById(accountId);
    if (target == null) return BulkResult(0, ids.length);
    var changed = 0;
    var skipped = 0;
    for (var i = 0; i < transactions.length; i++) {
      final t = transactions[i];
      if (!ids.contains(t.id)) continue;
      if (t.type == TxType.transfer ||
          currencyOf(t.accountId) != target.currency) {
        skipped++;
        continue;
      }
      if (t.accountId == accountId) continue;
      transactions[i] = t.copyWith(accountId: accountId);
      changed++;
    }
    if (changed > 0) _commit();
    return BulkResult(changed, skipped);
  }

  /// Hapus transaksi terpilih. Mengembalikan yang terhapus (untuk Urungkan).
  List<Transaction> bulkDelete(Set<String> ids) {
    final removed = transactions.where((t) => ids.contains(t.id)).toList();
    if (removed.isEmpty) return removed;
    transactions.removeWhere((t) => ids.contains(t.id));
    _commit();
    return removed;
  }

  void restoreTransactions(List<Transaction> list) {
    var any = false;
    for (final t in list) {
      if (transactions.any((x) => x.id == t.id)) continue;
      transactions.add(t);
      any = true;
    }
    if (any) _commit();
  }

  /// Kembalikan transaksi ke isi sebelumnya (Urungkan ubah kategori/akun).
  void restoreSnapshot(List<Transaction> before) {
    var any = false;
    for (final old in before) {
      final i = transactions.indexWhere((x) => x.id == old.id);
      if (i < 0) continue;
      transactions[i] = old;
      any = true;
    }
    if (any) _commit();
  }
}

/// Bilah di atas Riwayat saat ada transaksi terpilih.
class SelectionBar extends StatelessWidget {
  const SelectionBar({
    super.key,
    required this.count,
    required this.onClose,
    required this.onSelectAll,
    required this.onCategory,
    required this.onAccount,
    required this.onDelete,
  });
  final int count;
  final VoidCallback onClose;
  final VoidCallback onSelectAll;
  final VoidCallback onCategory;
  final VoidCallback onAccount;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    Widget action(IconData icon, String label, VoidCallback tap,
            {Color? color}) =>
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: tap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 22, color: color ?? C.carbon),
                  const SizedBox(height: 2),
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color ?? C.carbon)),
                ],
              ),
            ),
          ),
        );
    return Material(
      color: C.surface,
      elevation: 3,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: tr('Batal pilih'),
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
                Expanded(
                  child: Text(tr('{0} dipilih', [count]),
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 16)),
                ),
                TextButton(onPressed: onSelectAll, child: const Text('Pilih semua')),
              ],
            ),
            Row(
              children: [
                action(Icons.label_rounded, 'Ubah kategori', onCategory),
                action(Icons.account_balance_wallet_rounded, 'Ubah akun',
                    onAccount),
                action(Icons.delete_outline_rounded, 'Hapus', onDelete,
                    color: C.redDark),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Pilih kategori untuk [type]; mengembalikan id kategori.
class BulkCategorySheet extends StatelessWidget {
  const BulkCategorySheet({super.key, required this.store, required this.type, required this.count});
  final AppStore store;
  final TxType type;
  final int count;

  @override
  Widget build(BuildContext context) {
    Widget row(TxCategory c, {bool child = false}) => InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.pop(context, c.id),
          child: Padding(
            padding: EdgeInsets.fromLTRB(child ? 30 : 4, 7, 4, 7),
            child: Row(
              children: [
                CatIcon(
                    icon: c.iconData,
                    art: c.art,
                    color: c.colorValue,
                    size: child ? 30 : 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(c.name,
                      style: TextStyle(
                          fontSize: child ? 13.5 : 14.5,
                          fontWeight: child ? FontWeight.w600 : FontWeight.w800,
                          color: C.carbon)),
                ),
              ],
            ),
          ),
        );
    return SheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('Ubah kategori {0} transaksi', [count]),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
              type == TxType.expense
                  ? 'Pilih kategori pengeluaran.'
                  : 'Pilih kategori pemasukan.',
              style: TextStyle(fontSize: 12.5, color: C.muted)),
          const SizedBox(height: 8),
          for (final c in store.topCategories(type)) ...[
            row(c),
            for (final k in store.childrenOf(c.id)) row(k, child: true),
          ],
        ],
      ),
    );
  }
}

/// Pilih akun tujuan; mengembalikan id akun.
class BulkAccountSheet extends StatelessWidget {
  const BulkAccountSheet({super.key, required this.store, required this.count});
  final AppStore store;
  final int count;

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('Pindahkan {0} transaksi ke akun', [count]),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
              'Transfer dan transaksi beda mata uang tidak ikut dipindah.',
              style: TextStyle(fontSize: 12.5, color: C.muted)),
          const SizedBox(height: 8),
          for (final a in store.accounts)
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.pop(context, a.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  children: [
                    CatIcon(
                        icon: a.type.icon,
                        art: a.type.art,
                        color: a.colorValue,
                        size: 38),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(a.name,
                          style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: C.carbon)),
                    ),
                    Text(a.currency,
                        style: TextStyle(fontSize: 12, color: C.muted)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Snackbar dengan tombol Urungkan, dipakai setelah aksi massal.
void bulkUndoSnack(BuildContext context, String message, VoidCallback onUndo) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    duration: const Duration(seconds: 5),
    persist: false,
    behavior: SnackBarBehavior.floating,
    backgroundColor: C.toast,
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    content: Text(message, style: const TextStyle(color: Colors.white)),
    action: SnackBarAction(
      label: tr('Urungkan'),
      textColor: const Color(0xFF7CFC8A),
      onPressed: onUndo,
    ),
  ));
}

/// Konfirmasi hapus massal. Mengembalikan true kalau user setuju.
Future<bool> confirmBulkDelete(
    BuildContext context, AppStore store, List<Transaction> list) async {
  HapticFeedback.mediumImpact();
  var out = 0.0, inn = 0.0;
  for (final t in list) {
    if (t.type == TxType.expense) out += store.amountIDR(t);
    if (t.type == TxType.income) inn += store.amountIDR(t);
  }
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(tr('Hapus {0} transaksi?', [list.length]),
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19)),
      content: Text(
          [
            if (out > 0) tr('Pengeluaran {0}', [money(out)]),
            if (inn > 0) tr('Pemasukan {0}', [money(inn)]),
            'Saldo akun ikut berubah. Kamu bisa mengurungkannya sebentar setelah ini.',
          ].join('\n'),
          style: TextStyle(color: C.muted, height: 1.4)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: C.redDark),
          child: const Text('Hapus'),
        ),
      ],
    ),
  );
  return r ?? false;
}
