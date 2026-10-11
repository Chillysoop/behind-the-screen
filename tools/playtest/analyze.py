"""Read playtest logs and write one report for the round.

Every tester sends back their playtest_log.jsonl (Windows: %APPDATA%\\behind_the_screen\\).
Put them in a folder, one file per tester (rename them after the tester), then:

    python3 tools/playtest/analyze.py path/to/logs/            # or list the files
    python3 tools/playtest/analyze.py tools/playtest/samples/  # try it on pretend logs

Writes playtest_report.html next to the logs (or --out FILE) and prints a summary.
Only the Python standard library is needed.

The M7 gate asks whether the slice answers its question: is writing a session satisfying,
and does watching it play out pay off? This report reads that from the end-of-slice survey
and the two quick questions after every session, and shows where people stopped.
"""
import argparse
import glob
import html
import json
import os
import statistics
import sys
from collections import Counter, OrderedDict

SESSIONS = 4
PREP_ORDER = ["Satisfying", "Okay", "Like homework"]
WATCH_ORDER = ["Paid off", "Was okay", "Dragged"]
NEXT_ORDER = ["Yes", "Maybe", "No"]
SCALES = [
    ("satisfying", "Writing a session was satisfying", True),
    ("payoff", "Watching it play out paid off", True),
    ("homework", "Prep felt like homework", False),
    ("gut", "The players reacted the way my gut said they would", True),
]


def read_log(path):
    """One tester's file -> list of runs (a run = one campaign, by seed), in order."""
    runs = OrderedDict()
    with open(path, encoding="utf-8", errors="replace") as f:
        for n, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except ValueError:
                rec = None
            if not isinstance(rec, dict):
                print(f"  {os.path.basename(path)} line {n}: not a log record, skipped", file=sys.stderr)
                continue
            seed = rec.get("seed", "?")
            run = runs.setdefault(seed, {"seed": seed, "weeks": [], "quick": {}, "survey": None})
            kind = rec.get("type", "week")
            if kind == "week":
                run["weeks"].append(rec)
            elif kind == "week_survey":
                for k in ("prep", "watch"):
                    if not isinstance(rec.get(k), str):
                        rec[k] = None
                run["quick"][num(rec.get("week"))] = rec
            elif kind == "slice_survey":
                for k in ("drag", "favourite", "next"):
                    if rec.get(k) is not None and not isinstance(rec.get(k), str):
                        rec[k] = str(rec[k])
                text = rec.get("text")
                if isinstance(text, dict):   # the game nests the typed answers under "text"
                    for k in ("drag", "favourite"):
                        if isinstance(text.get(k), str) and not rec.get(k):
                            rec[k] = text[k]
                run["survey"] = rec
    return list(runs.values())


def tester_name(path):
    base = os.path.splitext(os.path.basename(path))[0]
    if base == "playtest_log":
        base = os.path.basename(os.path.dirname(os.path.abspath(path))) or base
    return base


def main_run(runs):
    """The run that counts for a tester: the one that got furthest (a survey beats no survey)."""
    return max(runs, key=lambda r: (r["survey"] is not None, len(r["weeks"])))


def num(x):
    """A number from a log field, or None (a hand-edited or odd log shouldn't crash the report)."""
    if isinstance(x, bool):
        return None
    if isinstance(x, (int, float)):
        return x
    try:
        return float(x)
    except (TypeError, ValueError):
        return None


def dct(x):
    return x if isinstance(x, dict) else {}


def lst(x):
    return x if isinstance(x, list) else []


def median(xs):
    xs = [v for v in (num(x) for x in xs) if v is not None]
    return statistics.median(xs) if xs else None


def fmt(x, digits=1):
    x = num(x)
    if x is None:
        return "-"
    if isinstance(x, float) and not x.is_integer():
        return f"{x:.{digits}f}"
    return str(int(x))


