import json, glob, collections, statistics as st
rows=[]
for f in glob.glob('/tmp/claude-0/-home-claude/46e59c5f-85fd-5f10-ad9d-79f66fef24b7/scratchpad/bal/r_*.log'):
    for line in open(f):
        if 'RESULTADO_JSON' in line:
            rows.append(json.loads(line.split('RESULTADO_JSON ',1)[1]))
print(len(rows),'runs')
g=collections.defaultdict(list)
for r in rows:
    g[(",".join(r['party']), r['gear'], r['diff'], r['level'])].append(r)
for k in sorted(g, key=lambda k:(len(k[0].split(',')),k[0],k[2],k[3],k[1])):
    rs=g[k]; n=len(rs)
    wins=sum(r['result']=='venceu' for r in rs)
    fl=[r['floor'] for r in rs if r['result']!='venceu']
    secs=st.mean(r['seconds'] for r in rs)
    deaths=collections.Counter()
    for r in rs:
        for h,c in r['deaths'].items(): deaths[h]+=c
    gold=st.mean(r['gold'] for r in rs); kills=st.mean(r['kills'] for r in rs)
    tm=sum(r['result']=='tempo' for r in rs)
    print(f"{k[0]:42s} {k[1]:5s} d{k[2]} L{k[3]:<2d} | vit {wins}/{n} | caiu andares {sorted(fl)} | tempo {tm} | {secs/60:4.1f}min | abates {kills:5.0f} | ouro {gold:5.0f} | mortes {dict(deaths)}")
