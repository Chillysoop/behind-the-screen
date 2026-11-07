"""The status ring (November 3): a token ring laid around a mini's base on the battle mat when
it's under an effect (charmed, turning to stone, frightened...). A soft-edged band with eight
small notches, like a cardboard condition token. White: the mark material tints it by effect.

    python3 tools/gen_ring.py      # writes assets/textures/ring.png
"""
import math

from PIL import Image

N = 128
OUTER = 61.0     # outer radius (px)
INNER = 47.0     # inner radius
NOTCHES = 8      # little gaps around the band
NOTCH = 0.10     # each gap's width, in radians

im = Image.new("RGBA", (N, N), (255, 255, 255, 0))
px = im.load()
c = N / 2.0
for y in range(N):
    for x in range(N):
        dx, dy = x + 0.5 - c, y + 0.5 - c
        r = math.hypot(dx, dy)
        # Inside the band, with antialiased edges.
        edge = min(r - INNER, OUTER - r)
        if edge <= 0:
            continue
        a = min(1.0, edge / 1.5)
        # A brighter rim on both edges, a lighter middle: reads as a ring, not a disc.
        mid = (r - INNER) / (OUTER - INNER)
        a *= 0.75 + 0.25 * abs(mid - 0.5) * 2
        # The notches.
        ang = math.atan2(dy, dx) % (2 * math.pi / NOTCHES)
        gap = min(ang, 2 * math.pi / NOTCHES - ang)
        if gap < NOTCH / 2:
            a *= max(0.0, gap / (NOTCH / 2)) ** 2
        px[x, y] = (255, 255, 255, int(round(a * 255)))
im.save("assets/textures/ring.png")
print("wrote assets/textures/ring.png")
