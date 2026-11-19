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
    if g.get("mode") == "cluster":
        i = n - g.get("cluster_min", 5)
        return p[min(i, len(p) - 1)] if i >= 0 else 0
    i = n - 3
    return p[i] if 0 <= i < len(p) else 0


def cluster_wins(g, grid, stake, mult):
    """Gruppen aus gleichen Symbolen (waagrecht und senkrecht), Joker zählen für jedes Symbol."""
    out = []
    reels = len(grid)
    for sym in g["pays"]:
        if sym == WILD:
            continue
        seen = set()
        for r in range(reels):
            for row in range(len(grid[r])):
                if grid[r][row] != sym or (r, row) in seen:
                    continue
                group = []
                todo = [(r, row)]
                seen.add((r, row))
                while todo:
                    cr, crow = todo.pop()
                    group.append((cr, crow))
                    for dr, drow in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nr, nrow = cr + dr, crow + drow
                        if 0 <= nr < reels and 0 <= nrow < len(grid[nr]) and (nr, nrow) not in seen \
                                and grid[nr][nrow] in (sym, WILD):
                            seen.add((nr, nrow))
                            todo.append((nr, nrow))
                seen = {c for c in seen if grid[c[0]][c[1]] != WILD}
                p = pay(g, sym, len(group))
                if p:
                    out.append((p * stake * mult // g["div"], group))
    return out


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


def wins(g, grid, stake, mult, wm=None):
    """Liste (Auszahlung, Felder)."""
    out = []
    reels = len(grid)
    if g.get("mode") == "cluster":
        return cluster_wins(g, grid, stake, mult)
    if g.get("mode", "lines") == "lines":
        lb = stake // len(g["lines"])
        sw = g.get("scatter_wild")
        for line in g["lines"]:
            h = line_hit(g, [WILD if sw and grid[r][line[r]] == SCATTER else grid[r][line[r]] for r in range(reels)])
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
                            # Joker mit Multiplikator zählt als so viele Wege
                            c += (wm or {}).get(i * g["rows"] + row, 1) if x == WILD else 1
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
    start = g.get("start_reels", 0)
    for ri, st in enumerate(strips):
        h = rng.choice(g["heights"]) if g.get("heights") else g["rows"]
        if start and ri >= start:
            h = 0
        s = rng.randrange(len(st))
        stops.append(s)
        grid.append([st[(s + row) % len(st)] for row in range(h)])
    if free and g.get("giant"):
        n = g["giant"]
        r0, row0 = (reels - n) // 2, (g["rows"] - n) // 2
        st = strips[r0 + n // 2]
        while True:
            sym = rng.choice(st)
            if sym not in (SCATTER, COIN, BONUS):
                break
        for r in range(r0, r0 + n):
            for row in range(row0, row0 + n):
                grid[r][row] = sym
    if not free:
        g["_sticky"] = set()
        g["_book"] = None
    elif g.get("sticky"):
        held = g.setdefault("_sticky", set())
        for r, row in held:
            if row < len(grid[r]):
                grid[r][row] = WILD
        for r in range(reels):
            for row, x in enumerate(grid[r]):
                if x == WILD:
                    held.add((r, row))
    wm = {}
    if g.get("wild_mults"):
        vals, wts = g["wild_mults"]
        for r in range(reels):
            for row, x in enumerate(grid[r]):
                if x == WILD:
                    wm[r * g["rows"] + row] = rng.choices(vals, wts)[0]
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
        ws = wins(g, shown, stake, m, wm if steps == 0 else None)
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
                # Wie SlotEngine: Streu- und Bonussymbole fallen nicht nach
                while True:
                    above[r] = (above[r] - 1) % len(strips[r])
                    if g.get("scatter_drop") or strips[r][above[r]] not in (SCATTER, BONUS):
                        break
                fresh.insert(0, strips[r][above[r]])
            nxt.append(fresh + kept)
        shown = expand(g, nxt, free)
    info["steps"] = steps
    # Endlose Walzen: jeder Gewinn öffnet rechts eine Walze, alle offenen drehen neu
    if start:
        open_ = start
        last_win = total > 0
        info["open"] = open_
        while last_win and open_ < reels:
            open_ += 1
            nxt = []
            for r in range(reels):
                if r >= open_:
                    nxt.append([])
                    continue
                st = strips[r]
                i = rng.randrange(len(st))
                col = []
                while len(col) < g["rows"]:
                    x = st[i % len(st)]
                    i += 1
                    if x != SCATTER:
                        col.append(x)
                nxt.append(col)
            m = base * ((open_ - start + 1) if free else 1)
            ws = wins(g, nxt, stake, m)
            w = sum(x[0] for x in ws)
            total += w
            last_win = len(ws) > 0
            info["open"] = open_
    # Wandernde Joker im Grundspiel: Joker rücken nach links, der Rest dreht neu (ohne Streusymbole)
    if g.get("walking") and not free:
        walking = [(r, row) for r in range(reels) for row in range(len(shown[r])) if shown[r][row] == WILD]
        n = 1
        while n < 20:
            walking = [(r - 1, row) for r, row in walking if r > 0]
            if not walking:
                break
            nxt = []
            for r in range(reels):
                st = strips[r]
                i = rng.randrange(len(st))
                col = []
                while len(col) < len(grid[r]):
                    x = st[i % len(st)]
                    i += 1
                    if x != SCATTER:
                        col.append(x)
                nxt.append(col)
            held = set(walking)
            for r, row in walking:
                nxt[r][row] = WILD
            for r in range(reels):
                for row in range(len(nxt[r])):
                    if nxt[r][row] == WILD and (r, row) not in held:
                        walking.append((r, row))
            total += sum(w[0] for w in wins(g, nxt, stake, base))
            n += 1
        info["respins"] = n - 1
    # Buch-Freispiele: Sondersymbol füllt alle Walzen, auf denen es liegt, und zahlt auf allen Linien
    book = g.get("_book")
    if free and g.get("book") and book is not None:
        n = sum(1 for c in shown if book in c)
        p = pay(g, book, n)
        if p:
            total += p * (stake // len(g["lines"])) * len(g["lines"]) * base
            info["book"] = n
    # Wie SlotEngine: im Raster vor dem Ausfüllen der Joker zählen (fallen in Kaskaden nicht nach)
    flat = [x for c in (shown if g.get("scatter_drop") else grid) for x in c]
    info["cascade_scatter"] = flat.count(SCATTER) >= 3 and sum(c.count(SCATTER) for c in grid) < 3
    scatters = flat.count(SCATTER)
    bonus = flat.count(BONUS)
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
    if g.get("book") and freewon and g.get("_book") is None:
        g["_book"] = rng.choice(g.get("book_choices", [0, 1, 2, 3, 4, 5]))
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
