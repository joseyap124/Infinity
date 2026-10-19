part of '../main.dart';

// Paket gaya (v5.1): ikon pintasan tematik, pilihan Gaya, dan pilihan Maskot.
// Bentuk ikon sama dengan papan mockup (kanvas 96x96), digambar dengan kode
// supaya tetap offline dan tajam di ukuran berapa pun.

/// Membaca data jalur SVG sederhana (M L H V C S Q T A Z, huruf besar dan kecil).
Path svgPath(String d) {
  final path = Path();
  final tok = RegExp(
      r'[MmLlHhVvCcSsQqTtAaZz]|[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?');
  final t = tok.allMatches(d).map((m) => m.group(0)!).toList();
  var i = 0;
  var cx = 0.0, cy = 0.0, sx = 0.0, sy = 0.0;
  var lcx = 0.0, lcy = 0.0; // titik kontrol terakhir (untuk S dan T)
  var prev = '';
  double n() => double.parse(t[i++]);
  bool isNum() => i < t.length && !RegExp(r'^[A-Za-z]').hasMatch(t[i]);
  var cmd = '';
  while (i < t.length) {
    if (RegExp(r'^[A-Za-z]').hasMatch(t[i])) cmd = t[i++];
    final rel = cmd == cmd.toLowerCase();
    var c = cmd.toUpperCase();
    if (c == 'Z') {
      path.close();
      cx = sx;
      cy = sy;
      prev = 'Z';
      continue;
    }
    do {
      switch (c) {
        case 'M':
          var x = n(), y = n();
          if (rel) {
            x += cx;
            y += cy;
          }
          path.moveTo(x, y);
          cx = sx = x;
          cy = sy = y;
          cmd = rel ? 'l' : 'L';
          c = 'L'; // pasangan angka berikutnya setelah M berarti garis
          prev = 'M';
        case 'L':
          var x = n(), y = n();
          if (rel) {
            x += cx;
            y += cy;
          }
          path.lineTo(x, y);
          cx = x;
          cy = y;
          prev = 'L';
        case 'H':
          var x = n();
          if (rel) x += cx;
          path.lineTo(x, cy);
          cx = x;
          prev = 'H';
        case 'V':
          var y = n();
          if (rel) y += cy;
          path.lineTo(cx, y);
          cy = y;
          prev = 'V';
        case 'C':
          var x1 = n(), y1 = n(), x2 = n(), y2 = n(), x = n(), y = n();
          if (rel) {
            x1 += cx;
            y1 += cy;
            x2 += cx;
            y2 += cy;
            x += cx;
            y += cy;
          }
          path.cubicTo(x1, y1, x2, y2, x, y);
          lcx = x2;
          lcy = y2;
          cx = x;
          cy = y;
          prev = 'C';
        case 'S':
          var x2 = n(), y2 = n(), x = n(), y = n();
          if (rel) {
            x2 += cx;
            y2 += cy;
            x += cx;
            y += cy;
          }
          final x1 = (prev == 'C' || prev == 'S') ? 2 * cx - lcx : cx;
          final y1 = (prev == 'C' || prev == 'S') ? 2 * cy - lcy : cy;
          path.cubicTo(x1, y1, x2, y2, x, y);
          lcx = x2;
          lcy = y2;
          cx = x;
          cy = y;
          prev = 'S';
        case 'Q':
          var x1 = n(), y1 = n(), x = n(), y = n();
          if (rel) {
            x1 += cx;
            y1 += cy;
            x += cx;
            y += cy;
          }
          path.quadraticBezierTo(x1, y1, x, y);
          lcx = x1;
          lcy = y1;
          cx = x;
          cy = y;
          prev = 'Q';
        case 'T':
          var x = n(), y = n();
          if (rel) {
            x += cx;
            y += cy;
          }
          final x1 = (prev == 'Q' || prev == 'T') ? 2 * cx - lcx : cx;
          final y1 = (prev == 'Q' || prev == 'T') ? 2 * cy - lcy : cy;
          path.quadraticBezierTo(x1, y1, x, y);
          lcx = x1;
          lcy = y1;
          cx = x;
          cy = y;
          prev = 'T';
        case 'A':
          final rx = n(), ry = n(), rot = n();
          final large = n() != 0, sweep = n() != 0;
          var x = n(), y = n();
          if (rel) {
            x += cx;
            y += cy;
          }
          path.arcToPoint(Offset(x, y),
              radius: Radius.elliptical(rx, ry),
              rotation: rot,
              largeArc: large,
              clockwise: sweep);
          cx = x;
          cy = y;
          prev = 'A';
        default:
          // Perintah tak dikenal: hentikan supaya tidak berputar selamanya.
          return path;
      }
    } while (isNum());
  }
  return path;
}

