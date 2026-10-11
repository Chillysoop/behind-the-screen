"""The slice's people, painted as standees like the M4 NPCs (tools/gen_sprites_m4.py), so the
mini on the mat is the person in the story: Vask with Kessrick's wolf badge and the scar, Wren
with the bell-ringer's rope, the man in the grey coat, Tilly from the market, Ottilie Vane the
wool merchant, Old Hob the miller, Captain Holt and her banner, Brother Tumble with his pie,
Verrin of the Ninth Tower, Nib the goblin scout and Brother Ansel the sexton.

Writes assets/sprites/npc_<name>.png. Then add them to assets/sprites/sprites.atlas and the
portrait cut-outs (tools/gen_portraits.py). Run from tools/: python3 gen_sprites_npcs.py
"""
import gen_sprites_m4 as m4
from gen_sprites_m4 import C, canvas, face, finish, hand, head, legs, sword


def gs():
    return m4._sp()


def npc_vask():
    g = gs()
    img, d = canvas()
    skin = "#d8a07a"
    legs(d, "#3a3230", "#1e1a18")
    # grey cloak behind, dark leather
    d.polygon([(176, 320), (336, 320), (380, 590), (132, 590)], fill=C("#5a5c62"))
    d.rounded_rectangle([180, 316, 332, 530], 50, fill=C("#4a3428"))
    d.line([(200, 330), (312, 500)], fill=C("#2a1d1a"), width=12)
    d.rectangle([180, 470, 332, 492], fill=C("#2a1d1a"))
    # the wolf badge, pewter
    d.ellipse([262, 350, 304, 392], fill=C("#9aa0a8"))
    d.polygon([(270, 364), (283, 354), (296, 364), (290, 382), (276, 382)], fill=C("#4a4a52"))
    # the tower key on his belt
    d.ellipse([196, 480, 222, 506], outline=C("#c9a24c"), width=5)
    d.line([(209, 506), (209, 540)], fill=C("#c9a24c"), width=6)
    g.limb(d, (190, 350), (168, 440), 36, C("#4a3428"))
    hand(d, (166, 446), skin)
    g.limb(d, (322, 350), (352, 430), 36, C("#4a3428"))
    hand(d, (354, 436), skin)
    sword(d, (356, 432), (396, 250), blade="#c8ccd4", hilt="#3a2a20", width=14)
    head(d, skin, cy=246, rx=66, ry=70)
    face(d, 256, 244, "scowl", sep=28)
    # the scar, across the eye
    d.line([(214, 206), (252, 286)], fill=C("#8a3a32"), width=6)
    # cropped dark hair and stubble
    d.chord([188, 170, 324, 250], 180, 360, fill=C("#2a1d1a"))
    d.chord([206, 268, 306, 316], 0, 180, fill=C("#5a4a40"))
    finish(img, "npc_vask", 141)


def npc_wren():
    g = gs()
    img, d = canvas()
    skin = "#f0c8a4"
    legs(d, "#5a4a3a", "#3a2a20")
    d.polygon([(200, 330), (312, 330), (336, 560), (176, 560)], fill=C("#3e5a7a"))
    d.rectangle([196, 450, 316, 466], fill=C("#6a4a30"))
    # a coil of bell rope over the shoulder
    for k in range(3):
        d.ellipse([282 - k * 6, 324 + k * 10, 352 - k * 6, 404 + k * 10], outline=C("#c8a868"), width=8)
    g.limb(d, (206, 360), (184, 430), 30, C("#3e5a7a"))
    hand(d, (180, 436), skin)
    # a small handbell
    d.polygon([(168, 448), (196, 448), (204, 482), (160, 482)], fill=C("#b88a3a"))
    d.ellipse([176, 480, 188, 492], fill=C("#7a5a2a"))
    g.limb(d, (306, 360), (330, 430), 30, C("#3e5a7a"))
    hand(d, (332, 436), skin)
    head(d, skin, cy=250, rx=64, ry=66)
    face(d, 256, 250, "nervous", sep=26)
    # short russet hair, hood down behind
    d.chord([186, 172, 326, 262], 180, 360, fill=C("#a8542a"))
    d.ellipse([170, 290, 342, 340], fill=C("#2a2a36"))
    finish(img, "npc_wren", 142)


