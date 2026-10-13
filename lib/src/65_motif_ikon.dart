part of '../main.dart';

// =============================================================================
// Gaya (v5.4): motif latar (kabut, awan, lampu, langit malam) dan ikon
// kategori serta menu bawah per gaya. Semuanya digambar dengan kode, jadi tetap
// offline dan tidak menambah ukuran aplikasi.
// =============================================================================

typedef _Op2 = (String, bool); // (jalur SVG, tertutup/berisi?)

/// Bentuk ikon di kanvas 64x64. Yang tertutup boleh diisi warna.
final Map<String, List<_Op2>> _kGlyphs = {
  'home': [('M12 28L32 10L52 28V54H12Z', true), ('M26 54V38H38V54', false)],
  'food': [
    ('M44 8c-6 0-8 8-8 14s3 8 8 8s8-2 8-8s-2-14-8-14z', true),
    ('M44 30V56', false),
    ('M14 8V22q0 6 6 6q6 0 6-6V8', false),
    ('M20 8V56', false),
  ],
  'car': [
    ('M8 38L14 24Q16 20 20 20H44Q48 20 50 24L56 38V50H8Z', true),
    ('M12 38H52', false),
    (_circ(20, 50, 6), true),
    (_circ(44, 50, 6), true),
  ],
  'bill': [
    ('M18 8h28v46l-5-4-4.5 4-4.5-4-4.5 4-4.5-4-5 4z', true),
    ('M25 20h14M25 28h14M25 36h9', false),
  ],
  'receipt': [
    ('M18 8h28v46l-5-4-4.5 4-4.5-4-4.5 4-4.5-4-5 4z', true),
    ('M25 20h14M25 28h14M25 36h9', false),
  ],
  'health': [('M24 8H40V24H56V40H40V56H24V40H8V24H24Z', true)],
  'pill': [
    ('M18 38L38 18a9 9 0 0 1 13 13L31 51a9 9 0 0 1-13-13Z', true),
    ('M28 28L41 41', false),
  ],
  'care': [
    ('M26 8H38V22H26Z', true),
    ('M20 22H44V56H20Z', true),
    ('M20 36H44', false),
  ],
  'sport': [
    ('M4 24H12V40H4Z', true),
    ('M12 28H52V36H12Z', true),
    ('M52 24H60V40H52Z', true),
  ],
  'school': [
    ('M32 12L58 26L32 40L6 26Z', true),
    ('M16 33V46Q32 56 48 46V33', false),
  ],
  'travel': [
    (
      'M32 6c3 0 4 3 4 6v14l22 14v6L36 40v10l8 6v4L32 56L20 60v-4l8-6V40L6 46v-6l22-14V12c0-3 1-6 4-6Z',
      true
    ),
  ],
  'phone': [
    ('M20 6H44Q48 6 48 10V54Q48 58 44 58H20Q16 58 16 54V10Q16 6 20 6Z', true),
    ('M28 50H36', false),
  ],
  'gift': [
    ('M10 28H54V56H10Z', true),
    ('M8 18H56V28H8Z', true),
    ('M32 18V56', false),
    ('M32 18C20 18 18 6 26 6C32 6 32 14 32 18C32 14 32 6 38 6C46 6 44 18 32 18Z',
        true),
  ],
  'charity': [
    ('M32 52C10 38 8 22 18 16C25 12 30 16 32 21C34 16 39 12 46 16C56 22 54 38 32 52Z',
        true),
  ],
  'bag': [
    ('M12 22H52L56 56H8Z', true),
    ('M22 22V16a10 10 0 0 1 20 0V22', false),
  ],
  'movie': [
    ('M6 16H58V27a5 5 0 0 0 0 10V48H6V37a5 5 0 0 0 0-10Z', true),
    ('M40 20V44', false),
  ],
  'coffee': [
    ('M10 22H46V40Q46 54 28 54Q10 54 10 40Z', true),
    ('M46 26H52Q58 26 58 33Q58 40 52 40H46', false),
    ('M20 8Q16 12 20 16M30 8Q26 12 30 16', false),
  ],
  'invest': [
    ('M8 52L24 34L34 42L56 14M44 14H56V26', false),
    ('M8 58H56', false),
  ],
  'card': [
    ('M6 14H58V50H6Z', true),
    ('M6 26H58M14 40H28', false),
  ],
  'sos': [
    (_circ(32, 32, 26), true),
    (_circ(32, 32, 10), true),
    ('M14 14L24 24M50 14L40 24M14 50L24 40M50 50L40 40', false),
  ],
  'other': [
    (_circ(12, 32, 5), true),
    (_circ(32, 32, 5), true),
    (_circ(52, 32, 5), true),
  ],
  'bank': [
    ('M6 22L32 8L58 22Z', true),
    ('M12 28H20V48H12Z', true),
    ('M28 28H36V48H28Z', true),
    ('M44 28H52V48H44Z', true),
    ('M6 52H58V58H6Z', true),
  ],
  'salary': [
    ('M6 18H58V46H6Z', true),
    (_circ(32, 32, 8), true),
  ],
  'grid': [
    ('M8 8H28V28H8Z', true),
    ('M36 8H56V28H36Z', true),
    ('M8 36H28V56H8Z', true),
    ('M36 36H56V56H36Z', true),
  ],
  'pie': [
    ('M32 8A24 24 0 1 0 56 32H32Z', true),
    ('M36 4A24 24 0 0 1 60 28H36Z', true),
  ],
  'target': [
    (_circ(32, 32, 24), true),
    (_circ(32, 32, 14), true),
    (_circ(32, 32, 3), true),
  ],
};

