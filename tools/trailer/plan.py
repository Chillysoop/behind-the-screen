"""Write the 40-second trailer's cut list: python3 tools/trailer/plan.py OUT_DIR/plan.json

Each shot is placed on the music's grid (128 BPM, a bar is 1.875 s) by where it starts in the
trailer; its length is the gap to the next one, rounded to whole frames so the cuts stay on the beat.
`at` is seconds into a recording made by tools/trailer/record.sh (rec3: the trailer-paced take at 15
fps; rec1: an earlier take at the game's own pace, recorded at 30 fps, used for the unspoiled opening
and a clear Insight read). The recordings live next to the plan, with music.wav (music.py) and
titles/ (titles.py).
"""
import json
import os
import sys

BAR = 4 * 60.0 / 128
FPS = 30
R1 = {"src": "rec1.mkv", "rec_fps": 30}
R3 = {"src": "rec3/rec.mkv", "rec_fps": 15}


def T(png, t_in=0.08, t_out=None):
    return {"png": "titles/" + png + ".png", "in": t_in, "out": t_out}


# (start in the trailer, source, fields). A shot runs until the next one starts.
CUTS = [
    # Open: the table, from across the room, then in to the game.
    (0 * BAR, R1, {"at": 300.0, "zoom": [1.0, 1.12], "focus": [0.5, 0.42], "texts": [T("four_friends")]}),
    (1 * BAR, R1, {"at": 321.5, "zoom": [1.0, 1.04], "texts": [T("one_table")]}),
    # Build: you're the one behind the screen; the prep, and the story bent around them.
    (2 * BAR, R3, {"at": 155.0, "zoom": [1.15, 1.0], "focus": [0.5, 0.6], "texts": [T("you_run_it")], "flash": True}),
    (3 * BAR, R1, {"at": 67.0, "zoom": [1.0, 1.12], "focus": [0.45, 0.45], "texts": [T("plan")]}),
    (4 * BAR, R3, {"at": 70.0, "zoom": [1.0, 1.12], "focus": [0.4, 0.45], "texts": [T("bend")]}),
    (5 * BAR, R3, {"at": 245.0, "zoom": [1.0, 1.06]}),
    # Drive: room after room, and the calls in them.
    (6 * BAR, R3, {"at": 1545.0, "zoom": [1.0, 1.1], "focus": [0.5, 0.45], "texts": [T("run_rooms")], "flash": True}),
    (7 * BAR, R3, {"at": 318.0, "zoom": [1.05, 1.12], "focus": [0.5, 0.5]}),
    (7.5 * BAR, R3, {"at": 588.0, "zoom": [1.0, 1.06]}),
    (8 * BAR, R3, {"at": 1898.0, "zoom": [1.05, 1.22], "focus": [0.62, 0.45], "texts": [T("make_call")]}),
    (9 * BAR, R3, {"at": 505.5, "zoom": [1.0, 1.1], "focus": [0.45, 0.5]}),
    # Combat.
    (10 * BAR, R3, {"at": 1754.5, "zoom": [1.0, 1.15], "focus": [0.5, 0.5], "texts": [T("initiative")], "flash": True}),
    (11 * BAR, R3, {"at": 760.0, "zoom": [1.35, 1.45], "focus": [0.5, 0.5]}),
    (11.5 * BAR, R3, {"at": 1830.0, "zoom": [1.35, 1.45], "focus": [0.5, 0.5]}),
    (12 * BAR, R3, {"at": 397.5, "zoom": [1.05, 1.18], "focus": [0.65, 0.42]}),
    # Read: the people at the table.
    (13 * BAR, R1, {"at": 1101.0, "zoom": [1.25, 1.45], "focus": [0.2, 0.52], "texts": [T("read")], "flash": True}),
    (14 * BAR, R3, {"at": 139.3, "zoom": [1.2, 1.3], "focus": [0.82, 0.4]}),
    (15 * BAR, R3, {"at": 2002.0, "zoom": [1.0, 1.1], "focus": [0.55, 0.45]}),
    (16 * BAR, R3, {"at": 608.0, "zoom": [1.0, 1.08], "focus": [0.4, 0.55], "texts": [T("want")]}),
    # Rise: both halves.
    (17 * BAR, R3, {"at": 2023.5, "zoom": [1.0, 1.1], "focus": [0.5, 0.45], "texts": [T("play")], "flash": True}),
    # (In close on the friends, so the card beside them is out of the shot and the title has room.)
    (18 * BAR, R3, {"at": 811.5, "zoom": [1.38, 1.5], "focus": [0.33, 0.42], "texts": [T("run_table")], "dip": True}),
    # A breath, then the title on the hit.
    (35.45, None, {"image": "titles/black.png"}),
    (35.62, None, {"image": "titles/end_bg.png", "zoom": [1.0, 1.04], "flash": True, "fade_out": 0.7,
                   "layers": [{"png": "titles/end_title.png", "in": 0.0, "slam": True},
                              {"png": "titles/end_tag.png", "in": 1.1},
                              {"png": "titles/end_small.png", "in": 1.9}]}),
]
END = 40.0


def main():
    out = sys.argv[1]
    shots = []
    for i, (start, src, fields) in enumerate(CUTS):
        nxt = CUTS[i + 1][0] if i + 1 < len(CUTS) else END
        frames = round(nxt * FPS) - round(start * FPS)
        shot = dict(src or {})
        shot.update(fields)
        shot["len"] = frames / FPS
        for t in shot.get("texts", []):
            if t["out"] is None:
                t["out"] = max(t["in"] + 0.3, shot["len"] - 0.2)
        shots.append(shot)
    plan = {"music": "music.wav", "out": "behind_the_screen_trailer.mp4", "shots": shots}
    with open(out, "w") as f:
        json.dump(plan, f, indent=1)
    print(len(shots), "shots,", sum(s["len"] for s in shots), "s")


if __name__ == "__main__":
    main()
