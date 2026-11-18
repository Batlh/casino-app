"""Flippertische als Daten: erzeugt lib/games/pinball/pinball_tables.dart und auf Wunsch Vorschaubilder.

Aufruf:  python3 tool/pinball_tables.py lib/games/pinball/pinball_tables.dart [Ordner für Vorschaubilder]
"""
import math, sys, os

OUT_DART = sys.argv[1]
OUT_DIR = sys.argv[2] if len(sys.argv) > 2 else None

FR = 9.25  # rechter Rand des Feldes


def outer():
    pts = [(0, 13.2), (0, 2.4), (2.2, 0), (5, 0)]
    for i in range(1, 30):
        a = -math.pi / 2 + math.pi / 2 * i / 30
        pts.append((5 + 4.95 * math.cos(a), 4 + 4 * math.sin(a)))
    pts += [(9.95, 4), (9.95, 18.2)]
    return pts


def lower(outlane=False):
    """Unterer Teil, bei allen Tischen gleich (geprüft gegen hängende Kugeln).
    outlane: links eine Auslaufbahn an der Wand entlang (für den Rückschuss), die Führung beginnt erst bei x = 0,9."""
    walls = [
        dict(p=outer()),
        dict(p=[(0.9, 13.28) if outlane else (0, 12.4), (2.5, 14.85)]),
        dict(p=[(FR, 12.4), (6.75, 14.85)]),
        dict(p=[(0, 13.2), (0, 16.3), (1.2, 18.2)]),
        dict(p=[(FR, 16.3), (8.05, 18.2)]),
    ]
    for x in [2.8, 4.0, 5.2, 6.4]:
        walls.append(dict(p=[(x, 1.9), (x, 2.9)], b=0.4))
    slings = [((2.0, 11.6), (2.9, 13.8), (2.0, 13.2)), ((7.25, 11.6), (6.35, 13.8), (7.25, 13.2))]
    flippers = [((2.6, 15.3), 1), ((6.65, 15.3), -1)]
    lanes = [dict(x=x, y=2.4, g='top', hw=0.5) for x in [3.4, 4.6, 5.8]]
    return walls, slings, flippers, lanes


def ramp_left(rid, name, exit_right=True, points=1000):
    """Rampe links: Mund zwischen zwei Führungen, Rückwand oben; die Bahn führt über den Tisch in die rechte Rücklaufbahn."""
    walls = [
        dict(p=[(0.9, 10.2), (1.1, 7.4)]),
        dict(p=[(2.0, 10.0), (2.2, 7.4)]),
        dict(p=[(1.1, 7.4), (1.65, 6.85), (2.2, 7.4)], b=0.2),  # Dach: oben rollt die Kugel ab
    ]
    path = [(1.52, 9.0), (1.62, 6.6), (1.9, 4.2), (2.9, 1.5), (4.6, 0.75), (6.6, 1.3), (8.0, 3.0), (8.75, 5.6),
            (8.85, 8.8), (8.55, 11.4), (8.05, 12.75)]
    ramp = dict(id=rid, name=name, a=(0.95, 9.2), b=(2.07, 9.2), d=(0, -1), path=path, v=(-2.6, 2.4), pts=points, ms=5)
    return walls, ramp


def ramp_right(rid, name, points=1000):
    walls = [
        dict(p=[(8.35, 10.2), (8.15, 7.4)]),
        dict(p=[(7.25, 10.0), (7.05, 7.4)]),
        dict(p=[(7.05, 7.4), (7.6, 6.85), (8.15, 7.4)], b=0.2),
    ]
    path = [(7.73, 9.0), (7.63, 6.6), (7.35, 4.2), (6.35, 1.5), (4.65, 0.75), (2.65, 1.3), (1.25, 3.0), (0.5, 5.6),
            (0.4, 8.8), (0.7, 11.4), (1.2, 12.75)]
    ramp = dict(id=rid, name=name, a=(7.18, 9.2), b=(8.3, 9.2), d=(0, -1), path=path, v=(2.6, 2.4), pts=points, ms=5)
    return walls, ramp


