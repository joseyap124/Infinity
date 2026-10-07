"""Catatan rilis dari CHANGELOG.md.

  python3 tool/release_notes.py next 1.4 [judul-commit]  -> isi rilis baru (bagian "Berikutnya")
  python3 tool/release_notes.py sync                      -> perbarui teks rilis v1.x yang sudah ada
"""
import pathlib, re, subprocess, sys, tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
HEAD = ('Pasang `Infinity-v{v}.apk` dari HP, menimpa versi lama (data tetap aman). '
        'File `-hp-lama-32bit` hanya untuk HP lama yang gagal memasang versi biasa.\n\n')


def sections():
    text = (ROOT / 'CHANGELOG.md').read_text(encoding='utf-8')
    out = {}
    for m in re.finditer(r'^## (.+?)\n(.*?)(?=^## |\Z)', text, re.S | re.M):
        title = m.group(1).strip()
        key = 'next' if title.lower().startswith('berikutnya') else title.split()[0]
        out[key] = m.group(2).strip()
    return out


def main():
    cmd = sys.argv[1]
    secs = sections()
    if cmd == 'next':
        v = sys.argv[2]
        body = secs.get('next') or secs.get('v' + v) or ''
        if not body:
            title = sys.argv[3] if len(sys.argv) > 3 else ''
            body = f'Perubahan: {title}' if title else ''
        print(HEAD.format(v=v) + body)
    elif cmd == 'sync':
        for key, body in secs.items():
            if not re.fullmatch(r'v1\.\d+(\.\d+)?', key) or not body:
                continue
            ok = subprocess.run(['gh', 'release', 'view', key], capture_output=True).returncode == 0
            if not ok:
                continue
            with tempfile.NamedTemporaryFile('w', suffix='.md', delete=False, encoding='utf-8') as f:
                f.write(HEAD.format(v=key[1:]) + body)
            subprocess.run(['gh', 'release', 'edit', key, '--notes-file', f.name], check=True)
            print('diperbarui:', key)


main()
