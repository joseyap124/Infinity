part of '../main.dart';

// =============================================================================
// CEK KESEHATAN DATA
// Mencari hal yang bisa membuat angka meleset: kategori hilang, kemungkinan
// transaksi dobel, saldo minus yang tidak wajar, talangan patungan tidak
// cocok, backup lama, dll.
// =============================================================================

enum HealthLevel { ok, info, warn }

class HealthIssue {
  const HealthIssue(this.level, this.title, this.detail,
      {this.fixLabel, this.fix, this.items = const []});
  final HealthLevel level;
  final String title;
  final String detail;
  final String? fixLabel;
  final void Function()? fix;

  /// Contoh transaksi yang bermasalah (untuk ditampilkan).
  final List<Transaction> items;
}

extension DataHealth on AppStore {
  /// Pasangan transaksi yang kemungkinan dobel: tipe, akun, nominal, dan
  /// catatan sama, selisih waktu maksimal 2 menit.
  List<(Transaction, Transaction)> possibleDuplicates() {
    final sorted = [...transactions]..sort((a, b) => a.date.compareTo(b.date));
    final out = <(Transaction, Transaction)>[];
    for (var i = 0; i < sorted.length; i++) {
      final a = sorted[i];
      for (var j = i + 1; j < sorted.length; j++) {
        final b = sorted[j];
        if (b.date.difference(a.date).inMinutes > 2) break;
        if (a.type == b.type &&
            a.accountId == b.accountId &&
            a.toAccountId == b.toAccountId &&
            (a.amount - b.amount).abs() < 0.005 &&
            a.title.trim().toLowerCase() == b.title.trim().toLowerCase()) {
          out.add((a, b));
        }
      }
    }
    return out;
  }

  List<HealthIssue> healthCheck(DateTime now) {
    final out = <HealthIssue>[];

    // 1. Kategori yang sudah dihapus.
    final lostCat = transactions
        .where((t) =>
            t.type != TxType.transfer &&
            ((t.categoryId != null && categoryById(t.categoryId) == null) ||
                t.splits.any((s) => categoryById(s.categoryId) == null)))
        .toList();
    if (lostCat.isNotEmpty) {
      out.add(HealthIssue(
        HealthLevel.warn,
        '${lostCat.length} transaksi kategorinya sudah dihapus',
        'Transaksi ini tidak masuk statistik kategori mana pun.',
        fixLabel: 'Pindah ke kategori lain-lain',
        fix: () => _reassignLostCategories(),
        items: lostCat.take(5).toList(),
      ));
    }

    // 2. Kemungkinan dobel.
    final dups = possibleDuplicates();
    if (dups.isNotEmpty) {
      out.add(HealthIssue(
        HealthLevel.warn,
        '${dups.length} kemungkinan transaksi dobel',
        'Tipe, akun, nominal, dan catatan sama dalam selang 2 menit. Cek di Riwayat; kalau memang dobel, hapus salah satunya.',
        items: [for (final (_, b) in dups.take(5)) b],
      ));
    }

    // 3. Saldo minus di akun yang biasanya tidak bisa minus.
    for (final a in accounts) {
      if (a.type == AccountType.credit) continue;
      final bal = balanceOf(a.id);
      if (bal < -0.5) {
        out.add(HealthIssue(
          HealthLevel.warn,
          'Saldo ${a.name} minus ${money(-bal, a.currency)}',
          a.id == kTalanganId
              ? 'Pembayaran patungan yang diterima lebih besar dari talangan. Cek catatan patungan.'
              : 'Kemungkinan ada pemasukan yang belum dicatat, atau saldo awal kurang. Samakan lewat edit akun kalau perlu.',
        ));
      }
    }

    // 4. Talangan patungan vs piutang yang belum lunas.
    final hold = accountById(kTalanganId);
    if (hold != null) {
      final owed = debts
          .where((d) => d.holdAccountId == kTalanganId && !d.settled)
          .fold(0.0, (s, d) => s + d.remaining);
      final bal = balanceOf(kTalanganId);
      if ((bal - owed).abs() >= 1) {
        out.add(HealthIssue(
          HealthLevel.info,
          'Talangan Patungan ${money(bal)}, piutang patungan ${money(owed)}',
          'Biasanya sama. Beda kalau ada piutang patungan yang dihapus/diedit, atau transaksi talangan diubah manual.',
        ));
      }
    }

    // 5. Transaksi jauh di masa depan.
    final future = transactions
        .where((t) => t.date.isAfter(now.add(const Duration(days: 31))))
        .toList();
    if (future.isNotEmpty) {
      out.add(HealthIssue(
        HealthLevel.info,
        '${future.length} transaksi bertanggal lebih dari sebulan ke depan',
        'Mungkin salah pilih tahun/bulan saat mencatat.',
        items: future.take(5).toList(),
      ));
    }

    // 6. Backup.
    final last = settings.lastAutoBackup;
    if (transactions.isNotEmpty &&
        (last == null || now.difference(last).inDays > 14)) {
      out.add(HealthIssue(
        HealthLevel.warn,
        last == null
            ? 'Belum pernah backup'
            : 'Backup terakhir ${now.difference(last).inDays} hari lalu',
        'Buka Backup & Pulihkan lalu tekan Backup sekarang. Simpan juga salinannya ke Google Drive.',
      ));
    }
    // 7. Salinan di luar HP (Google Drive dll).
    final drive = settings.lastDriveSave;
    if (transactions.isNotEmpty &&
        (drive == null || now.difference(drive).inDays > 7)) {
      out.add(HealthIssue(
        HealthLevel.info,
        drive == null
            ? 'Belum pernah simpan backup ke Google Drive'
            : 'Simpan ke Google Drive terakhir ${now.difference(drive).inDays} hari lalu',
        'Backup di Download/Infinity ikut hilang kalau HP hilang atau rusak. Buka Backup & Pulihkan lalu Simpan backup ke Drive.',
      ));
    }

    // 8. Notifikasi "Perlu dicek".
    if (settings.droppedCaptures > 0) {
      out.add(HealthIssue(
        HealthLevel.warn,
        '${settings.droppedCaptures} notifikasi lama terbuang',
        'Antrean "Perlu dicek" sempat penuh ($kMaxPendingCaptures). Cocokkan saldo dengan app bank kalau ada yang terlewat.',
        fixLabel: 'Sudah dicek',
        fix: () => updateSettings((x) => x.droppedCaptures = 0),
      ));
    } else if (pendingCaptures.length >= kMaxPendingCaptures - 60) {
      out.add(HealthIssue(
        HealthLevel.warn,
        '${pendingCaptures.length} notifikasi menunggu dicek',
        'Batasnya $kMaxPendingCaptures; kalau lewat, yang paling lama terbuang.',
      ));
    }

    // 9. Penyimpanan.
    if (!lastSaveOk) {
      out.add(const HealthIssue(
        HealthLevel.warn,
        'Perubahan terakhir gagal disimpan',
        'Buat backup sekarang dan kirim isi Laporan error. Jangan hapus app.',
      ));
    }
    return out;
  }

