## Playtest report: is it alive? (round three, 24 prologues)

I read all eight careless prologues from start to end. I measured across all 24 with grep/uniq and three small scripts (`rep.py`, `votes.py`, `cards.py`, in /tmp/claude-0/-home-claude/6545778f-6f8d-5d88-b2f4-2abfe14c8e6f/scratchpad/pt3alive/). I also read the journey and report screens in screens_31 and screens_34. I didn't read any code.

References like "31 careless:123" mean /tmp/claude-0/-home-claude/6545778f-6f8d-5d88-b2f4-2abfe14c8e6f/scratchpad/playlogs3/prologue_31_careless.txt, line 123.

**Headline:** the repeated-lines fix worked inside a single run. In 31 careless, 203 of the 206 friend lines are distinct; in 33, 193 of 194. What repeats now is the *shape*:
- each friend makes the same bid at the same beat in every run;
- friends cave instantly with the same stock line;
- the same look-around templates come back in every room;
- the group chat is a script;
- the break always lands in the same spot.

The biggest payoffs (Hyper Destroyer Mode, the mirror, a natural-20 death save) happen without a single line to the table.

### Findings: alive

**1. Each friend's vote bid is fixed by seat. Bad (alive).** The opening bids never change across 24 runs:

| Beat | Bid | Runs |
|---|---|---|
| Garden | Dev: "Let's just fight them." | 24/24 |
| Donation box | Jess: "Let's have a go at the lock." | 24/24 |
| Donation box | Sam: "Let's drop a coin in." | 24/24 |
| Black knight | Dev: "take a closer look" | 24/24 |
| Black knight | Sam: "wide berth" | 22/24 |
| Chamber | Dev: "skip the homework" | 24/24 |
| Chamber | Mara: ritual | 22/24 |
| Euryale yields | Mara: deal / Dev: finish it / Sam: let her go | 10/10 each |

- Outcomes do vary (the garden was doused in 11 runs and burned in 13; coin 8, lock 16; door taken 17, left 7). But that variation comes only from who stays silent, who flips and how ties break.
- The brief says "the friends choose differently from run to run". They don't. The arithmetic around them does.
- **Right:** bids driven by state. For example, Sam pushes to end a fight when Oswin is hurt, Mara goes for water after reading the plaque, and sometimes a friend backs the other side or brings a third idea.

**2. Friends reverse their own bid one line later ("Okay, okay."). Bad (alive, fits).**
- 49 lines in 21/24 prologues; 47 of them are the same friend overturning what they just proposed, with nobody pushing.
- Example, 31 careless:431-432: "[jess] Let's leave the exhibits alone." then "[jess] Okay, okay. Take one of the mirror-bright doors."
- Twice in careless runs (33 careless:471-472 and 34 careless:627-628), and twice more in careful runs (31, 34), two friends cave back to back with the identical line "Okay, okay. Take one of the mirror-bright doors."
- **Right:** a cave answers someone else's push, at most once per vote, in the friend's own voice.

**3. Mood and history reasons are attached to the wrong option. Bad (fits, true).**
- 35 mismatches: 14 bold-mood reasons on a careful option, 21 safe-mood reasons on a bold one.
  - 32 careless:588-589: "Let's pick the lock, quietly. We were careful last time. Where's the fun in that?" and "Let's pick the lock, quietly. We played it safe last time. Let's not."
  - 33 careless:506: "Let's pick the lock, quietly. Tonight's a good night. Let's go big."
  - 31 careless:68: "Let's set the bushes on fire. I'm running on fumes. Easy does it."
- "Let's do the one we know works" is used for fire right after the plaque says "try the water" (32 careless:62, 35 careless:66).
- History claims ("We charged in / went in swinging / were reckless last time") are false in 19 of 63 uses. It's mostly Sam arguing to tidy up straight after the careful ritual (32 careless:177) or after buying a book (33 careless:641).
- **Right:** draw reasons from a pool that matches the option's lean, and check history against the actual last decision.

**4. "I lost last time" is honest now but mechanical. Minor (alive).**
- 159 lines (6.6 per prologue) from three phrasings: "I went along last time. This one's mine." (58), "I gave way last time. Not on this one." (54), "Last time I came round. This time you can." (47).
- 149 of 159 are true. Keep the logic.
- **Right:** rotate the wording, name what was lost ("I let you burn the garden. I get the book."), and drop it when nothing's at stake.

**5. Silent friends are credited with ideas. Minor (clear).**
- 184 of 266 decisions name a friend who said nothing, e.g. 31 careless:191: "keep them till they drip away (Dev and Jess's idea)". Dev never spoke.
- **Right:** show the silent vote ("Dev shrugs: whatever Jess said") or don't credit it.

