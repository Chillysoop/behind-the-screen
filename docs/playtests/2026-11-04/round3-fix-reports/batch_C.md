Batch C (words, votes and the chat) is done on branch **r3-words**, pushed through 6d2219b with 7 commits from e691363. All five ROUND3 items are fixed, along with the engine review's items 7, 8 and 10. The full gate passes. The new check, `tools/tests/round3_words_check.lua`, passes on my branch and fails every item on e691363 (942 failures; I confirmed this in a throwaway worktree at e691363, which I have since removed).

The "Before" and "After" numbers below come from the 24 reviewer logs (seeds 31–38, three DMs). I used `pt3alive/votes.py` unchanged except for its log folder, plus my own measures in `scratchpad/r3c/tools/measure.py`.

## C1. Votes
- **Cause.** Each friend's lean was their player type times large card effects, plus noise of 1.6. Mood and habit reasons were attached by a derived kind that called the ritual "bold" and fire "neither". A friend who spoke would cave on the very next line with "Okay, okay." The credit named silent friends. Forks never cleared a friend's grievance from the vote before, and `wanted` was recorded before the lead's vote was fixed.
- **Fix** (`museum_night` `carry` and `table_pick`, plus module data):
  - **Bids come from the moment:**
    - A friend's taste is softly capped, and the moment's pulls weigh in at `VOTE_MOMENT` 0.7.
    - New pulls: their hero hurt or another's, a rough or easy last fight, boredom, and what the card's words point at (`points`, the lead only).
    - Option `pulls` read what happened earlier ("We've already burnt his garden. Let's not rob him as well."). The friend carrying the pond key wants to use it (`uses`).
    - A friend who has had a big night speaks last.
    - Once a vote, a friend close to the first speaker may back them instead of their own pick.
  - **Reasons fit the option.** Options now carry `lean`, and every reason is checked against it.
  - **Caves.** A friend gives way only after another friend pushes, at most once a vote, in their own voice (`VOTE_PUSH_LINES`, `VOTE_CAVE`).
  - **Silent votes are shown.** A quiet friend whose vote settles it says so (`VOTE_SIDE`), and a two-against-two tie says how it broke (`VOTE_TIE`). The credit names only friends the table heard. Only friends whose heroes are in the scene vote.
  - **"Last time" is true:**
    - The habit reads only the vote just gone.
    - Named forms say what was lost ("Last time I let you have a go at the lock.").
    - A fork clears the grievance of anyone who got their way there.
    - The habit and "I lost last time" reasons are only said when something is at stake, and the latter once a night per friend.
  - **Winners.** A friend who just backed the room doesn't grumble about it. No fight barks play once a room is settled without a fight.
  - **Thoughts and short forms.** "Outvoted" in a thought only when she was outvoted. Options have `short` forms for second voices.
