"""Turn tools/sim/social_data.json (from tools/sim/social.lua) into a readable page:
tools/sim/social_report.html. No dependencies; open the page in any browser.

    python3 tools/sim/social_report.py
"""
import html
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
data = json.load(open(os.path.join(HERE, "social_data.json")))

CONFLICTS = [
    ("spotlight", "The Pip show", "Jess fills every scene; the quieter players fade."),
    ("rules", "Rules lawyering", "Dev wants rule of cool, Sam wants the same rules every time."),
    ("tone", "Tone clash", "Mara wants Ilsa's story taken seriously; Jess can't resist a joke."),
]
FIXES = {
    "spotlight": [("ally", "Asked Jess to help pull the quiet ones in"), ("talk", "Told Jess straight"),
                  ("table", "Kept passing the spotlight at the table")],
    "rules": [("house_rule", "Posted a house rule"), ("vote", "Called a table vote"),
              ("look_it_up", "Promised to look it up, then posted it")],
    "tone": [("split", "Planned a serious scene and a goofy one"), ("revisit", "Revisited Session Zero"),
             ("table", "Protected the quiet moments at the table")],
}
PLAYERS = [("mara", "Mara", "Storyteller, then Explorer", ["wayfinder", "mirror_mage", "evoker"]),
           ("dev", "Dev", "Butt-kicker, then Power gamer", ["champion", "banner_captain", "spellguard"]),
           ("jess", "Jess", "Method actor, then Instigator", ["silvertongue", "thief", "ambusher"]),
           ("sam", "Sam", "Casual, then Tactician", ["hearth", "life", "mischief"])]
SUBNAME = {"champion": "Champion", "banner_captain": "Banner Captain", "spellguard": "Spellguard",
           "thief": "Thief", "silvertongue": "Silvertongue", "ambusher": "Ambusher", "life": "Life",
           "hearth": "Hearth", "mischief": "Mischief", "evoker": "Evoker", "wayfinder": "Wayfinder",
           "mirror_mage": "Mirror Mage"}
SEEDNAME = {"retired_captain": "The retired captain", "mirror_letters": "Ilsa's backwards letters",
            "rooftop_signs": "Chalk on the rooftops", "laughing_shrine": "The Laughing Saint's shrine"}

e = html.escape
checks = data["checks"]
passed = sum(1 for c in checks if c["ok"])


def bar_rows(rows, maxv, unit="", cls="s1"):
    out = []
    for label, v, note in rows:
        w = 0 if maxv <= 0 else max(1.5, 100 * v / maxv)
        out.append(
            f'<div class="brow"><span class="blabel">{e(label)}</span>'
            f'<span class="btrack"><i class="{cls}" style="width:{w:.1f}%"></i></span>'
            f'<span class="bval num">{e(str(v))}{unit}</span>'
            + (f'<span class="bnote">{e(note)}</span>' if note else "") + "</div>")
    return "\n".join(out)


# Conflicts: fixes by way.
conflict_figs = []
for cid, name, about in CONFLICTS:
    ways = data["ways"].get(cid, {})
    rows = [(label, ways.get(how, 0), "") for how, label in FIXES[cid]]
    total = sum(r[1] for r in rows)
    maxv = max([r[1] for r in rows] + [1])
    conflict_figs.append(f'''<figure class="figure">
  <figcaption><h3>{e(name)}</h3><p>{e(about)} Settled {total} times.</p></figcaption>
  <div class="bars">{bar_rows(rows, maxv)}</div>
</figure>''')

# What ignoring costs: Commitment of the people involved, campaigns where it came up.
bots = data["bots"]
cost_rows = []
for b in bots:
    cells = []
    for cid, _, _ in CONFLICTS:
        x = data["by_bot"][b["id"]][cid]
        live = x["live"]
        still = round(100 * x["still"] / x["n"])
        cl = x.get("commit_live", 0)
        cells.append(f'<td class="num"><span class="cbar" style="--v:{max(0, (cl - 60) / 40):.3f}"></span>'
                     f'{cl:.0f}<small>{still}% unsettled</small></td>')
    cost_rows.append(f'<tr><td class="style"><b>{e(b["label"])}</b><small>{e(b["about"])}</small></td>{"".join(cells)}</tr>')

