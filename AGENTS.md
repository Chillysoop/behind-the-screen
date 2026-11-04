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
**Before starting it, read `docs/design/longer-adventure-notes.md`:** the November 2 playtest feedback on cause
and effect, what to build first (one event log, one shape for conditional text, the truth test as the gate), what's
still open from the museum, and a checklist.

Where v2 lives:

| Path | What it holds |
| --- | --- |
| `game/data/museum/module.lua` | The adventure: rooms, the doors between them (`links`), what a second look can still find, knobs, room moments, Euryale's marks, requests, loose ends, favors, the showdown, endings. Every line in our own words. |
| `game/data/museum/cards.lua` | Its places, people, goals, snags and prizes as ordinary cards, plus how the heroes play each goal. |
| `game/model/adventure.lua` | The adventure's state: the map, marks, flags, Francs, hooks, prompts. It also switches the shared content over (`adventure.enter`) and filters out anything from the old story. |
| `game/model/museum_week.lua`, `game/model/museum_night.lua` | The week (prep hours, knobs) and the night (rooms, forks where the table picks the way, trips back with a reason, side rooms, moments, Euryale's interludes, boss night). |
| `game/model/thoughts.lua`, `game/data/thoughts.lua` | What the four friends think and don't say on game night (a want that's nagging them, their take on a call, the week they've had, a roll that looked convenient, Pip's plan to go off alone): how many the DM catches is their Empathy. A caught thought shows only a tell until the DM reads it with an Insight roll (`thoughts.read`: d20 + Empathy + familiarity against the thought's dc and how hard that friend is to read; clear, gist, miss then ask, or a misread on a 1, on its own dice). Each has two answers and "Let it be". The night director calls in at its beats; `game/ui/night_view.lua` draws the cloud over the panel and the card, and calls `thoughts.read`/`ask`/`respond` between beats. |
| `game/model/standing.lua`, `game/ui/recap_view.lua` | The DM's recap on game night: the Story sidebar (top left: the adventure's sides from `MODULE.sides`, each person's line now, who at the table is drawn to them) and the Table sidebar (top right: each friend's reason for coming and whether it's paid off, what they love, who they're drawn to or put off by, how they seem tonight, the last thought you read, how well you know them). Story and Table buttons in the top bar, S for both; the night waits while one is open. Affinity: the kinds of player a person appeals to (`likes`), the hero whose reason is in their room, and the moments since (`standing.note`, from `museum_night.play_moment`). |
| `game/model/familiar.lua` | How well the DM knows each friend ("New to you" to "Like a book"): grows with nights together, clear reads, answers that land and prep talks; a bonus on reading their thoughts. Shown as dots on the prep board's player cards. The first piece of a fuller you-as-a-DM progression. |
| `game/model/map_repo.lua`, `game/ui/map_repo_view.lua` | The map repository: every map the DM can put on the table; a room's map, side rooms, the next scene's map, the DM's own maps (edited in `game/ui/map_view.lua`). |
| `game/model/ties.lua`, `game/ui/ties_view.lua` | The tie-and-lock editor ("Ties and locks" on the prep board): lock a door or a room until something happens, a moment (only if, or cut), a person (out of sight until: their moments skip, their room plays without them); tie a mark on Euryale's card, or a hero's reason for coming moving room, to something happening. Conditions: a room done, a card's out (by its words: `MODULE.outs`, or its aspect), a mark, Francs, a session. Refuses a lock that could never open or could leave the lair out of reach. The state is `campaign.adv.locks` / `.ties` / `.hook_room`; `adventure.lua`'s walking reads the locks, `museum_night.ties_beat` opens and fires them on game night. Generic over the module's data. |
| `game/ui/museum_*.lua` | The hooks page, the prep board (the museum as the book's floor plans) and showdown board, the journey recap. |
| `tools/maps/`, `game/data/maps/*.map`, `game/data/map_library.lua` | The map import pipeline (`tools/maps/README.md`): a book's map image to a draft, a draft to a hand-finished `.map` spec, specs built into the map library, which `game/data/boards.lua` merges into its boards. The museum's ten rooms are specs here; `game/data/terrain.lua` points the `mus_*` places at them. Never copy a book's art or text: our pieces, our words. |
| `game/rules/museum.lua` | The museum's monsters' special rules (with the stat blocks in `game/rules/data/monsters.lua`). |
| `game/ui/edit_guard.lua` | Cancel on the DM's menus (November 3): a menu takes a copy of what it can change when it opens; its X (or Esc) puts it back, asking "Throw away your changes?" only when something really changed. Used by the map repository and the ties editor. |
| `game/model/tile_stats.lua`, `game/ui/panels.lua` | The player tiles' numbers (November 3): HP and AC always, and the class's own resources as pips (spell slots, Channel Divinity, Second Wind, Action Surge) with hovers. Who's speaking lights their tile and their mini's outline (`main/people/*_outline.sprite`, `materials/outline.*`): gold in character, blue out of character, purple thinking. |
| `game/model/museum_night.lua` (`table_pick`, `fork`, `whats_there`) | Player choices are the players' (November 3): a party moment (`party = true`, each option's `want`) is talked over and settled by the table from their stats, and the DM can only nudge when asked; the same for where to go next. After they pick, the DM decides what's there (the book's room, improvised, or another prepped encounter moved in). |
| `game/model/museum_night.lua` (`explore`, `drag`, `hand_off`, `drops_*`), `MODULE.explore` | Looking around (November 3): before a room's business (after its fight, in a fight room) the friends take turns walking over to places on its board (`map_library` `places`) and say what they make of them. A find or a trap there (`MODULE.explore`) is the DM's call behind the screen, gated by the night's call budget. Moments with a `spot` walk their hero there; `mus.drag` pulls a mini into a feature and back. A magic item goes to whoever'll use it best (`hand_off`). |
| `game/model/npcs.lua`, `game/ui/npc_view.lua`, `MODULE.npc_sheet` | People's sheets (November 3): their name in any line is a clickable word (gloss.lua's people terms, `kit.on_click` on a spot with `on_click`); the sheet shows who they are, their line now (standing.lua), their stat block, and what the DM put in their pockets (`campaign.adv.drops`) with how the party gets it: beaten (falls out after the fight), pickpocket or ask (a player's idea from their stats; the DM rules). |
| `game/model/loot.lua`, `game/ui/rewards_view.lua` | The dice box after a session (November 3): earned from how the night went, opened before the report, rarities common to mythic (`game/data/dice.lua`). |
| `game/model/fight.lua` (`wake`), `main/board/board.script` (`lift`) | Pieces that come alive (November 3): a room's `wake = { feature, at }` puts each foe on the square of the piece it was, opens that square, and the board lifts the piece off (and keeps it off on the report's replay). |
| `game/ui/saves_view.lua` | Saving and loading (November 3): the autosave (the museum's own file, `museum_save.txt`) and three slots of your own (`museum_slot1..3.txt`). The title is Continue (the newest save), Load, New game; Save is on the prep board and the report. A save's header carries when it was made and where the story stood (`save.dump(c, meta)`, `save.peek`). |
| `game/model/barks.lua`, `game/data/barks.lua` | Fight barks that fit the moment (November 3): a line is checked against what just happened (`fits`: "natural twenty" needs a 20, "who's next" needs foes left), and lines are made from the moment in each friend's voice (`made`: the foe, the weapon, how many are left). The DM's word on a round of only walking, and on a charmed hero who won't attack. `night:fresh(list, key)` now remembers across weeks. |
| `game/ui/battle_hud.lua`, `main/fx/ring.*`, `tools/gen_ring.py` | Status rings on the mat (November 3): a coloured ring around a mini's base for the effect that matters most on it (charmed, turning to stone, frightened...), its tag under the health bar in the same colour, with a hover. |
| `game/model/warnings.lua` | Fair warning (November 4): a warning is about a thing (`campaign.adv.warned[key]`, keyed by the moment it's about), given by the DM (told, or "Are you sure?": `museum_night.warn_step` on a card with `danger`), asked for in the chat (`mus.warn`, a string keys it to another moment), or known from an option (`mus.risk`). A harsh outcome asks `warnings.judge`: warned, a die rolled in the open, or a table that agreed to brutal (Session Zero's `harsh` rule) lands as fair; otherwise Trust drops. More than `TOO_MANY` warnings a night drains the suspense. |
| `game/model/sight.lua` | Line of sight on a room's board (November 4): walls and closed doors block it; `walk` paths minis round walls and opens doors on the way; NPCs and foes (`cast.visible`) stand on the mat only once a party mini can see them (`night:come_into_view`), and a fight starts with the minis where they stand (`night.mini_pos`). |
| `game/model/companions.lua`, `MODULE.companions` | Who comes along (November 4): a pet in a pocket (Exhibit B: helps its owner look round, has lines) or a person (Telpur: a `monster` stat block, in initiative with a mini, played by its friend, or by a player whose hero fell: `night.pilots`). Join from a chat answer (`companion`, `companion_find`) or a story flag (`joins.flag`). |
| `game/model/death.lua` (`after_fall`), `night_view` `dying` | Down and dead (November 4): the death-save card over the mat shows each save; a hero who dies stays at the table, and their friend picks how to play on (`fallen_seat`: pilot a companion, run the monsters, watch). |
| `game/model/museum_night.lua` (`maybe_break`) | The break (November 4): every night takes one around a third of the way in (or before the lair); the DM picks what the heroes do meanwhile: nothing, a short rest, a long rest where the room allows it, or research (+2 on the next related roll). |
| `game/ui/night_view.lua` (speed, roll banner, `VOICE`, `become`, `draw_replay_hud`) | Game night's controls and readouts (November 4): Pause / 1x / 2x / 4x top right; a roll's total big over the roller; caption tags for who you're talking to; a player speaking in character turns into their hero (`main/people/person.script` `become`); inspiration offered on a big moment and given from the tile's button; the report's Look replays fights with health bars and acts. Moods carry over between weeks (`score.start_carry`). |
| `game/model/table_life.lua`, `MODULE.table_life` | Table life (November 4): small moments that play themselves in a room's quiet stretch (after the look round, or after its fight): a friend pokes at a curio on the board (`curios`: the book's room features in our words, or invented where the book is thin), a small die rolls on its own (`tiny_roll` event, drawn small over the tile), and the DM answers dull, detail or lore by the total; questions for whoever's in the room (`npc_questions`), and table bits (a snack, a cantrip, a souvenir, haggling with Telpur for real Francs). Only a natural 20 or 1 makes a card (`tl_crit`, the harmless answer first), and only with small-moment crits on (`campaign.small_crits`, the toggle under End session). Caps: `PER_ROOM`, `PER_NIGHT`; none at 4x (`night.fast`), one at 2x; each curio once a prologue (`adv.tl_seen`). `tools/tests/table_life_check.lua`. |

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
  `require("game.model.util").lazy("game.ui.other")` and call it at use time. The builder only packs modules
  a script reaches through a literal `require "x"`, so a module reached only through `lazy` must also be
  required literally somewhere (`game/game.gui_script` does it for `game.model.museum_night`), or the
  built game stops with "module not found". `tools/tests/require_check.py` checks both.
