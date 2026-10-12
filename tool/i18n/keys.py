import sys,re,json,collections
sys.path.insert(0,'/tmp/claude-0/i18n')
from scan import *
from codemod import unescape,split_interp
def cands(f):
    s=open(f,encoding='utf-8').read()
    out=[]
    for (i,e,body,raw) in find_literals(s):
        if raw: continue
        if s[i]=='"' and "'" in body: pass
        mnx=re.match(r'\s*(.)',s[e:e+200],re.S)
        nxt=mnx.group(1) if mnx else ''
        key,args=split_interp(body) if '$' in body.replace('\\$','') else (body,[])
        k=unescape(key)
        letters=re.sub(r'\{\d+\}','',k)
        if not re.search(r'[A-Za-z]{2}',letters): continue
        if '_' in k and ' ' not in k: continue
        if re.fullmatch(r'[a-z][A-Za-z0-9]*',k): continue      # camelCase id
        if re.fullmatch(r'[a-z0-9_\-./:]+',k): continue
        if k.startswith(('http','dart:','package:','assets/','infinity://','es.','com.','android.')): continue
        if len(k)>220: continue
        if nxt not in ',):;?' : continue
        # baris sebelumnya mengandung 'import', 'part ' dll
        ls=s.rfind('\n',0,i)+1
        line=s[ls:s.find('\n',i)]
        if re.match(r'\s*(import|part|export)\b',line): continue
        out.append((k,s.count('\n',0,i)+1))
    return out
if __name__=='__main__':
    allk=collections.OrderedDict()
    for f in sys.argv[1:]:
        for k,ln in cands(f):
            allk.setdefault(k,[]).append((f.split('/')[-1],ln))
    json.dump({k:v for k,v in allk.items()},open('/tmp/claude-0/i18n/keys_out.json','w'),ensure_ascii=False,indent=0)
    print(len(allk))
