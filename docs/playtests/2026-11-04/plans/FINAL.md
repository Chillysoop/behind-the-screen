# The final fix pass, from the confirming playtest

Four confirming reviews of r3-int (24 new prologues, seeds 51–58 with the careful, random and careless sim DMs; two
UI runs dumped screen by screen; one real-engine prologue), each checking last round's findings and reporting new ones:
/tmp/claude-0/-home-claude/6545778f-6f8d-5d88-b2f4-2abfe14c8e6f/scratchpad/reviews4/
- truth_confirm.md (truth and fit; careful and random runs)
- alive_confirm.md (repetition, variety, the chain; all 24)
- screens_confirm.md (every screen, newcomer and lapsed DM)
- engine_confirm.md (the real-engine screenshots; crops in reviews4/crops/)
The logs: /tmp/claude-0/-home-claude/6545778f-6f8d-5d88-b2f4-2abfe14c8e6f/scratchpad/playlogs4/ (runs are repeatable:
`lua tools/sim/museum.lua <seed> <style> log`; the UI runs: `DUMP_DIR=<dir> lua tools/tests/museum_smoke.lua 51` or 54).
Last round's reviews and the batch reports are in reviews3/ and reports3/ for context.

Three batches, each in its own worktree from r3-int at bfa5157. Each owns its findings; where two meet, the one listed
owns it and the other keeps its change small.

## F1. Facts (worktree bts-f1, branch f-facts; check file tools/tests/final_facts_check.lua)
- **Blocker:** a Steam Mech (Hans) fights for a party that never woke it, after the between-sessions loose end
  "mech_left" (truth N1, 57 careful W5; screens N3, 54). Its mark says "They woke the Steam Mech". Only what happened can
  come back: find what the loose end really does and make every line, mark, board and recap say that.
  Same run: Euryale's "Your Witness writes beautifully" without the notebook.
- After a lost boss fight: heroes turned to stone are back the next week with no word (screens N2); Pip both stone and
  "came round on the floor" the same night. Say how each came back.
- Deaths everywhere (truth B1, B3, N2–N4, special-attention list): the wake where the party is (not a gift shop they
  haven't reached, not with Telpur before they've met him); no chat questions about a dead hero's skills; the last-words
  card gives real last words; the epilogue names the dead; Euryale remembers beating them after a wipe; the dead hero's
  pack picked up where it fell; a fallen hero's running joke set down or handed on.
- Money and memory in the recaps (truth B10, B11, B12, N6, T5; alive N4, N6, 19): no donation-box charge after they gave
  to it; the recap repeats the reason and amount Flitwidget said; no bare "saw what was left" with nothing behind it;
  "sisters back" only when earned; the daggers credited to who carried them; "went for the lock" only if she did; one
  roll's two Francs said as two; the "Along the way" tally matches.
- Contradictions and slips (truth M4, B6, T9, T14, T15, P1, P6, N5, N8, N10, N11; screens N1, N4, N6, N11, N15, N17;
  alive N5, 12; engine "Big rolls 0/0" and Mara's "quiet all night"): the bird (sings first; nobody "can't place" it once
  named); sleeping or stone monsters don't move; "they'd been warned" only when warned; the scarabs that "go to her"
  after being killed; Hit Dice; "the last huntlings scatter" after the last one fled; the vorpal sword and first pick;
  Pip alone on the stairs (a save or "glimpsed her"); Telpur "to her face" after she's gone; "Lovely to meet you" to
  someone met before; lines followed by their opposite; things in places nobody is; the boss night's chain order
  (knockouts inside the fight, and name "the frame"); the dice score shown as 55 with no box; the knight both in and out
  of its frame; "Overdue" for an on-time level; people's entries forgetting what the chain remembers; the sheet's HP vs
  the table's (say Aid); the failed Mech code said twice; the mirror, Hyper Destroyer Mode and the failed notebook in
  the recap; the report's "Big rolls: 0 in the open, 0 behind your screen" beside a natural 20; a friend's "I've been
  quiet all night" after two votes went her way.

## F2. Words (worktree bts-f2, branch f-words; check file tools/tests/final_words_check.lua)
- Bids and moods from the moment, not the seat (alive 1, N2): the opening bids (Dev fights the garden, Sam's coin,
  Mara's ritual, Dev's knight, Jess's daggers and wine, Dev's "fight her", the yield's three bids) and Sam "tired" 27
  times. Keep R10 (roadmap_table_check) holding; report the before/after per beat.
- The table reacts to payoffs (alive 12): the mirror, Hyper Destroyer Mode, the vorpal sword in hand.
- Templates checked against the facts (alive 3, N1, N3, 8; truth T6, M15, N7, N9): "I said yes when we X" (say "I went
  along" and only when they did), "That one hurt" after no damage, "X's plan, Y's timing" and "a move together" with no
  plan or joint move, "There's a manual for this?" after buying it, Mara's "doesn't add up" with no roll, "Not a bad
  fight" after a death, the chat's false claims ("that last hit was pip's", "the way the DM wanted", buying marbles
  already bought, "incidents"), the same news told twice, the filler list (M15), lines about a lever, the old archives,
  a chandelier that aren't there (F4).
- Votes count only voices the table heard (truth M8): 22 of 41 tie asides follow three voices.
- Variety where runs are the same script (alive N7, N8, 11, 17): Session Zero's limits and reactions, the reward scene,
  Exhibit B's 11 stock lines, Thessaly as the only unhappy reactor; Session Zero quotes never agreed ("rare and
  meaningful", "10:30 pm") (truth M7); a DM question never answered (truth N12).
- Broken and repeated quotes (screens N7; engine "The bit where on the dead archivist's desk..." and the same quote from
  Dev and Jess); pronoun leftovers (Flitwidget "they're here" on the Ties card; "Their spells..." on the Level 4 cards).

## F3. Screens (worktree bts-f3, branch f-screens; check: extend tools/tests/round3_screens_check.lua)
- The real engine (engine_confirm.md): Euryale and Pip missing from the boss-night frame while the table bargains with
  her (8_53); heroes hidden behind the offices' partitions (8_36) and Thessaly in 8_25 (placement is fight.squares_shown
  and night:staging: make walls count, not just other minis); the key strip's backing; the toast header's cut letter and
  stray underline; the prep header showing through Ties and locks; prep hours 10 to 8 on the boss board unexplained;
  the handwriting font's capital k (a different font: tools/gen_ui.py); a speech bubble over the room title before the
  mini lands; a board swapping mid-air under the title; a cut dice name.
- The dumps (screens_confirm.md): the remaining cut-offs (the report's "+N Fun from your call" and "Suspicious of the
  cooked..." lines, the fork header, Jess's promise on her card, the ties labels, mini-map labels on the boss board,
  journey and notes, the Session Zero hint); the Story sidebar dropping sections without a "more"; "cooked" and the
  "DC was 2" caption explained; Investment and Suspicion explained, with which way is good; Empathy shown where the
  Thought card says it is; a face that frowns beside "beaming"; the polish list.
