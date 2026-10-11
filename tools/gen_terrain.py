"""Terrain sets for game night: the scenery that drops onto the battle mat for
each scene (goblin camp, forest road, ruined chapel, tavern, market square, rope
bridge, open ground). Layout comes from terrain_layout.py; each set becomes up to
three meshes: stone pieces (stone.png), painted pieces (palette.png) and a floor
overlay (wood or flagstones). Units are centimetres; a square is 5 cm.
"""
import math

import numpy as np

import gen_meshes as gm
import gen_textures as gt
from terrain_layout import SETS

MAT_X0, MAT_Z0 = -56.0, -34.5
MAT_Y = 75.15
PAL = gt.palette_uv


def g(x, y):
    """World (x, z) of grid square (x, y), 1-based."""
    return (MAT_X0 + 2.5 + 5 * (x - 1), MAT_Z0 + 2.5 + 5 * (y - 1))


def centre(squares):
    xs = [g(x, y)[0] for (x, y) in squares]
    zs = [g(x, y)[1] for (x, y) in squares]
    return (sum(xs) / len(xs), sum(zs) / len(zs))


def sw(name):
    return gm.swatch(PAL(name))


STONE = gm.triplanar(12)


# ------------------------------------------------------------------ pieces
# Each builder returns (stone_mesh, paint_mesh) for its squares.

def _empty():
    return gm.Mesh(), gm.Mesh()


def campfire(sq, seed):
    st, pt = _empty()
    cx, cz = centre(sq)
    for k in range(9):
        a = k / 9 * 2 * math.pi
        rk = gm.rock((cx + math.cos(a) * 3.0, MAT_Y + 0.45, cz + math.sin(a) * 3.0), 1.0, seed + k, STONE, squash=0.8)
        st.add(gm.flatten_below(rk, MAT_Y))
    for k, a in enumerate((0.3, 1.35, 2.4)):
        lg = gm.box((0, 0, 0), (5.0, 1.0, 1.0), sw("log"))
        pt.add(lg.transformed(yaw=a, roll=0.18 * (1 if k % 2 else -1), offset=(cx, MAT_Y + 0.8, cz)))
    pt.add(gm.cylinder((cx, MAT_Y, cz), 1.6, 1.2, 0.5, 10, sw("ember")))
    return st, pt


def tent(sq, seed):
    st, pt = _empty()
    cx, cz = centre(sq)
    length = 5.0 * len(sq) - 0.6
    h, half = 7.0, 4.2
    along_x = len(set(x for x, _ in sq)) > 1
    m = gm.Mesh()
    canvas = sw("canvas")
    L = length / 2
    for s in (-1, 1):
        ps = [(-L, 0, s * half), (L, 0, s * half), (L, h, 0), (-L, h, 0)]
        n = (0, half, s * h)
        nn = np.array(n, float) / np.linalg.norm(n)
        m.quad([np.array(p) for p in ps], [nn] * 4, [PAL("canvas")] * 4)
    for s in (-1, 1):
        ps = [(s * L, 0, -half), (s * L, 0, half), (s * L, h, 0)]
        m.tri([np.array(p) for p in ps], [np.array((s, 0, 0), float)] * 3, [PAL("canvas_dark")] * 3)
    m.add(gm.box((0, h + 0.2, 0), (length + 0.6, 0.5, 0.5), sw("log")))
    pt.add(m.transformed(yaw=0 if along_x else math.pi / 2, offset=(cx, MAT_Y, cz)))
    return st, pt


def log_seat(sq, seed):
    st, pt = _empty()
    cx, cz = centre(sq)
    lg = gm.cylinder((0, -2.0, 0), 1.3, 1.3, 4.0, 10, sw("log"))
    pt.add(lg.transformed(roll=math.pi / 2, yaw=seed * 0.7, offset=(cx, MAT_Y + 1.3, cz)))
    return st, pt


def rock(sq, seed):
    st, pt = _empty()
    cx, cz = centre(sq)
    for k in range(3):
        r = 2.4 - k * 0.6
        rk = gm.rock((cx + (k - 1) * 1.6, MAT_Y + r * 0.35, cz + ((k * 7) % 3 - 1) * 1.2), r, seed + k, STONE)
        st.add(gm.flatten_below(rk, MAT_Y))
    return st, pt


