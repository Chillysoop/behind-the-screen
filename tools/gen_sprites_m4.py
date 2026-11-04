"""M4 standees: the slice's monsters and NPCs, painted like the M0 minis
(chunky shapes, big heads, a white paper border), plus pose variants for the
four players around the table (leaning in, cheering, laughing, gasping, arms
crossed, yawning, on the phone, thinking).
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from gen_common import path

SPR = "assets/sprites"


def _sp():
    import gen_sprites as gs
    return gs


def C(h, a=255):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


# ------------------------------------------------------------------ shared bits

def head(d, skin, cx=256, cy=252, rx=80, ry=80):
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=C(skin))


def face(d, cx, cy, mood="calm", sep=34, eye="#2a1d1a"):
    gs = _sp()
    if mood == "grin":
        gs.eyes(d, cx, cy, sep=sep, r=(8, 10))
        d.chord([cx - 26, cy + 16, cx + 26, cy + 50], 0, 180, fill=C("#5a2420"))
        d.rectangle([cx - 18, cy + 32, cx + 18, cy + 38], fill=C("#f4f0e0"))
    elif mood == "scowl":
        gs.eyes(d, cx, cy, sep=sep, r=(7, 8))
        d.line([(cx - sep - 16, cy - 20), (cx - sep + 14, cy - 10)], fill=C(eye), width=7)
        d.line([(cx + sep + 16, cy - 20), (cx + sep - 14, cy - 10)], fill=C(eye), width=7)
        d.line([(cx - 16, cy + 36), (cx + 16, cy + 36)], fill=C("#4a2a22"), width=6)
    elif mood == "nervous":
        gs.eyes(d, cx, cy, sep=sep, r=(9, 12))
        d.arc([cx - 18, cy + 24, cx + 18, cy + 44], 200, 340, fill=C("#4a2a22"), width=5)
    elif mood == "kind":
        gs.eyes(d, cx, cy, sep=sep, happy=True)
        gs.smile(d, cx, cy + 34, 18)
    elif mood == "sly":
        for sx in (-1, 1):
            ex = cx + sx * sep
            d.chord([ex - 12, cy - 8, ex + 12, cy + 12], 0, 180, fill=C(eye))
        d.arc([cx - 22, cy + 18, cx + 22, cy + 42], 20, 140, fill=C("#4a2a22"), width=5)
    else:
        gs.eyes(d, cx, cy, sep=sep)
        gs.smile(d, cx, cy + 34, 16)


def legs(d, leg, boot):
    _sp().boots_and_legs(d, leg, boot)


def sword(d, hand, tip, blade="#dfe4ea", hilt="#7a5236", width=16):
    hx, hy = hand
    tx, ty = tip
    d.line([(hx, hy), (tx, ty)], fill=C(blade), width=width)
    d.line([(hx - 18, hy + 6), (hx + 18, hy - 6)], fill=C(hilt), width=10)


def club(d, hand, top, wood="#6b4a32", head_r=30):
    d.line([hand, top], fill=C(wood), width=18)
    tx, ty = top
    d.ellipse([tx - head_r, ty - head_r, tx + head_r, ty + head_r], fill=C(wood))


def hand(d, xy, skin, r=15):
    x, y = xy
    d.ellipse([x - r, y - r, x + r, y + r], fill=C(skin))


def finish(img, name, seed, alpha=None):
    gs = _sp()
    fig = gs.painterly(img, seed)
    fig = gs.outline(fig, 4)
    if alpha is not None:
        a = np.asarray(fig).astype(float)
        a[..., 3] *= alpha
        fig = Image.fromarray(a.astype(np.uint8), "RGBA")
    fig = gs.paper_border(fig)
    fig.resize((fig.width // 2, fig.height // 2), Image.LANCZOS).save(path(SPR, name + ".png"))


def canvas():
    img = Image.new("RGBA", (512, 640), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


# ------------------------------------------------------------------ monsters

def goblin_boss():
    gs = _sp()
    img, d = canvas()
    skin = "#7c9a4a"
    # cape behind
    d.polygon([(190, 360), (322, 360), (370, 590), (142, 590)], fill=C("#8a2f2f"))
    d.rounded_rectangle([206, 520, 246, 596], 14, fill=C(skin))
    d.rounded_rectangle([266, 520, 306, 596], 14, fill=C(skin))
    d.ellipse([194, 580, 252, 614], fill=C("#5f7a36"))
    d.ellipse([260, 580, 318, 614], fill=C("#5f7a36"))
    d.polygon([(196, 380), (316, 380), (330, 540), (182, 540)], fill=C("#6a5a3a"))
    d.rectangle([186, 470, 326, 488], fill=C("#d9b24c"))
    gs.limb(d, (204, 400), (170, 470), 30, C(skin))
    gs.limb(d, (308, 400), (346, 340), 30, C(skin))
    sword(d, (350, 330), (392, 190), width=14)
    # head, ears
    d.polygon([(186, 300), (96, 250), (190, 340)], fill=C(skin))
    d.polygon([(326, 300), (416, 250), (322, 340)], fill=C(skin))
    d.ellipse([176, 230, 336, 400], fill=C(skin))
    for sx in (-1, 1):
        ex = 256 + sx * 36
        d.ellipse([ex - 18, 288, ex + 18, 318], fill=C("#f4e06a"))
        d.ellipse([ex - 6, 294, ex + 6, 314], fill=C("#1f1a14"))
    d.chord([222, 336, 290, 372], 0, 180, fill=C("#3a1f1a"))
    # the very proud hat
    d.ellipse([150, 214, 362, 260], fill=C("#3a2a4a"))
    d.polygon([(196, 236), (316, 236), (300, 120), (212, 120)], fill=C("#3a2a4a"))
    d.rectangle([198, 206, 314, 226], fill=C("#d9b24c"))
    d.polygon([(300, 130), (360, 40), (380, 60), (316, 150)], fill=C("#d94a3a"))
    d.polygon([(310, 140), (392, 70), (400, 92), (322, 156)], fill=C("#f0c75a"))
    finish(img, "goblin_boss", 111)


def bandit():
    gs = _sp()
    img, d = canvas()
    skin = "#e0b48c"
    legs(d, "#5a4a3a", "#3a2a20")
    d.polygon([(190, 330), (322, 330), (340, 530), (172, 530)], fill=C("#7a5a3a"))
    d.polygon([(226, 340), (286, 340), (292, 520), (220, 520)], fill=C("#8a6a44"))
    d.rectangle([176, 470, 336, 488], fill=C("#3a2a20"))
    gs.limb(d, (198, 360), (160, 440), 34, C("#7a5a3a"))
    hand(d, (156, 448), skin)
    sword(d, (150, 452), (120, 300))
    gs.limb(d, (314, 360), (350, 450), 34, C("#7a5a3a"))
    hand(d, (352, 456), skin)
    # hood + bandana
    d.ellipse([168, 156, 344, 340], fill=C("#a08a64"))
    head(d, skin, cy=258, rx=66, ry=66)
    d.chord([190, 262, 322, 344], 0, 180, fill=C("#a83a32"))
    d.polygon([(300, 300), (350, 330), (310, 340)], fill=C("#a83a32"))
    gs.eyes(d, 256, 244, sep=26, r=(7, 9))
    d.line([(216, 222), (242, 230)], fill=C("#2a1d1a"), width=6)
    d.line([(296, 222), (270, 230)], fill=C("#2a1d1a"), width=6)
    finish(img, "bandit", 112)


def bandit_captain():
    gs = _sp()
    img, d = canvas()
    skin = "#c98d62"
    legs(d, "#2a2a32", "#3a2420")
    # long red coat
    d.polygon([(186, 320), (326, 320), (370, 596), (142, 596)], fill=C("#a83a32"))
    d.polygon([(226, 330), (286, 330), (276, 520), (236, 520)], fill=C("#efe4cc"))
    for y in (370, 410, 450):
        d.ellipse([290, y, 302, y + 12], fill=C("#d9b24c"))
    d.rectangle([180, 466, 332, 482], fill=C("#2a1d1a"))
    gs.limb(d, (318, 350), (360, 280), 34, C("#a83a32"))
    hand(d, (364, 272), skin)
    sword(d, (366, 268), (420, 120), width=14)
    gs.limb(d, (194, 360), (166, 450), 34, C("#a83a32"))
    hand(d, (162, 456), skin)
    # head, braid, tricorn
    d.ellipse([176, 230, 236, 380], fill=C("#2a1a14"))
    head(d, skin, cy=258, rx=72, ry=74)
    face(d, 256, 252, "grin", sep=30)
    d.ellipse([256 + 30 - 16, 236, 256 + 30 + 16, 268], fill=C("#1f1a18"))
    d.line([(214, 214), (300, 270)], fill=C("#1f1a18"), width=5)
    d.polygon([(150, 200), (362, 200), (330, 150), (256, 120), (182, 150)], fill=C("#2a1d1a"))
    d.polygon([(150, 200), (256, 228), (362, 200), (256, 186)], fill=C("#3a2a24"))
    d.polygon([(300, 150), (380, 96), (390, 112), (312, 164)], fill=C("#f1efe8"))
    finish(img, "bandit_captain", 113)


def cultist():
    gs = _sp()
    img, d = canvas()
    skin = "#d8b49a"
    d.polygon([(256, 150), (390, 600), (122, 600)], fill=C("#6a1f24"))
    d.polygon([(256, 260), (330, 600), (182, 600)], fill=C("#4a151a"))
    for x in range(196, 330, 26):
        d.polygon([(x, 600), (x + 13, 580), (x + 26, 600)], fill=C("#2a0e10"))
    gs.limb(d, (204, 370), (170, 450), 32, C("#6a1f24"))
    hand(d, (166, 456), skin)
    d.arc([96, 400, 176, 480], 180, 330, fill=C("#c8c0b0"), width=10)
    d.line([(166, 456), (150, 520)], fill=C("#5a3a24"), width=10)
    gs.limb(d, (308, 370), (342, 440), 32, C("#6a1f24"))
    hand(d, (346, 446), skin)
    # deep hood with glowing eyes
    d.ellipse([168, 150, 344, 350], fill=C("#6a1f24"))
    d.polygon([(256, 90), (314, 170), (198, 170)], fill=C("#6a1f24"))
    d.ellipse([196, 200, 316, 336], fill=C("#1a0c0c"))
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for sx in (-1, 1):
        gd.ellipse([256 + sx * 24 - 16, 244, 256 + sx * 24 + 16, 276], fill=(255, 120, 60, 200))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(6)))
    d = ImageDraw.Draw(img)
    for sx in (-1, 1):
        d.ellipse([256 + sx * 24 - 6, 254, 256 + sx * 24 + 6, 266], fill=C("#ffd27a"))
    finish(img, "cultist", 114)


def tough():
    gs = _sp()
    img, d = canvas()
    skin = "#d9a27a"
    d.rounded_rectangle([196, 500, 246, 592], 16, fill=C("#4a3a2a"))
    d.rounded_rectangle([266, 500, 316, 592], 16, fill=C("#4a3a2a"))
    d.rounded_rectangle([180, 568, 252, 614], 18, fill=C("#2a2020"))
    d.rounded_rectangle([260, 568, 332, 614], 18, fill=C("#2a2020"))
    # big body, vest
    d.rounded_rectangle([150, 300, 362, 520], 70, fill=C(skin))
    d.polygon([(170, 320), (236, 320), (226, 520), (160, 510)], fill=C("#5a4030"))
    d.polygon([(342, 320), (276, 320), (286, 520), (352, 510)], fill=C("#5a4030"))
    d.rectangle([150, 470, 362, 494], fill=C("#2a1d1a"))
    d.rectangle([236, 466, 276, 498], fill=C("#8c939c"))
    # wolf badge (Kessrick's men wear it)
    d.ellipse([292, 340, 330, 378], fill=C("#8c939c"))
    d.polygon([(298, 352), (311, 344), (324, 352), (318, 368), (304, 368)], fill=C("#4a4a52"))
    gs.limb(d, (162, 340), (120, 430), 48, C(skin))
    hand(d, (116, 438), skin, 20)
    club(d, (116, 438), (96, 270), head_r=36)
    for (x, y) in [(84, 252), (110, 260), (92, 290)]:
        d.ellipse([x - 6, y - 6, x + 6, y + 6], fill=C("#8c939c"))
    gs.limb(d, (350, 340), (382, 430), 48, C(skin))
    hand(d, (384, 438), skin, 20)
    # small bald head
    head(d, skin, cy=236, rx=64, ry=66)
    d.chord([196, 252, 316, 312], 0, 180, fill=C("#7a5a44"))
    face(d, 256, 232, "scowl", sep=26)
    finish(img, "tough", 115)


def wolf(name, seed, fur, belly, eye, big=False):
    img, d = canvas()
    # side-on, walking left
    d.ellipse([150, 330, 420, 470], fill=C(fur))
    d.ellipse([180, 400, 380, 470], fill=C(belly))
    for (x, top) in [(190, 430), (240, 440), (330, 440), (380, 430)]:
        d.rounded_rectangle([x - 16, top, x + 16, 590], 12, fill=C(fur))
        d.ellipse([x - 20, 576, x + 20, 604], fill=C("#2a2220"))
    d.polygon([(410, 380), (500, 300), (480, 360), (420, 420)], fill=C(fur))
    # head
    d.ellipse([88, 250, 238, 390], fill=C(fur))
    d.polygon([(100, 330), (20, 356), (30, 380), (120, 380)], fill=C(fur))
    d.polygon([(28, 360), (60, 360), (58, 380), (26, 380)], fill=C("#1f1a18"))
    d.polygon([(130, 270), (150, 190), (180, 260)], fill=C(fur))
    d.polygon([(184, 266), (210, 190), (228, 274)], fill=C(fur))
    d.polygon([(140, 262), (152, 214), (170, 258)], fill=C("#c98a7a"))
    d.ellipse([110, 296, 140, 322], fill=C(eye))
    d.ellipse([120, 302, 132, 316], fill=C("#1f1a14"))
    d.line([(40, 378), (110, 386)], fill=C("#5a2420"), width=6)
    if big:
        for x in (60, 82):
            d.polygon([(x, 380), (x + 10, 380), (x + 5, 398)], fill=C("#f4f0e0"))
    finish(img, name, seed)


def skeleton():
    img, d = canvas()
    bone = "#e8e0c8"
    dark = "#3a3028"
    for x in (222, 290):
        d.line([(x, 500), (x - 4, 590)], fill=C(bone), width=14)
        d.ellipse([x - 26, 578, x + 20, 606], fill=C(bone))
    d.ellipse([196, 470, 316, 520], fill=C(bone))
    d.line([(256, 330), (256, 480)], fill=C(bone), width=14)
    for i, y in enumerate(range(350, 460, 22)):
        w = 70 - i * 6
        d.arc([256 - w, y - 16, 256 + w, y + 24], 200, 340, fill=C(bone), width=9)
    d.line([(190, 340), (322, 340)], fill=C(bone), width=14)
    d.line([(196, 344), (160, 440)], fill=C(bone), width=12)
    d.line([(316, 344), (352, 430)], fill=C(bone), width=12)
    d.ellipse([340, 420, 364, 444], fill=C(bone))
    sword(d, (352, 430), (380, 290), blade="#9a8a6a", hilt="#5a3a24", width=14)
    d.ellipse([148, 430, 172, 454], fill=C(bone))
    # rusty round shield
    d.ellipse([110, 400, 200, 490], fill=C("#7a5a3a"))
    d.ellipse([140, 430, 170, 460], fill=C("#9a8a6a"))
    # skull
    d.ellipse([186, 190, 326, 320], fill=C(bone))
    d.rounded_rectangle([216, 290, 296, 340], 14, fill=C(bone))
    for sx in (-1, 1):
        d.ellipse([256 + sx * 32 - 20, 236, 256 + sx * 32 + 20, 280], fill=C(dark))
        d.ellipse([256 + sx * 32 - 5, 252, 256 + sx * 32 + 5, 262], fill=C("#ff8a5a"))
    d.polygon([(248, 286), (264, 286), (256, 302)], fill=C(dark))
    for x in range(226, 290, 14):
        d.line([(x, 318), (x, 336)], fill=C(dark), width=4)
    finish(img, "skeleton", 116)


def zombie():
    gs = _sp()
    img, d = canvas()
    skin = "#8fa07c"
    legs(d, "#4a4a5a", "#3a2a20")
    d.polygon([(190, 330), (322, 330), (330, 530), (182, 530)], fill=C("#6a6a7a"))
    for (x, y) in [(200, 500), (240, 520), (300, 505)]:
        d.polygon([(x, y), (x + 20, y + 30), (x + 40, y)], fill=C("#6a6a7a"))
    d.ellipse([280, 400, 316, 430], fill=C("#5a3a3a"))
    # arms reaching forward (toward the viewer's left)
    gs.limb(d, (200, 360), (110, 380), 30, C(skin))
    gs.limb(d, (312, 360), (210, 400), 30, C(skin))
    hand(d, (100, 380), skin)
    hand(d, (200, 404), skin)
    head(d, skin, cy=252, rx=74, ry=76)
    d.chord([182, 176, 330, 260], 180, 360, fill=C("#4a4038"))
    for sx in (-1, 1):
        ex = 256 + sx * 30
        d.ellipse([ex - 14, 238, ex + 14, 266], fill=C("#f0ecd0"))
        d.ellipse([ex - 4 + sx * 3, 246, ex + 4 + sx * 3, 256], fill=C("#2a2020"))
        d.line([(ex - 16, 238), (ex + 16, 244)], fill=C("#5a6a4a"), width=6)
    d.chord([226, 284, 290, 320], 0, 180, fill=C("#3a2a2a"))
    d.ellipse([290, 210, 312, 228], fill=C("#6a7a5a"))
    finish(img, "zombie", 117)


def ghoul():
    gs = _sp()
    img, d = canvas()
    skin = "#9a8fa8"
    d.rounded_rectangle([210, 500, 244, 596], 12, fill=C(skin))
    d.rounded_rectangle([268, 500, 302, 596], 12, fill=C(skin))
    d.ellipse([196, 580, 250, 610], fill=C("#6a6078"))
    d.ellipse([262, 580, 316, 610], fill=C("#6a6078"))
    # hunched gaunt body
    d.polygon([(200, 320), (330, 340), (322, 510), (196, 510)], fill=C(skin))
    for y in (380, 410, 440):
        d.arc([210, y, 300, y + 30], 200, 340, fill=C("#6a6078"), width=5)
    d.polygon([(196, 470), (322, 470), (332, 520), (186, 520)], fill=C("#4a4058"))
    # long arms with claws
    gs.limb(d, (206, 350), (130, 460), 24, C(skin))
    gs.limb(d, (322, 360), (390, 460), 24, C(skin))
    for (cx, cy, s) in [(130, 460, -1), (390, 460, 1)]:
        for k in range(3):
            d.line([(cx, cy), (cx + s * (10 + k * 8), cy + 40 - k * 6)], fill=C("#f0ead8"), width=5)
    head(d, skin, cx=262, cy=262, rx=70, ry=66)
    for sx in (-1, 1):
        ex = 262 + sx * 28
        d.ellipse([ex - 14, 238, ex + 14, 266], fill=C("#f4f06a"))
        d.ellipse([ex - 4, 246, ex + 4, 258], fill=C("#1f1a14"))
    d.chord([222, 276, 302, 330], 0, 180, fill=C("#2a1a24"))
    for x in range(232, 296, 10):
        d.polygon([(x, 292), (x + 8, 292), (x + 4, 308)], fill=C("#f4f0e0"))
    finish(img, "ghoul", 118)


def ogre():
    gs = _sp()
    img, d = canvas()
    skin = "#b0a070"
    d.rounded_rectangle([170, 500, 236, 596], 20, fill=C(skin))
    d.rounded_rectangle([276, 500, 342, 596], 20, fill=C(skin))
    d.ellipse([150, 572, 246, 616], fill=C("#5a4a3a"))
    d.ellipse([266, 572, 362, 616], fill=C("#5a4a3a"))
    # huge round belly with a stained bib
    d.ellipse([110, 250, 402, 540], fill=C(skin))
    d.polygon([(130, 470), (382, 470), (392, 530), (120, 530)], fill=C("#6a5a3a"))
    d.polygon([(186, 290), (326, 290), (316, 450), (196, 450)], fill=C("#f1ebe0"))
    for (x, y, r) in [(220, 340, 10), (290, 380, 14), (240, 420, 8)]:
        d.ellipse([x - r, y - r, x + r, y + r], fill=C("#b0503a"))
    d.line([(186, 290), (210, 240)], fill=C("#f1ebe0"), width=8)
    d.line([(326, 290), (302, 240)], fill=C("#f1ebe0"), width=8)
    gs.limb(d, (126, 330), (80, 450), 56, C(skin))
    hand(d, (78, 458), skin, 26)
    club(d, (78, 458), (60, 250), wood="#7a5236", head_r=46)
    gs.limb(d, (386, 330), (420, 450), 56, C(skin))
    hand(d, (424, 458), skin, 26)
    # small head
    head(d, skin, cy=210, rx=62, ry=58)
    gs.eyes(d, 256, 200, sep=24, r=(7, 8))
    d.chord([222, 214, 290, 262], 0, 180, fill=C("#4a2a22"))
    for x in (236, 274):
        d.polygon([(x - 6, 222), (x + 6, 222), (x, 204)], fill=C("#f4f0e0"))
    d.polygon([(188, 200), (164, 170), (196, 182)], fill=C(skin))
    d.polygon([(324, 200), (348, 170), (316, 182)], fill=C(skin))
    finish(img, "ogre", 119)


# ------------------------------------------------------------------ NPCs
# (The stranger is the mini for anyone without one of their own: game/ui/night_view.lua.)

def npc_stranger():
    gs = _sp()
    img, d = canvas()
    d.polygon([(256, 140), (400, 604), (112, 604)], fill=C("#2a2a36"))
    d.polygon([(256, 260), (320, 604), (192, 604)], fill=C("#1e1e28"))
    gs.limb(d, (210, 380), (196, 460), 30, C("#2a2a36"))
    d.ellipse([184, 450, 208, 474], fill=C("#cfb08a"))
    d.ellipse([164, 150, 348, 340], fill=C("#2a2a36"))
    d.polygon([(256, 96), (310, 166), (202, 166)], fill=C("#2a2a36"))
    d.ellipse([194, 196, 318, 330], fill=C("#121218"))
    for sx in (-1, 1):
        d.ellipse([256 + sx * 22 - 7, 256, 256 + sx * 22 + 7, 266], fill=C("#e8e0c8"))
    finish(img, "npc_stranger", 122)


# ------------------------------------------------------------------ Thessaly, redrawn

def wizard_thessaly():
    """Thessaly is an elf (Mara's character): long hair, pointy ears, no beard."""
    gs = _sp()
    img, d = canvas()
    skin = "#f2c9a0"
    hair = "#c9663a"
    d.rounded_rectangle([204, 568, 254, 612], 18, fill=C("#3a2a4a"))
    d.rounded_rectangle([258, 568, 308, 612], 18, fill=C("#3a2a4a"))
    d.line([(372, 600), (360, 180)], fill=C("#6b4a32"), width=14)
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([312, 116, 412, 216], fill=(120, 230, 255, 170))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(12)))
    d = ImageDraw.Draw(img)
    d.ellipse([336, 140, 388, 192], fill=C("#7fe6ff"))
    d.ellipse([348, 150, 368, 170], fill=C("#e8fbff"))
    # long hair behind
    d.rounded_rectangle([170, 210, 342, 470], 60, fill=C(hair))
    d.polygon([(196, 320), (316, 320), (350, 596), (162, 596)], fill=C("#5b3a8a"))
    d.polygon([(240, 330), (272, 330), (282, 596), (230, 596)], fill=C("#4a2f72"))
    for (x, y) in [(206, 440), (300, 480), (190, 540), (262, 548)]:
        pts = []
        for k in range(10):
            a = -np.pi / 2 + k * np.pi / 5
            rr = 9 if k % 2 == 0 else 4
            pts.append((x + np.cos(a) * rr, y + np.sin(a) * rr))
        d.polygon(pts, fill=C("#f0c75a"))
    d.rectangle([186, 450, 326, 466], fill=C("#d9b24c"))
    gs.limb(d, (318, 360), (358, 420), 38, C("#5b3a8a"))
    d.ellipse([344, 404, 376, 436], fill=C(skin))
    gs.limb(d, (194, 360), (170, 452), 38, C("#5b3a8a"))
    d.ellipse([156, 438, 186, 468], fill=C(skin))
    # pointed ears, face, fringe, hat
    d.polygon([(184, 270), (144, 236), (192, 296)], fill=C(skin))
    d.polygon([(328, 270), (368, 236), (320, 296)], fill=C(skin))
    d.ellipse([182, 196, 330, 336], fill=C(skin))
    gs.eyes(d, 256, 268, sep=32, r=(8, 11))
    gs.blush(d, 256, 292)
    gs.smile(d, 256, 304, 16)
    d.chord([186, 196, 326, 268], 180, 360, fill=C(hair))
    d.ellipse([138, 196, 374, 236], fill=C("#4a2f72"))
    d.polygon([(186, 214), (326, 214), (300, 120), (318, 40), (250, 100), (214, 160)], fill=C("#5b3a8a"))
    d.polygon([(190, 200), (322, 200), (318, 216), (186, 216)], fill=C("#d9b24c"))
    d.ellipse([262, 132, 286, 156], fill=C("#f0c75a"))
    d.ellipse([270, 128, 292, 152], fill=C("#5b3a8a"))
    finish(img, "wizard", 104)