- **No globals.** Every function and variable is `local` or a field of the module's `M`.
- **Old saves must keep loading.** `game/model/save.lua` migrates them; `tools/tests/save_check.lua` checks it.
- **Generated files are not hand-edited.** Meshes, textures, sprites, fonts, `main/main.collection`,
  `main/props/`, `main/board/`, `main/scene_data.lua` and `game/ui/metrics.lua` come from `tools/*.py`. Change the
  generator and rerun it (README, "Regenerating assets").
- **Player-facing text is plain and warm.** Short sentences and everyday words, no designer jargon.
  Every screen says what it's for. Every game word on screen explains itself on hover: the glossary
  (`game/data/rules_glossary.lua`, plus an adventure's own `MODULE.glossary`) is on for every screen by
  default (`kit.gloss_default`); speech and the chat turn it off (`gloss = false`).
- **The prototype notice stays.** Every launch opens on "Before you play" (`game/ui/intro_view.lua`) until the
  player clicks Agree. Tests agree to it first (`tools/tests/gui_smoke.lua`, `game/ui/autotest.lua`).
- **Say only what's true (November 2, `docs/design/2026-11-02-cause-and-effect.md`).** A line that asserts
  an outcome reads it from state or carries a condition (`when`, `text_if`, `read_if`, `line_if`, `win_if`).
  Every flag set is read by something, every mark changes boss night, a log that hurts someone hurts them
  (`mus.hurt`), and anything picked up works later (`MODULE.items`). One system owns each beat (a prize,
  an ending, a death); the rest record. The truth test fails otherwise.
- **The adventure owns its fiction.** Session Zero's pitch and asks, the prep notes, the people's memory,
  the gifts, the recap's words and its magic items come from the module (`MODULE.session_zero`, `content`,
  `prep_notes`, `memory`, `talk`, `keepsakes`, `recap_beats`, `magic_items`); shared systems fall back to
  neutral words, never another story's.
