"""A13 standees: the Vale Bestiary's monsters, painted like the M4 minis (chunky shapes, big
heads, a white paper border). Run from the project root:  python3 tools/gen_sprites_a13.py
Writes assets/sprites/<id>.png; the atlas lists them (assets/sprites/sprites.atlas).
"""
import sys

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, "tools")
import gen_sprites_m4 as m4  # noqa: E402
from gen_sprites_m4 import C, canvas, club, face, finish, hand, head, legs, sword  # noqa: E402


def gs():
    return m4._sp()


def dagger(d, at, tip):
    sword(d, at, tip, width=10)


def pirate():
    img, d = canvas()
    skin = "#c98d62"
    legs(d, "#3a3a4a", "#2a1a14")
    # striped shirt, sash, open vest
    d.polygon([(192, 330), (320, 330), (334, 520), (178, 520)], fill=C("#f1ece0"))
    for y in range(344, 520, 26):
        d.rectangle([186, y, 326, y + 10], fill=C("#3a5a8a"))
    d.polygon([(180, 330), (222, 330), (214, 520), (172, 520)], fill=C("#7a2a2a"))
    d.polygon([(332, 330), (290, 330), (298, 520), (340, 520)], fill=C("#7a2a2a"))
    d.rectangle([172, 470, 340, 492], fill=C("#d9a23c"))
    gs().limb(d, (196, 360), (150, 430), 32, C("#f1ece0"))
    hand(d, (146, 436), skin)
    dagger(d, (144, 440), (110, 360))
    gs().limb(d, (316, 360), (360, 420), 32, C("#f1ece0"))
    hand(d, (364, 426), skin)
    dagger(d, (366, 428), (408, 352))
    head(d, skin, cy=256, rx=68, ry=70)
    face(d, 256, 252, "grin", sep=28)
    # red bandana with tails, gold earring
    d.chord([184, 186, 328, 280], 180, 360, fill=C("#b8322a"))
    d.polygon([(312, 230), (370, 260), (354, 280), (306, 252)], fill=C("#b8322a"))
    d.ellipse([318, 280, 334, 300], outline=C("#e8c24c"), width=5)
    finish(img, "pirate", 201)


def merrow():
    img, d = canvas()
    skin = "#6f8f7a"
    # fish tail curling under
    d.polygon([(190, 470), (330, 470), (360, 560), (300, 600), (220, 600), (170, 560)], fill=C("#4f6f62"))
    d.polygon([(220, 590), (160, 630), (256, 610), (350, 632), (300, 590)], fill=C("#8fb0a0"))
    for y in (500, 530, 560):
        d.arc([196, y, 320, y + 40], 200, 340, fill=C("#3f5f52"), width=5)
    # huge torso
    d.ellipse([140, 260, 372, 500], fill=C(skin))
    d.ellipse([190, 320, 322, 470], fill=C("#a9c4a8"))
    gs().limb(d, (156, 320), (100, 440), 50, C(skin))
    hand(d, (96, 448), skin, 24)
    gs().limb(d, (356, 320), (400, 260), 50, C(skin))
    hand(d, (404, 254), skin, 24)
    # harpoon with a chain
    d.line([(404, 254), (430, 60)], fill=C("#7a5236"), width=14)
    d.polygon([(418, 70), (430, 20), (444, 70)], fill=C("#c8ccd2"))
    d.polygon([(418, 92), (404, 70), (430, 84)], fill=C("#c8ccd2"))
    for k in range(6):
        d.ellipse([90 + k * 6, 460 + k * 18, 108 + k * 6, 478 + k * 18], outline=C("#8a9096"), width=4)
    # head, fin ears, teeth
    head(d, skin, cy=226, rx=70, ry=64)
    d.polygon([(190, 220), (130, 180), (150, 250)], fill=C("#8fb0a0"))
    d.polygon([(322, 220), (382, 180), (362, 250)], fill=C("#8fb0a0"))
    for sx in (-1, 1):
        ex = 256 + sx * 28
        d.ellipse([ex - 12, 208, ex + 12, 232], fill=C("#f4e06a"))
        d.ellipse([ex - 4, 214, ex + 4, 228], fill=C("#1f1a14"))
    d.chord([214, 236, 298, 290], 0, 180, fill=C("#2a1a1a"))
    for x in range(222, 292, 12):
        d.polygon([(x, 250), (x + 10, 250), (x + 5, 268)], fill=C("#f4f0e0"))
    finish(img, "merrow", 202)


