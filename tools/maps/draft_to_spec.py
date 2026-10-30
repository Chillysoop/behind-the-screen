"""Turn an importer draft (import_map.py) into a map spec skeleton to finish by hand: crop the
room out of the draft, turn it so it fits the 20 x 13 mat (with its way in on the west edge where
it can), and write the squares as a grid with a legend of first-guess pieces.

    python3 tools/maps/draft_to_spec.py DRAFT.json --out ROOM.map
        [--crop col,row,w,h]       the room's squares in the draft (default: everything not outside)
        [--rotate auto|0|90|180|270]   quarter turns clockwise (auto: fit the mat, way in to the west)
        [--scale auto|1|2|3]       blow a small room up (each square becomes 2 x 2 or 3 x 3)
        [--id ID] [--title TITLE] [--adventure ID] [--credit TEXT]

What it guesses: walls (drawn along the grid lines or filling squares) become wall_room, doors
wall_door, plants bush; stairs, water, dark squares and objects are left as TODO squares ('S',
'~', '_' and '?') the builder refuses until they're replaced by real pieces. A room bigger than the
mat is cut to fit (the warning says by how much); condense it by hand.
"""
import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mapspec as ms  # noqa: E402

CHAR = {"outside": " ", "dark": "_", "floor": ".", "wall": "#", "door": "D", "water": "~", "stairs": "S",
        "plants": "*", "object": "?"}
LEGEND = [
    ("#", "wall_room", "walls", "auto"),
    ("D", "wall_door", "doors", "auto"),
    ("*", "bush", "plants", ""),
    ("S", "TODO_stairs", "stairs", ""),
    ("~", "TODO_water", "water", ""),
    ("_", "TODO_dark", "dark", ""),
    ("?", "TODO_object", "things", ""),
]


def rotate(cells, quarter):
    """Turn a grid of rows a quarter turn clockwise, quarter times."""
    for _ in range(quarter % 4):
        cells = [list(row) for row in zip(*cells[::-1])]
    return cells


def room_cells(draft, crop):
    """The draft's classes with its edge walls folded into the squares: a wall or door drawn along
    a grid line becomes a wall or door square on the room's side of the line."""
    cells = [list(r) for r in draft["cells"]]
    rows, cols = len(cells), len(cells[0])
    eh, ev = draft["edges"]["h"], draft["edges"]["v"]

    def inside(r, c):
        return 0 <= r < rows and 0 <= c < cols and cells[r][c] not in ("outside", "dark")

    def mark(r, c, k):
        if 0 <= r < rows and 0 <= c < cols and cells[r][c] in ("floor", "object", "outside"):
            cells[r][c] = k if cells[r][c] != "outside" or k == "wall" else cells[r][c]

    for r in range(rows + 1):
        for c in range(cols):
            k = eh[r][c]
            if k:
                # The line between row r-1 and row r: the wall goes on whichever side is room.
                up, down = inside(r - 1, c), inside(r, c)
                if down and not up:
                    mark(r, c, k)
                elif up and not down:
                    mark(r - 1, c, k)
                elif up and down:
                    mark(r, c, k)
    for r in range(rows):
        for c in range(cols + 1):
            k = ev[r][c]
            if k:
                left, right = inside(r, c - 1), inside(r, c)
                if right and not left:
                    mark(r, c, k)
                elif left and not right:
                    mark(r, c - 1, k)
                elif left and right:
                    mark(r, c, k)
    if crop:
        c0, r0, w, h = crop
        cells = [row[c0:c0 + w] for row in cells[r0:r0 + h]]
    else:
        keep_r = [i for i, row in enumerate(cells) if any(k not in ("outside", "dark") for k in row)]
        keep_c = [j for j in range(cols) if any(cells[i][j] not in ("outside", "dark") for i in range(rows))]
        if keep_r and keep_c:
            cells = [row[keep_c[0]:keep_c[-1] + 1] for row in cells[keep_r[0]:keep_r[-1] + 1]]
    return cells


def pick_rotation(cells):
    """The turn that fits the mat best, then puts the most doors on the west side."""
    best = None
    for q in (0, 1, 2, 3):
        g = rotate(cells, q)
        h, w = len(g), len(g[0])
        over = max(0, w - ms.W) + max(0, h - ms.H)
        west = sum(1 for row in g for j, k in enumerate(row) if k == "door" and j < w / 3)
        key = (over, -west, q)
        if best is None or key < best[0]:
            best = (key, q)
    return best[1]


