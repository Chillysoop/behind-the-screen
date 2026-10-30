"""First pass at reading a battle map image: find its square grid, then guess what each square
is from its colour and texture, and write a draft (JSON) plus an overlay picture to check it by
eye. It's a first pass a person (or Claude) corrects, not the finished map: draft_to_spec.py
turns a draft into a map spec to finish by hand.

    python3 tools/maps/import_map.py IMAGE [--grid auto|PX|PX,OX,OY] [--crop x,y,w,h]
                                           [--out DRAFT.json] [--overlay OVERLAY.png]

  --grid auto       find the square size and where the lines fall (the default)
  --grid 142        the square is 142 px; find where the lines fall
  --grid 142,12,30  the square is 142 px and a grid line runs through x = 12 and y = 30
  --crop x,y,w,h    work on that part of the image only (pixels)

The classes: outside (the background around the map), floor, wall, door, water, stairs, plants,
object (something drawn on the floor: furniture, an exhibit, an icon) and dark. Walls drawn along
the grid lines (as on most battle maps) are found too, edge by edge: draft["edges"].
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

CLASSES = ["outside", "floor", "wall", "door", "water", "stairs", "plants", "object", "dark"]
COLOURS = {"outside": (120, 120, 120), "floor": (240, 230, 200), "wall": (60, 40, 40), "door": (230, 140, 30),
           "water": (40, 120, 230), "stairs": (170, 90, 200), "plants": (60, 170, 60), "object": (230, 60, 60),
           "dark": (20, 20, 20)}
LETTER = {"outside": " ", "floor": ".", "wall": "#", "door": "D", "water": "~", "stairs": "S", "plants": '"',
          "object": "o", "dark": "_"}


# ------------------------------------------------------------------ the grid

def _smooth(p, k):
    k = max(1, int(k))
    c = np.convolve(p, np.ones(k) / k, mode="same")
    return c


def edge_profiles(gray):
    """How many rows have a sharp step at each column (and columns at each row): long straight
    lines, like a grid's, stand out; one-off drawings don't."""
    gx = np.abs(np.diff(gray, axis=1))
    gy = np.abs(np.diff(gray, axis=0))
    thr = max(8.0, float(np.percentile(np.concatenate([gx.ravel()[::7], gy.ravel()[::7]]), 90)))
    px = (gx > thr).mean(axis=0)
    py = (gy > thr).mean(axis=1)
    px = np.clip(px - _smooth(px, 25), 0, None)
    py = np.clip(py - _smooth(py, 25), 0, None)
    return px, py


def autocorr(p):
    q = p - p.mean()
    n = len(q)
    f = np.fft.rfft(q, 2 * n)
    ac = np.fft.irfft(f * np.conj(f))[:n]
    return ac / (ac[0] + 1e-9)


def best_lag(p, lo, hi):
    ac = autocorr(p)
    hi = min(hi, len(ac) - 2)
    if hi <= lo:
        return None, 0.0
    seg = ac[lo:hi]
    lag = int(np.argmax(seg)) + lo
    peak = ac[lag]
    # Prefer the fundamental: a lag a whole fraction of the best one that's nearly as strong.
    for d in (6, 5, 4, 3, 2):
        sub = lag / d
        if sub >= lo:
            a, b = int(sub) - 2, int(sub) + 3
            if a > 0 and ac[a:b].max() >= 0.6 * peak:
                lag = int(np.argmax(ac[a:b])) + a
                peak = ac[lag]
                break
    return lag, float(peak)


def comb(p, period, phase, win=2):
    n = len(p)
    pos = np.arange(phase, n, period)
    if len(pos) < 2:
        return 0.0
    tot = 0.0
    for x in pos:
        i = int(round(x))
        tot += p[max(0, i - win):min(n, i + win + 1)].max() if i < n else 0
    return tot / len(pos)


def refine(px, py, period, fixed=False):
    """The square size (to a twentieth of a pixel) and where the lines fall on each axis."""
    best = (-1, period, 0.0, 0.0)
    span = [period] if fixed else list(np.arange(period * 0.97, period * 1.03, 0.05))
    for per in span:
        phases = np.arange(0, per, 1.0)
        sx = [comb(px, per, ph) for ph in phases]
        sy = [comb(py, per, ph) for ph in phases]
        ix, iy = int(np.argmax(sx)), int(np.argmax(sy))
        score = sx[ix] + sy[iy]
        if score > best[0]:
            best = (score, per, float(phases[ix]), float(phases[iy]))
    score, per, ox, oy = best
    # Half-pixel phase polish.
    for axis in (0, 1):
        p = px if axis == 0 else py
        o = ox if axis == 0 else oy
        cands = np.arange(o - 1, o + 1.01, 0.25)
        o2 = float(cands[int(np.argmax([comb(p, per, c % per, win=1) for c in cands]))]) % per
        if axis == 0:
            ox = o2
        else:
            oy = o2
    return per, ox, oy, score


def find_grid(gray, size=None):
    h, w = gray.shape
    px, py = edge_profiles(gray)
    if size:
        per = float(size)
        _, ox, oy, score = refine(px, py, per, fixed=True)
        return dict(size=per, ox=ox, oy=oy, found="given size", score=round(score, 4))
    lo = max(10, int(min(w, h) / 90))
    hi = max(lo + 4, int(min(w, h) / 3))
    lx, sx = best_lag(px, lo, hi)
    ly, sy = best_lag(py, lo, hi)
    if lx and ly and abs(lx - ly) <= 0.08 * max(lx, ly):
        per = (lx * sx + ly * sy) / (sx + sy)
    else:
        per = lx if (sx >= sy and lx) else ly
    if not per:
        raise SystemExit("couldn't find a grid: give the square size with --grid PX")
    per, ox, oy, score = refine(px, py, per)
    return dict(size=round(per, 3), ox=round(ox, 2), oy=round(oy, 2), found="auto", score=round(score, 4),
                strength=round(min(sx, sy), 3))


# ------------------------------------------------------------------ what each square is

def mode_colour(pixels):
    q = (pixels // 8).astype(np.int32)
    keys = q[:, 0] * 1024 + q[:, 1] * 32 + q[:, 2]
    vals, counts = np.unique(keys, return_counts=True)
    k = vals[np.argmax(counts)]
    sel = pixels[keys == k]
    return sel.mean(axis=0)


def _steps(profile, amp=10.0):
    """How many times a brightness profile swings by more than amp (steps, stripes)."""
    p = _smooth(profile, 3)
    n, last, d = 0, p[0], 0
    for v in p[1:]:
        if v - last > amp and d <= 0:
            n, d, last = n + 1, 1, v
        elif last - v > amp and d >= 0:
            n, d, last = n + 1, -1, v
        elif (d > 0 and v > last) or (d < 0 and v < last):
            last = v
    return n


def cell_stats(rgb, gray, x0, y0, s, refs=None, inset=0.18):
    m = int(s * inset)
    a = rgb[int(y0) + m:int(y0 + s) - m, int(x0) + m:int(x0 + s) - m].reshape(-1, 3)
    g = gray[int(y0) + m:int(y0 + s) - m, int(x0) + m:int(x0 + s) - m]
    if a.size == 0:
        return None
    mx, mn = a.max(axis=1), a.min(axis=1)
    psat = (mx - mn) / (mx + 1e-6)
    gx = np.abs(np.diff(g, axis=1))
    gy = np.abs(np.diff(g, axis=0))
    edge = ((gx > 30).mean() + (gy > 30).mean()) / 2
    rows, cols = g.mean(axis=1), g.mean(axis=0)
    gf = g.ravel()
    st = dict(rgb=a.mean(axis=0), gray=float(g.mean()), std=float(g.std()), sat=float(psat.mean()),
              blue=float((a[:, 2] - (a[:, 0] + a[:, 1]) / 2).mean()),
              green=float((a[:, 1] - (a[:, 0] + a[:, 2]) / 2).mean()),
              dark=float((gf < 70).mean()), white=float((gf > 245).mean()), ink=float((gf < 110).mean()),
              greyfill=float(((gf > 135) & (gf < 200) & (psat < 0.07)).mean()),
              edge=float(edge), steps=max(_steps(rows), _steps(cols)),
              aniso=float((rows.std() + 1) / (cols.std() + 1)))
    if refs is not None:
        def near(c, tol):
            return float((np.linalg.norm(a - np.asarray(c), axis=1) < tol).mean())
        st["f_bg"] = near(refs["outside"], 12)
        st["f_floor"] = near(refs["floor"], 12) if refs["floor"] is not None else 0.0
        bl = a[:, 2] - (a[:, 0] + a[:, 1]) / 2
        st["f_blue"] = float(((bl > max(14.0, refs["floor_blue"] + 5)) & (gf > 90)).mean())
        st["f_green"] = float((((a[:, 1] - (a[:, 0] + a[:, 2]) / 2) > 12) & (psat > 0.15)).mean())
    return st


def classify(st, refs):
    """A square's class and how sure the guess is (0-1)."""
    if st["gray"] < 55 or st["dark"] > 0.7:
        return "dark", 0.8
    if max(st["f_floor"], st["f_bg"]) > 0.55:
        if st["f_bg"] >= st["f_floor"]:
            return "outside", min(1.0, st["f_bg"])
        return "floor", min(1.0, st["f_floor"])
    if st["f_blue"] > 0.45:
        return "water", st["f_blue"]
    if st["f_green"] > 0.35:
        return "plants", st["f_green"]
    if st["steps"] >= 4 and st["edge"] < 0.2 and (st["aniso"] > 3 or st["aniso"] < 0.34):
        return "stairs", 0.5                      # parallel treads, one way only
    if st["greyfill"] > 0.3 and st["f_bg"] + st["greyfill"] + st["white"] > 0.75 and st["edge"] < 0.1:
        return "wall", 0.5                        # a thick wall with the outside beyond it
    if (st["greyfill"] > 0.15 and st["f_bg"] > 0.08 and st["f_floor"] > 0.08 and st["edge"] < 0.1
            and st["f_bg"] + st["f_floor"] + st["greyfill"] + st["white"] > 0.8):
        return "wall", 0.4                        # floor, a wall, then the outside: a slanting outer wall
    if st["greyfill"] > 0.45 and st["edge"] < 0.07:
        return "wall", 0.45
    if st["f_floor"] + st["f_bg"] > 0.5 and (st["aniso"] > 4 or st["aniso"] < 0.25) and st["edge"] < 0.06:
        return "floor", 0.4                       # floor with a wall line running past it
    if st["edge"] > 0.18:
        return "plants" if st["sat"] < 0.15 and st["white"] < 0.15 else "object", 0.3   # leaves are busy
    if st["white"] > 0.6 and st["edge"] < 0.08:
        return "floor", 0.4                       # paving: bright slabs
    if st["std"] < 8 and st["sat"] < 0.08 and st["gray"] < 205:
        return "plants", 0.3                      # a flat grey blob: trees and hedges on a grey-scale map
    return "object", 0.4


