"""The Museum of Nightmares' own paper minis (R4): its monsters and its people, painted like the M4
standees (chunky shapes, big heads, a white paper border). Each is drawn from what the creature is
in our own words (game/data/museum/cards.lua, module.lua, game/rules/museum.lua), never from the
book's art. Run from the project root:

    python3 tools/gen_sprites_museum.py [name ...]

Writes assets/sprites/<name>.png. tools/generate.py lists them in the atlas (BUILD), and
tools/gen_portraits.py cuts their portraits; game/ui/night_view.lua (MUSEUM_SPRITE, CAST_SPRITE) and
the module's people (`sprite`) say who uses which.
"""
import math
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, "tools")
import gen_sprites_m4 as m4  # noqa: E402
from gen_common import path  # noqa: E402
from gen_sprites_m4 import C, canvas, finish, hand  # noqa: E402

SPR = "assets/sprites"


def gs():
    return m4._sp()


def glow(img, draw_fn, blur):
    """A soft light: draw_fn paints on a clear layer, which is blurred over the picture."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(layer))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(blur)))
    return ImageDraw.Draw(img)


def shade(h, k):
    """A colour a little darker (k < 1) or lighter (k > 1)."""
    r, g, b, _ = C(h)
    f = (lambda v: int(min(255, v * k))) if k <= 1 else (lambda v: int(min(255, v + (255 - v) * (k - 1))))
    return "#%02x%02x%02x" % (f(r), f(g), f(b))


def snake(d, pts, body, head_at, facing, eye="#f4d24a", width=13):
    """A little snake: a curved body through pts, a round head at head_at, two dot eyes, a tongue."""
    d.line(pts, fill=C(body), width=width, joint="curve")
    for (x, y) in pts:
        d.ellipse([x - width / 2, y - width / 2, x + width / 2, y + width / 2], fill=C(body))
    hx, hy = head_at
    d.ellipse([hx - 13, hy - 10, hx + 13, hy + 10], fill=C(body))
    for sx in (-1, 1):
        d.ellipse([hx + sx * 6 - 3, hy - 5, hx + sx * 6 + 3, hy + 1], fill=C(eye))
    fx = hx + facing * 12
    d.line([(hx + facing * 9, hy + 5), (fx + facing * 6, hy + 10)], fill=C("#c8323a"), width=3)


def gear(d, cx, cy, r, teeth, col, hub):
    pts = []
    for k in range(teeth * 2):
        a = k * math.pi / teeth
        rr = r if k % 2 == 0 else r * 0.78
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    d.polygon(pts, fill=C(col))
    d.ellipse([cx - r * 0.32, cy - r * 0.32, cx + r * 0.32, cy + r * 0.32], fill=C(hub))


# ------------------------------------------------------------------ the four seen most

def euryale():
    """The Gorgon: a calm host in a white hood, bronze eyes and a sly smile, a mane of small
    snakes peeking out from under it, a purple robe, an emerald bow, and a glass of red wine."""
    img, d = canvas()
    skin = "#c3d6a8"
    robe, robe_dk = "#5b3478", "#45265e"
    hood, hood_dk = "#f1ece0", "#d3cab6"
    snakes = ["#4f9a4a", "#3d8650", "#72b040"]
    # the emerald bow behind her (viewer's right), its string on her side
    d.arc([322, 176, 428, 580], 290, 70, fill=C("#1f7a52"), width=16)
    d.arc([328, 182, 422, 574], 300, 60, fill=C("#4fc48a"), width=5)
    for (x, y) in [(392, 186), (392, 570)]:
        d.ellipse([x - 9, y - 9, x + 9, y + 9], fill=C("#d9b24c"))
    d.line([(392, 188), (392, 568)], fill=C("#e8e2d0"), width=3)
    # the long purple robe, a gold belt, a hem that pools a little
    d.polygon([(200, 330), (312, 330), (366, 606), (146, 606)], fill=C(robe))
    d.polygon([(236, 340), (276, 340), (300, 606), (212, 606)], fill=C(robe_dk))
    d.rectangle([194, 436, 318, 450], fill=C("#d9b24c"))
    d.ellipse([246, 430, 266, 456], fill=C("#2fa36b"))
    # the hood's mantle over her shoulders
    d.chord([166, 270, 346, 410], 180, 360, fill=C(hood))
    d.polygon([(166, 338), (346, 338), (334, 384), (178, 384)], fill=C(hood))
    d.line([(180, 382), (332, 382)], fill=C("#d9b24c"), width=6)
    # snakes spilling from under the hood, down over the mantle
    snake(d, [(204, 300), (182, 330), (190, 362)], snakes[0], (194, 372), -1)
    snake(d, [(308, 300), (332, 326), (322, 356)], snakes[1], (318, 366), 1)
    # arms in purple sleeves: a glass of red wine held up (viewer's left), the bow hand (viewer's right)
    gs().limb(d, (188, 372), (160, 430), 30, C(robe))
    hand(d, (156, 436), skin, 16)
    d.polygon([(130, 384), (180, 384), (170, 414), (140, 414)], fill=C("#efe8f0"))
    d.polygon([(134, 390), (176, 390), (168, 410), (142, 410)], fill=C("#a3242e"))
    d.line([(155, 414), (155, 446)], fill=C("#efe8f0"), width=5)
    d.ellipse([138, 442, 172, 452], fill=C("#efe8f0"))
    gs().limb(d, (324, 372), (380, 388), 30, C(robe))
    hand(d, (388, 388), skin, 16)
    # the hood: soft, with a gentle peak
    d.ellipse([156, 142, 356, 348], fill=C(hood))
    d.polygon([(206, 168), (306, 168), (262, 108), (250, 108)], fill=C(hood))
    d.arc([166, 152, 346, 338], 200, 340, fill=C(hood_dk), width=8)
    d.ellipse([190, 184, 322, 338], fill=C("#2a2230"))
    # the mane: small snakes curling out from under the hood all round her face, heads out on its rim
    cx, cy = 256, 262
    for i, a in enumerate([168, 198, 228, 256, 284, 312, 342]):
        col = snakes[i % 3]
        r = math.radians(a)
        bx, by = cx + 40 * math.cos(r), cy + 50 * math.sin(r)
        hx, hy = cx + 76 * math.cos(r), cy + 86 * math.sin(r)
        mx, my = cx + 62 * math.cos(r + 0.18), cy + 70 * math.sin(r + 0.18)
        d.line([(bx, by), (mx, my), (hx, hy)], fill=C(col), width=15, joint="curve")
        d.ellipse([hx - 15, hy - 12, hx + 15, hy + 12], fill=C(col))
        d.ellipse([hx - 8, hy - 7, hx + 8, hy + 1], fill=C(shade(col, 1.3)))
        for sx in (-1, 1):
            d.ellipse([hx + sx * 7 - 3, hy - 5, hx + sx * 7 + 3, hy + 1], fill=C("#2a1a10"))
        tx, ty = hx + 16 * math.cos(r), hy + 16 * math.sin(r)
        d.line([(hx + 10 * math.cos(r), hy + 10 * math.sin(r)), (tx, ty)], fill=C("#c8323a"), width=3)
    d.ellipse([202, 212, 310, 332], fill=C(skin))
    # bronze eyes, half-lidded; a sly smile
    for sx in (-1, 1):
        ex = 256 + sx * 26
        d.chord([ex - 14, 258, ex + 14, 286], 0, 180, fill=C("#c88a34"))
        d.ellipse([ex - 4, 266, ex + 4, 284], fill=C("#2a1a10"))
        d.line([(ex - 16, 270), (ex + 16, 270)], fill=C("#3a2a2a"), width=5)
        d.line([(ex - 14 * sx, 254), (ex + 12 * sx, 250)], fill=C("#3a4a2a"), width=4)
    d.arc([234, 288, 286, 320], 25, 150, fill=C("#5a2a3a"), width=5)
    d.line([(284, 300), (292, 294)], fill=C("#5a2a3a"), width=5)
    finish(img, "euryale", 301)


def knight_of_shades():
    """A painted knight in black armour climbing out of his frame: red light where a face should be,
    a great sword, and wet black paint still dripping off him."""
    img, d = canvas()
    steel, steel_lt, steel_dk = "#2a2836", "#55557a", "#17161f"
    gold, gold_dk = "#cf9f45", "#946a2a"
    # the frame he came out of, behind him: gilt, with his painted dusk in it
    d.rounded_rectangle([118, 96, 394, 470], 10, fill=C(gold))
    d.rounded_rectangle([132, 110, 380, 456], 6, fill=C(gold_dk))
    d.rectangle([146, 124, 366, 442], fill=C("#7a9aa8"))
    d.rectangle([146, 124, 366, 210], fill=C("#9ab4b8"))
    d.ellipse([300, 150, 344, 194], fill=C("#efd9a0"))
    d.chord([110, 330, 300, 520], 180, 360, fill=C("#6f8a5a"))
    d.chord([220, 350, 420, 540], 180, 360, fill=C("#5a7a4a"))
    d.rectangle([118, 442, 394, 470], fill=C(gold))
    for (x, y) in [(118, 96), (394, 96), (118, 470), (394, 470)]:
        d.ellipse([x - 16, y - 16, x + 16, y + 16], fill=C(gold))
    # legs and sabatons, stepping out over the frame's edge
    for x in (220, 292):
        d.rounded_rectangle([x - 24, 470, x + 24, 590], 12, fill=C(steel))
        d.rounded_rectangle([x - 30, 572, x + 30, 612], 12, fill=C(steel_dk))
        d.ellipse([x - 20, 502, x + 20, 534], fill=C(steel_lt))
    # the body: breastplate and a skirt of plates
    d.rounded_rectangle([174, 300, 338, 480], 34, fill=C(steel))
    d.polygon([(180, 440), (332, 440), (346, 500), (166, 500)], fill=C(steel_dk))
    for x in (206, 238, 274, 306):
        d.line([(x, 446), (x + (x - 256) * 0.1, 496)], fill=C(steel), width=4)
    d.arc([190, 318, 322, 430], 200, 340, fill=C(steel_lt), width=6)
    # pauldrons
    for sx in (-1, 1):
        d.ellipse([256 + sx * 88 - 46, 286, 256 + sx * 88 + 46, 362], fill=C(steel))
        d.arc([256 + sx * 88 - 40, 292, 256 + sx * 88 + 40, 356], 200, 330, fill=C(steel_lt), width=6)
    # the great sword, point down in front of him, both hands on the grip
    d.polygon([(246, 414), (266, 414), (264, 590), (256, 608), (248, 590)], fill=C("#dde2e8"))
    d.line([(256, 420), (256, 588)], fill=C("#a8b0ba"), width=3)
    d.rounded_rectangle([200, 402, 312, 418], 6, fill=C("#b8bcc6"))
    d.ellipse([194, 400, 212, 420], fill=C("#b8bcc6"))
    d.ellipse([300, 400, 318, 420], fill=C("#b8bcc6"))
    d.rounded_rectangle([249, 350, 263, 404], 4, fill=C("#5a2a22"))
    d.ellipse([244, 334, 268, 358], fill=C("#b8bcc6"))
    gs().limb(d, (188, 336), (238, 380), 34, C(steel))
    gs().limb(d, (324, 336), (274, 380), 34, C(steel))
    for x in (240, 272):
        d.ellipse([x - 18, 362, x + 18, 398], fill=C(steel_dk))
    # the helm, with a slit of red light where a face should be
    d.rounded_rectangle([194, 176, 318, 316], 44, fill=C(steel))
    d.polygon([(194, 250), (318, 250), (300, 316), (212, 316)], fill=C(steel))
    d.arc([204, 186, 308, 300], 200, 300, fill=C(steel_lt), width=8)
    d.rectangle([204, 236, 308, 262], fill=C("#0c0a10"))
    d.rectangle([250, 236, 262, 296], fill=C("#0c0a10"))
    d = glow(img, lambda g: (g.rectangle([206, 238, 306, 260], fill=(255, 60, 40, 230)),
                             g.rectangle([252, 238, 260, 292], fill=(255, 60, 40, 200))), 7)
    d.rectangle([212, 244, 300, 254], fill=C("#ff8a5a"))
    d.rectangle([254, 244, 258, 286], fill=C("#ff8a5a"))
    # a ragged crimson plume
    for i, (col, dx) in enumerate([("#6a1a22", -6), ("#8a2430", 4), ("#a8323a", 12)]):
        d.polygon([(250 + dx, 182), (272 + dx, 182), (296 + dx * 2, 120 - i * 8), (268 + dx, 140), (240 + dx, 110 + i * 6)],
                  fill=C(col))
    # wet paint dripping off his edges, and a puddle where he stands
    for (x, y, ln) in [(182, 496, 34), (206, 500, 22), (312, 500, 30), (334, 494, 40), (172, 354, 26), (340, 352, 34)]:
        d.rounded_rectangle([x - 6, y - 4, x + 6, y + ln], 6, fill=C(steel_dk))
        d.ellipse([x - 9, y + ln - 6, x + 9, y + ln + 12], fill=C(steel_dk))
        d.ellipse([x - 4, y + ln - 2, x + 1, y + ln + 4], fill=C("#8a8ab8"))
    d.ellipse([150, 596, 362, 622], fill=C(steel_dk))
    d.ellipse([290, 600, 330, 610], fill=C("#5a5a80"))
    finish(img, "knight_of_shades", 302)


def sentinel():
    """The entrance hall's guard: a bronze suit of armour gone green with age, on a marble plinth with
    a little brass plaque, fists like hams. A statue, until someone touches the donation case."""
    img, d = canvas()
    green, green_dk, bronze = "#5f9e8c", "#3e7064", "#b5823e"
    # the plinth
    d.rounded_rectangle([132, 548, 380, 612], 8, fill=C("#d9d4ca"))
    d.rounded_rectangle([120, 534, 392, 558], 8, fill=C("#ebe7de"))
    d.line([(150, 584), (362, 584)], fill=C("#bdb6aa"), width=4)
    d.rounded_rectangle([224, 564, 288, 592], 4, fill=C("#c9a043"))
    d.line([(234, 574), (278, 574)], fill=C("#7e5a26"), width=3)
    d.line([(234, 582), (268, 582)], fill=C("#7e5a26"), width=3)
    # short thick legs, greaves
    for x in (214, 298):
        d.rounded_rectangle([x - 30, 470, x + 30, 540], 14, fill=C(green))
        d.rounded_rectangle([x - 38, 514, x + 38, 544], 12, fill=C(green_dk))
        d.line([(x - 22, 486), (x + 22, 486)], fill=C(bronze), width=5)
    # a barrel of a breastplate with a ridge down it, a belt
    d.rounded_rectangle([160, 296, 352, 496], 56, fill=C(green))
    d.line([(256, 314), (256, 446)], fill=C(green_dk), width=6)
    d.arc([186, 306, 326, 430], 200, 340, fill=C(bronze), width=6)
    d.arc([200, 330, 312, 446], 210, 330, fill=C(green_dk), width=5)
    d.rectangle([164, 452, 348, 474], fill=C(green_dk))
    d.rectangle([238, 448, 274, 478], fill=C("#d9b24c"))
    # a gorget, big pauldrons, and arms down to huge fists
    d.chord([204, 280, 308, 330], 180, 360, fill=C(green_dk))
    for sx in (-1, 1):
        cx = 256 + sx * 104
        gs().limb(d, (256 + sx * 100, 340), (256 + sx * 118, 430), 46, C(green))
        d.ellipse([cx - 50, 282, cx + 50, 362], fill=C(green))
        d.arc([cx - 42, 290, cx + 42, 354], 200, 330, fill=C(bronze), width=7)
        fx, fy = 256 + sx * 120, 466
        d.ellipse([fx - 40, fy - 38, fx + 40, fy + 38], fill=C(green_dk))
        for k in range(3):
            d.arc([fx - 30, fy - 30 + k * 16, fx + 30, fy + k * 16], 200, 340, fill=C(green), width=5)
        d.arc([fx - 36, fy - 34, fx + 36, fy + 34], 210, 300, fill=C(bronze), width=5)
    # a round helm with a tall comb, and two calm blue lights in its visor
    d.ellipse([190, 166, 322, 304], fill=C(green))
    d.chord([214, 108, 298, 220], 180, 360, fill=C(green_dk))
    d.arc([216, 112, 296, 218], 200, 340, fill=C(bronze), width=5)
    d.arc([200, 176, 312, 296], 200, 300, fill=C(bronze), width=6)
    d.rounded_rectangle([206, 226, 306, 270], 18, fill=C("#1e2a26"))
    d = glow(img, lambda g: [g.ellipse([256 + sx * 24 - 14, 236, 256 + sx * 24 + 14, 262], fill=(120, 200, 255, 220))
                             for sx in (-1, 1)], 6)
    for sx in (-1, 1):
        d.ellipse([256 + sx * 24 - 7, 242, 256 + sx * 24 + 7, 256], fill=C("#dff4ff"))
    d.line([(256, 272), (256, 300)], fill=C(green_dk), width=6)
    finish(img, "sentinel", 303)


def giant_scarab_swarm():
    """Crypt scarabs: a heap of glossy beetles, blue and green with gold edges, on one base,
    a couple taking off from the top."""
    img, d = canvas()
    rng = random.Random(11)
    shells = [("#2a4aa0", "#6a8ae0"), ("#1f7a7a", "#5ac8c0"), ("#2a7040", "#6ab870"), ("#3a3a8a", "#7a7ad8")]
    # the sand they boil up out of
    d.chord([96, 520, 416, 660], 180, 360, fill=C("#d8b878"))
    d.chord([150, 540, 362, 640], 180, 360, fill=C("#e6ca8e"))

    def beetle(cx, cy, s, ang, flying=False):
        layer = Image.new("RGBA", (200, 200), (0, 0, 0, 0))
        b = ImageDraw.Draw(layer)
        sh, hi = shells[rng.randrange(len(shells))]
        for k in (-1, 0, 1):                      # legs
            for sx in (-1, 1):
                b.line([(100 + sx * 26, 104 + k * 18), (100 + sx * 44, 98 + k * 22), (100 + sx * 48, 112 + k * 24)],
                       fill=C("#2a2026"), width=5)
        if flying:
            for sx in (-1, 1):
                b.ellipse([100 + sx * 40 - 26, 54, 100 + sx * 40 + 26, 140], fill=C("#f2ead0", 220))
                b.line([(100 + sx * 22, 64), (100 + sx * 48, 132)], fill=C("#c8b890"), width=3)
        b.ellipse([64, 72, 136, 158], fill=C(sh))            # wing case
        b.ellipse([74, 48, 126, 90], fill=C(shade(sh, 0.7)))  # thorax
        b.ellipse([86, 32, 114, 58], fill=C("#2a2026"))      # head
        b.line([(90, 38), (80, 22)], fill=C("#2a2026"), width=4)
        b.line([(110, 38), (120, 22)], fill=C("#2a2026"), width=4)
        b.line([(100, 88), (100, 156)], fill=C(shade(sh, 0.6)), width=4)
        b.arc([66, 74, 134, 156], 150, 330, fill=C("#e8be52"), width=6)   # a gold rim
        b.arc([76, 50, 124, 88], 180, 360, fill=C("#e8be52"), width=4)
        b.ellipse([78, 92, 98, 120], fill=C(hi))
        b.ellipse([83, 96, 91, 106], fill=(255, 255, 255, 235))
        layer = layer.rotate(ang, resample=Image.BICUBIC)
        layer = layer.resize((int(200 * s), int(200 * s)), Image.LANCZOS)
        img.alpha_composite(layer, (int(cx - 100 * s), int(cy - 100 * s)))

    # a heap: wide at the bottom, the last few on top, two in the air
    spots = []
    for (y, n, half) in [(560, 4, 132), (500, 4, 106), (440, 3, 74), (384, 2, 40)]:
        for i in range(n):
            x = 256 - half + (2 * half) * (i / max(1, n - 1)) + rng.uniform(-10, 10)
            spots.append((y + rng.uniform(-8, 8), x))
    for (y, x) in sorted(spots):
        beetle(x, y, rng.uniform(0.86, 0.96), rng.uniform(-35, 35))
    beetle(176, 300, 0.74, 25, flying=True)
    beetle(336, 262, 0.7, -20, flying=True)
    finish(img, "giant_scarab_swarm", 304)


# ------------------------------------------------------------------ the rest

def bone_construct():
    """The Chamber of Ancients' guardian: gold and bleached bone, three skulls bound in gold and
    jewels, a staff topped with a fanged skull, and scarabs peeping out of the cracks."""
    img, d = canvas()
    bone, bone_dk = "#ece4cc", "#b8ab8a"
    gold, gold_dk = "#d9a93c", "#9a7224"
    eye = "#4ad8c8"

    def skull(cx, cy, r, jewel):
        d.ellipse([cx - r, cy - r, cx + r, cy + r * 0.92], fill=C(bone))
        d.rounded_rectangle([cx - r * 0.6, cy + r * 0.55, cx + r * 0.6, cy + r * 1.05], int(r * 0.2), fill=C(bone))
        d.chord([cx - r * 1.04, cy - r * 1.02, cx + r * 1.04, cy - r * 0.1], 180, 360, fill=C(gold))
        d.rectangle([cx - r * 1.02, cy - r * 0.42, cx + r * 1.02, cy - r * 0.22], fill=C(gold_dk))
        d.ellipse([cx - r * 0.2, cy - r * 0.62, cx + r * 0.2, cy - r * 0.24], fill=C(jewel))
        for sx in (-1, 1):
            ex = cx + sx * r * 0.42
            d.ellipse([ex - r * 0.26, cy - r * 0.12, ex + r * 0.26, cy + r * 0.36], fill=C("#2a2420"))
            d.ellipse([ex - r * 0.1, cy + r * 0.02, ex + r * 0.1, cy + r * 0.22], fill=C(eye))
        d.polygon([(cx - r * 0.1, cy + r * 0.48), (cx + r * 0.1, cy + r * 0.48), (cx, cy + r * 0.62)], fill=C("#2a2420"))
        for k in range(-2, 3):
            x = cx + k * r * 0.2
            d.line([(x, cy + r * 0.72), (x, cy + r * 1.0)], fill=C(bone_dk), width=3)

    d = glow(img, lambda g: g.ellipse([150, 260, 362, 470], fill=(255, 210, 120, 60)), 30)
    # the staff, behind its hand (viewer's left), topped with a fanged skull
    d.line([(130, 604), (138, 170)], fill=C("#7a5236"), width=14)
    for y in (300, 420, 540):
        d.rectangle([126, y, 144, y + 10], fill=C(gold))
    d.ellipse([104, 120, 172, 182], fill=C(bone))
    d.chord([104, 120, 172, 170], 180, 360, fill=C(gold))
    for sx in (-1, 1):
        d.ellipse([138 + sx * 14 - 9, 146, 138 + sx * 14 + 9, 164], fill=C("#2a2420"))
    for x in (126, 150):
        d.polygon([(x - 5, 176), (x + 5, 176), (x, 196)], fill=C("#f4f0e0"))
    # thick leg bones with gold bands, bony feet
    for x in (216, 296):
        d.rounded_rectangle([x - 14, 470, x + 14, 588], 10, fill=C(bone))
        d.rectangle([x - 18, 506, x + 18, 520], fill=C(gold))
        d.ellipse([x - 30, 576, x + 26, 612], fill=C(bone))
    d.ellipse([188, 446, 324, 500], fill=C(bone))
    d.polygon([(180, 460), (332, 460), (318, 530), (194, 530)], fill=C(gold_dk))     # a gold kilt
    for x in range(198, 320, 20):
        d.line([(x, 466), (x - (x - 256) * 0.05, 526)], fill=C(gold), width=8)
    # spine and ribs, banded in gold
    d.rounded_rectangle([248, 320, 264, 470], 6, fill=C(bone))
    for i, y in enumerate(range(352, 452, 24)):
        w = 74 - i * 7
        d.arc([256 - w, y - 18, 256 + w, y + 28], 200, 340, fill=C(bone), width=12)
    d.arc([182, 364, 330, 424], 205, 335, fill=C(gold), width=6)
    # a scarab or two peeping out between the ribs
    for (x, y, col) in [(222, 396, "#2a4aa0"), (292, 420, "#1f7a7a")]:
        d.ellipse([x - 10, y - 8, x + 10, y + 10], fill=C(col))
        d.ellipse([x - 5, y - 13, x + 5, y - 5], fill=C("#2a2026"))
        d.arc([x - 10, y - 8, x + 10, y + 10], 160, 300, fill=C(gold), width=3)
    # arms: one on the staff, one a bony fist
    gs().limb(d, (190, 344), (150, 430), 20, C(bone))
    d.ellipse([124, 412, 166, 454], fill=C(bone))
    d.rectangle([146, 380, 176, 392], fill=C(gold))
    gs().limb(d, (322, 344), (370, 430), 20, C(bone))
    d.ellipse([350, 414, 392, 456], fill=C(bone))
    d.rectangle([336, 380, 366, 392], fill=C(gold))
    # the broad jewelled collar
    d.chord([176, 292, 336, 392], 180, 360, fill=C(gold))
    d.arc([184, 300, 328, 384], 190, 350, fill=C("#2fa0a0"), width=8)
    d.arc([194, 312, 318, 372], 190, 350, fill=C("#c8323a"), width=6)
    for k in range(7):
        a = math.radians(196 + k * 25)
        x, y = 256 + 72 * math.cos(a), 342 + 44 * math.sin(a)
        d.ellipse([x - 6, y - 6, x + 6, y + 6], fill=C("#f4f0e0"))
    # three skulls: one big in the middle, two on its shoulders
    skull(176, 292, 34, "#2fa0a0")
    skull(336, 292, 34, "#2fa0a0")
    skull(256, 236, 54, "#c8323a")
    finish(img, "bone_construct", 305)


def kruthik_huntling():
    """The hunting floor's pack: a low, armoured, many-legged thing with plated back, beady eyes,
    snapping jaws and hooked talons for feet. Side-on, prowling left, low to the ground."""
    img, d = canvas()
    plate, plate_dk, plate_lt = "#9a8a3c", "#5e5222", "#c4b25a"
    belly, claw = "#d8c890", "#f0e6c8"
    leg_col = "#74662a"
    dy = 56                                       # how far down the body sits: short, crouched legs

    def leg(hip, lean, col, w):
        x, y = hip
        knee = (x + lean * 46, y - 64)
        foot = (x + lean * 70, 602)
        d.line([hip, knee], fill=C(col), width=w + 4)
        d.line([knee, foot], fill=C(col), width=w)
        d.ellipse([knee[0] - w / 2 - 3, knee[1] - w / 2 - 3, knee[0] + w / 2 + 3, knee[1] + w / 2 + 3], fill=C(col))
        d.polygon([(foot[0] - 8, 596), (foot[0] + 8, 596), (foot[0] + lean * 6, 614)], fill=C(claw))

    # the far legs, behind the body
    for (x, lean) in [(392, 1), (320, 0.5), (246, -0.8)]:
        leg((x + 14, 470 + dy), lean, "#4a4018", 12)
    # a short segmented tail with a spike
    d.ellipse([400, 410 + dy, 460, 460 + dy], fill=C(plate))
    d.ellipse([440, 396 + dy, 484, 436 + dy], fill=C(plate))
    d.polygon([(468, 400 + dy), (508, 362 + dy), (488, 420 + dy)], fill=C(claw))
    # the body: overlapping plates from the tail to the head, a spiny ridge
    d.ellipse([176, 400 + dy, 420, 506 + dy], fill=C(belly))
    for i, x in enumerate([392, 352, 312, 272, 232]):
        top = 366 - (i % 2) * 6 + dy
        d.polygon([(x - 14, top + 8), (x, top - 40), (x + 14, top + 8)], fill=C(plate_dk))
        d.ellipse([x - 52, top, x + 52, 480 + dy], fill=C(plate))
        d.arc([x - 52, top, x + 52, 480 + dy], 200, 330, fill=C(plate_lt), width=6)
        d.arc([x - 48, top + 6, x + 48, 476 + dy], 100, 170, fill=C(plate_dk), width=6)
    # the near legs, knees up over its flank
    for (x, lean) in [(380, 1), (308, 0.5), (236, -0.8)]:
        leg((x, 486 + dy), lean, leg_col, 14)
    # the head: a plated wedge with a crest, three beady eyes, big hooked jaws
    d.ellipse([96, 340 + dy, 232, 456 + dy], fill=C(plate))
    d.chord([96, 332 + dy, 232, 424 + dy], 180, 360, fill=C(plate_lt))
    d.polygon([(150, 346 + dy), (196, 300 + dy), (204, 352 + dy)], fill=C(plate_dk))
    d.arc([104, 348 + dy, 224, 424 + dy], 190, 300, fill=C(plate_dk), width=6)
    for (x, y) in [(136, 382), (164, 372), (190, 384)]:
        d.ellipse([x - 11, y - 10 + dy, x + 11, y + 10 + dy], fill=C("#f4d24a"))
        d.ellipse([x - 4, y - 4 + dy, x + 4, y + 4 + dy], fill=C("#1f1a14"))
    d.chord([74, 404 + dy, 140, 470 + dy], 90, 270, fill=C("#5a2420"))
    d.polygon([(118, 410 + dy), (78, 396 + dy), (44, 416 + dy), (52, 430 + dy), (80, 418 + dy), (108, 432 + dy)],
              fill=C(claw))                                                                               # upper jaw
    d.polygon([(118, 456 + dy), (82, 470 + dy), (48, 456 + dy), (54, 444 + dy), (84, 452 + dy), (110, 440 + dy)],
              fill=C(claw))                                                                               # lower jaw
    finish(img, "kruthik_huntling", 306)


def the_lecturer():
    """The ghost of the lecture room: a gaunt, see-through man in a gown and a scholar's cap at his
    lectern, round spectacles over eyes like milk, a pointer, and no mouth at all."""
    gown, gown_dk = "#b8b4cc", "#8e8aa8"
    skin = "#dcdae8"
    ghost, g = canvas()
    # a wisp of a body: no feet, a tail of gown trailing behind the lectern
    g.polygon([(200, 320), (312, 320), (350, 520), (318, 590), (286, 548), (256, 600), (226, 548), (194, 590), (162, 520)],
              fill=C(gown))
    g.polygon([(236, 330), (276, 330), (286, 520), (226, 520)], fill=C(gown_dk))
    # the pointer arm (viewer's right) and the arm on the lectern (viewer's left)
    gs().limb(g, (316, 350), (372, 300), 30, C(gown))
    g.ellipse([362, 282, 392, 312], fill=C(skin))
    g.line([(380, 294), (440, 150)], fill=C("#8a6a4a"), width=8)
    g.ellipse([434, 140, 448, 154], fill=C("#d8cfa8"))
    gs().limb(g, (196, 350), (188, 420), 30, C(gown))
    # a long, gaunt head under a scholar's cap
    g.ellipse([196, 170, 316, 330], fill=C(skin))
    for sx in (-1, 1):
        g.ellipse([256 + sx * 34 - 12, 266, 256 + sx * 34 + 12, 300], fill=C("#c4c0d6"))
    for sx in (-1, 1):
        ex = 256 + sx * 26
        g.ellipse([ex - 15, 236, ex + 15, 262], fill=C("#fbfaf4"))
        g.ellipse([ex - 22, 228, ex + 22, 270], outline=C("#4a4858"), width=5)
    g.line([(248, 248), (264, 248)], fill=C("#4a4858"), width=5)
    for sx in (-1, 1):
        g.line([(256 + sx * 12, 222), (256 + sx * 40, 216)], fill=C("#8e8aa8"), width=6)
    g.polygon([(156, 176), (256, 136), (356, 176), (256, 214)], fill=C("#4a4858"))
    g.rounded_rectangle([206, 176, 306, 206], 8, fill=C("#3a3848"))
    g.line([(256, 172), (336, 186), (342, 236)], fill=C("#d9b24c"), width=5)
    g.ellipse([334, 230, 350, 250], fill=C("#d9b24c"))
    gs_ = gs()
    ghost = gs_.outline(gs_.painterly(ghost, 307), 4)
    a = np.asarray(ghost).astype(float)
    a[..., 3] *= 0.8
    ghost = Image.fromarray(a.astype(np.uint8), "RGBA")
    glow(ghost, lambda gl: [gl.ellipse([256 + sx * 26 - 16, 234, 256 + sx * 26 + 16, 264], fill=(255, 255, 240, 200))
                            for sx in (-1, 1)], 6)
    # the lectern in front of him, solid wood, with an open book of notes
    lect, l = canvas()
    l.polygon([(204, 452), (308, 452), (296, 590), (216, 590)], fill=C("#7a5236"))
    l.rounded_rectangle([180, 584, 332, 612], 8, fill=C("#5e3e26"))
    l.line([(256, 470), (256, 576)], fill=C("#5e3e26"), width=6)
    l.polygon([(160, 420), (352, 420), (366, 462), (146, 462)], fill=C("#8a6040"))
    l.polygon([(174, 410), (254, 420), (254, 446), (170, 436)], fill=C("#f4eedc"))
    l.polygon([(258, 420), (338, 410), (342, 436), (258, 446)], fill=C("#f4eedc"))
    for k in range(3):
        l.line([(184, 418 + k * 7), (244, 426 + k * 7)], fill=C("#9a907a"), width=2)
        l.line([(268, 426 + k * 7), (330, 418 + k * 7)], fill=C("#9a907a"), width=2)
    l.ellipse([168, 404, 196, 428], fill=C(skin))          # his hand on the book
    lect = gs_.outline(gs_.painterly(lect, 308), 4)
    ghost.alpha_composite(lect)
    fig = gs_.paper_border(ghost)
    fig.resize((fig.width // 2, fig.height // 2), Image.LANCZOS).save(path(SPR, "the_lecturer.png"))


def steam_mech():
    """The World of Tomorrow's pride: eight feet of brass plate over clockwork, a green battery
    glowing behind its helmet, a panel in its chest with a red switch, a steam fist, a chain gun,
    and missiles tucked into its shoulders."""
    img, d = canvas()
    brass, brass_dk, brass_lt, copper = "#d0a446", "#8e6a26", "#ecc874", "#b8693a"
    iron = "#4a4650"
    # steam puffing from a stack behind its shoulder
    for (x, y, r) in [(372, 132, 22), (392, 104, 28), (366, 82, 20)]:
        d.ellipse([x - r, y - r, x + r, y + r], fill=C("#f2f0ec", 230))
    d.rounded_rectangle([346, 140, 370, 230], 6, fill=C(iron))
    # the green battery behind its helmet
    d = glow(img, lambda g: g.ellipse([190, 120, 322, 230], fill=(120, 255, 140, 170)), 16)
    d.rounded_rectangle([222, 130, 290, 200], 14, fill=C("#5ae07a"))
    d.rounded_rectangle([236, 142, 276, 190], 10, fill=C("#c8ffd0"))
    # piston legs, big feet, gears at the knees
    for x in (208, 304):
        d.rounded_rectangle([x - 22, 480, x + 22, 584], 8, fill=C(iron))
        d.rounded_rectangle([x - 30, 470, x + 30, 530], 10, fill=C(brass))
        gear(d, x, 540, 22, 8, copper, brass_dk)
        d.rounded_rectangle([x - 44, 574, x + 40, 612], 14, fill=C(brass_dk))
    # the barrel body, riveted, with the chest panel and its red switch
    d.rounded_rectangle([156, 284, 356, 498], 46, fill=C(brass))
    d.arc([170, 296, 342, 490], 200, 300, fill=C(brass_lt), width=8)
    for y in (300, 480):
        for x in range(182, 340, 22):
            d.ellipse([x - 4, y - 4, x + 4, y + 4], fill=C(brass_dk))
    d.rounded_rectangle([204, 330, 308, 440], 10, fill=C(brass_dk))
    d.rounded_rectangle([212, 338, 300, 432], 6, fill=C("#2a2830"))
    for k in range(1, 4):
        d.line([(212 + k * 22, 342), (212 + k * 22, 396)], fill=C("#5ae07a", 180), width=2)
        d.line([(216, 340 + k * 14), (296, 340 + k * 14)], fill=C("#5ae07a", 180), width=2)
    d.rounded_rectangle([238, 404, 274, 426], 4, fill=C("#e8e2d0"))
    d.rounded_rectangle([248, 398, 264, 420], 4, fill=C("#d8322a"))
    # shoulder pods with missiles peeking out
    for sx in (-1, 1):
        cx = 256 + sx * 116
        d.rounded_rectangle([cx - 40, 262, cx + 40, 320], 12, fill=C(copper))
        for k in (-1, 0, 1):
            mx = cx + k * 22
            d.rounded_rectangle([mx - 7, 244, mx + 7, 270], 4, fill=C("#e8e2d0"))
            d.polygon([(mx - 7, 248), (mx + 7, 248), (mx, 234)], fill=C("#d8322a"))
    # the steam fist (viewer's left)
    gs().limb(d, (160, 320), (128, 420), 30, C(iron))
    gear(d, 150, 368, 20, 8, copper, brass_dk)
    d.rounded_rectangle([92, 410, 168, 484], 22, fill=C(brass))
    for k in range(3):
        d.line([(104, 426 + k * 18), (156, 426 + k * 18)], fill=C(brass_dk), width=5)
    # the chain gun (viewer's right)
    gs().limb(d, (352, 320), (384, 400), 30, C(iron))
    d.rounded_rectangle([360, 390, 420, 450], 12, fill=C(brass_dk))
    for k in range(3):
        d.rounded_rectangle([372 + k * 14, 444, 382 + k * 14, 530], 4, fill=C(iron))
    d.rounded_rectangle([364, 520, 418, 534], 4, fill=C(brass_dk))
    # the helmet: a dome with a round window and two lamp eyes
    d.ellipse([188, 164, 324, 300], fill=C(brass))
    d.arc([198, 174, 314, 290], 200, 300, fill=C(brass_lt), width=8)
    d.ellipse([206, 206, 306, 286], fill=C(brass_dk))
    d.ellipse([214, 214, 298, 278], fill=C("#3a4a5a"))
    d = glow(img, lambda g: [g.ellipse([256 + sx * 20 - 14, 232, 256 + sx * 20 + 14, 260], fill=(255, 200, 90, 220))
                             for sx in (-1, 1)], 5)
    for sx in (-1, 1):
        d.ellipse([256 + sx * 20 - 9, 237, 256 + sx * 20 + 9, 255], fill=C("#ffe8a8"))
    d.arc([236, 252, 276, 272], 20, 160, fill=C("#ffe8a8"), width=4)
    d.ellipse([250, 152, 262, 170], fill=C(copper))
    finish(img, "steam_mech", 309)


def telpur():
    """The gift shop's talking boot, once (it says) a great lord of the underworld: a tall leather
    boot with a curled, pointed toe, two little horns at its cuff, bored half-lidded eyes, and laces
    that curl into a grand moustache."""
    img, d = canvas()
    leather, leather_dk, leather_lt = "#7a3a2c", "#4e2218", "#a85a40"
    # the foot, with a pointed toe that curls up (toward the viewer's left), and the sole
    d.polygon([(206, 520), (316, 520), (330, 600), (110, 600), (84, 586), (60, 540), (82, 552), (110, 566), (196, 560)],
              fill=C(leather))
    d.ellipse([48, 520, 80, 552], fill=C(leather))
    d.rounded_rectangle([100, 592, 340, 614], 8, fill=C("#2e1a12"))
    d.rounded_rectangle([290, 584, 346, 614], 6, fill=C("#2e1a12"))       # the heel
    d.arc([120, 540, 250, 600], 200, 330, fill=C(leather_lt), width=6)
    # the shaft
    d.rounded_rectangle([196, 300, 320, 580], 34, fill=C(leather))
    d.arc([204, 308, 312, 560], 200, 260, fill=C(leather_lt), width=8)
    # the laces down its front, criss-crossed
    for k in range(4):
        y = 446 + k * 30
        d.line([(232, y), (284, y + 22)], fill=C("#efe4cc"), width=6)
        d.line([(284, y), (232, y + 22)], fill=C("#efe4cc"), width=6)
        for x in (230, 286):
            d.ellipse([x - 5, y - 5, x + 5, y + 5], fill=C("#d9b24c"))
    # the folded cuff, and two little horns
    d.rounded_rectangle([182, 284, 334, 334], 18, fill=C(leather_dk))
    d.arc([188, 288, 328, 330], 200, 340, fill=C(leather_lt), width=5)
    for sx in (-1, 1):
        x = 256 + sx * 50
        d.polygon([(x - 16, 294), (x + 16, 294), (x + sx * 30, 250), (x + sx * 34, 222), (x + sx * 14, 252)],
                  fill=C("#a8322a"))
        d.polygon([(x + sx * 24, 246), (x + sx * 34, 222), (x + sx * 20, 240)], fill=C("#e8c8a0"))
    # bored eyes, half shut, and a grand moustache of laces
    for sx in (-1, 1):
        ex = 256 + sx * 28
        d.ellipse([ex - 18, 352, ex + 18, 388], fill=C("#f4f0e0"))
        d.ellipse([ex - 7, 366, ex + 7, 384], fill=C("#2a1d1a"))
        d.chord([ex - 19, 350, ex + 19, 386], 180, 360, fill=C(leather_dk))
        d.line([(ex - 20, 368), (ex + 20, 368)], fill=C("#2a1d1a"), width=5)
    for sx in (-1, 1):
        # each half of the moustache: a fat sweep of lace out from the middle, curling up at the end
        x0, x1 = (250, 340) if sx > 0 else (172, 262)
        d.chord([x0, 398, x1, 438], 0, 180, fill=C("#efe4cc"))
        cx = 256 + sx * 86
        d.arc([cx - 14, 396, cx + 14, 424], 180 if sx > 0 else 90, 90 if sx > 0 else 0, fill=C("#efe4cc"), width=9)
    d.ellipse([244, 396, 268, 418], fill=C("#d9b24c"))
    finish(img, "telpur", 310)


def flitwidget():
    """Formicarius Flitwidget, the gnome who owns the museum: a huge blond moustache, a feathered top
    hat, a showman's red coat, a broom in one hand and one of his own Francs held up in the other."""
    img, d = canvas()
    skin = "#f0c49c"
    coat, coat_dk = "#b0342e", "#7e2420"
    stache = "#ecc65a"
    # the broom (viewer's left), bristles at the bottom
    d.line([(150, 600), (142, 300)], fill=C("#8a6040"), width=12)
    d.polygon([(124, 520), (164, 520), (186, 612), (102, 612)], fill=C("#d8b860"))
    d.rectangle([122, 520, 166, 534], fill=C("#a83a32"))
    for x in range(112, 182, 12):
        d.line([(x + (x - 144) * 0.1, 540), (x + (x - 144) * 0.3, 606)], fill=C("#b8963c"), width=3)
    # short legs, pointy shoes
    for x in (228, 284):
        d.rounded_rectangle([x - 14, 520, x + 14, 584], 10, fill=C("#3a3a4a"))
    d.polygon([(196, 576), (244, 576), (244, 608), (176, 608), (170, 594)], fill=C("#2a1d1a"))
    d.polygon([(268, 576), (316, 576), (342, 594), (336, 608), (268, 608)], fill=C("#2a1d1a"))
    # the showman's coat with tails, a yellow waistcoat, gold buttons
    d.polygon([(196, 380), (316, 380), (346, 556), (166, 556)], fill=C(coat))
    d.polygon([(228, 384), (284, 384), (280, 520), (232, 520)], fill=C("#e8b840"))
    for y in (410, 444, 478):
        d.ellipse([250, y - 6, 262, y + 6], fill=C("#8a5a20"))
    d.polygon([(196, 380), (232, 384), (228, 470)], fill=C(coat_dk))
    d.polygon([(316, 380), (280, 384), (284, 470)], fill=C(coat_dk))
    d.line([(170, 552), (342, 552)], fill=C("#d9b24c"), width=6)
    # the broom arm, and the arm holding up a Flitwidget Franc
    gs().limb(d, (200, 404), (152, 440), 28, C(coat))
    hand(d, (146, 440), skin, 15)
    gs().limb(d, (312, 404), (360, 350), 28, C(coat))
    hand(d, (364, 344), skin, 15)
    d.polygon([(352, 300), (420, 282), (430, 326), (362, 344)], fill=C("#5aa860"))
    d.polygon([(358, 306), (414, 291), (422, 320), (366, 336)], fill=C("#8ad08a"))
    d.ellipse([380, 298, 400, 318], fill=C("#f0c49c"))
    d.line([(384, 312), (398, 309)], fill=C(stache), width=3)
    # a big head, a round nose, beaming eyes, rosy cheeks
    d.ellipse([170, 216, 342, 392], fill=C(skin))
    for sx in (-1, 1):
        d.ellipse([256 + sx * 86 - 14, 290, 256 + sx * 86 + 14, 330], fill=C(skin))
    gs().eyes(d, 256, 290, sep=36, happy=True)
    gs().blush(d, 256, 318, sep=56)
    d.line([(204, 266), (236, 262)], fill=C("#c8a040"), width=8)
    d.line([(308, 266), (276, 262)], fill=C("#c8a040"), width=8)
    # the huge moustache, then the nose on top of it
    d.ellipse([168, 322, 256, 366], fill=C(stache))
    d.ellipse([256, 322, 344, 366], fill=C(stache))
    for sx in (-1, 1):
        d.ellipse([256 + sx * 96 - 18, 316, 256 + sx * 96 + 18, 348], fill=C(stache))
        d.arc([256 + sx * 100 - 18, 300, 256 + sx * 100 + 18, 336], 0 if sx > 0 else 90, 180 if sx > 0 else 270,
              fill=C(stache), width=9)
    d.arc([186, 330, 326, 362], 200, 340, fill=C("#c8a040"), width=4)
    d.ellipse([232, 300, 280, 342], fill=C("#e8a07c"))
    d.ellipse([242, 306, 256, 318], fill=C("#f8d0b8"))
    d.chord([236, 352, 276, 380], 0, 180, fill=C("#7a3028"))
    # the feathered top hat
    d.ellipse([168, 214, 344, 244], fill=C("#2a4a5a"))
    d.rounded_rectangle([196, 96, 316, 230], 10, fill=C("#2f5a6a"))
    d.rectangle([196, 196, 316, 220], fill=C("#d9b24c"))
    plume = [(304, 204), (318, 150), (340, 104), (372, 70), (396, 62), (384, 90), (362, 128), (340, 170), (318, 210)]
    d.polygon(plume, fill=C("#d8573a"))
    d.line([(310, 204), (334, 140), (366, 92), (392, 66)], fill=C("#f0a050"), width=5, joint="curve")
    for (x, y) in [(346, 112), (330, 150), (362, 96)]:
        d.line([(x, y), (x + 22, y + 10)], fill=C("#a83a2a"), width=4)
    d.ellipse([294, 190, 316, 214], fill=C("#5aa860"))
    finish(img, "flitwidget", 311)