def npc_grey_coat():
    g = gs()
    img, d = canvas()
    skin = "#dcb092"
    legs(d, "#3a3a3e", "#1e1a18")
    d.polygon([(190, 320), (322, 320), (370, 600), (142, 600)], fill=C("#7a7c84"))
    d.polygon([(246, 330), (266, 330), (266, 600), (246, 600)], fill=C("#5e6068"))
    d.ellipse([272, 380, 300, 408], fill=C("#9aa0a8"))      # the badge, half hidden
    g.limb(d, (198, 350), (182, 440), 34, C("#7a7c84"))
    hand(d, (180, 446), skin)
    g.limb(d, (314, 350), (330, 440), 34, C("#7a7c84"))
    hand(d, (332, 446), skin)
    head(d, skin, cy=256, rx=62, ry=66)
    face(d, 256, 262, "sly", sep=26)
    # a wide-brimmed hat, low over the eyes
    d.ellipse([150, 190, 362, 236], fill=C("#3a3a40"))
    d.rounded_rectangle([200, 140, 312, 214], 20, fill=C("#3a3a40"))
    d.rectangle([200, 196, 312, 206], fill=C("#7a2a2a"))
    finish(img, "npc_grey_coat", 143)


def npc_tilly():
    g = gs()
    img, d = canvas()
    skin = "#e8b890"
    legs(d, "#6a4a3a", "#3a2a20")
    d.polygon([(196, 330), (316, 330), (352, 580), (160, 580)], fill=C("#b8483a"))
    d.polygon([(214, 380), (298, 380), (310, 560), (202, 560)], fill=C("#efe4c8"))
    g.limb(d, (204, 360), (176, 430), 32, C("#b8483a"))
    hand(d, (172, 436), skin)
    # the basket
    d.chord([300, 400, 400, 480], 0, 180, fill=C("#a07848"))
    d.arc([310, 360, 390, 450], 180, 360, fill=C("#7a5232"), width=8)
    for (x, col) in [(320, "#d6a23d"), (346, "#6d9447"), (372, "#a8463a")]:
        d.ellipse([x - 12, 418, x + 12, 442], fill=C(col))
    g.limb(d, (308, 360), (334, 420), 32, C("#b8483a"))
    head(d, skin, cy=250, rx=66, ry=68)
    face(d, 256, 250, "grin", sep=28)
    d.chord([184, 170, 328, 262], 180, 360, fill=C("#6a3a20"))
    d.ellipse([306, 186, 360, 240], fill=C("#6a3a20"))
    d.polygon([(186, 196), (326, 196), (316, 172), (196, 172)], fill=C("#d6a23d"))
    finish(img, "npc_tilly", 144)


def npc_ottilie():
    g = gs()
    img, d = canvas()
    skin = "#f2d4bc"
    d.polygon([(200, 330), (312, 330), (372, 600), (140, 600)], fill=C("#3a5a4a"))
    d.polygon([(226, 340), (286, 340), (300, 600), (212, 600)], fill=C("#e8dcc0"))
    d.rectangle([200, 400, 312, 414], fill=C("#b8954e"))
    g.limb(d, (206, 360), (180, 440), 30, C("#3a5a4a"))
    # a bundle of wool
    d.ellipse([132, 420, 206, 480], fill=C("#efe8da"))
    d.ellipse([150, 404, 214, 456], fill=C("#e2d8c4"))
    g.limb(d, (306, 360), (338, 420), 30, C("#3a5a4a"))
    d.rounded_rectangle([320, 380, 396, 466], 6, fill=C("#5a3420"))
    d.rectangle([328, 390, 388, 456], fill=C("#efe4cc"))
    head(d, skin, cy=252, rx=64, ry=68)
    face(d, 256, 252, "calm", sep=26)
    # spectacles, and hair up in a neat bun
    for sx in (-1, 1):
        d.ellipse([256 + sx * 26 - 18, 236, 256 + sx * 26 + 18, 270], outline=C("#b8954e"), width=4)
    d.chord([190, 176, 322, 262], 180, 360, fill=C("#8a8a8a"))
    d.ellipse([226, 140, 286, 196], fill=C("#8a8a8a"))
    finish(img, "npc_ottilie", 145)


