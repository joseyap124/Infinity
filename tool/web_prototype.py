"""Rapikan hasil `flutter build web` untuk dibuka di iPhone sebagai prototipe."""
import json, pathlib, re, shutil, sys

web = pathlib.Path(sys.argv[1])
root = pathlib.Path(__file__).resolve().parent.parent

# Ikon celengan untuk layar utama iPhone dan favicon.
icon = root / 'docs' / 'icon.png'
if icon.exists():
    for name in ('apple-touch-icon.png', 'favicon.png', 'icons/Icon-192.png', 'icons/Icon-maskable-192.png'):
        dst = web / name
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy(icon, dst)

idx = web / 'index.html'
html = idx.read_text(encoding='utf-8')
# Path relatif supaya bisa di-hosting di sub-folder mana pun.
html = re.sub(r'<base href="[^"]*">', '<base href="./">', html)
html = re.sub(r'<title>.*?</title>', '<title>Infinity</title>', html, flags=re.S)
extra = '''
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
  <meta name="apple-mobile-web-app-title" content="Infinity">
  <meta name="theme-color" content="#007A0E">
  <link rel="apple-touch-icon" href="apple-touch-icon.png">
'''
html = html.replace('</head>', extra + '</head>', 1)
idx.write_text(html, encoding='utf-8')

man = web / 'manifest.json'
if man.exists():
    m = json.loads(man.read_text(encoding='utf-8'))
    m.update(name='Infinity', short_name='Infinity', background_color='#121316',
             theme_color='#007A0E', description='Catatan keuangan (prototipe web)')
    man.write_text(json.dumps(m, indent=2), encoding='utf-8')
# Service worker tidak dipakai (halaman prototipe tidak mendukungnya).
boot = web / 'flutter_bootstrap.js'
if boot.exists():
    b = boot.read_text(encoding='utf-8')
    b = re.sub(r'_flutter\.loader\.load\(\{.*?\}\);\s*$', '_flutter.loader.load({});\n', b, flags=re.S)
    boot.write_text(b, encoding='utf-8')
for junk in ('flutter_service_worker.js', '.last_build_id', 'assets/AssetManifest.bin'):
    (web / junk).unlink(missing_ok=True)
print('web prototype siap:', web)
