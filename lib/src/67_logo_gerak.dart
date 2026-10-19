part of '../main.dart';

// =============================================================================
// LOGO BERGERAK (v6.1)
// Satu painter dipakai oleh animasi pembuka, panduan pertama kali, dan halaman
// Bantuan. Gambarnya sama dengan ikon app (lihat tool/make_logo.py).
// Garis waktu ada di LogoMotion supaya bisa diuji tanpa menggambar apa pun.
// =============================================================================

const Color kSplashCream = Color(0xFFFFF3CC);
const Color kSplashInk = Color(0xFF1F1B3A);

/// Lama animasi pembuka. Versi singkat dipakai untuk mode "Tiap buka".
const int kSplashMs = 2000;
const int kSplashQuickMs = 1100;

/// Lama gerak koin saat logo diketuk.
const int kLogoTapMs = 700;

/// Warna animasi pembuka menurut paket gaya dan tema.
class SplashLook {
  const SplashLook(this.bg, this.text, {this.discRing, this.discRingWidth = 5});
  final Color bg;
  final Color text;

  /// Tidak null: logo diletakkan di atas cakram krem berbingkai warna ini,
  /// supaya garis tinta logo tetap terbaca di latar gelap atau kuning.
  final Color? discRing;
  final double discRingWidth;

  bool get hasDisc => discRing != null;
}

SplashLook splashLook(String pack, {required bool dark}) {
  final sp = kStylePacks[pack];
  if (sp != null) {
    return SplashLook(sp.bg, sp.carbon,
        discRing: pack == 'kuning' ? sp.carbon : sp.line,
        discRingWidth: pack == 'kuning' ? 7 : 5);
  }
  if (dark) {
    return const SplashLook(Color(0xFF121316), Color(0xFFECEDEF),
        discRing: Color(0xFF2E3137));
  }
  return const SplashLook(kSplashCream, kSplashInk);
}

double _seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);
double _outCubic(double x) => 1 - math.pow(1 - x, 3).toDouble();
double _inPow(double x) => math.pow(x, 2.2).toDouble();
double _hop(double u) => 4 * u * (1 - u);
double _outBack(double x) {
  const c = 1.70158;
  final y = x - 1;
  return 1 + (c + 1) * y * y * y + c * y * y;
}

/// Satu bingkai gerak logo, pada kanvas 256x256.
class LogoMotion {
  const LogoMotion({
    required this.bgMix,
    required this.disc,
    required this.draw,
    required this.coin,
    required this.coinA,
    required this.coinY,
    required this.coinSX,
    required this.coinSY,
    required this.coinAngle,
    required this.shadow,
    required this.pulse,
    required this.ripple,
    required this.shine,
    required this.sparks,
  });

  /// 0 = latar krem (splash bawaan Android), 1 = latar paket gaya.
  final double bgMix;

  /// Skala cakram krem (0 sampai 1, boleh sedikit melampaui saat membal).
  final double disc;

  /// Bagian pita yang sudah tergambar, 0 sampai 1.
  final double draw;
  final bool coin;
  final double coinA;
  final double coinY;
  final double coinSX;
  final double coinSY;

  /// Putaran koin; kosinusnya menentukan sisi depan atau belakang.
  final double coinAngle;
  final double shadow;
  final double pulse;
  final double ripple;
  final double shine;

  /// Skala tiga bintang kecil.
  final List<double> sparks;

  static const List<(double, double, double, double)> sparkSpots = [
    (214, 78, 8, 0.58),
    (52, 190, 5, 0.66),
    (232, 160, 3.5, 0.74),
  ];

