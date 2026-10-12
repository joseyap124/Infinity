import glob
n=0
for f in glob.glob('lib/src/*.dart'):
    s=open(f,encoding='utf-8').read()
    out=[]
    for line in s.split('\n'):
        if "'id_ID'" in line and 'NumberFormat' not in line and 'DateFormat' in line:
            line=line.replace("'id_ID'","gDateLoc"); n+=1
        out.append(line)
    open(f,'w',encoding='utf-8').write('\n'.join(out))
print('date lines',n)
