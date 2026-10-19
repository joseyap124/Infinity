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
  Future<void> Function(FormResult r)? onContinue,
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
      onContinue: onContinue,
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
  final r = await showTxForm(context, store,
      draft: draft,
      // Simpan & lanjut: simpan tanpa menutup form.
      onContinue: (r) async {
        if (context.mounted) _commitNewTx(context, store, r, announce: false);
      });
  if (r == null || !context.mounted) return false;
  _commitNewTx(context, store, r, announce: true);
  return true;
}

/// Menyimpan hasil form transaksi baru, termasuk template dan peringatan
/// anggaran. [announce] false kalau form masih terbuka (Simpan & lanjut).
Transaction _commitNewTx(BuildContext context, AppStore store, FormResult r,
    {required bool announce, bool undo = false}) {
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
  // Catat cepat langsung simpan: beri kesempatan membatalkan.
  final action = undo
      ? SnackBarAction(
          label: 'Batalkan',
          onPressed: () => store.deleteTransaction(t.id),
        )
      : null;
  if (t.type == TxType.expense && status == BudgetStatus.broke) {
    snack(
        context,
        tr('{0} Anggaran {1} hampir habis.', [
          tr(BudgetStatus.broke.message),
          tr(store.settings.budgetPeriod.current)
        ]),
        action: action);
  } else if (announce) {
    snack(
        context,
        tr('{0} {1} tercatat ✅',
            [tr(t.type.label), money(t.amount, store.currencyOf(t.accountId))]),
        action: action);
  }
  return t;
}

/// Alasan template tidak bisa disimpan tanpa form (null = bisa langsung).
/// Cermin dari pemeriksaan di form supaya hasilnya sama.
String? _quickSaveProblem(AppStore store, TxTemplate t) {
  if (t.amount <= 0) return 'nominal kosong';
  final acc = store.accountById(t.accountId);
  if (acc == null) return 'akun hilang';
  if (t.type == TxType.transfer) {
    final to = store.accountById(t.toAccountId);
    if (to == null || to.id == acc.id) return 'akun tujuan tidak valid';
    if (to.currency != acc.currency && (t.toAmount ?? 0) <= 0) {
      return 'jumlah diterima kosong';
    }
  } else {
    if (t.categoryId == null || store.categoryById(t.categoryId) == null) {
      return 'kategori hilang';
    }
  }
  if (t.type != TxType.income) {
    final bal = store.balanceOf(acc.id);
    if (acc.type == AccountType.credit) {
      if (acc.creditLimit > 0 && bal - t.amount < -acc.creditLimit - 0.001) {
        return 'melebihi limit';
      }
    } else if (t.amount > bal + 0.001) {
      return 'saldo kurang';
    }
  }
  return null;
}

/// Ketuk template di Catat cepat: langsung tersimpan (tanggal = sekarang) dan
/// muncul tombol Batalkan. Kalau template belum lengkap atau saldo tidak
/// cukup, form dibuka seperti biasa supaya bisa dilengkapi. Mengembalikan
/// true kalau ada transaksi tersimpan.
Future<bool> quickSaveTemplate(
    BuildContext context, AppStore store, TxTemplate t) async {
  if (_quickSaveProblem(store, t) != null) {
    return openTxForm(context, store, template: t);
  }
  final draft = TxDraft.fromTemplate(t);
  if (draft.title.trim().isEmpty) draft.title = _defaultTitle(store, draft);
  HapticFeedback.lightImpact();
  _commitNewTx(context, store, FormResult(draft), announce: true, undo: true);
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
            CatIcon(icon: store.txIcon(t), art: store.txArt(t), color: store.txColor(t), size: 38),
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
                  Text(DateFormat('d MMM yyyy · HH:mm', gDateLoc).format(t.date),
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
          ? tr('Tersimpan. {0} transaksi yang sudah jatuh tempo langsung dicatat.', [created])
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
    {bool showDate = false,
    String? forAccount,
    double? balanceAfter,
    TxSelection? sel}) {
  final selecting = sel?.active ?? false;
  final picked = sel?.ids.contains(t.id) ?? false;
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
      ? DateFormat('d MMM · HH:mm', gDateLoc).format(t.date)
      : DateFormat('HH:mm').format(t.date);

  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Dismissible(
      key: ValueKey('tx_${t.id}'),
      // Saat memilih banyak, geser-untuk-hapus dimatikan supaya tidak terhapus tak sengaja.
      direction:
          selecting ? DismissDirection.none : DismissDirection.endToStart,
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
        color: picked ? C.accent.withValues(alpha: 0.14) : C.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: selecting
              ? () => sel!.toggle(t)
              : () => openTxDetail(context, store, t),
          onLongPress: sel == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  sel.toggle(t);
                },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                if (selecting)
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: picked ? C.accentDark : Colors.transparent,
                      border: Border.all(
                          color: picked ? C.accentDark : C.line, width: 2),
                    ),
                    child: picked
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 24)
                        : null,
                  )
                else
                  CatIcon(icon: store.txIcon(t), art: store.txArt(t), color: store.txColor(t)),
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
                            tr('Saldo {0}', [money(balanceAfter, store.currencyOf(forAccount))]),
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
    BuildContext context, AppStore store, List<Transaction> list,
    {TxSelection? sel}) {
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
      widgets.add(txTile(context, store, t, sel: sel));
    }
  });
  return widgets;
}
