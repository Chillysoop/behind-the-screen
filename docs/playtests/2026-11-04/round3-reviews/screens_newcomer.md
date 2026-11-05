# Playtest round three: whether each screen is clear (newcomer and lapsed DM)

I read every screen dump in order for both runs: `screens_31` (4 nights, ending "asleep") and `screens_34` (5 nights, same ending). Both live in /tmp/claude-0/-home-claude/6545778f-6f8d-5d88-b2f4-2abfe14c8e6f/scratchpad/playlogs3/. I didn't read any code. The smoke files only hold one summary line each.

**What the dumps don't cover.** They have no mid-night call cards except one Thought card per run. So I couldn't check four of the new things directly:
- "one call of each kind, each with a tip" on night 1
- the "Light fingers" card
- Telpur's price list
- any "Behind your screen" notes panel

Wherever a finding says something is "not on screen", that's the reason.

## Findings by severity

### Bad

**1. Prep-board text is cut off where it matters most** (clear). This was the most common problem in both runs.
- **The "Game night" forecast for each friend.** It's cut off in 26 of 36 cases across 9 prep boards: "Should enj...", "May be bo...", "May check...", "Probably f...". Only "Will love it" fits.
  - Files: every `4_prep_w*`, `4c_*`, `4t_board_locked`.
- **The marks on Euryale's card (UPSTAIRS section).** Every prep board from session 2 on cuts them off: "She skips the drink...", "They come up...", "Nothing comes up from...", "A scarab swarm joins...", "She's curious about them, an...", "Advantage on...", "Her stare can be...".
  - Files: `31/4_prep_w2-w3`, `34/4_prep_w2-w4`.
  - The full text only appears in Notes > Upstairs and on the report.
- **Room notes.** The comfort rules get cut exactly where they say what to avoid:
  - "Sam's ..." (seen 28 times)
  - "Sam's veil: kruthik huntlings, armoured a..."
  - "Mara's line: the archivist at his desk, with eyes c..."
  - "...the first hint of something called the..." (the clue word, "the Witness", is lost)
  - "...Flitwidget Francs. Th..."
  - "Side room off here: A museum hall. A donation box full of every coin in the worl..." (`4c_prep_w1_set`)
- **Boss-night choices** (`31/4b_showdown`, `34/4b_showdown`):
  - "As in the book: a drink, some questions, then an..."
  - "No talk, no deals: her bow is drawn when they rea..."
  - "As the book allows: beaten badly enough, she asks..."
  - "WHAT THE PARTY BRINGS: ... the..."
- **Spare hours:** "Write a backup page (1h): The first room tonight you didn't prep (a side room, a detour, one past tonight's)..." (18 times, `34/4_prep_w3-w4`).
- **Fix:** let these rows wrap, or show the full text on hover.

