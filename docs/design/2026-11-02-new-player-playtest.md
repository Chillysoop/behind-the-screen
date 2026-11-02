# New-player playtest: story clarity (November 2)

## How it was run

- Three full prologues through the real UI (`TRANSCRIPT=file lua tools/tests/museum_smoke.lua 1|3|4`): every line a
  player reads, in order, with what was pressed. Endings: seed 1 Euryale falls, seed 3 a bargain (after losing once),
  seed 4 she slips away. Screenshots of each screen from the engine recording for layout.
- Two fresh readers who had seen none of the design or code, each reading one run start to finish in order:
  a **newcomer** (never played D&D, plays cozy games; seed 1) and a **lapsed player** (a few sessions of D&D, ran one,
  never read the book; seed 4). Plus a pass over seed 3 and a cut-text audit (`AUDIT=1`).
- Every finding below was checked against the transcript. Line numbers are transcript lines (`s1:` seed 1, and so on).

## The headline

Both readers, separately, put the same things at the top: **the finale doesn't hold together, and the narration keeps
contradicting the call the DM just made.** Most of it is one pattern: the older story engine's generic lines (prizes,
scene outcomes, pacing cards, table friction, notes) still run on top of the museum's own lines, and the two disagree.
The good news is just as consistent: Session Zero, the friends, Euryale's asides upstairs, the marks on her card, the
DM-craft cards and the read-aloud boxes all landed.

## Fixed already

- **"Ilsa" at Session Zero.** Mara's reaction to every tone named Ilsa, from the old story (all runs, line 118). Her
  lines now fit any adventure, and the museum smoke test now checks every line that goes on screen at any moment for
  the old story (the checkpoints had missed it).

## The problems, ranked

### 1. Boss night falls apart (both readers: STOPPED ME)

Three ways, one per run:
- **Talked down (s4: 3826-3832, 3883-4006).** "She reads the first line, frowns, and is asleep before the second. They
  carry her out through the black curtain." Next line: "Euryale steps back with a little shrug. 'I agreed. They
  didn't.'" The fight that follows is led by **"the goblin chief"**, never mentioned before; he and the Knight run;
  "Ending: Euryale slips away" while everyone celebrates a Gorgon loose in town.
  Cause: `museum_night.lua` (~1325) clears `boss_name` for the extras-only fight, so the fight takes an old
  encounter's name; the "I agreed" line plays however the talk ended.
- **Fled, then yields (s1: 4004-4063).** The pacing card "The enemies break and flee" lets Euryale flee ("Ran:
  Euryale... It's over"), then her "Enough. I yield" card plays and Brannoc kills her. "Ending: Euryale falls."
- **Lost (s3: 3826-3836).** "They wake up in a cell, bound and stripped of their weapons" (an old generic fail,
  `fails.lua` "captured"), then "They tumble down the stairs with her laughter behind them", then "They limp out of
  the caravan". The report keeps both the cell and the stairs. The next session's "Last time" skips the lost fight.
- In every run, the marks the party built for the fight (the mirror, the sleeping pages) never come up in it: the hood
  never comes off, nobody reads her a page. Both readers felt four weeks of build-up didn't pay off.

### 2. The narration contradicts the call (both readers)

The museum moment plays the DM's choice, then a generic prize or outcome line says the opposite:
- "Rein them in: 'Not this one.'" then "the statue's thanks still ringing" and "a warm glow from the donation box"
  (s1 1074-1077, s4 1150-1157).
- 0 Francs, "Save the Francs for later", then "Telpur rings up the sale" and "a paper bag of strange goods"
  (s4 1988-2008; the recaps repeat the sale).
- "Leave the exhibits alone." then "They earn a cupboard door from the kitchen diorama" (s4 2283-2290).
- "By the gift shop they're puddles." then "They earn weapons made of wet paint" (s1 2150-2157); later "Not tonight:
  weapons made of paint stays out of reach" (s4 2487, also bad grammar). Cause: `night.lua` ~6032.
- "Flitwidget pays up" then "Goal: Settle up with Flitwidget. Not this time." (s4 4176-4184).
- A failed pry, "They're going in half blind", and Flitwidget tells them everything anyway (s4 884-898).
- "They pick up right where they stopped: the Hall of Paintings" followed by a choice of where to go (s1 1830).
- Monsters both flee and crumple: "Nobody's chasing them" then "The last thorn-beast crumples" (s4 1074-1095); the
  Lecturer "got away" and "fades" (s4 3252-3265); "The Fall of the Biggest Huntling" for a huntling that ran.
- "Go after Oswin" then the Lecturer drones at Brannoc (s4 3202-3212).

### 3. Lines about things that never happened (both readers)

- "Pip dangles the captured lookout over the millrace by his boots" (s4 1114): old-story table friction
  (`friction.lua`), then it gets its own table card. The lapsed reader scrolled back looking for the lookout.
- "the goblins are still waiting" in the garden's pacing card (s1 855).
- A mark from a tie invents the event: "(They took a polished cupboard door.)" / "Why would anyone take a door?" after
  the garden (s1 1048, s4 1128), then they take one for real a week later.
- Friends and lines mention things never shown: tentacles, the goat, the goose, marbles, "the lady by the
  mountains", Sir Nibbles, "the clue from earlier", "her plan last time", "eyes on his arms", Sam's news (set up
  twice, never told), potions after a lecture.

