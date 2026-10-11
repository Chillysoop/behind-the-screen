# Behind the Screen

A cozy DM simulator in Defold. This build has eight milestones from the prototype plan:

- **M7 the vertical slice, ready for outside testers:** Session Zero plus the first four sessions of "The Silent
  Bells", each with a story beat and story cards in your hand, a first act that lands or falls flat, and an
  end-of-slice scrapbook and survey. Two quick questions after every session, a log analyzer that reads the gate
  off a round of testers, a one-click tester package, and saving between sessions. Plus the cozy pass: rain,
  music and sound, an evening that darkens as game night goes on, and a pizza and a bowl of chips that empty
  over the night.
- **M6 social layer and progression:** Session Zero before week 1 (tone, lines and veils, table rules), a group
  chat you can answer and private messages, three table conflicts that each have several fixes, seeds you plant
  and pay off weeks later, inspiration that draws new cards, and level-ups where every player picks their own
  subclass at level 3.
- **M5 dialogue pipeline:** everything the players, their characters and the NPCs say comes from a library of
  1,228 AI-written lines that you review before they ship: 61 triggers, a voice sheet for each of the 4 players and
  11 NPCs, a batch generation script, a review mode inside the game (F4) and a coverage report. The gate is 3
  approved lines in every cell.
- **M4 game night at the table:** the night plays out on the battle mat. Scenery sets drop in for each scene,
  paper minis walk, fight and fall over on the M3 rules engine, the four players lean in, cheer, yawn or reach
  for their phones, and speech bubbles pop over their heads. You make 8 to 15 calls a night across six kinds of
  decision card, improv hands and rulings, roll big moments in front of or behind the screen, and a night runs
  about 15 minutes.
- **M1 greybox loop (the game):** prep a session on the beat board, run game night at the
  table, read the session report, and do it again next week.
- **M2 player status model:** every player's session meters and long-term bars, Empathy that
  decides how precisely you can read them, players who drift away (and say so) and come back,
  and a simulation harness that charts it all (`tools/sim/`).
- **M3 rules core (headless):** SRD 5.2.1 combat for the Fighter, Rogue, Cleric and Wizard at levels 2 to 4,
  all twelve slice subclasses, 12 monsters, the Cleric and Wizard spells to level 2, and a difficulty meter
  fitted on thousands of simulated fights (`game/rules/`). Every game night fight runs on it.
- **M0 engine spike (the sandbox):** the 2.5D table under warm lamplight, with four camera
  zooms and a physical d20. Press F2 to switch to it and back.

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

## How a week plays

0. **Session Zero** (once, before week 1). Pitch a tone, hear each player's ask, set the table rules.
1. **Group chat and messages.** Your friends react to last week and drop hints about what they want and how
   their week went. Theories about your mysteries come with replies you can send. When something's brewing at the
   table, someone messages you about it.
2. **Prep.** Pick a type for each of three scenes, then fill their five slots (location, cast, goal,
   complication, reward) from this week's hand. You have 12 hours of prep, so some slots stay empty and
   get improvised at the table. Watch the pacing curve and each player's forecast for Thursday. Talking to a
   player costs 2 hours and tells you their mood.
3. **Game night.** It plays out on the table (see below). You step in for decision cards, improv hands when
   an empty slot comes up or the party wanders off, big d20 rolls and how they land. A big roll can go in the
   open or behind the screen, where you can cook it. Cook too often and someone will ask to see the dice.
4. **Session report.** How each player felt, their meters for the night, how Commitment, Investment, Trust and
   Suspicion moved, the best moments, anything you improvised that's now canon, seeds and conflicts. Once the
   party has played two nights at a level you can level them up from here.

## Game night at the table (M4)

