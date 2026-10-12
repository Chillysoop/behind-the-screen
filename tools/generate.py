#!/usr/bin/env python3
"""Generate every asset and scene file for the Behind the Screen M0 spike.

    python3 tools/generate.py

Writes meshes (.glb), painted textures and sprites, and the Defold files that
place them (main/main.collection, props, minis, people, lamp, dice). Hand-written
code (scripts, materials, render script, HUD) is left alone, except that the
shared lighting block in materials/lit.fp is copied into materials/standee.fp.

Units are centimetres. The table top is at y = 75. The DM sits at +z.
"""
import json
import math
import os
import re

import numpy as np

import gen_meshes as gm
import gen_sprites
import gen_sprites_m4
import gen_terrain
import gen_textures as gt
import gen_ui
import terrain_layout
from gen_common import ROOT, path

# ----------------------------------------------------------------- layout

TABLE_Y = 75.0
MAT_Y = TABLE_Y + 0.15
MAT_X0, MAT_Z0, MAT_W, MAT_H = -56.0, -34.5, 100.0, 65.0
BASE_TOP = MAT_Y + 0.6
TRAY = dict(cx=60.0, cz=33.0, w=24.0, d=18.0, wall=1.2, h=4.0, base=0.6)
FELT_Y = TABLE_Y + TRAY["base"] + 0.02
# Dice trays (A9): one at every player's seat, and two for the DM: an open box in front of the
# screen, where the table sees the die, and a tray behind it, where only the DM does.
# name -> (centre x, centre z, width along x, depth along z); a throw runs along the longer side.
TRAYS = {
    "dm_open": (-12.0, 35.5, 24.0, 8.0),
    "dm_hidden": (-12.0, 45.8, 18.0, 7.2),
    "dev": (-66.0, 8.0, 12.0, 15.0),
    "mara": (-22.0, -43.0, 16.0, 11.0),
    "jess": (14.0, -43.0, 16.0, 11.0),
    "sam": (62.0, 18.0, 14.0, 14.0),
}
TRAY_WALL, TRAY_H, TRAY_BASE = 1.0, 3.2, 0.6
# Where the camera looks from for each tray: the DM's side, except the open box, which the
# table sees from theirs.
TRAY_VIEW = {"dm_open": (0.0, 40.0, -42.0)}
TRAY_VIEW_DEFAULT = (-2.0, 42.0, 45.0)
LAMP_PIVOT = (0.0, 290.0, -5.0)
BULB_OFFSET = (0.0, -125.0, 0.0)
D20_RADIUS = 2.3


def sq(i, j):
    """Centre of battle-mat square (i, j); squares are 5 cm."""
    return (MAT_X0 + 2.5 + 5 * i, MAT_Z0 + 2.5 + 5 * j)


FIRE = sq(6, 5)
MINIS = [  # name, square, base colour swatch
    ("fighter", sq(8, 6), "rim_fighter"),
    ("wizard", sq(4, 4), "rim_wizard"),
    ("cleric", sq(5, 3), "rim_cleric"),
    ("rogue", sq(10, 3), "rim_rogue"),
    ("goblin_spear", sq(13, 2), "rim_goblin"),
    ("goblin_club", sq(14, 4), "rim_goblin"),
]
MINI_SCALE = 0.031
MINI_PX = (256, 320)
PEOPLE = [  # name, (x, z)
    ("dev", (-106.0, -6.0)),
    ("mara", (-38.0, -80.0)),
    ("jess", (34.0, -80.0)),
    ("sam", (106.0, -14.0)),
]
PERSON_SCALE = 0.21
# Whole bodies on chairs (A9): the standee reaches the floor, the head where it always was.
PERSON_PX = (300, 655)
PERSON_BOTTOM = 0.0

PRESETS = [
    dict(name="Room", eye=(232.0, 212.0, 290.0), target=(-8.0, 84.0, -24.0), fov=42.0, drift=2.0),
    dict(name="Table", eye=(-4.0, 160.0, 110.0), target=(-4.0, 75.0, -6.0), fov=46.0, drift=0.8),
    dict(name="Imagination", eye=(-33.0, 90.0, 24.0), target=(8.0, 79.0, -16.0), fov=40.0, drift=0.25),
    dict(name="Dice tray", eye=(58.0, 118.0, 78.0), target=(60.0, 76.0, 33.0), fov=30.0, drift=0.15),
]
LARGE = {"ogre": 1.45, "dire_wolf": 1.3, "npc_ghost": 1.0}

PAL = gt.palette_uv

# ----------------------------------------------------------------- props


def room():
    floor = gm.plane_xz(50, 0, 60, 700, 640, gm.triplanar(120))
    walls = gm.Mesh()
    walls.add(gm.quad_uv([(-300, 0, -260), (400, 0, -260), (400, 300, -260), (-300, 300, -260)], (0, 0, 1),
                         [(-300 / 120, 300 / 120), (400 / 120, 300 / 120), (400 / 120, 0), (-300 / 120, 0)]))
    walls.add(gm.quad_uv([(-300, 0, 380), (-300, 0, -260), (-300, 300, -260), (-300, 300, 380)], (1, 0, 0),
                         [(380 / 120, 300 / 120), (-260 / 120, 300 / 120), (-260 / 120, 0), (380 / 120, 0)]))
    base = gm.Mesh()
    sw = gm.swatch(PAL("baseboard"))
    base.add(gm.box((50, 6, -259), (700, 12, 2), sw))
    base.add(gm.box((-299, 6, 60), (2, 12, 640), sw))
    return floor, walls, base


def window():
    frame = gm.Mesh()
    sw = gm.swatch(PAL("frame"))
    cx, cy, z = 70.0, 155.0, -259.0
    w, h, t = 100.0, 120.0, 7.0
    frame.add(gm.box((cx, cy + h / 2 + 3.5, z + 2), (w + 14, 7, 6), sw))
    frame.add(gm.box((cx, cy - h / 2 - 3.5, z + 2), (w + 14, 7, 6), sw))
    frame.add(gm.box((cx - w / 2 - 3.5, cy, z + 2), (7, h, 6), sw))
    frame.add(gm.box((cx + w / 2 + 3.5, cy, z + 2), (7, h, 6), sw))
    frame.add(gm.box((cx, cy - h / 2 - 8, z + 7), (w + 24, 3, 14), sw))  # sill
    glass = gm.quad_uv([(cx - w / 2, cy - h / 2, z + 0.5), (cx + w / 2, cy - h / 2, z + 0.5),
                        (cx + w / 2, cy + h / 2, z + 0.5), (cx - w / 2, cy + h / 2, z + 0.5)], (0, 0, 1),
                       [(0, 1), (1, 1), (1, 0), (0, 0)])
    return frame, glass


