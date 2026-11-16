"""Baut die Kartenbilder der App aus den gezeichneten Vorlagen.

Aufruf:  python3 tool/cards/build_cards.py <ordner_mit_bildkarten>

Der Ordner enthält die 1060 × 1484 px großen PNGs mit leeren Ecken:
spades_11 … clubs_13, joker_red, joker_black und spades_14 (Pik-Ass).

Erzeugt in assets/cards/:
- <farbe>_<rang>.webp für alle 52 Karten und joker_red/joker_black.webp
  (530 × 742 px, ohne Eckzeichen, die zeichnet die App selbst)
- index/<zeichen>.png: Eckzeichen als weiße Masken (Ränge 2–10, A, J, Q, K, B, D,
  die vier Farben und JOKER), die App färbt sie ein.

Zahlenkarten und die Asse für Herz, Karo und Kreuz entstehen hier aus den Masken in
tool/cards/src (pips/, aces/) im üblichen Raster des französischen Blatts.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage as ndi

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'cards')
SRC = os.path.join(HERE, 'src')
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf'

W, H = 1060, 1484
BG = np.array([250, 247, 239], float)
RED = np.array([218, 6, 10], float)
BLACK = np.array([9, 9, 8], float)
SUITS = ('spades', 'hearts', 'diamonds', 'clubs')
OUT_SIZE = (530, 742)

# Raster der Zahlenkarten: drei Spalten, vier Reihen, Mitte für 3, 5, 7, 8, 9, 10.
X = (325, 530, 735)
Y0 = 320
Y4 = H - Y0
MID = H / 2
D = (Y4 - Y0) / 3
L, C, R = X
LAYOUT = {
    2: [(C, Y0), (C, Y4)],
    3: [(C, Y0), (C, MID), (C, Y4)],
    4: [(L, Y0), (R, Y0), (L, Y4), (R, Y4)],
}
LAYOUT[5] = LAYOUT[4] + [(C, MID)]
LAYOUT[6] = LAYOUT[4] + [(L, MID), (R, MID)]
LAYOUT[7] = LAYOUT[6] + [(C, (Y0 + MID) / 2)]
LAYOUT[8] = LAYOUT[7] + [(C, (MID + Y4) / 2)]
_ROWS = [Y0, Y0 + D, Y4 - D, Y4]
LAYOUT[9] = [(x, y) for y in _ROWS for x in (L, R)] + [(C, MID)]
LAYOUT[10] = [(x, y) for y in _ROWS for x in (L, R)] + [(C, Y0 + D / 2), (C, Y4 - D / 2)]


def rgba(path):
    return np.asarray(Image.open(path).convert('RGBA')).astype(float)


def mask(path):
    return np.asarray(Image.open(path).convert('RGBA'))[..., 3].astype(float) / 255


def ink(suit):
    return RED if suit in ('hearts', 'diamonds') else BLACK


def put(card, m, cx, cy, color, flip=False):
    if flip:
        m = m[::-1, ::-1]
    h, w = m.shape
    x0, y0 = int(round(cx - w / 2)), int(round(cy - h / 2))
    sub = card[y0:y0 + h, x0:x0 + w, :3]
    sub[:] = sub * (1 - m[..., None]) + color * m[..., None]


def blank_from(court):
    """Leere Karte: Rahmen und Ecken aus einer Bildkarte, innen einfarbig."""
    card = court.copy()
    dark = card[..., :3].mean(2) < 120
    lab, _ = ndi.label(dark)
    frame = lab == lab[742, np.nonzero(dark[742, :60])[0][0]]
    inner = ndi.binary_fill_holes(frame) & ~ndi.binary_dilation(frame, iterations=2)
    card[inner, :3] = BG
    return card


def save(card, name):
    im = Image.fromarray(card.clip(0, 255).round().astype(np.uint8), 'RGBA').resize(OUT_SIZE, Image.LANCZOS)
    im.save(os.path.join(OUT, f'{name}.webp'), 'WEBP', quality=90, method=6)


def glyph(text, cap):
    """Text als weiße Maske, Großbuchstaben genau `cap` px hoch."""
    font = ImageFont.truetype(FONT, 400)
    ref = font.getbbox('K')
    scale = cap / (ref[3] - ref[1])
    font = ImageFont.truetype(FONT, int(round(400 * scale)))
    x0, y0, x1, y1 = font.getbbox(text)
    top = font.getbbox('K')[1]
    im = Image.new('L', (x1 - x0 + 4, max(y1, font.getbbox('K')[3]) - top + 4), 0)
    ImageDraw.Draw(im).text((2 - x0, 2 - top), text, font=font, fill=255)
    return im.crop(im.getbbox())


def star(size):
    """Fünfzackiger Stern als Maske, `size` px breit."""
    import math
    k = 4
    im = Image.new('L', (size * k, size * k), 0)
    c = size * k / 2
    pts = []
    for i in range(10):
        r = c if i % 2 == 0 else c * 0.42
        a = -math.pi / 2 + i * math.pi / 5
        pts.append((c + r * math.cos(a), c * 1.05 + r * math.sin(a)))
    ImageDraw.Draw(im).polygon(pts, fill=255)
    im = im.resize((size, size), Image.LANCZOS)
    return im.crop(im.getbbox())


def white(m):
    a = np.zeros(m.size[::-1] + (4,), np.uint8)
    a[..., :3] = 255
    a[..., 3] = np.asarray(m)
    return Image.fromarray(a, 'RGBA')


def build_index():
    d = os.path.join(OUT, 'index')
    os.makedirs(d, exist_ok=True)
    cap = 96
    for t in ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'A', 'J', 'Q', 'K', 'B', 'D']:
        g = glyph(t, cap)
        if t == '10':  # zwei Ziffern so schmal wie ein Buchstabe
            g = g.resize((int(g.width * 0.8), g.height), Image.LANCZOS)
        white(g).save(os.path.join(d, f'rank_{t}.png'), optimize=True)
    for s in SUITS:
        m = Image.open(os.path.join(SRC, 'pips', f'{s}.png')).convert('RGBA').getchannel('A')
        m = m.resize((int(m.width * 96 / m.height), 96), Image.LANCZOS)
        white(m).save(os.path.join(d, f'suit_{s}.png'), optimize=True)
    # JOKER senkrecht mit Stern
    letters = [glyph(c, 40) for c in 'JOKER']
    parts = letters + [star(36)]
    wmax = max(p.width for p in parts)
    gap = 8
    im = Image.new('L', (wmax, sum(p.height for p in parts) + gap * (len(parts) - 1)), 0)
    y = 0
    for p in parts:
        im.paste(p, ((wmax - p.width) // 2, y))
        y += p.height + gap
    white(im).save(os.path.join(d, 'joker.png'), optimize=True)


def main(court_dir):
    os.makedirs(OUT, exist_ok=True)
    courts = {}
    for s in SUITS:
        for r in (11, 12, 13):
            courts[f'{s}_{r}'] = rgba(os.path.join(court_dir, f'{s}_{r}.png'))
    for j in ('joker_red', 'joker_black'):
        courts[j] = rgba(os.path.join(court_dir, f'{j}.png'))
    courts['spades_14'] = rgba(os.path.join(court_dir, 'spades_14.png'))
    for name, card in courts.items():
        assert card.shape[:2] == (H, W), name
        save(card, name)
    blank = blank_from(courts['spades_11'])
    for s in SUITS:
        pip = mask(os.path.join(SRC, 'pips', f'{s}.png'))
        for r in range(2, 11):
            card = blank.copy()
            for x, y in LAYOUT[r]:
                put(card, pip, x, y, ink(s), flip=y > MID + 1)
            save(card, f'{s}_{r}')
        if s != 'spades':
            card = blank.copy()
            put(card, mask(os.path.join(SRC, 'aces', f'{s}.png')), W / 2, H / 2, ink(s))
            save(card, f'{s}_14')
    build_index()


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
