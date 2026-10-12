"""Keepsakes: the gifts players bring the DM (game/data/keepsakes.lua), as real things on the DM's side
of the table. One mesh per gift and part, built around its own base at the table top, its front
facing +z (toward the DM's chair). main/keepsakes/keepsakes.script sets them out in the slots
right of the DM screen, in the order they were given.

Units are centimetres, like the table (a mug is about 9 cm tall).

Writes:
  assets/meshes/keepsake_<id>_<part>.glb
  main/keepsakes/<id>_<part>.model, main/keepsakes/<id>.go, <id>.factory
  main/keepsakes/keepsakes.go          the script and a factory per gift

Run from the project root: python3 tools/gen_keepsakes.py
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import gen_meshes as gm  # noqa: E402
import gen_props as gp  # noqa: E402

ROOT = gp.ROOT
sw = gp.sw
STONE = gp.STONE


def k_mug(P):
    """A big white mug with a red band and a red d20 on the front, coffee in it."""
    r, h = 3.4, 8.2
    P.paint.add(gm.cylinder((0, 0, 0), r, r, h, 20, sw("white"), caps=(True, False)))
    P.paint.add(gm.cylinder((0, 0.6, 0), r - 0.4, r - 0.4, h - 0.6, 20, sw("white"), caps=(False, False), inside=True))
    P.paint.add(gm.cylinder((0, h, 0), r, r - 0.4, 0.01, 20, sw("white"), caps=(False, False)))
    P.paint.add(gm.cylinder((0, h - 1.6, 0), r - 0.4, r - 0.4, 0.01, 20, sw("ink"), caps=(False, True)))
    for y in (1.0, h - 1.4):
        P.paint.add(gm.cylinder((0, y, 0), r + 0.04, r + 0.04, 0.6, 20, sw("mug_red"), caps=(False, False)))
    d20 = gm.box((0, 0, 0), (2.0, 2.0, 0.2), sw("mug_red"))
    P.paint.add(d20.transformed(roll=math.pi / 4, offset=(0, 4.3, r + 0.02)))
    pip = gm.box((0, 0, 0), (0.9, 0.9, 0.06), sw("white"))
    P.paint.add(pip.transformed(roll=math.pi / 4, offset=(0, 4.3, r + 0.14)))
    # the handle, on the right
    P.paint.add(gm.box((r + 0.9, 6.4, 0), (2.0, 0.9, 1.0), sw("white")))
    P.paint.add(gm.box((r + 0.9, 2.2, 0), (2.0, 0.9, 1.0), sw("white")))
    P.paint.add(gm.box((r + 1.6, 4.3, 0), (0.9, 5.1, 1.0), sw("white")))


def k_dice_tower(P):
    """The Crooked Kettle as a dice tower: a timbered inn on a tray, the dice coming out the front door."""
    T = gp.Parts()
    w, d, h = 6.2, 6.0, 10.5
    gp.timber_walls(T, w, d, h)
    gp.gable_roof(T, w, d, h, 4.0, "roof_red", overhang=0.6)
    T.stone.add(gm.box((w / 2 - 1.4, h + 3.4, -1.0), (1.4, 4.6, 1.4), STONE))      # the chimney the dice go down
    T.paint.add(gm.box((w / 2 - 1.4, h + 5.75, -1.0), (1.0, 0.1, 1.0), sw("char")))
    T.paint.add(gm.box((0, 1.5, d / 2 + 0.12), (3.0, 3.0, 0.2), sw("char")))         # the open front door
    T.paint.add(gm.box((0, 3.2, d / 2 + 0.2), (3.6, 0.4, 0.35), sw("timber")))
    gp.window(T, -1.6, 7.2, d / 2)
    gp.window(T, 1.6, 7.2, d / 2)
    # the kettle sign on its bracket
    T.paint.add(gm.box((w / 2 + 1.0, 8.6, d / 2 - 0.6), (2.0, 0.25, 0.25), sw("iron")))
    T.paint.add(gm.box((w / 2 + 1.6, 7.6, d / 2 - 0.6), (1.6, 1.4, 0.2), sw("gold")))
    for part in ("paint", "stone"):
        getattr(P, part).add(getattr(T, part).transformed(roll=0.05, offset=(0, 0.8, -2.0)))  # crooked, of course
    # the tray in front, a lip all round
    P.paint.add(gm.box((0, 0.4, 1.0), (7.6, 0.8, 11.0), sw("wood_dark")))
    for (cx, cz, sx, sz) in [(0, 6.3, 7.6, 0.5), (-3.55, 3.5, 0.5, 5.5), (3.55, 3.5, 0.5, 5.5)]:
        P.paint.add(gm.box((cx, 1.2, cz), (sx, 1.0, sz), sw("wood_mid")))
    P.paint.add(gm.box((0, 0.82, 3.6), (6.6, 0.05, 4.8), sw("red_cloth")))
    die = gm.box((0, 0, 0), (1.4, 1.4, 1.4), sw("gold"))
    P.paint.add(die.transformed(yaw=0.5, offset=(0.8, 1.55, 4.0)))


def k_map(P):
    """A hand-drawn map of the Vale in a wooden frame, propped up on its stand to face the DM."""
    F = gm.Mesh()
    fw, fh = 12.0, 9.0
    F.add(gm.box((0, fh / 2, 0), (fw, fh, 0.6), sw("wood_dark")))
    F.add(gm.box((0, fh / 2, 0.32), (fw - 1.4, fh - 1.4, 0.06), sw("paper")))
    z = 0.38
    # the river, the road, the hills, the woods, the town and the X
    for (x, y, a, L) in [(-4.2, 2.0, 0.5, 2.4), (-2.6, 3.0, 0.9, 2.2), (-1.4, 4.4, 0.4, 2.0), (0.2, 5.2, 0.15, 2.0),
                         (2.0, 5.6, -0.3, 2.2), (3.8, 5.0, -0.8, 2.0)]:
        F.add(gm.box((0, 0, 0), (L, 0.35, 0.05), sw("water")).transformed(roll=a, offset=(x, y, z)))
    for (x, y, a, L) in [(-3.8, 6.4, -0.2, 2.6), (-1.4, 6.0, 0.1, 2.4), (1.0, 3.4, -0.6, 3.2), (3.0, 2.0, -0.2, 2.4)]:
        F.add(gm.box((0, 0, 0), (L, 0.18, 0.05), sw("ink")).transformed(roll=a, offset=(x, y, z)))
    for (x, y) in [(-3.6, 4.8), (-3.0, 5.2), (-2.4, 4.7), (3.6, 7.0), (4.2, 6.6)]:
        F.add(gm.box((x, y, z), (0.7, 0.7, 0.05), sw("leaf_b")))
    for (x, y) in [(0.0, 7.0), (1.0, 7.3), (2.0, 7.0)]:
        F.add(gm.box((0, 0, 0), (1.1, 1.1, 0.05), sw("stone_dark")).transformed(roll=math.pi / 4, offset=(x, y, z)))
    F.add(gm.box((-1.2, 3.0, z), (1.0, 0.8, 0.05), sw("roof_red")))
    for s in (-1, 1):
        F.add(gm.box((0, 0, 0), (1.0, 0.22, 0.05), sw("red_cloth")).transformed(roll=s * math.pi / 4, offset=(3.2, 3.4, z)))
    P.paint.add(F.transformed(pitch=-0.25, offset=(0, 0.3, 0)))
    P.paint.add(gm.box((0, 0.4, 0.8), (fw, 0.8, 1.6), sw("wood_mid")))            # the ledge it stands on
    P.paint.add(gm.box((0, 0, 0), (1.0, 8.0, 0.6), sw("wood_mid")).transformed(pitch=0.45, offset=(0, 3.6, -3.6)))


def k_plush(P):
    """An owlbear plush: round, brown, a cream face and belly, a beak and two ear tufts."""
    fur, face = "wood_light", "bone"
    P.paint.add(gm.sphere((0, 3.4, 0), 3.4, 14, 9, sw(fur), squash=0.95))
    P.paint.add(gm.sphere((0, 3.0, 1.5), 2.4, 12, 8, sw(face), squash=1.05))
    P.paint.add(gm.sphere((0, 7.3, 0.2), 2.7, 14, 9, sw(fur)))
    P.paint.add(gm.sphere((0, 7.2, 1.6), 1.8, 12, 8, sw(face), squash=0.95))
    beak = gm.cylinder((0, 0, 0), 0.55, 0.0, 1.5, 8, sw("gold"))
    P.paint.add(beak.transformed(pitch=math.pi / 2, offset=(0, 6.8, 3.0)))
    for s in (-1, 1):
        P.paint.add(gm.sphere((s * 0.75, 7.7, 3.25), 0.42, 8, 5, sw("ink")))
        tuft = gm.cylinder((0, 0, 0), 0.75, 0.0, 1.8, 8, sw(fur))
        P.paint.add(tuft.transformed(roll=-s * 0.35, offset=(s * 1.5, 9.2, 0)))
        P.paint.add(gm.sphere((s * 3.1, 3.8, 1.0), 1.15, 10, 6, sw(fur), squash=1.3))
        P.paint.add(gm.sphere((s * 1.5, 0.55, 2.2), 1.3, 10, 6, sw("wood_mid"), squash=0.55))


def k_candle(P):
    """A tavern candle in an amber jar, its label, its lid off beside it, lit."""
    r = 2.5
    P.paint.add(gm.cylinder((0, 0, 0), r, r, 6.2, 18, sw("bottle_amber"), caps=(True, False)))
    P.paint.add(gm.cylinder((0, 0.4, 0), r - 0.25, r - 0.25, 5.8, 18, sw("bottle_amber"), caps=(False, False), inside=True))
    P.paint.add(gm.cylinder((0, 6.2, 0), r, r - 0.25, 0.01, 18, sw("bottle_amber"), caps=(False, False)))
    P.paint.add(gm.cylinder((0, 0.4, 0), r - 0.26, r - 0.26, 4.4, 18, sw("candle"), caps=(False, True)))
    P.paint.add(gm.cylinder((0, 1.4, 0), r + 0.04, r + 0.04, 2.6, 18, sw("paper"), caps=(False, False)))
    P.paint.add(gm.box((0, 2.7, r + 0.08), (2.2, 0.3, 0.05), sw("ink")))
    P.paint.add(gm.box((0, 2.1, r + 0.08), (1.4, 0.2, 0.05), sw("ink")))
    P.paint.add(gm.box((0, 3.4, r + 0.08), (1.0, 0.5, 0.05), sw("mug_red")))
    P.paint.add(gm.box((0, 5.15, 0), (0.15, 0.7, 0.15), sw("char")))
    P.paint.add(gm.sphere((0, 5.85, 0), 0.38, 8, 5, sw("flame"), squash=1.2))
    P.paint.add(gm.cylinder((0, 6.1, 0), 0.32, 0.0, 1.1, 8, sw("flame")))
    P.paint.add(gm.cylinder((r * 2 + 1.0, 0, 0.6), r + 0.15, r + 0.15, 0.7, 18, sw("wood_mid")))   # the lid, off
    P.paint.add(gm.cylinder((r * 2 + 1.0, 0.7, 0.6), r - 0.3, r - 0.3, 0.2, 18, sw("wood_light")))


def k_mini(P):
    """A painted mini of Kessrick the Wolf on a little display plinth with a brass plaque."""
    P.paint.add(gm.box((0, 0.9, 0), (4.6, 1.8, 4.6), sw("wood_dark")))
    P.paint.add(gm.box((0, 2.0, 0), (4.0, 0.4, 4.0), sw("wood_mid")))
    P.paint.add(gm.box((0, 0.95, 2.32), (2.8, 0.7, 0.06), sw("gold")))
    M = gm.Mesh()
    M.add(gm.cylinder((0, 0, 0), 1.3, 1.3, 0.4, 14, sw("char")))
    M.add(gm.cylinder((0, 0.4, 0), 0.75, 0.6, 2.7, 10, sw("iron")))
    M.add(gm.cylinder((0, 0.4, -0.25), 1.05, 0.55, 2.9, 10, sw("banner_wolf"), caps=(False, True)))
    M.add(gm.box((0, 2.0, 0.55), (1.1, 0.3, 0.2), sw("red_cloth")))
    M.add(gm.sphere((0, 3.6, 0.05), 0.52, 10, 6, sw("log_end")))
    M.add(gm.sphere((0, 3.85, -0.15), 0.68, 10, 6, sw("wood_grey"), squash=0.8))       # the wolf pelt
    M.add(gm.box((0, 3.75, 0.62), (0.7, 0.35, 0.5), sw("wood_grey")))                    # its snout over his brow
    for s in (-1, 1):
        ear = gm.cylinder((0, 0, 0), 0.22, 0.0, 0.6, 6, sw("wood_grey"))
        M.add(ear.transformed(roll=-s * 0.3, offset=(s * 0.4, 4.25, -0.1)))
    M.add(gm.box((0, 0, 0), (0.18, 2.8, 0.36), sw("metal")).transformed(roll=-0.2, offset=(1.0, 2.2, 0.45)))
    M.add(gm.box((0, 0, 0), (0.8, 0.2, 0.3), sw("gold")).transformed(roll=-0.2, offset=(0.82, 1.0, 0.45)))
    P.paint.add(M.transformed(scale=1.45, offset=(0, 2.2, 0)))


def k_notebook(P):
    """A leather notebook with a strap, a brass clasp and a red ribbon, lying where the DM's notes go."""
    B = gm.Mesh()
    w, d = 9.0, 12.5
    B.add(gm.box((0, 0.14, 0), (w, 0.28, d), sw("door")))
    B.add(gm.box((0.15, 0.7, 0), (w - 0.6, 0.86, d - 0.5), sw("paper")))
    B.add(gm.box((0, 1.27, 0), (w, 0.28, d), sw("door")))
    B.add(gm.box((-w / 2 + 0.2, 0.7, 0), (0.5, 1.4, d), sw("door")))
    B.add(gm.box((w / 2 - 1.6, 0.7, 0), (0.9, 1.5, d + 0.08), sw("wood_dark")))
    B.add(gm.box((w / 2 + 0.06, 0.7, 0), (0.25, 1.5, 0.9), sw("wood_dark")))
    B.add(gm.box((w / 2 + 0.15, 0.75, 0), (0.25, 0.7, 1.1), sw("gold")))
    B.add(gm.box((1.6, 0.62, d / 2 + 0.8), (0.5, 0.06, 1.8), sw("red_cloth")))
    for k in range(3):
        B.add(gm.box((-2.6 + k * 0.5, 1.42, -3.4 + k * 0.1), (0.3, 0.04, 3.0), sw("gold")))
    P.paint.add(B.transformed(yaw=0.25))


