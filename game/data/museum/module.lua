-- The Museum of Nightmares as an adventure module: the rooms on its map and the ways between
-- them, how the DM can run each room (knobs), the calls each room puts to the DM on game night
-- (moments), the marks the build-up leaves on Euryale's card, what she thinks as they land, and
-- the questions between sessions (requests, loose ends, favors). Its cards are
-- game/data/museum/cards.lua.
--
-- Adapted from "The Museum of Nightmares" by Luke Russell (DMs Guild) for private playtesting.
-- Every line is our own words. The prologue is strictly the book: no Silent Bells story here.
-- Data only: tune freely. The model is game/model/adventure.lua.
--
-- Moments are decision cards (the shape of game/data/decisions.lua) with a `mus` table on any
-- option or roll outcome for what it does to the adventure:
--   mark      adds one of Euryale's marks (marks below)
--   flag      sets an adventure flag (what the party has, did or knows)
--   francs    Flitwidget Francs for the party's pool
--   careful   counts toward the "Careful hands" mark (gentle with the exhibits)
--   favor     { who = "flitwidget" | "telpur", n = 1 }: siding with someone (favors below)
--   risk      a chance the party took knowingly, after a warning: one in the fair-warning bank
--   warn      the DM warned them themselves: one in the bank, and a little tension gone
--   harsh     a harsh call: spends one from the bank, or the table feels it was arbitrary
--   fight     the room's fight happens (rooms whose fight is optional)
--   no_fight  the room's fight doesn't happen
--   drop      monster ids taken out of the room's fight (rooted by water, burned...)
--   hurt      { dice, sides }: the hero it happened to takes that much damage (never below 1 HP),
--             so a log that says they're hurt means their sheet is too
--   inspire   the hero it happened to gets Heroic Inspiration (a reroll, when it counts)
--   ready     the party saw it coming: the room's ambushers don't surprise them
--   ending    (boss night) how it ends: fallen, bargain, escape, ally, slept
-- Anything a flag or mark stands for that the party carries works in the fights after (M.items).
-- when / unless on a moment: { knob = id } | { flag = id } | { mark = id } | { fork = "both" }.

local M = {}

M.id = "museum"
M.title = "The Museum of Nightmares"
M.author = "Luke Russell"
M.credit = "Adapted from The Museum of Nightmares by Luke Russell (DMs Guild), for private playtesting."
M.pitch = "A gnome's travelling museum rolls into town, and one of its exhibits, a Gorgon, has taken it over. "
    .. "A one-shot prologue: as many sessions as it takes."
M.MAX_WEEKS = 8          -- a safety net: the prologue wraps up by then whatever happens
M.BUDGET = 10            -- prep hours a week
M.START_LEVEL = 2        -- the rules engine starts at level 2 (the book: 1); fights are tuned to match
M.UNPREPPED_QUALITY = 0.22   -- how much thinner a room plays when the DM didn't prep it

-- The DM's own notes: what the players don't know yet.
M.premise = {
    "A gnome called Formicarius Flitwidget runs a travelling museum out of a caravan. Through its curtains is a whole pocket world.",
    "He bought a Gorgon, Euryale, sealed in a clay jar. She broke free, turned visitors to stone, and took the museum over.",
    "She has twisted the exhibits to her side: living topiary in the garden, a knight that climbs out of its painting, pack hunters upstairs.",
    "Upstairs, in a locked office, a dead archivist was studying something called the Witness. It's bigger than this museum.",
    "Euryale wants the museum as her own little world. Underneath, she misses being free, and her two sisters are still sealed in jars.",
}

-- Who's who, for the notebook. known: shown from the start.
M.people = {
    { id = "mus_flitwidget", name = "Formicarius Flitwidget", role = "The curator", known = true,
      about = "A gnome with a huge moustache and a feathered hat. Cheerful, manic, and not telling them everything." },
    { id = "mus_telpur", name = "Telpur", role = "Runs the gift shop",
      about = "A talking boot. Says they were once a great lord of the underworld. It's all a bit hazy." },
    { id = "mus_euryale", name = "Euryale", role = "The Gorgon upstairs", known = true,
      about = "Calm, clever, and very patient. She turns people to stone, but only when she has to." },
    { id = "mus_mech", name = "The Steam Mech", role = "The World of Tomorrow's pride",
      about = "A brass war machine from a forgotten war. Obeys whoever speaks its name first." },
}

-- Each hero's reason for coming, from the book's background hooks. The player leans one way
-- (lean); the DM picks. room: where the hook pays off (the hero sits up when it plays).
M.hooks = {
    mara = {
        { id = "sage", name = "Knowledge", text = "Whole worlds under one roof. Thessaly wants to know everything in there.",
          room = "offices", lean = 2, says = "Every book, every exhibit. I'll take notes.",
          intro = "I've read about every wonder in the world. A museum with whole worlds inside it? I'm not missing that.",
          payoff = "Thessaly runs a finger along the archivist's shelves. Every book and every note in here: this is what she came for." },
        { id = "hermit", name = "Wonder", text = "After years with her books, other worlds behind a caravan curtain are too good to pass up.",
          room = "paintings", lean = 1, says = "Paintings of places that don't exist? Yes, please.",
          intro = "I've spent years with my books. Someone said there are other worlds behind that caravan's curtains. I want to see one.",
          payoff = "Thessaly stands in front of a painting of a place that doesn't exist, and forgets to breathe for a moment." },
    },
    dev = {
        { id = "soldier", name = "Duty", text = "If something in that caravan is killing people, it's inside the town walls. That makes it Brannoc's problem.",
          room = "lair", lean = 2, says = "Point me at whatever's doing the killing.",
          intro = "I was a soldier. If something in that caravan is killing people in this town, it's my job to stop it.",
          payoff = "Brannoc tightens his grip on his sword. Whatever has been killing people in this town is right here." },
        { id = "folk_hero", name = "Rumour", text = "The taverns say the museum is dark magic. Somebody has to go and look, so Brannoc will.",
          room = "garden", lean = 1, says = "Dark magic. Sure. I'll bring an axe.",
          intro = "The taverns say the museum's dark magic. Somebody should go in and hit the dark magic. I volunteered.",
          payoff = "Hedges that walk. Brannoc grins: the taverns were right, it is dark magic, and he gets to hit it." },
    },
    jess = {
        { id = "charlatan", name = "A con", text = "The gnome is running a con, and Pip isn't in on it. Unacceptable.",
          room = "street", lean = 2, says = "He's lying, and I want to know how good he is at it.",
          intro = "I know a con when I see one, and that gnome is running a good one. I want in.",
          payoff = "Pip watches Flitwidget work the crowd and grins. The gnome is good. Pip is better." },
        { id = "criminal", name = "Lying low", text = "A doorway to another world is a lovely place to lie low for a while.",
          room = "gift_shop", lean = 1, says = "Somewhere nobody's looking for me? Sold.",
          intro = "I need somewhere to lie low for a bit. A whole other world behind a curtain? Perfect.",
          payoff = "A shop inside a pocket world, behind a curtain nobody outside knows about. Pip puts her feet up: nobody will find her here." },
    },
    sam = {
        { id = "acolyte", name = "Faith", text = "Rumour says some exhibits mock the gods. Oswin has been asked to take a look.",
          room = "chamber", lean = 2, says = "Somebody should check it's not blasphemous. Gently.",
          intro = "My temple asked me to look at the museum. Some of the exhibits might be, um, blasphemous. I'll be polite about it.",
          payoff = "Oswin reads the chamber's old glyphs with care. Not blasphemous, just very, very old. He says a quiet prayer anyway." },
        { id = "urchin", name = "A bad feeling", text = "The museum seems harmless. Oswin can't shake the feeling that it isn't.",
          room = "hunting", lean = 1, says = "Something's off about the whole thing. I'll keep an eye out.",
          intro = "Everyone says the museum's harmless. I grew up on the streets, and I've got a bad feeling about it.",
          payoff = "Tracks laid as bait, hunters hiding in the dioramas: Oswin's bad feeling was right all along." },
    },
}

-- What each player adds when they're all in at the first session's introductions.
M.all_in = {
    mara = { "I've already started a notebook for the museum. Page one is just questions.", "I made Thessaly a library card. For a museum. I know." },
    dev = { "I sharpened Brannoc's greatsword. In my head. For an hour.", "His greatsword has a name. It's Ember." },
    jess = { "Pip has a lucky coin. It's not lucky. She stole it.", "Pip will be doing a voice for every exhibit. You've been warned." },
    sam = { "Oswin brought snacks for the museum. So did I.", "Oswin has a little prayer for doors. He says it at every door." },
}

-- What the heroes are in the prologue (adventure.enter puts it on the players).
M.heroes = {
    mara = { gist = "Thessaly, a wizard who wants to know everything", short = "Mysteries, reveals, notes. Long fights lose her." },
    dev = { gist = "Brannoc, a fighter who hits first", short = "Fights and cool weapons. Long talks lose him." },
    jess = { gist = "Pip, a rogue with sticky fingers", short = "Talking to NPCs in voice, and chaos. Don't cut her scenes short." },
    sam = { gist = "Oswin, a cleric who keeps everyone standing", short = "Friends, snacks, a fair clever fight. Don't put him on the spot." },
}

-- Session Zero for this adventure (adventure.enter swaps it into the shared Session Zero): a
-- pitch for the museum, not a campaign, and asks that touch what's really in it. A player's ask
-- stays theirs (they don't know what's in the book); the prep board is where it meets tonight's
-- rooms (MODULE.content says which rooms carry which tags). Keys match the shared ones, so the
-- rules that read them (a "grim" table takes its first harsh call on the chin) still do.
M.session_zero = {
    pitch = "What should the museum feel like?",
    tones = {
        mixed = { name = "A spooky funhouse", blurb = "The book's own feel: weird rooms, real teeth, and a talking boot.",
                  says = { mara = "Creepy with a wink. As long as the Gorgon is properly scary.",
                           dev = "Funhouse with monsters in it? Sold.",
                           jess = "A talking boot. I've already decided Pip loves it.",
                           sam = "Spooky but fun. I can do that." } },
        heroic = { name = "Monster hunters", blurb = "Big heroes clean out a haunted museum and save the town.",
                   says = { mara = "Fine, but the museum's mysteries should still matter.",
                            dev = "We hunt monsters. Perfect.",
                            jess = "Pip, monster hunter. Pip would like a hat for this.",
                            sam = "Heroes saving a town. That's a good Thursday." } },
        grim = { name = "Proper horror", blurb = "Statues that were people, a dead man at his desk. Real fear.",
                 says = { mara = "Yes. The museum should feel wrong.",
                          dev = "Scary fights? I'm listening.",
                          jess = "Can Pip still be funny while everyone screams?",
                          sam = "I come here to unwind, not to have nightmares." } },
        silly = { name = "A cartoon caper", blurb = "A gnome, a boot, and a Gorgon who'd like you to sit down for a drink.",
                  says = { mara = "Then nobody cares what's really in the jar.",
                           dev = "Do cartoon hedges still count as fights?",
                           jess = "CARTOON GORGON.",
                           sam = "Low stress. I can do low stress." } },
    },
    asks = {
        mara = { kind = "line", content = "gore",
                 text = "No gore. People can die in it, but I don't want anything gruesome described. Not on screen, not off it.",
                 agree = { label = "Agreed. That's a line.", reply = "Thank you. That one matters to me." },
                 push = { label = "Can it happen off screen?", reply = "I'd really rather it didn't. But okay." } },
        sam = { kind = "veil", content = "bugs",
                text = "Bugs can be in it. Just don't describe them crawling on anyone. Fade to black?",
                agree = { label = "Creepy-crawlies stay off screen.", reply = "Amazing. I'll stop dreading every jar." },
                push = { label = "Let's see how it goes.", reply = "Oh. Okay. I'll just brace myself, I guess." } },
        jess = { text = "Let Pip talk to people. Flitwidget, the boot, even the Gorgon. Don't cut my chats short to get to a fight.",
                 agree = { reply = "YES. Pip has questions for every exhibit that talks." } },
    },
    rules = {
        length = { about = "When each night of the museum ends. A room can still run long or short." },
    },
}
-- Real prep for a room of the book, on the prep board under each room (museum_week.room_prep):
-- the people you'll voice, the props and handouts to have ready. The minis come from the room's
-- fight, the Session Zero check from M.content.
M.prep_notes = {
    street = { voices = { "Flitwidget: quick, proud, a showman who changes the subject" } },
    garden = { handouts = { "the iron plaque by the pond" } },
    entrance = { handouts = { "the sign on the donation box" } },
    chamber = { handouts = { "the cracked tablet", "the notebook of glyphs" } },
    paintings = { handouts = { "a painting for each hero" } },
    gift_shop = { voices = { "Telpur: a demon lord stuck in a boot, grand and bored" }, handouts = { "Telpur's price list" } },
    hunting = { handouts = { "the trail of scratch marks" } },
    offices = { handouts = { "the archivist's notebook", "the secret note" } },
    tomorrow = { voices = { "the ceiling: a delighted game-show host" }, handouts = { "the grid code in the Mech's chest" } },
    lecture = { voices = { "the Lecturer: a monotone that never stops" } },
    lair = { voices = { "Euryale: calm, a gracious host, cold when crossed" }, handouts = { "the tapestry of three sisters" } },
}
M.content_names = { gore = "gore", bugs = "creepy-crawlies" }
-- Which rooms carry which Session Zero content tags (the prep board's lines-and-veils check, and
-- what plays softly at the table when a tag is veiled or under a line: text_if { soft = tag }).
M.content = {
    gore = { offices = "the archivist at his desk, with eyes carved into his arms" },
    bugs = { chamber = "the Bone Construct bursts into a swarm of scarabs",
             hunting = "kruthik huntlings, armoured and many-legged",
             lair = "scarabs or huntlings at her side, if they're on her card" },
}