# The museum garden's topiary come to life (the playtest, November 3: "make custom pieces for them"):
# beasts of clipped leaves on a thorny frame, a cat, a boar and a three-horned brute, eyes like embers.
def _leafy(d, rng, cx, cy, rx, ry, n=46, leaf="#3f7a34", dark="#2c5a26", light="#5e9a48"):
    """A clump of leaves filling an ellipse: overlapping circles in three greens."""
    import math as _m
    for i in range(n):
        a = rng.uniform(0, 2 * _m.pi)
        r = rng.uniform(0, 1) ** 0.6
        x = cx + _m.cos(a) * rx * r
        y = cy + _m.sin(a) * ry * r
        k = rng.uniform(18, 34)
        col = rng.choice([leaf, leaf, dark, light])
        d.ellipse([x - k, y - k, x + k, y + k], fill=C(col))


def _thorns(d, rng, cx, cy, rx, ry, n=16):
    import math as _m
    for i in range(n):
        a = rng.uniform(0, 2 * _m.pi)
        x = cx + _m.cos(a) * rx
        y = cy + _m.sin(a) * ry
        ox, oy = _m.cos(a) * 18, _m.sin(a) * 18
        d.polygon([(x - oy * 0.3, y + ox * 0.3), (x + ox, y + oy), (x + oy * 0.3, y - ox * 0.3)], fill=C("#5a3a22"))


