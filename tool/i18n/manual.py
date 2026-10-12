def sub(p,a,b,cnt=1):
    t=open(p,encoding='utf-8').read()
    assert a in t,(p,a[:50])
    t=t.replace(a,b,cnt); open(p,'w',encoding='utf-8').write(t)
p='lib/main.dart'
sub(p,"import 'package:flutter/material.dart';\n","import 'package:flutter/material.dart' hide Text;\n// Text bawaan dipakai lewat m.Text; Text milik app (47_bahasa.dart) menerjemahkan isinya.\nimport 'package:flutter/material.dart' as m show Text;\n")
sub(p,"part 'src/46_kesehatan_backup.dart';\n","part 'src/46_kesehatan_backup.dart';\npart 'src/47_bahasa.dart';\npart 'src/48_terjemahan_en.dart';\npart 'src/49_terjemahan_zh.dart';\n")
sub(p,"    await initializeDateFormatting('id_ID', null);\n","    await initializeDateFormatting('id_ID', null);\n    await initializeDateFormatting('en_US', null);\n    await initializeDateFormatting('zh_CN', null);\n")
m='lib/src/05_models.dart'
sub(m,"  String iconStyle = 'cartoon';\n","  String iconStyle = 'cartoon';\n\n  /// Bahasa tampilan: 'id' | 'en' | 'zh'.\n  String lang = 'id';\n")
sub(m,"        'iconStyle': iconStyle,\n","        'iconStyle': iconStyle,\n        if (lang != 'id') 'lang': lang,\n")
sub(m,"    s.iconStyle = _s(j['iconStyle']) == 'classic' ? 'classic' : 'cartoon';\n","    s.iconStyle = _s(j['iconStyle']) == 'classic' ? 'classic' : 'cartoon';\n    s.lang = const ['en', 'zh'].contains(_s(j['lang'])) ? _s(j['lang'])! : 'id';\n")
st='lib/src/07_store_seluruh_data_logika_bisnis.dart'
sub(st,"    settings.iconStyle = old.iconStyle;\n    settings.displayName = old.displayName;","    settings.iconStyle = old.iconStyle;\n    settings.lang = old.lang;\n    settings.displayName = old.displayName;")
sub(st,"    if (!has.containsKey('iconStyle')) settings.iconStyle = old.iconStyle;\n","    if (!has.containsKey('iconStyle')) settings.iconStyle = old.iconStyle;\n    if (!has.containsKey('lang')) settings.lang = old.lang;\n")
sh='lib/src/09_app_shell.dart'
sub(sh,"    gCartoon.value = store.settings.iconStyle != 'classic';\n    store.addListener(_syncTheme);","    gCartoon.value = store.settings.iconStyle != 'classic';\n    gLang.value = langOf(store.settings.lang);\n    store.addListener(_syncTheme);")
sub(sh,"""    appTextScale.value = store.settings.textScale;
    gCartoon.value = store.settings.iconStyle != 'classic';
  }""","""    appTextScale.value = store.settings.textScale;
    gCartoon.value = store.settings.iconStyle != 'classic';
    final lang = langOf(store.settings.lang);
    if (gLang.value != lang) {
      gLang.value = lang;
      // Semua teks dibaca ulang dengan bahasa baru, tanpa menutup halaman yang terbuka.
      WidgetsBinding.instance.addPostFrameCallback((_) => rebuildAllApp());
    }
  }""")
p='lib/src/43_rencana_pengaturan.dart'
sub(p,"""                    const SmallLabel('Gaya ikon kategori'),""","""                    const SmallLabel('Bahasa'),
                    const SizedBox(height: 8),
                    Segmented<String>(
                      values: const ['id', 'en', 'zh'],
                      selected: s.lang,
                      labelOf: (v) => langName(langOf(v)),
                      dense: true,
                      onChanged: (v) => store.updateSettings((x) => x.lang = v),
                    ),
                    const SizedBox(height: 6),
                    Text(
                        'English dan 简体中文 diterjemahkan bertahap. Yang belum diterjemahkan tetap tampil dalam bahasa Indonesia.',
                        style: TextStyle(fontSize: 12, color: C.muted)),
                    const SizedBox(height: 16),
                    const SmallLabel('Gaya ikon kategori'),""")
