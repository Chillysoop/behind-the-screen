# Behind the Screen: game overview for collaborators

November 4, 2026. This copy is for anyone working in the code. If it and the code disagree, the code is what ships.

> **What this describes.** There is one game: *The Museum of Nightmares* by Luke Russell (DMs Guild), run as a
> one-shot prologue in the adventure (module) format. A longer pre-written adventure will follow in the same format.
> The October game (the Silent Bells campaign with its story deck, valley map, factions and planner) was removed in
> the November 4 purge; git history and the `v2-museum-before-purge` branch keep it.

## What the game is

Behind the Screen is a cozy single-player game where you are the Dungeon Master for four simulated friends who meet every Thursday to play a fantasy tabletop game. You don't play a hero; you run the table. You prep each session, make the calls when game night needs you, read how your friends are feeling, and keep a story going that they care about week after week.

The fantasy is being a good DM: the friend who makes Thursday the best night of everyone's week. The game is a social simulation wrapped around a pre-written adventure and a real rules engine (SRD 5.2.1, the free D&D 5e rules). Its tone is warm and low-pressure: there is no game over, and a bad night is a story, not a failure.

- **Engine:** Defold 1.13.2, Lua. Every model and rule is engine-free Lua, so a whole prologue can be played headless.
- **Scope today:** Session Zero, then the museum room by room for as many sessions as it takes (three to five in testing), a boss night, and a journey recap with a short survey.
- **Next:** a longer adventure, written as data in the same format. The engine around it doesn't change.

## The loop

1. **Session Zero (once).** The table talks it through: the tone, each player's ask (a line, a veil or a promise), and the table rules (the X-card, which rolls are in the open, how rules calls work, how long a night runs, what happens when a hero dies, and how harsh it gets). Every option shows who likes it.
2. **Why each hero came.** Each player has two of the book's hooks and leans toward one; you pick. A hook ties the hero to a room, where they sit up when it plays.
3. **Between sessions.** The group chat: the friends talk about last night, and one of them asks you something. Then the week's prompts: a player's request (yes, with a laugh, no with a reason, or yes but it's dangerous), a loose end (where a skipped card turns up again), a rules call to post or leave, and a favor (one way it helps, one way it hurts).
4. **Prep on the museum map.** The board is the book's floor plans. You have 10 hours: prep the rooms the party might reach (an unprepped room plays thinner), set the book's advice as knobs, read each room's notes (who you'll voice, what to have ready), talk to a friend (1 hour), and spend spare hours on sleep or a backup page. Up to two unused hours carry over. "Ties and locks" lets you bend the adventure, and the map repository puts any map on the table.
5. **Game night.** It plays itself on a 3D tabletop: each room's board goes down, paper minis walk and fight on the rules engine, and the friends talk, cheer, yawn or check their phones. The table picks the way at forks. You make the calls the book's moments need, read what your friends are thinking, rule on rolls and decide which go behind the screen. The first night is gentler: the story's own calls, one big roll, one thought, and the rest waits for the second.
6. **The report.** A dice box first (earned from how the night went), then a recap you can edit, how each friend felt (least happy first), a verdict, gifts, and the level-up when it's ready.
7. **Boss night.** A showdown board (how Euryale opens, how far she goes), a talk, the fight, and an ending: she falls, a bargain, she slips away (for half the reward), she sleeps, or an unlikely ally. Then the journey: the route, what each room left behind, each hero's story in short lines, and what each friend wants next.

## The table: four friends you have to read

The players are the real subject of the game. Each is a person with tastes, a week outside the game, and opinions about you as a DM. Their archetypes come from Robin Laws' player types; the primary counts double, the secondary once.

| Player | Hero | Archetypes | Loves | Loses them |
| --- | --- | --- | --- | --- |
| Mara | Thessaly, Wizard | Storyteller, Explorer | Mysteries, reveals, notes | Long fights; jokes in her serious moments |
| Dev | Brannoc, Fighter | Butt-kicker, Power gamer | Fights and cool weapons | Long talky scenes |
| Jess | Pip, Rogue | Method actor, Instigator | Talking to people in voice, chaos | Having her scenes cut short |
| Sam | Oswin, Cleric | Casual, Tactician | Friends, snacks, a fair clever fight | Being put on the spot |

