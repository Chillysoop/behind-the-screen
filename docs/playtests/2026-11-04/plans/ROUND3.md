# Round three fixes: what the playtest found

Five fresh-eyes reviews of v2-museum at e691363 (24 headless prologues, seeds 31 to 38 with the careful, random
and careless sim DMs; two full UI runs dumped screen by screen; one real-engine prologue). The reviews, with exact
quotes and file:line or seed/week references, are in
/tmp/claude-0/-home-claude/6545778f-6f8d-5d88-b2f4-2abfe14c8e6f/scratchpad/reviews3/:
- careful_dm.md (truth and continuity, careful DM; B1-B17, M1-M17)
- random_dm.md (truth and fit under odd DM choices; T1-T15, P1-P6, F1-F7)
- alive.md (repetition and variety across all 24; findings 1-22, with counts)
- screens_newcomer.md (every screen as a newcomer and a lapsed DM; 1-17 plus polish)
- engine_screens.md (the real-engine screenshots), when it's there
The logs they read are in /tmp/claude-0/-home-claude/6545778f-6f8d-5d88-b2f4-2abfe14c8e6f/scratchpad/playlogs3/
(prologue_<seed>_<style>.txt, screens_31/, screens_34/). Runs are repeatable: `lua tools/sim/museum.lua <seed>
<style> log` reproduces a log exactly, so every finding can be reproduced before and after a fix.

The fixes are split into four batches by area. Each batch owns its findings; where two batches meet, the one listed
owns it and the other keeps its change small. The bar for "fixed": the finding no longer happens in the seed it was
seen in, a check holds it (a whole-prologue case or a targeted one, failing on e691363), and nothing that passed
before fails.

## A. State and fights (worktree bts-r3a, branch r3-state)
1. Alive, down, stone, charmed and dead gate everything: no line, check, card, twist, vote, small moment, friend's idea
   or epilogue scene for a hero who can't act; a dead hero's player speaks only as themselves (or plays what they chose);
   the wake comes after the lair, Flitwidget acknowledges the dead, the recap leads with the death. (careful B1, B6,
   B17, M3; alive 17 "I'm moving my mini" while down; random F5.)
2. Friendly fire is said aloud and the table reacts (careful B2; alive 12: Shatter hit allies 12 times).
3. What's destroyed stays destroyed across weeks: an ally (Owen the Steam Mech), foes killed last week, "woke the Steam
   Mech" after it burnt out; Euryale's second meeting knows about the first. (careful B3, B13.)
4. The big payoffs are narrated, with a reaction: the mirror (she meets her reflection), turning to stone and breaking
   free, Hyper Destroyer Mode, being charmed, a natural-20 death save; Telpur's knockout in more than one way. (careful
   B14; random P3; alive 11, 12.)
5. The DM's targeting picks and announced taunts steer the foes; "how do you want to do this?" goes to whoever really
   lands the blow. (careful B8, B9; random T10, T11.)
6. After a wipe or "they back out", nobody browses: the night reacts to what just happened. No look-arounds after
   leaving a room. (alive 13; random F5; careful M6.)
7. Recaps lead with the losses (deaths, downs, an ally lost, a wipe) and say "smashed", not "stilled", when it came to
   blades; a destroyed Sentinel doesn't "watch them leave"; the Lecturer who escaped isn't "silenced". (careful B7, B13,
   B16; random T2, T3; alive 20.)