def exhibit_b():
    """Exhibit B, Pip's museum rat: sitting up, big ears and bright eyes, a crumb of cheese in his
    paws, and a little exhibit label on a string round his neck."""
    img, d = canvas()
    fur, fur_dk, fur_lt, pink = "#9a8678", "#6e5e54", "#d8cabc", "#e8a0a0"
    # the tail curling round on the floor
    tail = [(300, 590), (350, 604), (398, 590), (420, 556), (410, 520), (386, 508)]
    for i in range(len(tail) - 1):
        d.line([tail[i], tail[i + 1]], fill=C(pink), width=14 - i * 2)
        x, y = tail[i + 1]
        r = (14 - i * 2) / 2
        d.ellipse([x - r, y - r, x + r, y + r], fill=C(pink))
    # a round body sitting up, a pale belly, feet
    d.ellipse([186, 420, 326, 600], fill=C(fur))
    d.ellipse([214, 456, 298, 592], fill=C(fur_lt))
    for sx in (-1, 1):
        d.ellipse([256 + sx * 44 - 26, 584, 256 + sx * 44 + 26, 612], fill=C(pink))
    # a crumb of cheese in his paws
    d.polygon([(230, 472), (290, 456), (286, 500), (232, 506)], fill=C("#f0c64a"))
    d.polygon([(230, 472), (290, 456), (276, 448), (226, 462)], fill=C("#f8dc7a"))
    for (x, y, r) in [(250, 484, 6), (272, 476, 5), (262, 494, 4)]:
        d.ellipse([x - r, y - r, x + r, y + r], fill=C("#d8a83a"))
    for sx in (-1, 1):
        d.ellipse([256 + sx * 34 - 14, 470, 256 + sx * 34 + 14, 496], fill=C(pink))
    # the head: big round ears, bright eyes, a pink nose, whiskers
    for sx in (-1, 1):
        ex = 256 + sx * 62
        d.ellipse([ex - 40, 290, ex + 40, 370], fill=C(fur))
        d.ellipse([ex - 26, 304, ex + 26, 358], fill=C(pink))
    d.ellipse([188, 318, 324, 440], fill=C(fur))
    d.ellipse([220, 370, 292, 438], fill=C(fur_lt))
    gs().eyes(d, 256, 370, sep=30, r=(11, 13))
    gs().blush(d, 256, 398, sep=46)
    d.ellipse([244, 400, 268, 418], fill=C("#d86a7a"))
    for sx in (-1, 1):
        for k in (-1, 1):
            d.line([(256 + sx * 20, 412 + k * 4), (256 + sx * 76, 404 + k * 12)], fill=C(fur_dk), width=3)
    d.arc([240, 412, 272, 432], 20, 160, fill=C("#4a2a22"), width=4)
    # the exhibit label on a string: a little card with a B on it
    d.line([(222, 438), (256, 462), (290, 438)], fill=C("#8a6040"), width=3)
    d.rounded_rectangle([272, 446, 318, 482], 4, fill=C("#f6f0dc"))
    d.line([(287, 453), (287, 475)], fill=C("#3a2a22"), width=4)
    d.arc([275, 453, 301, 465], 270, 90, fill=C("#3a2a22"), width=4)
    d.arc([275, 463, 305, 475], 270, 90, fill=C("#3a2a22"), width=4)
    finish(img, "exhibit_b", 312)


FIRST = [euryale, knight_of_shades, sentinel, giant_scarab_swarm]
REST = [bone_construct, kruthik_huntling, the_lecturer, steam_mech, telpur, flitwidget, exhibit_b]
BUILD = FIRST + REST


def build_all(names=None):
    for f in BUILD:
        if not names or f.__name__ in names:
            f()


if __name__ == "__main__":
    build_all(sys.argv[1:])
    print("museum minis:", ", ".join(f.__name__ for f in BUILD if len(sys.argv) < 2 or f.__name__ in sys.argv[1:]))