def merge(*parts):
    w, r = [], []
    for pw, pr in parts:
        w += pw
        r.append(pr)
    return w, r


TABLES = []

# ------------------------------------------------------------------ Neon Nacht
w, s, f, l = lower()
TABLES.append(dict(
    id='neon', name='Neon Nacht', blurb='Der Klassiker: fünf Pilze, Fallziele, Spinner und ein Loch für den Multiball',
    theme=dict(top=0xFF241047, mid=0xFF3A0F55, bottom=0xFF120726, wall=0xFF63E6FF, bumper=0xFFFF5EA8, sling=0xFF34E89E,
               flipper=0xFFFFC95C, accent=0xFFFF5EA8, light=0xFFFFC95C, ramp=0xFF63E6FF, dmd=0xFFFF8A3D, art='neon'),
    walls=w, slings=s, flippers=f, lanes=l,
    bumpers=[(3.0, 4.8), (6.2, 4.8), (4.6, 6.8), (1.3, 8.6), (7.9, 8.6)],
    drops=[dict(id='rechts', t=[(8.75, 5.5), (8.75, 6.1), (8.75, 6.7)], a=math.pi / 2)],
    spinners=[dict(id='links', a=(0.02, 6.4), b=(0.95, 6.4))],
    saucers=[dict(id='mitte', x=4.6, y=3.95, e=(-1.6, 3.6), lock=True)],
    missions=[('Pilze 25 mal', 'bumper', 25, None), ('Alle drei Gassen', 'lanes', 1, 'top'),
              ('Spinner 15 Umdrehungen', 'spinner', 15, None), ('Fallziele abräumen', 'drops', 1, None),
              ('Loch 3 mal treffen', 'saucer', 3, None)],
    labels=[('NEON NACHT', (4.6, 10.4), 0.55)],
))

# ------------------------------------------------------------------ Weltraumstation
w, s, f, l = lower()
rw, rr = merge(ramp_left('rakete', 'Raketenrampe'))
w += rw
w.append(dict(p=[(2.95, 7.9), (2.95, 9.1)], b=0.45, inv=True))  # unter den Planeten-Zielen
TABLES.append(dict(
    id='space', name='Weltraumstation', blurb='Raketenrampe, Satelliten-Fallziele und Andockschleuse für drei Kugeln',
    theme=dict(top=0xFF050B24, mid=0xFF0B1A44, bottom=0xFF02040F, wall=0xFF8FB8FF, bumper=0xFF5EE1FF, sling=0xFFB388FF,
               flipper=0xFFE8EEF8, accent=0xFFFFB74D, light=0xFF5EE1FF, ramp=0xFFB388FF, dmd=0xFF7FE0FF, art='space'),
    walls=w, slings=s, flippers=f, lanes=l, ramps=rr,
    bumpers=[(3.6, 4.6), (5.6, 4.6), (4.6, 6.2)],
    drops=[dict(id='satelliten', t=[(7.45, 6.4), (7.75, 6.92), (8.05, 7.44)], a=1.05)],
    targets=[dict(id='planeten', t=[(2.95, 8.2), (2.95, 8.8)], a=math.pi / 2)],
    spinners=[dict(id='orbit', a=(0.02, 8.5), b=(1.0, 8.5))],
    saucers=[dict(id='schleuse', x=6.95, y=4.1, e=(-2.2, 3.6), lock=True)],
    missions=[('Raketenstart: Rampe 3 mal', 'ramp', 3, 'rakete'), ('Satelliten abschießen', 'drops', 1, None),
              ('Orbit 20 Umdrehungen', 'spinner', 20, None), ('Andocken: 3 Kugeln fangen', 'lock', 3, None),
              ('Planeten 6 Treffer', 'targets', 6, None)],
    labels=[('STATION', (4.6, 10.4), 0.5)],
))

