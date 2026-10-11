"""Shared helpers for the Behind the Screen asset generator.

Everything here is deterministic: the same seed always paints the same pixels,
so regenerating assets never produces surprise diffs.
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTS = os.path.join(ROOT, "assets", "fonts")


def path(*parts):
    p = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    return p


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


def tile_noise(w, h, cells_x, cells_y, seed, octaves=4, persistence=0.5):
    """Seamless fractal noise in [0, 1], shape (h, w)."""
    out = np.zeros((h, w))
    amp, total = 1.0, 0.0
    for o in range(octaves):
        cx, cy = cells_x * 2 ** o, cells_y * 2 ** o
        r = np.random.default_rng(seed * 101 + o).random((cy, cx))
        big = np.tile(r, (3, 3))
        img = Image.fromarray((big * 255).astype(np.uint8)).resize((w * 3, h * 3), Image.BICUBIC)
        a = np.asarray(img, float)[h:2 * h, w:2 * w] / 255.0
        out += a * amp
        total += amp
        amp *= persistence
    out /= total
    return (out - out.min()) / max(out.max() - out.min(), 1e-6)


def to_img(rgb, alpha=None):
    rgb = np.clip(rgb, 0, 1)
    arr = (rgb * 255 + 0.5).astype(np.uint8)
    if alpha is None:
        return Image.fromarray(arr, "RGB")
    a = (np.clip(alpha, 0, 1) * 255 + 0.5).astype(np.uint8)
    return Image.fromarray(np.dstack([arr, a]), "RGBA")


def lerp(a, b, t):
    t = np.asarray(t)[..., None] if np.ndim(t) else t
    return a * (1 - t) + b * t


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def seg_dist(px, py, pts):
    """Distance from every pixel to a polyline, vectorised."""
    d = np.full(px.shape, 1e9)
    for (x0, y0), (x1, y1) in zip(pts[:-1], pts[1:]):
        vx, vy = x1 - x0, y1 - y0
        L2 = vx * vx + vy * vy + 1e-9
        t = np.clip(((px - x0) * vx + (py - y0) * vy) / L2, 0, 1)
        dx, dy = px - (x0 + t * vx), py - (y0 + t * vy)
        d = np.minimum(d, np.sqrt(dx * dx + dy * dy))
    return d


def catmull(pts, n=12):
    """Smooth a list of points with a Catmull-Rom spline."""
    pts = [pts[0]] + list(pts) + [pts[-1]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = map(np.array, pts[i - 1:i + 3])
        for k in range(n):
            t = k / n
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    out.append(np.array(pts[-2]))
    return [tuple(p) for p in out]


def brush_strokes(img, mask, count, seed, length=(6, 18), width=(2, 5), jitter=0.07, alpha=70):
    """Scatter short painterly strokes, tinted from the pixels under them."""
    rng = np.random.default_rng(seed)
    base = np.asarray(img.convert("RGB"), float)
    h, w = base.shape[:2]
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    m = np.asarray(mask) if mask is not None else None
    for _ in range(count):
        x, y = rng.integers(0, w), rng.integers(0, h)
        if m is not None and m[y, x] < 128:
            continue
        c = base[y, x] * (1 + rng.uniform(-jitter, jitter, 3))
        ang = rng.uniform(0, np.pi)
        L = rng.uniform(*length)
        dx, dy = np.cos(ang) * L / 2, np.sin(ang) * L / 2
        d.line([(x - dx, y - dy), (x + dx, y + dy)],
               fill=tuple(int(v) for v in np.clip(c, 0, 255)) + (alpha,),
               width=int(rng.integers(width[0], width[1] + 1)))
    out = img.convert("RGBA")
    out.alpha_composite(layer)
    if m is not None:
        a = np.minimum(np.asarray(out)[..., 3], np.asarray(img.convert("RGBA"))[..., 3])
        arr = np.asarray(out).copy()
        arr[..., 3] = a
        out = Image.fromarray(arr, "RGBA")
    return out if img.mode == "RGBA" else out.convert("RGB")
