part of '../main.dart';

// =============================================================================
// SHARED UI
// =============================================================================

void snack(BuildContext context, String message, {SnackBarAction? action}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(message),
    action: action,
    // Snackbar bertombol tetap hilang sendiri (tidak menetap).
    persist: false,
    duration: Duration(seconds: action == null ? 3 : 4),
  ));
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Ya',
  bool destructive = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal')),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: destructive ? C.redDark : C.accentDark,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20))),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Konfirmasi berbahaya: tombol baru aktif setelah user mengetik [word].
Future<bool> typedConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String word = 'HAPUS',
  String confirmLabel = 'Hapus',
}) async {
  final ctrl = TextEditingController();
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        final ok = ctrl.text.trim().toUpperCase() == word;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 14),
              Text.rich(TextSpan(children: [
                const TextSpan(text: 'Ketik '),
                TextSpan(
                    text: word,
                    style: TextStyle(
                        fontWeight: FontWeight.w900, color: C.redDark)),
                const TextSpan(text: ' untuk melanjutkan:'),
              ])),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setLocal(() {}),
                decoration: fieldDeco(word, accent: C.redDark),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal')),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: C.redDark,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20))),
              onPressed: ok ? () => Navigator.pop(ctx, true) : null,
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    ),
  );
  // ctrl tidak di-dispose di sini: dialog masih beranimasi keluar.
  return r ?? false;
}

/// Reset total: dipakai dari Lainnya dan dari Backup.
Future<void> confirmResetAll(BuildContext context, AppStore store) async {
  final ok = await typedConfirmDialog(context,
      title: 'Reset semua data?',
      message:
          'Semua transaksi, akun tambahan, template, budget, dan jadwal berulang akan dihapus permanen. Akun dasar dibuat ulang dengan saldo 0. PIN dan pengaturan keamanan tetap.\n\nSalin backup dulu kalau masih perlu.',
      confirmLabel: 'Reset');
  if (!ok || !context.mounted) return;
  store.clearAll();
  snack(context, 'Semua data dihapus. Mulai dari nol 🌱');
}

/// Padding isi halaman. Android 15+ menggambar app sampai ke balik tombol
/// navigasi sistem (edge-to-edge), jadi bawahnya ditambah tinggi bar itu.
EdgeInsets pagePad(BuildContext context, double bottom) => EdgeInsets.fromLTRB(
    16, 4, 16, bottom + MediaQuery.viewPaddingOf(context).bottom);

PreferredSizeWidget pageBar(String title, {List<Widget>? actions}) => AppBar(
      title: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.w900, fontSize: 19, color: C.carbon)),
      backgroundColor: C.bg,
      foregroundColor: C.carbon,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      actions: actions,
    );

InputDecoration fieldDeco(String label,
    {IconData? icon, String? prefix, String? helper, Color? accent}) {
  return InputDecoration(
    labelText: label,
    helperText: helper,
    helperMaxLines: 3,
    prefixIcon: icon == null ? null : Icon(icon),
    prefixText: prefix,
    filled: true,
    fillColor: C.bg,
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: C.line)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: accent ?? C.accentDark, width: 2)),
  );
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? C.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class CatIcon extends StatelessWidget {
  const CatIcon(
      {super.key, required this.icon, required this.color, this.size = 44});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: darken(color), size: size * 0.5),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: C.carbon)),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class SmallLabel extends StatelessWidget {
  const SmallLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w800, color: C.carbon));
  }
}

class FunProgressBar extends StatelessWidget {
  const FunProgressBar(
      {super.key, required this.value, required this.color, this.height = 14});

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final target = (value.isNaN || value.isInfinite) ? 0.0 : value.clamp(0.0, 1.0);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: C.line,
        borderRadius: BorderRadius.circular(height),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: target),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: v,
            heightFactor: 1,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(height),
                gradient:
                    LinearGradient(colors: [color.withValues(alpha: 0.7), color]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Segmented control serbaguna dengan warna per item.
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.colorOf,
    this.iconOf,
    this.dense = false,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;
  final Color Function(T)? colorOf;
  final IconData Function(T)? iconOf;
  final bool dense;

  Widget _item(T v) {
    final isSel = v == selected;
    final fg = isSel ? Colors.white : C.muted;
    final bg = isSel ? (colorOf?.call(v) ?? C.accentDark) : Colors.transparent;
    final icon = iconOf?.call(v);
    return Expanded(
      child: Semantics(
        button: true,
        selected: isSel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(v);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: EdgeInsets.symmetric(vertical: dense ? 9 : 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 15, color: fg),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(labelOf(v),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: dense ? 12 : 12.5,
                          fontWeight: FontWeight.w800,
                          color: fg)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: C.line),
      ),
      child: Row(children: values.map(_item).toList()),
    );
  }
}

