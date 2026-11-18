#!/usr/bin/env python3
"""Stimmt die Walzen aller Slots ab und schreibt lib/games/slots/slot_data.dart.

Die Wertung entspricht lib/games/slots/slot_engine.dart. Die Dart-Tests pruefen
das Ergebnis noch einmal mit dem echten Code.
"""
import random
import sys
from pathlib import Path

import numpy as np

WILD, SCATTER = 6, 7
KOSMOS_LINES = [
    [1, 1, 1, 1, 1], [0, 0, 0, 0, 0], [2, 2, 2, 2, 2], [0, 1, 2, 1, 0], [2, 1, 0, 1, 2],
    [0, 0, 1, 2, 2], [2, 2, 1, 0, 0], [1, 0, 0, 0, 1], [1, 2, 2, 2, 1], [1, 0, 1, 2, 1],
]
TIEFSEE_LINES = [
    [1, 1, 1, 1, 1], [2, 2, 2, 2, 2], [0, 0, 0, 0, 0], [3, 3, 3, 3, 3], [0, 1, 2, 1, 0],
    [3, 2, 1, 2, 3], [1, 2, 3, 2, 1], [2, 1, 0, 1, 2], [0, 1, 0, 1, 0], [3, 2, 3, 2, 3],
    [1, 0, 1, 0, 1], [2, 3, 2, 3, 2], [0, 0, 1, 2, 3], [3, 3, 2, 1, 0], [1, 1, 2, 3, 3],
    [2, 2, 1, 0, 0], [0, 1, 1, 1, 0], [3, 2, 2, 2, 3], [1, 2, 2, 2, 1], [2, 1, 1, 1, 2],
]
GARTEN_LINES = [[1, 1, 1], [0, 0, 0], [2, 2, 2], [0, 1, 2], [2, 1, 0]]

GAMES = {
    "kosmos": dict(
        rows=3, lines=KOSMOS_LINES,
        weights=[[8, 7, 6, 5, 3, 2, 1, 2], [8, 7, 6, 5, 3, 2, 2, 1], [8, 7, 6, 5, 3, 2, 2, 2],
                 [8, 7, 6, 5, 3, 2, 2, 1], [8, 7, 6, 5, 3, 2, 1, 2]],
        pays={0: [3, 8, 25], 1: [4, 10, 30], 2: [5, 15, 50], 3: [8, 25, 100], 4: [12, 50, 200],
              5: [20, 100, 500], 6: [50, 250, 1000]},
        scatter=[2, 5, 20], free=8, mult=2, expand=False, wildmult=False, seed=78),
    "tiefsee": dict(
        rows=4, lines=TIEFSEE_LINES,
        weights=[[10, 9, 8, 7, 4, 3, 0, 1], [10, 9, 8, 7, 4, 3, 2, 2], [10, 9, 8, 7, 4, 3, 3, 1],
                 [10, 9, 8, 7, 4, 3, 2, 2], [10, 9, 8, 7, 4, 3, 0, 1]],
        pays={0: [5, 10, 25], 1: [5, 15, 40], 2: [8, 20, 60], 3: [10, 30, 100], 4: [15, 60, 200],
              5: [25, 100, 500], 6: [30, 150, 750]},
        scatter=[2, 6, 25], free=10, mult=1, expand=True, wildmult=False, seed=3000, ways=True),
    "garten": dict(
        rows=3, lines=GARTEN_LINES,
        weights=[[12, 10, 8, 6, 4, 2, 1, 0], [12, 10, 8, 6, 4, 2, 2, 0], [12, 10, 8, 6, 4, 2, 1, 0]],
        pays={0: [4], 1: [6], 2: [12], 3: [25], 4: [50], 5: [100], 6: [500]},
        scatter=[], free=0, mult=1, expand=False, wildmult=True, seed=1972),
}


def build_strips(g):
    rng = random.Random(g["seed"])
    strips = []
    for w in g["weights"]:
        s = [i for i, n in enumerate(w) for _ in range(n)]
        best, score = None, 10**9
        for _ in range(500):
            rng.shuffle(s)
            c = sum(s[i] == s[(i + 1) % len(s)] for i in range(len(s)))
            if c < score:
                best, score = s[:], c
        strips.append(best)
    return strips


