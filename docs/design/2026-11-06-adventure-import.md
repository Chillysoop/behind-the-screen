# Importing an adventure from a PDF: the pipeline, and the first one

November 6, 2026. Two parts: (1) an upload pipeline meant to work for any adventure PDF, and (2) its first run,
*The Wild Sheep Chase* (Richard Jansen-Parkes, DMs Guild, 6 pages, 4th to 5th level) at *the Bogden Road Country
Inn* (a tavern sheet Conner shared as images), stitched onto the end of the museum. Nothing is built yet: this is
for Conner's calls (the end of this note) before any code.

It builds on what's already decided and written, and changes none of it:
- the Main Campaign Design doc's "Importing a 1,200-page book" and "Build order"
  (https://claude.ai/artifact/UjVzYSuuqJmGo2FDs4UmSw): read the reader's own PDF in the session and never store it,
  pull the world out paraphrased with page numbers, maps through `tools/maps`, line banks with conditions, review on
  the desks, then the checks;
- the importer's contract and its gates (`2026-11-05-root-causes.md`, "The importer's contract", items 1 to 6 with
  4a and 4b);
- `longer-adventure-notes.md` ("Build these before the content" and its checklist);
- the secrets system as built (`2026-11-05-secrets-and-knowledge.md`; `game/model/secrets.lua`, `told.lua`,
  `shown.lua`, `ideas.lua`'s digging, `game/data/find_out.lua`, the person sheet's WHAT THEY KNOW);
- AGENTS.md's ground rules (the book's structure is data, the friends know only what they've been told, every
  secret is a record with its ways out, things are described before they're named, never copy the book);
- Conner's decision that later adventures use the museum's module format.

**What the museum is** (Conner, November 6): a prototype, built to grow a game system for any adventure he uploads or
we write together. It may be deleted if the author doesn't give permission, so nothing shared may need it: the Sheep
Chase plays on its own (a fresh party) or after any adventure, and the hand-off is any adventure to any other. The
end goal is an adventure creation tool in the game, so DMs can make their own (lore, people, maps and all): the
standard is the format that tool will write.

**Permission:** as with the museum, a DMs Guild book is for private playtesting. The PDF stays out of the repo; our
data paraphrases it and points to pages.

---

## Part 1: the pipeline

### What "any PDF" can mean

Reading an adventure is judgment: who's public, what's secret, what the author meant. No script does that reliably,
so the reading is done in the session (Claude, following a written procedure), and everything around it is tooling
that makes the result the same shape every time and checks it. Three things vary from book to book and are planned
for, not hoped away:
- **the PDF itself:** text or scanned, one column or two (the museum's text came out with its columns interleaved),
  stat blocks and sidebars;
- **the calls:** every book has places where public and secret aren't clear, and those are Conner's, asked before
  building;
- **new mechanics:** a book with something the engine can't do (a wand that misfires, a bed that turns into a
  dragon) needs code. Each import lists what it needs, and the rules library grows with each one.

### The stages

| Stage | What happens | Exists today | To build |
| --- | --- | --- | --- |
| 0. Ingest | The PDF becomes per-page text (column-aware, OCR for scanned pages), page images, and a list of stat blocks and maps found. Kept outside the repo. | `pdftotext`, `pdftoppm` | `tools/import/ingest.py` |
| 1. Draft | The book is read whole and drafted into the module format, every record with its page, in our words (below). | The museum's format, by hand | The procedure, written down (then saved as a skill once it's proven) |
| 2. Calls | Every judgment call is listed for Conner: each capitalised term (public, or a secret with a mask), each DM-only fact, each gap or contradiction in the book. | The contract asks for it (4b) | A calls list the draft writes out |
| 3. Check | The data is checked before any play: real ways out, lines that wait, every secret findable, nothing early; the book's structure; maps; nothing copied. | `secrets_check`, `knowledge_check`, `book_check`, `museum_truth`, `build_maps --check` (all museum-only) | The same checks for any module, plus a copy check and a reachability check |
| 4. Engine | The adventure runs: its scenes, people, monsters and special rules, and the hand-off from the adventure before it. | The museum only | A module slot and the hand-off; the book's new mechanics |
| 5. Play | Sims over seeds and three kinds of DM, then a fresh-eyes read of whole runs against the PDF, fixes, the full gate, the engine run, a build. | All of it, for the museum | Pointed at the new module |