**2. The report's "HOW IT WENT, ONE THING TO THE NEXT" chain stops partway through the night** (clear, true). It seems to run out of room above the snapshot strip; there's no "more" marker. It's incomplete in 6 of 9 reports:
- `31/6_report_w1` ends at "They went into the entrance hall." The Chamber of Ancients (Oswin's payoff) is missing.
- `31/6_report_w2` ends at "They went into the Hall of Paintings." The Hunting Grounds, offices and World of Tomorrow are missing.
- `34/6_report_w1` ends at "The briar triceratops came at them, and they won." Three of five rooms are missing.
- `34/6_report_w2` ends at "They went into the Hunting Grounds, the place Oswin came for." The fight is missing.
- `34/6_report_w3` ends at "A voice in the dark said Thessaly's name." The whole lecture theatre is missing.

The WRAP-UP column looks capped too: `31/6_report_w2` is the only mid-prologue report with no "At a fork" line.

**3. Nights run far past the agreed end time and nothing on screen reacts** (true, fits). Session Zero sets "7 to 10" (Sam: "Perfect. I've got work on Friday.").
- `31/5_night_end_w2`: "12:24 am (till 10:00 pm)", "5h 24m at the table... 24 calls made."
- `34/5_night_end_w1` (night 1): "10:58 pm (till 10:00 pm)", "3h 58m".
- Neither report mentions it, yet early finishes always get a line ("Finished 1h 8m early", "Right on time (2h 51m)"). Sam still says "Same time next week?"
- **Fix:** end the night at the agreed time, or make running over cost something and say so.

**4. Boss reward doesn't match** (true).
- The boss board says: "If she gets away, Flitwidget pays half the reward: 15 gold each, not 30."
- The final report says: "Picked up: 40 gold each and a pick from the gift shop." (`31/6_report_w4`, `34/6_report_w5`)

**5. Heroes still called "they"** (broken text), 6 times.
- Group chat: "brannoc finally found what they came for" (`31/3_between_w2`), "pip finally found what they came for" (`34/3_between_w2`), "oswin finally found what they came for" (`34/3_between_w3`).
- Journey: "Heard the Witness whisper their name" for Oswin (`31/7_journey`) and Thessaly (`34/7_journey`).
- Report: "Brannoc's story moved tonight: why they came to the museum." (`34/6_report_w5`)
- Related: Mara gets "Their Goodwill filled up this week." (`34/6_report_w5`), although cards say "Read her". Telpur is "he" in his People entry but "they are a shoe" in chat, and the Story sidebar says "Telpur: Their best customer's friends" (`31/5r_recap_w3-w4`), which is hard to parse.

**6. I couldn't find the CARRYING list anywhere** (clear).
- The hero sheet (`4h_hero_sheet`, session 1 only) shows "GEAR: Leather Armor, Shortsword, Dagger, Shortbow, 1 healing potion".
- Notes > The party (`4n_notes_party_w2/w3`) lists no items, even after "Picked up: the Mech manual (Oswin has it)."
- The only inventory on screen is the boss board's "WHAT THE PARTY BRINGS", and it's cut off.

**7. Table stats are never explained** (clear). This hurts the newcomer most.
- Every report shows Commitment, Investment, Trust and Suspicion marked "-", "=" or "+". Nothing says what they are, or whether "-" on Suspicion is good.
- "Goodwill" sits on every prep card with no number or meaning.
- "Mood this week: ?" is "?" in all 36 cases.
- Only Trust gets a definition, in the warnings tip.

### Minor

**8. Night 1 isn't clearly gentler** (clear).
- It had 7 calls (run 31) and 8 (run 34). Later nights mostly had 4 to 9. In run 34, night 1 was also the longest night (5 rooms, ran late).
- Tips I did see, all good:
  - "It plays itself" (`5r_recap_w1`)
  - the Thought card's explanation of your own stats, with odds ("You need 8 or more: about 65%")
  - the "Small-moment crits" hover text
- Problems with night 1:
  - The first card arrives "Before the first scene" with a 30-second timer.
  - The very first frame shows all four faces frowning while their labels say "listening" (`5r_recap_w1`, `5t_thought_card`).

**9. The Thought-card tip points to the wrong key** (clear). It says "the Table sidebar tonight (S)", but the key strip says "S recap", and the buttons are named "Story" and "Table". (`5t_thought_card`, both runs)

**10. A failed read still gives a clear answer** (true, clear).
- Run 31: "You rolled 4 + 0 = 4, needing 8." then "you can tell what's behind it. Jess has good news, bursting to get out."
- Run 34's fail reads properly: "You can't tell what's going on with Mara right now."
- Files: `31/5t_thought_read` vs `34/5t_thought_read`.

**11. Wrong connectors and clumsy repeats in the chain** (true, polish).
- "The Lecturer came at them, and they won, but the drone through the floor stopped." This should be "so". (`31/6_report_w3`)
- "...but the biggest huntling left came at them, and the biggest huntling left fell." (`31/6_report_w4`). Run 34 has the same shape with "the scarab swarm" twice. Both open with "She" before Euryale has been named. "Biggest huntling left" appears 5 times in one report.
- "Thessaly had a look at the piles of books, so Thessaly found 2 Flitwidget Francs."
- "Oswin helped Telpur." (both runs, w2) doesn't say what he did.
- "Pip did Telpur's voice, all of it." (`31/6_report_w2`, journey). The call was the DM's "Do the voice. All of it."

**12. Wrap-up headlines contradict the moods** (true).
- "A mixed night: some loved it, some less so." appears when nobody loved it, 4 times (`31/6r_rewards_w1`, `w3`; `34/6r_rewards_w2`, `w4`).
- After the last night: "Most of them can't wait for next week." (`31/6r_rewards_w4`)
- The wrap screen and the report also disagree, e.g. "A good night" vs "A decent night. Not everyone was into it." (31 w4).

**13. Boss board contradicts itself** (clear). The mark "She skips the drink and the small talk" sits next to "She talks first: As in the book: a drink, some questions..." Nothing says which one wins. (both `4b_showdown` screens)

**14. Small number and fact slips** (true).
- Report says "(5 in the pool)" (`31/6_report_w2`), then the next prep board shows FRANCS 7 with no reason given.
- "1h 53m" on the night-end screen vs "(1h 52m)" on the report (31 w4); "2h 52m" vs "(2h 51m)" (34 w2).
- "At the top of the stairs. Euryale is waiting." (`31/6_report_w3`), but the next read-aloud says they "waited at the foot of the stairs while Pip crept up alone".

**15. Words a newcomer won't know** (clear).
- Unexplained terms:
  - Rules and stat terms: "Rule of cool", "vorpal sword", "Crits", "AC" (only once: "matching the AC is enough"), "Slots", "Channel", "Hit Dice", "Aid", "Mage Armor", "subclass", "Minis".
  - Newer-rules terms: "Mastery: Vex / Nick", "Heroic Inspiration" / the "Inspire" button. These will throw the lapsed DM too.
  - Game-specific and slang: "dice jail", "EMPATHY CLUELESS", "+6 in your notes", "final roll: normal".
- Unclear lines:
  - "Brannoc remembers something from the break's reading: +2." (`31/5_night_end_w4`)
  - Card names in brackets like "(Picks out)".
- "Crits" means two things: the "Crits: on" small-moment cards, and Dev's "Crits and deaths where I can see them."
- "Talk 2h" on the friend cards vs "talk to a friend (1h)" under spare hours.

**16. Between-sessions screen** (clear).
- The subtitle promises "what's changed since last time", but no such section appears.
- "A PROMISE: Last session you made a quick call on that rule" doesn't say which rule (w4, both runs).
- Chat oddities:
  - "that bit was SO good" right after "boss fight next week" (`31/3_between_w4`).
  - "i fell asleep in real life a little" / "that was my third period chemistry class" appears in both runs.
  - "best part of the night tbh" sits just before "i fell asleep in real life" (`34/3_between_w4`).

**17. Journey screen** (clear, alive).
- THE ROUTE is a list of one line per room, not a "so / but" chain, and it's cut off: "made the hunters come t...", "fought the...", "she goes for its...".
- Mara's, Dev's and Jess's closing quotes are word for word the same in both runs.

### Polish
- "Minis: 1 the lecturer."
- "Voice: Flitwidget: quick, proud..." (two colons)
- "fire arrows and slime (Brannoc has it)" (should be "has them")
- Snapshot captions start lowercase: "the Lecturer falls."
- "Telpur (Jess)'s pointy toe hits The Lecturer"
- Telpur's own entry says "they're taking Telpur along"
- "Someone they haven't met" appears twice on the People tab
- Session log opens on session 1 even at week 3
- Truncated titles: "At a fork: ...The gif...", "2. The Gift Shop and the Hall of Painti...", "The prologue is over: your table's..."
- Mini-map labels: "Str...", "S...", "Entran...", "Tomor...", "Offi..."
- Session Zero hint before you choose: "Each player can still ask for their own." is cryptic.
- Hero sheet: "Jess would rather: their choice." next to an unexplained "Honour it" button.
- The night's last caption ("That's a wrap. Chairs scrape...") is drawn underneath the end card.
- Debug-style text: "Playtest notes are saved after every week."

## Five things that would most improve the game
1. **Make the prep board readable.** Wrap or add hover text for the friend forecasts, the marks on Euryale's card, the veil and line notes, the boss choices and the backup-page text.
2. **Show the whole night in the report chain**, and fix its "but"/"so" words and repeated nouns. The journey should be a chain too.
3. **Respect the Session Zero end time.** End the night, or make running over cost something and say it on the report.
4. **Put the new systems on screen with a one-line explanation each:** a CARRYING list on the sheet and the party tab, Telpur's prices, Mood and Goodwill, and what Commitment, Investment, Trust and Suspicion mean.
5. **Clear the consistency slips:** heroes called "they", 30 vs 40 gold, headlines that don't match the moods, the failed read that still answers, and the "S" key.

## Five best moments (keep these)
1. **Notes > Upstairs** explains every mark with its cause: "(They set her garden on fire.)", "(You tied it to happen.)", "(Flitwidget slipped them one.)". Both runs.
2. **The boss board's "IF SHE GETS AWAY" line.** One plain sentence about what it costs. It's the clearest card in the game.
3. **Telpur comes along:** "He insisted, loudly, until somebody tied him to a pack strap." That's followed by the warning "talks during every sneaky bit" and his People entry remembering it (run 34).
4. **Chain lines that work:** "They set the bushes on fire, so Euryale smelled the smoke upstairs." / "Pip picked the office lock, but the pick snapped, and a shoulder did it in the end, so Thessaly came away with the archivist's notebook." / "Flitwidget saw what was left of his garden."
5. **Mara's leather notebook gift** ("Yours is held together with tape.") with "How do you take it?" and its tip, the level-up handwriting ("Crits on a 19. NINETEEN."), and "'Let's leave it there for a first night.' Nobody argues."

My only scratch scripts are text extractors in /tmp/claude-0/-home-claude/6545778f-6f8d-5d88-b2f4-2abfe14c8e6f/scratchpad/pt3tools/. Nothing else was written, and I didn't use anything from memory.