part of '../main.dart';

// =============================================================================
// KEKAYAAN BERSIH PER BULAN (Statistik)
// Total saldo semua akun (kartu kredit minus = utang) di akhir tiap bulan,
// dalam Rupiah dengan kurs yang berlaku sekarang.
// =============================================================================

class NetWorthPoint {
  const NetWorthPoint(this.month, this.value);

  /// Tanggal 1 bulan itu.
  final DateTime month;
  final double value;
}

extension NetWorthStore on AppStore {
  /// [months] titik terakhir, dari yang terlama. Bulan berjalan dihitung
  /// sampai [now]. Piutang/utang di menu Utang & Piutang tidak ikut (itu
  /// catatan, bukan akun), kecuali talangan patungan yang memang akun.
  List<NetWorthPoint> netWorthHistory(DateTime now, {int months = 12}) {
    final cutoffs = <DateTime>[
      for (var i = months - 1; i >= 0; i--)
        DateTime(now.year, now.month - i + 1), // awal bulan berikutnya
    ];
    final values = List<double>.filled(months, 0);
    for (final a in accounts) {
      final r = rate(a.currency);
      final perCut = List<double>.filled(months, a.initialBalance);
      for (final t in transactions) {
        final d = accountDelta(t, a.id);
        if (d == 0) continue;
        for (var i = 0; i < months; i++) {
          if (t.date.isBefore(cutoffs[i])) perCut[i] += d;
        }
      }
      for (var i = 0; i < months; i++) {
        values[i] += perCut[i] * r;
      }
    }
    return [
      for (var i = 0; i < months; i++)
        NetWorthPoint(
            DateTime(cutoffs[i].year, cutoffs[i].month - 1), values[i]),
    ];
  }
}

class NetWorthCard extends StatelessWidget {
  const NetWorthCard({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final pts = store.netWorthHistory(DateTime.now());
    final hide = store.settings.hideBalance;
    final now = pts.last.value;
    final prev = pts.length > 1 ? pts[pts.length - 2].value : now;
    final diff = now - prev;
    final first = pts.first.value;
    final yearDiff = now - first;
    String signed(double v) =>
        hide ? '••••' : '${v >= 0 ? '+' : '−'}${money(v.abs())}';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Kekayaan Bersih'),
          const SizedBox(height: 4),
          Text(hide ? 'Rp ••••••' : money(now),
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: now < 0 ? C.redDark : C.carbon)),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(children: [
              TextSpan(
                  text: signed(diff),
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: diff >= 0 ? C.income : C.redDark)),
              TextSpan(
                  text: ' dari akhir bulan lalu · ',
                  style: TextStyle(color: C.muted)),
              TextSpan(
                  text: signed(yearDiff),
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: yearDiff >= 0 ? C.income : C.redDark)),
              TextSpan(
                  text: ' dalam 12 bulan',
                  style: TextStyle(color: C.muted)),
            ]),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 150,
            child: CustomPaint(
              size: Size.infinite,
              painter: _NetWorthPainter(
                points: pts,
                line: C.accentDark,
                grid: C.line,
                label: C.muted,
                hideValues: hide,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
              'Total saldo semua akun di akhir tiap bulan (kartu kredit dihitung minus), pakai kurs sekarang.',
              style: TextStyle(fontSize: 11, color: C.muted)),
        ],
      ),
    );
  }
}

class _NetWorthPainter extends CustomPainter {
  _NetWorthPainter({
    required this.points,
    required this.line,
    required this.grid,
    required this.label,
    required this.hideValues,
  });

  final List<NetWorthPoint> points;
  final Color line, grid, label;
  final bool hideValues;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    const bottomPad = 18.0, topPad = 18.0, sidePad = 6.0;
    final h = size.height - bottomPad - topPad;
    final w = size.width - sidePad * 2;
    var lo = points.map((p) => p.value).reduce(math.min);
    var hi = points.map((p) => p.value).reduce(math.max);
    if ((hi - lo).abs() < 1) {
      hi += 1;
      lo -= 1;
    }
    final pad = (hi - lo) * 0.1;
    hi += pad;
    lo -= pad;
    Offset at(int i, double v) => Offset(
        sidePad + (points.length == 1 ? w / 2 : w * i / (points.length - 1)),
        topPad + h * (1 - (v - lo) / (hi - lo)));

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var k = 0; k <= 2; k++) {
      final y = topPad + h * k / 2;
      canvas.drawLine(Offset(sidePad, y), Offset(size.width - sidePad, y),
          gridPaint);
    }
    if (lo < 0 && hi > 0) {
      final y = at(0, 0).dy;
      canvas.drawLine(Offset(sidePad, y), Offset(size.width - sidePad, y),
          gridPaint..strokeWidth = 1.5);
    }

    final path = Path();
    final fill = Path();
    for (var i = 0; i < points.length; i++) {
      final o = at(i, points[i].value);
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
        fill.moveTo(o.dx, topPad + h);
        fill.lineTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
        fill.lineTo(o.dx, o.dy);
      }
    }
    final last = at(points.length - 1, points.last.value);
    fill
      ..lineTo(last.dx, topPad + h)
      ..close();
    canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [line.withValues(alpha: 0.22), line.withValues(alpha: 0)],
          ).createShader(Rect.fromLTWH(0, topPad, size.width, h)));
    canvas.drawPath(
        path,
        Paint()
          ..color = line
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round);
    canvas.drawCircle(last, 4.5, Paint()..color = line);
    canvas.drawCircle(last, 2, Paint()..color = Colors.white);

    // Label bulan (huruf pertama), bulan terakhir ditulis lengkap.
    for (var i = 0; i < points.length; i++) {
      final isLast = i == points.length - 1;
      final text = DateFormat('MMM', 'id_ID')
          .format(points[i].month);
      final tp = TextPainter(
        text: TextSpan(
            text: isLast ? text : text.substring(0, 1),
            style: TextStyle(
                fontSize: 10,
                color: label,
                fontWeight: isLast ? FontWeight.w800 : FontWeight.w500)),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      final x = at(i, points[i].value).dx - tp.width / 2;
      tp.paint(
          canvas,
          Offset(x.clamp(0, size.width - tp.width),
              size.height - bottomPad + 4));
    }
    if (!hideValues) {
      final tp = TextPainter(
        text: TextSpan(
            text: compactMoney(points.last.value),
            style: TextStyle(
                fontSize: 10.5, color: line, fontWeight: FontWeight.w900)),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(
          canvas,
          Offset((last.dx - tp.width).clamp(0, size.width - tp.width),
              (last.dy - tp.height - 6).clamp(0, size.height)));
    }
  }

  @override
  bool shouldRepaint(_NetWorthPainter old) =>
      old.points != points ||
      old.line != line ||
      old.hideValues != hideValues;
}
