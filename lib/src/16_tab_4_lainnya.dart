part of '../main.dart';

// =============================================================================
// TAB 4: LAINNYA
// =============================================================================

class MoreTab extends StatelessWidget {
  const MoreTab({super.key, required this.store});
  final AppStore store;

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Widget _tile(BuildContext context,
      {required IconData icon,
      required Color color,
      required String title,
      String? subtitle,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            // Satu warna aksen untuk semua menu; merah hanya untuk aksi berbahaya.
            CatIcon(
                icon: icon,
                color: color == C.redDark ? color : C.accentDark,
                size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: color == C.redDark ? C.redDark : null)),
                  if (subtitle != null)
                    Text(subtitle,
                        style: TextStyle(fontSize: 12, color: C.muted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: C.muted),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = store.settings;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const Text('Lainnya',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          AppCard(
            onTap: () => showSheet<void>(context, ProfileSheet(store: store)),
            child: Row(
              children: [
                Avatar(path: s.avatarPath, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.displayName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 16)),
                      Text(
                          s.lastAutoBackup == null
                              ? 'Belum pernah backup'
                              : tr('Backup terakhir {0}', [DateFormat('d MMM, HH.mm', gDateLoc).format(s.lastAutoBackup!)]),
                          style: TextStyle(fontSize: 12, color: C.muted)),
                    ],
                  ),
                ),
                Icon(Icons.edit_rounded, size: 18, color: C.muted),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              children: [
                _tile(context,
                    icon: Icons.settings_rounded,
                    color: C.carbon,
                    title: 'Pengaturan',
                    subtitle:
                        'Tampilan, Beranda, gajian, kurs, catat otomatis, keamanan',
                    onTap: () => _push(context, SettingsPage(store: store))),
                _tile(context,
                    icon: Icons.backup_rounded,
                    color: Colors.indigo,
                    title: 'Backup & pindah HP',
                    subtitle: 'Download, Google Drive, Excel',
                    onTap: () => _push(context, BackupPage(store: store))),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const SmallLabel('Data saya'),
          const SizedBox(height: 6),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              children: [
                _tile(context,
                    icon: Icons.account_balance_wallet_rounded,
                    color: C.blue,
                    title: 'Akun & dompet',
                    subtitle: tr('{0} akun', [store.accounts.length]),
                    onTap: () => _push(context, AccountsPage(store: store))),
                _tile(context,
                    icon: Icons.category_rounded,
                    color: Colors.pink,
                    title: 'Kategori',
                    subtitle: tr('{0} kategori & sub-kategori', [store.categories.length]),
                    onTap: () => _push(context, CategoriesPage(store: store))),
                _tile(context,
                    icon: Icons.bolt_rounded,
                    color: Colors.deepPurple,
                    title: 'Template catat cepat',
                    subtitle: tr('{0} template', [store.templates.length]),
                    onTap: () => _push(context, TemplatesPage(store: store))),
                _tile(context,
                    icon: Icons.repeat_rounded,
                    color: C.accent,
                    title: 'Transaksi berulang',
                    subtitle:
                        tr('{0} aktif', [store.recurring.where((r) => r.active).length]),
                    onTap: () => _push(context, RecurringPage(store: store))),
                _tile(context,
                    icon: Icons.upload_file_rounded,
                    color: Colors.redAccent,
                    title: 'Impor dari Money Manager',
                    subtitle: 'Dari file Excel hasil ekspor',
                    onTap: () => _push(
                        context, MoneyManagerImportPage(store: store))),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const SmallLabel('Alat bantu'),
          const SizedBox(height: 6),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              children: [
                _tile(context,
                    icon: Icons.insights_rounded,
                    color: C.accentDark,
                    title: 'Tinjauan minggu lalu',
                    subtitle: 'Total, hari terbesar, dan tiga temuan',
                    onTap: () => _push(context, WeekReviewPage(store: store))),
                if (store.feature('tunda'))
                  _tile(context,
                      icon: Icons.hourglass_bottom_rounded,
                      color: C.amberDark,
                      title: 'Tunda beli',
                      subtitle: store.waitingItems.isEmpty
                          ? 'Tunggu dulu sebelum membeli yang tidak mendesak'
                          : tr('{0} menunggu', [store.waitingItems.length]),
                      onTap: () => _push(context, WaitlistPage(store: store))),
                if (store.feature('acara'))
                  _tile(context,
                      icon: Icons.local_activity_rounded,
                      color: Colors.purple,
                      title: 'Acara',
                      subtitle: store.events.isEmpty
                          ? 'Mis. trip, Lebaran: total & anggaran per acara'
                          : '${store.events.length} acara',
                      onTap: () => _push(context, EventsPage(store: store))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
                'Anggaran, target tabungan, tagihan, utang & piutang ada di tab Rencana.',
                style: TextStyle(fontSize: 12, color: C.muted)),
          ),
          const SmallLabel('Bantuan'),
          const SizedBox(height: 6),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              children: [
                _tile(context,
                    icon: Icons.help_rounded,
                    color: C.blueDark,
                    title: 'Bantuan',
                    subtitle: 'Pindah HP, catat otomatis, backup, lupa PIN',
                    onTap: () => _push(context, HelpPage(store: store))),
                _tile(context,
                    icon: Icons.health_and_safety_rounded,
                    color: Colors.green,
                    title: 'Cek kesehatan data',
                    subtitle: 'Cari transaksi dobel, kategori hilang, backup lama',
                    onTap: () => _push(context, DataHealthPage(store: store))),
                _tile(context,
                    icon: Icons.bug_report_rounded,
                    color: Colors.blueGrey,
                    title: 'Laporan error',
                    subtitle: ErrorLog.count() == 0
                        ? 'Tidak ada error tercatat'
                        : '${ErrorLog.count()} error tercatat',
                    onTap: () => _push(context, const ErrorLogPage())),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: _tile(context,
                icon: Icons.restart_alt_rounded,
                color: C.redDark,
                title: 'Reset semua data',
                subtitle: 'Mulai dari nol, harus ketik HAPUS dulu',
                onTap: () => confirmResetAll(context, store)),
          ),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Icon(Icons.all_inclusive_rounded, color: C.muted),
                SizedBox(height: 4),
                Text(tr('Infinity v{0} · data tersimpan di perangkat ini', [kAppVersion]),
                    style: TextStyle(fontSize: 12, color: C.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