def analyze(paths):
    testers = []
    for p in paths:
        runs = read_log(p)
        if not runs:
            continue
        r = main_run(runs)
        # Keep the last record per week, in case a week was played twice (an older save), and
        # only the slice's sessions: "Keep playing" after the survey goes on past them.
        by_week = {}
        for w in r["weeks"]:
            wk = num(w.get("week"))
            if wk is not None and 1 <= wk <= SESSIONS:
                by_week[int(wk)] = w
        weeks = [by_week[k] for k in sorted(by_week)]
        t = {
            "name": tester_name(p),
            "runs": len(runs),
            "weeks": weeks,
            "quick": r["quick"],
            "survey": r["survey"],
            "played": len(weeks),
            "finished": len(weeks) >= SESSIONS,
        }
        t["prep_minutes"] = [(num(w.get("prep_seconds")) or 0) / 60 for w in weeks]
        t["night_minutes"] = [num(w.get("night_seconds")) / 60 for w in weeks if num(w.get("night_seconds")) is not None]
        t["fun"] = [w.get("average_fun") for w in weeks]
        t["cooks"] = sum(num(dct(w.get("rolls")).get("cooked")) or 0 for w in weeks)
        t["callouts"] = sum(num(w.get("callouts")) or 0 for w in weeks)
        t["level"] = weeks[-1].get("level") if weeks else None
        last = weeks[-1] if weeks else {}
        players = dct(last.get("players"))
        t["coming"] = sum(1 for p in players.values() if isinstance(p, dict)
                          and not p.get("on_break") and (num(dct(p.get("long")).get("commitment")) or 0) >= 55)
        t["fixed"] = sorted({str(k) for w in weeks for k, c in dct(w.get("conflicts")).items()
                             if isinstance(c, dict) and c.get("fixed")})
        t["paid"] = sorted({str(sd.get("id")) for w in weeks for sd in lst(w.get("seeds"))
                            if isinstance(sd, dict) and sd.get("state") == "paid"})
        t["story"] = sum(1 for w in weeks if (num(w.get("story")) or 0) > 0)
        t["chapter"] = next((w.get("chapter") for w in reversed(weeks) if w.get("chapter")), None)
        t["tips_off"] = bool(dct(last.get("guide")).get("off"))
        testers.append(t)
    return testers


def summarize(testers, min_score, min_yes):
    surveys = [t["survey"] for t in testers if t["survey"]]
    s = {"testers": len(testers), "surveys": len(surveys),
         "finished": sum(1 for t in testers if t["finished"])}
    for key, _, _ in SCALES:
        s[key] = median([v.get(key) for v in surveys])
        s[key + "_counts"] = Counter(int(num(v.get(key))) for v in surveys if num(v.get(key)) is not None)
    s["next"] = Counter(v.get("next") for v in surveys if v.get("next"))
    s["yes_share"] = (s["next"].get("Yes", 0) / len(surveys)) if surveys else None
    # Week by week.
    s["by_week"] = []
    for wk in range(1, SESSIONS + 1):
        prep = Counter()
        watch = Counter()
        mins, fun, night = [], [], []
        for t in testers:
            q = t["quick"].get(wk)
            if q and not q.get("skipped"):
                if q.get("prep"):
                    prep[q["prep"]] += 1
                if q.get("watch"):
                    watch[q["watch"]] += 1
            w = next((w for w in t["weeks"] if w.get("week") == wk), None)
            if w:
                mins.append((num(w.get("prep_seconds")) or 0) / 60)
                fun.append(w.get("average_fun"))
                if num(w.get("night_seconds")) is not None:
                    night.append(num(w.get("night_seconds")) / 60)
        s["by_week"].append({"week": wk, "prep": prep, "watch": watch, "prep_minutes": median(mins),
                             "night_minutes": median(night), "fun": median(fun), "played": len(mins)})
    s["stopped"] = [(t["name"], t["played"]) for t in testers if not t["finished"]]
    s["tips_off"] = [t["name"] for t in testers if t.get("tips_off")]
    # The gate, as the plan words it: writing satisfying, watching pays off, and people want more.
    if not surveys:
        s["verdict"] = "No end-of-slice surveys yet."
        s["pass"] = None
    else:
        ok_write = s["satisfying"] is not None and s["satisfying"] >= min_score
        ok_watch = s["payoff"] is not None and s["payoff"] >= min_score
        ok_more = s["yes_share"] is not None and s["yes_share"] >= min_yes
        s["pass"] = ok_write and ok_watch and ok_more
        parts = []
        parts.append(f"writing a session {'was' if ok_write else 'was not'} satisfying (median {fmt(s['satisfying'])} of 5)")
        parts.append(f"watching {'paid off' if ok_watch else 'did not pay off'} (median {fmt(s['payoff'])})")
        parts.append(f"{round(100 * s['yes_share'])}% would play session 5")
        s["verdict"] = ("The slice answers its question: " if s["pass"] else "Not yet: ") + "; ".join(parts) + "."
    s["breaks"] = where_it_breaks(testers, s)
    return s


