#!/usr/bin/env python3
"""Stimmt die Walzen des Slots "Kosmos 78" ab und schreibt lib/games/slots/slot_data.dart.

Ablauf: Gewichte je Walze vorgeben, Auszahlung per Monte-Carlo schaetzen, die
Dart-Datei erzeugen. Die Logik entspricht lib/games/slots/slot_engine.dart;
test/slot_engine_test.dart prueft das Ergebnis erneut mit dem echten Dart-Code.
"""
import random
import sys
from pathlib import Path

import numpy as np

SYMBOLS = ["mond", "stern", "komet", "planet", "ufo", "rakete", "sonne", "loch"]
WILD, SCATTER = 6, 7
PAYS = {
    0: {3: 3, 4: 8, 5: 25},
    1: {3: 4, 4: 10, 5: 30},
    2: {3: 5, 4: 15, 5: 50},
    3: {3: 8, 4: 25, 5: 100},
    4: {3: 12, 4: 50, 5: 200},
    5: {3: 20, 4: 100, 5: 500},
    6: {3: 50, 4: 250, 5: 1000},
}
SCATTER_PAY = {3: 2, 4: 5, 5: 20}  # Vielfaches des Gesamteinsatzes
FREE_SPINS, FREE_MULT = 8, 2
LINES = [
    [1, 1, 1, 1, 1], [0, 0, 0, 0, 0], [2, 2, 2, 2, 2], [0, 1, 2, 1, 0], [2, 1, 0, 1, 2],
    [0, 0, 1, 2, 2], [2, 2, 1, 0, 0], [1, 0, 0, 0, 1], [1, 2, 2, 2, 1], [1, 0, 1, 2, 1],
]
# Anzahl je Symbol auf jeder Walze (mond..loch)
WEIGHTS = [
    [8, 7, 6, 5, 3, 2, 1, 2],
    [8, 7, 6, 5, 3, 2, 2, 1],
    [8, 7, 6, 5, 3, 2, 2, 2],
    [8, 7, 6, 5, 3, 2, 2, 1],
    [8, 7, 6, 5, 3, 2, 1, 2],
]


def build_strips(seed=78):
    rng = random.Random(seed)
    strips = []
    for w in WEIGHTS:
        s = [i for i, n in enumerate(w) for _ in range(n)]
        best, score = None, 10**9
        for _ in range(500):  # gleiche Symbole moeglichst nicht direkt hintereinander
            rng.shuffle(s)
            c = sum(s[i] == s[(i + 1) % len(s)] for i in range(len(s)))
            if c < score:
                best, score = s[:], c
        strips.append(best)
    return strips


def line_pay(sym):
    """sym: 5 Symbole einer Linie. Multiplikator des Linieneinsatzes."""
    first = next((x for x in sym if x != WILD), WILD)
    if first == SCATTER:
        first = WILD
    count = 0
    for x in sym:
        if x == first or x == WILD:
            count += 1
        else:
            break
    if sym[0] == SCATTER:
        count = 0
    best = PAYS[first].get(count, 0) if first != SCATTER else 0
    wild_run = 0
    for x in sym:
        if x == WILD:
            wild_run += 1
        else:
            break
    return max(best, PAYS[WILD].get(wild_run, 0))


def simulate(strips, n=2_000_000, seed=1):
    rng = np.random.default_rng(seed)
    grids = np.zeros((n, 3, 5), dtype=np.int8)
    for r, st in enumerate(strips):
        arr = np.array(st, dtype=np.int8)
        stops = rng.integers(0, len(st), n)
        for row in range(3):
            grids[:, row, r] = arr[(stops + row) % len(st)]
    # Linien ueber Lookup auf eindeutige 5er-Kombinationen
    powers = 8 ** np.arange(5)
    table = {}
    total = np.zeros(n)
    for line in LINES:
        syms = grids[np.arange(n)[:, None], np.array(line)[None, :], np.arange(5)[None, :]]
        keys = (syms.astype(np.int64) * powers).sum(axis=1)
        uniq, inv = np.unique(keys, return_inverse=True)
        vals = np.zeros(len(uniq))
        for i, k in enumerate(uniq):
            k = int(k)
            if k not in table:
                table[k] = line_pay([(k >> (3 * j)) & 7 for j in range(5)])
            vals[i] = table[k]
        total += vals[inv]
    line_rtp = total.sum() / (10 * n)
    scatters = (grids == SCATTER).sum(axis=(1, 2))
    sc_pay = np.zeros(n)
    for c, p in SCATTER_PAY.items():
        sc_pay[scatters == c] = p
    sc_pay[scatters > 5] = SCATTER_PAY[5]
    sc_rtp = sc_pay.mean()
    trig = (scatters >= 3).mean()
    base = line_rtp + sc_rtp
    # jeder Ausloeser: FREE_SPINS Spins, Retrigger als geometrische Reihe
    per_trigger = FREE_SPINS * FREE_MULT * base / (1 - trig * FREE_SPINS)
    rtp = base + trig * per_trigger
    hit = ((total + sc_pay) > 0).mean()
    return dict(line=line_rtp, scatter=sc_rtp, trigger=trig, hit=hit, rtp=rtp)


def write_dart(strips, path):
    body = ",\n".join(f"  [{', '.join(map(str, s))}]" for s in strips)
    Path(path).write_text(
        "// Erzeugt von tool/tune_slot.py. Nicht von Hand aendern.\n"
        "const List<List<int>> kosmosStrips = [\n" + body + ",\n];\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    strips = build_strips()
    print([len(s) for s in strips])
    print(simulate(strips))
    if len(sys.argv) > 1:
        write_dart(strips, sys.argv[1])