/// Nama lain untuk kunci gambar yang bentuknya sama.
const Map<String, String> _kGlyphAlias = {
  'dompet': 'salary',
  'cash': 'salary',
  'saving': 'invest',
  'kartu_home': 'card',
};

/// Kunci bentuk untuk sebuah ikon, atau null kalau tidak ada bentuk bertema
/// (ikon itu tetap tampil seperti biasa).
String? packGlyphKey(String? art, IconData icon) {
  final k = art ?? kFnArt[icon.codePoint];
  if (k == null) return null;
  if (_kGlyphs.containsKey(k)) return k;
  return _kGlyphAlias[k];
}

class _GlyphTilePainter extends CustomPainter {
  _GlyphTilePainter(this.pack, this.glyph);
  final String pack;
  final String glyph;

  Paint _stroke(Color c, double w,
          {StrokeCap cap = StrokeCap.round,
          StrokeJoin join = StrokeJoin.round}) =>
      Paint()
        ..style = PaintingStyle.stroke
        ..color = c
        ..strokeWidth = w
        ..strokeCap = cap
        ..strokeJoin = join;

  @override
  void paint(Canvas canvas, Size size) {
    final ops = _kGlyphs[glyph];
    if (ops == null) return;
    canvas.save();
    canvas.scale(size.width / 96);
    switch (pack) {
      case 'malam':
        final tileM = RRect.fromRectAndRadius(
            const Rect.fromLTWH(2, 2, 92, 92), const Radius.circular(26));
        canvas.drawRRect(tileM, Paint()..color = const Color(0xFF0B1B3A));
        canvas.drawRRect(tileM, _stroke(const Color(0xFF1B3A6E), 1.5));
        canvas.translate(16, 16);
        final glow = _stroke(const Color(0xFF35E0FF).withValues(alpha: 0.7), 7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        final line = _stroke(const Color(0xFFBFF6FF), 2.6);
        for (final (d, _) in ops) {
          canvas.drawPath(_p(d), glow);
        }
        for (final (d, _) in ops) {
          canvas.drawPath(_p(d), line);
        }
      case 'kuning':
        final tileK = RRect.fromRectAndRadius(
            const Rect.fromLTWH(3, 3, 90, 90), const Radius.circular(18));
        canvas.drawRRect(tileK, Paint()..color = _yellow);
        canvas.drawRRect(tileK, _stroke(_ink, 4.5));
        canvas.save();
        canvas.translate(19, 19);
        for (final (d, closed) in ops) {
          if (closed) canvas.drawPath(_p(d), Paint()..color = _ink);
          canvas.drawPath(_p(d), _stroke(_ink, 4.5));
        }
        canvas.restore();
        canvas.translate(16, 16);
        for (final (d, closed) in ops) {
          if (closed) canvas.drawPath(_p(d), Paint()..color = Colors.white);
          canvas.drawPath(_p(d), _stroke(_ink, 4.5));
        }
      case 'merah':
        canvas.drawRect(
            const Rect.fromLTWH(0, 0, 96, 96), Paint()..color = Colors.black);
        canvas.drawPath(
            _p(_poly(
                '6,34 24,10 38,22 56,4 70,22 92,26 80,46 94,62 72,68 78,92 52,80 34,94 26,72 4,78 16,56')),
            Paint()..color = const Color(0xFFE60012));
        canvas.save();
        canvas.translate(50, 48);
        canvas.rotate(-5 * 3.1415926535 / 180);
        canvas.translate(-50, -48);
        canvas.drawPath(_p(_poly('14,24 76,12 86,72 24,84')),
            Paint()..color = Colors.white);
        canvas.restore();
        void at(double dx, double dy, Color c) {
          canvas.save();
          canvas.translate(dx, dy);
          for (final (d, _) in ops) {
            canvas.drawPath(
                _p(d),
                _stroke(c, 6,
                    cap: StrokeCap.square, join: StrokeJoin.miter));
          }
          canvas.restore();
        }

        at(19, 18, const Color(0xFFE60012));
        at(16, 15, Colors.black);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlyphTilePainter old) =>
      old.pack != pack || old.glyph != glyph;
}

/// Ikon kategori (dan sejenisnya) bergaya paket aktif.
class PackCatIcon extends StatelessWidget {
  const PackCatIcon({super.key, required this.glyph, this.size = 44, this.pack});
  final String glyph;
  final double size;
  final String? pack;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size(size, size),
        painter: _GlyphTilePainter(pack ?? C.pack, glyph),
      ),
    );
  }
}

