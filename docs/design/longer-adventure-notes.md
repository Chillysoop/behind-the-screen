# Notes for the longer adventure (saved November 2)

Read this before starting the longer, pre-written adventure that follows the museum. It collects
the cause-and-effect feedback from the November 2 playtests (four fresh-eyes readers, ten transcripts).
It also covers what we changed because of it, and what to build differently so a bigger adventure
doesn't repeat it. The full write-up is `2026-11-02-cause-and-effect.md`. The first playtest report is
`2026-11-02-new-player-playtest.md`.

## The one lesson

New players were confused less by missing features than by the game contradicting itself:
- a boss "yields" after she's dead;
- a cupboard door the party turned down is "found";
- the story so far says they heard the truth when they didn't;
- a gnome greets them as strangers on the last night.

Every one of these came from a line written for one outcome being played for another. A longer
adventure has more outcomes, more weeks between them and more people to remember them. So the rule is:
**nothing is said that the state doesn't hold, and nothing happens that the table doesn't hear.**

## Build these before the content

1. **One event log as the source of truth.**
   - Today the facts are spread across flags, marks, `st.chose`, `st.npc`, per-scene fields and the
     ledger.
   - Make one append-only log of typed events, each with its cause and week. For example: foe died
     (by whom, where), item taken (holder), promise made (to whom), NPC saw a deed.
   - Flags and marks become queries over it. The recap, memory, the chat, the journey, the report and
     the truth test all read the same log.
2. **One shape for conditional text.** Today there are `text_if`, `read_if`, `line_if`, `win_if`,
   `lose_if`, `got_if` and chat `{ text, when }`. Unify them as `say = { { when, text }, ..., text }`.
   Any line that asserts an outcome (beaten, dead, gone, took, gave, found) must have a `when` or read
   the log. The authoring check should flag one that doesn't.
3. **Effects declared next to causes.** Keep growing the moment vocabulary instead of one-off code:
   `hurt`, `inspire`, `ready`, `gold`, `give`, items with `opt`/`magic`/`once`, `asides`,
   `callbacks`. Each verb gets a test.
4. **The truth test is the gate.**
   - `tools/tests/museum_truth.lua` becomes `adventure_truth.lua`, run for every adventure, with more
     seeds and DM styles.
   - Add each new class of bug as an invariant. Not yet covered:
     - a person named in a line is present;
     - a chat promise resolves within N weeks;
     - an NPC's greeting matches their memory;
     - a number on screen equals the state;
     - nothing tied by the DM claims something the party did.
5. **Provenance on every line in transcript playtests** (`tools/sim/provenance.lua`), so a bad line
   points at its source.
6. **The adventure supplies its own Session Zero, prep notes, people, gifts and words.** Shared systems
   ask the adventure first and fall back to neutral words, never to another story's. The tables:
   - `session_zero`, `content`, `content_names`, `prep_notes`;
   - `memory`, `talk` (including `done`), `npc_lines`;
   - `keepsakes`, `recap_beats`, `friction`;
   - `magic_items`, `items`, `asides`, `callbacks`, `want_more`, `chat`.
7. **A lexicon per adventure.** `adventure.fits` checks shared lines against the adventure's own
   vocabulary. That vocabulary is built from all of the adventure's text, so a word in a hook ("the
   taverns say...") lets tavern lines through.
   - Give the vocabulary an exclude list, or build it only from in-world fields.
   - Add the museum's own names to `game/data/fiction_words.lua` when the next adventure starts, so it
     doesn't inherit Flitwidget and Telpur.

## What the playtests found, by kind (and what to design for)

**Old-story leakage.** Shared lines from the old campaign got into the museum:
- taverns, goblins, the Vale, "by the road", "the orphans' bake sale";
- "Same tavern, same time", "I call the ring";
- "last time..." on the first night.

The museum is clean now. For the next adventure: run the lexicon gate from day one, and review the
shared friction, banter and table-behaviour lines for words that assume a setting.

**Fixed text that asserts an outcome.** These were all written for one outcome and played for others:
- goal "got" lines and recap clauses;
- the closing lines ("the Witness, a sunken city" without the notebook);
- settle-up questions asked before the news was told;
- "Is it done?" after it was done;
- the Mech "waiting for orders" after it burnt out.

Design for: every line about what happened is conditional, and the log decides.

**Causes without effects, and effects without causes.**
- Pickups that never came up: daggers, fire arrows, a painted pistol, a mop.
- Hurts with no damage: "cut and furious".
- Group-chat answers that set nothing: a vorpal sword, a short rest, a shoelace.
- "Something old learns your name... a new problem" that never comes back.
- Session Zero asks nobody tests.

Design for: every flag is read, every promise has a payoff or an expiry, and the truth test enforces
both.

**DM tools that can write false fiction.**
- A tie put "a mirror in their packs" on Euryale's card, and every screen then said they took a
  cupboard door.
- The map repository offered taverns and roads for a museum.

Design for: a DM tool can only do what the fiction allows. Marks the party must earn (`party = true`)
can't be tied, and boards are filtered to the adventure.

