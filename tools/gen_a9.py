"""A9, at the table: rebuilds only what A9 changed, without regenerating every asset.

    python3 tools/gen_a9.py

- the players as whole bodies on their chairs (and the empty chair for anyone who's out),
  and the faces cut from them for the screens (tools/gen_portraits.py)
- a dice tray at every seat, plus the DM's open box in front of the screen and the tray behind
  it (meshes, physics, and scene_data's trays block)
- the players' standees placed so they sit on the floor with their heads where they were

tools/generate.py builds the same things on a full run; this keeps the A13 art and anything
else added since out of harm's way.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import generate as g  # noqa: E402
import gen_meshes as gm  # noqa: E402
import gen_portraits  # noqa: E402
import gen_sprites  # noqa: E402
from gen_common import path  # noqa: E402


def main():
    # The players, seated, and the empty chair.
    gen_sprites.players()
    atlas = path("assets/sprites/sprites.atlas")
    text = open(atlas).read()
    if "chair_empty.png" not in text:
        text = text.replace('images {\n  image: "/assets/sprites/flame.png"',
                            'images {\n  image: "/assets/sprites/chair_empty.png"\n}\nimages {\n  image: "/assets/sprites/flame.png"', 1)
        if "chair_empty.png" not in text:
            text = 'images {\n  image: "/assets/sprites/chair_empty.png"\n}\n' + text
        with open(atlas, "w", newline="\n") as f:
            f.write(text)
    gen_portraits.main()

    # The trays and the table's clutter (a stray die moved off Sam's tray).
    wood, felt = g.tray()
    gm.write_glb(path("assets/meshes", "tray.glb"), wood, "tray")
    gm.write_glb(path("assets/meshes", "tray_felt.glb"), felt, "tray_felt")
    gm.write_glb(path("assets/meshes", "tableware.glb"), g.tableware(), "tableware")
    boxes = [((0, g.TABLE_Y - 10, 0), (75, 10, 50))] + g.tray_physics()
    g.w("main/physics/world.collisionobject",
        'collision_shape: ""\ntype: COLLISION_OBJECT_TYPE_STATIC\nmass: 0.0\nfriction: 0.6\nrestitution: 0.25\n'
        'group: "world"\nmask: "dice"\n' + g.box_shapes(boxes)
        + 'linear_damping: 0.0\nangular_damping: 0.0\nlocked_rotation: false\nbullet: false\n')

    # scene_data: the trays block, after the dice line.
    sd = path("main/scene_data.lua")
    src = open(sd).read()
    src = re.sub(r"    -- dice trays \(A9\).*?\n    },\n", "", src, flags=re.S)
    lines = src.split("\n")
    out = []
    for line in lines:
        out.append(line)
        if line.startswith("    dice = {"):
            out += g.trays_lua()
    with open(sd, "w", newline="\n") as f:
        f.write("\n".join(out))

    # The standees: centred so the feet are on the floor and the head where it was.
    col = path("main/main.collection")
    src = open(col).read()
    y = g.PERSON_BOTTOM + g.PERSON_PX[1] * g.PERSON_SCALE / 2
    for (name, (x, z)) in g.PEOPLE:
        pat = re.compile(r'(instances \{\n  id: "%s"\n  prototype: "/main/people/%s.go"\n  position \{\n    x: [^\n]*\n    y: )[^\n]*'
                         % (name, name))
        src, n = pat.subn(lambda m: m.group(1) + g.fmt(y), src)
        assert n == 1, name
    with open(col, "w", newline="\n") as f:
        f.write(src)
    print("A9: players on chairs, %d trays, standees at y %s" % (len(g.TRAYS), g.fmt(y)))


if __name__ == "__main__":
    main()