**6. The look-around templates are dense. Bad (alive).**
- Mara's four stock lines, 3 to 8 per prologue:
  - "There's a story behind the X. I can feel it." 38 lines in 19/24
  - "I love that this museum has the X." 45 in 21/24
  - "Wait. Could the X be a clue?" 30 in 19/24
  - "Who left the X here? There's a story in that." 10
- They land on anything: "Wait. Could the front doors be a clue?" (36 careless:122).
- Jess: "'Stay close,' I tell the others, and step up to the X." 49 lines in 23/24, always Jess. Also "I've seen one of these before. Never like this." 17/24 (said to a sledgehammer) and "Careful. Nothing in this place is what it looks like." 18/24.
- Dev: "Does the X fight back? No? Moving on." or "Anything in here I'm allowed to hit?" 35 lines.
- **Right:** fewer reactions, each specific to the object, and none when there's nothing to say.

**7. The friends' own ideas in a room come from a tiny pool. Minor (alive; hurts replays).**
- 332 friend-started small rolls, only 59 distinct actions. Top ones: "I run my hand along the banister as I climb." 14, "I look out of the big window…" 14, "I tap one of the buzzing neon lamps." 13.
- The stairs get the same four looks (banister, flowers, steps, curtain): three or four of them in 8 prologues.
- Results repeat too: "Every bust has a moustache… One of them has two." followed by "Two moustaches. Overachiever." in 7/24.

**8. Dev's fight barks. Minor (alive, fits).**
- About 10 per prologue from a pool of about 12: "Finally. A real fight." 33 lines in 23/24, "Too easy." 25, "Loot time?" 25, "Finally. Hitting time." 25, "Dibs on the big one." 24, "Ooh, this looks fighty. I love it here." 22.
- "Too easy." comes after Brannoc was on 1 HP (37 careless:491) and after a six-round boss fight Euryale escaped (33 careless:874).
- **Right:** key the bark to how the fight actually went.

**9. The group chat is a script. Bad (alive, true, fits).**
- The same lines across seeds:
  - "does a healing spell work through a closed door" 24/24
  - "those huntlings were smart. i hated it. good fight though" 23/24, including after the party lost (36 careless:574)
  - "how strong is the gorgon" 19/24
  - "gnomes have middle names / flitwidget absolutely has four" 14
  - "bought new dice. they're green / a classic" 15
- Friends quote the DM's card titles, which they can't see: 64 lines in 23/24, e.g. "'light fingers' was the best part of the night, no notes" (31 careless:476). The most quoted titles: "an early knockout" 12, "it's what pip would do" 10, "the paint is wet" 9.
- "X finally found what they came for. emotional" uses "they" for she/he heroes, 23 lines. It's posted two or three times in a row in 13 chats (31 careless:256-260).
- Untrue callbacks:
  - "five gallons, three gallons, four gallons. i dreamt about jugs" in 3 of 3 runs where they skipped the ritual (34 careless:538)
  - "the sign said use water" in 5 of 13 runs where they did use the water
  - "the lady by the mountains" when nobody saw her (37 careless:616)
  - "oswin hit the floor last week" about tonight (36 careless:308)
- **Right:** chat about what actually happened, in the friends' own words.

**10. The break always lands in the same place, and in the worst place on boss night. Bad (fits).**
- One break per night in 96 of 97 nights. On boss night it comes between the stand-off and "Here they come" in 19 of the 22 lairs that had a break, including every careless one. Example, 31 careless:796, right after "They draw steel. The knight's armour drinks the first blow like ink."
- The break lines repeat: "'Break time.' Dev stretches until something pops. Jess is already in the kitchen." 27 times in 21/24, twice in 31 careless.
- Small moments during a short rest come from a pool of two: 28 of 44 rests show the pressed flower (15) or the sword grip (13).
- **Right:** break at a lull (after a room, before the lair door), and more rest moments tied to the night.

**11. Pet and ally beats repeat word for word. Minor (alive).**
- Jess's Exhibit B lines: 151 in 20/24, 18 in 34 careless alone; Exhibit B finds a Franc in weeks 2, 3 and 4 there.
- Telpur's knockout plays identically every time: "takes the hit and goes flying… 'Somebody get the boot!' … 'Tactical nap.'" (9 times in 7/24, twice in 32 and 34 careless).