### What the draft writes (the module format)

The museum's files, one set per adventure (`game/data/<adventure>/`):
- **`module.lua`:** the arc (scenes in order, where they branch), and for each scene what's **seen** on arrival
  (place, terrain, who's there, their quirks and tells: contract 4b) and its moments with options the friends propose
  in their own words (contract 6), triggers and locks as data (contract 3);
- **`secrets.lua`:** every DM-only fact as a secret: its page, its holder (a person, place, document, body, item or
  creature), hint and tell lines, the book's own reveal as a path with its skill and DC, and two ways out or more of
  two kinds; the defaults for its kind come free (`secrets.DEFAULTS`); `major` for the ones the adventure turns on;
  `event` paths for things that show it in play (contract 4a);
- **`told` masks:** what the table calls each secret name before it's told ("the hooded woman" for Euryale);
- **people:** each named person's sheet (voice, wants, what they hold, how the table first sees them), memory and
  lines with conditions;
- **monsters:** SRD ones by name; the book's own stat blocks as numbers (numbers are rules, not prose); each special
  rule named;
- **items:** each with its mechanics in rules terms;
- **`fidelity.lua`:** the book's facts with pages, for `book_check` and the knowledge scan; what we add is marked
  `ours`;
- **maps:** battle maps through `tools/maps` (`import_map.py` reads the grid, `draft_to_spec.py` makes a spec, our
  own kit pieces drawn over the book's layout, so no art is copied);
- **table life, cards, chat, recap words, Session Zero pitch, prep notes, keepsakes:** the adventure's own (AGENTS.md:
  the adventure owns its fiction).

### The checks it has to pass (from the contract, made module-agnostic)

- The secrets check (DATA, LINT, REACH, EARLY) and the knowledge check, for the new module's secrets and fidelity
  sheet; nothing known from the museum leaks forward or back (the two-campaign test).
- The book check against its fidelity sheet; the truth test as `adventure_truth`; the maps check.
- **New: the copy check.** No run of eight or more words in our data matches the PDF's text.
- **New: reachability.** Every scene, secret and ending can be reached in the sims.
- Then the existing gates (roadmap and round-three checks, saves, rules cases) and one fresh-eyes review.

### What has to change in the engine first

The game is built around the museum: `adventure.lua` loads the museum's data directly, 30 model files name the
museum, and the museum's own logic is about 12,000 lines (`museum_night.lua`, `museum_week.lua` and the data). So
before any new content:
1. **A module slot.** The museum moves into it unchanged, and every museum test still passes. Shared systems ask the
   current module (Session Zero, people, words, items, secrets); museum-only rules stay the museum's.
2. **The hand-off.** What carries from one adventure to the next: the heroes (level, hit points, items, scars), what
   each hero knows, who they've met and what those people think of them, the event log, the friends at the table
   (moods, rapport, goodwill). What doesn't: the museum's Francs (worthless outside it), its rooms and its clocks.
3. **The longer-adventure list's first items** where this needs them: the adventure's own tables, and the
   lexicon (the museum's names go into `fiction_words.lua` so the next story doesn't inherit Flitwidget).

---

## Part 2: The Wild Sheep Chase at the Bogden Road Country Inn

### Why it fits

It's written for 4th to 5th level, and our party ends the museum at level 4. It opens on an afternoon off, at a tavern
or in the street (p2), so the inn is its natural first scene. It's small (one fight in the inn, one at a house in the
woods), but it exercises most of the secrets system: a talking animal nobody can understand yet, beasts that are
really people, a narrator who leaves out his own part, a villain with his own side of the story, and a magic item
whose danger the DM has to hint at before it's used.

### The story, scene by scene

1. **The inn** (inn sheet; p2). An afternoon off at the Bogden Road Country Inn. Teddy Bolandeere, the innkeeper, is
   the local rumour hub; the book suggests seeding rumours of a feared, admired wizard called Noke (p2).
