"""Store-page art for Behind the Screen from real (clean) game captures (October 20).
The captures come from tools/keyart/capture.sh; tools/keyart/make_all.sh makes the whole set.

compose.py SRC OUT W H --focus fx,fy --zoom Z --logo left|right|center --valign top|bottom|middle
           [--tagline] [--logo-scale S]
"""
import argparse
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops, ImageEnhance

import os
FONTS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "fonts") + os.sep
LORA = FONTS + "Lora-Bold.ttf"
OUTFIT = FONTS + "Outfit-Regular.ttf"
OUTFIT_B = FONTS + "Outfit-Bold.ttf"

GOLD_TOP = (255, 226, 150)
GOLD_BOT = (226, 152, 58)
INK = (34, 18, 10)
CREAM = (246, 228, 190)


def crop_to(img, w, h, fx, fy, zoom):
    """Crop img to aspect w:h around focus (fx, fy) in 0..1, zoom >= 1, then resize to w x h."""
    iw, ih = img.size
    aspect = w / h
    cw = iw / zoom
    ch = cw / aspect
    if ch > ih / zoom:
        ch = ih / zoom
        cw = ch * aspect
    cx = min(max(fx * iw, cw / 2), iw - cw / 2)
    cy = min(max(fy * ih, ch / 2), ih - ch / 2)
    box = (cx - cw / 2, cy - ch / 2, cx + cw / 2, cy + ch / 2)
    return img.crop(tuple(round(v) for v in box)).resize((w, h), Image.LANCZOS)


def spaced_text_mask(text, font, tracking):
    """A mask of text with extra letter spacing (tracking in px)."""
    asc, desc = font.getmetrics()
    widths = [font.getlength(c) for c in text]
    total = sum(widths) + tracking * (len(text) - 1)
    pad = int(font.size * 0.5)
    m = Image.new("L", (int(total) + pad * 2, asc + desc + pad * 2), 0)
    d = ImageDraw.Draw(m)
    x = pad
    for c, cw in zip(text, widths):
        d.text((x, pad), c, font=font, fill=255)
        x += cw + tracking
    bbox = m.getbbox()
    return m.crop(bbox)


def gradient(size, top, bot):
    w, h = size
    g = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        g.putpixel((0, y), tuple(round(top[i] + (bot[i] - top[i]) * t) for i in range(3)))
    return g.resize((w, h))


def logo(height, tagline=None, align="center"):
    """The title lockup: BEHIND THE / SCREEN, gold on an ink outline. Returns RGBA."""
    big = ImageFont.truetype(LORA, int(height * 0.62))
    small = ImageFont.truetype(LORA, int(height * 0.25))
    m_big = spaced_text_mask("SCREEN", big, int(height * 0.035))
    m_small = spaced_text_mask("BEHIND THE", small, int(height * 0.06))
    gap = int(height * 0.07)
    W = max(m_big.width, m_small.width)
    rows = [(m_small, 0), (m_big, m_small.height + gap)]
    H = m_small.height + gap + m_big.height
    tag_mask = None
    if tagline:
        tf = ImageFont.truetype(OUTFIT, max(12, int(height * 0.13)))
        tag_mask = spaced_text_mask(tagline, tf, int(height * 0.004))
        H += int(height * 0.14) + tag_mask.height
        W = max(W, tag_mask.width)
    pad = int(height * 0.3)
    mask = Image.new("L", (W + pad * 2, H + pad * 2), 0)

    def xpos(mw):
        if align == "left":
            return pad
        if align == "right":
            return pad + W - mw
        return pad + (W - mw) // 2

    for mk, y in rows:
        mask.paste(mk, (xpos(mk.width), pad + y), mk)
    # Fill: a warm gold gradient over the letters.
    fill = gradient(mask.size, GOLD_TOP, GOLD_BOT).convert("RGBA")
    fill.putalpha(mask)
    # Outline and a soft shadow, in ink.
    stroke = mask.filter(ImageFilter.MaxFilter(2 * max(1, int(height * 0.022)) + 1))
    shadow = stroke.filter(ImageFilter.GaussianBlur(height * 0.08))
    glow = mask.filter(ImageFilter.GaussianBlur(height * 0.18))
    out = Image.new("RGBA", mask.size, (0, 0, 0, 0))
    # Warm glow first (lamp light on the letters), then shadow, outline, fill.
    glow_l = Image.new("RGBA", mask.size, (255, 170, 70, 0))
    glow_l.putalpha(glow.point(lambda v: int(v * 0.35)))
    out = Image.alpha_composite(out, glow_l)
    sh = Image.new("RGBA", mask.size, INK + (0,))
    sh.putalpha(shadow.point(lambda v: int(min(255, v * 1.1))))
    out = Image.alpha_composite(out, sh.transform(sh.size, Image.AFFINE, (1, 0, 0, 0, 1, -int(height * 0.04))))
    st = Image.new("RGBA", mask.size, INK + (0,))
    st.putalpha(stroke)
    out = Image.alpha_composite(out, st)
    # A thin lighter edge on top of the letters' upper half (a bit of bevel).
    out = Image.alpha_composite(out, fill)
    hi = ImageChops.subtract(mask, mask.transform(mask.size, Image.AFFINE, (1, 0, 0, 0, 1, -max(1, int(height * 0.012)))))
    hil = Image.new("RGBA", mask.size, (255, 246, 214, 0))
    hil.putalpha(hi.point(lambda v: int(v * 0.7)))
    out = Image.alpha_composite(out, hil)
    if tag_mask is not None:
        ty = pad + m_small.height + gap + m_big.height + int(height * 0.14)
        tm = Image.new("L", mask.size, 0)
        tm.paste(tag_mask, (xpos(tag_mask.width), ty), tag_mask)
        tsh = Image.new("RGBA", mask.size, INK + (0,))
        tsh.putalpha(tm.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(height * 0.03)))
        out = Image.alpha_composite(out, tsh)
        tl = Image.new("RGBA", mask.size, CREAM + (0,))
        tl.putalpha(tm)
        out = Image.alpha_composite(out, tl)
    return out.crop(out.getbbox())


