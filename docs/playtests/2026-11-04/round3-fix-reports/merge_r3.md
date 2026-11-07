## Round three merge: report

`r3-int` is at **ee0d5d0** and pushed (`origin/r3-int` matches). It holds all four batches merged in order A, B, D, C, with interaction fixes and docs on top. Nothing was merged into v2-museum. The full gate passes. The two throwaway worktrees I used are removed.

### Merges and conflicts

**A (origin/r3-state, 343c057) → 27cf3f5.** No conflicts. The tree is identical to 343c057, so A's own gate stands.

**B (origin/r3-world, 1c4e93e) → 16372de.** Four conflicts:
- **module.lua, the painting's "keep it" option.** A had reworded the old line so it no longer says they'd left the room. B had made it one weapon, the puller's. I took B's singular line ("It stays in hand, dripping, until it's nothing but a puddle…"), which also meets A's rule: it never says they left the hall.
- **people.lua, Flitwidget.** I kept A's `grief` lines and B's new `docked` (with its real reasons and `{gold_word}`) and `reward`. A's old `docked` is gone.
- **museum_night.lua, the Lecturer's notes.** Both kept. A: no pages when he ran. B: otherwise the best reader there picks them up, out loud.
- **table_life.lua.** All three kept: A's "a bit naming a hero who can't act waits", B's two-a-night cap, and B's "the marbles once bought".

**D (origin/r3-screens, bc978b6) → c1d583c.** One conflict:
- **report_view.lua, NEW DICE.** B and D both fixed it. I kept D's labels ("NEW DICE", "IN YOUR BAG k/n") and used B's `loot.newest_index` to choose which set shows first, so one function owns that.

**C (origin/r3-words, 6d2219b) → 8856f22.** Eleven files conflicted:
- **Bark context** (data and model) and **`when.lua`**: I took both sides in full. Bark context: A's clock and death-night facts, plus C's lock, statue, puzzle, first-fight and "came close" facts. `when.lua`: the union of both file lists.
- **killing_blows.lua**: both made the same `{boss}` fix; I took C's wording.
- **events.lua**: rebuilt from C's chain (room steps, fight `tail`, cutting a beat that repeats its cause, the Francs folded into one line) plus A's three changes: losses lead (`lead_beats`, `losses`), the `tell_beats` split (the Francs are now passed into it), and "no second 'but' in one sentence".
- **adventure.remove_mark**: C's cause-based "so"/"but", with A's `quiet` flag kept.
- **museum_night `table_pick`**: C's version. Its `night:at_hand()` now asks `able`, so it already covers A's voters; I removed A's unused copy. **`fork`**: C's version with A's voters throughout.
- **module.lua, nine conflicts.** Each is both sides together:
  - The lock card: B's `best` plus C's `short` and `pulls`.
  - The knight's "wide berth": A's line plus C's `short` and retuned effects.
  - The painted weapon: B's singular wording; I rewrote C's `points`, `short` and `lean` in the singular to match.
  - The fire arrows: B's `unless` plus C's `short`.
  - The mirror: C's chain words (they name Euryale), with B's comments kept.
  - The Lecturer's pages at the ultimatum: B's `by_holder` plus C's `short`.
  - The epilogue lines: C's new lines, with the Witness line on B's `witness_city` flag.
  - The room chat: C's rewrite, which already carries B's conditions.
- **table_life crit find**: B's find event in the log, with C's wording (the find stays a find, and a Franc turns up beside it).
- **roadmap_table_check, Exhibit B case**: C and D made the same fix; I kept D's.
- **Sad weeks in the chat**: as C suggested, `museum_week.somber` now reads A's losses from the log (a death, a wipe, an ally lost) as well as C's lost fight. It falls back to `new_char` for old saves.

### Interactions found and fixed
After B (5875dba, 7b943f8):
- **The red switch said once, then the mode.** B's `saved_switch` flipped the switch, but A never told the Hyper Destroyer Mode that followed: 18 A4 failures. Now the table hears B's switch line, then A's mode line, once each. A commander who is stone or charmed can't reach the panel.
- **Picks against taunts.** A's own code was inconsistent: the general monster AI and the Lecturer let an earlier stare-down beat the DM's pick, while Euryale did the opposite. Now every foe uses the same order: the DM running this turn (`c.dm_ran`), then a stare-down, then the tactics card's standing call. This touches `game/rules/` (`ai.lua`, `museum.lua`), so I added a rules case, `museum-pick-over-taunt`. I confirmed it fails on A's code.
- **A dead hero returned what she'd pocketed.** "Pip quietly puts a glass eye back" played with Pip dead. Now a friend gives it back in her place (new `pocket_back_for` lines, on the Dialogue Desk). Pocket events carry `char`, so a new hero in the seat never returns the old hero's things. A's check now reads "table" lines too, and fails on the old code.
- **Rules-lawyer banter on a death night.** It was exempt from A's quiet rule; now the rules card is asked plainly.
- **One clock for a late night.** I added `night:ran_late()`. The table, the goodbyes and the report now read the minutes the night was judged at. A's check had been reading the clock after the night's last lines ticked it on.
- **Check fixes** for things the code did correctly:
  - A's check wanted a wake even when the DM chose "Move on quickly"; it now owes one only after a goodbye.
  - `ties_check` didn't allow for A3's lost lair fight taking the tied scarabs mark off her card.

