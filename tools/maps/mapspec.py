"""Map specs: the plain-text battle maps in game/data/maps/*.map, read, checked and turned into
boards (the same shape as game/data/boards.lua). Shared by build_maps.py and draft_to_spec.py;
the format is written up in tools/maps/README.md.

A spec, in short:

    -- comments start with two dashes
    id: museum_chamber
    title: The Chamber of Ancients
    light: candle
    adventure: museum
    room: chamber
    source: adventure
    credit: The Museum of Nightmares by Luke Russell (DMs Guild), Area 1 map, rooms 3A-3H
    about: The jars, the tablet and the bone guardian's sarcophagus, as on the book's map.
    tags: indoor, ground floor, puzzle
    order: 3
    party: 3,7
    foes: 14,7
    npc: 10,4

    grid:
    |####################|        13 rows of 20 squares between bars, x west to east,
    |#..................#|        y north to south; '.' open floor, ' ' outside the room
    ...

    legend:
    -- char | kind      | feature | turn
    #       | wall_room | walls   | auto

    pieces:
    -- feature | kind         | x,y | turn
    floor      | floor_marble | 1,1 |

    features:
    -- id  | flags | words              | say
    floor  | base  | marble             | a marble floor

    spots:
    -- key | x,y | name        | line
    3A     | 9,6 | the pedestal | A raised stand with a button carved like a woman.
"""
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
W, H = 20, 13
MAPS_DIR = os.path.join(ROOT, "game", "data", "maps")
LIBRARY = os.path.join(ROOT, "game", "data", "map_library.lua")
PROPS = os.path.join(ROOT, "game", "data", "props.lua")
BOARDS = os.path.join(ROOT, "game", "data", "boards.lua")

FLOOR, OUTSIDE = ".", " "
LIGHTS = ("day", "candle", "hearth", "fire", "dark")

# Kinds on their way into the kit (tools/gen_props.py), with the footprints they were promised:
# build_maps.py --lenient lets a spec use them before they land in game/data/props.lua (with a
# warning). Once they're in the kit, the kit's own numbers win and this list isn't read for them;
# by default (strict) a kind the kit doesn't have is refused. (October 30: the museum's pieces,
# all landed now.)
EXPECTED = {
    "floor_marble": dict(fw=20, fh=13, blocks=False, flat=True),
    "paving": dict(fw=1, fh=1, blocks=False, flat=True),
    "wall_diag": dict(fw=1, fh=1, blocks=True),
    "wall_painting": dict(fw=1, fh=1, blocks=True),
    "wall_portrait": dict(fw=1, fh=1, blocks=True),
    "display_case": dict(fw=1, fh=1, blocks=True),
    "plinth": dict(fw=1, fh=1, blocks=True),
    "hedge": dict(fw=1, fh=1, blocks=True),
    "topiary": dict(fw=1, fh=1, blocks=True),
    "garden_steps": dict(fw=2, fh=3, blocks=False),
    "stairs_straight": dict(fw=2, fh=3, blocks=False),
    "donation_box": dict(fw=1, fh=1, blocks=True),
    "canopic_jars": dict(fw=1, fh=1, blocks=True),
    "stone_tablet": dict(fw=1, fh=1, blocks=True),
    "ritual_basin": dict(fw=1, fh=1, blocks=True),
    "diorama_cave": dict(fw=3, fh=2, blocks=True),
    "diorama_kitchen": dict(fw=3, fh=2, blocks=True),
    "model_city": dict(fw=4, fh=2, blocks=True),
    "giant_skull": dict(fw=3, fh=2, blocks=True),
    "stuffed_bird": dict(fw=1, fh=1, blocks=True),
    "lectern": dict(fw=1, fh=1, blocks=True),
    "blackboard": dict(fw=2, fh=1, blocks=True),
    "couch": dict(fw=2, fh=1, blocks=True),
    "statue_victim": dict(fw=1, fh=1, blocks=True),
    "statue_victim_b": dict(fw=1, fh=1, blocks=True),
    "statue_victim_c": dict(fw=1, fh=1, blocks=True),
    "tapestry": dict(fw=1, fh=1, blocks=True),
    "mech_dais": dict(fw=2, fh=2, blocks=False),
    "souvenir_table": dict(fw=2, fh=1, blocks=True),
    "bench_museum": dict(fw=2, fh=1, blocks=True),
}

