part of '../main.dart';

// Maskot Infinity dengan 6 suasana (v5.0) dan cincin sisa jatah hari ini.
// Gambarnya digambar dengan kode (tanpa file gambar) dari kanvas 176x162,
// sama dengan papan mockup maskot.

enum MascotMood { happy, ok, warn, danger, over, sleepy }

/// Maskot yang dipilih user: 'classic' | 'owl' | 'fox' | 'crow' | 'custom'.
final ValueNotifier<String> gMascotSkin = ValueNotifier<String>('classic');

/// Lokasi gambar maskot pilihan sendiri (skin 'custom').
final ValueNotifier<String?> gMascotCustom = ValueNotifier<String?>(null);

/// Nama berkas gambar maskot bawaan: assets/mascots/<skin>_<mood>.png
String mascotAsset(String skin, MascotMood mood) =>
    'assets/mascots/${skin}_${mood.name}.png';

const List<String> kMascotSkins = ['auto', 'classic', 'owl', 'fox', 'crow', 'custom'];

/// Maskot yang dipasangkan dengan tiap paket gaya (pilihan "Ikut paket").
const Map<String, String> kPackSkin = {
  'malam': 'owl',
  'kuning': 'fox',
  'merah': 'crow',
};

/// Maskot yang benar-benar dipakai: "Ikut paket" diterjemahkan ke maskot
/// paket gaya aktif (Klasik kalau paketnya Klasik).
String effectiveMascotSkin(AppSettings s) =>
    s.mascotSkin == 'auto' ? (kPackSkin[s.stylePack] ?? 'classic') : s.mascotSkin;

/// Kalimat maskot menurut nada paket. Urutan: senang, aman, hati-hati, bahaya,
/// boros, ngantuk. Paket Klasik (atau nada dimatikan) memakai kalimat netral.
String mascotLine(MascotMood m, {String pack = 'classic'}) {
  switch (pack) {
    case 'malam':
      return switch (m) {
        MascotMood.happy => tr('Malam ini tenang. Jatahmu masih lega.'),
        MascotMood.ok => tr('Pelan saja, semuanya masih terjaga.'),
        MascotMood.warn => tr('Mulai menipis. Pikir dulu sebelum membeli.'),
        MascotMood.danger => tr('Sisa sedikit. Bertahanlah sampai pagi.'),
        MascotMood.over => tr('Sudah lewat batas. Besok kita mulai lagi.'),
        MascotMood.sleepy => tr('Sudah lama sunyi. Ada yang belum dicatat?'),
      };
    case 'kuning':
      return switch (m) {
        MascotMood.happy => tr('Yeay, jatah masih banyak!'),
        MascotMood.ok => tr('Aman jaya, lanjut semangat!'),
        MascotMood.warn => tr('Eits, pelan-pelan ya belanjanya.'),
        MascotMood.danger => tr('Wah tinggal sedikit! Hemat dulu yuk.'),
        MascotMood.over => tr('Hari ini lewat jatah. Tercatat, besok mulai lagi ya.'),
        MascotMood.sleepy => tr('Halo? Belum ada catatan nih.'),
      };
    case 'merah':
      return switch (m) {
        MascotMood.happy => tr('Longgar. Jangan keburu senang.'),
        MascotMood.ok => tr('Terkendali. Pertahankan.'),
        MascotMood.warn => tr('Rem sedikit. Itu tidak perlu.'),
        MascotMood.danger => tr('Hampir habis. Pikir dulu sebelum belanja.'),
        MascotMood.over => tr('Lewat jatah. Hitung ulang.'),
        MascotMood.sleepy => tr('Kamu menghilang. Catat yang kemarin.'),
      };
  }
  return switch (m) {
    MascotMood.happy => tr('Keuangan aman terkendali.'),
    MascotMood.ok => tr('Pengeluaran masih wajar.'),
    MascotMood.warn => tr('Jatah hari ini mulai menipis.'),
    MascotMood.danger => tr('Jatah hari ini hampir habis.'),
    MascotMood.over => tr('Sudah lewat jatah hari ini.'),
    MascotMood.sleepy => tr('Belum mencatat. Ketuk untuk mulai.'),
  };
}

