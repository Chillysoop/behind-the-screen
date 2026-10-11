"""Painted sprites: paper-standee minis, the four players, and glow effects.

Everything is drawn at 2x and downsampled, then given a painterly finish.
Minis get a white paper border like real paper standees.
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from gen_common import path, hexc, tile_noise, smoothstep, brush_strokes, to_img

SPR = "assets/sprites"
OUTLINE = (38, 26, 22, 255)


def C(h, a=255):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


def limb(d, p0, p1, width, color):
    d.line([p0, p1], fill=color, width=width)
    for (x, y) in (p0, p1):
        r = width / 2
        d.ellipse([x - r, y - r, x + r, y + r], fill=color)


def eyes(d, cx, cy, sep=34, r=(9, 12), happy=False, color="#2a1d1a"):
    for sx in (-1, 1):
        ex = cx + sx * sep
        if happy:
            d.arc([ex - 13, cy - 8, ex + 13, cy + 14], 200, 340, fill=C(color), width=6)
        else:
            d.ellipse([ex - r[0], cy - r[1], ex + r[0], cy + r[1]], fill=C(color))
            d.ellipse([ex - 3, cy - 8, ex + 3, cy - 2], fill=(255, 255, 255, 230))


def blush(d, cx, cy, sep=52):
    for sx in (-1, 1):
        x = cx + sx * sep
        d.ellipse([x - 13, cy - 6, x + 13, cy + 6], fill=(230, 120, 110, 110))


def smile(d, cx, cy, w=22, open_=False):
    if open_:
        d.chord([cx - w, cy - 10, cx + w, cy + 22], 0, 180, fill=C("#5a2420"))
        d.chord([cx - w + 6, cy + 6, cx + w - 6, cy + 22], 200, 340, fill=C("#d96a6a"))
    else:
        d.arc([cx - w, cy - 12, cx + w, cy + 12], 20, 160, fill=C("#4a2a22"), width=5)


def painterly(fig, seed, light=True):
    arr = np.asarray(fig).astype(float)
    h, w = arr.shape[:2]
    y, x = np.mgrid[0:h, 0:w]
    n = tile_noise(w, h, max(2, w // 40), max(2, h // 40), seed, 4)
    shade = 1.0 + 0.10 * (n - 0.5)
    if light:
        shade *= 1.12 - 0.22 * (y / h) - 0.08 * (x / w)
    arr[..., :3] *= shade[..., None]
    out = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")
    mask = out.getchannel("A").point(lambda v: 255 if v > 200 else 0)
    return brush_strokes(out, mask, 2600, seed + 1, length=(5, 14), width=(2, 5), jitter=0.08, alpha=70)


def outline(fig, px=3, color=OUTLINE):
    a = fig.getchannel("A").point(lambda v: 255 if v > 100 else 0)
    ring = a.filter(ImageFilter.MaxFilter(px * 2 + 1))
    out = Image.new("RGBA", fig.size, (0, 0, 0, 0))
    out.paste(color, mask=ring)
    out.alpha_composite(fig)
    return out


def paper_border(fig, border=13):
    a = fig.getchannel("A").point(lambda v: 255 if v > 100 else 0)
    paper = a.filter(ImageFilter.MaxFilter(border * 2 + 1)).filter(ImageFilter.GaussianBlur(4)).point(
        lambda v: 255 if v > 100 else 0)
    edge = paper.filter(ImageFilter.MaxFilter(5))
    out = Image.new("RGBA", fig.size, (0, 0, 0, 0))
    out.paste((92, 74, 60, 255), mask=edge)
    out.paste((247, 240, 224, 255), mask=paper)
    out.alpha_composite(fig)
    return out


def finish_mini(fig, name, seed):
    fig = painterly(fig, seed)
    fig = outline(fig, 4)
    fig = paper_border(fig)
    fig.resize((fig.width // 2, fig.height // 2), Image.LANCZOS).save(path(SPR, name + ".png"))


def new_canvas(w=512, h=640):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def boots_and_legs(d, leg, boot, top=500):
    d.rounded_rectangle([214, top, 248, 592], 14, fill=C(leg))
    d.rounded_rectangle([264, top, 298, 592], 14, fill=C(leg))
    d.rounded_rectangle([198, 568, 252, 612], 18, fill=C(boot))
    d.rounded_rectangle([260, 568, 314, 612], 18, fill=C(boot))


def fighter():
    img, d = new_canvas()
    skin = "#f0c49c"
    boots_and_legs(d, "#4b4b55", "#4a3326")
    # sword arm (viewer's left), raised
    limb(d, (196, 360), (150, 282), 38, C("#9aa0a8"))
    d.polygon([(132, 262), (152, 262), (130, 60), (112, 72)], fill=C("#dfe4ea"))
    d.line([(142, 255), (122, 80)], fill=C("#a8b0ba"), width=4)
    d.rounded_rectangle([108, 262, 178, 280], 8, fill=C("#d9b24c"))
    d.ellipse([136, 276, 160, 300], fill=C(skin))
    # torso: chainmail under a blue tabard
    d.polygon([(186, 330), (326, 330), (346, 520), (166, 520)], fill=C("#9aa0a8"))
    d.polygon([(214, 340), (298, 340), (310, 530), (202, 530)], fill=C("#3d6db5"))
    d.line([(214, 340), (202, 530)], fill=C("#d9b24c"), width=6)
    d.line([(298, 340), (310, 530)], fill=C("#d9b24c"), width=6)
    d.rectangle([180, 470, 332, 490], fill=C("#5a3a24"))
    d.rectangle([244, 466, 268, 494], fill=C("#d9b24c"))
    # shield arm (viewer's right)
    limb(d, (318, 360), (340, 430), 38, C("#9aa0a8"))
    d.ellipse([262, 352, 422, 512], fill=C("#d9b24c"))
    d.ellipse([274, 364, 410, 500], fill=C("#a83a32"))
    d.polygon([(342, 392), (382, 432), (342, 472), (302, 432)], fill=C("#f1e6cf"))
    d.ellipse([330, 420, 354, 444], fill=C("#d9b24c"))
    # head + helmet
    d.ellipse([176, 172, 336, 332], fill=C(skin))
    d.pieslice([168, 156, 344, 336], 180, 360, fill=C("#b8bec6"))
    d.rectangle([168, 236, 344, 254], fill=C("#8c939c"))
    d.rectangle([248, 236, 264, 290], fill=C("#8c939c"))
    for i, col in enumerate(["#c0392b", "#d9483a", "#a83226"]):
        d.ellipse([236 + i * 8, 112 - i * 6, 276 + i * 8, 172 - i * 6], fill=C(col))
    eyes(d, 256, 280, sep=36)
    blush(d, 256, 302)
    smile(d, 256, 312, 18)
    finish_mini(img, "fighter", 101)


def rogue():
    img, d = new_canvas()
    skin = "#d9a27a"
    boots_and_legs(d, "#3b2e26", "#1f1a18")
    # cloak
    d.polygon([(256, 170), (380, 560), (330, 590), (182, 590), (132, 560)], fill=C("#2f5a3c"))
    d.polygon([(256, 230), (330, 540), (182, 540)], fill=C("#3f6e4a"))
    # arms with daggers
    limb(d, (200, 380), (160, 470), 34, C("#3f6e4a"))
    limb(d, (312, 380), (352, 470), 34, C("#3f6e4a"))
    d.ellipse([146, 456, 174, 484], fill=C(skin))
    d.ellipse([338, 456, 366, 484], fill=C(skin))
    d.polygon([(158, 470), (166, 470), (150, 540), (144, 534)], fill=C("#dfe4ea"))
    d.polygon([(346, 470), (354, 470), (368, 534), (362, 540)], fill=C("#dfe4ea"))
    d.rectangle([150, 462, 174, 472], fill=C("#7a5236"))
    d.rectangle([338, 462, 362, 472], fill=C("#7a5236"))
    # scarf
    d.rounded_rectangle([200, 316, 312, 352], 16, fill=C("#7a2f3a"))
    d.polygon([(286, 340), (312, 340), (300, 410), (280, 404)], fill=C("#7a2f3a"))
    # hood with face in shadow
    d.ellipse([160, 150, 352, 352], fill=C("#2f5a3c"))
    d.polygon([(256, 110), (300, 170), (212, 170)], fill=C("#2f5a3c"))
    d.ellipse([190, 196, 322, 330], fill=C("#2b2622"))
    d.ellipse([200, 230, 312, 330], fill=C(skin))
    eyes(d, 256, 276, sep=28, r=(8, 10))
    d.line([(214, 252), (240, 262)], fill=C("#2a1d1a"), width=6)
    d.line([(298, 252), (272, 262)], fill=C("#2a1d1a"), width=6)
    d.arc([236, 294, 276, 318], 10, 150, fill=C("#4a2a22"), width=5)
    finish_mini(img, "rogue", 102)


def cleric():
    img, d = new_canvas()
    skin = "#8d5a3b"
    d.rounded_rectangle([200, 568, 254, 612], 18, fill=C("#6a4a30"))
    d.rounded_rectangle([258, 568, 312, 612], 18, fill=C("#6a4a30"))
    # robe and tabard
    d.polygon([(190, 330), (322, 330), (356, 590), (156, 590)], fill=C("#efe9dc"))
    d.line([(156, 586), (356, 586)], fill=C("#d9b24c"), width=10)
    d.polygon([(220, 340), (292, 340), (300, 560), (212, 560)], fill=C("#d9b24c"))
    d.polygon([(226, 346), (286, 346), (292, 552), (220, 552)], fill=C("#f6f1e6"))
    sx, sy = 256, 430
    for a in np.linspace(0, 2 * np.pi, 13)[:-1]:
        d.line([(sx, sy), (sx + np.cos(a) * 34, sy + np.sin(a) * 34)], fill=C("#d9a83c"), width=6)
    d.ellipse([sx - 20, sy - 20, sx + 20, sy + 20], fill=C("#e9b949"))
    # mace arm (viewer's left)
    limb(d, (198, 360), (166, 450), 36, C("#efe9dc"))
    d.ellipse([152, 436, 180, 464], fill=C(skin))
    d.line([(166, 450), (150, 330)], fill=C("#6b4a32"), width=12)
    d.ellipse([124, 290, 176, 342], fill=C("#8c939c"))
    for a in np.linspace(0, 2 * np.pi, 7)[:-1]:
        d.polygon([(150 + np.cos(a) * 22, 316 + np.sin(a) * 22), (150 + np.cos(a + 0.3) * 34, 316 + np.sin(a + 0.3) * 34),
                   (150 + np.cos(a + 0.6) * 22, 316 + np.sin(a + 0.6) * 22)], fill=C("#a3aab3"))
    # raised hand with a glowing holy symbol (viewer's right)
    limb(d, (314, 360), (360, 290), 36, C("#efe9dc"))
    d.ellipse([346, 276, 374, 304], fill=C(skin))
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([318, 210, 410, 302], fill=(255, 230, 140, 150))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(10)))
    d.ellipse([346, 236, 382, 272], fill=C("#f3cf63"))
    d.ellipse([356, 246, 372, 262], fill=C("#fff4cc"))
    # head
    d.ellipse([176, 172, 336, 332], fill=C(skin))
    d.chord([170, 160, 342, 300], 180, 360, fill=C("#2a1d1a"))
    d.rectangle([176, 214, 336, 226], fill=C("#d9b24c"))
    eyes(d, 256, 268, sep=36)
    blush(d, 256, 292)
    smile(d, 256, 302, 20, open_=True)
    finish_mini(img, "cleric", 103)


def wizard():
    img, d = new_canvas()
    skin = "#f2c9a0"
    d.rounded_rectangle([204, 568, 254, 612], 18, fill=C("#3a2a4a"))
    d.rounded_rectangle([258, 568, 308, 612], 18, fill=C("#3a2a4a"))
    # staff (behind the body)
    d.line([(372, 600), (360, 180)], fill=C("#6b4a32"), width=14)
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([312, 116, 412, 216], fill=(120, 230, 255, 170))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(12)))
    d.ellipse([336, 140, 388, 192], fill=C("#7fe6ff"))
    d.ellipse([348, 150, 368, 170], fill=C("#e8fbff"))
    # robe with stars
    d.polygon([(196, 320), (316, 320), (350, 596), (162, 596)], fill=C("#5b3a8a"))
    d.polygon([(240, 330), (272, 330), (282, 596), (230, 596)], fill=C("#4a2f72"))
    for (x, y, r) in [(206, 420, 10), (300, 470, 8), (190, 530, 9), (318, 380, 7), (262, 540, 7)]:
        pts = []
        for k in range(10):
            a = -np.pi / 2 + k * np.pi / 5
            rr = r if k % 2 == 0 else r * 0.45
            pts.append((x + np.cos(a) * rr, y + np.sin(a) * rr))
        d.polygon(pts, fill=C("#f0c75a"))
    d.rectangle([186, 450, 326, 466], fill=C("#d9b24c"))
    # arms
    limb(d, (318, 360), (358, 420), 38, C("#5b3a8a"))
    d.ellipse([344, 404, 376, 436], fill=C(skin))
    limb(d, (194, 360), (170, 452), 38, C("#5b3a8a"))
    d.ellipse([156, 438, 186, 468], fill=C(skin))
    # head, beard, hat
    d.ellipse([180, 196, 332, 340], fill=C(skin))
    d.polygon([(190, 290), (322, 290), (300, 420), (256, 452), (212, 420)], fill=C("#f1efe8"))
    d.ellipse([200, 270, 312, 330], fill=C("#f1efe8"))
    eyes(d, 256, 262, sep=32, r=(7, 9))
    d.line([(212, 240), (244, 248)], fill=C("#f1efe8"), width=10)
    d.line([(300, 240), (268, 248)], fill=C("#f1efe8"), width=10)
    d.ellipse([244, 272, 268, 296], fill=C("#e9a888"))
    d.ellipse([138, 196, 374, 236], fill=C("#4a2f72"))
    d.polygon([(186, 214), (326, 214), (300, 120), (318, 40), (250, 100), (214, 160)], fill=C("#5b3a8a"))
    d.polygon([(190, 200), (322, 200), (318, 216), (186, 216)], fill=C("#d9b24c"))
    d.ellipse([262, 132, 286, 156], fill=C("#f0c75a"))
    d.ellipse([270, 128, 292, 152], fill=C("#5b3a8a"))
    finish_mini(img, "wizard", 104)


def goblin(name, seed, weapon):
    img, d = new_canvas()
    skin = "#7c9a4a"
    d.rounded_rectangle([206, 520, 246, 596], 14, fill=C(skin))
    d.rounded_rectangle([266, 520, 306, 596], 14, fill=C(skin))
    d.ellipse([194, 580, 252, 614], fill=C("#5f7a36"))
    d.ellipse([260, 580, 318, 614], fill=C("#5f7a36"))
    if weapon == "spear":
        d.line([(170, 600), (176, 200)], fill=C("#7a5a3a"), width=12)
        d.polygon([(160, 214), (192, 214), (178, 150)], fill=C("#8a8478"))
    else:
        d.line([(340, 470), (380, 330)], fill=C("#6b4a32"), width=18)
        d.ellipse([354, 290, 412, 360], fill=C("#7a5236"))
        for (x, y) in [(372, 300), (396, 322), (380, 340)]:
            d.ellipse([x - 5, y - 5, x + 5, y + 5], fill=C("#cfc6b4"))
    # ragged tunic
    pts = [(196, 380), (316, 380), (334, 530)]
    for k in range(7):
        x = 334 - k * 28
        pts.append((x - 14, 548 if k % 2 == 0 else 524))
    pts.append((178, 530))
    d.polygon(pts, fill=C("#7a5a3a"))
    d.rectangle([190, 470, 322, 486], fill=C("#4a3326"))
    # arms
    if weapon == "spear":
        limb(d, (204, 400), (176, 450), 30, C(skin))
        limb(d, (308, 400), (330, 470), 30, C(skin))
        d.ellipse([312, 458, 412, 548], fill=C("#8a6a44"))
        d.ellipse([348, 492, 376, 520], fill=C("#5a4430"))
    else:
        limb(d, (204, 400), (176, 470), 30, C(skin))
        limb(d, (308, 400), (342, 460), 30, C(skin))
    # big head, bigger ears
    d.polygon([(186, 300), (96, 250), (190, 340)], fill=C(skin))
    d.polygon([(326, 300), (416, 250), (322, 340)], fill=C(skin))
    d.polygon([(178, 302), (120, 266), (182, 326)], fill=C("#c98a7a"))
    d.polygon([(334, 302), (392, 266), (330, 326)], fill=C("#c98a7a"))
    d.ellipse([176, 230, 336, 400], fill=C(skin))
    for sx in (-1, 1):
        ex = 256 + sx * 36
        d.ellipse([ex - 18, 288, ex + 18, 318], fill=C("#f4e06a"))
        d.ellipse([ex - 6, 294, ex + 6, 314], fill=C("#1f1a14"))
    d.line([(214, 278), (240, 288)], fill=C("#3a4a22"), width=7)
    d.line([(298, 278), (272, 288)], fill=C("#3a4a22"), width=7)
    d.chord([222, 330, 290, 372], 0, 180, fill=C("#3a1f1a"))
    for x in (236, 264):
        d.polygon([(x - 6, 351), (x + 6, 351), (x, 364)], fill=C("#f4f0e0"))
    finish_mini(img, name, seed)


# ---------------------------------------------------------------- players

POSES = ["neutral", "lean", "cheer", "laugh", "gasp", "arms", "yawn", "phone", "think"]


def person(name, seed, skin, hair, sweater, draw_hair_back, draw_hair_front, extras=None, happy=False,
           open_mouth=False, glasses=False, pattern=None, pose="neutral"):
    """A player at the table. pose changes arms, eyes and mouth; neutral is the M0 look."""
    W, H = 600, 720
    img, d = new_canvas(W, H)
    shade = tuple(int(v * 0.85) for v in C(sweater)[:3]) + (255,)
    # arm targets per pose: (left shoulder -> hand), (right shoulder -> hand); None = default resting arm
    arms = {
        "neutral": ((150, 500, 130, 700), (450, 500, 470, 700)),
        "lean": ((150, 500, 200, 690), (450, 500, 400, 690)),
        "cheer": ((150, 470, 70, 250), (450, 470, 530, 250)),
        "laugh": ((150, 500, 240, 600), (450, 500, 470, 700)),
        "gasp": ((150, 490, 220, 330), (450, 490, 380, 330)),
        "arms": ((150, 500, 400, 590), (450, 500, 200, 600)),
        "yawn": ((150, 500, 130, 700), (450, 490, 330, 360)),
        "phone": ((150, 500, 260, 620), (450, 500, 340, 620)),
        "think": ((150, 500, 130, 700), (450, 490, 330, 420)),
    }[pose]
    dy = 26 if pose == "lean" else 0
    draw_hair_back(d)
    # torso and arms (cut off by the table)
    d.rounded_rectangle([118, 430, 482, 800], 90, fill=C(sweater))
    d.rounded_rectangle([262, 380, 338, 450], 20, fill=C(skin))
    behind = pose in ("neutral", "lean", "laugh", "phone", "think", "yawn")
    if behind:
        for (x0, y0, x1, y1) in arms:
            limb(d, (x0, y0), (x1, y1), 70, shade)
    if pattern:
        mask = img.getchannel("A")
        layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
        pattern(ImageDraw.Draw(layer))
        clipped = Image.new("RGBA", img.size, (0, 0, 0, 0))
        clipped.paste(layer, mask=mask)
        img.alpha_composite(clipped)
        d = ImageDraw.Draw(img)
    if extras:
        extras(d, pose)
    if pose == "phone":
        d.rounded_rectangle([262, 560, 338, 650], 10, fill=C("#1e1e24"))
        d.rounded_rectangle([270, 568, 330, 640], 6, fill=C("#9fd8ff"))
    hx, hy = 300, dy
    tilt_head = Image.new("RGBA", img.size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(tilt_head)
    hd.ellipse([186, 150 + hy, 414, 400 + hy], fill=C(skin))
    for sx in (-1, 1):
        hd.ellipse([300 + sx * 116 - 18, 260 + hy, 300 + sx * 116 + 18, 310 + hy], fill=C(skin))
    shift = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw_hair_front(ImageDraw.Draw(shift))
    if hy:
        tilt_head.alpha_composite(shift, (0, hy))
    else:
        tilt_head.alpha_composite(shift)
    hd = ImageDraw.Draw(tilt_head)
    ey = 282 + hy + (10 if pose == "phone" else 0)
    if pose in ("cheer", "laugh") or (happy and pose in ("neutral", "lean")):
        eyes(hd, 300, ey, sep=46, r=(11, 14), happy=True)
    elif pose == "gasp":
        for sx in (-1, 1):
            ex = 300 + sx * 46
            hd.ellipse([ex - 15, ey - 18, ex + 15, ey + 18], fill=(255, 255, 255, 255))
            hd.ellipse([ex - 8, ey - 8, ex + 8, ey + 8], fill=C("#2a1d1a"))
    elif pose in ("yawn",):
        for sx in (-1, 1):
            ex = 300 + sx * 46
            hd.arc([ex - 14, ey - 10, ex + 14, ey + 10], 20, 160, fill=C("#2a1d1a"), width=6)
    elif pose in ("arms", "phone"):
        for sx in (-1, 1):
            ex = 300 + sx * 46
            hd.chord([ex - 12, ey - 6, ex + 12, ey + 14], 0, 180, fill=C("#2a1d1a"))
            hd.line([(ex - 15, ey - 2), (ex + 15, ey - 2)], fill=C("#2a1d1a"), width=5)
    elif pose == "think":
        for sx in (-1, 1):
            ex = 300 + sx * 46
            hd.ellipse([ex - 11, ey - 14, ex + 11, ey + 14], fill=C("#2a1d1a"))
            hd.ellipse([ex - 3 + 4, ey - 12, ex + 5 + 4, ey - 4], fill=(255, 255, 255, 230))
    else:
        eyes(hd, 300, ey, sep=46, r=(11, 14), happy=False)
    if glasses:
        for sx in (-1, 1):
            hd.ellipse([300 + sx * 46 - 30, 252 + hy, 300 + sx * 46 + 30, 312 + hy], outline=C("#2a1d1a"), width=6)
        hd.line([(284, 280 + hy), (316, 280 + hy)], fill=C("#2a1d1a"), width=6)
    blush(hd, 300, 318 + hy, sep=66)
    my = 340 + hy
    if pose in ("cheer", "laugh", "lean") or (open_mouth and pose == "neutral"):
        smile(hd, 300, my, 26, open_=True)
    elif pose == "gasp":
        hd.ellipse([284, my - 6, 316, my + 30], fill=C("#5a2420"))
    elif pose == "yawn":
        hd.ellipse([276, my - 12, 324, my + 44], fill=C("#5a2420"))
    elif pose in ("arms", "phone"):
        hd.line([(282, my + 4), (318, my + 4)], fill=C("#4a2a22"), width=5)
    elif pose == "think":
        hd.arc([286, my - 2, 314, my + 14], 200, 340, fill=C("#4a2a22"), width=5)
    else:
        smile(hd, 300, my, 26, open_=False)
    if pose == "laugh":
        tilt_head = tilt_head.rotate(6, resample=Image.BICUBIC, center=(300, 300))
    elif pose == "think":
        tilt_head = tilt_head.rotate(-5, resample=Image.BICUBIC, center=(300, 300))
    elif pose == "phone":
        tilt_head = tilt_head.rotate(0, resample=Image.BICUBIC, center=(300, 300))
    img.alpha_composite(tilt_head)
    d = ImageDraw.Draw(img)
    if not behind:
        for (x0, y0, x1, y1) in arms:
            limb(d, (x0, y0), (x1, y1), 64, shade)
            d.ellipse([x1 - 34, y1 - 34, x1 + 34, y1 + 34], fill=C(skin))
    elif pose in ("yawn", "think", "laugh"):
        x0, y0, x1, y1 = arms[1] if pose != "laugh" else arms[0]
        d.ellipse([x1 - 32, y1 - 32, x1 + 32, y1 + 32], fill=C(skin))
    if pose == "phone":
        d.ellipse([228, 586, 288, 646], fill=C(skin))
        d.ellipse([312, 586, 372, 646], fill=C(skin))
    img = painterly(img, seed, light=True)
    img = outline(img, 4)
    out = name if pose == "neutral" else name + "_" + pose
    img.resize((W // 2, H // 2), Image.LANCZOS).save(path(SPR, out + ".png"))


def players(poses=None):
    for pose in (poses or POSES):
        _players_pose(pose)


def _players_pose(pose):
    # Mara: long red hair, glasses, mustard sweater, excited
    person("mara", 201, "#f2c9a0", "#b5482e", "#d0a040",
           lambda d: d.rounded_rectangle([160, 150, 440, 560], 120, fill=C("#b5482e")),
           lambda d: (d.chord([180, 130, 420, 330], 180, 360, fill=C("#b5482e")),
                      d.polygon([(186, 250), (230, 180), (300, 160), (250, 240)], fill=C("#c95a3a"))),
           open_mouth=True, glasses=True, pose=pose)

    # Dev: short dark hair, blue hoodie, holding a red d6
    def dev_extras(d, pose="neutral"):
        d.polygon([(200, 430), (400, 430), (360, 480), (240, 480)], fill=C("#36527f"))
        d.line([(276, 470), (270, 560)], fill=C("#e8e2d6"), width=8)
        d.line([(324, 470), (330, 560)], fill=C("#e8e2d6"), width=8)
        if pose in ("neutral", "laugh"):      # the d6 in his resting right hand
            d.rounded_rectangle([440, 630, 490, 680], 10, fill=C("#b33a3a"))
            d.ellipse([458, 648, 470, 660], fill=(250, 240, 230, 255))
    person("dev", 202, "#c98d62", "#1f1a1a", "#3f5f9a",
           lambda d: None,
           lambda d: d.polygon([(184, 250), (196, 170), (240, 140), (300, 128), (360, 140), (410, 178), (416, 250),
                                (380, 200), (330, 196), (300, 176), (260, 200), (220, 206)], fill=C("#1f1a1a")),
           extras=dev_extras, pose=pose)

    # Jess: curly hair with a bun, teal cardigan, laughing
    def jess_back(d):
        d.ellipse([250, 70, 350, 170], fill=C("#5a3a26"))
        for a in np.linspace(0, 2 * np.pi, 16)[:-1]:
            x, y = 300 + np.cos(a) * 128, 260 + np.sin(a) * 110
            d.ellipse([x - 40, y - 40, x + 40, y + 40], fill=C("#5a3a26"))

    def jess_front(d):
        for x in range(196, 420, 34):
            d.ellipse([x - 26, 146, x + 26, 214], fill=C("#6a4630"))

    def jess_extras(d, pose="neutral"):
        d.polygon([(250, 430), (350, 430), (330, 800), (270, 800)], fill=C("#efe4cc"))
    person("jess", 203, "#8d5a3b", "#5a3a26", "#3f8a84", jess_back, jess_front, extras=jess_extras,
           happy=True, open_mouth=True, pose=pose)

    # Sam: beanie, beard, plaid shirt, relaxed
    def sam_front(d):
        d.chord([176, 110, 424, 330], 180, 360, fill=C("#c0583a"))
        d.rounded_rectangle([172, 200, 428, 236], 16, fill=C("#a8462e"))
        d.ellipse([280, 84, 320, 124], fill=C("#d06a48"))
        d.chord([200, 270, 400, 420], 0, 180, fill=C("#6a4a30"))
        d.rectangle([258, 322, 342, 342], fill=C("#6a4a30"))

    def sam_plaid(d):
        for x in range(100, 500, 44):
            d.line([(x, 380), (x, 800)], fill=(40, 30, 30, 90), width=12)
        for y in range(450, 800, 44):
            d.line([(90, y), (510, y)], fill=(40, 30, 30, 80), width=10)

    def sam_extras(d, pose="neutral"):
        if pose in ("neutral", "yawn", "think"):   # the mug in his resting left hand
            d.rounded_rectangle([96, 600, 166, 700], 12, fill=C("#e8dcc0"))
            d.arc([150, 620, 196, 676], 270, 90, fill=C("#e8dcc0"), width=10)
    person("sam", 204, "#e8b48a", "#6a4a30", "#a83a32", lambda d: None, sam_front, extras=sam_extras,
           pattern=sam_plaid, pose=pose)


# ---------------------------------------------------------------- glow sprites

def flame():
    W, H = 256, 384
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for (scale, col, blur) in [(1.0, (255, 90, 30, 200), 18), (0.72, (255, 150, 50, 230), 12),
                               (0.45, (255, 220, 120, 255), 8), (0.25, (255, 250, 220, 255), 5)]:
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        cx, base = W / 2, H - 40
        rw, rh = 90 * scale, 300 * scale
        pts = []
        for t in np.linspace(0, np.pi, 40):
            x = cx + np.sin(t) * rw * (1 - (1 - np.cos(t)) * 0.18)
            y = base - (1 - np.cos(t)) / 2 * rh
            pts.append((x, y))
        pts += [(cx + (cx - x), y) for (x, y) in reversed(pts)]
        d.polygon(pts, fill=col)
        d.ellipse([cx - rw, base - rw * 0.9, cx + rw, base + rw * 0.6], fill=col)
        img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(blur)))
    save_emission(img.resize((W // 2, H // 2), Image.LANCZOS), "flame.png")


def halo():
    s = 256
    y, x = np.mgrid[0:s, 0:s].astype(float)
    r = np.sqrt(((x + 0.5) / s * 2 - 1) ** 2 + ((y + 0.5) / s * 2 - 1) ** 2)
    a = np.clip(1 - r, 0, 1) ** 2.2
    rgb = np.zeros((s, s, 3)) + hexc("#ffcf8a")
    save_emission(to_img(rgb, a), "halo.png")


def save_emission(img, name):
    """Glow sprites are stored as light on black with full alpha (additive)."""
    arr = np.asarray(img.convert("RGBA")).astype(float)
    rgb = arr[..., :3] * (arr[..., 3:4] / 255.0)
    out = np.dstack([rgb, np.full(rgb.shape[:2], 255.0)]).astype(np.uint8)
    Image.fromarray(out, "RGBA").save(path(SPR, name))


def build_all():
    import gen_sprites_m4
    fighter()
    rogue()
    cleric()
    goblin("goblin_spear", 105, "spear")
    goblin("goblin_club", 106, "club")
    players()
    flame()
    halo()
    gen_sprites_m4.build_monsters()     # includes Thessaly's redrawn wizard mini