def tidy(cells, conf):
    """Second looks with the neighbours in view. A patch of "wall" that never touches floor but sits
    in the background is a grey blob of trees or hedge (grey-scale maps draw them that way)."""
    rows, cols = len(cells), len(cells[0]) if cells else 0
    seen = set()
    for r in range(rows):
        for c in range(cols):
            if cells[r][c] != "wall" or (r, c) in seen:
                continue
            comp, stack = [], [(r, c)]
            seen.add((r, c))
            while stack:
                a, b = stack.pop()
                comp.append((a, b))
                for da, db in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    na, nb = a + da, b + db
                    if 0 <= na < rows and 0 <= nb < cols and cells[na][nb] == "wall" and (na, nb) not in seen:
                        seen.add((na, nb))
                        stack.append((na, nb))
            around = {}
            for a, b in comp:
                for da, db in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    na, nb = a + da, b + db
                    if 0 <= na < rows and 0 <= nb < cols and cells[na][nb] != "wall":
                        around[cells[na][nb]] = around.get(cells[na][nb], 0) + 1
            n = sum(around.values()) or 1
            if around.get("outside", 0) / n > 0.5 and (around.get("floor", 0) + around.get("door", 0)) / n < 0.15:
                for a, b in comp:
                    cells[a][b] = "plants"
                    conf[a][b] = 0.3