# ------------------------------------------------------------------ Piratenbucht
w, s, f, l = lower()
rw, rr = merge(ramp_right('schiff', 'Schiffsrampe'))
w += rw
TABLES.append(dict(
    id='pirate', name='Piratenbucht', blurb='Schiffsrampe, Kanonen-Fallziele und die Schatzkiste als Loch',
    theme=dict(top=0xFF0E3B4F, mid=0xFF0B5468, bottom=0xFF06212C, wall=0xFFF2D49B, bumper=0xFFE0533D, sling=0xFF3FA796,
               flipper=0xFFF2D49B, accent=0xFFFFC23D, light=0xFFFFC23D, ramp=0xFFC98B4B, dmd=0xFFFFB84D, art='pirate'),
    walls=w, slings=s, flippers=f, lanes=l, ramps=rr,
    bumpers=[(3.3, 4.9), (5.9, 4.9), (4.6, 6.4)],
    drops=[dict(id='kanonen', t=[(3.55, 8.35), (4.05, 8.58), (4.55, 8.81)], a=0.43)],
    targets=[dict(id='faesser', t=[(6.3, 7.9), (6.3, 8.5)], a=math.pi / 2)],
    spinners=[dict(id='wind', a=(8.28, 8.5), b=(9.23, 8.5))],
    saucers=[dict(id='schatz', x=1.35, y=6.6, e=(2.4, 3.2), lock=True)],
    missions=[('Entern: Schiffsrampe 3 mal', 'ramp', 3, 'schiff'), ('Kanonen abräumen', 'drops', 1, None),
              ('Schatzkiste 3 mal', 'lock', 3, None), ('Rückenwind: 20 Umdrehungen', 'spinner', 20, None),
              ('Fässer 6 Treffer', 'targets', 6, None)],
    labels=[('PIRATENBUCHT', (4.6, 10.4), 0.45)],
))

# ------------------------------------------------------------------ Spukschloss
w, s, f, l = lower()
rw, rr = merge(ramp_left('treppe', 'Geistertreppe'))
w += rw
w.append(dict(p=[(8.35, 10.2), (8.2, 6.5)]))  # Führung rechte Umlaufbahn
TABLES.append(dict(
    id='haunted', name='Spukschloss', blurb='Geister-Fallziele, die Gruft als Loch und eine Uhr, die sich dreht',
    theme=dict(top=0xFF1B1030, mid=0xFF2C1A45, bottom=0xFF0B0714, wall=0xFFB7F07A, bumper=0xFF9B6BFF, sling=0xFFB7F07A,
               flipper=0xFFE6DCC8, accent=0xFFFF8A3D, light=0xFFB7F07A, ramp=0xFF9B6BFF, dmd=0xFFB7F07A, art='haunted'),
    walls=w, slings=s, flippers=f, lanes=l, ramps=rr,
    bumpers=[(2.9, 5.2), (4.6, 4.5), (6.3, 5.2)],
    drops=[dict(id='geister', t=[(5.7, 8.7), (6.15, 8.45), (6.6, 8.2)], a=-0.5)],
    spinners=[dict(id='uhr', a=(8.3, 8.5), b=(9.23, 8.5))],
    saucers=[dict(id='gruft', x=4.6, y=7.3, e=(-1.6, 4.4), lock=True)],
    missions=[('Geister vertreiben', 'drops', 1, None), ('Die Treppe 3 mal hinauf', 'ramp', 3, 'treppe'),
              ('Mitternacht: Uhr 24 Umdrehungen', 'spinner', 24, None), ('Gruft 3 mal öffnen', 'lock', 3, None),
              ('Spuk: Pilze 20 mal', 'bumper', 20, None)],
    labels=[('SPUKSCHLOSS', (4.6, 10.4), 0.45)],
))

