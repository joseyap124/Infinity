part of '../main.dart';

// =============================================================================
// GOLONGAN PENGELUARAN (v3.6): kebutuhan, keinginan, tabungan, dst.
// Murni statistik: tidak mengatur atau membatasi apa pun.
// =============================================================================

enum SpendKind { need, want, save, grow, duty, other }

extension SpendKindX on SpendKind {
  String get label {
    switch (this) {
      case SpendKind.need:
        return 'Kebutuhan';
      case SpendKind.want:
        return 'Keinginan';
      case SpendKind.save:
        return 'Tabungan';
      case SpendKind.grow:
        return 'Investasi diri';
      case SpendKind.duty:
        return 'Kewajiban';
      case SpendKind.other:
        return 'Belum digolongkan';
    }
  }

  Color get color {
    switch (this) {
      case SpendKind.need:
        return const Color(0xFF3949AB);
      case SpendKind.want:
        return const Color(0xFFEF6C00);
      case SpendKind.save:
        return const Color(0xFF0A7D12);
      case SpendKind.grow:
        return const Color(0xFF00897B);
      case SpendKind.duty:
        return const Color(0xFF8E24AA);
      case SpendKind.other:
        return const Color(0xFF90A4AE);
    }
  }
}

SpendKind? spendKindFromName(String? name) {
  if (name == null) return null;
  for (final k in SpendKind.values) {
    if (k.name == name) return k;
  }
  return null;
}

/// Golongan bawaan per kategori. Kategori anak mengikuti induknya kalau tidak
/// disebut sendiri. Kategori buatan sendiri tanpa induk yang dikenal masuk
/// "Belum digolongkan" sampai diatur.
const Map<String, SpendKind> kDefaultKinds = {
  'pokok': SpendKind.need,
  'sehat': SpendKind.need,
  'olahraga': SpendKind.grow,
  'edu': SpendKind.grow,
  'legal': SpendKind.need,
  'sosial': SpendKind.want,
  'donasi': SpendKind.duty,
  'hiburan': SpendKind.want,
  'invest_out': SpendKind.save,
  'cicilan': SpendKind.duty,
  'darurat': SpendKind.need,
  'lain': SpendKind.other,
  'admin': SpendKind.need,
};

extension SpendKindStore on AppStore {
  /// Golongan sebuah kategori: pilihan user (kategori, lalu induknya), lalu
  /// bawaan (kategori, lalu induknya).
  SpendKind kindOf(String? catId) {
    if (catId == null) return SpendKind.other;
    final parent = categoryById(catId)?.parentId;
    final ov = settings.spendKinds;
    return spendKindFromName(ov[catId]) ??
        (parent == null ? null : spendKindFromName(ov[parent])) ??
        kDefaultKinds[catId] ??
        (parent == null ? null : kDefaultKinds[parent]) ??
        SpendKind.other;
  }

  /// Ubah golongan satu kategori. [kind] null = kembali ke bawaan.
  void setSpendKind(String catId, SpendKind? kind) {
    updateSettings((x) {
      if (kind == null) {
        x.spendKinds.remove(catId);
      } else {
        x.spendKinds[catId] = kind.name;
      }
    });
  }

  /// Total pengeluaran (Rupiah) per golongan di sebuah periode. Belanja yang
  /// dibagi ke beberapa kategori dihitung per bagiannya. Transfer ke akun yang
  /// tidak ikut "Aman dibelanjakan" (tabungan, dana darurat) dari akun yang
  /// ikut dihitung sebagai Tabungan.
  Map<SpendKind, double> spendByKind(DateTimeRange r) {
    final m = <SpendKind, double>{};
    for (final t in transactions) {
      if (!inRange(t.date, r)) continue;
      if (t.type == TxType.expense) {
        for (final (cid, v) in categoryParts(t)) {
          final k = kindOf(cid);
          m[k] = (m[k] ?? 0) + v;
        }
      } else if (t.type == TxType.transfer) {
        final from = accountById(t.accountId);
        final to = accountById(t.toAccountId);
        if (from != null && to != null && to.excludeSafe && !from.excludeSafe) {
          m[SpendKind.save] = (m[SpendKind.save] ?? 0) + amountIDR(t);
        }
      }
    }
    return m;
  }
}

class SpendKindCard extends StatelessWidget {
  const SpendKindCard(
      {super.key, required this.store, required this.range, required this.prev});
  final AppStore store;
  final DateTimeRange range;
  final DateTimeRange prev;