def k_bell(P):
    """A little brass hand bell on a wooden stand."""
    P.paint.add(gm.cylinder((0, 0, 0), 2.8, 2.6, 1.0, 18, sw("wood_dark")))
    P.paint.add(gm.cylinder((0, 1.0, 0), 2.3, 1.5, 1.0, 18, sw("gold")))
    P.paint.add(gm.cylinder((0, 2.0, 0), 1.5, 1.25, 2.2, 18, sw("gold")))
    P.paint.add(gm.sphere((0, 4.2, 0), 1.25, 16, 8, sw("gold"), squash=0.55))
    P.paint.add(gm.cylinder((0, 1.0, 0), 2.32, 2.32, 0.25, 18, sw("bronze"), caps=(False, False)))
    P.paint.add(gm.cylinder((0, 4.6, 0), 0.35, 0.3, 2.6, 10, sw("wood_mid")))
    P.paint.add(gm.sphere((0, 7.5, 0), 0.6, 10, 6, sw("wood_mid")))


def paper_sheet(P, w, d, color="paper", y=0.0):
    """A sheet lying flat, a hair above the table."""
    P.paint.add(gm.box((0, y + 0.08, 0), (w, 0.16, d), sw(color)))


def h_letter(P):
    """A folded letter with a red wax seal."""
    paper_sheet(P, 9.0, 6.0)
    P.paint.add(gm.box((0, 0.2, -0.8), (8.6, 0.06, 0.12), sw("canvas_dark")))
    for k in range(4):
        P.paint.add(gm.box((-1.0 + (k % 2) * 0.6, 0.18, 1.2 - k * 0.7), (5.0 - (k % 2) * 1.6, 0.04, 0.16), sw("ink")))
    P.paint.add(gm.cylinder((2.6, 0.16, -1.8), 0.7, 0.7, 0.25, 12, sw("red_cloth")))