Each scene gets its own set on the battle mat: the goblin camp, a forest road, chapel ruins, the Crooked
Kettle's taproom, the market square, the rope bridge over the gorge. The DM lifts the old scenery off, sets the
new one down, and drops the minis in. Captions along the bottom carry your narration; the players talk in
speech bubbles (cream when they speak in character, dark when it's table talk), and your NPCs talk from their
minis.

- **Quick checks** roll on the dice strip (top right) and fill the scene's progress pips: gold for wins, red
  for setbacks.
- **Fights** run on the M3 rules engine with the terrain as obstacles. Minis walk square by square, lunge,
  flash red when hit, tip over when they drop and get swept off when they're beaten. Damage floats up off the
  minis and each player's card shows their hit points. Your own attack rolls show face down ("?") on the dice
  strip while they stay behind the screen; press H to roll them in the open.
- **The players** sit around the table and show how they feel: leaning in, cheering, gasping, arms crossed,
  yawning, on their phone. Someone who's out this week leaves an empty chair.
- **Decision cards** come in six kinds (story, combat, rules, behind the screen, pacing, table) and slide in
  when a moment needs you. Fights bring their own: a hidden roll that would drop a hero, their last death
  save, a boss who wants to talk, a fight that drags on.
- **Improv hands** come up for every empty prep slot and when the party wanders off: pick one to three cards.
  Your best card counts fully; one that doesn't fit always hurts.
- **Big rolls** pause for you: roll in the open (the table trusts it) or behind the screen (you can cook it).
  Then you decide how the result lands: generous, straight or with a cost.

A night runs about 15 minutes at normal speed with 8 to 15 calls. The gentle timer (T) gives each card 15 to 45
seconds before the safe default plays, if you want to keep the night moving; it's off unless you turn it on.

## Session Zero, the table and leveling up (M6)

**Session Zero.** Before week 1 the table talks it through, and people say what they think, so every option shows
who likes it. Pitch a tone (serious story with silly downtime, warm and heroic, dark and dangerous, or loose and
silly). Hear each player's ask: Mara draws a **line** (nothing bad happens to kids), Sam asks for a **veil**
(spiders stay off screen), Dev and Jess ask for **promises** (roll his death in the open; don't cut her NPC
chats short). Set the table rules: the X-card, where your dice land, and how rules calls work. What you agree
to holds for the whole campaign: the prep board warns you when a card touches a line or veil, game night fades
veiled content out on its own, the X-card catches what slips through, and breaking a promise costs Trust. The
tone and the rules also decide which conflicts start warm.

**The group chat and your messages.** The prep board's left column has two tabs. **Group chat** is the week's
chat, newest at the bottom; when someone theorizes about one of your mysteries you can play along, deflect or
shoot it down. **Messages** has private messages from players (answering is free) and conversations you can
start yourself, a DM or a post to the whole group, which cost an hour of prep when you send them. Some replies
depend on how much the player trusts you.

**Table conflicts.** Three can come up in the slice, each built from what actually happens at the table:

| Conflict | What builds it | Ways to settle it |
| --- | --- | --- |
| **The Pip show:** Jess fills every scene | Jess getting far more spotlight than the others; promising never to cut her scenes | Ask her to help pull the quiet ones in; tell her straight; keep passing the spotlight at the table |
| **Rules lawyering:** Dev wants rule of cool, Sam wants the same rules every time | Every rules call lands on one side; "by the book" and "rule of cool" at Session Zero make it worse; "quick call, look it up after" only works if you do look it up | Post a house rule; call a vote; promise to look it up and post the ruling next week |
| **Tone clash:** Mara wants Ilsa's story serious, Jess can't resist a joke | The Session Zero tone; jokes landing in Mara's backstory scenes | Revisit Session Zero with a tone check; protect the quiet moments at the table; plan a week with a serious scene for Mara and a goofy one for Jess |

When a conflict starts brewing, a bystander messages you and its card can turn up on game night. If it gets
worse, the people in it lose Commitment every week until it's settled. Most fixes land in a week or two.

**Seeds.** In the drawer (click away from any slot), plant one seed a week for an hour of prep: a little mystery
mentioned on game night. From the next week its payoff card is in your hand for three weeks; put it on the board
and it pays off with a big story moment. Leave it and it goes stale, and the people theorizing about it notice.
Some seeds nudge a subclass (the retired captain makes Banner Captain tempting for Dev).

**Inspiration.** Also in the drawer: two evenings off a week, an hour each. A fantasy novel, movie night, the game
store's new supplement, rereading a backstory, a callback to last week's canon, or a walk in the rain. Each draws
cards you wouldn't otherwise get, and inspired cards play a little better.

**Level-ups.** The slice starts at level 2. After two nights at a level the report (and the prep board) offers
the level-up; after four the table starts asking. At level 3 every player picks their own subclass, for their own
reasons: who they are as a player, what their nights have been like, or a seed that stuck with them. You don't
get a say. At level 4 everyone takes an Ability Score Improvement. Game night fights use the new level and
subclasses from then on.

**The gate.** `lua tools/sim/social.lua [campaigns] [weeks]` (default 8 x 10, about 7 minutes) runs simulated DMs
who ignore conflicts, talk them out, say it straight, fix them at the table or plan around them, across five
Session Zero set-ups, then checks every conflict can be settled at least two ways, ignoring one costs the people
in it, fixes land within 1 to 3 weeks, every subclass pick is true to its player, seeds nudge picks without
forcing them, seeds pay off when followed up and go stale when not, and the safety tools work.

## The slice and the playtest round (M7)

**The arc.** The slice is Session Zero and the first four sessions of a 20-session campaign, *The Silent Bells*
(`game/data/arc.lua`). Each session has a beat with a title, a hint on the prep board and three or four story
cards dealt into your hand. Playing them moves the story; ignoring them is allowed. Session 4 turns the first act:
end it high and the table can't wait for session 5. Each beat also leans on one table conflict so the social
side shows up inside four weeks.

**After each session** two quick questions (did prep feel satisfying, did watching it pay off) go into the
playtest log. **After session 4** the scrapbook shows each player's four nights, their level and subclass, their
best line and whether they're coming back; then a short survey: four 1 to 5 scales, would you play session 5, and
two optional typed answers. "Keep playing" carries on past the slice.

**Saving.** The campaign saves after Session Zero and after every game night (`campaign_save.txt` beside the
playtest log); the title card offers **Continue**. Quitting during prep or game night restarts that session.
The save is the campaign between weeks, written as data (`game/model/save.lua`), and refuses a save from another
build instead of half-loading it.

**The cozy pass.** Rain on the window and two quiet music loops (prep and game night) that crossfade; M turns the
music off. Clicks, cards, the d20 rattling in the tray, paper, a phone ping for new messages, bells for crits,
payoffs and level-ups (all made by `tools/gen_audio.py`). The light drifts from dusk at prep to late evening
over game night, the window darkens and the fairy lights come up, and big moments make the lamp swell. A pizza
and a bowl of chips on the table empty over the night and come back for the next session.

**First-session tips.** Someone who has never seen the game gets one short tip at a time: Session Zero, the
first prep board, the first game night and its decision cards, the first report, then messages, the drawer and
levelling up the first time each matters. Tips outline what they talk about and never block; doing what a tip
asks moves it on, "Got it" dismisses it, "Hide tips" turns them off for that campaign. They're data
(`game/data/guide.lua`), saved with the campaign, and the playtest log notes how many were seen and whether they
were turned off.

**Any window size.** The game scales to fit the window (checked in the real engine at 1280x720, 1366x728,
1280x800 and 1920x1080, with real mouse clicks in a non-16:9 window). A window bigger than the screen can be
maximized.

**The playtest round.** The full runbook is the *Playtest round* tab of the design doc. In short:

    tools\playtest\package_playtest.ps1          # Windows: clean build, dev keys off, readme, zip in playtest\
    python tools\playtest\analyze.py playtest\logs   # every tester's log -> playtest_report.html and the verdict

The package is a release build with `tools/playtest/playtest.ini` over `game.project`: the draft dialogue still
plays (`drafts = 1`), F2, F3 and F4 are off (`playtest = 1`), and no debug ports open, so Windows Firewall stays
quiet. `tools/playtest/sample_logs.lua` writes pretend logs to try the analyzer on.

## A real session at the table (the real-session pass)

After the first playtest: the story was hard to follow, some cards made no sense where they landed, the rolls
didn't look like D&D and it was hard to tell who was who. This pass makes game night read like a real session.

**Who's who.** Four panels along the bottom of game night, one per player: their face (it follows how they're
sitting and reacts to big moments), their character's paper mini, "Pip, Rogue 2", their tell, Fun and Spotlight,
hit points during a fight, and their last roll: the d20 tumbles, lands, and shows the skill, the total and the DC
or Armor Class. Click a panel for that character's sheet.

