"""Batch generation for the dialogue library (M5).

Finds every cell (a trigger for one speaker, and one tier or mood when the trigger is
split) that has fewer lines than it needs, sends the trigger and the speaker's voice
sheet to an AI model in batches, and adds what comes back to
game/data/dialogue/lines.json as drafts for review.

    python3 tools/dialogue/generate.py                       # fill every short cell (needs ANTHROPIC_API_KEY)
    python3 tools/dialogue/generate.py --speaker jess        # only Jess's cells
    python3 tools/dialogue/generate.py --trigger crit --target 6
    python3 tools/dialogue/generate.py --dry-run prompts/    # write the requests to files instead of sending them
    python3 tools/dialogue/generate.py --import answers/*.json   # add answers written elsewhere

A cell counts its draft and approved lines (rejected ones don't count), so rejecting
a line in the review mode and running this again replaces it. Approved lines go into
the request as examples of the voice; rejected ones as examples to avoid.
Only the Python standard library is needed.
"""
import argparse
import datetime
import glob
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATA = os.path.join(ROOT, "game", "data", "dialogue")
FIELDS = ["id", "trigger", "speaker", "tier", "mood", "to", "text", "reply", "status", "orig", "note", "source"]
PLAYERS = ["mara", "dev", "jess", "sam"]
API_URL = "https://api.anthropic.com/v1/messages"
DEFAULT_MODEL = "claude-sonnet-5-5"
CELLS_PER_REQUEST = 10

GAME = """Behind the Screen is a cozy game about being the Dungeon Master for four friends who meet every Thursday \
to play a fantasy tabletop RPG. The player preps sessions and runs game night; the friends sit around the table, \
roll dice, joke, eat snacks and react. Their characters adventure on a paper battle mat. Lines appear as short \
speech bubbles or group-chat texts, so they must read in a couple of seconds. The tone is warm, funny and kind: \
friends teasing each other, never mean, nothing crude, no real-world brands or pop-culture references."""

VOICE_KINDS = {
    "table": "the PLAYER talking at the table as themselves (out of character)",
    "character": "the CHARACTER speaking in the story (in character)",
    "chat": "a text message the PLAYER sends to the group chat during the week",
    "npc": "the DM voicing this NPC in the story",
}


# Data ---------------------------------------------------------------------------------------

def load(name):
    with open(os.path.join(DATA, name), encoding="utf-8") as f:
        return json.load(f)


def encode_line(line):
    keys = [k for k in FIELDS if k in line] + sorted(k for k in line if k not in FIELDS)
    return "{" + ", ".join(json.dumps(k) + ": " + json.dumps(line[k], ensure_ascii=True) for k in keys) + "}"