def giant_crab():
    img, d = canvas()
    shell, dark = "#d2603a", "#9a3a22"
    # legs
    for sx in (-1, 1):
        for k in range(3):
            x0 = 256 + sx * (90 + k * 20)
            d.line([(x0, 470), (x0 + sx * 70, 540 + k * 20), (x0 + sx * 60, 600)], fill=C(dark), width=16)
    # body
    d.ellipse([130, 360, 382, 520], fill=C(shell))
    d.ellipse([170, 390, 342, 480], fill=C("#e88a5a"))
    # claws up
    for sx in (-1, 1):
        ax = 256 + sx * 110
        d.line([(256 + sx * 80, 400), (ax, 300)], fill=C(shell), width=30)
        d.ellipse([ax - 50, 200, ax + 50, 310], fill=C(shell))
        d.polygon([(ax - 10 * sx, 200), (ax + 60 * sx, 150), (ax + 40 * sx, 240)], fill=C("#f0d8c0"))
        d.polygon([(ax - 10 * sx, 210), (ax + 60 * sx, 150), (ax + 50 * sx, 210)], fill=C(dark))
    # eyes on stalks
    for sx in (-1, 1):
        ex = 256 + sx * 34
        d.line([(ex, 380), (ex, 320)], fill=C(dark), width=10)
        d.ellipse([ex - 16, 296, ex + 16, 328], fill=C("#f4f0e0"))
        d.ellipse([ex - 6, 304, ex + 6, 318], fill=C("#1f1a14"))
    finish(img, "giant_crab", 203)


def guard():
    img, d = canvas()
    skin = "#e2b896"
    legs(d, "#4a4a52", "#2a2020")
    d.polygon([(190, 330), (322, 330), (330, 520), (182, 520)], fill=C("#8c939c"))
    for y in range(342, 520, 14):
        for x in range(196, 320, 14):
            d.arc([x, y, x + 14, y + 14], 0, 180, fill=C("#6c737c"), width=3)
    d.polygon([(214, 330), (298, 330), (292, 520), (220, 520)], fill=C("#3a5a8a"))
    d.rectangle([182, 470, 330, 488], fill=C("#3a2a20"))
    # spear and shield
    gs().limb(d, (316, 360), (350, 430), 32, C("#8c939c"))
    hand(d, (354, 436), skin)
    d.line([(366, 600), (380, 120)], fill=C("#7a5236"), width=12)
    d.polygon([(368, 130), (380, 70), (394, 130)], fill=C("#d8dce2"))
    d.ellipse([100, 360, 220, 500], fill=C("#3a5a8a"))
    d.ellipse([140, 400, 180, 460], fill=C("#d9b24c"))
    head(d, skin, cy=258, rx=64, ry=66)
    face(d, 256, 258, "calm", sep=26)
    # round helmet with a nasal
    d.chord([186, 176, 326, 290], 180, 360, fill=C("#8c939c"))
    d.rectangle([250, 230, 262, 270], fill=C("#8c939c"))
    finish(img, "guard", 204)