**Rolls like a real table.** A check is d20 plus the character's skill modifier (SRD 5.2.1 proficiencies and
Expertise, `game/rules/skills.lua`) against a DC: "Pip, roll Sleight of Hand. DC 10." Whoever's good at it and
short on spotlight steps up. On a big roll the player throws the die; your call is whether you say the DC out loud
or keep it behind your screen, and cooking their roll means moving the hidden DC. Some checks (noticing an ambush,
reading a liar) are secret: you roll those behind the screen.

**Cards that fit where they are.** Every location has a setting (town, wild, indoor, ruin, underground...), and
complications, improv cards and decision cards say where they can happen. The prep board won't put "The floor gives
way" on a forest road, and some cards change their line to suit the place.

**A story you can follow.** Each night opens with a recap of last week and the session's opening, read aloud. Story
cards reveal something when played and add clues to your notes ("New in your notes" slides in); clues open later
beats. **Your notes** (N, or the Notes button on game night and the prep board) have this session (scenes, goal,
cast), the story so far, who's who, and the party with their character sheets. Game night waits while they're open.

**Character sheets** from a player's panel, their card on the prep board or the notes: Armor Class, hit points,
abilities and saves, all 18 skills with proficiency and Expertise marked, attacks, spells and slots, every feature
in full, gear and their backstory hook. The numbers are the rules engine's, the same ones the table rolls with.