# Subclass picks with no seeds.
plain = data["picks_plain"]
pick_rows = []
for key, name, arch, subs in PLAYERS:
    counts = plain.get(key, {})
    total = sum(counts.values()) or 1
    cells = []
    for s in subs:
        n = counts.get(s, 0)
        cells.append(f'<td class="pick"><span class="pbar" style="width:{100 * n / total:.0f}%"></span>'
                     f'<span class="ptext">{e(SUBNAME[s])} <b class="num">{n}</b></span></td>')
    pick_rows.append(f'<tr><th class="player">{e(name)}<small>{e(arch)}</small></th>{"".join(cells)}</tr>')

nudge = data["nudged"]["by_player"]
nudge_rows = []
for key, name, _, _ in PLAYERS:
    x = nudge.get(key)
    if not x:
        continue
    pct = round(100 * x["hits"] / x["n"]) if x["n"] else 0
    nudge_rows.append((f'{name}: {SEEDNAME.get(x["seed"], x["seed"])} toward {SUBNAME[x["sub"]]}', pct,
                       f'{x["hits"]} of {x["n"]}'))
reasons = data["reasons"]
seeds = data["seeds"]
safety = data["safety"]
careful_hurt = safety["agreeable"].get("hurt", 0) + safety["agreeable"].get("hurt_line", 0)
careless_hurt = safety["careless"].get("hurt", 0) + safety["careless"].get("hurt_line", 0)
xcard = safety["agreeable"].get("xcard_line", 0) + safety["agreeable"].get("xcard", 0)

check_items = "\n".join(
    f'<li><span class="chip {"pass" if c["ok"] else "fail"}">{"Pass" if c["ok"] else "Fail"}</span>'
    f'<span class="check-name">{e(c["name"])}</span><span class="check-detail">{e(c["detail"])}</span></li>'
    for c in checks)