def save_lines(lines):
    body = ",\n".join("  " + encode_line(l) for l in lines)
    text = '{\n "version": 1,\n "lines": [\n' + body + ("\n" if lines else "") + " ]\n}\n"
    with open(os.path.join(DATA, "lines.json"), "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


class Library:
    def __init__(self):
        self.triggers = load("triggers.json")
        self.voices = load("voices.json")["voices"]
        self.lines = load("lines.json")["lines"]
        self.by_id = {t["id"]: t for t in self.triggers["triggers"]}
        self.variants = self.triggers.get("variants", 4)

    def cells(self):
        for t in self.triggers["triggers"]:
            for s in t["speakers"]:
                for v in (t["split"]["values"] if "split" in t else [None]):
                    yield t, s, v

    def split_field(self, t):
        return t["split"]["field"] if "split" in t else None

    def cell_lines(self, t, speaker, value):
        field = self.split_field(t)
        return [l for l in self.lines if l["trigger"] == t["id"] and l["speaker"] == speaker
                and (field is None or l.get(field) == value)]

    def next_id(self, trigger, speaker):
        n = 0
        for l in self.lines:
            if l["trigger"] == trigger and l["speaker"] == speaker:
                m = re.search(r"\.(\d+)$", l["id"])
                if m:
                    n = max(n, int(m.group(1)))
        return f"{trigger}.{speaker}.{n + 1}"


def lint(lib, t, line, speaker):
    """Problems with one line (the same rules as game/model/dialogue.lua)."""
    out = []
    fill = set(t.get("fill", []))
    for field in ("text", "reply"):
        s = line.get(field)
        if field == "text" or s is not None:
            if not isinstance(s, str) or not s.strip():
                out.append(f"empty {field}")
                continue
            if len(s) > t.get("max", 90):
                out.append(f"{field} too long ({len(s)} > {t.get('max', 90)})")
            if any(ord(c) > 126 or ord(c) < 32 for c in s):
                out.append(f"{field} has non-ASCII characters")
            for k in re.findall(r"{([A-Za-z0-9_]+)}", s):
                if k not in fill:
                    out.append(f"{{{k}}} isn't available here")
    for need in t.get("needs", []):
        if not line.get(need):
            out.append(f"needs {need}")
    if line.get("to") is not None and (line["to"] not in PLAYERS or line["to"] == speaker):
        out.append("to must be another player")
    return out


# Requests --------------------------------------------------------------------------------------

def short_cells(lib, args):
    out = []
    for t, s, v in lib.cells():
        if args.trigger and t["id"] not in args.trigger:
            continue
        if args.speaker and s not in args.speaker:
            continue
        have = [l for l in lib.cell_lines(t, s, v) if l.get("status") != "rejected"]
        need = args.target - len(have)
        if need > 0:
            out.append((t, s, v, need))
    return out


def voice_text(lib, speaker):
    v = lib.voices[speaker]
    lines = []
    if v["kind"] == "player":
        lines.append(f"{v['name']} (a player) plays {v['char']}, a {v['class']}. Archetypes: {v['archetypes']}.")
        lines.append(f"At the table: {v['table']}")
        lines.append(f"In character: {v['character']}")
        lines.append(f"In the group chat: {v['chat']}")
        lines.append(f"Backstory hook ({{thread}}): {v['thread']}.")
        lines.append("With the others: " + "; ".join(f"{k}: {r}" for k, r in v["relationships"].items()))
        lines.append("Table samples: " + " | ".join(v["samples_table"]))
        lines.append("Character samples: " + " | ".join(v["samples_character"]))
    else:
        lines.append(f"{v['name']} (an NPC). {v['personality']}")
        lines.append("Samples: " + " | ".join(v["samples"]))
    lines.append("Verbal tics: " + "; ".join(v["tics"]))
    lines.append("Would never say or do: " + "; ".join(v["never"]))
    return "\n".join(lines)


def build_prompt(lib, speaker, batch):
    v = lib.voices[speaker]
    parts = [GAME, "", "VOICE SHEET", voice_text(lib, speaker), "", "CELLS TO WRITE"]
    for t, s, value, need in batch:
        key = f"{t['id']}|{s}|{value or ''}"
        desc = [f"- cell {key}: write {need} new line(s).",
                f"  Moment: {t['when']}",
                f"  Spoken as: {VOICE_KINDS[t['voice']]}."]
        if value:
            desc.append(f"  {t['split']['field'].capitalize()}: {value}.")
        fills = [f for f in t.get("fill", [])]
        desc.append("  Fill-ins you may use: " + (", ".join("{" + f + "}" for f in fills) if fills else "none") + ".")
        desc.append(f"  At most {t.get('max', 90)} characters.")
        if t["id"] == "banter":
            desc.append("  Each line needs \"to\" (the player key of the character spoken to: one of "
                        + ", ".join(p for p in PLAYERS if p != s) + ") and \"reply\" (that character's answer, in their voice).")
        existing = lib.cell_lines(t, s, value)
        good = [l["text"] for l in existing if l.get("status") in ("approved", "edited")]
        bad = [l["text"] for l in existing if l.get("status") == "rejected"]
        draft = [l["text"] for l in existing if l.get("status", "draft") == "draft"]
        if good:
            desc.append("  Approved (match this voice, don't repeat): " + " | ".join(good))
        if draft:
            desc.append("  Already drafted (don't repeat): " + " | ".join(draft))
        if bad:
            desc.append("  Rejected (avoid lines like these): " + " | ".join(bad))
        parts.extend(desc)
    parts += ["", "RULES",
              "- Plain ASCII only: no emoji, no curly quotes, no em dashes. Use straight quotes and a plain hyphen.",
              "- Every line must sound like this speaker and nobody else. Vary the shape: not every line an exclamation.",
              "- Only use the fill-ins listed for that cell, written exactly as {name}.",
              "- Short is better. A speech bubble is read in two seconds.",
              "",
              "Answer with JSON only, in this shape:",
              '{"cells": [{"cell": "<cell key>", "lines": [{"text": "..."}]}]}',
              f"Speaker: {speaker} ({v['name']})."]
    return "\n".join(parts)


def call_api(prompt, model, key):
    body = json.dumps({"model": model, "max_tokens": 4000,
                       "messages": [{"role": "user", "content": prompt}]}).encode("utf-8")
    req = urllib.request.Request(API_URL, data=body, method="POST", headers={
        "content-type": "application/json", "x-api-key": key, "anthropic-version": "2023-06-01"})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                data = json.loads(r.read().decode("utf-8"))
            return "".join(b.get("text", "") for b in data.get("content", []) if b.get("type") == "text")
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 502, 503, 529) and attempt < 3:
                time.sleep(5 * (attempt + 1))
                continue
            raise SystemExit(f"API error {e.code}: {e.read().decode('utf-8', 'replace')[:400]}")
        except urllib.error.URLError as e:
            if attempt < 3:
                time.sleep(5)
                continue
            raise SystemExit(f"Can't reach the API: {e.reason}")


