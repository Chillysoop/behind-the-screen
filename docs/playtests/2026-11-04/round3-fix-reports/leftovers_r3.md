## Round three's last open items: done

All four items are fixed, plus what the scan of fresh prologues turned up. Everything is in one commit, **6ccb03d** on `r3-int`, and it's pushed (`origin/r3-int` matches). The full gate passes: 47 of 47 steps.

### 1. Cheerful lines after a death or a lost boss fight
**The gate (`game/model/able.lua`):**
- `able.somber` has a new kind, "lost". It's set in `museum_night.after_showdown` when Euryale beats them, and lasts the rest of the night.
- `able.CHEER` covers more of the table's whoops and jokes: victory_close, fumble, ruling_good, snack, banter, check_win, miss, ouch, groan_other, scene_dislike, bored.
- `able.quiet_trigger` sends the goodbyes and the report card's word to quiet pools (`wrap_sad`, `report_sad`).
- `able.pick(night, list, sad)` is the helper the other sources use to swap in their quiet versions.

**What each source now does on a sad night:**
- **The lost boss fight:** the night ends there, with no break to come back from. I changed `roadmap_truth_check` F1 and `playtest_nov3_check` 14 to accept a night that was only her lair, lost, with no break.
- **Flitwidget at the thanks:**
  - Quiet versions of his thanks, reward and docking (`thanks_sad`, `reward_sad`, `docked_sad`). The quiet thanks still mention the draught, so batch B's B4 check holds.
  - Seeing them again and his praise use "@sad" lines, or he says nothing (`npc_line`).
  - The ending's `flit_sad`, his card's `again_sad` (no more "beaming at them"), the thanks' `win_sad` and the reward's `line_sad`.
  - On the talk card, his `done_sad`/`done_ask_sad` lines, and the hero answers with a new "sad" mood.
  - His grief for two heroes now says "were" (it said "Brannoc and Oswin was").
- **The friends:** a quiet opening and asides at the thanks (no "Best night ever"). Their last words come from `want_more_sad`, split by whether it was their own hero who died. That also fixes "Oswin says a prayer for the road" with Oswin dead, and "Same heroes, bigger fights?".
- **The break:** quiet lines (`BREAK_SAD`), so no "Everyone comes back warm".
- **Fights and faces:** a won fight isn't applauded (`party_win_sad`), and nobody's face cheers or laughs.
- **Telpur:** quiet `react_sad` and `up_sad` (no "Did we win? I was resting my eyes" after a wipe), and quiet versions of his thanks follow-ups.
- **The wrap:** the death line comes before "It was a good night" on a late night, and there's no "Groans all round".
- **What waits for another night:** banter, small moments and ideas, rest scenes, look-round asides, and the glowing thoughts (glow, celebrating, chatty).

**Check:** a new item Q in `round3_state_check`. It watches every line after a death, a wipe or a lost boss fight across all 46 prologues. It reads the cheerful lines from the module's and the code's own lists, so it also runs on old code. It catches a break after a lost boss fight, small moments, glowing thoughts and the report card's word, and it has two targeted cases (dead Oswin; the break). On ee0d5d0 it gives **182 failures**; now 0, over 14 sad nights and 7 lost boss fights.

### 2. Pronouns
- **The mechanism:** `util.PRONOUNS` has "it". `util.pronoun_of` now knows each museum monster by every name the table calls it: the stat block's name, with "the", the room's `boss_name`, `MODULE.foe_names` and the mat's numbered label. The pronoun comes from the cast card (through `npc_sheet`), else the new `MODULE.foe_pronouns` (huntling, swarm, briars: "it").
- **The stare-down:** it's now `fight.stare_line`, by the foe's own pronoun and spoken name. I updated A's A5 parser to read any pronoun and find the foe by its Taunted effect.
- **Other lines fixed:**
  - The boss card: "Who does it go for?", "who's been hurting her most".
  - The recap: "they brought it down".
  - Mara's bark: "hits harder than she looks".
- **The Knight of Shades is "it" throughout:** its cast card and the book call it a construct. That changed about 10 lines that said he, his or him.
- **Check:** new item F in `round3_words_check` (log scans plus cases). On ee0d5d0: **45 failures**.