def npc_hob():
    g = gs()
    img, d = canvas()
    skin = "#e8b48a"
    legs(d, "#7a6a54", "#3a2a20")
    d.rounded_rectangle([156, 316, 356, 540], 80, fill=C("#c9b896"))
    d.polygon([(196, 340), (316, 340), (326, 556), (186, 556)], fill=C("#f4f0e6"))
    for (x, y) in [(222, 400), (290, 460), (250, 510), (300, 380)]:
        d.ellipse([x - 10, y - 8, x + 10, y + 8], fill=C("#ffffff"))      # flour
    g.limb(d, (170, 350), (146, 440), 44, C("#c9b896"))
    hand(d, (142, 446), skin, 20)
    g.limb(d, (342, 350), (370, 430), 44, C("#c9b896"))
    # the flour sack
    d.rounded_rectangle([350, 400, 430, 500], 24, fill=C("#e8dcc0"))
    d.line([(362, 420), (420, 420)], fill=C("#a88b5a"), width=6)
    head(d, skin, cy=244, rx=74, ry=72)
    face(d, 256, 240, "kind", sep=30)
    d.chord([194, 262, 318, 322], 0, 180, fill=C("#f1efe8"))           # a floury white beard
    d.arc([184, 168, 328, 228], 200, 340, fill=C("#d8d4cc"), width=12)
    finish(img, "npc_hob", 146)


def npc_holt():
    g = gs()
    img, d = canvas()
    skin = "#d8a888"
    legs(d, "#4a4a3a", "#2a2020")
    d.rounded_rectangle([180, 320, 332, 530], 50, fill=C("#5a6a4a"))
    d.rectangle([180, 470, 332, 492], fill=C("#3a2a20"))
    d.ellipse([280, 350, 312, 382], fill=C("#d6a845"))                  # an old medal
    # the banner on its pole
    d.line([(150, 600), (150, 170)], fill=C("#6b4a32"), width=12)
    d.polygon([(156, 180), (256, 196), (240, 250), (256, 300), (156, 290)], fill=C("#8a2a24"))
    d.ellipse([186, 216, 224, 254], fill=C("#d6a845"))
    g.limb(d, (192, 350), (160, 420), 34, C("#5a6a4a"))
    hand(d, (156, 426), skin)
    g.limb(d, (322, 350), (346, 430), 34, C("#5a6a4a"))
    hand(d, (348, 436), skin)
    head(d, skin, cy=246, rx=66, ry=70)
    face(d, 256, 248, "calm", sep=28)
    d.chord([188, 172, 324, 252], 180, 360, fill=C("#c8c4bc"))          # grey hair
    d.line([(316, 230), (338, 330)], fill=C("#c8c4bc"), width=16)       # a long braid
    finish(img, "npc_holt", 147)


def npc_tumble():
    g = gs()
    img, d = canvas()
    skin = "#f0c09a"
    d.rounded_rectangle([210, 568, 254, 612], 16, fill=C("#5a3a24"))
    d.rounded_rectangle([258, 568, 302, 612], 16, fill=C("#5a3a24"))
    d.ellipse([150, 320, 362, 600], fill=C("#8a6a44"))
    d.line([(160, 470), (352, 470)], fill=C("#c8a868"), width=10)
    d.ellipse([280, 400, 300, 416], fill=C("#d6a23d"))                  # pie on his robe
    g.limb(d, (176, 380), (196, 450), 36, C("#8a6a44"))
    g.limb(d, (336, 380), (316, 450), 36, C("#8a6a44"))
    # the pie, held up proudly
    d.ellipse([206, 432, 306, 472], fill=C("#c98a3a"))
    d.ellipse([214, 430, 298, 458], fill=C("#e0aa5a"))
    hand(d, (200, 452), skin)
    hand(d, (312, 452), skin)
    head(d, skin, cy=258, rx=72, ry=70)
    face(d, 256, 262, "kind", sep=28)
    d.chord([184, 190, 328, 262], 180, 360, fill=C("#6a4a30"))
    d.ellipse([220, 186, 292, 226], fill=C(skin))                        # the tonsure
    finish(img, "npc_tumble", 148)


