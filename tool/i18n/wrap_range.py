import sys,re
sys.path.insert(0,'/tmp/claude-0/i18n')
from scan import *
from codemod import mk_tr
def wrap(path,ranges,skip_if=()):
    s=open(path,encoding='utf-8').read()
    lits=find_literals(s)
    edits=[]
    for (i,e,body,raw) in lits:
        if raw: continue
        ln=s.count('\n',0,i)+1
        if not any(a<=ln<=b for a,b in ranges): continue
        if s[i]!="'" : continue
        if not re.search(r'[A-Za-z]{2}',re.sub(r'\$\{[^}]*\}|\$\w+','',body)): continue
        if re.fullmatch(r"[dMyHmsEa\s,.:\-/]+",body): continue
        # sudah dalam tr(
        pre=s[max(0,i-6):i]
        if pre.endswith('tr('): continue
        # literal bersambung
        k=i-1
        while k>=0 and s[k].isspace(): k-=1
        if s[k] in '\'"': continue
        mnx=re.match(r'\s*(.)',s[e:e+200],re.S)
        if mnx and mnx.group(1) in '\'"': continue
        if any(x in body for x in skip_if): continue
        if '$' in body.replace('\\$',''):
            new=mk_tr(body)
        else:
            new=f"tr({s[i:e]})"
        if new: edits.append((i,e,new))
    for (i,e,r) in sorted(edits,reverse=True): s=s[:i]+r+s[e:]
    open(path,'w',encoding='utf-8').write(s)
    print(path,len(edits))
if __name__=='__main__':
    path=sys.argv[1]; rs=[tuple(map(int,x.split('-'))) for x in sys.argv[2:]]
    wrap(path,rs)