# ------------------------------------------------------------------ Rennstrecke
w, s, f, l = lower()
rw, rr = merge(ramp_left('box', 'Boxengasse'), ramp_right('kurve', 'Steilkurve'))
w += rw
TABLES.append(dict(
    id='racing', name='Rennstrecke', blurb='Zwei Rampen, Turbo-Spinner und Boxenstopp für den Multiball',
    theme=dict(top=0xFF2A2D33, mid=0xFF3A3E46, bottom=0xFF15171B, wall=0xFFF4F4F4, bumper=0xFFE53935, sling=0xFFFFD600,
               flipper=0xFFF4F4F4, accent=0xFFFFD600, light=0xFFFFD600, ramp=0xFFE53935, dmd=0xFFFFD600, art='racing'),
    walls=w, slings=s, flippers=f, lanes=l, ramps=rr,
    bumpers=[(3.6, 4.6), (5.6, 4.6), (4.6, 6.0)],
    targets=[dict(id='ampel', t=[(3.1, 7.6), (3.1, 8.2), (3.1, 8.8)], a=math.pi / 2)],
    spinners=[dict(id='turbo', a=(4.0, 7.9), b=(5.2, 7.9))],
    saucers=[dict(id='box', x=6.2, y=8.6, e=(-1.2, 4.2), lock=True)],
    missions=[('Runde: beide Rampen 4 mal', 'anyRamp', 4, None), ('Ampel: 3 Treffer', 'targets', 3, None),
              ('Turbo 25 Umdrehungen', 'spinner', 25, None), ('Boxenstopp 3 mal', 'lock', 3, None),
              ('Zielflagge: Rampen 6 mal', 'anyRamp', 6, None)],
    labels=[('GRAND PRIX', (4.6, 10.4), 0.5)],
))

# ------------------------------------------------------------------ Neonstadt (nach dem Entwurf vom 12.11.)
w, s, f, l = lower()
rw, rr = merge(ramp_left('links', 'Datenautobahn'), ramp_right('rechts', 'Hochbahn'))
w += rw
TABLES.append(dict(
    id='city', name='Neonstadt', blurb='Zwei Rampen, Zielbänke links und rechts, Datenkern für den Multiball und vier Modi',
    theme=dict(top=0xFF0A1220, mid=0xFF101B2C, bottom=0xFF080E19, wall=0xFFC9D6E3, bumper=0xFF43F4FF, sling=0xFFFF397E,
               flipper=0xFFF4F02B, accent=0xFFF4F02B, light=0xFFF4F02B, ramp=0xFF43F4FF, dmd=0xFFF4F02B, art='city'),
    walls=w, slings=s, flippers=f, lanes=l, ramps=rr,
    bumpers=[(3.7, 4.76), (5.6, 4.76), (4.65, 6.4)],
    targets=[dict(id='links', t=[(3.05, 7.7), (3.05, 8.3), (3.05, 8.9)], a=math.pi / 2),
             dict(id='rechts', t=[(6.2, 7.7), (6.2, 8.3), (6.2, 8.9)], a=math.pi / 2)],
    spinners=[dict(id='netz', a=(4.0, 9.6), b=(5.25, 9.6))],
    saucers=[dict(id='kern', x=4.65, y=8.3, e=(1.3, 4.2), lock=True)],
    missions=[('Einloggen: alle drei Gassen', 'lanes', 1, 'top'), ('Datenraub: Rampen 4 mal', 'anyRamp', 4, None),
              ('Zielbänke: 6 Treffer', 'targets', 6, None), ('Abriegelung: 3 Kugeln im Kern', 'lock', 3, None),
              ('Firewall: Rampen 6 mal', 'anyRamp', 6, None)],
    labels=[('NEONSTADT', (4.65, 10.6), 0.5)],
))