def share(counter, key):
    total = sum(counter.values())
    return counter.get(key, 0) / total if total else 0


def where_it_breaks(testers, s):
    """Plain pointers to the weak spots, worst first. Shown whatever the verdict."""
    out = []
    weeks = [w for w in s["by_week"] if w["played"]]
    if weeks:
        hw = max(weeks, key=lambda w: share(w["prep"], "Like homework"))
        if share(hw["prep"], "Like homework") >= 0.25:
            out.append(f"Prep for session {hw['week']} felt like homework to {hw['prep'].get('Like homework', 0)} "
                       f"of {sum(hw['prep'].values())} (median {fmt(hw['prep_minutes'])} min on the board). Look at that beat's hand and hint.")
        dr = max(weeks, key=lambda w: share(w["watch"], "Dragged") + 0.5 * share(w["watch"], "Was okay"))
        flat = share(dr["watch"], "Dragged") + share(dr["watch"], "Was okay")
        if flat >= 0.4:
            out.append(f"Session {dr['week']} was the weakest to watch: {dr['watch'].get('Dragged', 0)} dragged, "
                       f"{dr['watch'].get('Was okay', 0)} just okay (game night median {fmt(dr['night_minutes'])} min).")
        long = [w for w in weeks if w["night_minutes"] and w["night_minutes"] > 20]
        if long:
            out.append("Game nights ran long (over 20 min median) in session " + ", ".join(str(w["week"]) for w in long) + ".")
    for name, played in s["stopped"]:
        out.append(f"{name} stopped after session {played}; check their quick answers for that week.")
    if s.get("homework") is not None and s["homework"] >= 3:
        out.append(f"Prep felt like homework overall (median {fmt(s['homework'])} of 5).")
    if s.get("gut") is not None and s["gut"] <= 2:
        out.append(f"Players didn't react the way testers expected (median {fmt(s['gut'])} of 5): the tells may be too hidden.")
    flat_endings = [t["name"] for t in testers if t["chapter"] == "flat"]
    if flat_endings:
        out.append(f"The first act ended flat for {len(flat_endings)} of {sum(1 for t in testers if t['finished'])}: "
                   + ", ".join(flat_endings) + ".")
    unsettled = [t["name"] for t in testers if t["finished"] and not t["fixed"]]
    if len(unsettled) >= 2:
        out.append(f"{len(unsettled)} testers never settled a table conflict; the conversations may be easy to miss.")
    return out


# ------------------------------------------------------------------------------------ HTML

