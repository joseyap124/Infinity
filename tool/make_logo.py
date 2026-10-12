"""Menggambar logo Infinity (pita ∞ + koin Rp) jadi PNG untuk android_overlay.

Tidak dijalankan CI. Jalankan sendiri kalau logo diubah:
    pip install playwright && python3 tool/make_logo.py
Butuh Chromium (PLAYWRIGHT_BROWSERS_PATH atau path di CHROMIUM di bawah).
Hasil: drawable-nodpi (ikon adaptif, monokrom, splash) dan mipmap-* (ikon lama).
Latar ikon adaptif ada di drawable/ic_launcher_background.xml.
"""
import os
CHROMIUM = os.environ.get('CHROMIUM', '/opt/pw-browsers/chromium')
import math
D="#1F1B3A"
def split(p0,p1,p2,p3,t):
    lerp=lambda a,b:(a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t)
    a=lerp(p0,p1);b=lerp(p1,p2);c=lerp(p2,p3);d=lerp(a,b);e=lerp(b,c);f=lerp(d,e)
    return (p0,a,d,f),(f,e,c,p3)
def pth(seg): return f'M{seg[0][0]:.1f},{seg[0][1]:.1f} C{seg[1][0]:.1f},{seg[1][1]:.1f} {seg[2][0]:.1f},{seg[2][1]:.1f} {seg[3][0]:.1f},{seg[3][1]:.1f}'
S1=((60,128),(60,72),(104,72),(128,128)); S2=((128,128),(152,184),(196,184),(196,128))
S3=((196,128),(196,72),(152,72),(128,128)); S4=((128,128),(104,184),(60,184),(60,128))
FULL="M60,128 C60,72 104,72 128,128 C152,184 196,184 196,128 C196,72 152,72 128,128 C104,184 60,184 60,128 Z"
_,s3b=split(*S3,0.72); s4a,_=split(*S4,0.28)
WEAVE=pth(s3b)+' '+pth(s4a).replace('M','L',1) if False else None
w1=pth(s3b); w2=pth(s4a)
defs=f'''<defs>
<linearGradient id="rb" x1="60" y1="0" x2="196" y2="0" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#0FB5A6"/><stop offset=".55" stop-color="#4CC96A"/><stop offset="1" stop-color="#9BDB2D"/></linearGradient>
<linearGradient id="rb2" x1="0" y1="60" x2="0" y2="190" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#fff" stop-opacity=".55"/><stop offset=".5" stop-color="#fff" stop-opacity="0"/></linearGradient>
<linearGradient id="cn" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FFE766"/><stop offset="1" stop-color="#F5A81C"/></linearGradient>
<radialGradient id="bgc" cx=".3" cy=".25" r="1"><stop offset="0" stop-color="#FFFBEA"/><stop offset="1" stop-color="#FFE7A6"/></radialGradient>
<radialGradient id="bgm" cx=".3" cy=".25" r="1"><stop offset="0" stop-color="#F2FFFA"/><stop offset="1" stop-color="#BDEFDD"/></radialGradient>
<radialGradient id="bgs" cx=".3" cy=".25" r="1"><stop offset="0" stop-color="#F4FAFF"/><stop offset="1" stop-color="#BFE3FB"/></radialGradient>
<filter id="sh" x="-20%" y="-20%" width="140%" height="150%"><feDropShadow dx="0" dy="6" stdDeviation="5" flood-color="#1F1B3A" flood-opacity=".22"/></filter>
</defs>'''
def ribbon(wsc=1.0):
    return (f'<g filter="url(#sh)"><path d="{FULL}" fill="none" stroke="{D}" stroke-width="{33*wsc}" stroke-linejoin="round" stroke-linecap="round"/>'
     f'<path d="{FULL}" fill="none" stroke="url(#rb)" stroke-width="{23*wsc}" stroke-linejoin="round" stroke-linecap="round"/></g>'
     f'<path d="{FULL}" fill="none" stroke="url(#rb2)" stroke-width="{8*wsc}" stroke-linejoin="round" transform="translate(0 -5)"/>'
     # anyaman: untai kedua di atas
     f'<path d="{w1}" fill="none" stroke="{D}" stroke-width="{33*wsc}" stroke-linecap="butt"/><path d="{w2}" fill="none" stroke="{D}" stroke-width="{33*wsc}" stroke-linecap="butt"/>'
     f'<path d="{w1}" fill="none" stroke="url(#rb)" stroke-width="{23*wsc}" stroke-linecap="butt"/><path d="{w2}" fill="none" stroke="url(#rb)" stroke-width="{23*wsc}" stroke-linecap="butt"/>')
