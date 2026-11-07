# Rule sets

Conner, November 6: "every adventure will only use one rule set. However, I think it would be cool to add lots of
different adventures using different rule sets, leveraging our existing game mechanics / systems / features."

The plan stays 5e: the museum, the Sheep Chase and the long campaign. Other systems come as their own adventures, each
in exactly one rule set. The DM simulator is shared: prep hours, reading the table, the friends' thoughts and moods,
Session Zero's lines and veils, secrets and lore, forks, moments, recaps, the journey. A rule set is what changes the
DM's job: what a roll is, who rolls it, what a fight is, what a hero's sheet holds, how heroes grow.

## Step 1: where 5e lives today

**game/rules/ (9,300 lines): already a 5e engine, and it stays one.** The SRD 5.2.1 battle on a 5-foot grid
(battle.lua), the foes' tactics (ai.lua), spells, skills, dice, monsters, rests, encounters, and each adventure's own
monster rules (museum.lua, sheep.lua). Pure Lua, no Defold. This becomes the 5e rule set's engine more or less as it is.

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
| `check(hero, approach, difficulty, edge)` | The roll and its **tier**: great, full, partial, miss, botch. Plus the dice to show and the line to log. | d20 + mod vs DC; 20 great, 1 botch; partial only by the DM's ruling | 2d6 + stat; 10+ full, 7-9 partial, 6- miss |
| `approaches` | What a hero can try, and which hero is best at it | the 18 skills | a handful of moves or stats |
| `who_rolls` | Whether the DM rolls (and can hide it behind the screen) or the players do | DM, open or hidden | players, always in the open |
| `fight` | "tactical" (the grid, game/rules/battle) or "narrative" (a fight is a run of checks, harm and a clock) | tactical | narrative |
| `sheet` | What a hero's sheet holds and shows | class, abilities, skills, HP, AC, slots | stats, moves, harm, a playbook |
| `harm` | What going down is | HP, death saves | harm boxes, a last breath |
| `grow` | How heroes advance | levels, XP | advances, milestones |
| `words` | The glossary and the table's words for it | DC, Advantage, natural 20 | hit, weak hit, miss |

The shared layer reads tiers, never numbers: a scene's win and setback, a split win, fail forward, spotlight and fun,
callbacks ("still riding that last great roll") all key off great / full / partial / miss / botch. The friends'
reactions do too, so every bark, thought and rest beat works in any set.

## The steps

1. **Map it.** This page.
2. **The contract.** The table above, agreed.
3. **The seam, with 5e only.** Adventures get `rules = "5e"`; the nine check sites call `rules.check`; fights, sheets,
   growth and harm go through the set; the dice tray asks the set what to show. *Done when:* seeded playthroughs of
   the museum, the Sheep Chase and the carry come out word for word the same before and after, and the gate passes.
4. **Narrative fights.** A fight without the grid: checks, harm, a clock, the foes' moves as the DM's. Built in the
   shared layer so any non-grid set can use it. *Done when:* a 5e test scene can run its fight either way.
5. **The second set and a one-shot.** A 2d6 "moves" set (our own words, built on the open 10+ / 7-9 / 6- structure)
   and a short original adventure in it, ideally written through the upload pipeline. *Done when:* it plays start to
   end in the sims and the engine, with its own checks in the gate.
6. **The table meets the system.** Session Zero pitches it; each friend has a taste and a familiarity ("we roll two
   dice?"); the DM's prep changes with it (threats and clocks instead of encounters). *Done when:* the friends'
   reactions to the system show up in the transcripts.
7. **Guard it.** A gate check per set, and one that fails if 5e words or d20s turn up in a non-5e adventure, the way
   museum words are kept out of the Sheep Chase.

## Decisions owed

- Step 5's system: a 2d6 moves set (recommended), Forged in the Dark's position and effect, or d100 investigation.
- Heroes across systems: the same four friends always; new characters per one-shot (recommended, like a real table's
  one-shot night), or their usual heroes reimagined.
- Licensing: build on open reference documents only (the 5e SRD, Forged in the Dark, Fate, the Year Zero Engine,
  Basic Roleplaying), checking each licence first.