def line_pay(sym, g):
    pays = g["pays"]
    def pay(symbol, n):
        return pays[symbol][n - 3] if 3 <= n <= 2 + len(pays[symbol]) else 0
    if sym[0] == SCATTER:
        return 0
    first = next((x for x in sym if x != WILD), WILD)
    if first == SCATTER:
        first = WILD
    count = 0
    wilds = 0
    for x in sym:
        if x == first or x == WILD:
            count += 1
            wilds += x == WILD
        else:
            break
    normal = pay(first, count)
    if g["wildmult"] and first != WILD:
        normal *= 2 ** wilds
    run = 0
    for x in sym:
        if x == WILD:
            run += 1
        else:
            break
    return max(normal, pay(WILD, run))


def spin_stats(strips, g, n, seed, free_mode):
    rng = np.random.default_rng(seed)
    rows = g["rows"]
    reels = len(strips)
    grids = np.zeros((n, rows, reels), dtype=np.int8)
    for r, st in enumerate(strips):
        arr = np.array(st, dtype=np.int8)
        stops = rng.integers(0, len(st), n)
        for row in range(rows):
            grids[:, row, r] = arr[(stops + row) % len(st)]
    scatters = (grids == SCATTER).sum(axis=(1, 2))
    if free_mode and g["expand"]:
        for r in range(1, reels - 1):
            has = (grids[:, :, r] == WILD).any(axis=1)
            grids[has, :, r] = WILD
    powers = 8 ** np.arange(reels)
    table = {}
    total = np.zeros(n)
    idx = np.arange(n)[:, None]
    cols = np.arange(reels)[None, :]
    for line in g["lines"]:
        syms = grids[idx, np.array(line)[None, :], cols]
        keys = (syms.astype(np.int64) * powers).sum(axis=1)
        uniq, inv = np.unique(keys, return_inverse=True)
        vals = np.zeros(len(uniq))
        for i, k in enumerate(uniq):
            k = int(k)
            if k not in table:
                table[k] = line_pay([(k >> (3 * j)) & 7 for j in range(reels)], g)
            vals[i] = table[k]
        total += vals[inv]
    line_rtp = total.sum() / (len(g["lines"]) * n)
    sc_rtp, trig = 0.0, 0.0
    sc = np.zeros(n)
    if g["scatter"]:
        for c, p in enumerate(g["scatter"]):
            sc[scatters == c + 3] = p
        sc[scatters > 5] = g["scatter"][-1]
        sc_rtp = sc.mean()
        trig = (scatters >= 3).mean()
    return line_rtp, sc_rtp, trig, ((total + sc) > 0).mean()


def report(name, strips, g, n=1_500_000):
    line, sc, trig, hit = spin_stats(strips, g, n, 1, False)
    base = line + sc
    rtp = base
    if g["free"]:
        fl, fs, ft, _ = spin_stats(strips, g, n, 2, True)
        per = g["free"] * g["mult"] * (fl + fs) / (1 - ft * g["free"])
        rtp = base + trig * per
    print(f"{name}: RTP {rtp:.4f} Linien {line:.4f} Scatter {sc:.4f} "
          f"Ausloeser {trig:.4f} Trefferquote {hit:.3f} Laenge {[len(s) for s in strips]}")


def main():
    out = ["// Erzeugt von tool/tune_slots.py. Nicht von Hand aendern."]
    for name, g in GAMES.items():
        strips = build_strips(g)
        if g.get("ways"):
            print(f"{name}: zahlt auf Wegen, RTP siehe tool/sim_slots.py")
        else:
            report(name, strips, g)
        body = ",\n".join(f"  [{', '.join(map(str, s))}]" for s in strips)
        out.append(f"\nconst List<List<int>> {name}Strips = [\n{body},\n];")
    if len(sys.argv) > 1:
        Path(sys.argv[1]).write_text("\n".join(out) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
