"""Pachislo, nur Mittellinie. Schnelle Walzensteuerung (gleich wie später in Dart)."""
import random
S,B,G,K,R,P = 0,1,2,3,4,5
NAMES='SBGKRP'
N=21; SLIP=4
NEED={'P':(P,P,P),'R':(R,R,R),'G':(G,G,G),'BIG':(S,S,S),'REG':(S,S,B)}
def win3(st,s): return [st[(s+i)%N] for i in range(3)]
def roles(mid, left):
    out=set()
    if left is not None and left[1]==K: out.add('K')
    if None not in mid:
        for k,v in NEED.items():
            if tuple(mid)==v: out.add(k)
    return out
def stop(strips, mid, left, reel, press, flag):
    best=None; good=None
    for d in range(SLIP+1):
        s=(press+d)%N
        w=win3(strips[reel],s)
        m=list(mid); m[reel]=w[1]
        l=w if reel==0 else left
        if roles(m,l)-{flag}: continue
        if best is None: best=s
        if flag=='K':
            if reel==0 and w[1]==K: return s
        elif flag in NEED and w[1]==NEED[flag][reel]:
            if good is None: good=s
    return good if good is not None else (best if best is not None else press)
def game(strips, flag, rng, order=(0,1,2)):
    mid=[None]*3; left=None
    for reel in order:
        s=stop(strips,mid,left,reel,rng.randrange(N),flag)
        w=win3(strips[reel],s); mid[reel]=w[1]
        if reel==0: left=w
    return roles(mid,left)
def evaluate(strips, n=2000, seed=5):
    rng=random.Random(seed); res={}
    for flag in [None,'P','R','K','G','BIG','REG']:
        ok=bad=0
        for _ in range(n):
            order=tuple(rng.sample(range(3),3)) if rng.random()<0.3 else (0,1,2)
            got=game(strips,flag,rng,order)
            ok+= flag in got; bad+= bool(got-{flag})
        res[flag]=(round(ok/n,3),round(bad/n,4))
    return res
def gaps_ok(st, sym, maxgap):
    idx=[i for i,x in enumerate(st) if x==sym]
    return bool(idx) and all(b-a<=maxgap for a,b in zip(idx, idx[1:]+[idx[0]+N]))
def make(rng, reel):
    while True:
        counts={P:5,R:5,S:2,B:2,G:1}
        if reel==0: counts[K]=3
        st=[x for k,v in counts.items() for x in [k]*v]
        while len(st)<N: st.append(rng.choice([P,R,G,B]))
        rng.shuffle(st)
        if not gaps_ok(st,P,5) or not gaps_ok(st,R,5): continue
        if reel==0 and not gaps_ok(st,K,7): continue
        si=[i for i,x in enumerate(st) if x==S]
        if min((b-a)%N for a in si for b in si if a!=b)<7: continue
        ok=True
        for p in range(N):
            for X in (P,R):
                if not any(st[(p+d+1)%N]==X and (reel or K not in win3(st,p+d)) for d in range(5)): ok=False
            if reel==0 and not any(K not in win3(st,p+d) for d in range(5)): ok=False
        if ok: return st
if __name__=='__main__':
    import sys
    rng=random.Random(int(sys.argv[1]))
    best=None
    for t in range(40):
        strips=[make(rng,r) for r in range(3)]
        res=evaluate(strips,800)
        score=-1000*sum(b for _,b in res.values())+res['P'][0]+res['R'][0]+res['K'][0]+0.5*res['BIG'][0]
        if best is None or score>best[0]: best=(score,strips,res)
    print(best[2]); print(evaluate(best[1],5000,9))
    for s in best[1]: print(''.join(NAMES[x] for x in s))