def pine(sq, seed):
    st, pt = _empty()
    cx, cz = centre(sq)
    pt.add(gm.cylinder((cx, MAT_Y, cz), 0.9, 0.7, 4, 8, sw("bark")))
    for (y0, r, h, c) in [(3, 4.4, 7, "leaf_b"), (7, 3.5, 6, "leaf_a"), (11, 2.4, 5, "leaf_c")]:
        pt.add(gm.cylinder((cx, MAT_Y + y0, cz), r, 0.0, h, 9, sw(c), smooth=False))
    return st, pt


def oak(sq, seed):
    st, pt = _empty()
    cx, cz = centre(sq)
    pt.add(gm.cylinder((cx, MAT_Y, cz), 1.0, 0.8, 6, 8, sw("bark")))
    for (dx, dy, dz, r, c, s) in [(0, 8, 0, 4.0, "leaf_a", 1), (2.2, 6.5, 1.4, 3.0, "leaf_b", 2), (-2.2, 7, -1, 2.8, "leaf_c", 3)]:
        pt.add(gm.rock((cx + dx, MAT_Y + dy, cz + dz), r, seed + s, sw(c), squash=0.9))
    return st, pt


def totem(sq, seed):
    st, pt = _empty()
    cx, cz = centre(sq)
    pt.add(gm.box((cx, MAT_Y + 5, cz), (1.6, 10, 1.6), sw("log")))
    pt.add(gm.box((cx, MAT_Y + 8.5, cz), (4.0, 0.8, 0.8), sw("log")))
    pt.add(gm.sphere((cx, MAT_Y + 11, cz), 1.6, 8, 5, sw("bone")))
    for s in (-1, 1):
        pt.add(gm.box((cx + s * 2.0, MAT_Y + 9.4, cz), (0.5, 1.4, 0.5), sw("feather")))
    return st, pt


def fallen_log(sq, seed):
    st, pt = _empty()
    cx, cz = centre(sq)
    length = 5.0 * len(sq) - 0.8
    lg = gm.cylinder((0, -length / 2, 0), 1.6, 1.4, length, 10, sw("log"))
    pt.add(lg.transformed(roll=math.pi / 2, yaw=0.08, offset=(cx, MAT_Y + 1.5, cz)))
    for k in (-1, 1):
        pt.add(gm.rock((cx + k * 3, MAT_Y + 3.0, cz), 0.8, seed + k + 5, sw("leaf_c")))
    return st, pt


def bush(sq, seed):
    st, pt = _empty()
    cx, cz = centre(sq)
    for (dx, dz, r, c, s) in [(0, 0, 2.4, "leaf_b", 1), (1.6, 1.0, 1.8, "leaf_a", 2), (-1.4, 0.8, 1.6, "leaf_c", 3)]:
        pt.add(gm.flatten_below(gm.rock((cx + dx, MAT_Y + r * 0.5, cz + dz), r, seed + s, sw(c), squash=0.8), MAT_Y))
    return st, pt


def pillar(sq, seed, height=12.0):
    st, pt = _empty()
    cx, cz = centre(sq)
    st.add(gm.box((cx, MAT_Y + 0.6, cz), (4.4, 1.2, 4.4), STONE))
    st.add(gm.cylinder((cx, MAT_Y + 1.2, cz), 1.7, 1.5, height - 2.4, 10, STONE))
    if height > 8:
        st.add(gm.box((cx, MAT_Y + height - 0.6, cz), (4.0, 1.2, 4.0), STONE))
    return st, pt


def broken_pillar(sq, seed):
    st, pt = pillar(sq, seed, height=6.0)
    cx, cz = centre(sq)
    chunk = gm.cylinder((0, -2.5, 0), 1.6, 1.6, 5.0, 10, STONE)
    st.add(chunk.transformed(roll=math.pi / 2, yaw=0.6, offset=(cx + 1.0, MAT_Y + 1.6, cz + 2.0)))
    return st, pt


def wall(sq, seed, rows=3):
    st, pt = _empty()
    rng = np.random.default_rng(seed)
    xs = [g(x, y)[0] for (x, y) in sq]
    zs = [g(x, y)[1] for (x, y) in sq]
    x0, x1 = min(xs) - 2.5, max(xs) + 2.5
    cz = sum(zs) / len(zs)
    for row in range(rows):
        n = max(1, int((x1 - x0) / 4.4) - row)
        for b in range(n):
            x = x0 + 2.3 + b * 4.5 + (1.2 if row % 2 else 0)
            blk = gm.box((0, 0, 0), (4.2, 2.8, 3.2), STONE)
            st.add(blk.transformed(yaw=rng.uniform(-0.06, 0.06), offset=(x, MAT_Y + 1.4 + row * 2.85, cz + rng.uniform(-0.3, 0.3))))
    return st, pt