def h_map(P):
    """A hand-drawn map: a river, a road, a few trees and an X."""
    paper_sheet(P, 12.0, 9.0, "canvas")
    for (x, z, a, L) in [(-4.0, 2.0, 0.5, 3.0), (-1.6, 0.8, 0.2, 2.6), (1.0, 0.4, -0.3, 2.8), (3.6, -0.8, -0.6, 2.6)]:
        P.paint.add(gm.box((0, 0, 0), (L, 0.04, 0.35), sw("water")).transformed(yaw=a, offset=(x, 0.19, z)))
    for (x, z, a, L) in [(-3.0, -2.6, 0.1, 3.4), (0.2, -2.0, -0.4, 3.0), (3.0, 2.2, 0.3, 2.6)]:
        P.paint.add(gm.box((0, 0, 0), (L, 0.04, 0.16), sw("ink")).transformed(yaw=a, offset=(x, 0.19, z)))
    for (x, z) in [(-3.6, -0.6), (-2.8, -1.2), (2.6, 2.8), (3.4, 3.2)]:
        P.paint.add(gm.box((x, 0.19, z), (0.6, 0.04, 0.6), sw("leaf_b")))
    for s_ in (-1, 1):
        P.paint.add(gm.box((0, 0, 0), (1.0, 0.04, 0.22), sw("red_cloth")).transformed(yaw=s_ * math.pi / 4, offset=(2.4, 0.2, -2.4)))


