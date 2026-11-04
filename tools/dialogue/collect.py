#!/usr/bin/env python3
"""Gather the Dialogue Desk's saved edits into one list for apply.py.

The desk keeps each edit as a document in its "edits" collection. Claude reads that collection
into a folder (one JSON file per edit), and this script merges the ones still waiting:
    python3 tools/dialogue/collect.py <folder> edits.json
    python3 tools/dialogue/apply.py edits.json --check
    python3 tools/dialogue/apply.py edits.json
It prints the document ids it gathered, so the applied ones can be marked "applied" on the desk.
"""
import json
import os
import sys


def body(doc):
    # A saved file may hold the document's fields directly, or wrapped with its id and version.
    if isinstance(doc, dict) and "file" in doc and "old" in doc:
        return doc
    for k in ("data", "document", "fields"):
        if isinstance(doc, dict) and isinstance(doc.get(k), dict):
            return body(doc[k])
    return None


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    folder, out = sys.argv[1], sys.argv[2]
    edits, ids = [], []
    for root, _, files in os.walk(folder):
        for name in sorted(files):
            if not name.endswith(".json"):
                continue
            with open(os.path.join(root, name), encoding="utf-8") as f:
                e = body(json.load(f))
            if not e or e.get("status") == "applied":
                continue
            edits.append({k: e.get(k) for k in ("file", "path", "old", "new", "note")})
            ids.append(name[:-5])
    with open(out, "w", encoding="utf-8") as f:
        json.dump({"edits": edits}, f, ensure_ascii=False, indent=1)
    print("dialogue edits gathered: %d -> %s" % (len(edits), out))
    for i, e in zip(ids, edits):
        print("  %s  %s: %r" % (i, e["file"], (e["new"] or "")[:70]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
