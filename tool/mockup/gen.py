"""Gambar gabungan mockup Infinity (data contoh) -> docs/mockup-infinity.jpg.

Cara pakai (dari folder tool/mockup):
  npm i @fontsource/roboto@5 material-icons@1
  pip install playwright pillow && playwright install chromium
  python3 gen.py && python3 shot.py
Layar digambar ulang dengan HTML mengikuti tampilan app, bukan screenshot asli.
"""
import base64, pathlib

HERE = pathlib.Path(__file__).parent
FONT = HERE / 'node_modules/@fontsource/roboto/files'
ICON = HERE / 'node_modules/material-icons/iconfont/material-icons-round.woff2'
LOGO = HERE / '../../docs/icon.png'

def b64(p):
    return base64.b64encode(pathlib.Path(p).read_bytes()).decode()

fonts = ''.join(
    f"@font-face{{font-family:R;font-weight:{w};src:url(data:font/woff2;base64,{b64(FONT / f'roboto-latin-{w}-normal.woff2')})}}"
    for w in (400, 500, 700, 900))
fonts += f"@font-face{{font-family:MI;src:url(data:font/woff2;base64,{b64(ICON)})}}"
logo = f"data:image/png;base64,{b64(LOGO)}"

ACC = {  # nama: (terang, tua-terang, tua-gelap)
    'hijau': ('#00AA13', '#007A0E', '#1E9E33'),
    'tosca': ('#14B8A6', '#0F766E', '#139C8C'),
    'lavender': ('#C9B8F0', '#6E5BA8', '#9583D1'),
    'indigo': ('#6366F1', '#4338CA', '#7878F2'),
}

def i(name, cls=''):
    return f'<span class="mi {cls}">{name}</span>'

def money(v, sign=''):
    s = f"{abs(v):,.0f}".replace(',', '.')
    return f"{sign}Rp {s}"

def phone(inner, dark=False, acc='hijau', label='', sub='', light_status=False):
    a = ACC[acc]
    accd = a[2] if dark else a[1]
    lsx = ' lt' if light_status else ''
    return f'''<figure>
<div class="phone {'dark' if dark else ''}" style="--acc:{a[0]};--accd:{accd}">
<div class="screen"><div class="status{lsx}"><span>15.59</span><span>{i('signal_cellular_alt')}{i('wifi')}{i('battery_full')}</span></div>{inner}</div></div>
<figcaption><b>{label}</b><span>{sub}</span></figcaption></figure>'''

def nav(active=0):
    items = [('home', 'Beranda'), ('receipt_long', 'Riwayat'), ('pie_chart', 'Statistik'), ('grid_view', 'Lainnya')]
    out = ''.join(f'<div class="ni {"on" if k == active else ""}"><span class="pill">{i(ic)}</span><small>{t}</small></div>'
                  for k, (ic, t) in enumerate(items))
    return f'<div class="nav">{out}</div>'

def fab():
    return f'<div class="fab">{i("add")} Catat</div>'

def tx(icon, color, title, sub, amount, kind='exp'):
    col = {'exp': 'var(--red)', 'inc': 'var(--inc)', 'tf': 'var(--blue)'}[kind]
    sign = {'exp': '-', 'inc': '+', 'tf': ''}[kind]
    return f'''<div class="tx"><span class="ci" style="--c:{color}">{i(icon)}</span>
<div class="grow"><b>{title}</b><small>{sub}</small></div><b style="color:{col}">{money(amount, sign)}</b></div>'''

def header(name='Jose', line='Catat yang kecil, karena yang kecil itu yang sering bocor.', photo=False):
    av = '<span class="av photo"></span>' if photo else f'<span class="av"><img src="{logo}"></span>'
    return f'''<div class="hdr"><div class="row">{av}<div class="grow"><b class="hn">{name}</b><small class="hl">{line}</small></div>{i('visibility','w')}</div>
<div class="bal card"><div class="row"><span class="chip blue">Total Saldo Bersih</span><span class="grow"></span><span class="link">Kelola akun</span></div>
<div class="big">Rp 12.480.500</div>
<div class="accs">
<div class="acc" style="--c:#00AED6"><span class="ci sm" style="--c:#00AED6">{i('account_balance_wallet')}</span><div><small>GoPay</small><b>Rp 245.000</b></div></div>
<div class="acc" style="--c:#FFA000"><span class="ci sm" style="--c:#FFA000">{i('account_balance')}</span><div><small>Bank Jago</small><b>Rp 9.735.500</b></div></div>
<div class="acc" style="--c:#00AA13"><span class="ci sm" style="--c:#00AA13">{i('payments')}</span><div><small>Kantong</small><b>Rp 2.500.000</b></div></div></div>
<div class="hr"></div>
<div class="qa"><div><span style="background:var(--red)">{i('north_east')}</span>Bayar</div><div><span style="background:var(--inc)">{i('south_west')}</span>Terima</div><div><span style="background:var(--blue)">{i('swap_horiz')}</span>Transfer</div><div><span style="background:var(--amberd)">{i('track_changes')}</span>Budget</div></div>
</div></div>'''

