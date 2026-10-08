part of '../main.dart';

// =============================================================================
// AKSI TRANSAKSI (dipakai banyak layar)
// =============================================================================

String _defaultTitle(AppStore store, TxDraft d) {
  if (d.type == TxType.transfer) {
    return 'Transfer ke ${store.accountName(d.toAccountId)}';
  }
  return store.categoryById(d.categoryId)?.name ?? d.type.label;
}

Future<FormResult?> showTxForm(
  BuildContext context,
  AppStore store, {
  required TxDraft draft,
  FormMode mode = FormMode.transaction,
  String? excludeTxId,
  bool isEditing = false,
  Frequency? frequency,
}) {
  return showSheet<FormResult>(
    context,
    TxFormSheet(
      store: store,
      draft: draft,
      mode: mode,
      excludeTxId: excludeTxId,
      isEditing: isEditing,
      frequency: frequency,
    ),
  );
}

/// Mengembalikan true kalau transaksi disimpan.
Future<bool> openTxForm(
  BuildContext context,
  AppStore store, {
  TxType type = TxType.expense,
  TxTemplate? template,
  TxDraft? prefill,
  bool keepPrefillDate = false,
  String? toAccountId,
  double? amount,
}) async {
  TxDraft draft;
  if (prefill != null) {
    if (!keepPrefillDate) prefill.date = DateTime.now();
    draft = prefill;
  } else if (template != null) {
    draft = TxDraft.fromTemplate(template);
  } else {
    var from = store.defaultAccountId;
    if (toAccountId != null && from == toAccountId) {
      from = store.accounts
          .firstWhere(
              (a) => a.id != toAccountId && a.type != AccountType.credit,
              orElse: () => store.accounts.first)
          .id;
    }
    draft = TxDraft(
        type: type,
        accountId: from,
        toAccountId: toAccountId,
        amount: amount ?? 0);
  }
  final r = await showTxForm(context, store, draft: draft);
  if (r == null || !context.mounted) return false;
  final before = store.budgetStatusNow();
  final t = r.draft.toTransaction(store.newId());
  store.upsertTransaction(t);
  if (r.saveAsTemplate) store.addTemplate(r.draft.toTemplate(store.newId()));

  final status = store.budgetStatusNow();
  final st = store.settings;
  if (t.type == TxType.expense &&
      st.notifEnabled &&
      st.notifBudget &&
      status != null &&
      status != BudgetStatus.safe &&
      status != before) {
    final spent =
        store.sumIDR(TxType.expense, st.budgetPeriod.range(DateTime.now()));
    unawaited(Notifier.instance.showNow(
        2,
        'Anggaran ${st.budgetPeriod.current}: ${status.message}',
        st.notifHideAmounts
            ? 'Buka Infinity untuk lihat sisa anggaran.'
            : 'Sisa ${money(st.globalBudget - spent)} dari ${money(st.globalBudget)}.'));
  }
  if (t.type == TxType.expense && status == BudgetStatus.broke) {
    snack(context,
        '${BudgetStatus.broke.message} Anggaran ${store.settings.budgetPeriod.current} hampir habis.');
  } else {
    snack(context,
        '${t.type.label} ${money(t.amount, store.currencyOf(t.accountId))} tercatat ✅');
  }
  return true;
}

Future<void> editTx(BuildContext context, AppStore store, Transaction t) async {
  final r = await showTxForm(context, store,
      draft: TxDraft.fromTransaction(t), excludeTxId: t.id, isEditing: true);
  if (r == null || !context.mounted) return;
  store.upsertTransaction(
      r.draft.toTransaction(t.id, recurringId: t.recurringId));
  snack(context, 'Transaksi diperbarui ✏️');
}

String _txAmountText(AppStore store, Transaction t) {
  final m = money(t.amount, store.currencyOf(t.accountId));
  return switch (t.type) {
    TxType.expense => '-$m',
    TxType.income => '+$m',
    TxType.transfer => m,
  };
}

