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


FIRST = [euryale, knight_of_shades, sentinel, giant_scarab_swarm]
BUILD = FIRST


def build_all(names=None):
    for f in BUILD:
        if not names or f.__name__ in names:
            f()


if __name__ == "__main__":
    build_all(sys.argv[1:])
    print("museum minis:", ", ".join(f.__name__ for f in BUILD if len(sys.argv) < 2 or f.__name__ in sys.argv[1:]))