CSS = """
:root { color-scheme: dark; --bg:#1b1411; --surface:#241b16; --raise:#2f241d; --ink:#f3e7cf; --ink-2:#c9b89c;
  --muted:#8f7f68; --rule:#3a2e25; --track:#33281f; --accent:#e8b04a; --good:#3fbf5a; --bad:#e0604f;
  --c1:#7fb069; --c2:#e8b04a; --c3:#e0604f;
  --font-display:"Lora", Georgia, serif; --font-body:"Outfit", system-ui, -apple-system, "Segoe UI", sans-serif; }
@media (prefers-color-scheme: light) { :root:not([data-theme="dark"]) { color-scheme: light; --bg:#f4ecdb;
  --surface:#fbf6ea; --raise:#efe4c8; --ink:#2b2018; --ink-2:#5d4e3c; --muted:#85745e; --rule:#e0d4b8; --track:#ebe2cc;
  --accent:#8a5a0e; --good:#0a7d0a; --bad:#c03434; --c1:#4f8a3a; --c2:#b07818; --c3:#c03434; } }
:root[data-theme="light"] { color-scheme: light; --bg:#f4ecdb; --surface:#fbf6ea; --raise:#efe4c8; --ink:#2b2018;
  --ink-2:#5d4e3c; --muted:#85745e; --rule:#e0d4b8; --track:#ebe2cc; --accent:#8a5a0e; --good:#0a7d0a; --bad:#c03434;
  --c1:#4f8a3a; --c2:#b07818; --c3:#c03434; }
* { box-sizing: border-box; }
body { margin:0; background:var(--bg); color:var(--ink); font:400 16px/1.55 var(--font-body); }
.wrap { max-width:1040px; margin:0 auto; padding-inline:20px; padding-block:40px 72px; display:grid; gap:48px; }
h1,h2,h3 { font-family:var(--font-display); font-weight:700; margin:0; text-wrap:balance; }
h1 { font-size:clamp(30px,5vw,44px); line-height:1.1; } h2 { font-size:clamp(22px,3.2vw,28px); }
h3 { font-family:var(--font-body); font-size:16px; font-weight:600; }
p { margin:0; max-width:68ch; } .lede { color:var(--ink-2); font-size:17px; }
.eyebrow { font-size:12px; font-weight:600; letter-spacing:.12em; text-transform:uppercase; color:var(--accent); }
header, section { display:grid; gap:14px; } .num { font-variant-numeric:tabular-nums; }
.verdict { padding:18px 20px; border-radius:12px; background:var(--surface); border:1px solid var(--rule);
  border-left:4px solid var(--accent); font-size:18px; }
.verdict.pass { border-left-color:var(--good); } .verdict.fail { border-left-color:var(--bad); }
.grid { display:grid; grid-template-columns:repeat(auto-fit, minmax(min(100%, 300px), 1fr)); gap:14px; }
.card { padding:16px; background:var(--surface); border:1px solid var(--rule); border-radius:12px; display:grid;
  gap:8px; align-content:start; min-width:0; }
.big { font-family:var(--font-display); font-size:30px; }
.muted { color:var(--muted); font-size:14px; }
.dist { display:flex; height:12px; border-radius:6px; overflow:hidden; background:var(--track); }
.dist i { display:block; height:100%; }
.legend { display:flex; flex-wrap:wrap; gap:4px 14px; font-size:13px; color:var(--ink-2); }
.legend span { display:inline-flex; align-items:center; gap:6px; } .legend b { width:10px; height:10px; border-radius:3px; display:inline-block; }
.scale { display:grid; grid-template-columns:repeat(5, 1fr); gap:6px; }
.scale div { text-align:center; padding:6px 0; border-radius:6px; background:var(--track); font-size:13px; color:var(--muted); }
.scale div.on { background:var(--accent); color:var(--bg); font-weight:600; }
.tablewrap { overflow-x:auto; }
table { border-collapse:collapse; width:100%; font-size:14px; font-variant-numeric:tabular-nums; }
th, td { padding:8px 10px; border-bottom:1px solid var(--rule); text-align:left; vertical-align:top; }
thead th { color:var(--muted); font-weight:500; font-size:13px; }
blockquote { margin:0; padding:10px 14px; background:var(--surface); border-left:3px solid var(--accent); border-radius:6px; }
blockquote cite { display:block; color:var(--muted); font-style:normal; font-size:13px; margin-top:4px; }
.quotes { display:grid; grid-template-columns:repeat(auto-fit, minmax(min(100%, 380px), 1fr)); gap:14px; align-items:start; }
.quotes > div { display:grid; gap:10px; min-width:0; }
.survey { grid-template-columns:repeat(auto-fit, minmax(min(100%, 220px), 1fr)); }
.survey .wide { grid-column:1 / -1; }
.weeks { grid-template-columns:repeat(auto-fit, minmax(min(100%, 420px), 1fr)); }
td.n { white-space:nowrap; }
@media (max-width: 560px) { .wrap { gap:36px; padding-block:28px 56px; } }
"""