  /// Animasi pembuka. [t] dari 0 sampai 1.
  static LogoMotion intro(double t) {
    final fall = _seg(t, 0.30, 0.54);
    var y = 128.0, sx = 1.0, sy = 1.0, h = 0.0;
    var angle = 0.0;
    if (fall < 1) {
      y = -60 + 188 * _inPow(fall);
      angle = 2 * math.pi * fall;
    } else {
      h = 26 * _hop(_seg(t, 0.54, 0.74)) + 8 * _hop(_seg(t, 0.74, 0.86));
      y = 128 - h;
      angle = 2 * math.pi;
      final s = math.sin(math.pi * _seg(t, 0.54, 0.60)) * 0.2 +
          math.sin(math.pi * _seg(t, 0.74, 0.78)) * 0.08;
      sy = 1 - s;
      sx = 1 + s * 0.7;
    }
    return LogoMotion(
      bgMix: _seg(t, 0, 0.12),
      disc: _outBack(_seg(t, 0, 0.16)),
      draw: Curves.easeInOut.transform(_seg(t, 0, 0.40)),
      coin: fall > 0,
      coinA: (fall * 5).clamp(0.0, 1.0),
      coinY: y,
      coinSX: sx,
      coinSY: sy,
      coinAngle: angle,
      shadow: _inPow(fall) * (1 - (h / 60).clamp(0.0, 1.0)),
      pulse: 1 + 0.03 * math.sin(math.pi * _seg(t, 0.54, 0.72)),
      ripple: _seg(t, 0.54, 0.80),
      shine: _seg(t, 0.84, 0.97),
      sparks: [
        for (final s in sparkSpots)
          _outBack(_seg(t, s.$4, s.$4 + 0.14)) *
              ((t > s.$4 + 0.14 && t < 0.97)
                  ? 1 + 0.14 * math.sin((t - s.$4) * 34)
                  : 1.0),
      ],
    );
  }

  /// Gerak saat logo diketuk: koin melompat, berputar sekali, mendarat.
  static LogoMotion tap(double tt) {
    final u = _seg(tt, 0, 0.5);
    final h = 34 * _hop(u) + 7 * _hop(_seg(tt, 0.64, 0.82));
    final s = math.sin(math.pi * _seg(tt, 0.5, 0.64)) * 0.18;
    return LogoMotion(
      bgMix: 1,
      disc: 1,
      draw: 1,
      coin: true,
      coinA: 1,
      coinY: 128 - h,
      coinSX: 1 + s * 0.7,
      coinSY: 1 - s,
      coinAngle: 2 * math.pi * Curves.easeInOut.transform(u),
      shadow: 1 - (h / 45).clamp(0.0, 1.0),
      pulse: 1 + 0.03 * math.sin(math.pi * _seg(tt, 0.5, 0.7)),
      ripple: _seg(tt, 0.5, 0.95),
      shine: _seg(tt, 0.6, 0.95),
      sparks: [
        for (final _ in sparkSpots)
          1 + 0.35 * math.sin(math.pi * _seg(tt, 0.45, 0.9)),
      ],
    );
  }

  /// Logo diam: sama dengan gerak ketukan pada awal atau akhirnya.
  static LogoMotion rest() => tap(0);
}

/// Logo pita ∞ + koin Rp pada kanvas 256x256.
class LogoPainter extends CustomPainter {
  LogoPainter(this.m, {this.look});
  final LogoMotion m;

  /// Kalau punya cakram, cakram digambar di belakang logo.
  final SplashLook? look;

  static const ink = kSplashInk;

  static Path _ribbonPath() => Path()
    ..moveTo(60, 128)
    ..cubicTo(60, 72, 104, 72, 128, 128)
    ..cubicTo(152, 184, 196, 184, 196, 128)
    ..cubicTo(196, 72, 152, 72, 128, 128)
    ..cubicTo(104, 184, 60, 184, 60, 128)
    ..close();

  // Dua potongan yang digambar ulang di atas titik silang (efek anyaman).
  static Path _weavePath() => Path()
    ..moveTo(151.46, 94.13)
    ..cubicTo(143.01, 101.03, 134.72, 112.32, 128, 128)
    ..cubicTo(121.28, 143.68, 112.99, 154.97, 104.54, 161.87);

  void _stroke(Canvas canvas, Path path, Paint base, double w, Shader? shader,
      Color color, StrokeCap cap) {
    canvas.drawPath(
        path,
        base
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..strokeCap = cap
          ..strokeJoin = StrokeJoin.round
          ..shader = shader
          ..color = color);
  }

  void _spark(Canvas canvas, double x, double y, double r, double line) {
    final q = r * 0.26;
    final p = Path()
      ..moveTo(x, y - r)
      ..lineTo(x + q, y - q)
      ..lineTo(x + r, y)
      ..lineTo(x + q, y + q)
      ..lineTo(x, y + r)
      ..lineTo(x - q, y + q)
      ..lineTo(x - r, y)
      ..lineTo(x - q, y - q)
      ..close();
    canvas.drawPath(
        p,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = line
          ..strokeJoin = StrokeJoin.round
          ..color = ink);
    canvas.drawPath(
        p,
        Paint()
          ..isAntiAlias = true
          ..color = Colors.white);
  }