def wall_low(sq, seed):
    return wall(sq, seed, rows=1)


def altar(sq, seed):
    st, pt = _empty()
    cx, cz = centre(sq)
    st.add(gm.box((cx, MAT_Y + 2.0, cz), (4.0, 4.0, 9.0), STONE))
    pt.add(gm.box((cx, MAT_Y + 4.1, cz), (4.4, 0.25, 7.0), sw("altar_cloth")))
    for dz in (-3.0, 0.0, 3.0):
        pt.add(gm.cylinder((cx, MAT_Y + 4.2, cz + dz), 0.35, 0.35, 1.6 + abs(dz) * 0.2, 6, sw("candle")))
        pt.add(gm.sphere((cx, MAT_Y + 6.0 + abs(dz) * 0.2, cz + dz), 0.35, 6, 4, sw("ember")))
    return st, pt


def rubble(sq, seed):
    st, pt = _empty()
    cx, cz = centre(sq)
    rng = np.random.default_rng(seed)
    for k in range(5):
        r = rng.uniform(0.7, 1.4)
        rk = gm.rock((cx + rng.uniform(-1.8, 1.8), MAT_Y + r * 0.3, cz + rng.uniform(-1.8, 1.8)), r, seed + k, STONE)
        st.add(gm.flatten_below(rk, MAT_Y))
    return st, pt


def bar(sq, seed):
    st, pt = _empty()
    xs = [g(x, y)[0] for (x, y) in sq]
    zs = [g(x, y)[1] for (x, y) in sq]
    x0, x1 = min(xs) - 2.3, max(xs) + 2.3
    cz = sum(zs) / len(zs)
    pt.add(gm.box(((x0 + x1) / 2, MAT_Y + 3.0, cz + 0.6), (x1 - x0, 6.0, 3.0), sw("wood_dark")))
    pt.add(gm.box(((x0 + x1) / 2, MAT_Y + 6.2, cz + 0.6), (x1 - x0 + 0.6, 0.5, 3.6), sw("wood_mid")))
    rng = np.random.default_rng(seed)
    for k in range(9):
        x = x0 + 1.5 + k * (x1 - x0 - 3) / 8
        col = ["bottle_green", "bottle_amber", "mug_cream"][k % 3]
        pt.add(gm.cylinder((x, MAT_Y + 6.45, cz + 0.6 + rng.uniform(-0.6, 0.6)), 0.5, 0.4, 2.0, 6, sw(col)))
    return st, pt


def hearth(sq, seed):
    st, pt = _empty()
    cx, cz = centre(sq)
    st.add(gm.box((cx, MAT_Y + 5.0, cz - 1.0), (9.0, 10.0, 3.0), STONE))
    st.add(gm.box((cx, MAT_Y + 10.5, cz - 1.0), (6.0, 3.0, 2.4), STONE))
    pt.add(gm.box((cx, MAT_Y + 2.6, cz + 0.6), (5.0, 4.0, 0.3), sw("chasm")))
    for k, a in enumerate((0.2, 2.0)):
        lg = gm.box((0, 0, 0), (3.6, 0.8, 0.8), sw("log"))
        pt.add(lg.transformed(yaw=a, offset=(cx, MAT_Y + 0.6, cz + 1.2)))
    pt.add(gm.cylinder((cx, MAT_Y, cz + 1.2), 1.2, 0.8, 0.4, 8, sw("ember")))
    return st, pt


def table_round(sq, seed):
    st, pt = _empty()
    cx, cz = centre(sq)
    along_x = len(set(x for x, _ in sq)) > 1
    w, d = (9.0, 4.4) if along_x else (4.4, 9.0)
    top = 4.2
    pt.add(gm.box((cx, MAT_Y + top, cz), (w, 0.7, d), sw("wood_mid")))
    for sx in (-1, 1):
        for sz in (-1, 1):
            pt.add(gm.box((cx + sx * (w / 2 - 0.7), MAT_Y + top / 2, cz + sz * (d / 2 - 0.7)), (0.7, top, 0.7), sw("wood_dark")))
    pt.add(gm.cylinder((cx - (w / 4 if along_x else 0), MAT_Y + top + 0.35, cz - (0 if along_x else d / 4)), 0.7, 0.6, 1.4, 6, sw("mug_red")))
    pt.add(gm.cylinder((cx + (w / 5 if along_x else 0.6), MAT_Y + top + 0.35, cz + (0.5 if along_x else d / 5)), 1.2, 1.2, 0.4, 8, sw("bowl")))
    return st, pt