After D (9659e6e):
- **A's and D's `length_text`.** D's S14 check couldn't read A's late-night wording ("Ran 30m past … (3h 30m at the table)"). I updated the check pattern.

After C (1670bbd, 407ab09):
- **R10 over its limit.** "Save it for the Gorgon" was the pick in 69% of runs. The cause: C's hurt-hero and rough-last-fight pulls applied to the Mech switch, whose risk falls on the Mech, not the heroes. A's harder fights made those pulls fire more ("Oswin's hurt. Let's not."). A new card field `risks = "mech"` turns them off for that card. It's now 58% and R10 holds; I didn't move the threshold.
- **Dead Oswin in a rest scene.** C's new rest scenes played for a dead hero ("Oswin mends a snapped strap"). They now need both heroes able to act and still the heroes the line names.
- **"The lady by the mountains" in the chat after the hall showed the elf.** B's flag didn't match the painting actually shown. It now follows the card's own words.
- **The vorpal sword never on Telpur's shelf.** When the DM's yes came after the party's first gift-shop visit, a trip back never showed it. A room's callbacks are now said once each (`adv.cb_said`, safe for old saves), and a trip back says the ones that have come true since.
- **museum_truth: "in Pip's place".** The friend's give-back line now says "in Pip's place" instead of having the gone hero do anything.
- **Check fixes:**
  - B's praise check now counts a spell's damage when A's knockout card splits the turn.
  - C's words check knows B's singular painted-weapon wants and the mirror's `lean = "none"`.
  - D's screens check reads a screen dumped twice (a second boss night's board, shorter after A3's losses) by its last facts.
  - `roadmap_words_check` knows C's curio `asks`.

### Gate
- **After A+B+D:** everything passed except `ties_check` (the tied mark, fixed above).
  - `save_check` 410/410, `rules_cases` 89/89, `museum_fights` 6414/0.
  - The gloss audit found 0 words without a hover.
  - The Dialogue Desk export gave 4542/4542 lines a specific when.
- **After C:** two failures, both fixed: `museum_truth` (the "in Pip's place" fix) and `roadmap_words_check` (curio `asks`). The Desk export was 5037/5038, fixed by making `risks` a key. I reran the steps that ran before those edits:
  - **Passed:** smoke 1–8, the 12 sims, `museum_truth` (0 failures), `nov3 4`, `table_life 2`, `roadmap_words`, `require_check`, `validate`.
  - **Desk export:** 5037/5037.
  - **Everything else passed in the full run:**
    - The four round3 checks and the four roadmap checks (R10 at 64% worst).
    - `save_check` 419/419, `rules_cases` 89/89, `museum_fights` 6414/0.
    - The thoughts, standing, ties, barks, map_repo, dialogue, board and rest checks.
    - The gloss audit, `build_maps --check`, `require_check`, `validate`.

### Docs
README, AGENTS and the overview now carry all four batches' lines, plus what the merge added: `able`, the target order, `ran_late`, `risks`, callbacks once each, and the chat's sad week. Commits 6ccee57 and ee0d5d0.

### Still open (not fixed: outside the merge)
- **The stare-down line calls Euryale and the Lecturer "it".** fight.lua:2188, "The Lecturer can't take its eyes off Oswin". A's A5 check parses that exact text, so a fix needs the check updated too.
- **Monsters with no pronoun are still "they"** (the Knight of Shades), and **"Oswin helped Telpur." doesn't say what he did.** Both were in C's report.
- **Cheery lines after a death.** These lines aren't gated by A's quiet rule:
  - At the gift shop, after Flitwidget's grief: his "My heroes! You're back! Tea?", "Splendid, splendid…" (the draught line), "The reward! … I always pay my heroes", and Dev's "Best night ever".
  - The goodbyes "Good game!" and "Same time next week".
  - A break after a lost boss fight ("Everyone comes back warm"), right before the night ends.
- **The engine-side items** A and D listed still need the real engine.

Nothing in this report came from memory.