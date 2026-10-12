import sys,re,importlib
sys.path.insert(0,'/tmp/claude-0/i18n')
mods=sys.argv[1:]
T={}
for m in mods:
    mod=importlib.import_module(m)
    for i,en,zh in mod.T: T[i]=(en,zh)
bad=0
def ph(s): return sorted(re.findall(r'\{\d+\}',s))
for i,(en,zh) in T.items():
    if ph(i)!=ph(en) or ph(i)!=ph(zh):
        print('PLACEHOLDER MISMATCH',repr(i)); bad+=1
def q(s):
    return "'"+s.replace('\\','\\\\').replace("'","\\'").replace('$','\\$').replace('\n','\\n')+"'"
def emit(idx,name,doc):
    lines=[f'// {doc}','const Map<String, String> %s = {'%name]
    for i,v in T.items(): lines.append(f'  {q(i)}: {q(v[idx])},')
    lines.append('};')
    return '\n'.join(lines)+'\n'
pat=open('/home/claude/infinity-repo/lib/src/48_terjemahan_en.dart',encoding='utf-8').read()
m=re.search(r'/// Pola untuk.*',pat,re.S)
patblock=m.group(0) if m else ''
open('/home/claude/infinity-repo/lib/src/48_terjemahan_en.dart','w',encoding='utf-8').write("part of '../main.dart';\n\n// Terjemahan English. Kunci = teks Indonesia di kode. {0}, {1} = isian.\n// File ini dibuat dari daftar terjemahan; tambah entri baru di bagian bawah.\n"+emit(0,'kEnStrings','English')+'\n'+patblock)
open('/home/claude/infinity-repo/lib/src/49_terjemahan_zh.dart','w',encoding='utf-8').write("part of '../main.dart';\n\n// Terjemahan 简体中文. Kunci = teks Indonesia di kode. {0}, {1} = isian.\n"+emit(1,'kZhStrings','简体中文'))
print(len(T),'entri; masalah',bad)
