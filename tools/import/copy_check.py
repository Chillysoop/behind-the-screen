"""Our words, never the book's (the importer's contract; docs/design/adventure-standard.md). Two checks of an
adventure's data against a book the reader has, run here and never stored in the repo:

    python3 tools/import/copy_check.py ADVENTURE_ID --book BOOK.txt|INGEST_DIR [--run 8]
        the copy check: no run of RUN words or more in the adventure's data (every string in game/data/<id>/ and
        its maps) matches the book's text. A match is a line to rewrite in our own words.
    python3 tools/import/copy_check.py ADVENTURE_ID --names NAMES.txt [--allow WORD,...]
        the originality check, for an adventure written as a shape of another book (Banners of Honour for the long
        campaign): none of that book's names (ingest.py's names.txt) appear in our data.

Exit 1 on any finding.
"""
import argparse
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def words(text):
    return re.findall(r"[a-z0-9']+", text.lower().replace("’", "'"))


def lua_strings(path):
    s = open(path, encoding="utf-8", errors="ignore").read()
    s = re.sub(r"--\[\[.*?\]\]", " ", s, flags=re.S)
    out = []
    for m in re.finditer(r'"((?:[^"\\\n]|\\.)*)"|\[\[(.*?)\]\]', s, flags=re.S):
        t = m.group(1) if m.group(1) is not None else m.group(2)
        if t and " " in t:
            line = s.count("\n", 0, m.start()) + 1
            out.append((line, t))
    return out


def data_files(adv):
    files = sorted(glob.glob(os.path.join(ROOT, "game", "data", adv, "*.lua")))
    files += sorted(glob.glob(os.path.join(ROOT, "game", "data", "maps", adv + "_*.map")))
    return files


def book_text(path):
    if os.path.isdir(path):
        parts = []
        for f in sorted(glob.glob(os.path.join(path, "pages", "*.txt"))):
            parts.append(open(f, encoding="utf-8", errors="ignore").read())
        return "\n".join(parts)
    return open(path, encoding="utf-8", errors="ignore").read()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("adventure")
    ap.add_argument("--book")
    ap.add_argument("--names")
    ap.add_argument("--run", type=int, default=8)
    ap.add_argument("--allow", default="")
    a = ap.parse_args()
    files = data_files(a.adventure)
    if not files:
        sys.exit("no data for adventure %r" % a.adventure)
    found = []
    if a.book:
        bw = words(book_text(a.book))
        n = a.run
        grams = set(tuple(bw[i:i + n]) for i in range(len(bw) - n + 1))
        for f in files:
            strings = lua_strings(f) if f.endswith(".lua") else [(i + 1, l) for i, l in enumerate(open(f).read().split("\n"))]
            for line, t in strings:
                w = words(t)
                caps = [x for x in re.findall(r"[A-Za-z0-9']+", t.replace("\u2019", "'"))]
                for i in range(len(w) - n + 1):
                    if tuple(w[i:i + n]) in grams:
                        j = i + n
                        while j < len(w) and tuple(w[j - n + 1:j + 1]) in grams:
                            j += 1
                        # (A title is a name, not prose: most of its words capitalised, "The Neverwinter
                        # University Press Guide to Primeval Creatures".)
                        run = caps[i:j] if len(caps) == len(w) else []
                        if run and sum(1 for x in run if x[0].isupper()) >= 0.7 * len(run):
                            break
                        found.append("%s:%d: %d words as the book has them: \"%s\"" % (
                            os.path.relpath(f, ROOT), line, j - i, " ".join(w[i:j])))
                        break
        print("COPY   no run of %d words from the book   files %d%s" % (n, len(files), "  FAIL x%d" % len(found) if found else ""))
    if a.names:
        allow = set(x.strip() for x in a.allow.split(",") if x.strip())
        names = []
        for l in open(a.names, encoding="utf-8"):
            t = l.split("\t")[0].strip()
            if t and t not in allow and len(t) > 3:
                names.append(t)
        pats = [(t, re.compile(r"\b" + re.escape(t) + r"\b")) for t in names]
        hits = 0
        for f in files:
            body = open(f, encoding="utf-8", errors="ignore").read()
            for t, p in pats:
                m = p.search(body)
                if m:
                    hits += 1
                    found.append("%s:%d: the source book's name \"%s\"" % (os.path.relpath(f, ROOT), body.count("\n", 0, m.start()) + 1, t))
        print("ORIGIN none of the source book's names   names %d%s" % (len(names), "  FAIL x%d" % hits if hits else ""))
    for x in found[:40]:
        print("       FAIL: " + x)
    print("copy check: all clear" if not found else "copy check: %d findings" % len(found))
    sys.exit(1 if found else 0)


if __name__ == "__main__":
    main()
