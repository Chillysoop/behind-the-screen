"""The battle-mat mark (real-session pass): one grid square of a spell's area or a lasting zone.
A rounded square with a bright rim and a lighter fill, so a block of them reads as an area with
its squares still countable. White: the mark material tints it.

    python3 tools/gen_mark.py      # writes assets/textures/mark.png
"""
from PIL import Image

N = 64
R = 10        # corner radius
INSET = 3     # gap to the next square
RIM = 5       # rim width


def inside(x, y):
    """Distance from (x, y) to the rounded square's edge, positive inside."""
    lo, hi = INSET + R, N - INSET - R
    cx = min(max(x, lo), hi)
    cy = min(max(y, lo), hi)
    d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
    if lo <= x <= hi or lo <= y <= hi:
        # Along a straight edge: distance to that edge.
        ex = min(x - INSET, N - INSET - x)
        ey = min(y - INSET, N - INSET - y)
        return min(ex, ey)
    return R - d


im = Image.new("RGBA", (N, N), (255, 255, 255, 0))
px = im.load()
for y in range(N):
    for x in range(N):
        d = inside(x + 0.5, y + 0.5)
        if d <= 0:
            a = 0.0
        elif d < 1.2:
            a = d / 1.2                     # antialiased outer edge
        elif d < RIM:
            a = 1.0                         # the rim
        elif d < RIM + 3:
            a = 1.0 - 0.45 * (d - RIM) / 3  # rim fades into the fill
        else:
            a = 0.55                        # the fill
        px[x, y] = (255, 255, 255, int(round(a * 255)))
im.save("assets/textures/mark.png")
print("wrote assets/textures/mark.png")
