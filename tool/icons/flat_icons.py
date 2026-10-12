# Ikon gaya Flat (v5.0): ilustrasi datar tanpa garis tepi, bayangan lembut di
# bawah, kanvas 64x64. Tiap ikon = string SVG bagian dalam. Dirender ke PNG
# 144px oleh build_flat.py.
SH = '<ellipse cx="32" cy="58.5" rx="19" ry="3" fill="#000" opacity="0.10"/>'

def S(d, w=3.2, c='#8A4A3A', extra=''):
    return f'<path d="{d}" fill="none" stroke="{c}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round" {extra}/>'
def P(d, f, extra=''): return f'<path d="{d}" fill="{f}" {extra}/>'
def E(cx, cy, rx, ry, f, extra=''): return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="{f}" {extra}/>'
def C(cx, cy, r, f, extra=''): return f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{f}" {extra}/>'
def R(x, y, w, h, rad, f, extra=''): return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rad}" fill="{f}" {extra}/>'

ICONS = {}
def icon(key):
    def deco(fn):
        ICONS[key] = fn()
        return fn
    return deco

@icon('food')
def _(): return (SH + S('M44 6L30 28', 3.2, '#FFF3D6') + S('M51 9L37 29', 3.2, '#FFF3D6') +
    P('M8 30H56Q56 55 32 55Q8 55 8 30Z', '#F4846B') + E(32, 30, 24, 8, '#FFF3D6') +
    S('M12 30Q18 20 24 30Q30 20 36 30Q42 20 48 30', 3.4, '#FFD98A') + E(40, 25, 5, 4, '#C75B43'))

@icon('coffee')
def _(): return (SH + S('M24 5Q19 11 25 16', 3, '#C9D6E2') + S('M35 3Q30 10 36 15', 3, '#C9D6E2') +
    S('M46 29H51Q58 29 58 37Q58 45 49 45', 4, '#4A8FBF') +
    P('M14 24H48V40Q48 53 31 53Q14 53 14 40Z', '#6BB6E6') + E(31, 24, 17, 5, '#FFFFFF') + E(31, 24, 13, 3.2, '#8B5E3C'))

@icon('car')
def _(): return (SH + P('M6 40V32Q6 28 10 27L16 16Q18 12 23 12H41Q46 12 48 16L54 27Q58 28 58 32V40Q58 44 54 44H10Q6 44 6 40Z', '#4C9BE8') +
    P('M19 17H31V27H13Z', '#D9EEFF') + P('M34 17H44L50 27H34Z', '#D9EEFF') +
    C(18, 44, 7, '#2B3A55') + C(46, 44, 7, '#2B3A55') + C(18, 44, 3, '#CFD8E3') + C(46, 44, 3, '#CFD8E3') +
    R(8, 33, 6, 4, 2, '#FFE58A') + R(50, 33, 6, 4, 2, '#FFB4A2'))

@icon('bag')
def _(): return (SH + S('M22 22V16Q22 7 32 7Q42 7 42 16V22', 3.4, '#E89B00') +
    P('M10 22H54L50 56H14Z', '#F2B90F') + P('M12 36H52L51 42H13Z', '#E89B00') + E(32, 29, 5, 3, '#FFE58A'))

@icon('bill')
def _(): return (SH + P('M14 6H50V54L45 50L40 54L35 50L30 54L25 50L20 54L14 50Z', '#FFFFFF') +
    P('M14 6H50V54L45 50L40 54L35 50L30 54L25 50L20 54L14 50Z', '#B8C7E6', 'opacity="0.35" transform="translate(2 2)"') +
    P('M14 6H50V54L45 50L40 54L35 50L30 54L25 50L20 54L14 50Z', '#FFFFFF') +
    R(20, 14, 24, 4, 2, '#6B7FD7') + R(20, 24, 24, 3, 1.5, '#C9D2EE') + R(20, 31, 24, 3, 1.5, '#C9D2EE') + R(20, 38, 14, 3, 1.5, '#C9D2EE') +
    R(36, 38, 8, 3, 1.5, '#F2B90F'))