String _circ(double cx, double cy, double r) =>
    'M${cx - r} ${cy}a$r $r 0 1 0 ${2 * r} 0a$r $r 0 1 0 ${-2 * r} 0z';

String _poly(String pts) {
  final v = pts.split(RegExp(r'[ ,]+')).map(double.parse).toList();
  final b = StringBuffer('M${v[0]} ${v[1]}');
  for (var k = 2; k < v.length; k += 2) {
    b.write('L${v[k]} ${v[k + 1]}');
  }
  b.write('z');
  return b.toString();
}

enum PackGlyph { bill, budget, split, debt, target }

const String _receipt = 'M18 8h28v46l-5-4-4.5 4-4.5-4-4.5 4-4.5-4-5 4z';
const String _leftBody = 'M8 54c0-9 6-16 14-16s14 7 14 16z';
const String _rightBody = 'M40 54c0-8 4-13 10-13s7 5 7 13z';
const String _arrowA = '8,12 36,12 36,4 56,19 36,34 36,26 8,26';
const String _arrowB = '56,38 28,38 28,30 8,45 28,60 28,52 56,52';

/// Gambar garis (Malam Biru dan Merah Panggung).
final Map<PackGlyph, List<String>> _outline = {
  PackGlyph.bill: [_receipt, 'M25 20h14M25 28h14M25 36h9'],
  PackGlyph.budget: [_circ(32, 32, 22), 'M32 10v22h22'],
  PackGlyph.split: [
    _circ(22, 22, 8),
    'M8 52c0-8 6-14 14-14s14 6 14 14',
    _circ(46, 26, 6),
    'M40 40c8 0 15 4 15 12'
  ],
  PackGlyph.debt: [
    'M10 22h38M38 12l10 10-10 10',
    'M54 42H16M26 32L16 42l10 10'
  ],
  PackGlyph.target: [
    _circ(32, 32, 22),
    _circ(32, 32, 12),
    _circ(32, 32, 3),
    'M32 32L54 10M46 10h8v8'
  ],
};

/// Bayangan keras Kuning Ceria (siluet berisi hitam).
final Map<PackGlyph, List<String>> _shadow = {
  PackGlyph.bill: [_receipt],
  PackGlyph.budget: [_circ(32, 32, 22)],
  PackGlyph.split: [
    _circ(22, 22, 8),
    _leftBody,
    _circ(46, 26, 6),
    _rightBody
  ],
  PackGlyph.debt: [_poly(_arrowA), _poly(_arrowB)],
  PackGlyph.target: [_circ(32, 32, 22)],
};

class _Op {
  const _Op(this.d, {this.fill, this.width, this.color});
  final String d;
  final Color? fill;
  final double? width;
  final Color? color;
}

const Color _ink = Color(0xFF14130A);
const Color _red = Color(0xFFE8212F);
const Color _yellow = Color(0xFFFFD92E);

/// Isi berwarna Kuning Ceria: putih dan merah dengan garis hitam tebal.
final Map<PackGlyph, List<_Op>> _fills = {
  PackGlyph.bill: [
    _Op(_receipt, fill: Colors.white),
    const _Op('M25 20h14M25 28h14M25 36h9', width: 3.5),
  ],
  PackGlyph.budget: [
    _Op(_circ(32, 32, 22), fill: Colors.white),
    const _Op('M32 32V10A22 22 0 0 1 54 32Z', fill: _red),
  ],
  PackGlyph.split: [
    _Op(_rightBody, fill: Colors.white),
    _Op(_circ(46, 26, 6), fill: Colors.white),
    _Op(_leftBody, fill: _red),
    _Op(_circ(22, 22, 8), fill: Colors.white),
  ],
  PackGlyph.debt: [
    _Op(_poly(_arrowA), fill: Colors.white),
    _Op(_poly(_arrowB), fill: _red),
  ],
  PackGlyph.target: [
    _Op(_circ(32, 32, 22), fill: Colors.white),
    _Op(_circ(32, 32, 14), fill: _red),
    _Op(_circ(32, 32, 6), fill: Colors.white),
    const _Op('M32 32L55 9', width: 7),
    const _Op('M32 32L55 9', width: 2.6, color: _yellow),
    const _Op('M46 8h10v10'),
  ],
};

