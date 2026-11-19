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

LINES10 = [[1, 1, 1, 1, 1], [0, 0, 0, 0, 0], [2, 2, 2, 2, 2], [0, 1, 2, 1, 0], [2, 1, 0, 1, 2],
           [0, 0, 1, 2, 2], [2, 2, 1, 0, 0], [1, 0, 0, 0, 1], [1, 2, 2, 2, 1], [1, 0, 1, 2, 1]]

# Gewichte je Walze für die Symbole 0–9 (0–5 normal, 6 Joker, 7 Scatter, 8 Münze, 9 Bonus)
GAMES = {
    "mine": dict(
        mode="ways", anywhere=False, div=100, rows=3, stake=100,
        weights=[[9, 8, 7, 6, 4, 3, 0, 1, 0, 0], [9, 8, 7, 6, 4, 3, 2, 1, 0, 0], [9, 8, 7, 6, 4, 3, 2, 1, 0, 0],
                 [9, 8, 7, 6, 4, 3, 2, 1, 0, 0], [9, 8, 7, 6, 4, 3, 0, 1, 0, 0]],
        pays={0: [3, 4, 12], 1: [3, 7, 13], 2: [4, 9, 18], 3: [4, 12, 23], 4: [7, 18, 45], 5: [12, 27, 91]},
        cascade=[1, 2, 3, 5], free_cascade=[2, 4, 6, 10],
        scatter=[2, 5, 20], free=10, seed=1849),
    # Edelsteinmine, Variante B (Einstellung): Grubenlampen fallen in Kaskaden nach und zählen am Ende.
    # Längere Walzen, damit die Freispiele nicht zu oft kommen.
    "mineB": dict(
        mode="ways", anywhere=False, div=100, rows=3, stake=100, scatter_drop=True,
        weights=[[11, 10, 8, 7, 5, 4, 0, 1, 0, 0], [11, 10, 8, 7, 5, 4, 2, 1, 0, 0], [11, 10, 8, 7, 5, 4, 2, 1, 0, 0],
                 [11, 10, 8, 7, 5, 4, 2, 1, 0, 0], [11, 10, 8, 7, 5, 4, 0, 1, 0, 0]],
        pays={0: [4, 5, 15], 1: [4, 9, 18], 2: [5, 12, 25], 3: [5, 16, 31], 4: [9, 25, 61], 5: [16, 36, 124]},
        cascade=[1, 2, 3, 5], free_cascade=[2, 4, 6, 10],
        scatter=[2, 5, 20], free=10, seed=1850),
    # 3 × 3 mit 27 Wegen, Joker mit Multiplikator ×2, ×3 oder ×5 (zählt als so viele Wege)
    "frucht": dict(
        mode="ways", anywhere=False, div=20, rows=3, stake=100,
        weights=[[10, 9, 8, 7, 5, 4, 0, 0, 0, 0], [10, 9, 8, 7, 5, 4, 3, 0, 0, 0], [10, 9, 8, 7, 5, 4, 0, 0, 0, 0]],
        pays={0: [5], 1: [8], 2: [10], 3: [15], 4: [24], 5: [58]},
        wild_mults=([2, 3, 5], [6, 3, 1]),
        seed=1977),
    # 3 × 3, 27 Wege, Kaskaden; neun Fruchtsorten (0–5 und 10–12), damit nicht ständig wieder etwas passt
    "lawine": dict(
        mode="ways", anywhere=False, div=20, rows=3, stake=100,
        weights=[[8, 8, 7, 6, 5, 4, 0, 2, 0, 0, 8, 7, 6], [8, 8, 7, 6, 5, 4, 2, 2, 0, 0, 8, 7, 6],
                 [8, 8, 7, 6, 5, 4, 0, 2, 0, 0, 8, 7, 6]],
        pays={0: [15], 1: [15], 10: [18], 2: [22], 11: [26], 3: [29], 12: [36], 4: [51], 5: [110]},
        cascade=[1, 2, 3, 5], free_cascade=[2, 4, 6, 10],
        scatter=[3], free=8, seed=2611),
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
        pays={0: [1, 2, 5, 9], 1: [2, 3, 6, 12], 2: [2, 4, 7, 15], 3: [2, 5, 9, 21], 4: [4, 7, 15, 35],
              5: [6, 12, 29, 71]},
        cascade=[1, 2, 2, 3, 3], free_cascade=[2, 3, 4, 5, 6, 8],
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
    # Mega-Slot „mit allem“: sechs Walzen mit wechselnder Höhe, Kaskaden, Joker ×2/×3, liegende Joker in Freispielen,
    # Glücksmünzen mit Hold & Spin und Bonusrad. Anteile etwa: Wege 55 %, Freispiele 19 %, Hold & Spin 15 %, Rad 6 %.
    "pharao": dict(
        mode="ways", anywhere=False, div=500, rows=5, heights=[2, 3, 4, 5], stake=500, sticky=True,
        weights=[[18, 16, 14, 12, 8, 6, 0, 1, 7, 2], [18, 16, 14, 12, 8, 6, 4, 1, 7, 0], [18, 16, 14, 12, 8, 6, 4, 1, 7, 2],
                 [18, 16, 14, 12, 8, 6, 4, 1, 7, 0], [18, 16, 14, 12, 8, 6, 4, 1, 7, 2], [18, 16, 14, 12, 8, 6, 0, 1, 7, 0]],
        pays={0: [2, 5, 13, 24], 1: [5, 8, 16, 32], 2: [5, 11, 19, 40], 3: [6, 13, 24, 55], 4: [11, 19, 40, 92],
              5: [16, 32, 77, 187]},
        cascade=[1, 2, 3, 5], free_cascade=[2, 4, 6, 10], wild_mults=([2, 3], [3, 1]),
        scatter=[2, 5, 20], free=10,
        hold=dict(trigger=6, respins=3, chance=0.04,
                  values=[10, 20, 30, 40, 50, 100, 200, 400, 1000, 4000],
                  weights=[300, 250, 180, 120, 80, 40, 15, 8, 3, 1], grand=10000),
        wheel=[("coins", 50, 6), ("coins", 100, 4), ("free", 10, 4), ("holdSpin", 6, 3), ("coins", 200, 2),
               ("free", 15, 2), ("coins", 500, 1)],
        seed=777),
    # Zauberbibliothek: 10 Linien, das Buch ist Joker und Streusymbol, Buch-Freispiele mit Sondersymbol
    "buch": dict(
        mode="lines", lines=LINES10, rows=3, stake=100, scatter_wild=True, book=True,
        book_choices=[0, 1, 2, 10, 11, 3, 12, 4, 5],
        weights=[[8, 8, 7, 6, 5, 4, 0, 2, 0, 0, 6, 6, 5]] * 5,
        pays={0: [5, 25, 100], 1: [5, 25, 100], 2: [5, 25, 100], 10: [5, 40, 150], 11: [5, 40, 150],
              3: [10, 50, 250], 12: [15, 60, 300], 4: [20, 80, 500], 5: [50, 250, 2000]},
        scatter=[2, 20, 200], free=10, seed=1517),
    # Bonbonfabrik: 7 × 7, Gruppen ab 5, Kaskaden
    "bonbon": dict(
        mode="cluster", cluster_min=5, div=100, rows=7, stake=100, random_strips=True,
        weights=[[16, 16, 15, 13, 12, 10, 1, 1, 0, 0, 15, 13]] * 7,
        pays={0: [160, 200, 250, 330, 400, 600, 800, 1200, 2000, 3500, 8000],
              1: [160, 200, 250, 330, 400, 600, 800, 1200, 2000, 3500, 8000],
              10: [200, 250, 330, 400, 600, 800, 1200, 1600, 2500, 4000, 10000],
              2: [200, 250, 330, 400, 600, 800, 1200, 1600, 2500, 4000, 10000],
              11: [250, 330, 400, 600, 800, 1200, 1600, 2500, 3500, 6000, 12000],
              3: [330, 400, 600, 800, 1200, 1600, 2500, 3500, 5000, 8000, 20000],
              4: [400, 600, 800, 1200, 1600, 2500, 3500, 5000, 8000, 12000, 30000],
              5: [800, 1200, 1600, 2500, 3500, 5000, 8000, 12000, 20000, 40000, 80000]},
        cascade=[1, 2, 3, 4, 5], free_cascade=[2, 4, 6, 8, 10],
        scatter=[3, 10, 50], free=10, seed=1893),
    # Goldgräber: 243 Wege, wandernde Joker im Grundspiel, 3 × 3 Riesensymbol in Freispielen
    "gold": dict(
        mode="ways", anywhere=False, div=20, rows=3, stake=100, walking=True, giant=3,
        weights=[[16, 16, 14, 9, 7, 5, 1, 5, 0, 0, 14, 12], [16, 16, 14, 9, 7, 5, 1, 0, 0, 0, 14, 12],
                 [16, 16, 14, 9, 7, 5, 1, 5, 0, 0, 14, 12], [16, 16, 14, 9, 7, 5, 1, 0, 0, 0, 14, 12],
                 [16, 16, 14, 9, 7, 5, 1, 5, 0, 0, 14, 12]],
        pays={0: [2, 5, 15], 1: [2, 5, 15], 10: [2, 6, 18], 11: [2, 6, 18], 2: [3, 8, 25], 3: [4, 12, 40], 4: [6, 16, 60],
              5: [12, 35, 125]},
        scatter=[2, 10, 50], free=8, seed=1849),
    # Runenpfad: endlose Walzen, 3 von 8 offen, jeder Gewinn öffnet die nächste
    "runen": dict(
        mode="ways", anywhere=False, div=10, rows=3, stake=100, start_reels=3,
        weights=[[12, 12, 11, 7, 5, 4, 1, 2, 0, 0, 11, 10]] * 3 + [[12, 12, 11, 7, 5, 4, 1, 0, 0, 0, 11, 10]] * 5,
        pays={0: [4, 8, 16, 35, 65, 130], 1: [4, 8, 16, 35, 65, 130], 10: [4, 9, 20, 40, 85, 170],
              11: [4, 9, 20, 40, 85, 170], 2: [8, 13, 25, 50, 105, 210], 3: [13, 21, 42, 105, 210, 425],
              4: [17, 34, 64, 170, 340, 850], 5: [25, 50, 105, 255, 640, 1700]},
        scatter=[3], free=8, seed=2401),
}


def build_strips(g):
    rng = random.Random(g["seed"])
    strips = []
    for w in g["weights"]:
        s = [i for i, n in enumerate(w) for _ in range(n)]
        best, score = None, 10**9
        # Gruppen-Slots: einfach gemischt, gleiche Nachbarn sind dort erwünscht
        for _ in range(1 if g.get("random_strips") else 500):
            rng.shuffle(s)
            # keine gleichen Nachbarn, Sonder-Symbole nicht direkt untereinander
            c = sum(s[i] == s[(i + 1) % len(s)] or (6 <= s[i] <= 9 and 6 <= s[(i + 1) % len(s)] <= 9) for i in range(len(s)))
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
