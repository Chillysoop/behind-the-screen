"""Welcome to the Ring's own paper minis: the crew of the Brittle Star, one for each friend, painted like the M4
standees (chunky shapes, big heads, a white paper border). Each is drawn from what the hero is in our own words
(game/data/ring/module.lua's heroes: their looks, kit and trinket), never from the book's art. Run from the project root:

    python3 tools/gen_sprites_ring.py [name ...]

Writes assets/sprites/<name>.png. tools/generate.py lists them in the atlas (BUILD), and tools/gen_portraits.py cuts
their portraits (mini_<name>); the module's heroes say who uses which (`mini`).
"""
import sys

from PIL import Image  # noqa: F401  (the canvas is PIL's)

sys.path.insert(0, "tools")
import gen_sprites_m4 as m4  # noqa: E402
from gen_sprites_m4 import C, canvas, finish, hand, head, legs  # noqa: E402


def gs():
    return m4._sp()


def crew_ilse():
    """Ilse Varrow, static noise translator, velocity cursed: a long grey-blue coat, a headset with a little antenna,
    hologlasses a size too small, a notebook of symbols in one hand, and a face that glitches at its edges."""
    g = gs()
    img, d = canvas()
    skin = "#e8c4a8"
    legs(d, "#3a4250", "#26262e")
    d.polygon([(188, 330), (324, 330), (352, 590), (160, 590)], fill=C("#5a6a86"))        # the long coat
    d.polygon([(232, 336), (280, 336), (284, 560), (228, 560)], fill=C("#2e3442"))        # the jumper under it
    g.limb(d, (198, 360), (176, 452), 32, C("#5a6a86"))
    hand(d, (176, 460), skin)
    d.rounded_rectangle([150, 430, 204, 500], 6, fill=C("#e9dfc6"))                       # the notebook
    for k in range(4):
        y = 444 + k * 13
        d.line([(160, y), (194, y)], fill=C("#7a4a8a"), width=3)
    g.limb(d, (314, 360), (338, 450), 32, C("#5a6a86"))
    hand(d, (340, 458), skin)
    # hair, head, the glitch at the edges
    d.ellipse([174, 160, 338, 330], fill=C("#d8d0c4"))
    head(d, skin, cy=256, rx=66, ry=68)
    for k, (dx, y) in enumerate([(-74, 220), (70, 250), (-70, 286)]):
        d.rectangle([256 + dx - 10, y, 256 + dx + 14, y + 8], fill=C("#7fd7e8" if k % 2 == 0 else "#c87ae8"))
    # the too-small hologlasses, and the headset
    for sx in (-1, 1):
        ex = 256 + sx * 24
        d.rounded_rectangle([ex - 15, 236, ex + 15, 256], 5, fill=C("#7fd7e8", 200))
    d.line([(241, 246), (271, 246)], fill=C("#2a2a32"), width=4)
    g.eyes(d, 256, 246, sep=24, r=(5, 6))
    d.arc([182, 170, 330, 300], 200, 340, fill=C("#2a2a32"), width=9)
    d.ellipse([170, 238, 196, 270], fill=C("#2a2a32"))
    d.line([(184, 240), (170, 190)], fill=C("#2a2a32"), width=5)
    d.ellipse([162, 180, 178, 196], fill=C("#e85a5a"))
    g.smile(d, 256, 290, 12)
    finish(img, "crew_ilse", 401)


def crew_brask():
    """Brask Hollin, asteroid driller, carbon: a heavy orange EVA suit with its helmet off, grey stubble, metal
    splinters glinting in one cheek, a battered raid rifle over his shoulder and a big wrench."""
    g = gs()
    img, d = canvas()
    skin = "#c48a62"
    legs(d, "#c86a2a", "#3a3a40")
    d.rounded_rectangle([168, 320, 344, 560], 40, fill=C("#d8782e"))                      # the suit
    d.rectangle([168, 420, 344, 446], fill=C("#3a3a40"))
    d.rounded_rectangle([222, 350, 290, 400], 8, fill=C("#4a5a66"))                       # the chest panel
    for k in range(3):
        d.ellipse([232 + k * 18, 364, 244 + k * 18, 376], fill=C(["#e85a5a", "#f4d24a", "#7fe08a"][k]))
    # the rifle, slung behind
    d.line([(320, 300), (210, 520)], fill=C("#3a3430"), width=20)
    d.line([(300, 340), (330, 360)], fill=C("#3a3430"), width=12)
    g.limb(d, (186, 350), (150, 450), 40, C("#d8782e"))
    hand(d, (148, 460), skin, r=18)
    d.line([(146, 470), (126, 560)], fill=C("#9aa4ac"), width=14)                         # the wrench
    d.ellipse([110, 548, 142, 580], fill=C("#9aa4ac"))
    d.ellipse([118, 556, 134, 572], fill=C("#d8782e"))
    g.limb(d, (326, 350), (356, 446), 40, C("#d8782e"))
    hand(d, (358, 456), skin, r=18)
    # the collar ring the helmet locks onto, the head, stubble and splinters
    d.ellipse([186, 300, 326, 352], fill=C("#9aa4ac"))
    head(d, skin, cy=250, rx=70, ry=70)
    d.chord([190, 250, 322, 326], 0, 180, fill=C("#8a8a8a"))
    d.ellipse([196, 186, 316, 230], fill=C("#8a8a8a"))
    for x, y in ((300, 262), (308, 276), (296, 284)):
        d.polygon([(x, y), (x + 8, y - 3), (x + 4, y + 6)], fill=C("#dfe4ea"))
    g.eyes(d, 256, 244, sep=26, r=(7, 7))
    d.line([(216, 226), (244, 232)], fill=C("#3a3a3a"), width=7)
    d.line([(296, 226), (268, 232)], fill=C("#3a3a3a"), width=7)
    d.line([(236, 290), (276, 290)], fill=C("#4a2a22"), width=6)
    finish(img, "crew_brask", 402)


