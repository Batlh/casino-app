#!/usr/bin/env python3
"""Erzeugt Soundeffekte (assets/sfx) und das App-Icon (assets/icon)."""
import wave
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SR = 22050
root = Path(__file__).resolve().parent.parent
rng = np.random.default_rng(78)

def t(d): return np.arange(int(SR * d)) / SR
def env(x, a=0.002, r=8.0):
    tt = np.arange(len(x)) / SR
    return x * np.minimum(tt / a, 1) * np.exp(-tt * r)
def tone(f, d, r=8.0, h=(1, .4, .2)):
    x = sum(g * np.sin(2 * np.pi * f * (i + 1) * t(d)) for i, g in enumerate(h))
    return env(x, r=r)
def noise(d, r=40.0): return env(rng.normal(0, 1, int(SR * d)), r=r)
def seq(notes, gap, d=.3, r=7.0):
    out = np.zeros(int(SR * (gap * len(notes) + d)))
    for i, f in enumerate(notes):
        x = tone(f, d, r); s = int(i * gap * SR); out[s:s + len(x)] += x
    return out
def mix(*parts):
    n = max(len(a) for a in parts)
    return sum(np.pad(a, (0, n - len(a))) for a in parts)
def save(name, x, vol=.7):
    x = x / max(np.abs(x).max(), 1e-6) * vol
    x = np.concatenate([x, np.zeros(int(SR * .01))])
    with wave.open(str(root / 'assets/sfx' / f'{name}.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())

save('chip', mix(tone(2300, .08, 60), tone(3400, .08, 70) * .6, noise(.03, 120) * .3), .5)
save('card', np.convolve(noise(.09, 45), np.ones(6) / 6, 'same'), .5)
save('tick', tone(1500, .04, 90), .3)
save('reel_stop', mix(tone(170, .14, 26, (1, .3)), noise(.05, 90) * .4), .6)
save('coin', mix(tone(1975, .35, 9), tone(2637, .35, 12) * .7), .45)
save('win', seq([523, 659, 784, 1047], .08, .35), .55)
save('big_win', seq([523, 659, 784, 1047, 784, 1047, 1319, 1568], .085, .5, 5), .65)
save('lose', seq([330, 262], .12, .25, 12), .3)
save('ball', noise(.5, 7) * (.5 + .5 * np.sin(2 * np.pi * 26 * t(.5))), .22)

# Icon: gepraegter Pfennig auf Senfgelb
S = 1024
for name, bg in (('icon', (242, 163, 58, 255)), ('icon_fg', (0, 0, 0, 0))):
    img = Image.new('RGBA', (S, S), bg)
    d = ImageDraw.Draw(img)
    m = 150 if name == 'icon' else 250
    d.ellipse([m + 18, m + 26, S - m + 18, S - m + 26], fill=(58, 33, 22, 255))
    d.ellipse([m, m, S - m, S - m], fill=(214, 146, 58, 255), outline=(107, 62, 30, 255), width=20)
    i = m + 60
    d.ellipse([i, i, S - i, S - i], outline=(107, 62, 30, 255), width=12)
    c = S / 2; rr = c - m - 30
    for a in np.linspace(0, 2 * np.pi, 48, endpoint=False):
        x, y = c + rr * np.cos(a), c + rr * np.sin(a)
        d.ellipse([x - 7, y - 7, x + 7, y + 7], fill=(107, 62, 30, 255))
    f = ImageFont.truetype(str(root / 'assets/fonts/Shrikhand-Regular.ttf'), int((S - 2 * m) * .55))
    d.text((c, c - 16), 'Pf', font=f, fill=(58, 33, 22, 255), anchor='mm')
    img.save(root / 'assets/icon' / f'{name}.png')
