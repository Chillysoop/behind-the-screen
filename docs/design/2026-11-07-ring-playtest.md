# Ring playtest, November 7

*Welcome to the Ring* played by the Death in Space rule set, compared to the core rules and the adventure (printed
page numbers; every word about the book here is a paraphrase).

**How it was run.**
- Nine whole runs from the headless sim (`tools/sim/museum.lua`, seeds 101 to 103, each with a careful, a random and
  a careless DM), about 3,700 lines.
- The real engine played the ring by itself (`ADVENTURE=ring MODES=8 tools/tests/engine_check.sh`), with screenshots
  of every screen.
- Two reviewers who hadn't seen the code each read all nine runs: one against the book's rules and adventure, one as
  a newcomer. The first wrapped the fight engine to print the events the sim's log leaves out.
- Every finding below was checked against the logs or the screenshots before it went in. "N of 9" is how many runs
  show it.

## Found and fixed during the playtest

- **Picking the ring on the title screen broke its fights.** The adventure's creatures were filed under whichever rule
  set was on when it loaded, so after the museum, Death in Space's foes landed in 5e's roster. The fights then had
  nameless 4-hit-point foes with bare hands. Starting straight into the ring crashed the real engine. Fixed: an
  adventure's creatures go into its own set's roster. `tools/tests/adventure_switch_check.lua` switches the way the
  title screen does.
- **Starting straight into the ring gave every friend the fallback knight mini.** That covered their seat cut-outs,
  the board and their tiles. Fixed: the player record carries the hero's mini.

## The short version

The rules engine holds up. About 45 attacks were checked by hand: Tech at range and Body in melee against defense
rating, damage within the weapon's dice, the extra dice, Body checks at 0, morale, void points. All eight stat lines
match the book. The crew and the hub come from the book's tables. The friends sound like themselves, the station's
small details are vivid, and the comms is a charmer.

The story doesn't hold together yet, in four ways that happen in most runs:

1. **The adventure's order isn't enforced** (6 of 9).
   - The crew reaches the engine hall and hands Roy a circuit board Monotone never gave them. Ragosa's shuttle docks
     are open from the first fork.
   - Root cause: an exit's `gates` are documented in the adventure standard, but the compiler drops them. So none of
     the ring's gates ever applied (the board, the relay, Ragosa's clock), and the clock's "the timer reads zero"
     never plays.
2. **Scenes are decided twice** (5 of 9).
   - The decision card settles it, then the scene's own goal roll argues it again. "Hina laughs them out of her
     office" is followed by "Hina's fuel is theirs". Roy shakes on a deal, then "Roy wants nothing to do with them".
   - The recap then repeats the wrong one.
   - The goal's win and lose lines aren't tied to the flags the cards set. A scene that tracked no progress also
     defaults to a win, so "the relay is fried", then "the water's flowing".
3. **Endings don't follow what happened.**
   - Ragosa "limps back onto her shuttle" after dying (5 of 5 fights).
   - The crew gets "Roy's word and the farm" though the water never reached it (6 of 9). Roy's favor in the book is
     the water.
   - A debt talked down to 250 is back to 500 at the end (3 of 9).
   - An ending's `line_if` isn't read.
4. **The table names the friends' D&D heroes.**
   - "Pip's going to tell this one differently" (4 of 9). Session Zero has Dev's promise about "Brannoc" and Jess's
     "Pip is thriving", plus tones about tavern nights and goblins in hats.
   - Also: "Loot time?", "Best DM in the land!", "Initiative! Say initiative!".
   - Shared data has about 240 lines that name the usual heroes outright.

## Findings

### Shared game (any adventure)