def crew_mox():
    """Mox Calloway, gravity swindler, void: dark robes open over a suit with shifting holographic patterns, a smooth
    pale mask with a painted grin, a voice scrambler at her throat, a fan of glowing playing cards in one hand."""
    g = gs()
    img, d = canvas()
    legs(d, "#2a2436", "#1a1622")
    d.polygon([(178, 326), (334, 326), (376, 596), (136, 596)], fill=C("#2e2640"))        # the robes
    d.polygon([(226, 332), (286, 332), (300, 570), (212, 570)], fill=C("#3a7a8a"))        # the suit beneath
    for k in range(5):
        y = 356 + k * 40
        d.line([(222, y), (290, y + 18)], fill=C("#c87ae8"), width=5)
        d.line([(290, y), (222, y + 18)], fill=C("#7fd7e8"), width=4)
    g.limb(d, (192, 352), (150, 420), 32, C("#2e2640"))
    hand(d, (146, 424), "#d8c8e8")
    for k, col in enumerate(("#f4d24a", "#7fd7e8", "#e85a8a", "#7fe08a")):              # the cards, fanned
        x0 = 112 + k * 16
        d.polygon([(x0, 400 - k * 6), (x0 + 26, 394 - k * 6), (x0 + 30, 436 - k * 6), (x0 + 4, 442 - k * 6)],
                  fill=C(col, 230))
    g.limb(d, (320, 352), (348, 446), 32, C("#2e2640"))
    hand(d, (350, 454), "#d8c8e8")
    # the hood, the mask, the scrambler
    d.ellipse([164, 150, 348, 346], fill=C("#2e2640"))
    d.ellipse([196, 186, 316, 318], fill=C("#efe8f4"))
    for sx in (-1, 1):
        ex = 256 + sx * 26
        d.chord([ex - 14, 232, ex + 14, 258], 180, 360, fill=C("#1a1622"))
    d.arc([222, 262, 290, 300], 20, 160, fill=C("#a83a5a"), width=6)
    d.rounded_rectangle([226, 318, 286, 340], 8, fill=C("#4a4a56"))
    for k in range(4):
        d.ellipse([234 + k * 13, 324, 242 + k * 13, 332], fill=C("#7fe08a"))
    finish(img, "crew_mox", 403)


def crew_pell():
    """Pell Abernathy, orbit vagabond, punk: a green mohawk, a battered jacket covered in patches of leaves and flowers,
    a pocket greenhouse (a little glass dome with a sprout in it) held up proudly, and a big easy smile."""
    g = gs()
    img, d = canvas()
    skin = "#a87050"
    legs(d, "#4a4a3a", "#2a2a22")
    d.polygon([(184, 326), (328, 326), (344, 540), (168, 540)], fill=C("#5a4a3a"))        # the jacket
    d.polygon([(232, 332), (280, 332), (284, 530), (228, 530)], fill=C("#e8e0c8"))        # the shirt
    for x, y, col in ((196, 372, "#7fe08a"), (300, 400, "#f4a0c8"), (204, 450, "#f4d24a"), (306, 470, "#7fe08a")):
        d.ellipse([x - 16, y - 16, x + 16, y + 16], fill=C("#efe4cc"))
        d.ellipse([x - 10, y - 10, x + 10, y + 10], fill=C(col))
    g.limb(d, (318, 352), (360, 284), 34, C("#5a4a3a"))
    hand(d, (364, 276), skin)
    d.chord([334, 214, 398, 278], 180, 360, fill=C("#bfe8f0", 190))                      # the pocket greenhouse
    d.rectangle([334, 244, 398, 256], fill=C("#7a5a3a"))
    d.line([(366, 244), (366, 222)], fill=C("#3a8a3a"), width=4)
    d.ellipse([356, 214, 368, 226], fill=C("#5ac85a"))
    d.ellipse([366, 218, 378, 230], fill=C("#5ac85a"))
    g.limb(d, (194, 356), (168, 446), 34, C("#5a4a3a"))
    hand(d, (166, 454), skin)
    # head, the mohawk, the smile
    head(d, skin, cy=254, rx=68, ry=70)
    for k in range(6):
        x = 228 + k * 11
        d.polygon([(x - 6, 196), (x + 6, 196), (x + 2, 142 + (k % 2) * 12)], fill=C("#5ad85a"))
    g.eyes(d, 256, 246, sep=26, happy=True)
    g.smile(d, 256, 284, 22, open_=True)
    d.ellipse([310, 262, 322, 274], fill=C("#d9b24c"))                                    # an earring
    finish(img, "crew_pell", 404)


BUILD = [crew_ilse, crew_brask, crew_mox, crew_pell]


def build_all(names=None):
    for f in BUILD:
        if not names or f.__name__ in names:
            f()


if __name__ == "__main__":
    build_all(sys.argv[1:])
    print("ring minis:", ", ".join(f.__name__ for f in BUILD if len(sys.argv) < 2 or f.__name__ in sys.argv[1:]))
