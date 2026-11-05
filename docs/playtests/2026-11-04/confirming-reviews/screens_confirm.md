# Playtest round four: confirming the screen fixes (newcomer and lapsed DM)

I read every screen dump in order for both new runs, as a D&D newcomer and as a lapsed DM:
- `screens_51`: 5 nights, ending "Euryale slips away".
- `screens_54`: 5 nights. Session 4 is a lost boss fight; session 5 is a rematch, ending "Euryale falls".

Both live in /tmp/claude-0/-home-claude/6545778f-6f8d-5d88-b2f4-2abfe14c8e6f/scratchpad/playlogs4/. I didn't read any code.

File names below are `51/...` or `54/...`. A finding marked "both" happened in both runs.

**What the dumps still don't show:**
- Hover text. Commitment, Trust, Goodwill, Inspire and "Small crits" are now underlined, which suggests hover text, but none of it is dumped.
- Mid-night call cards, except one Thought card per run.
- Every between-sessions card after the first. Each week says "Then 1 to 4 more", and those cards aren't dumped.

So two of the new "bad" findings (N2 and N3) might be explained on a card I couldn't see. I say so where it matters.

---

## Part 1: The old findings, one by one

| # | Old finding | Now | Evidence |
|---|---|---|---|
| 1 | Prep-board text cut off | **Better, not done** | See below |
| 2 | Report chain stops partway | **Fixed** | Every report with a long night now ends "...and the night goes on." and "The whole night (N more) >", and the `6c_chain_*` page lists the whole night line by line, through the last room. Run 51 week 1 ends "Its scarabs crawled... / Along the way, Oswin found two Flitwidget Francs." Run 54 week 1 reaches the gift shop and the Lecturer reporting to Euryale. |
| 3 | Nights run late, nothing reacts | **Fixed** | Overruns are smaller and now cost something. In `51/5_night_end_w3`: "It fizzles a little. Somebody checks the time." In `51/6_report_w3`: "Ran 34m past the 10:00 pm you agreed at Session Zero (3h 34m at the table). Sam trusts you a little less for it. Sam was fading by 10:29 pm." In `54/6_report_w1`: "Ran 49m past... Mara and Sam trust you a little less for it." On-time nights read "Right on time (2h 55m). Dev had time to spare; Sam was fading by 9:50 pm." |
| 4 | Boss reward doesn't match the board | **Fixed** (wording clunky) | The board still says "15 gold each, not 30". The reports now give the arithmetic. `51/6_report_w5`: "20 gold each (real gold, not Francs; talked up ten; half of forty, for letting her go)". `54/6_report_w5`: "40 gold each (real gold, not Francs; talked up ten)". The numbers add up, but the double-semicolon aside is hard to read. Better: "Flitwidget paid 30, Oswin talked him up to 40, and you get half for letting her go: 20 each." |
| 5 | Heroes called "they" | **Fixed where seen**, with new cases | All the old lines are now right: "pip and oswin got what they came for" is plural, "Named in a whisper by the Witness", "Brannoc's story moved tonight: why he came to the museum", "Jess wants it to be her call". New "they" cases are on the Level 4 card (N10). |
| 6 | No CARRYING list | **Fixed** | The hero sheet has CARRYING ("1 healing potion / +1 Shield", `51/4h_hero_sheet_w3`), and so does Notes > The party (`4n_notes_party_w2/w3`, both runs: "Flitwidget's bracelet of protection" under Oswin). The boss board's WHAT THE PARTY BRINGS now wraps in full. |
| 7 | Table stats never explained | **Better** | See below |
| 8 | Night 1 not clearly gentler | **Better** | See below |
| 9 | Thought-card tip names the wrong key | **Fixed** | The key strip now says "S Story/Table", and the tip says "the Table button at the top has both (or S, twice)" (both `5t_thought_card`). |
| 10 | Failed read still gives an answer | **Fixed** | `51/5t_thought_read`: "You rolled 4 + 2 = 6, needing 12: too far off to read... Dev is gripping his dice a little hard, and that's all you can tell." `54/5t_thought_read` reads the same way. |
| 11 | Wrong connectors and repeats in the chain | **Better** | See below |
| 12 | Wrap headlines contradict the moods | **Fixed** | All 10 wrap screens match their reports and the moods. For example, `51/6r_rewards_w4` says "A rough one. Someone had a bad night..." when Mara and Dev were bored. "A mixed night: some loved it" is gone, and the last night no longer says "can't wait for next week". |
| 13 | Boss board contradicts itself | **Fixed** | Both `4b_showdown` screens now say "Her card wins here: she smelled the smoke, so there's no drink and no small talk. She goes straight to her ultimatum." `54/4_prep_w5` adds "With an ambush there's no talk, so handing her the Lecturer's pages won't come up." |
| 14 | Small number and fact slips | **Fixed** | Francs carry exactly from report to board in both runs: 3→3, 5→5, 9→9, 11→11 in run 51, and 3→3→3→4 in run 54. Night-end and report durations match in all 10 nights. The stairs line no longer clashes. |
| 15 | Words a newcomer won't know | **Better** | See below |
| 16 | Between-sessions screen | **Fixed** | See below |
| 17 | Journey screen | **Better** | See below |

