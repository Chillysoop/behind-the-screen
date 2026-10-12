"""Painted textures for the room, the table and the props."""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from gen_common import (path, hexc, tile_noise, to_img, lerp, smoothstep, seg_dist,
                        catmull, brush_strokes, font)

TEX = "assets/textures"

# Palette swatches for simple low-poly props. Each swatch is a flat 16x16 cell.
PALETTE = {
    "lamp_shade": "#e9d3a6", "lamp_shade_in": "#ffe7b0", "brass": "#b98b45", "cord": "#2a2220",
    "bulb": "#fff2c8", "mug_red": "#a8463a", "mug_teal": "#3f7f7a", "mug_cream": "#e8dcc0",
    "coffee": "#3b2416", "bowl": "#7a5236", "chip": "#e7b85a", "tea": "#8a5a24",
    "bark": "#5b4030", "leaf_a": "#4f7a3a", "leaf_b": "#3e6a33", "leaf_c": "#6d9447",
    "log": "#6b4a32", "log_end": "#c49a6c", "ember": "#ff8a3d",
    "base": "#2b2522", "rim_fighter": "#3d6db5", "rim_rogue": "#3f6e4a", "rim_cleric": "#d9b24c",
    "rim_wizard": "#7b4fb0", "rim_goblin": "#7c8c3a",
    "shelf": "#4a3326", "book_a": "#7d2f2b", "book_b": "#2f4f6b", "book_c": "#5f6b2f",
    "book_d": "#a07a3a", "book_e": "#4b2f5f", "book_f": "#c8b89a",
    "frame": "#3a2a20", "baseboard": "#2e221b", "fairy": "#ffd690", "fairy_b": "#ffc070",
    "wire": "#1e1a18", "screen_edge": "#5a2a24", "pot": "#9b5a3c", "plant": "#4d7a3c",
    "pencil": "#e2b23c", "pencil_tip": "#2a2a2a", "dice_red": "#b33a3a", "dice_blue": "#3a5fb3",
    # M4 terrain sets
    "canvas": "#d9c9a3", "canvas_dark": "#b8a47c", "bone": "#e3d9c0", "feather": "#c0483a",
    "altar_cloth": "#7a2f3a", "candle": "#efe6cf", "wood_dark": "#5a3b25", "wood_mid": "#8a5e38",
    "bottle_green": "#3d6b4a", "bottle_amber": "#b07a2a", "barrel": "#7a5232", "metal": "#6a6e74",
    "awning_red": "#b2483a", "awning_blue": "#3f6a9a", "awning_yellow": "#d6a23d", "water": "#3a6f86",
    "crate": "#a07848", "hay": "#c9a95a", "chasm": "#16110e", "rope": "#a88b5a",
    "base_party": "#d0a040", "base_foe": "#8a3a32", "base_npc": "#5a7a8a",
    # Each player's mini stands on a base the colour of their shirt (base_party is Mara's mustard).
    "base_dev": "#3f5f9a", "base_jess": "#3f8a84", "base_sam": "#a83a32",
}
PALETTE_COLS = 8


def palette_uv(name):
    keys = list(PALETTE.keys())
    i = keys.index(name)
    cx, cy = i % PALETTE_COLS, i // PALETTE_COLS
    rows = (len(keys) + PALETTE_COLS - 1) // PALETTE_COLS
    return ((cx + 0.5) / PALETTE_COLS, (cy + 0.5) / rows)


def palette_png():
    keys = list(PALETTE.keys())
    rows = (len(keys) + PALETTE_COLS - 1) // PALETTE_COLS
    img = Image.new("RGB", (PALETTE_COLS * 16, rows * 16))
    d = ImageDraw.Draw(img)
    for i, k in enumerate(keys):
        cx, cy = i % PALETTE_COLS, i // PALETTE_COLS
        d.rectangle([cx * 16, cy * 16, cx * 16 + 15, cy * 16 + 15], fill=PALETTE[k])
    img.save(path(TEX, "palette.png"))


