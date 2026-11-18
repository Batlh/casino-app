#!/usr/bin/env python3
"""Baut die Walzen der neuen Slots und stimmt sie ab. Schreibt lib/games/slots/slot_data_neu.dart.

Aufruf:  python3 tool/tune_new_slots.py [lib/games/slots/slot_data_neu.dart] [Drehungen]
Die Wertung steht in tool/sim_slots.py und entspricht SlotEngine.play().
"""
import random
import sys
from multiprocessing import Pool
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import sim_slots as S  # noqa: E402

# Gewichte je Walze für die Symbole 0–9 (0–5 normal, 6 Joker, 7 Scatter, 8 Münze, 9 Bonus)
GAMES = {
    "mine": dict(
        mode="ways", anywhere=False, div=100, rows=3, stake=100,
        weights=[[9, 8, 7, 6, 4, 3, 0, 1, 0, 0], [9, 8, 7, 6, 4, 3, 2, 1, 0, 0], [9, 8, 7, 6, 4, 3, 2, 1, 0, 0],
                 [9, 8, 7, 6, 4, 3, 2, 1, 0, 0], [9, 8, 7, 6, 4, 3, 0, 1, 0, 0]],
        pays={0: [3, 5, 14], 1: [3, 8, 16], 2: [5, 11, 22], 3: [5, 14, 27], 4: [8, 22, 54], 5: [14, 32, 108]},
        cascade=[1, 2, 3, 5], free_cascade=[2, 4, 6, 10],
        scatter=[2, 5, 20], free=10, seed=1849),
    "drachen": dict(
        mode="ways", anywhere=True, div=50, rows=3, stake=100,
        weights=[[9, 8, 7, 6, 4, 3, 0, 0, 6, 0], [9, 8, 7, 6, 4, 3, 2, 0, 6, 0], [9, 8, 7, 6, 4, 3, 2, 0, 6, 0],
                 [9, 8, 7, 6, 4, 3, 2, 0, 6, 0], [9, 8, 7, 6, 4, 3, 0, 0, 6, 0]],
        pays={0: [6, 16, 40], 1: [8, 20, 50], 2: [10, 25, 65], 3: [14, 33, 85], 4: [20, 50, 170], 5: [33, 85, 340]},
        hold=dict(trigger=6, respins=3, chance=0.03,
                  values=[5, 10, 15, 20, 25, 50, 100, 200, 500, 2000],
                  weights=[300, 250, 180, 120, 80, 40, 15, 8, 3, 1], grand=10000),
        seed=1200),
    "jahrmarkt": dict(
        mode="ways", anywhere=True, div=50, rows=3, stake=100, expand=True,
        weights=[[9, 8, 7, 6, 4, 3, 0, 0, 0, 3], [9, 8, 7, 6, 4, 3, 2, 0, 0, 0], [9, 8, 7, 6, 4, 3, 2, 0, 0, 3],
                 [9, 8, 7, 6, 4, 3, 2, 0, 0, 0], [9, 8, 7, 6, 4, 3, 0, 0, 0, 3]],
        pays={0: [3, 9, 22], 1: [4, 11, 27], 2: [5, 13, 32], 3: [7, 16, 43], 4: [11, 27, 86], 5: [16, 43, 160]},
        wheel=[("coins", 5, 6), ("coins", 10, 5), ("coins", 15, 4), ("free", 8, 4), ("coins", 25, 3),
               ("holdSpin", 6, 3), ("coins", 50, 1), ("free", 12, 2)],
        hold=dict(trigger=6, respins=3, chance=0.03,
                  values=[5, 10, 15, 20, 25, 50, 100, 200, 500, 2000],
                  weights=[300, 250, 180, 120, 80, 40, 15, 8, 3, 1], grand=10000),
        free=0, seed=1954),
    # Sechs Walzen mit wechselnder Höhe (2 bis 5 Symbole), bis zu 4.096 Wege, Kaskaden
    "vulkan": dict(
        mode="ways", anywhere=False, div=500, rows=5, heights=[2, 3, 4, 5], stake=500,
        weights=[[9, 8, 7, 6, 4, 3, 0, 1, 0, 0]] + [[9, 8, 7, 6, 4, 3, 2, 1, 0, 0]] * 4 + [[9, 8, 7, 6, 4, 3, 0, 1, 0, 0]],
        pays={0: [1, 3, 6, 12], 1: [2, 4, 8, 15], 2: [2, 5, 9, 20], 3: [3, 6, 12, 27], 4: [5, 9, 19, 46],
              5: [8, 15, 38, 92]},
        cascade=[1, 2, 3, 4, 5], free_cascade=[2, 4, 6, 8, 10, 15],
        scatter=[2, 5, 20], free=12, seed=1815),
    # 1024 Wege; in Freispielen bleiben Kirschblüten (Joker) bis zum Ende liegen
    "sakura": dict(
        mode="ways", anywhere=False, div=100, rows=4, stake=100, sticky=True,
        weights=[[10, 9, 8, 7, 4, 3, 0, 1, 0, 0]] + [[10, 9, 8, 7, 4, 3, 1, 1, 0, 0]] * 3 + [[10, 9, 8, 7, 4, 3, 0, 1, 0, 0]],
        pays={0: [3, 9, 25], 1: [3, 12, 31], 2: [6, 15, 37], 3: [6, 18, 46], 4: [12, 31, 93], 5: [18, 49, 185]},
        scatter=[2, 5, 20], free=8, seed=2604),
    # Sechs Walzen mit wechselnder Höhe und Glücksmünzen (Hold & Spin auf 6 × 5 Feldern)
    "jade": dict(
        mode="ways", anywhere=False, div=100, rows=5, heights=[2, 3, 4, 5], stake=500,
        weights=[[9, 8, 7, 6, 4, 3, 0, 0, 4, 0]] + [[9, 8, 7, 6, 4, 3, 2, 0, 4, 0]] * 4 + [[9, 8, 7, 6, 4, 3, 0, 0, 4, 0]],
        pays={0: [4, 12, 22, 45], 1: [7, 15, 30, 57], 2: [8, 18, 33, 75], 3: [12, 22, 45, 100], 4: [19, 33, 71, 172],
              5: [30, 57, 141, 343]},
        # 4 % je Feld und Respin: Grand (alle 30 Felder) etwa alle 1,6 Mio. Drehungen statt praktisch nie
        hold=dict(trigger=6, respins=3, chance=0.04,
                  values=[5, 10, 15, 20, 25, 50, 100, 200, 500, 2000],
                  weights=[300, 250, 180, 120, 80, 40, 15, 8, 3, 1], grand=10000),
        seed=888),
}