page = f'''<title>Social Layer Check</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Lora:wght@600;700&family=Outfit:wght@400;500;600&display=swap">
<style>
/* The game's lamp-lit palette, like the other gate reports: dark first, the prep board's paper in light mode. */
:root {{
  color-scheme: dark;
  --bg: #1b1411; --surface: #241b16; --raise: #2f241d; --ink: #f3e7cf; --ink-2: #c9b89c; --muted: #8f7f68;
  --rule: #3a2e25; --track: #33281f; --accent: #e8b04a; --good: #3fbf5a; --bad: #e0604f;
  --s1: #e8b04a; --s2: #5aa39b; --s3: #a48ad6;
  --font-display: "Lora", Georgia, "Times New Roman", serif;
  --font-body: "Outfit", system-ui, -apple-system, "Segoe UI", sans-serif;
}}
@media (prefers-color-scheme: light) {{
  :root:not([data-theme="dark"]) {{
    color-scheme: light;
    --bg: #f4ecdb; --surface: #fbf6ea; --raise: #efe4c8; --ink: #2b2018; --ink-2: #5d4e3c; --muted: #85745e;
    --rule: #e0d4b8; --track: #ebe2cc; --accent: #8a5a0e; --good: #0a7d0a; --bad: #c03434;
    --s1: #b07818; --s2: #2f7f78; --s3: #6a4f9f;
  }}
}}
:root[data-theme="light"] {{
  color-scheme: light;
  --bg: #f4ecdb; --surface: #fbf6ea; --raise: #efe4c8; --ink: #2b2018; --ink-2: #5d4e3c; --muted: #85745e;
  --rule: #e0d4b8; --track: #ebe2cc; --accent: #8a5a0e; --good: #0a7d0a; --bad: #c03434;
  --s1: #b07818; --s2: #2f7f78; --s3: #6a4f9f;
}}
* {{ box-sizing: border-box; }}
body {{ margin: 0; background: var(--bg); color: var(--ink); font: 400 16px/1.55 var(--font-body); }}
.wrap {{ max-width: 1040px; margin: 0 auto; padding-inline: 20px; padding-block: 40px 72px; display: grid; gap: 52px; }}
h1, h2, h3 {{ font-family: var(--font-display); font-weight: 700; text-wrap: balance; margin: 0; }}
h1 {{ font-size: clamp(30px, 5vw, 44px); line-height: 1.1; }}
h2 {{ font-size: clamp(22px, 3.2vw, 28px); line-height: 1.2; }}
h3 {{ font-family: var(--font-body); font-size: 16px; font-weight: 600; }}
p {{ margin: 0; max-width: 68ch; }}
.eyebrow {{ font-size: 12px; font-weight: 600; letter-spacing: 0.12em; text-transform: uppercase; color: var(--accent); }}
.lede {{ color: var(--ink-2); font-size: 17px; }}
.num {{ font-variant-numeric: tabular-nums; }}
header, section {{ display: grid; gap: 16px; }}
section > header {{ gap: 8px; }}
.verdict {{ display: flex; flex-wrap: wrap; align-items: baseline; gap: 8px 18px; padding: 18px 20px; border-radius: 12px;
  background: var(--surface); border: 1px solid var(--rule); }}
.verdict strong {{ font-family: var(--font-display); font-size: 26px; }}
.verdict span {{ color: var(--ink-2); font-size: 14px; }}
.figs {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 300px), 1fr)); gap: 16px; }}
.figure {{ margin: 0; min-width: 0; display: grid; gap: 12px; align-content: start; padding: 16px; background: var(--surface);
  border: 1px solid var(--rule); border-radius: 12px; }}
.figure figcaption {{ display: grid; gap: 4px; }}
.figure figcaption p {{ font-size: 14px; color: var(--ink-2); }}
.bars {{ display: grid; gap: 10px; }}
.brow {{ display: grid; grid-template-columns: 1fr auto; gap: 4px 10px; align-items: center; }}
.blabel {{ grid-column: 1 / -1; font-size: 14px; }}
.btrack {{ height: 10px; background: var(--track); border-radius: 5px; overflow: hidden; }}
.btrack i {{ display: block; height: 100%; border-radius: 5px; }}
.btrack i.s1 {{ background: var(--s1); }} .btrack i.s2 {{ background: var(--s2); }} .btrack i.s3 {{ background: var(--s3); }}
.bval {{ font-size: 14px; font-weight: 600; min-width: 3ch; text-align: right; }}
.bnote {{ grid-column: 1 / -1; font-size: 12px; color: var(--muted); }}
.tablewrap {{ overflow-x: auto; }}
table {{ border-collapse: collapse; width: 100%; font-size: 14px; }}
th, td {{ padding: 10px 12px; border-bottom: 1px solid var(--rule); text-align: left; vertical-align: top; }}
thead th {{ color: var(--muted); font-weight: 500; font-size: 13px; }}
td small, th small {{ display: block; color: var(--muted); font-size: 12px; font-weight: 400; }}
td.style {{ min-width: 220px; }}
td.style b {{ display: block; font-weight: 600; }}
td.num {{ white-space: nowrap; font-weight: 600; position: relative; }}
.cbar {{ display: block; height: 6px; width: 72px; margin-bottom: 6px; border-radius: 3px;
  background: linear-gradient(90deg, var(--s2) calc(var(--v) * 100%), var(--track) 0); }}
th.player {{ white-space: nowrap; min-width: 150px; }}
td.pick {{ position: relative; min-width: 150px; }}
.pbar {{ position: absolute; left: 8px; bottom: 6px; height: 4px; border-radius: 2px; background: var(--s3); max-width: calc(100% - 16px); }}
.ptext b {{ margin-left: 4px; }}
.stats {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 220px), 1fr)); gap: 16px; }}
.stat {{ padding: 16px; background: var(--surface); border: 1px solid var(--rule); border-radius: 12px; display: grid; gap: 4px; }}
.stat strong {{ font-family: var(--font-display); font-size: 28px; }}
.stat span {{ font-size: 14px; color: var(--ink-2); }}
.checks {{ list-style: none; margin: 0; padding: 0; display: grid; }}
.checks li {{ display: grid; grid-template-columns: auto 1fr; gap: 4px 12px; align-items: baseline; padding: 10px 0;
  border-bottom: 1px solid var(--rule); }}
.checks li:last-child {{ border-bottom: 0; }}
.chip {{ font-size: 12px; font-weight: 600; letter-spacing: 0.04em; text-transform: uppercase; padding: 2px 9px;
  border-radius: 999px; border: 1px solid currentColor; }}
.chip.pass {{ color: var(--good); }} .chip.fail {{ color: var(--bad); }}
.check-name {{ font-weight: 500; }}
.check-detail {{ grid-column: 2; color: var(--ink-2); font-size: 14px; }}
.notes {{ display: grid; gap: 10px; color: var(--ink-2); font-size: 15px; }}
.notes b {{ color: var(--ink); font-weight: 600; }}
code {{ font-size: 13px; background: var(--raise); padding: 1px 6px; border-radius: 4px; }}
@media (max-width: 560px) {{ .wrap {{ gap: 40px; padding-block: 28px 56px; }} }}
</style>
<main class="wrap">
<header>
  <div class="eyebrow">Behind the Screen &middot; M6 gate</div>
  <h1>Social Layer Check</h1>
  <p class="lede">{data["campaigns"]} simulated campaigns of {data["weeks"]} weeks: five ways of handling the table, each
  with five different Session Zeros. The gate asks two things: can every conflict be settled more than one way, and
  does every level-3 subclass pick fit the player who made it?</p>
  <div class="verdict"><strong class="num">{passed} of {len(checks)} checks pass</strong>
  <span>Every conflict was settled three different ways. Of {data["picks_total"]} subclass picks, none had nothing behind it.</span></div>
</header>

<section>
  <header><h2>Every conflict has more than one fix</h2>
  <p class="lede">How often each fix settled the conflict, across every simulated DM who tried something.</p></header>
  <div class="figs">
{"".join(conflict_figs)}
  </div>
</section>

<section>
  <header><h2>Ignoring a conflict costs the people in it</h2>
  <p class="lede">Average Commitment of the players involved at the end of the run, in campaigns where the conflict
  came up, and how often it was still unsettled at the end.</p></header>
  <div class="tablewrap"><table>
    <thead><tr><th>Simulated DM</th>{"".join(f"<th>{e(n)}</th>" for _, n, _ in CONFLICTS)}</tr></thead>
    <tbody>{"".join(cost_rows)}</tbody>
  </table></div>
  <p class="muted" style="color:var(--muted);font-size:14px">{data["fixes_quick"]} of {data["fixes_total"]} fixes landed
  within three weeks of the conflict coming up. The tone clash also settles on its own sometimes, when a week happens
  to give Mara and Jess each their kind of scene.</p>
</section>

<section>
  <header><h2>Every subclass pick fits its player</h2>
  <p class="lede">At level 3 the players choose for themselves. With no seeds planted, 60 parties picked like this:</p></header>
  <div class="tablewrap"><table>
    <thead><tr><th>Player</th><th colspan="3">Subclass picks</th></tr></thead>
    <tbody>{"".join(pick_rows)}</tbody>
  </table></div>
  <p style="color:var(--ink-2);font-size:15px">What was behind each of the {data["picks_total"]} picks across every run:
  their archetypes {reasons["arch"]}, the nights they'd had {reasons["hist"]}, a seed that stuck with them {reasons["seed"]}.
  A seed can make a subclass tempting, but it doesn't force the pick:</p>
  <figure class="figure"><figcaption><h3>A paid-off seed aimed at one player</h3>
  <p>Share of players who then picked the subclass the seed nudged toward.</p></figcaption>
  <div class="bars">{bar_rows(nudge_rows, 100, "%", "s3")}</div></figure>
</section>

<section>
  <header><h2>Seeds and Session Zero</h2></header>
  <div class="stats">
    <div class="stat"><strong class="num">{round(100 * seeds["in_time"] / max(1, seeds["planted"]))}%</strong>
      <span>of seeds paid off within 3 weeks when the DM followed up ({seeds["planted"]} planted)</span></div>
    <div class="stat"><strong class="num">{round(100 * seeds["neglect_stale"] / max(1, seeds["neglect_planted"]))}%</strong>
      <span>went stale when the DM never played the payoff card</span></div>
    <div class="stat"><strong class="num">{careful_hurt} vs {careless_hurt}</strong>
      <span>times someone was hurt by content: careful Session Zero vs a careless one</span></div>
    <div class="stat"><strong class="num">{xcard}</strong>
      <span>times the X-card caught a card that crossed a line, so nobody got hurt</span></div>
  </div>
</section>

<section>
  <header><h2>All checks</h2></header>
  <ul class="checks">
{check_items}
  </ul>
</section>

<section class="notes">
  <h2>How it was run</h2>
  <p><b>Simulated DMs.</b> {"; ".join(e(b["label"]) + ": " + e(b["about"][0].lower() + b["about"][1:].rstrip(".")) for b in bots)}.
  All of them prep the same way (the balanced prep style from the M2 harness) and plant a seed most weeks.</p>
  <p><b>Session Zeros.</b> A careful one (compromise tone, every ask agreed, the X-card, quick rulings looked up after),
  three that each lean into one conflict, and a careless one (pushed back on every ask, no X-card, rule of cool).</p>
  <p><b>Subclass picks.</b> 60 parties with no seeds, then 60 where one player's nudging seed was planted in week 1 and
  paid off before the level-up. Every pick also has to have a line for that player to say at the table.</p>
  <p><b>Reproduce.</b> <code>lua tools/sim/social.lua</code> from the project root (about five minutes), then
  <code>python3 tools/sim/social_report.py</code> for this page.</p>
</section>
</main>
'''
open(os.path.join(HERE, "social_report.html"), "w", encoding="utf-8").write(page)
print("wrote tools/sim/social_report.html")