  void _label(Canvas canvas, String text, double size, double cx, double cy) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              fontSize: size,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF9A5B05))),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  void _coin(Canvas canvas) {
    const cx = 196.0, r = 33.0;
    final cy = m.coinY;
    final faded = m.coinA < 1;
    if (faded) {
      canvas.saveLayer(
          Rect.fromLTWH(cx - 60, cy - 60, 120, 140),
          Paint()..color = Color.fromRGBO(0, 0, 0, m.coinA));
    }
    canvas.save();
    // Gepeng saat mendarat: bagian bawah koin tetap menempel.
    canvas.translate(cx, cy + r);
    canvas.scale(m.coinSX, m.coinSY);
    canvas.translate(-cx, -(cy + r));
    // Berputar: lebar mengecil mengikuti kosinus, sisi belakang tampil ∞.
    final c = math.cos(m.coinAngle);
    final front = c >= 0;
    canvas.translate(cx, cy);
    canvas.scale(math.max(c.abs(), 0.05), 1);
    canvas.translate(-cx, -cy);

    canvas.drawCircle(
        Offset(cx, cy + 6),
        r,
        Paint()
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
          ..color = ink.withValues(alpha: 0.22 * m.shadow));
    canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.fill
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFE766), Color(0xFFF5A81C)],
          ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)));
    canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = ink);
    canvas.drawCircle(
        Offset(cx, cy),
        r * 0.72,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.6
          ..color = const Color(0xFFE39A10));
    if (front) {
      _label(canvas, 'Rp', r * 0.82, cx, cy);
      canvas.drawPath(
          Path()
            ..moveTo(cx - r * 0.55, cy - r * 0.28)
            ..quadraticBezierTo(
                cx - r * 0.43, cy - r * 0.78, cx + r * 0.07, cy - r * 0.74),
          Paint()
            ..isAntiAlias = true
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 5
            ..color = Colors.white.withValues(alpha: 0.85));
    } else {
      _label(canvas, '∞', r * 1.05, cx, cy);
    }
    if (front && m.shine > 0 && m.shine < 1) {
      canvas.save();
      canvas.clipPath(Path()
        ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r - 3)));
      canvas.translate(cx, cy);
      canvas.rotate(-0.6);
      final x0 = -r * 2 + r * 4 * m.shine;
      canvas.drawRect(
          Rect.fromLTWH(x0 - r * 0.3, -r * 2, r * 0.6, r * 4),
          Paint()
            ..shader = LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: 0.8),
                Colors.white.withValues(alpha: 0),
              ],
            ).createShader(
                Rect.fromLTWH(x0 - r * 0.3, 0, r * 0.6, 1)));
      canvas.restore();
    }
    canvas.restore();
    if (faded) canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 256);

    final lk = look;
    if (lk != null && lk.hasDisc && m.disc > 0) {
      final a = (m.disc * 1.5).clamp(0.0, 1.0);
      final rad = 118 * m.disc;
      canvas.drawCircle(const Offset(128, 128), rad,
          Paint()..color = kSplashCream.withValues(alpha: a));
      canvas.drawCircle(
          const Offset(128, 128),
          rad,
          Paint()
            ..isAntiAlias = true
            ..style = PaintingStyle.stroke
            ..strokeWidth = lk.discRingWidth
            ..color = lk.discRing!.withValues(alpha: a));
    }

    final grad = const LinearGradient(
      colors: [Color(0xFF0FB5A6), Color(0xFF4CC96A), Color(0xFF9BDB2D)],
      stops: [0, 0.55, 1],
    ).createShader(const Rect.fromLTRB(60, 0, 196, 1));

    // Pita: tergambar mengikuti garis, lalu utuh dengan anyaman di silangan.
    if (m.draw > 0.002) {
      canvas.save();
      canvas.translate(128, 128);
      canvas.scale(m.pulse);
      canvas.translate(-128, -128);
      final full = _ribbonPath();
      var part = full;
      if (m.draw < 1) {
        part = Path();
        for (final mt in full.computeMetrics()) {
          part.addPath(mt.extractPath(0, mt.length * m.draw), Offset.zero);
        }
      }
      final cap = m.draw < 1 ? StrokeCap.round : StrokeCap.butt;
      canvas.save();
      canvas.translate(0, 6);
      _stroke(
          canvas,
          part,
          Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
          33,
          null,
          ink.withValues(alpha: 0.22),
          StrokeCap.round);
      canvas.restore();
      _stroke(canvas, part, Paint()..isAntiAlias = true, 33, null, ink,
          StrokeCap.round);
      _stroke(canvas, part, Paint()..isAntiAlias = true, 23, grad, ink, cap);
      if (m.draw >= 1) {
        final w = _weavePath();
        _stroke(canvas, w, Paint()..isAntiAlias = true, 33, null, ink,
            StrokeCap.butt);
        _stroke(canvas, w, Paint()..isAntiAlias = true, 23, grad, ink,
            StrokeCap.butt);
      }
      canvas.restore();
    }

    // Riak tipis dari tempat koin mendarat.
    if (m.ripple > 0 && m.ripple < 1) {
      final ru = m.ripple;
      canvas.drawCircle(
          const Offset(196, 128),
          33 + ru * 36,
          Paint()
            ..isAntiAlias = true
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1 + 3.5 * (1 - ru)
            ..color = const Color(0xFF0FB5A6)
                .withValues(alpha: 0.55 * (1 - ru)));
    }

    if (m.coin) _coin(canvas);

    for (var i = 0; i < LogoMotion.sparkSpots.length; i++) {
      final s = LogoMotion.sparkSpots[i];
      final p = m.sparks[i];
      if (p <= 0.01) continue;
      _spark(canvas, s.$1, s.$2, s.$3 * p, i == 2 ? 2 : 3);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(LogoPainter old) => old.m != m || old.look != look;
}

