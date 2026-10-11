"""Dice sets: a d20 texture per set (assets/textures/d20_<id>.png) and a swatch for the screens
(assets/portraits/dice_<id>.png), painted from the colours in game/data/dice.lua. Reruns the
portraits so the swatches join their atlas.

    python3 tools/gen_dice.py
"""
import os
import re
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from gen_common import hexc, tile_noise, to_img, lerp, smoothstep, font  # noqa: E402
import gen_textures as gt  # noqa: E402
import generate  # noqa: E402

DATA = os.path.join(ROOT, "game", "data", "dice.lua")
TEX = os.path.join(ROOT, "assets", "textures")
PORT = os.path.join(ROOT, "assets", "portraits")


def sets():
    text = open(DATA).read()
    out = {}
    for m in re.finditer(r'\n    (\w+) = \{ name = "([^"]+)", tier = (\d), a = "(#\w+)", b = "(#\w+)", swirl = "(#\w+)", '
                         r'numbers = "(#\w+)"(, stars = true)?', text):
        out[m.group(1)] = dict(name=m.group(2), tier=int(m.group(3)), a=m.group(4), b=m.group(5), swirl=m.group(6),
                               numbers=m.group(7), stars=bool(m.group(8)))
    return out


def body(w, h, s, seed):
    n = tile_noise(w, h, 6, 6, 91 + seed, 5)
    swirl = tile_noise(w, h, 3, 3, 92 + seed, 4)
    b = lerp(hexc(s["a"]), hexc(s["b"]), smoothstep(0.3, 0.8, n))
    b = lerp(b, hexc(s["swirl"]), smoothstep(0.55, 0.8, swirl) * 0.6)
    return b


def texture(sid, s, faces, seed):
    w = h = 512
    img = to_img(body(w, h, s, seed))
    d = ImageDraw.Draw(img, "RGBA")
    rng = np.random.default_rng(seed)
    if s["stars"]:
        for _ in range(260):
            x, y = rng.integers(0, w), rng.integers(0, h)
            r = rng.uniform(0.6, 1.8)
            d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 255, int(rng.integers(120, 255))))
    f = font("Lora-Bold.ttf", 40)
    num = hexc(s["numbers"])
    col = tuple(int(c * 255) for c in num[:3]) + (255,)
    light = sum(num[:3]) > 1.5
    shadow = (20, 10, 30, 200) if light else (255, 255, 255, 90)
    for n_, tri in faces:
        (ax, ay), (bx, by), (cx, cy) = tri
        d.line([(ax, ay), (bx, by), (cx, cy), (ax, ay)], fill=(255, 255, 255, 50), width=3)
        gx, gy = (ax + bx + cx) / 3, (ay + by + cy) / 3 + 2
        txt = str(n_) + ("." if n_ in (6, 9) else "")
        d.text((gx + 1.5, gy + 1.5), txt, font=f, fill=shadow, anchor="mm")
        d.text((gx, gy), txt, font=f, fill=col, anchor="mm")
    img.save(os.path.join(TEX, "d20_%s.png" % sid))


def swatch(sid, s, seed):
    """A little d20 for the screens: a hexagon of the set's colours with a 20 on it."""
    S = 96
    big = S * 4
    tex = to_img(body(big, big, s, seed)).convert("RGBA")
    mask = Image.new("L", (big, big), 0)
    md = ImageDraw.Draw(mask)
    import math
    pts = [(big / 2 + big * 0.46 * math.cos(math.radians(90 + 60 * k)), big / 2 + big * 0.46 * math.sin(math.radians(90 + 60 * k)))
           for k in range(6)]
    md.polygon(pts, fill=255)
    out = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    out.paste(tex, (0, 0), mask)
    d = ImageDraw.Draw(out, "RGBA")
    if s["stars"]:
        rng = np.random.default_rng(seed)
        for _ in range(60):
            x, y = rng.integers(40, big - 40), rng.integers(40, big - 40)
            r = rng.uniform(1.5, 4)
            if mask.getpixel((int(x), int(y))) > 0:
                d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 255, 200))
    # The facets: a triangle in the middle, lines to the rim.
    c = (big / 2, big / 2)
    tri = [(big / 2, big * 0.2), (big * 0.24, big * 0.66), (big * 0.76, big * 0.66)]
    d.polygon(tri, outline=(255, 255, 255, 90), width=6)
    for p_ in pts:
        q = min(tri, key=lambda t: (t[0] - p_[0]) ** 2 + (t[1] - p_[1]) ** 2)
        d.line([p_, q], fill=(255, 255, 255, 60), width=5)
    d.polygon(pts, outline=(0, 0, 0, 150), width=8)
    num = hexc(s["numbers"])
    col = tuple(int(v * 255) for v in num[:3]) + (255,)
    f = font("Lora-Bold.ttf", 120)
    d.text((c[0] + 4, big * 0.5 + 4), "20", font=f, fill=(0, 0, 0, 120), anchor="mm")
    d.text((c[0], big * 0.5), "20", font=f, fill=col, anchor="mm")
    out.resize((S, S), Image.LANCZOS).save(os.path.join(PORT, "dice_%s.png" % sid))


def main():
    _, faces, _, _ = generate.d20()
    ss = sets()
    for k, (sid, s) in enumerate(sorted(ss.items())):
        texture(sid, s, faces, k * 7)
        swatch(sid, s, k * 7)
    import gen_portraits
    gen_portraits.main()
    print("wrote %d dice sets" % len(ss))


if __name__ == "__main__":
    main()