def edge_band(gray, x0, y0, x1, y1):
    xa, xb = sorted((int(x0), int(x1)))
    ya, yb = sorted((int(y0), int(y1)))
    b = gray[max(0, ya):max(0, yb), max(0, xa):max(0, xb)]
    return b


def wall_edges(gray, grid, rows, cols, refs):
    """Walls drawn along the grid lines: for each square's north and west edge, is there a band of
    wall (darker than the floor, all the way along) or a door (a pale gap in a wall line)?"""
    s, ox, oy = grid["size"], grid["ox"], grid["oy"]
    t = max(2, int(s * 0.13))
    floor_g = refs["floor_gray"]

    def kind(band):
        if band.size == 0:
            return ""
        dark = (band < floor_g - 45).mean()
        if dark > 0.55:
            return "wall"
        return ""

    h = [["" for _ in range(cols)] for _ in range(rows + 1)]
    v = [["" for _ in range(cols + 1)] for _ in range(rows)]
    for r in range(rows + 1):
        y = oy + r * s
        for c in range(cols):
            x = ox + c * s
            h[r][c] = kind(edge_band(gray, x + s * 0.2, y - t, x + s * 0.8, y + t))
    for r in range(rows):
        y = oy + r * s
        for c in range(cols + 1):
            x = ox + c * s
            v[r][c] = kind(edge_band(gray, x - t, y + s * 0.2, x + t, y + s * 0.8))

    # Doors: a light gap in a wall line, with wall on both sides along the line.
    def light(band):
        return band.size and (band > floor_g - 10).mean() > 0.45 and (band < 100).mean() > 0.04

    for r in range(rows + 1):
        y = oy + r * s
        for c in range(1, cols - 1):
            if not h[r][c] and h[r][c - 1] == "wall" and (h[r][c + 1] == "wall" or (c + 2 < cols and h[r][c + 2] == "wall")):
                x = ox + c * s
                if light(edge_band(gray, x + s * 0.2, y - t, x + s * 0.8, y + t)):
                    h[r][c] = "door"
    for c in range(cols + 1):
        x = ox + c * s
        for r in range(1, rows - 1):
            if not v[r][c] and v[r - 1][c] == "wall" and (v[r + 1][c] == "wall" or (r + 2 < rows and v[r + 2][c] == "wall")):
                y = oy + r * s
                if light(edge_band(gray, x - t, y + s * 0.2, x + t, y + s * 0.8)):
                    v[r][c] = "door"
    return h, v