def table():
    m = gm.Mesh()
    wood = gm.triplanar(60)
    m.add(gm.box((0, TABLE_Y - 2.5, 0), (150, 5, 100), wood))
    for sx in (-1, 1):
        for sz in (-1, 1):
            m.add(gm.box((sx * 68, (TABLE_Y - 5) / 2, sz * 43), (7, TABLE_Y - 5, 7), wood))
    m.add(gm.box((0, TABLE_Y - 9, -46.5), (130, 8, 3), wood))
    m.add(gm.box((0, TABLE_Y - 9, 46.5), (130, 8, 3), wood))
    m.add(gm.box((-71.5, TABLE_Y - 9, 0), (3, 8, 80), wood))
    m.add(gm.box((71.5, TABLE_Y - 9, 0), (3, 8, 80), wood))
    return m


def mat():
    return gm.plane_xz(MAT_X0 + MAT_W / 2, MAT_Y, MAT_Z0 + MAT_H / 2, MAT_W, MAT_H,
                       gm.rect_uv(MAT_X0, MAT_Z0, MAT_W, MAT_H))


def rug():
    return gm.plane_xz(0, 0.25, 0, 290, 220, gm.rect_uv(-145, -110, 290, 220))


def tray():
    """Every dice tray (A9): wooden walls and a felt floor, all in one mesh each."""
    wood = gm.triplanar(30)
    m, felt = gm.Mesh(), gm.Mesh()
    wl, h, base = TRAY_WALL, TRAY_H, TRAY_BASE
    for (cx, cz, tw, td) in TRAYS.values():
        m.add(gm.box((cx, TABLE_Y + base / 2, cz), (tw, base, td), wood))
        hy = TABLE_Y + h / 2
        m.add(gm.box((cx, hy, cz - td / 2 + wl / 2), (tw, h, wl), wood))
        m.add(gm.box((cx, hy, cz + td / 2 - wl / 2), (tw, h, wl), wood))
        m.add(gm.box((cx - tw / 2 + wl / 2, hy, cz), (wl, h, td - 2 * wl), wood))
        m.add(gm.box((cx + tw / 2 - wl / 2, hy, cz), (wl, h, td - 2 * wl), wood))
        felt.add(gm.plane_xz(cx, FELT_Y, cz, tw - 2 * wl, td - 2 * wl, gm.triplanar(12)))
    return m, felt


def tray_physics():
    """The trays' floors and tall invisible walls, so a thrown die stays in its tray."""
    boxes = []
    for (cx, cz, tw, td) in TRAYS.values():
        ix0, ix1 = cx - tw / 2 + TRAY_WALL, cx + tw / 2 - TRAY_WALL
        iz0, iz1 = cz - td / 2 + TRAY_WALL, cz + td / 2 - TRAY_WALL
        boxes += [
            ((cx, FELT_Y - 2, cz), (tw / 2, 2, td / 2)),
            ((ix0 - 3, TABLE_Y + 12, cz), (3, 12, td / 2 + 3)),
            ((ix1 + 3, TABLE_Y + 12, cz), (3, 12, td / 2 + 3)),
            ((cx, TABLE_Y + 12, iz0 - 3), (tw / 2 + 3, 12, 3)),
            ((cx, TABLE_Y + 12, iz1 + 3), (tw / 2 + 3, 12, 3)),
        ]
    return boxes


def trays_lua():
    """scene_data's trays: where each is, where a die is thrown from and how, and the camera."""
    lines = ["    -- dice trays (A9): a player's at their seat; the DM's open box and hidden tray",
             "    trays = {"]
    for name, (cx, cz, tw, td) in TRAYS.items():
        along_x = tw >= td
        long = tw if along_x else td
        if along_x:
            spawn = (cx - long / 3, TABLE_Y + 12.0, cz)
            throw = (long * 3.2, -18.0, 0.0)
        else:
            spawn = (cx, TABLE_Y + 12.0, cz - long / 3)
            throw = (0.0, -18.0, long * 3.2)
        if name in TRAY_VIEW or name.startswith("dm_"):
            off = TRAY_VIEW.get(name, TRAY_VIEW_DEFAULT)
        else:
            # A player's tray is seen from the middle of the table, the player behind it.
            k = math.hypot(cx, cz) or 1.0
            off = (-cx / k * 30.0, 38.0, -cz / k * 30.0)
        eye = (cx + off[0], TABLE_Y + off[1], cz + off[2])
        lines.append(f"        {name} = {{ pos = {lua_vec((cx, FELT_Y, cz))}, w = {fmt(tw)}, d = {fmt(td)}, "
                     f"spawn = {lua_vec(spawn)}, throw = {lua_vec(throw)}, "
                     f"eye = {lua_vec(eye)}, target = {lua_vec((cx, TABLE_Y + 1.0, cz))} }},")
    lines.append("    },")
    return lines


def screen_panel(width, height, thick, u_outer, u_inner):
    """A DM-screen panel built in local space: +z faces the DM, -z the players."""
    m = gm.Mesh()
    w2, t2 = width / 2, thick / 2
    edge = (0.004, 0.5)
    for (n, z, (ua, ub), mirror) in [((0, 0, 1), t2, u_inner, False), ((0, 0, -1), -t2, u_outer, True)]:
        ps, uvs = [], []
        for (x, y) in [(-w2, 0), (w2, 0), (w2, height), (-w2, height)]:
            ps.append((x, y, z))
            f = (w2 - x) / width if mirror else (x + w2) / width
            uvs.append((ua + f * (ub - ua), 1 - y / height))
        m.quad(ps, [n] * 4, uvs)
    e = gm.box((0, height / 2, 0), (width, height, thick), lambda p, n: edge, skip=("+z", "-z"))
    return m.add(e)


def dm_screen():
    m = gm.Mesh()
    zc, H, T = 41.0, 22.0, 0.8
    pts = [(-40.1, 49.5), (-22.0, zc), (-2.0, zc), (16.1, 49.5)]  # left to right as the DM sees it
    for k in range(3):
        (ax, az), (bx, bz) = pts[k], pts[k + 1]
        width = math.hypot(bx - ax, bz - az)
        yaw = math.atan2(-(bz - az), bx - ax)
        inner = (0.5 + k / 6, 0.5 + (k + 1) / 6)
        outer = ((2 - k) / 6, (3 - k) / 6)
        panel = screen_panel(width - 0.4, H, T, outer, inner)
        m.add(panel.transformed(yaw=yaw, offset=((ax + bx) / 2, TABLE_Y, (az + bz) / 2)))
    return m


def sheets():
    m = gm.Mesh()
    for (x, z, yaw) in [(-66.0, -8.0, math.pi / 2), (-40.0, -43.0, math.pi), (30.0, -43.0, math.pi),
                        (64.0, -10.0, -math.pi / 2)]:
        q = gm.quad_uv([(-7, 0, -5.5), (7, 0, -5.5), (7, 0, 5.5), (-7, 0, 5.5)], (0, 1, 0),
                       [(0, 0), (1, 0), (1, 1), (0, 1)])
        m.add(q.transformed(yaw=yaw, offset=(x, TABLE_Y + 0.12, z)))
    return m