**1. Prep-board text cut off: better, not done.**
- **Friend forecasts: fixed.** "Should enjoy it", "May check out", "May be bored" and "Probably fine" all fit, in every board in both runs.
- **Room notes: fixed.** The veil, the line, the Witness, the Francs and the side room all wrap in full now. For example: "Sam's veil: kruthik huntlings, armoured and many-legged, so you'll keep it off screen." and "Mara's line: the archivist at his desk, with eyes carved into his arms, so you'll leave it out altogether."
- **Boss choices and spare hours: fixed.** "She talks first / As in the book: a drink, some questions, then an ultimatum.", "Write a backup page (1h): ... plays as if you had."
- **Euryale's marks: mostly fixed.** They wrap in full on most boards: 51 weeks 2–3, 54 weeks 2–3, every showdown, Notes > Upstairs and the journey. They're **still cut** on `51/4_prep_w4` and `51/4c_prep_w4_set`, where 7 marks sit beside the story list: "She skips the drink...", "They come up...", "The Mech fights f...". One is also cut on `51/7_journey`: "and she goes for its...".
- New cut-offs are under N5.

**7. Table stats never explained: better.**
- Mood reads "Mood: not known", then "Mood: Talk to see", instead of "?".
- The first report has a tip: "Each player's night, the least happy first, and the bars that carry over. Weeks of low Commitment and someone takes a break."
- Commitment, Trust and Goodwill are underlined, so they probably have hover text.
- **Still unclear:**
  - Investment and Suspicion have no underline and no words anywhere.
  - Nothing says whether "-" next to Suspicion on the report is good or bad.
  - Goodwill is still a heart with no number.

**8. Night 1 not clearly gentler: better.**
- Night 1 had 5 calls (run 51) and 7 (run 54). Later nights had 5 to 20.
- The first frame now shows neutral faces with "listening" (`5r_recap_w1`, both runs).
- The Thought card's timer is 60s.
- **But** run 54's night 1 was still the longest at the table: "3h 49m at the table, wrapping up at 10:49 pm" over 5 rooms (`54/5_night_end_w1`). This is the same pattern as last round's run 34.

**11. Wrong connectors and repeats in the chain: better.**
- **Fixed:** "The Lecturer came at them, and they won, so the drone through the floor stopped." "Biggest huntling" now appears once per chain. "Oswin helped Telpur", "Pip did Telpur's voice" and "Thessaly ... so Thessaly found 2 Francs" are gone.
- **Still there:** "Its scarabs crawled up through the walls to her." (both, week 1). "Its" and "her" have nothing to point back to.
- **Repeated names:** "a tentacle dragged Thessaly into the pond" (`51/6_report_w1`) and "A voice whispered in the dark to Oswin, but something old learned Oswin's name." (`51/6c_chain_w3`).
- The new boss-night ordering problem is N1.