final Map<String, Path> _pathCache = {};
Path _p(String d) => _pathCache.putIfAbsent(d, () => svgPath(d));

class _PackIconPainter extends CustomPainter {
  _PackIconPainter(this.pack, this.glyph);
  final String pack;
  final PackGlyph glyph;

  Paint _stroke(Color c, double w,
      {StrokeCap cap = StrokeCap.round, StrokeJoin join = StrokeJoin.round}) {
    return Paint()
      ..style = PaintingStyle.stroke
      ..color = c
      ..strokeWidth = w
      ..strokeCap = cap
      ..strokeJoin = join;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 96);
    switch (pack) {
      case 'malam':
        _malam(canvas);
      case 'kuning':
        _kuning(canvas);
      case 'merah':
        _merah(canvas);
    }
    canvas.restore();
  }

  void _malam(Canvas canvas) {
    canvas.drawPath(
        _p('M22 84q7-4 13 0t13 0t13 0t13 0'),
        _stroke(const Color(0xFF35E0FF).withValues(alpha: 0.35), 2));
    canvas.save();
    canvas.translate(16, 10);
    final glow =
        _stroke(const Color(0xFF35E0FF).withValues(alpha: 0.7), 7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final line = _stroke(const Color(0xFFBFF6FF), 2.6);
    for (final d in _outline[glyph]!) {
      canvas.drawPath(_p(d), glow);
    }
    for (final d in _outline[glyph]!) {
      canvas.drawPath(_p(d), line);
    }
    canvas.restore();
  }

  void _kuning(Canvas canvas) {
    final tile = RRect.fromRectAndRadius(
        const Rect.fromLTWH(3, 3, 90, 90), const Radius.circular(18));
    canvas.drawRRect(tile, Paint()..color = _yellow);
    canvas.drawRRect(tile, _stroke(_ink, 4.5));
    canvas.save();
    canvas.translate(19, 19);
    for (final d in _shadow[glyph]!) {
      canvas.drawPath(_p(d), Paint()..color = _ink);
      canvas.drawPath(_p(d), _stroke(_ink, 4.5));
    }
    canvas.restore();
    canvas.save();
    canvas.translate(16, 16);
    for (final op in _fills[glyph]!) {
      if (op.fill != null) {
        canvas.drawPath(_p(op.d), Paint()..color = op.fill!);
      }
      canvas.drawPath(_p(op.d), _stroke(op.color ?? _ink, op.width ?? 4.5));
    }
    canvas.restore();
  }

  void _merah(Canvas canvas) {
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
    void glyphAt(double dx, double dy, Color c) {
      canvas.save();
      canvas.translate(dx, dy);
      for (final d in _outline[glyph]!) {
        canvas.drawPath(
            _p(d),
            _stroke(c, 6,
                cap: StrokeCap.square, join: StrokeJoin.miter));
      }
      canvas.restore();
    }

    glyphAt(19, 18, const Color(0xFFE60012));
    glyphAt(16, 15, Colors.black);
  }

  @override
  bool shouldRepaint(_PackIconPainter old) =>
      old.pack != pack || old.glyph != glyph;
}

/// Ikon pintasan sesuai paket gaya aktif ([pack] bukan 'classic').
class PackIcon extends StatelessWidget {
  const PackIcon({super.key, required this.glyph, this.size = 52, this.pack});
  final PackGlyph glyph;
  final double size;