def mug(x, z, colour, rng):
    m = gm.Mesh()
    sw = gm.swatch(PAL(colour))
    m.add(gm.cylinder((x, TABLE_Y, z), 4.0, 4.2, 9.5, 18, sw, caps=(True, False)))
    m.add(gm.cylinder((x, TABLE_Y + 0.6, z), 3.6, 3.8, 8.9, 18, sw, caps=(False, False), inside=True))
    m.add(gm.cylinder((x, TABLE_Y + 9.5, z), 4.2, 3.8, 0.01, 18, sw, caps=(False, False)))
    m.add(gm.cylinder((x, TABLE_Y + 7.4, z), 3.6, 3.6, 0.01, 18, gm.swatch(PAL("coffee")), caps=(False, True)))
    m.add(gm.box((x + 4.8, TABLE_Y + 5, z), (1.6, 5, 1.4), sw))
    return m


def tableware():
    rng = np.random.default_rng(5)
    m = gm.Mesh()
    m.add(mug(-66.0, 22.0, "mug_teal", rng))
    m.add(mug(-60.0, -42.0, "mug_red", rng))
    m.add(mug(66.0, 6.0, "mug_cream", rng))
    # the snack bowl (the chips in it are their own model: see chips())
    bx, bz = BOWL
    sw = gm.swatch(PAL("bowl"))
    m.add(gm.cylinder((bx, TABLE_Y, bz), 6.5, 11.0, 5.5, 22, sw, caps=(True, False)))
    m.add(gm.cylinder((bx, TABLE_Y + 0.6, bz), 6.0, 10.4, 4.9, 22, sw, caps=(False, False), inside=True))
    m.add(gm.cylinder((bx, TABLE_Y + 5.5, bz), 11.0, 10.4, 0.01, 22, sw, caps=(False, False)))
    # pencils and stray dice
    for (x, z, yaw) in [(-62.0, -2.0, 0.4), (-44.0, -38.0, 1.9), (40.0, -40.0, 2.6), (62.0, -22.0, -0.3)]:
        p = gm.box((0, 0, 0), (12, 0.8, 0.8), gm.swatch(PAL("pencil")))
        m.add(p.transformed(yaw=yaw, offset=(x, TABLE_Y + 0.4, z)))
    for (x, z, c, yaw) in [(-70.0, -24.0, "dice_red", 0.3), (70.0, -28.0, "dice_blue", 0.8), (50.0, 40.0, "dice_red", 1.2)]:
        d = gm.box((0, 0, 0), (1.8, 1.8, 1.8), gm.swatch(PAL(c)))
        m.add(d.transformed(yaw=yaw, offset=(x, TABLE_Y + 0.9, z)))
    return m


# ------------------------------------------------------------------ the snack table (M7)
# The chips and the pizza are separate models so the table can eat them: the chips
# sink in the bowl and the slices go one by one over game night, and both come back
# for the next session (main/snacks/snacks.script). Both are built around their own
# origin: CHIPS_ORIGIN is the inside floor of the bowl, PLATE the middle of the plate.

BOWL = (-60.0, 40.0)
CHIPS_ORIGIN = (BOWL[0], TABLE_Y + 0.6, BOWL[1])
PLATE = (58.0, TABLE_Y, -38.0)
PIZZA_SLICES = 6


def chips():
    rng = np.random.default_rng(5)
    m = gm.Mesh()
    sw = gm.swatch(PAL("chip"))
    heap = gm.rock((0.0, 3.0, 0.0), 8.6, 77, sw, squash=0.32)
    m.add(gm.flatten_below(heap, 0.4))
    for k in range(22):
        a, r = rng.uniform(0, 2 * math.pi), rng.uniform(0, 7.0)
        chip = gm.box((0, 0, 0), (2.4, 0.2, 1.8), sw)
        m.add(chip.transformed(yaw=rng.uniform(0, 6.3), pitch=rng.uniform(-0.6, 0.6), roll=rng.uniform(-0.5, 0.5),
                               offset=(math.cos(a) * r, 5.0 + (7.0 - r) * 0.22 + rng.uniform(0, 0.6), math.sin(a) * r)))
    return m


def plate():
    sw = gm.swatch(PAL("mug_cream"))
    m = gm.Mesh()
    m.add(gm.cylinder((0, 0, 0), 7.0, 9.5, 0.9, 28, sw, caps=(True, True)))
    m.add(gm.cylinder((0, 0.9, 0), 9.5, 10.0, 0.01, 28, sw, caps=(False, False)))
    return m


def wedge(r0, r1, a0, a1, y0, y1, uvf, seg=4, top=True):
    """A slice of a ring: radii r0..r1, angles a0..a1, from y0 up to y1."""
    m = gm.Mesh()
    angles = [a0 + (a1 - a0) * i / seg for i in range(seg + 1)]
    def pt(r, a, y):
        return np.array((math.cos(a) * r, y, math.sin(a) * r))
    up = np.array((0.0, 1.0, 0.0))
    for i in range(seg):
        aa, ab = angles[i], angles[i + 1]
        am = (aa + ab) / 2
        out_n = np.array((math.cos(am), 0.0, math.sin(am)))
        ps = [pt(r1, aa, y0), pt(r1, ab, y0), pt(r1, ab, y1), pt(r1, aa, y1)]
        m.quad(ps, [out_n] * 4, [uvf(p, out_n) for p in ps])
        if top:
            ps = [pt(r0, aa, y1), pt(r1, aa, y1), pt(r1, ab, y1), pt(r0, ab, y1)]
            if r0 <= 1e-6:
                m.tri([ps[0], ps[1], ps[2]], [up] * 3, [uvf(p, up) for p in ps[:3]])
            else:
                m.quad(ps, [up] * 4, [uvf(p, up) for p in ps])
        if r0 > 1e-6:
            in_n = -out_n
            ps = [pt(r0, aa, y0), pt(r0, ab, y0), pt(r0, ab, y1), pt(r0, aa, y1)]
            m.quad(ps, [in_n] * 4, [uvf(p, in_n) for p in ps])
    for a, sgn in ((a0, -1.0), (a1, 1.0)):
        n = np.array((-math.sin(a), 0.0, math.cos(a))) * sgn
        ps = [pt(r0, a, y0), pt(r1, a, y0), pt(r1, a, y1), pt(r0, a, y1)]
        m.quad(ps, [n] * 4, [uvf(p, n) for p in ps])
    return m


def pizza_slice(k):
    """Slice k of PIZZA_SLICES, on the plate: cheese, a crust rim and a couple of pepperoni."""
    rng = np.random.default_rng(40 + k)
    gap = 0.05
    a0 = 2 * math.pi * k / PIZZA_SLICES + gap
    a1 = 2 * math.pi * (k + 1) / PIZZA_SLICES - gap
    base = 0.9
    m = gm.Mesh()
    m.add(wedge(0.0, 6.6, a0, a1, base, base + 0.55, gm.swatch(PAL("chip"))))
    m.add(wedge(6.6, 7.8, a0, a1, base, base + 1.0, gm.swatch(PAL("log_end"))))
    for j in range(2):
        a = rng.uniform(a0 + 0.2, a1 - 0.2)
        r = 2.6 + j * 2.2 + rng.uniform(-0.3, 0.3)
        m.add(gm.cylinder((math.cos(a) * r, base + 0.55, math.sin(a) * r), 0.95, 0.95, 0.12, 10,
                          gm.swatch(PAL("mug_red")), caps=(False, True)))
    return m


