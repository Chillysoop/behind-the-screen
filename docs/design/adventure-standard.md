# The adventure standard

What every adventure in the game is made of, whatever book it came from. November 6, 2026 (step 1 of
`2026-11-06-adventure-import.md`). It's the Main Campaign Design doc's world model
(https://claude.ai/artifact/UjVzYSuuqJmGo2FDs4UmSw) written as records and fields, checked against six books: the
museum (M), *The Wild Sheep Chase* at the Bogden Road inn (S), *Banners of Honour* as the long campaign's model (B),
*A Night of Masks and Monsters* (N), *Watchers in the Dark* (W) and *The Mage Tower* (T).

## The principles it keeps

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
| `follows` | Which adventures it can follow, and what carries over (`handoff`) | S, B | owed |
| `milestones` | What levels the party up (an item found, a title, a foe beaten) | B | data |
| `keeps` | What the party keeps afterwards: a title, renown, a base, a debt owed | S, N, T, B | data |
| `depends` | Other files the book relies on (mask cards, a lore supplement), and outside rules | N, W | data |
| `heroes`, `hooks`, `all_in` | The heroes' reasons for coming, and what each player adds | all | plays |
| `session_zero`, `content`, `prep_notes` | Its Session Zero, content tags by place, real prep for each place | all | plays |

### Places, by layer

| Field | Holds | Books | Status |
| --- | --- | --- | --- |
| `id`, `name`, `layer` | `region`, `site` (a settlement or a lone building), `area` (a room or keyed area) | all | owed (layer) |
| `in` | The place it sits in: an area in a site, a site in a region | all | owed |
| `read` | What the table sees on arrival: place, terrain, who's there, their quirks and tells | all | plays |
| `board`, `spots` | Its battle map and the places on it, named as the heroes see them | M, S, N, W, T | plays |
| `exits`, `gates` | Where it leads, and what lets them through: an item, a status, a solved puzzle, a found secret, a check, a standing | all | plays (as `links`, locks) |
| `travel` | For a region: routes between sites, days, the road's hazards and its encounter table | S, B, W | owed |
| `shops` | Prices, services, rooms for the night | S, B | data |
| `curios`, `explore` | What's there to poke at and what a friend says about it | M | plays |
| `pages` | The book's pages for it | all | plays |

### People

| Field | Holds | Books | Status |
| --- | --- | --- | --- |
| `tier` | `named`, `local` (from a type template: name, job, hours, want, quirk, voice), `crowd` | all | owed (tiers) |
| `look`, `pronoun`, `voice` | What the table sees and hears | all | plays |
| `disguise`, `true` | Who they seem to be and who they are (a secret with its ways out) | N, B, S | plays (as a secret) |
| `wants`, `secrets`, `knows` | What they want, keep and know, and when they'll say it | all | plays |
| `lies` | What they'll lie about, and the Insight DC to catch it | N, B | owed |
| `stats` | A core stat block by name with tweaks, or the book's own | all | plays |
| `attitude`, `memory` | What they think of each hero and the party, read from the log | all | plays |
| `where` | Where they are, and when (a schedule for those who move) | B, N | owed |
| `paths` | A later self that depends on an early choice (an ally or a villain), each with its stats and lines | B | owed |
| `lines` | Their lines by situation, with conditions, most specific first | all | plays |
| `companion` | Comes along with the party (Telpur, the sheep) | M, S | plays |

### Factions and standing

| Field | Holds | Books | Status |
| --- | --- | --- | --- |
| `factions` | Name, members, what they want, who they side with | B, N, W | data (`sides`) |
| `standing` | A score per hero per faction, its thresholds and what each does (trusted, knighted, outlawed) | B | owed |
| `votes` | Who holds a say in an outcome, and how they lean | B | owed |

### Threads, story events and endings

| Field | Holds | Books | Status |
| --- | --- | --- | --- |
| `threads` | A hook: who's behind it, the clues in, a clock if ignored, the ways it ends | S, B, N, W | owed |
| `events` | A story event with its trigger: on arrival, in time, at a standing, on a choice, on someone's path; `required` or `only_if` | all | plays (as moments) |
| `moments` | A call to the DM in a place, with options the friends propose in their own words | all | plays |
| `endings` | Each ending as a condition on the event log | all | plays (museum's) |
| `failure` | What a loss does instead of ending the run (captured, gear taken) | W, M | plays (museum's) |

### Clocks

| Field | Holds | Books | Status |
| --- | --- | --- | --- |
| `clocks` | Counts in rounds, hours, days, months or real table minutes; a chance per interval; a DM cue; what fires | N, W, T, B | owed |

### What the table knows

| Field | Holds | Books | Status |
| --- | --- | --- | --- |
| `secrets` | Every DM-only fact: holder, page, hint and tell, the book's reveal and two ways out or more | all | plays |
| `told` | What the table calls a secret name before it's told | all | plays |
| `clues` | Where a clue is, what it points to, the DC | all | plays (as secret paths) |
| `rumours` | A claim, true or false, who knows it, where it spreads | S, B | owed |
| `handouts` | An in-world document, by when it's handed over | N, B | owed |
| `glossary` | The adventure's own words, explained on hover | all | plays |

### Things

| Field | Holds | Books | Status |
| --- | --- | --- | --- |
| `items` | What it is, who holds it, what it does in rules terms, what it opens or proves | all | plays |
| `items[].state` | What it holds that can change (a flame's colour, charges, cracked or whole) | T, S | owed |
| `items[].hidden` | A power unknown until worn or attuned | N | owed |
| `magic_items` | The adventure's own magic items | all | plays |
| `puzzles` | Pieces, state, clues, the solution, reset, what failing does | T, B | owed |
| `conditions` | A save every interval, stages, a cure (an infection, a slow transformation) | W, N | owed |
| `creatures` | Monsters: core by name, the book's own blocks as numbers, tactics, their special rules | all | plays |
| `tables` | Random tables (encounters, guests, fortunes) | B, N | owed |

### Rule modules

Minigames and campaign systems as named modules beside the core rules: the museum's monster rules, a contest (the
joust), a drinking game, a base to build and run month by month. A module declares what state it keeps and what it
writes to the log. (M plays; B, N, T owed.)

### The table's own words

The friends' and the table's lines for this adventure, all with conditions: `table_life`, `chat`, `chat_ask`,
`chat_banter`, `chat_intro`, `chat_news`, `talk`, `npc_lines`, `memory`, `recap`, `recap_beats`, `beats`, `openings`,
`want_more`, `keepsakes`, `friction`, `pocketables`, `ruling_costs`, `asides`, `thoughts`, `answer_like`. All play
today.

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

## What step 1 builds from this

1. The module slot: `game/data/adventures.lua`, the museum registered in it, and everything that reads the adventure
   asking the current one.
2. The schema validator (root-causes class 11): every table above with its fields and types, unknown fields an error,
   run first in every gate, on the museum first.
3. One shape for conditional text, with the museum's six old shapes read through it until they're rewritten.
4. Flags and marks read from the event log.
5. The truth, secrets, knowledge and book checks for any registered adventure.

The fields marked **owed** come in as the first book that needs them does: the Sheep Chase brings `layer`, `in`,
`travel`, `shops`, `tier`, `follows`, `rumours`, `items[].state` and `clocks`; the long campaign brings the rest.