**12. The big set-ups pay off off-screen. Bad (alive, true).**
- Hyper Destroyer Mode fires 4 times and is never narrated. In 37 careless:855 it was saved "for the Gorgon" all week; the only line is "Euryale just got Pip'd."
- Euryale meets her reflection in the cupboard door 6 times with no line (34 careless:1049).
- A natural-20 death save stands Pip up silently (35 careless:448).
- "Pip pockets something small" (16 times) never says what, and it never comes back.
- "Brannoc lets Oswin have first pick" (38 careless:112) is never honoured.
- Vorpal sword answered "Yes: Telpur stocks one. It costs 40 Francs." in 8 runs: it never appears in the shop and Dev never asks.
- Thessaly's Shatter hits allies 12 times across 5 casts and drops 3 of them, including killing Telpur (32 careless:387) and hitting downed Pip (34 careless:1008). Nobody blames Mara.
- **Right:** every payoff gets a narrated beat and a reaction from the table.

**13. The party wipe gets boilerplate. Bad (fits, alive).** 36 careless:490-505:
- Four "comes round on the floor with 1 hit point" lines in a row.
- Then a browsing vote over the kitchen diorama ("I gave way last time…") while "the huntlings are still out there".
- Then the chat says "good fight though". The biggest moment of the run gets the least reaction.

**14. News that never comes out. Minor (alive).**
- "I've got news. Big news. I'm saving it for the break." appears 9 times. In careless runs it never surfaces: it only comes out when the DM asks.
- A real friend would tell it anyway, or at least mention it in the chat.

**15. Session Zero. Minor (alive, true).**
- The same reaction is said twice in one round of introductions in 6 of 8 seeds: "Oh, I love her already." (34, 35, 38), "Chills. Actual chills." (32), "Okay, now I have to try harder." (36).
- "Tea guy! Love tea guy." is said about Oswin when no tea was mentioned (seed 32).

**16. Lines that don't fit the character. Minor (fits).**
- Wizard Thessaly: "a good whack with the flat of my blade" (Mara says it in 4 of 7 uses).
- Oswin: "I check the desk drawers. Quietly. Out of habit." (Sam in 4 of 9).
- Pip: "Don't touch anything. I mean it." (Jess, 4 times).

**17. Filler that doesn't fit the moment. Minor (fits).**
- "There's more in the car." right after a twist (32 careless:299).
- "A puzzle? Can Pip just pickpocket the answer?" in combat rooms (9 uses).
- "Initiative!" and "this looks fighty" right after Euryale is talked round (36 careless:865, 38 careless:556).
- "I'm moving my mini." while Brannoc is down (36 careless:467).
- "That ending, though…" after a banister (12 times in 10/24).
- "Off the back of a fight" 73 lines after the last fight (34 careless:514).
- Pip counts loot while Euryale is still on one knee (37 careless:870).
- When the table is unhappy, it's Thessaly who reacts in 36 of 38 cases.

### Findings: report, recap and journey (true, alive)

**18. The chain reads as a list. Bad.**
- 48% of beats are linked (610 of 1258) over 97 nights. 209 of 929 recap lines are "They went into X"; 41 are a bare "X found a Flitwidget Franc."
- Redundant: "…fought the guardian, so they fought the Bone Construct" (14 times); "Euryale got away. So Euryale slipped away." (33 careless:927-928).
- Garbled: "so they had a mirror she would have to face"; "held off the huntlings, just and woke the Steam Mech" (36 careless:590, after they lost).
- The 34 week-2 report screen ends its chain before the night's fight.

**19. The recaps claim things the night never showed.**
- "They doused the hedges with pond water, so Oswin/Thessaly found a Flitwidget Franc." 11 times; no Franc was shown.
- "They dropped a coin in the donation box, so Oswin found a Flitwidget Franc." 8 of 8; the scene said "Something warm settles over Oswin."
- "Flitwidget saw what was left of his garden / the Bone Construct" appears in 21/24 final recaps; it's shown in a scene in only 6.

**20. The recaps leave out the big moments.** Brannoc down twice (31 careless week 2), the wipe's 7 downs (36 careless), Oswin down (36, 38), the failed notebook (34 careless week 4), Hyper Destroyer Mode.

**21. The chains that do work** are the model to copy:
- "Flitwidget saw what was left of his garden, so Flitwidget took the breakages out of their reward." (36 careless week 4)
- "Telpur caught her at it, so Telpur put his prices up a Franc." (35 careless week 1)

**22. The journey screen.**
- The route is a numbered list with one beat per room, and lines are cut off ("They went round and made the hunters come t...").
- "Heard the Witness whisper their name" uses "their" for a she/he hero.
- The friends' quotes are identical across the two journeys.

### Other bars, noticed in passing