def terrain():
    stone = gm.triplanar(12)
    rocks = gm.Mesh()
    for (x, z, r, s) in [(22.0, -28.0, 4.2, 1), (27.5, -23.5, 3.0, 2), (18.5, -31.0, 2.4, 3), (32.0, -28.0, 2.0, 4),
                         (40.0, -14.0, 2.6, 5), (-48.0, 22.0, 3.0, 6), (-6.0, 22.0, 1.8, 7)]:
        rk = gm.rock((x, MAT_Y + r * 0.35, z), r, s, stone)
        rocks.add(gm.flatten_below(rk, MAT_Y))
    # campfire ring
    fx, fz = FIRE
    for k in range(9):
        a = k / 9 * 2 * math.pi
        rk = gm.rock((fx + math.cos(a) * 3.6, MAT_Y + 0.45, fz + math.sin(a) * 3.6), 1.1, 20 + k, stone, squash=0.8)
        rocks.add(gm.flatten_below(rk, MAT_Y))
    # ruined wall
    ruin = gm.Mesh()
    rng = np.random.default_rng(9)
    for row in range(3):
        n_blocks = [4, 3, 1][row]
        for b in range(n_blocks):
            x = 25.0 + b * 4.6 + (2.3 if row % 2 else 0) + rng.uniform(-0.3, 0.3)
            blk = gm.box((0, 0, 0), (4.3, 3.0, 3.4), stone)
            ruin.add(blk.transformed(yaw=rng.uniform(-0.08, 0.08),
                                     offset=(x, MAT_Y + 1.5 + row * 3.05, -3.0 + rng.uniform(-0.3, 0.3))))
    fallen = gm.box((0, 0, 0), (4.3, 3.0, 3.4), stone)
    ruin.add(fallen.transformed(yaw=0.7, roll=0.15, offset=(31.0, MAT_Y + 1.5, 2.5)))
    # trees
    trees = gm.Mesh()
    tx, tz = -50.0, -15.0
    trees.add(gm.cylinder((tx, MAT_Y, tz), 1.3, 1.0, 7, 8, gm.swatch(PAL("bark"))))
    for (y0, r, h, c) in [(5, 7.0, 9, "leaf_b"), (10, 5.5, 8, "leaf_a"), (15, 3.8, 7, "leaf_c")]:
        trees.add(gm.cylinder((tx, MAT_Y + y0, tz), r, 0.0, h, 9, gm.swatch(PAL(c)), smooth=False))
    bx, bz = 38.0, -27.0
    trees.add(gm.cylinder((bx, MAT_Y, bz), 1.0, 0.8, 4, 8, gm.swatch(PAL("bark"))))
    for (dx, dy, dz, r, c, s) in [(0, 7, 0, 4.5, "leaf_a", 31), (2.5, 5.5, 1.5, 3.4, "leaf_b", 32), (-2.5, 6, -1, 3.2, "leaf_c", 33)]:
        trees.add(gm.rock((bx + dx, MAT_Y + dy, bz + dz), r, s, gm.swatch(PAL(c)), squash=0.9))
    # campfire logs
    logs = gm.Mesh()
    for k, a in enumerate((0.3, 1.35, 2.4)):
        lg = gm.box((0, 0, 0), (6.0, 1.1, 1.1), gm.swatch(PAL("log")))
        logs.add(lg.transformed(yaw=a, roll=0.18 * (1 if k % 2 else -1), offset=(fx, MAT_Y + 0.9, fz)))
    return rocks, ruin, trees, logs


def bases():
    m = gm.Mesh()
    for (name, (x, z), sw) in MINIS:
        m.add(gm.cylinder((x, MAT_Y, z), 2.25, 2.1, 0.6, 20, gm.swatch(PAL(sw))))
        m.add(gm.cylinder((x, MAT_Y + 0.6, z), 1.6, 1.6, 0.01, 20, gm.swatch(PAL("base")), caps=(False, True)))
    return m


def bookshelf():
    m = gm.Mesh()
    sw = gm.swatch(PAL("shelf"))
    x0, z0, z1, H, D = -300.0, -190.0, -90.0, 200.0, 30.0
    xc, zc = x0 + D / 2, (z0 + z1) / 2
    m.add(gm.box((xc, H / 2, z0 + 1.5), (D, H, 3), sw))
    m.add(gm.box((xc, H / 2, z1 - 1.5), (D, H, 3), sw))
    m.add(gm.box((x0 + 1, H / 2, zc), (2, H, z1 - z0), sw))
    rng = np.random.default_rng(13)
    books = ["book_a", "book_b", "book_c", "book_d", "book_e", "book_f"]
    for k, y in enumerate([2.0, 50.0, 98.0, 146.0, 194.0]):
        m.add(gm.box((xc, y, zc), (D, 3, z1 - z0 - 6), sw))
        if y > 190:
            break
        z = z0 + 4.0
        while z < z1 - 8:
            bw = rng.uniform(2.5, 5.0)
            bh = rng.uniform(26, 40)
            lean = rng.uniform(-0.12, 0.12) if rng.random() < 0.15 else 0.0
            b = gm.box((0, bh / 2, 0), (rng.uniform(20, 25), bh, bw), gm.swatch(PAL(books[rng.integers(0, 6)])))
            m.add(b.transformed(roll=0, pitch=lean, offset=(x0 + 14, y + 1.5, z + bw / 2)))
            z += bw + rng.uniform(0.1, 0.6)
            if rng.random() < 0.08:
                z += rng.uniform(6, 12)
    return m


def plant():
    m = gm.Mesh()
    x, z = 185.0, -228.0
    m.add(gm.cylinder((x, 0, z), 15, 19, 34, 16, gm.swatch(PAL("pot"))))
    for (dx, dy, dz, r, s) in [(0, 52, 0, 22, 41), (12, 44, 8, 15, 42), (-12, 46, -6, 16, 43), (4, 64, -4, 14, 44)]:
        m.add(gm.rock((x + dx, dy, z + dz), r, s, gm.swatch(PAL("plant")), squash=0.95))
    return m


def fairy_lights():
    m = gm.Mesh()
    hooks = np.linspace(-290, 395, 7)
    for a, b in zip(hooks[:-1], hooks[1:]):
        for k in range(8):
            t = (k + 0.5) / 8
            x = a + (b - a) * t
            y = 246 - 16 * (1 - (2 * t - 1) ** 2)
            c = "fairy" if k % 2 else "fairy_b"
            m.add(gm.sphere((x, y, -256.5), 1.5, 8, 6, gm.swatch(PAL(c))))
    return m


