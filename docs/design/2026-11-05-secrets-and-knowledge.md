# Secrets and what the table knows

How secret information and the DM's knowledge against the players' knowledge work today, what's missing for the longer
campaign, and what to build. Written after the knowledge playtest (`docs/design/2026-11-05-knowledge-playtest.md`)
and its fixes.

**Built on November 6 (c-fix), to Conner's calls** (the end of this note): `game/model/secrets.lua` (the record, the
table's and each hero's knowledge, the ways out with the defaults by kind, plants, holds, the DM's asks),
`game/data/museum/secrets.lua` (the museum's eighteen, with pages), `game/data/find_out.lua` and `ideas.lua`'s find
(the friends dig), the person sheet's WHAT THEY KNOW and the prep board's secrets, planted items that stay secret
until handed over, `game/model/shown.lua` (what's been shown in a room, described before it's named), and
`tools/tests/secrets_check.lua` (DATA, LINT, REACH, EARLY from the data). The museum's old flags (`truth`, the bird's
name) are now what a secret unlocks. Still to come: retiring the knowledge check's museum-written hand lists in favour
of the secret data, and items a hero has but hasn't identified.

## The short answer

**We are not set up correctly yet for a big upload.** The museum now keeps its secrets, but it does so with a dozen
separate pieces, each covering part of the problem and each written by hand for this one book. Four things are
missing:

1. **No single record of a secret.** One secret today lives in five places: the book sheet, the "told" registry,
   a handful of flags, a cast card's `secret` string, and a condition on every line that mentions it. Miss one of
   them and it leaks. Every leak the playtest found came from this.
2. **Few ways to find things out, all hand-written.** Most secrets have one route in, usually one card with one
   roll. If the card doesn't come up, or the roll misses, the table can't learn the secret until the end. No
   spells, no bardic performance, no trades. The friends' own ideas can't aim at a secret.
3. **The DM can't see or steer secrets.** The person sheet shows stats and pockets, but not what that person knows
   or hides, and there's no "reveal it now" or "drop a hint".
4. **The checks are museum-shaped.** They catch leaks after the fact, from word lists written for this book. Nothing
   checks that each secret can actually be found, or found by more than one kind of hero.

**What to build:** one new system, a Secrets record with reveal paths. We'd extend the parts that already work
(who hears what, the told registry, people's memories, the friends' ideas, the person sheet, its planted items).
Then the checks would be re-based on that data, so an imported campaign gets them for free. The rest of this note
gives the detail.

## How it works today

| Piece | What it does | Where | Its limit |
| --- | --- | --- | --- |
| Who hears a line | Each line has an audience: said to the table, behind your screen, your own unspoken doing, the cut upstairs | `voice.lua`, line styles | Works. Says who hears a *line*, not what's *secret*. |
| What the table has been told | The names and secrets the table has heard. Lines naming one not yet told are held back or reworded ("the hooded woman" until Euryale is named). A choice or roll can `tells` it | `told.lua`, `MODULE.told` (new today) | Table-wide only. Records words heard, not facts learned. No hints, no "learned by whom, how". Masks are a safety net, not a design. |
| Older knowledge flags | `truth` (the confession), `witness_named`, `sunken_city`, `bird_named`, `tapestry` | `museum_night.heard`, `MODULE.names_heard` | One-off flags. Lines test them by hand. |
| Hidden foes | A foe that looks like part of the room says nothing until it moves (`seen = false`, `dormant`, `visible`, `wake`) | cast cards, room `wake` | Works for monsters. Not for secrets that aren't monsters. |
| Reveal moments | Cards with a roll: Persuasion on Flitwidget, History on the tablet, Nature on the bird, Insight against the whisper, Survival on the tracks. Plus the small moments' dull / detail / lore answers, and the people's answer / better answer to a question | `MODULE.moments`, `table_life.lua` | One route per secret, mostly. Written per card. |
| Scenes on your cards | A card's `see` line is said to the table before you decide (new today) | moments' `see` | Each card has to remember it. |
| What the museum's people know about the party | Deeds they saw or were told, opinions, what they pass on | `people.lua`, the event log | Well built. It's the mirror image of what we need for the players. |
| Your knowledge | The prep board's notes (premise, prep notes), the notebook's people, a cast card's `secret` (used only to fill a card), the person sheet (who, their line now, stats, pockets) | `MODULE.premise`, `npcs.lua`, `npc_view.lua` | No secrets on the person sheet. No way to reveal or hint on your own terms. |
| Planted items | You put a magic item on someone: it falls out when they're beaten, can be pickpocketed, or asked for | `npcs.lua` drops, `museum_night.drops_*`, `ideas.lua` | Pickpocketing needs someone to notice it first (a Perception die). Asking doesn't: a friend asks for an item nothing showed them. That's a leak. Items can't be clues. |
| The friends' own ideas | Ask, take, help, follow, hide, poke, aimed at people, pockets and curios; scored by player type, class, mood and opinions | `ideas.lua` | The natural home for emergent discovery. There's no "find out" verb, and no class abilities (spells, performance). |
| Checks | Names and facts before they're told, masked friend lines, two campaigns in one process; the book sheet (starts, places, doors, traps, secrets, names, items) | `knowledge_check.lua`, `book_check.lua`, `fidelity.lua` | Hand lists for this book. They find words, not meaning. Nothing checks that a secret can be found. |