8. The break comes at a lull, never between the boss stand-off and initiative; a night that runs past the agreed end
   time is said and costs something (Session Zero's end time). (alive 10; careful M16; screens 3; random F6.)

## B. Who did it, what they have, what it cost, who remembers (worktree bts-r3b, branch r3-world)
1. One owner per action, from the event log: the hero the setup names is the one who rolls, gets the loot and the
   credit (the lock card, the Telpur voice, praise lines, the painted weapon, the notes, the rules question's asker,
   the potion drinker). (careful B4, B12, M5; random T1, T4, T6; alive "other bars".)
2. Only what's owned fires; what's given is shown being given: Telpur's slime, the stolen fire arrows (Telpur notices
   his own stock, and doesn't sell back what was stolen), Flitwidget's bracelet handed over, the marbles, the vorpal
   sword when the DM said yes, the red switch offered in the lair, "first pick" honoured, "Pip pockets something small"
   names what and it comes back, no loot twist with no loot. (careful B5, B15, M12, M17; random P1, P2, P5, P6, T12.)
3. Money adds up: the chain credits Francs to who found them for what they did; the pool matches what was heard; the
   reward is one number everywhere (the boss board, the haggle, the report: 30, 40, halved for an escape); a deduction
   for breakages changes the number and only counts real breakages; "thirty gold" is said before anyone calls it low.
   (careful B10, B12, M9; random T5, T8, T12; screens 4, 14; alive 19 and "haggle".)
4. Memory and knowledge are true: friends know only what the party learned (the Witness, the jugs, the lady by the
   mountains, the sign); Flitwidget remembers the stolen draught (and not when Pip was caught), "robbed" not "tried to
   rob", "they took his job" doesn't read as theft; "They'd been warned" only when they were; Flitwidget isn't heard in
   the lair; Session Zero's agreements are either made at Session Zero (a short lines-and-veils beat) or not quoted.
   (careful B11, M7, M10; random T7, T9, P4, F7; alive 9's untrue callbacks.)

## C. Words, votes and the chat (worktree bts-r3c, branch r3-words)
1. Votes: bids come from the moment and each friend's state, not their seat; no friend overturns their own bid a line
   later ("Okay, okay."), a cave answers someone else's push; reasons match the option's lean; "last time" claims are
   true; "I lost last time" in more words and naming what was lost; a silent friend's deciding vote is shown; the
   winner never says the loser's line; outvoted thoughts only when outvoted. (alive 1-5; random F1-F3; careful M1, M8.)
2. Look-around and the friends' ideas: fewer, object-specific reactions, none when there's nothing to say; a wider
   pool of ideas per room. Dev's barks keyed to how the fight went. Lines fit the hero (no blade for Thessaly, no shield
   for Brannoc) and the room (no lock in the paintings, no roof, no puzzle in a fight room). (alive 6-8, 16, 17; random
   F4; careful M11, M15.)
3. The group chat is written from what happened: no fixed script, no DM card titles, no untrue callbacks, one line per
   moment, friends' news that does come out. (alive 9, 14; careful B11's chat part.)
4. Pronouns everywhere: chat ("finally found what they came for"), Euryale never "it", one foe never "them". Broken
   text and template leaks from all four reviews' polish lists. Session Zero's duplicate reactions. Break and rest
   moments from wider pools; pet and ally lines that don't repeat word for word. (alive 10, 11, 15; careful M13; random
   broken text.)
5. The chain and the journey read as a story: no bare "They went into X" unless it carries a reason, no tautologies
   ("fought the guardian, so they fought the Bone Construct"), no garbled clauses, real connectors; the journey a short
   story per room, not a cut-off list. (alive 18, 21, 22; careful M14; random T15; screens 11, 17.)

## D. The screens (worktree bts-r3d, branch r3-screens)
Everything in screens_newcomer.md and engine_screens.md that's about what's on screen: cut-off text on the prep board
(friend forecasts, Euryale's marks, room notes, boss choices, spare hours), the report's chain cut short, a CARRYING
list on the sheet and the party tab, the table stats explained, the Thought card's key, a failed read that still
answers, headlines that disagree with the moods, the boss board's contradiction, minute mismatches, unexplained terms
(hovers), the between-sessions subtitle and "which rule", the journey's cut route, and the polish list. Plus what the
engine screenshots show (minis, Exhibit B, overlaps, layout).
