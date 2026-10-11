"""New characters (M8, B3): two for each class, as paper minis. Each is the class's standee
repainted (its cloth and hair recoloured, so it reads as someone else at a glance), with the
mini's paper border kept. Writes assets/sprites/pregen_<id>.png and adds them to the sprite atlas,
then reruns the portraits (mini_pregen_<id> for the screens).

    python3 tools/gen_pregens.py
"""
import colorsys
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPR = os.path.join(ROOT, "assets", "sprites")

# id -> (class mini, hue shift 0..1, saturation scale, value scale)
PREGENS = {
    "bryn": ("fighter", 0.42, 1.0, 1.0),
    "hesk": ("fighter", 0.08, 0.7, 0.85),
    "tam": ("rogue", 0.55, 1.0, 1.0),
    "lark": ("rogue", 0.88, 1.1, 1.05),
    "aldith": ("cleric", 0.30, 0.9, 1.0),
    "rufus": ("cleric", 0.62, 1.0, 0.95),
    "corwin": ("wizard", 0.25, 1.0, 0.95),
    "ysolde": ("wizard", 0.70, 1.1, 1.05),
}


def recolor(src, shift, sat, val):
    im = Image.open(os.path.join(SPR, src + ".png")).convert("RGBA")
    a = np.asarray(im).astype(float) / 255.0
    rgb, alpha = a[..., :3], a[..., 3]
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx, mn = rgb.max(axis=2), rgb.min(axis=2)
    chroma = mx - mn
    # Only coloured pixels move: skin tones (warm, low chroma), the white paper border and the
    # dark outline stay as they are.
    hsv = np.vectorize(colorsys.rgb_to_hsv, otypes=[float, float, float])(r, g, b)
    h, s, v = hsv
    skin = (h > 0.015) & (h < 0.12) & (s > 0.12) & (s < 0.72) & (v > 0.2)
    move = (chroma > 0.12) & (alpha > 0.5) & ~skin
    h2 = np.where(move, (h + shift) % 1.0, h)
    s2 = np.where(move, np.clip(s * sat, 0, 1), s)
    v2 = np.where(move, np.clip(v * val, 0, 1), v)
    out = np.vectorize(colorsys.hsv_to_rgb, otypes=[float, float, float])(h2, s2, v2)
    rgb2 = np.stack(out, axis=2)
    res = np.concatenate([rgb2, alpha[..., None]], axis=2)
    return Image.fromarray((np.clip(res, 0, 1) * 255).astype(np.uint8), "RGBA")


def main():
    names = []
    for pid, (src, shift, sat, val) in PREGENS.items():
        name = "pregen_" + pid
        recolor(src, shift, sat, val).save(os.path.join(SPR, name + ".png"))
        names.append(name)
    atlas = os.path.join(SPR, "sprites.atlas")
    text = open(atlas).read()
    add = "".join('images {\n  image: "/assets/sprites/%s.png"\n}\n' % n for n in names if ("/%s.png" % n) not in text)
    if add:
        i = text.index("margin:")
        text = text[:i] + add + text[i:]
        with open(atlas, "w", newline="\n") as f:
            f.write(text)
    import sys
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import gen_portraits
    for n in names:
        if n not in gen_portraits.STANDEES:
            gen_portraits.STANDEES.append(n)
    gen_portraits.main()
    print("wrote %d new characters" % len(names))


if __name__ == "__main__":
    main()