/// Konfirmasi sebelum menghapus (geser sering tidak sengaja).
Future<bool> confirmDeleteTx(
    BuildContext context, AppStore store, Transaction t) async {
  HapticFeedback.mediumImpact();
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      icon: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
            color: C.redDark.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: Icon(Icons.delete_outline_rounded, color: C.redDark, size: 28),
      ),
      title: const Text('Hapus transaksi ini?',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19)),
      content: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: C.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: C.line),
        ),
        child: Row(
          children: [
            CatIcon(icon: store.txIcon(t), color: store.txColor(t), size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w800, color: C.carbon)),
                  Text(DateFormat('d MMM yyyy · HH:mm', 'id_ID').format(t.date),
                      style: TextStyle(fontSize: 12, color: C.muted)),
                ],
              ),
            ),
            Text(_txAmountText(store, t),
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: t.type.color,
                    fontSize: 13)),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18))),
                child: const Text('Batal'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                    backgroundColor: C.redDark,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18))),
                child: const Text('Hapus',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return r ?? false;
}

void deleteWithUndo(BuildContext context, AppStore store, Transaction t) {
  final removed = store.deleteTransaction(t.id);
  if (removed == null) return;
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    duration: const Duration(seconds: 3),
    persist: false,
    behavior: SnackBarBehavior.floating,
    backgroundColor: C.toast,
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    content: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle),
          child: const Icon(Icons.delete_outline_rounded,
              color: Colors.white, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Transaksi dihapus',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14)),
              Text('${t.title} · ${_txAmountText(store, t)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      ],
    ),
    action: SnackBarAction(
      label: 'Urungkan',
      textColor: const Color(0xFF7CFC8A),
      onPressed: () => store.restoreTransaction(removed),
    ),
  ));
}

enum _DetailAction { edit, duplicate, copy, delete }

Future<void> openTxDetail(
    BuildContext context, AppStore store, Transaction t) async {
  final action = await showSheet<_DetailAction>(
      context, TransactionDetailSheet(store: store, transaction: t));
  if (action == null || !context.mounted) return;
  switch (action) {
    case _DetailAction.edit:
      await editTx(context, store, t);
    case _DetailAction.duplicate:
      await openTxForm(context, store,
          prefill: TxDraft.fromTransaction(t)..photos = []);
    case _DetailAction.copy:
      await Clipboard.setData(ClipboardData(text: txShareText(store, t)));
      if (context.mounted) snack(context, 'Teks transaksi disalin 📋');
    case _DetailAction.delete:
      if (await confirmDeleteTx(context, store, t) && context.mounted) {
        deleteWithUndo(context, store, t);
      }
  }
}

Future<void> openRecurringForm(BuildContext context, AppStore store,
    {RecurringRule? rule}) async {
  final draft = rule == null
      ? TxDraft(
          type: TxType.expense,
          accountId: store.defaultAccountId,
          date: DateTime.now())
      : TxDraft(
          type: rule.type,
          title: rule.title,
          amount: rule.amount,
          toAmount: rule.toAmount,
          categoryId: rule.categoryId,
          accountId: rule.accountId,
          toAccountId: rule.toAccountId,
          note: rule.note,
          date: rule.nextDate);
  final r = await showTxForm(context, store,
      draft: draft,
      mode: FormMode.recurring,
      frequency: rule?.frequency ?? Frequency.monthly,
      isEditing: rule != null);
  if (r == null || !context.mounted) return;
  final d = r.draft;
  store.upsertRecurring(RecurringRule(
    id: rule?.id ?? store.newId(),
    title: d.title,
    amount: d.amount,
    toAmount: d.type == TxType.transfer ? d.toAmount : null,
    type: d.type,
    categoryId: d.type == TxType.transfer ? null : d.categoryId,
    accountId: d.accountId,
    toAccountId: d.type == TxType.transfer ? d.toAccountId : null,
    note: d.note,
    frequency: r.frequency ?? Frequency.monthly,
    start: d.date,
    active: rule?.active ?? true,
  ));
  final created = store.processRecurring();
  snack(
      context,
      created > 0
          ? 'Tersimpan. $created transaksi yang sudah jatuh tempo langsung dicatat.'
          : 'Transaksi berulang tersimpan 🔁');
}