**15. Words a newcomer won't know: better.**
- **Fixed or improved:**
  - "Crits: on" is now "Small crits: on", with hover.
  - "Brannoc remembers something...: +2" and "+6 in your notes" are gone.
  - "dice jail" became "One d20 is serving time tonight: Dev's."
  - One "final roll" now reads "harder (DC +2)".
  - "Subclass" is explained on the level-up card: "Everyone picks a subclass. You don't get a say, and that's the fun part."
- **Still unexplained:**
  - Rules and stats: "Rule of cool", "vorpal sword", "Slots", "Channel" (34–35 screens), "Hit Dice", "Mastery: Vex / Nick / Graze / Slow", "Heroic Inspiration" ("changed hands", "earned").
  - Game labels: "EMPATHY CLUELESS" (28 screens), "final roll: normal" (twice), the card names in brackets "(Light fingers)" and "(A way out)".
  - New term: "cooked" (N8).

**16. Between-sessions screen: fixed.**
- The subtitle now reads "Between sessions: the group chat, and the questions waiting for you before the prep board."
- The promise names its rule: "Last session you made a quick call on "Can I block my ears?" (you said: "Yes. It's a good idea, and it works.")" (`51/3_between_w5`). Others name "stacking bonuses" and "potions" (`54/3_between_w2`, `w5`).
- "that was my third period chemistry class" and "i fell asleep in real life a little" now come straight after the Lecturer night (`51/3_between_w5`), so they land as jokes.
- One new oddity is N9.

**17. Journey screen: better.**
- THE ROUTE lines are no longer cut.
- "Named in a whisper by the Witness" replaces "their name".
- Only Jess's closing quote is word for word the same in both runs: "I want to see where the caravan goes next."
- **Still:**
  - The route is a list, not a chain.
  - Two rooms get just "went their way" (both runs).
  - Run 54 repeats a boss line (N12).
  - The mini-map labels are cut (see the polish list).

### Polish list from last round

- **Fixed:**
  - "Minis: 1 the lecturer." is now "Minis: the Lecturer."
  - "Voice: Flitwidget:" is now "Voice for Flitwidget:"
  - Snapshot captions are capitalised: "The Lecturer falls."
  - "Someone they haven't met" twice is now "2 more people in the museum they haven't met yet."
  - The session log opens on the latest session.
  - The hero sheet says "Jess wants it to be her call." next to "Honour it".
  - The last caption ("And that's a wrap...") now sits below the end card, not under it.
  - The debug "Playtest notes" line is gone; the survey says where answers go.
- **Not seen this round:**
  - "(Brannoc has it)". The boss board now says "a quiver of fire arrows, lifted (Pip)".
  - "Telpur (Jess)'s pointy toe".
- **Still there:**
  - Telpur's entry says "Knows they're taking Telpur along" (`51/4n_notes_people_w3`).
  - Session-log list titles are cut: "1. From the Street to the Chamber of...", "2. The Hall of Paintings and the Hunti..." (both, `4n_notes_log_w3`).
- **Partly fixed:**
  - **Mini-map labels.** They fit on the prep board now (Paintings, Tomorrow, Offices). They're still cut on the showdown board, the journey and Notes > The museum: "S...", "Tomorr...", "Offi...", "St..." (both: `4_prep_w5`, `4b_showdown`, `7_journey`, `4n_notes_museum_*`).
  - **The Session Zero hint.** It was reworded but is now cut off at the right edge: "The table's rule. A player can still ask you for anoth..." (both, `1_session_zero`).

---

## Part 2: New findings

### Bad