/// Wadah bottom sheet bersudut membulat yang aman dari keyboard.
class SheetFrame extends StatelessWidget {
  const SheetFrame({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Align(
      alignment: Alignment.bottomCenter,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Container(
          decoration: BoxDecoration(
            color: C.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: C.line,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<T?> showSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => child,
  );
}

class ErrorBox extends StatelessWidget {
  const ErrorBox(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: C.redDark, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    color: C.redDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.color,
      this.icon});

  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 54,
      decoration: BoxDecoration(
        color: onPressed == null ? C.muted : (color ?? C.accentDark),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onPressed,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key, required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: C.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: C.accentDark, size: 30),
          ),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontWeight: FontWeight.w800, color: C.carbon)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(color: C.muted, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

/// Pemilih akun horizontal (bisa banyak akun).
class AccountPicker extends StatelessWidget {
  const AccountPicker({
    super.key,
    required this.store,
    required this.selectedId,
    required this.onSelected,
    required this.accent,
    this.disabledId,
    this.excludeTxId,
  });

  final AppStore store;
  final String selectedId;
  final String? disabledId;
  final String? excludeTxId;
  final Color accent;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: store.accounts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final a = store.accounts[i];
          final sel = a.id == selectedId;
          final disabled = a.id == disabledId;
          final bal = store.balanceOf(a.id, excludeTxId: excludeTxId);
          return Opacity(
            opacity: disabled ? 0.35 : 1,
            child: GestureDetector(
              onTap: disabled ? null : () => onSelected(a.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 128,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: sel ? accent.withValues(alpha: 0.1) : C.bg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: sel ? accent : C.line, width: sel ? 2 : 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(a.type.icon, color: darken(a.colorValue), size: 18),
                        const Spacer(),
                        if (sel)
                          Icon(Icons.check_circle_rounded,
                              color: accent, size: 16),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(a.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: C.carbon)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(money(bal, a.currency),
                          style: TextStyle(
                              fontSize: 11,
                              color: bal < 0 ? C.redDark : C.muted)),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class DonutChartPainter extends CustomPainter {
  DonutChartPainter(
      {required this.values, required this.colors, required this.progress});

  final List<double> values;
  final List<Color> colors;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 22.0;
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - stroke / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = C.line
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke);

    final total = values.fold(0.0, (s, v) => s + v);
    if (total <= 0) return;

    const gap = 0.03;
    final useGap = values.length > 1;
    var start = -math.pi / 2;
    final full = 2 * math.pi * progress;
    for (var i = 0; i < values.length; i++) {
      final sweep = full * (values[i] / total);
      final draw = useGap ? math.max(0.0, sweep - gap) : sweep;
      if (draw > 0) {
        canvas.drawArc(
            rect,
            start,
            draw,
            false,
            Paint()
              ..color = colors[i]
              ..style = PaintingStyle.stroke
              ..strokeWidth = stroke
              ..strokeCap = StrokeCap.butt);
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter old) {
    if (old.progress != progress || old.values.length != values.length) {
      return true;
    }
    for (var i = 0; i < values.length; i++) {
      if (old.values[i] != values[i] || old.colors[i] != colors[i]) return true;
    }
    return false;
  }
}

class TrendBucket {
  const TrendBucket(this.label, this.income, this.expense);
  final String label;
  final double income;
  final double expense;
}

class TrendChart extends StatelessWidget {
  const TrendChart({super.key, required this.buckets, this.height = 150});
  final List<TrendBucket> buckets;
  final double height;

  Widget _bar(double v, double maxV, Color c, double width) {
    final target = maxV <= 0 ? 0.0 : v / maxV;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, f, _) => Container(
        width: width,
        height: math.max(f * height, v > 0 ? 3.0 : 0.0),
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(width / 2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxV = buckets.fold(
        0.0, (m, b) => math.max(m, math.max(b.income, b.expense)));
    final barW = buckets.length > 8 ? 7.0 : 11.0;
    return Column(
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final b in buckets)
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _bar(b.income, maxV, C.green, barW),
                      const SizedBox(width: 2),
                      _bar(b.expense, maxV, C.red, barW),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final b in buckets)
              Expanded(
                child: Text(b.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(fontSize: 10, color: C.muted)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendDot(color: C.green, label: 'Pemasukan'),
            SizedBox(width: 16),
            _LegendDot(color: C.red, label: 'Pengeluaran'),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: C.muted)),
      ],
    );
  }
}