-- The museum's rooms. part: which floor of the story. type: the scene type it plays as.
-- quick: a short room (a hook, a beat, a rest). cost: prep hours. next: the way the story runs on
-- from here (prep reads ahead along it; the doors themselves are M.links below). stop: the night
-- can end after this room.
-- encounter: the fight (monster ids from game/rules/data/monsters.lua; the first is the boss).
-- optional_fight: the fight only happens if a moment says so. at: where it sits on the map (0-100).
M.start = "street"
M.rooms = {
    street = {
        name = "The street", part = 1, type = "social", quick = true, cost = 1, at = { 50, 98 }, map = "Street",
        comps = { location = "mus_street", cast = "mus_flitwidget", goal = "mus_take_job", complication = "mus_crowd" },
        read = "Everyone in town is talking about the new museum. The talk leads to a crowded back street, and a gnome on the roof of a caravan.",
        sum = "Meet Flitwidget, hear about the Gorgon, take the job.",
        next = { "garden" }, knobs = { "pry" },
    },
    garden = {
        name = "The garden", part = 1, type = "combat", cost = 2, at = { 50, 86 }, map = "Garden",
        comps = { location = "mus_garden", cast = "mus_briar", goal = "mus_cross_garden", complication = "mus_tentacles", reward = "mus_francs" },
        encounter = { "briar_triceratops", "briar_boar", "briar_beast" }, boss_name = "the briar triceratops",
        -- The topiary comes alive where it stands (fight.lua): each foe steps off the hedge it was
        -- (the horned one by the pond, the bristly one by the doors, a cat on the terrace), and
        -- that hedge is gone from the mat. A hedge nobody became stays a hedge.
        wake = { feature = "beasts", at = { briar_triceratops = { 10, 9 }, briar_boar = { 10, 2 }, briar_beast = { 4, 5 } } },
        read = "Three curtains, then grass underfoot. A garden that can't fit in a caravan, a dark pond, and hedges cut into beasts.",
        sum = "Living topiary, a pond with something in it, and a sign that says to use water.",
        next = { "entrance" }, knobs = { "elements", "curtain" },
    },
    entrance = {
        name = "The entrance hall", part = 1, type = "social", quick = true, cost = 1, at = { 50, 74 }, map = "Entrance",
        comps = { location = "mus_entrance", cast = "mus_sentinel", goal = "mus_donation", complication = "mus_statue", reward = "mus_boon" },
        encounter = { "sentinel" }, boss_name = "the Sentinel", optional_fight = true,
        read = "Huge carved doors open on marble and blue light. Two signed doors at the far end, and a metal guard between them.",
        sum = "A donation box full of every coin in the world, and the guard that protects it.",
        next = { "chamber", "paintings" },
    },
    chamber = {
        name = "The Chamber of Ancients", part = 1, type = "puzzle", cost = 2, at = { 26, 62 }, map = "Ancients",
        comps = { location = "mus_chamber", cast = "mus_bone_construct", goal = "mus_ritual", complication = "mus_scarab_cracks", reward = "mus_francs" },
        encounter = { "bone_construct" }, boss_name = "the Bone Construct", optional_fight = true,
        read = "Sandstone columns and a hot, whispering wind. A guardian of gold and bone stands among old jars and a cracked tablet.",
        sum = "A bone guardian that a water ritual can calm, if anyone reads the tablet.",
        next = { "paintings", "gift_shop" }, knobs = { "hint" },
    },
    paintings = {
        name = "The Hall of Paintings", part = 1, type = "exploration", cost = 2, at = { 74, 62 }, map = "Paintings",
        comps = { location = "mus_paintings", cast = "mus_knight", goal = "mus_cross_hall", complication = "mus_paint_pull", reward = "mus_paint_kit" },
        encounter = { "knight_of_shades" }, boss_name = "the Knight of Shades", optional_fight = true,
        read = "A long hall hung with paintings of kings, monsters and impossible places. It smells of wet paint.",
        sum = "Paintings you can reach into, and a knight that climbs out of one.",
        next = { "chamber", "gift_shop" }, knobs = { "portrait", "dice" },
    },
    gift_shop = {
        name = "The gift shop", part = 1, type = "downtime", quick = true, cost = 1, at = { 50, 50 }, map = "Gift shop", stop = true, rest = true,
        comps = { location = "mus_gift_shop", cast = "mus_telpur", goal = "mus_shop", complication = "mus_no_refunds", reward = "mus_shop_goods" },
        read = "A quiet little shop at the foot of the stairs: shelves of souvenirs, a bowl of marbles, and a boot asleep on the counter.",
        sum = "A rest, Telpur the talking boot, and somewhere to spend Flitwidget Francs. The book's place to stop for the night.",
        next = { "hunting" }, knobs = { "comedy" }, level = 3,
        callbacks = {
            { when = { flag = "spork" }, text = "On the counter, between the marbles: the vorpal spork, as promised. Telpur won't sell it. \"Display only.\"" },
        },
    },
    hunting = {
        name = "The Hunting Grounds", part = 2, type = "combat", cost = 2, at = { 50, 37 }, map = "Hunting Grounds",
        comps = { location = "mus_hunting", cast = "mus_huntlings", goal = "mus_hunt", complication = "mus_lure", reward = "mus_mirror" },
        encounter = { "kruthik_huntling", "kruthik_huntling", "kruthik_huntling", "kruthik_huntling", "kruthik_huntling" },
        boss_name = "the biggest huntling",
        read = "Up the stairs, a floor full of dioramas and stuffed beasts. It's messier up here, and something is watching.",
        read_if = { { when = { soft = "bugs" }, text = "Up the stairs, a floor full of dioramas and stuffed beasts. It's messier up here. Something in the exhibits is hunting, and you keep it in the shadows." } },
        sum = "Pack hunters hiding among the exhibits. They bait traps, and they run when they're losing.",
        next = { "offices", "tomorrow", "lecture", "stairs" }, knobs = { "marks" },
    },
    offices = {
        name = "The offices", part = 2, type = "mystery", cost = 2, at = { 20, 24 }, map = "Offices",
        comps = { location = "mus_offices", goal = "mus_archivist", complication = "mus_whispers", reward = "mus_notebook" },
        read = "Two quiet studies off the hunting floor. One door is locked from the inside.",
        sum = "A six-winged bird, a dead archivist, and the first hint of something called the Witness. No fight.",
        next = { "tomorrow", "lecture", "stairs" }, knobs = { "witness" },
    },
    tomorrow = {
        name = "The World of Tomorrow", part = 2, type = "puzzle", cost = 1, at = { 50, 24 }, map = "Tomorrow",
        comps = { location = "mus_tomorrow", cast = "mus_mech", goal = "mus_wake_mech", complication = "mus_panel", reward = "mus_mech_ally" },
        read = "Static, neon, and a delighted voice from the ceiling welcoming them to the future.",
        sum = "A brass war machine that obeys whoever cracks its code and speaks its name.",
        next = { "offices", "lecture", "stairs" }, knobs = { "timer" },
    },
    lecture = {
        name = "The lecture theatre", part = 2, type = "combat", cost = 2, at = { 80, 24 }, map = "Lecture",
        comps = { location = "mus_lecture", cast = "mus_lecturer", goal = "mus_silence", complication = "mus_drone", reward = "mus_sleep_notes" },
        encounter = { "the_lecturer" }, boss_name = "the Lecturer",
        read = "Benches, dust, cobwebs, and a lecture that's been going on for a hundred years.",
        sum = "A ghost whose lecture is so dull it puts people to sleep for good.",
        next = { "offices", "tomorrow", "stairs" },
    },
    stairs = {
        name = "The stairs up", part = 2, type = "exploration", quick = true, cost = 0, at = { 50, 12 }, map = "Stairs", stop = true, virtual = true,
        read = "At the far end of the hunting floor, a narrow stair climbs toward a smell of smoke and wine.",
        read_if = { { when = { done = "offices" }, text = "Between the two studies, a narrow stair climbs toward a smell of smoke and wine." } },
        sum = "Up to Euryale. The night stops at the top step.",
        next = { "lair" },
    },
    lair = {
        name = "The Gorgon's lair", part = 3, type = "set_piece", cost = 2, at = { 50, 1 }, map = "Gorgon's lair", boss = true,
        comps = { location = "mus_lair", cast = "mus_euryale", goal = "mus_face_her", complication = "mus_stare", reward = "mus_quiet" },
        encounter = { "euryale" }, boss_name = "Euryale",
        read = "The stairs end in a room like a temple, full of statues that were people once.",
        sum = "Euryale, and everything the party did on the way up.",
        next = {},
        -- Said as the room starts, when they hold: what the week between promised, paying off here.
        callbacks = {
            { when = { flag = "she_read" }, text = "The archivist's notebook lies open on her couch. \"Your Witness writes beautifully,\" Euryale says. She has read every page." },
        },
    },
    -- Not on the map: boss night's last scene, back downstairs, once she's dealt with (the book's
    -- ending, played as a scene so the finale is a whole evening and not one fight and a goodbye).
    thanks = {
        name = "Flitwidget's thanks", part = 3, type = "social", cost = 0, epilogue = true,
        comps = { location = "mus_gift_shop", cast = "mus_flitwidget", goal = "mus_settle_up", reward = "mus_thanks" },
        read = "Back down in the gift shop, Flitwidget has put out tea, a plate of biscuits and a very small cash box.",
        sum = "The reward, a pick from the shop, and what comes next.",
        callbacks = {
            -- (Telpur's own shop: the wrap-up remembers him, the second playtest review. F4.)
            { when = { flag = "telpur_fell" }, text = "Telpur is back on his counter with a sock tied round his middle like a bandage. He tells everyone who'll listen how he took a hit for the party." },
            { when = { flag = "telpur_along", not_flag = "telpur_fell" }, text = "Telpur hops back onto his counter, laces still dusty from upstairs, and starts telling everyone how he saved the day." },
            { when = { flag = "told" }, text = "\"Telpur told me everything, you know,\" says Flitwidget, pouring the tea. \"Everything.\" He doesn't say which bits he minded." },
            { when = { flag = "guards" }, text = "Flitwidget has already told the next town they're his caravan guards. Nobody remembers agreeing to it." },
            { when = { flag = "vorpal_lair" }, text = "And behind Euryale's couch, right where you said it would be: a vorpal sword. It's {given}'s now.",
              give = { magic = "vorpal_sword", who = "dev" } },
        },
    },
}
-- Once a night, as the first fight starts (museum_night.arm), when they hold: what the week
-- between left them with. no_sneak: nobody gets the drop on anyone this time.
M.asides = {
    { id = "fussed", when = { flag = "fussed" }, no_sneak = true,
      text = "Flitwidget's voice floats up from somewhere below: \"Everything all right up there? Anybody dead?\" So much for sneaking up on anything." },
    { id = "shoelace", when = { holds_here = "shoelace" }, owner = "jess",
      intro = "Pip has a new shoelace tonight, a present from Telpur's own boot. It talks. It hasn't stopped since the gift shop.",
      text = "Pip's talking shoelace, one of Telpur's, has advice for everyone. Nobody asked." },
    { id = "telpur", when = { flag = "telpur_along" }, no_sneak = true,
      text = "Telpur, tied to a pack strap, has opinions about every exhibit, out loud. Whatever's in here knows they're coming." },
}
-- An ally fighting beside them who didn't walk in with them: said as the fight starts, the first
-- time it's there tonight (companions.ally_arrives, museum_night.arm).
M.ally_join = {
    steam_mech = "{mech} clanks up the stairs behind them, steam hissing, and takes its place in the line.",
}
-- "Last time, they ..." at the start of a night: what each room came to, as a clause.
M.recap = {
    street = { win = "took Flitwidget's job", lose = "took Flitwidget's job without the whole story" },
    garden = { win = "got through the living garden", lose = "got through the garden, scratched and bleeding" },
    entrance = { win = "got past the donation box and its guard", lose = "fled the entrance hall's guard" },
    chamber = { win = "stilled the Bone Construct", lose = "barely got away from the Bone Construct" },
    paintings = { win = "crossed the Hall of Paintings", lose = "backed out of the Hall of Paintings" },
    gift_shop = { win = "rested in the gift shop with Telpur", lose = "dozed through Telpur's rules in the gift shop" },
    hunting = { win = "beat the huntlings on the second floor", lose = "held off the huntlings, just" },
    offices = { win = "found the archivist's notebook", lose = "left the offices with more questions than answers" },
    tomorrow = { win = "woke the Steam Mech", lose = "couldn't wake the Steam Mech" },
    lecture = { win = "silenced the Lecturer", lose = "staggered out of the Lecturer's class" },
    stairs = { win = "climbed the stairs to Euryale's door", lose = "climbed the stairs to Euryale's door" },
    lair = { win = "faced Euryale", lose = "faced Euryale, and she sent them back down the stairs" },
}

-- How the rooms join, door to door, as on the book's maps (each way). The party walks through
-- rooms it has cleared without stopping; going back to one has to be for a reason (museum_night:
-- a second look, a hint, a rest or the shop, fleeing). Once inside the caravan nobody goes back
-- out to the street.
M.links = {
    { "street", "garden" }, { "garden", "entrance" },
    { "entrance", "chamber" }, { "entrance", "paintings" },
    { "chamber", "gift_shop" }, { "paintings", "gift_shop" },
    { "gift_shop", "hunting" },
    { "hunting", "offices" }, { "hunting", "tomorrow" }, { "hunting", "lecture" },
    { "hunting", "stairs" }, { "offices", "stairs" },
    { "stairs", "lair" },
}
M.no_return = { street = true }
-- What a second look at a cleared room can still turn up: its moments that hand out something
-- (a weapon from a painting, the key in the pond, the polished door). A room has "something
-- missed" while one of these was never played or was passed up.
M.second_look = {
    garden = { "mus_pond" }, entrance = { "mus_box" }, chamber = { "mus_tidy" },
    paintings = { "mus_reach" }, hunting = { "mus_mirror" }, tomorrow = { "mus_code" },
}
-- Why the table would go back somewhere ({names}, {want}, {room}).
M.revisit_why = {
    missed = "{names} {want} another look at {room}. They're sure they missed something in there.",
    hint = "You let slip that {room} still has something in it.",
    passed = "{names} {want} to see {room}. They walked right past it.",
    shop = "{names} {want} to nip back to the gift shop and spend some Francs.",
    rest = "Everyone's hurting. {names} {want} to fall back to the gift shop for a breather.",
}
M.order = { "street", "garden", "entrance", "chamber", "paintings", "gift_shop", "hunting", "offices", "tomorrow", "lecture", "stairs", "lair" }

-- A fork's question, by the rooms on offer.
M.forks = {
    wings = { text = "Two gold-and-mahogany signs: the Chamber of Ancients one way, the Hall of Paintings the other. The table splits.",
              title = "Which wing?" },
    second_wing = { text = "One wing done. The other is right there, and so is the gift shop at the foot of the stairs.", title = "The other wing?" },
    hub = { text = "Three doors off the hunting floor, and a narrow stair going up. Everyone has an opinion.", title = "Where next?" },
    roam = { text = "There's a way on. There's also a reason to go back.", title = "Onward, or back?" },
}
-- What the party sees from where it's standing, at a fork (museum_night.fork): by the room they're
-- in, never by the rooms on offer (the playtest, Nov 2: "Three doors off the hunting floor" said in
-- the garden). A room not listed gets the plain words. after: { rooms, text }, said instead once
-- all those rooms are done.
M.fork_at = {
    street = { text = "The caravan's curtains stand open. The crowd has wandered off." },
    garden = { text = "Behind them, the garden. Ahead, the museum doors at the top of the broken steps." },
    entrance = { text = "Two gold-and-mahogany signs: the Chamber of Ancients one way, the Hall of Paintings the other.",
                 after = { rooms = { "chamber", "paintings" }, text = "Back in the entrance hall's blue light, with both wings behind them." } },
    chamber = { text = "The Chamber of Ancients is behind them, its hot wind dying down." },
    paintings = { text = "The Hall of Paintings is behind them, its frames still dripping." },
    gift_shop = { text = "The gift shop: a curtain back to the wings, and a narrow stair going up." },
    hunting = { text = "Three doors off the hunting floor, and a narrow stair going up." },
    offices = { text = "Out of the studies, back onto the hunting floor." },
    tomorrow = { text = "Out of the World of Tomorrow, back onto the hunting floor." },
    lecture = { text = "Out of the lecture theatre, back onto the hunting floor, ears still ringing." },
}
-- What each room promises at a fork, and who it pulls (archetype weights add to each friend's tastes).
M.pull = {
    garden = { label = "Through the curtains, into the garden", want = "to get into the garden", tags = { "explore", "danger" } },
    entrance = { label = "On into the museum", want = "to get inside", tags = { "explore" } },
    hunting = { label = "Up the stairs to the second floor", want = "to see what's upstairs", tags = { "explore", "danger" } },
    chamber = { label = "The Chamber of Ancients", want = "the Chamber of Ancients", tags = { "puzzle", "lore", "danger" } },
    paintings = { label = "The Hall of Paintings", want = "the Hall of Paintings", tags = { "explore", "mystery", "funny" } },
    gift_shop = { label = "On to the gift shop", want = "to head on to the gift shop", tags = { "cozy", "loot" } },
    offices = { label = "The offices", want = "the offices", tags = { "lore", "mystery" } },
    tomorrow = { label = "The World of Tomorrow", want = "the World of Tomorrow", tags = { "puzzle", "loot" } },
    lecture = { label = "The lecture theatre", want = "the lecture theatre", tags = { "danger", "funny" } },
    stairs = { label = "Up the stairs, now", want = "to go up the stairs now", tags = { "action", "danger" } },
}

-- How the DM can run each room (the book's own advice, made into choices). like: how each
-- friend takes it when it's on (-2..2). cost: extra prep hours. pick_hero: choose a hero for it.
M.knobs = {
    pry = { room = "street", name = "Make them pry for the truth", off = "Flitwidget just tells them",
            like = { mara = 1, dev = 0, jess = 2, sam = -1 },
            blurb = "He hides the Gorgon behind 'incidents with the exhibits' until someone gets it out of him." },
    elements = { room = "garden", name = "Tell them every room has things to use", off = "Let them find out",
                 like = { mara = -1, dev = 1, jess = 0, sam = 2 },
                 say = "You tell the table up front: every room has things in it they can use. Eyes light up.",
                 blurb = "The book rewards using a room's stuff (shears, a sledgehammer, the pond). Saying so up front means they'll try." },
    curtain = { room = "garden", name = "The curtain closes behind them", off = "The way out stays open",
                like = { mara = 2, dev = 1, jess = 0, sam = -2 },
                say = "Behind them, the black curtain is gone. There's no way back but through.",
                blurb = "No way back until it's done. Tense, and Sam hates it." },
    hint = { room = "chamber", name = "Hint the guardian needn't be fought", off = "Let them work it out",
             like = { mara = 1, dev = -1, jess = 0, sam = 2 },
             say = "You let your eyes linger on the cracked tablet as you describe it. Mara notices.",
             blurb = "The book suggests it for new players: not every enemy has to die." },
    portrait = { room = "paintings", name = "Hang a painting picked for one hero", off = "Just the book's paintings", cost = 1,
                 pick_hero = true, like = { mara = 0, dev = 0, jess = 0, sam = 0 },
                 blurb = "The book says to add paintings that suit your heroes. Whoever it's for gets the hall's big moment." },
    dice = { room = "paintings", name = "Keep the painting of five people rolling dice", off = "Cut it",
             like = { mara = -1, dev = 0, jess = 2, sam = 1 },
             blurb = "A painting of a table, dice, and someone behind a screen. It breaks the fourth wall." },
    comedy = { room = "gift_shop", name = "Play Telpur as a comedy break", off = "Play Telpur straight",
               like = { mara = -1, dev = 0, jess = 2, sam = 1 },
               blurb = "A silly voice, a lot of rules about refunds, and a breather before upstairs." },
    marks = { room = "hunting", name = "Leave scratch marks that hint at the ambush", off = "No hint",
              like = { mara = 1, dev = 0, jess = -1, sam = 2 },
              blurb = "A fair warning that the tracks are bait. Without it, the huntlings get the jump on them." },
    witness = { room = "offices", name = "Keep the Witness in, as a thread for later", off = "Leave it out",
                like = { mara = 2, dev = -1, jess = 1, sam = 0 },
                blurb = "The archivist was studying something huge. A hook for the full campaign." },
    timer = { room = "tomorrow", name = "Run the code on a real 30-second timer", off = "Take their time",
              like = { mara = 0, dev = 1, jess = 1, sam = -2 },
              blurb = "Real pressure at the real table. Sam hates being put on the spot." },
}

-- The painting each hero gets if the DM hangs one for them (all from the book's gallery).
M.portraits = {
    mara = { painting = "a lady by an icy mountain road, looking straight out at Thessaly", gift = "nothing to take, only a question she can't stop thinking about", empty = true },
    dev = { painting = "a warrior in scarlet armour on a bridge, sword raised", gift = "the warrior's own blade, made of paint" },
    jess = { painting = "a smug duellist with a pistol in each hand", gift = "a painted pistol with one shot in it" },
    sam = { painting = "an empty golden throne with bats carved into it", gift = "a glass of something red that is definitely not wine" },
}

-- Room moments: the calls each room puts to the DM on game night. at: "start" (before the room's
-- fight or checks), "mid" (between), "end" (after), "follow" (only after an option's then_moment).
-- Rooms play them in this order. party = true: a choice that's the players' to make, never the DM's
-- (the playtest, November 3): the table talks it over (museum_night.table_pick), each option's `want`
-- is how they say it, and the DM only nudges when they ask. roll.best: the best at the skill rolls.
M.moments = {
    -- The street ---------------------------------------------------------------------------------
    { id = "mus_truth", room = "street", at = "start", when = { knob = "pry" }, type = "story",
      actor = { "instigator", "method_actor", "storyteller" },
      title = "\"Incidents with the exhibits\"",
      text = "{actor_char} doesn't buy the gnome's story for a second. 'Incidents' is doing a lot of work.",
      options = {
          { label = "Let them pry. Roll against his bluster.",
            roll = { dc = 12, skill = { "insight", "persuasion", "intimidation" }, convenient = "success",
                     success = { log = "He cracks. A Gorgon in a jar, a jar that broke, and visitors who never came out. His assistant Telpur is still inside.",
                                 effects = { { "actor", spotlight = 10 }, { "arch:storyteller", story = 6, fun = 4 }, { "arch:instigator", fun = 5 } },
                                 mus = { flag = "truth", aspect = "Got the truth out of Flitwidget" } },
                     fail = { log = "He beams, waves his hat, and changes the subject to the gift shop. They're going in half blind.",
                              effects = { { "arch:storyteller", story = 3 }, { "arch:tactician", fun = -2 } } } } },
          { label = "He tells them anyway. Get them to the garden.",
            log = "Flitwidget drops his voice: a Gorgon called Euryale, a broken jar, and people who didn't come out.",
            effects = { { "arch:casual", fun = 3 }, { "arch:tactician", fun = 2 }, { "arch:instigator", fun = -3 } },
            mus = { flag = "truth" } },
      } },
    { id = "mus_francs_intro", room = "street", at = "end", type = "story", actor = { "power_gamer", "instigator", "casual" },
      title = "Flitwidget Francs",
      text = "Flitwidget holds up a crisp green note with his own face on it. 'Deal with my exhibits, and these appear in your pockets. Spend them in the gift shop!'",
      options = {
          { label = "Explain the Francs properly. Some players love a currency.",
            log = "One Franc per beaten exhibit, solved puzzle, or clever use of the museum's own things.",
            effects = { { "arch:power_gamer", fun = 5, reward = 4 }, { "arch:tactician", fun = 3 }, { "arch:storyteller", boredom = 3 } },
            table_min = 3 },
          { label = "Keep it a surprise. They'll find out.",
            log = "\"You'll see!\" says Flitwidget, and shoos them up the steps. \"There's a lot more of it than there looks, trust me!\"",
            effects = { { "arch:explorer", fun = 3 }, { "arch:storyteller", fun = 2 } } },
      } },

    -- The garden ----------------------------------------------------------------------------------
    { id = "mus_plaque", room = "garden", spot = "1A", at = "start", type = "story", actor = { "explorer", "tactician", "storyteller" }, party = true,
      title = "A sign by the pond",
      text = "{actor_char} finds a little iron plaque by the pond: \"Mind the hedges. If they get lively, try the water.\" Signed FF.",
      options = {
          { label = "Use the water. Douse the hedges.", want = "douse the hedges with pond water",
            log = "Helmets full of pond water hit the topiary. The smallest hedge-beast twists, sprouts and roots itself to the spot. The big ones keep coming.",
            effects = { { "actor", spotlight = 8 }, { "arch:explorer", fun = 5 }, { "arch:tactician", fun = 5 }, { "all", challenge = -4 } },
            mus = { francs = 1, drop = { "briar_beast" }, flag = "water" } },
          { label = "They're bushes. Set them on fire.", want = "set the bushes on fire",
            log = "Oil, a torch, and a whoosh. Half the garden goes up like kindling, and the briar boar with it.",
            effects = { { "arch:butt_kicker", fun = 6 }, { "arch:instigator", fun = 4 }, { "arch:storyteller", fun = -2 }, { "all", challenge = -4 } },
            mus = { drop = { "briar_boar" }, mark = "garden_burned" } },
          { label = "Just fight them. Steel, not water.", want = "just fight them",
            log = "Blades out. The hedges come at them all at once.",
            effects = { { "arch:butt_kicker", fun = 4 }, { "all", challenge = 6 } } },
      } },
    { id = "mus_pond", room = "garden", danger = "the pond: something with tentacles lives in it", spot = "pond", at = "end", type = "story", actor = { "instigator", "explorer" },
      title = "The dark pond",
      text = "{actor_char} wants a closer look at the pond. As they lean over the water, a grey tentacle slides up through the lilies, tastes the air, and sinks back down. Everyone saw it.",
      options = {
          { label = "Let them. They know what's in there.",
            roll = { dc = 10, skill = { "acrobatics", "athletics" }, convenient = "success",
                     success = { log = "{actor_char} dodges a tentacle and fishes out a little brass key. Nobody knows what it opens. Yet.",
                                 effects = { { "actor", spotlight = 8, fun = 5 } }, mus = { risk = true, francs = 1, flag = "brass_key", aspect = "Fished a brass key out of a haunted pond" } },
                     fail = { log = "A tentacle wraps {actor_char}'s ankle and drags them in up to the waist. They come out cut and furious.",
                              effects = { { "actor", spotlight = 6, challenge = 4 } }, mus = { risk = true, harsh = true, hurt = { 1, 6 }, drag = { "pond", "pond" }, aspect = "Was dragged into a haunted pond" } } } },
          { label = "\"Are you sure? It's got tentacles.\"",
            log = "{actor_char} thinks better of it. The pond burbles, disappointed.",
            effects = { { "arch:instigator", fun = -2 }, { "arch:casual", fun = 2 } }, mus = { warn = true } },
      } },

    -- The entrance hall -------------------------------------------------------------------------
    { id = "mus_box", room = "entrance", spot = "2B", at = "start", type = "story", actor = { "instigator", "method_actor" }, party = true,
      title = "The donation box",
      text = "A glass case of coins from every world, and a little card: \"Every coin keeps the lamps lit.\" {actor_char} looks at the case, then the lock, then the metal guard standing right there.",
      options = {
          { label = "Somebody drops a coin in.", want = "drop a coin in",
            log = "A coin clinks in, and the statue booms: \"YOUR GENEROSITY IS NOTED.\" Something warm settles over {actor_char}.",
            effects = { { "arch:casual", fun = 4 }, { "arch:method_actor", fun = 2 }, { "all", reward = 4 } },
            mus = { francs = 1, flag = "boon", inspire = "The museum thanks {char} for the donation.", careful = 1, favor = { who = "flitwidget", n = 1 } } },
          { label = "{actor_char} tries the lock.", want = "have a go at the lock", then_moment = "mus_box_lock",
            log = "{actor_char} cracks their knuckles and kneels by the case.",
            effects = { { "arch:instigator", fun = 3 } } },
      } },
    -- The DM's call once they go for the lock: let it ride (a roll, the guard right there), or stop it.
    { id = "mus_box_lock", room = "entrance", spot = "2B", at = "follow", type = "story", actor = { "instigator" },
      title = "Picks out",
      text = "{actor_char} has the picks out, with a metal guard the size of a wardrobe standing right there.",
      options = {
          { label = "Let it ride. Roll Sleight of Hand, with the guard right there.",
            roll = { dc = 13, skill = { "sleight_of_hand" }, convenient = "success",
                     success = { log = "Two picks, one click. A fistful of coins from a dozen worlds goes into {actor_char}'s pack, and the Sentinel steps down off its plinth.",
                                 effects = { { "actor", spotlight = 12, fun = 6 }, { "arch:instigator", fun = 6 }, { "arch:butt_kicker", fun = 4 }, { "arch:tactician", trust = -1 } },
                                 mus = { risk = true, fight = true, mark = "robbed", favor = { who = "flitwidget", n = -1 }, aspect = "Robbed a museum's donation box" } },
                     fail = { log = "The pick snaps in the lock with a ping. The Sentinel's head turns. Then the rest of it.",
                              effects = { { "actor", spotlight = 6, challenge = 4 }, { "arch:butt_kicker", fun = 4 }, { "arch:tactician", trust = -1 } },
                              mus = { risk = true, fight = true, favor = { who = "flitwidget", n = -1 }, aspect = "Tried to rob a museum's donation box" } } } },
          { label = "Rein them in, out of character: \"Not this one.\"",
            log = "You give {actor_char} a look over the screen. They put the picks away, sulking.",
            effects = { { "actor", fun = -6, trust = -1 }, { "others", fun = 2 } } },
      } },

    -- The Chamber of Ancients ------------------------------------------------------------------
    { id = "mus_tablet", room = "chamber", spot = "3E", at = "start", type = "story", actor = { "storyteller", "tactician", "explorer" }, party = true,
      title = "The cracked tablet",
      text = "{actor_char} kneels by the cracked tablet with the little notebook of glyphs, while the guardian lifts its staff.",
      options = {
          { label = "Work out the ritual. Someone holds it off.", want = "work out the ritual while someone holds the guardian off",
            roll = { dc = 12, skill = { "history", "investigation", "religion" }, convenient = "success",
                     success = { log = "Five gallons in the falcon, three in the jackal, and the goddess wants exactly four. Pour, tip, pour, tip, and onto the pedestal.",
                                 effects = { { "actor", spotlight = 14 }, { "arch:storyteller", fun = 6, story = 6 }, { "arch:tactician", fun = 6 }, { "arch:butt_kicker", fun = -3 } },
                                 mus = { no_fight = true, mark = "calmed", francs = 1, careful = 1, aspect = "Calmed a tomb guardian with an old ritual" } },
                     fail = { log = "The glyphs swim. It's going to be blades.",
                              effects = { { "arch:butt_kicker", fun = 3 } }, mus = { fight = true, flag = "ritual_failed" } } } },
          { label = "Skip the homework. Fight it.", want = "skip the homework and fight it",
            log = "Nobody needs a tablet to hit things. Weapons out.",
            effects = { { "arch:butt_kicker", fun = 6 }, { "arch:storyteller", fun = -3 }, { "arch:tactician", fun = -2 } },
            mus = { fight = true } },
      } },
    { id = "mus_falcon", room = "chamber", danger = "the falcon jar: the tablet's last lines say what happens to anyone who gets it wrong", spot = "3A", at = "mid", when = { flag = "ritual_failed" }, type = "screen", actor = { "instigator", "storyteller", "power_gamer" },
      title = "A discontented falcon",
      text = "As the guardian closes in, {actor_char} grabs the half-full falcon jar for the pedestal anyway. Nobody managed to read the tablet's last lines. You know what they say.",
      options = {
          { label = "Let them. They never read the warning.", sub = "Harsh, and out of nowhere for them.",
            log = "The pedestal flares. {actor_char} is flung across the room and lands hard, winded.",
            effects = { { "actor", spotlight = 10, challenge = 8 }, { "arch:butt_kicker", fun = 3 } },
            mus = { harsh = true, hurt = { 2, 6 }, aspect = "Was flung across a tomb by an unhappy goddess" } },
          { label = "\"Are you sure? Try the last line again.\"",
            log = "{actor_char} squints at the last line again, gets the gist, swears, and puts the jar down.",
            effects = { { "actor", fun = -2 }, { "arch:casual", fun = 2 } }, mus = { warn = true } },
      } },
    { id = "mus_tidy", room = "chamber", at = "end", type = "story", actor = { "casual", "tactician", "instigator" }, party = true,
      title = "Put it all back?",
      text = "The chamber's a mess: jars, daggers, the tablet and the little notebook, scattered across the sand.",
      options = {
          { label = "Tidy up. Flitwidget will notice.", want = "tidy up for Flitwidget",
            log = "Everything goes back on its plinth. A Franc materialises in {actor_char}'s pocket.",
            effects = { { "arch:casual", fun = 4 }, { "arch:butt_kicker", boredom = 4 } },
            mus = { francs = 1, careful = 1, favor = { who = "flitwidget", n = 1 } } },
          { label = "{actor_char} pockets the twin daggers.", want = "keep the twin daggers",
            log = "Two curved daggers, rings locked together through the hilts. They're not coming apart, but they're coming along.",
            effects = { { "actor", fun = 5, reward = 5 }, { "arch:storyteller", fun = -1 } }, mus = { flag = "daggers", aspect = "Kept two daggers that won't come apart" } },
          { label = "Leave it. Onward.", want = "leave the mess and move on",
            log = "They step over the mess and keep moving.", effects = { { "arch:butt_kicker", fun = 1 } } },
      } },

    -- The Hall of Paintings --------------------------------------------------------------------
    { id = "mus_reach", room = "paintings", danger = "the paintings: reach in and the cold bites", at = "start", type = "story", actor = { "explorer", "instigator", "method_actor" },
      title = "The paint is wet",
      text = "{actor_char} leans close to {painting}. The paint is wet, and frost glitters on the frame. A hand would go right in.",
      options = {
          { label = "Let them reach in. They've seen the frost.",
            roll = { dc = 12, skill = { "athletics", "acrobatics", "arcana" }, convenient = "success",
                     success = { log = "{actor_char} pulls out {gift}, still wet. It'll last about an hour out here.",
                                 effects = { { "actor", spotlight = 12, fun = 6, reward = 6 }, { "arch:explorer", fun = 4 } },
                                 mus = { risk = true, flag = "paint", francs = 1, aspect = "Pulled a weapon out of a painting" },
                                 -- (A painting with nothing to give, as in the book: no weapon, and no paint to drip later.)
                                 empty = { log = "{actor_char} reaches in to the elbow. Nothing to take: the lady in the painting only looks back, and leaves {actor_char} with a question that won't go away.",
                                           effects = { { "actor", spotlight = 10, fun = 5, story = 4 }, { "arch:explorer", fun = 4 } },
                                           mus = { risk = true, francs = 1, aspect = "Reached into a painting and came back with a question" } } },
                     fail = { log = "The painting bites. {actor_char} pulls back an arm numb to the elbow, empty-handed.",
                              effects = { { "actor", spotlight = 6, challenge = 5 } }, mus = { risk = true, harsh = true, hurt = { 1, 4 }, aspect = "Got frostbite from a painting" } } } },
          { label = "\"Those frames are frosted for a reason.\"",
            log = "{actor_char} keeps their hands in their pockets. The painted figure looks almost disappointed.",
            effects = { { "arch:explorer", fun = -2 }, { "arch:casual", fun = 2 } }, mus = { warn = true } },
      } },
    { id = "mus_dice_painting", room = "paintings", spot = "4C", at = "mid", when = { knob = "dice" }, type = "table", actor = { "method_actor", "instigator", "casual" },
      title = "Five people and some dice",
      text = "A small painting: five people round a table, rolling dice. One sits behind a little screen. {actor_char} stops dead. They look familiar.",
      options = {
          { label = "Lean in. The painted DM gives them a little wave.",
            log = "Somebody at the real table actually screams. Then everybody laughs.",
            effects = { { "arch:method_actor", fun = 7 }, { "arch:casual", fun = 5 }, { "arch:storyteller", fun = -2 }, { "all", social = 6 } },
            table_min = 2 },
          { label = "It's just a painting. Move on.",
            log = "\"Weird,\" says {actor_char}, and moves on. Nobody can stop glancing back at it.",
            effects = { { "arch:storyteller", fun = 2 } } },
      } },
    { id = "mus_knight_frame", room = "paintings", spot = "4K", at = "mid", type = "story", actor = { "explorer", "butt_kicker", "instigator" }, party = true, proposes = 1,
      title = "The Knight of Shades",
      text = "At the end of the hall, the black knight's portrait. {actor_char} wants a closer look. Its oils seem to shift.",
      options = {
          { label = "Take a closer look. Whatever happens, happens.", want = "take a closer look at the knight",
            log = "The knight grips the edge of its frame and climbs out, oil streaming off its armour.",
            effects = { { "arch:butt_kicker", fun = 5 }, { "arch:explorer", fun = 3 }, { "all", challenge = 6 } },
            mus = { fight = true, aspect = "Woke the Knight of Shades" } },
          { label = "Give it a wide berth.", want = "give the knight a wide berth",
            log = "Nobody goes near it. The knight's painted eyes follow them all the way to the door.",
            effects = { { "arch:casual", fun = 3 }, { "arch:butt_kicker", fun = -4 } },
            mus = { no_fight = true, mark = "knight" } },
      } },
    { id = "mus_return_paint", room = "paintings", at = "end", when = { flag = "paint" }, type = "story", actor = { "casual", "tactician" }, party = true,
      title = "Put the paint back?",
      text = "The painted weapons are starting to drip. {actor_char} could slide them back into their paintings before they melt.",
      options = {
          { label = "Put them back. It feels polite.", want = "put the painted weapons back",
            log = "Each one slides home. A Franc appears, and the duellist in the frame tips his hat.",
            effects = { { "arch:casual", fun = 3 } }, mus = { francs = 1, careful = 1, favor = { who = "flitwidget", n = 1 } } },
          { label = "Keep them till they drip away.", want = "keep them till they drip away",
            log = "They carry them out, dripping. By the gift shop they're puddles.", effects = { { "arch:power_gamer", fun = 2 } } },
      } },

    -- The gift shop ---------------------------------------------------------------------------
    { id = "mus_telpur_bit", room = "gift_shop", at = "start", when = { knob = "comedy" }, type = "table", actor = { "method_actor", "instigator", "casual" },
      title = "Telpur, Duke of Somewhere",
      text = "Telpur clears their throat, which is hard for a boot. \"Once I was a great lord of the underworld. Now I do the till. No refunds.\"",
      options = {
          { label = "Do the voice. All of it.",
            log = "The voice is terrible. Jess cries laughing. Sam has to put his drink down.",
            effects = { { "arch:method_actor", fun = 8 }, { "arch:casual", fun = 5 }, { "arch:storyteller", fun = -2 }, { "all", social = 8 } },
            table_min = 4, mus = { favor = { who = "telpur", n = 1 } } },
          { label = "Keep it short. There's a Gorgon upstairs.",
            log = "Telpur sulks, and points a lace at the price tags.",
            effects = { { "arch:butt_kicker", fun = 2 }, { "arch:method_actor", fun = -3 } } },
      } },
    { id = "mus_shopping", room = "gift_shop", spot = "5A", at = "mid", type = "story", actor = { "power_gamer", "tactician", "storyteller" }, party = true,
      title = "What do they buy?",
      text = "The party pools its Flitwidget Francs on the counter: {francs} of them. Telpur waits, laces twitching.",
      shop = true,
      options = {
          { label = "A scholar's book on gorgon-worshippers (4 Francs)", price = 4, want = "buy the book on gorgon-worshippers",
            log = "The Tenets of the Rotting Temple. {actor_char} starts reading before they've left the shop.",
            effects = { { "arch:storyteller", fun = 6, story = 5 }, { "arch:butt_kicker", fun = -1 } },
            mus = { mark = "know", spend = 4, favor = { who = "telpur", n = 1 } } },
          { label = "The Mech Instruction Manual (3 Francs)", price = 3, want = "buy the Mech manual",
            log = "A thick manual with a lot of diagrams. Chapter nine: what the red switch does, and how to survive it.",
            effects = { { "arch:tactician", fun = 6 }, { "arch:power_gamer", fun = 4 } },
            mus = { flag = "manual", spend = 3, favor = { who = "telpur", n = 1 } } },
          { label = "Fire arrows and a bucket of slime (3 Francs)", price = 3, want = "buy the fire arrows and the slime",
            log = "Arrows that burn and slime that bites, enough for one good fight. {actor_char} is very happy.",
            effects = { { "arch:butt_kicker", fun = 6 }, { "arch:power_gamer", fun = 4 } },
            mus = { flag = "arrows", spend = 3, favor = { who = "telpur", n = 1 } } },
          { label = "The vorpal sword (40 Francs)", price = 40, needs = { flag = "vorpal_price" }, want = "buy the vorpal sword",
            log = "Forty Francs, counted twice. Telpur wraps it in brown paper. It's very, very sharp.",
            effects = { { "actor", fun = 10, reward = 10 }, { "arch:power_gamer", fun = 6 } },
            mus = { flag = "vorpal_sword", spend = 40, favor = { who = "telpur", n = 1 } } },
          { label = "Save the Francs for later.", want = "save the Francs for later",
            log = "They keep their Francs. Telpur is personally offended.",
            effects = { { "arch:tactician", fun = 1 }, { "arch:power_gamer", fun = -2 } } },
      } },

    -- The Hunting Grounds ---------------------------------------------------------------------
    { id = "mus_tracks", room = "hunting", spot = "6I", at = "start", when = { knob = "marks" }, type = "story", actor = { "tactician", "explorer", "butt_kicker" }, party = true,
      title = "Scratch marks",
      text = "Fresh scratch marks lead across the floor to the cave model. {actor_char} points out they're very easy to follow. Almost as if someone wanted them followed.",
      options = {
          { label = "Follow them anyway. They know it's bait.", want = "follow the marks anyway, weapons out",
            log = "They follow the trail with weapons out. The huntlings spring the trap, and the party was ready for it.",
            effects = { { "arch:butt_kicker", fun = 5 }, { "all", challenge = 4 } }, mus = { risk = true, ready = true } },
          { label = "Go round. Make the hunters come to them.", want = "go round and make the hunters come to us",
            log = "They put their backs to the bulette's skull and wait. It's the huntlings who have to come out.",
            effects = { { "arch:tactician", fun = 6 }, { "arch:butt_kicker", fun = -1 } }, mus = { flag = "no_surprise", ready = true } },
      } },
    { id = "mus_mirror", room = "hunting", spot = "6J", at = "end", type = "story", actor = { "tactician", "explorer", "storyteller" }, party = true,
      title = "Polished doors",
      text = "In the kitchen diorama, the cupboard doors are polished to a mirror shine. {actor_char} could prise one off.",
      options = {
          { label = "Take one. You never know.", want = "take one of the mirror-bright doors",
            log = "{actor_char} unscrews a cupboard door and straps it to their pack. Nobody asks why. Someone should.",
            effects = { { "actor", spotlight = 6 }, { "arch:tactician", fun = 4 } }, mus = { mark = "mirror", aspect = "Carried a cupboard door upstairs to fight a Gorgon" } },
          { label = "Leave the exhibits alone.", want = "leave the exhibits alone",
            log = "They leave the kitchen as they found it.", effects = { { "arch:casual", fun = 1 } }, mus = { careful = 1 } },
      } },

    -- The offices -----------------------------------------------------------------------------
    -- The locked door comes first: nobody reacts to what's inside before they're in.
    { id = "mus_office_door", room = "offices", spot = "door", at = "start", type = "story", actor = { "butt_kicker", "instigator", "tactician" }, party = true,
      title = "Locked from the inside",
      text = "The second study's door is locked, and the key is on the inside. {actor_char} looks at the lock, then at the door.",
      options = {
          { label = "The little brass key from the pond.", needs = { flag = "brass_key" }, want = "try the brass key from the pond",
            log = "It turns first time. Whoever locked it wanted out of the museum, not into the pond.",
            effects = { { "actor", spotlight = 8, fun = 4 }, { "arch:explorer", fun = 4 }, { "arch:storyteller", story = 3 } },
            mus = { flag = "door_open" } },
          { label = "Shoulder it open.", want = "shoulder it open",
            roll = { dc = 12, skill = { "athletics" }, convenient = "success", best = true,
                     success = { log = "The door bursts open on the second shove.", effects = { { "actor", spotlight = 6 }, { "arch:butt_kicker", fun = 4 } },
                                 mus = { flag = "door_open" } },
                     fail = { log = "The door holds; the shoulder doesn't. It takes the whole party, and a lot of noise.",
                              effects = { { "actor", challenge = 3 }, { "arch:tactician", fun = -1 } }, mus = { flag = "door_open" } } } },
          { label = "Pick the lock, quietly.", want = "pick the lock, quietly",
            roll = { dc = 13, skill = { "sleight_of_hand" }, convenient = "success", best = true,
                     success = { log = "{actor_char} pushes the key out onto a sheet of paper and pulls it under the door. Click.",
                                 effects = { { "actor", spotlight = 10, fun = 5 } }, mus = { flag = "door_open" } },
                     fail = { log = "The pick snaps. In the end, somebody's shoulder does it anyway.",
                              effects = { { "actor", fun = -2 } }, mus = { flag = "door_open" } } } },
      } },
    { id = "mus_office_inside", room = "offices", spot = "7B", at = "start", when = { flag = "door_open" }, type = "story", actor = { "storyteller", "explorer", "tactician" },
      title = "The second study",
      text = "Inside: the archivist, dead at his desk, with eyes carved all over his arms. A six-winged bird sings under a glass dome. A notebook lies open by his hand.",
      -- (A table that veiled gore at Session Zero hears it gently.)
      -- (A line under gore: nothing gruesome, not even hinted. A veil: it's there, off screen.)
      text_if = { { when = { line = "gore" }, text = "Inside: the archivist, slumped at his desk as if he fell asleep there, and never woke. A six-winged bird sings under a glass dome. A notebook lies open by his hand." },
                  { when = { soft = "gore" }, text = "Inside: the archivist, dead at his desk, his sleeves pulled down over his arms. A six-winged bird sings under a glass dome. A notebook lies open by his hand." } },
      options = {
          { label = "Let them take it all in, slowly.",
            log = "Nobody speaks for a moment. {actor_char} takes out a pencil.",
            effects = { { "arch:storyteller", fun = 4, story = 4 }, { "arch:explorer", fun = 3 }, { "arch:butt_kicker", boredom = 3 } }, table_min = 3 },
          { label = "Keep it brisk. Notebook, bird, out.",
            log = "\"Grab the notebook. Don't touch the bird.\" Fair.",
            effects = { { "arch:butt_kicker", fun = 2 }, { "arch:storyteller", fun = -2 } } },
      } },
    { id = "mus_whispers", room = "offices", spot = "7B", at = "mid", when = { knob = "witness" }, type = "screen", actor = { "storyteller", "explorer", "casual" },
      title = "Whispers",
      text = "{actor_char} bends over the archivist's body. A faint voice starts whispering, to them alone.",
      options = {
          { label = "Roll for it, behind the screen.",
            roll = { dc = 13, skill = { "insight", "religion" }, secret = true, convenient = "success",
                     success = { log = "{actor_char} shakes it off. Just the wind. Probably.", effects = { { "actor", fun = 2 } } },
                     fail = { log = "Something old learns {actor_char}'s name. You write it down for later.",
                              effects = { { "actor", story = 8, fun = 4 }, { "arch:storyteller", investment = 2 } }, mus = { flag = "whispered", aspect = "Heard the Witness whisper their name" } } } },
          { label = "Pass them a note: they hear it, and only they know.",
            log = "You slide a folded note across the table. It says: \"A voice in the dark says your name, once, the way an old friend would.\" {actor_char}'s player reads it, goes pale, and says nothing.",
            effects = { { "actor", story = 10, fun = 6 }, { "arch:storyteller", investment = 3 }, { "arch:casual", fun = -1 } },
            mus = { flag = "whispered", aspect = "Heard the Witness whisper their name" } },
      } },

    -- The World of Tomorrow -------------------------------------------------------------------
    { id = "mus_code", room = "tomorrow", spot = "8A", at = "start", type = "puzzle", actor = { "tactician", "power_gamer", "storyteller" },
      title = "The code in its chest",
      text = "A panel in the machine's chest slides open on a string of numbers. Grid references. It won't stay open long.",
      options = {
          { label = "Give them the time they need.", unless = { knob = "timer" },
            roll = { dc = 12, skill = { "investigation", "arcana" }, convenient = "success",
                     success = { log = "{actor_char} reads the grid, says the word, and steam hisses. \"Activation accepted. My name is {mech}.\"",
                                 effects = { { "actor", spotlight = 12 }, { "arch:tactician", fun = 6 }, { "arch:power_gamer", fun = 6 } },
                                 mus = { mark = "mech", francs = 1, resolve = "win", aspect = "Woke the Steam Mech and commands it" } },
                     fail = { log = "The panel snaps shut. The code changes. The machine stays a statue.",
                              effects = { { "arch:power_gamer", fun = -4 } }, mus = { resolve = "lose" } } } },
          { label = "Thirty real seconds. Go.", when = { knob = "timer" },
            roll = { dc = 13, skill = { "investigation", "arcana" }, convenient = "success",
                     success = { log = "With two seconds to spare, {actor_char} shouts the word. \"Activation accepted. My name is {mech}.\" The table erupts.",
                                 effects = { { "actor", spotlight = 16, fun = 8 }, { "arch:butt_kicker", fun = 5 }, { "arch:casual", fun = -3 } },
                                 mus = { mark = "mech", francs = 2, resolve = "win", aspect = "Woke the Steam Mech with two seconds to spare" } },
                     fail = { log = "Time. The panel snaps shut, and Sam lets out a breath he's been holding for thirty seconds.",
                              effects = { { "arch:casual", fun = -4 }, { "arch:instigator", fun = 3 } }, mus = { resolve = "lose" } } } },
      } },
    { id = "mus_hyper", room = "tomorrow", danger = "the red switch: only if absolutely necessary", spot = "8A", at = "end", when = { mark = "mech" }, type = "story", actor = { "instigator", "power_gamer", "butt_kicker" }, party = true, proposes = 1,
      title = "Hyper Destroyer Mode",
      text = "Inside the Mech's chest panel, a red switch: \"HYPER DESTROYER MODE. Only if absolutely necessary.\" {actor_char} is grinning.",
      options = {
          { label = "Try it, here and now.", want = "flip the switch right now",
            roll = { dc = 12, skill = { "arcana", "investigation" }, convenient = "success",
                     success = { log = "The Mech swells, missiles pop out of its shoulders, and it shuts itself down again before anything explodes. Impressive. Terrifying. The switch is scorched: it won't do that again for a while.",
                                 effects = { { "actor", fun = 8 }, { "arch:power_gamer", fun = 5 } }, mus = { risk = true, flag = "hyper_spent" } },
                     fail = { log = "It overheats with a shriek of steam and a smell of burnt clockwork. The Mech won't be walking anywhere now.",
                              effects = { { "actor", fun = 2 }, { "arch:tactician", fun = -4 } }, mus = { risk = true, harsh = true, unmark = "mech", flag = "mech_burnt", aspect = "Burnt out the Steam Mech" } } } },
          { label = "\"Save it for the Gorgon.\"", want = "save it for the Gorgon",
            log = "{actor_char} snaps the panel shut. For the Gorgon.",
            effects = { { "arch:tactician", fun = 4 }, { "arch:instigator", fun = -2 } }, mus = { warn = true, flag = "hyper_saved" } },
      } },

    -- The lecture theatre ---------------------------------------------------------------------
    { id = "mus_earplugs", room = "lecture", at = "start", type = "rules", actor = { "tactician", "casual", "storyteller" },
      title = "Can I block my ears?",
      text = "{actor_char} wants to stuff candle wax in their ears before going in. \"If I can't hear him, he can't bore me, right?\"",
      options = {
          { label = "Yes. It's a good idea, and it works.",
            log = "Wax in, cloth over. It works. Nobody else thought of it.",
            effects = { { "actor", fun = 6 }, { "arch:tactician", fun = 4, trust = 1 } }, leans = "cool", mus = { flag = "deaf", aspect = "Beat a ghost's lecture with candle wax" } },
          { label = "He's in their heads. Wax won't help.",
            log = "The drone goes straight past the wax. {actor_char} sighs.",
            effects = { { "actor", fun = -3 }, { "arch:power_gamer", fun = -1 } }, leans = "strict" },
      } },

    -- The stairs --------------------------------------------------------------------------------
    { id = "mus_alone", room = "stairs", danger = "the stairs up: something is waiting at the top", at = "start", when = { flag = "pip_alone" }, type = "table", actor = { "instigator" }, who = "jess",
      title = "It's what {actor_char} would do",
      text = "While the others argue, {actor_char} slips up the stairs alone. \"It's what {actor_char} would do,\" says {actor}, already halfway out of her chair.",
      options = {
          { label = "Let it ride. Run them alone for a bit.",
            log = "{actor_char} creeps up to the curtain, hears a calm voice say {actor_char}'s name, and scrambles back down. {actor} is delighted. Everyone else waited ten minutes.",
            effects = { { "actor", fun = 8, spotlight = 14 }, { "others", fun = -4, boredom = 8 } }, table_min = 10, mus = { risk = true, flag = "seen", aspect = "Went up the Gorgon's stairs alone" } },
          { label = "Rein them in, kindly, out of character.",
            log = "\"{actor_char} can scout next week, with the group.\" {actor} pouts, then laughs.",
            effects = { { "actor", fun = -4 }, { "others", fun = 3, trust = 1 } } },
          { label = "Let it cost them: Euryale is waiting.",
            log = "At the top of the stairs, bronze eyes. {actor_char} comes back down very pale, and very quiet.",
            effects = { { "actor", fun = 2, challenge = 8 }, { "arch:storyteller", fun = 3 } }, mus = { risk = true, harsh = true, flag = "seen", aspect = "Met a Gorgon's eyes alone, and came back" } },
      } },

    -- Euryale's lair ---------------------------------------------------------------------------
    -- The knight they walked past climbs out of a frame behind her couch. Its paint is still wet,
    -- and the book's answer to him is paint (weapons out of a painting cut him like he's paper).
    { id = "mus_lair_frame", room = "lair", danger = "the knight's frame: the paint is wet, and he's watching", at = "mid", when = { mark = "knight" }, fight_only = true, type = "story", actor = { "explorer", "butt_kicker", "tactician" }, party = true,
      title = "The frame behind the couch",
      text = "The black knight steps out of a frame behind her couch, and the paint he left behind is still wet. {actor_char} could reach in for something to fight him with.",
      options = {
          { label = "Reach in. It's worth the chill.", want = "reach into the frame for a painted blade",
            roll = { dc = 12, skill = { "athletics", "acrobatics", "arcana" }, convenient = "success",
                     success = { log = "{actor_char} pulls out a painted blade, dripping. Paint cuts paint.",
                                 effects = { { "actor", spotlight = 10, fun = 5 }, { "arch:tactician", fun = 3 } },
                                 mus = { risk = true, flag = "paint", aspect = "Armed the party out of a Gorgon's own painting" } },
                     fail = { log = "The frame bites. {actor_char} pulls back numb fingers with nothing in them.",
                              effects = { { "actor", challenge = 5 } }, mus = { risk = true, harsh = true, hurt = { 1, 4 } } } } },
          { label = "No time. Swords out.", want = "forget the frame and draw steel",
            log = "They draw steel. The knight's armour drinks the first blow like ink.",
            effects = { { "arch:butt_kicker", fun = 3 }, { "arch:explorer", fun = -2 } }, mus = { warn = true } },
      } },
}

-- Euryale's card: the marks the build-up leaves on it. why: what the party did. showdown: what it
-- changes on boss night. thought: what she thinks, upstairs, when it lands (her inner voice).
-- from: the rooms that can leave it at their end (the night's own bookkeeping, not a moment), for
-- the tie-and-lock editor's outs.
-- foe: a monster that joins her (count: how many). ally: one that fights for the party.
-- party: something the party did or carries (a mirror, the Mech, a robbery): only they can put it
-- there, so the DM's ties can't (game/model/ties.lua), or her card would say they did what they didn't.
-- opt: a battle option (game/rules: mirror, averted, drowsy, paint). talk: easier (+) or harder
-- (-) to talk her round.
-- The people with a sheet (game/model/npcs.lua, game/ui/npc_view.lua): their name in any text
-- opens it. monster: their stat block when they fight; sprite: their mini; hows: the ways the DM
-- can let the party get something off them (a boot has no pockets; a construct takes no
-- requests); match: the words that are them in a line.
M.npc_sheet = {
    order = { "mus_flitwidget", "mus_telpur", "mus_euryale", "mus_sentinel", "mus_bone_construct", "mus_knight",
              "mus_lecturer", "mus_mech" },
    mus_flitwidget = { room = "street", sprite = "npc_rosin", hows = { "ask", "pocket" }, match = { "Flitwidget" },
                       not_before = " Franc" },
    mus_telpur = { room = "gift_shop", sprite = "npc_hermit", hows = { "ask" }, match = { "Telpur" } },
    mus_euryale = { room = "lair", sprite = "npc_sable", monster = "euryale", hows = { "beaten", "pocket", "ask" }, match = { "Euryale" } },
    mus_sentinel = { room = "entrance", sprite = "animated_armor", monster = "sentinel", hows = { "beaten" }, match = { "the Sentinel", "The Sentinel" },
                     about = "A suit of metal armour between the doors. It stays a statue as long as nobody touches the donation case." },
    mus_bone_construct = { room = "chamber", sprite = "skeleton", monster = "bone_construct", hows = { "beaten" }, match = { "Bone Construct" },
                           about = "Gold and bleached bone with three skull faces. It guards the chamber's pedestal." },
    mus_knight = { room = "paintings", sprite = "animated_armor", monster = "knight_of_shades", hows = { "beaten" },
                   match = { "Knight of Shades" }, about = "Black armour and red light where a face should be. He climbs out of his painting." },
    mus_lecturer = { room = "lecture", sprite = "specter", monster = "the_lecturer", hows = { "beaten", "ask" }, match = { "the Lecturer", "The Lecturer" },
                     about = "A grey ghost who drones on without a mouth. Fall asleep in his lecture and you may not wake up." },
    mus_mech = { room = "tomorrow", sprite = "animated_armor", monster = "steam_mech", hows = { "ask", "beaten" }, match = { "Steam Mech" } },
}

-- Who comes along with the party (game/model/companions.lua): a pet or a person who joined them.
-- joins: how (a flag the story sets, or `chat` when a chat answer says yes); owner: whose they are
-- (the one who plays them in a fight, and who talks about them); monster: their stat block if they
-- fight (they're in initiative, with a mini); pocket: a pet that hides in a fight instead. helps:
-- what they do when the party looks around (museum_night.explore). lines: what's said about them.
-- Table life: small moments that play themselves (game/model/table_life.lua), room by room.
M.table_life = require "game.data.museum.table_life"

M.companions = {
    order = { "exhibit_b", "telpur" },
    exhibit_b = { name = "Exhibit B", kind = "pet", what = "Pip's museum rat", owner = "jess", joins = { chat = "pip_pet" }, pocket = true,
                  helps = { bonus = 2, find = 0.25, find_line = "Exhibit B scurries off under an exhibit and comes back with a Flitwidget Franc in his teeth." },
                  lines = {
                      join = "Pip has a new friend tonight: a museum rat called Exhibit B, riding in her hood. He seems to approve of the museum.",
                      start = { "Exhibit B is in my hood. Say hi, Exhibit B.", "Exhibit B came. He insisted.", "I brought Exhibit B a tiny bit of cheese for the museum." },
                      look = { "Exhibit B, go sniff that. Good boy.", "Exhibit B doesn't like it. That's a sign.", "Exhibit B's whiskers are going. Something's here." },
                      fight = { "Exhibit B, pocket! NOW!", "Nobody step on Exhibit B.", "Exhibit B is in the pocket. We're fine. Mostly." },
                      win = { "Exhibit B was very brave in the pocket.", "Exhibit B gets the first crumb of the victory snack." },
                  } },
    telpur = { name = "Telpur", kind = "person", what = "the talking boot from the gift shop", owner = "jess", joins = { flag = "telpur_along" },
               monster = "telpur", cast = "mus_telpur",
               helps = { bonus = 1, find = 0.1, find_line = "Telpur knows this museum: \"Under the third tile. Flitwidget hides Francs everywhere.\"" },
               lines = {
                   join = "Telpur is coming with them tonight. They insisted, loudly, until somebody tied them to a pack strap. They have opinions about every exhibit.",
                   start = { "Telpur, from the backpack: \"Onward! Mind the laces.\"", "Telpur is already complaining about the walking." },
                   look = { "Telpur: \"I'd not touch that. Then again, I'm a boot.\"", "Telpur: \"In my day we had a museum like this. Smaller. More screaming.\"" },
                   fight = { "Telpur: \"Point me at it!\"", "Telpur hops into the fight, laces flying." },
                   win = { "Telpur: \"Another victory for the Lord of Laces.\"", "Telpur takes most of the credit." },
                   -- (When he drops in a fight, and after it: companions.fell and after_fight.)
                   down = "Telpur takes the hit and goes flying, laces everywhere. He lands in a heap and doesn't move.",
                   react = "Telpur! Somebody get the boot!",
                   up = "Telpur comes round in a tangle of laces. \"I meant to do that. Tactical nap.\"",
               } },
}

-- Looking around each room (museum_night.explore): the places on its board the friends wander
-- over to, one at a time, before the room's business (the playtest, November 3), and the DM's
-- finds and traps among them. Ours, not the book's: small things, so the DM always has a call
-- to make behind the screen. (Places a moment is about stay out of this list: the moment walks
-- its hero there itself, with its `spot`.)
M.explore = {
    garden = { "shears", "hammer",
               finds = { shears = { francs = 1, what = "a Flitwidget Franc in the grass",
                                    line = "Under the shears, pressed into the grass: a Flitwidget Franc." } } },
    entrance = { "light", "front",
                 finds = { light = { francs = 1, what = "a Franc someone dropped",
                                     line = "Something glints on the marble under the chandelier: a Flitwidget Franc." } } },
    chamber = { "3C", "3H", "3G",
                finds = { ["3C"] = { francs = 1, what = "a Franc at the bottom of the jackal jug",
                                     line = "{actor_char} tips the jackal jug. A Flitwidget Franc rolls out into the sand." } },
                traps = { ["3H"] = { what = "pull the crocodile's jaw too far and it snaps shut", dc = 12, skill = { "acrobatics", "sleight_of_hand" },
                                     spot_dc = 12, hurt = { 1, 4 },
                                     hit = "The crocodile's jaw snaps shut on {actor_char}'s fingers. The water keeps running.",
                                     dodge = "The jaw snaps shut a finger's width from {actor_char}'s hand.",
                                     spotted = "{actor_char} notices the hinge is far too strong for a tap, and wedges it open with a stick." } } },
    paintings = { "4D", "4I", "4J",
                  finds = { ["4J"] = { francs = 1, what = "a real Franc tucked in the frame",
                                       line = "Wedged behind the duellist's frame: a real Flitwidget Franc, not a painted one." } } },
    gift_shop = { "shelves", "souvenirs", looks = 1 },
    hunting = { "6B", "6H", "6F",
                finds = { ["6H"] = { francs = 1, what = "a strip of razorbark worth a Franc to the right buyer",
                                     line = "{actor_char} peels off a strip of razorbark without losing a finger. Somebody will pay a Franc for that." } },
                traps = { ["6F"] = { what = "a snare the huntlings strung between the vines", dc = 12, skill = { "acrobatics", "athletics" },
                                     spot_dc = 13, hurt = { 1, 6 },
                                     hit = "A loop of vine whips tight round {actor_char}'s ankle and yanks them off their feet. Something in the jungle chitters.",
                                     dodge = "{actor_char} feels the vine tighten and steps out of the loop just in time.",
                                     spotted = "{actor_char} spots the loop of vine in the leaves and cuts it. Something in the jungle chitters, disappointed." } } },
    offices = { "drawings", "eyes", looks = 1 },
    tomorrow = { "cases", "console",
                 finds = { cases = { francs = 1, what = "a Franc stuck in a machine from tomorrow",
                                     line = "One of tomorrow's machines has a coin slot, and a Flitwidget Franc stuck halfway in it." } } },
    lecture = { "books", "board", looks = 1,
                finds = { books = { francs = 1, what = "a Franc used as a bookmark",
                                    line = "Somebody used a Flitwidget Franc as a bookmark, a long time ago." } } },
}

M.marks = {
    topiary = { name = "Topiary at her couch", why = "Briar Guardians left standing in the garden", from = { "garden" },
                showdown = "A Briar Beast fights beside her", foe = "briar_beast",
                thought = "One of my hedges is still standing. Come here, kitten." },
    garden_burned = { party = true, name = "She smelled the smoke", why = "They set her garden on fire",
                      showdown = "She skips the drink and the small talk", talk = -2,
                      thought = "Fire. How crude. I liked that garden." },
    robbed = { party = true, name = "Thieves, like her", why = "They tried to rob the donation box",
               showdown = "They can offer her a cut of the box to leave", thought = "They tried the gnome's little money box. Oh, I like them already." },
    scarabs = { name = "Scarabs in the walls", why = "They smashed the Bone Construct", from = { "chamber" },
                showdown = "A scarab swarm joins her", foe = "giant_scarab_swarm",
                thought = "They smashed the old guardian. Its beetles are mine now." },
    calmed = { party = true, name = "One guard fewer", why = "They calmed the Bone Construct with the ritual",
               showdown = "Nothing comes up from below to help her", talk = 1,
               thought = "They did the water ritual properly. Nobody does it properly." },
    knight = { name = "A knight in a frame", why = "The Knight of Shades was never woken",
               why_if = { { when = { chose = { "mus_knight_frame", 1 } }, text = "The Knight of Shades got away from them" } },
               thought_if = { { when = { chose = { "mus_knight_frame", 1 } }, text = "My knight came crawling back into a frame up here. They'll meet him again." } },
               showdown = "The Knight steps out of a painting in her lair", foe = "knight_of_shades",
               thought = "They walked straight past my knight. He'll keep." },
    pack = { name = "Her pack", why = "Kruthik Huntlings ran from the fight", from = { "hunting" },
             showdown = "The survivors hunt beside her", foe = "kruthik_huntling",
             thought = "The little hunters came running to me. Good dogs." },
    mirror = { party = true, name = "A mirror in their packs", why = "They took a polished cupboard door",
               showdown = "Her stare can be turned back on her", opt = "mirror",
               thought = "One of them took a cupboard door. Why would anyone take a door?" },
    know = { party = true, name = "They know what she is", why = "They read up on gorgons",
             showdown = "They know to look away, and about her sisters", opt = "averted",
             thought = "Someone downstairs is reading about my kind. How flattering. How annoying." },
    bracelet = { party = true, name = "A bracelet of protection", why = "Flitwidget slipped them one",
                 showdown = "Advantage on saves against her stare", opt = "averted",
                 thought = "The gnome gave them a trinket. How sweet. We'll see what it's worth." },
    mech = { party = true, name = "A machine on their side", why = "They woke the Steam Mech",
             showdown = "The Mech fights for them, and she goes for its commander", ally = "steam_mech",
             thought = "The gnome's toy is walking about. It's pointed at me, isn't it." },
    drone = { name = "A drone through the floor", why = "The Lecturer is still lecturing", from = { "lecture" },
              showdown = "They come up half asleep: they lose their edge against her charm", opt = "drowsy",
              thought = "The bore is still droning. They'll come up here half asleep." },
    pages = { party = true, name = "Sleeping pages", why = "They took the Lecturer's notes", from = { "lecture" },
              showdown = "A trick: get her to read one", thought = "They silenced the bore and kept his notes. Clever, or just tidy?" },
    careful = { party = true, name = "Careful hands", why = "They were gentle with the exhibits",
                showdown = "She's curious about them, and easier to talk round", talk = 2,
                thought = "They put my exhibits back where they found them. Who does that?" },
}
-- The book's sides, for the DM's recap on game night (game/model/standing.lua, the Story sidebar):
-- who's on each, and where each one stands now. A member's states are tried in order; the first
-- whose `when` holds (done = a room they've been through, mark = on Euryale's card, flag = something
-- they did or found, favor = { who, at } at least that much goodwill) gives the line. tone: good |
-- bad | quiet, for its colour. likes: which kinds of player are drawn to them (archetype -> 0..2),
-- with the hero whose reason for coming is in their room keener still. Every line in our own words.
M.sides = {
    { id = "collection", name = "Euryale and her collection",
      about = "The Gorgon upstairs, and the exhibits that woke when her jar broke.",
      members = {
          { id = "mus_euryale", name = "Euryale", role = "The Gorgon upstairs", room = "lair", boss = true,
            likes = { storyteller = 2, butt_kicker = 1, tactician = 1, method_actor = 1 } },
          { id = "mus_briar", name = "The briar guardians", role = "The garden's topiary", room = "garden",
            likes = { butt_kicker = 1, explorer = 1 },
            states = { { when = { mark = "topiary" }, text = "One still standing, waiting at her couch", tone = "bad" },
                       { when = { mark = "garden_burned" }, text = "Burned, and she smelled the smoke", tone = "bad" },
                       { when = { done = "garden" }, text = "Cut down", tone = "good" } } },
          { id = "mus_bone_construct", name = "The Bone Construct", role = "The Chamber of Ancients' guardian", room = "chamber",
            likes = { explorer = 2, storyteller = 1, butt_kicker = 1 },
            states = { { when = { mark = "calmed" }, text = "Calmed by the ritual, kneeling", tone = "good" },
                       { when = { mark = "scarabs" }, text = "Smashed; its scarabs went to her", tone = "bad" },
                       { when = { done = "chamber" }, text = "Beaten", tone = "good" } } },
          { id = "mus_knight", name = "The Knight of Shades", role = "A painting that fights", room = "paintings",
            likes = { butt_kicker = 2, power_gamer = 1 },
            states = { { when = { mark = "knight" }, text = "Still in his frame: he'll step out in her lair", tone = "bad" },
                       { when = { done = "paintings" }, text = "Beaten", tone = "good" } } },
          { id = "mus_huntlings", name = "The kruthik huntlings", role = "The hunting floor's pack", room = "hunting",
            likes = { butt_kicker = 2, tactician = 1 },
            states = { { when = { mark = "pack" }, text = "The survivors ran upstairs to her", tone = "bad" },
                       { when = { done = "hunting" }, text = "Beaten", tone = "good" } } },
          { id = "mus_lecturer", name = "The Lecturer", role = "A ghost who won't stop talking", room = "lecture",
            likes = { storyteller = 1, tactician = 1, instigator = 1 },
            states = { { when = { mark = "drone" }, text = "Still droning through the floor", tone = "bad" },
                       { when = { mark = "pages" }, text = "Silenced; his notes are theirs", tone = "good" },
                       { when = { done = "lecture" }, text = "Silenced", tone = "good" } } },
      },
      -- Who fights beside her, by the marks on her card.
      with = { topiary = "a Briar Beast", scarabs = "a scarab swarm", knight = "the Knight of Shades", pack = "her huntlings" },
    },
    { id = "keepers", name = "The museum's keepers",
      about = "The gnome who owns it all, his gift shop, and what's left of his staff.",
      members = {
          { id = "mus_flitwidget", name = "Flitwidget", role = "The curator, who hired them", room = "street", favor = "flitwidget",
            likes = { storyteller = 1, casual = 2, method_actor = 1 },
            states = { { when = { mark = "robbed" }, text = "Trusts them less: they tried his donation box", tone = "bad" },
                       { when = { favor = { who = "flitwidget", at = 2 } }, text = "Delighted with them", tone = "good" },
                       { when = { favor = { who = "flitwidget", at = 1 } }, text = "Pleased so far", tone = "good" },
                       { when = { done = "street" }, text = "Hoping they're as good as they look", tone = "quiet" } } },
          { id = "mus_sentinel", name = "The Sentinel", role = "The entrance hall's guard", room = "entrance",
            likes = { tactician = 1, instigator = 1 },
            states = { { when = { mark = "robbed" }, text = "Woken by the would-be thieves", tone = "bad" },
                       { when = { done = "entrance" }, text = "Back on guard by the donation box", tone = "quiet" } } },
          { id = "mus_telpur", name = "Telpur", role = "The talking boot in the gift shop", room = "gift_shop", favor = "telpur",
            likes = { method_actor = 2, instigator = 1, casual = 2 },
            states = { { when = { flag = "telpur_along" }, text = "Coming along with them, talking", tone = "good" },
                       { when = { favor = { who = "telpur", at = 2 } }, text = "Their best customer's friends", tone = "good" },
                       { when = { done = "gift_shop" }, text = "Met: a boot with opinions", tone = "quiet" } } },
          { id = "mus_mech", name = "The Steam Mech", role = "The World of Tomorrow's war machine", room = "tomorrow",
            likes = { power_gamer = 2, butt_kicker = 1, tactician = 1 },
            states = { { when = { mark = "mech" }, text = "Woken: {mech} fights for them", tone = "good" },
                       { when = { flag = "mech_burnt" }, text = "Burnt out", tone = "bad" },
                       { when = { done = "tomorrow" }, text = "Still asleep in its alcove", tone = "quiet" } } },
      },
    },
    { id = "witness", name = "The Witness",
      about = "Whatever wrote in the archivist's notebook. A thread for later, if you keep it.",
      members = {
          { id = "mus_notebook", name = "The archivist's notebook", role = "Eyes drawn on every page", room = "offices",
            likes = { storyteller = 2, explorer = 1 },
            states = { { when = { flag = "studied" }, text = "Studied: a line about the Witness", tone = "good" },
                       { when = { flag = "notebook" }, text = "In their packs", tone = "good" },
                       { when = { done = "offices" }, text = "Left behind in the dark", tone = "quiet" } } },
          { id = "mus_whispers", name = "The whispers", role = "Something that knows their names", room = "offices",
            likes = { storyteller = 1, method_actor = 1 },
            states = { { when = { flag = "whispered" }, text = "One of them heard it, and was heard back", tone = "bad" },
                       { when = { done = "offices" }, text = "Quiet, for now", tone = "quiet" } } },
      },
    },
}

-- What a card's outs are called in the tie-and-lock editor (game/model/ties.lua), for the flags
-- whose options don't already name them with an aspect (or name them too narrowly). Past tense,
-- as if someone at the table did it.
M.outs = {
    truth = "Heard the truth about the Gorgon",
    water = "Doused the hedges with pond water",
    boon = "Dropped a coin in the donation box",
    ritual_failed = "Got the water ritual wrong",
    manual = "Bought the Mech Instruction Manual",
    arrows = "Bought fire arrows and a bucket of slime",
    no_surprise = "Made the huntlings come to them",
    hyper_saved = "Saved Hyper Destroyer Mode for the Gorgon",
}
M.mark_order = { "topiary", "garden_burned", "robbed", "scarabs", "calmed", "knight", "pack", "mirror", "know", "bracelet", "mech", "drone", "pages", "careful" }

-- What the party carries, and what it does in the fights after they get it: anything picked up,
-- bought or handed over works from then on, and the table hears it as a fight starts (museum_night
-- .arm). when: as on moments (usually the flag the pickup sets). rooms: only in these rooms' fights
-- (default any). ally: only when that ally fights with them. once: used up by its first fight.
-- opt: the battle option it turns on (game/rules/museum.lua); weapon: the holder's weapon attacks
-- get this magic bonus. boss: about Euryale herself (not said when only her collection fights). The
-- truth test (tools/tests/museum_truth.lua) fails on any flag nothing reads.
-- magic: a real magic item (game/rules/data/magic_items.lua's format, M.magic_items below) that
-- goes on the sheet of whoever picked it up, so the rules use it in every fight from then on.
-- carry: a thing a hero carries (game/model/items.lua, the one inventory): the flag or mark in `when`
-- that hands it over puts it in the pack of the hero whose choice it was (the buyer, the finder, the
-- friend who asked for it; else `to`), and it works only when that hero is at the table. {holder} is
-- them. title, text: its name and what it does, for the hero's sheet. count: how many uses (the
-- pages). once: used up by its first fight. adv, topic: Advantage on that skill about that subject.
M.items = {
    { id = "daggers", when = { flag = "daggers" }, magic = "twin_daggers", name = "the twin daggers", carry = true,
      line = "{holder} fights with the twin daggers from the Chamber of Ancients: they hit like magic weapons." },
    { id = "arrows", when = { flag = "arrows" }, opt = "fire_arrows", once = true, name = "fire arrows and slime", carry = true,
      text = "Telpur's fire arrows and a bucket of slime: every hero's first weapon hit each turn burns or bites. Enough for one fight.",
      line = "Out come Telpur's fire arrows and the bucket of slime: every hero's first weapon hit each turn burns or bites, this fight only." },
    { id = "paint_dagger", when = { flag = "paint_dagger" }, rooms = { "lair" }, opt = "paint", name = "a paint-touched dagger", carry = true,
      to = "jess", text = "A dagger Telpur dipped in the hall's wet paint. In the lair, its blows count as magic, and painted things fear it.",
      line = "{holder} has Telpur's paint-touched dagger out: their blows count as magic, and painted things fear it." },
    { id = "manual", when = { flag = "manual" }, ally = "steam_mech", opt = "manual", name = "the Mech manual", carry = true,
      title = "the Mech Instruction Manual",
      text = "A thick manual with a lot of diagrams. Chapter nine says what the red switch does: with it open, the Mech has Advantage against overheating.",
      line = "{holder} has the Mech manual open at chapter nine: if the red switch goes, {mech} has Advantage against overheating." },
    { id = "hyper_spent", when = { flag = "hyper_spent" }, ally = "steam_mech", opt = "no_hyper",
      line = "{mech}'s red switch is still scorched from the test run: no Hyper Destroyer Mode tonight." },
    { id = "hyper_saved", when = { flag = "hyper_saved" }, ally = "steam_mech",
      line = "{mech}'s red switch is untouched, saved for the Gorgon." },
    { id = "mirror", when = { mark = "mirror" }, rooms = { "lair" }, boss = true, name = "the cupboard door", carry = true,
      title = "a polished cupboard door",
      text = "A cupboard door from the kitchen diorama, polished like a mirror. Held up in the lair, her own stare can turn back on her.",
      line = "{holder} has the polished cupboard door ready: if she lifts her hood, she meets her own eyes." },
    { id = "bracelet", when = { mark = "bracelet" }, rooms = { "lair" }, boss = true, name = "Flitwidget's bracelet", carry = true,
      title = "Flitwidget's bracelet of protection", text = "A thin silver bracelet Flitwidget slipped them. In the lair: Advantage on saves against her stare.",
      line = "Flitwidget's bracelet of protection is on: Advantage on saves against her stare." },
    { id = "know", when = { mark = "know" }, rooms = { "lair" }, boss = true,
      line = "They've read up on gorgons: eyes down, Advantage on saves against her stare." },
    { id = "charmed", when = { flag = "charmed" }, rooms = { "lair" }, boss = true, once = true, charm = true,
      line = "{holder} is still smiling at Euryale over the wine: they start the fight charmed by her." },
    { id = "vorpal_sword", when = { flag = "vorpal_sword" }, magic = "vorpal_sword", name = "the vorpal sword", carry = true,
      line = "{holder} has the vorpal sword out. Telpur's forty Francs were well spent." },
    { id = "vorpal", when = { flag = "vorpal_lair" }, rooms = { "lair" }, boss = true,
      line = "Somewhere behind her couch is the vorpal sword they were promised. First, Euryale." },
    -- (Things they carry that don't change a fight: what they're for is elsewhere. The book helps its
    -- reader with what they know about gorgons, the pages put a reader to sleep, the notebook is the
    -- Witness's thread, the shoelace talks. F10: one inventory, and the shop's shelf is real.)
    { id = "gorgon_book", when = { mark = "know" }, name = "the book on gorgon-worshippers", carry = true,
      title = "The Tenets of the Rotting Temple", adv = { "history" }, topic = "gorgons",
      text = "A scholar's book on the people who worship gorgons. Whoever has it has Advantage on History about gorgons, and knows there are three sisters." },
    { id = "notebook", when = { flag = "notebook" }, name = "the archivist's notebook", carry = true, to = "mara",
      text = "The dead archivist's notebook: a city under the sea, stone pillars covered in writing, and eyes drawn on every page." },
    { id = "pages", when = { mark = "pages" }, name = "the Lecturer's notes", carry = true, count = 3,
      text = "Three ghostly pages of lecture notes. Whoever reads one is asleep before the end of the line. One page a reader." },
    { id = "shoelace", when = { flag = "shoelace" }, name = "Telpur's talking shoelace", carry = true, to = "jess",
      text = "One of Telpur's own laces, a present from the gift shop. It talks. It has opinions about everything." },
}
-- The recap's words for a beat (game/model/recap.lua TEMPLATES), where the shared ones assume a
-- campaign: a foe that runs in the museum goes deeper in, not off to swear revenge.
M.recap_beats = {
    escape = { "{text}.", "One of them got away, deeper into the museum.", "Something ran, and it's somewhere upstairs now." },
    villain_falls = { "{text}." },     -- (by name: "the one leading them went down" said nothing, November 3)
}

-- What the friends do to each other at the table (game/data/friction.lua acts and bonds), in the
-- museum: every line says what was done, here. false: that one doesn't happen in this adventure.
M.friction = {
    acts = {
        my_guy = "{actor_char} pockets something small from the nearest exhibit. 'Sorry, it's just what {actor_char} would do,' {actor} shrugs.",
        lone_wolf = "{actor_char} slips off alone to poke at the exhibits, and everyone else waits by the door for ten minutes.",
        shove_a_friend = "{actor_char} shoves {target_char} into a display case to win an argument.",
        barge_the_bargain = "{actor_char} talks right over {target_char} while {target_char} is still asking questions.",
    },
    -- (The DM's answers: a table of fields to replace.)
    responses = {
        outlet = { label = "Give {actor_char} the next big moment, on purpose.",
                   log = "You make a note, and you keep it: the next big moment is {actor_char}'s." },
    },
    bonds = {
        share_the_loot = "{actor_char} lets {target_char} have first pick of whatever they find next: 'You'll get more use out of it than me.'",
        stand_up_for = "'They're with us,' {actor_char} says, stepping in front of {target_char}.",
    },
}

-- A ruling's cost, in the museum (game/data/rulings.lua's "yes, but" and "at a cost" options): every
-- line is a hurt, because the hero who pays it takes 1d4 damage (night.lua), so it's never just words.
M.ruling_costs = {
    success = { "It works, but it costs them: a nasty scrape that'll ache for the rest of the night.",
                "It works, but it costs them: a hard landing, and a bruise to show for it.",
                "It works, but it costs them: a cut across the knuckles that won't stop stinging." },
    near = { "Close enough, and they pay for it: a bruise, a bent buckle, and a lot of noise.",
             "Close enough, and they pay for it: a scrape that stings for the rest of the night." },
}

-- The friends' gifts at the real table (game/data/keepsakes.lua), in this adventure's words (the 3D
-- pieces stay as they are).
M.keepsakes = {
    dice_tower = { name = "a dice tower shaped like a crooked little house", short = "dice tower",
                   line = "Painted it myself. The dice come out the front door.",
                   use = "Your next big roll rattles down through the house and out the front door." },
    map = { name = "a framed map of the museum, drawn by hand", short = "museum map",
            line = "I've been drawing it since the first night. Check the bottom corner.",
            use = "It goes up where everyone can see it. Someone's already pointing at the stairs." },
    candle = { name = "a candle called 'The Gorgon's Lair'", short = "candle",
               line = "Smells like red wine and old stone. Light it for the creepy rooms.",
               use = "You light it the moment the party walks into a creepy room." },
    mini = { name = "a painted wolf mini, for whatever comes after the museum", short = "wolf mini",
             line = "For the campaign. There's always a wolf.",
             use = "The wolf watches from behind your screen. The table eyes it every time they look up." },
    bell = { name = "a little brass bell from a museum gift shop", short = "brass bell",
             line = "Ring it when something's coming. The boot at the till says it's cursed. Probably.",
             use = "You ring it once when something's coming. Everyone sits up." },
}

-- The adventure's own magic items, added to the rules' list while it runs (adventure.enter).
M.magic_items = {
    vorpal_sword = { name = "Vorpal sword", rarity = "Legendary", attune = true,
                     text = "The one they asked about in the group chat. +3 to attack and damage rolls with it.",
                     effect = { weapon = 3 }, ["for"] = { "fighter", "rogue", "cleric", "wizard" } },
    twin_daggers = { name = "Twin daggers", rarity = "Uncommon", attune = false,
                     text = "Two curved daggers from the Chamber of Ancients, their rings locked together. +1 to attack and damage rolls with weapons.",
                     effect = { weapon = 1 }, ["for"] = { "rogue", "fighter", "cleric", "wizard" } },
}
M.CAREFUL_AT = 3         -- gentle acts before she notices
M.base = { name = "Euryale, the Gorgon", line = "A calm host in a white hood. Bow and charm while the hood is on; her stare and her snakes when it comes off." }

-- What happens to rooms left behind (when the party moves past them for good), and to the end of
-- each room by how it went: marks and flags the adventure writes itself.
M.left_behind = {
    paintings = { mark = "knight" },
    lecture = { mark = "drone" },
}

-- Euryale's other thoughts: the night's openings and her reaction to a hero's big moment.
M.thoughts = {
    open = { "Upstairs, Euryale moves a statue an inch to the left, and waits.",
             "Upstairs, Euryale listens to the museum creak, and smiles.",
             "Upstairs, Euryale pours a second glass of wine, for a guest who hasn't arrived yet.",
             "Upstairs, Euryale dusts a stone hand that was reaching for the door when it stopped.",
             "Upstairs, Euryale reads the museum's guest book, and underlines four names.",
             "Upstairs, the snakes under Euryale's hood all turn toward the stairs at once." },
    arrive = "They're on the stairs. Good. I was getting bored.",
}

-- Between sessions ------------------------------------------------------------------------------

-- Requests in the group chat. after: the room that has to be done first. Four answers: yes,
-- laugh (yes, with a laugh), reason (no, with a reason), danger (yes, but it's dangerous).
M.ANSWERS = { "yes", "laugh", "reason", "danger" }
M.ANSWER_NAMES = { yes = "Yes", laugh = "Yes, with a laugh", reason = "No, with a reason", danger = "Yes, but it's dangerous" }
-- How each archetype takes each kind of answer (on top of what the asker feels).
M.answer_like = {
    yes = { power_gamer = 1, butt_kicker = 1, tactician = -1 },
    laugh = { instigator = 2, method_actor = 2, casual = 1, power_gamer = -2 },
    reason = { tactician = 2, casual = 1, instigator = -1 },
    danger = { butt_kicker = 2, storyteller = 2, casual = -1 },
}
-- The museum's own words, explained on hover (game/ui/gloss.lua adds them to the rules glossary).
M.glossary = {
    { id = "francs", match = { "Flitwidget Francs", "FRANCS", "%f[%a]Francs?%f[%A]" }, plain = "Flitwidget Francs",
      text = "The museum's own money: one appears for each beaten exhibit, solved puzzle or clever use of the museum. "
          .. "The party spends them in the gift shop." },
    { id = "boss_card", match = { "Euryale's card", "EURYALE'S CARD", "[Hh]er card" }, plain = "Euryale's card",
      text = "Everything the party does can put a mark on it: who fights beside her, what the party brings, how easily "
          .. "she talks. Boss night plays what's on it." },
}

M.requests = {
    { id = "vorpal", who = "dev", after = "garden",
      ask = "real question. can {char} find a vorpal sword in this museum",
      ask_if = { { state = "down", text = "real question. {char} keeps getting flattened. is there a vorpal sword in this museum" },
                 { state = "last_hit", text = "{char} needs a weapon worthy of that last hit. vorpal sword in this museum y/n" } },
      answers = {
          yes = { reply = "Telpur stocks one. It costs 40 Francs.", asker = 3, mus = { flag = "vorpal_price" } },
          laugh = { reply = "There's a vorpal spork in the gift shop. It's very sharp. For a spork.", asker = 0, mus = { flag = "spork" } },
          reason = { reply = "Not at level 2. Maybe in the campaign, if you're very good.", asker = -1 },
          danger = { reply = "There is one. It's behind Euryale's couch.", asker = 2, mus = { warn = true, flag = "vorpal_lair" } },
      } },
    { id = "long_rest", who = "sam", after = "gift_shop",
      ask = "can we start next time with a proper rest in the gift shop?", only_if = true,
      ask_if = { { state = "spells", text = "can we start next time with a proper rest in the gift shop? {char} is out of spells" },
                 { state = "hurt", text = "can we start next time with a proper rest in the gift shop? {char} is held together with tape" },
                 { state = "party", text = "can we start next time with a proper rest in the gift shop? we're all running on fumes" } },
      answers = {
          yes = { reply = "Yes. You wake up fully rested. Telpur snored all night.", asker = 3, mus = { flag = "rested" } },
          laugh = { reply = "Yes, but Telpur talks in their sleep. About hell. In detail.", asker = 2, mus = { flag = "rested" } },
          reason = { reply = "Time's funny in the museum. You pick up right where you stopped, bruises and all.", asker = -2 },
          danger = { reply = "You rest, and wake to find a statue at the foot of the stairs that wasn't there before.", asker = 1, mus = { flag = "rested", warn = true } },
      } },
    { id = "keep_boot", who = "jess", after = "gift_shop",
      ask = "can {char} take Telpur with us? the talking boot in the gift shop. asking for {char}",
      ask_if = { { when = { mark = "robbed" }, text = "can {char} take Telpur with us? the talking boot. legally, this time" } },
      about = "Telpur is the talking boot behind the gift shop's counter, who says he was once a great lord of the underworld. "
          .. "Jess loved him.",
      answers = {
          yes = { reply = "Telpur agrees to come along, as long as nobody wears them.", asker = 3, mus = { flag = "telpur_along" } },
          laugh = { reply = "Telpur gives {char} a shoelace. It still talks. It won't stop.", asker = 2, mus = { flag = "shoelace" } },
          reason = { reply = "Telpur's bound to the shop. Visiting hours only.", asker = -1 },
          danger = { reply = "Telpur comes along, and talks during every sneaky bit.", asker = 2, mus = { flag = "telpur_along", warn = true } },
      } },
    { id = "study", who = "mara", after = "offices", needs_flag = "notebook",
      ask = "can {char} study the archivist's notebook this week? properly",
      about = "The notebook they took from the dead archivist in the offices, full of drawings of eyes.",
      ask_if = { { state = "hurt", text = "{char} is too beaten up to explore. can we spend the week studying the archivist's notebook instead" } },
      answers = {
          yes = { reply = "{char} finds a line about the Witness that nobody else would have spotted.", asker = 3, mus = { flag = "studied" } },
          laugh = { reply = "It's mostly doodles of eyes. Hundreds of them. Some quite good.", asker = -1 },
          reason = { reply = "Not without someone who reads that script. Hold on to it for the campaign.", asker = 0 },
          danger = { reply = "{char} studies it, and the whispering starts again at night.", asker = 2, mus = { flag = "whispered", warn = true } },
      } },
}

-- Loose ends: a card that lost its place. when: what the game noticed. Each option re-homes it.
M.loose_ends = {
    { id = "knight_left", when = { skipped = "paintings" },
      text = "They never went into the Hall of Paintings. Where does the Knight of Shades turn up?",
      options = {
          { label = "In her lair, out of a painting", mus = { mark = "knight" }, like = { dev = 2, sam = -1 } },
          { label = "It stays in its frame", mus = {}, like = { sam = 1 } },
          { label = "Telpur sells a paint-touched dagger", mus = { flag = "paint_dagger" }, like = { jess = 1, dev = 1 } },
      } },
    { id = "construct_left", when = { skipped = "chamber" },
      text = "They never went into the Chamber of Ancients. What happens to the Bone Construct?",
      options = {
          { label = "Its scarabs creep upstairs to her", mus = { mark = "scarabs" }, like = { dev = 1, sam = -1 } },
          { label = "It stays bound to its chamber", mus = {}, like = { sam = 1 } },
      } },
    { id = "notebook_left", when = { skipped = "offices" },
      text = "They went up without searching the offices. Where does the archivist's notebook go?",
      options = {
          { label = "Euryale has it, and has read it", mus = { flag = "she_read" }, like = { mara = 2 } },
          { label = "Telpur sells it as \"a strange book\"", mus = { flag = "notebook" }, like = { mara = 1, jess = 1 } },
          { label = "It stays lost. The Museum stays a one-shot.", mus = {}, like = { dev = 1, mara = -1 } },
      } },
    { id = "mech_left", when = { skipped = "tomorrow" },
      text = "Nobody woke the Steam Mech. Does it sit this one out?",
      options = {
          { label = "Flitwidget wakes it himself, for the fight", mus = { mark = "mech" }, like = { sam = 2, dev = 1 } },
          { label = "It stays a statue", mus = {}, like = {} },
      } },
}

-- Favors: siding with someone two or more times. Pick one way it helps and one way it hurts.
M.FAVOR_AT = 2
M.favors = {
    flitwidget = {
        name = "Flitwidget", text = "The party keeps taking good care of Flitwidget's museum. Pick one way it helps them and one way it hurts.",
        helps = {
            { label = "He slips them a bracelet of protection", mus = { mark = "bracelet" } },
            { label = "Three extra Francs, \"for the trouble\"", mus = { francs = 3 } },
        },
        hurts = {
            { label = "He volunteers them as guards for his next stop", mus = { flag = "guards" } },
            { label = "He keeps checking on them, loudly, at the worst moments", mus = { flag = "fussed" } },
        },
    },
    telpur = {
        name = "Telpur", text = "The party has taken a shine to Telpur, and Telpur to them. Pick one way it helps them and one way it hurts.",
        helps = {
            { label = "A discount: two Francs back", mus = { francs = 2 } },
            { label = "Gossip: the Gorgon hates fire and loves an audience", mus = { warn = "mus_lair_frame" } },
        },
        hurts = {
            { label = "Telpur insists on coming along", mus = { flag = "telpur_along" } },
            { label = "Telpur tells Flitwidget everything they did", mus = { flag = "told" } },
        },
    },
}

-- Boss night ----------------------------------------------------------------------------------

M.showdown = {
    openers = {
        talk = { name = "She talks first", blurb = "As in the book: a drink, some questions, then an ultimatum.",
                 like = { mara = 2, dev = -1, jess = 2, sam = 1 } },
        ambush = { name = "She strikes from the shadows", blurb = "No talk, no deals: her bow is drawn when they reach the top step.",
                   like = { mara = -1, dev = 2, jess = -1, sam = -1 } },
    },
    styles = {
        yields = { name = "She yields near the end", blurb = "As the book allows: beaten badly enough, she asks to stop.",
                   like = { mara = 1, dev = -1, jess = 1, sam = 2 } },
        last = { name = "She fights to the last", blurb = "No mercy asked, none given.",
                 like = { mara = 0, dev = 2, jess = 0, sam = -1 } },
    },
    drink = {
        id = "mus_drink", type = "story", actor = { "method_actor", "instigator", "casual" }, party = true,   -- (theirs to drink or not: November 3)
        title = "A drink",
        text = "Euryale pours from a carafe of red wine. \"Such a long climb. Rest your feet, and have a glass.\" {actor_char} reaches for a cup.",
        text_if = { { when = { flag = "rematch" }, text = "The carafe is out again. \"Back so soon? Sit. Drink. You'll need it.\" {actor_char} reaches for a cup." } },
        options = {
            { label = "{actor_char} drinks.", want = "drink the wine",
              roll = { dc = 12, skill = { "insight", "religion" }, convenient = "success",
                       success = { log = "It's just very good wine. Euryale looks faintly impressed.", effects = { { "actor", fun = 4, spotlight = 6 } } },
                       fail = { log = "{actor_char} decides Euryale is lovely, actually, and lowers the weapon. If this comes to a fight, {actor_char} starts it charmed.",
                                effects = { { "actor", fun = 2, spotlight = 8 }, { "others", challenge = 4 } }, mus = { flag = "charmed", risk = true, aspect = "Was charmed by a Gorgon, briefly" } } } },
            { label = "Nobody drinks.", want = "leave the wine alone", log = "Untouched cups. Euryale sighs, as if they've hurt her feelings.",
              effects = { { "arch:tactician", fun = 3 }, { "arch:method_actor", fun = -2 } } },
        },
    },
    talk = {
        id = "mus_ultimatum", type = "story", actor = { "storyteller", "method_actor", "instigator" }, party = true,   -- (their answer, not yours)
        title = "Join the collection",
        text = "Euryale sets down her cup. \"Here is your choice. Stay, as part of my collection. Or die.\" {actor_char} has one chance to answer.",
        text_if = { { when = { mark = "garden_burned" }, text = "Euryale doesn't sit. \"Here is your choice. Stay, as part of my collection. Or die.\" {actor_char} has one chance to answer." },
                    { when = { flag = "rematch" }, text = "Euryale sets down her cup. \"I'll ask once more. Stay, as part of my collection. Or die.\" {actor_char} has one chance to answer." } },
        options = {
            { label = "Weapons out.", want = "fight her", log = "Steel answers for them. Euryale stands, smiling. \"As you like.\"",
              effects = { { "arch:butt_kicker", fun = 6 }, { "arch:storyteller", fun = -1 } }, mus = { fight = true } },
            { label = "Bargain: help her find her sisters.", want = "bargain: her sisters for her leaving", needs = { mark = "know" }, alt_needs = { flag = "tapestry" },
              roll = { dc = 14, skill = { "persuasion", "insight" }, convenient = "success",
                       success = { log = "Her hood dips. \"Two clay jars, somewhere out there.\" She'd leave for that. She would.",
                                   effects = { { "actor", spotlight = 14, fun = 8 }, { "arch:storyteller", fun = 8, story = 8 }, { "arch:butt_kicker", fun = -3 } },
                                   mus = { ending = "bargain", aspect = "Talked a Gorgon into a bargain" } },
                       fail = { log = "\"You know nothing about my sisters.\" The hood comes down, a little.",
                                effects = { { "all", challenge = 6 } }, mus = { fight = true } } } },
            { label = "Offer her a cut of the donation box.", want = "buy her off with the donation box", needs = { mark = "robbed" },
              roll = { dc = 13, skill = { "deception", "persuasion" }, convenient = "success",
                       success = { log = "\"Thieves after my own heart.\" She takes the coin, and the back curtain, and she's gone.",
                                   effects = { { "actor", spotlight = 12, fun = 8 }, { "arch:instigator", fun = 8 }, { "arch:storyteller", fun = 2 } },
                                   mus = { ending = "escape", aspect = "Paid a Gorgon to leave" } },
                       fail = { log = "\"You would rob your host twice?\" She laughs, and reaches for her bow.",
                                effects = { { "all", challenge = 6 } }, mus = { fight = true } } } },
            { label = "Hand her a page of the Lecturer's notes.", want = "put her to sleep with the Lecturer's notes",
              needs = { mark = "pages", holds_here = "pages" }, mus = { use = "pages" },
              roll = { dc = 13, skill = { "deception", "sleight_of_hand" }, convenient = "success",
                       success = { log = "She reads the first line, frowns, and is asleep before the second.",
                                   effects = { { "actor", spotlight = 14, fun = 8 }, { "all", fun = 4 }, { "arch:butt_kicker", fun = -2 } },
                                   mus = { ending = "slept", aspect = "Put a Gorgon to sleep with a lecture" } },
                       fail = { log = "She glances at the page and smiles. \"I have read this lecture. I was there.\"",
                                effects = { { "all", challenge = 6 } }, mus = { fight = true } } } },
            { label = "Talk her round. Ask what she really wants.", want = "talk her round", needs = { talk = 2 },
              roll = { dc = 15, skill = { "persuasion", "insight" }, convenient = "success",
                       success = { log = "For the first time, the calm slips. Out there was chaos; in here was safe. And lonely. \"Perhaps,\" she says, \"we need not fight.\"",
                                   effects = { { "actor", spotlight = 16, fun = 10 }, { "arch:storyteller", fun = 10, story = 10 }, { "arch:butt_kicker", fun = -4 } },
                                   mus = { ending = "ally", aspect = "Talked a Gorgon round" } },
                       fail = { log = "\"You do not get to know me.\" The calm comes back, colder.",
                                effects = { { "all", challenge = 6 } }, mus = { fight = true } } } },
        },
    },
    -- Said in the fight, the moment she yields (fight.lua: a boss prepped to yield, below a third
    -- of her hit points); then the yield card plays, once the fight has stopped.
    yield_line = "Euryale stops fighting, and her whole collection goes still around her.",
    -- She died, but her collection still won the fight: she's fallen all the same.
    dead_but_lost = "Euryale is dead, but her collection drives them back down the stairs. By morning, without her, the exhibits go still.",
    yield = {
        id = "mus_yield", type = "boss", actor = { "storyteller", "casual", "butt_kicker" }, party = true,   -- (mercy is theirs)
        title = "\"Enough\"",
        text = "Down on one knee, snakes hissing, Euryale lowers her bow. \"Enough. I yield. Let me go, and you'll never see me again.\"",
        options = {
            { label = "Let her go.", want = "let her go", log = "Nobody lifts a weapon as she gathers up her bow and stands.",
              effects = { { "arch:storyteller", fun = 6 }, { "arch:casual", fun = 4 }, { "arch:butt_kicker", fun = -3 } }, mus = { ending = "escape", aspect = "Let a Gorgon walk free" } },
            { label = "Make her a deal: her sisters, for her help.", want = "make her a deal",
              log = "A long silence. Then a nod. \"For my sisters.\"",
              effects = { { "arch:storyteller", fun = 8, story = 6 }, { "arch:butt_kicker", fun = -2 } }, mus = { ending = "bargain" } },
            { label = "Finish it.", want = "finish it", log = "{actor_char} doesn't hesitate. It's over.",
              effects = { { "arch:butt_kicker", fun = 8 }, { "arch:storyteller", fun = -3 } }, mus = { ending = "fallen", aspect = "Ended Euryale" } },
        },
    },
}

-- When the talk ends it but her marks brought her company: what the company does, by the ending.
-- fight: they still fight (led by {lead}); otherwise she calls them off and there's no fight.
M.after_talk = {
    ally = { line = "Euryale lifts one hand, and her whole collection goes still.", fight = false },
    bargain = { line = "\"Leave them be,\" she tells her collection. One by one, they go still.", fight = false },
    escape = { line = "Euryale takes the coin and is gone through the back curtain. Her collection doesn't care for coin: {lead} comes forward.", fight = true },
    slept = { line = "Euryale snores. Her collection doesn't: as they lift her, {lead} comes forward.", fight = true },
}
-- How a fight with only her collection ends badly: she's gone already, so it ends anyway.
M.extras_lost = "They fall back down the stairs, battered. Without her, the collection loses heart by morning, and the exhibits go still."
-- Who leads her collection when she isn't fighting, and how any foe is named in a sentence.
M.foe_names = {
    euryale = "Euryale", knight_of_shades = "the Knight of Shades", kruthik_huntling = "the biggest huntling left",
    giant_scarab_swarm = "the scarab swarm", briar_beast = "the last briar beast", briar_triceratops = "the briar triceratops",
    briar_boar = "a briar boar", bone_construct = "the Bone Construct", sentinel = "the Sentinel", the_lecturer = "the Lecturer",
}
M.lead_order = { "knight_of_shades", "briar_beast", "giant_scarab_swarm", "kruthik_huntling" }

-- How the prologue ends, by how they dealt with Euryale.
M.endings = {
    fallen = { name = "Euryale falls",
               line = "She crumples as she falls, and whatever she was slips away into the gaps in the floor like smoke. Only a purple robe, a white hood and an emerald bow are left.",
               -- (How she fell changes what's left: her own reflection turned her to stone.)
               stone_line = "Euryale stands where the mirror caught her, stone from hood to bow. Around the lair, the other statues start to soften back into people.",
               flit = "\"Splendid! Though I wouldn't bet my caravan she's gone for good. Her kind have a habit of coming back.\"" },
    bargain = { name = "A bargain with a Gorgon",
                line = "Euryale leaves the museum with a promise: they'll look for two clay jars, and she'll owe them a favour.",
                flit = "\"A bargain? With her? Well. I suppose that's one way to tidy up.\"" },
    escape = { name = "Euryale slips away",
               line = "Euryale is gone through the black curtain, out into the world. The statues in the lair start to soften back into people. Somewhere out there, a Gorgon is loose: a problem for another night.",
               flit = "\"Out? Well, as long as she's out of my museum. Mostly that's what I wanted. Mostly.\"" },
    slept = { name = "Euryale, asleep",
              line = "They carry Euryale out through the black curtain, snoring softly, and leave her somewhere far from the museum. The statues in the lair start to soften back into people.",
              flit = "\"Asleep? On a lecture? I always said it was a very good lecture.\"" },
    ally = { name = "An unlikely ally",
             line = "Euryale stays, as curator of her own quiet wing. The statues soften back into people, blinking, one by one.",
             flit = "\"Co-curators? I... suppose she does have an eye for arrangement.\"" },
    timeout = { name = "Still upstairs",
                line = "Weeks went by and Euryale is still upstairs. Flitwidget packs up the caravan and moves on, very carefully.",
                flit = "\"Perhaps we come back to this one.\"" },
}
M.epilogue = {
    "And an invitation: Flitwidget needs guards for the road, and he's heard strange news from the mountains. A murder, and a conspiracy.",
}
-- What each friend says when the prologue ends: they want the full campaign.
M.want_more = {
    mara = { { "Okay, the Witness. A sunken city. I need to know. When's the campaign?", when = { flag = "notebook" } },
             "That was a prologue? I've already got a notebook for the campaign." },
    dev = { "Same heroes, bigger fights? I'm in. Every Thursday.", "Level 4 and a gnome with a caravan. Let's go." },
    jess = { "Pip is keeping the gnome. Pip is keeping everything. Campaign. Now.", "I want to see where the caravan goes next." },
    sam = { "That was so much fun. Same time next week? For the real thing?", "I'll bring snacks for the whole campaign. That's a promise." },
}

-- The group chat between sessions: what the friends say about the room they just played.
-- The everyday bit of the group chat, one a week: { who, line, who replies, their reply }.
M.chat_banter = {
    { "sam", "who's on snacks this week", "jess", "me. it's going to be crisps again" },
    { "mara", "i made a little map of the museum. don't look at it dev, it has spoilers", "dev", "how does it have spoilers. you made it" },
    { "jess", "can we start 15 min late thursday, bus thing", "sam", "np, i'll be late anyway" },
    { "dev", "i've been practising brannoc's battle cry in the car", "mara", "please don't do it at the table" },
    { "sam", "bought new dice. they're green. they already roll badly", "jess", "a classic", dice = "jade" },   -- (his tray rolls them from now on)
    { "mara", "does anyone know if gnomes have middle names", "jess", "flitwidget absolutely has four" },
}

-- Questions for the DM in the group chat, one a week (museum_week.write_chat); you answer from the
-- board, and the one who asked takes it the way it lands. Lore, a ruling, the plan for Thursday.
-- replies: { label (your button), say (what you post), back (their answer), effects (their stats) }.
M.chat_ask = {
    { id = "flit_wizard", who = "mara", from = 1, text = "@DM is flitwidget an actual wizard or just a very confident gnome",
      replies = { { label = "A wizard. Obviously.", say = "a wizard. obviously.", back = "i KNEW it", effects = { investment = 2 } },
                  { label = "You'll have to find out.", say = "you'll have to find out", back = "rude. writing that down", effects = { investment = 3 } },
                  { label = "A very confident gnome.", say = "a very confident gnome", back = "honestly that's worse", effects = { fun = 1 } } } },
    { id = "pip_pet", who = "jess", from = 2, text = "@DM can pip adopt a museum rat. his name is exhibit b",
      replies = { { label = "Yes. Exhibit B is yours.", say = "yes. exhibit b is yours", back = "EXHIBIT B LIVES", effects = { investment = 4, fun = 2 },
                    companion = "exhibit_b" },
                  { label = "If Pip can find one.", say = "if pip can find one", back = "challenge accepted", effects = { investment = 2 },
                    companion_find = "exhibit_b" },
                  { label = "No pets in the museum.", say = "no pets in the museum, sorry", back = "flitwidget would allow it", effects = { fun = -2, trust = -1 } } } },
    { id = "sam_rules", who = "sam", from = 2, text = "@DM quick one: does a healing spell work through a closed door",
      replies = { { label = "Only if Oswin can see them.", say = "only if oswin can see them", back = "fair", effects = { trust = 2 } },
                  { label = "I'll look it up and get back to you.", say = "i'll look it up and get back to you", back = "appreciate it", effects = { trust = 1, commitment = 1 } },
                  { label = "Sure, why not.", say = "sure, why not", back = "...ok cool", effects = { trust = -1, fun = 1 } } } },
    { id = "gorgon_strength", who = "dev", from = 2, text = "@DM how strong is the gorgon. like on a scale of one to brannoc",
      replies = { { label = "Stronger than you'd like.", say = "stronger than you'd like", back = "perfect", effects = { investment = 2 } },
                  { label = "You'll find out.", say = "you'll find out", back = "that's not a number", effects = { fun = 1 } },
                  { label = "Honestly? Very.", say = "honestly? very", back = "ok now i'm scared. good scared", effects = { investment = 3 } } } },
    { id = "mara_map", who = "mara", from = 2, text = "@DM is it ok if i keep a map of the museum in my notebook. for thessaly",
      replies = { { label = "Please do. I love that.", say = "please do. i love that", back = "eee ok", effects = { investment = 3, commitment = 1 } },
                  { label = "Sure.", say = "sure", back = "ok!", effects = { investment = 1 } } } },
    { id = "time_check", who = "sam", from = 3, text = "@DM are we still on for 7 thursday",
      replies = { { label = "7 sharp.", say = "7 sharp", back = "see you then", effects = { commitment = 2 } },
                  { label = "Let's say 7:30.", say = "let's say 7:30", back = "even better", effects = { commitment = 1, fun = 1 } } } },
    { id = "telpur_deal", who = "jess", from = 3, when = { done = "gift_shop" }, text = "@DM what's telpur's deal. is the boot ok",
      replies = { { label = "Telpur is a demon lord. In a boot.", say = "telpur is a demon lord. in a boot", back = "i have so many questions", effects = { investment = 3 } },
                  { label = "Ask Telpur.", say = "ask telpur", back = "i WILL", effects = { fun = 2 } } } },
    { id = "brannoc_gorgons", who = "dev", from = 3, text = "@DM would brannoc know anything about gorgons. soldier family and all",
      replies = { { label = "He's heard the stories.", say = "he's heard the stories. none of them end well", back = "nice. ominous", effects = { investment = 3 } },
                  { label = "Roll History when you get there.", say = "roll history when you get there", back = "rolling a 20 already", effects = { investment = 2 } } } },
}

M.chat = {
    -- (A line about something only if it happened: { text, when = condition }, as on moments.)
    street = { jess = { "flitwidget is lying and i love him", when = { not_flag = "truth" } }, sam = "do we get a discount at the gift shop since we're the help" },
    garden = { dev = "the topiary fight. ten out of ten", mara = { "the sign said use water. i'm thinking about that sign", when = { seen = "mus_plaque" } } },
    entrance = { jess = { "i would like it on record that i only LOOKED at the box", when = { seen = "mus_box", not_mark = "robbed" } },
                 sam = { "the statue said thank you. it was very loud", when = { flag = "boon" } } },
    chamber = { mara = { "five gallons, three gallons, four gallons. i dreamt about jugs", when = { seen = "mus_tablet" } }, dev = "three skulls is too many skulls" },
    paintings = { jess = { "WHO PAINTED US INTO THE PAINTING", when = { seen = "mus_dice_painting" } },
                  mara = { "the lady by the mountains. who is she", when = { flag = "portrait_mara" } } },
    gift_shop = { jess = "telpur is my favourite character and they are a shoe", dev = "can i buy the marbles. for throwing" },
    hunting = { sam = "those huntlings were smart. i hated it. good fight though", dev = { "we should've chased the ones that ran", when = { mark = "pack" } } },
    offices = { mara = { "a city under the sea. the WITNESS. i have so many questions", when = { flag = "notebook" } },
                sam = { "the eyes on his arms. not ok", when = { seen = "mus_office_inside", not_soft = "gore" } } },
    tomorrow = { dev = { "WE HAVE A ROBOT", when = { mark = "mech" } }, jess = { "i'm calling it el roboto whatever its real name is", when = { mark = "mech" } } },
    lecture = { sam = "that was my third period chemistry class", jess = "i fell asleep in real life a little" },
    stairs = { dev = { "boss fight next week. finally", when = { not_flag = "rematch" } }, mara = "she's been watching us this whole time hasn't she" },
}

-- What each of the museum's people knows about the party (the DM runs them, so they remember):
-- the first ones that hold, as phrases for the talk card and their lines. when: as on moments.
M.memory = {
    mus_flitwidget = {
        { when = { mark = "robbed" }, text = "they tried to rob his donation box" },
        { when = { flag = "boon" }, text = "they dropped a coin in his donation box" },
        { when = { chose = { "mus_tidy", 1 } }, text = "they put his exhibits back" },
        { when = { chose = { "mus_return_paint", 1 } }, text = "they slid the paint back into his paintings" },
        { when = { mark = "mech" }, text = "they woke his Steam Mech" },
        { when = { flag = "truth" }, text = "they know what's really upstairs" },
        { when = { done = "street" }, text = "they took his job" },
    },
    mus_telpur = {
        { when = { flag = "manual" }, text = "they bought the Mech manual" },
        { when = { flag = "arrows" }, text = "they bought fire arrows and slime" },
        { when = { mark = "know" }, text = "they bought the book on gorgons" },
        { when = { flag = "telpur_along" }, text = "they're taking Telpur along" },
        { when = { done = "gift_shop" }, text = "they've rested in the shop" },
    },
}
-- How a talk with them goes when the DM speaks for them (game/model/takeover.lua): their own words
-- for each stance, a first meeting (open) and seeing the party again (again), and asked for what
-- they know (ask). In the museum nobody says "go north, they say".
M.talk = {
    mus_flitwidget = {
        open = { warm = { "Adventurers! You have the look. Come, come, never mind the crowd." },
                 guarded = { "Closed. Temporarily. Ish. Who's asking?" },
                 lie = { "Nothing's wrong with my museum. A few incidents. With the exhibits." } },
        again = { warm = { "My heroes! Sit, sit. There are biscuits.", "You're back! And mostly in one piece!" },
                  guarded = { "Ah. You. Yes. Let's talk about my donation box first.", "Before anything else: is anything broken?" },
                  lie = { "Everything's fine! Splendid! Nothing at all for you to worry about. Upstairs." } },
        ask = { warm = { "A Gorgon. Euryale. I bought her in a jar, and the jar broke. There. I said it.",
                         "Here is what I know, all of it, and some of it twice." },
                guarded = { "Some things a curator keeps to himself.", "Ask me again when my museum's quiet." },
                lie = { "Incidents. With the exhibits. That's all.", "The gift shop is lovely this time of year." } },
        -- (When it's over: the museum is his again.)
        done = { warm = { "You did it. My museum! Quiet as a library. Have a biscuit. Have two." },
                 guarded = { "It's over. I'll be counting the exhibits for a week, mind." },
                 lie = { "I never doubted you for a moment. Well. One moment. Possibly two." } },
    },
    mus_telpur = {
        open = { warm = { "Oh, bloody 'ell, customers. Lovely. Browse away." },
                 guarded = { "Hands where I can see them. Everything's paid for or it stays put." },
                 lie = { "Me? Just a boot. Nothing upstairs at all." } },
        again = { warm = { "My favourite customers! What'll it be?", "Back again? Mind the marbles." },
                  guarded = { "No refunds on anything you bought last time. Before you ask." },
                  lie = { "Never seen you before in my life. Which is long." } },
        ask = { warm = { "Upstairs? She hates fire and loves an audience. You didn't hear it from me." },
                guarded = { "A boot hears things. A boot doesn't repeat them." },
                lie = { "Upstairs is just storage. Lovely storage." } },
    },
}

-- The DM's NPC lines, for game night's dialogue (game/model/dialogue.lua cells). speaker: the
-- cast card. trigger: npc_greet, npc_good, npc_bad, npc_taunt, npc_down.
M.npc_lines = {
    mus_flitwidget = {
        npc_greet = { "Welcome, welcome! Closed, I'm afraid. Temporarily. Ish.", "Ah! Adventurers! You have the look. The look of people who need money." },
        -- (Seeing them again: museum_night's greeting picks these once they've met.)
        npc_again = { "My heroes! You're back! Tea?", "There you are! Come in, come in. Mind the exhibits." },
        npc_good = { "Splendid! Marvellous! I knew you had the look.", "Oh, you're good. You're very good. Do you want a job? You have a job." },
        npc_bad = { "Now, now. Let's not upset the exhibits.", "That's... not how I would have done it. But it's done." },
    },
    mus_telpur = {
        npc_greet = { "Wha? Oh! Customers. I was resting my laces. Welcome to the gift shop.", "Browse all you like. Whatever you break, you've bought." },
        npc_again = { "Back again? Lovely. Still no refunds.", "My favourite customers. Mind the marbles." },
        npc_good = { "Lovely choice. Very lovely. Can't take it back, mind.", "A customer with taste. Rare, round 'ere." },
        npc_bad = { "Don't touch the marbles unless you're buying the marbles.", "I was a duke of the underworld, you know. I don't have to take this." },
    },
    mus_euryale = {
        npc_greet = { "Welcome. What a long way you've come.", "Come in. Sit. I've been listening to you all the way up." },
        npc_good = { "Oh, well done. Well done indeed.", "You're cleverer than the others were." },
        npc_bad = { "That was a mistake. A small one. You'll make bigger.", "Do you know how long I sat in that jar?" },
        npc_taunt = { "Look at me. Just for a moment.", "Every one of these statues was braver than you." },
        npc_down = { "Clever... but not clever enough.", "This is not over. It is never over, for my kind." },
    },
    mus_lecturer = {
        npc_greet = { "...and so, as I was saying, the history of soil...", "Sit. Sit. We are only on chapter forty." },
        npc_taunt = { "Settle down at the back.", "There will be a test." },
        npc_down = { "Class... dismissed...", "But I haven't... set the homework..." },
    },
}

-- What the night opens with, by part of the museum (the read-aloud before the first room).
-- (Said only when the last night ended in that room: museum_night.intro.)
M.openings_from = {
    gift_shop = { [2] = "The gift shop door clicks shut behind them. Up the stairs, the museum gets untidier, and quieter." },
}
M.openings = {
    [1] = "Everyone in town is talking about the new museum. The merchants were amazed. The guards were terrified. The children won't stop giggling.",
    [2] = "Past the gift shop and up the stairs, the museum gets untidier, and quieter.",
    [3] = "The narrow stair. A smell of smoke and wine. A curtain at the top, and someone humming behind it.",
}
-- The names the Steam Mech might have (the book's list).
M.mech_names = { "Hans", "Nevile", "Yukiko", "El Roboto", "Owen" }

return M