# ------------------------------------------------------------------ Angelsee
w, s, f, l = lower(outlane=True)
rw, rr = merge(ramp_right('steg', 'Stegrampe'))
w += rw
w.append(dict(p=[(2.95, 7.0), (2.95, 9.4)], b=0.45, inv=True))  # hinter dem Ring
TABLES.append(dict(
    id='lake', name='Angelsee', blurb='Rückschuss links, Angelschnur-Spinner und der Bootssteg für drei Kugeln',
    theme=dict(top=0xFF0B3A4A, mid=0xFF0F5A63, bottom=0xFF06222B, wall=0xFFBFEFFF, bumper=0xFFFF8A65, sling=0xFF7CD992,
               flipper=0xFFFFF3C4, accent=0xFFFFB74D, light=0xFFFFE082, ramp=0xFF8D6E63, dmd=0xFF80DEEA, art='lake'),
    walls=w, slings=s, flippers=f, lanes=l, ramps=rr,
    bumpers=[(3.6, 4.7), (5.8, 4.7), (4.7, 6.1)],
    targets=[dict(id='ring', t=[(2.95, 7.3), (2.95, 7.9), (2.95, 8.5), (2.95, 9.1)], a=math.pi / 2)],
    spinners=[dict(id='schnur', a=(0.02, 7.0), b=(0.95, 7.0))],
    saucers=[dict(id='boot', x=4.7, y=8.2, e=(1.6, 4.2), lock=True)],
    kickbacks=[dict(id='rettungsring', x=0.45, y=15.9, v=(0.5, -18.0), arm='ring')],
    missions=[('Barsch: Pilze 15 mal', 'bumper', 15, None), ('Hecht: Schnur 20 Umdrehungen', 'spinner', 20, None),
              ('Zander: Stegrampe 3 mal', 'ramp', 3, 'steg'), ('Wels: 3 Kugeln im Boot', 'lock', 3, None),
              ('Rettungsring: 4 Treffer', 'targets', 4, None)],
    labels=[('ANGELSEE', (4.6, 10.6), 0.5)],
))

# ------------------------------------------------------------------ Dschungeltempel
w, s, f, l = lower()
rw, rr = merge(ramp_right('liane', 'Lianenrampe'))
w += rw
w += [
    dict(p=[(3.85, 8.7), (3.85, 7.0)]),  # Tempelkammer links
    dict(p=[(5.35, 8.7), (5.35, 7.0)]),  # rechts
    dict(p=[(3.85, 7.0), (4.6, 6.55), (5.35, 7.0)], b=0.2),  # Dach
]
f = f + [((0.55, 10.4), 1, 1.35)]  # dritter Flipper oben links
w.append(dict(p=[(0, 9.6), (0.6, 9.95)], b=0.2))  # Abweiser: keine Kugel in der Ecke zwischen Wand und Drehpunkt
TABLES.append(dict(
    id='jungle', name='Dschungeltempel', blurb='Drei Fallziele öffnen das Tempeltor, dahinter die Schatzkammer; dritter Flipper',
    theme=dict(top=0xFF12301A, mid=0xFF1D4A24, bottom=0xFF0A1A0E, wall=0xFFE6C77A, bumper=0xFF8BC34A, sling=0xFF4CAF50,
               flipper=0xFFE6C77A, accent=0xFFFF7043, light=0xFFFFD54F, ramp=0xFF795548, dmd=0xFFFFC107, art='jungle'),
    walls=w, slings=s, flippers=f, lanes=l, ramps=rr,
    bumpers=[(3.0, 4.5), (6.2, 4.5), (4.6, 5.3)],
    drops=[dict(id='idol', t=[(6.5, 7.6), (6.5, 8.2), (6.5, 8.8)], a=math.pi / 2)],
    spinners=[dict(id='wasserfall', a=(0.02, 6.4), b=(0.95, 6.4))],
    saucers=[dict(id='schatz', x=4.6, y=7.65, e=(0.6, 4.6), lock=True)],
    gates=[dict(id='tor', a=(3.85, 8.7), b=(5.35, 8.7), opens='idol', closes='schatz', secs=20)],
    missions=[('Idol finden: Fallziele', 'drops', 1, None), ('Brücke: Lianenrampe 3 mal', 'ramp', 3, 'liane'),
              ('Tempeltor öffnen', 'gate', 2, None), ('Schatzkammer: 3 Kugeln', 'lock', 3, None),
              ('Wasserfall 20 Umdrehungen', 'spinner', 20, None)],
    labels=[('DSCHUNGEL', (4.6, 10.6), 0.5)],
))