def barrel(sq, seed):
    st, pt = _empty()
    cx, cz = centre(sq)
    pt.add(gm.cylinder((cx, MAT_Y, cz), 1.7, 1.9, 2.2, 12, sw("barrel")))
    pt.add(gm.cylinder((cx, MAT_Y + 2.2, cz), 1.9, 1.7, 2.2, 12, sw("barrel")))
    for y in (0.6, 2.2, 3.8):
        pt.add(gm.cylinder((cx, MAT_Y + y - 0.2, cz), 1.95, 1.95, 0.4, 12, sw("metal")))
    return st, pt


def stall(sq, seed):
    st, pt = _empty()
    cx, cz = centre(sq)
    awn = ["awning_red", "awning_blue", "awning_yellow"][seed % 3]
    pt.add(gm.box((cx, MAT_Y + 2.0, cz + 2.0), (9.0, 4.0, 3.0), sw("wood_mid")))
    for sx in (-1, 1):
        for sz in (-1, 1):
            pt.add(gm.box((cx + sx * 4.2, MAT_Y + 4.5, cz + sz * 3.8), (0.5, 9.0, 0.5), sw("wood_dark")))
    roof = gm.box((0, 0, 0), (10.0, 0.4, 9.0), sw(awn))
    pt.add(roof.transformed(pitch=0.18, offset=(cx, MAT_Y + 9.2, cz)))
    for k in range(4):
        pt.add(gm.sphere((cx - 3 + k * 2, MAT_Y + 4.5, cz + 2.0), 0.7, 6, 4, sw(["chip", "mug_red", "leaf_c", "hay"][k])))
    return st, pt


def well(sq, seed):
    st, pt = _empty()
    cx, cz = centre(sq)
    st.add(gm.cylinder((cx, MAT_Y, cz), 2.3, 2.3, 2.4, 14, STONE))
    pt.add(gm.cylinder((cx, MAT_Y + 2.3, cz), 1.6, 1.6, 0.15, 14, sw("water")))
    for sx in (-1, 1):
        pt.add(gm.box((cx + sx * 2.0, MAT_Y + 4.5, cz), (0.5, 5.0, 0.5), sw("wood_dark")))
    roof = gm.Mesh()
    for s in (-1, 1):
        roof.add(gm.box((0, 0, 0), (3.2, 0.3, 5.4), sw("wood_mid")).transformed(roll=s * 0.6, offset=(s * 1.2, 0, 0)))
    pt.add(roof.transformed(offset=(cx, MAT_Y + 7.6, cz)))
    return st, pt


def crate(sq, seed):
    st, pt = _empty()
    cx, cz = centre(sq)
    pt.add(gm.box((0, 1.6, 0), (3.4, 3.2, 3.4), sw("crate")).transformed(yaw=seed * 0.3, offset=(cx, MAT_Y, cz)))
    pt.add(gm.box((cx + 0.6, MAT_Y + 3.9, cz - 0.4), (2.2, 1.6, 2.2), sw("crate")))
    return st, pt


def cart(sq, seed):
    st, pt = _empty()
    cx, cz = centre(sq)
    pt.add(gm.box((cx, MAT_Y + 3.0, cz), (8.0, 1.6, 4.4), sw("wood_mid")))
    pt.add(gm.box((cx, MAT_Y + 4.4, cz), (7.0, 1.4, 3.6), sw("hay")))
    for sx in (-1, 1):
        for sz in (-1, 1):
            wh = gm.cylinder((0, -0.3, 0), 1.6, 1.6, 0.6, 12, sw("wood_dark"))
            pt.add(wh.transformed(pitch=math.pi / 2, offset=(cx + sx * 2.8, MAT_Y + 1.6, cz + sz * 2.5)))
    return st, pt


