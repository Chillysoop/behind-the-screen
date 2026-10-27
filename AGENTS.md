# Working on Behind the Screen

A cozy single-player game where you are the Dungeon Master for four simulated friends. Made in Defold
1.13.2 with Lua. Before changing anything, read:

1. `docs/OVERVIEW.md`: what the game is, the weekly loop, how stories work, how the systems overlap,
   progression, and what's still open.
2. `README.md`: every system in detail, controls, the project layout, and every test.
3. `docs/design/`: notes on the latest changes (the newest is the step-by-step setup and prep, October 26).

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
- **Chill mode is off by default.** With it off, choices show no green or red "who'd like it" faces. The player
  reads the table from what the friends say, think and how they sit. Gate any new "who'd love it" hint behind
  `game/ui/prefs.lua`'s `chill()`.

## Checking your work

Any Lua 5.1+ or LuaJIT interpreter runs the tests from the project root. Before you commit, run at least:

    for s in 1 2 3 4 5 6; do lua tools/tests/gui_smoke.lua $s || break; done
                                          # the whole slice through the real UI against a mock GUI
                                          # (seeds 1-4: a full table, 5-6: a small one)
    python3 tools/tests/require_check.py  # no require cycles
    python3 tools/validate.py             # every Lua file parses, every resource exists

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

The vertical slice (Session Zero plus four sessions) plays end to end. "Where it stands, and what's still open" in
`docs/OVERVIEW.md` lists what simulated playtests found and the open design questions. The weakest area right now
is the story the game plays back to the DM between sessions.