**What the simulation tracks for each player:**

- **Session meters** (spotlight, challenge, story, social, reward) move beat by beat on game night. Weighted by archetype, they make **Fun**; boredom builds when a scene isn't for them. A visible **tell** shows how they're doing ("grinning", "eyeing their phone").
- **Long-term bars** settle after each night: **Commitment** (will they keep coming), **Investment** (do they care about the story), **Trust** (do they trust you) and **Suspicion** (do they think you cook rolls).
- **Mood** is rolled weekly (fine, tired, celebrating, stressed, chatty, distracted) and carries into the night. You learn it by talking to them.
- **Thoughts:** what they think and don't say on game night (a want that's nagging them, their take on a call, the week they've had, a roll that looked convenient).
- **Goodwill** fills on good nights; a full heart means they bring you a gift that stays on your side of the table.
- **Rapport** between each pair of players can sour into friction you defuse or let slide.

**Reading them is a skill, and it grows.** **Empathy** (five levels, Clueless to Reads minds) rises with every game night and every talk. It sets how precisely bars show, whether they update live, whether you get early warnings, and how many thoughts you catch. **Familiarity** ("New to you" to "Like a book") is how well you know each friend; it helps you read their thoughts, which takes an Insight roll. Bars are fills and icons, never numbers, and Suspicion is always a blurred band.

**The social layer.** Three table conflicts can build from what happens at the table: Jess hogging the spotlight, Dev and Sam fighting over rules calls, and Mara's serious moments against Jess's jokes. They're settled at the table: a vote, enough good calls, or a night that gives both sides their scene. A friend whose Commitment sinks shows it on their card ("Seems to be losing steam lately"). The prologue is short and everyone's keen, so the whole table comes every week; breaks wait for the longer campaign. There's no hard fail.

## How stories work

The story is a pre-written adventure, cut into pieces that remember. The game doesn't invent the plot; it plays the book's rooms and lets what the party does change what comes later.