- **Numbers (before → after):**
  - Fixed-seat bids ((card, friend) pairs with one bid in 90%+ of runs): 20 of 59 → 10 of 56.
  - Same-breath reversals: 47 → 0 (reviewer's script); 33 → 0 (my stricter one).
  - Mismatched reasons: 35 → 0.
  - False "I lost last time" claims: 8 → 0.
  - False history claims: 19 of 63 → 1 of 43. The reviewer's script ignores forks; my check, which counts forks, finds 0 of 148.
  - Decisions crediting a silent friend: 184 → 0.
- **R10:** overall commonest pick 54%, worst measured card 64% (Hyper Destroyer Mode). To keep R10 passing I retuned some option weights in the module: the tablet, knight, Mech switch, mirror, lair frame, trail and lock. Margins are thin: any change to the order of random draws moves a card by ±5–8 points. Rerun R10 on r3-int after A's `table_pick` change.
- **Left:** strong tastes still show (Dev looks closer at the knight in 22 of 24 runs, Sam drops a coin in 26 of 27, Mara does the ritual in 24 of 24); pushing harder broke R10. I didn't build "a third idea".

## C2. Looking round, small looks, barks, fit
- **Look-around.** Each place now has its own lines (`MODULE.explore_say`), only the first look in a room gets a word, and a place with nothing to say gets nothing. Stock look lines: 232 → 0. Reactions per prologue: 11.5 → 7.1, each about that thing.
- **Small looks.** Curios take `asks` (several ways to say what they do). I added three new stair curios and two for the World of Tomorrow. Distinct small looks: 56 → 97. Thessaly no longer has a blade, Brannoc has no shield, and "Out of habit" is gone.
- **Dev's barks:**
  - "Too easy" doesn't play after 5+ rounds, a close call, or a boss who fled or yielded.
  - "Nobody tell my character…" only comes from the friend whose hero came close.
  - "Finally" only at the night's first fight.
- **Room fit.** New `barks.context` facts: lines about a lock, statue, puzzle, roof or ending play only where there is one, and banter is filtered too. Rooms now carry `locks` and `statues`.
- **Left:** Exhibit B's lines and Telpur's knockout still repeat word for word.

## C3. The group chat (`museum_week.night_lines` and `write_chat`, `M.CHAT`, `M.CHAT_REPLY`)
- **From the event log.** Posts cover:
  - downs, counted truly (twice, three times)
  - a lost fight
  - Pip caught at someone's stock
  - the moment that made or spoiled a night, in the party's own words ("when we gave the knight a wide berth"), never a card title
  - one post for however many heroes found what they came for, with each hero's own pronoun
  - good news the table never heard (`MODULE.chat_news`)
- **Rooms and replies.** Room posts only say what happened there, three ways each; "good fight though" only after a win. Replies answer the post. There are three first-week openers, and the week's question is one that fits.
- **Sad weeks.** After a death or a lost fight the chat has no jokes or small talk. A's `able.somber` can replace my check at the merge.
- **Numbers (before → after):**
  - Card titles quoted in the chat: 64 → 0.
  - Posts that are lines heard in half the runs or more: 59% → 13%.
  - Distinct chat lines: 115 → 189.
- **Left:** two questions stay in fixed places by design (the first one, and the rat question the week it opens, since Exhibit B joins from it).

## C4. Pronouns, broken text, pools
- **Pronouns:**
  - Euryale: the boss card now says "Who does she go for? She attacks with her…", and killing-blow lines use the boss's own pronouns.
  - Single foes: no "behind them"; the mat's numbered names ("Briar Beast 1") aren't spoken.
  - On screen: "Her Goodwill", Flitwidget's "he's here", and "why he came".
  - Other "they" lines fixed: the mirror and Mech chain clauses, and two heroes now "went off together".
- **Spoken labels.** Fork lines are said without the card's brackets, so no "(to spend Francs)" aloud and no "on on".
- **Polish:**
  - "Euryale lifts her hood".
  - The clay jars are named as her sisters.
  - A find no longer turns into a Franc.
  - The prologue's last lines name the hero the friend plays now (this was a museum_truth failure when Pip had died).
- **Session Zero.** Each reaction once per round, by the hero's pronoun; no "Tea guy".
- **Pools.** Seven break-start and seven break-end lines (was four each); eight rest moments (was two). A friend's lines now stay fresh for 5 weeks (was 3).

## C5. The chain and the journey (`events.chain`)
- A plain step into a room says where the next thing happened ("In the entrance hall, they dropped a coin in").
- A fight told after the choice that started it gives only how it ended (a new `tail` field on fight events).
- A beat that repeats its cause is left out, or keeps only its new part (`MODULE.beats.same`).
- The Francs found are folded into one "Along the way…" line at the end of the night.
- Euryale is named before she is "she", and a mark taken off by what just happened is a "so".
- **Numbers:** bare "They went into X" lines 202 → 0 (two hooked lines carry the reason). Tautologies 23 → 0.
- The journey reads the same per-room chain. The screen layout and cut-off are D's.

## Gate
Everything passes:
- `museum_smoke` seeds 1–8; the 12 sims; `museum_truth`; `playtest_nov3_check 4`; `table_life_check 2`; `save_check` (417/417).
- `round3_words_check`; all four roadmap checks (R10 held).
- `thoughts`, `barks`, `dialogue`, `ties`, `rest` and `standing` checks; `require_check`; `validate`.
- Dialogue Desk: 4822 of 4822 lines have a when rule.

## Changes to other checks and others' areas
- **Three other checks changed:**
  - `roadmap_world_check`: one hand-built chain expectation now expects the "In the entrance hall, …" sentence.
  - `roadmap_table_check` EB: it tries smoke seeds 1–4 until Exhibit B is on a board, because seed 1 now reaches the lair the week he joins.
  - `thoughts_check`: fills in the `outvoted` placeholder.
- **Small touches outside my area:**
  - `night.lua`: scene barks, the call log's card, the fight tail, fight and foe text, bark context, the banter filter, the talk memory window.
  - `adventure.lua`: the unmark link, the escape label, the hero's story-thread line.
  - Others: `fight.lua` (kill name), `takeover.lua`, `report.lua`, `report_view.lua`, `ties_view.lua`, the journey view's quote, `intros`, `thoughts` (`news_told`).
- **Merge notes:**
  - A also changed `table_pick`, `fork` and `events.chain`, so expect conflicts there.
  - B changed chat `when`s, including the `witness_city` flag, which only exists in B's branch. My new `MODULE.chat` keeps B's conditions, so that line stays silent until the merge.
  - I copied B's dice `bought` line into `write_chat` to ease that merge.

## Doc lines
- **AGENTS:** "Votes come from the moment (round 3): an option's `lean`, `points`, `pulls`, `uses` and `short`. A friend gives way only to a push; a quiet decider speaks; the credit names only who was heard; the habit names the vote just gone. The chat is written from the log (`museum_week.CHAT`), never card titles. Looking round uses `MODULE.explore_say`. `barks.context` covers locks, statues, puzzles and first fights. `events.chain` folds room steps and Francs and drops repeats (`beats.same`, fight `tail`)."
- **README tests:** `lua tools/tests/round3_words_check.lua [seeds]` — round three's words: votes from the moment, looking round, the chat, pronouns, the chain as a story.

## Noticed, not mine
- Monsters without a pronoun are still "they" (the Knight of Shades).
- "Oswin helped Telpur." doesn't say what he did.
- Telpur's knockout still plays the same way every time.

Nothing from memory was used.