def coin(cx=196,cy=128,r=34,txt=True):
    t=f'<text x="{cx}" y="{cy+r*0.3}" font-size="{r*0.82}" font-weight="800" text-anchor="middle" fill="#9A5B05" font-family="DejaVu Sans">Rp</text>' if txt else ''
    return (f'<g filter="url(#sh)"><circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#cn)" stroke="{D}" stroke-width="6"/></g>'
      f'<circle cx="{cx}" cy="{cy}" r="{r*0.72}" fill="none" stroke="#E39A10" stroke-width="3.6"/>{t}'
      f'<path d="M{cx-r*0.55} {cy-r*0.28} q{r*0.12} -{r*0.5} {r*0.62} -{r*0.46}" stroke="#fff" stroke-opacity=".85" stroke-width="5" fill="none" stroke-linecap="round"/>')
def spark(x,y,r,c="#fff"):
    return f'<path d="M{x} {y-r} L{x+r*.26} {y-r*.26} L{x+r} {y} L{x+r*.26} {y+r*.26} L{x} {y+r} L{x-r*.26} {y+r*.26} L{x-r} {y} L{x-r*.26} {y-r*.26}Z" fill="{c}"/>'
def logo(bg='bgc',small=False,scale=1.0):
    g=f'{ribbon(1.08 if small else 1)}{coin(196,128,36 if small else 33,not small)}'
    if not small: g+=spark(214,78,8,"#fff")+spark(52,190,5,"#fff")+f'<circle cx="224" cy="150" r="3" fill="#fff" opacity=".9"/>'
    return f'<rect width="256" height="256" fill="url(#{bg})"/><g transform="translate(128 128) scale({scale}) translate(-128 -128)">{g}</g>'
def mono():
    return f'<path d="{FULL}" fill="none" stroke="{D}" stroke-width="26" stroke-linejoin="round"/><circle cx="196" cy="128" r="22" fill="{D}"/>'

R=os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'android_overlay', 'app', 'src', 'main', 'res')
from playwright.sync_api import sync_playwright
def page(inner,size,css='',bg='transparent'):
    return f'''<!doctype html><html><head><style>html,body{{margin:0;background:{bg};}}svg.o{{display:block;{css}}}</style></head><body>
<svg width="0" height="0" style="position:absolute">{defs}</svg>
<svg class="o" width="{size}" height="{size}" viewBox="0 0 256 256">{inner}</svg></body></html>'''
def g(inner,scale): return f'<g transform="translate(128 128) scale({scale}) translate(-128 -128)">{inner}</g>'
jobs=[]
full=ribbon()+coin(196,128,33)+spark(214,78,8)+spark(52,190,5)+'<circle cx="224" cy="150" r="3" fill="#fff" opacity=".9"/>'
jobs.append((f'{R}/drawable-nodpi/ic_launcher_foreground.png',432,g(full,.82),''))
jobs.append((f'{R}/drawable-nodpi/ic_launcher_monochrome.png',432,g(mono().replace(D,'#000'),.82),''))
jobs.append((f'{R}/drawable-nodpi/ic_splash_logo.png',432,g(ribbon()+coin(196,128,33),.66),''))
sizes={'mdpi':48,'hdpi':72,'xhdpi':96,'xxhdpi':144,'xxxhdpi':192}
for d,px in sizes.items():
    small=px<=72
    jobs.append((f'{R}/mipmap-{d}/ic_launcher.png',px,logo('bgc',small,.9),'border-radius:22%;overflow:hidden;'))
with sync_playwright() as p:
    b=p.chromium.launch(executable_path=CHROMIUM)
    for path,size,inner,css in jobs:
        os.makedirs(os.path.dirname(path),exist_ok=True)
        pg=b.new_page(viewport={'width':size,'height':size})
        pg.set_content(page(inner,size,css))
        pg.screenshot(path=path,omit_background=True,clip={'x':0,'y':0,'width':size,'height':size})
        pg.close()
    b.close()
print('ok')
