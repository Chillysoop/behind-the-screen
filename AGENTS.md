# Working on Behind the Screen

A cozy single-player game where you are the Dungeon Master for four simulated friends. Made in Defold
1.13.2 with Lua. Before changing anything, read:

1. `docs/OVERVIEW.md`: what the game is, the weekly loop, how stories work, how the systems overlap,
   progression, and what's still open.
2. `README.md`: every system in detail, controls, the project layout, and every test.
3. `docs/design/`: notes on changes, including the step-by-step rework that was set aside.

**This branch: `v2-museum`.** There is one game: a real published adventure, *The Museum of Nightmares* by Luke
Russell (DMs Guild), run as a one-shot prologue in the adventure (module) format: Session Zero, why each hero came,
then the museum room by room for as many sessions as it takes, a boss night, and a journey recap. The October game
(the Silent Bells campaign with its random story deck, factions, seeds, valley map and campaign planner) is gone: it
was removed in the November 4 purge, and the `v2-museum-before-purge` branch and git history keep it. The four
friends, Session Zero, the rules engine and game night stay. The design and the feedback behind it are in
`docs/design/2026-10-30-museum-v2.md`. This is the main version of the game, titled Behind The Screen (Conner,
November 6); pull request #1 moves `main` up to it, and the October 20 build stays in history at 90823ab.
Every adventure uses exactly one rule set, 5e for now; other systems are planned as their own adventures, through
the steps in `docs/design/rule-sets.md`.
A longer, full pre-written adventure will follow as the main campaign, in the same adventure format.
**Before starting it, read `docs/design/longer-adventure-notes.md`:** the November 2 playtest feedback on cause
and effect, what to build first (one event log, one shape for conditional text, the truth test as the gate), what's
still open from the museum, and a checklist.
**Then read `docs/design/2026-11-05-root-causes.md`:** the ten kinds of problem four playtest rounds keep finding
(who may hear a line, the DM speaking for the players, claims with no record behind them, book structure not kept as
data, and six more), the rule and the check for each, the importer's contract, and the tracker of every open item
(Conner's 27 points on the November 4 build and the final pass's leftovers). Fix sessions start from its tracker.

Where v2 lives:

