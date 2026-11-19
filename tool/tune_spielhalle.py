"""Abstimmung für den Spielhallen-Automaten (lib/games/arcade/arcade_engine.dart).

Gleiche Regeln wie im Spiel: 3 Walzen, eine Gewinnlinie (Mitte). Nach Drehungen ohne Gewinn bietet der Automat
manchmal Halten oder Nachschieben an; der Spieler nutzt sie hier so, wie es die eingebaute Hilfe vorschlägt.
3 Sterne bringen Sonderspiele mit doppeltem Gewinn. Die Risikoleiter ist fair (50 %) und ändert die Quote nicht.

Aufruf: python3 tool/tune_spielhalle.py [drehungen]
"""
import random
import sys

SYMS = ['Kirsche', 'Zitrone', 'Orange', 'Pflaume', 'Melone', 'Glocke', 'Stern', 'Sieben']
# Walzen (je 22 Stopps), Index in SYMS
STRIPS = [
    [0, 1, 2, 0, 3, 1, 4, 0, 2, 5, 1, 3, 0, 6, 2, 1, 4, 0, 3, 7, 1, 2],
    [1, 0, 3, 2, 1, 4, 2, 0, 5, 1, 3, 2, 6, 1, 0, 4, 2, 3, 7, 1, 2, 3],
    [2, 1, 3, 0, 4, 2, 1, 5, 3, 2, 1, 6, 4, 2, 3, 1, 7, 2, 4, 1, 3, 2],
]
THREE = {7: 100, 5: 40, 4: 20, 3: 12, 2: 10, 1: 6, 0: 5}
FREE_SPINS = 10
FREE_MULT = 2
HOLD_CHANCE = 0.22
NUDGE_CHANCE = 0.15


def line_pay(line):
    a, b, c = line
    if a == b == c:
        if a == 6:
            return 0
        return THREE[a]
    if a == 0 and b == 0:
        return 3
    if a == 0:
        return 1
    return 0


def stars(line):
    return all(s == 6 for s in line)


def spin_pos(rng):
    return [rng.randrange(len(s)) for s in STRIPS]


def line_of(pos):
    return [STRIPS[i][pos[i]] for i in range(3)]


def hold_choice(line):
    """Hilfe: Paare halten (bestes Symbol), sonst eine Kirsche auf Walze 1."""
    a, b, c = line
    best = None
    for i, j in ((0, 1), (0, 2), (1, 2)):
        if line[i] == line[j] and line[i] != 6:
            if best is None or THREE[line[i]] > THREE[line[best[0]]]:
                best = (i, j)
    if best:
        return set(best)
    if a == 0:
        return {0}
    if a == 6 and b == 6:
        return {0, 1}
    return set()


def nudge_best(pos):
    """Jede Walze darf einmal ±1 geschoben werden; bester Gewinn (ein Schub insgesamt)."""
    best_pay, best = line_pay(line_of(pos)), None
    for r in range(3):
        for d in (-1, 1):
            p = list(pos)
            p[r] = (p[r] + d) % len(STRIPS[r])
            l = line_of(p)
            pay = line_pay(l) + (1000 if stars(l) else 0)
            if pay > best_pay:
                best_pay, best = pay, p
    return best


def play(rng, spins):
    staked = paid = 0
    hold = set()
    held_pos = None
    free = 0
    for _ in range(spins):
        if free > 0:
            free -= 1
            mult = FREE_MULT
        else:
            staked += 1
            mult = 1
        pos = spin_pos(rng)
        if hold and held_pos:
            for r in hold:
                pos[r] = held_pos[r]
        hold = set()
        line = line_of(pos)
        win = line_pay(line)
        if stars(line):
            free += FREE_SPINS
        if win == 0 and not stars(line) and mult == 1:
            # Entweder Nachschieben oder Halten, wie im Spiel
            if rng.random() < NUDGE_CHANCE:
                p = nudge_best(pos)
                if p:
                    pos = p
                    line = line_of(pos)
                    win = line_pay(line)
                    if stars(line):
                        free += FREE_SPINS
            elif rng.random() < HOLD_CHANCE:
                hold = hold_choice(line)
                held_pos = pos
        paid += win * mult
    return paid / staked


if __name__ == '__main__':
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 2_000_000
    rng = random.Random(1)
    print(f'Quote {play(rng, n) * 100:.2f} %')