def h_note(P):
    """A torn page of notes."""
    paper_sheet(P, 7.0, 8.0)
    for k in range(6):
        P.paint.add(gm.box((-0.4 + (k % 3) * 0.3, 0.18, 2.8 - k * 1.1), (5.2 - (k % 3) * 1.2, 0.04, 0.16), sw("ink")))


def h_sketch(P):
    """A sketch of a place: a roofline and a door in charcoal."""
    paper_sheet(P, 9.0, 7.0)
    P.paint.add(gm.box((0, 0.18, 0.8), (4.0, 0.04, 2.6), sw("stone_dark")))
    for s_ in (-1, 1):
        P.paint.add(gm.box((0, 0, 0), (2.8, 0.04, 0.22), sw("ink")).transformed(yaw=s_ * 0.6, offset=(s_ * 1.1, 0.2, -1.2)))
    P.paint.add(gm.box((0, 0.2, 1.4), (0.8, 0.04, 1.4), sw("char")))


GIFTS = {
    "dice_tower": k_dice_tower,
    "map": k_map,
    "mug": k_mug,
    "plush": k_plush,
    "candle": k_candle,
    "mini": k_mini,
    "notebook": k_notebook,
    "bell": k_bell,
    # handouts (game/data/handouts.lua): paper at the players' seats
    "handout_letter": h_letter,
    "handout_map": h_map,
    "handout_note": h_note,
    "handout_sketch": h_sketch,
}