def parse_answer(text):
    """The first JSON object in a model's answer."""
    start = text.find("{")
    end = text.rfind("}")
    if start < 0 or end < start:
        raise ValueError("no JSON object in the answer")
    return json.loads(text[start:end + 1])


def add_answer(lib, answer, source, report):
    """Add the lines in one answer; returns how many were added."""
    added = 0
    for cell in answer.get("cells", []):
        key = cell.get("cell", "")
        bits = key.split("|")
        if len(bits) < 2 or bits[0] not in lib.by_id:
            report.append(f"unknown cell {key!r}")
            continue
        trigger, speaker = bits[0], bits[1]
        value = bits[2] if len(bits) > 2 and bits[2] else None
        t = lib.by_id[trigger]
        if speaker not in t["speakers"]:
            report.append(f"{key}: {speaker} doesn't say {trigger}")
            continue
        field = lib.split_field(t)
        if field and value not in t["split"]["values"]:
            report.append(f"{key}: needs a {field}")
            continue
        seen = {l["text"].lower() for l in lib.cell_lines(t, speaker, value)}
        for item in cell.get("lines", []):
            if isinstance(item, str):
                item = {"text": item}
            line = {"trigger": trigger, "speaker": speaker}
            if field:
                line[field] = value
            for k in ("to", "text", "reply", "note"):
                if item.get(k) is not None:
                    line[k] = item[k].strip() if isinstance(item[k], str) else item[k]
            problems = lint(lib, t, line, speaker)
            if line.get("text", "").lower() in seen:
                problems.append("duplicate")
            if problems:
                report.append(f"{key}: dropped {line.get('text')!r}: {', '.join(problems)}")
                continue
            seen.add(line["text"].lower())
            line["id"] = lib.next_id(trigger, speaker)
            line["status"] = "draft"
            line["source"] = source
            lib.lines.append(line)
            added += 1
    return added


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--trigger", action="append", help="only this trigger (repeatable)")
    ap.add_argument("--speaker", action="append", help="only this speaker (repeatable)")
    ap.add_argument("--target", type=int, help="lines wanted per cell, counting drafts and approved (default: the variants in triggers.json)")
    ap.add_argument("--model", default=os.environ.get("BTS_MODEL", DEFAULT_MODEL))
    ap.add_argument("--dry-run", metavar="DIR", help="write each request to DIR instead of sending it")
    ap.add_argument("--import", dest="imports", nargs="+", metavar="FILE", help="add answers from JSON files")
    ap.add_argument("--source", help="label for imported lines (default: the file name)")
    args = ap.parse_args()

    lib = Library()
    args.target = args.target or lib.variants
    report = []
    today = datetime.date.today().isoformat()

    if args.imports:
        total = 0
        for pattern in args.imports:
            for path in sorted(glob.glob(pattern)) or [pattern]:
                with open(path, encoding="utf-8") as f:
                    answer = parse_answer(f.read())
                total += add_answer(lib, answer, args.source or f"import {os.path.basename(path)} {today}", report)
        save_lines(lib.lines)
        print(f"imported {total} lines; library has {len(lib.lines)}")
        for r in report:
            print("  " + r)
        return

    cells = short_cells(lib, args)
    if not cells:
        print("every cell has enough lines")
        return
    by_speaker = {}
    for c in cells:
        by_speaker.setdefault(c[1], []).append(c)
    batches = []
    for speaker, cs in by_speaker.items():
        for i in range(0, len(cs), CELLS_PER_REQUEST):
            batches.append((speaker, cs[i:i + CELLS_PER_REQUEST]))
    print(f"{len(cells)} cells need {sum(c[3] for c in cells)} lines: {len(batches)} requests")

    if args.dry_run:
        os.makedirs(args.dry_run, exist_ok=True)
        for n, (speaker, batch) in enumerate(batches, 1):
            path = os.path.join(args.dry_run, f"{n:03d}_{speaker}.md")
            with open(path, "w", encoding="utf-8", newline="\n") as f:
                f.write(build_prompt(lib, speaker, batch) + "\n")
        print(f"wrote {len(batches)} requests to {args.dry_run}; answer each as {{\"cells\": [...]}} and run --import")
        return

    key = os.environ.get("ANTHROPIC_API_KEY")
    if not key:
        raise SystemExit("Set ANTHROPIC_API_KEY to call the API, or use --dry-run / --import.")
    total = 0
    for n, (speaker, batch) in enumerate(batches, 1):
        print(f"[{n}/{len(batches)}] {speaker}: {len(batch)} cells")
        text = call_api(build_prompt(lib, speaker, batch), args.model, key)
        try:
            answer = parse_answer(text)
        except ValueError as e:
            report.append(f"request {n}: {e}")
            continue
        total += add_answer(lib, answer, f"{args.model} {today}", report)
        save_lines(lib.lines)   # keep what we have if a later request fails
    print(f"added {total} draft lines; library has {len(lib.lines)}")
    for r in report:
        print("  " + r)


if __name__ == "__main__":
    main()