**N1. On boss nights, the chain puts the knockouts first, before the fight they happened in** (true, clear). 3 times, all on the two most important nights.
- `51/6_report_w5`: "Brannoc went down. / They chose to fight Euryale. / They forgot the frame and drew steel..." The recap above it says "Brannoc hit the floor mid-fight."
- `54/6_report_w4`: "The whole party went down in the lair. / Euryale knew what the Lecturer had told her. / Pip pulled a painted blade out of the frame. / Euryale came at them, and it was too much for them."
- `54/6_report_w5`: "They lost Hans. Brannoc went down four times. Euryale knew what the Lecturer had told her. They forgot the frame and drew steel."
- Both runs also say "They forgot the frame and drew steel." Neither the newcomer nor the lapsed DM can tell which frame.
- **What would be right:** downs in the order they happened, inside the fight, with a "but" ("they fought Euryale, but Brannoc went down twice, so..."). Also name the frame ("They ignored the painted knight's frame...").

**N2. In run 54, two heroes are turned to stone, and next week everything is normal with no word about it** (true, alive). Caveat: three of the four between-sessions cards that week aren't dumped.
- `54/5_night_end_w4` says "Oswin turns to stone." It also says "Brannoc, Pip and Thessaly come round on the floor with 1 hit point each, groggy, alive, and beaten."
- The same night's recap (`54/6_report_w4`) says "Pip turned to stone. / Oswin turned to stone." So Pip both turned to stone and came round on the floor.
- In `54/3_between_w5`, the chat jokes about the floor ("pip spent half the night on the floor. twice"). Sam says nothing about Oswin being a statue.
- In session 5, Oswin is at "24/24" and rolling Insight (`54/5_night_end_w5`).
- The journey histories (`54/7_journey`) don't mention stone at all.
- **What would be right:** one clear line of what happened to each hero, and a line for how Oswin came back (Flitwidget, a cure, the statues softening). Sam should react in the chat, and his journey history should get a line.

**N3. In run 54, the Steam Mech fights for the party, but they never went to its room** (true). Same caveat about the unseen between cards.
- The journey (`54/7_journey`) says: "Never seen: the offices and the World of Tomorrow."
- Yet the session-5 boss board (`54/4_prep_w5`) lists "the Steam Mech (Hans)" under WHAT THE PARTY BRINGS, with the mark "A machine on their side".
- The Story sidebar (`54/5r_story_w5`) says "Woken: Hans fights for them", and the report (`54/6_report_w5`) says "Hans went into Hyper Destroyer Mode." and "They lost Hans."
- Nothing on any dumped screen says how Hans woke up.
- **What would be right:** if a between card woke him, the journey and the story list should say so ("Between sessions: Thessaly cracked Hans's code from the notes"). Otherwise he shouldn't be there.

### Minor

**N4. The dice box says you hit the score and then gives you nothing** (true), once.
- `51/6r_rewards_w5` says "A happy table earns one: a Table Score of 55 or more (tonight: 55)." Next to it: "No box tonight".
- This is probably 54.6 rounded up to 55. Either round down for display, or give the box.

**N5. New and remaining cut-offs** (clear). Each one cuts the part you need.
- **The report's "why" lines.** 10 of them are cut across the 10 reports (6 Fun lines and 4 suspicion lines), and the same cuts repeat on the level-up and whole-night pages:
  - "+5 Fun from your call "Let them. They know..." (`51/6_report_w1`)
  - "+6 Fun from your call "Second phase! It rises..." (`51/6_report_w3`)
  - "(Five people and some..." (twice, `51/6_report_w2`)
  - ""Everyone on Brannoc."..." (`51/6_report_w5`)
  - "+3 Fun from your call "The enemies break and..." (`54/6_report_w2`)
  - "Suspicious of the cooked Perception roll that..." (3 times, `54/6_report_w1`)
  - "Suspicious of the Arcana roll you cooked behind..." (`54/6_report_w2`)
  - The suspicion lines are the game telling you the table caught your fudge, and they stop before saying which roll.