class _NavGlyphPainter extends CustomPainter {
  _NavGlyphPainter(this.pack, this.glyph, this.selected, this.color);
  final String pack;
  final String glyph;
  final bool selected;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final ops = _kGlyphs[glyph];
    if (ops == null) return;
    canvas.save();
    canvas.scale(size.width / 64);
    Paint stroke(Color c, double w) => Paint()
      ..style = PaintingStyle.stroke
      ..color = c
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (pack == 'malam' && selected) {
      final glow = stroke(const Color(0xFF35E0FF).withValues(alpha: 0.7), 8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      for (final (d, _) in ops) {
        canvas.drawPath(_p(d), glow);
      }
    }
    for (final (d, closed) in ops) {
      if (pack == 'kuning' && selected && closed) {
        canvas.drawPath(_p(d), Paint()..color = Colors.white);
      }
      canvas.drawPath(_p(d), stroke(color, 5));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_NavGlyphPainter old) =>
      old.pack != pack ||
      old.glyph != glyph ||
      old.selected != selected ||
      old.color != color;
}

/// Ikon menu bawah. Kalau gaya Klasik, memakai ikon Material biasa.
Widget navIcon(String glyph, IconData outlined, IconData filled, bool selected) {
  if (C.pack == 'classic') return Icon(selected ? filled : outlined);
  final Color color;
  switch (C.pack) {
    case 'malam':
      color = selected ? const Color(0xFFBFF6FF) : C.muted;
    case 'kuning':
      color = selected ? _ink : _ink.withValues(alpha: 0.55);
    default:
      color = selected ? const Color(0xFFFF5A5F) : C.muted;
  }
  return ExcludeSemantics(
    child: CustomPaint(
      size: const Size(26, 26),
      painter: _NavGlyphPainter(C.pack, glyph, selected, color),
    ),
  );
}

// -----------------------------------------------------------------------------
// Motif latar
// -----------------------------------------------------------------------------

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.pack, this.card);
  final String pack;
  final bool card;

  Offset _pt(double cx, double cy, double r, double a) =>
      Offset(cx + r * math.cos(a), cy + r * math.sin(a));

  void _swirl(Canvas c, double cx, double cy, int n, Color col, double w,
      double step) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..color = col
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i <= n; i++) {
      final r = i * step;
      final a0 = 20 * i * math.pi / 180;
      final a1 = a0 + 250 * math.pi / 180;
      final path = Path()
        ..moveTo(_pt(cx, cy, r, a0).dx, _pt(cx, cy, r, a0).dy)
        ..arcToPoint(_pt(cx, cy, r, a1),
            radius: Radius.circular(r), largeArc: true, clockwise: true);
      c.drawPath(path, p);
    }
  }

  void _sparkle(Canvas c, double x, double y, double r, Color col) {
    final path = Path()
      ..moveTo(x, y - r)
      ..lineTo(x + r * .22, y - r * .22)
      ..lineTo(x + r, y)
      ..lineTo(x + r * .22, y + r * .22)
      ..lineTo(x, y + r)
      ..lineTo(x - r * .22, y + r * .22)
      ..lineTo(x - r, y)
      ..lineTo(x - r * .22, y - r * .22)
      ..close();
    c.drawPath(path, Paint()..color = col);
  }

  void _malam(Canvas c, double w, double h, double sc) {
    final rnd = math.Random(7);
    _swirl(c, w * .78, h * .22, 6, const Color(0xFF35B6FF).withValues(alpha: .32),
        2.2, 14 * sc);
    _swirl(c, w * .12, h * .8, 4, const Color(0xFF35B6FF).withValues(alpha: .2),
        2, 12 * sc);
    final mc = Offset(w * .84, h * .2);
    c.drawCircle(
        mc,
        42 * sc,
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFFFFE9A8).withValues(alpha: .9),
            const Color(0xFFFFE9A8).withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: mc, radius: 42 * sc)));
    final moon = Path.combine(
        PathOperation.difference,
        Path()..addOval(Rect.fromCircle(center: mc, radius: 16 * sc)),
        Path()
          ..addOval(Rect.fromCircle(
              center: Offset(mc.dx + 7 * sc, mc.dy - 4 * sc), radius: 14 * sc)));
    c.drawPath(moon, Paint()..color = const Color(0xFFFFE08A));
    for (var i = 0; i < 22; i++) {
      final x = rnd.nextDouble() * w, y = rnd.nextDouble() * h;
      if (rnd.nextDouble() < .35) {
        _sparkle(c, x, y, (4 + rnd.nextDouble() * 4) * sc.clamp(0.7, 1.0),
            const Color(0xFFCFF6FF)
                .withValues(alpha: .5 + rnd.nextDouble() * .4));
      } else {
        c.drawCircle(
            Offset(x, y),
            .8 + rnd.nextDouble() * 1,
            Paint()
              ..color = const Color(0xFFCFF6FF)
                  .withValues(alpha: .3 + rnd.nextDouble() * .5));
      }
    }
  }

  void _cloud(Canvas c, double x, double y, double s, Color col, double op) {
    c.save();
    c.translate(x, y);
    c.scale(s);
    c.saveLayer(const Rect.fromLTWH(-80, -50, 260, 130),
        Paint()..color = Colors.white.withValues(alpha: op));
    final p = Paint()
      ..color = col
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6);
    for (final (cx, cy, r) in const [
      (0.0, 6.0, 20.0),
      (26.0, -6.0, 26.0),
      (56.0, 4.0, 22.0),
      (28.0, 10.0, 24.0),
      (-18.0, 12.0, 14.0),
      (74.0, 12.0, 14.0),
    ]) {
      c.drawCircle(Offset(cx, cy), r, p);
    }
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-24, 14, 106, 20), const Radius.circular(10)),
        p);
    c.restore();
    c.restore();
  }

  void _fog(Canvas c, double x, double y, double rx, double ry, Color col,
      double op, double blur) {
    c.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: rx * 2, height: ry * 2),
        Paint()
          ..color = col.withValues(alpha: op)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur));
  }

  void _sky(Canvas c, bool big, Color cloudCol, double cloudOp, Color fogCol,
      Color fogTone) {
    if (big) {
      _cloud(c, 20, 26, 1.0, cloudCol, cloudOp);
      _cloud(c, 250, 60, 1.25, cloudCol, cloudOp * .9);
      _cloud(c, 150, 118, .7, cloudCol, cloudOp * .7);
      _cloud(c, 318, 6, .6, cloudCol, cloudOp * .8);
      for (final (x, y, rx, ry, o) in const [
        (60.0, 100.0, 150.0, 22.0, .25),
        (300.0, 110.0, 170.0, 22.0, .2),
      ]) {
        _fog(c, x, y, rx, ry, fogTone, o, 14);
      }
      for (final (x, y, rx, ry, o) in const [
        (70.0, 70.0, 140.0, 18.0, .45),
        (310.0, 100.0, 180.0, 22.0, .5),
        (150.0, 130.0, 210.0, 26.0, .45),
        (220.0, 170.0, 260.0, 34.0, .55),
        (90.0, 215.0, 260.0, 40.0, .6),
        (320.0, 235.0, 240.0, 40.0, .6),
      ]) {
        _fog(c, x, y, rx, ry, fogCol, o, 14);
      }
    } else {
      _cloud(c, 100, 18, .9, cloudCol, cloudOp);
      _cloud(c, 60, 92, .6, cloudCol, cloudOp * .8);
      for (final (x, y, rx, ry, o) in const [
        (150.0, 30.0, 90.0, 18.0, .45),
        (110.0, 80.0, 100.0, 22.0, .45),
        (170.0, 125.0, 90.0, 20.0, .5),
      ]) {
        _fog(c, x, y, rx, ry, fogCol, o, 7);
      }
      _fog(c, 60, 135, 80, 16, fogTone, .3, 7);
    }
  }

  void _bean(Canvas c, double x, double y, double rot, double s) {
    c.save();
    c.translate(x, y);
    c.rotate(rot * math.pi / 180);
    c.scale(s);
    c.drawOval(const Rect.fromLTRB(-11, -16, 11, 16),
        Paint()..color = const Color(0xFF6B3A22));
    c.drawPath(
        Path()
          ..moveTo(0, -15)
          ..cubicTo(-6, -6, 6, 6, 0, 15),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFF2A120B)
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round);
    c.restore();
  }

  void _merah(Canvas c, double w, double h, double sc) {
    final rnd = math.Random(5);
    for (final lx in [w * .28, w * .74]) {
      final ly = h * .2;
      final gc = Offset(lx, ly + 3 * sc);
      c.drawCircle(
          gc,
          64 * sc,
          Paint()
            ..shader = RadialGradient(colors: [
              const Color(0xFFFFB347).withValues(alpha: .55),
              const Color(0xFFFFB347).withValues(alpha: 0),
            ]).createShader(Rect.fromCircle(center: gc, radius: 64 * sc)));
      c.drawLine(
          Offset(lx, 0),
          Offset(lx, h * .12),
          Paint()
            ..color = const Color(0xFFFFF1DC).withValues(alpha: .5)
            ..strokeWidth = 1.5);
      c.drawPath(
          Path()
            ..moveTo(lx - 16 * sc, ly)
            ..arcToPoint(Offset(lx + 16 * sc, ly),
                radius: Radius.circular(16 * sc), clockwise: true)
            ..close(),
          Paint()..color = const Color(0xFFD4262C));
      c.drawCircle(gc, 5 * sc, Paint()..color = const Color(0xFFFFD27A));
    }
    for (var i = 0; i < 7; i++) {
      _bean(
          c,
          w * .5 + rnd.nextDouble() * w * .47,
          h * .35 + rnd.nextDouble() * h * .55,
          rnd.nextInt(180).toDouble(),
          (.5 + rnd.nextDouble() * .4) * sc);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final baseW = card ? 190.0 : 390.0;
    final baseH = card ? 150.0 : 300.0;
    final s = card ? size.height / baseH : size.width / baseW;
    final sc = card ? .55 : 1.0;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(s);
    switch (pack) {
      case 'malam':
        if (!card) {
          canvas.drawRect(
              Rect.fromLTWH(0, 0, baseW, baseH),
              Paint()
                ..shader = LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                      const Color(0xFF0A1B45),
                      const Color(0xFF0A1B45).withValues(alpha: 0)
                    ])
                    .createShader(Rect.fromLTWH(0, 0, baseW, baseH)));
        }
        _malam(canvas, baseW, baseH, sc);
      case 'kuning':
        _sky(canvas, !card, Colors.white, .95, Colors.white,
            const Color(0xFFD9A400));
      case 'merah':
        if (!card) {
          canvas.drawRect(
              Rect.fromLTWH(0, 0, baseW, baseH),
              Paint()
                ..shader = LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                      const Color(0xFF3A1210),
                      const Color(0xFF3A1210).withValues(alpha: 0)
                    ])
                    .createShader(Rect.fromLTWH(0, 0, baseW, baseH)));
        }
        _merah(canvas, baseW, baseH, sc);
    }
    canvas.restore();
    if (!card) {
      // Pudar ke warna latar di bagian bawah supaya tidak terpotong tegas.
      final fadeH = size.height * .3;
      canvas.drawRect(
          Rect.fromLTWH(0, size.height - fadeH, size.width, fadeH),
          Paint()
            ..shader = LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [C.bg.withValues(alpha: 0), C.bg])
                .createShader(Rect.fromLTWH(
                    0, size.height - fadeH, size.width, fadeH)));
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter old) =>
      old.pack != pack || old.card != card;
}

/// Latar bermotif di belakang bagian atas Beranda. Tidak apa-apa kalau
/// [C.pack] 'classic': tidak menggambar apa-apa.
class PackBackdrop extends StatelessWidget {
  const PackBackdrop({super.key, this.card = false});
  final bool card;

  @override
  Widget build(BuildContext context) {
    if (C.pack == 'classic') return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _BackdropPainter(C.pack, card),
        ),
      ),
    );
  }
}

/// Sisi kanan kartu yang bermotif, memudar ke kiri supaya tulisan tetap
/// terbaca. Ditaruh di Stack di bawah isi kartu.
class PackCardMotif extends StatelessWidget {
  const PackCardMotif({super.key});

  @override
  Widget build(BuildContext context) {
    if (C.pack == 'classic') return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      return Stack(
        children: [
          Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: w * .6,
              child: const PackBackdrop(card: true)),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      C.surface,
                      C.surface,
                      C.surface.withValues(alpha: 0)
                    ],
                    stops: const [0, .42, .9],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}