2. **The sheep** (p2). A sheep bursts in with a sealed scroll in its mouth and makes for the most magical hero. The seal
   says it's Speak with Animals; read aloud, it lets everyone understand the sheep: Finethir Shinebright, an elven
   wizard, who begins to tell his story.
3. **Guz** (p2 to p3). Howling. A huge half-orc, Guz, comes for "Master Noke's sheep" with three collared wolves and a
   hooded figure. He'll talk, bribe or threaten, then fight; his side wants to grab the sheep, not kill it. If they get
   him, they make for Noke's house and it's a chase. In an inn: overturned tables and chairs.
4. **After the dust settles** (p3). Shinebright's version: his tower, his wand, his apprentice Noke turning him into a
   sheep two years ago, the escape last night. He promises rewards he can't pay.
5. **The house in the woods** (p4). A path off the main road a few miles out, fresh tracks of the group Guz led.
   Shinebright's old house is three platforms woven from four living oaks: a garden, the main hall (library and lab,
   sitting room, dining room and kitchen), and a bedroom above; two huts and an outhouse below. Three apes with
   greatswords on the lawn; a brown bear in the outhouse. The hall's door is usually locked (Athletics 14 or thieves'
   tools 12).
6. **Noke** (p5). He orders them to hand back the sheep. Talked to, he tells his side and asks after Guz. In a fight he
   buffs his guards (Enlarge on the bear, Ray of Frost), then flees to the bedroom; three rounds later he bursts out
   riding his bed, turned into a wooden dragon. If it falls, he turns the wand on himself and it misfires: a gibbering
   mouther.
