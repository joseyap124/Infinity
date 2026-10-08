part of '../main.dart';

// =============================================================================
// HALAMAN: NOTIFIKASI
// =============================================================================

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key, required this.store});
  final AppStore store;

  Future<void> _pickTime(BuildContext context) async {
    final s = store.settings;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: s.reminderHour, minute: s.reminderMinute),
    );
    if (t == null) return;
    store.updateSettings((x) {
      x.reminderHour = t.hour;
      x.reminderMinute = t.minute;
    });
  }

  Widget _switch(
      {required String title,
      required String subtitle,
      required bool value,
      required ValueChanged<bool>? onChanged}) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 12.5, color: C.muted)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pageBar('Notifikasi'),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final s = store.settings;
          final on = s.notifEnabled;
          final planned = store.plannedNotifications();
          final time = TimeOfDay(hour: s.reminderHour, minute: s.reminderMinute)
              .format(context);
          return ListView(
            padding: pagePad(context, 32),
            children: [
              if (!Notifier.instance.supported)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: ErrorBox(
                      'Notifikasi tidak tersedia di versi ini (misalnya DartPad atau izin belum diberikan).'),
                ),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: _switch(
                  title: 'Aktifkan notifikasi',
                  subtitle: on
                      ? '${planned.length} pengingat terjadwal'
                      : 'Semua pengingat mati',
                  value: on,
                  onChanged: (v) {
                    store.updateSettings((x) => x.notifEnabled = v);
                    if (v) unawaited(Notifier.instance.requestPermission());
                  },
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(
                  children: [
                    _switch(
                      title: 'Sembunyikan nominal',
                      subtitle: 'Notifikasi tidak menampilkan jumlah uang',
                      value: s.notifHideAmounts,
                      onChanged: on
                          ? (v) =>
                              store.updateSettings((x) => x.notifHideAmounts = v)
                          : null,
                    ),
                    _switch(
                      title: 'Transaksi berulang',
                      subtitle:
                          'Sehari sebelum (bulanan/tahunan) dan saat jatuh tempo',
                      value: s.notifRecurring,
                      onChanged: on
                          ? (v) =>
                              store.updateSettings((x) => x.notifRecurring = v)
                          : null,
                    ),
                    _switch(
                      title: 'Tagihan kartu kredit',
                      subtitle: '3 hari sebelum dan saat jatuh tempo',
                      value: s.notifCredit,
                      onChanged: on
                          ? (v) =>
                              store.updateSettings((x) => x.notifCredit = v)
                          : null,
                    ),
                    _switch(
                      title: 'Peringatan anggaran',
                      subtitle: 'Saat status berubah jadi Seret atau Jebol',
                      value: s.notifBudget,
                      onChanged: on
                          ? (v) =>
                              store.updateSettings((x) => x.notifBudget = v)
                          : null,
                    ),
                    _switch(
                      title: 'Utang & piutang',
                      subtitle: 'Sehari sebelum dan saat tenggat',
                      value: s.notifDebt,
                      onChanged: on
                          ? (v) => store.updateSettings((x) => x.notifDebt = v)
                          : null,
                    ),
                    _switch(
                      title: 'Pintasan di panel notifikasi',
                      subtitle:
                          'Ikon Riwayat, Cari, Template, dan Tambah yang selalu ada di panel notifikasi',
                      value: s.quickBar,
                      onChanged: (v) =>
                          store.updateSettings((x) => x.quickBar = v),
                    ),
                    _switch(
                      title: 'Pengingat harian',
                      subtitle: 'Setiap hari jam $time',
                      value: s.dailyReminder,
                      onChanged: on
                          ? (v) =>
                              store.updateSettings((x) => x.dailyReminder = v)
                          : null,
                    ),
                    if (on && s.dailyReminder)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _pickTime(context),
                          icon: const Icon(Icons.schedule_rounded),
                          label: Text('Ubah jam ($time)'),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (on && planned.isNotEmpty)
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('Pengingat terdekat'),
                      const SizedBox(height: 6),
                      for (final n in ([...planned]
                            ..sort((a, b) => a.when.compareTo(b.when)))
                          .take(5))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 92,
                                child: Text(
                                    DateFormat('d MMM HH:mm', 'id_ID')
                                        .format(n.when),
                                    style: TextStyle(
                                        fontSize: 12, color: C.muted)),
                              ),
                              Expanded(
                                child: Text(n.title,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Kirim notifikasi tes',
                icon: Icons.notifications_active_rounded,
                onPressed: on
                    ? () {
                        unawaited(Notifier.instance.showNow(3,
                            '🔔 Notifikasi Infinity aktif',
                            'Pengingat tagihan dan transaksi berulang akan muncul di sini.'));
                        snack(context,
                            'Notifikasi tes dikirim. Kalau tidak muncul, cek izin notifikasi di pengaturan HP.');
                      }
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                  'Catatan: pengingat dijadwalkan ke sistem Android, jadi tetap muncul walau aplikasi ditutup. Beberapa HP (Xiaomi, Oppo, Vivo) membatasi aplikasi di latar belakang. Kalau pengingat tidak muncul, matikan penghemat baterai untuk Infinity.',
                  style: TextStyle(fontSize: 12.5, color: C.muted)),
            ],
          );
        },
      ),
    );
  }
}