def spy():
    img, d = canvas()
    skin = "#d8a88a"
    legs(d, "#2a2a32", "#1a1a1e")
    d.polygon([(256, 200), (380, 600), (132, 600)], fill=C("#2e2a3a"))
    d.polygon([(256, 300), (320, 600), (192, 600)], fill=C("#3e3a4a"))
    gs().limb(d, (204, 360), (160, 420), 30, C("#2e2a3a"))
    hand(d, (156, 426), skin)
    # hand crossbow
    d.rectangle([110, 410, 170, 424], fill=C("#5a3a24"))
    d.arc([96, 392, 136, 444], 90, 270, fill=C("#5a3a24"), width=6)
    gs().limb(d, (308, 360), (340, 450), 30, C("#2e2a3a"))
    hand(d, (344, 456), skin)
    dagger(d, (346, 458), (366, 520))
    d.ellipse([174, 160, 338, 340], fill=C("#2e2a3a"))
    head(d, skin, cy=262, rx=58, ry=60)
    # half mask and sly eyes
    d.rectangle([198, 268, 314, 322], fill=C("#1a1a22"))
    face(d, 256, 248, "sly", sep=24)
    finish(img, "spy", 205)


def swarm_of_rats():
    img, d = canvas()
    import random
    rnd = random.Random(7)
    spots = []
    for _ in range(26):
        x = rnd.randint(110, 400)
        y = rnd.randint(330, 590)
        spots.append((y, x))
    for y, x in sorted(spots):
        s = rnd.choice([-1, 1])
        fur = rnd.choice(["#7a7276", "#8a8286", "#6a6266", "#5a5256"])
        d.ellipse([x - 34, y - 20, x + 34, y + 20], fill=C(fur))
        d.ellipse([x + s * 26 - 18, y - 16, x + s * 26 + 18, y + 12], fill=C(fur))
        d.ellipse([x + s * 18 - 8, y - 28, x + s * 18 + 8, y - 12], fill=C("#c9a0a0"))
        d.ellipse([x + s * 34 - 4, y - 8, x + s * 34 + 4, y], fill=C("#1f1a14"))
        d.line([(x - s * 30, y + 6), (x - s * 70, y + 24)], fill=C("#c9a0a0"), width=5)
    finish(img, "swarm_of_rats", 206)


def animated_armor():
    img, d = canvas()
    steel, dark = "#a8b0ba", "#6c747e"
    for x in (214, 298):
        d.rounded_rectangle([x - 26, 500, x + 26, 592], 14, fill=C(steel))
        d.rounded_rectangle([x - 34, 576, x + 30, 612], 12, fill=C(dark))
    d.rounded_rectangle([180, 320, 332, 520], 30, fill=C(steel))
    d.line([(256, 330), (256, 510)], fill=C(dark), width=6)
    for y in (420, 450, 480):
        d.arc([186, y - 20, 326, y + 20], 20, 160, fill=C(dark), width=5)
    for sx in (-1, 1):
        d.ellipse([256 + sx * 90 - 44, 300, 256 + sx * 90 + 44, 380], fill=C(steel))
    gs().limb(d, (176, 360), (150, 460), 38, C(steel))
    gs().limb(d, (336, 360), (362, 460), 38, C(steel))
    for x in (148, 364):
        d.ellipse([x - 24, 452, x + 24, 500], fill=C(dark))
    # helm with an empty, glowing visor
    d.rounded_rectangle([196, 180, 316, 320], 40, fill=C(steel))
    d.rectangle([212, 236, 300, 258], fill=C("#141018"))
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(glow).rectangle([220, 240, 292, 254], fill=(120, 200, 255, 220))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(5)))
    d = ImageDraw.Draw(img)
    d.polygon([(250, 180), (262, 180), (276, 120), (236, 120)], fill=C("#b8322a"))
    finish(img, "animated_armor", 207)


def giant_spider():
    img, d = canvas()
    body, dark = "#3a2e2a", "#241c1a"
    for sx in (-1, 1):
        for k, (ky, kx) in enumerate([(380, 110), (420, 135), (460, 130), (500, 110)]):
            x0 = 256 + sx * 60
            x1 = 256 + sx * (kx + 20)
            d.line([(x0, 420 + k * 14), (x1, ky - 70), (256 + sx * (kx + 70), 600 - k * 10)], fill=C(dark), width=16)
    d.ellipse([170, 400, 342, 600], fill=C(body))
    d.polygon([(220, 460), (292, 460), (256, 560)], fill=C("#8a2a22"))
    d.ellipse([196, 300, 316, 430], fill=C(body))
    for k, (ex, ey, r) in enumerate([(236, 350, 12), (276, 350, 12), (220, 330, 7), (292, 330, 7)]):
        d.ellipse([ex - r, ey - r, ex + r, ey + r], fill=C("#e84a3a"))
    d.polygon([(236, 410), (226, 444), (246, 416)], fill=C("#d8d0c0"))
    d.polygon([(276, 410), (286, 444), (266, 416)], fill=C("#d8d0c0"))
    finish(img, "giant_spider", 208)