def dist_bar(counter, order, colors):
    total = sum(counter.get(k, 0) for k in order)
    if total == 0:
        return '<div class="dist"></div>'
    parts = "".join(f'<i style="width:{100 * counter.get(k, 0) / total:.1f}%;background:var({c})" title="{html.escape(k)}: {counter.get(k, 0)}"></i>'
                    for k, c in zip(order, colors))
    return f'<div class="dist">{parts}</div>'


def legend(order, colors, counter=None):
    return '<div class="legend">' + "".join(
        f'<span><b style="background:var({c})"></b>{html.escape(k)}{(" " + str(counter.get(k, 0))) if counter is not None else ""}</span>'
        for k, c in zip(order, colors)) + "</div>"


def scale_card(s, key, label, higher_better):
    counts = s[key + "_counts"]
    total = sum(counts.values())
    med = s[key]
    cells = "".join(f'<div class="{"on" if med is not None and round(med) == v else ""}">{v}<br><span class="num">{counts.get(v, 0)}</span></div>'
                    for v in range(1, 6))
    note = "higher is better" if higher_better else "lower is better"
    return (f'<div class="card"><h3>{html.escape(label)}</h3><div class="big num">{fmt(med)}<span class="muted"> / 5 median</span></div>'
            f'<div class="scale">{cells}</div><p class="muted">{total} answers, {note}. Each box: the score, then how many gave it.</p></div>')


