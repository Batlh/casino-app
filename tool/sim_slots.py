#!/usr/bin/env python3
"""Simuliert Slots mit allen Funktionen (Wege, Kaskaden, Hold & Spin, Glücksrad, wechselnde Höhe).

Die Logik entspricht SlotEngine.play() in lib/games/slots/slot_engine.dart. Damit werden die
Beträge der neuen Slots abgestimmt; die Dart-Tests prüfen die Quote noch einmal mit dem echten Code.
"""
import random

WILD, SCATTER, COIN, BONUS = 6, 7, 8, 9


def pay(g, sym, n):
    p = g["pays"].get(sym)
    if not p:
        return 0
    i = n - 3
    return p[i] if 0 <= i < len(p) else 0


def line_hit(g, syms):
    if syms[0] == SCATTER:
        return None
    first = next((x for x in syms if x != WILD), WILD)
    if first == SCATTER:
        first = WILD
    if first not in g["pays"]:
        return None
    count = wilds = 0
    for x in syms:
        if x == first or x == WILD:
            count += 1
            wilds += x == WILD
        else:
            break
    run = 0
    for x in syms:
        if x == WILD:
            run += 1
        else:
            break
    normal = pay(g, first, count)
    if g.get("wildmult") and first != WILD:
        normal <<= wilds
    wild = pay(g, WILD, run)
    if normal == 0 and wild == 0:
        return None
    return (WILD, run, wild) if wild > normal else (first, count, normal)


def wins(g, grid, stake, mult):
    """Liste (Auszahlung, Felder)."""
    out = []
    reels = len(grid)
    if g.get("mode", "lines") == "lines":
        lb = stake // len(g["lines"])
        for line in g["lines"]:
            h = line_hit(g, [grid[r][line[r]] for r in range(reels)])
            if h:
                out.append((h[2] * lb * mult, [(r, line[r]) for r in range(h[1])]))
        return out
    anywhere = g.get("anywhere", False)
    for sym in g["pays"]:
        if sym == WILD:
            continue
        r = 0
        while r < reels:
            if not any(x == sym or x == WILD for x in grid[r]):
                if not anywhere:
                    break
                r += 1
                continue
            end = r
            while end < reels and any(x == sym or x == WILD for x in grid[end]):
                end += 1
            n = end - r
            real = any(sym in grid[i] for i in range(r, end))
            p = pay(g, sym, n)
            if real and p > 0:
                ways = 1
                cells = []
                for i in range(r, end):
                    c = 0
                    for row, x in enumerate(grid[i]):
                        if x == sym or x == WILD:
                            c += 1
                            cells.append((i, row))
                    ways *= c
                out.append((p * ways * stake * mult // g["div"], cells))
            if not anywhere:
                break
            r = end
    return out


def expand(g, grid, free):
    grid = [list(c) for c in grid]
    if free and g.get("expand"):
        for r in range(1, len(grid) - 1):
            if WILD in grid[r]:
                grid[r] = [WILD] * len(grid[r])
    return grid


def coin_value(g, rng):
    h = g["hold"]
    return rng.choices(h["values"], h["weights"])[0]


def hold_spin(g, rng, start, stake):
    h = g["hold"]
    cells = len(g["strips"]) * g["rows"]
    coins = dict(start)
    respins = h["respins"]
    while respins > 0 and len(coins) < cells:
        landed = False
        for c in range(cells):
            if c not in coins and rng.random() < h["chance"]:
                coins[c] = coin_value(g, rng)
                landed = True
        respins = h["respins"] if landed else respins - 1
    full = len(coins) >= cells
    return (sum(coins.values()) + (h["grand"] if full else 0)) * stake // 10, full


def play(g, rng, stake, free=False):
    """Liefert (Gesamtgewinn, gewonnene Freispiele, Infos)."""
    strips = g["strips"]
    reels = len(strips)
    grid, stops = [], []
    for st in strips:
        h = rng.choice(g["heights"]) if g.get("heights") else g["rows"]
        s = rng.randrange(len(st))
        stops.append(s)
        grid.append([st[(s + row) % len(st)] for row in range(h)])
    if not free:
        g["_sticky"] = set()
    elif g.get("sticky"):
        held = g.setdefault("_sticky", set())
        for r, row in held:
            if row < len(grid[r]):
                grid[r][row] = WILD
        for r in range(reels):
            for row, x in enumerate(grid[r]):
                if x == WILD:
                    held.add((r, row))
    flat = [x for c in grid for x in c]
    scatters = flat.count(SCATTER)
    bonus = flat.count(BONUS)
    coins = {}
    if g.get("hold"):
        for r in range(reels):
            for row, x in enumerate(grid[r]):
                if x == COIN:
                    coins[r * g["rows"] + row] = coin_value(g, rng)
    ladder = g.get("free_cascade") if free and g.get("free_cascade") else g.get("cascade", [])
    base = g.get("mult", 1) if free else 1
    above = stops[:]
    shown = expand(g, grid, free)
    total = 0
    steps = 0
    info = {}
    while True:
        m = base * ladder[min(steps, len(ladder) - 1)] if ladder else base
        ws = wins(g, shown, stake, m)
        total += sum(w[0] for w in ws)
        steps += 1
        if not ladder or not ws or steps > 50:
            break
        hit = {c for w in ws for c in w[1]}
        nxt = []
        for r in range(reels):
            kept = [x for row, x in enumerate(shown[r]) if (r, row) not in hit]
            k = len(shown[r]) - len(kept)
            fresh = []
            for _ in range(k):
                above[r] = (above[r] - 1) % len(strips[r])
                fresh.insert(0, strips[r][above[r]])
            nxt.append(fresh + kept)
        shown = expand(g, nxt, free)
    info["steps"] = steps
    freewon = 0
    if g.get("scatter") and scatters >= 3:
        i = min(scatters - 3, len(g["scatter"]) - 1)
        total += g["scatter"][i] * stake * base
        freewon = g["free"]
    if g.get("hold") and len(coins) >= g["hold"]["trigger"]:
        w, full = hold_spin(g, rng, coins, stake)
        total += w
        info["hold"] = w
        info["full"] = full
    if g.get("wheel") and bonus >= 3:
        segs = g["wheel"]
        kind, amount = rng.choices([(k, a) for k, a, _ in segs], [w for *_, w in segs])[0]
        info["wheel"] = kind
        if kind == "coins":
            total += amount * stake
        elif kind == "free":
            freewon += amount
        else:
            cells = list(range(reels * g["rows"]))
            rng.shuffle(cells)
            w, full = hold_spin(g, rng, {c: coin_value(g, rng) for c in cells[:amount]}, stake)
            total += w
            info["hold"] = w
    return total, freewon, info


def rtp(g, spins=200_000, seed=1, stake=None):
    rng = random.Random(seed)
    stake = stake or g["stake"]
    paid = 0
    free = 0
    hits = 0
    feats = {"free": 0, "hold": 0, "wheel": 0, "full": 0}
    big = 0
    for _ in range(spins):
        t, f, info = play(g, rng, stake)
        paid += t
        hits += t > 0
        big = max(big, t)
        if f:
            feats["free"] += 1
        if "hold" in info:
            feats["hold"] += 1
        if "wheel" in info:
            feats["wheel"] += 1
        if info.get("full"):
            feats["full"] += 1
        free += f
        while free:
            free -= 1
            t, f, info = play(g, rng, stake, True)
            paid += t
            big = max(big, t)
            free += f
    return paid / (spins * stake), hits / spins, {k: spins / v if v else 0 for k, v in feats.items()}, big / stake