  @override
  Widget build(BuildContext context) {
    final now = store.spendByKind(range);
    final before = store.spendByKind(prev);
    final income = store.sumIDR(TxType.income, range);
    final incomeBefore = store.sumIDR(TxType.income, prev);
    final spent = now.values.fold(0.0, (a, b) => a + b);
    if (spent <= 0) return const SizedBox.shrink();
    final spentBefore = before.values.fold(0.0, (a, b) => a + b);
    final byIncome = income > 0;
    final base = byIncome ? income : spent;
    final baseBefore = incomeBefore > 0 ? incomeBefore : spentBefore;
    final kinds = SpendKind.values.where((k) => (now[k] ?? 0) > 0).toList();
    final total = math.max(base, spent);
    final left = byIncome && income > spent ? income - spent : 0.0;

    String delta(SpendKind k) {
      if (baseBefore <= 0 || (before[k] ?? 0) <= 0) return '';
      final d = (now[k]! / base * 100) - (before[k]! / baseBefore * 100);
      if (d.abs() < 0.5) return 'sama seperti periode lalu';
      return '${d > 0 ? 'naik' : 'turun'} ${d.abs().toStringAsFixed(0)} poin dari periode lalu';
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Kebutuhan, keinginan, tabungan',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: C.carbon)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SpendKindsPage(store: store))),
                child: const Text('Atur golongan'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 14,
              child: Row(
                children: [
                  for (final k in kinds)
                    Expanded(
                        flex: math.max(1, (now[k]! / total * 1000).round()),
                        child: Container(color: k.color)),
                  if (left > 0)
                    Expanded(
                        flex: math.max(1, (left / total * 1000).round()),
                        child: Container(color: C.line)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (final k in kinds)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(top: 5, right: 8),
                      decoration:
                          BoxDecoration(color: k.color, shape: BoxShape.circle)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(k.label,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        if (delta(k).isNotEmpty)
                          Text(delta(k),
                              style: TextStyle(fontSize: 11.5, color: C.muted)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(money(now[k]!),
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 14)),
                      Text('${(now[k]! / base * 100).toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 12, color: C.muted)),
                    ],
                  ),
                ],
              ),
            ),
          if (left > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(right: 8),
                      decoration:
                          BoxDecoration(color: C.line, shape: BoxShape.circle)),
                  const Expanded(
                      child: Text('Sisa (belum dipakai)',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14))),
                  Text(money(left),
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 14)),
                  const SizedBox(width: 8),
                  Text('${(left / base * 100).toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 12, color: C.muted)),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Text(
              byIncome
                  ? 'Persen dari pemasukan periode ini. Transfer ke akun yang tidak ikut Aman dibelanjakan dihitung sebagai tabungan. Setoran Target belum dihitung.'
                  : 'Belum ada pemasukan di periode ini, jadi persen dihitung dari total pengeluaran.',
              style: TextStyle(fontSize: 11.5, color: C.muted)),
        ],
      ),
    );
  }
}

/// Atur golongan tiap kategori pengeluaran.
class SpendKindsPage extends StatelessWidget {
  const SpendKindsPage({super.key, required this.store});
  final AppStore store;

  Future<void> _pick(BuildContext context, TxCategory c) async {
    final cur = store.kindOf(c.id);
    final hasOverride = store.settings.spendKinds.containsKey(c.id);
    final picked = await showDialog<Object>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(c.name),
        children: [
          for (final k in SpendKind.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, k),
              child: Row(
                children: [
                  Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(right: 10),
                      decoration:
                          BoxDecoration(color: k.color, shape: BoxShape.circle)),
                  Expanded(
                      child: Text(k.label,
                          style: TextStyle(
                              fontWeight: k == cur
                                  ? FontWeight.w900
                                  : FontWeight.w500))),
                  if (k == cur) const Icon(Icons.check_rounded, size: 18),
                ],
              ),
            ),
          if (hasOverride)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'reset'),
              child: const Text('Kembalikan ke bawaan'),
            ),
        ],
      ),
    );
    if (picked is SpendKind) {
      store.setSpendKind(c.id, picked);
    } else if (picked == 'reset') {
      store.setSpendKind(c.id, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pageBar('Golongan pengeluaran'),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final cats =
              store.categories.where((c) => c.type == TxType.expense).toList();
          final tops = cats.where((c) => c.parentId == null).toList();
          Widget tile(TxCategory c, {bool child = false}) {
            final k = store.kindOf(c.id);
            return ListTile(
              contentPadding: EdgeInsets.only(left: child ? 36 : 16, right: 16),
              dense: child,
              title: Text(c.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: child ? FontWeight.w500 : FontWeight.w800)),
              trailing: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: k.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12)),
                child: Text(k.label,
                    style: TextStyle(
                        color: k.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ),
              onTap: () => _pick(context, c),
            );
          }

          return ListView(
            padding: EdgeInsets.only(
                bottom: MediaQuery.viewPaddingOf(context).bottom + 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                    'Hanya untuk statistik. Ketuk kategori untuk mengubah golongannya. Kategori anak mengikuti induknya kalau tidak diubah sendiri.',
                    style: TextStyle(fontSize: 12.5, color: C.muted)),
              ),
              for (final top in tops) ...[
                tile(top),
                for (final c in cats.where((c) => c.parentId == top.id))
                  tile(c, child: true),
              ],
            ],
          );
        },
      ),
    );
  }
}