/// Warna alas lingkaran maskot. Burung hantu bulunya gelap, jadi alasnya biru es.
Color mascotBase(String skin) =>
    skin == 'owl' ? const Color(0xFFDCEEFF) : Colors.white;

extension MascotMoodText on MascotMood {
  String get label => switch (this) {
        MascotMood.happy => 'Senang',
        MascotMood.ok => 'Aman',
        MascotMood.warn => 'Hati-hati',
        MascotMood.danger => 'Bahaya',
        MascotMood.over => 'Boros',
        MascotMood.sleepy => 'Ngantuk',
      };

  Color get ringColor => switch (this) {
        MascotMood.happy || MascotMood.ok => C.income,
        MascotMood.warn => C.amberDark,
        MascotMood.danger || MascotMood.over => C.redDark,
        MascotMood.sleepy => C.muted,
      };
}

/// Hari tanpa catatan yang membuat maskot mengantuk.
const int kSleepyDays = 3;

/// Suasana maskot dari sisa jatah hari ini. Batas sisa jatah:
/// 80% ke atas Senang, 50 sampai kurang dari 80 Aman, 30 sampai kurang dari
/// 50 Hati-hati, 0 sampai kurang dari 30 Bahaya, di bawah 0 Boros.
/// Belum mencatat apa pun [kSleepyDays] hari terakhir: Ngantuk (mengalahkan yang lain).
MascotMood mascotMoodFor(
    {required double leftToday,
    required double perDay,
    required DateTime? lastTx,
    required DateTime now,
    required bool hasAccounts}) {
  if (hasAccounts &&
      (lastTx == null || now.difference(lastTx).inDays >= kSleepyDays)) {
    return MascotMood.sleepy;
  }
  if (leftToday < 0) return MascotMood.over;
  final ratio = perDay > 0 ? leftToday / perDay : 0.0;
  if (ratio >= 0.8) return MascotMood.happy;
  if (ratio >= 0.5) return MascotMood.ok;
  if (ratio >= 0.3) return MascotMood.warn;
  return MascotMood.danger;
}

/// Tanggal transaksi terakhir (tidak termasuk yang terjadwal di masa depan).
DateTime? lastTransactionDate(AppStore store, DateTime now) {
  DateTime? last;
  for (final t in store.transactions) {
    if (t.date.isAfter(now)) continue;
    if (last == null || t.date.isAfter(last)) last = t.date;
  }
  return last;
}

class MascotPainter extends CustomPainter {
  MascotPainter(this.mood);
  final MascotMood mood;

  static const _ink = Color(0xFF1F1B3A);
  static const _y = 126.0;
  static const _drop = Color(0xFF6BC7F2);

  Paint _stroke(Color c, double w) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = c;
  Paint _fill(Color c) => Paint()
    ..style = PaintingStyle.fill
    ..color = c;

  void _eye(Canvas c, double cx,
      {double dx = 0, double dy = 0, double rp = 6, double rw = 13}) {
    c.drawCircle(Offset(cx, _y), rw, _fill(Colors.white));
    c.drawCircle(Offset(cx, _y), rw, _stroke(_ink, 3));
    c.drawCircle(Offset(cx + dx, _y + dy), rp, _fill(_ink));
    c.drawCircle(Offset(cx + dx + 2, _y + dy - 2), 2, _fill(Colors.white));
  }

  void _lid(Canvas c, double cx, double yLeft, double yRight,
      {double rw = 13}) {
    final p = Path()
      ..moveTo(cx - rw - 1, _y - rw - 2)
      ..lineTo(cx + rw + 1, _y - rw - 2)
      ..lineTo(cx + rw + 1, yRight)
      ..lineTo(cx - rw - 1, yLeft)
      ..close();
    c.drawPath(p, _fill(_ink));
  }