def npc_verrin():
    g = gs()
    img, d = canvas()
    skin = "#ecc6a2"
    d.polygon([(204, 330), (308, 330), (360, 604), (152, 604)], fill=C("#2a3a6a"))
    for (x, y) in [(220, 430), (290, 500), (250, 560), (310, 400)]:
        d.polygon([(x, y - 10), (x + 6, y), (x, y + 10), (x - 6, y)], fill=C("#d6a845"))   # stars
    g.limb(d, (210, 360), (180, 300), 30, C("#2a3a6a"))
    hand(d, (176, 292), skin)
    d.ellipse([160, 256, 192, 288], fill=C("#8ac8ff"))                  # a spell, showing off
    g.limb(d, (302, 360), (332, 440), 30, C("#2a3a6a"))
    hand(d, (334, 446), skin)
    d.line([(340, 600), (348, 220)], fill=C("#3a2a20"), width=10)
    head(d, skin, cy=258, rx=62, ry=66)
    face(d, 256, 262, "sly", sep=26)
    d.polygon([(256, 60), (346, 214), (166, 214)], fill=C("#2a3a6a"))  # a very tall hat
    d.ellipse([150, 196, 362, 232], fill=C("#22305a"))
    d.chord([212, 276, 300, 330], 0, 180, fill=C("#4a3020"))           # a neat little beard
    finish(img, "npc_verrin", 149)


def npc_nib():
    g = gs()
    img, d = canvas()
    skin = "#7c8c3a"
    d.rounded_rectangle([220, 540, 250, 600], 12, fill=C("#4a3a2a"))
    d.rounded_rectangle([262, 540, 292, 600], 12, fill=C("#4a3a2a"))
    d.rounded_rectangle([200, 400, 312, 556], 40, fill=C("#6a5a3a"))
    g.limb(d, (210, 420), (186, 480), 24, C(skin))
    hand(d, (184, 486), skin, 13)
    # the very large notebook
    d.rounded_rectangle([280, 420, 360, 520], 6, fill=C("#7a2f2b"))
    d.rectangle([288, 428, 352, 512], fill=C("#efe4c8"))
    g.limb(d, (302, 420), (314, 470), 24, C(skin))
    head(d, skin, cy=330, rx=64, ry=58)
    for sx in (-1, 1):
        d.polygon([(256 + sx * 54, 316), (256 + sx * 120, 280), (256 + sx * 60, 346)], fill=C(skin))
    face(d, 256, 330, "nervous", sep=26, eye="#1a1a10")
    finish(img, "npc_nib", 150)


def npc_ansel():
    g = gs()
    img, d = canvas()
    skin = "#ecc8a8"
    d.polygon([(200, 330), (312, 330), (350, 604), (162, 604)], fill=C("#3a3a3e"))
    d.line([(256, 340), (256, 600)], fill=C("#2a2a2e"), width=6)
    g.limb(d, (206, 360), (176, 420), 30, C("#3a3a3e"))
    hand(d, (172, 426), skin)
    # the lantern
    d.line([(172, 430), (172, 450)], fill=C("#3a3a3e"), width=4)
    d.rounded_rectangle([152, 450, 192, 506], 6, fill=C("#ffd98a"), outline=C("#4a4a52"), width=5)
    g.limb(d, (306, 360), (330, 440), 30, C("#3a3a3e"))
    hand(d, (332, 446), skin)
    for k in range(4):                                                   # the ring of keys
        d.line([(336, 456), (326 + k * 8, 490)], fill=C("#c9a24c"), width=5)
    d.ellipse([320, 448, 352, 470], outline=C("#c9a24c"), width=4)
    head(d, skin, cy=250, rx=62, ry=66)
    face(d, 256, 250, "nervous", sep=26)
    d.arc([186, 176, 326, 236], 200, 340, fill=C("#d8d4cc"), width=10)
    finish(img, "npc_ansel", 151)


NEW = ["npc_vask", "npc_wren", "npc_grey_coat", "npc_tilly", "npc_ottilie", "npc_hob", "npc_holt", "npc_tumble",
       "npc_verrin", "npc_nib", "npc_ansel"]


def main():
    for name in NEW:
        globals()[name]()
        print("painted", name)


if __name__ == "__main__":
    main()