  void _reassignLostCategories() {
    bool lost(String? c) => c != null && categoryById(c) == null;
    transactions = [
      for (final t in transactions)
        if (t.type == TxType.transfer)
          t
        else if (lost(t.categoryId) || t.splits.any((s) => lost(s.categoryId)))
          t.copyWith(
            categoryId: lost(t.categoryId)
                ? fallbackCategory(t.type)
                : t.categoryId,
            splits: [
              for (final s in t.splits)
                lost(s.categoryId)
                    ? TxSplit(fallbackCategory(t.type) ?? s.categoryId, s.amount)
                    : s
            ],
          )
        else
          t
    ];
    _commit();
  }
}

class DataHealthPage extends StatelessWidget {
  const DataHealthPage({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final now = DateTime.now();
        final issues = store.healthCheck(now);
        final oldest = store.transactions.isEmpty
            ? null
            : store.transactions
                .map((t) => t.date)
                .reduce((a, b) => a.isBefore(b) ? a : b);
        return Scaffold(
          appBar: pageBar('Cek kesehatan data'),
          body: ListView(
            padding: pagePad(context, 32),
            children: [
              AppCard(
                child: Row(
                  children: [
                    Icon(
                        issues.isEmpty
                            ? Icons.verified_rounded
                            : Icons.health_and_safety_rounded,
                        size: 36,
                        color: issues.isEmpty ? C.income : C.amberDark),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              issues.isEmpty
                                  ? 'Data sehat 👍'
                                  : '${issues.length} hal perlu dicek',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 16)),
                          Text(
                              '${store.transactions.length} transaksi · ${store.accounts.length} akun'
                              '${oldest == null ? '' : ' · sejak ${DateFormat('MMM yyyy', 'id_ID').format(oldest)}'}',
                              style: TextStyle(fontSize: 12.5, color: C.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              for (final i in issues)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                                i.level == HealthLevel.warn
                                    ? Icons.warning_amber_rounded
                                    : Icons.info_outline_rounded,
                                color: i.level == HealthLevel.warn
                                    ? C.amberDark
                                    : C.blueDark),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(i.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(i.detail,
                            style: TextStyle(fontSize: 12.5, color: C.muted)),
                        for (final t in i.items)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                                '• ${DateFormat('d MMM yyyy HH:mm', 'id_ID').format(t.date)} · ${t.title} · ${money(t.amount, store.currencyOf(t.accountId))}',
                                style: const TextStyle(fontSize: 12)),
                          ),
                        if (i.fix != null) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton(
                              onPressed: () {
                                i.fix!();
                                snack(context, 'Diperbaiki ✅');
                              },
                              style: FilledButton.styleFrom(
                                  backgroundColor: C.accentDark),
                              child: Text(i.fixLabel ?? 'Perbaiki'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              Text(
                  'Cek ini hanya membaca data; tidak ada yang diubah kecuali kamu menekan tombol perbaikan.',
                  style: TextStyle(fontSize: 12, color: C.muted)),
            ],
          ),
        );
      },
    );
  }
}