def specter():
    img, d = canvas()
    pale, dim = "#c8dcf0", "#8aa8c8"
    d.polygon([(256, 200), (360, 360), (340, 520), (300, 470), (270, 610), (240, 480), (200, 560), (172, 360)], fill=C(pale))
    d.polygon([(256, 260), (330, 380), (300, 460), (256, 420), (212, 460), (182, 380)], fill=C(dim))
    gs().limb(d, (190, 360), (120, 300), 26, C(pale))
    gs().limb(d, (322, 360), (392, 300), 26, C(pale))
    for (cx, cy) in [(116, 296), (396, 296)]:
        for k in range(3):
            d.line([(cx, cy), (cx + (k - 1) * 14, cy - 34)], fill=C("#f4f8ff"), width=5)
    head(d, pale, cy=236, rx=66, ry=74)
    for sx in (-1, 1):
        d.ellipse([256 + sx * 28 - 16, 216, 256 + sx * 28 + 16, 256], fill=C("#1a2434"))
    d.ellipse([236, 272, 276, 312], fill=C("#1a2434"))
    finish(img, "specter", 209, alpha=0.82)


def brown_bear():
    img, d = canvas()
    fur, dark, muzzle = "#7a5232", "#5a3a22", "#c8a07a"
    for x in (206, 306):
        d.rounded_rectangle([x - 40, 480, x + 40, 596], 26, fill=C(fur))
        d.ellipse([x - 46, 570, x + 46, 614], fill=C(dark))
    d.ellipse([140, 290, 372, 560], fill=C(fur))
    d.ellipse([196, 350, 316, 520], fill=C("#9a6a42"))
    gs().limb(d, (160, 340), (100, 260), 56, C(fur))
    gs().limb(d, (352, 340), (412, 260), 56, C(fur))
    for (cx, cy) in [(96, 254), (416, 254)]:
        d.ellipse([cx - 30, cy - 30, cx + 30, cy + 30], fill=C(dark))
        for k in range(4):
            d.line([(cx - 18 + k * 12, cy - 22), (cx - 22 + k * 14, cy - 44)], fill=C("#f0ead8"), width=5)
    head(d, fur, cy=228, rx=78, ry=72)
    for sx in (-1, 1):
        d.ellipse([256 + sx * 62 - 26, 150, 256 + sx * 62 + 26, 200], fill=C(fur))
        d.ellipse([256 + sx * 62 - 12, 164, 256 + sx * 62 + 12, 188], fill=C("#c98a7a"))
    d.ellipse([214, 236, 298, 300], fill=C(muzzle))
    d.ellipse([240, 240, 272, 264], fill=C("#1f1a18"))
    for sx in (-1, 1):
        d.ellipse([256 + sx * 34 - 9, 204, 256 + sx * 34 + 9, 222], fill=C("#1f1a14"))
    d.chord([228, 262, 284, 296], 0, 180, fill=C("#5a2420"))
    finish(img, "brown_bear", 210)