- **Fork header, 9 screens** (`54` week 3: the prep board, its set version, the hero sheet and all six Notes tabs): "At a fork: The offices, The World of Tomorrow, The lecture..." On Notes > This session it's the page title.
- **Jess's friend card, 4 screens** (`51/4_prep_w4`, `4c_prep_w4_set`, `4_prep_w5`, `4b_showdown`): "Talking to NPCs in voice, and chaos. Don't cut her...". This is her Session Zero promise, cut at the verb.
- **Ties and locks option labels, both runs** (`4t_ties_list`, `4t_ties_room`): "Let them reach in, an...", "Take a closer look. W...".
- **The Story sidebar drops sections without saying so.**
  - In the first weeks it ends with THE WITNESS and the legend "A full ring: keen. A faint one: interested. A red dot: put off."
  - Once the list grows, both vanish with no "more" marker: from `51/5r_story_w3`/`w4` and `54/5r_story_w3` on.
  - In run 54 the Witness was never found, so the thread just disappears.

**N6. In run 51, the knight both left its frame and stayed in it** (true). About 6 lines.
- They fought the knight and it fled: "they fought the Knight of Shades, and it got away. So the knight went to wait in a frame in her lair." (`51/6_report_w2`).
- But:
  - The recap says "One of them got away", though there was only one knight.
  - The recap also says "At the end of the hall, the knight's frame hangs empty."
  - The story list says "S2 The Hall of Paintings: through, with the knight still in its frame" (`51/4_prep_w3`, `w4`).
  - The Story sidebar says "Still in its frame: it'll step out in her lair" (`51/5r_story_w3`–`w5`).
  - Dev's chat line says "we left the knight in its painting and i will regret that" (`51/3_between_w3`). That's run 54's choice, not run 51's.
- **What would be right:** "fought the knight, and it fled to her lair", in every one of these places.

**N7. The friend-quote template breaks** (broken text), twice.
- "The bit where a fight that came down to the wire was a highlight." (`51/6_report_w5`, `6r_rewards_w5`)
- "The bit where Oswin finds what he came for: a bad feeling was cool." (`54/6_report_w2`, `4n_notes_log_w3`)
- **Better:** "That fight that came down to the wire was the highlight." / "Oswin finding his bad feeling in the Hunting Grounds? Cool."

**N8. Fudged ("cooked") rolls are never explained, and one caption looks like a bug** (clear).
- `54/5t_thought_card` says "Pip rolls 2 + 2 = 4. Behind the screen, the DC was 2." A DC of 2 doesn't happen in normal play.
- The report then says "Suspicious of the cooked Perception roll that..." and "Big rolls tonight: 1 in the open, 1 behind your screen, 1 cooked." (`54/6_report_w1`, `w2`; also `51/6_report_w2`).
- Neither the newcomer nor the lapsed DM is told that "cooked" means fudged behind the screen.
- **What would be right:** say it on the spot: "Behind the screen, you let it pass (the DC was 13)." Then one line on what cooking costs.

**N9. A chat reply with nothing to reply to** (fits), twice.
- "can't stop thinking about it either" comes straight after "those huntlings were smart..." (`51/3_between_w4`) and after "do we get a discount at the gift shop" (`54/3_between_w2`). Nobody said they couldn't stop thinking about anything.
- Several chat lines also repeat across the two runs: "bought new dice. they're green.", "@DM what's telpur's deal. is the boot ok", "@DM quick one: does a healing spell work through a closed door", "still think we should've gone the other way".

**N10. Heroes called "their" and "they" on the Level 4 card** (broken text), 8 times.
- The same in both `6b_levelup_w5`: "Their spells are harder to resist" (Thessaly), "Their weapon hits harder" (Brannoc), "their weapon lands more often" (Pip), "they notice more" (Oswin).
- Also "Oswin fails to resist (a CON save, with Advantage: they know to look away)" (`54/5_night_end_w4`).

