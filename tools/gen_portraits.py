"""Portraits for the screens (real-session pass): the four players' faces in every pose,
the characters' paper minis, the NPCs and the monsters, cut from the table's sprites into
a GUI atlas (assets/portraits/portraits.atlas, texture "portraits" in game.gui).

    python3 tools/gen_portraits.py

Needs Python 3 with pillow. Run it again after changing the sprites (tools/generate.py).
"""

import os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES = os.path.join(ROOT, "assets", "sprites")
OUT = os.path.join(ROOT, "assets", "portraits")

PLAYERS = ["mara", "dev", "jess", "sam"]
POSES = ["", "arms", "cheer", "gasp", "laugh", "lean", "phone", "think", "yawn"]
FACE = 128            # a player's face: head and shoulders, square
MINI = (96, 120)      # a paper mini: the whole standee

# Paper minis on the table: the heroes, the NPCs and the monsters.
STANDEES = ["fighter", "rogue", "cleric", "wizard",
            "npc_gus", "npc_stranger", "npc_hermit", "npc_rival", "npc_corin", "npc_sable", "npc_ghost",
            "goblin_boss", "goblin_club", "goblin_spear", "bandit", "bandit_captain", "cultist", "tough",
            "wolf", "dire_wolf", "skeleton", "zombie", "ghoul", "ogre"]


def face(name):
    im = Image.open(os.path.join(SPRITES, name + ".png")).convert("RGBA")
    w, h = im.size
    # Head and shoulders: the top of the 300x360 player sprite, a little in from the sides.
    box = (int(w * 0.08), int(h * 0.03), int(w * 0.92), int(h * 0.03 + w * 0.84))
    crop = im.crop(box).resize((FACE, FACE), Image.LANCZOS)
    # A round frame: the GUI draws a coloured disc behind it.
    mask = Image.new("L", (FACE * 4, FACE * 4), 0)
    ImageDraw.Draw(mask).ellipse((2, 2, FACE * 4 - 3, FACE * 4 - 3), fill=255)
    mask = mask.resize((FACE, FACE), Image.LANCZOS)
    out = Image.new("RGBA", (FACE, FACE), (0, 0, 0, 0))
    alpha = Image.composite(crop.getchannel("A"), Image.new("L", (FACE, FACE), 0), mask)
    out.paste(crop, (0, 0))
    out.putalpha(alpha)
    return out


def standee(name):
    im = Image.open(os.path.join(SPRITES, name + ".png")).convert("RGBA")
    bbox = im.getbbox() or (0, 0, im.size[0], im.size[1])
    im = im.crop(bbox)
    w, h = im.size
    k = min(MINI[0] / w, MINI[1] / h)
    im = im.resize((max(1, int(w * k)), max(1, int(h * k))), Image.LANCZOS)
    out = Image.new("RGBA", MINI, (0, 0, 0, 0))
    out.paste(im, ((MINI[0] - im.size[0]) // 2, MINI[1] - im.size[1]), im)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    names = []
    for p in PLAYERS:
        for pose in POSES:
            src = p if not pose else p + "_" + pose
            if not os.path.exists(os.path.join(SPRITES, src + ".png")):
                continue
            name = "face_" + p + ("" if not pose else "_" + pose)
            face(src).save(os.path.join(OUT, name + ".png"))
            names.append(name)
    for s in STANDEES:
        if not os.path.exists(os.path.join(SPRITES, s + ".png")):
            continue
        name = "mini_" + s
        standee(s).save(os.path.join(OUT, name + ".png"))
        names.append(name)
    with open(os.path.join(OUT, "portraits.atlas"), "w") as f:
        for n in names:
            f.write('images {\n  image: "/assets/portraits/%s.png"\n}\n' % n)
        f.write("margin: 2\nextrude_borders: 2\ninner_padding: 0\n")
    print("wrote %d portraits to %s" % (len(names), OUT))


if __name__ == "__main__":
    main()