def import_map(path, grid_arg="auto", crop=None):
    img = Image.open(path).convert("RGB")
    if crop:
        x, y, w, h = crop
        img = img.crop((x, y, x + w, y + h))
    rgb = np.asarray(img).astype(np.float32)
    gray = rgb.mean(axis=2)
    H, W = gray.shape
    if grid_arg in (None, "auto"):
        grid = find_grid(gray)
    else:
        parts = [float(v) for v in str(grid_arg).split(",")]
        if len(parts) == 3:
            grid = dict(size=parts[0], ox=parts[1] % parts[0], oy=parts[2] % parts[0], found="given", score=None)
        else:
            grid = find_grid(gray, size=parts[0])
    s = grid["size"]
    cols = int((W - grid["ox"]) // s)
    rows = int((H - grid["oy"]) // s)
    grid.update(cols=cols, rows=rows)

    # Reference colours: the background is the commonest colour in the outer ring of squares (an
    # image's own frame is often a different colour); the floor is the commonest colour among the
    # plain squares that aren't background.
    ring = []
    for r in range(rows):
        for c in range(cols):
            if r in (0, rows - 1) or c in (0, cols - 1):
                x0, y0 = int(grid["ox"] + c * s), int(grid["oy"] + r * s)
                ring.append(rgb[y0 + int(s * 0.2):y0 + int(s * 0.8), x0 + int(s * 0.2):x0 + int(s * 0.8)].reshape(-1, 3)[::5])
    bg = mode_colour(np.concatenate(ring)) if ring else mode_colour(rgb.reshape(-1, 3)[::50])
    first = [[cell_stats(rgb, gray, grid["ox"] + c * s, grid["oy"] + r * s, s) for c in range(cols)] for r in range(rows)]
    plain = [st["rgb"] for row in first for st in row
             if st is not None and st["edge"] < 0.07 and st["std"] < 20 and np.linalg.norm(st["rgb"] - bg) > 8]
    fl = mode_colour(np.array(plain)) if plain else None
    refs = dict(outside=bg, floor=fl, floor_blue=float(fl[2] - (fl[0] + fl[1]) / 2) if fl is not None else 0.0,
                floor_gray=float(fl.mean()) if fl is not None else float(bg.mean()))
    stats = [[cell_stats(rgb, gray, grid["ox"] + c * s, grid["oy"] + r * s, s, refs) for c in range(cols)]
             for r in range(rows)]

    cells, conf = [], []
    for r in range(rows):
        row, crow = [], []
        for c in range(cols):
            st = stats[r][c]
            k, p = classify(st, refs) if st else ("outside", 0.0)
            row.append(k)
            crow.append(round(p, 2))
        cells.append(row)
        conf.append(crow)
    tidy(cells, conf)
    eh, ev = wall_edges(gray, grid, rows, cols, refs)
    counts = {k: sum(row.count(k) for row in cells) for k in CLASSES}
    return dict(image=os.path.abspath(path), crop=list(crop) if crop else None, image_size=[W, H], grid=grid,
                refs={k: (np.round(v, 1).tolist() if isinstance(v, np.ndarray) else v) for k, v in refs.items()},
                classes=CLASSES, letters=LETTER, cells=cells, confidence=conf, edges=dict(h=eh, v=ev), counts=counts,
                text=["".join(LETTER[k] for k in row) for row in cells])


def overlay(draft, out_png, max_side=2400):
    img = Image.open(draft["image"]).convert("RGB")
    if draft["crop"]:
        x, y, w, h = draft["crop"]
        img = img.crop((x, y, x + w, y + h))
    g = draft["grid"]
    scale = min(1.0, max_side / max(img.size))
    if scale < 1:
        img = img.resize((int(img.size[0] * scale), int(img.size[1] * scale)))
    s, ox, oy = g["size"] * scale, g["ox"] * scale, g["oy"] * scale
    base = Image.blend(img, Image.new("RGB", img.size, (255, 255, 255)), 0.25).convert("RGBA")
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for r, row in enumerate(draft["cells"]):
        for c, k in enumerate(row):
            x0, y0 = ox + c * s, oy + r * s
            col = COLOURS[k]
            if k not in ("floor", "outside"):
                d.rectangle([x0 + 1, y0 + 1, x0 + s - 1, y0 + s - 1], fill=col + (90,))
            d.text((x0 + 3, y0 + 2), LETTER[k] if k != "outside" else "-", fill=col + (255,) if k != "floor" else (120, 100, 60, 255))
    for r in range(g["rows"] + 1):
        d.line([(ox, oy + r * s), (ox + g["cols"] * s, oy + r * s)], fill=(255, 0, 0, 110), width=1)
    for c in range(g["cols"] + 1):
        d.line([(ox + c * s, oy), (ox + c * s, oy + g["rows"] * s)], fill=(255, 0, 0, 110), width=1)
    wcol = {"wall": (150, 0, 0, 230), "door": (255, 150, 0, 255)}
    for r, row in enumerate(draft["edges"]["h"]):
        for c, k in enumerate(row):
            if k:
                d.line([(ox + c * s, oy + r * s), (ox + (c + 1) * s, oy + r * s)], fill=wcol[k], width=max(3, int(s / 10)))
    for r, row in enumerate(draft["edges"]["v"]):
        for c, k in enumerate(row):
            if k:
                d.line([(ox + c * s, oy + r * s), (ox + c * s, oy + (r + 1) * s)], fill=wcol[k], width=max(3, int(s / 10)))
    out = Image.alpha_composite(base, layer).convert("RGB")
    # A key along the bottom.
    key_h = 22
    full = Image.new("RGB", (out.size[0], out.size[1] + key_h), (255, 255, 255))
    full.paste(out, (0, 0))
    dk = ImageDraw.Draw(full)
    x = 6
    for k in CLASSES:
        dk.rectangle([x, out.size[1] + 5, x + 12, out.size[1] + 17], fill=COLOURS[k])
        dk.text((x + 16, out.size[1] + 5), k, fill=(0, 0, 0))
        x += 22 + 7 * len(k)
    dk.text((x + 10, out.size[1] + 5), f"grid {g['size']:.2f}px at {g['ox']:.1f},{g['oy']:.1f}  {g['cols']}x{g['rows']}",
            fill=(0, 0, 0))
    full.save(out_png)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("image")
    ap.add_argument("--grid", default="auto")
    ap.add_argument("--crop", help="x,y,w,h in pixels")
    ap.add_argument("--out", required=True, help="the draft (JSON)")
    ap.add_argument("--overlay", help="the overlay picture (default: next to the draft)")
    a = ap.parse_args()
    crop = [int(v) for v in a.crop.split(",")] if a.crop else None
    draft = import_map(a.image, a.grid, crop)
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    with open(a.out, "w") as f:
        json.dump(draft, f, indent=1)
    ov = a.overlay or os.path.splitext(a.out)[0] + "_overlay.png"
    overlay(draft, ov)
    g = draft["grid"]
    print(f"grid: {g['size']:.2f} px squares, lines at x = {g['ox']:.1f} + n*size, y = {g['oy']:.1f} + n*size "
          f"({g['cols']} x {g['rows']} squares, {g['found']})")
    print("squares: " + ", ".join(f"{k} {n}" for k, n in draft["counts"].items() if n))
    walls = sum(1 for row in draft["edges"]["h"] for k in row if k == "wall") + \
        sum(1 for row in draft["edges"]["v"] for k in row if k == "wall")
    doors = sum(1 for row in draft["edges"]["h"] for k in row if k == "door") + \
        sum(1 for row in draft["edges"]["v"] for k in row if k == "door")
    print(f"edges: {walls} wall, {doors} door")
    print(f"wrote {a.out} and {ov}")


if __name__ == "__main__":
    main()
