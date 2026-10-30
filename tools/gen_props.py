"""The board's prop kit: every piece of scenery the DM can set down on the battle mat, one mesh
per kind, built around its own footprint so the table can drop pieces in one at a time as the
DM describes a place (main/board/board.script). Boards (game/data/boards.lua) say which pieces
go where; this file says what each piece looks like and what it does on the mat.

Units are centimetres; a square is 5 cm. A piece's origin is the centre of its footprint, at the
mat's surface (y = 0). Its front faces +z (south, toward the DM's seat). fw x fh is the footprint
in squares before rotation.

Writes:
  assets/meshes/prop_<kind>_<part>.glb       one mesh per part (stone, paint, wood)
  assets/textures/props_palette.png          the painted parts' colours
  main/board/props/<kind>_<part>.model, main/board/props/<kind>.go, <kind>.factory
  main/board/board.go                        the board script and a factory per kind
  game/data/props.lua                        footprints and what each kind does on the mat

Run from the project root: python3 tools/gen_props.py
"""
import math
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import gen_meshes as gm  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SQ = 5.0

# ------------------------------------------------------------------ palette
PALETTE = {
    "bark": "#5b4030", "leaf_a": "#4f7a3a", "leaf_b": "#3e6a33", "leaf_c": "#6d9447", "leaf_d": "#2f5a2c",
    "log": "#6b4a32", "log_end": "#c49a6c", "ember": "#ff8a3d", "ember_dim": "#a8442a", "ash": "#3a3532",
    "ash_light": "#5e5853", "char": "#1e1a18", "canvas": "#d9c9a3", "canvas_dark": "#b8a47c", "bone": "#e3d9c0",
    "feather": "#c0483a", "altar_cloth": "#7a2f3a", "candle": "#efe6cf", "flame": "#ffcf6a",
    "wood_dark": "#5a3b25", "wood_mid": "#8a5e38", "wood_light": "#b08458", "wood_grey": "#7d7468",
    "bottle_green": "#3d6b4a", "bottle_amber": "#b07a2a", "mug_cream": "#e8dcc0", "mug_red": "#a8463a",
    "bowl": "#7a5236", "barrel": "#7a5232", "metal": "#6a6e74", "iron": "#3c3e42", "gold": "#d6a845",
    "bronze": "#9a6a32", "bronze_dark": "#6a4622", "awning_red": "#b2483a", "awning_blue": "#3f6a9a",
    "awning_yellow": "#d6a23d", "awning_green": "#4f7a52", "water": "#3a6f86", "water_deep": "#24495a",
    "water_light": "#6aa0b0", "crate": "#a07848", "hay": "#c9a95a", "chasm": "#16110e", "rope": "#a88b5a",
    "plaster": "#e6dcc6", "plaster_dark": "#c9bca2", "timber": "#4a3122", "roof_red": "#9a4a36",
    "roof_dark": "#6e3a2c", "thatch": "#b8954e", "thatch_dark": "#8a6c36", "slate": "#55606a",
    "window": "#ffd98a", "window_dark": "#2a2a36", "door": "#5a3420", "dirt": "#8a6a48", "dirt_dark": "#6e5238",
    "sand": "#d2b47c", "sand_dark": "#b8975e", "grass": "#6e8f4a", "grass_dark": "#55743a", "moss": "#5d7a3e",
    "paper": "#efe4c8", "ink": "#2a2420", "red_cloth": "#8a2e2e", "blue_cloth": "#2e4a7a", "purple_cloth": "#5a3a7a",
    "green_cloth": "#3a5a3a", "velvet": "#6a1e2e", "rug_a": "#8a3a2e", "rug_b": "#c9a24c", "rug_c": "#2e4a5a",
    "web": "#e8e8ee", "bone_dark": "#b8ab8c", "frost": "#d8e8f0", "banner_red": "#8a2a24", "banner_wolf": "#2a2a2a",
    "coin": "#e8c050", "stone_light": "#b0aaa0", "stone_dark": "#6a645c", "rust": "#8a4a2a", "white": "#f4f2ee",
    # The museum's (October 30). New colours go on the end, and only into the last row's free cells:
    # another row would move every swatch's v and change every mesh already made.
    "marble": "#e3ddd1", "marble_vein": "#bdb5a6", "glass": "#a9cfd9", "chalkboard": "#2c3a32", "pale_stone": "#cdc5b4",
}
COLS = 8
_KEYS = list(PALETTE.keys())
ROWS = (len(_KEYS) + COLS - 1) // COLS
assert ROWS == 11, "the palette grew a row: every prop and keepsake mesh would change (see PALETTE)"