**Fights built for this party.** A combat or set-piece scene on the prep board has a **The fight** button: pick from
twelve SRD monsters, see the XP against the Low, Moderate and High budgets with the engine's forecast, and notes on
how that lineup plays against these four (who it's good against, who gets to shine). Game night fights what you
built.

**Fights you can read.** Hit point bars and conditions over every mini, everyone rolling initiative and the turn
order along the top, attack numbers in the log ("18 vs AC 15 for 9 (1d6+3)"), spell areas flashing on the mat and
lasting zones (Web, Grease) staying there until they end. A long fight plays faster the longer you've been
watching, the small table talk thins out, and if the walk into the fight was long you get the monsters' tactics
call at the start.

**Who a choice is for.** Faces on decision options, scene types and hand cards show who'd love it and who wouldn't;
hovering a card in your hand shows its full text, where it fits and why. The hand is paged five at a time so names
never get cut.

Everything at the table runs on the rules engine (`game/model/sheet.lua`, `game/rules/`), so a mode where real
players roll their own dice could plug into it; the game itself stays simulated.

## Dialogue (M5)

Every line anyone says lives in `game/data/dialogue/`:

| File | What it holds |
| --- | --- |
| `triggers.json` | The 82 moments that need a line (a crit, a called-out cooked roll, a goodbye in the group chat...), who says each, whether it's said at the table, in character, in the group chat or by an NPC, the fill-ins a line may use and its length limit. Group chat moods and the report's fun tiers get lines of their own. |
| `voices.json` | A voice sheet for each speaker: personality, how they sound at the table and in character, verbal tics, what they'd never say, sample lines. |
| `lines.json` | The lines, one per row: trigger, speaker, text, and a status (draft, approved, edited or rejected). |

A **cell** is one trigger for one speaker (and one tier or mood when the trigger is split that way): 368 cells,
4 lines each (M6 added 244 lines for conflicts, seeds, level-ups, subclass picks and six new NPCs). Shipped builds only use approved lines; development builds (and the desktop shortcut's build) use
drafts too, so new lines fire at the table and can be reviewed. Lines that name another player only play when
that player is there, and a few lines are written for a particular pair (Jess teasing Dev).

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
`--dry-run DIR` writes the requests to files and `--import FILE` adds answers you got elsewhere. The first 1,228
lines went through exactly that path.

**Coverage.** `lua tools/dialogue/coverage.lua` prints the gate and writes `tools/dialogue/coverage.html`, a grid of
every cell: green when it has 3 approved lines, amber while it waits on review, red when it needs more lines.

## Reading the table (M2)

Every bar is a fill and an icon, never a number, and **Empathy** decides how well you can read them.
It grows with every game night you run and every one-on-one talk.

| Empathy | What you see |
| --- | --- |
| 1 Clueless | Rough fills (quarters). Long-term bars show last week's values. Game night bars only move between scenes. |
| 2 Getting a feel | Finer fills, up to date. The report shows which way each bar moved. |
| 3 Attentive | Game night bars move every beat. Trend arrows on the player cards. |
| 4 Perceptive | Early warning when someone starts drifting away. The report shows big moves (++ / --). |
| 5 Reads minds | Precise fills. |

Suspicion is always a blurred band. Empathy narrows it but never closes it.

**Who keeps coming.** Commitment follows recent Fun most, then that night's Fun, Investment and Trust; a rough week
in someone's life pulls it down a little. Below 25, a player says so in the group chat. After two weeks of that,
and still below 20, they take a break for 3 to 5 weeks. A check-in during prep (2 hours) brings them back sooner,
and they always come back with a fresh start. Nobody leaves without warning.

## Controls

| Key | Game | Sandbox (F2) |
| --- | --- | --- |
| Mouse | Click cards, slots and options; click a player's panel or prep card for their sheet; right-drag to look around at game night | Right-drag to orbit |
| Enter | Next step: Session Zero, start the week, run game night, see the report, next week | |
| Esc | Close a conversation, the level-up moment, your notes, a sheet or the encounter builder | |
| N | Your notes: this session, the story so far, who's who, the party | |
| M | Music off or on (rain and sounds stay) | |
| Space | Skip to the next beat of game night | Roll the d20 |
| F | Game night speed: 1x, 2x, 4x | |
| Tab | Open or close the game night log | |
| H | Your own rolls (monster attacks and saves): behind the screen or in the open | |
| T | Gentle timer on decision cards, on or off | |
| 1 / 2 / 3 / 4 | Camera during game night (it also moves on its own) | Room / Table / Imagination / Dice tray |
| F3 | Show every hidden number | |
| F4 | Dialogue review mode (development builds) | |
| Q | Dialogue review queue, during game night with F4 on | |
| A / E / R | In the review queue: approve, edit, reject the line | |
| L | | Dim the lamp |

## Playtesting

After every week the game appends a line to a playtest log: the board you built, prep and game night time, every
decision, every big roll (open, hidden, cooked), how each player ended up, conflicts, seeds and the story. The
quick questions and the end-of-slice survey add their own lines (`"type"`: `week`, `week_survey`,
`slice_survey`). On Windows it's at `%APPDATA%\behind_the_screen\playtest_log.jsonl`; F3 shows the exact path.
See *The slice and the playtest round* above for running a round with outside testers.

## Project layout

| Path | What it holds |
| --- | --- |
| `game/data/` | All content as plain data: players, archetypes, scene types, scene cards, decision cards, improv, moods |
| `game/data/dialogue/` | The dialogue library (M5): triggers, voice sheets, lines |
| `game/model/` | The rules, in engine-free Lua: prep budget and pacing, game night, player meters, long-term bars (`bars.lua`), Empathy (`empathy.lua`), the report |
| `game/ui/` | The greybox screens: prep board, game night, report, debug numbers |
| `game/rules/` | M3 rules engine, engine-free Lua: dice, creatures, the battle (attacks, saves, damage, conditions, concentration, death saves, movement), spells, subclasses, tactics, the slice party and encounter building |
| `game/rules/data/` | SRD 5.2.1 data with page references: classes, weapons and armor, monsters; plus the fitted difficulty meter (`difficulty_fit.lua`, generated) |
| `game/game.gui_script` | Ties the screens to the camera, the HUD and the d20 |
| `render/`, `materials/` | The render pipeline and shaders (warm lamp, campfire, moonlight, imagination fade) |
| `main/` | The table scene: camera, lamp, d20, players, HUD; `main/table/` stages game night (terrain sets, minis, poses, sparks), `main/minis/` is one paper mini, `main/terrain/` the scenery sets |
| `game/model/night.lua`, `fight.lua`, `pacing.lua` | Game night as a stream of timed beats: scenes, checks, fights on the rules engine, decision cards; and how long each beat plays |
| `game/model/dialogue.lua`, `talk.lua` | Loading, picking, saving and checking dialogue lines (M5) |
| `game/ui/review_view.lua` | The dialogue review mode (F4) |
| `game/data/session_zero.lua`, `conflicts.lua`, `convos.lua` | M6: Session Zero options, the three table conflicts, every conversation script |
| `game/data/seeds.lua`, `inspiration.lua`, `progression.lua` | M6: seeds and their payoffs, inspiration activities, level pacing and what pulls each subclass |
| `game/model/social.lua`, `convo.lua` | M6: Session Zero, conflict pressure and fixes, promises; running a conversation |
| `game/model/seeds.lua`, `progression.lua` | M6: seeds, inspiration draws, chat theories; level-ups and subclass picks |
| `game/ui/session_zero_view.lua`, `messages_view.lua`, `levelup_view.lua` | M6 screens: Session Zero, the chat column and conversation modal, the level-up moment |
| `game/data/arc.lua` | M7: the slice's four story beats and the first-act finale |
| `game/model/save.lua` | M7: saving and loading the campaign between sessions |
| `game/ui/slice_end_view.lua`, `ambience.lua`, `autotest.lua` | M7: the scrapbook and survey; sound, light and snacks; the in-engine autotest |
| `game/data/guide.lua`, `game/ui/guide_view.lua` | The first-session tips: what each says, when it shows, and the pinned layer that draws them |
| `main/audio/`, `main/snacks/`, `assets/audio/` | M7: the sound player and sounds; the pizza and chips |
| `tools/playtest/` | M7: tester package script, tester readme, log analyzer, pretend logs |
| `game/rules/skills.lua`, `game/data/actions.lua` | Real-session pass: skill proficiencies and modifiers; what heroes try in each kind of scene, with the skill and DC |
| `game/model/story.lua`, `sheet.lua`, `matchup.lua` | Real-session pass: clues, the recap and your notes; character sheets from the rules engine; how a lineup plays against the party |
| `game/ui/panels.lua`, `battle_hud.lua` | Real-session pass: the player panels; HP bars, conditions, the turn order and spell areas on game night |
| `game/ui/notes_view.lua`, `sheet_view.lua`, `encounter_view.lua` | Real-session pass: your notes, character sheets, the encounter builder |
| `main/fx/mark.*`, `materials/mark.*`, `assets/portraits/` | Real-session pass: spell areas and zones on the mat; faces and minis for the screens |
| `tools/` | Asset generators (Python), headless tests (Lua), the simulation harness (`tools/sim/`) and the project validator |

## Tuning and tests

Everything in `game/data/` is safe to edit. After changing it, run the headless tests from the project root
with any Lua 5.1+ or LuaJIT interpreter:

    lua tools/tests/sim_weeks.lua      # simulates 720 weeks with three DM styles and checks the numbers
    lua tools/tests/gui_smoke.lua      # clicks through the whole slice of the real UI against a mock GUI, then continues a save
    lua tools/tests/rules_cases.lua    # 48 hand-checked SRD 5.2.1 combat cases (M3)
    lua tools/sim/nights.lua           # 288 game nights with six DM styles against the M4 gate (about 20 seconds)
    lua tools/tests/dialogue_check.lua # every line well formed, every cell playable, the picker behaves (M5)
    lua tools/tests/social_check.lua   # M6 data hangs together; Session Zero, conversations, seeds, level-ups work
    lua tools/sim/social.lua           # the M6 gate: conflicts, subclass picks, seeds (about 7 minutes)
    lua tools/sim/slice.lua            # the M7 slice: four sessions with three simulated DMs (about 30 seconds)
    lua tools/tests/save_check.lua     # save after any session, load, play on: nothing may change (about 40 seconds)
    python3 tools/validate.py          # every Lua file parses, every resource and sprite animation exists
    tools/tests/engine_check.sh        # Linux + Xvfb: the real engine plays itself, saves, continues (about 10 minutes)
    MODES=4 tools/tests/engine_check.sh  # the same, showing off notes, sheets, the builder, checks and a fight in screenshots
    AUDIT=1 lua tools/tests/gui_smoke.lua  # also lists every text the screens had to cut short, and where

## Simulation harness (M2)

    lua tools/sim/run.lua [campaigns] [weeks]     # default 16 campaigns x 24 weeks, about 3 minutes

Seven simulated DMs (balanced, story first, combat only, ignores Sam, cooks the dice, random, wings it) each run
the campaigns against the real model. It prints the M2 gate checks and writes `tools/sim/report.html`, a page of
charts you can open in any browser: Suspicion and Trust when you cook dice, Investment by prep style, a player
being ignored, every player's favourite scene type, one campaign week by week, and every break any player took.
DM styles live in `tools/sim/dm_styles.lua`; add your own there.

## Rules engine (M3)

    lua tools/tests/rules_cases.lua               # hand-checked SRD cases, each with forced dice and a page number
    lua tools/sim/battles.lua [battles] [seed]    # default 12,000 fights, about 5 minutes

`battles.lua` runs the slice party at levels 2 to 4 (every subclass mix) against random encounters from Trivial
to beyond High, checks the difficulty meter with 5-fold cross-validation (every fight is forecast by a meter
fitted without it), compares each original subclass with its class's SRD subclass, and writes
`tools/sim/battles_report.html` plus `game/rules/data/difficulty_fit.lua` (fitted on all the fights). The same
seed gives the same numbers. In code:

    local enc = require "game.rules.encounter"
    enc.meter(3, 4, { "ogre", "ogre" })
    -- { srd = "Moderate", someone_drops = 0.37, party_falls = 0.00, someone_dies = 0.01, hp_lost = 0.21,
    --   danger = "Tense", extrapolated = false, ... }
    enc.run(3, { "wolf", "wolf", "dire_wolf" }, { seed = 7, verbose = "print" })   -- one fight, logged

The meter reads the SRD XP budget plus each stat block's Hit Points and damage, so a new monster gets a forecast
without new simulations. Fights bigger or smaller than the simulated range (more than 2.5 monsters per
character, or far outside the XP budget) come back with `extrapolated = true`.

What it simplifies: every creature takes one square on a 5-foot grid, scenery blocks squares but gives no cover,
simple readable tactics on both sides, and monsters leave fallen characters alone. Hiding, grappling, shoving,
readied actions and non-combat spells aren't modeled yet.

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
fonts, status icons, terrain sets, `main/main.collection`, `main/props/`, `main/terrain/`, `main/scene_data.lua`,
`game/data/terrain_layout.lua`, `game/ui/metrics.lua`, `main/snacks/` models), so make scene changes in the
generator, not in the editor. The sounds have their own generator: `python3 tools/gen_audio.py` writes
`assets/audio/` and `main/audio/` (except `audio.script`).
Terrain sets are laid out square by square in `tools/terrain_layout.py`; the same layout blocks squares in fights.
After changing sprites, `python3 tools/gen_portraits.py` recuts the faces and minis the screens use
(`assets/portraits/`), and `python3 tools/gen_mark.py` redraws the square used for spell areas on the mat.

Fonts: Outfit, Lora and Nothing You Could Do, under the SIL Open Font License (license files in `assets/fonts/`).