**Fight-state truth.** Each of these needs one place that decides it, and every line after it reads
that:
- dead vs. ran vs. surrendered vs. yielded;
- a hero still stone, or on 0 HP, chatting after the fight;
- a charmed hero who looks idle;
- "teamwork" from a hero who did nothing;
- the killing blow credited to someone other than who landed it;
- doubled damage with no reason given.

**Order of beats.**
- The goal line was said before the ending was decided.
- The boss board was built before the left-behind marks landed.
- A question was asked about news before the news was told.

Design for: beats that depend on each other declare the order, and the board is computed from the
same state the night will use.

**Session Zero promises.**
- A line was handled like a veil.
- The open-death promise was broken by a hidden death roll.
- The X-card never came up.
- Jess's "don't cut my chats" ask was never tested.

Design for: each ask names what it touches in the adventure (`content`), each agreed promise is
checked where it could break, and the prep board shows where tonight meets each one.

**NPC memory.**
- Flitwidget said hello three ways in one scene, the last as a stranger.
- On the last night he still used his "incidents" lie.

Design for: one greeting per scene, never a first-meeting line after meeting, and talk that knows
the adventure's state (`talk.done`).

**Reporting and numbers.**
- "Nothing picked up" was shown right after finds.
- The Francs line was hidden when the night's net was zero.
- One report showed two durations a minute apart ("2h 45m" and "2h 44m").

Design for: the report is a read of the log, with nothing computed a second way.

**Economy.**
- Every gift-shop item cost more than the party ever had.
- Trips back to the shop happened with nothing affordable.

Design for: income and prices from the same table, and a sim that reports what was affordable when.

**Noise and pacing.**
- The same hint was offered at five forks in a row.
- Second looks turned up nothing.
- A night stopped without saying so.
- "It's just what Pip would do" came five times with no deed.
- Rounds passed with heroes walking and nothing said, on the lair's big board.

Design for: a line once a night unless it's new information, and every friction line describes a
deed.

**Location (fixed November 2).** Fork text ("three doors off the hunting floor") was chosen by which rooms
were on offer, not by where the party stood. The night's opening said "the gift shop door clicks shut" when
they'd stopped elsewhere. The stairs were "between the studies" before anyone had seen them. A side room
was reported under the room it opens off. Now `MODULE.fork_at` describes the fork from where they stand,
and `openings_from` describes the start of a night from where they stopped. The truth test fails on a fork
that describes another room. Design for: every location line reads the party's position.

## Still open from the museum (fix or design around)

- **Long walks.** On big boards, several rounds pass with heroes walking and nothing said. A charmed
  hero whose only reachable foe is the one who charmed him looks idle.
- **Killing-blow credit.** Handing the killing blow to another player narrates their hero landing it,
  while the dice log shows who did.
- **Small numbers.** Duration rounding differs between two report lines. The spotlight conflict line
  can disagree with that night's spotlight.
- **Thoughts.** Two friends can have the same thought word for word. A "good news" mood line can read
  as sarcastic.
- **Jargon.** "Breezy" and "Deadly" danger labels, "SECRET CHECK", and other rules words without a
  hover.

## Checklist when the longer adventure lands

- [ ] Event log in place; flags and marks are views of it.
- [ ] One conditional-text shape; authoring check for unconditional outcome lines.
- [ ] Adventure tables filled: Session Zero, content tags, prep notes, memory and talk, items, magic
      items, asides, callbacks, chat, recap words, friction, keepsakes, want-more.
- [ ] Lexicon: the adventure's vocabulary built from in-world text only; the museum's names added to
      `fiction_words.lua`.
- [ ] `adventure_truth.lua` passes on 20+ seeds across three DM styles, with the new invariants above.
- [ ] Economy sim: what the party can afford, when.
- [ ] Three fresh-eyes transcript playtests (`TRANSCRIPT=file`), findings verified, each class turned
      into an invariant.

## Round 3 (November 2): are the DM's calls clear and impactful? Do the friends repeat?

This round used six UI transcripts (seeds 31 to 36), 16 headless runs (seeds 41 to 48, careful and random
DMs) and two fresh-eyes readers.

### The DM's calls

Most cards are clear, and many matter:
- fire or water at the pond;
- robbing the donation box (Euryale's card, Flitwidget's memory, the ending);
- a quick ruling that becomes a promise Sam remembers;
- Heroic Inspiration;
- why each hero came.

77% of the museum's moment options change the adventure's state. 25 of the 104 shared decision options
change the fight or the scene; the rest only move the friends' meters.

The biggest calls are the least readable:
- **An ambush opener** skips the talk, so marks that offer a talk option (thieves, sleeping pages)
  are wasted.
- **"The enemies break and flee"** on round 6 lets Euryale escape, and that becomes the ending.
- **When the night runs out of calls**, the dice decide in silence.

Some cards do nothing, or say something false:
- "minions drop" against a lone foe;
- "costs" that cost nothing ("the torch goes out");
- "better outlet next scene" that never comes;
- a mark's reason that contradicts what happened: "never woken" for a knight who fled, and the drone
  still listed after the Lecturer was silenced.