# Pieces that stand against a wall or in a wall line (doors too): "auto" turns them to face the
# open floor, and walls beside them line up with them.
WALL_LIKE = re.compile(r"^(wall_|stone_wall$|tapestry$|curtain$|bookshelf$|scroll_rack$|blackboard$|hearth$|"
                       r"wardrobe$|vault_door$|ruin_wall|door$|door_open$|door_locked$)")


class SpecError(Exception):
    pass


# ------------------------------------------------------------------ the kit

def load_kit(props_path=PROPS):
    """The prop kinds in game/data/props.lua: {kind: dict(fw, fh, blocks, flat, clear, mask, words, say)}."""
    kit = {}
    if not os.path.exists(props_path):
        return kit
    src = open(props_path, encoding="utf-8").read()
    for m in re.finditer(r"^\s{4}(\w+) = \{ fw = (\d+), fh = (\d+), blocks = (\w+),(.*?)\n\s+words = \{(.*?)\}, "
                         r"say = \"((?:[^\"\\]|\\.)*)\"", src, re.M | re.S):
        name, fw, fh, blocks, rest, words, say = m.groups()
        mask = None
        if "mask" in rest:
            mask = {(int(a), int(b)) for a, b in re.findall(r"\{ (\d+), (\d+) \}", rest)}
        kit[name] = dict(fw=int(fw), fh=int(fh), blocks=(blocks == "true"), flat=("flat = true" in rest),
                         clear=("clear = true" in rest), mask=mask, words=re.findall(r"\"((?:[^\"\\]|\\.)*)\"", words),
                         say=say, cover=("cover = true" in rest), kit=True)
    # Doors (door, door_open, door_locked): "closed", "open" or "locked".
    for m in re.finditer(r"^\s{4}(\w+) = \{([^\n]*\n[^\n]*)", src, re.M):
        dm = re.search(r'door = "(\w+)"', m.group(2))
        if dm and m.group(1) in kit:
            kit[m.group(1)]["door"] = dm.group(1)
    return kit


def kit_with_expected(kit, strict=False):
    """The kit, plus the expected kinds that haven't landed yet (unless strict)."""
    out = dict(kit)
    pending = []
    for name, k in EXPECTED.items():
        if name not in out:
            pending.append(name)
            if not strict:
                d = dict(blocks=True, flat=False, clear=False, mask=None, words=[name.replace("_", " ")],
                         say=name.replace("_", " "), cover=False, kit=False)
                d.update(k)
                out[name] = d
    return out, pending


def footprint(kind_def, r):
    fw, fh = kind_def["fw"], kind_def["fh"]
    return (fh, fw) if r % 2 == 1 else (fw, fh)


def squares(kind_def, x, y, r):
    """The squares a piece covers, as in game/model/board.lua: [(x, y, blocks)], off-mat ones too."""
    fw, fh = kind_def["fw"], kind_def["fh"]
    r %= 4
    out = []
    for dy in range(fh):
        for dx in range(fw):
            if r == 0:
                gx, gy = dx, dy
            elif r == 1:
                gx, gy = fh - 1 - dy, dx
            elif r == 2:
                gx, gy = fw - 1 - dx, fh - 1 - dy
            else:
                gx, gy = dy, fw - 1 - dx
            blocks = kind_def["blocks"]
            if kind_def.get("mask"):
                blocks = (dx, dy) in kind_def["mask"]
            out.append((x + gx, y + gy, blocks))
    return out


def is_ground(kind_def):
    """Pieces that lie on the mat (floors, paths, rugs): other pieces may stand on them."""
    return bool(kind_def.get("flat") or kind_def.get("clear") or
                (not kind_def["blocks"] and kind_def["fw"] * kind_def["fh"] >= W * H))


