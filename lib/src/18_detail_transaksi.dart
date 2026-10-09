part of '../main.dart';

// =============================================================================
// DETAIL TRANSAKSI
// =============================================================================

class TransactionDetailSheet extends StatelessWidget {
  const TransactionDetailSheet(
      {super.key, required this.store, required this.transaction});

  final AppStore store;
  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final cur = store.currencyOf(t.accountId);
    final sign =
        t.type == TxType.expense ? '-' : (t.type == TxType.income ? '+' : '');

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: Text(label,
                    style: TextStyle(color: C.muted, fontSize: 13)),
              ),
              Expanded(
                child: Text(value,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ],
          ),
        );

    return SheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
              child: CatIcon(
                  icon: store.txIcon(t), color: store.txColor(t), size: 64)),
          const SizedBox(height: 12),
          Text(t.title,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('$sign${money(t.amount, cur)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: t.type.color)),
          if (cur != 'IDR')
            Text('≈ ${money(store.amountIDR(t))}',
                textAlign: TextAlign.center,
                style: TextStyle(color: C.muted)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
                color: C.bg, borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                row('Tipe', t.type.label),
                if (t.splits.isEmpty)
                  row('Kategori', store.categoryLabel(t))
                else
                  for (final sp in t.splits)
                    row(store.categoryById(sp.categoryId)?.name ?? 'Tanpa kategori',
                        money(sp.amount, cur)),
                if (t.type == TxType.transfer) ...[
                  row('Dari Akun', store.accountName(t.accountId)),
                  row('Ke Akun', store.accountName(t.toAccountId)),
                  if (t.toAmount != null)
                    row('Diterima',
                        money(t.receivedAmount, store.currencyOf(t.toAccountId))),
                ] else
                  row('Akun', store.accountName(t.accountId)),
                row('Tanggal',
                    DateFormat('EEEE, d MMM yyyy · HH:mm', 'id_ID')
                        .format(t.date)),
                if (t.recurringId != null) row('Sumber', 'Transaksi berulang'),
                if (t.note.isNotEmpty) row('Catatan', t.note),
                if (t.photos.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final p in t.photos) ReceiptThumb(name: p, size: 72),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pop(_DetailAction.duplicate),
                  icon: const Icon(Icons.library_add_rounded),
                  label: const Text('Duplikat'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pop(_DetailAction.copy),
                  icon: const Icon(Icons.content_copy_rounded),
                  label: const Text('Salin teks'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(_DetailAction.edit),
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Edit'),
            style: FilledButton.styleFrom(
              backgroundColor: C.accentDark,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(_DetailAction.delete),
            icon: const Icon(Icons.delete_rounded),
            label: const Text('Hapus Transaksi',
                style: TextStyle(fontWeight: FontWeight.w800)),
            style: OutlinedButton.styleFrom(
              foregroundColor: C.redDark,
              side: BorderSide(color: C.redDark, width: 1.5),
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
          ),
          const SizedBox(height: 6),
          Text('Tip: geser item ke kiri di riwayat untuk hapus cepat.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: C.muted)),
        ],
      ),
    );
  }
}