# ------------------------------------------------------------------ Zirkus
w, s, f, l = lower()
rw, rr = merge(ramp_left('trapez', 'Trapezrampe'))
w += rw
w += [
    dict(p=[(7.2, 6.6), (7.2, 4.6), (8.0, 4.6), (8.0, 6.6)], b=0.3),  # Gasse der Kanonenkugel
]
w.append(dict(p=[(2.95, 7.9), (2.95, 9.1)], b=0.45, inv=True))  # hinter dem Seil
TABLES.append(dict(
    id='circus', name='Zirkus', blurb='Kanonenkugel in der Gasse, Glücksrad in der Manege und die Trapezrampe',
    theme=dict(top=0xFF3A0A1E, mid=0xFF5A1030, bottom=0xFF1C0510, wall=0xFFFFE0B2, bumper=0xFFFFD54F, sling=0xFF4FC3F7,
               flipper=0xFFFFE0B2, accent=0xFFFF4081, light=0xFFFFEB3B, ramp=0xFF4FC3F7, dmd=0xFFFF80AB, art='circus'),
    walls=w, slings=s, flippers=f, lanes=l, ramps=rr,
    bumpers=[(3.5, 4.5), (5.7, 4.5), (4.6, 6.0)],
    targets=[dict(id='seil', t=[(2.95, 8.2), (2.95, 8.8)], a=math.pi / 2)],
    saucers=[dict(id='manege', x=4.6, y=7.9, e=(1.4, 4.2), lock=False, wheel=True),
             dict(id='kaefig', x=6.1, y=7.4, e=(-1.2, 4.2), lock=True)],
    captives=[dict(id='kanone', home=(7.6, 6.05), d=(0, -1), travel=0.9, name='Mensch aus der Kanone')],
    missions=[('Seiltanz: 6 Treffer', 'targets', 6, None), ('Kanone: 5 Treffer', 'captive', 5, None),
              ('Trapez 3 mal', 'ramp', 3, 'trapez'), ('Raubtiernummer: 3 Kugeln im Käfig', 'lock', 3, None),
              ('Große Manege: Glücksrad 2 mal', 'saucer', 2, 'manege')],
    labels=[('ZIRKUS', (4.6, 10.6), 0.6)],
))


# ------------------------------------------------------------------ Dart schreiben
def pt(p):
    return f'Pt({p[0]:.3f}, {p[1]:.3f})'