@icon('health')
def _(): return (SH + R(8, 18, 48, 36, 8, '#EF5B5B') + S('M24 18V13Q24 9 28 9H36Q40 9 40 13V18', 3.4, '#C73B3B') +
    R(27, 26, 10, 20, 2, '#FFFFFF') + R(22, 31, 20, 10, 2, '#FFFFFF'))

@icon('school')
def _(): return (SH + P('M32 10L60 24L32 38L4 24Z', '#3F4C8F') + P('M16 33V44Q32 54 48 44V33L32 41Z', '#5C6BC0') +
    S('M54 27V42', 2.6, '#F2B90F') + C(54, 44, 3.2, '#F2B90F') + P('M32 10L60 24L32 38Z', '#4F5FB0'))

@icon('movie')
def _(): return (SH + R(8, 24, 48, 30, 5, '#2F3447') + P('M8 24L12 10L56 18L52 24Z', '#454B66') +
    P('M13 10L22 11.8L18.5 22L9.6 20.2Z', '#F2F2F2') + P('M25 12.5L34 14.3L30.5 24.5L21.6 22.7Z', '#F2B90F') +
    P('M37 15L46 16.8L42.5 27L33.6 25.2Z', '#F2F2F2') + P('M49 17.5L56 19V24H46Z', '#F2B90F') +
    P('M28 32L40 39L28 46Z', '#FFFFFF'))

@icon('saving')
def _(): return (SH + E(32, 36, 23, 18, '#F59BB6') + P('M50 30L58 26V38L51 38Z', '#F59BB6') + P('M14 22L20 14L26 24Z', '#F087A8') +
    P('M44 22L48 15L52 25Z', '#F087A8') + R(24, 52, 7, 6, 2, '#E36F95') + R(40, 52, 7, 6, 2, '#E36F95') +
    C(46, 32, 2.4, '#3A2A33') + R(26, 14, 14, 3.6, 1.8, '#C84F77') + C(32, 8, 6, '#F2B90F') + S('M30 8H34', 1.8, '#C99700') +
    E(54, 36, 3.2, 2.4, '#E36F95'))

@icon('salary')
def _(): return (SH + R(8, 20, 48, 32, 6, '#4CC38A') + P('M8 26L32 40L56 26V22Q56 20 54 20H10Q8 20 8 22Z', '#2E9E6B') +
    R(18, 8, 28, 24, 3, '#FFFFFF', 'transform="rotate(-6 32 20)"') +
    C(32, 19, 6, '#F2B90F', 'transform="rotate(-6 32 20)"') + P('M8 26L32 42L56 26V50Q56 52 54 52H10Q8 52 8 50Z', '#4CC38A'))

@icon('gift')
def _(): return (SH + R(8, 26, 48, 30, 5, '#F26F8C') + R(6, 18, 52, 12, 4, '#FF8FA8') + R(28, 18, 8, 38, 0, '#FFE58A') +
    P('M32 18Q22 4 14 10Q10 16 22 18Z', '#FFE58A') + P('M32 18Q42 4 50 10Q54 16 42 18Z', '#FFD257'))

@icon('home')
def _(): return (SH + R(12, 28, 40, 28, 4, '#FFE0B0') + P('M4 31L32 8L60 31L55 36L32 17L9 36Z', '#E8604C') +
    R(26, 38, 12, 18, 3, '#8B5E3C') + R(16, 33, 8, 8, 2, '#8FD0F5') + R(40, 33, 8, 8, 2, '#8FD0F5') + R(44, 10, 6, 12, 1.5, '#C94F3D'))

@icon('care')
def _(): return (SH + R(24, 8, 16, 7, 3, '#C084FC') + R(28, 3, 8, 6, 2, '#A855F7') + R(14, 15, 36, 40, 10, '#E9D5FF') +
    R(20, 25, 24, 20, 6, '#FFFFFF') + P('M32 30Q38 36 32 41Q26 36 32 30Z', '#C084FC') + R(14, 15, 36, 10, 6, '#D8B4FE'))