## What goes wrong for a big campaign

- **A secret is scattered.** Adding one means the sheet, the registry, a flag, the cast card and a condition on
  every line, and nothing ties them together. In this round there were 74 lines where the friends knew something
  too early; none of them was caught until a scan. A hundred-room campaign would have thousands.
- **"Said" isn't "known".** The registry hears a word, so it can't tell "they know she's a Gorgon" from "someone
  said Gorgon". There's no partial knowledge (a hint like "something about her eyes" against the whole truth). And
  no per-hero knowledge: what Pip saw alone in a split party, a whisper to one hero, a vision.
- **One route in.** The confession is one card with one roll. If the knob is off, or you say no, or the roll misses,
  the Gorgon stays hidden until her hood comes off. The book's other routes (Telpur, the scholar's book, the
  tapestry) are only half wired. There are no routes for a wizard's Comprehend Languages on the tablet, a cleric's
  Speak with Dead on the archivist, Detect Thoughts on Flitwidget, a bard singing for Telpur, or a rogue
  eavesdropping.
- **You can't steer it.** You can't see who knows what, give a hint, reveal early because the table is stuck, or
  hold a reveal back for a better moment. Reveals happen only when a prewritten card comes up.
- **Planted things leak or stay inert.** "Can we have that?" asks for an item nobody's seen. A letter in a pocket
  can't reveal anything.
- **Knowledge is hand-written onto lines.** Every friend line about the world needs its own condition. The scan
  found the misses afterwards; nothing prevents them.

## What to build

### 1. The secret record (data)

One entry per thing the DM knows that the table doesn't, in the module (the importer writes these):

```lua
secrets = {
  gorgon = {
    what = "Euryale, a Gorgon Flitwidget bought sealed in a jar, has taken over the museum",   -- yours
    page = 6, held_by = { "mus_flitwidget", "mus_telpur" },
    names = { "Gorgon", "Euryale", mask = { Euryale = "the hooded woman" } },
    hint = "Flitwidget keeps saying 'incidents'. Something in there is worse than he lets on.",
    tells = "Her name is Euryale, a Gorgon he bought sealed in a clay jar...",
    paths = {
      { kind = "check", on = "mus_flitwidget", skill = "persuasion", dc = 12, page = 6 },     -- the book's own
      { kind = "check", on = "mus_flitwidget", skill = "intimidation", dc = 16, page = 6 },
      { kind = "check", on = "mus_flitwidget", skill = "insight", dc = 12, gives = "hint" },
      { kind = "spell", on = "mus_flitwidget", spell = "detect_thoughts" },
      { kind = "ask", on = "mus_telpur", opinion = "warm", page = 16 },
      { kind = "read", item = "gorgon_book", skill = "history", dc = 13, page = 27, gives = "hint" },
      { kind = "event", event = "hood_off", page = 26 },
      { kind = "dm" },                                    -- you can always reveal it yourself
    },
    unlocks = { flag = "truth" },
  },
}
```