def home(dark=False, acc='hijau', photo=False):
    body = header(photo=photo) + f'''<div class="pad">
<div class="card"><div class="row"><b>Anggaran Bulanan</b><span class="grow"></span><small class="mut">1-31 Okt</small></div>
<div class="row sp"><small class="mut">Terpakai Rp 1.835.000</small><small class="mut">dari Rp 3.000.000</small></div>
<div class="bar"><span style="width:61%;background:var(--amberd)"></span></div>
<div class="status-pill" style="color:var(--amberd)">Mulai Seret, Hati-hati! ⚠️</div></div>
<div class="row sp sect"><b>Transaksi Terakhir</b><span class="link">Lihat semua</span></div>
{tx('local_cafe', '#8D6E63', 'Kopi susu gula aren', 'Cafe / Restaurant ☕ · GoPay · 15.20', 24000)}
{tx('fastfood', '#FB8C00', 'Nasi goreng', 'Makan dan Minum 🍲 · Kantong · 12.10', 25000)}
{tx('payments', '#FFA000', 'Gaji Oktober', 'Gaji · Bank Jago · 09.00', 7500000, 'inc')}
</div>'''
    return phone(f'<div class="scroll">{body}</div>{fab()}{nav(0)}', dark, acc,
                 'Beranda · mode gelap' if dark else 'Beranda',
                 'Foto, nama & motivasi harian bisa diatur' if not dark else 'Ikut HP, kontras teks tetap jelas', light_status=True)

def form_rows(cat='Kebutuhan Pokok 📅 / Makan dan Minum 🍲'):
    rows = [('Tanggal', 'Rab, 07/10/2026', True), ('Jumlah', '<span class="amt">Rp 25.000</span>', False),
            ('Kategori', cat, True), ('Akun', 'Kantong Utama<small class="mut r">Rp 2.500.000</small>', True),
            ('Catatan', 'Nasi goreng', False), ('Deskripsi', '<span class="mut">Opsional</span>', False)]
    return ''.join(f'<div class="frow"><span class="fl">{a}</span><span class="fv">{b}</span>{i("chevron_right","mut") if c else ""}</div>' for a, b, c in rows)

def tabs(sel='Pengeluaran'):
    return '<div class="tabs">' + ''.join(
        f'<span class="{"on " + k if t == sel else ""}">{t}</span>'
        for t, k in [('Pemasukan', 'inc'), ('Pengeluaran', 'exp'), ('Transfer', 'tf')]) + '</div>'

def form():
    inner = f'''<div class="dim"></div><div class="sheet full"><div class="handle"></div>
<div class="row"><b class="h">Catat Pengeluaran</b><span class="grow"></span>{i('close')}</div>
{tabs()}{form_rows()}
<div class="chips"><span class="chipo">{i('content_paste')} Tempel struk</span><span class="chipo g">{i('bolt')} Kopi pagi</span><span class="chipo g">{i('bolt')} Ojol</span></div>
<label class="cb"><span class="box"></span>Simpan juga sebagai template catat cepat</label>
<div class="btn red">Simpan</div></div>'''
    return phone(inner, label='Catat transaksi', sub='Baris rapi ala Money Manager')

CATS = ['Kebutuhan Pokok 📅', 'Kesehatan dan Kebersihan 🏥', 'Education 🏫', 'Social Dan Relasi 💑', 'Hiburan dan Gaya Hidup 🛍️', 'Investasi 💰', 'Cicilan & Utang 💳', 'Darurat / Lain lain 🆘', 'Admin Bank 🏧']

def cat_panel():
    grid = ''.join(f'<div class="cell {"sel" if k == 0 else ""}">{c}{"<em>›</em>" if k in (0,1,2,3,4,5,7) else ""}</div>' for k, c in enumerate(CATS))
    inner = f'''<div class="ghost">{tabs()}{form_rows('<span class="mut">Pilih kategori</span>')}</div><div class="dim"></div>
<div class="sheet panel"><div class="row ph"><b>Kategori</b><span class="grow"></span>{i('close')}</div><div class="grid3">{grid}</div></div>'''
    return phone(inner, label='Pilih kategori', sub='Langsung muncul di bawah, dekat jempol')