# ------------------------------------------------------------------ reading a spec

SECTIONS = ("grid", "legend", "pieces", "features", "spots")
HEADER_KEYS = ("id", "title", "light", "adventure", "room", "source", "credit", "about", "tags", "order", "party", "foes",
               "npc", "npc_at", "tight")
# source: where the map came from. "adventure": drawn by hand after an adventure's own map;
# "imported": straight from import_map.py and draft_to_spec.py, not finished by hand yet.
SOURCES = ("adventure", "imported")


def _xy(s, where):
    m = re.fullmatch(r"\s*(\d+)\s*,\s*(\d+)\s*", s or "")
    if not m:
        raise SpecError(f"{where}: expected x,y, got {s!r}")
    return int(m.group(1)), int(m.group(2))


def _turn(s, where):
    s = (s or "").strip()
    if s in ("", "0"):
        return 0
    if s == "auto":
        return "auto"
    if s in ("1", "2", "3"):
        return int(s)
    raise SpecError(f"{where}: turn must be 0-3 or auto, got {s!r}")


def _fields(line, n):
    parts = [p.strip() for p in line.split("|")]
    if len(parts) > n:
        parts = parts[:n - 1] + ["|".join(parts[n - 1:])]
    while len(parts) < n:
        parts.append("")
    return parts


def parse(text, path="<spec>"):
    """A spec's text -> a dict of its parts (not checked against the kit yet)."""
    spec = dict(path=path, header={}, grid=[], legend={}, legend_order=[], pieces=[], features=[], spots=[],
                npc_at={})
    section = None
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        raw = lines[i]
        i += 1
        lineno = i
        where = f"{os.path.basename(path)}:{lineno}"
        stripped = raw.strip()
        if section == "grid" and stripped.startswith("|"):
            m = re.fullmatch(r"\s*\|(.*)\|\s*", raw)
            if not m:
                raise SpecError(f"{where}: a grid row is |20 squares|")
            row = m.group(1)
            if len(row) != W:
                raise SpecError(f"{where}: grid row {len(spec['grid']) + 1} has {len(row)} squares, not {W}")
            spec["grid"].append(row)
            continue
        if not stripped or stripped.startswith("--"):
            continue
        m = re.fullmatch(r"(\w+):\s*(.*)", stripped)
        if m and m.group(1) in SECTIONS and m.group(2) == "":
            section = m.group(1)
            continue
        if section is None:
            if not m or m.group(1) not in HEADER_KEYS:
                raise SpecError(f"{where}: expected a header line (key: value), got {stripped!r}")
            key, val = m.group(1), m.group(2).strip()
            if key == "npc_at":
                mm = re.fullmatch(r"(\w+)\s+(\d+\s*,\s*\d+)", val)
                if not mm:
                    raise SpecError(f"{where}: npc_at is 'name x,y'")
                spec["npc_at"][mm.group(1)] = _xy(mm.group(2), where)
            else:
                spec["header"][key] = val
            continue
        if section == "grid":
            raise SpecError(f"{where}: a grid row is |20 squares| (bars at both ends)")
        if section == "legend":
            ch, kind, feat, turn = _fields(raw.strip(), 4)
            if raw.strip().startswith("|"):
                raise SpecError(f"{where}: a legend line starts with its character")
            ch = raw.strip()[0]
            if len(raw.strip().split("|")[0].strip()) != 1:
                raise SpecError(f"{where}: a legend character is one character")
            if ch in (FLOOR, OUTSIDE, "|"):
                raise SpecError(f"{where}: {ch!r} is reserved")
            if ch in spec["legend"]:
                raise SpecError(f"{where}: {ch!r} is in the legend twice")
            if not kind:
                raise SpecError(f"{where}: legend {ch!r} has no kind")
            spec["legend"][ch] = dict(kind=kind, feature=feat or kind, turn=_turn(turn, where), line=lineno)
            spec["legend_order"].append(ch)
        elif section == "pieces":
            feat, kind, xy, turn = _fields(stripped, 4)
            if not feat or not kind:
                raise SpecError(f"{where}: a piece is 'feature | kind | x,y | turn'")
            x, y = _xy(xy, where)
            t = _turn(turn, where)
            if t == "auto":
                raise SpecError(f"{where}: placed pieces take a turn of 0-3")
            spec["pieces"].append(dict(feature=feat, kind=kind, x=x, y=y, r=t, line=lineno))
        elif section == "features":
            fid, flags, words, say = _fields(stripped, 4)
            if not re.fullmatch(r"[a-z][a-z0-9_]*", fid):
                raise SpecError(f"{where}: feature ids are lower_case words, got {fid!r}")
            fl = flags.split()
            bad = [f for f in fl if f not in ("base", "own_words")]
            if bad:
                raise SpecError(f"{where}: unknown flags {bad} (base, own_words)")
            spec["features"].append(dict(id=fid, base="base" in fl, own_words="own_words" in fl,
                                         words=[w.strip() for w in words.split(",") if w.strip()],
                                         say=say or None, line=lineno))
        elif section == "spots":
            key, xy, name, line = _fields(stripped, 4)
            if not key or not name or not line:
                raise SpecError(f"{where}: a spot is 'key | x,y | name | one line'")
            x, y = _xy(xy, where)
            spec["spots"].append(dict(key=key, x=x, y=y, name=name, line=line, lineno=lineno))
    return spec


