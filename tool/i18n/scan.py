import re,sys,collections,json
# Scanner untuk literal string Dart sederhana (satu token, kutip tunggal atau ganda, bukan raw/triple).
def read_literal(s,i):
    """s[i] adalah kutip pembuka. Kembalikan (end_index_exclusive, raw_body) atau None."""
    q=s[i]
    if s[i:i+3]==q*3: return None
    j=i+1; depth=0; out=[]
    while j<len(s):
        c=s[j]
        if c=='\\':
            out.append(s[j:j+2]); j+=2; continue
        if c=='$' and j+1<len(s) and s[j+1]=='{':
            # lewati sampai kurung kurawal penutup (nested)
            d=0; k=j+1
            while k<len(s):
                if s[k]=='{': d+=1
                elif s[k]=='}':
                    d-=1
                    if d==0: break
                elif s[k] in '\'"':
                    # string di dalam interpolasi
                    qq=s[k]; k+=1
                    while k<len(s) and s[k]!=qq:
                        if s[k]=='\\': k+=1
                        k+=1
                k+=1
            out.append(s[j:k+1]); j=k+1; continue
        if c==q: return (j+1,''.join(out))
        if c=='\n': return None
        out.append(c); j+=1
    return None

CTX=[
 (re.compile(r'(?<![\w.])Text\(\s*$'),'Text'),
 (re.compile(r'(?<![\w.])SectionTitle\(\s*$'),'SectionTitle'),
 (re.compile(r'(?<![\w.])pageBar\(\s*$'),'pageBar'),
 (re.compile(r'(?<![\w.])snack\(\s*[\w.]+,\s*$'),'snack'),
 (re.compile(r'\b(label|hint|hintText|labelText|helperText|tooltip|confirmLabel|cancelLabel|message|subtitle|body|action|title|text|child|prefix|suffix|prefixText|suffixText|content):\s*$'),'named'),
]
def contexts(s):
    for m in re.finditer(r'[\'"]',s):
        i=m.start()
        # abaikan kutip yang bagian dari literal lain: tandai posisi tercakup
        yield i
def find_literals(s):
    i=0; res=[]
    n=len(s)
    while i<n:
        c=s[i]
        if c=='/' and s[i:i+2]=='//':
            i=s.find('\n',i); 
            if i<0: break
            continue
        if c=='/' and s[i:i+2]=='/*':
            i=s.find('*/',i)+2; continue
        if c in '\'"':
            if s[i:i+3]==c*3:
                e=s.find(c*3,i+3); i=e+3; continue
            raw = i>0 and s[i-1]=='r' and not (i>1 and (s[i-2].isalnum() or s[i-2]=='_'))
            r=read_literal(s,i)
            if r is None: i+=1; continue
            e,body=r
            res.append((i,e,body,raw))
            i=e; continue
        i+=1
    return res