def gnoll_warrior():
    img, d = canvas()
    fur, spot = "#b89a62", "#6a4e2a"
    legs(d, fur, "#3a2a20")
    d.polygon([(186, 320), (326, 320), (336, 520), (176, 520)], fill=C(fur))
    for (x, y) in [(206, 360), (290, 380), (236, 430), (306, 460), (200, 480)]:
        d.ellipse([x - 12, y - 10, x + 12, y + 10], fill=C(spot))
    d.polygon([(176, 470), (336, 470), (346, 530), (166, 530)], fill=C("#5a3a2a"))
    gs().limb(d, (196, 350), (150, 440), 32, C(fur))
    hand(d, (146, 446), fur)
    # bone bow
    d.arc([60, 300, 180, 560], 300, 60, fill=C("#ece2c8"), width=12)
    d.line([(150, 316), (150, 546)], fill=C("#d8d0c0"), width=3)
    gs().limb(d, (316, 350), (354, 440), 32, C(fur))
    hand(d, (358, 446), fur)
    # hyena head
    d.ellipse([186, 190, 326, 320], fill=C(fur))
    d.polygon([(214, 270), (186, 330), (300, 330), (298, 270)], fill=C("#8a6a42"))
    d.ellipse([200, 306, 228, 324], fill=C("#1f1a18"))
    d.polygon([(206, 200), (196, 130), (240, 196)], fill=C(fur))
    d.polygon([(306, 200), (316, 130), (272, 196)], fill=C(fur))
    for sx in (-1, 1):
        d.ellipse([256 + sx * 30 - 10, 232, 256 + sx * 30 + 10, 252], fill=C("#f4c03a"))
        d.ellipse([256 + sx * 30 - 3, 236, 256 + sx * 30 + 3, 248], fill=C("#1f1a14"))
    d.line([(210, 316), (296, 320)], fill=C("#3a1a14"), width=6)
    for x in range(214, 292, 14):
        d.polygon([(x, 316), (x + 8, 316), (x + 4, 330)], fill=C("#f4f0e0"))
    d.polygon([(220, 190), (292, 190), (256, 150)], fill=C(spot))
    finish(img, "gnoll_warrior", 211)


def bugbear_warrior():
    img, d = canvas()
    fur, skin = "#8a6a3a", "#c8964a"
    legs(d, "#5a4a2a", "#3a2a20")
    d.polygon([(176, 310), (336, 310), (350, 520), (162, 520)], fill=C(fur))
    d.polygon([(190, 330), (322, 330), (310, 470), (202, 470)], fill=C("#6a4a2a"))
    d.rectangle([168, 466, 344, 486], fill=C("#3a2a20"))
    # very long arms
    gs().limb(d, (186, 340), (110, 520), 34, C(fur))
    hand(d, (106, 528), skin, 20)
    gs().limb(d, (326, 340), (420, 300), 34, C(fur))
    hand(d, (424, 296), skin, 20)
    d.line([(424, 296), (430, 180)], fill=C("#6b4a32"), width=12)
    d.rounded_rectangle([404, 150, 460, 196], 8, fill=C("#8c939c"))
    head(d, skin, cy=236, rx=74, ry=68)
    d.chord([176, 160, 336, 250], 180, 360, fill=C(fur))
    d.polygon([(186, 230), (130, 190), (190, 262)], fill=C(skin))
    d.polygon([(326, 230), (382, 190), (322, 262)], fill=C(skin))
    face(d, 256, 236, "scowl", sep=28)
    d.ellipse([236, 252, 276, 276], fill=C("#7a4a2a"))
    finish(img, "bugbear_warrior", 212)


def warrior_veteran():
    img, d = canvas()
    skin = "#d6a682"
    legs(d, "#5a5a62", "#2a2020")
    d.polygon([(184, 320), (328, 320), (338, 520), (174, 520)], fill=C("#7c848e"))
    for y in range(336, 520, 30):
        d.line([(186, y), (326, y)], fill=C("#5c646e"), width=6)
    d.polygon([(200, 330), (312, 330), (300, 420), (212, 420)], fill=C("#8a2a2a"))
    d.rectangle([174, 470, 338, 490], fill=C("#3a2a20"))
    gs().limb(d, (196, 350), (160, 440), 34, C("#7c848e"))
    hand(d, (156, 446), skin)
    gs().limb(d, (316, 350), (360, 430), 34, C("#7c848e"))
    hand(d, (364, 436), skin)
    sword(d, (366, 432), (430, 150), width=20)
    head(d, skin, cy=252, rx=66, ry=68)
    face(d, 256, 244, "calm", sep=26)
    # grey beard and a scar
    d.chord([196, 252, 316, 340], 0, 180, fill=C("#b8b4ac"))
    d.line([(286, 214), (300, 250)], fill=C("#a8604a"), width=5)
    d.chord([190, 176, 322, 260], 180, 360, fill=C("#9a968e"))
    finish(img, "warrior_veteran", 213)