def dart():
    o = ['// Erzeugt aus tool/pinball_tables.py – Änderungen dort machen und neu erzeugen.',
         '// ignore_for_file: prefer_const_constructors', '', "import 'dart:ui' show Color;", '',
         "import 'pinball_layout.dart';", '']
    names = []
    for t in TABLES:
        var = {'neon': 'neonNightTable', 'space': 'spaceTable', 'pirate': 'pirateTable', 'haunted': 'hauntedTable',
               'racing': 'racingTable', 'city': 'cityTable', 'lake': 'lakeTable', 'jungle': 'jungleTable',
               'circus': 'circusTable'}[t['id']]
        names.append(var)
        th = t['theme']
        o.append(f"const {var} = TableSpec(")
        o.append(f"  id: '{t['id']}',")
        o.append(f"  name: '{t['name']}',")
        o.append(f"  blurb: '{t['blurb']}',")
        o.append('  theme: TableTheme(')
        for k in ['top', 'mid', 'bottom', 'wall', 'bumper', 'sling', 'flipper', 'accent', 'light', 'ramp', 'dmd']:
            o.append(f'    {k}: Color(0x{th[k]:08X}),')
        o.append(f"    art: '{th['art']}',")
        o.append('  ),')
        o.append('  walls: [')
        for wl in t['walls']:
            extra = ''
            if 'b' in wl:
                extra += f", bounce: {wl['b']}"
            if wl.get('inv'):
                extra += ', visible: false'
            o.append(f"    WallSpec([{', '.join(pt(p) for p in wl['p'])}]{extra}),")
        o.append('  ],')
        o.append('  flippers: [')
        for fl in t['flippers']:
            length = f', length: {fl[2]}' if len(fl) > 2 else ''
            o.append(f'    FlipperSpec({pt(fl[0])}, {fl[1]}{length}),')
        o.append('  ],')
        o.append('  bumpers: [' + ', '.join(f'BumperSpec({x}, {y})' for x, y in t['bumpers']) + '],')
        o.append('  slings: [' + ', '.join(f'SlingSpec({pt(a)}, {pt(b)}, {pt(c)})' for a, b, c in t['slings']) + '],')
        o.append('  lanes: [' + ', '.join(f"LaneSpec({ln['x']}, {ln['y']}, group: '{ln['g']}', halfWidth: {ln['hw']})" for ln in t['lanes']) + '],')
        if t.get('drops'):
            o.append('  drops: [' + ', '.join(
                f"DropBankSpec('{d['id']}', [{', '.join(pt(p) for p in d['t'])}], angle: {d['a']:.4f})" for d in t['drops']) + '],')
        if t.get('targets'):
            o.append('  targets: [' + ', '.join(
                f"TargetBankSpec('{d['id']}', [{', '.join(pt(p) for p in d['t'])}], angle: {d['a']:.4f})" for d in t['targets']) + '],')
        if t.get('spinners'):
            o.append('  spinners: [' + ', '.join(f"SpinnerSpec('{sp['id']}', {pt(sp['a'])}, {pt(sp['b'])})" for sp in t['spinners']) + '],')
        if t.get('saucers'):
            o.append('  saucers: [' + ', '.join(
                f"SaucerSpec('{sc['id']}', {sc['x']}, {sc['y']}, {sc['e'][0]}, {sc['e'][1]}, lock: {str(sc['lock']).lower()}"
                + (", wheel: true" if sc.get('wheel') else '') + ')' for sc in t['saucers']) + '],')
        if t.get('kickbacks'):
            o.append('  kickbacks: [' + ', '.join(
                f"KickbackSpec('{k['id']}', {k['x']}, {k['y']}, {k['v'][0]}, {k['v'][1]}, armBank: '{k['arm']}')" for k in t['kickbacks']) + '],')
        if t.get('gates'):
            o.append('  gates: [' + ', '.join(
                f"GateSpec('{g['id']}', {pt(g['a'])}, {pt(g['b'])}, opensWith: '{g['opens']}', closesOn: '{g['closes']}', openSeconds: {g['secs']})"
                for g in t['gates']) + '],')
        if t.get('captives'):
            o.append('  captives: [' + ', '.join(
                f"CaptiveSpec('{c['id']}', {pt(c['home'])}, {c['d'][0]}, {c['d'][1]}, travel: {c['travel']}, name: '{c['name']}')"
                for c in t['captives']) + '],')
        if t.get('ramps'):
            o.append('  ramps: [')
            for r in t['ramps']:
                o.append(f"    RampSpec('{r['id']}', {pt(r['a'])}, {pt(r['b'])}, {r['d'][0]}, {r['d'][1]}, "
                         f"[{', '.join(pt(p) for p in r['path'])}], {r['v'][0]}, {r['v'][1]}, points: {r['pts']}, minSpeed: {r['ms']}, name: '{r['name']}'),")
            o.append('  ],')
        o.append('  missions: [')
        for title, kind, count, mid in t['missions']:
            idp = f", id: '{mid}'" if mid else ''
            o.append(f"    MissionSpec('{title}', MissionKind.{kind}, {count}{idp}),")
        o.append('  ],')
        o.append('  labels: [' + ', '.join(f"('{tx}', {pt(p)}, {sz})" for tx, p, sz in t['labels']) + '],')
        o.append(');')
        o.append('')
    o.append('/// Alle Tische in der Reihenfolge der Auswahl.')
    o.append('const pinballTables = [' + ', '.join(names) + '];')
    o.append('')
    return '\n'.join(o)