- **The lock beat swaps hero (true).** "[dm] Pip cracks her knuckles and kneels by the case." is followed by "Thessaly has the picks out" and Thessaly rolling, in 5 runs. The recap then says "so Brannoc emptied the donation box" (34, 35, 38 careful).
- **The potion card names the wrong drinker (true).** "Jess drank a healing potion last turn" is wrong in 5 of 10 cards; Pip had fed the potion to Brannoc (31 careless:401) or to Oswin (36 careless:430).
- **Flitwidget's memory has gaps (true).** "Flitwidget knows them: … they took his job" reads like theft (18 of 18). The stolen healing draught is never remembered (stolen in 10 runs, mentioned in 0).
- **The haggle doesn't add up (true).** "Ten gold less each, for the damage" is followed by "makes it forty each", so the deduction vanishes (36 careless:884-902).
- **Broken text.**
  - "we'd just agreed on on to the gift shop" (31 careless:286)
  - "(to spend Francs) (Dev, Jess and Sam's pick)", and the label is spoken aloud: "If it were me? Back to the gift shop (to spend Francs)." (33 careless:576, 36 careless:600)
  - "Somebody hug them" about Brannoc
  - "Goodnight, sweet Kruthik Huntling 2."
  - The beast speaks as "[Kruthik Huntlings] Every step you took to get here, I knew about."
  - "if she lifts her hood, she meets her own eyes" has an ambiguous "she" (12/24)
  - "two clay jars" as the sisters is unclear
- **Wrong location (fits).** "Between the two studies, a narrow stair climbs" right after the lecture theatre (33 careless:722, 36 careless:782).
- **Joke during a death (fits, careful run).** 35 careful: "Okay, round two. Pip is angry now." and a fist bump right after Oswin dies; dead Oswin's player then votes on the yield.

### What's good, so we keep it

- Exact repetition within one run is nearly gone.
- Outcomes vary across seeds. Endings: slept 5, fallen 6, escape 7, bargain 5, ally 1.
- People remembering works when it fires: "You burned my garden" (8), "He hasn't forgotten the donation box" (6), Telpur's raised prices, the Lecturer reporting to Euryale.
- Direction reasons follow the party's state ("Oswin's hurt: nothing with teeth, please", "Pip went down in the Hunting Grounds").
- Vote reasons sometimes cite real gear: "What did I bring a cupboard door up here for, then?"
- The railroad warning works: "Twice tonight you've steered them. It's starting to feel like a railroad."

### The five changes that would most improve the game

1. **Make friends' bids and reasons depend on the moment, not the seat.** Vary who proposes what, cap the "Okay, okay" reversals, match mood reasons to the option's lean, and check "last time" claims against what really happened.
2. **Narrate every payoff and let the table react.** Hyper Destroyer Mode, the mirror, the natural-20 death save, friendly fire, Telpur's knockout, the vorpal promise and the "first pick" promise.
3. **Write the group chat from what actually happened.** No card titles, no fixed script, no untrue callbacks, no "they" for a hero, one line per moment.
4. **Move the break to a lull** (never in the middle of the boss stand-off) and widen the pools for break and rest moments.
5. **Make the recaps and the journey tell a story.** Include only what was shown; include downs, losses and payoffs; cut the bare "They went into X" lines; use real causes; tell the journey as a short story instead of one line per room.

### The five best moments

1. **One theft, remembered for weeks** (35 careless). Telpur catches Pip: "Oi! That's stock!" Then "I don't answer questions from shoplifters. Shelf first." (704). Then Euryale: "My lecturer tells me one of you has quick fingers. Keep them where I can see them." (764)
2. **The brass key from the week-1 pond opens the office door two sessions later** (36 careless:101 and 648-652). Same run: Sir Glowsalot (105), and Flitwidget's "You saved it. You also set fire to quite a lot of it. Biscuit?" (883)
3. **"Let's buy her off with the donation box."** answered with "You would rob your host twice?" (34 careless:959-967). Same run: Pip creeps up alone and "hears a calm voice say Pip's name, and scrambles back down" (903).
4. **The talked-round ending** (38 careless). "Out there was chaos; in here was safe. And lonely." (551), then "Co-curators? I... suppose she does have an eye for arrangement." (567)
5. **The small table moments:**
   - "You're my favourite wizard." / "I'm your only wizard." (37 careless:663)
   - "Midnight." / "Destroyer." / "It's a panther." (35 careless:370)
   - Telpur's tiny boots labelled "For best"
   - Oswin's prayer over the sleepers while Brannoc keeps his helmet off and makes no joke (32 careless:556-557)
   - "She's redecorated. Villains always redecorate." (37 careless:742)
   - The Lecturer: "There will be a test." (35 careless:642)

Nothing from memory was used, and I have nothing new to suggest saving.