**The adventure is data.** Everything the museum is lives in `game/data/museum/`: its rooms and the doors between them, each room's moments (the calls the book's scenes need), its people and their memory, its places, goals, snags and prizes as cards, the hooks, the requests, loose ends and favors, the showdown, the endings, and its own words for every shared system (Session Zero's pitch, the prep notes, the gifts, the recap, the magic items, the glossary). Game night, the fights, the friends and the report are shared systems that play any adventure written this way, and they fall back to neutral words, never another story's.

**Cards that remember.** Euryale's card on the prep board collects marks as the party goes. Each mark comes from something they did and changes boss night: who fights beside her, what the party brings, or how easily she talks.

**The table chooses.** At a fork the friends talk it over and settle where to go from what they want; the DM can only nudge when asked. After they pick, the DM decides what's there: the book's room, something improvised, or another prepped encounter moved in. They choose differently from run to run: each option has its own fans, the friend who gave way last time holds out for theirs, the table notices its habit, and the week each friend has had weighs in, all said out loud. A bid comes from the moment as much as the friend: a hurt hero, a rough last fight, what happened earlier in the night. A friend only gives way when another pushes.

**Harsh calls that feel fair.** A warning is about a thing. When the party was warned (you described it, asked "Are you sure?", or they found out), a die was rolled in the open, or the table agreed to brutal at Session Zero, a harsh outcome lands as fair. Otherwise it costs Trust. Too many warnings in a night drain the suspense.

**Only what's true.** A line that says what happened reads it from the adventure's state or carries a condition. Every flag set is read by something, every mark changes boss night, and anything picked up works later. The truth test (`tools/tests/museum_truth.lua`) plays whole prologues and fails on a line that contradicts what happened.

**One event log.** What happened in the adventure is one list (`game/model/events.lua`): who did what to whom, where, who saw it, and what it follows from. Every line that says what happened reads it from there; no two systems keep their own copy.

**Therefore or but.** Every beat a night plays should follow from an earlier one or complicate it, and the report and the journey tell the night as that chain, joined with "so" and "but" only where the earlier beat really caused or turned the later one; a beat that would have happened anyway starts a sentence of its own. The sims measure each night's share of linked beats and its longest unlinked run, and the rooms that start the most get rewritten first (see the Main Campaign Design doc, linked from `AGENTS.md`).

**People who remember.** Flitwidget, Telpur, the Lecturer, Euryale and the companions each think something of each hero and of the party, read from the log through what they saw or were told. It changes what they say, what they charge and what they do: Telpur's prices go up after a theft at his shelf, broken exhibits sour Flitwidget's thanks and his reward, and the Lecturer passes what he hears up to Euryale.

**One owner for each action.** The hero a moment names is the one who rolls, carries what it gave and gets the credit, and what's handed over is shown being handed over. Only what someone owns can fire. The reward is one number everywhere, real gold, said by Flitwidget before anyone haggles; every Franc in or out of the pool is in the log.

**Who can't act doesn't.** A hero who's dead, down, stone or charmed doesn't talk in character, roll, vote, pick things up or get an idea; their player still talks as themselves (`game/model/able.lua`). After a death or a wipe the table goes quiet, and the recap leads with the loss.

**The friends' own ideas.** The room's cards aren't the only things that can happen. In a quiet stretch a friend reaches for something on their own: a question, a curio, a helping hand, someone to follow, somewhere to hide, or something to lift off someone who never planted it. Most just happen on a small die; one that could turn someone against the party comes to you as a card.

## How the DM learns where the story is

The player is the DM, so the game has to keep a lot of moving story in their head without turning into a spreadsheet. The friends carry as much of it as possible: what they remember, want and feel is shown in their own words.

**During prep:**

- **The prep board** is the museum's floor plans: the rooms ahead, the ones done, the doors and the stairs, and Euryale's card with its marks. Each room says what prepping it does, who you'll voice and what to have ready.
- **The group chat** in the left column: what the friends said about last night, written from what happened (a sad week has no jokes), and the week's prompts.
- **The friends' cards** on the right: how each is doing, their mood once you've talked, their Goodwill, how well you know them, and what pulls them toward each room.

**During game night:**

- The opening cards and "Last time, they..." set the scene.
- Each room's read-aloud is the DM's text; the party's reactions play out in speech bubbles, and a player speaking in character turns into their hero.
- **The Story and Table sidebars (S):** where each side of the story stands and its key people, and each friend's reason for coming, what they love, who they're drawn to, how they seem tonight and the last thought you read. One at a time: S goes Story, Table, neither.
- **People's sheets:** click a name in any line for who they are, their line now, their stat block and what's in their pockets.
- **The log (Tab)** and the dice strip keep every line and roll.

**Any time:** **your notes (N)**, in six tabs: the museum, upstairs (Euryale), this session, people, the session log and the party.

## How the systems overlap

Nearly every system does one of three things: it changes where the adventure stands, it changes how the friends feel, or it writes to the record. Game night is where they all meet, and what happens there is what next week's prep, the chat and boss night read.

**One room touches several systems at once.** A room is on the map (prep decides how well it plays), it may be someone's hook (that friend sits up), it has people who remember the party, it can leave a mark on Euryale's card, and every friend likes some kinds of room more than others. So choosing which rooms to prep, and how, is the core decision of the week.

**Other places they meet:**

- **Session Zero** reaches into every night: the X-card, which rolls are in the open, how long the night runs, death, and how harsh it gets.
- **The week's prompts** change the adventure: a request granted can put a weapon in the party's hands, a loose end decides where a skipped foe turns up, a favor helps one room and hurts another.
- **The rules feed the story:** a fight's outcome, a big roll made in the open or a hero's death all write to the record and to Euryale's card.

**Worked example: the garden.**

1. The garden's hedges are cut into beasts, and when the fight starts they come alive where they stand.
2. If the party leaves one standing, Euryale's card gains "Topiary at her couch", and her thought upstairs says so ("One of my hedges is still standing").
3. On boss night a Briar Beast fights beside her.
4. If they set the garden on fire instead, she smells the smoke: she skips the drink and the small talk, and the talk is harder.
5. Either way the journey recap names what the garden left behind.

**Worked example: a hook.**

1. At the hooks page you pick Thessaly's reason for coming: Knowledge. It ties her to the archivist's offices.
2. The Table sidebar shows her reason and whether it has paid off yet.
3. When the party reaches the offices, Mara sits up, and the room says what Thessaly came for.
4. Her story moves: more Investment and Fun that night, and a line in the journey.

## The rules underneath, and the fights

The dice and the fights run on a real D&D rules engine, so the table plays by the same rules a real one does. The player never has to run it by hand: the engine plays the rules, and the DM makes the calls a DM makes.

**The engine.** It uses SRD 5.2.1 (the free D&D 2024 rules), with characters at levels 2 to 4, twelve subclasses, and the SRD's monsters plus the museum's own (`game/rules/museum.lua`). A check is d20 plus the character's skill against a DC ("Pip, roll Sleight of Hand. DC 10."). Whoever is good at the skill and short on spotlight steps up. Character sheets show the engine's own numbers.

**Big rolls are the DM's oldest dilemma.**

- **In the open:** the table sees the die and the DC, and trusts the result.
- **Behind the screen:** the DC stays hidden, so you can cook it, nudging it to save a hero or keep a story going.
- **Suspicion** grows with cooking. Cook too often and someone asks to see the dice.
- **However it lands,** you choose how it plays: generous, straight or with a cost.
- **Failing is fun when it's handled well:** natural 1s go to dice jail.
- **Some checks are secret** (noticing an ambush, reading a liar): you roll those behind the screen.

**Fights come from the rooms.** Every room brings its own encounter, on its own board drawn from the book's maps. Minis walk square by square, use cover and line of sight, take hits and drop. Pieces of the room can come alive. Fights bring their own calls: a hidden roll that would drop a hero, their last death save, a fight that drags on, the killing blow (the player whose hero or ally lands it describes it). The big moments are said aloud as they happen (her stare, the mirror, turning to stone, Hyper Destroyer Mode, a natural 20 on a death save), and so is a spell that catches the party. Who you tell a foe to go for, it goes for, until it has. Once a night you can speak as a key person (warm, guarded or lying), and once a night you can run the boss's turn.

**Rests, the break and death.** Every night takes a break about a third of the way in (on boss night, once her part is settled), and you pick what the heroes do meanwhile: nothing, a short rest, a long rest where the room allows it, or research. A night that runs well past the end agreed at Session Zero is said at the table and costs Trust. Death follows what Session Zero agreed: the last death save plays as a call; the fallen get a goodbye or come back with a scar; a hero who dies stays at the table, and their player picks how to play on (a companion, the monsters, or watching), with a new character from the next session. The wake comes once the danger is past, in the gift shop, and what the dead hero carried is shared out loud.

## Progression

Progress happens on four tracks: the party grows, the DM gets better at reading people, the friendships deepen, and the table fills up with things the friends gave you. None of them is a skill tree; each comes out of playing.

| Track | What grows | How |
| --- | --- | --- |
| The party | Levels 2 to 4 | After two nights at a level the report (and the prep board) offers the level-up; after four the table starts asking. At level 3 each player picks their own subclass for their own reasons (who they are, what their nights were like), and the DM gets no say. At level 4 everyone takes an Ability Score Improvement. |
| The DM | Empathy and familiarity | Every game night and every talk adds to Empathy; nights together, clear reads and answers that land add to how well you know each friend. Higher Empathy shows the bars more finely and catches more thoughts. Suspicion stays a blurred band. |
| The friendships | Commitment, Investment, Trust, Goodwill | Commitment follows recent fun, Investment their own story, Trust fair calls and kept promises. A full Goodwill heart brings you a gift (a dice tower, a framed map of the museum, a candle...) that stays on your side of the table. |
| The dice | The dice box | After each session a box of dice, earned from how the night went: common to mythic. You can give a set to a friend. |

**Losing ground is part of it.**

- **Losing steam:** a friend whose Commitment sinks shows it on their card, and a bad night shows in the report.
- **Conflicts:** table conflicts cost the people in them every week until they're settled at the table.

## Why it could be fun

The fantasy is the best part of being a DM without the parts that make people quit: no blank page, no rules to memorize, no scheduling, no one actually let down. What's left is the craft and the warmth.

- **Reading people is the game.** The core skill isn't optimization, it's noticing: Dev folding his arms, Sam reaching for a phone, a thought cloud over Mara's tile. The satisfaction is the same as at a real table: guessing what someone will love, giving it to them, and watching them light up.
- **Prep is a puzzle with a payoff.** Ten hours, more rooms than you can prep, and a table that picks its own way. Every room you ready is a small bet about four people at once, and game night shows whether it paid off.
- **The story remembers.** What the party does in one room shows up on Euryale's card, in the chat, in the people they meet again and on boss night. The journey afterwards reads like a session your group actually played.
- **Small calls carry weight.** Whether to cook a roll, whether to warn them first, whether to cut the joke in Mara's serious moment. These are real DM dilemmas, and the game lets the consequences play out rather than scoring them right or wrong.
- **It's cozy.** A warm room, snacks, dice, friends who mostly like each other. Failure is soft: a bad night means someone's a bit less keen, not a game over.
- **It teaches the real thing.** Session Zero, safety tools, spotlight balance, fair warning and running a published adventure are real DM techniques. Someone who plays this should be a better DM at a real table.

**Who it's for:** people who love D&D stories but don't DM (or are scared to), DMs who enjoy prep and want it without the scheduling, and fans of cozy management and character games.

## Where it stands, and what's still open

**Built.** The prologue plays end to end through the real UI, the real engine and headless: every seeded run reaches an ending in three to five sessions. Every room plays on its own board drawn from the book's maps (`tools/maps/`), and the fights use the book's own monsters, on their own paper minis (the museum's people too). The rules, the friends and the adventure are engine-free Lua with their own tests.

**Open:**

1. A "just the adventure" mode, for players who want the story without the table.
2. The longer adventure that follows the prologue. Before starting it, read `docs/design/longer-adventure-notes.md`: one event log as the source of truth (the museum's is `game/model/events.lua`), one shape for conditional text, and the truth test as the gate.

## Glossary

| Term | Meaning |
| --- | --- |
| Adventure, module | A pre-written adventure as data (`game/data/<adventure>/`): rooms, moments, people, cards, marks, endings and its own words. The museum is the first. |
| Big roll | A d20 roll that pauses for the DM: in the open or behind the screen, then generous, straight or with a cost. |
| Boss night | The last session: the showdown board, a talk, the fight and an ending. |
| Commitment | How likely a friend is to keep coming. It follows recent fun; when it sinks, their card says so. |
| Cooking | Moving a hidden DC to change how a roll lands. It raises Suspicion. |
| Decision card | A moment on game night that needs the DM: a room's moment, a fight's call, a rules question, a table problem. |
| Event log | The one record of what happened in the adventure: who did what, who saw it, and what it follows from. Lines, people's opinions and the night's chain read it. |
| Empathy | The DM's skill at reading the table, 1 to 5. It decides how precisely you see the friends' bars and how many thoughts you catch. |
| Fair warning | Knowing about a danger before a harsh call lands. Warned, it feels fair; unwarned, it costs Trust. |
| Familiarity | How well you know one friend, "New to you" to "Like a book". It helps you read their thoughts. |
| Fork | Where the party picks its way. The table settles it; the DM decides what's there. |
| Goodwill, keepsake | A friend's heart, filled by good nights. When it's full they bring a gift that stays on your side of the table. |
| Hook | A hero's reason for coming, tied to one room, where they sit up. |
| Investment | How much a friend cares about the story, especially their own hero's. |
| Knob | The book's advice for running a room, as a choice on the prep board. |
| Loose end, favor, request | The week's prompts between sessions: where a skipped card turns up, one way something helps and one way it hurts, a player asking for something. |
| Mark | Something the party did, written on Euryale's card. Each one changes boss night. |
| Opinion | What one of the museum's people thinks of a hero or the party, hostile to devoted, from what they saw or were told. |
| Session Zero | The first meeting: tone, lines and veils, table rules. Its agreements apply all campaign. |
| Suspicion | How much the table suspects you're cooking the dice. It is always a blurred band. |
| Taking over | Once a night, speaking as a key person or running the boss's turn yourself. |
| Thought | What a friend is thinking and not saying. Catch it, read it with an Insight roll, then answer it or let it be. |
| Ties and locks | Your own wiring for the adventure: lock a door, a room or a person until something happens, or tie a mark to something the party does. |
| Trust | How much a friend trusts you to be fair: kept promises, fair calls, no railroading. |
