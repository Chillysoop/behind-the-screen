"""Fold review decisions saved outside the project back into lines.json.

When the game can't find the project folder (a build run from somewhere else),
the review mode saves decisions to dialogue_overrides.json in the game's save
folder instead. This applies them to game/data/dialogue/lines.json and renames
the overrides file so it isn't applied twice.

    python3 tools/dialogue/merge_overrides.py                 # the default save folder
    python3 tools/dialogue/merge_overrides.py path/to/dialogue_overrides.json
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import generate  # noqa: E402  (shares the library format)


def default_path():
    """Where Defold's sys.get_save_file puts it on this system."""
    if os.name == "nt":
        return os.path.join(os.environ.get("APPDATA", ""), "behind_the_screen", "dialogue_overrides.json")
    if sys.platform == "darwin":
        return os.path.expanduser("~/Library/Application Support/behind_the_screen/dialogue_overrides.json")
    return os.path.expanduser("~/.behind_the_screen/dialogue_overrides.json")


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else default_path()
    if not os.path.exists(path):
        raise SystemExit(f"No overrides file at {path}. Nothing to merge.")
    with open(path, encoding="utf-8") as f:
        overrides = json.load(f).get("lines", {})
    lib = generate.Library()
    by_id = {l["id"]: l for l in lib.lines}
    changed, missing = 0, 0
    for line_id, o in overrides.items():
        l = by_id.get(line_id)
        if not l:
            missing += 1
            continue
        if o.get("text") and o["text"] != l["text"]:
            l.setdefault("orig", l["text"])
            l["text"] = o["text"]
        if o.get("status"):
            l["status"] = o["status"]
        changed += 1
    generate.save_lines(lib.lines)
    os.replace(path, path + ".merged")
    print(f"merged {changed} decisions into lines.json ({missing} for lines that no longer exist)")


if __name__ == "__main__":
    main()
