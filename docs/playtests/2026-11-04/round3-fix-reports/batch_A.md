## Batch A (state and fights): done and pushed. r3-state is at 343c057, nine commits on e691363, and the full gate passes.

The three blockers (B1–B3) went first, on their own, in 4e7635f. Then one commit per item: bcd5c62 (A4), 52530ef (A5), 60352b6 (A6), 29b34f5 (A7), 54eed38 (A8). After that: dec9966 (the two items batch B passed on, plus thought answers), 8fb56a4 (batch D's three) and 343c057 (problems that seed drift turned up).

**How I confirmed each check fails on e691363:** I copied `tools/tests/round3_state_check.lua` into a throwaway worktree at e691363 (now removed) and ran it there. The check uses its own reading of dead/down/stone/charmed instead of `able.lua`, so it runs on the old code. The old code fails every item: A1 198 failures, A2 24, A3 39, A4 82, A5 17, A6 39, A7 108, A8 121, D 73. The failures name the same seeds and moments the reviews did: 35 careful W4 (dead Oswin talking to Flitwidget, the "Round 3 and we're doing okay" line), 32 careful W5 (Pip pockets something while stone), 33/36 careful W3 (flanking while charmed), 37 careful W5 (dead foes back, first-meeting ambush line), 32 careful W2 / 34 careful W2 / 38 careful W1 (foes ignoring picks), 38 careful W3 (the knockout card named the wrong hero), 31 careful W1 (destroyed Sentinel "watches them"), 31 careless W2 (Brannoc down twice, not recapped). The two new `rules_cases` also fail on e691363 and pass now.

**Seeds drift.** Every fix changes how random numbers are used, so the reviewed seeds no longer replay the same events. For example, Oswin no longer dies in 35 careful. So the check plays all 24 reviewed seed/DM pairs, 6 more seeds, and 16 "fragile" runs (Oswin on 1 hit point, the DM letting the dice stand), plus targeted cases. Deaths stay rare (about 4 across those runs); the check fails if it sees fewer than 2.

## Per finding

**A1 — who can't act doesn't (B1, B6, B17, M3, alive 17).**
- Cause: every picker (`at_hand`, the takeover talker, `conversation`, fight chat, the "I'm coming" healer, a fighter's rules card, the vote pools, the killing-blow teller, the mirror holder, thought answers) used whoever was at the table, whatever state their hero was in. The wake was said inside `death.fall`. Nothing tracked the table's mood after a loss. The stone line promised "Only Euryale falling".
- Fix: a new `game/model/able.lua` owns a hero's state. `night:at_hand()` asks it, so every picker does. `table_pick` and `fork` only let friends whose heroes can act vote. `able.somber` (a death, a wipe, an ally lost) quiets cheering lines and table bits, and getting back up after a death is said quietly. The wake waits for the gift shop or the night's end (`death.hold_wake`), and Flitwidget speaks first (new `grief` lines). A death is a lead beat in the event log, so the recap leads with it. The stone line now says the stone holds "until her hold breaks", and the line when it breaks says why.
- From batch B: a dead hero's pack is shared out loud (`death.settle_pack`, logged as "given"), so the next hero in that seat starts with nothing of theirs.
- Thought answers that have the hero act are neither offered nor delivered while that hero can't act. A replaced hero's reason for coming isn't paid off in the new hero's seat, and table bits naming a fallen hero wait.
- Check: the A1 gate on every event, the death watchers and targeted cases (dead Oswin, his pack).

**A2 — friendly fire (B2).**
- Cause: nothing read a hero's damage to their own side.
- Fix: `fight.friendly_fire` says it, the friend who was hit says something to the caster, the caster owns it, and it's a `friendly` beat in the log (a lead beat when it dropped someone).
- Check: every friendly-fire damage step must be told and get a reply, and the report must say whose spell it was.

**A3 — destroyed stays destroyed (B3, B13).**
- Cause: lair losses never came off Euryale's marks. The recap clause didn't know about the burnt-out Mech. The ambush opener had no rematch line.
- Fix: `museum_night.lair_losses`. An ally smashed or burnt out comes off her card for good and leads the recap. In a lost fight, fallen foes take their marks with them (huntlings by count). `recap.tomorrow.since` covers the burnt-out Mech, there's a rematch ambush line, and the Mech's fall has its own lines.
- Check: each lair line-up against the last one's losses, the recap wording, the rematch line, and a targeted case (Owen lost).

**A4 — big payoffs told (B14, P3, alive 11–12).**
- Cause: the rules' museum features were only logged.
- Fix: `fight.tell_moments` narrates them in order, including steps between turns: veil, stare and who it caught, the mirror and whether it took, turning to stone (anyone), cracking free, charmed, Hyper Destroyer Mode (about the mode only, leaving B's switch line alone), burning out, powering down, a natural-20 death save. Telpur's knockout now has three ways.
- Check: every such feature must be told before the turn settles; Telpur's ways are counted.

**A5 — picks and taunts steer the foes (B8, B9, T10, T11).**
- Cause (rules): `ai.lua` swung at whoever was close when the told target was out of reach. `lecturer_turn` and Euryale's spells and snakes ignored taunts. Kruthiks fled on DM-run turns. Picks lasted one turn.
- Cause (cards): the knockout and "how do you want to do this" cards named the pilot's hero when an ally was about to land the blow.
- Fix: told foes move toward their target; picks hold until the foe has gone at them (`dm_keep`); the cards name the ally and go to its player (`fight.ally_player`, `killing_blow(..., by_name)`, `kb_share(..., lander_name)`).
- Check: every pick, taunt and named blow is followed; `rules_cases` adds museum-told-target and museum-lecture-taunt.

**A6 — no browsing after a loss (alive 13, F5, M6).**
- Fix: a lost room plays no end moments and no small moments. A wipe is said once, everyone comes round in one line, a friend reacts, the table stays quiet for the night, and the night stops on a rough note. Two lines that said they'd left a room are reworded.
- Check: lost rooms watched, a wipe said once, no cheer after it, and a case that no moment line says they've left.

**A7 — recaps lead with losses (B7, B13, B16, T2, T3, alive 20).**
- Fix: `events.lead_beats` / `events.losses`: deaths, then wipes, allies lost, friendly fire, then downs merged per hero ("went down three times"). They lead the report chain and the next night's "Last time, ...". The Chamber recap says "smashed" when it came to blades. A fought Sentinel has its own line.
- The Lecturer who escaped isn't "silenced" and isn't said to "fade". Per batch B, he also keeps his notes: no pages mark and no reward (`r.ran`). He still reports to Euryale.
- Check: downs recapped, reports and openings lead with losses, plus the Sentinel, Chamber and Lecturer cases.

**A8 — break and late nights (alive 10, M16, screens 3, F6).**
- Fix: a boss night that starts at her door takes its break after her part is settled, before the gift shop. A night more than 15 minutes past the Session Zero end is said at the table (`night.LATE_LINES`) and isn't applauded. Bark context gains `late`, `midnight` and `died`, so no "same time next week" or "expect it by midnight". `length_text` gives the agreed end and the existing Trust cost.
- Check: every break and every late night.

**Batch D's three.**
- Minis: `fight.squares_shown` places each mini where it isn't behind another hero or a wall, and only inside the anchor's room (the octagon's corners counted as open squares). The lair spec now puts Euryale at 14,9 (front and centre); `map_library` was rebuilt. The check measures heroes straight behind each other: 0 of 3320 placements now, 703 of 3276 before.
- The first night's first thought waits for the first room.
- The homework line names the roll (`night.RESEARCH_LINES`).

## Left or uncertain
- engine_screens item 2 (minis off the board, bases on the tiles) looks like the drop animation (lift 30, delay up to about 1.4 s plus a 0.7 s bounce) caught by autotest's 1.6 s shot wait. That's engine-side and I couldn't run the engine, so it's unchanged.
- Euryale's mini size (generated `scene.large`) is unchanged.
- "Behind" assumes the camera looks from the south (higher y is nearer).

## Gate at 343c057 (all pass)
- Smoke 1–8, the 12 sims, `museum_truth`, `playtest_nov3_check 4`, `table_life_check 2`, `save_check` (424/424), `round3_state_check`.
- The four roadmap checks.
- `rules_cases` 87/87, `barks`, `thoughts`, `standing`, `ties`, `rest`, `dialogue`, `map_repo`, `board`, `build_maps --check`, the gloss audit, `museum_fights`.
- Dialogue Desk export: 4454/4454 lines have a specific when.
- `require_check`, `validate`.

## Changes outside my area (kept small)
- C: `table_pick` and `fork` voter pools; `events.chain` never puts a second "but" onto a clause that already has one; `recap.lua` "betrayed {who_them}"; the Mech mark's chain now says "the party's side".
- B: `people.lua` (Flitwidget's `grief`), the cards for the Lecturer's notes, `adventure.remove_mark(c, id, quiet)`, `recap_clause` (`since` and `ran`).
- `companions.lua`: lines can be lists; the death card's notes are filled in.
- Two existing checks changed:
  - `barks_check` now reads the real lander and treats a turn split by a card as one turn.
  - `roadmap_world_check`'s Lecturer case accepts any of his three lines.
- Expect merges with B in `fight.record` and `saved_switch`, and with D in `length_text`, `recap.lua` and `museum_week`.

## Doc lines
**AGENTS table:**
- `game/model/able.lua` (round three): one owner for a hero's state (dead, down, stone; in a fight, charmed or out of it). `night:at_hand()` asks it, so every picker, the votes and the cards do. `able.somber` (a death, a wipe, an ally lost) quiets cheering lines.
- `fight.tell_moments` / `friendly_fire`: the fight's big moments and friendly fire told, from `BARKS.told`, three ways each.
- `death.hold_wake` / `settle_pack`: the wake once the danger is past; the dead hero's pack shared out loud.
- `museum_night.lair_losses`: what's destroyed stays destroyed.
- `events.lead_beats` / `losses`: recaps lead with the losses.
- `fight.squares_shown`: every mini shows.
- Boss-night break after the lair; `night.LATE_LINES` for late nights.

**README tests:**
- `lua tools/tests/round3_state_check.lua [extra seeds]` — round three batch A, played across the 24 reviewed prologues, more seeds, fragile runs and targeted cases (about 15 s).

## Noticed, not mine
- The chat still jokes after a wipe or a death (C).
- Flitwidget's ending line is still heard in the lair (B).
- R10's mus_drink sits near its 66% limit; one intermediate state hit 68%, so it's a noisy check (C).

Nothing in this report came from memory.