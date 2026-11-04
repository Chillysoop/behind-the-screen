#!/usr/bin/env python3
"""Which of the Dialogue Desk's lines were seen in play (the other half of reach.lua).

Reads the export (dialogue.json), the text the table saw (reach.lua's .text files and the smoke
test's transcripts), and the dialogue picks (.picks), and marks each line seen or not. A line with
fill-ins ({actor_char}) counts as seen when its fixed words turn up in that order in one piece of
text. Prints the unseen lines grouped by file and the first part of their place in the data, so a
person can tell a rare line from one the adventure never uses.
    python3 tools/dialogue/reach_match.py dialogue.json out.json <text or picks files...>
"""
import collections
import json
import re
import sys

FILL = re.compile(r"\{[A-Za-z_]+\}")


def main():
    if len(sys.argv) < 4:
        print(__doc__)
        return 2
    export = json.load(open(sys.argv[1], encoding="utf-8"))
    texts, picked, triggers = [], set(), collections.Counter()
    for path in sys.argv[3:]:
        with open(path, encoding="utf-8", errors="replace") as f:
            if path.endswith(".picks"):
                for row in f:
                    parts = row.rstrip("\n").split("\t")
                    if len(parts) == 3:
                        triggers[(parts[0], parts[1])] += 1
                        if parts[2] != "-":
                            picked.add(parts[2])
            else:
                texts.extend(line.strip().lower() for line in f)
    big = "\n".join(sorted(set(texts)))
    seen = {}
    for l in export["lines"]:
        t = l["text"].lower().strip()
        lid = l["path"][1] if l["file"].endswith("lines.json") else None
        if lid and lid in picked:
            seen[l["id"]] = True
            continue
        parts = [p.strip() for p in FILL.split(t)]
        parts = [p for p in parts if p]
        if not parts:
            seen[l["id"]] = False
            continue
        longest = max(parts, key=len)
        if longest not in big:
            seen[l["id"]] = False
            continue
        if len(parts) == 1:
            seen[l["id"]] = True
            continue
        rx = re.compile(".{0,80}?".join(re.escape(p) for p in parts))
        seen[l["id"]] = rx.search(big) is not None
    out = {"seen": seen, "triggers": {"%s|%s" % k: n for k, n in triggers.items()}}
    json.dump(out, open(sys.argv[2], "w"), indent=0)
    by = collections.defaultdict(lambda: [0, 0])
    for l in export["lines"]:
        key = (l["group"], str(l["path"][0]))
        by[key][0 if seen[l["id"]] else 1] += 1
    print("lines seen in play: %d of %d" % (sum(1 for v in seen.values() if v), len(seen)))
    for (g, p), (s, u) in sorted(by.items()):
        print("  %-22s %-28s seen %4d  unseen %4d" % (g, p[:28], s, u))
    return 0


if __name__ == "__main__":
    sys.exit(main())