**N11. Level 4 is called overdue when it's on time** (true).
- `54/6_report_w5` says "Level up to 4 / Overdue: the table keeps asking."
- Every earlier report said "The book's next level comes when the museum is done", and this is that night. Run 51 says "Everyone gets stronger."

**N12. The journey retells the boss nights with a passive line, twice in run 54** (alive).
- `54/7_journey`: "9. The Gorgon's lair (S4): Euryale knew what the Lecturer had told her" and "10. The Gorgon's lair (S5): Euryale knew what the Lecturer had told her".
- One was a defeat and one a win. Neither line says so, and Brannoc's history leaves both nights out.

**N13. A face and its label disagree** (clear), once.
- On `54/5t_thought_card`, Jess's face is the frowning one and her label says "beaming". Sam's face is neutral and his label says "grinning".

**N14. The Thought card points to Empathy in the Table sidebar, which doesn't show it** (clear).
- The tip says "tonight the Table button at the top has both" (Empathy and how well you know each friend).
- The Table sidebar (all 10 `5r_recap_*`) shows only "You know them: new to you / getting to know / familiar". Empathy isn't on it.

**N15. People and sidebars forget things the chain remembers** (alive).
- In run 54, Telpur caught Pip stealing and raised his prices: "Telpur caught her at it, so Telpur put his prices up a Franc." (`54/6c_chain_w1`). His People entry only says "Knows they've rested in the shop." (`54/4n_notes_people_w3`).
- The Table sidebar still says "Drawn to the briar guardians" for Dev in week 5, long after they burned (`54/5r_recap_w5`).

**N16. The side room reads as part of the entrance hall** (clear), both runs.
- `4c_prep_w1_set` says "Side room off here: A museum hall. A donation box full of every coin in the world, and the guard that protects it." It reads as if the side room holds the donation box.
- `51/6_report_w2` lists "Tonight: A museum hall, off the entrance hall, the Hall of Paintings..." The chain never mentions that room, and the recap says "First stop: the entrance hall."

**N17. The sheet's hit points don't match the table's** (clear, for the lapsed DM).
- `51/4h_hero_sheet_w3` says Brannoc has HIT POINTS 28. The table bar that night shows "33/33" (`51/5_night_end_w3`). Thessaly is 25 and Pip is 29, also +5.
- This is presumably Oswin's Aid spell, but nothing on screen says so. Unexplained attack bonuses are similar: "Fire Bolt 18 + 8" at level 2 (`51/5_night_end_w1`), probably Bless.

### Polish
- "Lifted: Pip lifted a quiver of Telpur's fire arrows." (`51/6_report_w4`)
- "Heroic Inspiration changed hands." when Pip simply spent it (`51/6_report_w4`).
- "A harsh call in the stairs up felt arbitrary." should be "on the stairs" (`54/6_report_w3`).
- A stray leading dash: "- Brannoc's story moved tonight..." (`51/6_report_w5`).
- Capitals mid-sentence:
  - "At a fork: The Hall of Paintings and The gift shop."
  - "Something swarmed out of The Bone Construct"
  - "Came for Lying low", "Came for Rumour", "Came for Wonder" (`54/7_journey`)
  - "Left on Euryale's card: She smelled the smoke, A drone through the floor."
  - "(Kruthik Huntlings ran from the fight.)"
- "Done. "Five people and some dice" in the Hall of Paintings: Cut: it never plays." has two colons (`4t_ties_list`).
- "You know them: new to you" reads oddly. Better: "How well you know them: not yet".
- The clock at the top runs 1–2 minutes past "wrapping up at" on the end card: "10:51 pm" vs "10:49 pm" (`54/5_night_end_w1`), and "10:36" vs "10:34" (`51/5_night_end_w3`).
- WHAT THEY'VE BEEN WARNED ABOUT mixes topics ("The pond: something with tentacles...") with a whole reply pasted in: "You rest, and wake to find a statue at the foot of the stairs that wasn't there before." (`54/4n_notes_upstairs_w3`).
- "And that's a wrap. Somebody's already clearing the pizza boxes." is followed straight away by "That's a wrap for tonight."
- The friends pick the same four subclasses in both runs (Wayfinder, Champion, Silvertongue, Hearth Domain). That's at odds with "the friends choose differently from run to run".
- The lapsed DM will notice that Brannoc carries a "+1 Shield" next to a two-handed greatsword.