def lamp_parts():
    body, bulb = gm.Mesh(), gm.Mesh()
    body.add(gm.cylinder((0, -108, 0), 0.45, 0.45, 108, 8, gm.swatch(PAL("cord")), caps=(False, False)))
    body.add(gm.cylinder((0, -113, 0), 3.2, 2.4, 5, 14, gm.swatch(PAL("brass"))))
    body.add(gm.cylinder((0, -130, 0), 24, 6, 18, 28, gm.swatch(PAL("lamp_shade")), caps=(False, False)))
    body.add(gm.cylinder((0, -130, 0), 23.6, 5.8, 17.6, 28, gm.swatch(PAL("lamp_shade_in")), caps=(False, False),
                         inside=True))
    body.add(gm.cylinder((0, -130.6, 0), 24.4, 24.4, 0.8, 28, gm.swatch(PAL("brass")), caps=(False, False)))
    body.add(gm.cylinder((0, -112.01, 0), 6.0, 2.8, 0.01, 28, gm.swatch(PAL("lamp_shade")), caps=(False, False)))
    bulb.add(gm.sphere((0, -125, 0), 4.6, 14, 10, gm.swatch(PAL("bulb"))))
    return body, bulb


def blob_quad():
    return gm.quad_uv([(-0.5, 0, -0.5), (0.5, 0, -0.5), (0.5, 0, 0.5), (-0.5, 0, 0.5)], (0, 1, 0),
                      [(0, 0), (1, 0), (1, 1), (0, 1)])


def d20():
    """Icosahedron with numbered faces; opposite faces sum to 21."""
    V, F = gm.icosahedron()
    faces = []
    for (a, b, c) in F:
        pa, pb, pc = V[a], V[b], V[c]
        n = np.cross(pb - pa, pc - pa)
        if np.dot(n, pa + pb + pc) < 0:
            b, c = c, b
            pa, pb, pc = V[a], V[b], V[c]
            n = -n
        faces.append(((pa, pb, pc), n / np.linalg.norm(n)))
    numbers = [0] * 20
    used = set()
    k = 1
    order = sorted(range(20), key=lambda i: (-faces[i][1][1], math.atan2(faces[i][1][2], faces[i][1][0])))
    for i in order:
        if i in used:
            continue
        opp = min((j for j in range(20) if j != i and j not in used),
                  key=lambda j: np.dot(faces[i][1], faces[j][1]))
        numbers[i], numbers[opp] = 21 - k, k
        used.update((i, opp))
        k += 1
    m = gm.Mesh()
    tex_faces, lua_faces = [], []
    cw, ch = 512 / 5, 512 / 4
    for idx, ((pa, pb, pc), n) in enumerate(faces):
        col, row = idx % 5, idx // 5
        cx, cy = (col + 0.5) * cw, (row + 0.5) * ch + 4
        A, B, C = (cx - 46, cy + 40), (cx + 46, cy + 40), (cx, cy - 40)
        tex_faces.append((numbers[idx], (A, B, C)))
        uv = [(A[0] / 512, A[1] / 512), (B[0] / 512, B[1] / 512), (C[0] / 512, C[1] / 512)]
        m.tri([pa * D20_RADIUS, pb * D20_RADIUS, pc * D20_RADIUS], [n, n, n], uv)
        lua_faces.append((float(n[0]), float(n[1]), float(n[2]), numbers[idx]))
    hull = [tuple(float(x) for x in v * D20_RADIUS) for v in V]
    return m, tex_faces, lua_faces, hull


# ----------------------------------------------------------------- Defold writers

def w(rel, text):
    with open(path(rel), "w", newline="\n") as f:
        f.write(text)


def fmt(x):
    return repr(round(float(x), 4))


def vec(name, v, indent="  "):
    keys = "xyzw"
    inner = "".join(f"{indent}  {keys[i]}: {fmt(c)}\n" for i, c in enumerate(v))
    return f"{indent}{name} {{\n{inner}{indent}}}\n"


def model_file(mesh_name, texture, material="/materials/lit.material", sampler="tex0"):
    return (f'mesh: "/assets/meshes/{mesh_name}.glb"\nname: "{{{{NAME}}}}"\n'
            f'materials {{\n  name: "default"\n  material: "{material}"\n'
            f'  textures {{\n    sampler: "{sampler}"\n    texture: "{texture}"\n  }}\n}}\n')


def sprite_file(anim, material, atlas="/assets/sprites/sprites.atlas"):
    return (f'default_animation: "{anim}"\nmaterial: "{material}"\n'
            f'textures {{\n  sampler: "texture_sampler"\n  texture: "{atlas}"\n}}\n')


def go_file(components):
    out = ""
    for cid, comp in components:
        out += f'components {{\n  id: "{cid}"\n  component: "{comp}"\n}}\n'
    return out


def instance(iid, proto, pos=(0, 0, 0), rot=(0, 0, 0, 1), scale=1.0):
    s = scale if isinstance(scale, (tuple, list)) else (scale, scale, scale)
    return (f'instances {{\n  id: "{iid}"\n  prototype: "{proto}"\n' + vec("position", pos) + vec("rotation", rot)
            + vec("scale3", s) + "}\n")


def box_shapes(boxes):
    shapes, data = "", ""
    for i, (c, half) in enumerate(boxes):
        shapes += ("  shapes {\n    shape_type: TYPE_BOX\n" + vec("position", c, "    ")
                   + vec("rotation", (0, 0, 0, 1), "    ") + f"    index: {i * 3}\n    count: 3\n  }}\n")
        data += "".join(f"  data: {fmt(v)}\n" for v in half)
    return "embedded_collision_shape {\n" + shapes + data + "}\n"


def lua_vec(v):
    return "vmath.vector3(" + ", ".join(fmt(x) for x in v) + ")"


# ----------------------------------------------------------------- main

def sync_shaders():
    src = open(path("materials/lit.fp")).read()
    block = re.search(r"// BEGIN LIGHTING\n.*?// END LIGHTING", src, re.S).group(0)
    dst_path = path("materials/standee.fp")
    dst = open(dst_path).read()
    dst = re.sub(r"// BEGIN LIGHTING\n.*?// END LIGHTING", lambda m: block, dst, flags=re.S)
    with open(dst_path, "w", newline="\n") as f:
        f.write(dst)