  void _dropAt(Canvas c, double x, double top) {
    final p = Path()
      ..moveTo(x, top)
      ..quadraticBezierTo(x + 7, top + 12, x, top + 19)
      ..quadraticBezierTo(x - 7, top + 12, x, top);
    c.drawPath(p, _fill(_drop));
    c.drawPath(p, _stroke(_ink, 2.5));
  }

  void _tear(Canvas c, double x) {
    final p = Path()
      ..moveTo(x, _y + 12)
      ..quadraticBezierTo(x + 7, _y + 25, x, _y + 34)
      ..quadraticBezierTo(x - 7, _y + 25, x, _y + 12);
    c.drawPath(p, _fill(_drop));
    c.drawPath(p, _stroke(_ink, 2.5));
  }

  void _text(Canvas c, String t, Offset center, double size, Color color,
      {double opacity = 1}) {
    final tp = TextPainter(
      text: TextSpan(
          text: t,
          style: TextStyle(
              color: color.withValues(alpha: opacity),
              fontSize: size,
              fontWeight: FontWeight.w900)),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const vb = Rect.fromLTWH(40, 30, 176, 162);
    final k = math.min(size.width / vb.width, size.height / vb.height);
    canvas.save();
    canvas.translate(
        (size.width - vb.width * k) / 2, (size.height - vb.height * k) / 2);
    canvas.scale(k);
    canvas.translate(-vb.left, -vb.top);

    final rib = Path()
      ..moveTo(60, 128)
      ..cubicTo(60, 72, 104, 72, 128, 128)
      ..cubicTo(152, 184, 196, 184, 196, 128)
      ..cubicTo(196, 72, 152, 72, 128, 128)
      ..cubicTo(104, 184, 60, 184, 60, 128)
      ..close();
    canvas.drawPath(rib, _stroke(_ink, 18));

    switch (mood) {
      case MascotMood.happy:
        for (final x in const [94.0, 162.0]) {
          final p = Path()
            ..moveTo(x - 12, _y + 4)
            ..quadraticBezierTo(x, _y - 16, x + 12, _y + 4);
          canvas.drawPath(p, _stroke(_ink, 6));
        }
        canvas.drawCircle(const Offset(80, 146), 6, _fill(const Color(0xFFF4A6B0)));
        canvas.drawCircle(const Offset(176, 146), 6, _fill(const Color(0xFFF4A6B0)));
        final star = Path()
          ..moveTo(128, 36)
          ..lineTo(133, 47)
          ..lineTo(144, 52)
          ..lineTo(133, 57)
          ..lineTo(128, 68)
          ..lineTo(123, 57)
          ..lineTo(112, 52)
          ..lineTo(123, 47)
          ..close();
        canvas.drawPath(star, _fill(const Color(0xFFF2B90F)));
      case MascotMood.ok:
        _eye(canvas, 94, dx: 1, dy: 1);
        _eye(canvas, 162, dx: 1, dy: 1);
      case MascotMood.warn:
        _eye(canvas, 94, dx: 4, dy: 2, rp: 5);
        _eye(canvas, 162, dx: -4, dy: 2, rp: 5);
        _lid(canvas, 94, _y - 6, _y - 12);
        _lid(canvas, 162, _y - 12, _y - 6);
        _dropAt(canvas, 204, 84);
      case MascotMood.danger:
        _eye(canvas, 94, rp: 3, rw: 15);
        _eye(canvas, 162, rp: 3, rw: 15);
        _dropAt(canvas, 58, 92);
        _dropAt(canvas, 198, 92);
        _text(canvas, '!', const Offset(128, 48), 30, const Color(0xFFB91C2B));
      case MascotMood.over:
        // Menangis: mata "> <" dan dua aliran air mata.
        final sad = _stroke(_ink, 5);
        canvas.drawPath(
            Path()
              ..moveTo(84, _y - 9)
              ..lineTo(100, _y)
              ..lineTo(84, _y + 9),
            sad);
        canvas.drawPath(
            Path()
              ..moveTo(172, _y - 9)
              ..lineTo(156, _y)
              ..lineTo(172, _y + 9),
            sad);
        _tear(canvas, 92);
        _tear(canvas, 164);
      case MascotMood.sleepy:
        for (final x in const [94.0, 162.0]) {
          _eye(canvas, x, dy: 5, rp: 5);
          final lid = Path()
            ..moveTo(x - 14, _y - 1)
            ..arcTo(Rect.fromCircle(center: Offset(x, _y - 1), radius: 14),
                math.pi, math.pi, false)
            ..close();
          canvas.drawPath(lid, _fill(_ink));
        }
        _text(canvas, 'z', const Offset(194, 72), 24, _ink, opacity: 0.8);
        _text(canvas, 'z', const Offset(210, 52), 17, _ink, opacity: 0.6);
    }

    canvas.drawCircle(const Offset(196, 128), 20, _fill(const Color(0xFFF2B90F)));
    canvas.drawCircle(const Offset(196, 128), 20, _stroke(_ink, 5));
    _text(canvas, 'Rp', const Offset(196, 128), 17, _ink);
    canvas.restore();
  }

  @override
  bool shouldRepaint(MascotPainter old) => old.mood != mood;
}

class MascotView extends StatelessWidget {
  const MascotView({super.key, required this.mood, this.size = 80});
  final MascotMood mood;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tr('Maskot Infinity: {0}', [tr(mood.label)]),
      child: ExcludeSemantics(
        child: ListenableBuilder(
          listenable: Listenable.merge([gMascotSkin, gMascotCustom]),
          builder: (context, _) =>
              mascotImage(gMascotSkin.value, mood, size, gMascotCustom.value),
        ),
      ),
    );
  }
}