def read(path):
    return parse(open(path, encoding="utf-8").read(), path)


# ------------------------------------------------------------------ turning a spec into a board

def _auto_turn(kind, x, y, grid_open):
    """Which way a wall piece at (x, y) faces: toward the open floor, its back to the mat's edge,
    the outside or another wall. 0 faces south, 1 west, 2 north, 3 east."""
    if kind == "wall_diag":
        return _diag_turn(x, y, grid_open)
    dirs = [(0, (0, 1)), (3, (1, 0)), (1, (-1, 0)), (2, (0, -1))]   # south, east, west, north: the order of preference

    def on_mat(cx, cy):
        return 1 <= cx <= W and 1 <= cy <= H

    def is_open(cx, cy):
        return on_mat(cx, cy) and grid_open[cy - 1][cx - 1]

    best, best_score = 0, -1
    for r, (dx, dy) in dirs:
        front = is_open(x + dx, y + dy)
        back = is_open(x - dx, y - dy)
        score = (2 if front else 0) + (1 if front and not back else 0) + (1 if front and not on_mat(x - dx, y - dy) else 0)
        if score > best_score:
            best, best_score = r, score
    return best


# wall_diag: which corner of the room it closes off. The kit draws r = 0 for the room's north-west
# corner (the wall runs from the square's south-west corner to its north-east one, the room to the
# south-east); each quarter turn moves it on round the room (1: north-east, 2: south-east,
# 3: south-west), as tools/gen_props.py b_wall_diag says.
DIAG_TURN = {"nw": 0, "ne": 1, "se": 2, "sw": 3}


def _diag_turn(x, y, grid_open):
    def is_open(cx, cy):
        return 1 <= cx <= W and 1 <= cy <= H and grid_open[cy - 1][cx - 1]

    n, s, w, e = is_open(x, y - 1), is_open(x, y + 1), is_open(x - 1, y), is_open(x + 1, y)
    # The room is on the open side: closed to the north and west means the north-west corner.
    if not n and not w:
        return DIAG_TURN["nw"]
    if not s and not w:
        return DIAG_TURN["sw"]
    if not s and not e:
        return DIAG_TURN["se"]
    if not n and not e:
        return DIAG_TURN["ne"]
    # Mid-run of a two-deep diagonal: look one further out.
    if x <= W // 2:
        return DIAG_TURN["nw"] if y <= H // 2 else DIAG_TURN["sw"]
    return DIAG_TURN["ne"] if y <= H // 2 else DIAG_TURN["se"]


