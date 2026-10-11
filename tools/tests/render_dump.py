"""Render a GUI node dump from gui_smoke.lua to a PNG, roughly as Defold would.
    python3 tools/tests/render_dump.py <dump.txt> <out.png> [background.png]
"""
import math
import sys

from PIL import Image, ImageDraw, ImageFont

FONTS = {
    "ui14": ("Outfit-Regular.ttf", 15), "ui18": ("Outfit-Regular.ttf", 18), "ui18b": ("Outfit-Bold.ttf", 18),
    "ui22b": ("Outfit-Bold.ttf", 22), "title30": ("Lora-Bold.ttf", 30), "hand24": ("NothingYouCouldDo-Regular.ttf", 24),
    "story22": ("Lora-Bold.ttf", 22),
}
_cache = {}


def font(name):
    if name not in _cache:
        f, s = FONTS.get(name, FONTS["ui18"])
        _cache[name] = ImageFont.truetype("assets/fonts/" + f, s)
    return _cache[name]


W, H = 1600, 900
src, out = sys.argv[1], sys.argv[2]
if len(sys.argv) > 3:
    bg = Image.open(sys.argv[3]).convert("RGBA").resize((W, H))
else:
    bg = Image.new("RGBA", (W, H), (40, 30, 26, 255))
img = bg.copy()

HX = {"nw": 0, "w": 0, "sw": 0, "n": 0.5, "c": 0.5, "s": 0.5, "ne": 1, "e": 1, "se": 1}
VY = {"nw": 0, "n": 0, "ne": 0, "w": 0.5, "c": 0.5, "e": 0.5, "sw": 1, "s": 1, "se": 1}

for line in open(src):
    parts = line.rstrip("\n").split("\t")
    kind, x, y, w, h, piv = parts[0], float(parts[1]), float(parts[2]), float(parts[3]), float(parts[4]), parts[5]
    r, g, b, a = [float(v) for v in parts[6:10]]
    fnt, image, euler, slice_ = parts[10], parts[11], float(parts[12]), float(parts[13])
    text = parts[14].replace("\\n", "\n") if len(parts) > 14 else ""
    col = (int(r * 255), int(g * 255), int(b * 255), int(a * 255))
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    if kind == "box":
        if euler:
            cx, cy = x, H - y
            ang = math.radians(-euler)
            pts = []
            for sx, sy in ((-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)):
                pts.append((cx + sx * math.cos(ang) - sy * math.sin(ang), cy + sx * math.sin(ang) + sy * math.cos(ang)))
            d.polygon(pts, fill=col)
        else:
            x0 = x - HX[piv] * w
            y0 = (H - y) - VY[piv] * h
            box = [x0, y0, x0 + w, y0 + h]
            if image == "dot":
                d.ellipse(box, fill=col)
            elif image == "panel":
                d.rounded_rectangle(box, radius=max(0, min(slice_ or 10, w / 2, h / 2)), fill=col)
            elif image == "vignette":
                pass
            elif image.startswith("face_") or image.startswith("mini_"):
                pic = Image.open("assets/portraits/" + image + ".png").convert("RGBA").resize((max(1, int(w)), max(1, int(h))))
                if col[3] < 255 or col[:3] != (255, 255, 255):
                    r0, g0, b0, a0 = pic.split()
                    r0 = r0.point(lambda v: v * col[0] // 255)
                    g0 = g0.point(lambda v: v * col[1] // 255)
                    b0 = b0.point(lambda v: v * col[2] // 255)
                    a0 = a0.point(lambda v: v * col[3] // 255)
                    pic = Image.merge("RGBA", (r0, g0, b0, a0))
                layer.alpha_composite(pic, (int(x0), int(y0)))
            elif image.startswith("icon_"):
                ic = Image.open("assets/ui/" + image + ".png").convert("RGBA").resize((max(1, int(w)), max(1, int(h))))
                tint = Image.new("RGBA", ic.size, col[:3] + (255,))
                tint.putalpha(Image.eval(ic.getchannel("A"), lambda a: a * col[3] // 255))
                layer.alpha_composite(tint, (int(x0), int(y0)))
            else:
                d.rectangle(box, fill=col)
    else:
        f = font(fnt)
        asc, desc = f.getmetrics()
        lh = asc + desc
        lines = text.split("\n")
        bh = lh * len(lines)
        top = (H - y) - VY[piv] * bh
        for i, ln in enumerate(lines):
            lw = f.getlength(ln)
            d.text((x - HX[piv] * lw, top + i * lh), ln, font=f, fill=col)
    img = Image.alpha_composite(img, layer)
img.convert("RGB").save(out)