open(OUT_DART, 'w').write(dart())
if OUT_DIR is None:
    print('ok', len(TABLES))
    sys.exit(0)
from PIL import Image, ImageDraw  # noqa: E402

# ------------------------------------------------------------------ Vorschau
S = 50
for t in TABLES:
    img = Image.new('RGB', (int(9.95 * S) + 1, 18 * S + 1), (20, 20, 30))
    d = ImageDraw.Draw(img)
    P = lambda p: (p[0] * S, p[1] * S)
    for wl in t['walls']:
        d.line([P(p) for p in wl['p']], fill=(120, 200, 255) if not wl.get('inv') else (80, 80, 80), width=3)
    d.line([P((FR, 18.2)), P((FR, 4.6))], fill=(120, 200, 255), width=3)
    for x, y in t['bumpers']:
        d.ellipse([P((x - .5, y - .5)), P((x + .5, y + .5))], outline=(255, 90, 160), width=3)
    for a, b, c in t['slings']:
        d.polygon([P(a), P(b), P(c)], outline=(80, 230, 150))
    for (px, py), dr, *_ in t['flippers']:
        a = 0.5 if dr > 0 else math.pi - 0.5
        d.line([P((px, py)), P((px + 1.75 * math.cos(a), py + 1.75 * math.sin(a)))], fill=(255, 200, 90), width=8)
    for ln in t['lanes']:
        d.ellipse([P((ln['x'] - .15, ln['y'] - .15)), P((ln['x'] + .15, ln['y'] + .15))], fill=(255, 200, 90))
    for dr in t.get('drops', []):
        for c in dr['t']:
            dx, dy = math.cos(dr['a']) * .275, math.sin(dr['a']) * .275
            d.line([P((c[0] - dx, c[1] - dy)), P((c[0] + dx, c[1] + dy))], fill=(255, 80, 80), width=6)
    for tb in t.get('targets', []):
        for c in tb['t']:
            dx, dy = math.cos(tb['a']) * .25, math.sin(tb['a']) * .25
            d.line([P((c[0] - dx, c[1] - dy)), P((c[0] + dx, c[1] + dy))], fill=(255, 255, 80), width=6)
    for sp in t.get('spinners', []):
        d.line([P(sp['a']), P(sp['b'])], fill=(200, 120, 255), width=2)
    for sc in t.get('saucers', []):
        d.ellipse([P((sc['x'] - .3, sc['y'] - .3)), P((sc['x'] + .3, sc['y'] + .3))], outline=(255, 255, 255), width=3)
        d.line([P((sc['x'], sc['y'])), P((sc['x'] + sc['e'][0] * .3, sc['y'] + sc['e'][1] * .3))], fill=(255, 255, 255), width=1)
    for r in t.get('ramps', []):
        d.line([P(p) for p in r['path']], fill=(90, 160, 255), width=10)
        d.line([P(r['a']), P(r['b'])], fill=(255, 255, 255), width=2)
    d.text((10, 10), t['name'], fill=(255, 255, 255))
    img.save(os.path.join(OUT_DIR, f"{t['id']}.png"))
print('ok', len(TABLES))
