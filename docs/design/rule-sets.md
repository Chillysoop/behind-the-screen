# Rule sets

Conner, November 6: "every adventure will only use one rule set. However, I think it would be cool to add lots of
different adventures using different rule sets, leveraging our existing game mechanics / systems / features."

The plan stays 5e: the museum, the Sheep Chase and the long campaign. Other systems come as their own adventures, each
in exactly one rule set. The DM simulator is shared: prep hours, reading the table, the friends' thoughts and moods,
Session Zero's lines and veils, secrets and lore, forks, moments, recaps, the journey. A rule set is what changes the
DM's job: what a roll is, who rolls it, what a fight is, what a hero's sheet holds, how heroes grow.

## Shared toolkits: the table's, any system's

Conner, November 6: "Other systems should also be able to use maps and grids and d20s and all types of dice." What's
on a real table belongs to no system. Every rule set may use any of it; what a set owns is its rules on top.

| Toolkit | What it is | Where |
|---|---|---|
| **Dice** | Any die and any way of rolling it: d4 to d100, sums and modifiers, keep highest or lowest (Advantage is "2d20kh1"), exploding dice, Fate dice, pools that count successes. A roll says its own faces, so the tray and the log show the dice that were really rolled. | game/kit/dice.lua (built; tools/tests/dice_kit_check.lua) |
| **Maps** | The map repository, the room boards and the three layers (region, settlement, battle), with their DM and player views. | game/model/map_repo.lua, maps.lua, game/data/maps (already shared) |
| **Grids** | Squares on a board: distance (the board's own square size and diagonal rule), who stands where, the edges, straight lines, line of sight past walls and doors, light and its sources, doors opening. Any set's fight can be on the grid, with its own combat rules on it; 5e's battle stands on it and adds attacks, cover, torches and Darkvision. | game/kit/grid.lua (built; tools/tests/grid_kit_check.lua). Still to join it: the walking minis' sight and paths (game/model/sight.lua) |
| **Clocks and tokens** | Countdowns (Noke's men), progress clocks, tokens handed to a player (inspiration's chip, a hold). | game/model/adventure.lua's clocks; the tokens on the tiles |

A rule set picks from the kit: its dice ("1d20" for 5e's checks, "2d6" for a moves set, "1d100" for d100), whether
its fights are on the grid, and its square size. The words "d20", "grid" or "roll" are the kit's, not a system's:
shared text says the dice the roll used ("You roll the d20 behind your screen" comes from the roll, never fixed).

## No leaks: the first rule

Conner, November 6: "It's critical that systems never leak into another system." Not a check at the end: every step
below builds to it, and the build fails when it's broken.

1. **Nothing defaults.** An adventure names its rule set (`rules`), and the game won't run one that doesn't
   (game/model/ruleset.lua). There is no "5e unless it says otherwise".
2. **A system owns its rules, and only it reaches them.** Its rules, its data and its words live with the set
   (game/rules/sets/<id>, and 5e's engine in game/rules/). The shared game (game/model, game/ui) never requires a
   system's rules: it asks the current set, through ruleset.current(). The toolkits (dice, maps, grids, clocks)
   are everyone's, and any set or shared module uses them directly.
3. **Shared content is neutral or tagged.** A thought, bark, rest scene, ruling, glossary entry, DM's bag item or
   keepsake either says nothing about any system's rules, or carries `rules = "<id>"` and only ever shows in that
   set's adventures. A tagged thing in another set's adventure is a validation error, not a quiet skip.
4. **Hand-offs carry the table, not the system.** From one adventure to another in a different set, the friends, their
   memories, their moods and the table's lines and veils come along; items, sheets, levels, spells, money and
   anything else with rules in it never do. The heroes are new characters in the new system. (Within one set, the
   carry works as it does now.)
5. **Saves know their set.** A save records its rule set, and loading it into an adventure of another set is refused.
6. **Fences, in the gate:**
   - *Word fence:* each set lists its own words (`owns`; 5e: DC, Advantage, natural 20, spell slot, hit points,
     saving throw, Heroic Inspiration...). Every seeded playthrough of another set's adventure fails on any word
     that set doesn't own too, the way museum words are kept out of the Sheep Chase. Two sets that both roll d20s
     both say "d20": the dice are the kit's.
   - *Require fence:* a shared module that requires a system's engine directly fails the build.
   - *Data fence:* validation fails on content tagged for a set other than the adventure's, and on an adventure
     without a `rules` field.
   - *Hand-off fence:* a carry between sets that brings an item, a sheet, a level or a spell fails.

## Step 1: where 5e lives today

**game/rules/ (9,300 lines): already a 5e engine, with the table's toolkits mixed in.** The SRD 5.2.1 battle on a
5-foot grid (battle.lua), the foes' tactics (ai.lua), spells, skills, dice, monsters, rests, encounters, and each
adventure's own monster rules (museum.lua, sheep.lua). Pure Lua, no Defold. It becomes the 5e rule set's engine more
or less as it is, once the toolkits come out of it: the dice (dice.lua was already general; game/kit/dice.lua is the
shared one now) and the grid (positions, movement, sight, doors and reach, inside battle.lua with 5e's attacks).

**The leaks: 5e in the shared layer.** These are what the seam moves behind the rule set.

| Where | What's 5e about it |
|---|---|
| night.lua | The check, written out in full in three places (a scene's goal, a stunt, the DM's own roll from the dice tray): d20 + modifier against a DC, natural 20 and 1, Advantage from an item, Heroic Inspiration's reroll. `mod_for` reads 5e skills. |
| museum_night.lua, takeover.lua, ideas.lua, table_life.lua | Six more d20 rolls of their own (a lore dig, a side roll, the takeover's talk, an idea's test, a table moment). |
| fight.lua | Calls the battle, the AI, spells and monsters directly: a fight is always the grid. |
| sheet.lua, progression.lua, death.lua | A hero is a 5e sheet (class, ability scores, skills, HP, AC, spell slots); growth is levels and XP; going down is death saves. |
| items.lua, dm_bag.lua, loot.lua | +1 weapons, Advantage items, potions in HP. |
| data/decisions.lua, data/rulings.lua | Most rulings are any DM's (split the win, fail forward), but some are 5e's own: death saves in the open, Bless stacking, a boss's crit. |
| data/rules_glossary.lua, barks, told | The words: DC, Advantage, Heroic Inspiration, "rolls a natural 20". |
| UI: night_view (dice tray), sheet_view, levelup_view, battle_hud | A d20 to roll in the open or behind the screen; the 5e sheet; the level-up screen; the battle board's HP and turns. |

**Adventure data is 5e data, and that's fine.** About 100 DCs, 270 skill names, stat blocks, levels and XP in the
museum and the Sheep Chase. Each adventure declares its rule set and is written in that set's terms; nothing in an
adventure's data needs translating.

## Step 2: what a rule set provides

One module per rule set (game/rules/sets/<id>.lua), picked by the adventure's `rules` field (default "5e"). The shared
layer only ever asks it these things.

| Hook | What it answers | 5e | A 2d6 "moves" set |
|---|---|---|---|
| `check(rng, {mod, dc, edge})` | The roll and its **tier**: triumph, success, near, flop. Plus the dice to show and the line to log. | d20 + mod vs DC; a natural 20 or 5 over is a triumph, a natural 1 or 5 under a flop, a smaller miss near | 2d6 + stat; 12+ triumph, 10+ success, 7-9 near (the "yes, but"), 6- flop |
| `approaches` | What a hero can try, and which hero is best at it | the 18 skills | a handful of moves or stats |
| `who_rolls` | Whether the DM rolls (and can hide it behind the screen) or the players do | DM, open or hidden | players, always in the open |
| `dice` | The dice its rolls use, from the kit | "1d20" (Advantage "2d20kh1") | "2d6" |
| `fight` | On the grid (the shared grid, with the set's own combat rules) or told as story (a run of checks, harm and a clock). Any set can have either, or both. | on the grid, SRD 5.2.1 combat | told as story, or on the grid |
| `sheet` | What a hero's sheet holds and shows | class, abilities, skills, HP, AC, slots | stats, moves, harm, a playbook |
| `harm` | What going down is | HP, death saves | harm boxes, a last breath |
| `grow` | How heroes advance | levels, XP | advances, milestones |
| `words` | The glossary and the table's words for it | DC, Advantage, natural 20 | hit, weak hit, miss |

The shared layer reads tiers, never numbers: a scene's win and setback, a split win, fail forward, spotlight and fun,
callbacks ("still riding that last great roll") all key off triumph / success / near / flop, the words the DM's
rulings already used (game/data/rulings.lua). The friends'
reactions do too, so every bark, thought and rest beat works in any set.

## The steps

1. **Map it.** This page.
2. **The contract.** The table above, agreed.
3. **The seam, with 5e only.** Adventures name `rules = "5e"`; the nine check sites call the set's `check`; fights,
   sheets, growth and harm go through the set; the dice tray shows the dice the roll used. The toolkits come out
   of game/rules into game/kit: the dice (done), then the grid out of battle.lua, so another set's fight can stand on
   it with its own rules. Everything 5e in the shared
   layer is either moved behind the set or tagged `rules = "5e"`, and the require, data and hand-off fences go in now
   (they pass with one set; they're there before the second arrives). *Done when:* seeded playthroughs of the
   museum, the Sheep Chase and the carry come out word for word the same before and after, and the gate passes.
   **Built, November 7.** How a set's things are kept to it, for whoever adds the next set:
   - *A set's module* (game/rules/sets/<id>.lua) holds its die (`dice`: notation, name, icon), `check`, `tier`,
     `odds_line`, its approaches (`mod`, `name`), `words` (everything the shared game says in its terms: "DC",
     "Heroic Inspiration", rests, the tiles' hovers, the recap's crit lines...), `owns` (its words, for the fence),
     `rule_terms`, `scene_dc`, `difficulty_names`, `piece_rules` and `engine` (its parts, loaded on first use).
   - *The shared game asks the current set* (game/model/ruleset.lua): `ruleset.current()`, `ruleset.part("battle")`
     (a stand-in that looks the part up at the moment it's used), `ruleset.engine(name)`, `ruleset.fits(record)`.
     Screens a set brings of its own go through game/ui/sets.lua (`sets.part`, `sets.screen`).
   - *A set's own file in the shared folders* starts with `-- rules: 5e` (the grid fight, the sheet, the tiles'
     stats, levels, the fight's steps on the board, the battle panel, the level-up, the hero's sheet); a line of
     shared code that's only about one set's things ends with `-- rules: 5e`.
   - *A set's content in shared data* carries `rules = "5e"`: a record (a decision card, a glossary term, a bag
     thing, a dialogue line or moment, a bark), or a list of lines (fight moments told). Its picker keeps to the
     adventure's set (`ruleset.fits`).
   - *The table's own* (the DM's read of a friend, dice jail, the DM's craft, the friends' moods) names no set's
     words; the DM's read rolls the table's die (`thoughts.READ_DICE`).
4. **Fights both ways.** Told as story: checks, harm, a clock, the foes' moves as the DM's. On the grid: the shared
   grid with a set's own combat rules (5e's is the first). Both in the shared layer, so any set can have either.
   *Done when:* a 5e test scene can run its fight either way, and a test set fights on the grid with rules of its own.
   **Built, November 7.** A scene's `fight_mode = "story"` (or a set whose `fight` is "story") plays its fight with
   game/model/story_fight.lua: each hero at hand says what they go for, rolls the set's check against the set's
   number for the scene (`scene_dc`), and the tier moves a clock (4 to 6 marks by how hard the scene is) or costs
   the hero a hit (two and they're out of it); it's logged like any fight, so the report, the recap and the journey
   tell it. The set says which approaches count in a story fight (`story_approaches`). The shared grid has the way
   round walls (`path`). tools/tests/fixtures/skirmish_set.lua is a second set for the tests (2d6, its own stats,
   three harm and you're out) whose grid fight stands on game/kit/grid with none of 5e loaded;
   tools/tests/rule_sets_check.lua plays it, a story fight under it, and whole Sheep Chases with the yard and the
   bedroom told as story (`STORY_ROOMS=compound,bedroom` on the sim).
5. **The second set and a one-shot.** *Done when:* it plays start to end in the sims and the engine, with its own
   checks in the gate. **Built, November 7, with Death in Space** (Conner uploaded the core rules and its starting
   adventure, for private playtesting) instead of a 2d6 set of our own:
   - *The set* (game/rules/sets/dis.lua): a d20 and one of four abilities (Body, Dexterity, Savvy, Tech) against 12,
     always (`fixed_dc`: how hard a thing is shows as advantage or disadvantage, never a moved number); a miss gives a
     void point, four at most, and a player spends one for advantage on a roll that matters (`edge`), at the risk of a
     mark if it still misses (`after_check`). The table's ways of trying things (its stock moves name 5e's skills) map
     to the abilities (`approach`). No inspiration token, no levels, fights told as story (`fight = "story"`, harder:
     `story_marks`). Its engine parts are its own (game/rules/dis/: party, progression, tile_stats), and so are its
     screens (game/ui/sheet_view_dis.lua; game/ui/battle_hud_none.lua, a HUD with nothing on the mat).
   - *The adventure* (game/data/ring/): Welcome to the Ring on Aurum 80, in our words with the book's pages. Four new
     characters, one per friend, by the book's steps (an adventure's `heroes` with `char`, `class_name`, `pronouns`,
     `mini`, `sheet` and the rest replace the friends' usual heroes while it runs), and their hub, the Brittle Star,
     by the hub steps (`M.hub`, its own board game/data/maps/ring_hub.map and minis tools/gen_sprites_ring.py).
   - *What the sweep moved:* board placement out of 5e's fight (game/model/placement.lua), the secrets' usual ways out
     by set (`secret_defaults`), the bag's books tagged 5e, rests and hurts said without hit points for a set whose
     fights are told, `ruleset.has` for a screen that shows a part only when the set has one, `goal.win_sets`.
6. **The table meets the system.** Session Zero pitches it; each friend has a taste and a familiarity ("we roll two
   dice?"); the DM's prep changes with it (threats and clocks instead of encounters). *Done when:* the friends'
   reactions to the system show up in the transcripts.
7. **Guard it.** The word fence runs both ways from the day the second set lands (no 5e words in its adventure, none
   of its words in a 5e one), and every set brings its own checks to the gate.
   **Built, November 7:** tools/tests/set_words_check.lua reads what a playthrough says to the table and fails on any
   word another set owns; the gate runs it on Death in Space's sims and on 5e's, with the ring's schema, secrets,
   copy check against the book, sims and engine smokes.

## Decisions owed

- Step 5's system: settled, Death in Space (Conner, November 7). A set of our own can still come later.
- Heroes across systems: the same four friends always, with new characters per one-shot (like a real table's
  one-shot night). Reimagining their usual heroes would mean carrying them between systems, which the no-leaks rule
  allows only as a name and a story, never their stats or kit.
- Licensing: build on open reference documents only (the 5e SRD, Forged in the Dark, Fate, the Year Zero Engine,
  Basic Roleplaying), checking each licence first.