**Paths, by kind.** Each kind can also come as a default for a type of secret, so an import gets several routes
without anyone writing them:

| Kind | Example | Who it suits |
| --- | --- | --- |
| `check` | Persuasion DC 12 on Flitwidget; Investigation on the desk | everyone; by their best skill |
| `ask` | a person tells them once they like the party enough (`people.lua` opinions) | the talkers, the kind |
| `read` | a document or a book they carry (the notebook, the scholar's book) | the scholars |
| `see` | in plain view, or found by looking at a place on the board | the explorers |
| `spell` | Detect Thoughts on a person, Comprehend Languages on writing, Speak with Dead on a body, Detect Magic or Identify on an item | wizards, clerics, bards |
| `perform` / `trade` | a song, a gift, a favour or a deal for what someone knows | bards, charmers, the generous |
| `steal` | a pickpocketed letter, a looted body | rogues |
| `event` | something happening in play: the hood off, a fight, a moment | anyone there |
| `dm` | you reveal it, or hint at it, when you choose | you |

**Defaults by type of secret:**
- A person's secret: Insight gives a hint; Persuasion, Intimidation or Deception get the truth; so do charm,
  Detect Thoughts or a good enough opinion.
- A document: Investigation, History, Arcana or Religion; or Comprehend Languages.
- A place: Perception or Investigation; or Detect Magic.
- A body: Medicine or Investigation; or Speak with Dead.
- An item: Arcana; or Identify or Detect Magic.

### 2. What the table knows (engine)

- **Generalise `told.lua`** into what's known, per secret: `{ level = "hint" | "known", how = path, who = heroes,
  week }`. The names and masks we built today become each secret's `names`.
- **Per hero where it matters.** Something learned alone (a split party, a whisper, a vision) is that hero's until
  their friend shares it, and sharing it out loud is a line of its own. The table learns everything said aloud.
- **Lines declare what they're about** (`about = "gorgon"`) instead of a hand-made condition. The engine holds a
  line until its secret is known, and a hint-level line until it's hinted. The masks stay as the safety net.

### 3. The friends find things out (emergent play)

- **A "find out" verb in `ideas.lua`**, aimed at the reveal paths open in the scene. Each friend scores them by what
  their hero can do (skills, the spells on their sheet, a bard's performance), their kind of player (storytellers
  and explorers love lore, instigators push and intimidate, method actors perform, power gamers trade), how
  they're doing tonight, and what the person thinks of them.
- **Most resolve on their own,** with a small die and your answer from behind the screen, as the curios do today.
- **One that matters comes to you as a card,** within the night's call budget, as pickpocketing does: "Thessaly
  wants to cast Detect Thoughts on Flitwidget. He's holding something back. What does she hear?" Your options are
  the truth, a hint, or "he feels it and clams up".
- **The book's scripted reveal stays, as one path among several.** Missing it no longer locks the secret away.

### 4. Your view, and your choice of when

- **The person sheet gets a Secrets section.** It lists what they know or hide: each secret, whether the table has
  it (no, a hint, yes), and how it could still come out (the open paths, with skills and DCs). Three buttons:
  - **Reveal now:** you say it, and it's in the log as yours.
  - **Drop a hint:** a hint-level line.
  - **Hold it back tonight:** that person's paths are closed for the night.

  Places and items get the same, on the room's prep card.
- **You can plant a secret as well as an item,** on a person, a place, a body or a thing. It stays hidden until a
  path finds it.
- **Planted items get a "seen" state:** hidden, then noticed (Perception, a search, a peek during a pickpocket),
  then known. "Can we have that?" waits until it's been noticed, which fixes today's leak. An item can carry a
  secret: a letter in a pocket reveals what it says when it's read.

### 5. The importer's contract, so a big upload comes in clean

On top of what the root-cause doc already asks for, the importer has to:

1. **Turn every DM-only fact into a secret,** with its page, who or what holds it, the book's own reveal (the
   check and its DC) as a path, and the default paths for its type.
2. **Make every proper name public or secret.** For each secret name, say what the table calls it before it's
   told. The importer lists every capitalised term in the book and asks.
3. **Split every room into what the heroes see and what the DM keeps.** Split every card's scene text into its
   `see` and your note.
4. **Make every player-facing line declare the secrets it touches** (`about`): friend lines, vote wants, chat,
   recaps, narration. A lint at import fails any line that mentions a secret's names or phrases without one.

### 6. The checks, from the data

The checks would be generated from the secrets, so they work for any campaign:

- **Reachable.** Every secret has at least two paths, of at least two kinds. Across simulated campaigns, each one
  is found by more than one path and by more than one class or kind of player. A coverage report shows which
  secrets only ever come out one way, or never.
- **Never early.** A secret becomes known only through a path (the log records which). No line ever gives it away.
  This is today's knowledge and names checks, driven by the secret data instead of hand lists.
- **Lint at import.** Player-facing text is checked against the secrets before anything runs, and so are cards
  that describe a scene without a `see`.
- **Per hero.** An in-character line from a hero who wasn't there, about something learned alone, needs it shared
  first.

## What we keep

- **Who hears what** (`voice.lua`): unchanged.
- **The told registry and its masks and tells:** become each secret's names and its "known" state.
- **`people.lua`:** what the museum's people know about the party, the mirror of this; the `ask` path uses its
  opinions.
- **`ideas.lua`:** gets the find-out verb.
- **The person sheet and its planted items:** get the Secrets section and the seen state.
- **The book sheet (`fidelity.lua`):** its secrets and reveals become the import's secrets. The structure facts
  (starts, doors, traps) stay as they are.
- **The checks:** re-based on the data.

## A plan, in three steps

1. **The record, for the museum.** Convert today's secrets into secret records with paths: the Gorgon and her
   name, her sisters, the ritual, the Witness, the bird, the bait in the tracks, the knight, the huntlings' name,
   the hood, the notes, Telpur's past and the Mech's code. Then add the Secrets section and its buttons to the
   person sheet, and the seen state for planted items (which fixes "can we have that?").
2. **The friends find things out.** The find-out verb, scored by class and kind of player; the spell, performance
   and trade paths; per-hero knowledge.
3. **The importer's contract and generic checks.** The import lint, the reachability and coverage report, and the
   museum's hand lists retired.

Each step ships through the knowledge checks, the gate and a fresh-eyes playtest.

## Conner's calls (November 5)

1. **No cost to reveal.** Reveal now, Drop a hint and Hold it back are free.
2. **The friends dig by who they are:** their kind of player, their hero, and whether they have clues or a theory
   building. By default they're curious and want to engage with the plot.
3. **Each hero's knowledge is tracked,** so the longer campaign is prepared and tested.
4. **The prep board shows how each could come out,** but the friends can improvise, so the DM improvises the reveal
   sometimes: a way that isn't in the notes comes to the DM as a card to make up.

And for big uploads: the DM knows everything and reveals what the players see (location, terrain, the characters in
view, their quirks and tells). So the importer splits everything into what the table can see when they get there and
what's secret, with each secret's holder and ways out (the root-cause doc's importer contract, items 4a and 4b).

## The calls as they were asked

1. **Should your reveals cost anything?** A hint is free, but "Reveal now" could cost a little suspense or
   challenge, the way an unearned save does. Or it could be free: it's your table.
2. **How often should the friends go digging?** Every room with a secret, or only when it suits their kind of
   player? This sets the pace.
3. **Per-hero knowledge in the prologue,** or only from the longer campaign on? It mostly matters for split parties
   and private visions.
4. **On the prep board, should each secret show how it could come out?** That would let you prep for it: put the
   scholar's book on the shelf, give Telpur a reason to talk.