Hidden mechanics don't show in the log: drowsy Disadvantage, the fire arrows' die.

Feedback on how a call landed is good in the moment ("X would love it", reaction lines). Afterwards it's
weak: the room-end "The table:" line has no cause, and the report gives generic reasons.

### The friends

Each friend is the same person every run, which is good. But too much is fixed:
- **Fork votes.** On the second floor, Mara wants the offices, Jess the lecture theatre and Dev the stairs
  in 8 of 8 runs. `want()` is archetype tags, plus the hero's reason room, plus a little noise; mood and
  history are never used.
- **Who takes a card.** A card's actor is the first friend whose main archetype is on its list. So the
  plaque and the tablet always go to Mara, the box to Jess, "Can I block my ears?" to Sam, and the
  locked door to Dev (`night:pick_actor`).
- **Who opens a room.** Only Thessaly or Pip.
- **Pip's theft.** "Pip pockets a little brass figure" happens 2 or 3 times a run, with Thessaly's jab
  each time. It's the only friction act left after the museum filter, and it ignores the DM's answers
  and death (a dead Thessaly still glares).
- **The group chat, requests, settle-up approaches, goodbyes and subclass picks** are word for word every
  run.
- **Lines that repeat.** About a third to a half of in-character lines turn up in another run. Dev's fight
  barks and Mara's long-fight tell recur most.

What does vary comes from the DM and the dice: routes (8 of 8 distinct), who drops, cooked rolls and
steering. The systems react to those (suspicion, Sam's promise, the retreat vote when hurt), but the
words don't.

### What to build for the longer adventure

Friends decide from state, not just archetype:
- votes and actors weigh mood, hit points, spotlight, recent events, rapport and the hero's reason,
  and the friends say why;
- leads rotate;
- friction acts are finite, escalate, and listen to the DM's answer;
- group chat and requests are drawn from the night's events (the event log);
- barks are tied to the actual moment;
- line freshness carries across weeks;
- death and new heroes are honoured everywhere.

For DM calls:
- put the consequence on any card that touches the ending;
- every mark's reason comes from what happened (`why_if`);
- say when the call budget runs out;
- remove no-op options;
- label steering and the end of the night on forks;
- a "your calls tonight" block in the report names each call and who it moved.

### Fixed after round 3 (November 2)

DM calls:
- **Consequences on the card.** The ambush opener lists what it gives up on the boss board. "Break and flee"
  says Euryale escapes and that it ends the adventure. A fight card drops options that can't do anything
  (no minions to drop). The call budget says when it runs out: "From here the dice decide, out in the open."
- **No false or empty calls.**
  - A quick ruling's "cost" is now real damage (`MODULE.ruling_costs`).
  - "Give them the next big moment" keeps its promise: the next card and roll go to that friend.
  - Mark reasons come from what happened (`why_if`, `thought_if`, and "You tied it to happen").
  - Silencing the Lecturer takes the drone off her card.
  - A burnt-out Mech says so.
- **Hidden mechanics show.** A save says "with Advantage" or "with Disadvantage" and why (the drone, wax
  in their ears, the manual). The fire arrows' extra die is in the dice log. The manual's Advantage now
  actually applies; it never did before.
- **Fork labels** say whose pick it is ("the table's pick", "steering them", "steering them again: costs
  Trust") and that the stairs end the night.
- **Feedback after.**
  - Each room's end card names your biggest call there and whose Fun it moved.
  - Each friend's row on the report names the call that moved them most, in place of the meter's guess.
  - The wrap-up lists your three biggest calls of the night (`night.call_log`).

The friends:
- **Votes come from the night** (`fork_mood` in `museum_night.lua`), and each friend says why:
  - their hero is hurt, or went down in the last room;
  - the last fight went badly for them, or they loved it;
  - a fighter itching after a quiet room;
  - boredom;
  - a quiet night so far;
  - their hero's reason for coming;
  - following a friend they've grown close to.

  The truth test checks that the "hurt", "went down" and "why they came" reasons hold. On the second floor,
  the first vote now differs in about half the runs.
- **Leads rotate.** `night:pick_lead` weighs the card's archetypes against spotlight, who led last, a downed
  hero and boredom. Each museum moment picks its own lead. A card that is one friend's own (`who`) keeps
  them, and names whoever they play now.
- **Pip's mischief is finite.**
  - Each act happens once a prologue (`adv.acts_done`).
  - Answering it calms the doer (`adv.calm`).
  - A promised "next big moment" is kept.
  - The jab comes from someone who's alive.
- **The group chat starts from last night** (`museum_week.night_lines`): a hero lost, a hero on the floor,
  the last hit, being overruled, the call that made or spoiled their night, a hero's reason paid off.
  Room lines fill in after.
- **Requests read the state** (`ask_if`, `only_if`, `adventure.request_ask`).
  - "Out of spells" is asked only when the hero is out of spells.
  - The rest request is asked only when someone is hurt.
  - Requests name whoever the friend plays now.

Still the same every run: the subclass picks, settle-up approaches, goodbyes and most room chat lines. These
are the next candidates.
