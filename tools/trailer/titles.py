"""Text for the trailer, drawn as transparent 1920x1080 PNGs (python3 tools/trailer/titles.py OUT_DIR).

Big lines in Lora Bold, the game's own serif, in its gold; small lines in Outfit. Each card is a
PNG with a soft shadow so it reads over the table. The end card is opaque: the title over the
table's own dark wood colour, with a vignette.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1920, 1080
ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
FONTS = os.path.join(ROOT, "assets", "fonts")
GOLD = (232, 176, 74, 255)
CREAM = (243, 231, 207, 255)
DARK = (27, 20, 17)


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


def shadowed(lines, out, y_center=None, anchor_y=None):
    """lines: [(text, font, color)], stacked and centred; y_center: where the block's middle sits."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sizes = []
    for text, f, _ in lines:
        box = f.getbbox(text)
        sizes.append((box[2] - box[0], box[3] - box[1], box))
    gap = 18
    total = sum(s[1] for s in sizes) + gap * (len(lines) - 1)
    y = (y_center if y_center is not None else H * 0.5) - total / 2
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    d = ImageDraw.Draw(img)
    placed = []
    for (text, f, col), (w, h, box) in zip(lines, sizes):
        x = (W - w) / 2 - box[0]
        yy = y - box[1]
        placed.append((x, yy, text, f, col))
        sd.text((x + 4, yy + 6), text, font=f, fill=(0, 0, 0, 230))
        y += h + gap
    # A soft dark glow behind the words, so they read over a busy table.
    glow = shadow.filter(ImageFilter.GaussianBlur(18))
    glow2 = shadow.filter(ImageFilter.GaussianBlur(5))
    img = Image.alpha_composite(img, glow)
    img = Image.alpha_composite(img, glow2)
    d = ImageDraw.Draw(img)
    for x, yy, text, f, col in placed:
        d.text((x, yy), text, font=f, fill=col)
    img.save(out)


def end_card(out, tagline, small):
    img = Image.new("RGB", (W, H), DARK)
    # A warm lamp-lit middle fading to near black at the edges.
    glow = Image.new("L", (W, H), 0)
    gd = ImageDraw.Draw(glow)
    gd.ellipse((W * 0.12, H * 0.05, W * 0.88, H * 0.95), fill=255)
    glow = glow.filter(ImageFilter.GaussianBlur(220))
    warm = Image.new("RGB", (W, H), (74, 52, 36))
    img = Image.composite(warm, img, glow)
    rgba = img.convert("RGBA")
    rgba.save(out.replace(".png", "_bg.png"))
    title = font("Lora-Bold.ttf", 150)
    tag = font("Outfit-Regular.ttf", 52)
    sm = font("Outfit-Regular.ttf", 30)
    over = os.path.splitext(out)[0]
    shadowed([("BEHIND THE SCREEN", title, GOLD)], over + "_title.png", y_center=H * 0.44)
    shadowed([(tagline, tag, CREAM)], over + "_tag.png", y_center=H * 0.60)
    shadowed([(small, sm, (185, 168, 142, 255))], over + "_small.png", y_center=H * 0.86)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "titles"
    os.makedirs(out, exist_ok=True)
    big = font("Lora-Bold.ttf", 112)
    mid = font("Lora-Bold.ttf", 92)
    cards = {
        "four_friends": [("FOUR FRIENDS.", big, CREAM)],
        "one_table": [("ONE TABLE.", big, CREAM)],
        "you_run_it": [("AND YOU RUN IT.", big, GOLD)],
        "plan": [("PLAN THE NIGHT.", mid, CREAM)],
        "bend": [("BEND THE STORY.", mid, CREAM)],
        "run_rooms": [("RUN EVERY ROOM.", mid, CREAM)],
        "make_call": [("MAKE THE CALL.", mid, GOLD)],
        "initiative": [("ROLL FOR INITIATIVE.", mid, CREAM)],
        "read": [("READ YOUR PLAYERS.", mid, CREAM)],
        "want": [("GIVE THEM WHAT THEY WANT.", mid, GOLD)],
        "play": [("PLAY THE ADVENTURE.", big, CREAM)],
        "run_table": [("RUN THE TABLE.", big, GOLD)],
    }
    for name, lines in cards.items():
        shadowed(lines, os.path.join(out, name + ".png"), y_center=H * 0.5 if name in
                 ("four_friends", "one_table", "you_run_it", "play", "run_table") else H * 0.16)
    end_card(os.path.join(out, "end.png"), "Play the adventure. Run the table. At the same time.",
             "A cozy game about being the one behind the screen")
    print("titles in", out)


if __name__ == "__main__":
    main()
