"""Read an adventure PDF into clean pages and a list of what needs a person's eye (step 2 of
docs/design/2026-11-06-adventure-import.md). The book stays the reader's: everything this writes goes in OUT,
outside the repo, and nothing from it is committed.

    python3 tools/import/ingest.py BOOK.pdf OUT [--ocr auto|always|never] [--pages 1-20]

OUT gets:
    pages/NNN.txt     each page's text in reading order, cropped to the page (no text from the facing page),
                      columns kept apart, ligatures and line-end hyphens mended (NNN = the PDF's page number)
    pages/NNN.ocr.txt the same from OCR, for a page with no text layer (or --ocr always)
    index.json        per page: the printed page number found on it, words, whether it needed OCR, its headings
                      (by font size), links; then the book's whole headings, names, spellings that look like
                      the same name, the offset between printed and PDF page numbers, and every issue found
    issues.txt        the same issues as a list to read: each goes on the calls list for Conner, never fixed
                      silently (the import doc, Part 3)
    names.txt         every capitalised term and where it is: the calls list's public-or-secret question
                      (the importer's contract, 4b), and the list the originality check reads for a book that
                      comes in as a shape

What it finds (all seen in the six books so far): pages with no text layer; printed numbers that differ from the
PDF's; headings in small capitals that extract jumbled (found by font and size instead); ligatures and a font fault
that turns "f" into "1" or "Z"; names spelled two ways; links to outside rules; text only inside pictures (it can't
read those: they're listed as pages with pictures and little text).
"""
import argparse
import collections
import json
import os
import re
import subprocess
import sys

try:
    import pdfplumber
except ImportError:  # pragma: no cover
    sys.exit("ingest.py needs pdfplumber (pip install pdfplumber --break-system-packages)")

LIGATURES = {"ﬀ": "ff", "ﬁ": "fi", "ﬂ": "fl", "ﬃ": "ffi", "ﬄ": "ffl", "’": "'",
             "‘": "'", "“": '"', "”": '"', "–": "-", "—": "-"}
FONT_FAULT = re.compile(r"\b[a-z]*1[a-z]{2,}\b")             # "1ind", "in1luence": a font that lost its f
FONT_FAULT_Z = re.compile(r"\bZ[a-z]{2,}\b")                  # "Zlees", but only beside the 1s (Zula is a name)
STOP_NAMES = {"The", "A", "An", "If", "When", "This", "That", "These", "Those", "Each", "Any", "All", "On", "In", "At",
              "As", "It", "Its", "He", "She", "They", "You", "Your", "We", "Our", "His", "Her", "Their", "There", "Then",
              "But", "And", "Or", "Of", "To", "For", "With", "From", "By", "One", "Two", "Three", "DC", "HP", "AC",
              "Hit", "Points", "Armor", "Class", "Speed", "STR", "DEX", "CON", "INT", "WIS", "CHA", "Challenge",
              "Actions", "Senses", "Languages", "Skills", "Damage", "Saving", "Throws", "Melee", "Ranged", "Weapon",
              "Attack", "Bonus", "Reaction", "Reactions", "Legendary", "Treasure", "Development", "Roleplaying",
              # (the rules' own words, and a book's parts)
              "Strength", "Dexterity", "Constitution", "Intelligence", "Wisdom", "Charisma", "Athletics", "Acrobatics",
              "Sleight", "Stealth", "Arcana", "History", "Investigation", "Nature", "Religion", "Animal", "Insight",
              "Medicine", "Perception", "Survival", "Deception", "Intimidation", "Performance", "Persuasion",
              "Appendix", "Part", "Chapter", "Table", "Map", "Page", "Advantage", "Disadvantage", "Spellcasting"}


def mend(text):
    for a, b in LIGATURES.items():
        text = text.replace(a, b)
    # A word broken over a line with a hyphen.
    text = re.sub(r"(\w)-\n(\w)", r"\1\2", text)
    return text