def main():
    meshes_dir = path("assets/meshes/x")
    os.makedirs(os.path.dirname(meshes_dir), exist_ok=True)

    d20_mesh, d20_tex_faces, d20_lua_faces, d20_hull = d20()
    gt.build_all(d20_tex_faces, FIRE, (MAT_X0, MAT_Z0))
    gen_sprites.build_all()
    gen_ui.build_all()
    sync_shaders()

    T = "/assets/textures/"
    floor, walls, baseboard = room()
    frame, glass = window()
    tray_wood, tray_felt = tray()
    lamp_body, lamp_bulb = lamp_parts()

    # name -> (mesh, texture, surface (spec, shininess, emissive))
    props = {
        "floor": (floor, "wood_floor.png", (0.12, 18, 0)),
        "walls": (walls, "wallpaper.png", (0.0, 8, 0)),
        "baseboard": (baseboard, "palette.png", (0.05, 8, 0)),
        "window_frame": (frame, "palette.png", (0.1, 12, 0)),
        "window_glass": (glass, "window.png", (0.0, 8, 0.75)),
        "rug": (rug(), "rug.png", (0.0, 8, 0)),
        "table": (table(), "wood_table.png", (0.18, 22, 0)),
        "battlemat": (mat(), "battlemat.png", (0.02, 8, 0)),
        "tray": (tray_wood, "wood_table.png", (0.18, 22, 0)),
        "tray_felt": (tray_felt, "felt.png", (0.0, 8, 0)),
        "dm_screen": (dm_screen(), "dm_screen.png", (0.08, 12, 0)),
        "sheets": (sheets(), "paper.png", (0.02, 8, 0)),
        "tableware": (tableware(), "palette.png", (0.35, 40, 0)),
        "bookshelf": (bookshelf(), "palette.png", (0.05, 10, 0)),
        "plant": (plant(), "palette.png", (0.05, 10, 0)),
        "fairy_lights": (fairy_lights(), "palette.png", (0.0, 8, 1.3)),
    }
    preview = {"props": [], "sprites": [], "presets": PRESETS, "lamp_pivot": LAMP_PIVOT,
               "bulb_offset": BULB_OFFSET, "fire": [FIRE[0], MAT_Y + 1.5, FIRE[1]]}

    comps, surfaces = [], []
    for name, (mesh, tex, surf) in props.items():
        gm.write_glb(path("assets/meshes", name + ".glb"), mesh, name)
        w(f"main/props/{name}.model", model_file(name, T + tex))
        comps.append((name, f"/main/props/{name}.model"))
        default = (0.05, 8, 0)
        if tuple(surf) != default:
            surfaces.append((name, surf))
        preview["props"].append({"mesh": name, "texture": tex, "surface": list(surf), "material": "lit",
                                 "position": [0, 0, 0]})
    comps.append(("props", "/main/props/props.script"))
    w("main/props/props.go", go_file(comps))
    lines = ["-- Generated by tools/generate.py: per-prop shininess and glow.",
             "-- The evening (M7): \"mood\" { window = glow, fairy = glow, seconds } dims the window",
             "-- as night falls outside and brings the fairy lights up.", "",
             "local GLOW = {}", "", "function init(self)"]
    glow_props = ("window_glass", "fairy_lights")
    for name, (s, sh, e) in surfaces:
        lines.append(f'    go.set("#{name}", "surface", vmath.vector4({fmt(s)}, {fmt(sh)}, {fmt(e)}, 0))')
    for name, (s, sh, e) in surfaces:
        if name in glow_props:
            lines.append(f'    GLOW.{name} = {{ s = {fmt(s)}, sh = {fmt(sh)}, e = {fmt(e)} }}')
    lines.append("    self.fade = nil")
    lines.append("end")
    lines += [
        "",
        "local function set_glow(name, e)",
        "    local g = GLOW[name]",
        "    g.e = e",
        "    go.set(\"#\" .. name, \"surface\", vmath.vector4(g.s, g.sh, e, 0))",
        "end",
        "",
        "function update(self, dt)",
        "    local f = self.fade",
        "    if not f then",
        "        return",
        "    end",
        "    f.t = math.min(f.t + dt, f.seconds)",
        "    local k = f.seconds > 0 and f.t / f.seconds or 1",
        "    for name, to in pairs(f.to) do",
        "        set_glow(name, f.from[name] + (to - f.from[name]) * k)",
        "    end",
        "    if f.t >= f.seconds then",
        "        self.fade = nil",
        "    end",
        "end",
        "",
        "function on_message(self, message_id, message)",
        "    if message_id == hash(\"mood\") then",
        "        local f = { t = 0, seconds = message.seconds or 2, from = {}, to = {} }",
        "        if message.window then",
        "            f.from.window_glass, f.to.window_glass = GLOW.window_glass.e, message.window",
        "        end",
        "        if message.fairy then",
        "            f.from.fairy_lights, f.to.fairy_lights = GLOW.fairy_lights.e, message.fairy",
        "        end",
        "        self.fade = f",
        "    end",
        "end",
        "",
    ]
    w("main/props/props.script", "\n".join(lines))

    # the snack table (M7): chips in the bowl, pizza on a plate
    snack_comps = []
    gm.write_glb(path("assets/meshes", "plate.glb"), plate(), "plate")
    w("main/snacks/plate.model", model_file("plate", T + "palette.png"))
    snack_comps.append(("plate", "/main/snacks/plate.model"))
    for k in range(PIZZA_SLICES):
        name = f"pizza_{k + 1}"
        gm.write_glb(path("assets/meshes", name + ".glb"), pizza_slice(k), name)
        w(f"main/snacks/{name}.model", model_file(name, T + "palette.png"))
        snack_comps.append((name, f"/main/snacks/{name}.model"))
    snack_comps.append(("snacks", "/main/snacks/snacks.script"))
    w("main/snacks/pizza.go", go_file(snack_comps))
    gm.write_glb(path("assets/meshes", "chips.glb"), chips(), "chips")
    w("main/snacks/chips.model", model_file("chips", T + "palette.png"))
    w("main/snacks/chips.go", go_file([("model", "/main/snacks/chips.model")]))
    preview["props"].append({"mesh": "chips", "texture": "palette.png", "surface": [0.05, 8, 0], "material": "lit",
                             "position": list(CHIPS_ORIGIN)})
    preview["props"].append({"mesh": "plate", "texture": "palette.png", "surface": [0.2, 30, 0], "material": "lit",
                             "position": list(PLATE)})

    # lamp
    gm.write_glb(path("assets/meshes", "lamp_body.glb"), lamp_body, "lamp_body")
    gm.write_glb(path("assets/meshes", "lamp_bulb.glb"), lamp_bulb, "lamp_bulb")
    w("main/lamp/lamp_body.model", model_file("lamp_body", T + "palette.png"))
    w("main/lamp/lamp_bulb.model", model_file("lamp_bulb", T + "palette.png"))
    w("main/lamp/lamp.go", go_file([("body", "/main/lamp/lamp_body.model"), ("bulb", "/main/lamp/lamp_bulb.model"),
                                    ("lamp", "/main/lamp/lamp.script")]))
    preview["props"].append({"mesh": "lamp_body", "texture": "palette.png", "surface": [0.25, 24, 0], "material": "lit",
                             "position": list(LAMP_PIVOT)})
    preview["props"].append({"mesh": "lamp_bulb", "texture": "palette.png", "surface": [0, 1, 1.6], "material": "lit",
                             "position": list(LAMP_PIVOT)})

    # blob shadows
    gm.write_glb(path("assets/meshes", "blob.glb"), blob_quad(), "blob")
    w("main/minis/blob.model", model_file("blob", T + "blob.png", "/materials/blob.material"))
    w("main/minis/blob.go", go_file([("model", "/main/minis/blob.model"), ("shadow", "/main/minis/shadow.script")]))
    w("main/dice/dice_blob.go", go_file([("model", "/main/minis/blob.model")]))

    # d20
    gm.write_glb(path("assets/meshes", "d20.glb"), d20_mesh, "d20")
    w("main/dice/d20.model", model_file("d20", T + "d20.png"))
    w("main/dice/d20.convexshape", "shape_type: TYPE_HULL\n" + "".join(f"data: {fmt(c)}\n" for v in d20_hull for c in v))
    w("main/dice/d20.collisionobject",
      'collision_shape: "/main/dice/d20.convexshape"\ntype: COLLISION_OBJECT_TYPE_DYNAMIC\nmass: 1.0\n'
      'friction: 0.35\nrestitution: 0.3\ngroup: "dice"\nmask: "world"\nmask: "dice"\n'
      'linear_damping: 0.05\nangular_damping: 0.2\nlocked_rotation: false\nbullet: true\n')
    w("main/dice/d20.go", go_file([("model", "/main/dice/d20.model"), ("collisionobject", "/main/dice/d20.collisionobject"),
                                   ("shine", "/main/dice/d20_shine.script")]))
    w("main/dice/d20_shine.script",
      '-- Generated by tools/generate.py: glossy resin for the d20.\n\nfunction init(self)\n'
      '    go.set("#model", "surface", vmath.vector4(0.7, 70, 0.04, 0))\nend\n')
    w("main/dice/d20.factory", 'prototype: "/main/dice/d20.go"\n')
    w("main/dice/dice.go", go_file([("factory", "/main/dice/d20.factory"), ("dice", "/main/dice/dice.script")]))

    # static physics: table top and the walls of every dice tray (tall, invisible)
    boxes = [((0, TABLE_Y - 10, 0), (75, 10, 50))] + tray_physics()
    w("main/physics/world.collisionobject",
      'collision_shape: ""\ntype: COLLISION_OBJECT_TYPE_STATIC\nmass: 0.0\nfriction: 0.6\nrestitution: 0.25\n'
      'group: "world"\nmask: "dice"\n' + box_shapes(boxes)
      + 'linear_damping: 0.0\nangular_damping: 0.0\nlocked_rotation: false\nbullet: false\n')
    w("main/physics/world.go", go_file([("collisionobject", "/main/physics/world.collisionobject")]))

    # The board (the story-matched table): the prop kit, a factory per kind, dropped in piece by piece as
    # the DM describes a place. Boards are data (game/data/boards.lua); the kit is tools/gen_props.py.
    # (The M4 terrain sets, one baked mesh per set, are gone; game/data/terrain_layout.lua reads the boards.)
    import gen_props
    gen_props.main()

    # dynamic minis: the table script spawns them from these prototypes
    # A party mini's base is its player's shirt colour: "party" is Mara's, and Dev, Jess and Sam
    # have their own (main/minis/mini.script picks one by the player).
    for side in ("party", "foe", "npc", "dev", "jess", "sam"):
        base = gm.Mesh()
        base.add(gm.cylinder((0, 0, 0), 2.25, 2.1, 0.6, 20, gm.swatch(PAL("base_" + side))))
        base.add(gm.cylinder((0, 0.6, 0), 1.6, 1.6, 0.01, 20, gm.swatch(PAL("base")), caps=(False, True)))
        gm.write_glb(path("assets/meshes", f"base_{side}.glb"), base, f"base_{side}")
        w(f"main/minis/base_{side}.model", model_file(f"base_{side}", T + "palette.png"))
    w("main/minis/mini_base.go", go_file([("party", "/main/minis/base_party.model"), ("foe", "/main/minis/base_foe.model"),
                                          ("npc", "/main/minis/base_npc.model"), ("dev", "/main/minis/base_dev.model"),
                                          ("jess", "/main/minis/base_jess.model"), ("sam", "/main/minis/base_sam.model")]))
    w("main/minis/mini.go", go_file([("sprite", "/main/minis/mini.sprite"), ("mini", "/main/minis/mini.script")]))
    w("main/minis/mini.sprite", sprite_file("fighter", "/materials/standee.material"))
    w("main/fx/spark.go", go_file([("sprite", "/main/fx/halo.sprite"), ("spark", "/main/fx/spark.script")]))
    w("main/table/mini.factory", 'prototype: "/main/minis/mini.go"\n')
    w("main/table/base.factory", 'prototype: "/main/minis/mini_base.go"\n')
    w("main/table/shadow.factory", 'prototype: "/main/dice/dice_blob.go"\n')
    w("main/table/spark.factory", 'prototype: "/main/fx/spark.go"\n')
    w("main/table/table.go", go_file([("table", "/main/table/table.script"), ("mini_factory", "/main/table/mini.factory"),
                                      ("base_factory", "/main/table/base.factory"),
                                      ("shadow_factory", "/main/table/shadow.factory"),
                                      ("spark_factory", "/main/table/spark.factory"),
                                      ("mark_factory", "/main/table/mark.factory")]))

    # sprites: atlas, minis, people (with poses), glows
    import gen_sprites_a13
    import gen_pregens
    import gen_sprites_npcs
    mini_names = ([m[0] for m in MINIS] + gen_sprites_m4.MONSTERS + gen_sprites_m4.NPCS
                  + [f.__name__ for f in gen_sprites_a13.BUILD] + ["pregen_" + k for k in gen_pregens.PREGENS]
                  + gen_sprites_npcs.NEW)
    people_names = [p[0] for p in PEOPLE]
    pose_names = [f"{p}_{pose}" for p in people_names for pose in gen_sprites.POSES if pose != "neutral"]
    sprite_names = mini_names + people_names + pose_names + ["chair_empty", "flame", "halo"]
    w("assets/sprites/sprites.atlas",
      "".join(f'images {{\n  image: "/assets/sprites/{n}.png"\n}}\n' for n in sprite_names)
      + "margin: 2\nextrude_borders: 2\ninner_padding: 0\n")

    for (name, _) in PEOPLE:
        w(f"main/people/{name}.sprite", sprite_file(name, "/materials/standee.material"))
        w(f"main/people/{name}.go", go_file([("sprite", f"/main/people/{name}.sprite"),
                                             ("person", "/main/people/person.script")]))
    w("main/fx/flame.sprite", sprite_file("flame", "/materials/glow.material"))
    w("main/fx/flame.go", go_file([("sprite", "/main/fx/flame.sprite"), ("flame", "/main/fx/flame.script")]))
    w("main/fx/halo.sprite", sprite_file("halo", "/materials/glow.material"))
    w("main/fx/halo.go", go_file([("sprite", "/main/fx/halo.sprite"), ("halo", "/main/fx/halo.script")]))

    # HUD
    # assets/ui/ui.atlas is written by gen_ui.py
    font_tpl = ('font: "/assets/fonts/{ttf}"\nmaterial: "/builtins/fonts/font.material"\nsize: {size}\n'
                'antialias: 1\nalpha: 1.0\noutline_alpha: 1.0\noutline_width: {ow}\noutput_format: TYPE_BITMAP\n')
    w("assets/fonts/body.font", font_tpl.format(ttf="Outfit-Regular.ttf", size=22, ow="2.0"))
    w("assets/fonts/big.font", font_tpl.format(ttf="Lora-Bold.ttf", size=96, ow="3.0"))
    w("main/hud/hud.gui",
      'script: "/main/hud/hud.gui_script"\n'
      'fonts {\n  name: "body"\n  font: "/assets/fonts/body.font"\n}\n'
      'fonts {\n  name: "big"\n  font: "/assets/fonts/big.font"\n}\n'
      'textures {\n  name: "ui"\n  texture: "/assets/ui/ui.atlas"\n}\n'
      'material: "/builtins/materials/gui.material"\nadjust_reference: ADJUST_REFERENCE_PARENT\n')
    w("main/hud/hud.go", go_file([("hud", "/main/hud/hud.gui")]))
    w("main/camera/camera.go", go_file([("camera", "/main/camera/camera.script")]))

    # main collection
    col = 'name: "main"\n'
    col += instance("props", "/main/props/props.go")
    col += instance("world", "/main/physics/world.go")
    col += instance("camera", "/main/camera/camera.go")
    col += instance("hud", "/main/hud/hud.go")
    col += instance("game", "/game/game.go")
    col += instance("audio", "/main/audio/audio.go")  # sounds: tools/gen_audio.py
    col += instance("pizza", "/main/snacks/pizza.go", PLATE)
    col += instance("chips", "/main/snacks/chips.go", CHIPS_ORIGIN)
    col += instance("lamp", "/main/lamp/lamp.go", LAMP_PIVOT)
    bulb = tuple(a + b for a, b in zip(LAMP_PIVOT, BULB_OFFSET))
    col += instance("lamp_halo", "/main/fx/halo.go", (bulb[0], bulb[1] - 2, bulb[2]), scale=0.22)
    col += instance("dice", "/main/dice/dice.go")
    col += instance("board", "/main/board/board.go")
    col += instance("keepsakes", "/main/keepsakes/keepsakes.go")  # the players' gifts: tools/gen_keepsakes.py
    col += instance("table", "/main/table/table.go")
    col += instance("dice_blob", "/main/dice/dice_blob.go", (0, -500, 0))
    flame_scale = 0.055
    col += instance("flame", "/main/fx/flame.go", (FIRE[0], MAT_Y + 1.0 + 192 * flame_scale / 2, FIRE[1]),
                    scale=flame_scale)
    preview["sprites"].append({"name": "flame", "kind": "glow", "position": [FIRE[0], MAT_Y + 1.0 + 192 * flame_scale / 2, FIRE[1]],
                               "scale": flame_scale, "px": [128, 192], "strength": 0.6})
    preview["sprites"].append({"name": "halo", "kind": "halo", "position": [bulb[0], bulb[1] - 2, bulb[2]],
                               "scale": 0.22, "px": [256, 256], "strength": 0.55})
    art_h = MINI_PX[1] * MINI_SCALE
    for (name, (x, z)) in PEOPLE:
        y = PERSON_BOTTOM + PERSON_PX[1] * PERSON_SCALE / 2
        col += instance(name, f"/main/people/{name}.go", (x, y, z), scale=PERSON_SCALE)
        preview["sprites"].append({"name": name, "kind": "standee", "position": [x, y, z], "scale": PERSON_SCALE,
                                   "px": list(PERSON_PX)})
    col += "scale_along_z: 0\n"
    w("main/main.collection", col)

    # scene constants for scripts
    lua = ["-- Generated by tools/generate.py: layout constants shared by the scripts.", "", "return {", "    presets = {"]
    for p in PRESETS:
        lua.append(f'        {{ name = "{p["name"]}", eye = {lua_vec(p["eye"])}, target = {lua_vec(p["target"])}, '
                   f'fov = {fmt(p["fov"])}, drift = {fmt(p["drift"])} }},')
    lua.append("    },")
    lua.append(f"    fire = {lua_vec((FIRE[0], MAT_Y, FIRE[1]))},")
    lua.append("    -- battle mat grid (M4): square (x, y) is 1-based, x west to east, y north to south")
    lua.append(f"    grid = {{ x0 = {fmt(MAT_X0)}, z0 = {fmt(MAT_Z0)}, size = 5, y = {fmt(MAT_Y)}, base_top = {fmt(BASE_TOP)}, "
               f"w = {terrain_layout.GRID_W}, h = {terrain_layout.GRID_H} }},")
    lua.append(f"    mini = {{ scale = {fmt(MINI_SCALE)}, height = {fmt(art_h)} }},")
    lua.append("    large = { " + ", ".join(f"{k} = {fmt(v)}" for k, v in LARGE.items()) + " },")
    # Where each standee's art starts (share of the sprite from the top), so HP bars sit just over the head.
    from PIL import Image
    tops = {}
    for n in sorted(set(mini_names)):
        im = Image.open(path(f"assets/sprites/{n}.png")).convert("RGBA")
        bb = im.getchannel("A").point(lambda a: 255 if a > 40 else 0).getbbox()
        tops[n] = round(bb[1] / im.size[1], 2) if bb else 0.2
    lua.append("    -- where each standee's art starts, from the top of the sprite: HP bars sit just over the head")
    lua.append("    mini_tops = { " + ", ".join(f"{k} = {fmt(v)}" for k, v in tops.items()) + " },")
    lua.append("    -- where each player's head is (speech bubbles)")
    lua.append("    heads = {")
    for (name, (x, z)) in PEOPLE:
        lua.append(f"        {name} = {lua_vec((x, PERSON_BOTTOM + PERSON_PX[1] * PERSON_SCALE + 2, z))},")
    lua.append("    },")
    lua.append(f"    lamp = {{ bulb_offset = {lua_vec(BULB_OFFSET)} }},")
    spawn = (TRAY["cx"] - TRAY["w"] / 2 + 4.0, TABLE_Y + 16.0, TRAY["cz"] - 2.0)
    lua.append(f"    dice = {{ spawn = {lua_vec(spawn)}, throw = {lua_vec((95.0, -20.0, 25.0))}, floor_y = {fmt(FELT_Y)} }},")
    lua += trays_lua()
    lua.append("    -- d20 face normals (local space) and the number printed on each face")
    lua.append("    d20_faces = {")
    for (nx, ny, nz, num) in d20_lua_faces:
        lua.append(f"        {{ {fmt(nx)}, {fmt(ny)}, {fmt(nz)}, {num} }},")
    lua.append("    },")
    lua.append("}")
    w("main/scene_data.lua", "\n".join(lua) + "\n")

    preview["d20"] = {"spawn": spawn, "floor_y": FELT_Y}
    with open(path("tools/preview_scene.json"), "w") as f:
        json.dump(preview, f, indent=1)
    print("generated", len(props) + 5, "meshes,", len(sprite_names), "sprites, main.collection")


if __name__ == "__main__":
    main()
