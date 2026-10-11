"""Click every game-night card with real X input and check each click lands (the fix pass, A1).

The game runs with tools/tests/ui_play/ui_play.ini: autotest mode 5 drives every screen
except the cards, and the input trace (game/ui/input_trace.lua) logs each card with where
its buttons are, each mouse press the engine saw and what it hit, and each answer. For every
card this script clicks a random point inside a random option, the way a person would, and
waits for the answer. A click that doesn't land is sorted by cause:

  dropped   the engine never saw the press (a frame stall swallowed it)
  missed    the press arrived but hit another button or nothing
  ignored   the press hit the right button and the card still didn't answer

    python3 drive.py --home HOME_DIR [--cards 200] [--hold 0.1] [--shots DIR]

Prints one line per card and a summary; exits 1 if any click was ignored or missed (and, with
--strict, if any was dropped).
"""
import argparse, os, random, subprocess, sys, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from xinput import X  # noqa: E402


def find(home, name):
    # The save folder is hidden (~/.behind_the_screen or ~/.local/share/...), which glob skips.
    for root, _dirs, files in os.walk(home):
        if name in files:
            return os.path.join(root, name)
    return None


class Trace:
    def __init__(self, home):
        self.home, self.path, self.pos, self.lines = home, None, 0, []

    def poll(self):
        if not self.path:
            self.path = find(self.home, "input_trace.log")
            if not self.path:
                return []
        with open(self.path, "r", errors="replace") as f:
            f.seek(self.pos)
            text = f.read()
            self.pos = f.tell()
        new = []
        for raw in text.splitlines():
            parts = raw.split(" ", 3)
            if len(parts) < 3:
                continue
            new.append({"t": float(parts[0]), "frame": int(parts[1]), "event": parts[2],
                        "rest": parts[3] if len(parts) > 3 else ""})
        self.lines += new
        return new


def parse_card(rest):
    seq, kind, buttons = (rest.split(" ", 2) + ["", ""])[:3]
    out = []
    for item in buttons.split(";"):
        bits = item.split("|")
        if len(bits) == 5:
            out.append({"label": bits[0], "x": int(bits[1]), "y": int(bits[2]), "w": int(bits[3]), "h": int(bits[4])})
    return int(seq), kind, out


def done(home):
    log = find(home, "autotest.log")
    if not log:
        return None
    with open(log, errors="replace") as f:
        text = f.read()
    if "AUTOTEST done" in text:
        return "done"
    if "AUTOTEST FAILED" in text:
        return "failed"
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--home", required=True, help="the HOME the game runs with (its save folder is under it)")
    ap.add_argument("--cards", type=int, default=200)
    ap.add_argument("--hold", type=float, default=0.1, help="seconds the button is held, like a person (0.1)")
    ap.add_argument("--wait", type=float, default=12.0, help="seconds to wait for a click to land")
    ap.add_argument("--tries", type=int, default=4)
    ap.add_argument("--scale", type=float, default=1.0, help="window pixels per layout pixel (1600x900 layout)")
    ap.add_argument("--shots", default=None)
    ap.add_argument("--strict", action="store_true", help="count dropped clicks as failures too")
    ap.add_argument("--max-minutes", type=float, default=240)
    a = ap.parse_args()
    x = X()
    tr = Trace(a.home)
    rnd = random.Random(7)
    stats = {"cards": 0, "clicks": 0, "landed": 0, "dropped": 0, "missed": 0, "ignored": 0}
    card = None
    start = time.time()
    if a.shots:
        os.makedirs(a.shots, exist_ok=True)

    def shot(name):
        if a.shots:
            subprocess.run(["import", "-display", os.environ.get("DISPLAY", ":91"), "-window", "root",
                            os.path.join(a.shots, name + ".png")], capture_output=True)

    while stats["cards"] < a.cards and time.time() - start < a.max_minutes * 60:
        for ln in tr.poll():
            if ln["event"] == "card":
                card = parse_card(ln["rest"])
        state = done(a.home)
        if state:
            print("game finished (" + state + ")")
            break
        if not card:
            time.sleep(0.5)
            continue
        seq, kind, buttons = card
        card = None
        if not buttons:
            continue
        # Improv: Play only lists once a card is picked (the trace lists enabled buttons), so
        # click a hand card first; its redraw comes back as a new card line with Play in it.
        if kind == "improv":
            play = [b for b in buttons if b["label"].startswith("Play")]
            hand = [b for b in buttons if b["label"].startswith("[improv_card_")]
            target = play[0] if play else (rnd.choice(hand) if hand else buttons[0])
        else:
            target = rnd.choice(buttons)
        landed = False
        for attempt in range(1, a.tries + 1):
            px = target["x"] + rnd.uniform(6, max(7, target["w"] - 6))
            py = target["y"] + rnd.uniform(6, max(7, target["h"] - 6))
            sx, sy = int(px * a.scale), int(py * a.scale)
            mark = len(tr.lines)
            x.move(sx - 4, sy)
            time.sleep(0.25)
            x.move(sx, sy)
            time.sleep(0.25)
            x.click(sx, sy, hold=a.hold)
            stats["clicks"] += 1
            t0 = time.time()
            seen_press, outcome = None, None
            while time.time() - t0 < a.wait:
                tr.poll()
                for ln in tr.lines[mark:]:
                    if ln["event"] == "press" and seen_press is None:
                        seen_press = ln["rest"]
                    if ln["event"] in ("answer", "card"):
                        outcome = ln
                        break
                if outcome:
                    break
                time.sleep(0.2)
            if outcome:
                landed = True
                stats["landed"] += 1
                if outcome["event"] == "card":
                    card = parse_card(outcome["rest"])
                print("card %d %-10s %-34s landed on try %d" % (seq, kind, target["label"][:34], attempt))
                break
            if seen_press is None:
                why = "dropped"
            elif ("hit=" + target["label"]) in seen_press:
                why = "ignored"
            else:
                why = "missed"
            stats[why] += 1
            print("card %d %-10s %-34s %s (press: %s)" % (seq, kind, target["label"][:34], why, seen_press))
            shot("card%03d_%s_try%d" % (seq, why, attempt))
        if kind != "improv" or target["label"].startswith("Play"):
            stats["cards"] += 1
        if not landed:
            print("card %d never took a click; stopping" % seq)
            break
    print("SUMMARY " + " ".join("%s=%d" % kv for kv in stats.items()))
    bad = stats["ignored"] + stats["missed"] + (stats["dropped"] if a.strict else 0)
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