def columns(page):
    """The page's words in reading order: one column or two, found by the gap down the middle."""
    w = page.width
    words = page.extract_words(keep_blank_chars=False, use_text_flow=False, extra_attrs=["size", "fontname"])
    words = [x for x in words if 0 <= x["x0"] and x["x1"] <= w]          # (cropped: nothing from the facing page)
    if not words:
        return [], words
    mid = w / 2
    crossing = [x for x in words if x["x0"] < mid - 6 and x["x1"] > mid + 6]
    two = len(crossing) < max(3, len(words) * 0.04)
    cols = [[x for x in words if x["x1"] <= mid + 6], [x for x in words if x["x0"] >= mid - 6]] if two else [words]
    lines = []
    for col in cols:
        rows = collections.OrderedDict()
        for x in sorted(col, key=lambda x: (round(x["top"] / 3), x["x0"])):
            rows.setdefault(round(x["top"] / 3), []).append(x)
        for row in rows.values():
            lines.append(row)
    return lines, words


def printed_number(lines):
    """A bare number on the page's first or last two lines: the folio."""
    cands = lines[:2] + lines[-2:]
    for row in cands:
        t = " ".join(x["text"] for x in row).strip()
        if re.fullmatch(r"\d{1,4}", t):
            return int(t)
    return None


def headings(lines, body_size):
    out = []
    for row in lines:
        size = max(x["size"] for x in row)
        text = " ".join(x["text"] for x in row).strip()
        if size >= body_size * 1.25 and 2 <= len(text) <= 80 and not re.fullmatch(r"\d+", text):
            out.append({"text": mend(text), "size": round(size, 1), "font": row[0].get("fontname", "")})
    return out


def ocr(pdf, pno, out_dir):
    base = os.path.join(out_dir, "ocr_%03d" % pno)
    subprocess.run(["pdftoppm", "-f", str(pno), "-l", str(pno), "-r", "200", "-png", "-singlefile", pdf, base],
                   check=True, capture_output=True)
    r = subprocess.run(["tesseract", base + ".png", "-", "--psm", "3"], capture_output=True, text=True)
    os.remove(base + ".png")
    return r.stdout


