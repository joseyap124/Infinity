"""Ikon celengan babi (desain sendiri) di latar gelap: vector adaptif + PNG lama."""
import os, sys
from PIL import Image, ImageDraw

RES = sys.argv[1]
PREVIEW = sys.argv[2]
BG = (22, 24, 29)        # #16181D
PINK = (255, 143, 177)   # #FF8FB1
PINK_D = (226, 94, 138)  # #E25E8A
DARK = (40, 30, 40)
GOLD = (255, 200, 61)    # #FFC83D
GOLD_D = (214, 150, 20)

# Geometri di kanvas 108x108 (zona aman adaptive icon ~ 21..87)
BODY = (54, 60, 22, 16)          # cx, cy, rx, ry
SNOUT = (77, 60, 6, 7)
EAR = [(61, 48), (64.5, 38.5), (71, 48.5)]
LEGS = [(40, 70, 47, 81), (59, 70, 66, 81)]
EYE = (67, 54, 2.2)
NOSTRILS = [(75.6, 58.2, 1.1), (75.6, 61.8, 1.1)]
SLOT = (47, 44.2, 61, 46.6)
COIN = (54, 33, 6.5)


def hexc(c):
    return '#FF%02X%02X%02X' % c


def ell(cx, cy, rx, ry):
    return 'M%g,%g a%g,%g 0 1,0 %g,0 a%g,%g 0 1,0 %g,0 z' % (cx - rx, cy, rx, ry, 2 * rx, rx, ry, -2 * rx)


def rrect(x1, y1, x2, y2, r):
    return ('M%g,%g h%g a%g,%g 0 0 1 %g,%g v%g a%g,%g 0 0 1 %g,%g h%g a%g,%g 0 0 1 %g,%g v%g a%g,%g 0 0 1 %g,%g z'
            % (x1 + r, y1, x2 - x1 - 2 * r, r, r, r, r, y2 - y1 - 2 * r, r, r, -r, r, -(x2 - x1 - 2 * r), r, r, -r, -r,
               -(y2 - y1 - 2 * r), r, r, r, -r))


paths = []
def P(d, fill):
    paths.append('    <path android:fillColor="%s" android:pathData="%s"/>' % (hexc(fill), d))

for l in LEGS:
    P(rrect(*l, 2.5), PINK_D)
P('M%g,%g L%g,%g L%g,%g z' % (*EAR[0], *EAR[1], *EAR[2]), PINK_D)
P(ell(*BODY), PINK)
P(ell(*SNOUT), PINK_D)
for n in NOSTRILS:
    P(ell(n[0], n[1], n[2], n[2]), DARK)
P(ell(EYE[0], EYE[1], EYE[2], EYE[2]), DARK)
P(rrect(*SLOT, 1.2), DARK)
P(ell(COIN[0], COIN[1], COIN[2], COIN[2]), GOLD)
P(ell(COIN[0], COIN[1], COIN[2] * 0.62, COIN[2] * 0.62), GOLD_D)
P(ell(COIN[0], COIN[1], COIN[2] * 0.45, COIN[2] * 0.45), GOLD)
tail = ('    <path android:strokeColor="%s" android:strokeWidth="2.4" android:strokeLineCap="round" '
        'android:fillColor="#00000000" android:pathData="M32.5,57 c-4,-0.5 -6,-4.5 -3,-6.5 c2.5,-1.5 4,1.5 1.5,3"/>' % hexc(PINK_D))
paths.insert(0, tail)

vec = ('<?xml version="1.0" encoding="utf-8"?>\n'
       '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
       '    android:width="108dp" android:height="108dp"\n'
       '    android:viewportWidth="108" android:viewportHeight="108">\n'
       + '\n'.join(paths) + '\n</vector>\n')
os.makedirs(os.path.join(RES, 'drawable'), exist_ok=True)
open(os.path.join(RES, 'drawable', 'ic_launcher_foreground.xml'), 'w').write(vec)
os.makedirs(os.path.join(RES, 'mipmap-anydpi-v26'), exist_ok=True)
adaptive = ('<?xml version="1.0" encoding="utf-8"?>\n'
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <background android:drawable="@color/ic_bg"/>\n'
            '    <foreground android:drawable="@drawable/ic_launcher_foreground"/>\n'
            '    <monochrome android:drawable="@drawable/ic_launcher_foreground"/>\n'
            '</adaptive-icon>\n')
open(os.path.join(RES, 'mipmap-anydpi-v26', 'ic_launcher.xml'), 'w').write(adaptive)


def render(size, rounded=True):
    S = 4  # supersample
    W = size * S
    img = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # PNG lama: latar penuh, konten diperbesar sedikit (crop zona 18..90)
    off, span = 18, 72
    k = W / span
    tx = lambda x: (x - off) * k
    if rounded:
        d.rounded_rectangle([0, 0, W - 1, W - 1], radius=int(W * 0.22), fill=BG)
    else:
        d.rectangle([0, 0, W, W], fill=BG)
    def E(cx, cy, rx, ry, c):
        d.ellipse([tx(cx - rx), tx(cy - ry), tx(cx + rx), tx(cy + ry)], fill=c)
    # ekor
    d.arc([tx(27.5), tx(50), tx(33.5), tx(57.5)], 90, 360, fill=PINK_D, width=int(2.4 * k))
    for l in LEGS:
        d.rounded_rectangle([tx(l[0]), tx(l[1]), tx(l[2]), tx(l[3])], radius=2.5 * k, fill=PINK_D)
    d.polygon([(tx(x), tx(y)) for x, y in EAR], fill=PINK_D)
    E(*BODY, PINK)
    E(*SNOUT, PINK_D)
    for n in NOSTRILS:
        E(n[0], n[1], n[2], n[2], DARK)
    E(EYE[0], EYE[1], EYE[2], EYE[2], DARK)
    d.rounded_rectangle([tx(SLOT[0]), tx(SLOT[1]), tx(SLOT[2]), tx(SLOT[3])], radius=1.2 * k, fill=DARK)
    E(COIN[0], COIN[1], COIN[2], COIN[2], GOLD)
    E(COIN[0], COIN[1], COIN[2] * .62, COIN[2] * .62, GOLD_D)
    E(COIN[0], COIN[1], COIN[2] * .45, COIN[2] * .45, GOLD)
    return img.resize((size, size), Image.LANCZOS)

for folder, px in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
    dd = os.path.join(RES, 'mipmap-' + folder)
    os.makedirs(dd, exist_ok=True)
    render(px).save(os.path.join(dd, 'ic_launcher.png'))
render(512).save(PREVIEW)
print('ok')