- **The prologue is strictly the book.** Nothing from the Silent Bells (Ilsa, Kessrick, Millbrook, the Kettle...)
  may show while the museum runs: `adventure.foreign` lists the old names and `game/data/fiction_words.lua` the
  old world's places, people, creatures and callbacks (`adventure.fits`); `adventure.enter` filters shared lines,
  and the museum tests fail on any that slip through. Never copy the book's text; paraphrase it.

## Checking your work

Any Lua 5.1+ or LuaJIT interpreter runs the tests from the project root. On this branch, before you commit, run at
least:

    for s in 1 2 3 4 5 6 7 8; do lua tools/tests/museum_smoke.lua $s || break; done
                                          # the whole prologue through the real UI against a mock GUI
    for st in careful random careless; do for s in 1 2 3 4; do lua tools/sim/museum.lua $s $st || break; done; done
                                          # the prologue headless, three kinds of DM
                                          # (add "log" after the style to read every line the table hears)
    lua tools/tests/map_repo_check.lua    # the map repository and the open floors
    lua tools/tests/museum_truth.lua      # cause and effect: every flag read, every mark does something, logs
                                          # that promise an effect have it, whole prologues against what's said
    lua tools/tests/thoughts_check.lua    # the friends' thoughts: lines, answers, Empathy, whole prologues
    lua tools/tests/standing_check.lua    # the DM's recap: sides, people's lines, who's drawn to whom, the Table rows
    lua tools/tests/ties_check.lua        # ties and locks: block and open, refusals, a tied mark, saves, whole prologues
    lua tools/tests/barks_check.lua       # fight barks fit the moment; a handed-off killing blow is told, not re-swung
    GLOSS_AUDIT=1 lua tools/tests/museum_smoke.lua 1   # every game word on screen has a hover (tools/tests/gloss_words.lua)
    python3 tools/maps/build_maps.py --check  # every map spec builds: on the mat, starts free, walls closed
    lua tools/tests/museum_fights.lua     # the museum's monsters on the rules engine (about 80s)
    lua tools/tests/rules_cases.lua       # hand-checked rules, the museum's monsters among them
    lua tools/tests/save_check.lua        # saves load back, mid-prologue too
    lua tools/tests/playtest_nov3_check.lua 8   # the November 3 notes, played: whole prologues, each fix seen in play
    lua tools/tests/table_life_check.lua  # small moments: they happen, never in fights or at 4x, crit cards only when on
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
  On this branch, `MODES=8 TIMEOUT=2500 tools/tests/engine_check.sh out` plays the whole prologue and screenshots
  each screen into `out`.

## Status

v2's prologue plays end to end through the real UI, the real engine and headless: every seeded run reaches an
ending in three to five sessions, and the fights use the book's own monsters (`game/rules/museum.lua`). Every room
plays on its own board drawn from the book's maps (`tools/maps/`). What's open: the museum's own monster minis (it
borrows the closest existing ones), the "just the adventure" mode, and the full campaign that follows the prologue.
The tie-and-lock editor is in (`game/model/ties.lua`); the museum sim (`tools/sim/museum.lua`) plays without locks.
