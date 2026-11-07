## Batch B is done

All four items in ROUND3.md section B are fixed, plus the two engine-review findings you sent mid-task (item 1: the reward's number and currency; item 16: the dice). Everything is on branch **r3-world**, 6 commits from e691363 to **1c4e93e**, pushed. The full gate passes.

**The new check:** `tools/tests/round3_world_check.lua [first last]`. It plays seeds 31 to 38 with all three DM styles exactly as `tools/sim/museum.lua` does. I confirmed its transcript matches `playlogs3/prologue_31_careful.txt` line for line on e691363, so every finding is checked in the run the review read. It counts failures by part, and `ALL=1` lists them all. Targeted cases run after the prologues so the runs stay sim-exact.

**How I confirmed the checks fail on old code:** I copied the check into a throwaway `git worktree` at e691363 (since removed) and ran it there. Results: B1 79 failures, B2 95, B3 173, B4 141. On the branch: 0 failures.

**Who owns each fact now:**
- **The event log** (`events.lua`) holds a moment's backers and what came out of the painting. It also logs every Franc found (now including ruling Francs and small-moment finds), every spend, and the new kinds `pocket` and `promise`.
- **The inventory** (`items.lua`) holds every pickup.
- `people.knows_of` can now also filter a theft by whether it succeeded or was caught (new `outcome` field).

### B1. One owner per action
- **Lock card** (31, 34, 35, 38 careful; 31, 33, 38 random).
  - Cause: the follow-up card re-picked its hero (owed spotlight or the big-roll share). Also, whoever happened to lead the vote knelt, even a wizard.
  - Fix: the follow-up keeps its hero. Whoever is best with picks among those who voted for it kneels.
  - Files: `museum_night.lua` (`then_moment`, the option's `best`), module.lua.
- **Telpur's voice** credited to a hero in the chain. Cause: the beat said `{char}`. The beat now says the table cried laughing.
- **Praise lines.**
  - "X's plan, Y's timing" now needs the room's last settled choice to have been X's, carried out by Y, with no failed roll. It reads the backers from the log (`friction.lua` `needs_plan`, `night.lua` `bond_act`).
  - "A move together": a Graze (a miss that still does damage) no longer counts as a hit (`fight.record`).
- **Painted weapon.** It's one weapon, named, held by whoever pulled it out (the card's new `owner` field, from the log). If that hero voted against what the table settled, someone who backed it does it, as the established F18 rule requires.
- **Notes and notebook.**
  - The table hears who picks up the Lecturer's notes (the best reader there) and the archivist's notebook (whoever took the second study in).
  - At the ultimatum, whoever carries the pages hands Euryale one (option `by_holder`).
- **Rules questions.** The lead-in line is the card's own asker's, and a line naming a different rule is dropped.
- **Potion question.** It's the drinker's, or it says who gave the potion to whom (new `text_given` on the card).
- **What's left:** the kill going to the wrong hero (B9) is batch A's item 5.

### B2. Only what's owned fires; what's given is shown
- **Slime from the lifted quiver** (32/36/38 careful; 31/35 random).
  - Cause: the lifted quiver used the full "arrows and slime" battle option.
  - Fix: a new value, `fire_arrows = "arrows"`, burns on ranged hits only. This needed a change in `game/rules/museum.lua` and `game/rules/battle.lua`. New rules case `museum-fire-arrows` fails on old code.
- **Telpur's stolen stock.** He won't sell the arrows while the lifted quiver is in a pack. He recognises his own stock the next time he sees it, at the counter or along for a fight, but not in the same room the night it went. He then knows about the theft (`people.spots`, `museum_night.owner_sees`).
- **Bracelet.** Flitwidget gives it to the hero he likes best (read from the log). The table hears it handed over at the next night's start, and the lair line names whose wrist (`between_gifts`).
- **Marbles.** A real purchase: the price is said, a roll moves it a Franc either way, it comes out of the pool and the bag goes into a pack. They're mentioned at the next fight.
- **Vorpal sword.**
  - "Yes": the sword is on Telpur's shelf at forty Francs (a gift shop callback).
  - "Danger": the thanks line now says it was found behind her couch on the way out of the lair.
- **Red switch.** If they saved it for her, the Mech's commander flips it in the lair (`fight.saved_switch`).
- **First pick.** The promise is recorded and kept at the next find or at the gift shop pick in the thanks, out loud. It's never made once the adventure is over.
- **"Pip pockets something small."** It now names a thing from that room (new `MODULE.pocketables`). The thing is logged and given back, by the thanks at the latest.
- **Loot count with no loot.** That act is off in the museum.

### B3. Money adds up
- **The pool.** Every Franc into the pool is logged with who found it and said at the table:
  - a moment's Franc that its own words didn't mention
  - a ruling Franc
  - a small-moment find
  - a moved find
  - between-session favour Francs, said at the next night's start
- Explore finds now name the hero. The check holds that the change in the pool each night equals the log's ins and outs.
- **The reward is one number.**
  - Flitwidget says it before anyone haggles.
  - Docking names the real reason: what they broke, by name, from the log; his draught; or his donation box.
  - The haggle raises it ten from wherever it stands (was a fixed 40).
  - Escape pays half.
  - The board and the report say it's real gold, not Francs, and the report gives the reasons ("real gold, not Francs; ten off for what they did; talked up ten; half of thirty, for letting her go").
- **Engine review item 1** is covered by the above.
- **Engine review item 16 (dice).** A friend who says in the chat they bought dice shows off those dice that week. The report's NEW DICE shows this week's box by default (`loot.newest_index`). That last part is a small change in `report_view.lua`, which is batch D's area.

### B4. Memory and knowledge are true
- **Friends' knowledge.**
  - The Witness and the sunken city need the notebook read out. A whisper no longer sets the Witness flag (it says the hero's name, not "the Witness").
  - The jugs need the ritual to have worked.
  - The lady by the mountains needs her painting to have been the one shown.
  - The sign line only plays if they didn't use the water.
  - I only changed these chat lines' `when` conditions; batch C may rewrite the chat itself.
- **Flitwidget's draught.** He misses it when it really went. When he caught Pip at it, he doesn't say it's gone.
- **Wording.** Euryale's card and Flitwidget's memory now say "robbed" and "said yes to his job".
- **"They'd been warned"** is no longer said when you decide Euryale is waiting at the stairs.
- **Flitwidget in the lair.** His word on the ending is now said downstairs in his thanks.
- **Session Zero.** After the introductions there's a short lines-and-veils beat: Mara and Sam say what they'd rather not see, and the table hears your Session Zero answer ("You nod: …"). The reminders the night gives now quote something everyone heard. Lines are in `intros.ASKS_OPEN` and `ANSWER`.

### New lines and the Dialogue Desk
New code tables are on the Desk's `CODE_TABLES`: `museum_night.WORLD_LINES`, `fight.SWITCH_LINES`, `intros.ASKS_OPEN`, `intros.ANSWER`. New when rules are in `when.lua`. The export gives 4411 of 4411 lines a specific when.

### Changes I had to make outside batch B
Each is small:
- A table-bit cap of two a night, because my changes shifted a seed into failing roadmap_words F26.
- One killing-blow line, and one line of mine, that called one person "they". The roadmap_table D6 scan caught them.
- The report_view dice default (batch D's screens).
- Combo bookkeeping in `fight.record` (batch A's fights).

`museum_truth.lua` now checks that a Franc line means a Franc was paid, and that Flitwidget's reward line matches the reward. Those two pass on old code because the lines they check are new.

### Gate (run in order at 1c4e93e): everything passes
- smoke 1–8 and the 12 sims
- museum_truth (0 failures)
- nov3 4, table_life 2, save_check (396 of 396)
- round3_world_check
- the four roadmap checks (truth, words, table, world)
- thoughts, standing, ties, barks, dialogue, map_repo, board, rest
- rules_cases (86 of 86), museum_fights (6418 checks, 0 failed)
- gloss audit, maps, require_check, validate

### Noticed but not mine
- A replacement hero in a dead hero's seat carries the dead hero's pack: the bracelet showed on "Sister Aldith's wrist" in 38 careful. Batch A's death handling.
- Chat says "went down TWICE" for three or more downs, and the "hit the floor last week" wording. Batch C.
- Friends' barks still describe veiled scarabs ("Describe it properly, please"). Batch C, or A.
- The Lecturer who escaped still drops his notes. Batch A, item 7.
- The red switch flip is my line; batch A narrating Hyper Destroyer Mode (their item 4) should keep its line about the mode itself, so the two don't repeat each other.

### Doc lines for README/AGENTS
- **Tests list:** `lua tools/tests/round3_world_check.lua [first last]` — round three's batch B, played on the reviews' own seeds (31 to 38, three DMs) exactly as the sim plays them: one owner per action, only what's owned fires and what's given is shown, the money adds up, memory and knowledge are true; plus targeted cases. `ALL=1` lists every failure.
- **AGENTS, events.lua row:** a party moment carries its `backers`, and a painting's moment the `gift` that came out. Every Franc into the pool is a `find` (a ruling's, a small moment's and a favour's between sessions too, `between = true`). Every Franc out is a `spend`. A pocketed thing is a `pocket` (with `returned`), and a promise kept is a `promise`. The pool on any night is the log's ins minus outs.
- **AGENTS, people.lua row:** `knows`/`not_knows` take `outcome = "got" | "caught"`. `people.spots` covers someone seeing their own stolen thing in a hero's hands (Telpur at his counter, or along for a fight), and they know it from then on.
- **AGENTS, items.lua row:** a thing's `from_fondest` gives it to the hero that person likes best, and its `handover` words show it given at the next night's start (`museum_night.between_gifts`). The lifted quiver is `opt_value = "arrows"`: arrows without the slime, burning on ranged hits only (`game/rules/museum.lua`).
- **AGENTS, the reward row:** the reward is real gold, not Francs, and it's one number: `adventure.reward_vars` (`{gold_word}`, `{gold_up_word}`) for every line that says it, and `adventure.reward_why` for the report. Flitwidget says it first, docking names the real reason, the haggle is `gold_up`, and an escape pays half.
- **AGENTS, Session Zero:** the lines and veils agreed at Session Zero are said at the table after the first night's introductions (`intros.asks`).
- **AGENTS, museum_night:** a card's `owner` names the card whose moment handed the thing over. An option's `best` (skills) picks the one best at it among its backers. An option's `by_holder` is done by whoever carries the thing. `museum_night.first_pick` keeps the friends' first-pick promise.

Nothing in this report came from memory, and I found nothing new worth saving.