"""Group the rows tools/sim/provenance.lua wrote by the code that produced them.

    python3 tools/sim/provenance_report.py OUT_DIR/*.tsv > report.txt

For each source (file:function:line, and who called it), how many lines it said and up to five
different examples, biggest first. Numbers are folded so combat rolls group together.
"""
import collections
import re
import sys

by_src = collections.defaultdict(collections.Counter)
for path in sys.argv[1:]:
    for row in open(path, encoding="utf-8", errors="replace"):
        parts = row.rstrip("\n").split("\t")
        if len(parts) < 4:
            continue
        week, kind, src, text = parts[0], parts[1], parts[2], parts[3]
        first = src.split(" < ")[0]
        key = first + "   (" + kind.split(":")[0] + ")"
        by_src[key][re.sub(r"\d+", "#", text)] += 1

order = sorted(by_src.items(), key=lambda kv: -sum(kv[1].values()))
for key, texts in order:
    total = sum(texts.values())
    print(f"== {key}  x{total}  ({len(texts)} different)")
    for t, n in texts.most_common(5):
        print(f"   {n:4d}  {t[:220]}")