7. **Other ways in** (p5, p6). Lure him out with a fake prestigious contract (very hard, he's paranoid); steal the
   wand while he sleeps (he rarely does); disarm him. The book says to let these play out, not force the main path.
8. **Big choices** (p6). The recovered wand is damaged: Arcana 15 to see it's unreliable; each use is Arcana 17, a
   miss turns the target into a gibbering mouther, a bad miss also blows it up. Shinebright wants it used on him anyway
   (Persuasion 15 talks him out of it) and asks that his college be told if he dies. Outcomes: restored (no money, but
   transmutation services); dead (loot about 1,000 gp of lab gear, or keep the house, and nobles come looking for
   Noke); refused (he keeps hoping, owes them). 500 XP each either way.

### What the table sees, and what the DM keeps

| Scene | Seen on arrival (public) | Kept (secrets) |
| --- | --- | --- |
| The inn | The common room, the bars, the hearth, the stage outside; Teddy; the travellers (Count Turleon, Sir Luenn) | Rumours about Noke until asked |
| The sheep | A sheep, a scroll with a seal saying Speak with Animals | That it's a wizard, until the scroll is read |
| Guz | A half-orc, three wolves in iron collars with strangely clever eyes, a big hooded figure | The beasts are people; the hooded figure is a bear |
| The story | What Shinebright says | What he leaves out: how he treated Noke; that he can't pay |
| The path | A well-trodden path, fresh tracks | Whose tracks (Guz's group) until read |
| The house | Three platforms in living oaks, huts, an outhouse, apes playing dice | The bear in the outhouse; the locked door; Noke's escape plan |
| Noke | A frantic wizard and his demand | Why he did it; the wand on him; the bed; the misfire |
| The wand | A cracked twig with an iron band | That it's dangerous to use (the book insists on at least a hint before anyone uses it) |

### The secrets (first draft, for `secrets.lua`)

| Secret | Holder | The book's way | Other ways | Page |
| --- | --- | --- | --- | --- |
| The sheep is the wizard Shinebright (major) | the sheep | read the scroll | Insight or Animal Handling (it acts far too clever: a hint), Detect Magic (transmutation), Arcana on it | 2 |
| Guz's beasts are polymorphed people | the wolves, the bear | the hood falls in the fight (event) | Insight on their eyes (hint), Detect Magic, Shinebright says so | 2 |
| What Noke wants, and why (major) | Noke | talk to him | Shinebright's story (his side only: a hint), the notes in the lab, Insight on Shinebright | 4, 5 |
| Shinebright can't pay | Shinebright | told afterwards | Insight on his promises (hint), the bare house | 3, 6 |
| A bear in the outhouse | the outhouse | it comes out (event) | Perception, Survival at the tracks, a smell | 4 |
| The wand never leaves Noke | Noke | Shinebright says so | watching Noke, Insight | 3 |
| The bed (his escape) | Noke | it happens (event) | none before; the DM can hint | 5 |
| The wand is unreliable (major) | the wand | Arcana 15 on it | it sparks when touched (the book's hint), Noke warns them, Detect Magic or Identify | 6 |
| A second scroll in the hall | the library | search the hall | Shinebright remembers it | 6 |
| Noke could be lured out | Noke | a very good lie, a plan, luck | Insight on him (what he wants: fame, a big contract) | 5 |

Ways the friends dig would come from `find_out.lua` as now (a rogue listens in, a wizard reads, a cleric examines),
with improvised ones carded to the DM. Our party has no druid or ranger, so Speak with Animals is only the scroll,
unless a new hero brings it.

### People

- **Teddy Bolandeere** (inn sheet): innkeeper and barman, warm, fatherly, the rumour hub. He: our pronoun list.
- **Finethir Shinebright** (p2, p3): high elf transmuter, two years a sheep; vain, fussy, lectures, good-hearted
  when it costs him little. Uses pony stats with Int 18 and Wis 14. A companion like Telpur, but nobody understands
  him until the scroll.
- **Guz** (p2, p3): half-orc, loyal to Noke, not bright, likes long words he half understands; violence first.
- **Ahmed Noke** (p4, p5): the apprentice; paranoid, guilty, ambitious, nearly broke; asks after Guz.
- **Count Behpoh Turleon** and **Sir Luenn of Nordenin** (inn sheet): travellers at the inn. Their hooks belong to
  other books (*An Enchanting Proposal*, among the inn sheet's suggestions), so here they'd be colour only.
- The inn's staff: two dozen, loyal to Teddy.

### Monsters, items, maps

- **Monsters.** Already in the game: wolf, brown bear. To add from the SRD: ape (with the book's greatsword slash,
  flees below half), pony (Shinebright), gibbering mouther. The book's own stat blocks: Guz (Reckless, a greatsword
  that hits two), Noke (a 7th-level caster; his buffs Enlarge/Reduce, Haste and Slow aren't in our spell engine yet),
  the Bed Dragon Wyrmling (Splinter Breath, vulnerable to fire, turns back into a bed if his concentration breaks).
- **Items.** The scroll (read aloud, everyone hears), a second scroll, the modified Wand of True Polymorph (its rules
  are on p6), the lab gear (about 1,000 gp), Shinebright's old robe.
- **Maps.** The inn's ground floor, upper floor and cellar (inn sheet); Noke's house (the two-page map: three
  platforms, two huts, the outhouse). Our boards are flat, so the platforms' heights (10, 20, 30 feet) are notes.

### New mechanics it needs

- A creature nobody understands until a spell or item says so (the sheep's lines held until the scroll).
- Foes whose goal is to grab and carry someone off, not kill; a chase if they get away.
- Beasts that think (they act clever, flee when hurt: the huntlings' nerve is close).
- A caster who buffs his side and runs, then comes back three rounds later as something else (the knight's frame and
  the scarabs are close).
- A breath weapon in a cone with a recharge.
- A wand with risky uses as a DM card (the roll, the misfire, the explosion).
- Money: gold, silver and copper at the inn (rooms 3 to 8 sp, meals and drinks in copper); the museum's Francs stop
  here.

### The book's own loose ends (asked, not guessed)

- The tower is "south-east of town" and "off a main road a few miles out of town"; the inn is at the junction of the
  Bogden road and the lord's road. Proposal: Bogden is the town, and the path to the house leaves the lord's road a
  few miles from the inn.
- The scroll is "Speak to Animals" in one place and "Speak with Animals" in others; Noke casts True Polymorph from
  the wand (his own top spell is Polymorph); Guz's Charisma reads 8 (+1). Small things, fixed in our data with a note.
- The museum ends on Flitwidget's hint of a murder up a mountain road, which this book doesn't pick up.

---

## Conner's calls

**Answered November 6:** a time skip (a week or two later, an afternoon off at the inn); Flitwidget's mountain-road
hint kept as an open thread for later, with rumours of Noke at the inn; the travellers as colour only; the pipeline
first, then the Sheep Chase through it.

The calls as they were asked:

1. **The stitch.** Straight after Flitwidget's thanks (they step out of the caravan onto the Bogden road at dusk, and
   the next afternoon is the inn), or a time skip (a week or two later, an afternoon off at the inn)?
2. **The museum's last hook.** Keep Flitwidget's mountain-road hint as a thread for later, or swap it for a rumour
   that leads here (a wizard's apprentice making a name for himself near Bogden)?
3. **The inn's travellers.** Colour only (table life and rumours), or leave them out?
4. **Scope of the pipeline this round.** Build the module slot, the hand-off, the ingest, the copy check and the
   checks for any module, then the Sheep Chase on top of them (recommended: it's what the longer campaign needs
   anyway), or the Sheep Chase alone in the quickest way and the pipeline after?

## Checked against what we've already written (November 6)

Before step 1, the plan was read against the Main Campaign Design doc, the roadmap page, the root-causes doc,
the longer-adventure notes, AGENTS.md, the secrets note and Conner's saved notes. What that changed:

1. **The format is the design doc's world model, not the museum's files as they are.** The design doc says the book
   becomes a world, not a script: people, places, threads, items, rumours and events, each with a few plain fields.
   Places carry their layer (hex, settlement, building, room), and threads carry their clues, a clock that ticks if
   ignored, and the ways they can end (endings are conditions on the event log). The museum's files express part of
   that: its rooms are places on the table layer, its prep board is the settlement layer in miniature, and its moments
   are pinned to places. The standard written in step 1 is the world model, with the museum mapped onto it, and every
   place sits in a region and a settlement even when the region is thin.
2. **The three map layers, each with a DM layer and a player layer** (the design doc; Conner's saved notes). The
   player layer is what's been shown (`shown.lua`) and the DM layer is what's still a secret (`secrets.lua`), so the
   secrets system is that split, already built.
3. **People come in three tiers** (the design doc's "Lines that fit"): the book's named people with lines of their own;
   locals made from a type template (the smith, the barmaid: name, job, hours, want, quirk, voice), kept once met; and
   the crowd's ambient lines. Every line carries conditions and the most specific one wins. The inn's two dozen staff are
   locals; Teddy and the travellers are named.
4. **What the roadmap and the longer-adventure notes put before any content.** The roadmap's phase 5 is "the event log
   and one shape for conditional text, then the content", gated on the truth test clean over 20 or more seeds and three
   kinds of DM. Of the notes' "build these before the content":
   - the event log is built (wave 2), but flags and marks still keep their own copies beside it;
   - the six shapes of conditional text (`text_if`, `read_if`, `line_if`, `win_if`, `lose_if`, `got_if`) are still six;
   - the museum truth test isn't yet a truth test for any adventure;
   - the museum's names aren't yet in `fiction_words.lua`, so the next story would inherit them;
   - provenance on every line is built (`tools/sim/provenance.lua`), and the adventure's own tables are filled for the
     museum.
   A new module is written to one shape from its first line, so these land in step 1, not after.
5. **The importer's contract lists more gates than exist yet.** The spoiler test, agency scan, claim scanner, book check,
   knowledge scan, secrets check, two-campaign test, movement, overlap and camera tests, state check, structure check
   and line audit. The line audit and the camera test were still to build on November 5. Step 1 says which gates exist,
   which run for any module, and which are still owed.
6. **Conner's plan to review every bug and fix first** (his saved notes): the root-causes doc did that up to the
   November 4 build. The four rounds since (the knowledge playtest, the secrets build, rounds two to four) found new
   kinds of problem that need a home in its classes and a check each, for example:
   - a data table nested inside the wrong table (the locked door's places swallowed two rooms' look-arounds);
   - a fix that shifts the dice and turns a vote lopsided (the pond's roll made the box a coin 75% of the time);
   - checks that disagree with the game about what's right (an opportunity attack counted as ignoring the DM's pick).
7. **Variety is designed in** (the design doc, "What makes each run different"): each book lists how its world can be
   seeded (which rumours are true, where someone hides), and the sims report how often each thread is followed and
   each ending reached. For the Sheep Chase: whether Teddy's rumours about Noke are fair or not, and whether Guz finds
   the party at the inn or on the road.
8. **The review desks.** Retired (Conner, November 6: "I don't need the dialogue desk anymore"). Lines are read in
   play and in the fresh-eyes playtest instead; the Dialogue Desk's tools are gone from `tools/dialogue/`.
9. **Still Conner's, from the design doc's open questions, and not needed for the Sheep Chase:** the hex size, fog of
   war by default or not, whether time moves per session or per day, exact coins or a lighter "how well off", whether
   the four friends stay the core, and theatre-of-mind for small fights. (For the Sheep Chase: exact coins at the inn,
   time in days on the road, and its two fights on table maps.)

## Part 3: what five books need from the standard (November 6)

Conner sent four more books to shape the standard (read for structure only, nothing imported): *Banners of Honour*
(Kefa Studios, 372 pages, levels 1 to 10, the model for the long campaign), *A Night of Masks and Monsters* (Ashley
Warren, 25 pages, a masquerade in a strange city), *Watchers in the Dark* (Kelsey Dionne, 18 pages, a one-session
cave crawl) and *The Mage Tower* (Jeremy Fair, 29 pages, ten floors of puzzles for any level). With the museum and the
Sheep Chase that's six shapes: a building, a short road trip, a city party, a hub-and-spoke dungeon, a tower of puzzles
and a kingdom.

### Two ways a book comes in

1. **Faithfully** (the museum, the Sheep Chase): the book's own adventure, in our words, with page references, for
   private playtesting.
2. **As a shape** (the long campaign): *Banners of Honour* is the model, but the campaign is ours. What we take is its
   skeleton: its structure, pacing, kinds of beats and kinds of systems. Its world, names, people, factions, gods, items,
   places and signature set pieces stay its own. The pipeline's second mode reads a book and writes a **shape**: the
   arc and its acts, a chapter template, an abstract beat map, the kinds of systems it runs on, and its scale. We then
   write an original campaign against the shape. An **originality check** fails any of the source's names or set pieces
   that turn up in our data. The list it checks against is built at ingest and kept with the book, outside the repo.
   Its systems are reinvented, not copied: an honour score and two loyalty tracks become our own kind of reputation
   and allegiance, a joust becomes our own contest, and building up a castle becomes our own base.

### The shape of Banners of Honour (as a model, abstracted)

- **An arc in three acts.** A fixed opening at a neutral place in crisis; an open middle where the party works three
  tracks at once (climbing one side's ladder of trust, hunting the pieces of a relic, and uncovering who is secretly
  steering each side); and an end with several branches, settled by what the party built up. The middle's order is free:
  places are suggested by level, and the book says the openness should never feel forced.
- **A chapter template**, nearly every time: a banner with the place's tension; its ruler and their private problem;
  its knights or defenders; its people and their rumours; the travel there (a hazard, a regional encounter table); the
  arrival; keyed areas (read-aloud, DM text, sub-rooms, shops, treasure, a roleplaying guide); then story events.
- **Story events with triggers**: one required event; about 45 optional ones ("use this only if"); a few timed ones;
  about ten that fire when a hero's standing crosses a threshold; some that follow an important person's path; a couple
  that run the whole campaign; and three endings.
- **Each chapter feeds the arc**: a relic piece, a step up one side's ladder, a secret about a powerful person, or a
  recurring character coming back changed by the party's earlier choice.
- **A typical chapter's rhythm**: approach through the terrain, a first look that shows the tension, a tour of the
  places that matter, the ruler's problem becoming a crisis with three or more ways through, a side intrigue with false
  leads, a reveal that ties the place to the bigger conflict, a choice with loyalty consequences, a payoff, and an
  optional knighting.
- **Scale**: about 17 major places and 30 minor ones, about 215 keyed areas, about 63 story events, about 200 named
  people (a handful major), 23 maps, 28 dice tables, 22 custom stat blocks, 8 handouts. (Conner's notes had the target
  at about 1,200 pages; this one is 372, so the first long campaign is a third of that size.)
- **No hexes and no battle maps.** One pictorial region map, settlement and building maps. The game's region and table
  layers have to be made, not imported.

### What the standard must hold (all six books together)

Beyond what the museum's files already hold:
- **The adventure:** level range, party size, what it depends on (other files, a rules reference),
  milestones (what levels the party up), and what the party keeps afterwards (a title, renown, a base).
- **Places by layer**, each with what the table sees and what the DM keeps, exits and **gates** (what lets the party
  through: an item, a status, a solved puzzle, a found secret, a check, a standing). Shops with prices and services.
- **People in three tiers**, and for the named ones: their look, a disguise and their true self, wants, secrets, what
  they know (and when they'll say it), lies with the Insight DC to catch them, a stat block or a core one with tweaks,
  an attitude that changes, where they are and when, and **paths**: a person whose later self depends on one early
  choice (an ally or a villain).
- **Factions**, with members, allegiances and votes, and a **standing** per hero per faction with its thresholds and
  what each threshold does.
- **Threads and story events**, each with its trigger (arrival, time, a standing threshold, a choice, a person's path,
  required or "only if"), and **endings** as conditions on the event log.
- **Clocks**: game time, rounds, hours, days, months; a chance per interval; a DM cue; a real-time clock (the masquerade
  ties its reveals to half an hour at the table).
- **Clues** (where, what they point to, the DC), **rumours** (true or false, who knows them, where they spread) and
  **handouts**. These sit with the secrets system as it is.
- **Puzzles** with their pieces, state, clues, solution, reset and what failing does; **items that hold state** (a
  flame's colour, a gem).
- **Hidden gear** per hero with a delayed reveal (the masks, unknown until worn), and **staged transformations**.
- **Conditions with saves every interval**, and an attitude change for every creature at once (the boss dies, its
  thralls stop).
- **Random tables.** (No versions by level band or difficulty: Conner, November 6.)
- **Minigames and campaign systems** as named rule modules beside the core rules, the way `game/rules/museum.lua` holds
  the museum's: a contest, a drinking game, a base to build and run month by month.
- **A failure branch** that moves the party (captured, gear taken) instead of ending the run.
- **Maps** with their keys linked to places. (No separate DM markings on maps: Conner, November 6. What the table
  knows stays the secrets system's job.)

### What ingest has to handle (found in these books)

Printed page numbers that differ from the PDF's (by one, by two, in every cross-reference); pages with no text layer
(Banners' appendices need OCR, and its handouts are in a script font only vision can read); text duplicated from the
facing page outside the crop; headings in small capitals that come out jumbled (found by font and size instead);
ligatures, hyphens and a font fault that turns "f" into "1"; columns and sidebars interleaved; tables flattened; map
keys, puzzle clues and even a stat block only inside images; names spelled two ways; a contents entry that's really an
advert; text and map that disagree; files the book promises but doesn't include; monsters given only as links to
outside rules. Each of these goes in the calls list for Conner, never fixed silently.

## Calls from the draft (November 6)

Marked `call = N` in `game/data/sheep/module.lua`. Each has a proposal that stands unless Conner says otherwise.

1. **Where things are.** Bogden is the town (an hour's walk from the inn), and the path to the house leaves the lord's
   road a few miles from the inn. The book only says "south-east of town" and "a few miles out" (p3, p4).
2. **The inn sheet's rooms and menus.** The rooms are in at 3, 5 and 8 sp, with our own names for them. The sheet's
   own names and its menus need the sheet again (the images weren't kept between sessions). **Done:** Conner
   re-attached it, and the inn is in from it: rooms, menu, services and wagon work, the three floors, Teddy, the
   staff, the two nobles, and Sir Luenn's hook for another book carried as an open thread.
8. **The inn sheet's suggested encounters** (*The Blue Ocean*, *Traveling Apothecary*) belong to other products.
   Proposal: leave them out of the Sheep Chase; the creation tool could take one in later as its own short thread.
3. **Guz's Charisma.** The block gives 8 with a +1 modifier (p2); 8 is −1. Proposal: 8 (−1).
4. **A fourth ending** of our own: Guz takes the sheep home and nobody follows. **Conner: keep it, as the failure**
   (and Noke, free with the wand, is a thread left open).
5. **Noke's other guards** (p3: they'll find him eventually) as a clock. **Conner: three days.**
6. **How long the scroll lasts.** Speak with Animals is ten minutes; the book has a second scroll for talking to him
   later (p6), so it wears off. **Conner: the inn scene and the walk to the woods, then a sheep again.**
7. **Noke's buffs.** Enlarge/Reduce (his main move), Haste and Slow aren't in our spells yet. Proposal: add
   Enlarge/Reduce and Haste in step 5, Slow later.

The reader's issues for this book were three run-together words read as two spellings (no calls), and "Speak to
Animals" on p3 against "Speak with" everywhere else (ours says "with").

## The plan, once the calls are in

0. **The review** (Conner's plan): the problems found since November 4 go into the root-causes doc's classes, each with
   its check, so the import is written against them. **Done** (classes 11 and 12, and the table "Since November 4").
1. **The standard, and the museum inside it**, with no new content:
   - the world model written up as the module standard (people in three tiers, places by layer, threads, items,
     rumours, events, secrets with their ways out, masks, what's shown, line banks with conditions, the fidelity sheet,
     maps), and the museum's data mapped onto it;
   - one shape for conditional text; flags and marks read from the event log; the truth test for any adventure; the
     museum's names in `fiction_words.lua`;
   - the module slot: the museum moves in, museum-only rules stay the museum's, shared code asks the module;
   - the checks made module-agnostic, and the gates listed as there or owed;
   - the standard checked against all six books (Part 3): every record kind they need is in it, even where the engine
     doesn't play it yet, so nothing has to be reshaped when the long campaign comes.
   Done when every museum test passes unchanged and the truth test is clean on 20 seeds and three kinds of DM.
   **Done** (November 6): the full gate green, and the truth test clean on 60 prologues. See
   `docs/design/adventure-standard.md`.
2. Ingest, the copy check, the originality check and the calls list, run on the museum's PDF first and then on the
   other five, so every pitfall in Part 3 is caught. **Built** (November 6): `tools/import/ingest.py` read all six
   (Banners of Honour's 372 pages in 12 minutes, 72 of them by OCR), and its `issues.txt` and `names.txt` are the
   calls list's first draft. `tools/import/copy_check.py` is the copy check (the museum's data, read against its own
   PDF, had five lines that followed the book too closely; rewritten) and the originality check (the game's own
   words and the other books' count as ordinary words; `--allow` for an English word the book also uses as a name).
3. The hand-off from the museum. **Built** (November 6), for any adventure to any other, not just the museum:
   `adventure.handoff` and `adventure.use`; the standard's "Adventures tied together"; `tools/tests/handoff_check.lua`.
4. The Sheep Chase drafted through the pipeline, with its calls list; Conner's calls on what comes up. **Drafted**
   (November 6): `game/data/sheep/` (the module in the standard's records, ten secrets, the fidelity sheet), clean on
   the shape, secrets (data alone) and copy checks. It plays on its own with a fresh party, or after any adventure.
   The calls are below.
5. Its monsters, mechanics and maps, a thin region (the inn's hex, the road, the woods), then its lines and table life,
   read in play. The game night's flow generalized from the museum's to any adventure's ("Before the museum can go"
   in the standard).
6. Sims (with the variety report), a fresh-eyes playtest against the PDF, fixes, the gate, the engine run, a build.

After it ships, step 4's procedure is written up as a skill, so the next book follows the same steps.