@icon('pill')
def _(): return (SH + '<g transform="rotate(-40 30 32)">' + R(6, 20, 48, 22, 11, '#FFFFFF') +
    P('M17 20H30V42H17Q6 42 6 31Q6 20 17 20Z', '#EF5B5B') + R(6, 20, 48, 22, 11, 'none', 'stroke="#E3E8F0" stroke-width="0"') +
    R(12, 24, 14, 3.5, 1.7, '#FFFFFF', 'opacity="0.55"') + '</g>' +
    C(48, 46, 10, '#FFD257') + C(48, 46, 10, '#F2B90F', 'opacity="0.0"') + S('M42 46H54', 2.6, '#E89B00') + C(45, 42.5, 2.2, '#FFF0B0'))

@icon('invest')
def _(): return (SH + E(26, 50, 20, 6, '#C99700') + E(26, 44, 20, 6, '#F2B90F') + E(26, 38, 20, 6, '#C99700') + E(26, 32, 20, 6, '#F2B90F') +
    E(26, 32, 12, 3, '#FFE58A') + S('M38 24L50 12', 4, '#2EAA3C') + S('M42 11H51V20', 4, '#2EAA3C'))

@icon('sos')
def _(): return (SH + C(32, 32, 24, '#FF6B5E') + C(32, 32, 10, '#FFFFFF') + C(32, 32, 10, '#EAF0F7') +
    P('M32 8A24 24 0 0 1 56 32H42A10 10 0 0 0 32 22Z', '#FFFFFF') + P('M32 56A24 24 0 0 1 8 32H22A10 10 0 0 0 32 42Z', '#FFFFFF') +
    C(32, 32, 10, '#FFFFFF', 'opacity="0"') + C(32, 32, 10, '#FBE7E4', 'opacity="0"'))

@icon('fuel')
def _(): return (SH + R(10, 8, 28, 48, 5, '#FF8A3D') + R(15, 14, 18, 14, 3, '#FFE3C7') + R(7, 52, 34, 6, 3, '#D86A1F') +
    S('M38 20H46Q50 20 50 24V42Q50 48 54 48Q58 48 58 42V28L52 22', 3.6, '#4B5563') + C(55, 20, 1, '#4B5563'))

@icon('bike')
def _(): return (SH + C(15, 42, 11, 'none', 'stroke="#2F3447" stroke-width="3.6"') + C(49, 42, 11, 'none', 'stroke="#2F3447" stroke-width="3.6"') +
    S('M15 42L26 24H42L49 42', 3.6, '#4CC38A') + S('M26 24L34 42H15', 3.6, '#2E9E6B') + S('M34 42L42 24', 3.6, '#4CC38A') +
    S('M22 20H29', 3.6, '#2F3447') + S('M42 24L40 16H46', 3.6, '#2F3447') + C(34, 42, 2.6, '#F2B90F'))

@icon('phone')
def _(): return (SH + R(16, 4, 32, 54, 7, '#3F4C8F') + R(20, 11, 24, 38, 3, '#8FD0F5') + P('M20 11H44V28L20 40Z', '#BDE5FB') +
    C(32, 54, 2.2, '#C9D2EE') + R(28, 6.5, 8, 1.8, 0.9, '#C9D2EE'))

@icon('pet')
def _(): return (SH + P('M32 30Q20 30 16 42Q14 52 24 52Q28 52 32 49Q36 52 40 52Q50 52 48 42Q44 30 32 30Z', '#C98B5A') +
    E(14, 28, 6, 8, '#C98B5A', 'transform="rotate(-20 14 28)"') + E(26, 16, 6, 8.5, '#C98B5A', 'transform="rotate(-8 26 16)"') +
    E(38, 16, 6, 8.5, '#C98B5A', 'transform="rotate(8 38 16)"') + E(50, 28, 6, 8, '#C98B5A', 'transform="rotate(20 50 28)"') +
    E(32, 42, 7, 5, '#F2D3B3'))