def sub_panel():
    left = ''.join(f'<div class="li {"on" if k == 0 else ""}">{c}</div>' for k, c in enumerate(CATS[:7]))
    subs = ['Umum (Kebutuhan Pokok 📅)', 'Makan dan Minum 🍲', 'Transportasi 🚕', 'Bills (Listrik, Air, Kuota) 💡', 'Kos / Asrama 🏠', 'Keperluan Rumah 🧺']
    right = ''.join(f'<div class="li2 {"on" if k == 1 else ""}">{c}{i("check","ok") if k == 1 else ""}</div>' for k, c in enumerate(subs))
    inner = f'''<div class="ghost">{tabs()}{form_rows('<span class="mut">Pilih kategori</span>')}</div><div class="dim"></div>
<div class="sheet panel"><div class="row ph">{i('arrow_back')}<b>Kategori</b><span class="grow"></span>{i('close')}</div><div class="split"><div class="l">{left}</div><div class="r">{right}</div></div></div>'''
    return phone(inner, label='Sub-kategori', sub='Induk di kiri, sub di kanan, 2 ketukan')

def history():
    def day(d, tot, items):
        return f'<div class="row sp day"><b>{d}</b><small class="mut">{tot}</small></div>' + ''.join(items)
    inner = f'''<div class="scroll pad top"><div class="row"><b class="h1">Riwayat</b><span class="grow"></span><span class="seg2"><span class="on">{i('list')}</span><span>{i('calendar_month')}</span></span></div>
<div class="search">{i('search','mut')} <span class="mut">Cari transaksi</span></div>
<div class="fchips"><span>Hari Ini</span><span>Minggu Ini</span><span class="on">Bulan Ini</span><span>Semua</span></div>
<div class="sum3"><div><small>Pemasukan</small><b style="color:var(--inc)">+Rp 7.500.000</b></div><div><small>Pengeluaran</small><b style="color:var(--red)">-Rp 1.835.000</b></div></div>
{day('Rabu, 7 Okt', '-Rp 49.000', [tx('local_cafe', '#8D6E63', 'Kopi susu gula aren', 'Cafe / Restaurant ☕ · GoPay', 24000), tx('fastfood', '#FB8C00', 'Nasi goreng', 'Makan dan Minum 🍲 · Kantong', 25000)])}
{day('Selasa, 6 Okt', '-Rp 337.000', [tx('directions_car', '#00AA13', 'GoRide ke kantor', 'Transportasi 🚕 · GoPay', 17000), tx('receipt', '#5C6BC0', 'Kuota bulanan', 'Bills 💡 · Bank Jago', 120000), tx('swap_horiz', '#007A94', 'Isi saldo GoPay', 'Bank Jago → GoPay', 200000, 'tf')])}
{day('Kamis, 1 Okt', '+Rp 7.500.000', [tx('payments', '#FFA000', 'Gaji Oktober', 'Gaji · Bank Jago', 7500000, 'inc')])}
</div>{fab()}{nav(1)}'''
    return phone(inner, label='Riwayat', sub='Cari, filter, total per hari')

