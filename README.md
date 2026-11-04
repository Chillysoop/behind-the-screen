# Behind the Screen

A cozy DM simulator in Defold.

You are the Dungeon Master for four simulated friends. The game runs a real published adventure, *The Museum of
Nightmares* by Luke Russell (DMs Guild), as a one-shot prologue: Session Zero, why each hero came, then the museum
room by room for as many sessions as it takes, a boss night against Euryale the Gorgon, and a journey recap. The
adventure is data in the adventure (module) format, cut into pieces that remember: the party picks the way at
forks, each room plays its own moments, and every room can leave a mark on Euryale's card for the boss night.
Between sessions come requests, loose ends and favors; harsh calls land as fair when the table was warned. The
museum's floors are open: the party roams between the book's rooms and only goes back for a reason. Every room
plays on its own board, drawn from the book's maps in our own pieces (`tools/maps/`), and the DM's map repository
puts any map on the table. On game night you catch what the friends are thinking and not saying (how many is
your Empathy), read it with an Insight roll, and answer it or let it be. "Ties and locks" on the prep board lets
you bend the adventure: lock a door, a room, a person or a card until something happens, and tie a mark on the
boss's card (or a hero's reason for coming) to what the party does. A longer pre-written adventure will follow in
the same format.

See `AGENTS.md` for where everything lives and how to test it, `docs/OVERVIEW.md` for the game as a whole, and
`docs/design/2026-10-30-museum-v2.md` for the museum's design. The text adapts the book in our own words, for
private playtesting only.

**Branches.** This is `v2-museum`. `main` is still the October 20 build with the prototype notice. The October game
(the Silent Bells campaign, its story deck, valley map, factions and planner) was removed from this branch in the
November 4 purge; `v2-museum-before-purge` keeps it. The step-by-step rework of setup and prep from October 26 is on
the `step-by-step` branch, and Codex's guided edition is on `streamlined-edition`.

What's in it, by the milestones it was built in:

- **The adventure (v2):** the module format (`game/data/museum/`), the museum's map, rooms, moments, marks, people,
  prompts, showdown and endings, the prep board on the book's floor plans, the hooks page and the journey recap.