def render(testers, s, out_path, min_score, min_yes):
    e = html.escape
    rows = []
    for t in testers:
        sv = t["survey"] or {}
        rows.append("<tr>" + "".join(f'<td class="{"" if i in (0, 7) else "n"}">{c}</td>' for i, c in enumerate([
            e(t["name"]), f'{t["played"]} of {SESSIONS}' + ("" if t["finished"] else " (stopped)"),
            fmt(sum(t["prep_minutes"]), 0) + " min", fmt(median(t["fun"])), str(t["cooks"]) + (f' ({t["callouts"]} called out)' if t["callouts"] else ""),
            fmt(t["level"]), str(t["coming"]) + " of 4", e(", ".join(t["fixed"])) or "-", str(len(t["paid"])),
            " / ".join(fmt(sv.get(k)) for k, _, _ in SCALES), e(sv.get("next") or "-")])) + "</tr>")
    weeks = []
    for w in s["by_week"]:
        weeks.append(f'''<div class="card"><h3>Session {w["week"]}</h3>
<p class="muted">{w["played"]} played. Prep {fmt(w["prep_minutes"])} min, game night {fmt(w["night_minutes"])} min (medians); average Fun {fmt(w["fun"])}.</p>
<p class="muted">Prep felt</p>{dist_bar(w["prep"], PREP_ORDER, ["--c1", "--c2", "--c3"])}{legend(PREP_ORDER, ["--c1", "--c2", "--c3"], w["prep"])}
<p class="muted">Watching it</p>{dist_bar(w["watch"], WATCH_ORDER, ["--c1", "--c2", "--c3"])}{legend(WATCH_ORDER, ["--c1", "--c2", "--c3"], w["watch"])}
</div>''')
    quotes = []
    for key, heading in (("drag", "Where did it drag?"), ("favourite", "Favourite moment")):
        said = [f'<blockquote>{e(t["survey"][key])}<cite>{e(t["name"])}</cite></blockquote>'
                for t in testers if t["survey"] and t["survey"].get(key)]
        if said:
            quotes.append(f'<div><h3>{heading}</h3>{"".join(said)}</div>')
    vclass = "pass" if s["pass"] else ("fail" if s["pass"] is False else "")
    page = f"""<title>Playtest Round</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Lora:wght@600;700&family=Outfit:wght@400;500;600&display=swap">
<style>{CSS}</style>
<main class="wrap">
<header>
  <div class="eyebrow">Behind the Screen &middot; M7 playtest</div>
  <h1>Playtest Round</h1>
  <p class="lede">{s["testers"]} testers, {s["finished"]} of them through all {SESSIONS} sessions, {s["surveys"]} end-of-slice surveys.
  The gate: is writing a session satisfying, and does watching it play out pay off?
  {(str(len(s["tips_off"])) + " turned the first-session tips off.") if s["tips_off"] else ""}</p>
  <div class="verdict {vclass}">{e(s["verdict"])}</div>
  <p class="muted">Pass rule used here: median of {min_score} or more on both, and {round(100 * min_yes)}% or more would play session 5.
  Change it with --min-score and --min-yes.</p>
</header>
<section><h2>The end-of-slice survey</h2>
  <div class="grid survey">{"".join(scale_card(s, k, label, hb) for k, label, hb in SCALES)}
  <div class="card wide"><h3>Would you play session 5?</h3>{dist_bar(s["next"], NEXT_ORDER, ["--c1", "--c2", "--c3"])}{legend(NEXT_ORDER, ["--c1", "--c2", "--c3"], s["next"])}</div>
  </div>
</section>
<section><h2>Session by session</h2>
  <p class="lede">The two quick questions after every session, with prep and game night times.</p>
  <div class="grid weeks">{"".join(weeks)}</div>
</section>
<section><h2>Where it breaks</h2>
  <p class="lede">The weak spots in this round, worst first. If the slice passes, these are the polish list; if not, start here.</p>
  <ul>{"".join(f"<li>{e(b)}</li>" for b in s["breaks"]) or "<li>Nothing stands out.</li>"}</ul>
</section>
<section><h2>In their words</h2><div class="quotes">{"".join(quotes) or '<p class="muted">No written answers yet.</p>'}</div></section>
<section><h2>Every tester</h2>
  <div class="tablewrap"><table>
  <thead><tr><th>Tester</th><th>Sessions</th><th>Prep</th><th>Fun</th><th>Cooked rolls</th><th>Level</th><th>Coming back</th>
  <th>Conflicts settled</th><th>Seeds paid</th><th>Survey (sat / payoff / homework / gut)</th><th>Session 5?</th></tr></thead>
  <tbody>{"".join(rows)}</tbody></table></div>
  <p class="muted">Prep is real minutes on the prep board across the slice; Fun is the median of each night's average; "coming back" counts players whose Commitment ended at 55 or more.</p>
</section>
</main>
"""
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(page)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("paths", nargs="+", help="playtest_log.jsonl files, or folders of them")
    ap.add_argument("--out", help="where to write the report (default: playtest_report.html beside the logs)")
    ap.add_argument("--min-score", type=float, default=4, help="median score that counts as a pass (default 4)")
    ap.add_argument("--min-yes", type=float, default=0.6, help="share who'd play session 5 (default 0.6)")
    args = ap.parse_args()
    files = []
    for p in args.paths:
        if os.path.isdir(p):
            files += sorted(glob.glob(os.path.join(p, "*.jsonl")))
        else:
            files.append(p)
    if not files:
        sys.exit("No .jsonl logs found.")
    testers = analyze(files)
    s = summarize(testers, args.min_score, args.min_yes)
    out = args.out or os.path.join(os.path.dirname(os.path.abspath(files[0])), "playtest_report.html")
    render(testers, s, out, args.min_score, args.min_yes)
    print(f"{s['testers']} testers, {s['finished']} finished the slice, {s['surveys']} surveys")
    for k, label, _ in SCALES:
        print(f"  {label}: median {fmt(s[k])}")
    if s["surveys"]:
        print(f"  Would play session 5: " + ", ".join(f"{k} {s['next'].get(k, 0)}" for k in NEXT_ORDER))
    for w in s["by_week"]:
        print(f"  Session {w['week']}: prep {fmt(w['prep_minutes'])} min; prep felt "
              + ", ".join(f"{k} {w['prep'].get(k, 0)}" for k in PREP_ORDER) + "; watching "
              + ", ".join(f"{k} {w['watch'].get(k, 0)}" for k in WATCH_ORDER))
    print(s["verdict"])
    for b in s["breaks"]:
        print("  - " + b)
    print("wrote " + out)


if __name__ == "__main__":
    main()