### 3. "Oswin helped Telpur." and the other beats that said nothing
- The help ideas have `did` lines, one per line the table hears ("Oswin held Flitwidget's ladder for him").
- The painting's beat names what came out (and has its own words for the empty painting).
- Telpur's tell names what was lifted (`told_got`/`told_caught`; steal events now carry `char`).
- "X and Y went off together" was untrue: the split-party card sends them different ways. It now says who looked around on their own and who went the other way.
- **Check:** new item W. On ee0d5d0: **44 failures**.

### 4. Telpur's knockout
A's three ways for his fall, his friend's cry and his coming round all survived the merge, and they all play: 6 different lines across the runs, on ee0d5d0 too. What still played one way was the follow-up at the thanks: the sock line was the same in 3 of 3 runs in seeds 31–38. Both thanks follow-ups (after he fell, and after he came along) now come three ways each, plus quiet versions.
**Check:** new item K. On ee0d5d0: **3 failures**.

**How I confirmed the checks fail on old code:** I copied both check files into a throwaway worktree at ee0d5d0 and ran them there (counts above). The worktree is removed.

### Scan of the 12 new prologues (seeds 41–44, three DMs) and 16 fragile runs
Beyond the items above, I found and fixed:
- Rest scenes ("Both laugh") and small moments after a death and a wipe.
- Look-round lines like "There's a tiny train!" on a sad night.
- Snack talk, banter and teasing after Oswin died.
- Flitwidget docking the reward right after saying it could wait (he now docks quietly).
- The chat calling Pip's replacement "her" ("be nice to her") when the new hero (Tam Quickley) is a he.
- "Goodnight, sweet the kruthik huntling." (broken text).

### Gate (all pass, run in order)
- Smoke seeds 1–8 and the 12 sims.
- `museum_truth`, `playtest_nov3_check 4`, `table_life_check 2`.
- `save_check` 419/419, `rules_cases` 89/89, `museum_fights` 6414/0.
- The four round3 checks and the four roadmap checks.
- The thoughts, standing, ties, barks, map_repo, dialogue, board and rest checks.
- The gloss audit, `build_maps --check`, `require_check` and `validate`.
- The Dialogue Desk export: 5200 of 5200 lines have a specific when. I added when-rules in `tools/dialogue/when.lua` and put `BREAK_SAD` in `export.lua`.

### Left open
- On a sad night these still play:
  - The heroes' in-character first words to Flitwidget (Pip's "Darling, you look like someone who appreciates a good deal.").
  - The defeat lines ("This is the dice's fault.").
  - A thought's snack answer ("Chairs creak hopefully"). That's thoughts, batch A's area.
- Flitwidget still docks the reward on a death night, just quietly.
- The bored tells are silent on sad nights.
- Telpur's "fell" flag lasts the whole campaign, so the thanks mentions his bandage even if he fell weeks earlier. That was already so before.
- The engine-side items still need the real engine.

### Doc lines (I didn't edit README or AGENTS)
- **AGENTS, the able.lua row:** "`able.somber` also has 'lost' (Euryale sent them home; that night ends with no break). The quiet versions: `able.quiet_trigger` (`wrap_sad`, `report_sad`), `able.pick` for a source's `_sad` lines (people lines, `npc_*_sad`, a card's `again_sad`/`win_sad`/`line_sad`/`intent_sad`/`talk_sad`, an ending's `flit_sad`, a callback's `sad`, `want_more_sad`, `done_sad`, Telpur's `up_sad`/`react_sad`, `BREAK_SAD`, `party_win_sad`, talk_reply's `sad`). Small moments, rest scenes, look-round asides and glowing thoughts wait."
- **AGENTS, the pronoun rule:** "the museum's monsters too: a cast card's `pronoun` or `MODULE.foe_pronouns` ('it' for a construct, swarm or beast), by every name the table calls them (`util.pronoun_of`)."
- **README tests:** round3_state_check adds "the quiet after a loss (Q)". round3_words_check adds "each foe's own pronoun (F), a beat says what was done (W), Telpur's knockout three ways (K)".

Nothing in this report came from memory.