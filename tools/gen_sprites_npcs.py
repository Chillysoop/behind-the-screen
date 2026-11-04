"""People painted as standees like the M4 NPCs (tools/gen_sprites_m4.py). The one left is a retired
privateer with a wooden leg, who stands in for the museum's Flitwidget until he gets a mini of his
own (game/ui/night_view.lua CAST_SPRITE).

Writes assets/sprites/npc_<name>.png. Then add them to assets/sprites/sprites.atlas and the
portrait cut-outs (tools/gen_portraits.py). Run from tools/: python3 gen_sprites_npcs.py
"""
import gen_sprites_m4 as m4
from gen_sprites_m4 import C, canvas, face, finish, hand, head


def gs():
    return m4._sp()



def npc_rosin():
    """Captain Ada Rosin: a retired privateer with a wooden leg and an opinion about your knots."""
    g = gs()
    img, d = canvas()
    skin = "#d9a47e"
    # one good leg and boot, one wooden peg
    d.rounded_rectangle([214, 500, 248, 592], 14, fill=C("#3a3a48"))
    d.rounded_rectangle([198, 568, 252, 612], 18, fill=C("#2a1d1a"))
    d.rounded_rectangle([264, 500, 298, 540], 14, fill=C("#3a3a48"))
    d.polygon([(268, 536), (294, 536), (286, 606), (276, 606)], fill=C("#a07848"))
    d.ellipse([272, 598, 290, 612], fill=C("#6b4a32"))
    # the long navy coat, gold buttons
    d.polygon([(192, 326), (320, 326), (356, 560), (156, 560)], fill=C("#2a3a5a"))
    d.polygon([(232, 334), (280, 334), (276, 470), (236, 470)], fill=C("#efe4c8"))
    for y in (360, 400, 440):
        d.ellipse([214, y - 7, 228, y + 7], fill=C("#d6a845"))
        d.ellipse([284, y - 7, 298, y + 7], fill=C("#d6a845"))
    d.rectangle([192, 470, 320, 488], fill=C("#7a2f2b"))                # a red sash
    g.limb(d, (200, 352), (172, 440), 34, C("#2a3a5a"))
    hand(d, (168, 446), skin)
    # a coil of rope with a knot she's not happy with
    for k in range(3):
        d.ellipse([136 - k * 4, 440 + k * 8, 196 - k * 4, 500 + k * 8], outline=C("#c8a868"), width=7)
    g.limb(d, (312, 352), (344, 300), 34, C("#2a3a5a"))                # pointing it out
    hand(d, (348, 292), skin)
    d.line([(352, 286), (372, 262)], fill=C(skin), width=12)
    head(d, skin, cy=250, rx=64, ry=68)
    face(d, 256, 254, "scowl", sep=26)
    d.line([(318, 236), (330, 330)], fill=C("#d8d4cc"), width=14)       # a white braid
    d.ellipse([322, 324, 340, 342], fill=C("#7a2f2b"))
    # the tricorn
    d.polygon([(166, 206), (346, 206), (256, 150)], fill=C("#1e1a24"))
    d.polygon([(150, 214), (196, 176), (316, 176), (362, 214), (256, 198)], fill=C("#2a2430"))
    d.line([(176, 206), (336, 206)], fill=C("#d6a845"), width=5)
    finish(img, "npc_rosin", 152)


NEW = ["npc_rosin"]


def main():
    for name in NEW:
        globals()[name]()
        print("painted", name)


if __name__ == "__main__":
    main()