def main():
    comps = [("keepsakes", "/main/keepsakes/keepsakes.script")]
    written = {"keepsakes.script", "keepsakes.go"}
    stats = []
    for name, fn in GIFTS.items():
        P = gp.Parts()
        fn(P)
        parts = []
        tris = 0
        for part in ("stone", "paint", "wood"):
            mesh = getattr(P, part)
            if len(mesh.p) == 0:
                continue
            mname = f"keepsake_{name}_{part}"
            gm.write_glb(os.path.join(ROOT, "assets/meshes", mname + ".glb"), mesh, mname)
            gp.w(f"main/keepsakes/{name}_{part}.model", gp.model_file(mname, gp.TEX[part]))
            written |= {f"{name}_{part}.model"}
            parts.append((part, f"/main/keepsakes/{name}_{part}.model"))
            tris += len(mesh.p) // 3
        gp.w(f"main/keepsakes/{name}.go", gp.go_file(parts))
        gp.w(f"main/keepsakes/{name}.factory", f'prototype: "/main/keepsakes/{name}.go"\n')
        written |= {name + ".go", name + ".factory"}
        comps.append((name, f"/main/keepsakes/{name}.factory"))
        stats.append((name, tris))
    gp.w("main/keepsakes/keepsakes.go", gp.go_file(comps))
    for fn in os.listdir(os.path.join(ROOT, "main/keepsakes")):
        if fn not in written:
            os.remove(os.path.join(ROOT, "main/keepsakes", fn))
    print(f"{len(GIFTS)} keepsakes: " + ", ".join(f"{n} {t}" for n, t in stats))


if __name__ == "__main__":
    main()
