part of '../main.dart';

// =============================================================================
// HALAMAN: TEMPLATE
// =============================================================================

class TemplatesPage extends StatelessWidget {
  const TemplatesPage({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pageBar('Template Catat Cepat'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openTemplateForm(context, store),
        backgroundColor: C.accentDark,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Template baru'),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(
          padding: pagePad(context, 100),
          children: [
            Text(
                'Untuk pengeluaran yang sering diulang. Ketuk template untuk mencatat (nominal, tanggal, dan jam masih bisa diubah sebelum simpan). Ketuk ⋮ untuk mengubah atau menghapus template.',
                style: TextStyle(color: C.muted, fontSize: 13)),
            const SizedBox(height: 12),
            if (store.templates.isEmpty)
              const AppCard(
                  child: EmptyState(
                      icon: Icons.bolt_rounded, title: 'Belum ada template'))
            else
              for (final t in store.templates)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    onTap: () => openTxForm(context, store, template: t),
                    child: Row(
                      children: [
                        CatIcon(
                            icon: t.type == TxType.transfer
                                ? Icons.swap_horiz_rounded
                                : (store.categoryById(t.categoryId)?.iconData ??
                                    Icons.bolt_rounded),
                            color: t.type == TxType.transfer
                                ? C.blue
                                : (store.categoryById(t.categoryId)?.colorValue ??
                                    C.muted)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                              Text(
                                  '${t.type.label} · ${store.accountName(t.accountId)}',
                                  style: TextStyle(
                                      fontSize: 12, color: C.muted)),
                            ],
                          ),
                        ),
                        Text(money(t.amount, store.currencyOf(t.accountId)),
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: t.type.color)),
                        PopupMenuButton<String>(
                          tooltip: 'Pilihan',
                          icon: Icon(Icons.more_vert_rounded, color: C.muted),
                          onSelected: (v) async {
                            if (v == 'edit') {
                              openTemplateForm(context, store, existing: t);
                            } else if (v == 'hapus') {
                              final ok = await confirmDialog(context,
                                  title: 'Hapus template?',
                                  message: 'Template "${t.title}" akan dihapus. Transaksi yang sudah dicatat tidak ikut terhapus.',
                                  confirmLabel: 'Hapus',
                                  destructive: true);
                              if (ok) store.deleteTemplate(t.id);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                                value: 'edit',
                                child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(Icons.edit_outlined),
                                    title: Text('Edit'))),
                            PopupMenuItem(
                                value: 'hapus',
                                child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(Icons.delete_outline_rounded,
                                        color: C.redDark),
                                    title: Text('Hapus',
                                        style: TextStyle(color: C.redDark)))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
