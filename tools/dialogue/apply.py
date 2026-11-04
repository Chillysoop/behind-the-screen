#!/usr/bin/env python3
"""Write dialogue edits back into the game's data files (the dialogue review page's other half).

The page (tools/dialogue/export.lua makes its data) collects edits as a JSON list:
    [{"file": "game/data/museum/module.lua", "path": [...], "old": "line as it was", "new": "line as it should be"}, ...]
Each edit is applied only where the old line appears exactly once in its file, as a string literal
(Lua's "..." with escapes, or JSON's). Anything else is reported and left alone, so nothing is ever
guessed. Run from the project root:
    python3 tools/dialogue/apply.py edits.json            # apply
    python3 tools/dialogue/apply.py edits.json --check    # report only
"""
import json
import sys


def lua_lit(s):
    out = s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
    return '"' + out + '"'


def json_lit(s):
    return json.dumps(s, ensure_ascii=False)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    check = "--check" in sys.argv
    edits = json.load(open(sys.argv[1], encoding="utf-8"))
    if isinstance(edits, dict):
        edits = edits.get("edits", [])
    by_file = {}
    for e in edits:
        by_file.setdefault(e["file"], []).append(e)
    applied, skipped = 0, []
    for path, es in sorted(by_file.items()):
        try:
            src = open(path, encoding="utf-8").read()
        except OSError as err:
            skipped.extend((e, "can't open the file: %s" % err) for e in es)
            continue
        lit = json_lit if path.endswith(".json") else lua_lit
        changed = src
        for e in es:
            old, new = e.get("old"), e.get("new")
            if old is None or new is None or old == new:
                skipped.append((e, "nothing to change"))
                continue
            a, b = lit(old), lit(new)
            n = changed.count(a)
            if n == 0:
                skipped.append((e, "the old line isn't in the file any more (edited since the export?)"))
            elif n > 1:
                skipped.append((e, "the old line appears %d times in the file: edit it there by hand" % n))
            else:
                changed = changed.replace(a, b)
                applied += 1
        if changed != src and not check:
            open(path, "w", encoding="utf-8").write(changed)
    print("dialogue edits: %d applied%s, %d skipped" % (applied, " (check only)" if check else "", len(skipped)))
    for e, why in skipped:
        print("  SKIPPED %s: %r -- %s" % (e.get("file"), (e.get("old") or "")[:70], why))
    return 0 if not skipped else 1


if __name__ == "__main__":
    sys.exit(main())