def compile_spec(spec, kit):
    """A parsed spec -> (board dict, problems, warnings). The board has the boards.lua shape plus
    id, source, tags, spots, adventure, order."""
    problems, warnings = [], []
    name = os.path.basename(spec["path"])
    hd = spec["header"]

    def bad(msg):
        problems.append(f"{name}: {msg}")

    for key in ("id", "title", "light", "adventure", "source", "credit", "about"):
        if not hd.get(key):
            bad(f"no {key}: line")
    if hd.get("source") and hd["source"] not in SOURCES:
        bad(f"source {hd['source']!r} is not one of {', '.join(SOURCES)}")
    if len(hd.get("about", "")) > 120:
        warnings.append(f"{name}: the about line is long ({len(hd['about'])} characters)")
    bid = hd.get("id", "")
    if bid and not re.fullmatch(r"[a-z][a-z0-9_]*", bid):
        bad(f"id {bid!r} must be lower_case words")
    if hd.get("light") and hd["light"] not in LIGHTS:
        bad(f"light {hd['light']!r} is not one of {', '.join(LIGHTS)}")
    if len(spec["grid"]) != H:
        bad(f"the grid has {len(spec['grid'])} rows, not {H}")
        return None, problems, warnings

    grid = spec["grid"]
    legend = spec["legend"]
    for y, row in enumerate(grid, 1):
        for x, ch in enumerate(row, 1):
            if ch not in (FLOOR, OUTSIDE) and ch not in legend:
                bad(f"square {x},{y}: {ch!r} isn't in the legend")
    for ch, lg in legend.items():
        if lg["kind"] not in kit:
            bad(f"legend {ch!r}: no kind {lg['kind']!r} in the kit")
        elif not kit[lg["kind"]].get("kit", True):
            warnings.append(f"{name}: {lg['kind']} isn't in game/data/props.lua yet (using its expected footprint)")
    for pc in spec["pieces"]:
        if pc["kind"] not in kit:
            bad(f"piece line {pc['line']}: no kind {pc['kind']!r} in the kit")
        elif not kit[pc["kind"]].get("kit", True):
            warnings.append(f"{name}: {pc['kind']} isn't in game/data/props.lua yet (using its expected footprint)")
    if problems:
        return None, problems, warnings

    # Which squares are open floor (for turning wall pieces): anything not outside and not a wall-like piece.
    grid_open = [[(ch != OUTSIDE and not (ch in legend and (WALL_LIKE.match(legend[ch]["kind"]) or
                                                             legend[ch]["kind"] == "wall_diag")))
                  for ch in row] for row in grid]

    # Grid squares -> pieces: a block of one character is tiled from its north-west corner in reading order.
    pieces = []
    used = [[False] * W for _ in range(H)]
    for y in range(1, H + 1):
        for x in range(1, W + 1):
            ch = grid[y - 1][x - 1]
            if ch in (FLOOR, OUTSIDE) or used[y - 1][x - 1]:
                continue
            lg = legend[ch]
            k = kit[lg["kind"]]
            r = lg["turn"]
            if r == "auto":
                if (k["fw"], k["fh"]) != (1, 1):
                    bad(f"legend {ch!r}: turn auto is for one-square pieces")
                    return None, problems, warnings
                r = _auto_turn(lg["kind"], x, y, grid_open)
            w, h = footprint(k, r)
            ok = True
            for dy in range(h):
                for dx in range(w):
                    cx, cy = x + dx, y + dy
                    if not (1 <= cx <= W and 1 <= cy <= H) or grid[cy - 1][cx - 1] != ch or used[cy - 1][cx - 1]:
                        ok = False
            if not ok:
                bad(f"square {x},{y}: {ch!r} ({lg['kind']}, {w}x{h}) doesn't fill a whole {w}x{h} block there")
                continue
            for dy in range(h):
                for dx in range(w):
                    used[y + dy - 1][x + dx - 1] = True
            pieces.append(dict(feature=lg["feature"], kind=lg["kind"], x=x, y=y, r=r, src=f"grid {ch!r} at {x},{y}"))
    for pc in spec["pieces"]:
        pieces.append(dict(feature=pc["feature"], kind=pc["kind"], x=pc["x"], y=pc["y"], r=pc["r"],
                           src=f"piece line {pc['line']}"))

    # Squares: on the mat, what blocks, overlaps.
    blocked, taken = set(), {}
    clear, doors = set(), set()
    for pc in pieces:
        k = kit[pc["kind"]]
        sq = squares(k, pc["x"], pc["y"], pc["r"])
        off = [(a, b) for a, b, _ in sq if not (1 <= a <= W and 1 <= b <= H)]
        if off:
            bad(f"{pc['kind']} ({pc['src']}) runs off the mat at {off[0][0]},{off[0][1]}")
        for a, b, blk in sq:
            if not (1 <= a <= W and 1 <= b <= H):
                continue
            if k.get("door"):
                doors.add((a, b))
            if k.get("clear"):
                clear.add((a, b))
            elif blk:
                blocked.add((a, b))
            if not is_ground(k):
                if (a, b) in taken:
                    bad(f"{pc['kind']} ({pc['src']}) and {taken[(a, b)]} both stand on {a},{b}")
                taken[(a, b)] = f"{pc['kind']} ({pc['src']})"
    blocked -= clear
    outside = {(x, y) for y in range(1, H + 1) for x in range(1, W + 1) if grid[y - 1][x - 1] == OUTSIDE}

    # Features, in the order the DM sets them down: the features section first, then the rest by first use.
    meta = {f["id"]: f for f in spec["features"]}
    order = [f["id"] for f in spec["features"]]
    for pc in pieces:
        if pc["feature"] not in order:
            order.append(pc["feature"])
    by_feat = {}
    for pc in pieces:
        by_feat.setdefault(pc["feature"], []).append(pc)
    features = []
    for fid in order:
        if not re.fullmatch(r"[a-z][a-z0-9_]*", fid):
            bad(f"feature id {fid!r} must be lower_case words")
        pcs = by_feat.get(fid)
        if not pcs:
            bad(f"feature {fid!r} has no pieces")
            continue
        m = meta.get(fid, {})
        parts = []
        for pc in pcs:
            if parts and parts[-1]["kind"] == pc["kind"]:
                parts[-1]["at"].append((pc["x"], pc["y"], pc["r"]))
            else:
                same = [p for p in parts if p["kind"] == pc["kind"]]
                if same:
                    same[0]["at"].append((pc["x"], pc["y"], pc["r"]))
                else:
                    parts.append(dict(kind=pc["kind"], at=[(pc["x"], pc["y"], pc["r"])]))
        f = dict(id=fid, parts=parts, base=m.get("base", False), own_words=m.get("own_words", False),
                 words=m.get("words", []), say=m.get("say"))
        words = list(f["words"]) + ([] if f["own_words"] else list(kit[parts[0]["kind"]].get("words", [])))
        if not words:
            bad(f"feature {fid!r} has no words the DM could mention it by")
        features.append(f)
    if not any(f["base"] for f in features):
        bad("nothing goes down with the place (mark the floor or the walls 'base')")

    # Starts.
    starts = {}
    for who in ("party", "foes", "npc"):
        if not hd.get(who):
            bad(f"no {who}: start")
            continue
        try:
            starts[who] = _xy(hd[who], f"{who}:")
        except SpecError as e:
            bad(str(e))
            continue
    for who, at in list(starts.items()) + [("npc_at " + k, v) for k, v in spec["npc_at"].items()]:
        x, y = at
        if not (1 <= x <= W and 1 <= y <= H):
            bad(f"the {who} start {x},{y} is off the mat")
        elif (x, y) in blocked or (x, y) in taken:
            bad(f"the {who} start {x},{y} is under scenery ({taken.get((x, y), 'a piece')})")
        elif (x, y) in outside:
            bad(f"the {who} start {x},{y} is outside the room")
        elif who in ("party", "foes"):
            room = sum(1 for dx in (-1, 0, 1) for dy in (-1, 0, 1)
                       if 1 <= x + dx <= W and 1 <= y + dy <= H and (x + dx, y + dy) not in blocked)
            if room < 5:
                bad(f"the {who} start {x},{y} is boxed in ({room} free squares around it)")

    # Who can walk where (eight ways, as the battle rules move). A shut door holds the party back
    # from the foes (as tools/tests/board_check.lua has it), but it opens: what's behind it is
    # still in the room.
    def reach(start, through_doors=False):
        wall = blocked - doors if through_doors else blocked
        seen, queue = {start}, [start]
        while queue:
            cx, cy = queue.pop()
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    nx, ny = cx + dx, cy + dy
                    if (dx or dy) and 1 <= nx <= W and 1 <= ny <= H and (nx, ny) not in wall and (nx, ny) not in seen:
                        seen.add((nx, ny))
                        queue.append((nx, ny))
        return seen

    walk = set()
    if "party" in starts and starts["party"] not in blocked:
        if "foes" in starts and starts["foes"] not in reach(starts["party"]):
            bad("the party can't reach the foes")
        walk = reach(starts["party"], through_doors=True)
        leak = sorted(walk & outside)
        if leak:
            bad(f"the party can walk outside the room (at {leak[0][0]},{leak[0][1]}"
                f"{' and ' + str(len(leak) - 1) + ' more' if len(leak) > 1 else ''}): close the walls")
    free = W * H - len(blocked) - len(outside - blocked)
    tight = hd.get("tight", "").lower() in ("yes", "true", "1")
    if free < (0.35 if tight else 0.6) * W * H:
        bad(f"only {free} free squares{'' if tight else ' (a cramped room can say tight: yes)'}")

    # Spots: the places worth going to.
    spots = []
    keys, at_sq = set(), {}
    for s in spec["spots"]:
        x, y = s["x"], s["y"]
        tag = f"spot {s['key']} ({x},{y})"
        if s["key"] in keys:
            bad(f"{tag}: the key is used twice")
        keys.add(s["key"])
        if not (1 <= x <= W and 1 <= y <= H):
            bad(f"{tag}: off the mat")
            continue
        if (x, y) in blocked or (x, y) in taken:
            bad(f"{tag}: on a square that's taken ({taken.get((x, y), 'blocked')})")
        if (x, y) in outside:
            bad(f"{tag}: outside the room")
        if walk and (x, y) not in walk and (x, y) not in blocked:
            bad(f"{tag}: the party can't walk there")
        if (x, y) in at_sq:
            bad(f"{tag}: the same square as spot {at_sq[(x, y)]}")
        at_sq[(x, y)] = s["key"]
        if len(s["line"]) > 160:
            warnings.append(f"{name}: {tag}: the line is long ({len(s['line'])} characters)")
        near = []
        for f in features:
            for p in f["parts"]:
                k = kit[p["kind"]]
                if is_ground(k) and (f["base"] or k["fw"] * k["fh"] > 4):
                    continue                     # the floor and the paths are beside everything
                for (px, py, pr) in p["at"]:
                    if any(max(abs(a - x), abs(b - y)) <= 1 for a, b, _ in squares(k, px, py, pr)):
                        if f["id"] not in near:
                            near.append(f["id"])
        spots.append(dict(id=s["key"], x=x, y=y, name=s["name"], line=s["line"], near=near))
    if len(spots) < 3:
        warnings.append(f"{name}: only {len(spots)} spots (give a room a handful)")

    tags = [t.strip() for t in hd.get("tags", "").split(",") if t.strip()]
    order_n = int(hd["order"]) if hd.get("order", "").isdigit() else 999
    if hd.get("room") and not re.fullmatch(r"[a-z][a-z0-9_]*", hd["room"]):
        bad(f"room {hd['room']!r} must be lower_case words (the adventure's own id for the room)")
    board = dict(id=bid, title=hd.get("title"), light=hd.get("light"), adventure=hd.get("adventure"), room=hd.get("room"),
                 source=hd.get("source"), credit=hd.get("credit"), about=hd.get("about"), tags=tags, order=order_n, tight=tight,
                 party=starts.get("party"), foes=starts.get("foes"), npc=starts.get("npc"),
                 npc_at=dict(spec["npc_at"]), features=features, spots=spots,
                 blocked=blocked, outside=outside, pieces=pieces)
    return board, problems, warnings


