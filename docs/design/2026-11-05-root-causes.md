# Root causes: what keeps going wrong, why, and how to stop it

November 5, 2026. Written after three playtest rounds, four rounds of fixes and Conner's own play of the November 4
build. It's the working resource for the next fix session, and the rulebook for importing the longer campaign so the
same kinds of problems don't happen at all.

## How to use this

- **Fixing the museum:** pick a class below, read its rule and its check, build the check first (it should fail on
  today's code), then fix the items listed under it until the check passes. The tracker at the end lists every open
  item with its class, where it lives and its status.
- **Writing or importing new content (the longer campaign):** read "The importer's contract" at the end. Every record
  and every line has to carry what that section asks for, and a region doesn't ship until its gates pass.
- **Reviewing a build:** the classes are also the reviewer's checklist. A finding that fits no class means this
  document is missing one: add it.

Sources (all in the repo, docs/playtests/2026-11-04/):
- `conner-feedback/README.md`: Conner's 27 points on the November 4 build, with his screenshots (C1 to C27 below).
- `confirming-reviews/`: the four confirming reviews of the build (truth, alive, screens, engine), quoted as V-items.
- `round3-reviews/` and `round3-fix-reports/`: the third playtest's reviews and what each fix batch did and found.
- `plans/`: the briefs the batches worked from. FINAL.md is the final fix pass, stopped part-way by the usage limit.
  Its three branches (f-facts, f-words, f-screens) each end in an unchecked work-in-progress commit on top of bfa5157.
- Earlier rounds: docs/design/2026-11-02-cause-and-effect.md, docs/design/longer-adventure-notes.md, and the round-two
  items on the roadmap page.

## The short version

Almost every problem found in four rounds comes from one of ten causes. Most are the same thing seen from different
sides: **the game says things it has no record of, or has a record of something and says it to the wrong person.**

| # | Class | One line | Conner's points |
| --- | --- | --- | --- |
| 1 | Audience | Hidden or private things said to the table | C4, C6, C12, C16, C21, C23 |
| 2 | Agency | The DM speaks for the players | C5, C7, C8, C20 |
| 3 | Claims without records | A line promises a mechanic, an item or a state that isn't there | C14, C15, C17, C25 |
| 4 | Book fidelity | The book's triggers, secrets and positions weren't captured as data | C4, C12, C14, C16, C22, C23 |
| 5 | Knowledge | Characters know what they couldn't (including from earlier runs) | C26, C16 |
| 6 | Space and movement | Minis move or stand where they physically can't | C19, C22, C23, C24 |
| 7 | Layout | UI pieces placed independently, so they collide | C2, C9, C27 |
| 8 | Presentation of state | Faces and labels that don't follow the moment | C1, C27 |
| 9 | Promised structure | A card or line promises something the engine doesn't do | C10, C11, C13, C18 |
| 10 | Templates without facts | Generic lines that imply facts they never check | C3, and most V-items |
| 11 | Data shape | A table nested in the wrong place, or a field misspelt, and nothing notices | (Nov 6) |
| 12 | Checks out of step | A check keeps its own idea of a rule, and fails the game for being right (or passes it for being wrong) | (Nov 6) |

Two process causes sit under all ten:
- **Tests checked what we'd thought of; players found what we hadn't.** Each batch's check proved its own fix. None
  asked the general questions ("is anything said to the table that the table shouldn't know?"). Fix: one general
  property check per class (below), run on every build over many seeds, plus a fresh-eyes review each round.
- **Parallel batches meet in the same lines.** Each batch was right alone; merged, two fixes said the same thing twice,
  or one undid the other's condition. Fix: one owner per fact and per line source (classes 3 and 10 make that
  mechanical), and merge interaction checks (the round-three merge's list) as a standing step.

---

## 1. Audience: who may hear a line

**What it looks like.**
- C6: "The metal statue between the doors hasn't moved. Yet." (game/data/museum/cards.lua:74): the table is told
  the Sentinel is a monster before anything wakes it.
- C4: the garden's topiary is called creatures before anything triggers.
- C16: Euryale's thoughts upstairs are said to the table: `night:say(..., "interlude")` in museum_night.lua
  (lines 3963, 4116, 4249, 4472). The players learn about the boss and how their rooms affect her.
- C21: "YOU, TO THE TABLE" lines that no real DM would say aloud: commentary on what's happening.
- C12: the knight shown as a knight mini in a frame from the start, so the secret is on the board.
- V (truth N1): Euryale's "Your Witness writes beautifully" without the notebook.

**Root cause.** The module's text has no audience. The book separates read-aloud boxes, DM notes and secrets; the
hand import kept the words but not that separation. And `night:say` has styles (dm, narration, interlude, screen)
that decide how a line *looks*, not who's allowed to *know* it. So a DM note, a secret and a read-aloud all reach the
caption the same way.

**The fix.**
- Every piece of module text gets an audience: `read` (the table hears it), `dm` (the DM's eyes only: the prep
  board, the screen, hovers), or `reveal = <condition>` (hidden until an event in the log makes it true).
- `night:say` takes an audience, not just a style: `table` (the DM aloud), `screen` (only the person playing sees it,
  as BEHIND YOUR SCREEN does), `chatter` (what the DM overhears at the table: C21's new category). A `dm` or
  unrevealed line can't be said to the table; it goes to the screen or nowhere.
- Euryale's interludes move to the screen (the DM's knowledge), unless the book has them read aloud. Check the book.
- Dormant monsters are props until they wake (the existing `wake = { feature, at }` system): the knight starts as a
  painting prop, the Sentinel as a statue, the topiary as hedges; the mini appears when the wake event happens.

**The rule.** The DM says aloud only what a real DM would say aloud: the read-aloud, rulings, answers to questions,
people's voices, what the dice did. Anything the players' heroes haven't perceived stays behind the screen.

**The check (spoiler test).** Over whole prologues: no line said to the table contains a `dm` fact or an unrevealed
one before its reveal event (monster names before they wake, secret doors, the boss's plans, room effects on her
card); plus a pattern list that fails on known tells ("hasn't moved", "yet.", "not what it seems", "something is
wrong with", an enemy's name in a room's opening read). The importer runs the same test.

## 2. Agency: who decides and who says it

**What it looks like.**
- C5: after a warning, the DM narrates "Pip thinks better of it." (museum_night.lua:1222, said in the dm style).
- C7: the fork's read-aloud lists what each friend wants ("Mara, Dev and Sam want the Chamber of Ancients (Dev:
  itching for a fight; Sam: it's why Oswin came). Jess wants the Hall of Paintings."), built from the vote.
- C20: the DM talks about what the players are doing, should do or want; the players should say it.
- C8: the friends speak in character about as often in week 5 as in week 1.

**Root cause.** The simulation decides for the friends (votes, wants, thoughts), and the night director reports
those decisions through the DM's narration because that's the channel every system already used. There's no step
where a friend *says* their decision; the DM tells the table what the table decided.

**The fix.**
- Decisions come from the players' mouths: the friend who carries the vote says what the party does, in their own
  line (in or out of character); the DM's line reacts ("Okay. The Chamber it is.").
- What the DM *thinks* the friends want is the DM's own read, on the screen, not aloud: a small "DM intuition" pop-up
  under the story panel, rolled like the Insight read already is (thoughts.read: d20 + Empathy + familiarity), so it's
  sometimes wrong early on and sharper as familiarity grows (familiar.lua). C7 asks for exactly this.
- After a warning, the DM gives the warning only (and only when asked or when a rule requires it); the friend answers.
- Random, uncontroversial actions (taking a trinket, looking at a curio) happen without the DM; the DM steps in only
  when something special is at stake.
- In-character share grows with sessions played and familiarity among the friends (C8): a per-friend number the line
  picker reads.

**The rule.** The DM never says what a hero thinks, feels, wants or decides. The players say it; the DM reacts,
rules and describes.

**Built, November 6** (Conner: "The DM should never say 'pip feels' or 'jess wants' etc. hard rule"; "players
announce what they're doing, and the DM responds to it, quick and automatic"). `game/model/agency.lua` sits in
`night:emit`, the one door every line goes through: a DM line's sentence with a hero doing something by choice
becomes that hero's player's announcement, in character and first person, followed by the rest of the DM's line as
the answer; an echo of what the player just said is left out; a feeling, a want, a thought or a look (grins,
mutters) is never said, and is recorded so `tools/tests/agency_check.lua` fails it and it's rewritten at the source.
A friend's words written into the DM's line become the friend's own line.

**The check.** Every DM line to the table is scanned for a hero or friend as the subject of a mental or decision verb
(thinks, wants, decides, would rather, is sure, wants to, goes along, changes their mind) and fails; every party
decision must be preceded by a friend's own line stating it.

## 3. Claims without records

**What it looks like.**
- C17: "Pip fights with the twin daggers" when the daggers aren't in the inventory, so it's unclear whether they do
  anything (items.lua owns what's carried; the line reads something else).
- C25: "they get +1 on their next roll" (rulings.lua:58, night.lua:2954) must actually land on the next roll.
- C14: the painting's scimitar: does the book give it a mechanical benefit, and is it in the game?
- C15: the friends hold DM inspiration and don't use it well.
- V (truth N1, the blocker): the Steam Mech fights for a party that never woke it, after the between-sessions loose end
  `mech_left`; its mark says "They woke the Steam Mech".
- V (screens N2): heroes turned to stone are back the next week with no word.

**Root cause.** A line can assert a mechanical fact (a bonus, an item in use, an ally on their side, a hero restored)
without that fact existing anywhere the rules engine reads. Some lines read a flag that one path sets and another
path also sets for a different reason (the loose end setting the Mech's flag). The inventory and the event log were
made the owners in round two and three, but not every line was moved onto them.

**The fix.**
- Every mechanical claim is data first: a bonus is a buff record (who, what roll, how much, until when) that the rules
  engine applies and consumes; an item in use is an items.lua entry the fight reads; an ally is an entry in the fight's
  side list that came from a logged event (woken, joined, hired). The line reads the record; it never stands alone.
- Flags that mean "this happened" are set only by the event that happened, and read through the log
  (events.lua), so a loose end can't set "woke the Mech".
- Every adventure item states its mechanics in data (the scimitar, the daggers, the bracelet, the vorpal sword),
  checked against the book (class 4).
- Inspiration: the friends' AI spends it by a rule (a roll that matters, within a few points), and the check counts
  that it's spent.

**The rule.** Nothing is said about what heroes have, can do, or gain unless it's a record the rules read, and the
record's effect is visible in play.

**The check (claim scanner).** Each said line is matched against claim patterns (`+N`, advantage, an item name,
"woke", "on their side", "back on their feet", "fights for them") and each match must have its record live at that
moment; each buff record must be consumed (or expire) and the roll it touched must show it. Fails on the Mech, the
daggers and the +1 today.

## 4. Book fidelity

**What it looks like.** C4 (how the topiary wakes; "the smoke" over hedges they didn't burn), C12 (the knight in a
painting, how it wakes), C14 (the scimitar's benefit), C16 (are the boss's thoughts the players'?), C22 (the Lecturer
behind the lectern), C23 (is Pip's office room locked?), the six-winged bird's place (round two), the gift shop's
prices.

**Root cause.** The museum was imported by hand, room by room, as prose paraphrase plus a few flags. The book's
*structure* (what triggers what, what the players know on entering, where everyone stands, what each item does, what
the DM keeps secret) was never written down as data, so nothing can check against it, and each later fix can drift
from it without anyone noticing.

**The fix.** A fidelity sheet per room, as data next to the module (game/data/museum/fidelity.lua or in each room):
- `enter_known`: what the players can see and know on entering (and nothing else).
- `secrets`: what the DM knows (with their `reveal` events).
- `triggers`: what wakes or changes what (the topiary wakes when ..., the knight steps out when ...), each with its page.
- `positions`: where each person and monster starts (the Lecturer behind the lectern), and which doors are locked.
- `items`: each item's mechanics in rules terms, with its page.
Each field carries a page reference to the reader's own PDF (page numbers only; never the book's text). The module's
lines and the fights are checked against the sheet.

**The rule.** The book's structure is data with page references; our words are ours. A fix that touches a room checks
its sheet.

**The check (book check).** For every room: the opening read mentions nothing outside `enter_known`; every trigger in
the sheet is reachable and nothing wakes without one; starting positions match; every item's mechanics match. The
sheet itself is reviewed once against the book (Conner, with his PDF).

**Built (November 5, c-fix).** The sheet is `game/data/museum/fidelity.lua`: per room, what the players `sees`,
the `secrets` with the `words` that give each away and what `reveal`s it (`shows`: the words of the line that is the
moment), the `foes` (cast card, how they `start`: prop, painting, hidden, still or awake; what `wakes` them; where they
stand, by the board's place), the `people`, the `doors`, the `traps` and the `items`, each with its page, and
`ours = true` with what the book has instead wherever the game added something (the twin daggers' +1, the vorpal
sword, the looking-round traps). `tools/tests/book_check.lua` checks it: SHEET (every room and card there), START
(a prop or a hidden foe says nothing and stands no mini as the room opens; one woken by a theft or a closer look is
an optional fight), PLACE (each anchor and each garden beast where the book puts it), DOORS, TRAPS (every trap is
the book's at its DC or marked ours), WORDS (nothing as a room opens gives a secret away, and in whole prologues
nothing the table hears does before its reveal) and ITEMS (the paintings, every magic item). Each item fails when
its fact is broken. Still to do: Conner's review of the sheet against his PDF.

## 5. Knowledge (including from earlier runs)

**What it looks like.**
- C26: the friends must never have meta knowledge of having played before; it's always their first time.
- C16: knowledge of the boss they shouldn't have.
- V (truth): "A Gorgon who only wanted her sisters back" before it's earned; the six-winged bird that someone "can't
  place" right after it was named; the Witness without the notebook.
- Round three: the jugs, the sign, the lady by the mountains, said in runs where they never happened.

**Root cause.** The friends' lines were written by people who know the whole adventure. A line that foreshadows
("I've seen one of these before. Never like this.", a guess that's always right, a joke about a room before they've
reached it) reads as knowledge. Round three added `knows` conditions to some lines, but there's no rule that every
line naming an adventure fact must carry one.

**The fix.**
- Every friend line that names something in the adventure (a person, a place, a creature, an item, a secret) carries a
  `knows` condition on the event log: the party saw it, heard it or was told it, this campaign.
- No line presumes the adventure's shape (what's coming, what's behind a door, how it ends); a guess has to be able to
  be wrong.
- Nothing carries over between campaigns except the player's own saves: no cross-run memory feeds any line (the vote
  history, the habits, the "last time" reasons are this campaign's only; check it).

**The rule.** The friends are always playing it for the first time. They know only what this campaign's log says
their heroes perceived or were told.

**The check.** Scan every friend line for adventure nouns (from the module's names, fidelity `secrets` and items): each
use needs a satisfied `knows` at that moment. And a two-campaign test: play a prologue, start a new campaign in the
same process, and fail if any line references the first.

**Built (November 5, c-fix).** `tools/tests/knowledge_check.lua`: KNOWN scans every friend line (at the table, in
character, the group chat, a thought, Session Zero's) for the adventure's names (its people, creatures, rooms,
items and the fidelity sheet's secrets) and fails on one the table hasn't heard said: what they know going in is
Session Zero's `told` (the premise, on its screen), the tones you pitch and their own reasons for coming; then
whatever the DM, the story, the museum's people and your chat answers say. TWICE plays campaigns one after another
in one process and fails if one differs by a line from playing it alone. It found the Mech manual named before the
shop said its stock, the World of Tomorrow at three unsigned doors, the Steam Mech in the chat with nobody having
named it, and Session Zero's lines with no premise told. Not yet covered: a line that presumes the adventure's
shape without naming anything (a guess that's always right).

**Built (November 6, c-fix): secrets as records.** `game/model/secrets.lua` and `MODULE.secrets`: every DM-only fact
is a record with its page, its holder, the DM's hint and tell lines, and its ways out (the book's, and the usual ones
for its kind); what's known is kept per hero (a hint or the whole), with how it came out; the friends dig their own
way (`ideas.lua`'s find), and the DM can reveal, hint or hold back from a person's sheet. `game/model/shown.lua`: a
board's places are public once described, and described before a friend names them. `tools/tests/secrets_check.lua`
checks it all from the data (DATA, LINT, REACH, EARLY). Design and Conner's calls:
`docs/design/2026-11-05-secrets-and-knowledge.md`.

## 6. Space and movement

**What it looks like.** C19 (Telpur's mini runs off the table after the Hunting Grounds; minis ran off the table
before too), C24 (characters pass through walls, even in quiet moments), C22 (the Lecturer not behind his lectern),
C23 (Pip in another room of the offices), V (engine: Euryale and Pip missing from the board while the table bargains
with her; heroes hidden behind the offices' partitions).

**Root cause.** Minis are placed by several separate code paths: staging a room, the look-around, quiet moments, a
fight's start and end, companions joining, a split party. Some move with `sight.walk` (which paths round walls), some
set a position directly. Companions aren't attached to the party's movement. Start positions come from code, not from
the room's map spec.

**The fix.**
- One movement API for every mini (e.g. `board.move(mini, to, why)`): it always paths on the room's grid with walls
  and doors, refuses through walls unless an ability allows it, and logs each step. Direct position sets are removed.
- Companions follow their owner (they move with the party's moves, and stay inside the room).
- Every map spec lists spawn spots for each person and monster (the Lecturer behind the lectern) and which doors start
  locked; staging reads them (class 4's `positions`).
- "Visible" is measured against walls from the camera's side, and the boss is placed where she's seen during her talk.

**The rule.** A mini is always on the room's floor, reached by a real path, where the book puts it.

**The check (movement test).** Over whole prologues: every step is to an adjacent open square and never crosses a wall
or closed door without an ability; every mini is inside its room's floor at every frame the night emits; every person
talking is visible (not behind a wall from the camera's side); companions end every move within reach of their owner;
spawn positions match the spec.

## 7. Layout

**What it looks like.** C27 (the death-save card on top of the DM screen's notes and the friends' tiles), C9 (the
DM's caption and the friends' bubbles collide with the in/out-of-character tags), C2 (a friend's model swaps to their
hero when speaking in character, and the hero's head sits below the table edge; the middle camera should fit every
face), V (engine: the toast's header cut, the key strip with no backing, a bubble over the room title).

**Root cause.** Each panel, card and bubble is positioned on its own, with its own fixed coordinates, added at a
different time by a different batch. Nothing knows the others are there. The text checks find cut-off text, but no
check measures overlaps, and nothing checks the 3D camera's framing after the in-character model swap.

**The fix.**
- Screen zones: a small registry in game/ui (top bar, story panel, caption band, bubble band, card area, tiles, toasts)
  that every piece asks for its place; two pieces can't take the same zone at once without one moving or waiting.
- The camera: a framing rule for the middle view (every seat's head, as the friend and as their hero, inside the view
  above the table edge), with a little zoom-out or smaller models (C2).

**The rule.** Nothing on screen covers something else that's meant to be read, and every face fits the view.

**The check (overlap test).** In SCREEN_CHECK mode, after every dump: the bounding boxes of visible readable nodes
(captions, bubbles, cards, tiles' text) don't intersect beyond a margin. In the engine check: a camera test that
projects each seat's head (both models) and fails if any is outside the view or under the table plane.

**Built (November 5, c-fix).** `tools/tests/overlap.lua` measures a screen from the nodes themselves (each text as
wide and tall as its lines come out in its font): two readable texts crossing, or a solid box drawn over one, within
a layer and between layers that aren't modal or popovers (decision cards, hover cards, the tips and the recap
drawers cover the screen on purpose). `museum_smoke.lua` with `OVERLAP_CHECK=1` runs it at every dump and every
step of game night, and `tools/tests/overlap_check.lua` plays eight prologues that way, failing on any overlap and on
any of game night's moving pieces never measured while up. The fix it led to is the zones registry this section
asks for, in a first form: `night_view.zones` (the caption and its voice tag, the room's title, the big and small
rolls, the side card, a toast), which every speech bubble steps round. Still to do: the camera test (each seat's
head, as the friend and as the hero, inside the view); today the engine run's screenshots show it.

## 8. Presentation of state

**What it looks like.** C1 (the friends start session 1 frowning; they should start at least smiling), C27 (Dev's tile
says "beaming" while Brannoc is dying at 0/33), V (screens: a face that frowns beside "beaming"; Sam "tired" every
night regardless of his mood).

**Root cause.** Faces and mood labels are computed from the fun score alone, with starting values that sit in the
frown range, and they don't read the moment's state (able.lua's somber, a hero dying, a lost fight).

**The fix.** One presentation function maps (the friend's mood, their hero's state, the night's moment) to a face and
a label; session 1 starts in the smiling range; a hero dying or a loss overrides a cheerful label.

**The rule.** What a face and a label say agrees with what's happening to that friend and their hero.

**The check.** At every frame the night emits: no cheerful label or face while that friend's hero is dying, dead or
down, or the table is somber; face and label agree; session 1's first frame is smiling or better.

## 9. Promised structure

**What it looks like.** C18 (splitting the party doesn't cut between the hero alone and the rest; it's one line, "You
cut back and forth like a heist movie.", decisions.lua:301), C13 (the "Something to find" card doesn't say what
check the poking hero rolled; in real D&D poking around is an Investigation check that should shape the DM's choice),
C11 (a session starts on a wood camp while the party is inside the museum: the between-nights campfire board stays up
until the first scene is staged), C10 (the snacks and drinks should be eaten through the night as a sign of time).

**Root cause.** Cards and lines were written for the experience we wanted, and some of the engine behind them never
got built: the split is a flag and a sentence; finds are DM cards without the roll that should prompt them; the
opening of a session runs on the default board.

**The fix.**
- Split party: two scenes in turn (the hero alone, then the rest), each with its own board position and beats, cut
  between, and regrouping said; or don't offer the card until it's built.
- Finds: poking around is an Investigation (or Perception) roll by the hero who does it; the find card shows "Oswin
  (Sam) is poking around with a 16 Investigation check", and the options read the total (a high roll makes "they find
  it" natural; a low one makes "nothing tonight" fair).
- A session opens on the board of the room where they stopped (the party where they left off).
- The table props (chips, pizza, drinks) shrink in steps with the table clock.

**The rule.** A card or line may only promise what the engine does. If a feature isn't built, the card isn't offered.

**The check.** For each card and line that names a structure (split, cut to, meanwhile, regroup, a roll's total), a
whole-prologue test that the structure happened (two scenes emitted, a regroup line, the roll's total on the card).

## 10. Templates without facts

**What it looks like.** C3 ("DC 13. You set it yourself and say it out loud.", night.lua:2738, after the DM just set it:
redundant and odd), and most of the confirming reviews' small findings: "I said yes when we X" when they'd argued
against it, "That one hurt" after no damage, "X's plan, Y's timing" with no plan, the twin daggers credited to whoever
handed them over, "two all" when only three spoke, "Lovely to meet you" to someone met weeks ago, Telpur talking to
Euryale "to her face" after she's gone, recaps that give a different docking reason or amount than Flitwidget said.

**Root cause.** Lines are generic templates with fill-ins. Each one implies facts (a plan was made, damage was taken,
four voices were heard, they haven't met) that the template never declares, so nothing checks them. The Dialogue
Desk shows when a line can play, but not what it claims.

**The fix.** Every template declares the facts it implies as conditions on the event log or the state (`needs`): "That
one hurt" needs damage taken this turn; "two all" needs four heard votes; "Lovely to meet you" needs a first meeting;
a recap's docking reason is the reason Flitwidget said (one owner: the docking event). The Desk shows each line's
needs beside its when.

**The rule.** A line says only what its conditions guarantee. A template with no conditions may say nothing that
could be false.

**The check (line audit).** For each template that plays in whole prologues, sample its plays and verify its declared
needs held at that moment; and a linter that flags templates containing claim words (hurt, plan, again, first, last
time, kept, all, everyone, two) with no matching condition.

---

## 11. Data shape (November 6)

**What went wrong.** The locked door's places (`MODULE.behind_doors`) were written in the middle of the look-around
table (`MODULE.explore`), so two rooms lost their look-arounds and nothing failed: Lua took the stray lines as more
fields of the wrong table. A misspelt field or a list one level too deep behaves the same way.

**The rule.** Every table in a module has a declared shape (its fields, their types, which are required), and a module
that doesn't match fails before any play. Unknown fields are errors, not ignored.

**The check (owed).** A schema validator over the whole module, from the adventure standard
(`2026-11-06-adventure-import.md`, step 1): every table, every record, every field. It runs first in every gate.

## 12. Checks out of step with the game (November 6)

**What went wrong.** Four times in one round a check failed the game for doing the right thing, because the check kept
its own copy of a rule: an opportunity attack on the foe's neighbour counted as ignoring the DM's pick; a boss told to
go after someone, and keeping on at them, counted as ignoring a later tactics call; a missed tablet read that wakes the
guardian counted as a fight from nowhere; Flitwidget's word for the dead counted as the dead "doing things". And once a
smoke run couldn't press a button because a gift sat over the report, so a check failed on a screen the player would
have cleared. The same split exists inside the game: whether an option is "risky" and whether it's "bold" were worked
out by two functions that disagreed, and a fix to one (the pond's roll) tipped the votes at the next card.

**The rule.** A check reads the game's own judgment where one exists (the same function, not a copy), and when a
check and the game disagree, the first question is which one is wrong. Inside the game, one question has one function.

**The check.** Each fix to a check names the game function it now reads, and gets a case that the game does right.

## Since November 4 (the knowledge playtest, the secrets build, rounds two to four)

Each finding with its class and the check that holds it. "Owed" means the check isn't built yet.

| Finding | Class | Held by |
| --- | --- | --- |
| Names said before the table heard them (Telpur, the archivist, the Witness, the hunters' kind) | 5 | `secrets_check` LINT, `knowledge_check` |
| "She" and a Gorgon's voice on the stairs before anyone knew who was up there | 5 | `knowledge_check` (pronouns: owed) |
| A hero in character naming the boss their hero never heard of | 5 | `knowledge_check` MASKED |
| A friend's idea tested against what the table knows, not what their own hero knows | 5 | `knowledge_check` (per hero) |
| "Book" (the rulebook) taken for the lecture theatre's books, so a place was described mid-fight | 1 | `shown.NOT_ONE`; `roadmap_words_check` F26 |
| Places behind a locked door described, walked to and dug into before the door was open | 1, 6 | `secrets_check` EARLY; `MODULE.behind_doors` |
| The kitchen's doors showing the pack before anyone had seen the kitchen | 1, 4 | `secrets_check` (path places: owed) |
| The book's own reveals missing (the tablet read, the kitchen doors, the pond's tentacles on the way to the water) | 4 | `secrets_check` REACH, `book_check` |
| One friend finding nearly every secret | 4 | `secrets_check` REACH (heroes) |
| A door locked with the key inside, then opened from outside with another key | 10 | `museum_truth` (owed: a line that contradicts the one before) |
| The bird singing the opposite way to the book | 4 | `book_check` against `fidelity.lua` |
| The look-arounds lost to a table nested in the wrong place | 11 | owed: the schema validator |
| A fix that tipped the next vote (the pond's roll made the box a coin 75% of the time) | 12, and R10 | `roadmap_table_check` R10; `risky_option` now defers to an option's `lean` (one function for both: owed) |
| Checks failing the game for doing the right thing (four cases above) | 12 | each check now reads the game's rule |
| A gift over the report hiding a button from the smoke run | 12 | `museum_smoke` takes the gift first |

## The importer's contract (the longer campaign)

Every record the importer makes from a book, and every line written for it, carries:
1. **Audience** for every piece of text: `read`, `dm`, or `reveal = <event>` (class 1).
2. **A page reference** for every fact taken from the book (page numbers only; the reader's own PDF; never the book's
   words) (class 4).
3. **Structure as data:** triggers (what wakes or changes what), what the players know on arrival, secrets, starting
   positions and spawn spots, locked doors, each item's mechanics in rules terms (classes 3, 4, 6).
4. **Knowledge conditions** on every line that names something in the world (class 5).
4a. **Every DM-only fact a secret** (November 6, class 5): a `MODULE.secrets` record with its page, what kind of
   thing holds it and who or where, the DM's hint and tell lines, and the book's own reveal as a path (its skill and
   DC), with two ways out or more of two kinds; the usual ones for its kind come free (`secrets.DEFAULTS`). A secret
   the adventure turns on is `major`. Something that happens in play and shows it is an `event` path the code fires.
4b. **Every room split into what the heroes see and what the DM keeps:** a board's spot names and lines, a room's
   read and a card's `see` say only what's in view (location, terrain, who's there, their quirks and tells); every
   proper name is public, or a secret with a mask for what the table calls it until it's told (`MODULE.told`). The
   importer lists every capitalised term in the book and asks which.
5. **Declared needs** on every template (class 10), and an owner for every fact it reads (the event log, the inventory,
   able.lua, people.lua), never a private flag (class 3).
6. **Decisions spoken by the players:** imported choice points come with each option's own fans and the lines the
   friends use to propose them, never DM narration of what they want (class 2).

A region ships only when its gates pass:
- the spoiler test (class 1), the agency scan (2), the claim scanner (3), the book check against its fidelity sheets
  (4), the knowledge scan, the secrets check (real ways out, lines that wait, every secret found, nothing early) and
  the two-campaign test (5), the movement test (6), the overlap and camera tests (7), the
  state-presentation check (8), the structure check (9), the line audit (10);
- the existing gates (truth test, the roadmap and round-three checks, saves, rules cases);
- and one fresh-eyes review of whole runs, by reviewers who haven't read the code, whose findings are each assigned a
  class here (or make a new class).

These rules and checks also go into AGENTS.md's ground rules and "Checking your work" when they're built, so every
future change follows them.

---

## The tracker

Status: **open** (nothing done), **fixed (c-fix)** (fixed on the c-fix branch, November 5, held by
tools/tests/conner_nov4_check.lua), **partial**, **merged** (the final pass's work, finished and merged on c-fix). Class numbers refer to the sections above. Where a line or file is known, it's named.

### Conner's points on the November 4 build

| ID | What | Class | Where to start | Status |
| --- | --- | --- | --- | --- |
| C1 | Friends start session 1 frowning | 8 | the face/label mapping (game/ui/panels.lua), starting mood | fixed (c-fix, Nov 5, second pass) |
| C2 | In-character model's head below the table; middle camera should fit every face | 7 | the middle camera view, people model scale (main/people/person.script `become`) | fixed (c-fix, Nov 5, second pass) |
| C3 | "You set it yourself" after setting a DC | 10 | game/model/night.lua:2738 | fixed (c-fix) |
| C4 | Topiary called creatures before waking; "smoke" over hedges not burned | 1, 4 | the garden room and briar cards; cards.lua:107 reads `garden_burned` | fixed (c-fix) |
| C5 | DM narrates "Pip thinks better of it" after a warning | 2 | game/model/museum_night.lua:1222; module.lua:747 | fixed (c-fix) |
| C6 | "The metal statue ... hasn't moved. Yet." | 1 | game/data/museum/cards.lua:74 | fixed (c-fix) |
| C7 | Forks read out what each friend wants; should be DM intuition pop-ups under the story panel, sharper with familiarity | 2 | museum_night.lua fork text (~3450), thoughts.read, familiar.lua | fixed (c-fix) |
| C8 | Friends talk in character more as they grow comfortable | 2 | the line picker's in-character share | fixed (c-fix, Nov 5, second pass) |
| C9 | DM caption position clashes with character dialogue; bubbles over the in/out-of-character tags | 7 | game/ui/night_view.lua VOICE (~942), caption and bubble layout | fixed (c-fix, Nov 5, second pass) |
| C10 | Snacks and drinks eaten in chunks through the night | 9 | the table props and the table clock (main/props, generators) | fixed (c-fix, Nov 5, second pass) |
| C11 | A session starts on a wood camp while in the museum | 9 | the night's opening before scene 1 is staged (the between-nights campfire) | fixed (c-fix, Nov 5, second pass) |
| C12 | The knight: a knight mini in a frame from the start; should be a painting that wakes | 1, 4 | the paintings room, `wake = { feature, at }`, the minis | fixed (c-fix) |
| C13 | The find card should show the poking hero's Investigation total | 9 | museum_night.lua look/find cards (~1370, ~1392) | fixed (c-fix, Nov 5, second pass) |
| C14 | The painting's scimitar: mechanical benefit per the book? | 3, 4 | the paintings room's gift, items.lua | fixed (c-fix) |
| C15 | Friends should use the inspiration they hold, well | 3 | the friends' AI, inspiration spending | fixed (c-fix) |
| C16 | Euryale's thoughts upstairs said to the table | 1, 4, 5 | museum_night.lua interludes (3963, 4116, 4249, 4472) | fixed (c-fix) |
| C17 | "Using the daggers" with no daggers in the inventory | 3 | fight.lua:548, items.lua, the hand-off | fixed (c-fix) |
| C18 | Splitting the party doesn't cut between groups | 9 | decisions.lua:301, night:at_hand | fixed (c-fix, Nov 5, second pass) |
| C19 | Telpur's mini runs off the table after the Hunting Grounds | 6 | companions on the board, the post-fight placement | fixed (c-fix, Nov 5, second pass) |
| C20 | The DM says what the players do or want; they should say it | 2 | every dm-style line about the party's choices | fixed (c-fix, Nov 5, second pass) |
| C21 | "YOU, TO THE TABLE" lines no DM would say; a new "what the DM hears from the table" channel | 1, 2 | night:say styles, night_view VOICE | fixed (c-fix) |
| C22 | The Lecturer starts behind the lectern | 4, 6 | the lecture theatre's map spec spawn spots | fixed (c-fix) |
| C23 | Pip started in another room of the offices; locked? | 4, 6 | the offices' map spec, its doors, staging | fixed (c-fix) |
| C24 | No passing through walls, ever, even in quiet moments | 6 | every mini move; sight.walk | fixed (c-fix, Nov 5, second pass) |
| C25 | "+1 on their next roll" must land on the next roll | 3 | rulings.lua:58, night.lua:2954 | fixed (c-fix) |
| C26 | Friends never know they've played before; always the first time | 5 | every friend line that names an adventure fact | fixed (c-fix) |
| C27 | The death-save card overlaps the DM screen and tiles; Dev "beaming" while Brannoc dies | 7, 8 | night_view `dying`, the tiles' labels | fixed (c-fix, Nov 5, second pass) |

### From the confirming reviews (V-items; the four files in confirming-reviews/)

| ID | What | Class | Status |
| --- | --- | --- | --- |
| V1 | **Blocker:** the Steam Mech fights for a party that never woke it (loose end `mech_left`); "They woke the Steam Mech" | 3 | merged (f-facts), its checks pass |
| V2 | Euryale's "Your Witness writes beautifully" without the notebook | 1, 5 | merged (f-facts), its checks pass |
| V3 | After a lost boss fight, stone heroes back next week with no word; Pip both stone and on the floor | 3 | merged (f-facts), its checks pass |
| V4 | Deaths: the wake held in a room not yet reached; chat asks about a dead hero; last-words card gives no last words; epilogue forgets the dead; Euryale's first-meeting speech after a wipe; the dead hero's pack carried in after being left | 3, 10 | merged (f-facts), its checks pass |
| V5 | Money in recaps: a donation-box charge after giving; the recap's reason or amount differs from what Flitwidget said; bare "saw what was left" | 3, 10 | merged (f-facts), its checks pass |
| V6 | Boss night's chain puts knockouts before the fight; "the frame" unnamed | 10 | merged (f-facts), its checks pass |
| V7 | Small contradictions: the bird "can't place it" after being named; sleeping or stone monsters move; "they'd been warned" with no warning; scarabs that "go to her" after being killed; Hit Dice "left" at the first rest; the knight in and out of its frame; "Overdue" at an on-time level; the dice score 55 with no box; "Big rolls: 0 and 0" beside a natural 20 | 10 | merged (f-facts), its checks pass |
| V8 | Opening bids still by seat (Dev fights the garden, Sam's coin, Mara's ritual, Dev's knight, the yield's bids); Sam "tired" 27 times | 2, 8 | merged (f-words), its checks pass |
| V9 | Payoffs get no reaction: the mirror, Hyper Destroyer Mode, the vorpal sword in hand; and they're missing from the recap | 9, 10 | merged (f-words), its checks pass |
| V10 | Templates against facts: "I said yes when we X", "That one hurt", "X's plan, Y's timing", "a move together", the manual line after buying it, Mara's "doesn't add up" with no roll, "Not a bad fight" after a death, chat's false claims | 10 | merged (f-words), its checks pass |
| V11 | Votes: "two all" when only three spoke (22 of 41 tie asides) | 10 | merged (f-words), its checks pass |
| V12 | Same script every run: Session Zero's limits and reactions, the reward scene, Exhibit B's 11 stock lines, Thessaly the only unhappy reactor; Session Zero quotes never agreed ("rare and meaningful", "10:30 pm") | 2, 10 | merged (f-words), its checks pass |
| V13 | Minis: Euryale and Pip missing in the boss-night frame; heroes behind the offices' partitions | 6 | merged (f-screens), its checks pass |
| V14 | Cut-offs left: the report's "+N Fun from your call" and "Suspicious of the cooked..." lines, the fork header, Jess's promise, the ties labels, mini-map labels, the Session Zero hint; the Story sidebar drops sections without saying so | 7 | merged (f-screens), its checks pass |
| V15 | Unexplained: "cooked" and "the DC was 2"; Investment and Suspicion and which way is good; Empathy not where the Thought card says | 7 | merged (f-screens), its checks pass |
| V16 | The handwriting font's capital-looking k; the key strip's backing; the toast's cut letter; the prep header through Ties and locks; prep hours 10 to 8 unexplained | 7 | merged (f-screens), its checks pass |

### Picking it up

1. Done (November 5, branch c-fix, merged into v2-museum): the final pass's three branches; all 27 of Conner's
   points, held by tools/tests/conner_nov4_check.lua (classes 1 to 3's reported cases) and
   tools/tests/conner_nov4b_check.lua (movement, faces, layout, structure, and the general scans for classes 1
   to 3 over every line of twelve prologues).
2. Done (November 5, c-fix): class 4's fidelity sheet and the book check (tools/tests/book_check.lua), class 5's
   knowledge scan and two-campaign test (tools/tests/knowledge_check.lua), class 7's measured overlap test
   (tools/tests/overlap_check.lua) and the zones the bubbles step round. Each fails on 1ea3901, and each fix it led
   to is in its commit.
3. Still to build: the line audit (class 10), the camera test (class 7), and the knowledge scan's second half (a
   line that presumes what's coming without naming it). Conner reviews the fidelity sheet against his PDF; the
   twin daggers are his call (the book gives them no powers, the game made them +1).
4. Then a fresh-eyes review of whole runs, and AGENTS.md gets the importer's contract as ground rules.
5. The knowledge playtest (November 5, after the three checks): nine prologues read line by line against the book
   by three reviewers who hadn't seen the code. Its findings and the fixes it suggests, in order, are in
   `docs/design/2026-11-05-knowledge-playtest.md`. The first decision is Conner's: whether the Gorgon is the premise
   or a secret.
6. Done (November 6, c-fix): the secrets system to Conner's calls (the Gorgon kept secret like the book; no cost to
   reveal; the friends dig by who they are; each hero's knowledge tracked; the ways out shown, with improvised ones
   carded to the DM), and two rounds of fresh-eyes playtests of it against the book. What was found and fixed, and
   the book's mechanics still left open, are in `docs/design/2026-11-05-secrets-and-knowledge.md` ("First plays of
   it"). Held by tools/tests/secrets_check.lua, now in the gate.
