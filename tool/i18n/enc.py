import sys,re,collections
sys.path.insert(0,'/tmp/claude-0/i18n')
from scan import *
def enclosing(s,i):
    d=0;j=i-1
    while j>=0:
        c=s[j]
        if c in ')]}': d+=1
        elif c in '([{':
            if d==0:
                if c=='(':
                    m=re.search(r'([A-Za-z_][\w.]*)\s*$',s[max(0,j-60):j])
                    return m.group(1) if m else '?'
                return '?'+c
            d-=1
        j-=1
    return '?'
if __name__=='__main__':
    cnt=collections.Counter()
    for f in sys.argv[1:]:
        s=open(f,encoding='utf-8').read()
        for (i,e,body,raw) in find_literals(s):
            if raw: continue
            line_start=s.rfind('\n',0,i)+1
            pre=s[line_start:i]
            m=re.search(r'\b(label|hint|hintText|labelText|helperText|tooltip|confirmLabel|cancelLabel|message|subtitle|body|action|title|text|prefix|suffix|prefixText|suffixText|content):\s*$',pre)
            if not m: continue
            nxt=s[e:e+3].lstrip()[:1]
            if nxt not in ',)': continue
            if not re.search(r'[A-Za-z]{2}',body): continue
            cnt[(m.group(1),enclosing(s,i))]+=1
    for k,v in sorted(cnt.items(),key=lambda x:-x[1]): print(v,k)