| # | What | Runs | Fix |
| --- | --- | --- | --- |
| 1 | Exit `gates` dropped by `standard.compile`: places open whatever has happened | 6 of 9 | Compile flag gates into the map; forks offer only open places |
| 2 | A scene's goal roll re-decides what its card decided | 5 of 9 | Goal lines follow the flags; the card's outcome counts as the goal's |
| 3 | A scene with no tracked progress ends on its win line (`settle_scene`) | 3 of 9 | Default to the card's outcome, or no claim |
| 4 | An ending's `line_if` isn't read | always | Read it like a goal's |
| 5 | Lines naming the friends' usual heroes play when the adventure brings its own | 4 of 9 | Filter them by the heroes the adventure brings, like the old-story words |
| 6 | Session Zero merges the shared tones, says and asks with the adventure's own: Brannoc, Pip, tavern nights, goblins | always | An adventure with its own tones and asks uses only those |
| 7 | Flat +1/+2 bonuses (a great roll, a miss's lesson, reading up, poking around alone) under a set whose target never moves | 8 of 9 | For a fixed-target set: advantage, never a number |
| 8 | "Hasn't met the party yet" after a deal with them | 3 of 9 | Count meeting someone in a card as meeting them |
| 9 | A hero's payoff line plays as they walk in ("the engine coughs, catches, and holds" before anyone touches it) | 9 of 9 | Payoffs say they've arrived, not that it's done |
| 10 | People speak before they're introduced (a rumour's `who` at the dock is the bar's old friend) | 7 of 9 | Data, plus a check that a speaker is met |
| 11 | "Shakes their head" for Ezra, Hina, Roy | 9 of 9 | Read the person's pronoun |
| 12 | A stabilized hero "comes round with 1 hit point" right after the fight; the book keeps them out cold until they rest | when it happens | A set's own rule |
| 13 | The read on a lie uses target 11 | 1 | The fixed target |

### The adventure (game/data/ring)

| # | What | Runs |
| --- | --- | --- |
| 14 | The engine hall and the board without having the board | 6 of 9 |
| 15 | Ragosa isn't on the clock: she can land in week 1, or wait while they finish rooms after it ran out | 9 of 9 |
| 16 | Telling Roy about the board repairs the ship though the farm stays dry | 6 of 9 |
| 17 | "Hand her Parliament" tells Ragosa about Hola! nobody learned; "hand her the Passel" uses plans nobody found | 3 of 3 |
| 18 | Hina pays for a ride that never happens (`hina_aboard` is never set) | 3 of 9 |
| 19 | The debt can't really be settled: "call his bluff" needs a secret the dock never gives in time; `debt_angry` and `debt_promised` do nothing | 9 of 9 |
| 20 | The exit description is always the docking bay's (`forks` keyed wrong) | 9 of 9 |
| 21 | The engine hall's description plays twice | 9 of 9 |
| 22 | Goal aims in the third person ("we're here to find their hub"); "go To the bar" | 9 of 9 |
| 23 | Four crew walk the hull with one EVA suit between them | 4 |
| 24 | Dace's "little job, later" never comes; the comms' last log and Ilse's stuck memory are never picked up | most |
| 25 | Ragosa is "in body armor" with no armor in her numbers | always |

### Screens (the real engine)

| # | What |
| --- | --- |
| 26 | The friends' tiles have 5e's "Inspire" button |
| 27 | Before the first scene, the board is the default meadow with a river |
| 28 | The DM's notebook on the table has fantasy scribbles (part of the table art) |
| 29 | The ambush line says "It moves first" for Ragosa |

## Decisions for Conner

- **The crew's weapons.** By the book, a new crew starts with 3d10 holos and no weapons (a pistol comes only as a
  starting bonus when the abilities sum below zero, and costs 125 holos). The game gave them two pistols, a raid rifle
  and hand weapons, so Ragosa goes down in round 1 of every fight. As written, Ragosa's shotguns against an unarmed
  crew would be brutal.
- **Ragosa's arrival.** In the book she shoots first and asks later. The game opens with her offer and lets the crew
  talk, sell out a gang, run or fight.
- **The debt.** The book says pay it off or get rid of it, with no fixed way. How should the game let them?
- **The book's tables for death and the void.** The book has a d20 table for how a hero truly dies and a d20 table of
  void corruptions. The game has neither (the void's five marks are ours). Should they come in, in our own words?

## Fix order (proposed)

1. Gates and the clock (1, 14, 15), so the adventure's order holds.
2. One outcome per scene (2, 3, 16, 17, 18, 19), so cards, goals, recaps and endings agree.
3. Endings (4, plus the ring's ending lines).
4. No other game's heroes or tones (5, 6), and the Inspire button (26).
5. Fixed-target bonuses and the set's own rules (7, 12, 13).
6. Introductions, payoffs, pronouns and wording (8 to 11, 20 to 25, 29).
7. The ring's story checks in the gate: `knowledge_check` and `book_check` crash on its data, and `museum_truth`
   finds 11 flags set that nothing reads.