def gorge(sq, seed):
    st, pt = _empty()
    xs = sorted(set(x for x, _ in sq))
    x0 = g(xs[0], 1)[0] - 2.5
    x1 = g(xs[-1], 1)[0] + 2.5
    # the chasm: dark ground split by the bridge rows
    rows = sorted(set(y for _, y in sq))
    runs, start = [], rows[0]
    for a, b in zip(rows, rows[1:] + [None]):
        if b != a + 1:
            runs.append((start, a))
            if b is not None:
                start = b
    rng = np.random.default_rng(seed)
    for (y0, y1) in runs:
        z0 = g(1, y0)[1] - 2.5
        z1 = g(1, y1)[1] + 2.5
        pt.add(gm.plane_xz((x0 + x1) / 2, MAT_Y + 0.08, (z0 + z1) / 2, x1 - x0, z1 - z0, gm.swatch(PAL("chasm"))))
        for edge in (x0, x1):
            z = z0 + 1.5
            while z < z1:
                r = rng.uniform(0.8, 1.4)
                rk = gm.rock((edge, MAT_Y + r * 0.3, z), r, int(seed + z * 3 + edge), STONE)
                st.add(gm.flatten_below(rk, MAT_Y))
                z += rng.uniform(2.0, 3.2)
    return st, pt


def rope_bridge(sq, seed):
    st, pt = _empty()
    x0 = g(9, 1)[0] - 3.5
    x1 = g(11, 1)[0] + 3.5
    z0 = g(1, 6)[1] - 2.3
    z1 = g(1, 8)[1] + 2.3
    n = int((x1 - x0) / 1.4)
    for k in range(n):
        x = x0 + 0.7 + k * 1.4
        pt.add(gm.box((x, MAT_Y + 0.5, (z0 + z1) / 2), (1.1, 0.3, z1 - z0), sw("wood_mid")))
    for z in (z0, z1):
        pt.add(gm.box(((x0 + x1) / 2, MAT_Y + 2.2, z), (x1 - x0, 0.25, 0.25), sw("rope")))
        for x in (x0, x1):
            pt.add(gm.box((x, MAT_Y + 1.4, z), (0.6, 2.8, 0.6), sw("wood_dark")))
    return st, pt


BUILDERS = {
    "campfire": campfire, "tent": tent, "log_seat": log_seat, "rock": rock, "pine": pine, "oak": oak, "totem": totem,
    "fallen_log": fallen_log, "bush": bush, "pillar": pillar, "broken_pillar": broken_pillar, "wall": wall,
    "wall_low": wall_low, "altar": altar, "rubble": rubble, "bar": bar, "hearth": hearth, "table_round": table_round,
    "barrel": barrel, "stall": stall, "well": well, "crate": crate, "cart": cart, "gorge": gorge,
    "rope_bridge": rope_bridge,
}

# Floor overlays covering the whole mat: (texture, tile size in cm)
FLOORS = {"floorboards": ("wood_floor.png", 30.0), "cobbles": ("stone.png", 8.0), "flagstones": ("stone.png", 14.0)}


def build(name):
    """Meshes for one set: {'stone': Mesh, 'paint': Mesh, 'floor': (Mesh, texture)}."""
    s = SETS[name]
    stone, paint, floor = gm.Mesh(), gm.Mesh(), None
    for i, (kind, squares) in enumerate(s["pieces"]):
        if kind in FLOORS:
            tex, tile = FLOORS[kind]
            floor = (gm.plane_xz(MAT_X0 + 50, MAT_Y + 0.04, MAT_Z0 + 32.5, 100, 65, gm.triplanar(tile)), tex)
            continue
        fn = BUILDERS.get(kind)
        if not fn:
            continue
        seed = (sum(map(ord, name)) * 31 + i * 7) % 1000
        st, pt = fn(squares or [(10, 7)], seed)
        stone.add(st)
        paint.add(pt)
    return {"stone": stone, "paint": paint, "floor": floor}


# Where the table puts a fire light (and the flame sprite) for each set, and how bright.
def fire_spot(name):
    s = SETS[name]
    for kind, squares in s["pieces"]:
        if kind == "campfire":
            x, z = centre(squares)
            return (x, MAT_Y + 1.0, z), 1.0
        if kind == "hearth":
            x, z = centre(squares)
            return (x, MAT_Y + 1.0, z + 1.2), 0.75
        if kind == "altar":
            x, z = centre(squares)
            return (x, MAT_Y + 6.0, z), 0.0
    return None, 0.0