def shade(img, side, strength, reach):
    """Darken toward one side (or a band) so the title reads."""
    w, h = img.size
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    if side in ("left", "right"):
        n = int(w * reach)
        for i in range(n):
            a = int(255 * strength * (1 - i / n) ** 1.6)
            x = i if side == "left" else w - 1 - i
            d.line([(x, 0), (x, h)], fill=a)
    elif side in ("top", "bottom"):
        n = int(h * reach)
        for i in range(n):
            a = int(255 * strength * (1 - i / n) ** 1.6)
            y = i if side == "top" else h - 1 - i
            d.line([(0, y), (w, y)], fill=a)
    dark = Image.new("RGB", (w, h), (14, 8, 5))
    return Image.composite(dark, img, m)


def vignette(img, strength=0.45):
    w, h = img.size
    small = Image.new("L", (64, 36), 0)
    d = ImageDraw.Draw(small)
    d.ellipse((-14, -10, 78, 46), fill=255)
    m = small.filter(ImageFilter.GaussianBlur(9)).resize((w, h), Image.BICUBIC)
    dark = Image.new("RGB", (w, h), (10, 6, 4))
    inv = m.point(lambda v: int((255 - v) * strength))
    return Image.composite(dark, img, inv)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("out")
    ap.add_argument("w", type=int)
    ap.add_argument("h", type=int)
    ap.add_argument("--focus", default="0.5,0.5")
    ap.add_argument("--zoom", type=float, default=1.0)
    ap.add_argument("--logo", default="left")
    ap.add_argument("--valign", default="middle")
    ap.add_argument("--logo-scale", type=float, default=0.30)
    ap.add_argument("--tagline", default=None)
    ap.add_argument("--shade", default=None)
    ap.add_argument("--shade-strength", type=float, default=0.7)
    ap.add_argument("--shade-reach", type=float, default=0.5)
    ap.add_argument("--margin", type=float, default=0.06)
    ap.add_argument("--warm", type=float, default=1.06)
    ap.add_argument("--vig", type=float, default=0.4)
    ap.add_argument("--no-logo", action="store_true")
    a = ap.parse_args()
    fx, fy = (float(v) for v in a.focus.split(","))
    img = Image.open(a.src).convert("RGB")
    img = crop_to(img, a.w, a.h, fx, fy, a.zoom)
    img = ImageEnhance.Color(img).enhance(a.warm)
    img = ImageEnhance.Contrast(img).enhance(1.04)
    if a.vig:
        img = vignette(img, a.vig)
    if a.shade:
        img = shade(img, a.shade, a.shade_strength, a.shade_reach)
    if not a.no_logo:
        lg = logo(int(a.h * a.logo_scale), a.tagline, "left" if a.logo == "left" else "right" if a.logo == "right" else "center")
        mx, my = int(a.w * a.margin), int(a.h * a.margin)
        if a.logo == "left":
            x = mx
        elif a.logo == "right":
            x = a.w - mx - lg.width
        else:
            x = (a.w - lg.width) // 2
        if a.valign == "top":
            y = my
        elif a.valign == "bottom":
            y = a.h - my - lg.height
        else:
            y = (a.h - lg.height) // 2
        base = img.convert("RGBA")
        base.alpha_composite(lg, (x, y))
        img = base.convert("RGB")
    img.save(a.out, optimize=True)
    print(a.out, img.size)


if __name__ == "__main__":
    main()