def calendar():
    days = ''
    vals = {1: (7500, 0), 3: (0, 86), 4: (0, 152), 6: (0, 337), 7: (0, 49)}
    cells = ['', '', ''] + list(range(1, 32))
    for k, d in enumerate(cells):
        if d == '':
            days += '<div class="cd"></div>'; continue
        v = vals.get(d)
        extra = ''
        if v:
            if v[0]: extra += f'<i class="pi">+{v[0]/1000:.1f}jt</i>'.replace('.0jt', 'jt').replace('7.5jt', '7,5jt')
            if v[1]: extra += f'<i class="ne">-{v[1]}rb</i>'
        days += f'<div class="cd {"today" if d == 7 else ""}"><b>{d}</b>{extra}</div>'
    head = ''.join(f'<span>{d}</span>' for d in ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'])
    inner = f'''<div class="scroll pad top"><div class="row"><b class="h1">Riwayat</b><span class="grow"></span><span class="seg2"><span>{i('list')}</span><span class="on">{i('calendar_month')}</span></span></div>
<div class="row sp mon">{i('chevron_left')}<b>Oktober 2026</b>{i('chevron_right')}</div>
<div class="card cal"><div class="wk">{head}</div><div class="cg">{days}</div></div>
<div class="row sp day"><b>Rabu, 7 Okt</b><small class="mut">-Rp 49.000</small></div>
{tx('local_cafe', '#8D6E63', 'Kopi susu gula aren', 'Cafe / Restaurant ☕ · GoPay', 24000)}
{tx('fastfood', '#FB8C00', 'Nasi goreng', 'Makan dan Minum 🍲 · Kantong', 25000)}</div>{fab()}{nav(1)}'''
    return phone(inner, label='Kalender', sub='Masuk & keluar per tanggal')

def stats():
    segs = [('Kebutuhan Pokok', 42, '#FB8C00'), ('Hiburan', 23, '#E91E63'), ('Kesehatan', 14, '#EF5350'), ('Education', 11, '#5C6BC0'), ('Lainnya', 10, '#546E7A')]
    grad, acc = [], 0
    for _, p, c in segs:
        grad.append(f'{c} {acc}% {acc + p}%'); acc += p
    rows = ''.join(f'<div class="srow"><span class="dot" style="background:{c}"></span><span class="grow">{n}</span><small class="mut">{p}%</small><b>{money(1835000 * p / 100)}</b></div><div class="bar thin"><span style="width:{p * 2}%;background:{c}"></span></div>' for n, p, c in segs)
    inner = f'''<div class="scroll pad top"><b class="h1">Statistik</b>
<div class="seg"><span>Mingguan</span><span class="on">Bulanan</span><span>Tahunan</span></div>
<div class="row sp mon">{i('chevron_left')}<b>Oktober 2026</b>{i('chevron_right')}</div>
<div class="sum3"><div><small>Pemasukan</small><b style="color:var(--inc)">+Rp 7.500.000</b></div><div><small>Pengeluaran</small><b style="color:var(--red)">-Rp 1.835.000</b></div></div>
<div class="card"><div class="seg sm"><span>Pemasukan</span><span class="on r">Pengeluaran</span></div>
<div class="donut" style="background:conic-gradient({','.join(grad)})"><div><small class="mut">Total</small><b>Rp 1.835.000</b></div></div>{rows}</div></div>{nav(2)}'''
    return phone(inner, label='Statistik', sub='Per kategori, mingguan/bulanan/tahunan')

def appearance(acc='lavender'):
    sw = [('Hijau', '#007A0E'), ('Tosca', '#0F766E'), ('Biru', '#1D4ED8'), ('Indigo', '#4338CA'), ('Ungu', '#7E22CE'), ('Oranye', '#C2410C'), ('Pink', '#BE185D'), ('Grafit', '#334155'),
          ('Sage', '#4F7F62'), ('Lavender', '#6E5BA8'), ('Rose', '#A9506F'), ('Peach', '#A65A2A'), ('Langit', '#3C6F97'), ('Mint', '#3B7F72')]
    sws = ''.join(f'<div class="sw"><span style="background:{c}" class="{"on" if n == "Lavender" else ""}">{i("check") if n == "Lavender" else ""}</span><small>{n}</small></div>' for n, c in sw)
    tiles = [('account_balance_wallet', '#00AED6', 'Akun & Dompet', '4 akun'), ('category', '#E91E63', 'Kategori', '38 kategori & sub-kategori'), ('track_changes', '#FFA000', 'Anggaran', 'Bulanan · Rp 3.000.000')]
    t = ''.join(f'<div class="tile"><span class="ci" style="--c:{c}">{i(ic)}</span><div class="grow"><b>{a}</b><small class="mut">{b}</small></div>{i("chevron_right","mut")}</div>' for ic, c, a, b in tiles)
    inner = f'''<div class="scroll pad top"><b class="h1">Lainnya</b>
<div class="card"><b class="lbl">Tampilan</b><div class="seg"><span class="on">Ikut HP</span><span>Terang</span><span>Gelap</span></div>
<b class="lbl">Warna utama</b><div class="sws">{sws}</div></div><div class="card">{t}</div></div>{nav(3)}'''
    return phone(inner, acc=acc, label='Tampilan', sub='Terang/gelap + 14 warna (6 pastel)')

def profile():
    inner = f'''<div class="ghost2">{header()}</div><div class="dim"></div><div class="sheet"><div class="handle"></div>
<div class="row"><b class="h">Atur Beranda</b><span class="grow"></span>{i('close')}</div>
<div class="row prof"><span class="ring"><span class="av big photo"></span></span><div><span class="tonal">{i('photo_library')} Ganti foto</span><span class="link">Pakai logo</span></div></div>
<div class="field"><small>Nama di Beranda</small>Jose</div>
<b class="lbl">Kalimat di bawah nama</b><div class="seg"><span>Sapaan jam</span><span>Tulis sendiri</span><span class="on">Motivasi</span></div>
<div class="note">Contoh hari ini: "Catat yang kecil, karena yang kecil itu yang sering bocor."<br>Berganti otomatis setiap hari.</div>
<div class="btn">Simpan</div></div>'''
    return phone(inner, acc='tosca', label='Atur Beranda', sub='Foto dari galeri, nama, sapaan/motivasi')

def importer():
    inner = f'''<div class="appbar">{i('arrow_back')}<b>Import Money Manager</b></div><div class="scroll pad">
<div class="card"><b>Cara ekspor dari Money Manager</b><small class="mut blk">1. Money Manager › Backup › Ekspor ke Excel<br>2. Pilih rentang tanggal, simpan .xlsx<br>3. Kembali ke sini, tekan Pilih file</small><div class="btn">{i('upload_file')} Pilih file Excel</div></div>
<div class="card"><b>Pratinjau</b><small class="mut blk">Money_Manager_10-7-26.xlsx</small>
<div class="kv"><span>Rentang</span><b>1 Agu 2026 - 6 Okt 2026</b></div><div class="kv"><span>Pengeluaran</span><b>97</b></div><div class="kv"><span>Pemasukan</span><b>7</b></div><div class="kv"><span>Transfer</span><b>22</b></div>
<small class="blk">Kategori baru: Jajan 🌮, Keperluan</small>
<div class="warn">Saldo akun dihitung dari transaksi yang diimpor. Cocokkan saldo awal di Akun &amp; Dompet.</div>
<div class="btn">{i('download_done')} Import 126 transaksi</div></div></div>'''
    return phone(inner, acc='indigo', label='Import Money Manager', sub='Dari file Excel, akun & kategori dicocokkan')

def widget_notif():
    inner = f'''<div class="wall"><div class="shade"><div class="row sp nt"><b>15.59</b><small>Rab, 7 Okt</small></div>
<div class="notif"><div class="row nh"><span class="pig"><img src="{logo}"></span><small>Infinity</small></div>
<div class="qb">{i('article')}<i></i>{i('search')}<i></i>{i('star_border')}<i></i>{i('add')}</div></div></div>
<div class="wdg"><div class="row sp"><b class="wt">∞ Infinity</b><small>Okt 2026</small></div><div class="wb">Rp 12.480.500</div>
<div class="row sp"><b style="color:var(--inc)">Masuk Rp 7,5jt</b><b style="color:var(--red)">Keluar Rp 1,8jt</b></div><small class="ws">Sisa anggaran Rp 1.165.000 (39%)</small>
<div class="wbtn"><span style="background:var(--red)">− Keluar</span><span style="background:var(--inc)">+ Masuk</span><span style="background:var(--blue)">⇄ Transfer</span></div></div>
<div class="apps"><span><img src="{logo}"><small>Infinity</small></span></div></div>'''
    return phone(inner, dark=True, label='Widget & pintasan', sub='Panel notifikasi 4 ikon + widget 4×2')

CSS = '''
*{box-sizing:border-box;margin:0}body{font-family:R,sans-serif;background:linear-gradient(160deg,#E8F7EA,#F3EEFB 55%,#FDEFF3);width:1800px;padding:44px 40px 50px;color:#1C1C1C}
.mi{font-family:MI;font-size:20px;line-height:1;display:inline-block;vertical-align:middle;font-feature-settings:'liga'}
.top-h{display:flex;align-items:center;gap:22px;margin:0 6px 34px}.top-h img{width:96px;height:96px;border-radius:24px;box-shadow:0 6px 18px #0002}
.top-h h1{font-size:64px;font-weight:900;letter-spacing:-1px}.top-h p{font-size:22px;color:#5B6270}
.grid{display:grid;grid-template-columns:repeat(4,1fr);gap:34px 20px}
figure{display:flex;flex-direction:column;align-items:center}figcaption{text-align:center;margin-top:14px}figcaption b{display:block;font-size:20px}figcaption span{font-size:15px;color:#5B6270}
.phone{--bg:#F8F9FA;--sf:#fff;--tx:#1C1C1C;--mu:#5B6270;--ln:#E9ECEF;--red:#D61F2E;--inc:#007A0E;--blue:#007A94;--amberd:#A35A00;width:400px;height:840px;border-radius:46px;background:#111;padding:9px;box-shadow:0 18px 40px #0003}
.phone.dark{--bg:#121316;--sf:#1E2024;--tx:#ECEDEF;--mu:#A3A9B4;--ln:#2E3137;--red:#EC5258;--inc:#1E9E33;--blue:#1497B5;--amberd:#D08A1E}
.screen{position:relative;width:100%;height:100%;border-radius:38px;overflow:hidden;background:var(--bg);color:var(--tx);font-size:13px}
.status{position:absolute;top:0;left:0;right:0;height:30px;display:flex;justify-content:space-between;align-items:center;padding:0 24px;font-size:12px;font-weight:500;z-index:9;color:var(--tx)}.status .mi{font-size:14px}.status.lt{color:#fff}
.row{display:flex;align-items:center;gap:8px}.sp{justify-content:space-between}.grow{flex:1;min-width:0}.mut{color:var(--mu)}small{font-size:11px}.blk{display:block;margin:4px 0 8px;line-height:1.5}
.scroll{position:absolute;inset:0;overflow:hidden}.pad{padding:0 14px}.top{padding-top:40px}
.hdr{background:var(--accd);border-radius:0 0 30px 30px;padding:38px 14px 12px;color:#fff}.hdr .w{color:#fff}
.av{width:38px;height:38px;border-radius:50%;background:#fff;border:2px solid #fff;display:flex;align-items:center;justify-content:center;overflow:hidden;flex:none}.av img{width:100%;height:100%}
.av.photo{background:radial-gradient(circle at 50% 38%,#F2C6A0 0 20%,transparent 21%),radial-gradient(circle at 50% 105%,#5A6B8C 0 42%,transparent 43%),linear-gradient(#BFD9EE,#E6F0F8)}
.hn{display:block;font-size:16px;font-weight:900}.hl{display:block;font-size:11.5px;line-height:1.25;opacity:.95}
.card{background:var(--sf);border-radius:22px;padding:12px 14px;margin-bottom:10px}.bal{margin-top:10px;color:var(--tx)}
.chip{font-size:10.5px;font-weight:800;padding:3px 9px;border-radius:12px}.chip.blue{background:#00AED622;color:var(--blue)}.link{color:var(--accd);font-weight:700;font-size:12px}
.big{font-size:24px;font-weight:900;margin:4px 0 8px}.accs{display:flex;gap:7px;overflow:hidden}.acc{flex:none;width:150px;height:52px;border-radius:18px;padding:0 9px;display:flex;align-items:center;gap:7px;background:color-mix(in srgb,var(--c) 9%,transparent)}
.acc small{display:block;color:var(--mu)}.acc b{font-size:12.5px}.ci{--c:#888;width:40px;height:40px;border-radius:50%;flex:none;display:flex;align-items:center;justify-content:center;background:color-mix(in srgb,var(--c) 15%,transparent);color:var(--c)}.ci.sm{width:30px;height:30px}.ci.sm .mi{font-size:15px}
.dark .ci{color:color-mix(in srgb,var(--c) 70%,white)}
.hr{height:1px;background:var(--ln);margin:9px 0 7px}.qa{display:flex}.qa div{flex:1;display:flex;flex-direction:column;align-items:center;gap:4px;font-size:12px;font-weight:700}.qa span{width:40px;height:40px;border-radius:14px;display:flex;align-items:center;justify-content:center;color:#fff}
.pad .card:first-child{margin-top:12px}.bar{height:10px;border-radius:6px;background:var(--ln);overflow:hidden;margin:6px 0}.bar span{display:block;height:100%;border-radius:6px}.bar.thin{height:5px;margin:2px 0 8px}
.status-pill{font-weight:800;font-size:12px}.sect{margin:12px 2px 6px}.sect b{font-size:15px}
.tx{display:flex;align-items:center;gap:10px;background:var(--sf);border-radius:20px;padding:10px 12px;margin-bottom:7px}.tx b{font-size:13px}.tx small{display:block;color:var(--mu);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.fab{position:absolute;right:16px;bottom:96px;background:var(--accd);color:#fff;border-radius:18px;padding:14px 18px;font-weight:800;font-size:14px;box-shadow:0 6px 14px #0003;display:flex;gap:6px;align-items:center}
.nav{position:absolute;left:0;right:0;bottom:0;height:80px;background:var(--sf);display:flex;padding-top:10px;border-top:1px solid var(--ln)}.ni{flex:1;display:flex;flex-direction:column;align-items:center;gap:3px;color:var(--mu)}.ni small{font-size:11.5px;font-weight:600}
.pill{width:58px;height:30px;border-radius:15px;display:flex;align-items:center;justify-content:center}.ni.on{color:var(--tx)}.ni.on .pill{background:color-mix(in srgb,var(--acc) 22%,transparent)}
.dim{position:absolute;inset:0;background:#0007}.sheet{position:absolute;left:0;right:0;bottom:0;background:var(--sf);border-radius:28px 28px 0 0;padding:10px 18px 22px}.sheet.full{top:70px}.handle{width:40px;height:4px;border-radius:2px;background:var(--ln);margin:0 auto 10px}
.h{font-size:18px;font-weight:900}.h1{font-size:24px;font-weight:900;display:block;margin-bottom:10px}
.tabs{display:flex;gap:6px;margin:10px 0 4px}.tabs span{flex:1;height:40px;border-radius:14px;border:1px solid var(--ln);display:flex;align-items:center;justify-content:center;font-weight:800;color:var(--mu);font-size:13px}
.tabs .on.exp{border:1.6px solid var(--red);color:var(--red);background:color-mix(in srgb,var(--red) 8%,transparent)}
.frow{display:flex;align-items:center;min-height:50px;border-bottom:1px solid var(--ln);gap:6px}.fl{width:80px;color:var(--mu);font-size:14px;font-weight:500}.fv{flex:1;font-size:14.5px;font-weight:700;display:flex;align-items:center}.fv .r{margin-left:auto;font-weight:400}.amt{font-size:20px;font-weight:900;color:var(--red)}
.chips{display:flex;gap:6px;margin:12px 0 4px}.chipo{border:1px solid var(--red);color:var(--tx);border-radius:18px;padding:7px 10px;font-weight:700;font-size:12px}.chipo .mi{font-size:15px;color:var(--red)}.chipo.g{border-color:var(--ln)}.chipo.g .mi{color:var(--tx)}
.cb{display:flex;gap:10px;align-items:center;margin:10px 0 14px;font-size:13px}.box{width:18px;height:18px;border:2px solid var(--mu);border-radius:3px}
.btn{height:52px;border-radius:22px;background:var(--accd);color:#fff;font-weight:800;font-size:15px;display:flex;align-items:center;justify-content:center;gap:6px;margin-top:10px}.btn.red{background:var(--red)}
.ghost{position:absolute;top:70px;left:0;right:0;bottom:0;background:var(--sf);border-radius:28px 28px 0 0;padding:14px 18px}.ghost2{position:absolute;inset:0}
.panel{padding:0}.ph{padding:10px 12px 8px 16px;border-bottom:1px solid var(--ln)}.ph b{font-size:16px;font-weight:900}
.grid3{display:grid;grid-template-columns:repeat(3,1fr)}.cell{height:68px;border-right:1px solid var(--ln);border-bottom:1px solid var(--ln);display:flex;align-items:center;justify-content:center;text-align:center;padding:0 6px;font-size:13px;font-weight:600;position:relative;line-height:1.2}
.cell em{position:absolute;right:5px;bottom:3px;font-style:normal;color:var(--mu)}.cell.sel{background:color-mix(in srgb,var(--red) 8%,transparent);color:var(--red);font-weight:800}
.split{display:flex;height:300px}.split .l{width:42%;border-right:1px solid var(--ln)}.li{padding:12px;font-size:13px;font-weight:600}.li.on{background:var(--bg);color:var(--red);font-weight:800}.split .r{flex:1;background:var(--bg)}.li2{padding:12px 14px;border-bottom:1px solid var(--ln);font-size:13px;font-weight:600;display:flex;justify-content:space-between}.li2.on{color:var(--red);font-weight:800}.li2 .ok{color:var(--red)}
.seg2{display:flex;background:var(--sf);border-radius:14px;padding:3px}.seg2 span{padding:5px 9px;border-radius:11px;color:var(--mu)}.seg2 .on{background:var(--accd);color:#fff}
.search{background:var(--sf);border:1px solid var(--ln);border-radius:20px;height:48px;display:flex;align-items:center;gap:8px;padding:0 14px;font-size:14px}
.fchips{display:flex;gap:6px;margin:10px 0}.fchips span{padding:7px 11px;border-radius:16px;background:var(--sf);border:1px solid var(--ln);font-size:12px;font-weight:600}.fchips .on{background:var(--accd);color:#fff;border-color:var(--accd)}
.sum3{display:flex;gap:8px;margin-bottom:6px}.sum3 div{flex:1;background:var(--sf);border-radius:18px;padding:9px 12px}.sum3 small{display:block;color:var(--mu)}.sum3 b{font-size:13.5px}
.day{margin:10px 4px 6px}.mon{margin:8px 4px 10px;font-size:15px}
.cal{padding:10px}.wk,.cg{display:grid;grid-template-columns:repeat(7,1fr);text-align:center}.wk span{font-size:11px;color:var(--mu);padding-bottom:6px}.cd{height:50px;border-radius:12px;display:flex;flex-direction:column;align-items:center;gap:1px;padding-top:4px}.cd b{font-size:12.5px}.cd i{font-style:normal;font-size:8.5px;font-weight:800}.pi{color:var(--inc)}.ne{color:var(--red)}
.cd.today{border:1.6px solid var(--accd)}
.seg{display:flex;background:var(--bg);border:1px solid var(--ln);border-radius:20px;padding:3px;margin:6px 0}.seg span{flex:1;text-align:center;padding:8px 0;border-radius:16px;font-weight:800;color:var(--mu);font-size:12.5px}.seg .on{background:var(--accd);color:#fff}.seg .on.r{background:var(--red)}.seg.sm span{padding:6px 0}
.donut{width:170px;height:170px;border-radius:50%;margin:10px auto 12px;display:flex;align-items:center;justify-content:center}.donut div{width:112px;height:112px;border-radius:50%;background:var(--sf);display:flex;flex-direction:column;align-items:center;justify-content:center}.donut b{font-size:14px}
.srow{display:flex;align-items:center;gap:8px;font-size:12.5px}.srow b{font-size:12.5px}.dot{width:10px;height:10px;border-radius:50%}
.lbl{display:block;font-size:13px;font-weight:800;margin:6px 0}.sws{display:grid;grid-template-columns:repeat(5,1fr);gap:10px 4px;margin-top:6px}.sw{display:flex;flex-direction:column;align-items:center;gap:3px}.sw span{width:40px;height:40px;border-radius:50%;display:flex;align-items:center;justify-content:center;color:#fff;border:3px solid transparent}.sw span.on{border-color:var(--tx)}.sw small{color:var(--mu)}
.tile{display:flex;align-items:center;gap:12px;padding:8px 0}.tile b{display:block;font-size:14px}
.prof{margin:8px 0 14px;gap:14px}.ring{padding:3px;border-radius:50%;background:var(--accd)}.av.big{width:64px;height:64px}.tonal{display:inline-flex;gap:6px;align-items:center;background:color-mix(in srgb,var(--acc) 25%,transparent);padding:10px 14px;border-radius:20px;font-weight:700;margin-right:8px}
.field{background:var(--bg);border:1px solid var(--ln);border-radius:20px;padding:8px 14px;font-size:15px;margin-bottom:8px}.field small{display:block;color:var(--mu)}
.note{background:var(--bg);border:1px solid var(--ln);border-radius:16px;padding:12px;color:var(--mu);font-size:12.5px;line-height:1.45;margin-top:8px}
.appbar{position:absolute;top:30px;left:0;right:0;height:52px;display:flex;align-items:center;gap:14px;padding:0 16px;font-size:18px}.appbar b{font-weight:900}.appbar+.scroll{top:84px}
.kv{display:flex;justify-content:space-between;font-size:13.5px;padding:3px 0}.kv span{color:var(--mu)}.warn{background:#FFA0001f;border-radius:16px;padding:10px 12px;font-size:12px;margin-top:8px;line-height:1.4}
.wall{position:absolute;inset:0;background:radial-gradient(circle at 20% 80%,#3B2F63,transparent 55%),radial-gradient(circle at 90% 30%,#14524C,transparent 50%),#0E1014;padding:40px 14px}
.shade{background:#1B1D22ee;border-radius:26px;padding:12px;margin-bottom:22px}.nt{color:#fff;padding:2px 6px 10px}.nt b{font-size:30px;font-weight:500}.nt small{color:#c9ccd2;font-size:13px}
.notif{background:#2A2D33;border-radius:22px;padding:10px 14px}.nh{color:#E6E7EA;margin-bottom:4px}.pig img{width:18px;height:18px;border-radius:5px;display:block}
.qb{display:flex;align-items:center;justify-content:space-around;height:52px;color:#E6E7EA}.qb .mi{font-size:28px}.qb i{width:1px;height:24px;background:#44474E}
.wdg{background:#1E2024;border-radius:24px;padding:14px;color:#ECEDEF}.wt{color:#4CC764;font-size:13px}.wdg small{color:#A3A9B4}.wb{font-size:21px;font-weight:700;margin:2px 0}.wdg .row b{font-size:12px}.ws{display:block;margin-top:2px}
.wbtn{display:flex;gap:6px;margin-top:10px}.wbtn span{flex:1;height:40px;border-radius:14px;display:flex;align-items:center;justify-content:center;color:#fff;font-weight:700;font-size:13px}
.apps{margin-top:26px;padding-left:10px}.apps span{display:inline-flex;flex-direction:column;align-items:center;gap:6px;color:#fff;font-size:12px}.apps img{width:60px;height:60px;border-radius:18px}
'''

phones = [home(), form(), cat_panel(), sub_panel(),
          history(), calendar(), stats(), home(dark=True, acc='tosca', photo=True),
          appearance(), profile(), importer(), widget_notif()]

html = f'''<!doctype html><html><head><meta charset="utf-8"><style>{fonts}{CSS}</style></head><body>
<div class="top-h"><img src="{logo}"><div><h1>Infinity</h1><p>Catatan keuangan Android · offline · Bahasa Indonesia · data contoh</p></div></div>
<div class="grid">{''.join(phones)}</div></body></html>'''
(HERE / 'mock.html').write_text(html)
print('ok', len(html))
