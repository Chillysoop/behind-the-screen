# Cause and effect: one voice, one truth (November 2)

The new-player playtest (`2026-11-02-new-player-playtest.md`) found the same problem everywhere: what the
table hears and what happened drift apart. A boss "yields" after she's dead. A party pockets two daggers
that never come up again. A gnome forgets the coin they put in his box. The group chat promises a vorpal
sword that doesn't exist. The game was borrowing lines from the old campaign (taverns, goblins, the
Kettle) that the museum never set up. This note records what changed, the rules we now hold to, and how
to keep it true as the adventures get longer.

## What changed

**The old story is gone from the museum.** `game/data/fiction_words.lua` lists the old world's places,
people, creatures and goods, plus callback phrases ("just like last time"). `adventure.fits(text)` drops a
shared line that names one, unless the adventure itself names it too. It runs over every shared
content list when the adventure starts (`adventure.enter`) and over the dialogue library. A new adventure
gets the same check against its own words for free.

**One voice per moment.** A room's prize is announced by whoever owns it: the moment that hands it over,
the ending, or the Francs pool. It's never announced twice, and never announced when it wasn't won.
Goal lines have `win_if`/`lose_if` variants chosen by what happened (who fled, which ending, what was
bought). On boss night her goal line waits for the ending.

**Fights end the way the dice say.**
- `combat_scene` records `foes_beaten`, `foes_ran`, `boss_dead` (and how), `boss_ran` and `boss_yielded`.
  Everything said afterwards reads those.
- Euryale yields inside the fight, below a third of her hit points, when the DM prepped her to. Her
  side stops with her, and the yield card plays after.
- The dead never yield. If she dies but her collection wins, the ending is still that she fell. If her
  own mirror got her, it's a stone ending.
- No goblins: an adventure fight's reinforcements are more of what's on the mat.
- Foes who never talk have no last words.

**What they pick up works.** `MODULE.items` says, per flag or mark, what it does in the fights after:
a battle option, a real magic item on the holder's sheet, a line at the start of the fight.
- The twin daggers are a +1 weapon on whoever pocketed them.
- Telpur's fire arrows burn for one fight.
- The Mech manual gives Advantage against overheating. A test-fired red switch is spent.
- The mirror, the bracelet and the book on gorgons protect against her stare.
- A failed drink starts the hero charmed.

Moments carry their consequences as data:
- `hurt` puts the damage on their sheet;
- `inspire` gives Heroic Inspiration;
- `ready` means no ambush.

**The week between counts.**
- Marks added in the group chat get Euryale's line at the next night.
- A promised rest is given.
- A loose-end Mech has a name.
- The answers that set flags come back at the table: a fussing gnome or a talking boot gives them away
  (`MODULE.asides`), and rooms have `callbacks` for what was promised (the vorpal sword behind her
  couch, Telpur telling Flitwidget everything).
- A ruling promised at the table can be posted before it breaks.

**NPCs remember.** `adventure.meet/met/memory/deed` and `MODULE.memory`. The DM runs the museum's
people, so they greet the party as people they know, and the talk card says what they know.

**Session Zero and prep are for this adventure.**
- `MODULE.session_zero` pitches the museum and asks about what's really in it: gore (the archivist) and
  creepy-crawlies (scarabs, huntlings). `MODULE.content` maps those tags to rooms.
- `soft = tag` picks gentle words at the table, and the DM says so once a night.
- The prep board says what prepping a room means: the minis, the voices, the handouts, and the ask it
  meets (`MODULE.prep_notes`, `museum_week.room_prep`).

**The truth test.** `tools/tests/museum_truth.lua` reads the data cold and plays whole prologues:
- every flag set is read by something, and every mark changes her fight or her talk;
- a log that says someone is hurt hurts them, one that says a Franc appears pays it, one that says they
  pocket something sets what they now have;
- no shared moment names a hero;
- in play: dead means fallen, a foe that ran is never "the last one falls", every mark gets her line,
  every pickup is on a sheet, every line fits the adventure.

## The rules we hold to

1. **Nothing is said that the state doesn't hold.** A line is either data about what happened (read from
   state) or it's conditional on state (`when`, `text_if`, `win_if`). A line that asserts an outcome
   unconditionally is a bug waiting for a different outcome.
2. **Every effect has a cause the table heard, and every cause has an effect.** If a log says it, the
   sheet, the map or the card says it too. If a flag is set, something reads it. If nothing should read
   it, it shouldn't be set.
3. **One owner per beat.** Exactly one system announces a prize, an ending or a death. Others record.
4. **The adventure owns its fiction.** Shared lines are table talk and mechanics. Anything about the
   world comes from the adventure or passes `fits`.
5. **The DM's choices are state.** What the DM picked (`st.chose`), how they prepped the boss
   (`boss_style`), what they told the chat: all of it is readable later, and lines read it.

## The path forward, for longer adventures

The museum is ten rooms and a boss. The campaign that follows will be dozens of scenes, more people,
more items and more weeks between. What held the museum together by hand won't scale by hand. In order
of payoff:

