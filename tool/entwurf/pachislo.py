"""Pachislo-Entwurf: Walzensteuerung mit höchstens 4 Feldern Nachrutschen."""
import random, itertools, sys
S,B,G,K,R,P = 0,1,2,3,4,5
NAMES='SBGKRP'
LINES=[(1,1,1)]
SLIP=4
N=21
def parse(s): return [NAMES.index(c) for c in s]
STRIPS=[parse(sys.argv[1]),parse(sys.argv[2]),parse(sys.argv[3])] if len(sys.argv)>3 else None

def window(strip,s): return [strip[(s+i)%N] for i in range(3)]

def roles_of(win):  # win: list of 3 windows (each 3 rows) for stopped reels (None if not stopped)
    """Rollen, die mit den gestoppten Walzen fertig sind."""
    out=set()
    if win[0] is not None and K in win[0]: out.add('K')
    if all(w is not None for w in win):
        for l in LINES:
            a,b,c=(win[i][l[i]] for i in range(3))
            if a==b==c==P: out.add('P')
            if a==b==c==R: out.add('R')
            if a==b==c==G: out.add('G')
            if a==b==c==S: out.add('BIG')
            if a==S and b==S and c==B: out.add('REG')
    return out

def possible(win, strips, role):
    """Kann role mit den noch offenen Walzen (beliebige Stopps) entstehen?"""
    opn=[i for i in range(3) if win[i] is None]
    for combo in itertools.product(range(N),repeat=len(opn)):
        w=list(win)
        for i,s in zip(opn,combo): w[i]=window(strips[i],s)
        if role in roles_of(w): return True
    return False

def avoidable(win, strips, flag):
    """Gibt es eine Fortsetzung ohne ungewollte Rolle?"""
    opn=[i for i in range(3) if win[i] is None]
    for combo in itertools.product(range(N),repeat=len(opn)):
        w=list(win)
        for i,s in zip(opn,combo): w[i]=window(strips[i],s)
        r=roles_of(w)-{flag}
        if not r: return True
    return False

def stop(strips, win, reel, press, flag):
    cands=[(press+d)%N for d in range(SLIP+1)]
    best=None
    for s in cands:
        w=list(win); w[reel]=window(strips[reel],s)
        bad=roles_of(w)-{flag}
        if bad: continue
        if not avoidable(w,strips,flag): continue
        if flag and possible(w,strips,flag):
            return s
        if best is None: best=s
    return best if best is not None else press

def game(strips, flag, rng, order=(0,1,2)):
    win=[None,None,None]
    for reel in order:
        s=stop(strips,win,reel,rng.randrange(N),flag)
        win[reel]=window(strips[reel],s)
    return roles_of(win)

if __name__=='__main__':
    rng=random.Random(1)
    for flag in [None,'P','R','K','G','BIG','REG']:
        ok=bad=0; n=600
        for _ in range(n):
            order=tuple(rng.sample(range(3),3)) if rng.random()<0.3 else (0,1,2)
            r=game(STRIPS,flag,rng,order)
            if flag in r: ok+=1
            if r-{flag}: bad+=1
        print(flag, 'getroffen', ok/n, 'falsch', bad/n)