def build_strips(g):
    rng = random.Random(g["seed"])
    strips = []
    for w in g["weights"]:
        s = [i for i, n in enumerate(w) for _ in range(n)]
        best, score = None, 10**9
        for _ in range(500):
            rng.shuffle(s)
            # keine gleichen Nachbarn, Sonder-Symbole nicht direkt untereinander
            c = sum(s[i] == s[(i + 1) % len(s)] or (s[i] >= 6 and s[(i + 1) % len(s)] >= 6) for i in range(len(s)))
            if c < score:
                best, score = s[:], c
        strips.append(best)
    return strips


def run(args):
    name, seed, spins = args
    g = dict(GAMES[name])
    g["strips"] = build_strips(g)
    return S.rtp(g, spins, seed=seed)


def main():
    out_path = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1].endswith(".dart") else None
    spins = int(sys.argv[-1]) if sys.argv[-1].isdigit() else 60000
    names = [n for n in GAMES if n in sys.argv] or list(GAMES)
    with Pool(2) as p:
        for name in names:
            res = p.map(run, [(name, s, spins) for s in (1, 2)])
            rtp = sum(r[0] for r in res) / len(res)
            print(f"{name}: RTP {rtp:.4f} ({', '.join(f'{r[0]:.3f}' for r in res)}) Treffer {res[0][1]:.3f} "
                  f"alle n Drehungen: {res[0][2]} groesster {res[0][3]:.0f}x")
    if out_path:
        lines = ["// Erzeugt von tool/tune_new_slots.py. Nicht von Hand aendern."]
        for name, g in GAMES.items():
            body = ",\n".join(f"  [{', '.join(map(str, s))}]" for s in build_strips(g))
            lines.append(f"\nconst List<List<int>> {name}Strips = [\n{body},\n];")
        Path(out_path).write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