1. **An event log as the single source of truth.** Today the facts live in several places: flags, marks,
   `st.chose`, `st.npc`, per-scene fields and the ledger. Move to one append-only log of typed events,
   each with its cause and its week:
   - `{ "foe_died", id, by, room }`
   - `{ "item_taken", id, holder }`
   - `{ "promised", what, to }`
   - `{ "npc_saw", npc, deed }`

   Flags and marks become queries over it. Recaps, memory, the chat, the journey and the truth test all
   read the same log, so they can't disagree.
2. **Lines are conditional by default.** Give every authored line an optional `when`. The authoring tool
   and the truth test should flag any line that asserts an outcome (beaten, dead, gone, took, gave)
   without one. `text_if`/`read_if`/`line_if`/`win_if` are the start of this; unify them as one
   `say = { { when, text }, ..., text }` shape.
3. **Declare effects next to causes.** Keep growing the `mus` vocabulary (`hurt`, `inspire`, `ready`,
   `item`, `give`) instead of writing one-off code. An adventure should be data plus a small set of
   verbs the engine knows. Every verb needs a test.
4. **Make the truth test the gate.** Run it in CI on every adventure, with more seeds and more DM
   styles. Add invariants as playtests find new classes of bug, not instances:
   - a person named in a line is present (or the line is about their absence);
   - a promise in the chat resolves within N weeks;
   - an NPC's greeting matches their memory;
   - a counter on screen equals the state.
5. **Provenance on every line.** `tools/sim/provenance.lua` already records which code said each line.
   Keep it running in the transcript playtests, so a bad line points straight at its source.
6. **The adventure supplies its own Session Zero, prep notes, people and gifts.** The museum shows the
   pattern: `MODULE.session_zero`, `content`, `prep_notes`, `memory`, `talk`, `keepsakes`,
   `recap_beats`, `magic_items`. A longer adventure fills the same tables. Shared systems should ask the
   adventure first and fall back to neutral words, never to another story's.
7. **Fresh-eyes transcript playtests every batch.** `TRANSCRIPT=file lua tools/tests/museum_smoke.lua
   seed` writes every screen in order. A reader who doesn't know the code finds the contradictions
   tests don't think of. Verify each finding against the transcript, then turn its class into an
   invariant (step 4).
8. **Lint the fiction lexicon per adventure.** When a new adventure arrives, its own vocabulary decides
   what fits. The old museum's words should be added to `fiction_words.lua` too, so the next adventure
   doesn't inherit them.

## Three more fresh-eyes playtests (the same day)

Six new transcripts (seeds 3, 5, 9, 12, 14 and 21), read by three readers who hadn't seen the code.
The old story was gone: no Ilsa, Kessrick, Vale, Kettle, village or goblins in any of them.

**Fixed:**
- **The DM's tie.** A tie added "a mirror in their packs" after the garden, and from then on every
  screen insisted they'd taken a cupboard door. Marks the party has to earn (`party = true`) can't be
  tied now.
- **Inspiration on a cooked miss.** Moving the DC to make a miss handed out Heroic Inspiration, because
  of an index left over from the triumph menu.
- **Euryale's yield** read as "surrenders" and "Ran:" for her whole collection. It's "stood down" now,
  said once.
- **Heroes left at 0 HP or as stone** kept chatting and rolling. They come round, or crack free, with a
  line.
- **The story so far** reported what the goal hoped for, not what happened. `got_if` fixes that.
- **Boss prep.** Rooms they never played added foes to her card after the board was built. Those marks
  land when the boss week starts, unless a pending loose end decides.
- **Session Zero.**
  - A line and a veil are no longer the same thing: a line leaves it out, a veil keeps it off screen.
  - The scarab burst softens for a bug veil.
  - A hidden death roll no longer saves the hero whose player asked for open deaths.
- **Flitwidget** said hello three ways in the thanks scene, the last as a stranger. He also asked about
  news before telling it, had no money line that paid out, and a final roll could fail the thanks.
- **Friction and bond lines.** Each one has a museum deed in it now. A "teamwork" line needs two
  heroes who acted. No tavern, road or ring.
- **The report** counts what was found, handed out and earned.
- **Smaller fixes:**
  - doubled damage says why;
  - fair warning explains itself once;
  - the gift shop is affordable, and trips back need something to buy;
  - the hint is offered once a night;
  - trips back aren't labelled as the room's fight;
  - the night says when it stops;
  - the map repository offers only boards that fit the museum.

The truth test now also fails on:
- a found prize the report doesn't list;
- a hero ending a night on 0 HP;
- a hero still stone after a night.

**Still open (worth a look next):**
- **Long walks.** On the lair's big board, several rounds pass with heroes walking and nothing said;
  a charmed hero whose only reachable foe is the one who charmed him looks idle.
- **Killing-blow credit.** Handing the killing blow to another player narrates their hero landing it,
  while the dice log shows who did.
- **Small numbers.** One report can show durations a minute apart ("2h 45m" and "2h 44m"); the
  spotlight conflict line can disagree with that night's spotlight.
- **Where they are.** Fork text ("three doors off the hunting floor") is chosen by the rooms on offer,
  not by where the party stands. A side room is reported under the room it opens off.
- **Thoughts.** Two friends can have the same thought word for word. A "good news" mood line can read
  as sarcastic.
- **Jargon** a new player trips on: "Breezy" and "Deadly" danger labels, "SECRET CHECK", "Graze".