/// Template baru, atau edit template [existing] tanpa membuat yang baru.
Future<void> openTemplateForm(BuildContext context, AppStore store,
    {TxTemplate? existing}) async {
  final r = await showTxForm(context, store,
      draft: existing != null
          ? TxDraft.fromTemplate(existing)
          : TxDraft(type: TxType.expense, accountId: store.defaultAccountId),
      mode: FormMode.template,
      isEditing: existing != null);
  if (r == null || !context.mounted) return;
  if (existing != null) {
    store.updateTemplate(r.draft.toTemplate(existing.id));
    snack(context, 'Template diperbarui ⚡');
  } else {
    store.addTemplate(r.draft.toTemplate(store.newId()));
    snack(context, 'Template tersimpan ⚡');
  }
}

/// Baris transaksi gaya Gojek + swipe kiri untuk hapus.
/// [forAccount]: tampilkan nominal dari sisi akun itu (transfer keluar
/// minus, transfer masuk plus). [balanceAfter]: saldo akun setelah transaksi.
Widget txTile(BuildContext context, AppStore store, Transaction t,
    {bool showDate = false, String? forAccount, double? balanceAfter}) {
  final cur = store.currencyOf(t.accountId);
  String amountText;
  Color amountColor;
  switch (t.type) {
    case TxType.expense:
      amountText = '-${money(t.amount, cur)}';
      amountColor = C.redDark;
    case TxType.income:
      amountText = '+${money(t.amount, cur)}';
      amountColor = C.income;
    case TxType.transfer:
      amountText = money(t.amount, cur);
      amountColor = C.blueDark;
  }
  if (forAccount != null && t.type == TxType.transfer) {
    amountText = t.toAccountId == forAccount
        ? '+${money(t.receivedAmount, store.currencyOf(forAccount))}'
        : '-${money(t.amount, cur)}';
  }
  final accountText = t.type == TxType.transfer
      ? '${store.accountName(t.accountId)} → ${store.accountName(t.toAccountId)}'
      : store.accountName(t.accountId);
  final when = showDate
      ? DateFormat('d MMM · HH:mm', 'id_ID').format(t.date)
      : DateFormat('HH:mm').format(t.date);

  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Dismissible(
      key: ValueKey('tx_${t.id}'),
      direction: DismissDirection.endToStart,
      // Harus digeser cukup jauh, lalu tetap dikonfirmasi.
      dismissThresholds: const {DismissDirection.endToStart: 0.45},
      confirmDismiss: (_) => confirmDeleteTx(context, store, t),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            C.redDark.withValues(alpha: 0.15),
            C.redDark,
          ]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  shape: BoxShape.circle),
              child: const Icon(Icons.delete_outline_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(height: 2),
            const Text('Hapus',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12)),
          ],
        ),
      ),
      onDismissed: (_) => deleteWithUndo(context, store, t),
      child: Material(
        color: C.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => openTxDetail(context, store, t),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CatIcon(icon: store.txIcon(t), color: store.txColor(t)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(t.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: C.carbon)),
                          ),
                          if (t.recurringId != null) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.repeat_rounded,
                                size: 14, color: C.muted),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text('$accountText · $when',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(fontSize: 12, color: C.muted)),
                      if (t.note.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('“${t.note}”',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  fontStyle: FontStyle.italic,
                                  color: C.muted)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(amountText,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: amountColor)),
                    if (balanceAfter != null && forAccount != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                            'Saldo ${money(balanceAfter, store.currencyOf(forAccount))}',
                            style: TextStyle(fontSize: 11, color: C.muted)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Daftar transaksi dikelompokkan per hari (dengan net harian dalam IDR).
List<Widget> groupedTxWidgets(
    BuildContext context, AppStore store, List<Transaction> list) {
  final sorted = [...list]..sort((a, b) => b.date.compareTo(a.date));
  final groups = <DateTime, List<Transaction>>{};
  for (final t in sorted) {
    groups.putIfAbsent(dayOnly(t.date), () => []).add(t);
  }
  final widgets = <Widget>[];
  groups.forEach((day, items) {
    var net = 0.0;
    for (final t in items) {
      if (t.type == TxType.income) net += store.amountIDR(t);
      if (t.type == TxType.expense) net -= store.amountIDR(t);
    }
    widgets.add(Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(dayLabel(day),
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800, color: C.muted)),
          ),
          Text(net > 0 ? '+${money(net)}' : money(net),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: net > 0
                      ? C.income
                      : (net < 0 ? C.redDark : C.muted))),
        ],
      ),
    ));
    for (final t in items) {
      widgets.add(txTile(context, store, t));
    }
  });
  return widgets;
}