/// Gambar maskot sesuai pilihan; kalau berkasnya hilang kembali ke maskot klasik.
Widget mascotImage(String skin, MascotMood mood, double size, String? custom) {
  Widget classic() => SizedBox(
        width: size,
        height: size * 0.92,
        child: CustomPaint(painter: MascotPainter(mood)),
      );
  if (skin == 'owl' || skin == 'fox' || skin == 'crow') {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(mascotAsset(skin, mood),
          fit: BoxFit.contain,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => classic()),
    );
  }
  if (skin == 'custom' && custom != null) {
    final f = File(custom);
    if (f.existsSync()) {
      return SizedBox(
        width: size,
        height: size,
        child: ClipOval(
          child: Image.file(f,
              key: ValueKey(custom),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => classic()),
        ),
      );
    }
  }
  return classic();
}

/// Cincin sisa jatah dengan maskot di tengahnya (atas alas putih supaya
/// pita gelap maskot tetap terbaca di mode gelap).
class MascotRing extends StatelessWidget {
  const MascotRing(
      {super.key,
      required this.mood,
      required this.progress,
      this.size = 132,
      this.stroke = 12});
  final MascotMood mood;
  final double progress;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final inner = size - stroke * 2 - 8;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
                progress.clamp(0.0, 1.0).toDouble(),
                mood.ringColor,
                C.isDark ? const Color(0xFF2E343C) : const Color(0xFFE3EDE4),
                stroke),
          ),
          ValueListenableBuilder<String>(
            valueListenable: gMascotSkin,
            builder: (context, skin, _) => Container(
              width: inner,
              height: inner,
              decoration: BoxDecoration(
                  color: mascotBase(skin), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: MascotView(mood: mood, size: inner * 0.84),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.color, this.track, this.width);
  final double progress;
  final Color color;
  final Color track;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(width / 2, width / 2, size.width - width,
        size.height - width);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, math.pi * 2, false, base..color = track);
    if (progress > 0) {
      canvas.drawArc(r, -math.pi / 2, math.pi * 2 * progress, false,
          base..color = color);
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) =>
      o.progress != progress || o.color != color || o.track != track;
}