def kobold_warrior():
    img, d = canvas()
    scale, belly = "#c8622a", "#e8a26a"
    for x in (226, 286):
        d.rounded_rectangle([x - 16, 500, x + 16, 590], 10, fill=C(scale))
        d.ellipse([x - 24, 576, x + 24, 604], fill=C("#8a3a1a"))
    d.polygon([(330, 500), (420, 560), (400, 580), (320, 530)], fill=C(scale))
    d.ellipse([196, 390, 316, 530], fill=C(scale))
    d.ellipse([222, 420, 290, 520], fill=C(belly))
    gs().limb(d, (206, 420), (170, 480), 22, C(scale))
    gs().limb(d, (306, 420), (342, 470), 22, C(scale))
    hand(d, (344, 474), scale, 12)
    dagger(d, (346, 476), (380, 410))
    # big reptile head
    d.ellipse([170, 250, 330, 400], fill=C(scale))
    d.polygon([(178, 330), (110, 350), (180, 380)], fill=C(scale))
    for sx in (-1, 1):
        d.polygon([(256 + sx * 40, 262), (256 + sx * 70, 200), (256 + sx * 54, 276)], fill=C("#e8d8b0"))
    for sx in (-1, 1):
        d.ellipse([256 + sx * 34 - 14, 300, 256 + sx * 34 + 14, 328], fill=C("#f4e06a"))
        d.ellipse([256 + sx * 34 - 3, 302, 256 + sx * 34 + 3, 326], fill=C("#1f1a14"))
    d.line([(120, 360), (200, 368)], fill=C("#5a2010"), width=5)
    finish(img, "kobold_warrior", 214)


def scout():
    img, d = canvas()
    skin = "#d8aa86"
    legs(d, "#4a5a3a", "#3a2a20")
    d.polygon([(190, 320), (322, 320), (334, 520), (178, 520)], fill=C("#5a7a42"))
    d.polygon([(178, 320), (334, 320), (360, 560), (152, 560)], fill=C("#4a6a36"))
    d.rectangle([182, 470, 330, 488], fill=C("#5a3a24"))
    gs().limb(d, (196, 350), (150, 400), 30, C("#4a6a36"))
    hand(d, (146, 406), skin)
    d.arc([70, 230, 190, 580], 290, 70, fill=C("#7a5236"), width=12)
    d.line([(146, 248), (146, 562)], fill=C("#d8d0c0"), width=3)
    gs().limb(d, (316, 350), (350, 430), 30, C("#4a6a36"))
    hand(d, (354, 436), skin)
    # quiver
    d.rounded_rectangle([320, 300, 350, 400], 10, fill=C("#7a5236"))
    for x in (326, 336, 346):
        d.line([(x, 300), (x - 6, 270)], fill=C("#e8e0c8"), width=4)
    d.ellipse([176, 160, 336, 330], fill=C("#4a6a36"))
    d.polygon([(256, 110), (300, 180), (212, 180)], fill=C("#4a6a36"))
    head(d, skin, cy=262, rx=58, ry=60)
    face(d, 256, 256, "calm", sep=24)
    finish(img, "scout", 215)


def worg():
    m4.wolf("worg", 216, "#4a3a32", "#7a6a5a", "#f4c03a", big=True)


BUILD = [pirate, merrow, giant_crab, guard, spy, swarm_of_rats, animated_armor, giant_spider, specter, brown_bear,
         gnoll_warrior, bugbear_warrior, warrior_veteran, kobold_warrior, scout, worg]


def build_all():
    for f in BUILD:
        f()


if __name__ == "__main__":
    build_all()
    print("A13 standees:", len(BUILD))