  /// Paket yang digambar; kosong = paket aktif.
  final String? pack;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size(size, size),
        painter: _PackIconPainter(pack ?? C.pack, glyph),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Pilihan Gaya
// -----------------------------------------------------------------------------

class StylePickerSheet extends StatelessWidget {
  const StylePickerSheet({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final sel = store.settings.stylePack;
    Widget option(String id, String name, String desc, Widget preview) {
      final on = sel == id;
      return Semantics(
        button: true,
        selected: on,
        label: tr(name),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            store.updateSettings((x) => x.stylePack = id);
            Navigator.pop(context);
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: on ? C.accentDark : C.line, width: on ? 2.5 : 1),
            ),
            child: Row(
              children: [
                preview,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: C.carbon)),
                      const SizedBox(height: 2),
                      Text(desc,
                          style: TextStyle(fontSize: 12, color: C.muted)),
                    ],
                  ),
                ),
                if (on)
                  Icon(Icons.check_circle_rounded, color: C.accentDark),
              ],
            ),
          ),
        ),
      );
    }

    Widget swatch(StylePack p) => SizedBox(
          width: 96,
          child: Row(
            children: [
              PackIcon(glyph: PackGlyph.bill, size: 44, pack: p.id),
              const SizedBox(width: 6),
              PackIcon(glyph: PackGlyph.target, size: 44, pack: p.id),
            ],
          ),
        );
    Widget classic() => SizedBox(
          width: 96,
          child: Row(
            children: [
              for (final ic in const [
                Icons.receipt_long_rounded,
                Icons.track_changes_rounded
              ])
                Container(
                  width: 44,
                  height: 44,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                      color: C.accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle),
                  child: Icon(ic, color: C.accentDark, size: 22),
                ),
            ],
          ),
        );
    return SheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Gaya',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ),
              IconButton(
                tooltip: tr('Tutup'),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          option('classic', 'Klasik',
              'Tampilan bawaan Infinity. Ikut Terang atau Gelap dan warna utama pilihanmu.', classic()),
          for (final p in kStylePacks.values) ...[
            const SizedBox(height: 10),
            option(p.id, p.name, p.desc, swatch(p)),
          ],
          const SizedBox(height: 12),
          Text(
              'Gaya selain Klasik mengatur warna, Terang atau Gelap, dan ikon pintasan sendiri. Pemasukan tetap hijau dan pengeluaran tetap merah.',
              style: TextStyle(fontSize: 12, color: C.muted)),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Pilihan Maskot
// -----------------------------------------------------------------------------

class MascotPickerSheet extends StatefulWidget {
  const MascotPickerSheet({super.key, required this.store});
  final AppStore store;

  @override
  State<MascotPickerSheet> createState() => _MascotPickerSheetState();
}

class _MascotPickerSheetState extends State<MascotPickerSheet> {
  bool _busy = false;

  String _nameOf(String skin) => switch (skin) {
        'auto' => 'Ikut paket',
        'owl' => 'Burung Hantu',
        'fox' => 'Rubah',
        'crow' => 'Gagak',
        'custom' => 'Gambar sendiri',
        _ => 'Klasik',
      };

  Future<void> _pickCustom() async {
    setState(() => _busy = true);
    try {
      final p = await pickAvatarImage();
      if (p != null) {
        final old = widget.store.settings.mascotCustomPath;
        if (old != null && old != p) _deleteFileQuiet(old);
        widget.store.updateSettings((x) {
          x.mascotCustomPath = p;
          x.mascotSkin = 'custom';
        });
        if (mounted) Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) snack(context, 'Gagal mengambil foto.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _choose(String skin) {
    if (skin == 'custom') {
      final path = widget.store.settings.mascotCustomPath;
      if (path == null || !File(path).existsSync()) {
        _pickCustom();
        return;
      }
    }
    widget.store.updateSettings((x) => x.mascotSkin = skin);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store.settings;
    final sel = s.mascotSkin;
    Widget tile(String skin) {
      final on = sel == skin;
      // "Ikut paket" menampilkan maskot paket gaya yang sedang aktif.
      final shown = skin == 'auto' ? (kPackSkin[s.stylePack] ?? 'classic') : skin;
      final Widget face;
      if (skin == 'custom' &&
          (s.mascotCustomPath == null ||
              !File(s.mascotCustomPath!).existsSync())) {
        face = Icon(Icons.add_photo_alternate_rounded,
            color: C.muted, size: 30);
      } else {
        face = mascotImage(shown, MascotMood.ok, 60, s.mascotCustomPath);
      }
      return Semantics(
        button: true,
        selected: on,
        label: tr(_nameOf(skin)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _busy ? null : () => _choose(skin),
          child: Container(
            width: 96,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: on ? C.accentDark : C.line, width: on ? 2.5 : 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                      color: skin == 'custom' ? C.line : mascotBase(shown),
                      shape: BoxShape.circle),
                  alignment: Alignment.center,
                  clipBehavior: Clip.antiAlias,
                  child: face,
                ),
                const SizedBox(height: 6),
                Text(_nameOf(skin),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                        color: C.carbon)),
              ],
            ),
          ),
        ),
      );
    }

    return SheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Maskot',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ),
              IconButton(
                tooltip: tr('Tutup'),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [for (final k in kMascotSkins) tile(k)],
          ),
          const SizedBox(height: 12),
          Text(
              'Maskot berganti ekspresi sesuai sisa jatah harianmu. Gambar sendiri hanya tersimpan di HP ini dan dipakai untuk semua suasana, ditandai lewat warna cincin.',
              style: TextStyle(fontSize: 12, color: C.muted)),
        ],
      ),
    );
  }
}
