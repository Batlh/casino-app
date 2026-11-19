import random, sys
sys.argv=['x']
import pachislo as PS
N=21
def gaps_ok(strip, sym, maxgap):
    idx=[i for i,x in enumerate(strip) if x==sym]
    if not idx: return False
    for a,b in zip(idx, idx[1:]+[idx[0]+N]):
        if b-a>maxgap: return False
    return True
def make(rng, reel):
    while True:
        counts={PS.P:5,PS.R:5,PS.S:2,PS.B:2,PS.G:2}
        if reel==0: counts[PS.K]=3; counts[PS.G]=1;counts[PS.B]=1  # 5+5+2+1+1+3=17 -> add more
        st=[]
        for k,v in counts.items(): st+= [k]*v
        fill=[PS.P,PS.R] if reel else [PS.P,PS.R,PS.G,PS.B]
        while len(st)<N: st.append(rng.choice(fill))
        rng.shuffle(st)
        # keine gleichen Nachbarn bei 7, BAR
        if not gaps_ok(st,PS.P,5) or not gaps_ok(st,PS.R,5): continue
        if reel==0 and not gaps_ok(st,PS.K,7): continue
        ok=True
        for p in range(N):
            for X in (PS.P,PS.R):
                if not any(st[(p+d+1)%N]==X and (reel or PS.K not in [st[(p+d+i)%N] for i in range(3)]) for d in range(5)):
                    ok=False
            if reel==0 and not any(PS.K not in [st[(p+d+i)%N] for i in range(3)] for d in range(5)): ok=False
        if not ok: continue
        # Sieben nicht direkt nebeneinander, zwei Sieben gut verteilt
        si=[i for i,x in enumerate(st) if x==PS.S]
        if len(si)>=2 and min((b-a)%N for a in si for b in si if a!=b)<6: continue
        return st
rng=random.Random(int(sys.argv[1]) if len(sys.argv)>1 else 3)
best=None
for t in range(60):
    strips=[make(rng,r) for r in range(3)]
    PS.STRIPS=strips
    r2=random.Random(5)
    score=0; res={}
    for flag in [None,'P','R','K','BIG','REG','G']:
        ok=bad=0;n=300
        for _ in range(n):
            order=tuple(r2.sample(range(3),3)) if r2.random()<0.3 else (0,1,2)
            got=PS.game(strips,flag,r2,order)
            ok+= flag in got; bad+= bool(got-{flag})
        res[flag]=(ok/n,bad/n)
    score = -100*sum(b for _,b in res.values()) + res['P'][0]+res['R'][0]+res['K'][0]
    if best is None or score>best[0]: best=(score,strips,res)
print(best[2])
for s in best[1]: print(''.join(PS.NAMES[x] for x in s))