---

## Five things that most need fixing now
1. **Keep boss-night facts straight in run 54.**
   - Pip both "turned to stone" and "came round on the floor".
   - Oswin is stone, then fine with no word.
   - Hans fights for the party though "Never seen: ... the World of Tomorrow."
   - Whatever happens between a lost boss night and the rematch has to be on screen and in the journey (N2, N3).
2. **Order the boss-night chain.** Knockouts go inside the fight with a "but", not first. Name "the frame" (N1).
3. **Finish the cut-off pass.**
   - The "+N Fun from your call" and "Suspicious of the cooked..." lines.
   - The 54 week-3 fork header.
   - Jess's promise on her card.
   - Euryale's marks on `51/4_prep_w4`.
   - The ties labels.
   - The Story sidebar silently dropping the Witness (N5, item 1).
4. **Clear the small true slips:**
   - "55 or more (tonight: 55)" with no box (N4).
   - The run-51 knight that is both in and out of its frame (N6).
   - "Overdue" (N11).
   - The broken "The bit where..." quotes (N7).
   - "they"/"their" on the Level 4 card (N10).
5. **Explain the last terms where they appear:**
   - "Cooked", and the "DC was 2" caption (N8).
   - Investment and Suspicion, and which way is good.
   - Empathy in the Table sidebar, as the tip promises (N14).
   - "Mastery", "Heroic Inspiration", "final roll: normal".

## Five best moments (keep these)
1. **Running late now has a cost.** "It fizzles a little. Somebody checks the time." then "Ran 34m past the 10:00 pm you agreed at Session Zero... Sam trusts you a little less for it. Sam was fading by 10:29 pm." (`51/5_night_end_w3`, `6_report_w3`).
2. **Telpur's fire arrows across a whole run (54).**
   - Week 1: "Pip went for a quiver of Telpur's fire arrows, and Telpur caught her at it, so Telpur put his prices up a Franc." then "The Lecturer told Euryale about Pip's quick fingers."
   - In the chat: "in my defence a quiver of telpur's fire arrows was RIGHT THERE" / "we're never going back to that shop".
   - On the finale: "Telpur told Flitwidget that Pip had tried to lift a quiver of Telpur's fire arrows."
   - Run 51 has its own version: "Telpur spotted his own fire arrows on Pip."
3. **The boss board settling its own conflicts in plain words.** "Her card wins here: she smelled the smoke, so there's no drink and no small talk." and "With an ambush there's no talk, so handing her the Lecturer's pages won't come up." (`4b_showdown`, `54/4_prep_w5`).
4. **The promise loop.**
   - The between card quotes your own words: "Last session you made a quick call on "Can I block my ears?" (you said: "Yes. It's a good idea, and it works.")"
   - The report remembers: "You never posted the ruling you promised to look up. Sam noticed."
   - Small callbacks land too: Sam's "bought new dice. they're green" becomes "Sam showed off a new set of dice: Jade.", and "that was my third period chemistry class" follows the Lecturer night.
5. **The whole-night page and the chain lines that work.**
   - "In the gift shop... so Telpur put his prices up a Franc."
   - "the party followed the scratch marks, weapons out, and they won, but some got away, so the huntlings that ran went to her."
   - "Hans went into Hyper Destroyer Mode."
   - The bleak run-54 loss: "Her laughter follows them all the way down the stairs."

My scratch extractor is in /tmp/claude-0/-home-claude/6545778f-6f8d-5d88-b2f4-2abfe14c8e6f/scratchpad/pt4tools/. I didn't use anything from memory.
