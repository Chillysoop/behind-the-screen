# The adventure standard

What every adventure in the game is made of, whatever book it came from. November 6, 2026 (step 1 of
`2026-11-06-adventure-import.md`). It's the Main Campaign Design doc's world model
(https://claude.ai/artifact/UjVzYSuuqJmGo2FDs4UmSw) written as records and fields, checked against six books: the
museum (M), *The Wild Sheep Chase* at the Bogden Road inn (S), *Banners of Honour* as the long campaign's model (B),
*A Night of Masks and Monsters* (N), *Watchers in the Dark* (W) and *The Mage Tower* (T).

## The principles it keeps

- **Any adventure, and one a DM writes.** The museum was the prototype (Conner, November 6) and may be deleted; the
  Sheep Chase is the first book after it, and the end goal is an adventure creation tool in the game. So every record
  here is plain data a DM could fill in by hand, shared code never names one adventure's rooms or people, and what
  only one adventure needs is its rule module. Nothing shared may need the museum.
- **A world, not a script.** People, places, threads, items and rumours, and scenes are what happens when the friends
  meet them. Rooms in order are just one shape a world can take.
- **One record of what happened.** Every action writes to the event log (`game/model/events.lua`), and every line,
  flag, mark, ending and memory reads from it.
- **Three map layers** (region, settlement, table), all views of one world. What the players know of each is the
  secrets system's job (`shown.lua` for what's been described, `secrets.lua` for what's kept), not marks on a map.
- **Three tiers of people:** the book's named people, locals from a type template, and the crowd.
- **One shape for conditional text:** `say = { { when = {...}, text }, ..., text }`, most specific first, a plain line
  last. Every line that asserts an outcome has a `when` or reads the log.
- **Our words, the book's pages.** Every fact from a book carries its page. Nothing is copied. A book can come in
  faithfully or as a shape for an original campaign (the import doc, Part 3).
- **Not in the standard** (Conner, November 6): DM markings on maps, and versions by level band or difficulty.

## Where an adventure lives

`game/data/<id>/`, registered in `game/data/adventures.lua` (id, title, the file that loads it, what it can follow).
Its battle maps are specs in `game/data/maps/<id>_*.map`. Rules only it needs go in `game/rules/<id>.lua` (as
`game/rules/museum.lua` holds Euryale's hood). Everything else is shared, and asks the current adventure first.

## The records

Status: **plays** (the engine runs it today), **data** (the standard holds it, the engine doesn't play it yet),
**owed** (not in the standard's code yet). Books: which of the six need it.

### The adventure

| Field | Holds | Books | Status |
| --- | --- | --- | --- |
| `id`, `title`, `author`, `credit` | Who made it, how it's credited | all | plays |
| `pitch`, `premise` | What the table is told at Session Zero; what the DM knows that they don't | all | plays |
| `levels`, `party` | Level range and party size it's written for | all | data |
| `follows`, `handoff` | Which adventures it can follow (`any = true`: any, or none), the time skip and the opening line | S, B | plays (`adventure.handoff`) |
| `milestones` | What levels the party up (an item found, a title, a foe beaten) | B | data |
| `keeps` | What the party keeps afterwards: a title, renown, a base, a debt owed, each with its `when` | S, N, T, B | data |
| `depends` | Other files the book relies on (mask cards, a lore supplement), and outside rules | N, W | data |
| `heroes`, `hooks`, `all_in` | The heroes' reasons for coming, and what each player adds | all | plays |
| `session_zero`, `content`, `prep_notes` | Its Session Zero, content tags by place, real prep for each place | all | plays |

### Places, by layer

| Field | Holds | Books | Status |
| --- | --- | --- | --- |
| `id`, `name`, `layer` | `region`, `site` (a settlement or a lone building), `area` (a room or keyed area), in `M.places` | all | data |
| `in` | The place it sits in: an area in a site, a site in a region | all | data |
| `read` | What the table sees on arrival: place, terrain, who's there, their quirks and tells | all | plays |
| `board`, `spots` | Its battle map and the places on it, named as the heroes see them | M, S, N, W, T | plays |
| `exits`, `gates` | Where it leads, and what lets them through: an item, a status, a solved puzzle, a found secret, a check, a standing | all | plays (as `links`, locks) |
| `travel` | For a region: routes between sites (`from`, `to`, `by`, `time`), the road's hazards and its encounter table | S, B, W | data |
| `shops`, `work` | Prices, services, rooms for the night; paid work to be had there | S, B | data |
| `lore` | Its history, for whoever asks | all | data |
| `curios`, `explore` | What's there to poke at and what a friend says about it | M | plays |
| `pages` | The book's pages for it | all | plays |

### Scenes: how a place plays at the table

A place the party plays through on game night has a `scene` (step 5, November 6). `game/model/standard.lua` compiles
the adventure as written into game night's form on load (`standard.compile`): each place with a scene becomes a room
with its cards (`<adventure>_<place>_place`, `_cast`, `_goal`, `_snag`, `_prize`), in the order the places are listed;
a scene's way on is its exits to a later scene, else the next one listed. The adventure as written is never changed.

| Field | Holds | Status |
| --- | --- | --- |
| `type`, `sum`, `setting` | `social`, `combat`, `exploration`, `puzzle` or `downtime`; one line for the prep board; indoor, outdoor, wild | plays |
| `goal` | `name`, `line`, `win`, `lose`, `got`, and `win_if` / `lose_if` in the one conditional shape | plays |
| `cast` | The person met there (an id in `people`), or none | plays |
| `foes`, `boss_name`, `foes_name`, `foes_short`, `foes_line` | Creature ids from `creatures` (the first is the boss), and what the table calls them | plays |
| `optional_fight`, `quick`, `stop`, `rest` | A fight only if it comes to it; a short scene; a place the night can end; a place to sleep | plays |
| `seen`, `wake`, `wakes` | A foe that looks like part of the room (`seen = false`), its line as it gets up, and the board piece it was (`wakes = { feature, at = { creature = { x, y } } }`) | plays |
| `snag`, `prize` | A complication and a reward card | plays |
| `board` | Its board's id (default `<adventure>_<place>`: `game/data/maps/sheep_*.map`) | plays |
| `digs` | How many times the friends can dig for a secret there (default one) | plays |
| `clears` | What wears off once the party leaves: `flags` cleared, and the `line` the DM says (the Sheep Chase's scroll, after the woods path) | plays |
| `hurry_on` | The next scene follows straight on: no break, rest or wrap-up card between (Noke up the slope to his bed) | plays |
| `goal.lose_sets`, `goal.line_if` | A flag losing here sets (the guards take the sheep), and the goal's words as things stand (no wand before he's explained) | plays |
| `on` (the place) | A place you're on, not in, for the recap: a path, a platform | plays |
| `leaves` | The scenes walking in here leaves behind for good, if they haven't been played: once they're on the road, the Sheep Chase's upstairs and cellar (`adventure.enter_room` skips them) | plays |

Story events with `at` and `when_in` (`arrive`, `start`, `mid`, `end`, `leave`) are its moments, in that order (`arrive`:
as they walk in, before anyone looks round; `leave`: as they go, after the room's small moments): `title`, `text`, `actor`
(the kinds of player who lead it), `party` (the table settles it), `options` (game night's choice record: `label`,
`want`, `short`, `lean`, `roll`, `log`, `mus`, `tells`, `effects`), `only_if`, `tells` (what it tells, whichever way it
goes), `risks` (whose risk it is, when not theirs). An event that fires on a fight is said as that place's fight
starts (`on_fight`); its `sets` are set then. An event with no options is said and played on, and its `sets` are set
as it plays (the cellar's heap is theirs once the rats are gone). A creature's
`flees_below` (a share of its Hit Points) and `flee_line` make it run (the rules engine, any adventure); with
`escapes` it gets away instead of dropping when a blow would finish it. A `rider` on a creature acts from its back each
turn (Noke's Ray of Frost from the bed dragon). An option's roll with `best` goes to whoever at the table is best at it,
and with `casters` only to a spellcaster (the wand). A story event with no choice is said aloud as it plays. The
adventure's own `slide` (the night's first slide), `story_start` (the prep board before anything's happened),
`currency` (money of its own, like the museum's Francs) and `read_up` (what the break's research covers) are its words
on shared screens; without them the screens say something neutral.

### People

| Field | Holds | Books | Status |
| --- | --- | --- | --- |
| `tier` | `named`, `local` (from a `template`: jobs, want, quirk), `crowd` | all | data |
| `look`, `pronoun`, `voice` | What the table sees and hears | all | plays |
| `disguise`, `true` | Who they seem to be and who they are (a secret with its ways out) | N, B, S | plays (as a secret) |
| `wants`, `secrets`, `knows` | What they want, keep and know, and when they'll say it | all | plays |
| `lies` | What they'll lie about, and the Insight DC to catch it | N, B | owed |
| `stats` | A core stat block by name with tweaks, or the book's own | all | plays |
| `attitude`, `memory` | What they think of each hero and the party, read from the log | all | plays |
| `where` | Where they are, and when (a schedule for those who move) | B, N | data (places only) |
| `paths` | A later self that depends on an early choice (an ally or a villain), each with its stats and lines | B | owed |
| `lines` | Their lines by situation, with conditions, most specific first | all | plays |
| `companion` | Comes along with the party (Telpur, the sheep) | M, S | plays |
| `understood` | What it takes to understand them (the sheep: the scroll, or Speak with Animals); their ways out wait `when = { flag = "understood" }` | S | data |

### Factions and standing

| Field | Holds | Books | Status |
| --- | --- | --- | --- |
| `factions` | Name, members, what they want, who they side with | B, N, W | data (`sides`) |
| `standing` | A score per hero per faction, its thresholds and what each does (trusted, knighted, outlawed) | B | owed |
| `votes` | Who holds a say in an outcome, and how they lean | B | owed |

### Threads, story events and endings

| Field | Holds | Books | Status |
| --- | --- | --- | --- |
| `threads` | A hook: who's behind it, the clues in, a clock if ignored, the ways it ends; `open_at_end` and `tags` for one a later adventure picks up | S, B, N, W | data (open ones carried by the hand-off) |
| `events` | A story event with its trigger (`on` = arrive, after, choice, fight, round, clock), `required` or `only_if`, the flags it `sets` | all | data (the museum's play as moments) |
| `moments` | A call to the DM in a place, with options the friends propose in their own words | all | plays |
| `endings` | Each ending as a condition on the event log (`when`) | all | plays (museum's); data (`when`) |
| `failure` | What a loss does instead of ending the run (captured, gear taken) | W, M | plays (museum's) |

### Clocks

| Field | Holds | Books | Status |
| --- | --- | --- | --- |
| `clocks` | Counts in rounds, hours, days, months or real table minutes; a chance per interval; a DM cue; what fires; `sets` (a flag, then the endings are checked) and `when` (only while it holds) | N, W, T, B | plays (days and sessions: `adventure.run_clocks`, the prep board lists them); data (the rest) |

### What the table knows

| Field | Holds | Books | Status |
| --- | --- | --- | --- |
| `secrets` | Every DM-only fact: holder, page (or `ours`, for one the game adds), hint and tell, the book's reveal and two ways out or more | all | plays |
| `told` | What the table calls a secret name before it's told | all | plays |
| `clues` | Where a clue is, what it points to, the DC | all | plays (as secret paths) |
| `rumours` | A claim, `truth` (true, false, half), who knows it, where; `only_if` (a thread carried in) | S, B | data |
| `handouts` | An in-world document, by when it's handed over | N, B | owed |
| `glossary` | The adventure's own words, explained on hover | all | plays |
| `lore_tips` | Something true the DM can tell when a friend pokes about: `room`, `hints` (a secret: a tip given counts as its hint), `when`, `moot` (no use once it holds), `text`, `page` (`game/model/lore_tips.lua`) | all | plays |

### Things

| Field | Holds | Books | Status |
| --- | --- | --- | --- |
| `items` | What it is, who holds it, what it does in rules terms, what it opens or proves; a carried one handed over by a flag (`carry`, `when`), and `as` for the shared thing it really is (Teddy's dusty bottle is a healing potion) | all | plays |
| `items[].state` | What it holds that can change (a flame's colour, charges, cracked or whole) | T, S | data |
| `items[].hidden` | What's unknown until found out: the secrets about it | N, S | data |
| `magic_items` | The adventure's own magic items | all | plays |
| `puzzles` | Pieces, state, clues, the solution, reset, what failing does | T, B | owed |
| `conditions` | A save every interval, stages, a cure (an infection, a slow transformation) | W, N | owed |
| `creatures` | Monsters: core by name with tweaks, the book's own blocks as numbers, tactics, their special rules, in the adventure's `M.creatures` | all | plays (shared roster); data (`M.creatures`) |
| `tables` | Random tables (encounters, guests, fortunes) | B, N | owed |

### Rule modules

Minigames and campaign systems as named modules beside the core rules: the museum's monster rules, a contest (the
joust), a drinking game, a base to build and run month by month. A module declares what state it keeps and what it
writes to the log. (M plays; B, N, T owed.) A creature names its own turn with `rules_turn`; the compile gives its
stat block `rules = <adventure>`, and `game/rules/ai.lua` hands the turn to that adventure's module first
(`game/rules/sheep.lua`: the bed dragon's Splinter Breath, Noke's Thunderwave).

### The table's own words

The friends' and the table's lines for this adventure, all with conditions: `table_life`, `chat`, `chat_ask`,
`chat_banter`, `chat_intro`, `chat_news`, `talk`, `npc_lines`, `memory`, `recap`, `recap_beats`, `beats`, `openings`,
`want_more`, `keepsakes`, `friction`, `pocketables`, `ruling_costs`, `asides`, `thoughts`, `answer_like`. All play
today.

### Endings, rumours and the rest of the table's words

Any adventure without a last scene of its own (`showdown`) plays its ending as the night reaches it: the ending's
`line`, the `keeps` that hold, `xp`, and a word from each friend by the ending's `tone` (good, bad, mixed); nothing small
comes up after it. `rumours` are told by their `who` the first time the party is where they belong (`where`: the place
or the building it's `in`), two a place, and one that picks up a carried thread comes first. A person's `understood`
names the `flag` that lets the table talk with them. `beats` holds a choice's words for the recap, `did` and `ok` per
option. `escapes_return` (the museum's) lets the way-out card offer a foe's escape, since there they come back;
`first_night_rewards` lets one small-moment reward come up on the gentle first night. A companion with `travels`
comes along into the next adventure, with words that fit anywhere.

### The DM's bag and lore tips (every adventure)

Conner, November 6. When a friend pokes at something in a small moment (`table_life`'s curios), the DM can make it
worth a look: as it lands, something real, one of the adventure's `lore_tips` for that place, or a thing tucked there
from the DM's bag. The bag (`game/data/dm_bag.lua`, `game/model/dm_bag.lua`) is the campaign's, not the adventure's:
thirty things from bits and bobs to legendary armour, each given once. Some are in it from the start; the rest are in
four books read in order, an hour of prep each, between sessions. Prep can also put a thing from the bag in someone's
pockets on their sheet, and it comes back to the bag if it's taken off them. At most two rewards a night, and the
card doesn't count as one of the night's decisions. The notes have a "Your bag" tab and a "Lore tips" tab.

Everything in the bag works (Conner, November 6: "make sure the items / weapons have mechanical benefits and work
correctly when used by friends"). A bit gives +1 to one kind of check on game night (`helps`); a potion is drunk in a
fight; a magic item works on the hero's sheet (`game/model/items.lua`, `apply`). A hero uses one weapon, one armour and
one shield (`slot`), the best they have: a +N Weapon is their main weapon, armour goes to someone who wears it, a shield
to someone who carries one (from their sheet, so not Brannoc's greatsword). Anyone can use the Wand of Magic Missiles:
the friends point it at a foe the darts are sure to finish, or one they can't reach. `tools/tests/dm_bag_check.lua`
checks all thirty on whoever gets them, and the friends using them in fights.

## The museum, mapped onto it

| Standard | The museum's tables today |
| --- | --- |
| The adventure | `id`, `title`, `author`, `credit`, `pitch`, `premise`, `heroes`, `hooks`, `all_in`, `session_zero`, `content`, `content_names`, `prep_notes`, `want_more`, `want_more_sad`, `epilogue` |
| Places | `start`, `rooms`, `order`, `links`, `no_return`, `forks`, `fork_at`, `pull`, `revisit_why`, `second_look`, `left_behind`, `explore`, `explore_say`, `behind_doors`, `openings`, `openings_from` |
| People | `people`, `npc_sheet`, `npc_lines`, `memory`, `talk`, `after_talk`, `companions`, `table_life` (companions), `ally_join`, `ally_lines`, `foe_names`, `foe_pronouns`, `lead_order`, `portraits`, `portrait_default`, `mech_names`, `names_heard` |
| Factions | `sides` |
| Events, moments, endings | `moments`, `beats`, `showdown`, `endings`, `extras_lost`, `loose_ends`, `marks`, `mark_order`, `knobs`, `reinforcements`, `favors`, `requests` |
| What the table knows | `secrets`, `told`, `glossary`, `names_heard` |
| Things | `items`, `magic_items`, `base` |
| The table's words | `recap`, `recap_beats`, `chat`, `chat_ask`, `chat_banter`, `chat_intro`, `chat_news`, `asides`, `thoughts`, `answer_like`, `keepsakes`, `friction`, `pocketables`, `ruling_costs`, `broke_words`, `outs` |
| Museum only | Francs, the Mech's names, Euryale's card (`npc_sheet`, `marks`), the boss night (`showdown`), the Lecturer's report: they stay the museum's and move to its rule module as the slot is built |

## The gates, there and owed

From the importer's contract (`2026-11-05-root-causes.md`), for any adventure in `game/data/adventures.lua`
(`ADVENTURE=<id>`):

| Gate | Check | Status |
| --- | --- | --- |
| Shape of the data (class 11) | `schema_check` | there |
| Spoilers, agency, claims (classes 1 to 3) | `conner_nov4b_check`'s general scans | museum only |
| Book fidelity (class 4) | `book_check` against the adventure's fidelity sheet | any adventure |
| Knowledge and the two-campaign test (class 5) | `knowledge_check` | any adventure |
| Secrets: real ways out, lines that wait, every secret found, nothing early | `secrets_check` (`0` runs: the data alone) | any adventure |
| Truth, and flags held to the event log | `museum_truth` | any adventure |
| Movement, faces, structure (classes 6, 8, 9) | `conner_nov4b_check` | museum only |
| Overlap (class 7) | `overlap_check` | there |
| Camera (class 7) | | owed |
| Line audit (class 10) | | owed |
| Copy and originality | `copy_check.py` | there |
| The hand-off: the past, lore, open threads, a fresh start | `handoff_check` | there |
| Fresh-eyes review of whole runs | a reviewer who hasn't read the code | every round |

## What step 1 builds from this

1. The module slot: `game/data/adventures.lua`, the museum registered in it, and everything that reads the adventure
   asking the current one. **Built.**
2. The schema validator (root-causes class 11): every table above with its fields and types, unknown fields an error,
   run first in every gate, on the museum first. **Built** (`schema_check`, `game/data/adventure_schema.lua`).
3. One shape for conditional text (`adventure.say`, `adventure.text`), with the museum's nine older shapes read
   through it until they're rewritten. **Built.**
4. Flags and marks in the event log: marks were already events; every flag set is now an event too
   (`adventure.watch_flags`), and the truth test fails a flag with no event. **Built.**
5. The truth, secrets, knowledge and book checks for any registered adventure.

The fields marked **owed** come in as the first book that needs them does. The Sheep Chase brought `layer`, `in`,
`travel`, `shops`, `tier`, `follows`, `rumours`, `items[].state` and `clocks` (November 6, `game/data/sheep/`); the
long campaign brings the rest.

## Adventures tied together

Conner, November 6: "if i upload a 1-3 level adventure, and a separate 4-5 level adventure, those can be connected
together, preserving items, lore, NPCs, history, so future plot hooks can connect together." `adventure.handoff(
campaign, to)` does it for any two:

- **The party:** heroes, levels, what they carry and their scars are the campaign's and don't change. If the next
  adventure starts higher, `campaign.level_due` holds the level it needs, played at its start.
- **History:** the event log goes on. Each flag event says whose adventure it was.
- **The past:** the finished adventure's state (`campaign.past[id]`: its flags, money, what was shown, how it ended).
- **Lore:** what the table learned, as `campaign.lore["<adventure>:<secret>"]`.
- **People:** they remember the party from the log. A later adventure that brings someone back uses their id.
- **Threads:** an adventure's `threads` with `open_at_end` (and a `when` that holds) go on in `campaign.threads`. A
  later adventure picks one up by id or tag with the condition `thread = ...` (the Sheep Chase's rumour of the
  mountains picks up the museum's `mountain_road`). The DM tying any open thread to any hook by hand is owed with the
  creation tool.
- Conditions on what came before: `past = <adventure>`, `thread = <id or tag>`, `knew = "<adventure>:<secret>"`.
- **At the table:** when an adventure ends and the registry has a next one (`adventure.next_up`), the journey screen
  has "Carry on into ...": the hand-off, levels caught up (`progression.catch_up`), then the next adventure's hooks
  page and its first session. That night opens with the hand-off's own words (`adventure.opening_line`) and no
  introductions. The shared content each adventure speaks in is put back as it was before the next one's words go on
  (`adventure.shared_reset`), so nothing of the museum's wording follows the party out.

Owed: a person's memory record (`people_memory`) is the adventure's, so a returning person needs it in the new one
too; money that's only good in one adventure (the museum's Francs) turning into something at the seam.

## Step 5: the Sheep Chase plays

Done November 6: the standard compiles to game night's form (above), and game night, the week and the ties editor
read the current adventure (`MODULE` is a live view of `adventure.data`), so anything the museum alone needed is
guarded or is the museum's data now (its currency, its villain's card, its Francs). The title screen picks which
adventure a new game plays, and a save records its adventure (`A=` in the header) and switches to it before it loads.
The Sheep Chase's six scenes play on their own boards, drawn after the inn sheet's first floor and Noke's Tower map
(the book's two pages side by side). Its checks: `ADVENTURE=sheep` with the sims, the UI smoke (the museum's own
rooms and people skipped), the agency check and the schema; the secrets check with whole nights still finds the lure
too rarely.

## Before the museum can go

The museum was the prototype and may be deleted (Conner, November 6). What still needs it, for step 5:

- The game night's flow is the museum's: `museum_night.lua`, `museum_week.lua` and `ties.lua` read the module once
  when they load, and the prep board, the journey and parts of the night view, fight and report name it. They become
  the adventure's night, reading the standard's places, events and moments.
- The museum's own monsters sit in the shared roster (`game/rules/data/monsters.lua`, `source = M.MUSEUM`). An
  adventure's creatures belong in its `M.creatures`.
- The default adventure (`game/data/adventures.lua`) and the tests that play prologues (`tools/sim/museum.lua`, the
  smoke runs, the gate) are the museum's.
- What's left after that is data: deleting `game/data/museum/`, its maps and its registry entry.
