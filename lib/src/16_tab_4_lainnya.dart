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
            CatIcon(icon: icon, color: color, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14)),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SmallLabel('Tampilan'),
                const SizedBox(height: 8),
                Segmented<String>(
                  values: const ['system', 'light', 'dark'],
                  selected: s.themeMode,
                  labelOf: (v) => switch (v) {
                    'light' => 'Terang',
                    'dark' => 'Gelap',
                    _ => 'Ikut HP',
                  },
                  dense: true,
                  onChanged: (v) =>
                      store.updateSettings((x) => x.themeMode = v),
                ),
                const SizedBox(height: 14),
                const SizedBox(height: 4),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => showSheet<void>(
                      context, AccentPickerSheet(store: store)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                              color: C.accentDark, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Warna utama',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: C.carbon)),
                              Text(C.accents[s.accentIndex].$1,
                                  style: TextStyle(
                                      fontSize: 12, color: C.muted)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: C.muted),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              children: [
                _tile(context,
                    icon: Icons.account_balance_wallet_rounded,
                    color: C.blue,
                    title: 'Akun & Dompet',
                    subtitle: '${store.accounts.length} akun',
                    onTap: () => _push(context, AccountsPage(store: store))),
                _tile(context,
                    icon: Icons.category_rounded,
                    color: Colors.pink,
                    title: 'Kategori',
                    subtitle: '${store.categories.length} kategori & sub-kategori',
                    onTap: () => _push(context, CategoriesPage(store: store))),
                _tile(context,
                    icon: Icons.track_changes_rounded,
                    color: C.amber,
                    title: 'Anggaran',
                    subtitle: s.globalBudget > 0
                        ? '${s.budgetPeriod.label} · ${money(s.globalBudget)}'
                        : 'Belum diatur',
                    onTap: () => _push(context, BudgetPage(store: store))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              children: [
                _tile(context,
                    icon: Icons.repeat_rounded,
                    color: C.accent,
                    title: 'Transaksi Berulang',
                    subtitle:
                        '${store.recurring.where((r) => r.active).length} aktif',
                    onTap: () => _push(context, RecurringPage(store: store))),
                _tile(context,
                    icon: Icons.handshake_rounded,
                    color: Colors.orange,
                    title: 'Utang & Piutang',
                    subtitle: store.debts.any((d) => !d.settled)
                        ? 'Piutang ${money(store.debtTotal(theyOwe: true))} · Utang ${money(store.debtTotal(theyOwe: false))}'
                        : 'Catat pinjam-meminjam',
                    onTap: () => _push(context, DebtsPage(store: store))),
                _tile(context,
                    icon: Icons.groups_rounded,
                    color: Colors.deepOrange,
                    title: 'Patungan',
                    subtitle: 'Bayar dulu, bagi ke teman jadi piutang',
                    onTap: () => showSheet<void>(
                        context, PatunganSheet(store: store))),
                _tile(context,
                    icon: Icons.local_activity_rounded,
                    color: Colors.purple,
                    title: 'Acara',
                    subtitle: store.events.isEmpty
                        ? 'Mis. trip, Lebaran: total & anggaran per acara'
                        : '${store.events.length} acara',
                    onTap: () => _push(context, EventsPage(store: store))),
                _tile(context,
                    icon: Icons.savings_rounded,
                    color: Colors.teal,
                    title: 'Target Tabungan',
                    subtitle: store.goals.isEmpty
                        ? 'Mis. dana darurat, liburan'
                        : '${store.goals.length} target',
                    onTap: () => _push(context, GoalsPage(store: store))),
                _tile(context,
                    icon: Icons.bolt_rounded,
                    color: Colors.deepPurple,
                    title: 'Template Catat Cepat',
                    subtitle: '${store.templates.length} template',
                    onTap: () => _push(context, TemplatesPage(store: store))),
                _tile(context,
                    icon: Icons.currency_exchange_rounded,
                    color: Colors.teal,
                    title: 'Mata Uang & Kurs',
                    subtitle: 'Konversi ke Rupiah',
                    onTap: () => _push(context, CurrencyPage(store: store))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              children: [
                _tile(context,
                    icon: Icons.auto_awesome_rounded,
                    color: Colors.deepOrange,
                    title: 'Catat Otomatis',
                    subtitle: switch (s.captureMode) {
                      'off' => 'Mati',
                      'ask' => 'Tanya dulu',
                      _ => 'Langsung catat dari notifikasi bank/e-wallet',
                    },
                    onTap: () =>
                        _push(context, AutoCapturePage(store: store))),
                _tile(context,
                    icon: Icons.notifications_rounded,
                    color: C.amber,
                    title: 'Notifikasi',
                    subtitle: s.notifEnabled ? 'Aktif' : 'Nonaktif',
                    onTap: () =>
                        _push(context, NotificationsPage(store: store))),
                _tile(context,
                    icon: Icons.lock_rounded,
                    color: C.carbon,
                    title: 'Keamanan',
                    subtitle: s.pin == null
                        ? 'PIN nonaktif'
                        : (s.biometric ? 'PIN + sidik jari aktif' : 'PIN aktif'),
                    onTap: () => _push(context, SecurityPage(store: store))),
                _tile(context,
                    icon: Icons.backup_rounded,
                    color: Colors.indigo,
                    title: 'Backup & Pulihkan',
                    subtitle: 'Ekspor/impor data JSON',
                    onTap: () => _push(context, BackupPage(store: store))),
                _tile(context,
                    icon: Icons.upload_file_rounded,
                    color: Colors.redAccent,
                    title: 'Import dari Money Manager',
                    subtitle: 'Dari file Excel hasil ekspor',
                    onTap: () => _push(
                        context, MoneyManagerImportPage(store: store))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              children: [
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
                title: 'Reset Semua Data',
                subtitle: 'Mulai dari nol, harus ketik HAPUS dulu',
                onTap: () => confirmResetAll(context, store)),
          ),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Icon(Icons.all_inclusive_rounded, color: C.muted),
                SizedBox(height: 4),
                Text('Infinity v$kAppVersion · data tersimpan di perangkat ini',
                    style: TextStyle(fontSize: 12, color: C.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
