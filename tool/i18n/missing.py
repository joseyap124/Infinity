import sys,glob,json,importlib
import os; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from keys import cands
have=set()
for m in ['tr1','tr2','tr3','tr4']+sys.argv[2:]:
    for i,en,zh in importlib.import_module(m).T: have.add(i)
pre=sys.argv[1].split(',')
for f in sorted(glob.glob('/home/claude/infinity-repo/lib/src/*.dart')):
    n=f.split('/')[-1][:2]
    if n not in pre: continue
    seen=set()
    for k,ln in cands(f):
        if k in have or k in seen: continue
        seen.add(k); print(n,ln,repr(k))