| Path | What it holds |
| --- | --- |
| `game/data/adventures.lua` | The adventures the game can run, and where each one's parts live (module, cards, fidelity, people, table life). `game/model/adventure.lua` runs the current one (`adventure.current()`, `adventure.part(name)`); a check runs against another with `ADVENTURE=<id>`. The standard every adventure follows is `docs/design/adventure-standard.md`, and the shape of its data is `game/data/adventure_schema.lua` (first written from the museum by `tools/import/schema_from.lua`; a new field goes in on purpose, with the standard). |
| `game/model/standard.lua`, `game/data/sheep/` | The standard compiled to game night's form (step 5, November 6): an adventure written in the standard (places with a `scene`, events with `when_in` and options, creatures) becomes rooms, cards (`<adventure>_<place>_place` and the rest, added to the content by `content.add_cards` when the adventure is used), moments, stat blocks in the rules' roster and its people's pronouns. `MODULE` in game night, the week, the ties and their screens is a live view of the current adventure. The Sheep Chase is the first: its scenes play on `game/data/maps/sheep_*.map`, after the inn sheet and Noke's Tower map. The title screen's "New game plays:" picks the adventure; a save's `A=` header says whose it is and `save.load` switches to it first. |
| `adventure.handoff`, `adventure.use` (`game/model/adventure.lua`) | Any adventure follows any other (Conner, November 6): the heroes, what they carry and the log go on; the finished one is `campaign.past[id]`, what the table learned `campaign.lore`, its open threads `campaign.threads` (picked up by `thread = id or tag`). See the standard's "Adventures tied together". |
| `game/data/museum/module.lua` | The adventure: rooms, the doors between them (`links`), what a second look can still find, knobs, room moments, Euryale's marks, requests, loose ends, favors, the showdown, endings. Also the gift shop's prices (`PRICE`, at the top: each option's label, price and what it takes come from there), the paintings the hall can hang for each hero and what reaching into each one risks, as the book has it (`portraits`, `portrait_default` for anyone else), who comes as more of them in each room when you call reinforcements (`reinforcements`: none listed, none offered), and what the week between left them with, said at the night's first fight (`asides`). Every line in our own words. |
| `game/data/museum/cards.lua` | Its places, people, goals, snags and prizes as ordinary cards, plus how the heroes play each goal. |
| `game/model/adventure.lua` | The adventure's state: the map, marks, flags, Francs, hooks, prompts. It also switches the shared content over to the adventure's words (`adventure.enter`), and `adventure.fits` keeps out shared lines about things its world doesn't have. A condition (`adventure.test`) can also ask `from` (the room they've just walked in from), `holds` (someone in the party carries a thing) and `holds_here` (someone at the table tonight does). `adventure.apply` hands a thing to the hero whose choice it was (the buyer, the finder). `adventure.recap_clause` is what a room came to in "Last time, they...": its `fought` words when its optional fight happened, its `alone` words when one hero went on alone. |
| `game/model/museum_week.lua`, `game/model/museum_night.lua` | The week (prep hours, knobs) and the night (rooms, forks where the table picks the way, trips back with a reason, side rooms, moments, Euryale's interludes, boss night). `museum_night.heard` notes a name the table has now heard said (the Witness), so lines that use it wait for it; `place_statue` puts the statue the group chat promised at the foot of the gift shop's stairs, on its board. |
| `game/model/thoughts.lua`, `game/data/thoughts.lua` | What the four friends think and don't say on game night (a want that's nagging them, their take on a call, the week they've had, a roll that looked convenient, Pip's plan to go off alone): how many the DM catches is their Empathy. A caught thought shows only a tell until the DM reads it with an Insight roll (`thoughts.read`: d20 + Empathy + familiarity against the thought's dc and how hard that friend is to read; clear, gist, miss then ask, or a misread on a 1, on its own dice). Each has two answers and "Let it be". The night director calls in at its beats; `game/ui/night_view.lua` draws the cloud over the panel and the card, and calls `thoughts.read`/`ask`/`respond` between beats. |
| `game/model/standing.lua`, `game/ui/recap_view.lua` | The DM's recap on game night: the Story sidebar (top left: the adventure's sides from `MODULE.sides`, each person's line now, who at the table is drawn to them) and the Table sidebar (top right: each friend's reason for coming and whether it's paid off, what they love, who they're drawn to or put off by, how they seem tonight, the last thought you read, how well you know them). Story and Table buttons in the top bar; they open one at a time (the buttons swap them, S goes Story, Table, neither), and the night waits while one is open. Affinity: the kinds of player a person appeals to (`likes`), the hero whose reason is in their room, and the moments since (`standing.note`, from `museum_night.play_moment`). |
| `game/model/familiar.lua` | How well the DM knows each friend ("New to you" to "Like a book"): grows with nights together, clear reads, answers that land and prep talks; a bonus on reading their thoughts. Shown as dots on the prep board's player cards. The first piece of a fuller you-as-a-DM progression. |
| `game/model/map_repo.lua`, `game/ui/map_repo_view.lua` | The map repository: every map the DM can put on the table; a room's map, side rooms, the next scene's map, the DM's own maps (edited in `game/ui/map_view.lua`). |
| `game/model/ties.lua`, `game/ui/ties_view.lua` | The tie-and-lock editor ("Ties and locks" on the prep board): lock a door or a room until something happens, a moment (only if, or cut), a person (out of sight until: their moments skip, their room plays without them); tie a mark on Euryale's card, or a hero's reason for coming moving room, to something happening. Conditions: a room done, a card's out (by its words: `MODULE.outs`, or its aspect), a mark, Francs, a session. Refuses a lock that could never open or could leave the lair out of reach. The state is `campaign.adv.locks` / `.ties` / `.hook_room`; `adventure.lua`'s walking reads the locks, `museum_night.ties_beat` opens and fires them on game night. Generic over the module's data. |
| `game/ui/museum_*.lua` | The hooks page, the prep board (the museum as the book's floor plans) and showdown board, the journey recap. |
| `tools/maps/`, `game/data/maps/*.map`, `game/data/map_library.lua` | The map import pipeline (`tools/maps/README.md`): a book's map image to a draft, a draft to a hand-finished `.map` spec, specs built into the map library, which `game/data/boards.lua` merges into its boards. The museum's ten rooms are specs here; `game/data/terrain.lua` points the `mus_*` places at them. Never copy a book's art or text: our pieces, our words. Every spot on a board says what it is (the spec's `form` column: one or many, and a thing, a fixture, a picture, a figure, a person or an area), and the friends' looking-round lines name the kinds they fit. |
| `game/rules/museum.lua` | The museum's monsters' special rules (with the stat blocks in `game/rules/data/monsters.lua`). Only a stat block marked `commanded` (the Steam Mech) powers down when its commander drops. |
| `game/ui/edit_guard.lua` | Cancel on the DM's menus (November 3): a menu takes a copy of what it can change when it opens; its X (or Esc) puts it back, asking "Throw away your changes?" only when something really changed. Used by the map repository and the ties editor. |
| `game/model/tile_stats.lua`, `game/ui/panels.lua` | The player tiles' numbers (November 3): HP and AC always, and the class's own resources as pips (spell slots, Channel Divinity, Second Wind, Action Surge) with hovers. Who's speaking lights their tile and their mini's outline (`main/people/*_outline.sprite`, `materials/outline.*`): gold in character, blue out of character, purple thinking. |
| `game/model/museum_night.lua` (`table_pick`, `fork`, `whats_there`) | Player choices are the players' (November 3): a party moment (`party = true`, each option's `want`) is talked over and settled by the table from their stats, and the DM can only nudge when asked; the same for where to go next. After they pick, the DM decides what's there (the book's room, improvised, or another prepped encounter moved in). A moment's `proposes = i` has its lead vote for the option the card says they want, and whoever acts on what the table settled is one who wanted it (`night.party_backers`), from the heroes still in the scene. What carries over into a vote (R10): `campaign.adv.votes` (who gave way last time and minded, who holds out for theirs next time; the last pick's kind, bold or safe, and how many in a row, so the table notices its habit), the week each friend has had and a quiet night for whoever leads; each said out loud three ways (`museum_night.VOTE_WHY`). At Euryale's ultimatum what they brought against her counts for the fight (`MODULE.showdown.edges`: a planner counts it all, whoever carries one wants to use it). Round three: votes come from the moment, an option's `lean`, `points`, `pulls`, `uses` and `short` (`VOTE_MOMENT`); a friend gives way only to a push (`VOTE_PUSH_LINES`, `VOTE_CAVE`), a quiet decider speaks (`VOTE_SIDE`, `VOTE_TIE`), the credit names only who was heard, and the habit names the vote just gone. Only the friends whose heroes are in the scene and can act vote. A card whose risk falls on something other than them says so (`risks`: the Mech's red switch), and then a hurt hero or a rough last fight doesn't make anyone shy of it. |
| `game/model/museum_night.lua` (`explore`, `drag`, `hand_off`, `drops_*`), `MODULE.explore` | Looking around (November 3): before a room's business (after its fight, in a fight room) the friends take turns walking over to places on its board (`map_library` `places`) and say what they make of them. A find or a trap there (`MODULE.explore`) is the DM's call behind the screen, gated by the night's call budget. Moments with a `spot` walk their hero there; `mus.drag` pulls a mini into a feature and back. A magic item goes to whoever'll use it best (`hand_off`). Round three: each place has its own lines (`MODULE.explore_say`), only the first look in a room gets a word, and a place with nothing to say gets nothing. |
| `game/model/npcs.lua`, `game/ui/npc_view.lua`, `MODULE.npc_sheet` | People's sheets (November 3): their name in any line is a clickable word (gloss.lua's people terms, `kit.on_click` on a spot with `on_click`); the sheet shows who they are, their line now (standing.lua), their stat block, and what the DM put in their pockets (`campaign.adv.drops`) with how the party gets it: beaten (falls out after the fight), pickpocket or ask (a player's idea from their stats; the DM rules). |
| `game/model/loot.lua`, `game/ui/rewards_view.lua` | The dice box after a session (November 3): earned from how the night went, opened before the report, rarities common to mythic (`game/data/dice.lua`). |
| `game/model/fight.lua` (`wake`), `main/board/board.script` (`lift`) | Pieces that come alive (November 3): a room's `wake = { feature, at }` puts each foe on the square of the piece it was, opens that square, and the board lifts the piece off (and keeps it off on the report's replay). |
| `game/ui/saves_view.lua` | Saving and loading (November 3): the autosave (the museum's own file, `museum_save.txt`) and three slots of your own (`museum_slot1..3.txt`). The title is Continue (the newest save), Load, New game; Save is on the prep board and the report. A save's header carries when it was made and where the story stood (`save.dump(c, meta)`, `save.peek`). |
| `game/model/barks.lua`, `game/data/barks.lua` | Fight barks that fit the moment (November 3): a line is checked against what just happened (`fits`: "natural twenty" needs a 20, "who's next" needs foes left), and lines are made from the moment in each friend's voice (`made`: the foe, the weapon, how many are left). The DM's word on a round of only walking, and on a charmed hero who won't attack. `night:fresh(list, key)` now remembers across weeks. Lines said outside a fight's turns fit the room too (`barks.context`, `barks.context_fits`, `night:bark_context`): "nobody to talk to" needs nobody there, "big guy" something big, "here with the chips" a room whose danger is settled. Round three: `barks.context` also knows a lock, a statue, a puzzle (rooms' `locks`, `statues`), whether they've looked round, a big last beat, the night's first fight, the friend whose hero came close, the clock (`late`, `midnight`) and a night a hero died. |
| `game/ui/battle_hud.lua`, `main/fx/ring.*`, `tools/gen_ring.py` | Status rings on the mat (November 3): a coloured ring around a mini's base for the effect that matters most on it (charmed, turning to stone, frightened...), its tag under the health bar in the same colour, with a hover. |
| `game/model/warnings.lua` | Fair warning (November 4): a warning is about a thing (`campaign.adv.warned[key]`, keyed by the moment it's about), given by the DM (told, or "Are you sure?": `museum_night.warn_step` on a card with `danger`), asked for in the chat (`mus.warn`, a string keys it to another moment), or known from an option (`mus.risk`). A harsh outcome asks `warnings.judge`: warned, a die rolled in the open, or a table that agreed to brutal (Session Zero's `harsh` rule) lands as fair; otherwise Trust drops. More than `TOO_MANY` warnings a night drains the suspense. |
| `game/model/sight.lua` | Line of sight on a room's board (November 4): walls and closed doors block it; `walk` paths minis round walls and opens doors on the way; NPCs and foes (`cast.visible`) stand on the mat only once a party mini can see them (`night:come_into_view`), and a fight starts with the minis where they stand (`night.mini_pos`). |
| `game/model/companions.lua`, `MODULE.companions` | Who comes along (November 4): a pet in a pocket (Exhibit B: helps its owner look round, has lines) or a person (Telpur: a `monster` stat block, in initiative with a mini, played by its friend, or by a player whose hero fell: `night.pilots`). Join from a chat answer (`companion`, `companion_find`) or a story flag (`joins.flag`). An ally who drops is said and answered (`companions.fell`: the friend who plays them reacts, flag `<id>_fell`), comes round after the fight (`after_fight`), and one who joins a fight without walking in with them is heard arriving first (`ally_arrives`, `MODULE.ally_join`). A pet stands on the table too: its own mini at the corner of its owner's square, going where they go and leaving with them (`main/table/table.script`), and its picture on its owner's tile; with `DUMP_DIR` the smoke test writes the minis the table is told to stand to `board_minis.txt`, so the board can be checked without the engine. |
| `game/model/death.lua` (`after_fall`), `night_view` `dying` | Down and dead (November 4): the death-save card over the mat shows each save; a hero who dies stays at the table, and their friend picks how to play on (`fallen_seat`: pilot a companion, run the monsters, watch). Round three: the wake once the danger is past, in the gift shop or at the night's end, with Flitwidget's `grief` line first (`death.hold_wake`); the dead hero's pack shared out loud among the friends whose heroes can act, each thing logged as given (`death.settle_pack`), so nothing waits in the seat for the next hero. |
| `game/model/able.lua` | Who can act (round three): one owner for a hero's state, dead, down, stone, and in a fight charmed or out of it (`able.state`, `can_act`, `can_fight`). `night:at_hand()` asks it, so every picker, the votes and the cards do. `able.somber` (a death, a wipe, an ally lost) quiets cheering lines and table habits; a rules card that night is asked plainly. |
| `game/model/fight.lua` (`tell_moments`, `friendly_fire`, `saved_switch`, `squares_shown`) | The fight's big moments told (round three), from `BARKS.told`, three ways each, once, in the order they happen: her hood, her stare, the mirror, stone, cracking free, charmed, Hyper Destroyer Mode, burning out, powering down, a natural-20 death save. Friendly fire said, answered and owned, in the fight's record for the recap. The red switch saved for her flipped in her lair by the Mech's commander (`SWITCH_LINES`), and then the mode told. Every mini set down where it shows: not straight behind another hero, not behind a wall, only inside the anchor's room. A foe's target: the DM running its turn (`c.dm_ran`), then a stare-down (Taunted), then a standing call (`dm_keep`, the tactics card), the same in `game/rules/ai.lua`'s `focus_target`, the Lecturer's and Euryale's turns. |
| `game/model/museum_night.lua` (`maybe_break`) | The break (November 4): every night takes one around a third of the way in (or before the lair; a boss night that starts at her door, once her part is settled); the DM picks what the heroes do meanwhile: nothing, a short rest, a long rest where the room allows it, or research (+2 on the next related roll). A thought answered with a snack or an early break brings it forward to the end of that room (`night.break_soon`); only `maybe_break` sets `had_break`. A night more than a quarter of an hour past the end agreed at Session Zero is said at the table (`night.LATE_LINES`) and costs Trust in the report; `night:ran_late` is the one clock the table, the goodbyes and the report read. |
| `game/ui/night_view.lua` (speed, roll banner, `VOICE`, `become`, `draw_replay_hud`) | Game night's controls and readouts (November 4): Pause / 1x / 2x / 4x top right; a roll's total big over the roller; caption tags for who you're talking to; a player speaking in character turns into their hero (`main/people/person.script` `become`); inspiration offered on a big moment and given from the tile's button; the report's Look replays fights with health bars and acts. Moods carry over between weeks (`score.start_carry`). Notes only the DM knows (the token you keep, a find you move, a room you wing, content kept off screen as agreed) take the `screen` style: a "BEHIND YOUR SCREEN" caption in a quieter colour (`night.screen_note` turns a "dm" line that says "behind your screen" into one). |
| `game/model/table_life.lua`, `MODULE.table_life` | Table life (November 4): small moments that play themselves in a room's quiet stretch (after the look round, or after its fight): a friend pokes at a curio on the board (`curios`: the book's room features in our words, or invented where the book is thin), a small die rolls on its own (`tiny_roll` event, drawn small over the tile), and the DM answers dull, detail or lore by the total; questions for whoever's in the room (`npc_questions`), and table bits (a snack, a cantrip, a souvenir, haggling with Telpur for real Francs). Only a natural 20 or 1 makes a card (`tl_crit`, the harmless answer first), and only with small-moment crits on (`campaign.small_crits`, the toggle under End session). Caps: `PER_ROOM`, `PER_NIGHT`; none at 4x (`night.fast`), one at 2x; each curio once a prologue (`adv.tl_seen`). A friend's reaction follows the answer you gave (each curio's `react` by `dull`, `detail`, `lore`, or `any`); a curio nobody's described gets its `see` line first; a natural 1 is the room's own `scare` (no lasting harm, never outside the museum); a question's crit lets the person `slip` something or answer what they `misheard`. Small moments wait until the room's danger is settled (`danger_ahead`; `museum_night.quiet_stretch` plays them after the room's last moments), and none comes from a hero who wandered off. `tools/tests/table_life_check.lua`. |
| `game/model/items.lua`, `game/ui/sheet_view.lua` | Each hero's one inventory (the second playtest review, F10): `campaign.items` owns everything they carry (the rules' magic items, the module's things with `carry`, healing potions), one holder each. `adventure.apply` gives what an option hands over to the hero whose choice it was; what someone owns leaves the gift shop's shelf (used up, it can be bought again); `items.use` and a moment's `mus.use` use it up; `holds` and `holds_here` test it; the sheet lists it under CARRYING with what each does; `items.start` moves an old save's flags, marks and holders into it. Every line that says who has something reads it from here. Round three: a thing's `from_fondest` gives it to the hero that person likes best, and its `handover` words show it given at the next night's start (`museum_night.between_gifts`); the lifted quiver is `opt_value = "arrows"`, arrows without the slime, burning on ranged hits only (`game/rules/museum.lua`). |
| `game/model/fight.lua` (`record`, `QUESTIONS`), `game/model/night.lua` (`at_hand`, `headache_ok`) | What happened in a fight, for the lines after it (F13, F14): `night.fight_record` (a heal on someone down or nearly, two heroes on one foe, a close call), `f.happened` (a Bless, a grapple, a fighter in melee) for a rules card's `fight_needs`, and `night.rules_question` (`fight.QUESTIONS`: a condition worth looking up). `night:at_hand()` is the heroes in this scene: one who split off (`split_party`) doesn't act, roll, bicker or poke at things in the scene they left; every picker of who acts uses it. A headache card's `needs.calm` keeps it out of a room with danger in it, and `needs.every = n` (with `every_key`) to once in n sessions. |
| `game/model/events.lua` | The event log (wave 2, R7 and R14): one list, saved with the campaign (`campaign.events`), of what happened in the adventure: who did what to whom, where, in which session, who saw it, and the earlier event it follows from (`from`, with `how` = "therefore" or "but"). It's the one source of truth: when two systems need a fact, both read it here. Who writes it: `items.lua` (every thing changing hands, how and from whom), `adventure.lua` (marks on and off Euryale's card, a deed for or against one of the museum's people), `museum_night.lua` (rooms walked into and why, the moments and what made them possible, Francs found, a roll that turned a moment), `night.lua` (every fight and how it ended, a hero going off alone), `ideas.lua` (the friends' own ideas) and `people.lua` (word passed on). A link is its writer's to make, and only for a real cause: a fight follows from the choice that started it, a roll that went wrong or the talk that ended her part, and a room's own fight, one that came whatever they did, follows from nothing. `events.chain` tells a session as so and but (a link word only right after the clause it follows from; of two beats from the same cause, the one that moves the story first), `events.measure` gives the share of beats linked and the longest unlinked run; the report and the journey read the chain, and the sims print the measure. `events.start` writes an old save's rooms, fights, marks, packs and favors into the log once. The words a beat is told with are the adventure's (`MODULE.beats`: `words`, `rooms`, and each card's options). Round three: the night's losses lead the report's chain and the next night's "Last time" (`events.lead_beats`, `events.losses`: a death, a wipe, an ally lost, friendly fire that dropped someone, then the downs merged per hero). A party moment carries its `backers`, and a painting's moment the `gift` that came out. Every Franc into the pool is a `find` (a ruling's, a small moment's and a favor's between sessions too, `between = true`), every Franc out a `spend`, a pocketed thing a `pocket` (with `char` and `returned`), a promise kept a `promise`: the pool on any night is the log's ins minus outs. `events.chain` tells a plain step into a room as where the next thing happened ("In the entrance hall, they..."), a fight told after the choice that started it by how it ended (its `tail`), drops a beat that repeats its cause (`MODULE.beats.same`) and folds the night's Francs into one "Along the way" line. |
| `game/model/people.lua`, `game/data/museum/people.lua` | People who remember (R11): Flitwidget, Telpur, the Lecturer, Euryale and the companions each hold an opinion of each hero and of the party (hostile, wary, neutral, warm, devoted), read from the log through them: the deeds they saw or were told about, by general rules (`people.WEIGHT`; the module writes the exceptions, like a rat who doesn't mind thieving). Their lines (`MODULE.people_lines`) are picked most specific first by conditions `adventure.test` reads: `opinion = { who, of, at_least, at_most }`, `knows` and `not_knows = { who, kind, by, to, whom }`, and `event` (it's in the log). What it changes: Telpur's prices (`people.price`: a Franc or two more after a theft, one off for friends) and his refusals, Flitwidget's thanks and a reward docked for the breakages, and the Lecturer's report upstairs (`museum_night.lecturer_report`, `people.pass_on`: what he hears through the floor reaches Euryale every night he's still lecturing, and she opens boss night with it). Round three: `knows`/`not_knows` take `outcome = "got" | "caught"`; `people.spots` covers someone seeing their own stolen thing in a hero's hands (Telpur at his counter, or along for a fight), and they know it from then on. |
| `game/model/ideas.lua` | The friends' own ideas (R12) and the pickpocket slice (R13): in a room's quiet stretch a friend in the scene reaches for something on their own (ask, take, help, follow, hide, poke) aimed at what's there: a person, what they carry, a shelf, a curio. Each friend scores the pairs from their player type, class, hero's reason for coming, how tonight's going and what the person thinks of them (`MODULE.ideas`: who likes each verb, what each person carries, the words). Most just happen on a small die. Lifting something comes to you as a card while the night has a call to spare (allow, roll, or no; otherwise the dice decide in the open, and on the first night always); a miss is a theft seen, in the log with its witnesses, and what's taken goes in the hero's pack. |
| `game/model/night.lua` (`gentle`), `museum_night.GENTLE_STOP` | A gentle first night (R6): on the adventure's first night (`night.gentle`, unless tips are off) the DM gets the story's own calls, the break and the wrap, one big roll to rule on, one thought and at most one rules question; a fight's calls, finds behind the screen, the table asking you and small-moment crits wait for the second night, every kind of call has a tip the first time, and a first night that's had its one more room ends there. |
| `MODULE.showdown.escape`, `adventure.reward_gold`, `adventure.escape_cost` | Letting Euryale get away costs something you can see (R5): half the reward. The showdown board says so, every option that lets her go (`escape = true`) and the nudge to it say so, and Flitwidget's thanks pays it. Round three: the reward is real gold, not Francs, and one number: `adventure.reward_vars` (`{gold_word}`, `{gold_up_word}`) for every line that says it, `adventure.reward_why` for the report. Flitwidget says it first, docking names the real reason, the haggle is `gold_up`, an escape pays half. |
| `game/model/museum_night.lua` (`lair_losses`, `first_pick`, a card's `owner`, an option's `best` and `by_holder`) | Round three: what's destroyed stays destroyed (`lair_losses`: an ally smashed or burnt out comes off her card for good, a lost fight's fallen foes stay fallen). A card's `owner` names the card whose moment handed the thing over; an option's `best` (skills) picks the one best at it among its backers; `by_holder` is done by whoever carries the thing; `first_pick` keeps the friends' first-pick promise. What a hero pocketed comes back at the thanks, by them while they're that seat's hero and can act, else through a friend (`WORLD_LINES.pocket_back_for`). A room's callbacks are said once each (`adv.cb_said`, `M.callbacks`), and a trip back says the ones that came true since. |
| `game/model/museum_week.lua` (`CHAT`, `write_chat`, `night_lines`), `MODULE.chat`, `MODULE.chat_news` | The group chat written from the log (round three): downs counted truly, a lost fight, a theft caught, the moment that made or spoiled the night in the party's own words (never a card title), one post for whoever found what they came for, good news the table never heard; each room's posts only say what happened there, replies answer the post, and a sad week (a death, a wipe, an ally lost or a lost fight: `museum_week.somber`, from the log) has no jokes or small talk. |
| `game/model/intros.lua` (`asks`) | Session Zero's lines and veils said at the table after the first night's introductions (round three: `ASKS_OPEN`, `ANSWER`), so the night's reminders quote something everyone heard. |
| `game/model/voice.lua`, a cast card's `seen`, `wake`, `dormant` | Who may hear a line (Conner's November 4 notes, the root-cause doc's class 1): a "dm" line is captioned as what it is (`voice.of`: words you say, your own doing, what you hear from the table, the story told), Euryale's thoughts upstairs and other notes are behind your screen (`voice.UNHEARD`). A foe that looks like part of the room says nothing as it opens (`seen = false`) and its `wake` line comes as its fight starts; a `dormant` one (the knight) has no mini on the mat until it climbs out. At a fork the friends say where they'd go and your read of them is a hunch behind the screen (`museum_night.fork_read`), as good as you know them. A miss ruled "they learn from it" waits on `campaign.learned` for that hero's next check (`night:take_learned`). |
| `night:walk`, `night.toward`, `night:split_off`, `night.worry`, `night_view.stage_opening`, `night_view.LAYOUT` | Conner's November 4 notes, second pass: a walk with no way round goes as near as it can and never through a wall, a check rolled elsewhere is walked to first, and the table lifts a mini that's re-staged more than a step away rather than sliding it; an ally the party brought is picked back up after a fight. A split party cuts to each one alone (a small roll, +1 on their next check) and regroups at the scene's end. A friend's face and tile follow their hero's state (`night.WORRY`); the first night starts happy (`score.FIRST_NIGHT`). A night opens on the board where they stopped. The caption, the friends' speech above their tiles and the IN/OUT OF CHARACTER tag each have their own band; the death-save card sits on the dying hero's tile. Poking around is an Investigation roll shown on the find card (`museum_night.FIND_DC`). The snacks and the coffee go down with the table's clock (`ambience.night_event`, `main/snacks/snacks.script`). |
| `game/ui/kit.lua` (`cut_hook`) | Text cut short shows the whole of it on hover (round three): `kit.ellipsize` remembers what it cut, `kit.text` calls `kit.cut_hook` (gloss.lua's card); `opts.full = false` turns it off. |
| `game/data/museum/fidelity.lua` | The book's structure as data, room by room, each fact with its page in the reader's PDF (page numbers only, our words): what the players `sees` walking in, the `secrets` (the `words` that give each away, what `reveal`s it, `shows`: the line that is the moment), the `foes` (how they `start` and what `wakes` them, where they stand by the board's place), `people`, `doors`, `traps`, `items` and the paintings. What the game added is marked `ours = true` with what the book has instead. `tools/tests/book_check.lua` holds the module, cards, boards and whole prologues to it. |
| `game/model/secrets.lua`, `MODULE.secrets` (`game/data/museum/secrets.lua`), `MODULE.told` | Secrets and what the table knows (November 6, Conner's calls: reveals cost nothing, the friends dig by their kind of player and their clues, each hero's knowledge tracked, the prep board shows the ways out). One record per secret: `what`, `page`, `type` (person, document, place, body, item, creature: its usual ways out, `secrets.DEFAULTS`), `held_by` / `on`, `hint` and `tell` lines, `theory` (a friend with the hint, out loud), `paths` (kind check, ask, read, see, spell, perform, trade, steal, event: skill and DC, gives hint, known or a part, `needs = "hint"`, `book = true`, `tells`, `flag`, `after_fight`), `parts` and `needs` (told a piece at a time: the tablet), `about` (what the friends call it), `weight`, `major`, `covered_by`. What's known: `campaign.adv.known[key]` with the table's level, what was said out loud, each hero's, how and by whom; `secrets.learn`, `event` (play shows it), `share` (a hero back from alone), `catch_up` (each night), `plant`, `hold`, `ask` (the DM's Reveal now / Drop a hint, said at the next beat: `ideas.dm_asks`). `told.lua` (the names: masks, `told` / `not_told`, now per hero) sits on it; `adventure.test` adds `hinted`, `not_hinted`, `part`. |
| `game/model/ideas.lua` (`find`), `game/data/find_out.lua` | The friends dig (November 6): ways of finding out by what holds the secret (talk round, lean on, booming voice, bluff, read them, sing, pay, listen in, ask, Detect Thoughts; study, Comprehend Languages; search, look, Detect Magic; examine, Speak with Dead; Identify; recall, watch), each with who loves it, the class it suits, and three ways for every line. Scored by kind of player, class and spells (`pc.rituals`), the clues they hold, a curious default and who's dug most. A book path rolls its DC; an improvised one is the DM's card to make up. At a room's start (after the look round) and in its quiet stretch, before the small moments; `FIND_PER_ROOM`, `FIND_PER_NIGHT`. A hero alone by a place can find one there (`night:split_find`). The tablet is read a line at a time while someone holds the guardian off (`museum_night.ritual_read`). |
| `game/model/shown.lua` | Shown before named (November 6): every place and feature on a room's board is public once it's described; a friend's line naming one nobody has gets its description first (`night.lua` emit), and people are named once the table's heard who they are (`shown.named`). |
| `game/ui/npc_view.lua` (`draw_secrets`, `draw_give`) | The person sheet's WHAT THEY KNOW: each secret, where the table stands, every way it could come out, Reveal now, Drop a hint, Hold it back; give them a secret to keep. The prep board's room rows list each room's secrets with their ways out on hover. A planted item asked for is asked for as help, and stays secret until it's handed over. |
| `MODULE.session_zero.told`, `night_view.zones` | What the table knows going in (the premise, shown on Session Zero's screen): the knowledge check's start. The night's zones (the caption and its voice tag, the room's title, the big and small rolls, the side card, a toast), each with its `rect`: every speech bubble steps round them (`place_bubbles`), and a new piece that can sit over others adds itself there. |

## Where things live

| Path | What it holds |
| --- | --- |
| `game/data/` | All content as plain data: players, the adventure's rooms and cards, scenes, dialogue. Safe to tune. |
| `game/model/` | The simulation, engine-free: prep, game night, the friends, the adventure, saves. |
| `game/rules/` | The SRD 5.2.1 rules engine, engine-free: dice, creatures, battles, spells, encounters. |
| `game/ui/` | The screens, drawn from GUI nodes through `game/ui/kit.lua`. `game/game.gui_script` ties them together. |
| `main/`, `render/`, `materials/`, `assets/` | The 3D table scene. Much of it is generated; see "Generated files". |
| `tools/tests/`, `tools/sim/` | Headless tests and simulations. |

## Ground rules

- **The existing design comes first.** Fit new ideas around what's built and documented. Don't replace a
  system wholesale unless asked.
- **Model and rules code stays engine-free.** No `gui.*`, `go.*` or `msg.*` in `game/model/` or `game/rules/`,
  so the whole campaign can run headless in the tests.
- **No require cycles.** Defold's builder refuses them. When a module needs one that requires it back, use
  `require("game.model.util").lazy("game.ui.other")` and call it at use time. The builder only packs modules
  a script reaches through a literal `require "x"`, so a module reached only through `lazy` must also be
  required literally somewhere (`game/game.gui_script` does it for `game.model.museum_night`), or the
  built game stops with "module not found". `tools/tests/require_check.py` checks both.
- **No globals.** Every function and variable is `local` or a field of the module's `M`.
- **Museum saves must keep loading.** The autosave and the three slots (`museum_save.txt`, `museum_slot1..3.txt`)
  point into the game data only by card (`{"components", "mus_*"}`); `game/model/save.lua` migrates anything that
  moves, and `tools/tests/save_check.lua` checks it. (Saves from the October game no longer load.)
- **Generated files are not hand-edited.** Meshes, textures, sprites, fonts, `main/main.collection`,
  `main/props/`, `main/board/`, `main/scene_data.lua` and `game/ui/metrics.lua` come from `tools/*.py`. Change the
  generator and rerun it (README, "Regenerating assets").
- **Player-facing text is plain and warm.** Short sentences and everyday words, no designer jargon.
  Every screen says what it's for. Every game word on screen explains itself on hover: the glossary
  (`game/data/rules_glossary.lua`, plus an adventure's own `MODULE.glossary`) is on for every screen by
  default (`kit.gloss_default`); speech and the chat turn it off (`gloss = false`).
- **The prototype notice stays.** Every launch opens on "Before you play" (`game/ui/intro_view.lua`) until the
  player clicks Agree. Tests agree to it first (`tools/tests/museum_smoke.lua`, `game/ui/autotest.lua`).
- **Say only what's true (November 2, `docs/design/2026-11-02-cause-and-effect.md`).** A line that asserts
  an outcome reads it from state or carries a condition (`when`, `text_if`, `read_if`, `line_if`, `win_if`).
  Every flag set is read by something, every mark changes boss night, a log that hurts someone hurts them
  (`mus.hurt`), and anything picked up works later (`MODULE.items`). One system owns each beat (a prize,
  an ending, a death); the rest record. The truth test fails otherwise.
- **Any adventure, not the museum (Conner, November 6).** The museum was a prototype for a system that plays any
  adventure he uploads or we write together, and it may be deleted. Shared code and checks ask the current adventure
  (`game/data/adventures.lua`) and never need the museum's data; what one adventure alone needs is its rule module
  (`game/rules/<id>.lua`). The end goal is an adventure creation tool in the game (lore, people, maps), and
  `docs/design/adventure-standard.md` is the format it writes, so a record has to be something a DM could fill in by hand.
- **Players announce, the DM answers (Conner, November 6: a hard rule).** The DM never says what a hero or a friend
  feels, wants, thinks or decides ("Pip feels", "Jess wants"), nor how a hero looks or sounds (grins, mutters):
  that's the player's to play. What a hero does by choice is said by their player first, in character ("I'll go
  over the pond, carefully."), and the DM's line is the answer: what happens. `game/model/agency.lua` does it for
  every line the DM says (`night:emit`): a hero's move in a DM line becomes their player's announcement (or is left
  out when they've just said it), and a feeling is never said; `tools/tests/agency_check.lua` fails any line that
  had to be dropped, so it's rewritten where it's written. Write a hero's choice as the player's line, and the DM's
  as what happens.
- **Seat order, and words from the seat (Conner, November 6).** The tiles along the bottom, and every row of the
  four, are in seat order, left to right as the DM sees the table (`game/data/players.lua`'s `seats`,
  `panels.seated`). A friend's words come from where they sit at the table, in or out of character, never from
  their tile (`night_view` `anchor_xy`: their head, or the edge of the screen toward their seat).
- **One shape for conditional text (November 6, `docs/design/adventure-standard.md`).** A text field is a plain line
  or a list of `{ when = {...}, text = "..." }` entries, most specific first, ending on a plain line; read it with
  `adventure.say(campaign, value, opts)` or `adventure.text(campaign, record, field)`. New data uses only this shape.
  The museum's older `*_if` fields (text_if, read_if, line_if, win_if, lose_if, got_if, why_if, thought_if, ask_if)
  are read through it until they're rewritten. Every flag set is an event in the log (`adventure.watch_flags`);
  `adv.flags` is the view the code reads.
- **Three or more ways for anything said every week.** Anything said every week or every fight comes three or more
  ways through `night:fresh(list, key)` (never twice running; `once` means once a session).
- **Therefore or but, never and then.** Every beat a night plays should follow from an earlier one ("therefore")
  or complicate it ("but"), and the recap tells the night as that chain. A moment that just comes next ("and
  then") is a weak moment. This is Trey Parker and Matt Stone's writers' room rule. The event log records it
  (`game/model/events.lua`: each event's `from` and `how`), and a link is only for a real cause: never stitch a
  beat to whatever came before it. `roadmap_world_check` fails on a false one and prints the baseline. The Main
  Campaign Design doc (https://claude.ai/artifact/UjVzYSuuqJmGo2FDs4UmSw) has the design.
- **The same seed plays the same way.** A loop whose order changes what happens or what's said walks
  `util.sorted_pairs`, never `pairs`; the same seed gives the same event log every run (`roadmap_table_check`'s
  DET plays seeds three times over).
- **One person is never "they".** The heroes (Thessaly she, Brannoc he, Pip she, Oswin he, and each new
  character's own), the friends at the table (Mara she, Dev he, Jess she, Sam he) and the museum's people
  (Flitwidget he, Telpur he, the Lecturer he, Euryale she, Exhibit B he: a cast card's `pronoun`, a companion's)
  have their own. A line that names one says `{actor_their}`, `{char_they}`, `{Actor_they}` (the hero),
  `{friend_their}` (the friend `{actor}` names) or `{Name_they}` for any name in the fill (`util.fill`). A group
  stays "they". The D6 scan in `roadmap_table_check` reads every line and every screen for it.
- **The adventure owns its fiction.** Session Zero's pitch and asks, the prep notes, the people's memory,
  the gifts, the recap's words and its magic items come from the module (`MODULE.session_zero`, `content`,
  `prep_notes`, `memory`, `talk`, `keepsakes`, `recap_beats`, `magic_items`); shared systems fall back to
  neutral words, never another story's.
- **The prologue is strictly the book.** Nothing from the old Silent Bells campaign (Ilsa, Kessrick, Millbrook, the
  Kettle...) may show: the shared data holds none of it since the purge, `adventure.foreign` lists the old names and
  `game/data/fiction_words.lua` the old world's places, people, creatures and callbacks (`adventure.fits`), and the
  museum tests fail on any that slip back in. Shared lines about things the museum doesn't have (a goblin, a mayor)
  wait for an adventure that does. Never copy the book's text; paraphrase it.
- **The book's structure is data (class 4).** What each room shows, keeps secret, wakes and locks, where everyone
  stands and what each thing does is in `game/data/museum/fidelity.lua` with its page. A change to a room checks its
  sheet (`book_check`); something the game adds is marked `ours` there, never passed off as the book's.
- **The friends know only what they've been told (class 5).** A friend line that names a person, creature, room or
  item in the adventure waits until the table has heard it said this campaign; nothing carries over from another
  campaign (`knowledge_check`).
- **Every secret is a record with its ways out (November 6).** Anything the DM knows that the table doesn't goes in
  `MODULE.secrets` with its page, its holder, the DM's hint and tell lines and two ways out or more of two kinds
  (`secrets_check` DATA). A line that names it waits for it (`when = { told | hinted }`, or a `covered_by`
  condition); a place's or a thing's name never names one. Reveals cost nothing, and the DM can always reveal, hint
  or hold back from the person's sheet.
- **Things are described before they're named.** A place or feature on a room's board is public once it's been
  described (`shown.lua`); a person once the table's heard their name. Board spot names and lines are what the
  heroes see: DM-only facts go in a secret, never in a spot's name or line.
- **Nothing covers text that's meant to be read (class 7).** A piece that can sit over others on game night has a
  `rect` in `night_view.zones`; `overlap_check` measures every screen and every step of the night.

## Checking your work

Any Lua 5.1+ or LuaJIT interpreter runs the tests from the project root. On this branch, before you commit, run at
least:

    for s in 1 2 3 4 5 6 7 8; do lua tools/tests/museum_smoke.lua $s || break; done
                                          # the whole prologue through the real UI against a mock GUI
    for st in careful random careless; do for s in 1 2 3 4; do lua tools/sim/museum.lua $s $st || break; done; done
                                          # the prologue headless, three kinds of DM
                                          # (add "log" after the style to read every line the table hears,
                                          # every roll with its die and every attack with who swung at whom)
    lua tools/tests/map_repo_check.lua    # the map repository and the open floors
    lua tools/tests/museum_truth.lua      # cause and effect: every flag read, every mark does something, logs
                                          # that promise an effect have it, whole prologues against what's said
    lua tools/tests/thoughts_check.lua    # the friends' thoughts: lines, answers, Empathy, whole prologues
    lua tools/tests/standing_check.lua    # the DM's recap: sides, people's lines, who's drawn to whom, the Table rows
    lua tools/tests/ties_check.lua        # ties and locks: block and open, refusals, a tied mark, saves, whole prologues
    lua tools/tests/barks_check.lua       # fight barks fit the moment; a handed-off killing blow is told, not re-swung
    GLOSS_AUDIT=1 lua tools/tests/museum_smoke.lua 1   # every game word on screen has a hover (tools/tests/gloss_words.lua)
    python3 tools/maps/build_maps.py --check  # every map spec builds: on the mat, starts free, walls closed
    lua tools/tests/museum_fights.lua     # the museum's monsters on the rules engine (about 80s)
    lua tools/tests/rules_cases.lua       # hand-checked rules, the museum's monsters among them
    lua tools/tests/save_check.lua        # saves load back, mid-prologue too
    lua tools/tests/playtest_nov3_check.lua 8   # the November 3 notes, played: whole prologues, each fix seen in play
    lua tools/tests/table_life_check.lua  # small moments: they happen, never in fights or at 4x, crit cards only when on
    lua tools/tests/roadmap_truth_check.lua   # the round-two truth fixes, played: whole prologues, three DMs, and cases
    lua tools/tests/roadmap_words_check.lua   # the round-two word fixes, played: whole prologues, three DMs, and cases
    lua tools/tests/roadmap_table_check.lua   # wave 2 at the table, played: the friends choose differently, Euryale's
                                          # escape costs, the gentle first night, everyone's own pronouns, Exhibit B
                                          # on the board, wave 1's leftovers, the same seed three times (about 50s)
    lua tools/tests/roadmap_world_check.lua   # wave 2's world: the log against the packs, her card and the fights,
                                          # people who remember, the friends' ideas, the pickpocket slice, the
                                          # chain's so and but with no false causes, and the therefore-or-but baseline
    lua tools/tests/round3_state_check.lua    # the third playtest's state and fights: who can't act doesn't, friendly
                                          # fire, destroyed stays destroyed, the big moments told, picks steer the
                                          # foes, losses lead, the break and the clock (about 15s)
    lua tools/tests/round3_world_check.lua    # the third playtest's world: one owner per action, only what's owned
                                          # fires, the money adds up, memory and knowledge are true (ALL=1 lists all)
    lua tools/tests/round3_words_check.lua    # the third playtest's words: votes from the moment, looking round,
                                          # the chat from the log, pronouns, the chain as a story
    lua tools/tests/round3_screens_check.lua  # the third playtest's screens: nothing cut without a hover, the prep
                                          # board and report in full, CARRYING, the stats explained, the engine
                                          # screenshots' fixes (about 40s)
    lua tools/tests/final_facts_check.lua     # the final pass's facts: the Mech, stone, deaths, money in the recaps
    lua tools/tests/conner_nov4_check.lua     # Conner's November 4 notes: who may hear a line, the players decide
                                          # and say so, claims with something behind them, never "last time"
    lua tools/tests/conner_nov4b_check.lua    # the rest of them: real walks, faces that fit the moment, the Table
                                          # view and the screen's bands, a split party, the find roll, the
                                          # opening board, the snacks, and the general scans for classes 1 to 3
    lua tools/tests/book_check.lua        # the museum against the book's structure (fidelity.lua): starts, places,
                                          # doors, traps, secrets before their reveal, the paintings, the items
    lua tools/tests/knowledge_check.lua 4 # the friends name only what they've been told; a second campaign in
                                          # the same process plays as if it were the first
    lua tools/tests/schema_check.lua      # the adventure's data has the shape the schema says: no table in the wrong place, no unknown field (first)
    python3 tools/import/copy_check.py museum --book OUT   # our words, not the book's: no run of 8 words from the reader's own PDF (read first with tools/import/ingest.py BOOK.pdf OUT, outside the repo)
    ADVENTURE=sheep lua tools/tests/schema_check.lua; ADVENTURE=sheep lua tools/tests/secrets_check.lua 0   # the Sheep Chase's data
    for st in careful random careless; do for s in 1 2 3 4; do ADVENTURE=sheep lua tools/sim/museum.lua $s $st || break; done; done
                                          # the Sheep Chase headless, to one of its endings
    for s in 1 2 3; do ADVENTURE=sheep lua tools/tests/museum_smoke.lua $s || break; done
                                          # the Sheep Chase through the real UI (the museum's own rooms and people skipped)
    ADVENTURE=sheep lua tools/tests/agency_check.lua 1   # players announce, the DM answers, in the Sheep Chase too
    lua tools/tests/agency_check.lua 2    # players announce, the DM answers: no hero's move or feeling said for them, seats in order
    lua tools/tests/handoff_check.lua     # adventures tied together: the party, the log, lore, the past and open threads carry over; a fresh start has none
    CARRY=1 lua tools/tests/museum_smoke.lua 1   # the museum, then "Carry on" into the Sheep Chase through the real UI
    lua tools/tests/sheep_rules_check.lua # the Sheep Chase's own rules: Noke's spells in the yard, his guards, the bed dragon and its rider
    lua tools/tests/sheep_inn_check.lua   # the inn's upstairs and cellar: the fork, Sir Luenn's ring each way, the rats, Teddy's
                                          # bottle, the road out leaving them behind, the drover for a party from the museum
    lua tools/tests/dm_bag_check.lua; ADVENTURE=sheep lua tools/tests/dm_bag_check.lua
                                          # the DM's bag, its books, people's pockets and lore tips, both adventures
    lua tools/tests/secrets_check.lua 4   # every secret from the data: real ways out, friend lines that wait,
                                          # each found in whole prologues, nothing known early (about 4 minutes)
    lua tools/tests/overlap_check.lua 8   # nothing covers readable text, measured on every screen and every step
                                          # of game night (about 3 minutes)
    python3 tools/tests/require_check.py  # no require cycles
    python3 tools/validate.py             # every Lua file parses, every resource exists

Then run the checks for the area you touched. The README's "Tuning and tests" section lists each one, for
example `lua tools/tests/rules_cases.lua` for the rules, `lua tools/tests/rest_check.lua` for rests.

`DUMP_DIR=out lua tools/tests/museum_smoke.lua 1` also writes every screen's nodes, so you can see what a screen
shows without the engine.

## Building

- **In the Defold editor:** open `game.project` and press Ctrl+B.
- **From the command line** (Bob 1.13.2 needs Java 25):

      java -jar bob.jar --root . --platform x86_64-win32 --archive \
          --settings tools/playtest/playtest.ini build bundle

- **Real engine on Linux:** `tools/tests/engine_check.sh` plays the game with Xvfb (it needs `BOB` and `JAVA` set).
  On this branch, `MODES=8 TIMEOUT=2500 tools/tests/engine_check.sh out` plays the whole prologue and screenshots
  each screen into `out`.

## Status

v2's prologue plays end to end through the real UI, the real engine and headless: every seeded run reaches an
ending in three to five sessions, and the fights use the book's own monsters (`game/rules/museum.lua`). Every room
plays on its own board drawn from the book's maps (`tools/maps/`). The museum's monsters and people stand on their own paper
minis (`tools/gen_sprites_museum.py`). What's open: the "just the adventure" mode, and the full campaign that
follows the prologue.
The tie-and-lock editor is in (`game/model/ties.lua`); the museum sim (`tools/sim/museum.lua`) plays without locks.
The Wild Sheep Chase plays too (`game/data/sheep/`, its own rules in `game/rules/sheep.lua`), on its own or carried on
into from the museum's journey screen. Both have the DM's bag, its books and lore tips (`docs/design/adventure-standard.md`).