def similar(a, b):
    """Two names one letter apart (Elvidius / Elvidious, Beldan / Beldon)."""
    if a == b or abs(len(a) - len(b)) > 1 or a[0] != b[0] or len(a) < 5:
        return False
    s0, l0 = (a, b) if len(a) <= len(b) else (b, a)
    # (A plural, a possessive or a past tense is the same word, not a second spelling.)
    if l0 in (s0 + "s", s0 + "d", s0.rstrip("'") + "s") or s0.endswith("s") and l0 == s0[:-1] + "'s":
        return False
    if len(a) == len(b):
        return sum(1 for x, y in zip(a, b) if x != y) == 1
    s, l = (a, b) if len(a) < len(b) else (b, a)
    return any(l[:i] + l[i + 1:] == s for i in range(len(l)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("pdf")
    ap.add_argument("out")
    ap.add_argument("--ocr", default="auto", choices=["auto", "always", "never"])
    ap.add_argument("--pages", default=None, help="a range like 1-20 (PDF pages)")
    a = ap.parse_args()
    os.makedirs(os.path.join(a.out, "pages"), exist_ok=True)
    issues, pages_out = [], []
    names = collections.defaultdict(set)
    all_heads = []
    links = []
    with pdfplumber.open(a.pdf) as pdf:
        n = len(pdf.pages)
        lo, hi = 1, n
        if a.pages:
            lo, hi = [int(x) for x in a.pages.split("-")]
        sizes = collections.Counter()
        for p in pdf.pages[lo - 1:min(hi, n)][:30]:
            for x in p.extract_words(extra_attrs=["size"]):
                sizes[round(x["size"])] += 1
        body = sizes.most_common(1)[0][0] if sizes else 10
        # (Every word the book uses in lower case: a capitalised word that's also used lower case is an ordinary
        # word at the start of a sentence, not a name.)
        # (Three times at least: a cover's stylised lower case doesn't make a city's name an ordinary word.)
        lower_count = collections.Counter()
        for p in pdf.pages[lo - 1:min(hi, n)]:
            for x in p.extract_words():
                t = x["text"].strip(".,;:!?()\"'")
                if t and t[0].islower():
                    lower_count[t.lower()] += 1
        lower_words = {w for w, k in lower_count.items() if k >= 3}
        for pno in range(lo, min(hi, n) + 1):
            page = pdf.pages[pno - 1]
            lines, words = columns(page)
            text = mend("\n".join(" ".join(x["text"] for x in row) for row in lines))
            rec = {"pdf_page": pno, "words": len(words), "printed": printed_number(lines),
                   "pictures": len(page.images), "ocr": False, "headings": headings(lines, body)}
            if (a.ocr == "always") or (a.ocr == "auto" and len(words) < 25 and page.images):
                if a.ocr != "never":
                    o = ocr(a.pdf, pno, a.out)
                    with open(os.path.join(a.out, "pages", "%03d.ocr.txt" % pno), "w") as f:
                        f.write(mend(o))
                    rec["ocr"] = True
                    if len(o.split()) > 20:
                        issues.append("p%d: no text layer; read by OCR (check it by eye)" % pno)
                    else:
                        issues.append("p%d: a picture page with little or no text (a map, art, or text only an eye can read)" % pno)
            with open(os.path.join(a.out, "pages", "%03d.txt" % pno), "w") as f:
                f.write(text)
            faults = FONT_FAULT.findall(text)
            if faults:
                faults += [z for z in FONT_FAULT_Z.findall(text) if z.lower() not in lower_words]
            if len(faults) >= 3:
                issues.append("p%d: %d words that look like a font fault (%s)" % (pno, len(faults), ", ".join(sorted(set(faults))[:5])))
            if "�" in text:
                issues.append("p%d: characters the PDF doesn't map to text (shown as �)" % pno)
            for h in rec["headings"]:
                all_heads.append(dict(h, page=pno))
            for m in re.finditer(r"\b([A-Z][a-z'’]+(?:\s+(?:of|the|de|du|von)?\s*[A-Z][a-z'’]+)*)", text):
                term = m.group(1).strip()
                first = term.split()[0]
                if first not in STOP_NAMES and len(term) > 2 and not (" " not in term and term.lower() in lower_words):
                    names[term].add(pno)
            for h in (page.hyperlinks or []):
                if h.get("uri"):
                    links.append({"page": pno, "uri": h["uri"]})
            pages_out.append(rec)
    # Printed vs PDF numbers: the usual offset, and pages that disagree with it.
    offs = collections.Counter(r["printed"] - r["pdf_page"] for r in pages_out if r["printed"] is not None)
    offset = offs.most_common(1)[0][0] if offs else None
    if offset not in (None, 0):
        issues.append("printed page numbers are the PDF's %+d: the book's contents and its 'see page N' references use "
                      "the printed ones" % offset)
    if links:
        issues.append("%d links out of the book (outside rules, videos): what they point to isn't in the PDF" % len(links))
    # Names that look like one name spelled two ways.
    single = sorted(t for t in names if " " not in t and len(names[t]) >= 1)
    pairs = []
    for i, x in enumerate(single):
        for y in single[i + 1:i + 40]:
            if similar(x, y):
                pairs.append((x, y))
    for x, y in pairs[:60]:
        issues.append("spelled two ways? %s (p%s) / %s (p%s)" % (x, min(names[x]), y, min(names[y])))
    index = {"pdf": os.path.basename(a.pdf), "pages": pages_out, "body_size": body, "offset": offset,
             "headings": all_heads, "links": links,
             "names": {k: sorted(v) for k, v in sorted(names.items()) if len(v) >= 2 or " " in k},
             "issues": issues}
    with open(os.path.join(a.out, "index.json"), "w") as f:
        json.dump(index, f, indent=1)
    with open(os.path.join(a.out, "issues.txt"), "w") as f:
        f.write("\n".join(issues) + "\n")
    with open(os.path.join(a.out, "names.txt"), "w") as f:
        for k, v in sorted(index["names"].items(), key=lambda kv: (-len(kv[1]), kv[0])):
            f.write("%s\t%d pages\tp%s\n" % (k, len(v), ",".join(str(x) for x in v[:12])))
    print("ingest: %d pages, %d headings, %d names, %d issues, %d read by OCR -> %s" % (
        len(pages_out), len(all_heads), len(index["names"]), len(issues), sum(1 for r in pages_out if r["ocr"]), a.out))


if __name__ == "__main__":
    main()
