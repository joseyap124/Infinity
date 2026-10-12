part of '../main.dart';

// =============================================================================
// BAHASA (v4.2): Indonesia, English, 简体中文.
//
// Teks di kode ditulis dalam bahasa Indonesia dan dipakai sebagai kunci. [tr]
// mencari terjemahannya; kalau tidak ada, teks Indonesia tampil apa adanya.
// Jadi terjemahan bisa ditambah bertahap tanpa merusak layar yang belum
// diterjemahkan.
//
// Kelas [Text] di bawah sengaja menutupi Text milik Flutter (main.dart
// menyembunyikan Text bawaan), supaya semua teks di app otomatis lewat [tr].
// =============================================================================

enum AppLang { id, en, zh }

/// Bahasa yang sedang dipakai. Diatur dari [AppSettings.lang].
final ValueNotifier<AppLang> gLang = ValueNotifier<AppLang>(AppLang.id);

AppLang langOf(String? code) => switch (code) {
      'en' => AppLang.en,
      'zh' => AppLang.zh,
      _ => AppLang.id,
    };

String langCode(AppLang l) => switch (l) {
      AppLang.en => 'en',
      AppLang.zh => 'zh',
      AppLang.id => 'id',
    };

/// Nama bahasa dalam bahasanya sendiri.
String langName(AppLang l) => switch (l) {
      AppLang.en => 'English',
      AppLang.zh => '简体中文',
      AppLang.id => 'Indonesia',
    };

/// Kode locale untuk intl (nama bulan dan hari).
String get gDateLoc => switch (gLang.value) {
      AppLang.en => 'en_US',
      AppLang.zh => 'zh_CN',
      AppLang.id => 'id_ID',
    };

/// Pola untuk teks yang berisi angka atau nama, mis. "12 transaksi".
/// [from] mencocokkan seluruh teks Indonesia; $1, $2 dst diisi dari grup.
class _Pat {
  const _Pat(this.from, this.en, this.zh);
  final String from;
  final String en;
  final String zh;
}

final Map<String, RegExp> _patCache = {};
final Map<String, String> _trCache = {};
AppLang _trCacheLang = AppLang.id;

/// Terjemahkan [id] (teks Indonesia). [args] mengisi {0}, {1}, dst.
String tr(String id, [List<Object?> args = const []]) {
  final lang = gLang.value;
  var s = id;
  if (lang != AppLang.id && id.isNotEmpty) {
    if (_trCacheLang != lang) {
      _trCache.clear();
      _trCacheLang = lang;
    }
    final cached = _trCache[id];
    if (cached != null) {
      s = cached;
    } else {
      final dict = lang == AppLang.en ? kEnStrings : kZhStrings;
      var found = dict[id];
      if (found == null) {
        for (final p in kPatterns) {
          final re = _patCache[p.from] ??= RegExp('^${p.from}\$');
          final m = re.firstMatch(id);
          if (m == null) continue;
          var t = lang == AppLang.en ? p.en : p.zh;
          for (var g = m.groupCount; g >= 1; g--) {
            t = t.replaceAll('\$$g', tr(m.group(g) ?? ''));
          }
          found = lang == AppLang.en ? _enSingular(t) : t;
          break;
        }
      }
      s = found ?? id;
      if (_trCache.length < 4000) _trCache[id] = s;
    }
  }
  if (args.isEmpty) return s;
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    s = s.replaceAll('{$i}', '$a');
  }
  if (lang == AppLang.en) s = _enSingular(s);
  return s;
}

const Map<String, String> _enPlurals = {
  'days': 'day',
  'months': 'month',
  'weeks': 'week',
  'years': 'year',
  'hours': 'hour',
  'seconds': 'second',
  'transactions': 'transaction',
  'reminders': 'reminder',
  'errors': 'error',
  'things': 'thing',
  'receivables': 'receivable',
  'notifications': 'notification',
  'installments': 'installment',
  'tries': 'try',
  'accounts': 'account',
  'templates': 'template',
  'events': 'event',
};
final RegExp _enOne = RegExp(r'(^|[^\d.,])1 (' + _enPlurals.keys.join('|') + r')\b');

/// English: "1 days" menjadi "1 day" untuk daftar kata benda yang dipakai di kamus.
String _enSingular(String s) {
  if (!s.contains('1 ')) return s;
  return s.replaceAllMapped(_enOne, (m) => '${m[1]}1 ${_enPlurals[m[2]] ?? m[2]}');
}

/// Bangun ulang semua layar yang sedang terbuka (dipanggil saat bahasa diganti),
/// tanpa menutup halaman yang sedang dibuka.
void rebuildAllApp() {
  void visit(Element e) {
    e.markNeedsBuild();
    e.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(visit);
}

/// Pengganti Text bawaan Flutter: isinya diterjemahkan lewat [tr].
class Text extends StatelessWidget {
  const Text(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : textSpan = null;

  const Text.rich(
    InlineSpan this.textSpan, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : data = null;

  final String? data;
  final InlineSpan? textSpan;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final ui.TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  @override
  Widget build(BuildContext context) {
    final span = textSpan;
    if (span != null) {
      return m.Text.rich(
        span,
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
    }
    return m.Text(
      tr(data ?? ''),
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}
