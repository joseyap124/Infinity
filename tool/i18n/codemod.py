import sys,re,collections,json
sys.path.insert(0,'/tmp/claude-0/i18n')
from scan import *
from enc import enclosing

OK_NAMED={'tooltip','hintText','labelText','helperText','prefixText','suffixText'}
# (nama argumen, pembungkus) yang diizinkan untuk literal berinterpolasi maupun polos
WL={
 ('label','NavigationDestination'),('label','PrimaryButton'),('label','FormRow'),('label','_SummaryBox'),('label','_LegendDot'),
 ('label','SnackBarAction'),('title','EmptyState'),('subtitle','EmptyState'),('title','_tile'),('subtitle','_tile'),
 ('title','_switch'),('subtitle','_switch'),('title','_page'),('action','_section'),('prefix','fieldDeco'),
 ('title','confirmDialog'),('message','confirmDialog'),('confirmLabel','confirmDialog'),('title','typedConfirmDialog'),
 ('confirmLabel','typedConfirmDialog'),('title','Insight'),('body','Insight'),('action','Insight'),('title','PinPad'),
 ('subtitle','PinPad'),('title','InsightStrip'),('title','_askPassword'),('text','Tab'),
}
def unescape(b):
    return (b.replace("\\'","'").replace('\\"','"').replace('\\n','\n').replace('\\$','$').replace('\\\\','\\'))
def split_interp(body):
    """Pecah isi literal jadi (kunci_dengan_{n}, [ekspresi])."""
    out=[];args=[];i=0;n=len(body)
    while i<n:
        c=body[i]
        if c=='\\': out.append(body[i:i+2]); i+=2; continue
        if c=='$':
            if i+1<n and body[i+1]=='{':
                d=0;k=i+1
                while k<n:
                    if body[k]=='{': d+=1
                    elif body[k]=='}':
                        d-=1
                        if d==0: break
                    elif body[k] in '\'"':
                        qq=body[k];k+=1
                        while k<n and body[k]!=qq:
                            if body[k]=='\\':k+=1
                            k+=1
                    k+=1
                expr=body[i+2:k]; args.append(expr); out.append('{%d}'%(len(args)-1)); i=k+1; continue
            m=re.match(r'\$([A-Za-z_]\w*)',body[i:])
            if m:
                args.append(m.group(1)); out.append('{%d}'%(len(args)-1)); i+=len(m.group(0)); continue
        out.append(c); i+=1
    return ''.join(out),args

def mk_tr(body,q="'"):
    key,args=split_interp(body)
    letters=re.sub(r'\{\d+\}','',key)
    if not re.search(r'[A-Za-z]{2}',letters.replace('\\n',' ')): return None
    out=[]
    for a in args:
        a2=a.strip()
        if re.search(r'\.(label|message|current)$',a2): out.append(f'tr({a2})')
        else: out.append(a2)
    return f"tr('{key}', [{', '.join(out)}])"

def eligible_contexts(s,i,e):
    """Kembalikan nama konteks kalau literal [i,e) layak diterjemahkan, selain itu None."""
    ls=s.rfind('\n',0,i)+1
    pre=s[ls:i]
    if pre.strip()=='':
        k=s.rfind('\n',0,ls-1)+1
        pre=s[k:ls].rstrip()+' '
    mnx=re.match(r'\s*(.)',s[e:e+200],re.S)
    nxt=mnx.group(1) if mnx else ''
    if nxt not in ',):': return None
    # literal bersambung dengan literal lain ('a' 'b'): lewati
    k=i-1
    while k>=0 and s[k].isspace(): k-=1
    if k>=0 and s[k] in '\'"': return None
    enc=enclosing(s,i)
    # ternary dalam Text(...)/snack(...)
    m=re.search(r'(?<![\w.])Text\(\s*$',pre)
    if m: return 'Text'
    if re.search(r'(?<![\w.])snack\(\s*[\w.]+,\s*$',pre): return 'snack'
    nm=re.search(r'\b([A-Za-z]\w*):\s*$',pre)
    if nm:
        name=nm.group(1)
        if name in OK_NAMED: return 'named:'+name
        if (name,enc) in WL: return 'wl:%s/%s'%(name,enc)
        return None
    if re.search(r'[?:]\s*$',pre) and enc in ('Text','snack') :
        return 'tern:'+enc
    return None

def process(path,apply=True):
    s=open(path,encoding='utf-8').read()
    lits=find_literals(s)
    edits=[]
    stats=collections.Counter()
    for (i,e,body,raw) in lits:
        if raw: continue
        if not re.search(r'[A-Za-z]{2}',body.replace('\\n',' ')): continue
        ctx=eligible_contexts(s,i,e)
        if not ctx: continue
        interp='$' in body.replace('\\$','')
        if ctx.startswith('named:'):
            # tooltip/hintText dll bukan Text: bungkus selalu
            if interp:
                new=mk_tr(body) if s[i]=="'" else None
            else:
                new=f"tr({s[i:e]})"
            if new: edits.append((i,e,new)); stats[ctx]+=1
        elif ctx.startswith('wl:') or ctx in ('snack',) or ctx.startswith('tern:snack'):
            # widget yang meneruskan ke Text: cukup bungkus yang berinterpolasi
            if interp and s[i]=="'":
                new=mk_tr(body)
                if new: edits.append((i,e,new)); stats[ctx]+=1
        elif ctx=='Text' or ctx.startswith('tern:Text'):
            if interp and s[i]=="'":
                new=mk_tr(body)
                if new: edits.append((i,e,new)); stats[ctx]+=1
    # tanggal mengikuti bahasa
    if not edits:
        return stats,s,s
    # hapus 'const' yang melingkupi tiap edit (tr() bukan konstanta)
    rm=set()
    for (i,e,r) in edits:
        d=0;j=i-1
        while j>=0:
            c=s[j]
            if c in ')]}': d+=1
            elif c in '([{':
                if d==0:
                    if c=='(':
                        m=re.search(r'(const\s+)([A-Za-z_][\w.]*(<[^()]*>)?)\s*$',s[max(0,j-90):j])
                        if m:
                            st=max(0,j-90)+m.start(1); rm.add((st,st+len(m.group(1))))
                    elif c=='[':
                        m=re.search(r'(const\s*)(<[^\[\]]*>)?\s*$',s[max(0,j-90):j])
                        if m and m.group(1):
                            st=max(0,j-90)+m.start(1); rm.add((st,st+len(m.group(1))))
                else: d-=1
                if d<0: d=0
            j-=1
    allp=[(i,e,r) for (i,e,r) in edits]+[(a,b,'') for (a,b) in rm]
    new=s
    for (i,e,r) in sorted(allp,reverse=True): new=new[:i]+r+new[e:]
    return stats,s,new

if __name__=='__main__':
    mode=sys.argv[1]
    total=collections.Counter()
    for f in sys.argv[2:]:
        st,old,new=process(f)
        total.update(st)
        if st: print(f.split('/')[-1],dict(st))
        if mode=='apply' and new!=old: open(f,'w',encoding='utf-8').write(new)
    print(dict(total))
