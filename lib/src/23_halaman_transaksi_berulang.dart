part of '../main.dart';

// =============================================================================
// HALAMAN: TRANSAKSI BERULANG
// =============================================================================

class RecurringPage extends StatelessWidget {
  const RecurringPage({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pageBar('Transaksi Berulang'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openRecurringForm(context, store),
        backgroundColor: C.accentDark,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah'),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final rules = [...store.recurring]
            ..sort((a, b) => a.nextDate.compareTo(b.nextDate));
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            children: [
              Text(
                  'Gaji, langganan, cicilan, atau kiriman rutin dicatat otomatis setiap kali aplikasi dibuka dan sudah jatuh tempo.',
                  style: TextStyle(color: C.muted, fontSize: 13)),
              const SizedBox(height: 12),
              if (rules.isEmpty)
                const AppCard(
                    child: EmptyState(
                        icon: Icons.repeat_rounded,
                        title: 'Belum ada transaksi berulang'))
              else
                for (final r in rules)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      onTap: () => openRecurringForm(context, store, rule: r),
                      child: Row(
                        children: [
                          CatIcon(
                              icon: r.type == TxType.transfer
                                  ? Icons.swap_horiz_rounded
                                  : (store.categoryById(r.categoryId)?.iconData ??
                                      Icons.repeat_rounded),
                              color: r.type == TxType.transfer
                                  ? C.blue
                                  : (store
                                          .categoryById(r.categoryId)
                                          ?.colorValue ??
                                      C.muted)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800)),
                                Text(
                                    '${money(r.amount, store.currencyOf(r.accountId))} · ${r.frequency.label}',
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: r.type.color)),
                                Text(
                                    r.active
                                        ? 'Berikutnya ${DateFormat('EEE, d MMM yyyy', 'id_ID').format(r.nextDate)}'
                                        : 'Dijeda',
                                    style: TextStyle(
                                        fontSize: 12, color: C.muted)),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              Switch(
                                value: r.active,
                                activeTrackColor: C.accentDark,
                                onChanged: (v) {
                                  store.toggleRecurring(r.id, v);
                                  if (v) {
                                    final n = store.processRecurring();
                                    if (n > 0) {
                                      snack(context,
                                          '$n transaksi jatuh tempo hari ini langsung dicatat');
                                    }
                                  }
                                },
                              ),
                              IconButton(
                                tooltip: 'Hapus',
                                icon: Icon(Icons.delete_outline_rounded,
                                    color: C.redDark),
                                onPressed: () async {
                                  final ok = await confirmDialog(context,
                                      title: 'Hapus transaksi berulang?',
                                      message:
                                          'Transaksi yang sudah tercatat tetap ada. Hanya jadwal ke depan yang dihapus.',
                                      confirmLabel: 'Hapus',
                                      destructive: true);
                                  if (ok) store.deleteRecurring(r.id);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