### 4. The last scene forgets the adventure (newcomer: STOPPED ME)

Tea in the gift shop replays the street's read-aloud ("On the caravan's roof, a gnome... is shooing a crowd"), and
the talk card says "They don't know the party yet. You speak for them: what are their first words?" Pip: "Lovely to
meet you." Then a riddle door and a room that "turns" that aren't there, 40 gold haggled then 30 paid, and "you said
you'd heard news from the mountains" before he's said it (s1 4070-4154, s4 4038-4141).

### 5. The offices, Mara's big mystery, can't be followed (both: STOPPED ME)

Reactions come before what they react to: the body before the door opens, "This writing" before any writing, "a city
under the sea" before the notebook shows one, "Twenty minutes on one riddle" for a riddle never shown, then "Click.
It was never locked" after the door burst open. The DM slides a secret note and never sees what it says. It ends
"Not this time", yet the report says Thessaly "got the story she came for" (s1 2949-3048, s4 3337-3447).

### 6. The counters don't match the story

- **Francs.** "They earn a fistful of Flitwidget Francs" twice, then the board says 0 and every gift shop item is
  "(not enough Francs)". The lapsed reader stopped there. Cause: the `mus_francs` prize card says it but never adds to
  the count; only moment options do.
- **Fair warning** banks when the party heeds a warning and when there was none; the rule is only in the Notes.
- **The introductions ignore the reasons picked**: picked Rumour, A con, A bad feeling; the intros speak Duty, Lying
  low, Faith (s4 776-804; s1 784 for Pip). Both readers thought their picks hadn't saved.
- **"Paid off"** for reasons whose room only showed "X sits up. This is what Y came for" (and once for a failed room).
- "You never posted the ruling you promised to look up. Sam noticed." Nothing between sessions offers a way to.

### 7. Threads set up and never given a fact

The Witness is a side on the Story panel from night 1 and the players get excited about "a sunken city", but the DM
never learns one concrete thing about it. Both readers felt like the least informed person at the table.

### 8. The first prep board

Francs, Fair warning, Empathy, Goodwill, "Mood this week: ?", marks (do they help her or them?), Book's map and Ties
and locks all at once, mostly unexplained; Ties and locks lists every mark and room by name before night 1 (spoilers,
and the cause of the invented cupboard door). Cut-off text the DM has to decide on (AUDIT=1): the showdown options
("As in the book: a drink, some questions, then an..."), Euryale's marks, the floor-plan labels ("Str...",
"Tomor...", read as a date), the table forecast ("Should enj...", "May be bo..."), the Ties options.

### 9. Smaller snags

- "Last time:" recaps are lists of labels ("The Hunting Grounds: the run of the second floor; ...") and once skipped a
  whole night.
- "Hint they missed something" sends them back to an identical card and nothing is found (s1 1093-1116, 3355-3381).
- Notes from the old campaign: "The first act is over", "Suggested fight: Goblin Boss, 6 Goblin Warriors" for the
  kruthik room and the Lecturer, "The World of Tomorrow's pride" with no name.
- Repeats: the same night titles, chat lines, "They planned for this", "Sorry I'm late" after "Everyone's here",
  last week's requests back as new.
- "You know them: new to you" for four friends; the night runs past Sam's agreed stop with no reaction; Thessaly says
  "Level three!" at level 4; "Talk 2h" and "Breezy" never explained; a stray "A bridge" side room (made by the test
  bot, but its name reads oddly in sentences).
- "One-shot prologue that runs as many sessions as it needs" reads as a contradiction to both.

## What worked (both readers)

- **Session Zero**: the chips and the instant replies made the stakes readable at a glance.
- **Euryale upstairs**: "Why would anyone take a door?", "Good dogs.", "It's pointed at me, isn't it." The clearest
  storytelling in the game, and the marks with their reasons in brackets made choices feel like they built the end.
- **The DM-craft cards**: say the DC or keep it, cooking the dice and the suspicion it earns, the railroad warning,
  "Mara is looking at your screen", "You broke a Session Zero promise to Jess".
- **Read-aloud boxes**, short and vivid; the painting of five people with dice; the group chat; forks that say who
  wants which way; the showdown screen ("one long scene with Euryale"); the ending's hook.

## Suggested order

1. Boss night: the extras' fight keeps Euryale's name and her people, one ending line per outcome, the loss narrated
   once, a boss that flees can't then yield, and each party-side mark gets its moment in the fight.
2. One voice per moment: when a museum moment has played, the generic prize, outcome, "Not tonight" and friction lines
   stay quiet (or follow it); Francs prizes add Francs.
3. The thanks scene: its own opening, Flitwidget who knows them, no stray read-aloud.
4. The offices in order, with the note shown to the DM.
5. Intros follow the picked reasons; "paid off" means a real beat; the first prep board explains its counters and
   nothing it shows is cut short; Ties and locks waits until after night 1.
6. The smaller snags.