def _eyes(d, xs, y, r=9):
    for x in xs:
        d.ellipse([x - r - 4, y - r - 4, x + r + 4, y + r + 4], fill=C("#ff7a3a", 120))
        d.ellipse([x - r, y - r, x + r, y + r], fill=C("#ffb24a"))
        d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=C("#3a1a0a"))


def briar(name, seed, shape):
    import random as _r
    rng = _r.Random(seed)
    img, d = canvas()
    # The pot it was clipped in: a low stone planter under its feet.
    d.rounded_rectangle([140, 560, 380, 610], 14, fill=C("#7a6a5a"))
    d.rounded_rectangle([130, 548, 390, 572], 10, fill=C("#8a7a6a"))
    # Woody legs.
    legs_at = {"cat": [(200, 470), (250, 480), (320, 480), (360, 470)],
               "boar": [(190, 470), (240, 480), (320, 480), (370, 470)],
               "tri": [(170, 470), (230, 480), (330, 480), (390, 470)]}[shape]
    for (x, top) in legs_at:
        d.rounded_rectangle([x - 14, top, x + 14, 556], 8, fill=C("#5a3a22"))
    if shape == "cat":
        _leafy(d, rng, 285, 420, 120, 70)               # body
        _leafy(d, rng, 150, 330, 66, 60, n=28)          # head
        for ex in (112, 176):                           # ears
            d.polygon([(ex - 26, 300), (ex, 238), (ex + 24, 300)], fill=C("#2c5a26"))
        d.line([(390, 400), (430, 320), (436, 280)], fill=C("#2c5a26"), width=30)   # tail
        _leafy(d, rng, 436, 276, 24, 24, n=8)
        _thorns(d, rng, 285, 420, 128, 78)
        _eyes(d, [128, 172], 326)
    elif shape == "boar":
        _leafy(d, rng, 280, 410, 140, 86)
        _leafy(d, rng, 140, 400, 70, 62, n=26)
        d.ellipse([60, 408, 110, 448], fill=C("#4a7a3a"))                       # snout
        for tx in (84, 104):
            d.polygon([(tx, 430), (tx - 14, 380), (tx + 6, 428)], fill=C("#efe6cf"))   # tusks
        _thorns(d, rng, 280, 400, 150, 92, n=22)
        _eyes(d, [128, 168], 378)
    else:
        _leafy(d, rng, 300, 400, 150, 92)
        _leafy(d, rng, 136, 380, 78, 70, n=30)
        d.polygon([(150, 300), (250, 250), (240, 330)], fill=C("#2c5a26"))      # frill
        _leafy(d, rng, 210, 300, 60, 50, n=16)
        for (hx, hy, tx, ty) in [(110, 340, 40, 270), (150, 330, 110, 240), (80, 390, 20, 380)]:
            d.polygon([(hx - 10, hy), (tx, ty), (hx + 10, hy + 8)], fill=C("#efe6cf"))   # three horns
        _thorns(d, rng, 300, 400, 160, 100, n=24)
        _eyes(d, [120, 160], 372)
    finish(img, name, seed)


MONSTERS = ["goblin_boss", "bandit", "bandit_captain", "cultist", "tough", "wolf", "dire_wolf", "skeleton",
            "zombie", "ghoul", "ogre", "briar_beast", "briar_boar", "briar_triceratops"]
NPCS = ["npc_stranger"]
POSES = ["lean", "cheer", "laugh", "gasp", "arms", "yawn", "phone", "think"]


def build_monsters():
    goblin_boss()
    bandit()
    bandit_captain()
    cultist()
    tough()
    wolf("wolf", 131, "#8a8a8e", "#c8c4bc", "#f4e06a")
    wolf("dire_wolf", 132, "#3a3638", "#6a6264", "#ff6a4a", big=True)
    skeleton()
    zombie()
    ghoul()
    ogre()
    briar("briar_beast", 141, "cat")
    briar("briar_boar", 142, "boar")
    briar("briar_triceratops", 143, "tri")
    npc_stranger()
    wizard_thessaly()