def uv(name):
    i = _KEYS.index(name)
    return ((i % COLS + 0.5) / COLS, (i // COLS + 0.5) / ROWS)


def sw(name):
    return gm.swatch(uv(name))


def write_palette():
    cell = 16
    img = Image.new("RGB", (COLS * cell, ROWS * cell), (255, 0, 255))
    px = img.load()
    for i, k in enumerate(_KEYS):
        h = PALETTE[k].lstrip("#")
        c = tuple(int(h[j:j + 2], 16) for j in (0, 2, 4))
        cx, cy = (i % COLS) * cell, (i // COLS) * cell
        for y in range(cy, cy + cell):
            for x in range(cx, cx + cell):
                px[x, y] = c
    img.save(os.path.join(ROOT, "assets/textures/props_palette.png"))


STONE = gm.triplanar(12)
STONE_FINE = gm.triplanar(6)


class Parts:
    """A piece's meshes by part: stone (stone.png), paint (the palette), wood (wood_floor.png)."""

    def __init__(self):
        self.stone, self.paint, self.wood = gm.Mesh(), gm.Mesh(), gm.Mesh()


def rng_for(name):
    return np.random.default_rng(sum(map(ord, name)) * 7919 % 100003)


def blob(cx, cz, rx, rz, y, color, seed, n=14, jag=0.25):
    """A flat irregular patch (ash, dirt, water) lying on the mat."""
    rng = np.random.default_rng(abs(int(seed)))
    m = gm.Mesh()
    c = np.array((cx, y, cz))
    pts = []
    for k in range(n):
        a = 2 * math.pi * k / n
        r = 1 + rng.uniform(-jag, jag)
        pts.append(np.array((cx + math.cos(a) * rx * r, y, cz + math.sin(a) * rz * r)))
    up = np.array((0, 1.0, 0))
    for k in range(n):
        m.tri([c, pts[k], pts[(k + 1) % n]], [up] * 3, [uv(color)] * 3)
    return m


def rect(x0, z0, x1, z1, y, color):
    return gm.plane_xz((x0 + x1) / 2, y, (z0 + z1) / 2, x1 - x0, z1 - z0, sw(color))


def rocky(m, cx, cy, cz, r, seed, squash=0.7):
    m.add(gm.flatten_below(gm.rock((cx, cy, cz), r, abs(int(seed)), STONE, squash=squash), 0.0))


# ------------------------------------------------------------------ builders
# Each builder fills a Parts for one piece. P = Parts(); return P.

def b_pine(P, rng):
    P.paint.add(gm.cylinder((0, 0, 0), 0.9, 0.7, 4, 8, sw("bark")))
    for (y0, r, h, c) in [(3, 4.4, 7, "leaf_b"), (7, 3.5, 6, "leaf_a"), (11, 2.4, 5, "leaf_c")]:
        P.paint.add(gm.cylinder((0, y0, 0), r, 0.0, h, 9, sw(c), smooth=False))


def b_oak(P, rng):
    P.paint.add(gm.cylinder((0, 0, 0), 1.0, 0.8, 6, 8, sw("bark")))
    for (dx, dy, dz, r, c, s) in [(0, 8, 0, 4.0, "leaf_a", 1), (2.2, 6.5, 1.4, 3.0, "leaf_b", 2), (-2.2, 7, -1, 2.8, "leaf_c", 3)]:
        P.paint.add(gm.rock((dx, dy, dz), r, s + 11, sw(c), squash=0.9))


def b_dead_tree(P, rng):
    P.paint.add(gm.cylinder((0, 0, 0), 1.0, 0.5, 9, 7, sw("wood_grey")))
    for (a, y, l) in [(0.5, 5, 4), (2.6, 6.5, 3.4), (4.4, 4.2, 3)]:
        br = gm.cylinder((0, 0, 0), 0.4, 0.15, l, 5, sw("wood_grey"))
        P.paint.add(br.transformed(roll=-0.9, yaw=a, offset=(0, y, 0)))


def b_bush(P, rng):
    for (dx, dz, r, c, s) in [(0, 0, 2.2, "leaf_b", 1), (1.4, 1.0, 1.6, "leaf_a", 2), (-1.3, 0.8, 1.5, "leaf_c", 3)]:
        P.paint.add(gm.flatten_below(gm.rock((dx, r * 0.45, dz), r, s, sw(c), squash=0.75), 0.0))


def b_tall_grass(P, rng):
    P.paint.add(blob(0, 0, 2.3, 2.3, 0.13, "grass_dark", 5))
    for k in range(9):
        x, z = rng.uniform(-1.8, 1.8), rng.uniform(-1.8, 1.8)
        P.paint.add(gm.cylinder((x, 0, z), 0.35, 0.0, rng.uniform(1.6, 2.8), 4, sw(["grass", "leaf_c", "grass_dark"][k % 3]),
                                smooth=False))


def b_rock(P, rng):
    for k in range(3):
        r = 2.3 - k * 0.6
        rocky(P.stone, (k - 1) * 1.5, r * 0.35, ((k * 7) % 3 - 1) * 1.1, r, 30 + k)


def b_boulder(P, rng):
    rocky(P.stone, -0.5, 2.0, 0.2, 4.6, 41, squash=0.65)
    rocky(P.stone, 2.8, 1.0, 2.6, 2.0, 42)
    P.paint.add(gm.flatten_below(gm.rock((-2.0, 4.6, -1.0), 1.4, 43, sw("moss"), squash=0.3), 0.0))


def b_standing_stone(P, rng):
    P.stone.add(gm.box((0, 0, 0), (2.6, 2, 1.6), STONE).transformed(offset=(0, 0, 0)))
    st = gm.box((0, 5.5, 0), (2.4, 11, 1.5), STONE)
    P.stone.add(st.transformed(roll=0.05, yaw=0.2))
    P.paint.add(gm.box((0, 7, 0.8), (1.6, 0.25, 0.08), sw("moss")))


def b_fallen_log(P, rng):
    length = 3 * SQ - 0.8
    lg = gm.cylinder((0, -length / 2, 0), 1.6, 1.4, length, 10, sw("log"))
    P.paint.add(lg.transformed(roll=math.pi / 2, yaw=0.06, offset=(0, 1.5, 0)))
    for k in (-1, 1):
        P.paint.add(gm.rock((k * 3, 3.0, 0), 0.8, 50 + k, sw("moss")))


def b_stump(P, rng):
    P.paint.add(gm.cylinder((0, 0, 0), 1.6, 1.4, 1.8, 9, sw("bark")))
    P.paint.add(gm.cylinder((0, 1.79, 0), 1.35, 1.35, 0.05, 9, sw("log_end")))


def b_campfire(P, rng):
    for k in range(9):
        a = k / 9 * 2 * math.pi
        rocky(P.stone, math.cos(a) * 1.9, 0.4, math.sin(a) * 1.9, 0.7, 60 + k, squash=0.8)
    for k, a in enumerate((0.3, 1.35, 2.4)):
        lg = gm.box((0, 0, 0), (3.2, 0.7, 0.7), sw("log"))
        P.paint.add(lg.transformed(yaw=a, roll=0.18 * (1 if k % 2 else -1), offset=(0, 0.6, 0)))
    P.paint.add(gm.cylinder((0, 0, 0), 1.1, 0.8, 0.4, 10, sw("ember")))
    P.paint.add(gm.cylinder((0, 0.4, 0), 0.7, 0.0, 1.6, 6, sw("flame"), smooth=False))


def b_tent(P, rng):
    """An A-frame tent, its door end facing the DM so it reads as a tent from the table."""
    half, D, h = 4.4, 2.2, 6.4          # half width (x), half depth (z), ridge height
    for s in (-1, 1):
        # the two slopes, one a shade darker so the ridge reads
        ps = [(0, h, -D), (0, h, D), (s * half, 0, D), (s * half, 0, -D)]
        n = np.array((s * h, half, 0), float)
        n /= np.linalg.norm(n)
        P.paint.quad([np.array(p, float) for p in ps], [n] * 4, [uv("canvas" if s < 0 else "canvas_dark")] * 4)
    for s in (-1, 1):
        ps = [(-half, 0, s * D), (half, 0, s * D), (0, h, s * D)]
        P.paint.tri([np.array(p, float) for p in ps], [np.array((0, 0, s), float)] * 3, [uv("canvas")] * 3)
    # the door: a dark opening with one flap pinned back
    door = [(-1.5, 0.02, D + 0.06), (1.5, 0.02, D + 0.06), (0, 4.2, D + 0.06)]
    P.paint.tri([np.array(p, float) for p in door], [np.array((0, 0, 1), float)] * 3, [uv("char")] * 3)
    flap = [(1.5, 0.02, D + 0.12), (3.0, 0.02, D + 0.12), (0.3, 3.9, D + 0.12)]
    P.paint.tri([np.array(p, float) for p in flap], [np.array((0, 0, 1), float)] * 3, [uv("canvas_dark")] * 3)
    # ridge pole poking out at both ends, and a peg rope at each corner
    P.paint.add(gm.box((0, h + 0.1, 0), (0.5, 0.5, 2 * D + 1.2), sw("log")))
    for sx in (-1, 1):
        for sz in (-1, 1):
            P.paint.add(gm.box((sx * (half + 0.3), 0.3, sz * (D - 0.4)), (0.3, 0.6, 0.3), sw("wood_dark")))


def b_log_seat(P, rng):
    lg = gm.cylinder((0, -2.0, 0), 1.2, 1.2, 4.0, 10, sw("log"))
    P.paint.add(lg.transformed(roll=math.pi / 2, yaw=0.4, offset=(0, 1.2, 0)))


def b_totem(P, rng):
    P.paint.add(gm.box((0, 5, 0), (1.6, 10, 1.6), sw("log")))
    P.paint.add(gm.box((0, 8.5, 0), (4.0, 0.8, 0.8), sw("log")))
    P.paint.add(gm.sphere((0, 11, 0), 1.6, 8, 5, sw("bone")))
    for s in (-1, 1):
        P.paint.add(gm.box((s * 2.0, 9.4, 0), (0.5, 1.4, 0.5), sw("feather")))


def b_bedroll(P, rng):
    P.paint.add(gm.box((0, 0.35, 0.6), (3.2, 0.7, 7.0), sw("blue_cloth")))
    P.paint.add(gm.box((0, 0.6, -2.8), (2.4, 0.9, 1.4), sw("canvas")))


def b_weapon_rack(P, rng):
    for s in (-1, 1):
        P.paint.add(gm.box((s * 1.8, 3, 0), (0.5, 6, 0.5), sw("wood_dark")))
    P.paint.add(gm.box((0, 5.6, 0), (4.2, 0.5, 0.5), sw("wood_dark")))
    for k in range(4):
        sp = gm.cylinder((0, 0, 0), 0.15, 0.15, 7.5, 5, sw("wood_mid"))
        P.paint.add(sp.transformed(roll=0.12 * (k - 1.5), offset=(-1.2 + k * 0.8, 0, 0.3)))
        P.paint.add(gm.cylinder((-1.2 + k * 0.8 + 0.12 * (k - 1.5) * -7.4, 7.4, 0.3), 0.3, 0.0, 1.0, 4, sw("metal")))


def b_road_ew(P, rng):
    w = 20 * SQ
    P.paint.add(rect(-w / 2, -6.0, w / 2, 6.0, 0.10, "dirt"))
    for k in range(22):
        x = -w / 2 + rng.uniform(0, w)
        P.paint.add(blob(x, rng.uniform(-5, 5), rng.uniform(1.5, 4), rng.uniform(0.6, 1.6), 0.12, "dirt_dark", 70 + k, n=8))
    for e in (-1, 1):
        x = -w / 2
        while x < w / 2:
            P.paint.add(blob(x, e * 6.4, rng.uniform(1.2, 2.6), rng.uniform(0.5, 1.0), 0.11, "grass_dark", int(x * 3) + e * 7, n=7))
            x += rng.uniform(3, 6)


def b_path_ns(P, rng):
    h = 13 * SQ
    P.paint.add(rect(-6.0, -h / 2, 6.0, h / 2, 0.10, "dirt"))
    for k in range(14):
        P.paint.add(blob(rng.uniform(-5, 5), -h / 2 + rng.uniform(0, h), rng.uniform(0.6, 1.6), rng.uniform(1.5, 3.5),
                         0.12, "dirt_dark", 90 + k, n=8))


def b_path_patch(P, rng):
    P.paint.add(blob(0, 0, 7.0, 7.0, 0.10, "dirt", 101))
    P.paint.add(blob(1.5, -1.0, 3.0, 2.0, 0.12, "dirt_dark", 102))


def b_ash(P, rng):
    P.paint.add(blob(0, 0, 7.0, 6.6, 0.10, "ash", 111))
    P.paint.add(blob(-2.0, 1.5, 3.5, 2.5, 0.12, "ash_light", 112))
    for k in range(6):
        x, z = rng.uniform(-5, 5), rng.uniform(-5, 5)
        P.paint.add(gm.sphere((x, 0.15, z), 0.3, 5, 3, sw("ember_dim")))
    for k in range(3):
        lg = gm.box((0, 0, 0), (rng.uniform(2.5, 4.5), 0.6, 0.6), sw("char"))
        P.paint.add(lg.transformed(yaw=rng.uniform(0, 3), offset=(rng.uniform(-4, 4), 0.3, rng.uniform(-4, 4))))


def b_sand_ring(P, rng):
    P.paint.add(blob(0, 0, 14.0, 14.0, 0.10, "sand", 121, n=24, jag=0.05))
    for k in range(10):
        P.paint.add(blob(rng.uniform(-10, 10), rng.uniform(-10, 10), rng.uniform(1, 2.5), rng.uniform(0.8, 2), 0.12,
                         "sand_dark", 122 + k, n=7))


def b_puddle(P, rng):
    P.paint.add(blob(0, 0, 6.5, 6.0, 0.16, "water", 131))
    P.paint.add(blob(-1.0, -0.6, 3.0, 2.2, 0.18, "water_light", 132))


def b_stream_ns(P, rng):
    h = 13 * SQ
    P.paint.add(rect(-4.6, -h / 2, 4.6, h / 2, 0.16, "water"))
    for k in range(12):
        P.paint.add(blob(rng.uniform(-3, 3), -h / 2 + rng.uniform(0, h), rng.uniform(0.6, 1.4), rng.uniform(2, 4), 0.18,
                         "water_light", 140 + k, n=8))
    for e in (-1, 1):
        z = -h / 2 + 1
        while z < h / 2:
            rocky(P.stone, e * 4.8, 0.3, z, rng.uniform(0.6, 1.1), int(z * 5) + e * 3)
            z += rng.uniform(2.5, 4.5)


def b_pond(P, rng):
    P.paint.add(blob(0, 0, 7.0, 6.6, 0.16, "water_deep", 151, jag=0.12))
    P.paint.add(blob(0.8, 0.5, 4.5, 4.0, 0.18, "water", 152, jag=0.15))
    for k in range(10):
        a = k / 10 * 2 * math.pi
        rocky(P.stone, math.cos(a) * 7.0, 0.3, math.sin(a) * 6.6, rng.uniform(0.6, 1.1), 153 + k)
    for k in range(3):
        P.paint.add(gm.cylinder((rng.uniform(-6, 6), 0, rng.uniform(5, 6.5)), 0.2, 0.0, 3.0, 4, sw("grass")))


def b_chasm(P, rng):
    w, h = 3 * SQ, 5 * SQ
    P.paint.add(rect(-w / 2 + 0.6, -h / 2, w / 2 - 0.6, h / 2, 0.10, "chasm"))
    for e in (-1, 1):
        z = -h / 2 + 1
        while z < h / 2:
            rocky(P.stone, e * (w / 2 - 0.4), 0.4, z, rng.uniform(0.8, 1.4), int(z * 7) + e * 5)
            z += rng.uniform(2.0, 3.0)


def b_rope_bridge(P, rng):
    w, d = 3 * SQ + 2, 3 * SQ - 1
    n = int(w / 1.4)
    for k in range(n):
        x = -w / 2 + 0.7 + k * 1.4
        P.paint.add(gm.box((x, 0.5, 0), (1.1, 0.3, d - 3), sw("wood_mid")))
    for z in (-d / 2 + 1, d / 2 - 1):
        P.paint.add(gm.box((0, 2.2, z), (w, 0.25, 0.25), sw("rope")))
        for x in (-w / 2, w / 2):
            P.paint.add(gm.box((x, 1.4, z), (0.6, 2.8, 0.6), sw("wood_dark")))


def b_cliff(P, rng):
    for k in range(3):
        rocky(P.stone, rng.uniform(-1, 1), 3.0 + k * 2.2, rng.uniform(-1, 1), 2.8 - k * 0.5, 160 + k, squash=1.3)


# --- town ---------------------------------------------------------------------------------

def gable_roof(P, w, d, y0, rise, color, overhang=0.8):
    """A pitched roof along x over a w x d footprint."""
    L = w / 2 + overhang
    half = d / 2 + overhang
    for s in (-1, 1):
        ps = [(-L, y0, s * half), (L, y0, s * half), (L, y0 + rise, 0), (-L, y0 + rise, 0)]
        n = np.array((0, half, s * rise), float)
        n /= np.linalg.norm(n)
        P.paint.quad([np.array(p, float) for p in ps], [n] * 4, [uv(color)] * 4)
        # underside so the roof never shows a hole from below
        P.paint.quad([np.array(p, float) for p in ps], [-n] * 4, [uv(color)] * 4)
    for s in (-1, 1):
        ps = [(s * (w / 2), y0, -d / 2), (s * (w / 2), y0, d / 2), (s * (w / 2), y0 + rise * (d / 2) / half, 0)]
        P.paint.tri([np.array(p, float) for p in ps], [np.array((s, 0, 0), float)] * 3, [uv("plaster")] * 3)


def timber_walls(P, w, d, h, plaster="plaster"):
    P.paint.add(gm.box((0, h / 2, 0), (w, h, d), sw(plaster)))
    for sx in (-1, 1):
        for sz in (-1, 1):
            P.paint.add(gm.box((sx * (w / 2 - 0.3), h / 2, sz * (d / 2 - 0.3)), (0.8, h + 0.1, 0.8), sw("timber")))
    for y in (0.4, h - 0.3):
        P.paint.add(gm.box((0, y, d / 2 + 0.05), (w + 0.2, 0.6, 0.25), sw("timber")))
        P.paint.add(gm.box((0, y, -d / 2 - 0.05), (w + 0.2, 0.6, 0.25), sw("timber")))
    P.paint.add(gm.box((0, h * 0.55, d / 2 + 0.05), (w + 0.2, 0.5, 0.25), sw("timber")))


def window(P, x, y, z, facing=1, w=1.8, h=2.0, lit=True):
    P.paint.add(gm.box((x, y, z + facing * 0.15), (w + 0.5, h + 0.5, 0.2), sw("timber")))
    P.paint.add(gm.box((x, y, z + facing * 0.28), (w, h, 0.1), sw("window" if lit else "window_dark")))
    P.paint.add(gm.box((x, y, z + facing * 0.34), (0.2, h, 0.05), sw("timber")))


def door(P, x, z, facing=1, w=2.4, h=4.2):
    P.paint.add(gm.box((x, h / 2, z + facing * 0.2), (w, h, 0.3), sw("door")))
    P.paint.add(gm.box((x, h + 0.25, z + facing * 0.25), (w + 0.6, 0.5, 0.35), sw("timber")))
    P.paint.add(gm.sphere((x + w * 0.3, h * 0.45, z + facing * 0.45), 0.18, 5, 3, sw("iron")))


def b_house(P, rng):
    w, d, h = 3 * SQ - 1.6, 3 * SQ - 2.4, 8.0
    timber_walls(P, w, d, h)
    gable_roof(P, w, d, h, 5.5, "roof_red")
    P.stone.add(gm.box((w / 2 - 2.2, h + 4.0, -1.5), (1.6, 6.0, 1.6), STONE))
    door(P, -2.5, d / 2)
    window(P, 3.0, 5.0, d / 2)
    window(P, -3.4, 5.6, -d / 2, facing=-1, lit=False)
    P.paint.add(gm.box((w / 2 + 0.15, 5.0, 0), (0.2, 2.2, 1.8), sw("window")))
    P.paint.add(gm.box((-w / 2 - 0.15, 5.0, 0), (0.2, 2.2, 1.8), sw("window_dark")))


def b_cottage(P, rng):
    w, d, h = 3 * SQ - 2.0, 2 * SQ - 1.6, 6.5
    timber_walls(P, w, d, h)
    gable_roof(P, w, d, h, 4.5, "thatch")
    door(P, 2.6, d / 2, w=2.2, h=3.8)
    window(P, -2.8, 4.2, d / 2)
    P.stone.add(gm.box((-w / 2 + 1.4, h + 3.0, 0.6), (1.4, 5.0, 1.4), STONE))


def b_shop(P, rng):
    w, d, h = 3 * SQ - 1.4, 2 * SQ - 2.0, 7.0
    timber_walls(P, w, d, h)
    gable_roof(P, w, d, h, 4.2, "slate")
    door(P, 3.6, d / 2, w=2.2, h=4.0)
    P.paint.add(gm.box((-1.8, 3.4, d / 2 + 0.3), (6.0, 2.6, 0.2), sw("window")))
    aw = gm.box((0, 0, 0), (8.4, 0.3, 3.0), sw("awning_green"))
    P.paint.add(aw.transformed(pitch=-0.35, offset=(-1.6, 5.4, d / 2 + 1.3)))
    P.paint.add(gm.box((-1.6, 6.3, d / 2 + 0.2), (5.0, 1.0, 0.25), sw("wood_light")))


def b_house_burned(P, rng):
    w, d = 3 * SQ - 1.6, 3 * SQ - 2.4
    # charred walls, broken at different heights; no roof
    for (x, z, sx, sz, hh) in [(0, d / 2, w, 0.9, 3.0), (0, -d / 2, w, 0.9, 7.0), (-w / 2, 0, 0.9, d, 5.5), (w / 2, 0, 0.9, d, 2.2)]:
        segs = 4
        for k in range(segs):
            t = (k + 0.5) / segs
            hk = hh * rng.uniform(0.35, 1.0)
            if sx > sz:
                P.paint.add(gm.box((x - sx / 2 + t * sx, hk / 2, z), (sx / segs, hk, sz), sw("char")))
            else:
                P.paint.add(gm.box((x, hk / 2, z - sz / 2 + t * sz), (sx, hk, sz / segs), sw("char")))
    P.paint.add(blob(0, 0, w / 2 - 0.5, d / 2 - 0.5, 0.12, "ash", 171))
    for k in range(4):
        bm = gm.box((0, 0, 0), (rng.uniform(5, 9), 0.7, 0.7), sw("char"))
        P.paint.add(bm.transformed(yaw=rng.uniform(0, 3), roll=rng.uniform(-0.3, 0.3), offset=(rng.uniform(-3, 3), 0.8, rng.uniform(-3, 3))))
    for k in range(5):
        P.paint.add(gm.sphere((rng.uniform(-4, 4), 0.2, rng.uniform(-4, 4)), 0.35, 5, 3, sw("ember_dim")))
    P.stone.add(gm.box((w / 2 - 2.0, 4.5, -d / 2 + 1.6), (1.8, 9.0, 1.8), STONE))


def b_town_wall(P, rng):
    h = 9.0
    P.stone.add(gm.box((0, h / 2, 0), (SQ + 0.05, h, 3.6), STONE))
    for k in (-1, 1):
        P.stone.add(gm.box((k * 1.3, h + 1.0, 0), (1.8, 2.0, 3.6), STONE))


def b_gate(P, rng):
    h = 10.0
    for s in (-1, 1):
        P.stone.add(gm.box((s * SQ, h / 2, 0), (SQ + 0.4, h, 4.4), STONE))
        P.stone.add(gm.box((s * SQ, h + 1.2, 0), (SQ + 0.8, 2.4, 4.8), STONE))
    P.stone.add(gm.box((0, h - 1.2, 0), (SQ, 2.4, 4.2), STONE))
    for k in range(5):
        P.paint.add(gm.box((-2.0 + k, (h - 2.4) / 2 + 2.2, -1.6), (0.25, h - 2.4 - 2.2, 0.25), sw("iron")))
    P.paint.add(gm.box((0, h - 3.0, -1.6), (4.4, 0.3, 0.3), sw("iron")))


def b_watchtower(P, rng):
    P.stone.add(gm.cylinder((0, 0, 0), 4.4, 4.0, 14.0, 12, STONE))
    for k in range(8):
        a = k / 8 * 2 * math.pi
        P.stone.add(gm.box((math.cos(a) * 3.7, 15.0, math.sin(a) * 3.7), (1.6, 2.0, 1.6), STONE))
    P.paint.add(gm.box((0, 6.0, 4.1), (1.6, 2.2, 0.2), sw("window")))


def b_fence(P, rng):
    for s in (-1, 1):
        P.paint.add(gm.box((s * 2.2, 1.6, 0), (0.5, 3.2, 0.5), sw("wood_dark")))
    for y in (1.2, 2.5):
        P.paint.add(gm.box((0, y, 0), (SQ + 0.2, 0.35, 0.3), sw("wood_mid")))


def b_well(P, rng):
    P.stone.add(gm.cylinder((0, 0, 0), 2.2, 2.2, 2.4, 14, STONE))
    P.paint.add(gm.cylinder((0, 2.3, 0), 1.6, 1.6, 0.15, 14, sw("water")))
    for sx in (-1, 1):
        P.paint.add(gm.box((sx * 2.0, 4.5, 0), (0.5, 5.0, 0.5), sw("wood_dark")))
    for s in (-1, 1):
        P.paint.add(gm.box((0, 0, 0), (3.0, 0.3, 5.2), sw("roof_dark")).transformed(roll=s * 0.6, offset=(s * 1.1, 7.6, 0)))
    P.paint.add(gm.box((0, 6.6, 0), (4.4, 0.4, 0.4), sw("wood_mid")))
    P.paint.add(gm.box((0.3, 4.6, 0), (0.15, 2.0, 0.15), sw("rope")))
    P.paint.add(gm.cylinder((0.3, 3.0, 0), 0.6, 0.7, 1.2, 8, sw("barrel")))


def b_stall(P, rng):
    awn = ["awning_red", "awning_blue", "awning_yellow"][int(rng.integers(0, 3))]
    P.paint.add(gm.box((0, 2.0, 2.0), (9.0, 4.0, 3.0), sw("wood_mid")))
    for sx in (-1, 1):
        for sz in (-1, 1):
            P.paint.add(gm.box((sx * 4.2, 4.5, sz * 3.8), (0.5, 9.0, 0.5), sw("wood_dark")))
    P.paint.add(gm.box((0, 0, 0), (10.0, 0.4, 9.0), sw(awn)).transformed(pitch=0.18, offset=(0, 9.2, 0)))
    for k in range(4):
        P.paint.add(gm.sphere((-3 + k * 2, 4.5, 2.0), 0.7, 6, 4, sw(["gold", "mug_red", "leaf_c", "hay"][k])))


def b_cart(P, rng):
    P.paint.add(gm.box((0, 3.0, 0), (8.0, 1.6, 4.4), sw("wood_mid")))
    P.paint.add(gm.box((0, 4.4, 0), (7.0, 1.4, 3.6), sw("hay")))
    for sx in (-1, 1):
        for sz in (-1, 1):
            wh = gm.cylinder((0, -0.3, 0), 1.6, 1.6, 0.6, 12, sw("wood_dark"))
            P.paint.add(wh.transformed(pitch=math.pi / 2, offset=(sx * 2.8, 1.6, sz * 2.5)))
    P.paint.add(gm.box((-5.6, 2.6, 0), (3.6, 0.4, 0.4), sw("wood_dark")))


def b_crate(P, rng):
    P.paint.add(gm.box((0, 1.6, 0), (3.4, 3.2, 3.4), sw("crate")).transformed(yaw=0.2))
    P.paint.add(gm.box((0.6, 3.9, -0.4), (2.2, 1.6, 2.2), sw("crate")))
    for y in (0.5, 2.7):
        P.paint.add(gm.box((0, y, 0), (3.5, 0.3, 3.5), sw("wood_dark")).transformed(yaw=0.2))


def b_barrel(P, rng):
    P.paint.add(gm.cylinder((0, 0, 0), 1.7, 1.9, 2.2, 12, sw("barrel")))
    P.paint.add(gm.cylinder((0, 2.2, 0), 1.9, 1.7, 2.2, 12, sw("barrel")))
    for y in (0.6, 2.2, 3.8):
        P.paint.add(gm.cylinder((0, y - 0.2, 0), 1.95, 1.95, 0.4, 12, sw("metal")))


def b_hay_bale(P, rng):
    P.paint.add(gm.box((0, 1.4, 0), (4.0, 2.8, 2.8), sw("hay")))
    for x in (-1.0, 1.0):
        P.paint.add(gm.box((x, 1.4, 0), (0.2, 2.9, 2.9), sw("thatch_dark")))


def b_lamp_post(P, rng):
    P.paint.add(gm.cylinder((0, 0, 0), 0.4, 0.3, 9.0, 6, sw("iron")))
    P.paint.add(gm.box((0, 9.4, 0), (1.4, 1.6, 1.4), sw("iron")))
    P.paint.add(gm.box((0, 9.4, 0), (1.0, 1.2, 1.5), sw("window")))


def b_bench(P, rng):
    P.paint.add(gm.box((0, 2.0, 0), (8.0, 0.5, 2.0), sw("wood_mid")))
    for s in (-1, 1):
        P.paint.add(gm.box((s * 3.4, 1.0, 0), (0.6, 2.0, 1.6), sw("wood_dark")))


def b_notice_board(P, rng):
    for s in (-1, 1):
        P.paint.add(gm.box((s * 1.8, 3.5, 0), (0.4, 7.0, 0.4), sw("wood_dark")))
    P.paint.add(gm.box((0, 5.2, 0), (4.4, 3.0, 0.3), sw("wood_mid")))
    for k in range(4):
        P.paint.add(gm.box((-1.4 + k * 0.95, 5.2 + (k % 2) * 0.5, 0.2), (0.8, 1.0, 0.05), sw("paper")))


def b_statue(P, rng):
    P.stone.add(gm.box((0, 1.0, 0), (4.0, 2.0, 4.0), STONE))
    P.stone.add(gm.cylinder((0, 2.0, 0), 1.2, 1.0, 5.0, 8, STONE))
    P.stone.add(gm.sphere((0, 8.0, 0), 1.0, 8, 6, STONE))
    for s in (-1, 1):
        arm = gm.cylinder((0, 0, 0), 0.4, 0.3, 3.0, 6, STONE)
        P.stone.add(arm.transformed(roll=s * 0.5, offset=(s * 1.0, 6.4, 0)))


def b_signpost(P, rng):
    P.paint.add(gm.box((0, 3.5, 0), (0.5, 7.0, 0.5), sw("wood_dark")))
    for (y, a) in [(6.0, 0.2), (5.0, -0.4)]:
        P.paint.add(gm.box((1.2, 0, 0), (3.0, 0.8, 0.2), sw("wood_light")).transformed(yaw=a, offset=(0, y, 0)))


def b_bell_fallen(P, rng):
    bell = gm.cylinder((0, 0, 0), 2.0, 1.0, 3.2, 12, sw("bronze"), caps=(False, True))
    bell.add(gm.cylinder((0, 0, 0), 1.9, 0.95, 3.1, 12, sw("bronze_dark"), caps=(False, False), inside=True))
    P.paint.add(bell.transformed(pitch=1.3, offset=(0, 1.9, -0.6)))
    P.paint.add(blob(0, 0.6, 2.4, 2.0, 0.12, "ash", 181))


def b_pit_ring(P, rng):
    """The fighting pit: a sand ring with posts and ropes. 6 x 6; only the posts block."""
    r = 3 * SQ - 1.0
    P.paint.add(blob(0, 0, r, r, 0.10, "sand", 191, n=24, jag=0.03))
    for k in range(8):
        P.paint.add(blob(rng.uniform(-10, 10), rng.uniform(-10, 10), rng.uniform(1, 2.5), rng.uniform(0.8, 2), 0.12,
                         "sand_dark", 192 + k, n=7))
    c = 3 * SQ - 2.5
    posts = [(-c, -c), (c, -c), (c, c), (-c, c)]
    for (x, z) in posts:
        P.paint.add(gm.box((x, 3.0, z), (0.8, 6.0, 0.8), sw("wood_dark")))
    for i in range(4):
        (x0, z0), (x1, z1) = posts[i], posts[(i + 1) % 4]
        for y in (2.4, 4.4):
            L = math.hypot(x1 - x0, z1 - z0)
            a = math.atan2(z1 - z0, x1 - x0)
            P.paint.add(gm.box((0, 0, 0), (L, 0.2, 0.2), sw("rope")).transformed(yaw=-a, offset=((x0 + x1) / 2, y, (z0 + z1) / 2)))


# --- indoors --------------------------------------------------------------------------------

def grid_lines(P, color, w=0.14):
    """The battle grid, drawn faintly over a floor so the squares still read."""
    W, H = 20 * SQ, 13 * SQ
    for i in range(1, 20):
        x = -W / 2 + i * SQ
        P.paint.add(rect(x - w / 2, -H / 2, x + w / 2, H / 2, 0.07, color))
    for j in range(1, 13):
        z = -H / 2 + j * SQ
        P.paint.add(rect(-W / 2, z - w / 2, W / 2, z + w / 2, 0.07, color))


def ground(P, rng, base, shades, grid, n=70):
    """Outdoor ground over the whole mat: a base colour, mottled, with the grid drawn faintly."""
    W, H = 20 * SQ, 13 * SQ
    P.paint.add(rect(-W / 2, -H / 2, W / 2, H / 2, 0.04, base))
    for k in range(n):
        P.paint.add(blob(rng.uniform(-W / 2 + 3, W / 2 - 3), rng.uniform(-H / 2 + 3, H / 2 - 3), rng.uniform(2.0, 6.0),
                         rng.uniform(1.5, 4.0), 0.05 + 0.002 * (k % 5), shades[k % len(shades)], 300 + k, n=9, jag=0.3))
    grid_lines(P, grid, w=0.12)


def b_floor_grass(P, rng):
    ground(P, rng, "grass", ["grass_dark", "leaf_c", "moss"], "grass_dark")


def b_floor_dirt(P, rng):
    ground(P, rng, "dirt", ["dirt_dark", "sand_dark", "grass_dark"], "dirt_dark")


def b_floor_ash(P, rng):
    ground(P, rng, "ash_light", ["ash", "grass_dark", "dirt_dark"], "ash")


def b_floor_sand(P, rng):
    ground(P, rng, "sand", ["sand_dark", "dirt"], "sand_dark", n=40)


def b_floor_boards(P, rng):
    """Floorboards, painted plank by plank (so a room reads apart from the wooden table under it)."""
    W, H = 20 * SQ, 13 * SQ
    P.paint.add(rect(-W / 2, -H / 2, W / 2, H / 2, 0.04, "timber"))
    shades = ["wood_mid", "wood_light", "barrel", "crate"]
    row_h = 2.5
    z = -H / 2
    r = 0
    while z < H / 2 - 0.01:
        x = -W / 2 - rng.uniform(0, 12)
        while x < W / 2:
            length = rng.uniform(10, 26)
            x0, x1 = max(x, -W / 2), min(x + length, W / 2)
            if x1 - x0 > 0.5:
                P.paint.add(rect(x0 + 0.08, z + 0.1, x1 - 0.08, min(z + row_h, H / 2) - 0.1, 0.05,
                                 shades[int(rng.integers(0, len(shades)))]))
            x += length
        z += row_h
        r += 1
    grid_lines(P, "timber")


def b_floor_flags(P, rng):
    P.stone.add(gm.plane_xz(0, 0.04, 0, 20 * SQ, 13 * SQ, gm.triplanar(14.0)))
    grid_lines(P, "stone_dark")


def b_floor_cobbles(P, rng):
    P.stone.add(gm.plane_xz(0, 0.04, 0, 20 * SQ, 13 * SQ, gm.triplanar(8.0)))
    grid_lines(P, "stone_dark")


def room_wall(P, kind):
    h, t = 11.0, 1.6
    z = -SQ / 2 + t / 2 + 0.2
    P.paint.add(gm.box((0, h / 2, z), (SQ + 0.05, h, t), sw("plaster")))
    P.paint.add(gm.box((0, 0.5, z + t / 2 + 0.05), (SQ + 0.05, 1.0, 0.2), sw("timber")))
    P.paint.add(gm.box((0, h - 0.4, z + t / 2 + 0.05), (SQ + 0.05, 0.8, 0.2), sw("timber")))
    P.paint.add(gm.box((-SQ / 2 + 0.4, h / 2, z + t / 2 + 0.05), (0.8, h, 0.2), sw("timber")))
    if kind == "window":
        window(P, 0, 6.5, z + t / 2, w=2.4, h=2.8)
    elif kind == "door":
        door(P, 0, z + t / 2, w=2.8, h=6.4)
    elif kind == "shelf":
        P.paint.add(gm.box((0, 6.0, z + t / 2 + 0.6), (4.2, 0.3, 1.2), sw("wood_mid")))
        for k in range(4):
            P.paint.add(gm.cylinder((-1.5 + k, 6.15, z + t / 2 + 0.6), 0.35, 0.3, 1.2, 6,
                                    sw(["bottle_green", "mug_cream", "bottle_amber", "mug_red"][k])))


def b_wall_room(P, rng):
    room_wall(P, "plain")


def b_wall_window(P, rng):
    room_wall(P, "window")


def b_wall_door(P, rng):
    room_wall(P, "door")


def b_wall_shelf(P, rng):
    room_wall(P, "shelf")


def b_bar(P, rng):
    P.paint.add(gm.box((0, 3.0, 0.6), (SQ + 0.05, 6.0, 3.0), sw("wood_dark")))
    P.paint.add(gm.box((0, 6.2, 0.6), (SQ + 0.4, 0.5, 3.6), sw("wood_mid")))
    for k in range(3):
        col = ["bottle_green", "bottle_amber", "mug_cream"][(k + int(rng.integers(0, 3))) % 3]
        P.paint.add(gm.cylinder((-1.5 + k * 1.5, 6.45, 0.6 + rng.uniform(-0.6, 0.6)), 0.5, 0.4, 2.0, 6, sw(col)))


def b_counter(P, rng):
    P.paint.add(gm.box((0, 2.8, 0), (SQ + 0.05, 5.6, 3.0), sw("wood_mid")))
    P.paint.add(gm.box((0, 5.8, 0), (SQ + 0.4, 0.4, 3.4), sw("wood_dark")))


def b_hearth(P, rng):
    P.stone.add(gm.box((0, 5.0, -1.2), (9.0, 10.0, 3.0), STONE))
    P.stone.add(gm.box((0, 10.5, -1.2), (6.0, 3.0, 2.4), STONE))
    P.paint.add(gm.box((0, 2.6, 0.4), (5.0, 4.0, 0.3), sw("chasm")))
    for a in (0.2, 2.0):
        P.paint.add(gm.box((0, 0, 0), (3.6, 0.8, 0.8), sw("log")).transformed(yaw=a, offset=(0, 0.6, 1.0)))
    P.paint.add(gm.cylinder((0, 0, 1.0), 1.2, 0.8, 0.4, 8, sw("ember")))
    P.paint.add(gm.cylinder((0, 0.4, 1.0), 0.8, 0.0, 2.2, 6, sw("flame"), smooth=False))
    P.paint.add(gm.box((0, 7.0, 0.5), (8.0, 0.5, 1.2), sw("wood_dark")))


def b_table_round(P, rng):
    top = 3.8
    P.paint.add(gm.cylinder((0, top, 0), 2.1, 2.1, 0.5, 12, sw("wood_mid")))
    P.paint.add(gm.cylinder((0, 0, 0), 0.5, 0.4, top, 6, sw("wood_dark")))
    P.paint.add(gm.cylinder((-0.8, top + 0.5, 0.4), 0.45, 0.4, 1.1, 6, sw("mug_red")))
    P.paint.add(gm.cylinder((0.7, top + 0.5, -0.5), 0.9, 0.9, 0.3, 8, sw("bowl")))
    for k in range(2):
        a = k * math.pi + 0.6
        P.paint.add(gm.cylinder((math.cos(a) * 2.4, 0, math.sin(a) * 2.4), 0.8, 0.8, 2.2, 8, sw("wood_dark")))


def b_table_long(P, rng):
    w, d, top = 9.0, 3.6, 4.0
    P.paint.add(gm.box((0, top, 0), (w, 0.6, d), sw("wood_mid")))
    for sx in (-1, 1):
        for sz in (-1, 1):
            P.paint.add(gm.box((sx * (w / 2 - 0.6), top / 2, sz * (d / 2 - 0.6)), (0.6, top, 0.6), sw("wood_dark")))
    for k in range(3):
        P.paint.add(gm.cylinder((-3 + k * 3, top + 0.3, 0.3), 0.45, 0.4, 1.1, 6, sw(["mug_cream", "mug_red", "bottle_amber"][k])))
    for s in (-1, 1):
        P.paint.add(gm.box((0, 2.0, s * 3.0), (w - 1, 0.5, 1.4), sw("wood_dark")))


def b_bed(P, rng):
    P.paint.add(gm.box((0, 1.4, 0), (4.0, 1.6, 9.0), sw("wood_dark")))
    P.paint.add(gm.box((0, 2.5, 0.6), (3.6, 0.8, 7.4), sw("red_cloth")))
    P.paint.add(gm.box((0, 2.8, -3.4), (3.0, 0.9, 1.6), sw("canvas")))
    P.paint.add(gm.box((0, 3.0, -4.3), (4.0, 4.2, 0.5), sw("wood_dark")))


def b_desk(P, rng):
    w, d, top = 9.0, 4.0, 4.2
    P.paint.add(gm.box((0, top, 0), (w, 0.5, d), sw("wood_dark")))
    for sx in (-1, 1):
        P.paint.add(gm.box((sx * (w / 2 - 1.2), top / 2, 0), (2.2, top, d - 0.4), sw("wood_mid")))
    for k in range(4):
        P.paint.add(gm.box((-3 + k * 1.6, top + 0.3, rng.uniform(-0.8, 0.8)), (1.6, 0.1, 2.0), sw("paper")).transformed(
            yaw=rng.uniform(-0.3, 0.3)))
    P.paint.add(gm.box((2.4, top + 0.5, -0.6), (2.6, 0.6, 1.8), sw("red_cloth")))
    P.paint.add(gm.cylinder((3.6, top + 0.25, 1.1), 0.3, 0.3, 1.2, 6, sw("candle")))
    P.paint.add(gm.sphere((3.6, top + 1.7, 1.1), 0.3, 6, 4, sw("flame")))
    P.paint.add(gm.cylinder((0, 0, 3.0), 0.9, 0.9, 2.4, 8, sw("wood_mid")))


def b_bookshelf(P, rng):
    w, d, h = 9.0, 2.4, 11.0
    P.paint.add(gm.box((0, h / 2, -0.8), (w, h, d), sw("wood_dark")))
    cols = ["red_cloth", "blue_cloth", "green_cloth", "bottle_amber", "purple_cloth", "paper"]
    for row in range(4):
        y = 1.2 + row * 2.5
        x = -w / 2 + 0.6
        while x < w / 2 - 1.0:
            bw = rng.uniform(0.4, 0.8)
            bh = rng.uniform(1.4, 2.0)
            P.paint.add(gm.box((x + bw / 2, y + bh / 2, 0.3), (bw, bh, 1.4), sw(cols[int(rng.integers(0, len(cols)))])))
            x += bw + 0.05
        P.paint.add(gm.box((0, y - 0.1, 0.3), (w - 0.4, 0.25, 1.6), sw("wood_mid")))


def b_scroll_rack(P, rng):
    w, d, h = 9.0, 2.4, 9.0
    P.paint.add(gm.box((0, h / 2, -0.8), (w, h, d), sw("wood_mid")))
    for row in range(3):
        for k in range(7):
            sc = gm.cylinder((0, -0.9, 0), 0.35, 0.35, 1.8, 6, sw("paper"))
            P.paint.add(sc.transformed(pitch=math.pi / 2, offset=(-3.6 + k * 1.2, 1.8 + row * 2.8, 0.6)))


def b_chest(P, rng):
    P.paint.add(gm.box((0, 1.3, 0), (4.0, 2.6, 2.8), sw("wood_mid")))
    lid = gm.cylinder((0, -2.0, 0), 1.4, 1.4, 4.0, 10, sw("wood_mid"), caps=(True, True))
    P.paint.add(lid.transformed(roll=math.pi / 2, offset=(0, 2.6, 0)))
    for x in (-1.4, 1.4):
        P.paint.add(gm.box((x, 2.0, 0), (0.35, 4.0, 3.0), sw("iron")))
    P.paint.add(gm.box((0, 2.2, 1.45), (0.8, 0.9, 0.2), sw("gold")))


def b_strongbox(P, rng):
    b_chest(P, rng)
    for k in range(6):
        P.paint.add(gm.cylinder((rng.uniform(-2, 2), 0, rng.uniform(1.8, 2.4)), 0.5, 0.5, 0.2 + 0.2 * (k % 3), 8, sw("coin")))


def b_rug(P, rng):
    w, d = 3 * SQ - 2.0, 2 * SQ - 2.0
    P.paint.add(rect(-w / 2, -d / 2, w / 2, d / 2, 0.20, "rug_a"))
    P.paint.add(rect(-w / 2 + 1.0, -d / 2 + 1.0, w / 2 - 1.0, d / 2 - 1.0, 0.21, "rug_b"))
    P.paint.add(rect(-w / 2 + 2.0, -d / 2 + 2.0, w / 2 - 2.0, d / 2 - 2.0, 0.22, "rug_c"))


def b_wardrobe(P, rng):
    P.paint.add(gm.box((0, 6.0, -0.6), (4.4, 12.0, 3.0), sw("wood_dark")))
    for s in (-1, 1):
        P.paint.add(gm.box((s * 1.1, 6.0, 0.95), (2.0, 10.6, 0.1), sw("wood_mid")))


def b_candelabra(P, rng):
    P.paint.add(gm.cylinder((0, 0, 0), 1.0, 0.3, 0.6, 8, sw("iron")))
    P.paint.add(gm.cylinder((0, 0.6, 0), 0.25, 0.25, 6.0, 6, sw("iron")))
    for s in (-1, 0, 1):
        P.paint.add(gm.cylinder((s * 1.2, 6.4, 0), 0.3, 0.3, 1.2, 6, sw("candle")))
        P.paint.add(gm.sphere((s * 1.2, 7.9, 0), 0.3, 6, 4, sw("flame")))
    P.paint.add(gm.box((0, 6.3, 0), (2.8, 0.25, 0.25), sw("iron")))


def b_curtain(P, rng):
    P.paint.add(gm.box((0, 11.0, -1.6), (SQ, 0.3, 0.3), sw("iron")))
    for k in range(5):
        P.paint.add(gm.box((-2.0 + k, 5.4, -1.6 + 0.2 * (k % 2)), (1.0, 10.8, 0.3), sw("velvet")))


# --- sacred and ruined ------------------------------------------------------------------

def b_pillar(P, rng, height=12.0):
    P.stone.add(gm.box((0, 0.6, 0), (4.2, 1.2, 4.2), STONE))
    P.stone.add(gm.cylinder((0, 1.2, 0), 1.7, 1.5, height - 2.4, 10, STONE))
    if height > 8:
        P.stone.add(gm.box((0, height - 0.6, 0), (4.0, 1.2, 4.0), STONE))


def b_broken_pillar(P, rng):
    b_pillar(P, rng, height=6.0)
    ch = gm.cylinder((0, -2.5, 0), 1.6, 1.6, 5.0, 10, STONE)
    P.stone.add(ch.transformed(roll=math.pi / 2, yaw=0.6, offset=(1.0, 1.6, 2.0)))


def b_ruin_wall(P, rng, rows=3):
    for row in range(rows):
        n = 2 if row % 2 == 0 else 1
        for b in range(n):
            x = -1.15 + b * 2.4 if n == 2 else 0.0
            blk = gm.box((0, 0, 0), (2.3 if n == 2 else 4.6, 2.8, 3.0), STONE)
            P.stone.add(blk.transformed(yaw=rng.uniform(-0.05, 0.05), offset=(x, 1.4 + row * 2.85, rng.uniform(-0.2, 0.2))))
    if rows >= 3:
        P.paint.add(gm.box((rng.uniform(-1, 1), rows * 2.85 + 0.05, 0), (1.6, 0.15, 2.0), sw("moss")))


def b_ruin_wall_low(P, rng):
    b_ruin_wall(P, rng, rows=1)


def b_stone_wall(P, rng):
    """A full-height masonry wall (towers, crypts): solid, no gaps."""
    h = 12.0
    P.stone.add(gm.box((0, h / 2, -0.4), (SQ + 0.05, h, 3.4), STONE))


def b_altar(P, rng):
    P.stone.add(gm.box((0, 2.0, 0), (4.0, 4.0, 9.0), STONE))
    P.paint.add(gm.box((0, 4.1, 0), (4.4, 0.25, 7.0), sw("altar_cloth")))
    for dz in (-3.0, 0.0, 3.0):
        P.paint.add(gm.cylinder((0, 4.2, dz), 0.35, 0.35, 1.6 + abs(dz) * 0.2, 6, sw("candle")))
        P.paint.add(gm.sphere((0, 6.0 + abs(dz) * 0.2, dz), 0.35, 6, 4, sw("flame")))


def b_pew(P, rng):
    w = 9.0
    P.paint.add(gm.box((0, 2.0, 0), (w, 0.5, 2.2), sw("wood_mid")))
    P.paint.add(gm.box((0, 3.6, -1.0), (w, 3.0, 0.4), sw("wood_mid")))
    for s in (-1, 1):
        P.paint.add(gm.box((s * (w / 2 - 0.3), 2.0, 0), (0.5, 4.0, 2.4), sw("wood_dark")))
    # a broken-off end: a pew that's seen better days
    P.paint.add(gm.box((0, 0, 0), (2.4, 0.5, 2.0), sw("wood_mid")).transformed(roll=0.5, offset=(w / 2 + 1.2, 0.8, 0.4)))


def b_rubble(P, rng):
    for k in range(5):
        r = rng.uniform(0.6, 1.3)
        rocky(P.stone, rng.uniform(-1.6, 1.6), r * 0.3, rng.uniform(-1.6, 1.6), r, 200 + k)


def b_sarcophagus(P, rng):
    P.stone.add(gm.box((0, 1.8, 0), (4.0, 3.6, 9.0), STONE))
    P.stone.add(gm.box((0, 3.9, 0), (4.4, 0.6, 9.4), STONE))
    P.stone.add(gm.sphere((0, 4.5, -3.0), 1.0, 8, 5, STONE, squash=0.5))
    P.stone.add(gm.box((0, 4.4, 0.6), (1.8, 0.6, 5.0), STONE))


def b_gravestone(P, rng):
    P.stone.add(gm.box((0, 2.6, 0), (3.2, 5.2, 0.9), STONE).transformed(roll=rng.uniform(-0.12, 0.12)))
    P.stone.add(gm.cylinder((0, 5.0, 0), 1.6, 1.6, 0.9, 10, STONE).transformed(pitch=math.pi / 2, offset=(0, 0, 0.45)))
    P.paint.add(rect(-1.4, 0.6, 1.4, 4.4, 0.13, "grass_dark"))


def b_open_grave(P, rng):
    P.paint.add(rect(-1.8, -4.0, 1.8, 4.0, 0.10, "chasm"))
    P.paint.add(gm.box((2.6, 0.9, 0), (1.6, 1.8, 7.0), sw("dirt")))
    P.stone.add(gm.box((0, 2.6, -4.6), (3.0, 5.2, 0.9), STONE))


def b_bones(P, rng):
    for k in range(6):
        b = gm.cylinder((0, -0.9, 0), 0.22, 0.22, 1.8, 5, sw("bone"))
        P.paint.add(b.transformed(roll=math.pi / 2, yaw=rng.uniform(0, 3), offset=(rng.uniform(-1.6, 1.6), 0.25, rng.uniform(-1.6, 1.6))))
    P.paint.add(gm.sphere((0.5, 0.6, 0.3), 0.7, 7, 5, sw("bone")))


def b_brazier(P, rng):
    for k in range(3):
        a = k / 3 * 2 * math.pi
        lg = gm.box((0, 0, 0), (0.3, 4.2, 0.3), sw("iron"))
        P.paint.add(lg.transformed(roll=0.25, yaw=a, offset=(math.cos(a) * 0.9, 2.0, math.sin(a) * 0.9)))
    P.paint.add(gm.cylinder((0, 3.6, 0), 1.0, 1.7, 1.2, 10, sw("iron")))
    P.paint.add(gm.cylinder((0, 4.7, 0), 1.4, 1.4, 0.2, 10, sw("ember")))
    P.paint.add(gm.cylinder((0, 4.8, 0), 1.1, 0.0, 2.6, 6, sw("flame"), smooth=False))


def b_web(P, rng):
    """Cobwebs: strands on the floor and a sheet strung between two posts. Rough going."""
    for k in range(8):
        a = rng.uniform(0, math.pi)
        st = gm.box((0, 0, 0), (rng.uniform(4, 8), 0.06, 0.12), sw("web"))
        P.paint.add(st.transformed(yaw=a, offset=(rng.uniform(-1.5, 1.5), 0.08, rng.uniform(-1.5, 1.5))))
    for k in range(6):
        y = 1.0 + k * 1.3
        P.paint.add(gm.box((0, y, -3.0), (rng.uniform(5, 8), 0.1, 0.1), sw("web")).transformed(roll=rng.uniform(-0.3, 0.3)))
    for k in range(5):
        x = -3 + k * 1.5
        P.paint.add(gm.box((x, 4.0, -3.0), (0.1, 7.5, 0.1), sw("web")).transformed(roll=rng.uniform(-0.25, 0.25)))


def b_spider_eggs(P, rng):
    for k in range(5):
        P.paint.add(gm.sphere((rng.uniform(-1.5, 1.5), 0.8, rng.uniform(-1.5, 1.5)), rng.uniform(0.6, 1.0), 7, 5, sw("web")))


def b_stairs_spiral(P, rng):
    P.stone.add(gm.cylinder((0, 0, 0), 1.0, 1.0, 16.0, 8, STONE))
    n = 14
    for k in range(n):
        a = k / 8 * 2 * math.pi
        y = 0.5 + k * 1.1
        st = gm.box((0, 0, 0), (4.0, 0.9, 2.2), STONE)
        P.stone.add(st.transformed(yaw=-a, offset=(math.cos(a) * 2.8, y, math.sin(a) * 2.8)))


def bell_mesh(r, h):
    m = gm.Mesh()
    m.add(gm.cylinder((0, 0, 0), r, r * 0.5, h, 14, sw("bronze"), caps=(False, True)))
    m.add(gm.cylinder((0, 0, 0), r * 0.95, r * 0.47, h * 0.97, 14, sw("bronze_dark"), caps=(False, False), inside=True))
    m.add(gm.cylinder((0, -0.2, 0), r * 1.05, r * 1.0, 0.5, 14, sw("bronze")))
    return m


def b_great_bell(P, rng):
    for sx in (-1, 1):
        for sz in (-1, 1):
            P.paint.add(gm.box((sx * 4.0, 8.0, sz * 3.6), (0.9, 16.0, 0.9), sw("timber")))
        P.paint.add(gm.box((sx * 4.0, 15.6, 0), (0.9, 0.9, 8.0), sw("timber")))
    P.paint.add(gm.box((0, 15.6, 0), (9.0, 1.0, 1.0), sw("timber")))
    P.paint.add(bell_mesh(3.6, 6.0).transformed(offset=(0, 8.6, 0)))
    P.paint.add(gm.sphere((0, 8.6, 0), 0.8, 7, 5, sw("iron")))
    for k in range(4):
        P.paint.add(rect(-3 + k * 1.8, -1.0, -2.0 + k * 1.8, 1.4, 0.24, "frost"))


def b_bell(P, rng):
    for s in (-1, 1):
        P.paint.add(gm.box((s * 2.0, 6.0, 0), (0.6, 12.0, 0.6), sw("timber")))
    P.paint.add(gm.box((0, 11.6, 0), (4.6, 0.7, 0.7), sw("timber")))
    P.paint.add(bell_mesh(1.7, 3.0).transformed(offset=(0, 7.8, 0)))


def b_banner(P, rng):
    P.paint.add(gm.box((0, 6.0, 0), (0.5, 12.0, 0.5), sw("wood_dark")))
    P.paint.add(gm.box((1.8, 11.4, 0), (3.6, 0.3, 0.3), sw("wood_dark")))
    P.paint.add(gm.box((1.8, 8.6, 0.1), (3.2, 5.4, 0.15), sw("banner_red")))
    P.paint.add(gm.sphere((1.8, 9.2, 0.25), 0.9, 6, 4, sw("banner_wolf"), squash=0.3))


def b_mound(P, rng):
    P.paint.add(gm.flatten_below(gm.sphere((0, -2.0, 0), 7.2, 14, 8, sw("grass"), squash=0.6), 0.0))
    P.stone.add(gm.box((0, 2.3, 6.4), (4.4, 4.6, 1.4), STONE))
    P.paint.add(gm.box((0, 1.8, 7.15), (2.6, 3.4, 0.1), sw("chasm")))


def b_frost(P, rng):
    P.paint.add(blob(0, 0, 2.2, 2.0, 0.24, "frost", 211, n=10, jag=0.35))


def b_wall_notes(P, rng):
    room_wall(P, "plain")
    z = -SQ / 2 + 1.6 + 0.35
    for k in range(5):
        x, y = rng.uniform(-1.8, 1.8), rng.uniform(4.0, 9.0)
        P.paint.add(gm.box((x, y, z), (rng.uniform(1.0, 1.6), rng.uniform(1.2, 1.8), 0.06), sw("paper")).transformed(
            roll=rng.uniform(-0.2, 0.2)))
        P.paint.add(gm.sphere((x, y + 0.7, z + 0.05), 0.12, 4, 3, sw("red_cloth")))


def b_vault_door(P, rng):
    h = 12.0
    P.stone.add(gm.box((0, h / 2, -0.4), (2 * SQ + 0.05, h, 3.4), STONE))
    door_m = gm.cylinder((0, 0, 0), 3.6, 3.6, 0.8, 18, sw("iron"))
    P.paint.add(door_m.transformed(pitch=math.pi / 2, offset=(0, 5.0, 1.3)))
    P.paint.add(gm.cylinder((0, 0, 0), 2.6, 2.6, 0.3, 18, sw("metal")).transformed(pitch=math.pi / 2, offset=(0, 5.0, 1.75)))
    for k in range(6):
        a = k / 6 * 2 * math.pi
        sp = gm.box((0, 0, 0), (0.3, 2.2, 0.3), sw("bronze"))
        P.paint.add(sp.transformed(roll=a, offset=(math.sin(a) * 1.1, 5.0 + math.cos(a) * 1.1, 2.0)))
    P.paint.add(gm.sphere((0, 5.0, 2.0), 0.5, 6, 4, sw("bronze")))


def b_flowers(P, rng):
    P.paint.add(blob(0, 0, 2.0, 1.8, 0.13, "grass", 221))
    for k in range(10):
        x, z = rng.uniform(-1.6, 1.6), rng.uniform(-1.4, 1.4)
        P.paint.add(gm.cylinder((x, 0, z), 0.08, 0.08, 1.2, 4, sw("leaf_c")))
        P.paint.add(gm.sphere((x, 1.3, z), 0.35, 5, 3, sw(["white", "awning_yellow", "feather", "purple_cloth"][k % 4])))


def b_tracks(P, rng):
    for k in range(6):
        x = -2.0 + k * 0.8
        z = 0.7 * (1 if k % 2 else -1)
        P.paint.add(blob(x, z, 0.35, 0.3, 0.25, "dirt_dark", 230 + k, n=6, jag=0.1))
        for t in range(3):
            P.paint.add(blob(x + 0.35, z - 0.25 + t * 0.25, 0.1, 0.1, 0.26, "dirt_dark", 240 + k * 3 + t, n=5, jag=0.05))


def b_drum(P, rng):
    P.paint.add(gm.cylinder((0, 0, 0), 1.9, 1.7, 3.0, 12, sw("barrel")))
    P.paint.add(gm.cylinder((0, 3.0, 0), 1.75, 1.75, 0.2, 12, sw("canvas")))
    for k in range(6):
        a = k / 6 * 2 * math.pi
        P.paint.add(gm.box((math.cos(a) * 1.85, 1.5, math.sin(a) * 1.85), (0.15, 3.0, 0.15), sw("rope")).transformed())
    for s in (-1, 1):
        st = gm.cylinder((0, 0, 0), 0.15, 0.15, 2.4, 5, sw("bone"))
        P.paint.add(st.transformed(roll=s * 0.9, offset=(s * 0.6, 3.4, 0.4)))


def door_frame(P):
    """A doorway in a wall line: two stone jambs, a lintel and the wall above, in line with
    stone_wall (z = -0.4), so a door sits flush in a wall the DM drew."""
    h, z, t = 12.0, -0.4, 3.4
    for sx in (-1, 1):
        P.stone.add(gm.box((sx * 2.15, h / 2, z), (0.75, h, t), STONE))
    P.stone.add(gm.box((0, (h + 8.6) / 2, z), (SQ + 0.05, h - 8.6, t), STONE))
    P.paint.add(gm.box((0, 8.45, z), (3.7, 0.3, t + 0.1), sw("timber")))
    # A timber cap on top, so a door in a wall line reads from above even when it's seen edge-on.
    P.paint.add(gm.box((0, h + 0.15, z), (SQ + 0.05, 0.3, t + 0.3), sw("door")))


def door_leaf(state):
    """The door itself, 3.5 wide: planks, two iron bands, a ring; locked adds a hasp and padlock."""
    m = gm.Mesh()
    m.add(gm.box((0, 4.2, 0), (3.5, 8.3, 0.55), sw("door")))
    for y in (2.0, 6.4):
        m.add(gm.box((0, y, 0), (3.55, 0.35, 0.65), sw("iron")))
    for k in range(4):
        m.add(gm.box((-1.3 + k * 0.87, 4.2, 0.3), (0.06, 8.0, 0.05), sw("wood_dark")))
    m.add(gm.sphere((1.2, 4.0, 0.42), 0.22, 5, 3, sw("iron")))
    if state == "locked":
        m.add(gm.box((1.15, 4.6, 0.4), (0.9, 0.3, 0.2), sw("iron")))
        m.add(gm.box((1.15, 4.1, 0.55), (0.55, 0.6, 0.3), sw("bronze")))
    return m


def b_door(P, rng):
    door_frame(P)
    P.paint.add(door_leaf("closed").transformed(offset=(0, 0, -0.4)))


def b_door_locked(P, rng):
    door_frame(P)
    P.paint.add(door_leaf("locked").transformed(offset=(0, 0, -0.4)))


def b_door_open(P, rng):
    """Swung a quarter turn on its hinge (the west jamb), into the square to the south."""
    door_frame(P)
    leaf = door_leaf("open").transformed(offset=(1.75, 0, 0))
    P.paint.add(leaf.transformed(yaw=-math.pi / 2, offset=(-1.75, 0, -0.4)))


def b_ice(P, rng):
    P.paint.add(blob(0, 0, 2.4, 2.3, 0.16, "frost", 233, n=12, jag=0.2))
    P.paint.add(blob(0.3, -0.2, 1.4, 1.2, 0.2, "water_light", 239, n=9, jag=0.3))
    for k in range(3):
        x, z = rng.uniform(-1.5, 1.5), rng.uniform(-1.5, 1.5)
        P.paint.add(gm.box((x, 0.22, z), (rng.uniform(0.8, 1.6), 0.04, 0.08), sw("white")).transformed(yaw=rng.uniform(0, 3)))


def b_torch_post(P, rng):
    P.paint.add(gm.cylinder((0, 0, 0), 0.7, 0.5, 0.6, 8, sw("iron")))
    P.paint.add(gm.cylinder((0, 0.6, 0), 0.22, 0.2, 6.4, 6, sw("wood_dark")))
    P.paint.add(gm.cylinder((0, 6.8, 0), 0.5, 0.65, 0.9, 8, sw("iron")))
    P.paint.add(gm.cylinder((0, 7.7, 0), 0.55, 0.0, 1.8, 6, sw("flame"), smooth=False))


def b_water_strip(P, rng):
    w, d = 20 * SQ, 4 * SQ
    P.paint.add(rect(-w / 2, -d / 2, w / 2, d / 2 - 0.6, 0.16, "water_deep"))
    for k in range(18):
        P.paint.add(blob(rng.uniform(-w / 2, w / 2), rng.uniform(-d / 2 + 1, d / 2 - 2), rng.uniform(1.5, 4), rng.uniform(0.3, 0.8),
                         0.18, "water", 250 + k, n=8))
    x = -w / 2 + 1
    while x < w / 2:
        P.stone.add(gm.box((x + 1.2, 0.6, d / 2 - 0.3), (2.6, 1.2, 1.4), STONE))
        x += 2.7


def b_pier(P, rng):
    w, d = 3 * SQ - 1.0, 4 * SQ + 1.0
    n = int(d / 1.3)
    for k in range(n):
        z = -d / 2 + 0.65 + k * 1.3
        P.paint.add(gm.box((0, 0.9, z), (w, 0.35, 1.05), sw("wood_mid" if k % 3 else "wood_light")))
    for sx in (-1, 1):
        for z in (-d / 2 + 1, 0, d / 2 - 1):
            P.paint.add(gm.cylinder((sx * (w / 2 - 0.4), 0, z), 0.45, 0.45, 2.4, 6, sw("wood_dark")))


# --- the museum (The Museum of Nightmares, v2) -------------------------------------------------
# Its marble halls, its garden and its exhibits. Walls hang on room_wall (plaster, timber trim),
# so a painting or a tapestry slots into a line of wall_room.

def limb(p0, p1, r0, r1, uvf, seg=6):
    """A tapered rod from p0 to p1: an arm, a leg, a neck, a horn."""
    p0, p1 = np.asarray(p0, float), np.asarray(p1, float)
    d = p1 - p0
    L = float(np.linalg.norm(d))
    d = d / L
    s = math.hypot(d[0], d[2])
    roll = math.atan2(s, d[1])
    yaw = math.atan2(d[2], -d[0]) if s > 1e-9 else 0.0
    return gm.cylinder((0, 0, 0), r0, r1, L, seg, uvf).transformed(yaw=yaw, roll=roll, offset=p0)


def disc(x, y, z, r, color, seg=10, t=0.06):
    """A flat round thing standing up and facing south (+z): a face on a tapestry, a clock."""
    return gm.cylinder((0, 0, 0), r, r, t, seg, sw(color)).transformed(pitch=math.pi / 2, offset=(x, y, z))


WALL_FACE = -SQ / 2 + 1.6 + 0.2       # where room_wall's south face is (z)


def b_floor_marble(P, rng):
    """The museum's polished floor: pale tiles, every other one a shade lighter, faint veins, and the
    grid as fine grout lines."""
    W, H = 20 * SQ, 13 * SQ
    P.paint.add(rect(-W / 2, -H / 2, W / 2, H / 2, 0.04, "marble"))
    for gy in range(13):
        for gx in range(20):
            if (gx + gy) % 2 == 0:
                x0, z0 = -W / 2 + gx * SQ, -H / 2 + gy * SQ
                P.paint.add(rect(x0, z0, x0 + SQ, z0 + SQ, 0.05, "white"))
    for k in range(46):
        x, z = rng.uniform(-W / 2 + 2, W / 2 - 2), rng.uniform(-H / 2 + 2, H / 2 - 2)
        a = rng.uniform(0, math.pi)
        for seg in range(2):
            ln = rng.uniform(1.2, 3.0)
            v = gm.plane_xz(ln / 2, 0.06, 0, ln, 0.09, sw("marble_vein"))
            P.paint.add(v.transformed(yaw=a, offset=(x, 0, z)))
            x, z = x + math.cos(a) * ln, z - math.sin(a) * ln
            a += rng.uniform(-0.6, 0.6)
    grid_lines(P, "marble_vein", w=0.16)


def b_paving(P, rng):
    """A garden path's square: two pale slabs set flush, a crack, a tuft of moss in the joint."""
    P.paint.add(gm.box((0, 0.1, -0.95), (4.7, 0.2, 2.75), sw("pale_stone")))
    P.paint.add(gm.box((-0.6, 0.1, 1.45), (3.5, 0.2, 1.8), sw("pale_stone")))
    P.paint.add(gm.box((1.75, 0.1, 1.45), (1.2, 0.2, 1.8), sw("pale_stone")))
    P.paint.add(rect(-1.4, -1.2, 0.6, -1.12, 0.21, "stone_light").transformed(yaw=0.4))
    P.paint.add(blob(1.15, 0.45, 0.6, 0.2, 0.15, "moss", 271, n=7))


def b_wall_diag(P, rng):
    """A wall across the square from corner to corner (an octagonal room's cut corners). Unturned it
    runs from the south-west corner to the north-east one and faces south-east: the room's
    north-west corner. Each quarter turn moves it on round the room: r 1 the north-east corner,
    r 2 the south-east, r 3 the south-west. A post at each end meets the wall_room along the edge."""
    h, t = 11.0, 1.6
    L = 2 * (SQ / 2 * math.sqrt(2) - t / 2)      # its ends' corners stay in the square
    wall = gm.Mesh()
    wall.add(gm.box((0, h / 2, 0), (L, h, t), sw("plaster")))
    wall.add(gm.box((0, 0.5, t / 2 + 0.05), (L - 1.2, 1.0, 0.2), sw("timber")))
    wall.add(gm.box((0, h - 0.4, t / 2 + 0.05), (L - 1.2, 0.8, 0.2), sw("timber")))
    P.paint.add(wall.transformed(yaw=math.pi / 4))
    for s in (-1, 1):
        c = s * (SQ / 2 - 0.9)
        P.paint.add(gm.box((c, h / 2, -c), (1.8, h, 1.8), sw("plaster")))


def picture_wall(P):
    """A plain stretch of room wall; returns the z of its south face."""
    room_wall(P, "plain")
    return WALL_FACE


def b_wall_painting(P, rng):
    """A stretch of wall with a framed landscape on it: hills, a sky, a sun, a far tower."""
    z = picture_wall(P)
    y = 6.4
    P.paint.add(gm.box((0, y, z + 0.15), (4.1, 3.3, 0.3), sw("gold")))
    P.paint.add(gm.box((0, y, z + 0.32), (3.4, 2.6, 0.06), sw("water_light")))
    P.paint.add(gm.box((0, y - 0.75, z + 0.36), (3.4, 1.1, 0.06), sw("leaf_c")))
    for (x, ww, hh, a, c) in [(-0.9, 2.0, 0.9, 0.25, "grass_dark"), (0.9, 2.2, 0.8, -0.2, "leaf_a")]:
        P.paint.add(gm.box((0, 0, 0), (ww, hh, 0.06), sw(c)).transformed(roll=a, offset=(x, y - 0.55, z + 0.4)))
    P.paint.add(disc(1.05, y + 0.65, z + 0.4, 0.38, "flame", seg=8))
    P.paint.add(gm.box((-0.7, y + 0.05, z + 0.44), (0.35, 1.0, 0.06), sw("stone_dark")))
    P.paint.add(gm.box((-0.7, y + 0.6, z + 0.44), (0.5, 0.2, 0.06), sw("roof_red")))
    # a little brass label under it
    P.paint.add(gm.box((0, y - 2.2, z + 0.1), (1.2, 0.4, 0.2), sw("bronze")))


def b_wall_portrait(P, rng):
    """A stretch of wall with a tall, dark portrait of a knight in black armour, red plume and all."""
    z = picture_wall(P)
    y = 6.1
    P.paint.add(gm.box((0, y, z + 0.15), (3.2, 5.6, 0.3), sw("wood_dark")))
    P.paint.add(gm.box((0, y, z + 0.32), (2.8, 5.2, 0.06), sw("gold")))
    P.paint.add(gm.box((0, y, z + 0.36), (2.4, 4.8, 0.06), sw("ink")))
    # the knight: shoulders and breastplate, the helm with its visor slit, a plume, a sword hilt
    P.paint.add(gm.box((0, y - 1.4, z + 0.42), (1.9, 2.0, 0.08), sw("iron")))
    P.paint.add(gm.box((0, y - 0.9, z + 0.48), (1.1, 1.0, 0.06), sw("metal")))
    P.paint.add(gm.box((0, y + 0.45, z + 0.42), (0.95, 1.2, 0.08), sw("iron")))
    P.paint.add(gm.box((0, y + 0.5, z + 0.5), (0.7, 0.14, 0.04), sw("ember")))
    P.paint.add(gm.box((0, 0, 0), (0.35, 0.75, 0.08), sw("banner_red")).transformed(roll=-0.3, offset=(0.15, y + 1.35, z + 0.42)))
    P.paint.add(gm.box((0.65, y - 1.25, z + 0.52), (0.14, 1.3, 0.05), sw("gold")))
    P.paint.add(gm.box((0.65, y - 0.75, z + 0.54), (0.6, 0.12, 0.05), sw("gold")))
    P.paint.add(gm.box((0, y - 3.2, z + 0.1), (1.2, 0.4, 0.2), sw("bronze")))


def b_tapestry(P, rng):
    """A stretch of wall hung with a tapestry: three sisters with snakes for hair, gold border, tassels."""
    z = picture_wall(P)
    P.paint.add(gm.box((0, 10.0, z + 0.4), (4.3, 0.3, 0.3), sw("iron")))
    for s in (-1, 1):
        P.paint.add(gm.sphere((s * 2.15, 10.0, z + 0.4), 0.3, 6, 4, sw("gold")))
    top, bot = 9.8, 3.0
    P.paint.add(gm.box((0, (top + bot) / 2, z + 0.3), (4.0, top - bot, 0.15), sw("rug_c")))
    for y in (top - 0.25, bot + 0.25):
        P.paint.add(gm.box((0, y, z + 0.4), (4.0, 0.22, 0.06), sw("gold")))
    for x in (-1.85, 1.85):
        P.paint.add(gm.box((x, (top + bot) / 2, z + 0.4), (0.22, top - bot, 0.06), sw("gold")))
    # the three sisters: robes, faces, hair of snakes
    for i, (x, robe) in enumerate([(-1.15, "awning_yellow"), (0.0, "red_cloth"), (1.15, "purple_cloth")]):
        lift = 0.35 if i == 1 else 0.0
        P.paint.add(gm.box((x, 5.4 + lift, z + 0.42), (0.9, 2.6, 0.06), sw(robe)))
        P.paint.add(gm.box((x, 4.2 + lift, z + 0.42), (1.1, 0.5, 0.06), sw(robe)))
        P.paint.add(disc(x, 7.15 + lift, z + 0.44, 0.38, "sand", seg=8))
        for k in range(5):
            a = math.pi * (0.1 + 0.8 * k / 4)
            r0 = (x + math.cos(a) * 0.3, 7.15 + lift + math.sin(a) * 0.3, z + 0.48)
            r1 = (x + math.cos(a) * 0.85, 7.15 + lift + math.sin(a) * 0.75, z + 0.48)
            P.paint.add(limb(r0, r1, 0.09, 0.05, sw("leaf_c" if k % 2 else "green_cloth"), seg=4))
    for k in range(7):
        P.paint.add(gm.cylinder((-1.8 + k * 0.6, bot - 0.6, z + 0.35), 0.1, 0.16, 0.6, 4, sw("gold")))


def b_display_case(P, rng):
    """A glass case on a dark wooden plinth, a crown on a red cushion inside. (The glass is tinted
    panes at the back and sides and a brass frame, so the crown still shows from the table.)"""
    P.paint.add(gm.box((0, 1.6, 0), (3.8, 3.2, 3.8), sw("wood_dark")))
    P.paint.add(gm.box((0, 3.3, 0), (4.1, 0.25, 4.1), sw("gold")))
    y0, y1, a = 3.45, 7.2, 1.8
    for sx in (-1, 1):
        for sz in (-1, 1):
            P.paint.add(gm.box((sx * a, (y0 + y1) / 2, sz * a), (0.22, y1 - y0, 0.22), sw("gold")))
    for sz in (-1, 1):
        P.paint.add(gm.box((0, y1, sz * a), (2 * a + 0.22, 0.22, 0.22), sw("gold")))
    for sx in (-1, 1):
        P.paint.add(gm.box((sx * a, y1, 0), (0.22, 0.22, 2 * a), sw("gold")))
    P.paint.add(gm.box((0, (y0 + y1) / 2, -a), (2 * a, y1 - y0, 0.08), sw("glass")))
    for sx in (-1, 1):
        P.paint.add(gm.box((sx * a, (y0 + y1) / 2, 0), (0.08, y1 - y0, 2 * a), sw("glass")))
        glint = gm.box((0, 0, 0), (0.04, 2.4, 0.18), sw("white")).transformed(pitch=0.6)
        P.paint.add(glint.transformed(offset=(sx * (a + 0.06), 5.4, 0.4)))
    P.paint.add(gm.box((0, 3.75, 0), (2.0, 0.6, 2.0), sw("red_cloth")))
    P.paint.add(gm.cylinder((0, 4.05, 0), 0.75, 0.85, 0.7, 10, sw("gold")))
    for k in range(5):
        an = k / 5 * 2 * math.pi
        P.paint.add(gm.cylinder((math.cos(an) * 0.78, 4.75, math.sin(an) * 0.78), 0.2, 0.0, 0.55, 4, sw("gold")))
    P.paint.add(gm.sphere((0, 4.45, 0.82), 0.16, 5, 3, sw("feather")))


def b_plinth(P, rng):
    """A marble pedestal with a bronze bust on it."""
    P.paint.add(gm.box((0, 0.4, 0), (3.6, 0.8, 3.6), sw("marble")))
    P.paint.add(gm.box((0, 2.6, 0), (2.6, 3.6, 2.6), sw("marble")))
    P.paint.add(gm.box((0, 4.7, 0), (3.4, 0.6, 3.4), sw("marble")))
    P.paint.add(gm.box((0, 3.0, 1.32), (1.4, 0.5, 0.06), sw("bronze")))
    P.paint.add(gm.box((0, 5.35, 0), (1.6, 0.7, 1.2), sw("stone_dark")))
    P.paint.add(gm.sphere((0, 6.3, 0), 1.2, 9, 5, sw("bronze"), squash=0.45))
    P.paint.add(gm.cylinder((0, 6.3, 0), 0.38, 0.35, 0.8, 7, sw("bronze")))
    P.paint.add(gm.sphere((0, 7.6, 0.05), 0.72, 8, 6, sw("bronze"), squash=1.15))
    P.paint.add(gm.box((0, 7.5, 0.72), (0.2, 0.35, 0.25), sw("bronze_dark")))


def b_hedge(P, rng):
    """A clipped hedge block, square-cut, so a row of them reads as one hedge."""
    h = 6.0
    P.paint.add(gm.box((0, h / 2, 0), (SQ - 0.1, h, SQ - 0.4), sw("leaf_d")))
    P.paint.add(gm.box((0, h + 0.15, 0), (SQ - 0.4, 0.3, SQ - 0.7), sw("leaf_b")))
    # a few leafy tufts on the faces the table sees, so it isn't a green box
    for k in range(8):
        x = rng.uniform(-1.9, 1.9)
        if k % 2:
            c, size = (x, h + 0.25, rng.uniform(-1.6, 1.6)), (rng.uniform(0.8, 1.4), 0.25, rng.uniform(0.8, 1.4))
        else:
            c, size = (x, rng.uniform(1.2, h - 1.0), (SQ - 0.4) / 2 + 0.1), (rng.uniform(0.7, 1.2), rng.uniform(0.5, 0.8), 0.25)
        P.paint.add(gm.box(c, size, sw(["leaf_b", "leaf_a"][k % 4 // 2])))


def b_topiary(P, rng):
    """A bush clipped into a beast on a low hedge plinth: a bull-ish thing with horns, its head to
    the east (so the table sees it side on)."""
    P.paint.add(gm.box((0, 0.5, 0), (4.2, 1.0, 3.4), sw("leaf_d")))
    for x in (-1.2, 1.2):
        for z in (-0.8, 0.8):
            P.paint.add(gm.cylinder((x, 0.9, z), 0.5, 0.45, 1.5, 6, sw("leaf_b")))
    P.paint.add(gm.sphere((-0.6, 3.3, 0), 1.6, 9, 6, sw("leaf_b"), squash=0.85))
    P.paint.add(gm.sphere((0.8, 3.5, 0), 1.5, 9, 6, sw("leaf_a"), squash=0.9))
    P.paint.add(gm.sphere((1.55, 4.4, 0.1), 0.9, 8, 5, sw("leaf_b")))
    P.paint.add(limb((1.9, 4.2, 0.1), (2.3, 3.95, 0.15), 0.55, 0.4, sw("leaf_c"), seg=7))
    for s in (-1, 1):
        P.paint.add(limb((1.75, 5.0, s * 0.55), (2.1, 6.0, s * 1.1), 0.25, 0.05, sw("leaf_c"), seg=5))
    P.paint.add(gm.sphere((-2.0, 3.9, 0), 0.5, 6, 4, sw("leaf_a")))


def b_garden_steps(P, rng):
    """Wide, shallow stone steps up to a raised terrace. The low end faces the DM (south); the
    terrace is the northern square. Low walls with an urn at the top flank them."""
    w, d = 2 * SQ, 3 * SQ
    n, rise, tread = 4, 0.55, 2.4
    terrace = d - n * tread
    for i in range(n):
        z1 = d / 2 - i * tread
        h = (i + 1) * rise
        P.paint.add(gm.box((0, h / 2, z1 - tread / 2), (w - 1.6, h, tread), sw("pale_stone")))
        P.paint.add(gm.box((0, h + 0.01, z1 - 0.2), (w - 1.6, 0.04, 0.4), sw("marble")))
    top = (n + 1) * rise
    P.paint.add(gm.box((0, top / 2, -d / 2 + terrace / 2), (w - 0.2, top, terrace), sw("pale_stone")))
    P.paint.add(blob(1.5, -d / 2 + 2.0, 1.2, 0.8, top + 0.02, "moss", 281, n=7))
    for s in (-1, 1):
        x = s * (w / 2 - 0.45)
        for i in range(n):
            z1 = d / 2 - i * tread
            hh = (i + 1) * rise + 0.9
            P.paint.add(gm.box((x, hh / 2, z1 - tread / 2), (0.8, hh, tread), sw("stone_light")))
        P.paint.add(gm.box((x, (top + 0.9) / 2, -d / 2 + terrace / 2), (0.8, top + 0.9, terrace), sw("stone_light")))
        uz, ux = -d / 2 + terrace - 0.6, s * (w / 2 - 0.6)
        P.paint.add(gm.cylinder((ux, top + 0.9, uz), 0.4, 0.6, 0.9, 8, sw("pale_stone")))
        P.paint.add(gm.cylinder((ux, top + 1.8, uz), 0.6, 0.45, 0.5, 8, sw("pale_stone")))
        P.paint.add(gm.sphere((ux, top + 2.45, uz), 0.5, 7, 4, sw("leaf_b")))


def b_stairs_straight(P, rng):
    """An indoor staircase going up to the north: polished steps, a red runner, banisters with newel
    posts at the bottom (south, toward the DM) and a landing at the top."""
    w, d = 2 * SQ, 3 * SQ
    n, rise, tread = 6, 0.5, 2.0
    landing = d - n * tread
    sw_ = w - 2.0
    for i in range(n):
        z1 = d / 2 - i * tread
        h = (i + 1) * rise
        P.paint.add(gm.box((0, h / 2, z1 - tread / 2), (sw_, h, tread), sw("wood_mid")))
        P.paint.add(gm.box((0, h + 0.03, z1 - tread / 2), (3.2, 0.06, tread + 0.02), sw("red_cloth")))
        P.paint.add(gm.box((0, h - rise / 2, z1 + 0.03), (3.2, rise, 0.06), sw("red_cloth")))
    top = (n + 1) * rise
    P.paint.add(gm.box((0, top / 2, -d / 2 + landing / 2), (sw_, top, landing), sw("wood_mid")))
    P.paint.add(gm.box((0, top + 0.03, -d / 2 + landing / 2), (3.2, 0.06, landing), sw("red_cloth")))
    rail = 3.2                        # the handrail's height over the steps
    z_lo, z_hi = d / 2 - 0.6, -d / 2 + landing
    y_lo, y_hi = 4.8, top + rail

    def rail_y(z):
        return y_lo + (y_hi - y_lo) * (z_lo - z) / (z_lo - z_hi)
    for s in (-1, 1):
        x = s * (w / 2 - 0.5)
        # the stringer stepping up the side, the balusters on it, the handrail on them
        for i in range(n):
            z1 = d / 2 - i * tread
            hh = (i + 1) * rise + 0.4
            P.paint.add(gm.box((x, hh / 2, z1 - tread / 2), (1.0, hh, tread), sw("wood_dark")))
            zb = z1 - tread / 2
            if zb < z_lo - 0.5:
                P.paint.add(gm.box((x, (hh + rail_y(zb)) / 2, zb), (0.25, rail_y(zb) - hh, 0.25), sw("wood_light")))
        P.paint.add(gm.box((x, (top + 0.4) / 2, -d / 2 + landing / 2), (1.0, top + 0.4, landing), sw("wood_dark")))
        P.paint.add(limb((x, y_lo, z_lo), (x, y_hi, z_hi), 0.3, 0.3, sw("wood_dark"), seg=4))
        P.paint.add(gm.box((x, y_hi, -d / 2 + landing / 2 + 0.1), (0.6, 0.6, landing + 0.2), sw("wood_dark")))
        P.paint.add(gm.box((x, (top + 0.4 + y_hi) / 2, -d / 2 + 0.6), (0.25, y_hi - top - 0.4, 0.25), sw("wood_light")))
        P.paint.add(gm.box((x, 2.4, d / 2 - 0.6), (0.8, 4.8, 0.8), sw("wood_dark")))
        P.paint.add(gm.sphere((x, 5.0, d / 2 - 0.6), 0.5, 7, 4, sw("gold")))


def b_donation_box(P, rng):
    """An ornate gilded box on a stand, a slot in its lid. (The book's box holds every coin there is.)"""
    P.paint.add(gm.box((0, 0.3, 0), (2.8, 0.6, 2.8), sw("wood_dark")))
    P.paint.add(gm.cylinder((0, 0.6, 0), 0.75, 0.6, 3.4, 8, sw("wood_dark")))
    P.paint.add(gm.box((0, 4.1, 0), (3.0, 0.3, 2.6), sw("gold")))
    P.paint.add(gm.box((0, 5.1, 0), (2.6, 1.7, 2.1), sw("gold")))
    P.paint.add(gm.box((0, 5.1, 1.07), (1.9, 1.1, 0.06), sw("velvet")))
    P.paint.add(gm.sphere((0, 5.1, 1.12), 0.28, 6, 4, sw("coin")))
    lid = gm.cylinder((0, -1.3, 0), 1.05, 1.05, 2.6, 10, sw("gold"))
    P.paint.add(lid.transformed(roll=math.pi / 2, offset=(0, 5.95, 0)))
    P.paint.add(gm.box((0, 7.02, 0), (1.2, 0.06, 0.25), sw("char")))
    for sx in (-1, 1):
        for sz in (-1, 1):
            P.paint.add(gm.sphere((sx * 1.3, 4.3, sz * 1.05), 0.22, 5, 3, sw("coin")))
            P.paint.add(gm.sphere((sx * 1.15, 6.15, sz * 0.9), 0.24, 5, 3, sw("coin")))


def b_canopic_jars(P, rng):
    """A low table of four old jars, each lid a head: a person, a jackal, a baboon, a falcon."""
    top = 2.5
    P.paint.add(gm.box((0, top, 0), (4.4, 0.35, 3.0), sw("wood_dark")))
    for sx in (-1, 1):
        for sz in (-1, 1):
            P.paint.add(gm.box((sx * 1.9, top / 2, sz * 1.2), (0.4, top, 0.4), sw("wood_dark")))
    jars = [(-1.55, 0.35, "bone", "sand", "person"), (-0.5, -0.4, "pale_stone", "char", "jackal"),
            (0.55, 0.4, "sand", "bone_dark", "baboon"), (1.6, -0.3, "bone", "bronze", "falcon")]
    for (x, z, body, head, what) in jars:
        y = top + 0.18
        P.paint.add(gm.cylinder((x, y, z), 0.38, 0.55, 0.8, 8, sw(body)))
        P.paint.add(gm.cylinder((x, y + 0.8, z), 0.55, 0.32, 0.7, 8, sw(body)))
        P.paint.add(gm.cylinder((x, y + 1.5, z), 0.34, 0.34, 0.12, 8, sw("gold")))
        hy = y + 1.95
        P.paint.add(gm.sphere((x, hy, z), 0.4, 7, 5, sw(head)))
        if what == "jackal":
            P.paint.add(limb((x, hy - 0.05, z + 0.2), (x, hy - 0.15, z + 0.75), 0.2, 0.1, sw(head), seg=5))
            for s in (-1, 1):
                P.paint.add(gm.cylinder((x + s * 0.2, hy + 0.2, z - 0.05), 0.14, 0.0, 0.6, 4, sw(head)))
        elif what == "falcon":
            P.paint.add(limb((x, hy, z + 0.3), (x, hy - 0.25, z + 0.65), 0.14, 0.02, sw("gold"), seg=4))
        elif what == "baboon":
            P.paint.add(gm.sphere((x, hy - 0.1, z + 0.35), 0.22, 6, 4, sw("bone")))
        else:
            P.paint.add(gm.box((x, hy + 0.05, z - 0.05), (0.9, 0.5, 0.7), sw("awning_blue")))


def b_stone_tablet(P, rng):
    """A cracked stone tablet held upright in a wooden frame on a stand: rows of carved signs, its
    top corner broken off and lying at its foot."""
    P.paint.add(gm.box((0, 0.35, -0.1), (4.6, 0.7, 2.2), sw("wood_dark")))
    tab = gm.Mesh()
    tab.add(gm.box((-0.45, 2.6, 0), (3.1, 4.4, 0.6), sw("stone_light")))
    tab.add(gm.box((1.55, 2.15, 0), (0.9, 3.5, 0.6), sw("stone_light")))
    tab.add(gm.box((0, 0, 0), (1.3, 1.0, 0.6), sw("stone_light")).transformed(roll=0.6, offset=(1.1, 3.95, 0)))
    for row in range(6):
        y = 4.2 - row * 0.55
        x = -1.65
        while x < (1.6 if row > 1 else 0.7):
            gw = rng.uniform(0.2, 0.45)
            tab.add(gm.box((x + gw / 2, y, 0.31), (gw, 0.26, 0.04), sw("stone_dark")))
            x += gw + rng.uniform(0.08, 0.25)
    for (a, b) in [((-0.3, 4.8), (0.1, 3.7)), ((0.1, 3.7), (-0.35, 2.5)), ((-0.35, 2.5), (0.05, 1.1))]:
        tab.add(limb((a[0], a[1], 0.33), (b[0], b[1], 0.33), 0.08, 0.06, sw("char"), seg=4))
    P.paint.add(tab.transformed(pitch=-0.1, offset=(0, 0.7, 0)))
    # the frame: a post either side with a clamp, a crossbar behind
    for sx in (-1, 1):
        P.paint.add(gm.box((sx * 2.2, 3.0, -0.2), (0.45, 4.6, 0.6), sw("wood_mid")))
        P.paint.add(gm.box((sx * 2.0, 3.2, 0.12), (0.5, 0.35, 0.9), sw("bronze")))
    P.paint.add(gm.box((0, 1.0, -0.5), (4.4, 0.4, 0.4), sw("wood_mid")))
    P.paint.add(gm.box((0, 0, 0), (1.0, 0.45, 0.8), sw("stone_light")).transformed(yaw=0.5, roll=0.3, offset=(1.5, 0.95, 0.75)))


def b_ritual_basin(P, rng):
    """A stone basin full of still water on a thick stem, gold signs around its bowl."""
    P.stone.add(gm.cylinder((0, 0, 0), 1.7, 1.3, 0.9, 10, STONE))
    P.stone.add(gm.cylinder((0, 0.9, 0), 0.9, 0.8, 2.0, 10, STONE))
    P.stone.add(gm.cylinder((0, 2.9, 0), 1.2, 2.3, 1.3, 12, STONE))
    P.stone.add(gm.cylinder((0, 4.2, 0), 2.35, 2.35, 0.35, 14, STONE))
    P.paint.add(gm.cylinder((0, 4.55, 0), 1.95, 1.95, 0.04, 14, sw("water")))
    P.paint.add(blob(-0.4, 0.3, 0.9, 0.6, 4.6, "water_light", 291, n=8))
    for k in range(6):
        a = k / 6 * 2 * math.pi + 0.3
        P.paint.add(gm.box((0, 0, 0), (0.12, 0.5, 0.5), sw("gold")).transformed(yaw=-a, offset=(math.cos(a) * 1.85, 3.6, math.sin(a) * 1.85)))


def diorama_platform(P, w, d, h, top):
    """An exhibit's raised platform: dark wood, a brass plaque in front, the scene's ground on top."""
    P.paint.add(gm.box((0, h / 2, 0), (w, h, d), sw("wood_dark"), skip=("+y",)))
    for sz in (-1, 1):
        P.paint.add(gm.box((0, h - 0.45, sz * d / 2), (w + 0.3, 0.3, 0.3), sw("wood_mid")))
    for sx in (-1, 1):
        P.paint.add(gm.box((sx * w / 2, h - 0.45, 0), (0.3, 0.3, d), sw("wood_mid")))
    P.paint.add(gm.box((0, h * 0.4, d / 2 + 0.05), (2.4, 0.7, 0.1), sw("gold")))
    P.paint.add(rect(-w / 2, -d / 2, w / 2, d / 2, h, top))


def b_diorama_cave(P, rng):
    """A raised platform with a little cave scene: rocks round a dark mouth, a fire, three tiny
    cave folk and a bear at the back."""
    w, d, h = 3 * SQ - 0.6, 2 * SQ - 0.6, 2.2
    diorama_platform(P, w, d, h, "dirt")
    for (x, y, z, r, s, sq) in [(-3.6, 1.1, -2.4, 2.1, 301, 1.0), (3.4, 1.0, -2.4, 2.1, 303, 1.0), (-0.1, 3.4, -2.7, 2.0, 302, 0.55),
                                (5.8, 0.7, -2.2, 1.4, 304, 0.9), (-6.0, 0.6, -2.6, 1.3, 305, 0.9)]:
        P.stone.add(gm.flatten_below(gm.rock((x, h + y, z), r, s, STONE, squash=sq), h))
    P.paint.add(gm.box((-0.1, h + 1.35, -2.6), (3.0, 2.7, 1.6), sw("chasm")))
    P.paint.add(gm.cylinder((0.6, h, 1.2), 0.65, 0.5, 0.2, 8, sw("ember")))
    P.paint.add(gm.cylinder((0.6, h + 0.2, 1.2), 0.45, 0.0, 1.0, 5, sw("flame"), smooth=False))
    for (x, z, c) in [(-1.4, 1.6, "sand"), (2.2, 1.9, "bone_dark"), (-0.4, 2.6, "sand_dark")]:
        P.paint.add(gm.cylinder((x, h, z), 0.32, 0.22, 1.1, 6, sw("hay" if c == "sand" else "dirt_dark")))
        P.paint.add(gm.sphere((x, h + 1.4, z), 0.3, 6, 4, sw(c)))
    P.paint.add(gm.sphere((-4.6, h + 0.9, 0.8), 1.0, 8, 5, sw("dirt_dark"), squash=0.8))
    P.paint.add(gm.sphere((-3.6, h + 1.3, 0.9), 0.55, 7, 4, sw("dirt_dark")))
    for k in range(5):
        x, z = rng.uniform(-6, 6), rng.uniform(0.5, 3.8)
        P.paint.add(gm.cylinder((x, h, z), 0.25, 0.0, 0.8, 4, sw("leaf_c"), smooth=False))


def b_diorama_kitchen(P, rng):
    """A raised platform with a little kitchen behind glass-bright polish: cupboards with brass
    knobs along the back, a black stove and its pipe, a table, plates on a shelf."""
    w, d, h = 3 * SQ - 0.6, 2 * SQ - 0.6, 2.2
    diorama_platform(P, w, d, h, "wood_light")
    P.paint.add(gm.box((0, h + 2.8, -d / 2 + 0.6), (w - 0.8, 5.6, 0.4), sw("plaster")))
    P.paint.add(gm.box((-w / 2 + 0.6, h + 2.8, -0.6), (0.4, 5.6, d - 2.0), sw("plaster")))
    for k in range(3):
        x = -5.0 + k * 2.3
        P.paint.add(gm.box((x, h + 1.4, -d / 2 + 1.5), (2.1, 2.8, 1.4), sw("wood_light")))
        P.paint.add(gm.box((x, h + 2.85, -d / 2 + 1.5), (2.3, 0.15, 1.6), sw("wood_dark")))
        for s in (-1, 1):
            P.paint.add(gm.box((x + s * 0.5, h + 1.4, -d / 2 + 2.26), (0.85, 2.4, 0.12), sw("wood_mid")))
            P.paint.add(gm.sphere((x + s * 0.12, h + 1.5, -d / 2 + 2.36), 0.12, 4, 3, sw("gold")))
    P.paint.add(gm.box((-2.7, h + 4.4, -d / 2 + 1.1), (6.6, 0.15, 0.7), sw("wood_dark")))
    for k in range(5):
        P.paint.add(disc(-5.4 + k * 1.2, h + 4.95, -d / 2 + 1.1, 0.45, "white", seg=8))
    sx = 3.8
    P.paint.add(gm.box((sx, h + 1.2, -d / 2 + 1.6), (2.8, 2.4, 1.8), sw("iron")))
    P.paint.add(gm.box((sx, h + 2.45, -d / 2 + 1.6), (3.0, 0.1, 2.0), sw("char")))
    P.paint.add(gm.box((sx, h + 0.8, -d / 2 + 2.52), (1.2, 0.8, 0.06), sw("ember")))
    P.paint.add(gm.cylinder((sx - 0.6, h + 2.5, -d / 2 + 1.6), 0.5, 0.5, 0.6, 8, sw("metal")))
    P.paint.add(gm.cylinder((sx + 0.7, h + 2.5, -d / 2 + 1.4), 0.45, 0.35, 0.8, 8, sw("bronze")))
    P.paint.add(gm.cylinder((sx + 0.9, h + 2.5, -d / 2 + 1.0), 0.25, 0.25, 3.2, 6, sw("iron")))
    P.paint.add(gm.box((-0.6, h + 1.3, 1.6), (2.4, 0.2, 1.6), sw("wood_mid")))
    for x in (-1.6, 0.4):
        P.paint.add(gm.box((x, h + 0.6, 1.6), (0.25, 1.2, 1.2), sw("wood_dark")))
    P.paint.add(gm.cylinder((-0.9, h + 1.4, 1.5), 0.3, 0.25, 0.5, 6, sw("mug_red")))
    P.paint.add(gm.box((1.6, h + 0.6, 2.4), (0.9, 1.2, 0.9), sw("wood_mid")))


def b_model_city(P, rng):
    """A low platform with a tiny city on it: streets, a park, houses, three towers, and a tram line
    running round it with its tram."""
    w, d, h = 4 * SQ - 0.6, 2 * SQ - 0.6, 1.6
    diorama_platform(P, w, d, h, "stone_light")
    P.paint.add(rect(3.0, -1.0, 6.4, 2.2, h + 0.05, "grass"))
    # the tram line: a loop of brass rail, the tram on its south side
    rx, rz = w / 2 - 1.0, d / 2 - 1.0
    for z in (-rz, rz):
        P.paint.add(gm.box((0, h + 0.1, z), (2 * rx, 0.15, 0.3), sw("bronze")))
    for x in (-rx, rx):
        P.paint.add(gm.box((x, h + 0.1, 0), (0.3, 0.15, 2 * rz), sw("bronze")))
    P.paint.add(gm.box((-3.0, h + 0.65, rz), (2.2, 0.9, 0.8), sw("awning_red")))
    P.paint.add(gm.box((-3.0, h + 0.8, rz + 0.42), (1.8, 0.3, 0.04), sw("window")))
    P.paint.add(gm.box((-3.0, h + 1.15, rz), (2.3, 0.12, 0.85), sw("gold")))
    blocks = [(-7.4, -2.6, 1.6, 2.0, 1.6), (-5.4, -2.7, 1.4, 1.4, 1.4), (-7.2, -0.1, 1.5, 1.2, 1.8), (-5.2, 0.2, 1.8, 1.8, 1.4),
              (-2.0, -2.8, 1.6, 2.4, 1.4), (-0.2, -2.6, 1.4, 1.6, 1.6), (-1.6, 0.4, 1.4, 1.2, 1.4), (0.6, 0.1, 1.6, 2.2, 1.4),
              (2.4, -2.8, 1.5, 1.4, 1.4), (4.4, -2.7, 1.8, 1.9, 1.4), (7.6, -2.6, 1.4, 1.5, 1.8), (7.4, 0.3, 1.6, 1.2, 1.6),
              (-7.5, 2.4, 1.2, 1.0, 1.0), (7.6, 2.4, 1.2, 1.1, 1.0)]
    walls = ["plaster", "plaster_dark", "pale_stone", "sand"]
    roofs = ["roof_red", "slate", "roof_dark"]
    for i, (x, z, bw, bh, bd) in enumerate(blocks):
        P.paint.add(gm.box((x, h + bh / 2, z), (bw, bh, bd), sw(walls[i % len(walls)])))
        roof = gm.cylinder((0, 0, 0), max(bw, bd) * 0.72, 0.0, 0.9, 4, sw(roofs[i % len(roofs)]), smooth=False)
        P.paint.add(roof.transformed(yaw=math.pi / 4, offset=(x, h + bh, z)))
    for (x, z, r, th, c) in [(-3.6, -0.9, 0.7, 5.2, "marble"), (2.6, -0.4, 0.6, 4.0, "pale_stone"), (5.4, -0.9, 0.55, 3.2, "plaster")]:
        P.paint.add(gm.cylinder((x, h, z), r, r * 0.85, th, 8, sw(c)))
        P.paint.add(gm.cylinder((x, h + th, z), r * 1.15, 0.0, 1.4, 8, sw("gold" if c == "marble" else "slate"), smooth=False))
    for k in range(4):
        P.paint.add(gm.sphere((rng.uniform(3.4, 6.0), h + 0.5, rng.uniform(-0.6, 1.8)), 0.45, 6, 4, sw("leaf_b")))


def b_giant_skull(P, rng):
    """A huge armoured beast's skull on a low stand: a bony frill with spikes at the back (west),
    two long brow horns, a beak of a snout to the east, and eye holes the size of a fist."""
    P.paint.add(gm.box((0, 0.4, 0), (3 * SQ - 0.8, 0.8, 2 * SQ - 1.6), sw("wood_dark")))
    P.paint.add(gm.box((0, 0.4, SQ - 0.75), (2.4, 0.5, 0.1), sw("gold")))
    P.paint.add(gm.sphere((-1.2, 3.6, 0), 3.0, 10, 7, sw("bone"), squash=0.85))
    P.paint.add(limb((0.5, 3.2, 0), (6.4, 1.9, 0), 2.3, 0.7, sw("bone"), seg=8))
    P.paint.add(limb((5.6, 1.9, 0), (6.9, 1.0, 0), 0.75, 0.1, sw("bone_dark"), seg=6))
    P.paint.add(limb((0.0, 1.6, 0), (5.2, 1.0, 0), 1.6, 0.6, sw("bone_dark"), seg=7))
    # the frill: a great plate tipped up behind the head, spikes round its edge
    tip, fc = -0.75, np.array((-3.5, 4.4, 0))
    fr = gm.cylinder((0, -0.4, 0), 3.9, 3.7, 0.8, 14, sw("bone_dark"))
    P.paint.add(fr.transformed(roll=tip, offset=fc))
    R = gm.rot_matrix(roll=tip)
    for k in range(9):
        # round the frill's rim (work in its plane, then tip it)
        a = math.pi * (0.3 + 1.4 * k / 8)
        q0 = R @ np.array((math.cos(a) * 3.7, 0.0, math.sin(a) * 3.7)) + fc
        q1 = R @ np.array((math.cos(a) * 4.7, 0.0, math.sin(a) * 4.7)) + fc
        P.paint.add(limb(q0, q1, 0.4, 0.0, sw("bone"), seg=4))
    for s in (-1, 1):
        P.paint.add(limb((0.2, 5.4, s * 1.4), (4.2, 8.4, s * 2.2), 0.6, 0.05, sw("bone"), seg=6))
        P.paint.add(gm.sphere((0.9, 4.3, s * 2.2), 0.75, 7, 5, sw("char")))
    P.paint.add(limb((4.6, 3.3, 0), (5.4, 4.9, 0), 0.45, 0.05, sw("bone"), seg=5))
    for k in range(5):
        x = 1.6 + k * 0.85
        P.paint.add(gm.cylinder((x, 1.7, 1.25 - k * 0.05), 0.2, 0.0, 0.7, 4, sw("white"), smooth=False))
    for (x, z) in [(-1.8, -1.2), (-0.6, 1.0), (-2.0, 1.3)]:
        P.paint.add(gm.sphere((x, 5.5, z), 0.9, 6, 4, sw("bone_dark"), squash=0.35))


def b_stuffed_bird(P, rng):
    """A big flightless bird, stuffed and stood on a plinth: yellow feathers, long neck, heavy beak,
    head to the east."""
    P.paint.add(gm.box((0, 0.35, 0), (3.8, 0.7, 3.4), sw("wood_dark")))
    P.paint.add(gm.box((0, 0.4, 1.72), (1.2, 0.35, 0.06), sw("gold")))
    for s in (-1, 1):
        P.paint.add(limb((-0.2 + s * 0.15, 0.7, s * 0.55), (-0.3, 3.7, s * 0.4), 0.18, 0.28, sw("rust"), seg=5))
        P.paint.add(gm.box((0.2 + s * 0.15, 0.78, s * 0.55), (1.0, 0.15, 0.5), sw("rust")))
    P.paint.add(gm.sphere((-0.5, 4.6, 0), 1.6, 9, 6, sw("coin"), squash=0.85))
    P.paint.add(gm.sphere((-1.4, 4.9, 0), 1.0, 7, 5, sw("awning_yellow")))
    for k in range(4):
        P.paint.add(limb((-1.9, 5.0, -0.6 + k * 0.4), (-2.4, 6.2 + (k % 2) * 0.4, -0.8 + k * 0.53), 0.25, 0.05,
                         sw("awning_yellow"), seg=4))
    for s in (-1, 1):
        P.paint.add(gm.sphere((-0.6, 4.9, s * 1.35), 0.75, 6, 4, sw("awning_yellow"), squash=0.6))
    P.paint.add(limb((0.5, 5.2, 0), (1.05, 8.1, 0.15), 0.6, 0.38, sw("coin"), seg=7))
    P.paint.add(gm.sphere((1.15, 8.35, 0.15), 0.62, 8, 5, sw("coin")))
    P.paint.add(limb((1.6, 8.3, 0.15), (2.45, 7.95, 0.2), 0.36, 0.08, sw("bronze"), seg=6))
    for s in (-1, 1):
        P.paint.add(gm.sphere((1.3, 8.55, 0.15 + s * 0.5), 0.12, 4, 3, sw("ink")))


def b_lectern(P, rng):
    """A lecturer's stand: the front (south) faces the room, the sloped top faces whoever reads from
    it on the north side, an open book on it."""
    P.paint.add(gm.box((0, 0.3, 0), (3.0, 0.6, 2.4), sw("wood_dark")))
    P.paint.add(gm.box((0, 3.0, 0), (1.5, 4.8, 1.2), sw("wood_mid")))
    P.paint.add(disc(0, 3.8, 0.63, 0.45, "gold", seg=8))
    top = gm.Mesh()
    top.add(gm.box((0, 0, 0), (3.4, 0.35, 2.6), sw("wood_dark")))
    top.add(gm.box((0, 0.24, 0.0), (2.6, 0.12, 1.8), sw("red_cloth")))
    for s in (-1, 1):
        top.add(gm.box((s * 0.62, 0.34, 0.0), (1.2, 0.1, 1.6), sw("paper")))
    top.add(gm.box((0, 0.3, -1.2), (3.4, 0.35, 0.2), sw("gold")))
    P.paint.add(top.transformed(pitch=-0.38, offset=(0, 5.75, 0)))


def b_blackboard(P, rng):
    """A blackboard on a wooden frame, chalk all over it. It stands against a north wall."""
    z = -SQ / 2 + 1.0
    for s in (-1, 1):
        P.paint.add(gm.box((s * 4.5, 4.5, z), (0.5, 9.0, 0.5), sw("wood_mid")))
        P.paint.add(gm.box((s * 4.5, 0.2, z + 0.4), (0.6, 0.4, 2.6), sw("wood_mid")))
    P.paint.add(gm.box((0, 6.2, z), (8.8, 5.0, 0.3), sw("wood_mid")))
    P.paint.add(gm.box((0, 6.2, z + 0.12), (8.2, 4.4, 0.12), sw("chalkboard")))
    P.paint.add(gm.box((0, 3.85, z + 0.4), (8.0, 0.2, 0.6), sw("wood_mid")))
    for k in range(3):
        P.paint.add(gm.box((-2 + k * 0.6, 4.0, z + 0.45), (0.4, 0.12, 0.12), sw("white")))
    f = z + 0.2
    for row in range(4):
        x = -3.6
        y = 7.7 - row * 0.8
        while x < 0.2:
            ww = rng.uniform(0.3, 1.1)
            P.paint.add(gm.box((x + ww / 2, y, f), (ww, 0.12, 0.04), sw("white")))
            x += ww + rng.uniform(0.2, 0.4)
    for k in range(10):
        a = k / 10 * 2 * math.pi
        P.paint.add(gm.box((0, 0, 0), (0.75, 0.1, 0.04), sw("white")).transformed(
            roll=a + math.pi / 2, offset=(2.0 + math.cos(a) * 1.1, 6.3 + math.sin(a) * 1.1, f)))
    P.paint.add(limb((2.0, 6.3, f), (3.3, 7.6, f), 0.06, 0.06, sw("white"), seg=4))


def b_couch(P, rng):
    """A chaise longue in purple velvet: a scrolled head at the west end, a half back, brass buttons."""
    for sx in (-1, 1):
        for sz in (-1, 1):
            P.paint.add(gm.cylinder((sx * 4.0, 0, sz * 1.3), 0.3, 0.2, 1.0, 6, sw("wood_dark")))
    P.paint.add(gm.box((0, 1.4, 0), (9.0, 0.8, 3.4), sw("wood_dark")))
    P.paint.add(gm.box((0.4, 2.2, 0.05), (8.2, 0.9, 3.1), sw("purple_cloth")))
    head = gm.box((0, 0, 0), (0.9, 3.4, 3.2), sw("purple_cloth"))
    P.paint.add(head.transformed(roll=0.28, offset=(-3.8, 3.0, 0.05)))
    scroll = gm.cylinder((0, -1.6, 0), 0.65, 0.65, 3.2, 8, sw("purple_cloth"))
    P.paint.add(scroll.transformed(pitch=math.pi / 2, offset=(-4.2, 4.65, 0.05)))
    back = gm.box((0, 0, 0), (5.2, 1.9, 0.6), sw("purple_cloth"))
    P.paint.add(back.transformed(roll=-0.12, offset=(-1.2, 3.3, -1.35)))
    P.paint.add(gm.box((0, 0, 0), (5.4, 0.25, 0.75), sw("wood_dark")).transformed(roll=-0.12, offset=(-1.2, 4.3, -1.35)))
    for k in range(4):
        x = -3.0 + k * 1.2
        P.paint.add(gm.sphere((x, 3.2 + (-x - 1.2) * 0.12, -1.0), 0.12, 4, 3, sw("gold")))


def figure(P, joints):
    """A stone person from joints: a dict of named points (the statues of the museum's victims)."""
    J = {k: np.array(v, float) for k, v in joints.items()}
    m = P.stone
    legs = [] if "lknee" in J else [("lfoot", "lhip", 0.42, 0.5), ("rfoot", "rhip", 0.42, 0.5)]
    for a, b, r0, r1 in legs + [("hips", "neck", 0.85, 1.0),
                         ("lsh", "lel", 0.36, 0.3), ("lel", "lhand", 0.3, 0.26), ("rsh", "rel", 0.36, 0.3),
                         ("rel", "rhand", 0.3, 0.26)]:
        if a in J and b in J:
            m.add(limb(J[a], J[b], r0, r1, STONE, seg=6))
    for a, b, r0, r1 in [("lknee", "lhip", 0.45, 0.5), ("rknee", "rhip", 0.45, 0.5), ("lfoot", "lknee", 0.38, 0.45),
                         ("rfoot", "rknee", 0.38, 0.45)]:
        if a in J and b in J:
            m.add(limb(J[a], J[b], r0, r1, STONE, seg=6))
    if "coat" in J:
        m.add(limb(J["coat"], J["hips"], 1.25, 0.9, STONE, seg=8))
    m.add(gm.sphere(J["hips"], 0.85, 7, 4, STONE))
    m.add(gm.sphere(J["head"], 0.62, 8, 6, STONE, squash=1.1))
    for h in ("lhand", "rhand"):
        m.add(gm.sphere(J[h], 0.3, 5, 3, STONE))
    m.add(gm.box((0, 0.15, 0), (2.6, 0.3, 2.2), STONE))     # the patch of floor that turned with them


def b_statue_victim(P, rng):
    """A visitor turned to stone, frightened: leaning back, both arms up to shield the face."""
    figure(P, {"lfoot": (-0.6, 0.2, 0.3), "rfoot": (0.6, 0.2, -0.3), "lhip": (-0.4, 3.4, 0), "rhip": (0.4, 3.4, 0),
               "hips": (0, 3.5, 0), "coat": (0, 2.2, 0), "neck": (0, 6.0, -0.4), "head": (0.2, 6.85, -0.35),
               "lsh": (-1.0, 5.8, -0.35), "lel": (-1.15, 6.4, 0.6), "lhand": (-0.35, 7.25, 0.55),
               "rsh": (1.0, 5.8, -0.35), "rel": (1.2, 6.6, 0.5), "rhand": (0.45, 7.5, 0.5)})


def b_statue_victim_b(P, rng):
    """A visitor turned to stone, cowering: down on the knees, curled over, arms over the head."""
    figure(P, {"lfoot": (-0.6, 0.45, -1.4), "rfoot": (0.6, 0.45, -1.3), "lknee": (-0.6, 0.55, 0.5), "rknee": (0.6, 0.55, 0.6),
               "lhip": (-0.45, 1.9, -0.7), "rhip": (0.45, 1.9, -0.7), "hips": (0, 2.0, -0.8), "neck": (0, 3.5, 0.6),
               "head": (0, 3.55, 1.35), "lsh": (-0.9, 3.5, 0.4), "lel": (-1.1, 4.3, 1.0), "lhand": (-0.25, 4.25, 1.45),
               "rsh": (0.9, 3.5, 0.4), "rel": (1.1, 4.2, 1.1), "rhand": (0.3, 4.3, 1.4)})


def b_statue_victim_c(P, rng):
    """A visitor turned to stone mid-stride, one arm reaching out to the south-east for help."""
    figure(P, {"lfoot": (0.3, 0.2, 1.1), "rfoot": (-0.4, 0.5, -1.3), "lhip": (0.35, 3.4, 0.1), "rhip": (-0.35, 3.4, -0.1),
               "hips": (0, 3.5, 0), "coat": (0, 2.3, 0.1), "neck": (0.1, 6.0, 0.6), "head": (0.2, 6.85, 0.95),
               "lsh": (1.0, 5.8, 0.4), "lel": (1.4, 6.4, 1.4), "lhand": (1.7, 6.9, 2.2),
               "rsh": (-0.9, 5.8, 0.5), "rel": (-1.5, 4.9, -0.4), "rhand": (-1.7, 4.1, -1.1)})


def b_mech_dais(P, rng):
    """A raised round iron platform with gears set round its rim, where a war machine stands on show."""
    h = 1.0
    P.paint.add(gm.cylinder((0, 0, 0), 4.0, 3.8, h, 16, sw("iron")))
    P.paint.add(gm.cylinder((0, h, 0), 3.4, 3.4, 0.06, 16, sw("metal")))
    P.paint.add(gm.cylinder((0, h + 0.06, 0), 1.5, 1.5, 0.06, 12, sw("bronze")))
    for k in range(8):
        a = k / 8 * 2 * math.pi
        P.paint.add(gm.box((math.cos(a) * 2.8, h + 0.12, math.sin(a) * 2.8), (0.3, 0.12, 0.3), sw("bronze"), skip=("-y",)))
    for k in range(7):
        a = (k + 0.5) / 7 * 2 * math.pi
        r = 0.8 if k % 2 else 0.65
        cx, cz = math.cos(a) * 3.9, math.sin(a) * 3.9
        y = 0.5 + 0.05 * (k % 2)
        gear = gm.Mesh()
        gear.add(gm.cylinder((0, 0, 0), r, r, 0.75, 10, sw("bronze" if k % 2 else "bronze_dark"), caps=(False, True)))
        for t in range(7):
            b = t / 7 * 2 * math.pi
            gear.add(gm.box((0, 0, 0), (0.3, 0.75, 0.3), sw("bronze" if k % 2 else "bronze_dark"), skip=("-y",)).transformed(
                yaw=-b, offset=(math.cos(b) * (r + 0.1), 0.375, math.sin(b) * (r + 0.1))))
        gear.add(gm.cylinder((0, 0.75, 0), 0.25, 0.25, 0.05, 6, sw("iron")))
        P.paint.add(gear.transformed(yaw=a * 0.7, offset=(cx, y, cz)))


def b_souvenir_table(P, rng):
    """A table in a red cloth, crowded with things to buy: little busts, snow globes, toy statues,
    postcards on a stand, and a price card."""
    top = 3.8
    for sx in (-1, 1):
        for sz in (-1, 1):
            P.paint.add(gm.box((sx * 4.0, top / 2, sz * 1.4), (0.45, top, 0.45), sw("wood_dark")))
    P.paint.add(gm.box((0, top, 0), (9.0, 0.35, 3.6), sw("wood_mid")))
    P.paint.add(gm.box((0, top - 0.6, 0), (9.2, 1.4, 3.8), sw("red_cloth")))
    y = top + 0.18
    things = ["globe", "bust", "statue", "globe", "cards", "bust", "statue", "globe"]
    for k, what in enumerate(things):
        x = -3.8 + k * 1.08
        z = 0.7 if k % 2 else -0.6
        if what == "globe":
            P.paint.add(gm.cylinder((x, y, z), 0.4, 0.35, 0.3, 6, sw("wood_dark")))
            P.paint.add(gm.sphere((x, y + 0.75, z), 0.48, 7, 5, sw("glass")))
            P.paint.add(gm.sphere((x, y + 0.6, z), 0.16, 4, 3, sw("white")))
        elif what == "bust":
            P.paint.add(gm.box((x, y + 0.25, z), (0.7, 0.5, 0.5), sw("marble")))
            P.paint.add(gm.sphere((x, y + 0.85, z), 0.3, 6, 4, sw("marble")))
        elif what == "statue":
            P.paint.add(gm.cylinder((x, y, z), 0.3, 0.2, 1.2, 5, sw("gold")))
            P.paint.add(gm.sphere((x, y + 1.35, z), 0.2, 5, 3, sw("gold")))
        else:
            P.paint.add(gm.box((0, 0, 0), (0.9, 1.2, 0.12), sw("wood_dark")).transformed(pitch=-0.25, offset=(x, y + 0.6, z - 0.3)))
            for c in range(3):
                card = gm.box((-0.3 + c * 0.3, 0.15, 0.1), (0.26, 0.5, 0.05), sw(["paper", "awning_blue", "leaf_c"][c]))
                P.paint.add(card.transformed(pitch=-0.25, offset=(x, y + 0.6, z - 0.3)))
    P.paint.add(gm.box((3.6, y + 1.1, 0), (0.1, 2.2, 0.1), sw("wood_dark")))
    P.paint.add(gm.box((3.6, y + 2.2, 0.08), (1.4, 0.8, 0.06), sw("paper")))
    P.paint.add(gm.box((3.4, y + 2.2, 0.12), (0.6, 0.18, 0.03), sw("ink")))


def b_bench_museum(P, rng):
    """A plain wooden bench with a low back, the lecture theatre's seating. The back is on the
    north side, so whoever sits faces south."""
    w = 9.2
    P.paint.add(gm.box((0, 2.2, 0.2), (w, 0.45, 2.2), sw("wood_light")))
    for sx in (-1, 1):
        for sz in (-1, 1):
            P.paint.add(gm.box((sx * (w / 2 - 0.5), 1.0, 0.2 + sz * 0.8), (0.4, 2.0, 0.4), sw("wood_mid")))
        P.paint.add(gm.box((sx * (w / 2 - 0.5), 3.4, -0.95), (0.4, 2.4, 0.35), sw("wood_mid")))
    P.paint.add(gm.box((0, 0.7, 0.2), (w - 1.0, 0.3, 0.3), sw("wood_mid")))
    for y in (3.3, 4.3):
        P.paint.add(gm.box((0, y, -0.95), (w, 0.5, 0.25), sw("wood_light")))


# ------------------------------------------------------------------ the kit
# fw, fh: footprint in squares. blocks: nobody stands there. cover: Half Cover to whoever stands
# next to it, from attacks across it. rough: Difficult Terrain. mask: only these (dx, dy) squares
# of the footprint block (the rest is open: a gate's arch, a pit's ring). light: a fire for the
# table's light (0..1). words/say: what the DM calls it, by default.

def K(fn, fw=1, fh=1, blocks=True, cover=False, rough=False, mask=None, light=0.0, words=(), say=""):
    return dict(fn=fn, fw=fw, fh=fh, blocks=blocks, cover=cover, rough=rough, mask=mask, light=light, words=list(words), say=say)


# SRD 5.2.1 for each piece (Rules Glossary: Cover, Breaking Objects; Equipment: light sources).
# Cover: a piece that covers at least half of a creature is Half Cover (+2 AC and Dex saves); at
# least three-quarters (a thick tree trunk, an arrow slit) is Three-Quarters Cover (+5). A piece
# you can't see through is Total Cover: nobody targets a creature directly through it.
THREE_QUARTERS = {"pine", "oak", "dead_tree", "standing_stone", "boulder", "pillar", "statue", "great_bell", "wall_window",
                  "hedge", "giant_skull", "statue_victim", "statue_victim_b", "statue_victim_c", "blackboard"}
OPAQUE = {"wall_room", "wall_door", "wall_shelf", "wall_notes", "house", "cottage", "shop", "house_burned", "town_wall",
          "gate", "watchtower", "tent", "bookshelf", "scroll_rack", "wardrobe", "curtain", "ruin_wall", "stone_wall",
          "stairs_spiral", "mound", "cliff", "vault_door", "hearth", "door", "door_locked",
          "wall_diag", "wall_painting", "wall_portrait", "tapestry"}
# Light: Bright Light out to the first radius, Dim Light for the second beyond it (feet). A
# Candle is 5 + 5, a Torch 20 + 20, a Lamp 15 + 30; a campfire, a hearth and a brazier burn like
# a torch.
LIGHT_FT = {"campfire": (20, 20), "hearth": (20, 20), "brazier": (20, 20), "torch_post": (20, 20),
            "candelabra": (5, 5), "lamp_post": (15, 30)}
# Doors: wood (AC 15), a Medium resilient object (18 HP); a Lock is DC 15 to pick with Thieves'
# Tools (Sleight of Hand), and forcing one is a Strength (Athletics) check, DC 20 (Hard).
DOORS = {"door": "closed", "door_open": "open", "door_locked": "locked"}
SLIPPERY = {"ice"}           # Slippery Ice: Difficult Terrain, DC 10 Dex save or Prone (p. 195)


# What one piece of cover is called when a shot or a swing hits it instead ("the arrow thuds into
# the crate"). Every kind that gives cover has one.
ONE = {
    "pine": "pine", "oak": "old oak", "dead_tree": "dead tree", "rock": "rocks", "boulder": "boulder",
    "standing_stone": "standing stone", "fallen_log": "fallen log", "log_seat": "log", "weapon_rack": "spear rack",
    "fence": "fence", "well": "well", "stall": "stall", "cart": "cart", "crate": "crate", "barrel": "barrel",
    "hay_bale": "hay bale", "bench": "bench", "statue": "statue", "bell_fallen": "fallen bell", "bar": "bar",
    "counter": "counter", "table_round": "table", "table_long": "long table", "bed": "bed", "desk": "desk",
    "chest": "chest", "strongbox": "strongbox", "pillar": "pillar", "broken_pillar": "broken pillar",
    "ruin_wall_low": "low wall", "altar": "altar", "pew": "pew", "sarcophagus": "tomb", "gravestone": "gravestone",
    "great_bell": "great bell", "bell": "bell", "drum": "war drum", "wall_window": "window",
    "display_case": "glass case", "plinth": "plinth", "hedge": "hedge", "topiary": "topiary", "donation_box": "donation box",
    "canopic_jars": "table of jars", "stone_tablet": "tablet", "ritual_basin": "basin", "diorama_cave": "diorama",
    "diorama_kitchen": "diorama", "model_city": "model city", "giant_skull": "giant skull", "stuffed_bird": "stuffed bird",
    "lectern": "lectern", "blackboard": "blackboard", "couch": "couch", "statue_victim": "statue", "statue_victim_b": "statue",
    "statue_victim_c": "statue", "souvenir_table": "souvenir table", "bench_museum": "bench",
}


KINDS = {
    # nature
    "pine": K(b_pine, cover=True, words=("pine", "trees", "tree", "forest", "woods"), say="pines"),
    "oak": K(b_oak, cover=True, words=("oak", "trees", "tree", "forest", "woods"), say="an old oak"),
    "dead_tree": K(b_dead_tree, cover=True, words=("dead tree", "bare tree", "trees"), say="a dead tree"),
    "bush": K(b_bush, blocks=False, rough=True, words=("bush", "brush", "undergrowth", "brambles"), say="thick brush"),
    "tall_grass": K(b_tall_grass, blocks=False, rough=True, words=("grass", "weeds"), say="long grass"),
    "rock": K(b_rock, cover=True, words=("rock", "stones", "boulder"), say="rocks"),
    "boulder": K(b_boulder, 2, 2, cover=True, words=("boulder", "rock"), say="a boulder"),
    "standing_stone": K(b_standing_stone, cover=True, words=("standing stone", "stones"), say="standing stones"),
    "fallen_log": K(b_fallen_log, 3, 1, cover=True, words=("log", "fallen"), say="a fallen log"),
    "stump": K(b_stump, blocks=False, rough=True, words=("stump",), say="stumps"),
    "campfire": K(b_campfire, light=1.0, words=("fire", "campfire", "embers", "smoke", "pot", "cooking"), say="a campfire"),
    "tent": K(b_tent, 2, 1, words=("tent", "camp"), say="tents"),
    "log_seat": K(b_log_seat, cover=True, words=("log", "seat"), say="logs to sit on"),
    "totem": K(b_totem, words=("totem", "skull", "bones"), say="a skull totem"),
    "bedroll": K(b_bedroll, 1, 2, blocks=False, words=("bedroll", "blanket", "sleeping"), say="bedrolls"),
    "weapon_rack": K(b_weapon_rack, cover=True, words=("spears", "weapons", "rack"), say="a rack of spears"),
    "road_ew": K(b_road_ew, 20, 3, blocks=False, words=("road", "track", "trail"), say="the road"),
    "path_ns": K(b_path_ns, 3, 13, blocks=False, words=("path", "track", "trail"), say="a path"),
    "path_patch": K(b_path_patch, 3, 3, blocks=False, words=("mud", "dirt", "clearing"), say="trampled mud"),
    "ash": K(b_ash, 3, 3, blocks=False, words=("ash", "ashes", "burned", "embers", "charred"), say="ash"),
    "sand_ring": K(b_sand_ring, 6, 6, blocks=False, words=("sand", "ring"), say="a sand floor"),
    "puddle": K(b_puddle, 3, 3, blocks=False, rough=True, words=("water", "flood", "puddle", "wet"), say="standing water"),
    "stream_ns": K(b_stream_ns, 2, 13, blocks=False, rough=True, words=("stream", "brook", "creek", "river", "water"),
                   say="a stream"),
    "pond": K(b_pond, 3, 3, words=("pond", "pool", "water"), say="a pond"),
    "chasm": K(b_chasm, 3, 5, words=("gorge", "chasm", "drop", "ravine", "bottom"), say="the gorge"),
    "rope_bridge": K(b_rope_bridge, 3, 3, blocks=False, words=("bridge", "planks", "rope"), say="the rope bridge"),
    "cliff": K(b_cliff, words=("cliff", "crag", "rocks", "ledge"), say="crags"),
    # town
    "house": K(b_house, 3, 3, words=("house", "houses", "building", "home", "town"), say="a house"),
    "cottage": K(b_cottage, 3, 2, words=("cottage", "house", "houses", "hut", "farm"), say="a cottage"),
    "shop": K(b_shop, 3, 2, words=("shop", "store", "houses", "building"), say="a shopfront"),
    "house_burned": K(b_house_burned, 3, 3, words=("burned", "burnt", "ruins", "ashes", "village", "houses"),
                      say="a burned-out house"),
    "town_wall": K(b_town_wall, words=("wall", "walls", "rampart", "battlement"), say="the town wall"),
    "gate": K(b_gate, 3, 1, mask=[(0, 0), (2, 0)], words=("gate", "arch", "portcullis"), say="the gate"),
    "watchtower": K(b_watchtower, 2, 2, words=("tower", "watchtower", "lookout"), say="a watchtower"),
    "fence": K(b_fence, cover=True, words=("fence",), say="a fence"),
    "well": K(b_well, cover=True, words=("well",), say="a well"),
    "stall": K(b_stall, 2, 2, cover=True, words=("stall", "stalls", "market", "awning", "traders"), say="market stalls"),
    "cart": K(b_cart, 2, 1, cover=True, words=("cart", "wagon", "carters"), say="a cart"),
    "crate": K(b_crate, cover=True, words=("crate", "crates", "boxes", "cargo"), say="crates"),
    "barrel": K(b_barrel, cover=True, words=("barrel", "barrels", "kegs", "casks", "ale"), say="barrels"),
    "hay_bale": K(b_hay_bale, cover=True, words=("hay", "straw"), say="hay bales"),
    "lamp_post": K(b_lamp_post, words=("lamp", "lamps", "lantern", "lamplighters"), say="a lamp post"),
    "bench": K(b_bench, 2, 1, cover=True, words=("bench", "benches"), say="benches"),
    "notice_board": K(b_notice_board, words=("notice", "board", "posters", "wanted"), say="a notice board"),
    "statue": K(b_statue, cover=True, words=("statue", "saint", "figure"), say="a statue"),
    "signpost": K(b_signpost, words=("signpost", "sign", "fork", "crossroads"), say="a signpost"),
    "bell_fallen": K(b_bell_fallen, cover=True, words=("bell", "tongue"), say="a fallen bell"),
    "pit_ring": K(b_pit_ring, 6, 6, blocks=False, mask=[(0, 0), (5, 0), (0, 5), (5, 5)],
                  words=("pit", "ring", "fight", "ropes", "sand"), say="the fighting ring"),
    # indoors
    "floor_boards": K(b_floor_boards, 20, 13, blocks=False, words=("floor", "boards"), say="floorboards"),
    "floor_flags": K(b_floor_flags, 20, 13, blocks=False, words=("flagstones", "stone floor"), say="flagstones"),
    "floor_cobbles": K(b_floor_cobbles, 20, 13, blocks=False, words=("cobbles", "cobbled", "square", "street"),
                       say="cobbles"),
    "floor_grass": K(b_floor_grass, 20, 13, blocks=False, words=("grass", "meadow", "field"), say="grass"),
    "floor_dirt": K(b_floor_dirt, 20, 13, blocks=False, words=("dirt", "mud", "trampled"), say="trampled dirt"),
    "floor_ash": K(b_floor_ash, 20, 13, blocks=False, words=("ash", "ashes", "scorched"), say="scorched ground"),
    "floor_sand": K(b_floor_sand, 20, 13, blocks=False, words=("sand", "shore", "beach"), say="sand"),
    "wall_room": K(b_wall_room, words=("wall", "walls", "room"), say="walls"),
    "wall_window": K(b_wall_window, cover=True, words=("window", "windows", "shutters", "rain"), say="shuttered windows"),
    "wall_door": K(b_wall_door, words=("door", "doorway"), say="a door"),
    "wall_shelf": K(b_wall_shelf, words=("shelf", "shelves", "bottles", "mugs"), say="shelves"),
    "bar": K(b_bar, cover=True, words=("bar", "counter", "mugs", "ale", "bottles", "taps"), say="the bar"),
    "counter": K(b_counter, cover=True, words=("counter", "desk", "ledger"), say="a counter"),
    "hearth": K(b_hearth, 2, 1, light=0.75, words=("fire", "hearth", "fireplace", "warm"), say="a fire in the hearth"),
    "table_round": K(b_table_round, cover=True, words=("table", "tables", "stools", "drink"), say="tables"),
    "table_long": K(b_table_long, 2, 1, cover=True, words=("table", "tables", "benches", "feast"), say="a long table"),
    "bed": K(b_bed, 1, 2, cover=True, words=("bed", "beds", "cot"), say="a narrow bed"),
    "desk": K(b_desk, 2, 1, cover=True, words=("desk", "papers", "ledger", "letters", "ink", "notes", "candle"),
              say="a desk covered in papers"),
    "bookshelf": K(b_bookshelf, 2, 1, words=("books", "shelves", "shelf", "library", "bookshelves", "pages"), say="bookshelves"),
    "scroll_rack": K(b_scroll_rack, 2, 1, words=("scrolls", "records", "archive", "maps"), say="racks of scrolls"),
    "chest": K(b_chest, cover=True, words=("chest", "trunk", "box"), say="a chest"),
    "strongbox": K(b_strongbox, cover=True, words=("strongbox", "coin", "coins", "money", "gold"), say="a strongbox"),
    "rug": K(b_rug, 3, 2, blocks=False, words=("rug", "carpet"), say="a rug"),
    "wardrobe": K(b_wardrobe, words=("wardrobe", "cupboard"), say="a wardrobe"),
    "candelabra": K(b_candelabra, light=0.35, words=("candles", "candle", "candlelight", "candelabra"), say="candles"),
    "curtain": K(b_curtain, words=("curtain", "curtains", "drapes"), say="velvet curtains"),
    # sacred and ruined
    "pillar": K(b_pillar, cover=True, words=("pillar", "pillars", "columns", "column"), say="pillars"),
    "broken_pillar": K(b_broken_pillar, cover=True, words=("pillar", "pillars", "broken", "fallen", "ruins"),
                       say="broken pillars"),
    "ruin_wall": K(b_ruin_wall, words=("wall", "walls", "ruin", "ruins", "stone"), say="crumbling walls"),
    "ruin_wall_low": K(b_ruin_wall_low, cover=True, words=("wall", "walls", "low wall", "ruins"), say="low walls"),
    "stone_wall": K(b_stone_wall, words=("wall", "walls", "stone"), say="stone walls"),
    "altar": K(b_altar, 1, 2, cover=True, light=0.0, words=("altar", "shrine", "candles", "offerings"), say="an altar"),
    "pew": K(b_pew, 2, 1, cover=True, words=("pew", "pews", "benches"), say="pews"),
    "rubble": K(b_rubble, blocks=False, rough=True, words=("rubble", "broken", "fallen", "collapsed", "cracked"), say="rubble"),
    "sarcophagus": K(b_sarcophagus, 1, 2, cover=True, words=("sarcophagus", "tomb", "tombs", "coffin", "dead"),
                     say="stone tombs"),
    "gravestone": K(b_gravestone, cover=True, words=("grave", "graves", "gravestone", "headstone", "graveyard"),
                    say="gravestones"),
    "open_grave": K(b_open_grave, 1, 2, words=("open grave", "graves", "dug", "grave"), say="an open grave"),
    "bones": K(b_bones, blocks=False, rough=True, words=("bones", "skulls", "skeleton"), say="bones"),
    "brazier": K(b_brazier, light=0.7, words=("brazier", "fire", "flames", "coals"), say="a burning brazier"),
    "web": K(b_web, 2, 2, blocks=False, rough=True, words=("web", "webs", "cobwebs", "spider", "webbed"), say="webs"),
    "spider_eggs": K(b_spider_eggs, blocks=False, rough=True, words=("eggs", "sacs", "spider"), say="egg sacs"),
    "stairs_spiral": K(b_stairs_spiral, 2, 2, words=("stairs", "steps", "staircase"), say="the stairs"),
    "great_bell": K(b_great_bell, 2, 2, cover=True, words=("great bell", "bell", "bells", "frost"), say="the great bell"),
    "bell": K(b_bell, cover=True, words=("bells", "bell"), say="bells"),
    "banner": K(b_banner, words=("banner", "badge", "wolf", "flag", "standard"), say="a wolf banner"),
    "mound": K(b_mound, 3, 3, words=("barrow", "mound", "hill", "grave"), say="the barrow mound"),
    "frost": K(b_frost, blocks=False, words=("frost", "ice", "cold"), say="frost"),
    "wall_notes": K(b_wall_notes, words=("drawings", "pinned", "papers", "notes", "pages"), say="drawings pinned to the walls"),
    "vault_door": K(b_vault_door, 2, 1, words=("vault", "vault door"), say="a vault door"),
    "flowers": K(b_flowers, blocks=False, words=("flowers", "flower"), say="flowers"),
    "tracks": K(b_tracks, blocks=False, words=("tracks", "prints", "footprints", "paw"), say="tracks in the mud"),
    "drum": K(b_drum, cover=True, words=("drum", "drums"), say="war drums"),
    "water_strip": K(b_water_strip, 20, 4, words=("water", "harbour", "harbor", "river", "sea", "lake", "bay"),
                     say="dark water"),
    "pier": K(b_pier, 3, 4, blocks=False, words=("pier", "jetty", "dock", "boats", "planks"), say="a pier"),
    # the DM's set pieces (Set the stage): a door that opens, ice, a torch on a post
    "door": K(b_door, words=("door", "doorway"), say="a door"),
    "door_open": K(b_door_open, blocks=False, words=("door", "doorway", "open door"), say="an open door"),
    "door_locked": K(b_door_locked, words=("door", "locked door", "lock"), say="a locked door"),
    "ice": K(b_ice, blocks=False, rough=True, words=("ice", "frozen", "slippery"), say="a sheet of ice"),
    "torch_post": K(b_torch_post, light=0.5, words=("torch", "torches", "torchlight"), say="a torch on a post"),
    # the museum (The Museum of Nightmares): its halls, its garden, its exhibits
    "floor_marble": K(b_floor_marble, 20, 13, blocks=False, words=("marble", "marble floor", "tiles", "polished"),
                      say="a polished marble floor"),
    "paving": K(b_paving, blocks=False, words=("path", "paving", "paved", "slabs"), say="a paved path"),
    "wall_diag": K(b_wall_diag, words=("wall", "walls", "corner"), say="walls"),
    "wall_painting": K(b_wall_painting, words=("painting", "paintings", "picture", "pictures", "canvas", "frames"),
                       say="paintings on the walls"),
    "wall_portrait": K(b_wall_portrait, words=("portrait", "knight", "dark armour", "dark armor"),
                       say="a portrait of a knight in dark armour"),
    "tapestry": K(b_tapestry, words=("tapestry", "tapestries", "hanging", "sisters"), say="a tapestry of three snake-haired sisters"),
    "display_case": K(b_display_case, cover=True, words=("case", "cases", "glass", "display", "exhibit", "exhibits"),
                      say="glass display cases"),
    "plinth": K(b_plinth, cover=True, words=("plinth", "plinths", "pedestal", "bust", "busts"), say="a bust on a plinth"),
    "hedge": K(b_hedge, cover=True, words=("hedge", "hedges", "hedgerow"), say="clipped hedges"),
    "topiary": K(b_topiary, cover=True, words=("topiary", "beast", "beasts", "clipped"), say="bushes clipped into beasts"),
    "garden_steps": K(b_garden_steps, 2, 3, blocks=False, words=("steps", "terrace"), say="wide stone steps up to a terrace"),
    "stairs_straight": K(b_stairs_straight, 2, 3, blocks=False, words=("stairs", "staircase", "stair", "upstairs"),
                         say="a staircase going up"),
    "donation_box": K(b_donation_box, cover=True, words=("donation", "donations", "donation box", "offering", "gilded"),
                      say="a gilded donation box"),
    "canopic_jars": K(b_canopic_jars, cover=True, words=("jars", "jar", "canopic", "urns"), say="old jars with animal heads"),
    "stone_tablet": K(b_stone_tablet, cover=True, words=("tablet", "inscription", "carvings", "runes"), say="a cracked stone tablet"),
    "ritual_basin": K(b_ritual_basin, cover=True, words=("basin", "bowl", "font", "ritual"), say="a stone basin of water"),
    "diorama_cave": K(b_diorama_cave, 3, 2, cover=True, words=("diorama", "dioramas", "cave", "cave folk"),
                      say="a diorama of a cave"),
    "diorama_kitchen": K(b_diorama_kitchen, 3, 2, cover=True, words=("diorama", "dioramas", "kitchen", "stove", "cupboards"),
                         say="a little kitchen on a platform"),
    "model_city": K(b_model_city, 4, 2, cover=True, words=("model", "city", "tram", "miniature", "tiny city"),
                    say="a model city with a tram"),
    "giant_skull": K(b_giant_skull, 3, 2, cover=True, words=("skull", "fossil", "giant skull", "horns"), say="a huge armoured skull"),
    "stuffed_bird": K(b_stuffed_bird, cover=True, words=("bird", "stuffed", "feathers"), say="a big stuffed bird"),
    "lectern": K(b_lectern, cover=True, words=("lectern", "podium", "lecture", "lecturer"), say="a lectern"),
    "blackboard": K(b_blackboard, 2, 1, cover=True, words=("blackboard", "chalkboard", "chalk"), say="a blackboard covered in chalk"),
    "couch": K(b_couch, 2, 1, cover=True, words=("couch", "chaise", "sofa", "velvet"), say="a purple velvet couch"),
    "statue_victim": K(b_statue_victim, cover=True, words=("statue", "statues", "petrified", "turned to stone"),
                       say="statues of frightened people"),
    "statue_victim_b": K(b_statue_victim_b, cover=True, words=("statue", "statues", "petrified", "cowering"),
                         say="a statue cowering"),
    "statue_victim_c": K(b_statue_victim_c, cover=True, words=("statue", "statues", "petrified", "reaching"),
                         say="a statue reaching out"),
    "mech_dais": K(b_mech_dais, 2, 2, blocks=False, words=("dais", "platform", "gears", "machine", "mech"),
                   say="a round dais ringed with gears"),
    "souvenir_table": K(b_souvenir_table, 2, 1, cover=True, words=("souvenir", "souvenirs", "trinkets", "gifts"),
                        say="a table of souvenirs"),
    "bench_museum": K(b_bench_museum, 2, 1, cover=True, words=("bench", "benches", "seats", "seating"),
                      say="rows of wooden benches"),
}
# A piece you can walk on even where another blocks the square (a pier over the water).
CLEAR = {"pier", "rope_bridge"}
# Pieces that lie flat on the mat: they're laid down rather than dropped.
FLAT = {"floor_boards", "floor_flags", "floor_cobbles", "floor_grass", "floor_dirt", "floor_ash", "floor_sand", "road_ew", "path_ns", "path_patch", "ash", "sand_ring", "puddle",
        "stream_ns", "water_strip", "frost", "tracks", "rug", "pit_ring", "flowers", "tall_grass", "ice",
        "floor_marble", "paving"}


# ------------------------------------------------------------------ output

def model_file(mesh_name, texture):
    return (f'mesh: "/assets/meshes/{mesh_name}.glb"\nname: "{{{{NAME}}}}"\n'
            f'materials {{\n  name: "default"\n  material: "/materials/lit.material"\n'
            f'  textures {{\n    sampler: "tex0"\n    texture: "{texture}"\n  }}\n}}\n')


def go_file(components):
    out = ""
    for cid, comp in components:
        out += f'components {{\n  id: "{cid}"\n  component: "{comp}"\n}}\n'
    return out


def w(rel, text):
    p = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w", newline="\n") as f:
        f.write(text)


TEX = {"stone": "/assets/textures/stone.png", "paint": "/assets/textures/props_palette.png",
       "wood": "/assets/textures/wood_floor.png"}


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    write_palette()
    board_comps = [("board", "/main/board/board.script")]
    lua = ["-- Generated by tools/gen_props.py. Don't edit by hand: change KINDS there and rerun it.",
           "-- The board's prop kit: footprint (fw x fh squares, before rotation), what each piece does on",
           "-- the mat, and what the DM calls it. main/board/board.script drops them in; game/model/board.lua",
           "-- works out what blocks, what's cover and what's rough ground.", "", "return {"]
    stats = []
    written = set()
    for name, k in KINDS.items():
        P = Parts()
        k["fn"](P, rng_for(name))
        comps = []
        tris = 0
        for part in ("stone", "paint", "wood"):
            mesh = getattr(P, part)
            if len(mesh.p) == 0:
                continue
            mname = f"prop_{name}_{part}"
            gm.write_glb(os.path.join(ROOT, "assets/meshes", mname + ".glb"), mesh, mname)
            w(f"main/board/props/{mname}.model", model_file(mname, TEX[part]))
            written |= {mname + ".glb", mname + ".model"}
            comps.append((part, f"/main/board/props/{mname}.model"))
            tris += len(mesh.p) // 3
        w(f"main/board/props/{name}.go", go_file(comps))
        w(f"main/board/props/{name}.factory", f'prototype: "/main/board/props/{name}.go"\n')
        written |= {name + ".go", name + ".factory"}
        board_comps.append((name, f"/main/board/props/{name}.factory"))
        stats.append((name, tris))
        mask = ""
        if k["mask"]:
            mask = ", mask = { " + ", ".join(f"{{ {dx}, {dy} }}" for dx, dy in k["mask"]) + " }"
        words = ", ".join(lua_str(x) for x in k["words"])
        clear = (", clear = true" if name in CLEAR else "") + (", flat = true" if name in FLAT else "")
        lua.append(f"    {name} = {{ fw = {k['fw']}, fh = {k['fh']}, blocks = {str(k['blocks']).lower()}, "
                   f"cover = {str(k['cover']).lower()}, rough = {str(k['rough']).lower()}, light = {k['light']}{mask}{clear},")
        one = f", one = {lua_str(ONE[name])}" if k["cover"] else ""
        rules = ""
        if k["cover"]:
            rules += ', deg = "three_quarters"' if name in THREE_QUARTERS else ', deg = "half"'
        if name in OPAQUE:
            rules += ", opaque = true"
        if name in LIGHT_FT:
            rules += f", bright = {LIGHT_FT[name][0]}, dim = {LIGHT_FT[name][1]}"
        if name in DOORS:
            rules += f', door = "{DOORS[name]}", ac = 15, hp = 18'
        if name in SLIPPERY:
            rules += ", slippery = true"
        one += rules
        lua.append(f"        words = {{ {words} }}, say = {lua_str(k['say'])}{one} }},")
    lua.append("}")
    missing = [n for n, k in KINDS.items() if k["cover"] and n not in ONE]
    unknown = (THREE_QUARTERS | OPAQUE | set(LIGHT_FT) | set(DOORS) | SLIPPERY) - set(KINDS)
    assert not unknown, "rules for kinds that don't exist: " + ", ".join(sorted(unknown))
    assert not missing, "cover pieces with no ONE name: " + ", ".join(missing)
    w("main/board/board.go", go_file(board_comps))
    # Anything left over from a kind or a part that's gone.
    for fn in os.listdir(os.path.join(ROOT, "main/board/props")):
        if fn not in written:
            os.remove(os.path.join(ROOT, "main/board/props", fn))
    for fn in os.listdir(os.path.join(ROOT, "assets/meshes")):
        if fn.startswith("prop_") and fn not in written:
            os.remove(os.path.join(ROOT, "assets/meshes", fn))
    w("game/data/props.lua", "\n".join(lua) + "\n")
    total = sum(t for _, t in stats)
    print(f"{len(KINDS)} kinds, {total} triangles; biggest: " +
          ", ".join(f"{n} {t}" for n, t in sorted(stats, key=lambda s: -s[1])[:6]))


if __name__ == "__main__":
    main()
