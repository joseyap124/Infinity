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
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
          children: [
            Text(
                'Untuk pengeluaran yang sering diulang. Ketuk template untuk mencatat (nominal, tanggal, dan jam masih bisa diubah sebelum simpan). Ketuk ✏️ untuk mengubah templatenya.',
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
                        IconButton(
                          tooltip: 'Edit template',
                          icon: Icon(Icons.edit_outlined, color: C.muted),
                          onPressed: () =>
                              openTemplateForm(context, store, existing: t),
                        ),
                        IconButton(
                          tooltip: 'Hapus template',
                          icon: Icon(Icons.delete_outline_rounded,
                              color: C.redDark),
                          onPressed: () => store.deleteTemplate(t.id),
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
