"""Render ikon Flat (flat_icons.py) ke PNG 144px dan tulis lib/src/54_ikon_flat.dart.
Pemakaian: python3 build_flat.py [--sheet out.png] [--write]
Butuh playwright (chromium) dan Pillow."""
import asyncio, base64, io, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from playwright.async_api import async_playwright
from PIL import Image
import flat_icons
try:
    import flat_icons2  # noqa: F401  (bagian kedua, mendaftar ke flat_icons.ICONS)
except ImportError:
    pass

SIZE = 144

def svg(inner):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="{SIZE}" height="{SIZE}">{inner}</svg>'

async def render(keys):
    out = {}
    async with async_playwright() as p:
        b = await p.chromium.launch()
        pg = await b.new_page(viewport={'width': SIZE, 'height': SIZE})
        for k in keys:
            await pg.set_content(f'<html><body style="margin:0;background:transparent">{svg(flat_icons.ICONS[k])}</body></html>')
            png = await pg.screenshot(omit_background=True, clip={'x': 0, 'y': 0, 'width': SIZE, 'height': SIZE})
            out[k] = Image.open(io.BytesIO(png)).convert('RGBA')
        await b.close()
    return out

def sheet(imgs, path, cols=10, bg=(255, 244, 229, 255)):
    keys = list(imgs)
    rows = (len(keys) + cols - 1) // cols
    cell = SIZE + 24
    W = Image.new('RGBA', (cols * cell, rows * cell), (255, 255, 255, 255))
    from PIL import ImageDraw
    d = ImageDraw.Draw(W)
    for i, k in enumerate(keys):
        x, y = (i % cols) * cell, (i // cols) * cell
        d.ellipse([x + 6, y + 4, x + cell - 6, y + cell - 20], fill=bg)
        W.paste(imgs[k], (x + 12, y + 8), imgs[k])
        d.text((x + 8, y + cell - 16), k, fill=(90, 90, 100, 255))
    W.save(path)

def png_bytes(im):
    q = im.quantize(colors=96, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)
    buf = io.BytesIO()
    q.save(buf, format='PNG', optimize=True)
    return buf.getvalue()

def main():
    keys = list(flat_icons.ICONS)
    imgs = asyncio.run(render(keys))
    if '--sheet' in sys.argv:
        sheet(imgs, sys.argv[sys.argv.index('--sheet') + 1])
    if '--write' in sys.argv:
        lines = ["part of '../main.dart';", '',
                 '// Ikon gaya Flat (v5.0): PNG 144px base64, dibuat oleh tool/icons/build_flat.py',
                 '// dari tool/icons/flat_icons*.py. Kunci sama dengan ikon Kartun; kunci yang',
                 '// tidak ada di sini memakai gambar Kartun.',
                 'const Map<String, String> kFlatB64 = <String, String>{']
        total = 0
        for k in keys:
            b = png_bytes(imgs[k]); total += len(b)
            lines.append(f"  '{k}': '{base64.b64encode(b).decode()}',")
        lines.append('};')
        lines.append('')
        open(os.path.join(os.path.dirname(__file__), '..', '..', 'lib', 'src', '54_ikon_flat.dart'), 'w').write('\n'.join(lines))
        print('ikon', len(keys), 'total byte PNG', total)

main()
