part of '../main.dart';

// =============================================================================
// KALKULATOR
// =============================================================================

/// Evaluasi ekspresi sederhana dengan prioritas ×/÷ sebelum +/−.
double? evalExpression(String expr) {
  if (expr.isEmpty) return null;
  const ops = '+−×÷';
  final nums = <double>[];
  final opList = <String>[];
  var buf = '';
  for (final ch in expr.split('')) {
    if (ops.contains(ch)) {
      final v = double.tryParse(buf);
      if (v == null) return null;
      nums.add(v);
      opList.add(ch);
      buf = '';
    } else {
      buf += ch;
    }
  }
  if (buf.isEmpty) {
    if (opList.isEmpty) return null;
    opList.removeLast();
  } else {
    final v = double.tryParse(buf);
    if (v == null) return null;
    nums.add(v);
  }
  final n2 = <double>[nums.first];
  final o2 = <String>[];
  for (var i = 0; i < opList.length; i++) {
    final op = opList[i];
    final v = nums[i + 1];
    if (op == '×') {
      n2[n2.length - 1] = n2.last * v;
    } else if (op == '÷') {
      if (v == 0) return null;
      n2[n2.length - 1] = n2.last / v;
    } else {
      o2.add(op);
      n2.add(v);
    }
  }
  var r = n2.first;
  for (var i = 0; i < o2.length; i++) {
    r = o2[i] == '+' ? r + n2[i + 1] : r - n2[i + 1];
  }
  return r;
}

class CalculatorSheet extends StatefulWidget {
  const CalculatorSheet({super.key, this.initial = 0});
  final double initial;

  @override
  State<CalculatorSheet> createState() => _CalculatorSheetState();
}

class _CalculatorSheetState extends State<CalculatorSheet> {
  late String _expr;
  String? _error;

  static const _ops = '+−×÷';

  static String _fmt(double v) {
    if (v == v.roundToDouble()) return v.round().toString();
    var s = v.toStringAsFixed(2);
    while (s.endsWith('0')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return s;
  }

  @override
  void initState() {
    super.initState();
    _expr = widget.initial > 0 ? _fmt(widget.initial) : '';
  }

  String get _currentNumber {
    var i = _expr.length - 1;
    while (i >= 0 && !_ops.contains(_expr[i])) {
      i--;
    }
    return _expr.substring(i + 1);
  }

  void _press(String k) {
    HapticFeedback.selectionClick();
    setState(() {
      _error = null;
      if (k == 'C') {
        _expr = '';
      } else if (k == '⌫') {
        if (_expr.isNotEmpty) _expr = _expr.substring(0, _expr.length - 1);
      } else if (k == '=') {
        final v = evalExpression(_expr);
        if (v == null) {
          _error = 'Ekspresi belum lengkap';
        } else {
          _expr = _fmt(v);
        }
      } else if (_ops.contains(k)) {
        if (_expr.isEmpty) return;
        if (_ops.contains(_expr[_expr.length - 1])) {
          _expr = _expr.substring(0, _expr.length - 1) + k;
        } else {
          _expr += k;
        }
      } else if (k == '.') {
        if (_currentNumber.contains('.')) return;
        _expr += _currentNumber.isEmpty ? '0.' : '.';
      } else {
        if (_expr.length < 40) _expr += k;
      }
    });
  }

  void _use() {
    final v = evalExpression(_expr);
    if (v == null || v <= 0) {
      setState(() => _error = 'Hasil harus lebih dari 0');
      return;
    }
    Navigator.of(context).pop(v);
  }

  Widget _key(String k, {Color? bg, Color? fg, int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Material(
          color: bg ?? C.bg,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _press(k),
            child: SizedBox(
              height: 56,
              child: Center(
                child: Text(k,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: fg ?? C.carbon)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = evalExpression(_expr);
    final opBg = C.accent.withValues(alpha: 0.15);
    return SheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Kalkulator',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: C.bg, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_expr.isEmpty ? '0' : _expr,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                    _error ??
                        (preview == null ? ' ' : '= ${_plain.format(preview)}'),
                    style: TextStyle(
                        fontSize: 14,
                        color: _error != null ? C.redDark : C.muted,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            _key('C', fg: C.redDark),
            _key('⌫'),
            _key('÷', bg: opBg, fg: C.accentDark),
            _key('×', bg: opBg, fg: C.accentDark),
          ]),
          Row(children: [
            _key('7'),
            _key('8'),
            _key('9'),
            _key('−', bg: opBg, fg: C.accentDark),
          ]),
          Row(children: [
            _key('4'),
            _key('5'),
            _key('6'),
            _key('+', bg: opBg, fg: C.accentDark),
          ]),
          Row(children: [
            _key('1'),
            _key('2'),
            _key('3'),
            _key('.'),
          ]),
          Row(children: [
            _key('0'),
            _key('000'),
            _key('=', bg: C.toast, fg: Colors.white, flex: 2),
          ]),
          const SizedBox(height: 10),
          PrimaryButton(label: 'Pakai hasil', onPressed: _use),
        ],
      ),
    );
  }
}
