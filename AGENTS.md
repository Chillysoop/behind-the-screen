# Working on Behind the Screen

A cozy single-player game where you are the Dungeon Master for four simulated friends. Made in Defold
1.13.2 with Lua. Before changing anything, read:

1. `docs/OVERVIEW.md`: what the game is, the weekly loop, how stories work, how the systems overlap,
   progression, and what's still open.
2. `README.md`: every system in detail, controls, the project layout, and every test.
3. `docs/design/`: notes on changes, including the step-by-step rework that was set aside.

**This branch: `v2-museum` (October 30).** v2 runs a real published adventure, *The Museum of Nightmares* by
Luke Russell (DMs Guild), as a one-shot prologue: Session Zero, why each hero came, then the museum room by room
for as many sessions as it takes, a boss night, and a journey recap. The random story deck, factions, seeds, the
valley map and the campaign planner are switched off while it runs (`campaign.module = "museum"`); the four
friends, Session Zero, the rules engine and game night stay. The design and the feedback behind it are in
`docs/design/2026-10-30-museum-v2.md`. `main` is still the October 20 build; don't merge this into it unless asked.
A longer, full pre-written adventure will follow as the main campaign, through the same adventure format.

Where v2 lives:

| Path | What it holds |
| --- | --- |
| `game/data/museum/module.lua` | The adventure: rooms and the ways between them, knobs, room moments, Euryale's marks, requests, loose ends, favors, the showdown, endings. Every line in our own words. |
| `game/data/museum/cards.lua` | Its places, people, goals, snags and prizes as ordinary cards, plus how the heroes play each goal. |
| `game/model/adventure.lua` | The adventure's state: the map, marks, flags, Francs, the fair-warning bank, hooks, prompts. It also switches the shared content over (`adventure.enter`) and filters out anything from the old story. |
| `game/model/museum_week.lua`, `game/model/museum_night.lua` | The week (prep hours, knobs) and the night (rooms, forks, moments, Euryale's interludes, boss night). |
| `game/ui/museum_*.lua` | The hooks page, the prep board and showdown board, the journey recap. |
| `game/rules/museum.lua` | The museum's monsters' special rules (with the stat blocks in `game/rules/data/monsters.lua`). |

## Where things live

| Path | What it holds |
| --- | --- |
| `game/data/` | All content as plain data: players, cards, scenes, dialogue, seeds, arcs. Safe to tune. |
| `game/model/` | The simulation, engine-free: prep, game night, the friends, the story deck, storylines, saves. |
| `game/rules/` | The SRD 5.2.1 rules engine, engine-free: dice, creatures, battles, spells, encounters. |
| `game/ui/` | The screens, drawn from GUI nodes through `game/ui/kit.lua`. `game/game.gui_script` ties them together. |
| `main/`, `render/`, `materials/`, `assets/` | The 3D table scene. Much of it is generated; see "Generated files". |
| `tools/tests/`, `tools/sim/` | Headless tests and simulations. |

## Ground rules

- **The existing design comes first.** Fit new ideas around what's built and documented. Don't replace a
  system wholesale unless asked.
- **Model and rules code stays engine-free.** No `gui.*`, `go.*` or `msg.*` in `game/model/` or `game/rules/`,
  so the whole campaign can run headless in the tests.
- **No require cycles.** Defold's builder refuses them. When a module needs one that requires it back, use
  `require("game.model.util").lazy("game.ui.other")` and call it at use time.
- **No globals.** Every function and variable is `local` or a field of the module's `M`.
- **Old saves must keep loading.** `game/model/save.lua` migrates them; `tools/tests/save_check.lua` checks it.
- **Generated files are not hand-edited.** Meshes, textures, sprites, fonts, `main/main.collection`,
  `main/props/`, `main/board/`, `main/scene_data.lua` and `game/ui/metrics.lua` come from `tools/*.py`. Change the
  generator and rerun it (README, "Regenerating assets").
- **Player-facing text is plain and warm.** Short sentences and everyday words, no designer jargon.
  Every screen says what it's for.
- **The prototype notice stays.** Every launch opens on "Before you play" (`game/ui/intro_view.lua`) until the
  player clicks Agree. Tests agree to it first (`tools/tests/gui_smoke.lua`, `game/ui/autotest.lua`).
- **The prologue is strictly the book.** Nothing from the Silent Bells (Ilsa, Kessrick, Millbrook, the Kettle...)
  may show while the museum runs: `adventure.foreign` lists the words, `adventure.enter` filters shared lines,
  and the museum tests fail on any that slip through. Never copy the book's text; paraphrase it.

## Checking your work

Any Lua 5.1+ or LuaJIT interpreter runs the tests from the project root. On this branch, before you commit, run at
least:

    for s in 1 2 3 4 5 6 7 8; do lua tools/tests/museum_smoke.lua $s || break; done
                                          # the whole prologue through the real UI against a mock GUI
    for st in careful random careless; do for s in 1 2 3 4; do lua tools/sim/museum.lua $s $st || break; done; done
                                          # the prologue headless, three kinds of DM
                                          # (add "log" after the style to read every line the table hears)
    lua tools/tests/museum_fights.lua     # the museum's fights on the rules engine
    python3 tools/tests/require_check.py  # no require cycles
    python3 tools/validate.py             # every Lua file parses, every resource exists

`tools/tests/gui_smoke.lua` drives the October 20 flow (the planner, backstories, the valley board), which this
branch no longer shows; it isn't expected to pass here.

Then run the checks for the area you touched. The README's "Tuning and tests" section lists each one, for
example:
- `lua tools/sim/slice.lua` for the four-session slice;
- `lua tools/tests/story_check.lua` and `lua tools/tests/chronicle_check.lua` for the story;
- `lua tools/tests/rules_cases.lua` for the rules.

`DUMP_DIR=out lua tools/tests/gui_smoke.lua 1` also writes every screen's nodes, so you can see what a screen shows
without the engine.

## Building

- **In the Defold editor:** open `game.project` and press Ctrl+B.
- **From the command line** (Bob 1.13.2 needs Java 25):

      java -jar bob.jar --root . --platform x86_64-win32 --archive \
          --settings tools/playtest/playtest.ini build bundle

- **Real engine on Linux:** `tools/tests/engine_check.sh` plays the game with Xvfb (it needs `BOB` and `JAVA` set).

## Status

v2's prologue plays end to end through the real UI and headless: every seeded run reaches one of the four
endings in three to five sessions. What's open: bespoke boards and minis for the museum's rooms and monsters
(it borrows the closest existing ones), a free tie-and-lock editor for adventures, the "just the adventure" mode,
and the full campaign that follows the prologue.