/// Animasi pembuka: pita tergambar, koin jatuh dan memantul, huruf naik satu
/// per satu. Warna latar mengikuti paket gaya.
class AnimatedSplash extends StatefulWidget {
  const AnimatedSplash(
      {super.key,
      required this.onDone,
      required this.look,
      this.quick = false});
  final VoidCallback onDone;
  final SplashLook look;

  /// Versi singkat (sekitar 1 detik) untuk mode "tiap buka".
  final bool quick;

  @override
  State<AnimatedSplash> createState() => _AnimatedSplashState();
}

class _AnimatedSplashState extends State<AnimatedSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  static const _word = 'Infinity';

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this,
        duration: Duration(
            milliseconds: widget.quick ? kSplashQuickMs : kSplashMs))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.of(context).disableAnimations) {
        _c.value = 1; // hormati setelan "kurangi animasi"
        widget.onDone();
      } else {
        _c.forward();
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final look = widget.look;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final m = LogoMotion.intro(t);
        return Scaffold(
          // Mulai dari krem yang sama dengan splash Android, lalu bergeser
          // ke warna paket supaya tidak ada kedipan.
          backgroundColor: Color.lerp(kSplashCream, look.bg, m.bgMix),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 220,
                  height: 220,
                  child: CustomPaint(painter: LogoPainter(m, look: look)),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < _word.length; i++)
                      _letter(i, t, look.text),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _letter(int i, double t, Color color) {
    final a = 0.66 + 0.03 * i;
    final pr = _outBack(_seg(t, a, a + 0.16));
    final al = _outCubic(_seg(t, a, a + 0.12));
    return Opacity(
      opacity: al,
      child: Transform.translate(
        offset: Offset(0, (1 - pr) * 14),
        child: m.Text(_word[i],
            style: TextStyle(
                color: color,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5)),
      ),
    );
  }
}

/// Logo yang bisa diketuk: koin melompat, berputar sekali, lalu mendarat.
/// Main sekali saat tampil, kecuali "Kurangi animasi" di HP menyala.
class AnimatedInfinityLogo extends StatefulWidget {
  const AnimatedInfinityLogo({super.key, this.size = 104});
  final double size;

  @override
  State<AnimatedInfinityLogo> createState() => _AnimatedInfinityLogoState();
}

class _AnimatedInfinityLogoState extends State<AnimatedInfinityLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: kLogoTapMs));

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _play();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _play() {
    if (MediaQuery.of(context).disableAnimations) return;
    _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final look = splashLook(C.pack, dark: C.isDark);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _play,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
              painter: LogoPainter(LogoMotion.tap(_c.value), look: look)),
        ),
      ),
    );
  }
}
