## Batch D (the screens): report

**Where it is:** branch `r3-screens` in `/home/claude/bts-r3d`, 10 commits on top of e691363, pushed. Everything passes.

**The new check:** `tools/tests/round3_screens_check.lua [seeds]`. By default it runs seeds 31, 34, 1 and 5 and takes about 40s.
- Each seed is a smoke run with `SCREEN_CHECK=1 GLOSS_AUDIT=1 DUMP_DIR`.
- `SCREEN_CHECK` is a new mode in `museum_smoke.lua`. At every dump it finds each text cut short with "...", points at whatever lies over it, and prints `CUT_NO_HOVER` unless a hover there draws the whole text. It also prints `FACT` lines (what the game state says a screen should show) and `HOVER` lines (what the stat, Goodwill and mood hovers say).
- The smoke now also opens the report's whole-night page (`6c_chain_w*`), dumps a week-3 hero sheet, opens the Story and Table sidebars one at a time, and gives the mock's minis a place on screen so the floating labels can be counted.
- **How I confirmed it fails on the old code:** I copied the new smoke, the check and `gloss_words.lua` into a throwaway worktree at e691363. On seeds 31 and 1 it reports 2120 failures, and every finding below fails there (each says how).

### What I changed, per finding (screens_newcomer.md)
1. **Prep board cut short.** `museum_prep_view.lua`, `player_cards.lua`.
   - Friend forecasts show in full beside a shorter bar.
   - Euryale's marks fit in full (beside the name, or under it) before falling back to one line. Each mark has a hover with its cause. The overflow note now reads "+N more: Notes, Upstairs".
   - Room summaries get two lines. Each Session Zero line or veil gets its own line.
   - Boss-night choices get two lines; WHAT THE PARTY BRINGS gets up to four; her card is no taller than its marks need.
   - Spare hours wrap. The private-message reminder gets three lines.
   - Map labels sit a pixel from the box edge.
   - **The kit fix behind all of this:** any text that is still cut now shows the whole of it on hover (`kit.cut_hook`, drawn by gloss.lua's card).
   - Checks: S1 and CUT. On old code, S1 flags the cut forecasts (seed 34), marks, summaries, asks, spare hours and boss choices, and CUT flags "Str...", the room summaries and the marks.
2. **Report chain stopped partway.**
   - The recap panel is wider and the beats get smaller when that lets the chain fit.
   - When it still doesn't fit, it shows whole sentences, then "...and the night goes on." and a "The whole night (N more)" button that opens a page with all of it. That page uses paragraphs that start at each "They ..." sentence.
   - The wrap-up now lists where the party stands and how long the night ran first. Anything that doesn't fit is on hover. It no longer says "+N in your notes", which was untrue.
   - Check: S2.
3. **Running late:** the cost belongs to batch A. On my side, the night's length line is now second in the wrap-up, so it can be seen. S14 fails old code because that line wasn't visible.
6. **CARRYING list:** always on the sheet (healing potions first, "Nothing yet" when empty, a hover for each item; GEAR is now only the starting kit). Also on the party page in the notes. Check: S6.
7. **Table stats unexplained.**
   - Each stat row on the report has a hover: what the stat is, how it moved tonight, and whether that's good or a worry.
   - The glossary now says which way is better for each stat. Goodwill's hover says what it is.
   - The mood shows "Mood: Talk to see" (or "Mood: not known" in week 1) instead of "?".
   - Check: S7.
8. **Faces on night 1:** a face no longer frowns beside "listening", "grinning" or "leaning in" (`panels.lua`). Check: S8.
9. **Thought card key:** the tip names the Table button. The key strip now says "S Story/Table". Check: S9.
10. **Failed read that still answers:** the card gives the total the read needs, and says when "N or more gets the gist". The old "needing 8" compared a die target with the total. Check: S10.
12. **Headlines against the moods:** the wrap screen now shows the report's own headline, then who loved it, who had fun and who was bored, by name. Check: S12.
13. **Boss board contradiction:** the board now says "Her card wins here: she smelled the smoke..." Check: S13.
14. **Minutes mismatch:** the wrap card uses the report's minutes. One line in `night.lua`'s `length_text` now floors instead of rounding. Check: S14.
15. **Unknown words:**
   - New glossary entries: vorpal sword, Mage Armor, Aid, Mastery/Vex/Nick, Minis, Inspire, final roll, EMPATHY, BEHIND YOUR SCREEN, "Dice jail" with a capital.
   - **The GLOSS_AUDIT gap:** "A LOOSE END" had no hover; it now has one. The audit reports 0 words without a hover.
   - The crits toggle now reads "Small crits". Talk hours read from `prep.TALK_COST` everywhere.
   - Check: GLOSS (the audit's word list now covers these words).
16. **Between sessions:** the subtitle only promises what the screen has. The promise names the rule (the question and what you said). Check: S16.
17. **Journey route cut:** each room's story fits whole in the lines it has, with all of it on hover; room names are shortened as "(S2)". Check: S17.
- **Polish (check P):**
  - Text fixes: "Minis: the Lecturer"; "Voice for X:"; "in Oswin's pack" instead of "(X has it)"; captions start with a capital; the debug line is replaced with "Next: the group chat, then your prep board."; cuts no longer leave "anyway...."; uneven "The ..." capitals in room lists fixed.
  - Notes: the session log opens on the newest session; the People page has one line for the people not met yet.
  - Small fits: the finished save's label fits; the session title steps down a font size instead of being cut.
  - Session Zero's death-rule note and the sheet's wish line ("Jess wants it to be her call") are clearer.
  - Layout: the night's last caption is no longer under the wrap card; no text sits over text on the bare screens.

### What I changed from engine_screens.md
- **Item 2, minis off the map:** a dropped mini, with its base and shadow, stays hidden until it actually falls (`main/minis/mini.script`). This is my reading of 8_36: the minis were hovering at drop height during the spawn delay.
- **Item 3, floating labels:** at most 2 on one mini and 6 on the board; a read-aloud passage clears them. Check: E3 (old code had 3 on one mini).
- **Items 4/5 (part):** the room title card is now at y 66 and toasts sit under it. Her card's new-mark toast uses the quiet "behind your screen" style.
- **Items 6/7:**
  - Only one recap sidebar at a time; the buttons swap them and S cycles Story → Table → closed. `autotest.lua` and the smoke are updated to match.
  - The caption moves aside for a thought card, and a bubble the card would cut is dropped. The first thought card gets twice the time to read its tip.
  - The first-night tip leaves when room 2 starts. The report tip now sits over the verdict, off WHAT IT EARNED. It used to block the Level up button, which the smoke had never noticed.
- **Item 9:** a wrapped quote pushes its fun bar down. Check: E9.
- **Item 10:** party dots only where they clear the room's name; stair marks further from names; the pond is deep blue instead of teal.
- **Item 11:** the key strip moved below the crits button; the rolls-strip label has a dark backing.
- **Item 12:** a night of three or more rooms is titled "From the Street to the Chamber of Ancients" (`recap.lua`).
- **Item 16:** NEW DICE shows tonight's box; older sets show as "IN YOUR BAG k/n". Check: E16.
- **Items 20/21:** the level-4 cards name the ability ("+2 STRENGTH, 17 to 19" and what it does). There is no "for next session" after the last night, and the headline no longer overlaps the line under it. Check: E11.
- **Item 22:** beaten foes are counted by kind; a harsh call says which room it was in.

### Not done, or needing the real engine
- **Not done:**
  - Minis hiding each other or standing behind walls, and Euryale's spot on boss night: placement comes from `night:staging` and the fights (batch A), and I couldn't see the results.
  - The handwriting font's capital-looking k: it needs a different TTF and a `gen_ui.py` rerun.
  - From 22: the ties window header showing through, Sam's missing tag, the opening card's empty half, the wall in front of a cutout, the boss board's prep hours, and the History chip.
  - Capping bubbles and roll cards (item 15).
- **Please look at these on the real screen:** minis landing on their bases; the title card and the quiet toast; floating labels in the boss fight; the key strip and rolls label; a caption stepping aside for a thought card; the prep board in real fonts (forecast bars, marks, taller room rows); the wider recap and narrower table panel; level-up cards; NEW DICE; the report tip over the verdict.

### Changes outside my area, and the gate
- **One run change you should know about:** moving the report tip off the Level up button changes how seed 1 plays (it levels up a week sooner). As a result:
  - **Exhibit B check:** in `roadmap_table_check`, the Exhibit B case now finds a seed whose Pip takes him along (it lands on seed 2) and still reads D6 and R5 off seed 1.
  - **Batch C's wording:** two chain words in `module.lua` now say "the party" ("the party had a mirror", "the Steam Mech was on the party's side"), because D6 flagged them in the new run.
  - **Small model edits, so you can watch for merge conflicts:** `night.lua` (one line), `museum_week.lua` (how room notes are labelled), `recap.lua` (the title), `session_zero.lua`, `guide.lua`.
- **Gate (all pass, run in sequence on the final code):**
  - Smoke seeds 1–8 and the 12 sims.
  - museum_truth, nov3 4, table_life 2, save_check.
  - round3_screens_check: all clear.
  - GLOSS_AUDIT: 0 words without a hover.
  - All four roadmap checks.
  - standing, thoughts, map_repo, ties, dialogue.
  - require_check and validate.

### Found, but belonging to other batches
- **B:**
  - Boss reward: 30/40/20 against the board's 15.
  - "gold" against Francs.
  - Francs pool 5 → 7.
  - The chat's "green" dice against Obsidian.
- **C:**
  - Pronouns: "why they came" for Brannoc, Mara's "Their Goodwill filled up", Telpur's entry, "Euryale noticed their careful hands" (D6 flags it on seed 2).
  - Chain wording: "but"/"so" connectors and the repeated Franc finds.
  - Quoted text: card titles in the chat, and in brackets in the report's call lines ("(The code in its chest)").
  - The chat oddities, the journey's repeated quotes, "Telpur (Jess)'s", and "top of the stairs" against "foot".
- **A:**
  - The first night's 30-second card before the first scene.
  - "remembers something from the break's reading: +2".
  - Mini placement.

### Doc lines for README/AGENTS
- AGENTS, Where v2 lives: `game/ui/kit.lua`: text cut short shows the whole of it on hover (`kit.ellipsize` remembers what it cut; `kit.text` calls `kit.cut_hook`, gloss.lua's card; `opts.full = false` turns it off).
- AGENTS/README, recap row: the Story and Table sidebars open one at a time; the buttons swap them and S goes Story, Table, neither.
- AGENTS, Checking your work: `lua tools/tests/round3_screens_check.lua   # the third playtest's screens: nothing cut without a hover, the prep board and report in full, CARRYING, the stats explained, the engine screenshots' fixes (about 40s)`.
- README, tests: `SCREEN_CHECK=1 lua tools/tests/museum_smoke.lua <seed>` prints `CUT_NO_HOVER` for cut text with no hover showing the whole of it, plus `FACT` and `HOVER` lines for the screen check.
- README, report: a night's chain shows under the beats in full, or as much as fits plus "The whole night (N more)", which opens a page with all of it.