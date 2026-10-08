part of '../main.dart';

// =============================================================================
// NOTIFIKASI
// =============================================================================

class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.when,
    required this.title,
    required this.body,
    this.daily = false,
  });

  final int id;
  final DateTime when;
  final String title;
  final String body;

  /// true = diulang setiap hari di jam yang sama.
  final bool daily;
}

// NOTIF-IMPL-BEGIN
/// Pembungkus flutter_local_notifications (v22). Notifikasi dijadwalkan ke
/// sistem Android, jadi tetap muncul walau aplikasi ditutup.
class Notifier {
  Notifier._();
  static final Notifier instance = Notifier._();

  final fln.FlutterLocalNotificationsPlugin _plugin =
      fln.FlutterLocalNotificationsPlugin();
  bool _ready = false;

  bool get supported => _ready;

  static const fln.NotificationDetails _details = fln.NotificationDetails(
    android: fln.AndroidNotificationDetails(
      'infinity_reminder',
      'Pengingat Infinity',
      channelDescription:
          'Pengingat tagihan, transaksi berulang, anggaran, dan catatan harian',
      importance: fln.Importance.high,
      priority: fln.Priority.high,
      // Di layar kunci isi notifikasi disembunyikan (ikut setelan privasi HP).
      visibility: fln.NotificationVisibility.private,
    ),
  );

  /// Tombol di notifikasi pintasan: 'qb_quick' | 'qb_add' | 'qb_history'.
  final StreamController<QuickAction> _actions =
      StreamController<QuickAction>.broadcast();
  Stream<QuickAction> get actions => _actions.stream;

  static const int quickBarId = 900001;

  Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        settings: const fln.InitializationSettings(
          android: fln.AndroidInitializationSettings('@drawable/ic_stat_infinity'),
        ),
        onDidReceiveNotificationResponse: (fln.NotificationResponse r) {
          final a = r.actionId;
          if (a != null && a.startsWith('qb_')) {
            _actions.add(QuickAction(a, r.input));
          }
        },
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  /// Tombol pintasan yang membuka app dari kondisi tertutup.
  Future<QuickAction?> launchAction() async {
    if (!_ready) return null;
    try {
      final d = await _plugin.getNotificationAppLaunchDetails();
      if (d == null || !d.didNotificationLaunchApp) return null;
      final r = d.notificationResponse;
      final a = r?.actionId;
      return (a != null && a.startsWith('qb_'))
          ? QuickAction(a, r?.input)
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> showQuickBar() async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: quickBarId,
        title: 'Infinity',
        body: 'Ketik "25rb kopi" di ＋ Pengeluaran, langsung tercatat',
        notificationDetails: const fln.NotificationDetails(
          android: fln.AndroidNotificationDetails(
            'infinity_quickbar',
            'Pintasan Infinity',
            channelDescription: 'Tombol catat cepat di panel notifikasi',
            importance: fln.Importance.low,
            priority: fln.Priority.low,
            ongoing: true,
            autoCancel: false,
            showWhen: false,
            onlyAlertOnce: true,
            playSound: false,
            enableVibration: false,
            visibility: fln.NotificationVisibility.public,
            actions: <fln.AndroidNotificationAction>[
              fln.AndroidNotificationAction('qb_quick', '＋ Pengeluaran',
                  showsUserInterface: true,
                  cancelNotification: false,
                  inputs: <fln.AndroidNotificationActionInput>[
                    fln.AndroidNotificationActionInput(
                        label: 'Contoh: 25rb kopi'),
                  ]),
              fln.AndroidNotificationAction('qb_add', 'Form',
                  showsUserInterface: true, cancelNotification: false),
              fln.AndroidNotificationAction('qb_history', 'Riwayat',
                  showsUserInterface: true, cancelNotification: false),
            ],
          ),
        ),
      );
    } catch (_) {}
  }

  Future<void> hideQuickBar() async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: quickBarId);
    } catch (_) {}
  }

  Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          fln.AndroidFlutterLocalNotificationsPlugin>();
      return (await android?.requestNotificationsPermission()) ?? true;
    } catch (_) {
      return false;
    }
  }

  Future<void> showNow(int id, String title, String body) async {
    if (!_ready) return;
    try {
      await _plugin.show(
          id: id, title: title, body: body, notificationDetails: _details);
    } catch (_) {}
  }

  /// Hapus semua jadwal lama lalu pasang jadwal baru.
  Future<void> replaceSchedule(List<PlannedNotification> items) async {
    if (!_ready) return;
    try {
      await _plugin.cancelAllPendingNotifications();
      for (final n in items) {
        await _plugin.zonedSchedule(
          id: n.id,
          title: n.title,
          body: n.body,
          // Waktu absolut (UTC) supaya tepat di zona waktu mana pun
          // (WIB/WITA/WIT) tanpa package zona waktu tambahan.
          scheduledDate: tz.TZDateTime.from(n.when.toUtc(), tz.UTC),
          notificationDetails: _details,
          // Inexact: tidak butuh izin "alarm tepat waktu", meleset beberapa menit.
          androidScheduleMode: fln.AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents:
              n.daily ? fln.DateTimeComponents.time : null,
        );
      }
    } catch (_) {}
  }
}
// NOTIF-IMPL-END

/// Tombol yang ditekan di notifikasi pintasan, plus teks yang diketik.
class QuickAction {
  const QuickAction(this.id, [this.input]);
  final String id;
  final String? input;
}

class QuickInput {
  const QuickInput(this.amount, this.title);
  final double amount;
  final String title;
}

/// "25rb kopi", "kopi 25.000", "1,5jt hp", "15000 parkir" -> nominal + judul.
QuickInput? parseQuickInput(String text) {
  // Satuan ribu: rb, rbu, rebu, ribu, ribuan, rban, k. Juta: jt, jta, juta.
  final m = RegExp(
          r'(\d+(?:[.,]\d+)*)\s*(?:(rb\w*|r[ie]bu\w*|rib\w*|k|jt\w*|jut\w*)(?![a-z]))?',
          caseSensitive: false)
      .firstMatch(text);
  if (m == null) return null;
  final numStr = m.group(1)!;
  final suf = (m.group(2) ?? '').toLowerCase();
  double? v;
  if (suf.isEmpty) {
    v = double.tryParse(numStr.replaceAll(RegExp(r'[.,]'), ''));
    // Rupiah di bawah 1.000 hampir tidak pernah dipakai: "25 nasgor" = 25rb.
    if (v != null && v > 0 && v < 1000) v = v * 1000;
  } else {
    final n = RegExp(r'^\d+[.,]\d{1,2}$').hasMatch(numStr)
        ? numStr.replaceAll(',', '.')
        : numStr.replaceAll(RegExp(r'[.,]'), '');
    final base = double.tryParse(n);
    if (base != null) {
      v = base * (suf.startsWith('j') ? 1000000 : 1000);
    }
  }
  if (v == null || v <= 0) return null;
  var title = '${text.substring(0, m.start)} ${text.substring(m.end)}'
      .replaceAll(RegExp(r'\brp\.?', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (title.isNotEmpty) title = title[0].toUpperCase() + title.substring(1);
  return QuickInput(v.roundToDouble(), title);
}