- **M8, the DM's craft:** one event log behind the recap and the report, dice jail and running jokes, death at the
  table, the killing blow and Heroic Inspiration, taking over (talking as a person, running the boss's turn), the
  five-part report and the map maker.
- **M7, ready for testers:** saving, the end-of-prologue survey, a one-click tester package, the playtest log and
  its analyzer, and the cozy pass: rain, music and sound, an evening that darkens as game night goes on, and a
  pizza and a bowl of chips that empty over the night.
- **M6, the social layer and progression:** Session Zero (tone, lines and veils, table rules), three table
  conflicts, and level-ups where every player picks their own subclass at level 3.
- **M5, the dialogue pipeline:** what the friends say comes from a library of AI-written lines you review before
  they ship, with a review mode inside the game (F4).
- **M4, game night at the table:** the night plays out on the battle mat. Paper minis walk, fight and fall over on
  the rules engine, the four players lean in, cheer, yawn or reach for their phones, and speech bubbles pop over
  their heads. You make 8 to 15 calls a night and roll big moments in front of or behind the screen.
- **M3, the rules core (headless):** SRD 5.2.1 combat for the Fighter, Rogue, Cleric and Wizard at levels 2 to 4,
  twelve subclasses, the SRD's monsters, the Cleric and Wizard spells to level 2, and a difficulty meter fitted on
  thousands of simulated fights (`game/rules/`). Every fight runs on it.
- **M2, the player status model:** every player's session meters and long-term bars, and Empathy that decides how
  precisely you can read them.
- **M0, the engine spike (the sandbox):** the 2.5D table under warm lamplight, with four camera zooms and a
  physical d20. Press F2 to switch to it and back.

## Run it

1. Open `game.project` in the Defold editor (1.13.2 or newer).
2. Press **Ctrl+B** (Cmd+B on Mac) to build and run. The game window can open behind the editor.

## Desktop shortcut (Windows)

**Behind the Screen - Play** on the desktop always opens the newest version: it rebuilds the game from this
folder whenever a file has changed, then starts it. The first build takes a minute or two; after that it only
rebuilds what changed, and if nothing changed it starts straight away. It uses the Defold editor you already have,
so the editor doesn't need to be open.

- The playable build lands in `bundle/`, the build log in `build/launcher/launcher.log`.
- If the game is already open, close it first so the newer version can be built.
- Moved the project or lost the shortcut? From this folder, run
  `powershell -ExecutionPolicy Bypass -File tools\launcher\play.ps1 -InstallShortcut` to make a new one.
- Something stuck? `play.ps1 -Rebuild` builds from scratch.

## How a session plays

0. **Session Zero** (once). Pitch the tone, hear each player's ask, set the table rules. Then **why each hero
   came**: each player has two of the book's hooks and leans toward one; you pick. A hook ties the hero to a room.
1. **Between sessions.** The group chat: the friends talk about the room they just played, someone asks you a
   question, and the week's prompts come in: a player's request (yes, with a laugh, no with a reason, or yes but
   it's dangerous), a loose end (where a card the party skipped turns up), a rules call to post or leave, and a
   favor (one way it helps, one way it hurts).
2. **Prep.** The prep board is the museum's floor plans. You have 10 hours: prep the rooms the party might reach
   (an unprepped room plays thinner), set the book's advice as knobs, and read each room's notes (who you'll voice,
   what to have ready). Talking to a friend costs an hour and tells you their mood. Spare hours go on a good night's
   sleep or a backup page, and up to two you don't use carry to next week. "Ties and locks" and the map repository
   are here too, with Euryale's card and its marks.
3. **Game night.** It plays out on the table (see below). The table picks the way at forks; you make the calls the
   book's moments need, read your friends' thoughts, and decide how big rolls land. A big roll can go in the open or
   behind the screen, where you can cook it. Cook too often and someone will ask to see the dice.
4. **The report.** The dice box first, then a recap you can edit, how each player felt, their meters for the night,
   how Commitment, Investment, Trust and Suspicion moved, the best moments, conflicts, and a gift if someone's heart
   is full. Once the party has played two nights at a level you can level them up from here.
5. **Boss night.** A showdown board (how Euryale opens, how far she goes), a talk, the fight and an ending. Then the
   journey recap and a short survey.

## Game night at the table (M4)

Each room goes down on the battle mat on its own board: its floor and walls first, then every other piece as the
narration names it. Captions along the bottom carry your narration; the players talk in speech bubbles (cream when
they speak in character, dark when it's table talk), and the people they meet talk from their minis. A player
speaking in character turns into their hero.

- **The way through.** At a fork the friends talk it over and settle where to go from what they want; you can only
  nudge when asked. After they pick, you decide what's there: the book's room, something improvised, or another
  prepped encounter moved in.
- **The rooms' moments** are the calls the book's scenes need, on cards that slide in. A card with a danger asks
  "Are you sure?" first, which counts as a fair warning.
- **Looking around.** Before a room's business the friends take turns walking over to places on its board and say
  what they make of them. A find or a trap there is your call behind the screen.
- **Small moments** play themselves in a room's quiet stretch: a friend pokes at a curio, a small die rolls on its
  own, someone has a question for whoever's in the room. A natural 20 or 1 makes a card only with small-moment crits
  on (the toggle under End session).
- **Thoughts.** A cloud over a friend's tile is something they're thinking and not saying. Click it to read it (an
  Insight roll), then answer it or let it be.
- **Quick checks** roll on the dice strip along the top and fill the scene's progress pips: gold for wins, red for
  setbacks.
- **Fights** run on the rules engine on the room's own board. Minis walk square by square, use cover and line of
  sight, lunge, flash red when hit, tip over when they drop and get swept off when they're beaten. Pieces of the
  room can come alive. Your own attack rolls show face down ("?") on the dice strip while they stay behind the
  screen; press H to roll them in the open. Fights bring their own calls: a hidden roll that would drop a hero,
  their last death save, a fight that drags on, the killing blow.
- **The break.** Every night takes one about a third of the way in; you pick what the heroes do meanwhile: nothing,
  a short rest, a long rest where the room allows it, or research.
- **Upstairs.** When Euryale's card gains a mark, the night cuts to her for a moment.
- **Big rolls** pause for you: roll in the open (the table trusts it) or behind the screen (you can cook it). Then
  you decide how the result lands: generous, straight or with a cost.
- **The players** sit around the table and show how they feel: leaning in, cheering, gasping, arms crossed,
  yawning, on their phone.

Pause, 1x, 2x and 4x are top right. The gentle timer (T) gives each card 15 to 45 seconds before the safe default
plays, if you want to keep the night moving; it's off unless you turn it on.

## The adventure

The museum is data, and the shared systems play whatever an adventure in this format gives them:

| Part | What it is |
| --- | --- |
| `game/data/museum/module.lua` | The rooms and the doors between them, each room's moments, knobs and second looks, the hooks, Euryale's marks, the requests, loose ends and favors, the people and what they remember, the showdown, the endings, and the adventure's own words for Session Zero, the prep notes, the chat, the gifts, the recap and its magic items. |
| `game/data/museum/cards.lua` | Its places, people, goals, snags and prizes as cards, and how the heroes play each goal. |
| `game/data/museum/table_life.lua` | The small moments: curios on each board, questions for the people there, table bits. |
| `game/data/maps/*.map`, `game/data/map_library.lua` | Each room's board, finished by hand from the book's maps and built by `tools/maps/build_maps.py` (`tools/maps/README.md`). |
| `game/rules/museum.lua` | The book's monsters' special rules (their stat blocks are in `game/rules/data/monsters.lua`). |

`game/model/adventure.lua` enters the adventure at startup (`adventure.enter`) and keeps its state in
`campaign.adv`: where the party is, the marks, flags and Francs, the prompts. `museum_week.lua` runs the week and
`museum_night.lua` the night; both read only the module's data, so a new adventure is new data. The shared lines
(the friends' dialogue, table habits, stock moves) are checked against the adventure's own world
(`adventure.fits`): a line about something the adventure doesn't have waits for one that does.

**Only what's true.** A line that says what happened reads it from state or carries a condition (`when`,
`text_if`, `read_if`, `line_if`, `win_if`); every flag set is read by something; every mark changes boss night.
`tools/tests/museum_truth.lua` plays whole prologues and fails otherwise.

## Session Zero, the table and leveling up (M6)

**Session Zero.** Before week 1 the table talks it through, and people say what they think, so every option shows
who likes it. Pitch a tone. Hear each player's ask: Mara draws a **line**, Sam asks for a **veil**, Dev and Jess ask
for **promises** (the adventure words the asks for what's in it). Set the table rules: the X-card, where your dice
land, how rules calls work, how long a night runs, what happens when a hero dies, and how harsh it gets. What you
agree to holds for the whole prologue: the prep board warns you when a room touches a line or veil, game night fades
veiled content out on its own, the X-card catches what slips through, breaking a promise costs Trust, and a harsh
call on a table that agreed to brutal lands as fair. The tone and the rules also decide which conflicts start warm.

**The group chat.** The prep board's left column. The friends talk about last night in their own voices, someone
asks you a question with replies you can send, and the week's prompts wait for your answer.

**Table conflicts.** Three can come up, each built from what actually happens at the table:

| Conflict | What builds it | How it's settled |
| --- | --- | --- |
| **The Pip show:** Jess fills every scene | Jess getting far more spotlight than the others; promising never to cut her scenes | Keep passing the spotlight at the table until it sticks |
| **Rules lawyering:** Dev wants rule of cool, Sam wants the same rules every time | Every rules call lands on one side; "by the book" and "rule of cool" at Session Zero make it worse; "quick call, look it up after" only works if you do look it up | Call a vote at the table. Posting a ruling you promised to look up calms it; leaving it breaks the promise |
| **Tone clash:** Mara wants the museum's mysteries taken seriously, Jess can't resist a joke | The Session Zero tone; jokes landing in Mara's serious moments | A night with a serious scene for Mara and a goofy one for Jess, and no jokes in hers |

When the spotlight or the rules conflict starts brewing, its card can turn up on game night. If it gets worse, the people in it lose
Commitment every week until it's settled.

**Level-ups.** The prologue starts at level 2. After two nights at a level the report (and the prep board) offers the
level-up; after four the table starts asking. At level 3 every player picks their own subclass, for their own
reasons: who they are as a player and what their nights have been like. You don't get a say. At level 4 everyone
takes an Ability Score Improvement. Game night fights use the new level and subclasses from then on.

## Saving, sound and the playtest round (M7)

**Saving.** The game autosaves to the museum's own file (`museum_save.txt`) after Session Zero, through prep and
after every game night, and you have three slots of your own (`museum_slot1..3.txt`). The title offers Continue
(the newest save), Load and New game; Save is on the prep board and the report. Quitting mid-prep comes back to the
same board; quitting during game night starts that night again. The save is the campaign written as data
(`game/model/save.lua`) and refuses a save from another build instead of half-loading it.

**The cozy pass.** Rain on the window and two quiet music loops (prep and game night) that crossfade; M turns the
music off. Clicks, cards, the d20 rattling in the tray, paper, chimes for crits and level-ups (all made by
`tools/gen_audio.py`). The light drifts from dusk at prep to late evening over game night, the window darkens and
the fairy lights come up, and big moments make the lamp swell. A pizza and a bowl of chips on the table empty over
the night and come back for the next session.

**First-session tips.** Someone who has never seen the game gets one short tip at a time on the first game night
(it plays itself, a friend's thought, your first call, where the die lands, cooking the dice, how a roll lands) and
the first report. Tips outline what they talk about and never block; doing what a tip asks moves it on, "Got it"
dismisses it, "Hide tips" turns them off for that campaign. They're data (`game/data/guide.lua`), saved with the
campaign.

**Any window size.** The game scales to fit the window (checked in the real engine at 1280x720, 1366x728,
1280x800 and 1920x1080, with real mouse clicks in a non-16:9 window). A window bigger than the screen can be
maximized.

**The playtest round.** In short:

    tools\playtest\package_playtest.ps1          # Windows: clean build, dev keys off, readme, zip in playtest\
    python tools\playtest\analyze.py playtest\logs   # every tester's log -> playtest_report.html and the verdict

The package is a release build with `tools/playtest/playtest.ini` over `game.project`: the draft dialogue still
plays (`drafts = 1`), F2, F3 and F4 are off (they're debug-build keys, and `playtest = 1`), and no debug ports open,
so Windows Firewall stays quiet. `tools/playtest/samples/` holds pretend logs to try the analyzer on.

## A real session at the table (the real-session pass)

**Who's who.** Four tiles along the bottom of game night, one per player: their face (it follows how they're
sitting and reacts to big moments), their character's paper mini, "Pip, Rogue 2", their tell, Fun and Spotlight, hit
points and Armor Class, their class's resources as pips (spell slots, Channel Divinity, Second Wind, Action Surge),
and their last roll: the d20 tumbles, lands, and shows the skill, the total and the DC or Armor Class. Whoever's
speaking lights their tile and their mini's outline: gold in character, blue out of character, purple thinking.
Click a tile for that character's sheet.

**Rolls like a real table.** A check is d20 plus the character's skill modifier (SRD 5.2.1 proficiencies and
Expertise, `game/rules/skills.lua`) against a DC: "Pip, roll Sleight of Hand. DC 10." Whoever's good at it and short
on spotlight steps up. On a big roll the player throws the die; your call is whether you say the DC out loud or keep
it behind your screen, and cooking their roll means moving the hidden DC. Some checks (noticing an ambush, reading a
liar) are secret: you roll those behind the screen. A roll's total shows big over the roller.

**Your notes** (N, or the Notes button): the museum, upstairs (Euryale), this session, people, the session log and
the party with their character sheets. Game night waits while they're open. **The Story and Table sidebars** (S on
game night) recap where each side of the story stands and each friend's reasons and leanings. Click a person's name
in any line for their sheet: who they are, their line now, their stat block and what's in their pockets.

**Character sheets** from a player's tile, their card on the prep board or the notes: Armor Class, hit points,
abilities and saves, all 18 skills with proficiency and Expertise marked, attacks, spells and slots, every feature
in full, and gear. The numbers are the rules engine's, the same ones the table rolls with.

**Fights you can read.** Hit point bars and conditions over every mini (a coloured ring at the base for the effect
that matters most), everyone rolling initiative and the turn order along the top, attack numbers in the log ("18 vs
AC 15 for 9 (1d6+3)"), spell areas flashing on the mat and lasting zones (Web, Grease) staying there until they end.
Fight barks fit the moment: "natural twenty" needs a 20, "who's next" needs foes left. The report's Look replays a
fight with health bars and acts.

**The map maker** (from the map repository): your own maps on the 20 x 13 grid, built from set pieces that carry
their SRD 5.2.1 rules. Tables, benches and crates are Half Cover; pillars, statues and trees Three-Quarters; walls
and bookshelves Total Cover (no line of sight); a door opens as someone walks through it (click it again: open,
locked); rubble, brush and webs are Difficult Terrain; ice is Slippery Ice; torches, braziers, candles and lamps
light a map set to Dark. A map you make can go on the table for a room, a side room or the next scene.

Everything at the table runs on the rules engine (`game/model/sheet.lua`, `game/rules/`), so a mode where real
players roll their own dice could plug into it; the game itself stays simulated.

## Dialogue (M5)

Every line the friends say lives in `game/data/dialogue/` (the museum's people have their own lines in the module):

| File | What it holds |
| --- | --- |
| `triggers.json` | The 61 moments that need a line (a crit, a called-out cooked roll, a level-up pick...), who says each, whether it's said at the table, in character or by the person the DM voices, the fill-ins a line may use and its length limit. The report's fun tiers get lines of their own. |
| `voices.json` | A voice sheet for each speaker (the four friends, and the plain voice for anyone without lines of their own): personality, how they sound at the table and in character, verbal tics, what they'd never say, sample lines. |
| `lines.json` | The lines, one per row: trigger, speaker, text, and a status (draft, approved, edited or rejected). |

A **cell** is one trigger for one speaker (and one tier or mood when the trigger is split that way): 204 cells, most
with 4 lines. Shipped builds only use approved lines; development builds (and the desktop shortcut's build) use
drafts too, so new lines fire at the table and can be reviewed. Lines that name another player only play when that
player is there, a few lines are written for a particular pair (Jess teasing Dev), and a line about something the
adventure's world doesn't have waits for one that does.

**Reviewing.** Press **F4** in the game. On game night a rail on the right shows each line as it fires, with
Approve, Edit and Reject; hover over it and the night waits for you. **Q** opens the queue, which walks every cell
that still has drafts, with the trigger and the speaker's voice sheet beside the lines (F4 on any other screen
opens it too). In the queue: Up/Down pick a line, **A** approve, **E** edit (type, Enter saves, Esc cancels, Tab
switches to a banter reply), **R** reject, **Enter** approves the rest of the cell and moves on, **N**/**P** next or
previous cell, **Esc** closes. Every decision saves straight into the project's `lines.json`. (If the game can't
find the project folder it saves to `dialogue_overrides.json` in the save folder instead; run
`python3 tools/dialogue/merge_overrides.py` to fold that in.)

**More lines.** `python3 tools/dialogue/generate.py` finds every cell short of 4 lines (rejected lines don't count),
sends the trigger and voice sheet to Claude in batches with the approved lines as examples and the rejected ones as
things to avoid, checks what comes back and adds it as drafts. It needs an `ANTHROPIC_API_KEY`; without one,
`--dry-run DIR` writes the requests to files and `--import FILE` adds answers you got elsewhere.

**Coverage.** `lua tools/dialogue/coverage.lua` prints the gate and writes `tools/dialogue/coverage.html`, a grid of
every cell: green when it has 3 approved lines, amber while it waits on review, red when it needs more lines. The
adventure's own lines go to the dialogue review page with `lua tools/dialogue/export.lua out.json`
(`tools/dialogue/README.md`).

## Reading the table (M2)

Every bar is a fill and an icon, never a number, and **Empathy** decides how well you can read them.
It grows with every game night you run and every talk.

| Empathy | What you see |
| --- | --- |
| 1 Clueless | Rough fills (quarters). Long-term bars show last week's values. Game night bars only move between scenes. |
| 2 Getting a feel | Finer fills, up to date. The report shows which way each bar moved. |
| 3 Attentive | Game night bars move every beat. Trend arrows on the player cards. |
| 4 Perceptive | Early warning when someone starts drifting away. The report shows big moves (++ / --). |
| 5 Reads minds | Precise fills. |

Suspicion is always a blurred band. Empathy narrows it but never closes it. Empathy also sets how many of the
friends' thoughts you catch, and **familiarity** ("New to you" to "Like a book", the dots on their card) makes them
easier to read: it grows with nights together, clear reads, answers that land and talks.

**Who keeps coming.** Commitment follows recent Fun most, then that night's Fun, Investment and Trust; a rough week
in someone's life pulls it down a little. Below 25, their card says they seem to be losing steam. The prologue is
short and everyone's keen, so the whole table comes every week.

## Controls

| Key | Game | Sandbox (F2) |
| --- | --- | --- |
| Mouse | Click cards, rooms and options; click a player's tile or card for their sheet, a person's name for theirs; right-drag to look around at game night | Right-drag to orbit |
| Enter | Next step: Session Zero, start the week, run game night, see the report, next week | |
| Esc | Close the level-up moment, your notes, a sheet, a menu (it asks before throwing away changes), an "are you sure?" or a finished talk | |
| C | Take a snapshot of the table on game night (three a night) | |
| N | Your notes (the Notes button on prep and game night) | |
| S | The Story and Table sidebars on game night | |
| M | Music off or on (rain and sounds stay) | |
| Space | Skip to the next beat of game night | Roll the d20 |
| F / G | Game night speed: faster (up to 4x) / slower (down to half speed) | |
| Tab | Open or close the game night log | |
| H | Your own rolls (monster attacks and saves): behind the screen or in the open | |
| T | Gentle timer on decision cards, on or off | |
| 1 to 4 | Pick a card's option on game night (the options show their numbers) | Room / Table / Imagination / Dice tray |
| F2 | The free-camera sandbox (debug builds only) | Back to the game |
| F3 | Show every hidden number (debug builds only) | |
| F4 | Dialogue review mode (development builds) | |
| Q | Dialogue review queue, during game night with F4 on | |
| A / E / R | In the review queue: approve, edit, reject the line | |
| L | | Dim the lamp |
| R | | Reset the view |

## Playtesting

After every week the game appends a line to a playtest log: the board you built, prep and game night time, every
decision, every big roll (open, hidden, cooked), how each player ended up, conflicts and the story. The quick
questions after a session and the end-of-prologue survey add their own lines (`"type"`: `week`, `week_survey`,
`slice_survey`). On Windows it's at `%APPDATA%\behind_the_screen\playtest_log.jsonl`; F3 shows the exact path.

## Project layout

| Path | What it holds |
| --- | --- |
| `game/data/` | All content as plain data: players, archetypes, scene types, decision cards, moods, rests, table habits, the glossary; the adventure's own rooms and cards in `game/data/museum/`, its maps in `game/data/maps/` |
| `game/data/dialogue/` | The dialogue library (M5): triggers, voice sheets, lines |
| `game/model/` | The simulation, in engine-free Lua: the adventure (`adventure.lua`, `museum_week.lua`, `museum_night.lua`), game night's shared helpers (`night.lua`), fights (`fight.lua`), the friends (`score.lua`, `bars.lua`, `empathy.lua`, `familiar.lua`, `thoughts.lua`, `social.lua`), the report, saves |
| `game/ui/` | The screens, drawn from GUI nodes through `kit.lua`: the hooks page, the prep board and showdown board (`museum_*`), game night, the report, the map repository and map maker, debug numbers |
| `game/rules/` | The M3 rules engine, engine-free Lua: dice, creatures, the battle (attacks, saves, damage, conditions, concentration, death saves, movement), spells, subclasses, tactics, the party and encounter building; the museum's monsters in `museum.lua` |
| `game/rules/data/` | SRD 5.2.1 data with page references: classes, weapons and armor, monsters, magic items; plus the fitted difficulty meter (`difficulty_fit.lua`, generated) |
| `game/game.gui_script` | Ties the screens to the camera, the HUD and the d20 |
| `render/`, `materials/` | The render pipeline and shaders (warm lamp, campfire, moonlight, imagination fade, outlines) |
| `main/` | The table scene: camera, lamp, d20, players, HUD; `main/table/` stages game night (minis, poses, sparks), `main/minis/` is one paper mini, `main/board/` the board and its prop kit (a factory per piece), `main/keepsakes/` the gifts on your side of the table |
| `game/data/boards.lua`, `props.lua`, `game/model/board.lua`, `main/board/board.script` | The table that matches the story: the plain boards (with the map library's), the prop kit's footprints (generated), what blocks, what's cover and rough ground, what the narration puts down |
| `game/model/dialogue.lua`, `talk.lua`, `barks.lua` | Loading, picking, saving and checking dialogue lines (M5); fight barks that fit the moment |
| `game/ui/review_view.lua` | The dialogue review mode (F4) |
| `game/data/session_zero.lua`, `conflicts.lua`, `progression.lua` | M6: Session Zero options, the three table conflicts, level pacing and what pulls each subclass |
| `game/ui/session_zero_view.lua`, `museum_setup_view.lua`, `levelup_view.lua` | Session Zero, the hooks page, the level-up moment |
| `game/model/save.lua`, `game/ui/saves_view.lua` | Saving and loading: the autosave and three slots |
| `game/ui/slice_end_view.lua`, `museum_journey_view.lua`, `ambience.lua`, `autotest.lua` | The journey recap and survey at the end of the prologue; sound, light and snacks; the in-engine autotest |
| `game/model/recap.lua`, `takeover.lua`, `maps.lua`, `death.lua`, `fails.lua`, `jokes.lua`, `loot.lua` | M8: the report's recap and verdict, taking over, the DM's own maps, death at the table, dice jail, running jokes, the dice box |
| `game/ui/report_view.lua`, `rewards_view.lua`, `map_repo_view.lua`, `map_view.lua` | The report, the dice box, the map repository and the map maker |
| `game/data/guide.lua`, `game/ui/guide_view.lua` | The first-session tips: what each says, when it shows, and the pinned layer that draws them |
| `main/audio/`, `main/snacks/`, `assets/audio/` | M7: the sound player and sounds; the pizza and chips |
| `tools/playtest/` | M7: tester package script, tester readme, log analyzer, pretend logs |
| `game/rules/skills.lua`, `game/data/actions.lua` | Skill proficiencies and modifiers; what heroes try in each kind of scene, with the skill and DC |
| `game/model/sheet.lua`, `matchup.lua` | Character sheets from the rules engine; how a lineup plays against the party |
| `game/ui/panels.lua`, `battle_hud.lua`, `night_view.lua`, `recap_view.lua` | The player tiles; HP bars, conditions, status rings, the turn order and spell areas; game night; the Story and Table sidebars |
| `game/ui/notes_view.lua`, `sheet_view.lua`, `player_cards.lua`, `npc_view.lua` | Your notes, character sheets, the friends' cards on the prep board, people's sheets |
| `main/fx/`, `materials/mark.*`, `assets/portraits/` | Spell areas, zones and status rings on the mat; faces and minis for the screens |
| `tools/` | Asset generators (Python), the map import pipeline (`tools/maps/`), headless tests (`tools/tests/`), the simulations (`tools/sim/`), the dialogue tools (`tools/dialogue/`) and the project validator |

## Tuning and tests

Everything in `game/data/` is safe to edit. After changing it, run the headless tests from the project root
with any Lua 5.1+ or LuaJIT interpreter:

    for s in 1 2 3 4 5 6 7 8; do lua tools/tests/museum_smoke.lua $s || break; done
                                       # the whole prologue through the real UI against a mock GUI
                                       # (DUMP_DIR=out writes every screen's nodes; TRANSCRIPT=file what a player reads)
    for st in careful random careless; do for s in 1 2 3 4; do lua tools/sim/museum.lua $s $st || break; done; done
                                       # the prologue headless, three kinds of DM ("log" after the style: every line)
    lua tools/tests/museum_truth.lua   # cause and effect: every flag read, every mark does something
    lua tools/tests/thoughts_check.lua # the friends' thoughts: lines, answers, Empathy, whole prologues
    lua tools/tests/standing_check.lua # the DM's recap: sides, people's lines, who's drawn to whom
    lua tools/tests/ties_check.lua     # ties and locks: block and open, refusals, saves, whole prologues
    lua tools/tests/barks_check.lua    # fight barks fit the moment; a handed-off killing blow is told, not re-swung
    lua tools/tests/map_repo_check.lua # the map repository and the open floors
    GLOSS_AUDIT=1 lua tools/tests/museum_smoke.lua 1   # every game word on screen has a hover (tools/tests/gloss_words.lua)
    python3 tools/maps/build_maps.py --check   # every map spec builds: on the mat, starts free, walls closed
    lua tools/tests/museum_fights.lua  # the museum's monsters on the rules engine (about 2 minutes)
    lua tools/tests/rules_cases.lua    # hand-checked SRD 5.2.1 combat cases (M3 and since)
    lua tools/tests/save_check.lua     # museum saves load back and play on, mid-prologue too (about 2 minutes)
    lua tools/tests/playtest_nov3_check.lua 8   # the November 3 notes, played: whole prologues
    lua tools/tests/table_life_check.lua  # small moments: they happen, never in fights or at 4x
    lua tools/tests/rest_check.lua     # Short and Long Rests by SRD 5.2.1, the party's state carried across nights
    lua tools/tests/dialogue_check.lua # every line well formed, every cell playable, the picker behaves (M5)
    lua tools/tests/board_check.lua    # every board laid out right (lua tools/tests/board_check.lua museum_garden prints one)
    python3 tools/tests/require_check.py  # no require cycles (the engine's builder refuses them)
    python3 tools/validate.py          # every Lua file parses, every resource and sprite animation exists
    lua tools/sim/provenance.lua SEED STYLE out.tsv   # where every line of a museum night comes from
    tools/tests/engine_check.sh        # Linux + Xvfb: the real engine plays the whole prologue, saves, continues
    MODES=4 tools/tests/engine_check.sh  # one session's game night in screenshots
    MODES=6 tools/tests/engine_check.sh  # the board gallery: every board set out in full, one screenshot each
    tools/tests/ui_play/run.sh         # real clicks on every game-night card (Linux + Xvfb)

`python3 tools/tests/render_dump.py dump.txt out.png` draws a screen's dumped nodes roughly as Defold would.

## Rules engine (M3)

    lua tools/tests/rules_cases.lua               # hand-checked SRD cases, each with forced dice and a page number
    lua tools/sim/battles.lua [battles] [seed]    # default 12,000 fights, about 5 minutes

`battles.lua` runs the party at levels 2 to 4 (every subclass mix) against random encounters from Trivial to beyond
High, checks the difficulty meter with 5-fold cross-validation (every fight is forecast by a meter fitted without
it), compares each original subclass with its class's SRD subclass, and writes `tools/sim/battles_report.html` plus
`game/rules/data/difficulty_fit.lua` (fitted on all the fights). The same seed gives the same numbers. In code:

    local enc = require "game.rules.encounter"
    enc.meter(3, 4, { "ogre", "ogre" })
    -- { srd = "Moderate", someone_drops = 0.37, party_falls = 0.00, someone_dies = 0.01, hp_lost = 0.21,
    --   danger = "Tense", extrapolated = false, ... }
    enc.run(3, { "wolf", "wolf", "dire_wolf" }, { seed = 7, verbose = "print" })   -- one fight, logged

The meter reads the SRD XP budget plus each stat block's Hit Points and damage, so a new monster gets a forecast
without new simulations. Fights bigger or smaller than the simulated range (more than 2.5 monsters per character,
or far outside the XP budget) come back with `extrapolated = true`.

What it simplifies: every creature takes one square on a 5-foot grid, scenery blocks squares, cover comes from the
best piece a straight line from square to square crosses (not pieces beside the attacker, not creatures, and not to
saves), line of sight is that same line (a corner blocks only when both sides do), light is by distance from each
source (blocked by walls), doors can't be broken by attacks and monsters don't pick locks, simple readable tactics
on both sides, and monsters leave fallen characters alone unless the DM runs the boss's turn and says otherwise.
Hiding, grappling, shoving, readied actions and non-combat spells aren't modeled yet.

The monsters, magic items, traps and hazards in `game/rules/data/` are from the SRD 5.2.1 with their page
references; the museum's own monsters are paraphrased from the book's stat blocks in our own words.

This work includes material from the System Reference Document 5.2.1 ("SRD 5.2.1") by Wizards of the Coast
LLC, available at https://www.dndbeyond.com/srd. The SRD 5.2.1 is licensed under the Creative Commons
Attribution 4.0 International License, available at https://creativecommons.org/licenses/by/4.0/legalcode.
The rules code paraphrases it and cites page numbers. The eight original subclasses (Banner Captain,
Spellguard, Silvertongue, Ambusher, Hearth Domain, Mischief Domain, Wayfinder, Mirror Mage) are our own
designs with working names, pending IP review.

## Regenerating assets

All art is procedural. To change the layout, the camera presets or the art, edit `tools/` and run:

    python3 tools/generate.py

It needs Python 3 with `numpy` and `pillow`, and overwrites the generated files (meshes, textures, sprites,
fonts, status icons, the board's prop kit, `main/main.collection`, `main/props/`, `main/board/`, `main/scene_data.lua`,
`game/ui/metrics.lua`, `main/snacks/` models), so make scene changes in the generator, not in the editor. The sounds
have their own generator: `python3 tools/gen_audio.py` writes `assets/audio/` and `main/audio/` (except
`audio.script`). The board's prop kit is `tools/gen_props.py` (one mesh and one factory per piece, and
`game/data/props.lua`); the plain boards are data in `game/data/boards.lua`, the adventure's are map specs
(`tools/maps/README.md`), and `python3 tools/preview_boards.py out_dir [board]` draws them without the engine. The
players' gifts on the DM's side of the table are `tools/gen_keepsakes.py` (`main/keepsakes/`, all but
`keepsakes.script`). The museum's own minis are painted by `tools/gen_sprites_museum.py` (run it from the project
root; `tools/generate.py` lists them in the atlas), and the ones its people still borrow by `tools/gen_sprites_m4.py`
and `tools/gen_sprites_npcs.py`. After changing sprites, `python3 tools/gen_portraits.py` recuts the faces and minis the
screens use (`assets/portraits/`), and `python3 tools/gen_mark.py` redraws the square used for spell areas on the
mat.

Fonts: Outfit, Lora and Nothing You Could Do, under the SIL Open Font License (license files in `assets/fonts/`).