def planks(w, h, plank_px, length_px, colors, seed, grain=7.0, seam=0.55, warp=2.5):
    rng = np.random.default_rng(seed)
    y = np.arange(h)[:, None].repeat(w, 1)
    x = np.arange(w)[None, :].repeat(h, 0)
    rows = h // plank_px
    row = y // plank_px
    n = tile_noise(w, h, 8, 8, seed, 5)
    fine = tile_noise(w, h, 64, 4, seed + 7, 3)
    offs = rng.integers(0, length_px, rows)
    col_idx = rng.integers(0, len(colors), (rows, w // length_px + 2))
    tone = rng.uniform(0.86, 1.1, (rows, w // length_px + 2))
    ox = (x + offs[row]) % w
    seg = ox // length_px
    base = np.stack([hexc(c) for c in colors])[col_idx[row, seg]] * tone[row, seg][..., None]
    yy = (y % plank_px) / plank_px
    g = np.sin((yy * grain + n * warp + seg * 0.37) * np.pi * 2) * 0.5 + 0.5
    g = g ** 3
    rgb = base * (0.9 + 0.12 * fine[..., None]) * (1 - 0.13 * g[..., None])
    seam_y = (np.minimum(y % plank_px, plank_px - 1 - (y % plank_px)) < 2)
    seam_x = ((ox % length_px) < 2)
    rgb[seam_y | seam_x] *= seam
    knots = rng.integers(0, 4)
    return rgb


def wood_table():
    rgb = planks(512, 512, 64, 512, ["#8a5a36", "#7d5131", "#93613b", "#86573a"], 3, grain=6, seam=0.6)
    img = to_img(rgb)
    img = brush_strokes(img, None, 1800, 11, length=(10, 30), width=(1, 3), jitter=0.05, alpha=40)
    img.save(path(TEX, "wood_table.png"))


def wood_floor():
    rgb = planks(512, 512, 64, 256, ["#5a3b27", "#4f3423", "#62412b", "#553925"], 5, grain=5, seam=0.45)
    img = to_img(rgb * 0.95)
    img = brush_strokes(img, None, 1500, 12, length=(12, 30), width=(1, 3), jitter=0.05, alpha=35)
    img.save(path(TEX, "wood_floor.png"))


def wallpaper():
    w = h = 512
    y, x = np.mgrid[0:h, 0:w]
    base = hexc("#2c463c")
    n = tile_noise(w, h, 6, 6, 21, 5)
    stripe = (np.sin(x / w * np.pi * 2 * 8) * 0.5 + 0.5) ** 6
    rgb = base * (0.9 + 0.18 * n[..., None]) * (1 + 0.07 * stripe[..., None])
    img = to_img(rgb)
    d = ImageDraw.Draw(img, "RGBA")
    # small repeating sprig motif between stripes
    for gx in range(8):
        for gy in range(6):
            cx = gx * 64 + 32 + (16 if gy % 2 else 0)
            cy = gy * (512 // 6) + 40
            cx %= 512
            col = (190, 160, 96, 70)
            d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=col)
            for a in (0.6, 2.5, 4.2):
                ex, ey = cx + np.cos(a) * 9, cy + np.sin(a) * 9
                d.ellipse([ex - 4, ey - 2.5, ex + 4, ey + 2.5], fill=(150, 170, 120, 55))
    img = brush_strokes(img, None, 1200, 22, jitter=0.04, alpha=30)
    img.save(path(TEX, "wallpaper.png"))


def rug():
    w = h = 512
    y, x = np.mgrid[0:h, 0:w].astype(float)
    u, v = (x + 0.5) / w * 2 - 1, (y + 0.5) / h * 2 - 1
    edge = np.maximum(np.abs(u), np.abs(v))
    red, ochre, navy, cream = hexc("#8a2f2a"), hexc("#c9913d"), hexc("#28385a"), hexc("#e6d3a8")
    rgb = np.zeros((h, w, 3)) + red
    # concentric borders
    rgb[edge > 0.80] = navy
    rgb[(edge > 0.86) & (edge < 0.90)] = ochre
    rgb[edge > 0.95] = red * 0.8
    band = (edge > 0.70) & (edge < 0.76)
    rgb[band] = cream
    # diamonds along the navy border
    along = np.where(np.abs(u) > np.abs(v), v, u)
    dia = (np.abs((along * 8) % 2 - 1) + np.abs((edge - 0.88) * 25)) < 0.55
    rgb[(edge > 0.80) & (edge < 0.95) & dia] = ochre
    # central medallion
    r = np.sqrt(u * u + (v * 1.0) ** 2)
    med = np.abs(u) + np.abs(v)
    rgb[med < 0.55] = navy
    rgb[med < 0.47] = ochre
    rgb[med < 0.40] = red * 1.1
    rgb[r < 0.14] = cream
    petal = (np.abs(np.sin(np.arctan2(v, u) * 4)) * 0.12 + 0.18) > r
    rgb[petal & (r > 0.14)] = ochre * 0.9
    n = tile_noise(w, h, 64, 64, 31, 3)
    rgb *= (0.86 + 0.2 * n[..., None])
    img = to_img(rgb)
    img = brush_strokes(img, None, 6000, 33, length=(2, 5), width=(1, 2), jitter=0.12, alpha=60)
    img.save(path(TEX, "rug.png"))


def felt(name, color, seed):
    w = h = 128
    n = tile_noise(w, h, 16, 16, seed, 4)
    rgb = hexc(color) * (0.85 + 0.3 * n[..., None])
    to_img(rgb).save(path(TEX, name))


def stone():
    w = h = 256
    n = tile_noise(w, h, 6, 6, 41, 6)
    m = tile_noise(w, h, 24, 24, 42, 3)
    a, b = hexc("#7d776c"), hexc("#5b564f")
    rgb = lerp(a, b, n) * (0.88 + 0.22 * m[..., None])
    moss = smoothstep(0.62, 0.8, tile_noise(w, h, 4, 4, 43, 4))
    rgb = lerp(rgb, hexc("#5f7040"), moss * 0.55)
    img = to_img(rgb)
    img = brush_strokes(img, None, 900, 44, length=(4, 10), width=(1, 3), jitter=0.08, alpha=60)
    img.save(path(TEX, "stone.png"))


def battlemat(fire_world, mat_origin):
    """A painted grass map with a path and a stream, 60 px per 5 cm square.

    fire_world: (x, z) of the campfire prop; mat_origin: (x0, z0) world corner of the mat.
    """
    sq = 60
    w, h = 20 * sq, 13 * sq
    y, x = np.mgrid[0:h, 0:w].astype(float)
    n = tile_noise(w, h, 10, 7, 51, 5)
    m = tile_noise(w, h, 40, 26, 52, 3)
    grass_a, grass_b, grass_c = hexc("#5f7f45"), hexc("#4b6a3a"), hexc("#7d9150")
    rgb = lerp(lerp(grass_b, grass_a, n), grass_c, smoothstep(0.65, 0.9, m) * 0.6)
    # dirt path
    path_pts = catmull([(-40, 640), (220, 600), (420, 470), (560, 430), (760, 470), (930, 380), (1250, 330)], 16)
    dp = seg_dist(x, y, path_pts) + (n - 0.5) * 30
    dirt = lerp(hexc("#9a7a52"), hexc("#7d6243"), m)
    rgb = lerp(rgb, dirt, smoothstep(40, 26, dp))
    # stream along the top-left
    river = catmull([(-40, 150), (160, 110), (330, 160), (470, 90), (600, -40)], 16)
    dr = seg_dist(x, y, river) + (n - 0.5) * 18
    water = lerp(hexc("#4f7f9a"), hexc("#7fb0c0"), smoothstep(0.4, 0.9, m))
    bank = smoothstep(36, 24, dr)
    rgb = lerp(rgb, hexc("#6a6a48"), smoothstep(46, 34, dr) * (1 - bank))
    rgb = lerp(rgb, water, bank)
    # campfire scorch (matches the campfire prop)
    cx = (fire_world[0] - mat_origin[0]) * sq / 5.0
    cy = (fire_world[1] - mat_origin[1]) * sq / 5.0
    sc = np.sqrt((x - cx) ** 2 + (y - cy) ** 2)
    rgb = lerp(rgb, hexc("#3e3428"), smoothstep(70, 30, sc + (n - 0.5) * 30) * 0.7)
    img = to_img(rgb)
    img = brush_strokes(img, None, 16000, 53, length=(6, 16), width=(2, 4), jitter=0.09, alpha=55)
    d = ImageDraw.Draw(img, "RGBA")
    rng = np.random.default_rng(54)
    for _ in range(140):  # flowers
        fx, fy = rng.integers(0, w), rng.integers(0, h)
        if dp[fy, fx] < 50 or dr[fy, fx] < 50:
            continue
        col = [(240, 220, 120, 200), (230, 140, 160, 190), (250, 250, 240, 200)][rng.integers(0, 3)]
        d.ellipse([fx - 3, fy - 3, fx + 3, fy + 3], fill=col)
    # grid
    for gx in range(0, w + 1, sq):
        d.line([(gx, 0), (gx, h)], fill=(25, 30, 20, 95), width=2)
    for gy in range(0, h + 1, sq):
        d.line([(0, gy), (w, gy)], fill=(25, 30, 20, 95), width=2)
    # cloth binding
    d.rectangle([0, 0, w - 1, h - 1], outline=(40, 34, 28, 255), width=8)
    img.save(path(TEX, "battlemat.png"))


def paper():
    w, h = 256, 200
    n = tile_noise(w, h, 8, 6, 61, 4)
    rgb = hexc("#efe4c8") * (0.92 + 0.1 * n[..., None])
    img = to_img(rgb)
    d = ImageDraw.Draw(img, "RGBA")
    d.rectangle([10, 10, w - 10, 34], fill=(120, 60, 50, 200))
    hand = font("NothingYouCouldDo-Regular.ttf", 20)
    d.text((16, 9), "Character", font=hand, fill=(250, 240, 220, 255))
    for i in range(6):
        yy = 52 + i * 22
        d.line([(110, yy + 16), (w - 14, yy + 16)], fill=(90, 80, 70, 140), width=1)
        d.rectangle([14, yy, 38, yy + 18], outline=(90, 70, 60, 200), width=2)
        d.text((48, yy - 2), ["STR", "DEX", "CON", "INT", "WIS", "CHA"][i], font=hand, fill=(70, 55, 45, 230))
        d.text((116, yy - 4), ["scribble", "notes", "loot?", "", "HP 24", "spells"][i], font=hand,
               fill=(40, 50, 90, 200))
    img.save(path(TEX, "paper.png"))


def dm_screen():
    w, h = 1024, 256
    img = Image.new("RGB", (w, h))
    # outer side (players see this): deep red leather with a gold d20 emblem
    n = tile_noise(512, h, 12, 6, 71, 5)
    outer = hexc("#6b2a25") * (0.8 + 0.3 * n[..., None])
    img.paste(to_img(outer), (0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    for i in range(3):
        x0 = i * 512 // 3
        d.rectangle([x0 + 10, 12, x0 + 512 // 3 - 10, h - 12], outline=(214, 170, 90, 210), width=4)
    cx, cy, r = 256, 128, 60
    pts = [(cx + r * np.cos(a), cy + r * np.sin(a)) for a in np.linspace(-np.pi / 2, 3 * np.pi / 2, 7)[:-1]]
    d.polygon(pts, outline=(230, 190, 110, 255), width=5)
    d.polygon([pts[0], pts[2], pts[4]], outline=(230, 190, 110, 200), width=3)
    d.text((cx, cy + 6), "20", font=font("Lora-Bold.ttf", 34), fill=(240, 200, 120, 255), anchor="mm")
    # inner side (the DM sees this): parchment notes, tables and sticky notes
    n2 = tile_noise(512, h, 10, 5, 72, 4)
    inner = hexc("#eadcb8") * (0.9 + 0.12 * n2[..., None])
    img.paste(to_img(inner), (512, 0))
    d = ImageDraw.Draw(img, "RGBA")
    hand = font("NothingYouCouldDo-Regular.ttf", 18)
    for i in range(3):
        x0 = 512 + i * 512 // 3
        d.rectangle([x0 + 8, 10, x0 + 512 // 3 - 8, h - 10], outline=(110, 80, 50, 160), width=2)
        for r_ in range(7):
            yy = 46 + r_ * 26
            d.line([(x0 + 16, yy), (x0 + 512 // 3 - 16, yy)], fill=(110, 90, 70, 110), width=1)
        d.text((x0 + 16, 14), ["Conditions", "DCs", "Names!"][i], font=hand, fill=(90, 40, 30, 230))
    rng = np.random.default_rng(73)
    for i, (sx, sy) in enumerate([(600, 150), (790, 60), (930, 160)]):
        col = [(250, 225, 110, 235), (160, 220, 200, 235), (250, 170, 160, 235)][i]
        d.rectangle([sx, sy, sx + 64, sy + 64], fill=col)
        d.text((sx + 6, sy + 8), ["goblin\nHP 7", "Mara's\nsister?", "seed:\nsymbol"][i], font=hand,
               fill=(60, 40, 30, 230))
    img.save(path(TEX, "dm_screen.png"))


def window():
    w, h = 256, 320
    y, x = np.mgrid[0:h, 0:w].astype(float)
    sky = lerp(hexc("#0d1a33"), hexc("#26406e"), (y / h) ** 0.8)
    mx, my = 180, 70
    md = np.sqrt((x - mx) ** 2 + (y - my) ** 2)
    sky = sky + hexc("#9ab8e8") * (np.exp(-md / 55) * 0.55)[..., None]
    sky = lerp(sky, hexc("#f4f0de"), smoothstep(22, 19, md))
    # distant rooftops
    roof = (h - 70 + 25 * np.sin(x / 37) + 12 * np.sin(x / 11 + 1)) < y
    sky[roof] = hexc("#0b1020")
    rng = np.random.default_rng(81)
    img = to_img(sky)
    d = ImageDraw.Draw(img, "RGBA")
    for _ in range(20):  # warm windows far away
        wx, wy = rng.integers(10, w - 10), rng.integers(h - 50, h - 10)
        d.rectangle([wx, wy, wx + 4, wy + 6], fill=(255, 200, 120, 180))
    for _ in range(26):
        sx, sy = rng.integers(0, w), rng.integers(0, 150)
        d.point((sx, sy), fill=(230, 235, 255, 200))
    for _ in range(140):  # rain streaks
        rx, ry = rng.integers(-20, w), rng.integers(-20, h)
        L = rng.integers(10, 26)
        d.line([(rx, ry), (rx + L * 0.25, ry + L)], fill=(190, 210, 240, rng.integers(25, 70)), width=1)
    for _ in range(30):  # drops on the glass
        dx, dy = rng.integers(0, w), rng.integers(0, h)
        r = rng.uniform(1.5, 3.5)
        d.ellipse([dx - r, dy - r, dx + r, dy + r], fill=(200, 220, 255, 60))
    # muntins
    d.rectangle([w // 2 - 4, 0, w // 2 + 4, h], fill=(40, 30, 24, 255))
    d.rectangle([0, h // 2 - 4, w, h // 2 + 4], fill=(40, 30, 24, 255))
    img.save(path(TEX, "window.png"))


def blob():
    s = 64
    y, x = np.mgrid[0:s, 0:s].astype(float)
    r = np.sqrt(((x + 0.5) / s * 2 - 1) ** 2 + ((y + 0.5) / s * 2 - 1) ** 2)
    a = smoothstep(1.0, 0.15, r) ** 1.4
    to_img(np.ones((s, s, 3)), a).save(path(TEX, "blob.png"))


def d20_texture(faces):
    """faces: list of (number, uv_triangle_px) in a 512x512 texture."""
    w = h = 512
    n = tile_noise(w, h, 6, 6, 91, 5)
    swirl = tile_noise(w, h, 3, 3, 92, 4)
    body = lerp(hexc("#3a2a6a"), hexc("#6a3a8a"), smoothstep(0.3, 0.8, n))
    body = lerp(body, hexc("#2d5a7a"), smoothstep(0.55, 0.8, swirl) * 0.6)
    img = to_img(body)
    d = ImageDraw.Draw(img, "RGBA")
    f = font("Lora-Bold.ttf", 40)
    for num, tri in faces:
        (ax, ay), (bx, by), (cx, cy) = tri
        d.line([(ax, ay), (bx, by), (cx, cy), (ax, ay)], fill=(255, 255, 255, 50), width=3)
        gx, gy = (ax + bx + cx) / 3, (ay + by + cy) / 3 + 2
        txt = str(num) + ("." if num in (6, 9) else "")
        col = (255, 214, 120, 255) if num != 20 else (255, 236, 160, 255)
        d.text((gx + 1.5, gy + 1.5), txt, font=f, fill=(20, 10, 30, 200), anchor="mm")
        d.text((gx, gy), txt, font=f, fill=col, anchor="mm")
    img.save(path(TEX, "d20.png"))


def vignette():
    w, h = 320, 180
    y, x = np.mgrid[0:h, 0:w].astype(float)
    u, v = (x + 0.5) / w * 2 - 1, (y + 0.5) / h * 2 - 1
    r = np.sqrt(u * u * 0.9 + v * v * 1.1)
    a = smoothstep(0.55, 1.35, r) ** 1.3
    to_img(np.zeros((h, w, 3)) + hexc("#120a06"), a).save(path("assets/ui", "vignette.png"))


def build_all(d20_faces, fire_world, mat_origin):
    palette_png()
    wood_table()
    wood_floor()
    wallpaper()
    rug()
    felt("felt.png", "#4a2a5a", 63)
    stone()
    battlemat(fire_world, mat_origin)
    paper()
    dm_screen()
    window()
    blob()
    d20_texture(d20_faces)
    vignette()