# ------------------------------------------------------------------ writing Lua

def lua_str(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def _at(at, indent=""):
    items = [f"{{ {x}, {y}, {r} }}" for x, y, r in at]
    if len(items) <= 10:
        return "{ " + ", ".join(items) + " }"
    rows = [", ".join(items[i:i + 10]) for i in range(0, len(items), 10)]
    return "{\n" + ",\n".join(indent + "    " + r for r in rows) + ",\n" + indent + "}"


def board_lua(b, indent="    "):
    i1, i2, i3 = indent, indent * 2, indent * 3
    out = [f"{i1}{b['id']} = {{"]
    head = f"{i2}title = {lua_str(b['title'])}, light = {lua_str(b['light'])},"
    if b.get("tight"):
        head += " tight = true,"
    out.append(head)
    out.append(f"{i2}adventure = {lua_str(b['adventure'])}, order = {b['order']},"
               + (f" room = {lua_str(b['room'])}," if b.get("room") else ""))
    out.append(f"{i2}source = {lua_str(b['source'])}, credit = {lua_str(b['credit'])},")
    out.append(f"{i2}about = {lua_str(b['about'])},")
    out.append(f"{i2}tags = {{ " + ", ".join(lua_str(t) for t in b["tags"]) + " },")
    out.append(f"{i2}party = {{ {b['party'][0]}, {b['party'][1]} }}, npc = {{ {b['npc'][0]}, {b['npc'][1]} }}, "
               f"foes = {{ {b['foes'][0]}, {b['foes'][1]} }},")
    if b["npc_at"]:
        out.append(f"{i2}npc_at = {{ " + ", ".join(f"{k} = {{ {v[0]}, {v[1]} }}" for k, v in sorted(b["npc_at"].items()))
                   + " },")
    out.append(f"{i2}features = {{")
    for f in b["features"]:
        if len(f["parts"]) == 1:
            p = f["parts"][0]
            s = f"{i3}{{ id = {lua_str(f['id'])}, kind = {lua_str(p['kind'])}, at = {_at(p['at'], i3)}"
        else:
            parts = ", ".join(f"{{ kind = {lua_str(p['kind'])}, at = {_at(p['at'], i3)} }}" for p in f["parts"])
            s = f"{i3}{{ id = {lua_str(f['id'])}, parts = {{ {parts} }}"
        if f["base"]:
            s += ", base = true"
        if f["words"]:
            s += ", words = { " + ", ".join(lua_str(w) for w in f["words"]) + " }"
        if f["own_words"]:
            s += ", own_words = true"
        if f["say"]:
            s += f", say = {lua_str(f['say'])}"
        out.append(s + " },")
    out.append(f"{i2}}},")
    out.append(f"{i2}places = {{")
    for s in b["spots"]:
        near = "{ " + ", ".join(lua_str(n) for n in s["near"]) + " }" if s["near"] else "{}"
        out.append(f"{i3}{{ id = {lua_str(s['id'])}, x = {s['x']}, y = {s['y']}, name = {lua_str(s['name'])}, near = {near},")
        out.append(f"{i3}  line = {lua_str(s['line'])} }},")
    out.append(f"{i2}}},")
    out.append(f"{i1}}},")
    return "\n".join(out)


def foreign_words():
    """The Silent Bells words that mustn't show while the museum runs (game/model/adventure.lua)."""
    p = os.path.join(ROOT, "game", "model", "adventure.lua")
    if not os.path.exists(p):
        return []
    src = open(p, encoding="utf-8").read()
    m = re.search(r"M\.FOREIGN = \{(.*?)\}", src, re.S)
    return [w.replace("%-", "-") for w in re.findall(r"\"([^\"]+)\"", m.group(1))] if m else []


def board_ids_in_boards_lua():
    if not os.path.exists(BOARDS):
        return set()
    return set(re.findall(r"^B\.(\w+) = \{", open(BOARDS, encoding="utf-8").read(), re.M))