def to_spec(draft, crop=None, rot="auto", scale="auto", bid="new_map", title="A new map", adventure="imported",
            credit=None):
    cells = room_cells(draft, crop)
    q = pick_rotation(cells) if rot == "auto" else int(rot) // 90
    cells = rotate(cells, q)
    h, w = len(cells), len(cells[0])
    if scale == "auto":
        s = 1
        for k in (3, 2):
            if w * k <= ms.W and h * k <= ms.H:
                s = k
                break
    else:
        s = int(scale)
    if s > 1:
        cells = [[k for k in row for _ in range(s)] for row in cells for _ in range(s)]
        h, w = len(cells), len(cells[0])
    notes = []
    if w > ms.W or h > ms.H:
        notes.append(f"the room is {w} x {h} squares: cut to {ms.W} x {ms.H} round its middle; condense it by hand")
        x0, y0 = max(0, (w - ms.W) // 2), max(0, (h - ms.H) // 2)
        cells = [row[x0:x0 + ms.W] for row in cells[y0:y0 + ms.H]]
        h, w = len(cells), len(cells[0])
    ox, oy = (ms.W - w) // 2, (ms.H - h) // 2
    grid = [[" "] * ms.W for _ in range(ms.H)]
    for r in range(h):
        for c in range(w):
            grid[oy + r][ox + c] = CHAR.get(cells[r][c], "?")
    # Starts: the party at the open square nearest the middle of the west side, the foes the east.
    free = [(x, y) for y in range(ms.H) for x in range(ms.W) if grid[y][x] == "."]

    def nearest(tx, ty):
        if not free:
            return (tx + 1, ty + 1)
        x, y = min(free, key=lambda p: (p[0] - tx) ** 2 + (p[1] - ty) ** 2)
        return (x + 1, y + 1)

    party = nearest(2, ms.H // 2)
    foes = nearest(ms.W - 3, ms.H // 2)
    npc = nearest(ms.W // 2, 2)
    used = {ch for row in grid for ch in row}
    src = os.path.basename(draft["image"])
    out = [f"-- Drafted by tools/maps/draft_to_spec.py from {src}"
           f"{' (crop ' + ','.join(map(str, crop)) + ')' if crop else ''}, turned {q * 90} degrees"
           f"{', scaled x' + str(s) if s > 1 else ''}.",
           "-- Finish it by hand: swap the TODO squares for real pieces, check the walls and doors, add spots.",
           "-- tools/maps/README.md has the format; python3 tools/maps/build_maps.py checks it."]
    out += [f"-- NOTE: {n}" for n in notes]
    out += ["", f"id: {bid}", f"title: {title}", "light: candle", f"adventure: {adventure}", "source: imported",
            f"credit: {credit or 'imported from ' + src}", f"about: {title}, first pass from the importer.",
            "tags: imported", f"party: {party[0]},{party[1]}", f"foes: {foes[0]},{foes[1]}", f"npc: {npc[0]},{npc[1]}",
            "", "grid:"]
    out += ["|" + "".join(row) + "|" for row in grid]
    out += ["", "legend:", "-- char | kind | feature | turn"]
    for ch, kind, feat, turn in LEGEND:
        if ch in used:
            out.append(f"{ch}  | {kind:<12} | {feat:<8} | {turn}")
    out += ["", "pieces:", "-- feature | kind | x,y | turn", "floor | floor_flags | 1,1 |", "",
            "features:", "-- id | flags | words | say", "floor | base | | the floor"]
    if "#" in used or "D" in used:
        out.append("walls | base | | walls")
    out += ["", "spots:", "-- key | x,y | name | one line", f"way_in | {party[0]},{party[1]} | the way in | Where the party comes in.", ""]
    return "\n".join(out), notes


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("draft")
    ap.add_argument("--out", required=True)
    ap.add_argument("--crop", help="col,row,w,h in the draft's squares")
    ap.add_argument("--rotate", default="auto")
    ap.add_argument("--scale", default="auto")
    ap.add_argument("--id", default=None)
    ap.add_argument("--title", default=None)
    ap.add_argument("--adventure", default="imported")
    ap.add_argument("--credit", default=None)
    a = ap.parse_args()
    draft = json.load(open(a.draft))
    crop = [int(v) for v in a.crop.split(",")] if a.crop else None
    bid = a.id or os.path.splitext(os.path.basename(a.out))[0]
    text, notes = to_spec(draft, crop, a.rotate, a.scale, bid, a.title or bid.replace("_", " ").capitalize(),
                          a.adventure, a.credit)
    with open(a.out, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    for n in notes:
        print("note:", n)
    print("wrote", a.out)


if __name__ == "__main__":
    main()
