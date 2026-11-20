import itertools, random, sys
sys.argv=['x']; sys.path.insert(0, __import__('os').path.dirname(__file__))
import ps2 as PS
from ps2 import S,B,G,K,R,P,N
def gaps(st,sym,mx): return PS.gaps_ok(st,sym,mx)
def reachable(st, X, reel0):
    return all(any(st[(p+d+1)%N]==X and (not reel0 or K not in PS.win3(st,p+d)) for d in range(5)) for p in range(N))
# Walze 1
r1=[]
for rot in range(N):
    for ex in itertools.permutations([S,B,G,S,B,G]):
        st=[None]*N
        # Pflaume, Replay, Kirsche je höchstens alle 5 Felder
        for i in (0,4,8,12,16): st[i]=P
        for i in (1,5,9,13,17): st[i]=R
        for i in (2,6,10,14,18): st[i]=K
        rest=[i for i in range(N) if st[i] is None]
        for i,x in zip(rest,ex): st[i]=x
        si=[i for i,x in enumerate(st) if x==S]
        if min((si[1]-si[0])%N,(si[0]-si[1])%N)<6: continue
        r1.append(st[rot:]+st[:rot])
r1=r1[::37]
print('Walze 1 Möglichkeiten', len(r1))
def other(rot, extra):
    st=[None]*N
    for i in (0,4,8,12,16): st[i]=P
    for i in (2,6,10,14,18): st[i]=R
    rest=[i for i in range(N) if st[i] is None]
    for i,x in zip(rest, extra): st[i]=x
    return st[rot:]+st[:rot]
rng=random.Random(4)
best=None
for t in range(600):
    a=rng.choice(r1)
    ex2=[S,G,B,P,S,R,G,B,P,G,R]; ex3=[S,G,B,R,S,P,G,B,R,G,P]
    rng.shuffle(ex2); rng.shuffle(ex3)
    b=other(rng.randrange(N),ex2); c=other(rng.randrange(N),ex3)
    if not all(gaps(x,P,5) and gaps(x,R,5) for x in (b,c)): continue
    si=[[i for i,x in enumerate(s) if x==S] for s in (b,c)]
    if any(min((y-x)%N for x in q for y in q if x!=y)<6 for q in si): continue
    res=PS.evaluate([a,b,c],400)
    score=-1000*sum(v[1] for v in res.values())+res['P'][0]+res['R'][0]+res['K'][0]+res['BIG'][0]+0.5*res['G'][0]
    if best is None or score>best[0]: best=(score,[a,b,c],res)
print(best[2]); print(PS.evaluate(best[1],6000,11))
for s in best[1]: print(''.join(PS.NAMES[x] for x in s))
