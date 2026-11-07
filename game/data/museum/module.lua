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

-- The gift shop's prices, in Flitwidget Francs (the shopping card, mus_shopping): each option's label,
-- its price and what it takes from the pool all come from here. The book prices the Tenets of the
-- Rotting Temple and the Mech manual the same, 6 Francs, and a fire arrow and a bucket of slime at 3
-- and 4; the museum pays fewer Francs than the book, so these keep its order (the manual no cheaper
-- than the Tenets, the arrows and slime the dearest) at the museum's own level. Measured over 300
-- seeded prologues with the three sim DMs, the party brings 6 or 7 Francs to the counter the first
-- time (2 to 13): at these prices about two in three can buy one thing, one in four could buy two,
-- almost none all three, and one in twelve can't buy anything yet. Change a price here and nowhere else.
local PRICE = { tenets = 4, manual = 4, arrows = 5, guide = 4 }
M.PRICE = PRICE           -- (Telpur's price on the day reads these: what he thinks of them moves it, people.price)
local function priced(label, n)
    return label .. " (" .. n .. " Francs)"
end

M.id = "museum"
M.title = "The Museum of Nightmares"
M.rules = "5e"          -- (its rule set: docs/design/rule-sets.md)
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
      about = "A talking boot. Says he was once a great lord of the underworld. It's all a bit hazy." },
    { id = "mus_euryale", name = "Euryale", role = "The Gorgon upstairs", known = true,
      about = "Calm, clever, and very patient. She turns people to stone, but only when she has to." },
    { id = "mus_mech", name = "The Steam Mech", role = "The World of Tomorrow's pride",
      about = "A brass war machine from a forgotten war. Obeys whoever speaks its name first." },
}

-- Each hero's reason for coming, from the book's background hooks. The player leans one way
-- (lean); the DM picks. room: where the hook pays off (the hero sits up when it plays).
-- votes: what the hero's reason for coming makes their player keen on at a vote (museum_night.carry): the
-- careful way or the bold one, where one way is a risk to them, said in their own words, three ways
-- (`here`: in the room the hook is about, the fight). The confirming playtest, alive 1: every friend made the same bid at the same
-- beat in 24 runs of 24; the hero's own reason for coming is part of the moment, and it varies.
M.hooks = {
    mara = {
        { id = "sage", name = "Knowledge", text = "Whole worlds under one roof. Thessaly wants to know everything in there.",
          room = "offices", lean = 2, says = "Every book, every exhibit. I'll take notes.",
          votes = { kind = "safe", say = { "Carefully. I want to learn something here.", "Let's do this properly. I'm taking notes.",
                                           "Slowly. There's so much to learn in here." } },
          intro = "I've read about every wonder in the world. A museum with whole worlds inside it? I'm not missing that.",
          payoff = "Thessaly runs a finger down the notes pinned round the study. Drawings and notes on every wall, more than anyone could read in a year." },
        { id = "hermit", name = "Wonder", text = "After years with her books, other worlds behind a caravan curtain are too good to pass up.",
          room = "paintings", lean = 1, says = "Paintings of places that don't exist? Yes, please.",
          votes = { kind = "bold", say = { "I didn't leave my books to stand at the back.", "I didn't come all this way to play it safe.",
                                           "Other worlds don't come to you. Let's go." } },
          intro = "I've spent years with my books. Someone said there are other worlds behind that caravan's curtains. I want to see one.",
          payoff = "A painting of a place that doesn't exist hangs right in front of Thessaly. Through the frame comes a breath of cold air from somewhere nobody has ever been." },
    },
    dev = {
        { id = "soldier", name = "Duty", text = "If something in that caravan is dangerous, it's inside the town walls. That makes it Brannoc's problem.",
          room = "lair", lean = 2, says = "Point me at whatever's doing the killing.",
          votes = { kind = "safe", say = { "A soldier picks his fights. This isn't one.", "Save it for whatever's doing the killing.",
                                                         "I've seen good people rush in. Let's not." },
                    -- (In the room he came for, the soldier wants the fight.)
                    here = { kind = "bold", say = { "This is what I came for. Point me at her.", "She's the one doing the killing. We end it.",
                                                    "I came here to stop her. So let's stop her." } } },
          intro = "I was a soldier. If something in that caravan is a danger to this town, it's my job to stop it.",
          payoff = "Brannoc tightens his grip on his sword. Whatever has the guards in this town so scared, it's right here." },
        { id = "folk_hero", name = "Rumour", text = "The taverns say the museum is dark magic. Somebody has to go and look, so Brannoc will.",
          room = "garden", lean = 1, says = "Dark magic. Sure. I'll bring an axe.",
          votes = { kind = "bold", say = { "The taverns want a story. Let's give them one.", "I didn't come here to tiptoe round it.",
                                           "Dark magic or not, let's get on with it." } },
          intro = "The taverns say the museum's dark magic. Somebody should go in and hit the dark magic. I volunteered.",
          -- (Nothing they haven't seen yet: the hedges are hedges until they move. Conner's playtest, C4.)
          payoff = "A whole garden inside a caravan, under a sky that twists. The taverns were right: this is dark magic." },
    },
    jess = {
        { id = "charlatan", name = "A con", text = "The gnome is running a con, and Pip isn't in on it. Unacceptable.",
          room = "street", lean = 2, says = "He's lying, and I want to know how good he is at it.",
          votes = { kind = "bold", say = { "A good con takes nerve. Let's have some.", "Nerve is my whole job. Come on.",
                                           "Fortune favours the brave. And the shifty." } },
          intro = "I know a con when I see one, and that gnome is running a good one. I want in.",
          payoff = "Up on the caravan roof, Flitwidget works the crowd like a fiddle: a wink here, a sad little sigh there, a hat held out at just the right moment. It's a con, and a good one." },
        { id = "criminal", name = "Lying low", text = "A doorway to another world is a lovely place to lie low for a while.",
          room = "gift_shop", lean = 1, says = "Somewhere nobody's looking for me? Sold.",
          votes = { kind = "safe", say = { "I'm meant to be lying low. Low means quiet.", "No fuss, please. I'm hiding, remember.",
                                                         "Let's not get noticed. That's the whole plan." } },
          intro = "I need somewhere to lie low for a bit. A whole other world behind a curtain? Perfect.",
          payoff = "A shop inside a pocket world, behind a curtain nobody outside knows about. Pip puts her feet up. Nobody out there will ever think to look in here." },
    },
    sam = {
        { id = "acolyte", name = "Faith", text = "Rumour says some exhibits mock the gods. Oswin has been asked to take a look.",
          room = "chamber", lean = 2, says = "Somebody should check it's not blasphemous. Gently.",
          votes = { kind = "safe", say = { "My temple would want us to be respectful.", "Gently. Some of this matters to someone.",
                                           "The respectful way, please." } },
          intro = "My temple asked me to look at the museum. Some of the exhibits might be, um, blasphemous. I'll be polite about it.",
          payoff = "Oswin reads the chamber's old glyphs with care. Nothing blasphemous in them: only very, very old prayers, to gods nobody has prayed to in a long while." },
        { id = "urchin", name = "A bad feeling", text = "The museum seems harmless. Oswin can't shake the feeling that it isn't.",
          room = "hunting", lean = 1, says = "Something's off about the whole thing. I'll keep an eye out.",
          votes = { kind = "bold", say = { "Streets teach you: don't wait for trouble to find you.", "Bad feeling or not, standing here won't help.",
                                           "Grew up on the streets. Sometimes you just go." } },
          intro = "Everyone says the museum's harmless. I grew up on the streets, and I've got a bad feeling about it.",
          -- (Not what's hiding up here before it moves: root causes, class 1.)
          payoff = "Every stuffed beast on this floor seems to be looking at Oswin. Glass eyes, every one of them, and they follow him across the room." },
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
    -- What you've told them going in: the premise, as the book's opening has the town talking about it. All
    -- they know of the adventure before the first night (tools/tests/knowledge_check.lua). Not the Gorgon:
    -- the book keeps her for Flitwidget's confession (p6), and so do the tones and everyone's lines here.
    told = "You've told them the premise: Formicarius Flitwidget's travelling museum is in town, and everyone's talking about it.",
    tones = {
        mixed = { name = "A spooky funhouse", blurb = "The book's own feel: weird rooms, real teeth, and a few laughs.",
                  says = { mara = "Creepy with a wink. As long as the scary parts are properly scary.",
                           dev = "Funhouse with monsters in it? Sold.",
                           jess = "A funhouse. I've already decided Pip loves it.",
                           sam = "Spooky but fun. I can do that." } },
        heroic = { name = "Monster hunters", blurb = "Big heroes clean out a haunted museum and save the town.",
                   says = { mara = "Fine, but the museum's mysteries should still matter.",
                            dev = "We hunt monsters. Perfect.",
                            jess = "Pip, monster hunter. Pip would like a hat for this.",
                            sam = "Heroes saving a town. That's a good Thursday." } },
        grim = { name = "Proper horror", blurb = "Rooms that feel wrong, and things best left alone. Real fear.",
                 says = { mara = "Yes. The museum should feel wrong.",
                          dev = "Scary fights? I'm listening.",
                          jess = "Can Pip still be funny while everyone screams?",
                          sam = "I come here to unwind, not to have nightmares." } },
        silly = { name = "A cartoon caper", blurb = "A gnome, a museum of oddities, and nobody too serious.",
                  says = { mara = "Then nobody cares what's really behind the curtain.",
                           dev = "Do cartoon monsters still count as fights?",
                           jess = "CARTOON MONSTERS.",
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
        jess = { text = "Let Pip talk to people. Flitwidget, anyone she meets. Don't cut my chats short to get to a fight.",
                 agree = { reply = "YES. Pip has questions for everyone." } },
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
        -- (What he says to everyone, no roll needed (p6): closed, "incidents", and a request. The second round's
        -- review: four runs in nine shook on a job nobody had offered.)
        read = "Everyone in town is talking about the new museum. The talk leads to a crowded back street, and a gnome on the roof of a caravan, shooing the crowd away: the museum is closed, he's afraid, on account of some incidents with the exhibits. Then he spots the party. He has a request, for anyone brave: sort out his troublesome exhibits, and he'll make it worth their while.",
        sum = "Meet Flitwidget, hear about the Gorgon, take the job.",
        next = { "garden" }, knobs = { "pry" },
    },
    garden = {
        statues = true,      -- (what the room has, for lines about it: barks context)
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
        statues = true, locks = true,
        name = "The entrance hall", part = 1, type = "social", quick = true, cost = 1, at = { 50, 74 }, map = "Entrance",
        comps = { location = "mus_entrance", cast = "mus_sentinel", goal = "mus_donation", complication = "mus_statue", reward = "mus_boon" },
        encounter = { "sentinel" }, boss_name = "the Sentinel", optional_fight = true,
        read = "Huge carved doors open on marble and blue light, a chandelier, and a glass donation case. Two signed doors at the far end, and a metal statue of an armoured man between them.",
        sum = "A donation box full of every coin in the world, and the guard that protects it.",
        next = { "chamber", "paintings" },
    },
    chamber = {
        name = "The Chamber of Ancients", part = 1, type = "puzzle", cost = 2, at = { 26, 62 }, map = "Ancients",
        comps = { location = "mus_chamber", cast = "mus_bone_construct", goal = "mus_ritual", complication = "mus_scarab_cracks", reward = "mus_francs" },
        encounter = { "bone_construct" }, boss_name = "the Bone Construct", optional_fight = true,
        read = "Sandstone columns and a hot, whispering wind. A guardian of gold and bone stands among old jugs, one carved with a falcon, one with a jackal, by a cracked tablet. A crocodile set into the wall, two curved daggers with locked rings, a pedestal with a button, and a rack of bones across the far door.",
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
            -- (The DM said yes, Telpur stocks one: there it is, on his shelf, at its price. Round three: the
            -- yes never showed.)
            { when = { flag = "vorpal_price", not_flag = "vorpal_sword" }, text = "On the shelf behind the counter, wrapped in brown paper, just as promised in the chat: the vorpal sword. The tag says forty Francs. Telpur taps it." },
            { when = { flag = "stairs_statue" }, text = "The statue is still at the foot of the stairs, one stone hand on the first step. Telpur swears it was a step lower this morning." },
            -- (The wake was held before they found the shop: word of it got here first. The confirming
            -- playtest, 53 careful, held it here with a boot they hadn't met.)
            { when = { flag = "wake_away" }, text = "Word of {dead} has reached the gift shop before the party. A candle is already burning on the counter." },
        },
    },
    hunting = {
        name = "The Hunting Grounds", part = 2, type = "combat", cost = 2, at = { 50, 37 }, map = "Hunting Grounds",
        comps = { location = "mus_hunting", cast = "mus_huntlings", goal = "mus_hunt", complication = "mus_lure", reward = "mus_mirror" },
        encounter = { "kruthik_huntling", "kruthik_huntling", "kruthik_huntling", "kruthik_huntling", "kruthik_huntling" },
        boss_name = "the biggest huntling",
        -- (As the book's read-aloud has it, p19: untidier, and they feel watched. The pack and where it hides
        -- are yours until they strike: the knowledge playtest.)
        read = "Up the stairs, a floor full of dioramas and stuffed beasts. It's messier up here, and something is watching.",
        sum = "Pack hunters hiding among the exhibits. They bait traps, and they run when they're losing.",
        next = { "offices", "tomorrow", "lecture", "stairs" }, knobs = { "marks" },
    },
    offices = {
        locks = true,
        name = "The offices", part = 2, type = "mystery", cost = 2, at = { 20, 24 }, map = "Offices",
        comps = { location = "mus_offices", goal = "mus_archivist", complication = "mus_whispers", reward = "mus_notebook" },
        -- (The bird is quiet first, so the twist's singing is a change: Celestia sing when there's magic about,
        -- the book p21, and the notebook next door is that. Round four's review: it stopped singing for it.)
        read = "Two quiet studies off the hunting floor. In one, a little gold-and-white bird with six wings, each patterned like an eye, sits silent under a glass dome. The other door is locked from the inside.",
        sum = "A six-winged bird, a dead archivist, and the first hint of something called the Witness. No fight.",
        next = { "tomorrow", "lecture", "stairs" }, knobs = { "witness" },
    },
    tomorrow = {
        name = "The World of Tomorrow", part = 2, type = "puzzle", cost = 1, at = { 50, 24 }, map = "Tomorrow",
        comps = { location = "mus_tomorrow", cast = "mus_mech", goal = "mus_wake_mech", complication = "mus_panel", reward = "mus_mech_ally" },
        read = "Static, neon, and a delighted voice from the ceiling welcoming them to the future, and to its star: the Steam Mech.",
        sum = "A brass war machine that obeys whoever cracks its code and speaks its name.",
        next = { "offices", "lecture", "stairs" }, knobs = { "timer" },
    },
    lecture = {
        name = "The lecture theatre", part = 2, type = "combat", cost = 2, at = { 80, 24 }, map = "Lecture",
        comps = { location = "mus_lecture", cast = "mus_lecturer", goal = "mus_silence", complication = "mus_drone", reward = "mus_sleep_notes" },
        encounter = { "the_lecturer" }, boss_name = "the Lecturer",
        read = "Benches, dust and cobwebs. Shrivelled figures slump on the benches, still facing the front. Blankets hang over the windows, a blackboard is full of chalk, and a lectern glows under a green lamp, where a lecture is still going on.",
        sum = "A ghost whose lecture is so dull it puts people to sleep for good.",
        next = { "offices", "tomorrow", "stairs" },
    },
    stairs = {
        name = "The stairs up", part = 2, type = "exploration", quick = true, cost = 0, at = { 50, 12 }, map = "Stairs", stop = true, virtual = true,
        read = "At the far end of the hunting floor, a narrow stair climbs toward a smell of incense and wine.",
        read_if = { { when = { from = "gift_shop", done = "offices" }, text = "Up from the gift shop, back across the quiet hunting floor, and to the narrow stair between the two studies. It climbs toward a smell of incense and wine." },
                    { when = { from = "gift_shop" }, text = "Up from the gift shop, back across the quiet hunting floor, to the narrow stair at its far end. It climbs toward a smell of incense and wine." },
                    { when = { done = "offices" }, text = "Between the two studies, a narrow stair climbs toward a smell of incense and wine." } },
        sum = "Up to Euryale. The night stops at the top step.",
        next = { "lair" },
    },
    lair = {
        statues = true,
        name = "The Gorgon's lair", part = 3, type = "set_piece", cost = 2, at = { 50, 1 }, map = "Gorgon's lair", boss = true,
        comps = { location = "mus_lair", cast = "mus_euryale", goal = "mus_face_her", complication = "mus_stare", reward = "mus_quiet" },
        encounter = { "euryale" }, boss_name = "Euryale",
        read = "The stairs end in a room like a temple: mosaics underfoot, smashed pottery everywhere, smoke in the air, and statues twisted as if they were screaming.",
        sum = "Euryale, and everything the party did on the way up.",
        next = {},
        -- Said as the room starts, when they hold: what the week between promised, paying off here.
        callbacks = {
            -- (The notebook went to her between sessions, a loose end: from the offices they never searched,
            -- so it's new to them, and so is the Witness. The confirming playtest, seed 57 careful: "Your
            -- Witness writes beautifully", to a party that never saw the notebook or heard the name.)
            { when = { flag = "she_read" }, text = "A notebook lies open on her couch, every page full of drawn eyes. \"I have read every page,\" Euryale says. \"Something was talking to whoever wrote it.\"" },
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
            -- (Three ways, and a quiet one after a death, `sad`: Telpur's knockout and its follow-up played
            -- the same way every time, the third playtest; and he boasted at a wake, round three's merge.)
            { when = { flag = "telpur_fell" },
              text = { "Telpur is back on his counter with a sock tied round his middle like a bandage. He tells everyone who'll listen how he took a hit for the party.",
                       "Telpur is back on his counter, one lace in a sling. Every customer hears how he threw himself in harm's way. It gets bigger every time.",
                       "Telpur is propped on his counter on a cushion, very carefully. \"Battle wound,\" he tells anyone who looks. \"Took it for the team.\"" },
              sad = { "Telpur is back on his counter with a sock tied round his middle like a bandage. For once, he doesn't say a word about it.",
                      "Telpur sits on his counter, one lace in a sling, and keeps his story to himself tonight.",
                      "Telpur is propped on a cushion on his counter. Nobody asks about the battle wound, and he doesn't tell it." } },
            { when = { flag = "telpur_along", not_flag = "telpur_fell" },
              text = { "Telpur hops back onto his counter, laces still dusty from upstairs, and starts telling everyone how he saved the day.",
                       "Telpur hops back onto his counter and starts on the story of the night. In his version, he did most of it.",
                       "Telpur is back on his counter, dusting off his laces and telling the snow globes how it went upstairs." },
              sad = { "Telpur hops back onto his counter, laces still dusty from upstairs, and for once says nothing at all.",
                      "Telpur climbs back onto his counter without a word and sits very still.",
                      "Telpur is back on his counter. He starts to tell the story of the night, then stops." } },
            { when = { flag = "told" }, text = "\"Telpur told me everything, you know,\" says Flitwidget, pouring the tea. \"Everything.\" He doesn't say which bits he minded." },
            { when = { flag = "guards" }, text = "Flitwidget has already told the next town they're his caravan guards. Nobody remembers agreeing to it.", sad = false },
            -- (Said downstairs: it's where they found it, on the way out of her lair.)
            { when = { flag = "vorpal_lair" }, text = "On the way out of her lair, {given} looked behind Euryale's couch, right where you said it would be: a vorpal sword. It's {given}'s now.",
              give = { magic = "vorpal_sword", who = "dev" } },
        },
    },
}
-- More of them, when the DM calls reinforcements on an early knockout (fight.lua M.reinforcement): the
-- room's own kind, by name. A room not listed has nobody to send (the entrance's guard, the Knight, the
-- Lecturer stand alone), so the card doesn't offer it there. tag: a Session Zero content tag (a line
-- drawn: never; a veil: the soft words).
M.reinforcements = {
    garden = { id = "briar_beast", n = 1, label = "It falls, but another hedge-beast wakes.",
               line = "{boss} falls, but the garden isn't done: another briar beast tears itself out of the topiary." },
    chamber = { id = "giant_scarab_swarm", n = 1, tag = "bugs", label = "It falls, but scarabs pour out of the floor.",
                line = "{boss} falls, and a swarm of scarabs boils up out of the cracks in the floor.",
                soft = "{boss} falls, and something swarms up out of the cracks in the floor. You keep it in the shadows." },
    hunting = { id = "kruthik_huntling", n = 2, tag = "bugs", label = "It falls, but two more huntlings drop in.",
                line = "{boss} falls, and two more huntlings drop out of the dioramas.",
                soft = "{boss} falls, and two more of the hunters come out of the dioramas, kept to the edges of the board." },
}
-- Once a night, as the first fight starts (museum_night.arm), when they hold: what the week
-- between left them with. no_sneak: nobody gets the drop on anyone this time.
-- (lines: other ways to say it, fresh across weeks. One that changes nothing, like the shoelace, isn't
-- said two weeks running: the second playtest review heard the same pair at every fight.)
M.asides = {
    { id = "fussed", when = { flag = "fussed" }, no_sneak = true,
      text = "Flitwidget's voice floats up from somewhere below: \"Everything all right up there? Anybody dead?\" So much for sneaking up on anything.",
      lines = { "Flitwidget's voice floats up from somewhere below: \"Everything all right up there? Anybody dead?\" So much for sneaking up on anything.",
                "From somewhere downstairs: \"Coo-ee! Just checking you're all alive!\" Whatever's in here heard that too.",
                "Flitwidget calls up the stairs to ask if anyone wants tea. Loudly. So much for the element of surprise." } },
    { id = "shoelace", when = { holds_here = "shoelace" }, owner = "jess",
      intro = "Pip has a new shoelace tonight, a present from Telpur's own boot. It talks. It hasn't stopped since the gift shop.",
      text = "Pip's talking shoelace, one of Telpur's, has advice for everyone. Nobody asked.",
      lines = { "Pip's talking shoelace, one of Telpur's, has advice for everyone. Nobody asked.",
                "Pip's shoelace pipes up with a battle plan. It's mostly about knots.",
                "The talking shoelace on Pip's boot tells everyone to stand up straight." } },
    { id = "telpur", when = { flag = "telpur_along" }, no_sneak = true,
      -- (Every line true in any room, her lair too, where she already sees them: the second playtest review. Not
      -- one lair line every week: round four's review heard the couch line two weeks running.)
      text = "Telpur, tied to a pack strap, has an opinion about everything in here, and shares every one of them. Out loud.",
      lines = { "Telpur, tied to a pack strap, has an opinion about everything in here, and shares every one of them. Out loud.",
                "Telpur, swinging from a pack strap, announces the party at the top of his voice. Nobody in here is caught napping now.",
                "Telpur hums a marching song from the pack strap. Loudly. Whatever's in here, it heard that.",
                "\"Go on, then! Show them!\" Telpur yells from his pack strap. Everything in the room turns to look." } },
}
-- An ally fighting beside them who didn't walk in with them: said as the fight starts, the first
-- time it's there tonight (companions.ally_arrives, museum_night.arm).
M.ally_join = {
    steam_mech = "{mech} clanks up the stairs behind them, steam hissing, and takes its place in the line.",
}
-- An ally that isn't a person, destroyed in a fight (companions.fell): gone for good, so said that way,
-- and its friend at the table reacts. {name}: what they called it. (Burning itself out has its own
-- words, the overheat moment: game/data/barks.lua told.)
M.ally_lines = {
    steam_mech = { down = { "{name} crashes down in a heap of brass and steam. The green light behind its helmet goes out.",
                            "{name} takes one hit too many and topples over, gears grinding to a stop.",
                            "Something inside {name} snaps. It sags, sparks, and goes still for good." },
                   react = { "{name}! No!", "Not {name}. Not like this.", "Get up, {name}. Please get up." } },
}
-- "Last time, they ..." at the start of a night: what each room came to, as a clause. fought: the
-- clause when the room's fight happened (its fight is optional: the second playtest review, F20, heard
-- "crossed the Hall of Paintings" after a fight with the Knight of Shades). alone: who went where,
-- when it wasn't the whole party ({char}: the hero whose moment it was).
M.recap = {
    street = { win = "took Flitwidget's job", lose = "took Flitwidget's job without the whole story" },
    garden = { win = "got through the living garden", lose = "got through the garden, scratched and bleeding" },
    entrance = { win = "got past the donation box and the metal statue", lose = "backed out of the entrance hall",
                 fought = { win = "fought their way past the Sentinel at the donation box", lose = "fled the Sentinel in the entrance hall" } },
    chamber = { win = "stilled the Bone Construct", lose = "barely got away from the Bone Construct",
                fought = { win = "smashed the Bone Construct", lose = "barely got away from the Bone Construct" } },
    paintings = { win = "crossed the Hall of Paintings", lose = "backed out of the Hall of Paintings",
                  fought = { win = "fought the Knight of Shades out of its frame in the Hall of Paintings",
                             lose = "backed out of the Hall of Paintings, the Knight of Shades after them" } },
    gift_shop = { win = "rested in the gift shop with Telpur", lose = "dozed through Telpur's rules in the gift shop" },
    hunting = { win = "beat the huntlings on the second floor", lose = "came off worst against the huntlings" },
    offices = { win = "found the archivist's notebook", lose = "left the offices with more questions than answers" },
    tomorrow = { win = "woke the Steam Mech", lose = "couldn't wake the Steam Mech",
                 since = { { when = { flag = "mech_burnt" }, win = "woke the Steam Mech, then burnt it out with its own red switch" } } },
    lecture = { win = "silenced the Lecturer", lose = "staggered out of the Lecturer's class",
                ran = "drove the Lecturer out of his own class" },
    stairs = { win = "climbed the stairs to Euryale's door", lose = "climbed the stairs to Euryale's door",
               alone = { moment = "mus_alone", options = { 1, 3 }, who = "jess",
                         text = "waited at the foot of the stairs while {char} crept up alone for a look" } },
    lair = { win = "faced Euryale", lose = "faced Euryale, and she sent them back down the stairs" },
}

-- The night as a chain (R14: game/model/events.lua, the session report and the journey recap): each
-- beat told as a short clause, joined to the beat it follows from with "so" or "but". rooms: walking
-- into a room, where "they went into ..." doesn't read. Then each moment's options, by their place on
-- the card: did (what was done), ok (when its roll worked), fail (what went wrong: a beat of its own,
-- "but"); false: not a beat (a call that changes nothing in the story). An option missing here is
-- told from its `want` ("set the bushes on fire": "they set the bushes on fire"). {char}: the hero.
M.beats = {
    -- The words for the night's own beats, wherever the code tells one ({room}, {char}, {what}, {who},
    -- {thing}, {n}, {want}, {pet}: filled in as it happens).
    words = {
        enter = "they went into {room}", hooked = "{enter}, the place {char} came for",
        back = "they went back to {room}", flee = "they fell back to {room}", rest = "they went back to {room} to rest",
        shop = "they went back to the gift shop with Francs to spend",
        look = "{char} had a look at {what}", tried = "{who} tried to {want}", didnt = "it didn't work",
        trap = "a trap went off: {what}",
        find = "{char} found a Flitwidget Franc", finds = "{char} found {n} Flitwidget Francs", pet_find = "{pet} found a Flitwidget Franc",
        pay = "Flitwidget's pay came through: a Franc", pays = "Flitwidget's pay came through: {n} Francs",
        price_up = "Telpur put his prices up a Franc", price_up_n = "Telpur put his prices up {n} Francs",
        price_down = "Telpur took a Franc off his prices for them",
        lecturer = "the Lecturer told Euryale about {what}", euryale = "Euryale knew what the Lecturer had told her",
        notice = "Flitwidget saw what was left of {thing}", told = "Telpur had a word with Flitwidget about {char}",
        -- (What Telpur told him, when it was a theft: "had a word about Pip" said nothing. Round three's merge.)
        told_got = "Telpur told Flitwidget that {char} had lifted {thing}",
        told_caught = "Telpur told Flitwidget that {char} had tried to lift {thing}",
        -- (By the reason he gave, with the figure he said: museum_night.thanks_word.)
        docked = "Flitwidget took {n} gold each off their reward", docked_break = "Flitwidget took {n} gold each off their reward",
        docked_draught = "Flitwidget took {n} gold each off their reward, for his healing draught",
        docked_caught = "Flitwidget took {n} gold each off their reward, for the hand in his waistcoat",
        docked_told = "Flitwidget took {n} gold each off their reward", docked_box = "Flitwidget took {n} gold each off their reward, for his donation box",
        lifted = "{char} lifted {thing}", lifted_off = "{char} lifted {thing} off {who}",
        caught = "{char} went for {thing}, and {who} caught {char_them} at it",
        spotted = "{who} spotted his own {thing} on {char}",
        helped = "{char} helped {who}", refused = "{who} wouldn't answer {char}",
        -- (The night's losses, told first: round three, A7. events.losses.)
        death = "{char} died in {room}", down = "{char} went down", down_n = "{char} went down {n}",
        ally_lost = "the party lost {name}", freed = "Euryale let {names} out of the stone", wipe = "the whole party went down in {room}",
        came_back = "{char} nearly died, and came back",
        friendly = "{char}'s {spell} caught {hit} too", friendly_down = "{char}'s own {spell} dropped {downed}",
    },
    -- (A beat that would only repeat the one it follows from, events.chain: the words in the clause before
    -- that mean it's been said, and what's new in it, if anything.)
    same = { ["Euryale slipped away"] = { words = { "got away", "let her go", "slipped" } },
             ["they struck a bargain with Euryale, and she left the museum"] = { words = { "deal", "bargain" }, rest = "she left the museum" },
             ["Euryale slept, and they carried her out"] = { words = { "asleep", "fell asleep" }, rest = "they carried her out" } },
    rooms = { stairs = "they started up the narrow stairs", lair = "they climbed up to Euryale's lair",
              street = "they met Flitwidget in the street" },
    mus_truth = { { did = "{char} pressed Flitwidget for the truth", ok = "{char} got the truth out of Flitwidget",
                    fail = "Flitwidget changed the subject to the gift shop" },
                  "Flitwidget told them about the Gorgon anyway" },
    mus_francs_intro = { false, false },
    mus_plaque = { "they doused the hedges with pond water", "they set the bushes on fire", "they went at the hedges with steel" },
    mus_pond = { { did = "{char} leaned over the dark pond", ok = "{char} fished a little brass key out of the pond",
                   fail = "a tentacle dragged {char} into the pond" }, false },
    -- (The lock: kneeling by it with the picks out, which is all they did when you reined them in. The
    -- confirming playtest: "Pip went for the donation box's lock" after she put the picks away.)
    mus_box = { "they dropped a coin in the donation box", "{char} knelt by the donation box with {char_their} picks out" },
    mus_box_lock = { { did = "{char} picked the lock with the guard right there", ok = "{char} emptied the donation box",
                       fail = "the pick snapped, and the Sentinel turned round" }, false },
    mus_tablet = { { did = "they tried to read the tablet", ok = "they read the tablet, and stilled the guardian with its old ritual",
                     fail = "the tablet wouldn't come clear in time, and it came to blades" }, "they skipped the tablet and fought the guardian" },
    mus_falcon = { "the falcon jar flung {char} across the room", false },
    mus_tidy = { "they tidied up for Flitwidget", "{char} kept the twin daggers", false },
    -- (What came out, by name: "pulled something out of a painting" said nothing, round three's merge.
    -- empty: the painting with nothing to give.)
    mus_reach = { { did = "{char} reached into a wet painting", ok = "{char} reached into a painting and pulled out {gift}",
                    empty = "{char} reached into a painting and came back with a question",
                    fail = "the painting bit {char}" }, false },
    mus_dice_painting = { false, false },
    mus_knight_frame = { "they took a closer look at the knight", "they gave the knight a wide berth" },
    mus_return_paint = { "{char} slid {gift} back into its painting", "they kept {gift} until it dripped away" },
    -- (The voice is the DM's, not a hero's: round three heard "Pip did Telpur's voice" after "[dm] The voice is terrible.")
    mus_telpur_bit = { "Telpur got his full voice, and the table cried laughing", false },
    mus_tracks = { "they followed the scratch marks, weapons out", "they went round and made the hunters come to them" },
    mus_mirror = { "{char} took one of the mirror-bright cupboard doors", "they left the exhibits alone" },
    mus_office_door = { "they tried the brass key from the pond on the office door",
                        { did = "they shouldered the office door", fail = "the door held, and opening it took a lot of noise" },
                        { did = "{char} picked the office lock", fail = "the pick snapped, and a shoulder did it in the end" } },
    mus_office_inside = { false, false },
    mus_whispers = { { did = "a voice whispered in the dark to {char}", ok = "{char} shook off the whispers",
                       fail = "something old learned {char}'s name" }, "a voice in the dark said {char}'s name" },
    mus_code = { { did = "{char} raced the clock for the Mech's code", ok = "{char} woke the Steam Mech",
                   fail = "the Mech's panel snapped shut" },
                 { did = "{char} worked at the Mech's code", ok = "{char} woke the Steam Mech",
                   fail = "the code changed, and the Mech stayed a statue" },
                 { did = "{char} raced the clock for the Mech's code", ok = "{char} woke the Steam Mech",
                   fail = "the Mech's panel snapped shut" } },
    mus_hyper = { { did = "they flipped the Mech's red switch", ok = "the Mech's red switch worked, once",
                    fail = "the Mech overheated and burnt out" }, "they saved the red switch for the Gorgon" },
    mus_earplugs = { "{char} blocked out the drone with candle wax", "the wax didn't keep the drone out of {char}'s head" },
    -- (Glimpsed, not met: no save was made and nobody turned to stone. The confirming playtest, 57 and 58 random.)
    mus_alone = { "{char} crept up the stairs alone", false, "{char} crept up alone and glimpsed Euryale from the top step" },
    mus_lair_frame = { { did = "{char} reached into the frame behind her couch", ok = "{char} pulled a painted blade out of the frame",
                         fail = "the frame bit {char}" }, "they forgot the frame and drew steel" },
    mus_drink = { { did = "{char} drank Euryale's wine", ok = "{char} drank Euryale's wine and kept a clear head",
                    fail = "the wine charmed {char}" }, "nobody drank Euryale's wine" },
    mus_ultimatum = { "they chose to fight Euryale",
                      { did = "they offered to find Euryale's sisters", ok = "they talked of Euryale's sisters, and she listened",
                        fail = "Euryale wouldn't hear about her sisters" },
                      { did = "they offered Euryale a cut of the donation box", ok = "Euryale took a cut of the donation box",
                        fail = "Euryale laughed at the offer of the donation box" },
                      { did = "they handed Euryale a page of the Lecturer's notes", ok = "Euryale read the Lecturer's notes and fell asleep",
                        fail = "Euryale had read the Lecturer's notes before" },
                      { did = "they asked Euryale what she really wanted", ok = "they talked Euryale round", fail = "Euryale wouldn't be talked round" } },
    mus_yield = { "they let her go", "they made her a deal: her sisters, for her help",
                  "they asked what she wanted, and made a deal for her sisters", "{char} finished it" },
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
    missed = "{names} {want} another look at {room}. {Names_they're} sure {names_they} missed something in there.",
    hint = "You let slip that {room} still has something in it.",
    passed = "{names} {want} to see {room}. The party walked right past it.",
    shop = "{names} {want} to nip back to the gift shop and spend some Francs.",
    rest = "Everyone's hurting. {names} {want} to fall back to the gift shop for a breather.",
}
M.order = { "street", "garden", "entrance", "chamber", "paintings", "gift_shop", "hunting", "offices", "tomorrow", "lecture", "stairs", "lair" }

-- A fork's question, by the rooms on offer.
M.forks = {
    wings = { text = "Two gold-and-mahogany signs: the Chamber of Ancients one way, the Hall of Paintings the other. The table splits.",
              title = "Which wing?" },
    second_wing = { text = "One wing done. The other is right there, and so is the gift shop at the foot of the stairs.", title = "The other wing?" },
    hub = { text = "Three doors off the hunting floor, each with a gold-and-mahogany sign: the offices, the World of Tomorrow, the lecture theatre. And a narrow stair going up. Everyone has an opinion.",
            title = "Where next?" },
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
    hunting = { text = "Three doors off the hunting floor, each with a gold-and-mahogany sign: the offices, the World of Tomorrow, the lecture theatre. And a narrow stair going up." },
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

-- The painting each hero gets if the DM hangs one for them (all from the book's gallery), and what
-- reaching in costs, as the book has it: the elf in the snow bites with cold, the warrior on the bridge
-- swings his blade, and the lady, the duellist and the throne let a hand in safely (safe: no roll).
-- hint: what the card shows of the danger; bite: the miss, hurt: its dice, skill: what dodges it.
M.portraits = {
    mara = { painting = "a lady by an icy mountain road, looking straight out at Thessaly", gift = "nothing to take, only a question she can't stop thinking about", empty = true,
             safe = true },
    dev = { painting = "a warrior in scarlet armour on a bridge, sword raised", gift = "the warrior's own blade, made of paint",
            hint = "The warrior's painted blade is raised right at the edge of the frame.",
            danger = "the warrior on the bridge: reach in and his blade cuts",
            bite = "The painted blade flicks out of the frame. {actor_char} snatches back a cut hand, empty.",
            hurt = { 1, 8 }, skill = { "acrobatics" }, aspect = "Got cut by a painted sword" },
    jess = { painting = "a smug duellist with a pistol in each hand", gift = "a painted pistol with one shot in it", safe = true },
    sam = { painting = "an empty golden throne with bats carved into it", gift = "a glass of something red that is definitely not wine", safe = true,
            not_weapon = true },
}
-- Anyone else's: the elf in the snowfield, whose cold bites.
M.portrait_default = { painting = "a white-haired elf in a snowfield, two curved swords at his sides", gift = "a painted scimitar",
                       hint = "Frost glitters on the frame.", danger = "the paintings: reach in and the cold bites",
                       bite = "The painting bites. {actor_char} pulls back an arm numb to the elbow, empty-handed.",
                       hurt = { 1, 4 }, aspect = "Got frostbite from a painting" }

-- Room moments: the calls each room puts to the DM on game night. at: "start" (before the room's
-- fight or checks), "mid" (between), "end" (after), "follow" (only after an option's then_moment).
-- Rooms play them in this order. party = true: a choice that's the players' to make, never the DM's
-- (the playtest, November 3): the table talks it over (museum_night.table_pick), each option's `want`
-- is how they say it, and the DM only nudges when they ask. roll.best: the best at the skill rolls.
M.moments = {
    -- The street ---------------------------------------------------------------------------------
    { id = "mus_truth", room = "street", at = "start", when = { knob = "pry", not_told = "gorgon" }, type = "story",
      actor = { "instigator", "method_actor", "storyteller" },
      title = "\"Incidents with the exhibits\"",
      -- (Said to the table as the card opens, before you decide: what the heroes heard him say, p6.)
      see = "Flitwidget keeps smiling, but every time someone says \"incidents\", his moustache twitches.",
      text = "{actor_char} doesn't buy the gnome's story for a second. 'Incidents' is doing a lot of work.",
      options = {
          { label = "Let them pry. Roll against his bluster.",
            roll = { dc = 12, skill = { "insight", "persuasion", "intimidation" }, convenient = "success",
                     success = { log = "He cracks. Her name is Euryale, a Gorgon he bought sealed in a clay jar. The jar broke, she's twisted his exhibits, and visitors who went in never came out. His assistant Telpur is still inside.",
                                 tells = { "gorgon", "euryale" },
                                 effects = { { "actor", spotlight = 10 }, { "arch:storyteller", story = 6, fun = 4 }, { "arch:instigator", fun = 5 } },
                                 mus = { flag = "truth", aspect = "Got the truth out of Flitwidget" } },
                     fail = { log = "He beams, waves his hat, and changes the subject to the gift shop. They're going in half blind.",
                              effects = { { "arch:storyteller", story = 3 }, { "arch:tactician", fun = -2 } } } } },
          { label = "He tells them anyway. Get them to the garden.",
            log = "Flitwidget drops his voice: a Gorgon called Euryale, a broken jar, and people who didn't come out. His assistant Telpur is still inside.",
            tells = { "gorgon", "euryale" },
            effects = { { "arch:casual", fun = 3 }, { "arch:tactician", fun = 2 }, { "arch:instigator", fun = -3 } },
            mus = { flag = "truth" } },
      } },
    { id = "mus_francs_intro", room = "street", at = "end", type = "story", actor = { "power_gamer", "instigator", "casual" },
      title = "Flitwidget Francs",
      see = "Flitwidget holds up a crisp green note with his own face on it. \"Deal with my exhibits, and these appear in your pockets. Spend them in the gift shop!\"",
      text = "Flitwidget holds up a crisp green note with his own face on it. 'Deal with my exhibits, and these appear in your pockets. Spend them in the gift shop!'",
      options = {
          { label = "Explain the Francs properly. Some players love a currency.",
            log = "One Franc per beaten exhibit, solved puzzle, or clever use of the museum's own things.",
            effects = { { "arch:power_gamer", fun = 5, reward = 4 }, { "arch:tactician", fun = 3 }, { "arch:storyteller", boredom = 3 } },
            table_min = 3 },
          { label = "Keep how they're earned a surprise. They'll find out.",
            log = "\"You'll see!\" says Flitwidget, and shoos them up the steps. \"There's a lot more of it than there looks, trust me!\"",
            effects = { { "arch:explorer", fun = 3 }, { "arch:storyteller", fun = 2 } } },
      } },

    -- The garden ----------------------------------------------------------------------------------
    { id = "mus_plaque", room = "garden", spot = "1A", at = "start", type = "story", actor = { "explorer", "instigator", "tactician", "storyteller" }, party = true,
      title = "A sign by the pond",
      text = "{actor_char} finds a little iron plaque by the pond: \"Please mind the bushes. In an emergency, use water.\" Signed FF.",
      options = {
          { label = "Use the water. Douse the hedges.", want = "douse the hedges with pond water", short = "use the water", lean = "safe",
            points = { "The sign says try the water. So, water.", "It's signed FF. Flitwidget says water, I say water.", "Water. The plaque literally says water." },
            -- (What happened before that bears on it, museum_night.carry: who it moves, by how much, and what they say.)
            pulls = { { when = { flag = "truth" }, who = { "tactician", "storyteller" }, n = 1.5,
                        say = { "Save our strength for the Gorgon.", "There's something worse than hedges in here. Let's not waste ourselves on them.",
                                "If Flitwidget's right about his Gorgon, we'll want our strength." } } },
            -- (The book, p9: anyone within 5 feet of the water draws the tentacles, a DC 10 Dexterity save or
            -- 1d4 slashing; each hedge the water hits rolls on the mutation table, museum_night's pond_water.)
            roll = { dc = 10, skill = { "dex" },
                     success = { log = "A helmet goes in at the water's edge, a tentacle slaps the surface, and {actor_char} jumps back just in time. Then helmets full of pond water hit the topiary.",
                                 effects = { { "actor", spotlight = 8 }, { "arch:explorer", fun = 4 }, { "arch:tactician", fun = 4 }, { "all", challenge = -2 } },
                                 mus = { francs = 1, flag = "water", pond_water = true, secret_event = "tentacles" } },
                     fail = { log = "A slimy tentacle lashes {actor_char}'s arm at the water's edge, but the helmet comes up full. Then helmets full of pond water hit the topiary.",
                              effects = { { "actor", spotlight = 8, challenge = 3 }, { "arch:explorer", fun = 3 }, { "arch:tactician", fun = 3 } },
                              mus = { francs = 1, flag = "water", pond_water = true, hurt = { 1, 4 }, risk = true, secret_event = "tentacles" } } } },
          { label = "They're bushes. Set them on fire.", want = "set the bushes on fire", short = "burn them", lean = "bold",
            -- (Once they know the hedges are alive: secrets.living_hedges. Living or not, hedges burn.)
            pulls = { { when = { hinted = "living_hedges" }, who = { "instigator", "butt_kicker", "power_gamer" }, n = 1.0,
                        say = { "If they're alive, they'll burn. Torch.", "Living hedges are still hedges. Fire.",
                                "Water's slow. Fire's not. They're bushes, whatever else they are." } } },
            log = "Oil, a torch, and a whoosh. Half the garden goes up like kindling, and the bush by the doors with it. Something in it squeals.",
            effects = { { "actor", spotlight = 6 }, { "arch:butt_kicker", fun = 3 }, { "arch:instigator", fun = 6 }, { "arch:storyteller", fun = 2 },
                        { "arch:casual", fun = 1.5 }, { "all", challenge = -4 } },
            mus = { drop = { "briar_boar" }, mark = "garden_burned" } },
          { label = "Just fight them. Steel, not water.", want = "just fight them", short = "fight them", lean = "bold",
            pulls = { { when = { flag = "truth" }, who = { "butt_kicker" }, n = 1, say = { "If there's a Gorgon in here, I want the practice.",
                        "Warm-up for the Gorgon. Come on.", "Hedges first, Gorgon later. Let's go." } } },
            log = "Blades out. The hedges come at them all at once.",
            effects = { { "arch:butt_kicker", fun = 4 }, { "all", challenge = 6 } } },
      } },
    { id = "mus_pond", room = "garden", danger = "the pond: something with tentacles lives in it", spot = "pond", at = "end", type = "story", actor = { "instigator", "explorer" },
      title = "The dark pond",
      see = "{actor_char} leans right over the pond for a closer look. A grey tentacle slides up through the lilies, tastes the air, and sinks back down.",
      -- (The player says what their hero does; the DM says what happens. Conner's playtest, C20.)
      text = "{actor}: \"{actor_char} leans right over the pond for a closer look.\" A grey tentacle slides up through the lilies, tastes the air, and sinks back down. Everyone saw it.",
      options = {
          { label = "Let them. They know what's in there.",
            roll = { dc = 10, skill = { "acrobatics", "athletics" }, convenient = "success",
                     success = { log = "{actor_char} dodges a tentacle and fishes out a little brass key. Nobody knows what it opens. Yet.",
                                 effects = { { "actor", spotlight = 8, fun = 5 } }, mus = { risk = true, francs = 1, flag = "brass_key", aspect = "Fished a brass key out of a haunted pond", secret_event = "tentacles" } },
                     fail = { log = "A tentacle wraps {actor_char}'s ankle and drags {actor_them} in up to the waist. {Actor_they} comes out cut and dripping.",
                              effects = { { "actor", spotlight = 6, challenge = 4 } }, mus = { risk = true, harsh = true, hurt = { 1, 6 }, drag = { "pond", "pond" }, aspect = "Was dragged into a haunted pond", secret_event = "tentacles" } } } },
          { label = "\"Are you sure? It's got tentacles.\"",
            log = "\"Nope,\" {actor} says. {actor_char} backs away from the water. The pond burbles, disappointed.",
            effects = { { "arch:instigator", fun = -2 }, { "arch:casual", fun = 2 } }, mus = { warn = true } },
      } },

    -- The entrance hall -------------------------------------------------------------------------
    { id = "mus_box", room = "entrance", spot = "2B", at = "start", type = "story", actor = { "casual", "instigator", "method_actor" }, party = true,
      title = "The donation box",
      text = "A glass case of coins from every world, and a little card: \"Every coin keeps the lamps lit.\" {actor_char} looks at the case, and then at its lock.",
      options = {
          { label = "Somebody drops a coin in.", want = "drop a coin in", short = "pay a coin",
            pulls = { { when = { mark = "garden_burned" }, who = { "tactician", "casual", "storyteller" }, n = 1.5,
                        say = { "We've already burnt his garden. Let's not rob him as well.", "We set fire to his garden. The least we can do is chip in.",
                                "After the garden? A coin. It's only polite." } },
                      { when = { event = { kind = "steal", who = "jess", outcome = "caught" } }, who = "jess", n = 3,
                        say = { "Pip got caught once already. Fine. A coin.", "Pip's on her best behaviour. For now. Coin.", "I've been caught once today. Coin it is." } },
                      -- (What they found out about the statue: secrets.sentinel_wakes. Only the whole of it, not a hint.)
                      { when = { told = "sentinel_wakes" }, who = { "tactician", "casual" }, n = 1.0,
                        say = { "That statue's watching the case. A coin, and nobody gets punched.", "We know what the statue's for. Coin.",
                                "I'm not picking a lock in front of that thing. Coin." } } },
            log = "A coin clinks in, and the statue booms: \"YOUR GENEROSITY IS NOTED.\" Something warm settles over {actor_char}.",
            effects = { { "arch:casual", fun = 4 }, { "arch:storyteller", fun = 3 }, { "arch:tactician", fun = 2 }, { "arch:power_gamer", fun = 1.5 },
                        { "all", reward = 2 } },
            mus = { francs = 1, flag = "boon", inspire = "The museum thanks {char} for the donation.", careful = 1, favor = { who = "flitwidget", n = 1 } } },
          { label = "{actor_char} tries the lock.", want = "have a go at the lock", short = "try the lock", then_moment = "mus_box_lock", best = { "sleight_of_hand" },
            pulls = { { when = { mark = "garden_burned" }, who = { "instigator", "butt_kicker" }, n = 1,
                        say = { "We've already burnt his garden. In for a penny.", "He's going to be cross about the garden anyway.",
                                "After the garden, what's a little lock?" } },
                      -- (Nobody's found out what the statue does: it's just a statue, to them.)
                      { when = { not_hinted = "sentinel_wakes" }, who = { "instigator", "power_gamer", "explorer" }, n = 1.7,
                        say = { "It's a statue. Statues don't do anything.", "Nobody's guarding it but a lump of metal.",
                                "One little lock. The statue won't mind." } } },
            log = "{actor_char} cracks {actor_their} knuckles and kneels by the case.",
            effects = { { "actor", spotlight = 6 }, { "arch:instigator", fun = 5 }, { "arch:method_actor", fun = 2 }, { "arch:power_gamer", fun = 2 } } },
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
            log = "You give {actor_char} a look over the screen. \"Fine. Not this one,\" {actor} says. {actor_char} puts the picks away.",
            effects = { { "actor", fun = -6, trust = -1 }, { "others", fun = 2 } } },
      } },

    -- The Chamber of Ancients ------------------------------------------------------------------
    { id = "mus_tablet", room = "chamber", spot = "3E", at = "start", type = "story", actor = { "storyteller", "tactician", "explorer" }, party = true,
      title = "The cracked tablet",
      text = "The cracked tablet, the little notebook of glyphs beside it, and the guardian lifting its staff.",
      options = {
          { label = "Read the tablet. Someone holds it off.", want = "read the tablet while someone holds the guardian off", short = "read the tablet", lean = "safe",
            effort = true,      -- (careful, but not the easy way: museum_night.carry)
            points = { "The notebook's right here. Let's use it.", "Give me a minute with these glyphs. I can do this.", "It's all in the notebook. Somebody hold it off." },
            pulls = { { when = { flag = "water" }, who = { "tactician", "storyteller", "casual" }, n = 0.5,
                        say = { "The water trick worked in the garden. Let's do this one properly too.", "The sign was right about the hedges. The notebook might be right too.",
                                "Doing it by the book worked in the garden. Let's do it again." } },
                      -- (A table that knows what's waiting upstairs would rather not spend itself here: R10, the
                      -- friends fought it 69% of the time.)
                      { when = { flag = "truth" }, who = { "tactician", "storyteller", "casual" }, n = 0.9,
                        say = { "Save the swords for the Gorgon.", "There's a Gorgon in here somewhere. Let's not bleed for this one.",
                                "If we can talk to it in glyphs, that's a fight we don't have to have." } } },
            -- (A line at a time, as the book has it, p12: museum_night.ritual_read. The second round's review: one
            -- roll gave up the whole ritual, and the DM's own solution with it.)
            log = "{actor_char} opens the notebook beside the tablet and starts on the first line.",
            mus = { ritual_read = {
                success = { effects = { { "actor", spotlight = 14 }, { "arch:storyteller", fun = 3.5, story = 6 }, { "arch:tactician", fun = 3.5 }, { "arch:butt_kicker", fun = -3 } },
                            mus = { no_fight = true, mark = "calmed", francs = 1, careful = 1, aspect = "Calmed a tomb guardian with an old ritual" } },
                fail = { effects = { { "arch:butt_kicker", fun = 3 } }, mus = { fight = true, flag = "ritual_failed" } } } } },
          { label = "Skip the homework. Fight it.", want = "skip the homework and fight it", short = "just fight it", lean = "bold",
            pulls = { { when = { chose = { "mus_plaque", 3 } }, who = { "butt_kicker", "instigator" }, n = 1,
                        say = { "Steel worked on the hedges. It'll work on this.", "We hit the hedges and the hedges stopped. Same again.",
                                "It worked in the garden. Weapons out." } } },
            log = "Nobody needs a tablet to hit things. Weapons out.",
            effects = { { "arch:butt_kicker", fun = 5 }, { "arch:instigator", fun = 4 }, { "arch:casual", fun = 3.5 }, { "arch:storyteller", fun = -2 } },
            mus = { fight = true } },
      } },
    -- (The player's idea, once they've read some of the tablet and not enough: never the DM moving a hero. The third
    -- round's review: "Oswin grabs the half-full falcon jar" that nobody had filled, and nobody had proposed.)
    { id = "mus_falcon", room = "chamber", danger = "the falcon jar: the tablet's last lines say what happens to anyone who gets it wrong", spot = "3A", at = "mid", when = { flag = "ritual_failed", hinted = "ritual" }, type = "screen", actor = { "instigator", "storyteller", "power_gamer" },
      title = "A discontented falcon",
      see = "{actor}: \"We've got some of the tablet. {actor_char} fills the falcon jar from the crocodile's tap as best {actor_they} can and runs it to the pedestal.\"",
      text = "{actor}: \"{actor_char} fills the falcon jar as best {actor_they} can and runs it to the pedestal.\" They never read the tablet's warning. You know what it says.",
      -- (The tablet's warning, if it came clear: then they were told.)
      text_if = { { when = { part = { "ritual", 7 } }, text = "{actor}: \"{actor_char} fills the falcon jar as best {actor_they} can and runs it to the pedestal.\" The tablet's last line warned them what a discontented falcon costs." } },
      options = {
          { label = "Let them. They never read the warning.", sub = "Harsh, and out of nowhere for them.",
            log = "The pedestal flares. {actor_char} is flung across the room and lands hard, winded.",
            effects = { { "actor", spotlight = 10, challenge = 8 }, { "arch:butt_kicker", fun = 3 } },
            mus = { harsh = true, hurt = { 2, 6 }, aspect = "Was flung across a tomb by an unhappy goddess" } },
          { label = "\"Are you sure? Try the last line again.\"",
            log = "{actor_char} puts the jar down and reads the last line again. It's a warning, and not a friendly one.",
            effects = { { "actor", fun = -2 }, { "arch:casual", fun = 2 } }, mus = { warn = true } },
      } },
    { id = "mus_tidy", room = "chamber", at = "end", type = "story", actor = { "casual", "tactician", "instigator" }, party = true,
      title = "Put it all back?",
      text = "The chamber's a mess: jars, daggers, the tablet and the little notebook, scattered across the sand.",
      options = {
          { label = "Tidy up. Flitwidget will notice.", want = "tidy up for Flitwidget", short = "tidy up",
            log = "Everything goes back on its plinth. A Franc materialises in {actor_char}'s pocket.",
            effects = { { "arch:casual", fun = 4 }, { "arch:storyteller", fun = 3 }, { "arch:butt_kicker", boredom = 4 } },
            mus = { francs = 1, careful = 1, favor = { who = "flitwidget", n = 1 } } },
          { label = "{actor_char} pockets the twin daggers.", want = "keep the twin daggers", short = "take the daggers", lean = "none",
            log = "Two curved daggers, rings locked together through the hilts. They're not coming apart, but they're coming along.",
            effects = { { "actor", fun = 4, reward = 4 }, { "arch:method_actor", fun = 3 }, { "arch:power_gamer", fun = 4 }, { "arch:storyteller", fun = -1 } },
            mus = { flag = "daggers", aspect = "Kept two daggers that won't come apart" } },
          { label = "Leave it. Onward.", want = "leave the mess and move on", short = "leave it", lean = "safe",
            log = "They step over the mess and keep moving.", effects = { { "arch:butt_kicker", fun = 3 }, { "arch:tactician", fun = 2 } } },
      } },

    -- The Hall of Paintings --------------------------------------------------------------------
    { id = "mus_reach", room = "paintings", danger = "the paintings: reach in and the cold bites", at = "start", type = "story", actor = { "explorer", "instigator", "method_actor" },
      title = "The paint is wet",
      text = "{actor_char} leans close to {painting}. The paint is wet.{reach_hint} A hand would go right in.",
      options = {
          { label = "Let them reach in, and roll for it.",
            roll = { dc = 12, skill = { "athletics", "acrobatics", "arcana" }, convenient = "success",
                     success = { log = "{actor_char} pulls out {gift}, still wet. It'll last about an hour out here.",
                                 effects = { { "actor", spotlight = 12, fun = 6, reward = 6 }, { "arch:explorer", fun = 4 } },
                                 mus = { risk = true, flag = "paint", francs = 1, aspect = "Pulled a weapon out of a painting" },
                                 -- (A painting with nothing to give, as in the book: no weapon, and no paint to drip later.)
                                 empty = { log = "{actor_char} reaches in to the elbow. Nothing to take: the lady in the painting only looks back, and leaves {actor_char} with a question that won't go away.",
                                           effects = { { "actor", spotlight = 10, fun = 5, story = 4 }, { "arch:explorer", fun = 4 } },
                                           mus = { risk = true, francs = 1, aspect = "Reached into a painting and came back with a question" } } },
                     fail = { log = "The painting bites. {actor_char}'s arm comes back numb to the elbow, empty-handed.",
                              effects = { { "actor", spotlight = 6, challenge = 5 } }, mus = { risk = true, harsh = true, hurt = { 1, 4 }, aspect = "Got frostbite from a painting" } } } },
          { label = "\"Better not touch the paintings.\"",
            log = "{actor_char} keeps {actor_their} hands in {actor_their} pockets. The painted figure looks almost disappointed.",
            effects = { { "arch:explorer", fun = -2 }, { "arch:casual", fun = 2 } }, mus = { warn = true } },
      } },
    { id = "mus_dice_painting", room = "paintings", spot = "4C", at = "mid", when = { knob = "dice" }, type = "table", actor = { "method_actor", "instigator", "casual" },
      title = "Five people and some dice",
      see = "A small painting: five people round a table, rolling dice, one of them behind a little screen. {actor_char} spots it first: the people in it look familiar.",
      text = "A small painting: five people round a table, rolling dice. One sits behind a little screen. {actor_char} stops dead. The people in it look familiar.",
      options = {
          { label = "Lean in. The painted DM gives them a little wave.",
            log = "Somebody at the real table actually screams. Then everybody laughs.",
            effects = { { "arch:method_actor", fun = 7 }, { "arch:casual", fun = 5 }, { "arch:storyteller", fun = -2 }, { "all", social = 6 } },
            table_min = 2 },
          { label = "It's just a painting. Move on.",
            log = "\"Weird,\" {actor} says. {actor_char} moves on. In the painting, the little painted DM watches them go.",
            effects = { { "arch:storyteller", fun = 2 } } },
      } },
    -- (Not "{actor_char} wants a closer look": whoever found it had to say so, on 3 HP and all. The
    -- confirming playtest, alive 1: Dev "closer look" 24 runs of 24. Who wants what is the table's.)
    { id = "mus_knight_frame", room = "paintings", spot = "4K", at = "mid", type = "story", actor = { "explorer", "butt_kicker", "instigator" }, party = true,
      title = "The Knight of Shades",
      text = "At the end of the hall, the black knight's portrait, grim and perfect. {actor_char} stops in front of it.",
      options = {
          { label = "Take a closer look. Whatever happens, happens.", want = "take a closer look at the knight", short = "look closer",
            -- (Only once they've a hint what hurts it: secrets.knight_weak. The second round's review. Before that,
            -- it's just a picture worth a closer look.)
            pulls = { { when = { flag = "paint", hinted = "knight_weak" }, who = { "butt_kicker", "explorer", "instigator" }, n = 1.5,
                        say = { "We've got painted weapons. Let's see what they do to it.", "Wet paint in our hands, a painted knight over there. Come on.",
                                "That's what the painted weapons are for, surely." } },
                      { when = { not_hinted = "knight_weak" }, who = { "explorer", "instigator", "storyteller" }, n = 1.0,
                        say = { "It's the best painting in here. I want a proper look.", "Everything else in this hall has something in it. Why not that one?",
                                "Look at the brushwork on that knight. Closer." } } },
            log = "The knight grips the edge of its frame and climbs out, oil streaming off its armour.",
            effects = { { "arch:butt_kicker", fun = 4 }, { "arch:explorer", fun = 4 }, { "arch:instigator", fun = 2 }, { "all", challenge = 4 } },
            mus = { fight = true, aspect = "Woke the Knight of Shades" } },
          { label = "Give it a wide berth.", want = "give the knight a wide berth", short = "leave it be",
            log = "Nobody goes near it. They leave the black knight on the wall, and walk on.",
            effects = { { "arch:casual", fun = 3 }, { "arch:tactician", fun = 4 }, { "arch:storyteller", fun = 5 }, { "arch:method_actor", fun = 2.5 },
                        { "arch:butt_kicker", fun = -3 } },
            mus = { no_fight = true, mark = "knight" } },
      } },
    -- (owner: the one who pulled it out of the painting has it, and it's theirs to put back.)
    { id = "mus_return_paint", room = "paintings", at = "end", when = { flag = "paint" }, type = "story", actor = { "method_actor", "casual", "tactician" }, party = true,
      owner = "mus_reach",
      title = "Put the paint back?",
      text = "The paint is running. {actor_char} is still holding {gift_the} from the painting, and it's starting to drip. {Actor_they} could slide it back into its frame before it melts.",
      options = {
          { label = "Put it back. It feels polite.", want = "put it back", short = "put it back",
            points = { "It's dripping. Back it goes, before it's a puddle.", "It has a frame waiting. It's only polite.", "Look, it's melting. Let's put it home." },
            log = "It slides home without a sound. A Franc appears in {actor_char}'s pocket, and the painted figure in the frame nods.",
            effects = { { "arch:casual", fun = 3 }, { "arch:storyteller", fun = 3 } }, mus = { francs = 1, careful = 1, favor = { who = "flitwidget", n = 1 } } },
          { label = "Keep it till it drips away.", want = "keep it till it drips away", short = "keep it", lean = "bold",
            log = "It stays in hand, dripping, until it's nothing but a puddle and a damp sleeve.",
            effects = { { "arch:power_gamer", fun = 4 }, { "arch:instigator", fun = 4 }, { "arch:method_actor", fun = 2 } } },
      } },

    -- The gift shop ---------------------------------------------------------------------------
    { id = "mus_telpur_bit", room = "gift_shop", at = "start", when = { knob = "comedy" }, type = "table", actor = { "method_actor", "instigator", "casual" },
      title = "Telpur, Duke of Somewhere",
      see = true,       -- (his claim, said to the table: p17)
      text = "Telpur clears his throat, which is hard for a boot. \"Once I was a great lord of the underworld. Now I do the till. No refunds.\"",
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
      text = "The party pools its Flitwidget Francs on the counter: {francs} of them. Telpur waits, laces twitching, by the price tags: {stock}.",
      shop = true,
      options = {
          -- (Their prices: PRICE, at the top of this file.)
          { label = priced("A scholar's book on a poison cult", PRICE.tenets), price = PRICE.tenets, want = "buy the scholar's book", short = "get the book",
            log = "The Tenets of the Rotting Temple. {actor_char} starts reading before {actor_they've} left the shop.",
            effects = { { "arch:storyteller", fun = 6, story = 5 }, { "arch:butt_kicker", fun = -1 } },
            mus = { mark = "know", spend = PRICE.tenets, favor = { who = "telpur", n = 1 } } },
          { label = priced("The Mech Instruction Manual", PRICE.manual), price = PRICE.manual, want = "buy the Mech manual", short = "get the manual",
            log = "A thick manual with a lot of diagrams. Chapter nine: what the red switch does, and how to survive it.",
            effects = { { "arch:tactician", fun = 6 }, { "arch:power_gamer", fun = 4 } },
            mus = { flag = "manual", spend = PRICE.manual, favor = { who = "telpur", n = 1 } } },
          -- (Not while the quiver Pip lifted off this shelf is still in a pack: he doesn't sell it twice.)
          -- (The book's way to name the hunters upstairs, p17, p20: secrets.kruthik's read path.)
          { label = priced("A guide to primeval creatures", PRICE.guide), price = PRICE.guide, want = "buy the guide to primeval creatures", short = "get the guide",
            log = "The Neverwinter University Press Guide to Primeval Creatures. A lot of pictures of things with too many legs.",
            effects = { { "arch:explorer", fun = 5 }, { "arch:tactician", fun = 3 }, { "arch:butt_kicker", fun = -1 } },
            mus = { flag = "guide", spend = PRICE.guide, favor = { who = "telpur", n = 1 } } },
          { label = priced("Fire arrows and a bucket of slime", PRICE.arrows), price = PRICE.arrows, want = "buy the fire arrows and the slime", short = "get the arrows",
            unless = { holds = "arrows_lifted" },
            log = "Arrows that burn and slime that bites, enough for one good fight. Telpur bundles them up for {actor_char}, slime and all.",
            effects = { { "arch:butt_kicker", fun = 6 }, { "arch:power_gamer", fun = 4 } },
            mus = { flag = "arrows", spend = PRICE.arrows, favor = { who = "telpur", n = 1 } } },
          { label = "The vorpal sword (40 Francs)", price = 40, needs = { flag = "vorpal_price" }, want = "buy the vorpal sword",
            log = "Forty Francs, counted twice. Telpur wraps it in brown paper. It's very, very sharp.",
            effects = { { "actor", fun = 10, reward = 10 }, { "arch:power_gamer", fun = 6 } },
            mus = { flag = "vorpal_sword", spend = 40, favor = { who = "telpur", n = 1 } } },
          { label = "Save the Francs for later.", want = "save the Francs for later", short = "keep our Francs",
            log = "They keep their Francs. Telpur is personally offended.",
            effects = { { "arch:tactician", fun = 1 }, { "arch:power_gamer", fun = -2 } } },
      } },

    -- The Hunting Grounds ---------------------------------------------------------------------
    { id = "mus_tracks", room = "hunting", spot = "6I", at = "start", when = { knob = "marks" }, type = "story", actor = { "tactician", "explorer", "butt_kicker" }, party = true,
      title = "Scratch marks",
      text = "Fresh scratch marks lead across the floor to the cave model. \"That trail is very easy to follow,\" {actor} says.",
      see = "Fresh scratch marks lead across the floor to the cave model. \"That trail is very easy to follow,\" {actor} says.",
      options = {
          { label = "Follow them anyway, weapons out.", want = "follow the marks anyway, weapons out", short = "follow the trail",
            log = "They follow the trail with weapons out. The huntlings spring the trap, and the party was ready for it.",
            effects = { { "arch:butt_kicker", fun = 3 }, { "arch:storyteller", fun = 1 }, { "all", challenge = 4 } },
            mus = { risk = true, ready = true } },
          { label = "Go round. Make the hunters come to them.", want = "go round and make whatever left them come to us", short = "go round", lean = "safe",
            log = "They put their backs to the bulette's skull and wait. Whatever's hunting them can come out first.",
            effects = { { "arch:tactician", fun = 5 }, { "arch:casual", fun = 2 }, { "arch:explorer", fun = 3.5 }, { "arch:butt_kicker", fun = -1 } },
            mus = { flag = "no_surprise", ready = true } },
          -- (The book's own way to see the pack, p20: the kitchen's cupboard doors are polished to a shine,
          -- and the characters can use them to spot the hunters. A fresh-eyes playtest: nobody ever did.)
          { label = "Check the kitchen's polished doors first.", want = "use the shiny cupboard doors in the kitchen to see what's watching us", short = "check the doors", lean = "safe",
            when = { not_told = "pack_hides" },
            roll = { dc = 13, skill = { "perception", "investigation" },
                     success = { log = "Angled just right, the polished doors show the whole floor. Two shapes keep very still in the jungle, and a third stands frozen behind the big bird, playing statue.",
                                 tells = { "pack_hides" }, tells_how = "check",
                                 effects = { { "actor", spotlight = 6, fun = 3 }, { "arch:tactician", fun = 4 }, { "arch:explorer", fun = 3 } },
                                 mus = { flag = "no_surprise", ready = true } },
                     fail = { log = "The doors show a blur of leaves and feathers. Something in the blur moves, and then the hunters move first.",
                              effects = { { "actor", challenge = 4 }, { "arch:butt_kicker", fun = 2 } }, mus = { risk = true } } },
            effects = { { "arch:tactician", fun = 3 }, { "arch:explorer", fun = 3 } } },
      } },
    { id = "mus_mirror", room = "hunting", spot = "6J", at = "end", type = "story", actor = { "tactician", "explorer", "storyteller" }, party = true,
      title = "Polished doors",
      text = "In the kitchen diorama, the cupboard doors are polished to a mirror shine. {actor_char} could prise one off.",
      options = {
          { label = "Take one. You never know.", want = "take one of the mirror-bright doors", short = "take a door", lean = "none",
            points = { "A mirror you can carry. That has to come in handy.", "Look at the shine on that. We're taking one.", "Mirrors are always useful in stories. Always." },
            -- (Once they know there's a gorgon: every story about one has a mirror in it. The scholar's book doesn't
            -- say so, p17; her reflection is the DM's, p35. The second round's review.)
            pulls = { { when = { told = "gorgon" }, who = { "tactician", "explorer", "storyteller" }, n = 1.2,
                        say = { "Gorgons and mirrors. That's the oldest story there is. We're taking one.", "If she's a gorgon, a mirror's the first thing I'd want.",
                                "Every story about gorgons has a mirror in it. Take the door." } } },
            log = "{actor_char} unscrews a cupboard door and straps it to {actor_their} pack.",
            effects = { { "actor", spotlight = 6 }, { "arch:tactician", fun = 3 }, { "arch:explorer", fun = 3 }, { "arch:power_gamer", fun = 3 } },
            mus = { mark = "mirror", aspect = "Carried a cupboard door upstairs to fight a Gorgon" } },
          { label = "Leave the exhibits alone.", want = "leave the exhibits alone", short = "leave them be",
            log = "They leave the kitchen as they found it.", effects = { { "arch:casual", fun = 4.5 }, { "arch:storyteller", fun = 3 }, { "arch:method_actor", fun = 1 } }, mus = { careful = 1 } },
      } },

    -- The offices -----------------------------------------------------------------------------
    -- The locked door comes first: nobody reacts to what's inside before they're in.
    { id = "mus_office_door", room = "offices", spot = "door", at = "start", type = "story", actor = { "butt_kicker", "instigator", "tactician" }, party = true,
      title = "Locked from the inside",
      text = "The second study's door is locked from the inside. {actor_char} looks at the lock, then at the door.",
      options = {
          { label = "The little brass key from the pond.", needs = { flag = "brass_key" }, want = "try the brass key from the pond", short = "try the key", lean = "safe",
            uses = "brass_key", uses_name = "the key from the pond",
            log = "It turns first time: somebody's spare, thrown in the pond. Whoever locked this door didn't want anyone else coming in.",
            effects = { { "actor", spotlight = 8, fun = 4 }, { "arch:explorer", fun = 4 }, { "arch:storyteller", story = 3 } },
            mus = { flag = "door_open" } },
          { label = "Shoulder it open.", want = "shoulder it open", short = "shoulder it",
            roll = { dc = 12, skill = { "athletics" }, convenient = "success", best = true,
                     success = { log = "The door bursts open on the second shove.", effects = { { "actor", spotlight = 6 }, { "arch:butt_kicker", fun = 4 } },
                                 mus = { flag = "door_open" } },
                     fail = { log = "The door holds; the shoulder doesn't. It takes the whole party, and a lot of noise.",
                              effects = { { "actor", challenge = 3 }, { "arch:tactician", fun = -1 } }, mus = { flag = "door_open" } } } },
          { label = "Pick the lock, quietly.", want = "pick the lock, quietly", short = "pick it quietly", lean = "safe",
            roll = { dc = 13, skill = { "sleight_of_hand" }, convenient = "success", best = true,
                     success = { log = "{actor_char} pushes the key out onto a sheet of paper and pulls it under the door. Click.",
                                 effects = { { "actor", spotlight = 10, fun = 5 } }, mus = { flag = "door_open" } },
                     fail = { log = "The pick snaps. In the end, somebody's shoulder does it anyway.",
                              effects = { { "actor", fun = -2 } }, mus = { flag = "door_open" } } } },
      } },
    { id = "mus_office_inside", room = "offices", spot = "7B", at = "start", when = { flag = "door_open" }, type = "story", actor = { "storyteller", "explorer", "tactician" },
      title = "The second study",
      see = true,       -- (the book's read-aloud, p21: said to the table, the gentle way if gore is a line)
      -- (The bird is in the other study, 7A, as in the book: this room is the dark one, papered in eyes.)
      -- (A withered body, as the book's read-aloud has it: who he was, and the eyes he carved, are for a closer
      -- look, p21. The second round's review: "the archivist" named on walking in.)
      text = "Inside, it's darker than it should be. The withered body of a man sits at an ancient desk, a notebook open by his hand. Every wall is papered with diagrams and scraps, and on almost every one, a glowing eye.",
      -- (A table that veiled gore at Session Zero hears it gently.)
      -- (A line under gore: nothing gruesome, not even hinted. A veil: it's there, off screen.)
      -- (He, in every version, as the rest of the room has him: "the last page he wrote". Round four's review
      -- heard "they" then "he".)
      text_if = { { when = { line = "gore" }, text = "Inside, it's darker than it should be. A man is slumped at an ancient desk as if he fell asleep there and never woke, a notebook open by his hand. Every wall is papered with diagrams and scraps, and on almost every one, a glowing eye." },
                  { when = { soft = "gore" }, text = "Inside, it's darker than it should be. A man's body sits at an ancient desk, his sleeves pulled down over his arms, a notebook open by his hand. Every wall is papered with diagrams and scraps, and on almost every one, a glowing eye." } },
      options = {
          { label = "Let them take it all in, slowly.",
            log = "Nobody speaks for a moment. {actor_char} takes out a pencil.",
            effects = { { "arch:storyteller", fun = 4, story = 4 }, { "arch:explorer", fun = 3 }, { "arch:butt_kicker", boredom = 3 } }, table_min = 3 },
          { label = "Keep it brisk. The notebook, and out.",
            log = "\"Grab the notebook. Touch nothing else.\" Fair.",
            effects = { { "arch:butt_kicker", fun = 2 }, { "arch:storyteller", fun = -2 } } },
      } },
    { id = "mus_whispers", room = "offices", spot = "7B", at = "mid", when = { knob = "witness" }, type = "screen", actor = { "casual", "explorer", "storyteller" },
      title = "Whispers",
      text = "{actor_char} bends over the archivist's body. A faint voice starts whispering, to {actor_them} alone.",
      options = {
          { label = "Roll for it, behind the screen.",
            roll = { dc = 13, skill = { "insight", "religion" }, secret = true, convenient = "success",
                     success = { log = "{actor_char} shakes it off. Just the wind. Probably.", effects = { { "actor", fun = 2 } } },
                     -- (Behind your screen: only that hero heard it, p21. The table hears nothing. The second round's
                     -- review: "You write it down for later" was said out loud.)
                     fail = { log = "You slide a folded note to {actor}: a voice in the dark says {actor_char}'s name, once. Behind your screen, you write it down.",
                              effects = { { "actor", story = 8, fun = 4 }, { "arch:storyteller", investment = 2 } },
                              mus = { flag = "whispered", aspect = "Named in a whisper by the Witness", secret_event = "whisper" } } } },
          { label = "Pass them a note: they hear it, and only they know.",
            log = "You slide a folded note across the table. It says: \"A voice in the dark says your name, once, the way an old friend would.\" {actor} reads it twice, folds it small, and puts it away.",
            effects = { { "actor", story = 10, fun = 6 }, { "arch:storyteller", investment = 3 }, { "arch:casual", fun = -1 } },
            mus = { flag = "whispered", aspect = "Named in a whisper by the Witness", secret_event = "whisper" } },
      } },

    -- The World of Tomorrow -------------------------------------------------------------------
    -- (Two ways to go whatever you prepped: the clock you planned, or the one you didn't. The second
    -- playtest review: with the timer prepped, the card had one option.)
    { id = "mus_code", room = "tomorrow", spot = "8A", at = "start", type = "puzzle", actor = { "tactician", "power_gamer", "storyteller" },
      title = "The code in its chest",
      see = "A panel in the machine's chest slides open on a string of numbers, in pairs. It won't stay open long.",
      text = "A panel in the machine's chest slides open on a string of numbers. Grid references. It won't stay open long.",
      options = {
          { label = "Thirty real seconds. Go.", when = { knob = "timer" },
            roll = { dc = 13, skill = { "investigation", "arcana" }, convenient = "success",
                     success = { log = "{actor_char} shouts the word. Two seconds to spare: \"Activation accepted. My name is {mech}.\" The table erupts.",
                                 effects = { { "actor", spotlight = 16, fun = 8 }, { "arch:butt_kicker", fun = 5 }, { "arch:casual", fun = -3 } },
                                 mus = { mark = "mech", francs = 2, resolve = "win", aspect = "Woke the Steam Mech with two seconds to spare" } },
                     fail = { log = "Time. The panel snaps shut, and Sam lets out a breath he's been holding for thirty seconds.",
                              effects = { { "arch:casual", fun = -4 }, { "arch:instigator", fun = 3 } }, mus = { resolve = "lose" } } } },
          { label = "Give them the time they need.", sub = "No clock: they take their time.",
            roll = { dc = 12, skill = { "investigation", "arcana" }, convenient = "success",
                     success = { log = "{actor_char} reads the grid and says the word. Steam hisses. \"Activation accepted. My name is {mech}.\"",
                                 effects = { { "actor", spotlight = 12 }, { "arch:tactician", fun = 6 }, { "arch:power_gamer", fun = 6 } },
                                 mus = { mark = "mech", francs = 1, resolve = "win", aspect = "Woke the Steam Mech and commands it" } },
                     fail = { log = "The panel snaps shut. The code changes. The machine stays a statue.",
                              effects = { { "arch:power_gamer", fun = -4 } }, mus = { resolve = "lose" } } } },
          { label = "Put thirty real seconds on the clock.", sub = "You hadn't planned a timer. It's tense; it's harder.", unless = { knob = "timer" },
            roll = { dc = 13, skill = { "investigation", "arcana" }, convenient = "success",
                     success = { log = "{actor_char} shouts the word. Two seconds to spare: \"Activation accepted. My name is {mech}.\" The table erupts.",
                                 effects = { { "actor", spotlight = 16, fun = 8 }, { "arch:butt_kicker", fun = 5 }, { "arch:casual", fun = -3 } },
                                 mus = { mark = "mech", francs = 2, resolve = "win", aspect = "Woke the Steam Mech with two seconds to spare" } },
                     fail = { log = "Time. The panel snaps shut, and Sam lets out a breath he's been holding for thirty seconds.",
                              effects = { { "arch:casual", fun = -4 }, { "arch:instigator", fun = 3 } }, mus = { resolve = "lose" } } } },
      } },
    -- (risks: what's at stake is the Mech, not them, so a hurt hero or a rough last fight doesn't make
    -- anyone shy of the switch.)
    { id = "mus_hyper", room = "tomorrow", danger = "the red switch: only if absolutely necessary", spot = "8A", at = "end", when = { mark = "mech" }, type = "story", actor = { "instigator", "power_gamer", "butt_kicker" }, party = true, proposes = 1,
      risks = "mech",
      title = "Hyper Destroyer Mode",
      text = "Inside the Mech's chest panel, a red switch sits under a little glass flap.",
      options = {
          { label = "Try it, here and now.", want = "flip the switch right now", short = "flip it",
            roll = { dc = 12, skill = { "arcana", "investigation" }, convenient = "success",
                     success = { log = "The Mech swells, missiles pop out of its shoulders, and it shuts itself down again before anything explodes. Impressive. Terrifying. The switch is scorched: it won't do that again for a while.",
                                 effects = { { "actor", fun = 6 }, { "arch:power_gamer", fun = 5 }, { "arch:instigator", fun = 3 } }, mus = { risk = true, flag = "hyper_spent" } },
                     fail = { log = "It overheats with a shriek of steam and a smell of burnt clockwork. The Mech won't be walking anywhere now.",
                              effects = { { "actor", fun = 2 }, { "arch:tactician", fun = -4 } }, mus = { risk = true, harsh = true, unmark = "mech", flag = "mech_burnt", secret_event = "mech_burnt", aspect = "Burnt out the Steam Mech",
                                                                                                    deeds = { { kind = "break", whom = "flitwidget", thing = "the Steam Mech" } } } } } },
          { label = "\"Save it for later.\"", want = "save it for the last fight", short = "save it",
            -- (Once they know what the switch costs: secrets.hyper, the manual's chapter nine or a hint.)
            pulls = { { when = { hinted = "hyper" }, who = { "tactician", "casual", "storyteller" }, n = 1.0,
                        say = { "It burns out. Let's burn it out on something that matters.", "One go, and then it's scrap. Save it.",
                                "We know what that switch costs. Not on a test run." } } },
            log = "{actor_char} snaps the panel shut. For later.",
            effects = { { "arch:tactician", fun = 5 }, { "arch:casual", fun = 3 }, { "arch:storyteller", fun = 5 }, { "arch:butt_kicker", fun = 3 },
                        { "arch:method_actor", fun = 2 } }, mus = { warn = true, flag = "hyper_saved" } },
      } },

    -- The lecture theatre ---------------------------------------------------------------------
    -- (Asked once a friend has a hint that it's his voice that does it: secrets.lecturer_ears. The second round's
    -- review: the same instant idea in every run read as scripted.)
    { id = "mus_earplugs", room = "lecture", at = "start", when = { hinted = "lecturer_ears" }, type = "rules", actor = { "tactician", "casual", "storyteller" },
      title = "Can I block my ears?",
      text = "{actor} asks: \"Can {actor_char} stuff candle wax in {actor_their} ears before going in? If I can't hear him, he can't bore me, right?\"",
      options = {
          { label = "Yes. It's a good idea, and it works.",
            log = "Wax in, cloth over. It works. Nobody else thought of it.",
            effects = { { "actor", fun = 6 }, { "arch:tactician", fun = 4, trust = 1 } }, leans = "cool", mus = { flag = "deaf", aspect = "Beat a ghost's lecture with candle wax" },
            tells = { "lecturer_ears" } },
          -- (Once they know it's his voice that does it, the call is who goes deaf: everyone, or just them.)
          { label = "Yes, and everyone does it, not just them.", when = { told = "lecturer_ears" },
            log = "Wax all round. The whole party goes in deaf as posts.",
            effects = { { "all", fun = 3 }, { "arch:tactician", fun = 3 } }, mus = { flag = "deaf", aspect = "Beat a ghost's lecture with candle wax" } },
          -- (Not once they've found out it's his voice that does it.)
          { label = "He's in their heads. Wax won't help.", when = { not_told = "lecturer_ears" }, sub = "The book has it working: whoever can't hear him has Advantage (page 24).",
            log = "The drone goes straight past the wax.",
            effects = { { "actor", fun = -3 }, { "arch:power_gamer", fun = -1 } }, leans = "strict" },
      } },

    -- The stairs --------------------------------------------------------------------------------
    { id = "mus_alone", room = "stairs", danger = "the stairs up: something is waiting at the top", at = "start", when = { flag = "pip_alone" }, type = "table", actor = { "instigator" }, who = "jess",
      title = "It's what {actor_char} would do",
      -- (Her player says it first, at the table: the card is your answer. Players announce, the DM answers.)
      see = "{actor}: \"I'm going up. Just a peek. It's what {actor_char} would do.\"",
      text = "While the others are still gathering their things, {actor_char} slips up the stairs alone. \"It's what {actor_char} would do,\" says {actor}, already halfway out of her chair.",
      options = {
          { label = "Let it ride. Run them alone for a bit.",
            log = "{actor_char} creeps up to the curtain. A calm voice on the other side says {actor_char}'s name, and that's enough: back down the stairs. \"Nope,\" {actor} says. Everyone else waited ten minutes.",
            effects = { { "actor", fun = 8, spotlight = 14 }, { "others", fun = -4, boredom = 8 } }, table_min = 10, mus = { risk = true, flag = "seen", aspect = "Went up the Gorgon's stairs alone" } },
          { label = "Rein them in, kindly, out of character.",
            log = "\"{actor_char} can scout next week, with the group.\" \"Fine. Next week,\" {actor} says.",
            effects = { { "actor", fun = -4 }, { "others", fun = 3, trust = 1 } } },
          -- (Not a risk they knew of: you decided she was waiting. Unless someone warned them, it's out
          -- of nowhere, and "They'd been warned" isn't said. Round three.)
          { label = "Let it cost them: Euryale is waiting.",
            log = "From the top step, {actor_char} glimpses a pair of bronze eyes past the curtain, and they glimpse {actor_char} right back. \"I'm coming back down. Now,\" {actor} says.",
            effects = { { "actor", fun = 2, challenge = 8 }, { "arch:storyteller", fun = 3 } }, mus = { harsh = true, flag = "seen", aspect = "Glimpsed a Gorgon from her top step, alone, and came back" } },
      } },

    -- Euryale's lair ---------------------------------------------------------------------------
    -- The knight they walked past climbs out of a frame behind her couch. Its paint is still wet,
    -- and the book's answer to it is paint (weapons out of a painting cut it like paper).
    { id = "mus_lair_frame", room = "lair", danger = "the knight's frame: the paint is wet, and it's watching", at = "mid", when = { mark = "knight" }, fight_only = true, type = "story", actor = { "explorer", "butt_kicker", "tactician" }, party = true,
      title = "The frame behind the couch",
      text = "The black knight steps out of a frame behind her couch, and the paint it left behind is still wet. {actor_char} could reach into the frame.",
      options = {
          { label = "Reach in. It's worth the chill.", want = "reach into the frame", short = "reach in",
            roll = { dc = 12, skill = { "athletics", "acrobatics", "arcana" }, convenient = "success",
                     success = { log = "{actor_char} pulls out a painted blade, dripping. Paint cuts paint.", tells = { "knight_weak" },
                                 effects = { { "actor", spotlight = 8, fun = 3 }, { "arch:explorer", fun = 4.5 }, { "arch:method_actor", fun = 3 } },
                                 mus = { risk = true, flag = "paint", aspect = "Armed the party out of a Gorgon's own painting" } },
                     fail = { log = "The frame bites. {actor_char}'s fingers come back numb and empty.",
                              effects = { { "actor", challenge = 5 } }, mus = { risk = true, harsh = true, hurt = { 1, 4 } } } } },
          { label = "No time. Swords out.", want = "forget the frame and draw steel", short = "draw steel",
            pulls = { { when = { holds_here = "paint_dagger" }, who = { "tactician", "butt_kicker", "casual", "explorer" }, n = 2.5,
                        say = { "We've got Telpur's paint-touched dagger. That'll do for him.", "No need. We brought paint of our own: Telpur's dagger.",
                                "Telpur's dagger is painted. Use that, not the frame." } } },
            log = "They draw steel. The knight's armour drinks the first blow like ink.",
            effects = { { "arch:butt_kicker", fun = 4 }, { "arch:casual", fun = 2.5 }, { "arch:tactician", fun = 2 }, { "arch:explorer", fun = -2 } }, mus = { warn = true } },
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
    mus_flitwidget = { room = "street", sprite = "flitwidget", hows = { "ask", "pocket" }, match = { "Flitwidget" },
                       not_before = " Franc" },
    mus_telpur = { room = "gift_shop", sprite = "telpur", hows = { "ask" }, match = { "Telpur" } },
    mus_euryale = { room = "lair", sprite = "euryale", monster = "euryale", hows = { "beaten", "pocket", "ask" }, match = { "Euryale" } },
    mus_sentinel = { room = "entrance", sprite = "sentinel", monster = "sentinel", hows = { "beaten" }, match = { "the Sentinel", "The Sentinel" },
                     about = "A suit of metal armour between the doors. It stays a statue as long as nobody touches the donation case." },
    mus_bone_construct = { room = "chamber", sprite = "bone_construct", monster = "bone_construct", hows = { "beaten" }, match = { "Bone Construct" },
                           about = "Gold and bleached bone with three skull faces. It guards the chamber's pedestal." },
    mus_knight = { room = "paintings", sprite = "knight_of_shades", monster = "knight_of_shades", hows = { "beaten" },
                   match = { "Knight of Shades" }, about = "Black armour and red light where a face should be. It climbs out of its painting." },
    mus_lecturer = { room = "lecture", sprite = "the_lecturer", monster = "the_lecturer", hows = { "beaten", "ask" }, match = { "the Lecturer", "The Lecturer" },
                     about = "A grey ghost who drones on without a mouth. Fall asleep in his lecture and you may not wake up." },
    mus_mech = { room = "tomorrow", sprite = "steam_mech", monster = "steam_mech", hows = { "ask", "beaten" }, match = { "Steam Mech" } },
}

-- Who comes along with the party (game/model/companions.lua): a pet or a person who joined them.
-- joins: how (a flag the story sets, or `chat` when a chat answer says yes); owner: whose they are
-- (the one who plays them in a fight, and who talks about them); monster: their stat block if they
-- fight (they're in initiative, with a mini); pocket: a pet that hides in a fight instead. helps:
-- what they do when the party looks around (museum_night.explore). lines: what's said about them.
-- sprite: a pet's own mini (a person's comes from their cast card or stat block).
-- Table life: small moments that play themselves (game/model/table_life.lua), room by room.
M.table_life = require "game.data.museum.table_life"
-- Lore tips the DM can hand out to point the way (game/model/lore_tips.lua).
M.lore_tips = require "game.data.museum.tips"
-- Who remembers what the party did, what they say about it, and the friends' own ideas (R11, R12,
-- R13: game/model/people.lua, game/model/ideas.lua).
do
    local P = require "game.data.museum.people"
    M.people_memory, M.people_lines, M.people_about, M.ideas = P.memory, P.lines, P.about, P.ideas
end

M.companions = {
    order = { "exhibit_b", "telpur" },
    exhibit_b = { name = "Exhibit B", pronoun = "he", kind = "pet", what = "Pip's museum rat", owner = "jess", joins = { chat = "pip_pet" }, pocket = true,
                  sprite = "exhibit_b",
                  -- (A pet goes where Pip goes: into the next adventure too, with words that aren't the museum's.
                  -- companions.carry, at the hand-off.)
                  travels = { join = "Exhibit B came along too, still riding in Pip's hood.",
                              start = { "Exhibit B is in my hood. Say hi, Exhibit B.", "Exhibit B came. He insisted.",
                                        "Exhibit B has opinions about this place already." },
                              helps = { bonus = 2 } },
                  helps = { bonus = 2, find = 0.25, find_line = "Exhibit B scurries off under an exhibit and comes back with a Flitwidget Franc in his teeth." },
                  lines = {
                      join = "Pip has a new friend tonight: a museum rat called Exhibit B, riding in her hood. He seems to approve of the museum.",
                      start = { "Exhibit B is in my hood. Say hi, Exhibit B.", "Exhibit B came. He insisted.", "I brought Exhibit B a tiny bit of cheese for the museum." },
                      -- (look: a sniff round, whatever's there; hint: only when there's something to find.)
                      look = { "Exhibit B, go sniff that. Good boy.", "Exhibit B sniffs it, sneezes, and loses interest.",
                               "Exhibit B has a look too. He's not impressed." },
                      hint = { "Exhibit B's whiskers are going. Something's here.", "Exhibit B won't leave it alone. There's something there." },
                      fight = { "Exhibit B, pocket! NOW!", "Nobody step on Exhibit B.", "Exhibit B is in the pocket. We're fine. Mostly." },
                      win = { "Exhibit B was very brave in the pocket.", "Exhibit B gets the first crumb of the victory snack." },
                      -- (When the hero he rode with has died and a new one takes the seat: handed on, once.)
                      handed_on = { "Exhibit B climbs out of {old}'s old hood and into {new}'s pocket. He sniffs {new} twice, and stays.",
                                    "Jess sets a crumb of cheese on {new}'s shoulder. \"He's yours now. {old} would want that.\" Exhibit B takes the cheese.",
                                    "Exhibit B rides on {new}'s shoulder now. Every so often he looks round for {old}." },
                  } },
    telpur = { name = "Telpur", pronoun = "he", kind = "person", what = "the talking boot from the gift shop", owner = "jess", joins = { flag = "telpur_along" },
               monster = "telpur", cast = "mus_telpur",
               helps = { bonus = 1, find = 0.1, find_line = "Telpur knows this museum: \"Under the third tile. Flitwidget hides Francs everywhere.\"" },
               lines = {
                   join = "Telpur is coming with them tonight. He insisted, loudly, until somebody tied him to a pack strap. He has opinions about every exhibit.",
                   start = { "Telpur, from the backpack: \"Onward! Mind the laces.\"", "Telpur is already complaining about the walking." },
                   -- (What he thinks of them now, first: R11, people.lua. A companion remembers too.)
                   start_if = {
                       { when = { knows = { who = "mus_telpur", kind = "steal", to = true } },
                         text = { "Telpur rides along tonight, laces folded, keeping a very close eye on everyone's hands.",
                                  "Telpur, from the backpack: \"I'm counting my laces. Both of them. Every hour.\"",
                                  "Telpur is coming, but he's made them promise: nobody so much as looks at his shelf again." } },
                       { when = { opinion = { who = "mus_telpur", at_least = "devoted" } },
                         text = { "Telpur, from the backpack: \"My favourite people! Onward, and mind the laces.\"",
                                  "Telpur has polished himself for the occasion. He's very proud to be along.",
                                  "Telpur, beaming, if a boot can beam: \"Best customers I ever had. Lead on.\"" } },
                   },
                   look = { "Telpur: \"I'd not touch that. Then again, I'm a boot.\"", "Telpur: \"In my day we had a museum like this. Smaller. More screaming.\"" },
                   hint = { "Telpur: \"Now that, I'd look at twice.\"", "Telpur: \"Warmer. Warmer. I'd look there, if I had hands.\"" },
                   fight = { "Telpur: \"Point me at it!\"", "Telpur hops into the fight, laces flying." },
                   win = { "Telpur: \"Another victory for the Lord of Laces.\"", "Telpur takes most of the credit." },
                   -- (When he drops in a fight, and after it: companions.fell and after_fight.)
                   -- (Three ways each: the same knockout word for word every time was the third playtest's.)
                   down = { "Telpur takes the hit and goes flying, laces everywhere. He lands in a heap and doesn't move.",
                            "Telpur gets punted clean across the room. He skids to a stop under an exhibit, very still.",
                            "A blow catches Telpur square on the toecap. He spins twice and flops over, laces limp." },
                   react = { "Telpur! Somebody get the boot!", "No! Not the boot!", "Telpur's down! Is he breathing? Do boots breathe?" },
                   up = { "Telpur comes round in a tangle of laces. \"I meant to do that. Tactical nap.\"",
                          "Telpur sits up, dazed. \"Did we win? I was resting my eyes. Both eyelets.\"",
                          "Telpur groans and wriggles upright. \"Nobody tell Flitwidget I was napping on the job.\"" },
                   -- (After a death or a lost fight, no jokes: "Did we win?" after a wipe, round three's merge.
                   -- able.somber, companions.fell and after_fight.)
                   react_sad = { "Telpur! Somebody get to him!", "Not Telpur too.", "Telpur's down. Please, someone." },
                   up_sad = { "Telpur comes round in a tangle of laces, looks at the others, and doesn't make a joke of it.",
                              "Telpur sits up slowly. For once, the boot has nothing to say.",
                              "Telpur wriggles upright and stays very quiet." },
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
                                    line = "Under the shears, pressed into the grass, {actor_char} finds a Flitwidget Franc." } } },
    entrance = { "light", "front",
                 finds = { light = { francs = 1, what = "a Franc someone dropped",
                                     line = "Something glints on the marble under the chandelier. {actor_char} picks it up: a Flitwidget Franc." } } },
    chamber = { "3C", "3H", "3G",
                finds = { ["3C"] = { francs = 1, what = "a Franc at the bottom of the jackal jug",
                                     line = "{actor_char} tips the jackal jug. A Flitwidget Franc rolls out into the sand, and into {actor_char}'s pocket." } },
                traps = { ["3H"] = { what = "pull the crocodile's jaw too far and it snaps shut", dc = 12, skill = { "acrobatics", "sleight_of_hand" },
                                     spot_dc = 12, hurt = { 1, 4 },
                                     hit = "The crocodile's jaw snaps shut on {actor_char}'s fingers. The water keeps running.",
                                     dodge = "The jaw snaps shut a finger's width from {actor_char}'s hand.",
                                     spotted = "{actor_char} notices the hinge is far too strong for a tap, and wedges it open with a stick." } } },
    paintings = { "4D", "4I", "4J",
                  finds = { ["4J"] = { francs = 1, what = "a real Franc tucked in the frame",
                                       line = "Wedged behind the duellist's frame, {actor_char} finds a real Flitwidget Franc, not a painted one." } } },
    gift_shop = { "shelves", "souvenirs", looks = 1 },
    hunting = { "6B", "6H", "6F",
                finds = { ["6H"] = { francs = 1, what = "a strip of razorbark worth a Franc to the right buyer",
                                     line = "{actor_char} peels off a strip of razorbark without losing a finger, and a Flitwidget Franc drops out from under it, into {actor_char}'s hand." } },
                traps = { ["6F"] = { what = "a snare the huntlings strung between the vines", dc = 12, skill = { "acrobatics", "athletics" },
                                     spot_dc = 13, hurt = { 1, 6 },
                                     hit = "A loop of vine whips tight round {actor_char}'s ankle and yanks {actor_them} off {actor_their} feet. Something in the jungle chitters.",
                                     dodge = "The vine tightens, and {actor_char} steps out of the loop just in time.",
                                     spotted = "{actor_char} spots the loop of vine in the leaves and cuts it. Something in the jungle chitters, disappointed." } } },
    offices = { "drawings", "7A", looks = 1 },        -- (the eye on every wall is behind the locked door)
    tomorrow = { "cases", "console",
                 finds = { cases = { francs = 1, what = "a Franc stuck in a machine from tomorrow",
                                     line = "One of tomorrow's machines has a coin slot, and {actor_char} works the Flitwidget Franc stuck halfway in it free." } } },
    lecture = { "books", "board", looks = 1,
                finds = { books = { francs = 1, what = "a Franc used as a bookmark",
                                    line = "Somebody used a Flitwidget Franc as a bookmark, a long time ago. Now it's in {actor_char}'s pocket." } } },
}
-- Places on a board behind a door that starts locked: nobody walks to them, and nothing there is described,
-- until it's open (`open`: the flag that opens it). The third round's review: the body at the desk described
-- in the first study, before anyone had opened the second.
M.behind_doors = {
    offices = { places = { "7B", "eyes", "door" }, open = "door_open" },
}
-- What a friend says on walking over to one of those places (museum_night.explore): about that thing,
-- one of its ways, and only the first look in a room gets a word; a place with nothing here gets none.
-- (The third playtest, alive 6: "Wait. Could the front doors be a clue?" and "Stay close" at anything.)
M.explore_say = {
    garden = { shears = { "Shears. Pointy end away from me, please.", "Someone left in a hurry. You don't just drop good shears.",
                          "Gardening shears in a haunted garden. Comforting." },
               hammer = { "That's a lot of hammer for one garden.", "A sledgehammer. For the stakes. Or for the hedges, if they start something.",
                          "Leave it there. If something needs knocking down, we know where it is." } },
    entrance = { light = { "The light's moving, like water. I love it.", "Blue light on marble. This place is showing off.",
                           "Is the chandelier magic, or just very good candles?" },
                 front = { "The doors are still open behind us. Good to know.", "Those doors creak like they're complaining.",
                           "Mental note: that's the way out." } },
    chamber = { ["3C"] = { "A jackal on a jug. Somebody liked jackals.", "Small, and very old. Somebody looked after it.",
                           "It's dry inside. Bone dry." },
                ["3G"] = { "Bigger than the jackal jug. Much bigger.", "Somebody carved every single feather on that falcon.",
                           "Heavy. Whatever goes in this, a lot of it does." },
                ["3H"] = { "A crocodile. Of course there's a crocodile.", "Don't put your fingers in its mouth. I'm serious.",
                           "A lever for a jaw. I'm not pulling it. You pull it." } },
    paintings = { ["4D"] = { "Look at that engine. It's on fire. On purpose?", "I'd ride that airship. I'd regret it, but I'd ride it.",
                             "The land under it is all broken. What happened down there?" },
                  ["4I"] = { "That squid is winning.", "Poor sailors. Nobody signs up for squid.", "Is the paint wet on this one too? I'm not touching it to find out." },
                  ["4J"] = { "He looks very pleased with himself.", "Smoking pistol, open shirt. He's trouble.", "I don't trust him. I like him. I don't trust him." } },
    gift_shop = { shelves = { "A jar of beans. For sale. In a museum.", "The rubber snake. I need the rubber snake.", "No refunds. It says so three times." },
                  souvenirs = { "Everything's priced in Francs. Of course it is.", "I want all of it. I can afford none of it.",
                                "Who buys a souvenir in a haunted museum? Me. I do." } },
    hunting = { ["6B"] = { "There's a tiny train! It goes all the way round!", "Twenty feet of city. Somebody built every single window.",
                           "If we're the giants here, I'm watching where I step." },
                ["6F"] = { "Birdsong, indoors. That's not right.", "I can't see a thing in there. I don't like that.",
                           "Something could be watching us from that jungle right now." },
                ["6H"] = { "That bark looks sharp enough to shave with.", "A tree right up to the ceiling. Indoors. Sure.",
                           "Worth money, you say? Very carefully, then." } },
    lecture = { board = { "Chalk dust everywhere. Somebody wrote a lot.", "I can't read the notes. I can tell they're boring, though.",
                          "The handwriting gets angrier near the bottom." },
                books = { "These are the dullest books I've ever seen.", "Every single one is about rules. Old rules.",
                          "I opened one and nearly fell asleep standing up." } },
    offices = { ["7A"] = { "That bird under the glass has too many wings.", "Gold on the desk. Somebody important worked here.",
                           "Six wings, and every one looks like an eye. I don't like it." },
                drawings = { "These drawings are very careful. And very weird.", "A bird's insides, in detail. Lovely.",
                             "Somebody studied that bird for years. Look at all the notes." } },
    tomorrow = { cases = { "Machines from tomorrow. Some of them are still ticking.", "I don't know what any of these do, and I want all of them.",
                           "That one's got a button. Nobody press the button." },
                 console = { "The voice is so cheerful. Too cheerful.", "Hello to you too, speaker.", "It says welcome every single time. Every time." } },
}

M.marks = {
    topiary = { chain = "a hedge-beast went up to wait at her couch", name = "Topiary at her couch", why = "Briar Guardians left standing in the garden", from = { "garden" },
                showdown = "A Briar Beast fights beside her", foe = "briar_beast",
                thought = "One of my hedges is still standing. Come here, kitten." },
    garden_burned = { chain = "Euryale smelled the smoke upstairs", breaks = "his garden", party = true, name = "She smelled the smoke", why = "They set her garden on fire",
                      showdown = "She skips the drink and the small talk", talk = -2,
                      thought = "Fire. How crude. I liked that garden." },
    robbed = { chain = "word reached Euryale that they were thieves, like her", party = true, name = "Thieves, like her", why = "They emptied the donation box",
               showdown = "They can offer her a cut of the box to leave", thought = "They emptied the gnome's little money box. Oh, I like them already." },
    scarabs = { chain = "its scarabs crawled up through the walls to her", breaks = "the Bone Construct", name = "Scarabs in the walls", why = "They smashed the Bone Construct", from = { "chamber" },
                showdown = "A scarab swarm joins her", foe = "giant_scarab_swarm",
                thought = "They smashed the old guardian. Its beetles are mine now.",
                -- (Crept up from a chamber nobody went into, a loose end: nobody smashed anything, so nothing
                -- broken for Flitwidget to dock either.)
                by = { mus_bone_construct = {
                    why = "Its scarabs crept up to her on their own",
                    thought = "Nobody came for the old guardian, so its beetles came to me instead.",
                    chain = "the Bone Construct's scarabs crept upstairs to her on their own" } } },
    calmed = { chain = "Euryale had one guard fewer", party = true, name = "One guard fewer", why = "They calmed the Bone Construct with the ritual",
               showdown = "Nothing comes up from below to help her", talk = 1,
               thought = "They did the water ritual properly. Nobody does it properly." },
    knight = { chain = "the knight went to wait in a frame in her lair", name = "A knight in a frame", why = "The Knight of Shades was never woken",
               why_if = { { when = { chose = { "mus_knight_frame", 1 } }, text = "The Knight of Shades got away from them" } },
               thought_if = { { when = { chose = { "mus_knight_frame", 1 } }, text = "My knight came crawling back into a frame up here. They'll meet it again." } },
               showdown = "The Knight steps out of a painting in her lair", foe = "knight_of_shades",
               thought = "They walked straight past my knight. It'll keep." },
    pack = { chain = "the huntlings that ran went to her", name = "Her pack", why = "Kruthik Huntlings ran from the fight", from = { "hunting" },
             showdown = "The survivors hunt beside her", foe = "kruthik_huntling",
             thought = "The little hunters came running to me. Good dogs." },
    mirror = { chain = "the party had a mirror for Euryale to face", party = true, name = "A mirror in their packs", why = "They took a polished cupboard door",
               showdown = "Her stare can be turned back on her", opt = "mirror",
               thought = "One of them took a cupboard door. Why would anyone take a door?" },
    know = { chain = "they knew what she was", party = true, name = "They know what she is", why = "They read up on gorgons",
             showdown = "They know to look away, and about her sisters", opt = "averted",
             thought = "Someone downstairs is reading about my kind. How flattering. How annoying." },
    bracelet = { chain = "Flitwidget gave them a bracelet against her stare", party = true, name = "A bracelet of protection", why = "Flitwidget slipped them one",
                 showdown = "Advantage on saves against her stare", opt = "averted",
                 thought = "The gnome gave them a trinket. How sweet. We'll see what it's worth." },
    mech = { chain = "the Steam Mech was on the party's side", unchain = "the Steam Mech was on nobody's side any more", party = true, name = "A machine on their side", why = "They woke the Steam Mech",
             showdown = "The Mech fights for them, and she goes for its commander", ally = "steam_mech",
             thought = "The gnome's toy is walking about. It's pointed at me, isn't it.",
             -- (by: someone else put it there, between sessions, a loose end's `by`; the log names them, and
             -- these say so: her card's reason and what it does, the chain's beat, the board, and the line at
             -- the next night's start, `told` (three ways, {mech} its name). The confirming playtest, seed 57
             -- careful: "They woke the Steam Mech", and the party never went near the World of Tomorrow.)
             by = { mus_flitwidget = {
                 why = "Flitwidget woke it himself, for the fight",
                 showdown = "The Mech fights for them, and you run it",
                 chain = "Flitwidget woke the Steam Mech himself, for the fight",
                 brings = "woken by Flitwidget",
                 told = { "Between sessions, Flitwidget went up to the World of Tomorrow with an oil can and woke the Steam Mech himself. It's called {mech}, and it's coming up the stairs with them tonight.",
                          "Flitwidget has news before they start: he woke the Steam Mech himself this week, with a lot of oil and a little swearing. {mech} will follow them up to her.",
                          "While they were away, Flitwidget cracked the Steam Mech's code on his own. {mech} is awake, and it's coming to the fight." } } } },
    drone = { chain = "the Lecturer's drone went on through the floors", unchain = "the drone through the floor stopped", name = "A drone through the floor", why = "The Lecturer is still lecturing", from = { "lecture" },
              showdown = "They come up half asleep: they lose their edge against her charm", opt = "drowsy",
              thought = "The bore is still droning. They'll come up here half asleep." },
    pages = { chain = "they kept pages that put readers to sleep", party = true, name = "Sleeping pages", why = "They took the Lecturer's notes", from = { "lecture" },
              showdown = "A trick: get her to read one", thought = "They silenced the bore and kept his notes. Clever, or just tidy?" },
    careful = { chain = "Euryale noticed the party's careful hands", party = true, name = "Careful hands", why = "They were gentle with the exhibits",
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
            states = { { when = { mark = "knight", chose = { "mus_knight_frame", 1 } }, text = "Got away from them: it'll step out of a frame in her lair", tone = "bad" },
                       { when = { mark = "knight" }, text = "Still in its frame: it'll step out in her lair", tone = "bad" },
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
            states = { { when = { mark_by = { "mech", "mus_flitwidget" } }, text = "Woken by Flitwidget: {mech} fights for them", tone = "good" },
                       { when = { mark = "mech" }, text = "Woken: {mech} fights for them", tone = "good" },
                       -- (Lost in her lair, smashed or burnt out: not "still asleep in its alcove", or "never met".)
                       { when = { flag = "steam_mech_lost" }, text = "Lost: {mech} fell fighting for them", tone = "bad" },
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
                       { when = { flag = "she_read" }, text = "Upstairs: Euryale has it, and has read it", tone = "bad" },
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
-- What Flitwidget calls each thing they broke (a mark's `breaks`, a deed's `thing`), in his own voice.
M.broke_words = { ["his garden"] = "my garden", ["the Bone Construct"] = "my tomb guardian", ["the Steam Mech"] = "my Steam Mech" }
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
      -- (What they do, said as the rules have it: Conner's playtest, C17, couldn't tell whether they did
      -- anything. The rules: magic_items.twin_daggers, on {holder}'s sheet under CARRYING.)
      line = "{holder} fights with the twin daggers from the Chamber of Ancients: +1 to hit and +1 damage.",
      -- (lines: what's said at the night's first fight, three ways, since it's said every week.)
      lines = { "{holder} fights with the twin daggers from the Chamber of Ancients: +1 to hit and +1 damage.",
                "{holder} has the twin daggers out, rings locked together: +1 to hit and +1 damage with them.",
                "{holder} draws the twin daggers from the chamber, still locked together: +1 to hit, +1 damage." } },
    { id = "arrows", when = { flag = "arrows" }, opt = "fire_arrows", once = true, name = "fire arrows and slime", carry = true,
      text = "Telpur's fire arrows and a bucket of slime: every hero's first weapon hit each turn burns or bites. Enough for one fight.",
      line = "Out come Telpur's fire arrows and the bucket of slime: every hero's first weapon hit each turn burns or bites, this fight only." },
    -- (The painting's gift, said as the hall's fight starts: whose it is and what it does, as the book has
    -- it. Conner's playtest, C14: was the scimitar anything?)
    -- (What it does to the knight is the knight's secret until it's found: secrets.knight_weak.)
    { id = "painted", when = { flag = "paint", told = "knight_weak" }, rooms = { "paintings" },
      line = "{gift_the} is still wet in {paint_holder}'s hand: it counts as paint, and paint is what the painted things here can't shrug off." },
    { id = "painted_plain", when = { flag = "paint", not_told = "knight_weak" }, rooms = { "paintings" },
      line = "{gift_the} is still wet in {paint_holder}'s hand, dripping colour on the floor." },
    { id = "paint_dagger", when = { flag = "paint_dagger" }, rooms = { "lair" }, opt = "paint", name = "a paint-touched dagger", carry = true,
      to = "jess", text = "A dagger Telpur dipped in the hall's wet paint. In the lair, its blows count as magic, and painted things fear it.",
      -- (A loose end's, between sessions: shown handed over at the next night's start, like the bracelet.)
      handover = { "Between sessions, Telpur pressed a dagger on {holder}, its blade still tacky with paint from the hall. \"Painted things hate it,\" he says. \"On the house.\"",
                   "Telpur waved {holder} over before they started: a dagger, dipped in the hall's wet paint. \"For anything that steps out of a frame.\"",
                   "{holder} has a new dagger tonight, from Telpur, its edge still sticky with the hall's paint. \"Painted things fear it,\" he promised." },
      line = "{holder} has Telpur's paint-touched dagger out: {holder_their} blows count as magic, and painted things fear it." },
    { id = "manual", when = { flag = "manual" }, ally = "steam_mech", opt = "manual", name = "the Mech manual", carry = true,
      title = "the Mech Instruction Manual",
      text = "A thick manual with a lot of diagrams. Chapter nine says what the red switch does: with it open, the Mech has Advantage against overheating.",
      line = "{holder} has the Mech manual open at chapter nine: if the red switch goes, {mech} has Advantage against overheating." },
    { id = "hyper_spent", when = { flag = "hyper_spent" }, ally = "steam_mech", opt = "no_hyper",
      line = "{mech}'s red switch is still scorched from the test run: no Hyper Destroyer Mode tonight." },
    { id = "hyper_saved", when = { flag = "hyper_saved" }, ally = "steam_mech",
      line = "{mech}'s red switch is untouched, saved for this." },
    { id = "mirror", when = { mark = "mirror" }, rooms = { "lair" }, boss = true, name = "the cupboard door", carry = true,
      title = "a polished cupboard door",
      text = "A cupboard door from the kitchen diorama, polished like a mirror. Held up in the lair, her own stare can turn back on her.",
      -- (What it does is for the fight to show: her reflection is in her stat block, p35. The knowledge playtest.)
      line = "{holder} has the polished cupboard door ready, for whatever it's worth." },
    -- (from_fondest: Flitwidget gives it to the hero he likes best, from the log. handover: how the
    -- table sees it given, at the next night's start; the lair's lines say whose wrist. Round three:
    -- "Flitwidget's bracelet is on a wrist and ready", and nobody ever saw him give it.)
    { id = "bracelet", when = { mark = "bracelet" }, rooms = { "lair" }, boss = true, name = "Flitwidget's bracelet", carry = true,
      from_fondest = "mus_flitwidget",
      title = "Flitwidget's bracelet of protection", text = "A thin silver bracelet Flitwidget slipped them. In the lair: Advantage on saves against her stare.",
      -- (What it's against waits for the fight: Flitwidget keeps his secret unless pried, p6. The knowledge playtest.)
      handover = { "Between sessions, Flitwidget caught {holder} by the sleeve and slipped a thin silver bracelet onto {holder_their} wrist. \"For protection,\" he whispered. \"Don't tell Telpur.\"",
                   "Before anyone else arrived, Flitwidget pressed a thin silver bracelet into {holder}'s hand. \"Wear it. You'll know when.\"",
                   "Flitwidget found {holder} between sessions and fastened a thin silver bracelet round {holder_their} wrist. \"For when it matters. You'll know when.\"" },
      line = "Flitwidget's bracelet of protection is on {holder}'s wrist.",
      lines = { "Flitwidget's bracelet of protection is on {holder}'s wrist.",
                "The silver bracelet Flitwidget gave {holder} glints.",
                "{holder} turns Flitwidget's bracelet on {holder_their} wrist." } },
    -- (What the scholar's book told them, p27: the page about the gaze living in the snakes, if it came clear
    -- (secrets.gorgon_lore), and that she's a gorgon at all. Otherwise only that they've read it.)
    { id = "know", when = { mark = "know", told = "gorgon", part = { "gorgon_lore", 2 } }, rooms = { "lair" }, boss = true,
      line = "Everyone's read the scholar's book: a gorgon's gaze lives in its snakes. Eyes down once the hood comes off, and Advantage on saves against her stare.",
      lines = { "Everyone's read the scholar's book: a gorgon's gaze lives in its snakes. Eyes down once the hood comes off, and Advantage on saves against her stare.",
                "The scholar's book did its job: the gaze is in the snakes, so they'll watch her hands, not her face. Advantage on saves against her stare.",
                "Everyone knows from the scholar's book where a gorgon's gaze comes from. Eyes low: Advantage on saves against her stare." } },
    { id = "know_plain", when = { mark = "know" }, unless = { told = "gorgon", part = { "gorgon_lore", 2 } }, rooms = { "lair" }, boss = true,
      line = "Everyone's had a look through the scholar's book. Whatever she is, they've an idea what to watch for." },
    { id = "charmed", when = { flag = "charmed" }, rooms = { "lair" }, boss = true, once = true, charm = true,
      line = "{holder} is still smiling at Euryale over the wine: {holder_they} starts the fight charmed by her." },
    { id = "vorpal_sword", when = { flag = "vorpal_sword" }, magic = "vorpal_sword", name = "the vorpal sword", carry = true,
      line = "{holder} has the vorpal sword out. Telpur's forty Francs were well spent.",
      lines = { "{holder} has the vorpal sword out. Telpur's forty Francs were well spent.",
                "{holder} unwraps the vorpal sword from its brown paper. Forty Francs, and worth every one.",
                "{holder} draws the vorpal sword, and the air hums along its edge. Telpur's forty Francs were well spent." } },
    { id = "vorpal", when = { flag = "vorpal_lair" }, rooms = { "lair" }, boss = true,
      line = "Somewhere behind her couch is the vorpal sword they were promised. First, Euryale." },
    -- (Things they carry that don't change a fight: what they're for is elsewhere. The book helps its
    -- reader with what they know about gorgons, the pages put a reader to sleep, the notebook is the
    -- Witness's thread, the shoelace talks. F10: one inventory, and the shop's shelf is real.)
    { id = "gorgon_book", when = { mark = "know" }, name = "the Tenets of the Rotting Temple", carry = true,
      title = "The Tenets of the Rotting Temple", adv = { "history" }, topic = "gorgons",
      text = "A scholar's book on the people who worship gorgons. Whoever has it has Advantage on History about gorgons, and knows there are three sisters." },
    { id = "guide", when = { flag = "guide" }, name = "the Guide to Primeval Creatures", carry = true,
      text = "A guidebook to primeval creatures, full of pictures. Read with Survival or Nature (DC 14), it can tell you what's hunting upstairs." },
    { id = "notebook", when = { flag = "notebook" }, name = "the archivist's notebook", carry = true, to = "mara",
      text = "The dead archivist's notebook: a city under the sea, stone pillars covered in writing, and eyes drawn on every page.",
      handover = { "Between sessions, Telpur let {holder} have \"a strange book\" for nothing: a dead man's notebook from the offices upstairs, eyes drawn on every page.",
                   "Telpur had something under his counter for {holder} this week: \"A strange book. Fell off a shelf upstairs.\" Every page is full of drawn eyes.",
                   "{holder} came away from Telpur's counter this week with \"a strange book\": the notebook of someone who worked upstairs, eyes on every page." } },
    { id = "pages", when = { mark = "pages" }, name = "the Lecturer's notes", carry = true, count = 3,
      text = "Three ghostly pages of lecture notes. Whoever reads one is asleep before the end of the line. One page a reader." },
    -- (Lifted off Telpur's shelf, not bought: R13. It works like the ones he sells, for as long as they hold it.)
    -- (opt_value "arrows": the arrows without the slime, so only a shot burns. Round three: the stolen
    -- quiver put "Telpur's slime" on everyone's swords.)
    { id = "arrows_lifted", when = { holds = "arrows_lifted" }, opt = "fire_arrows", opt_value = "arrows", once = true, name = "a quiver of fire arrows, lifted", carry = true,
      text = "A quiver of Telpur's fire arrows, off his bottom shelf and never paid for: every hero's first shot each turn burns. No slime: that's still on his shelf. Enough for one fight.",
      line = "{holder} hands round the fire arrows nobody paid for: every hero's first shot each turn burns, this fight only." },
    -- (Bought off Telpur's counter in a haggle, table_life: out of the pool, into the haggler's pack.
    -- Said at the night's first fight, three ways: a keepsake along for the ride. Nothing a fight won't deliver:
    -- they do nothing in one, so no line says they're ready for throwing. Round four's review, 81 careless.)
    { id = "marbles", when = { holds = "marbles" }, name = "a bag of Telpur's marbles", carry = true,
      text = "A bag of glass marbles off Telpur's counter, every one a different colour. A keepsake, and nice to roll about in a pocket.",
      line = "Telpur's marbles clink in {holder}'s pack.",
      lines = { "Telpur's marbles clink in {holder}'s pack.",
                "Somewhere in {holder}'s pack, a bag of Telpur's marbles rattles.",
                "{holder}'s pack clinks: Telpur's marbles, every colour there is, along for the ride." } },
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
-- What a hero pockets from the nearest exhibit (the friends' `my_guy`), room by room: named, in the
-- log (kind "pocket"), and given back before the end (round three: "Pip pockets something small"
-- sixteen times, never said what, and it never came back).
M.pocketables = {
    street = "a Flitwidget Museum leaflet", garden = "a brass label off a rose bush", entrance = "a foreign coin off the floor",
    chamber = "a tiny clay scarab", paintings = "a dried-up tube of paint", gift_shop = "a snow globe with the caravan in it",
    hunting = "a glass eye off a stuffed boar", offices = "a pencil stub with teeth marks in it", tomorrow = "a little brass cog",
    lecture = "a stick of chalk", stairs = "a dead candle from the stair",
}
M.friction = {
    acts = {
        -- (No loot to count in the museum: a room pays Francs into the pool, out loud.)
        skim_the_hoard = false,
        my_guy = { line = "{actor_char} pockets {pocketed}. 'Sorry, it's just what {actor_char} would do,' {actor} shrugs.",
                   pocket = true },
        lone_wolf = "{actor_char} slips off alone to poke at the exhibits, and everyone else waits by the door for ten minutes.",
        shove_a_friend = "{actor_char} shoves {target_char} into a display case to win an argument.",
        barge_the_bargain = "{actor_char} talks right over {target_char} while {target_char} is still asking questions.",
    },
    -- (The DM's answers: a table of fields to replace.)
    responses = {
        outlet = { label = "Give {actor_char} the next big moment, on purpose.",
                   log = "You make a note, and you keep it: the next big moment is {actor_char}'s.", screen = true },
    },
    bonds = {
        -- (A promise: the next thing the party finds goes to them, and the table hears it kept:
        -- museum_night.first_pick. Never once the adventure's over.)
        share_the_loot = { line = "{actor_char} lets {target_char} have first pick of whatever the party finds next: 'You'll get more use out of it than me.'",
                           say = "Whatever we find next, {target_char} gets first pick. You'll get more use out of it than me.",
                           promise = true },
        make_amends = { line = "{actor_char} gives back {pocketed}, polished, with a bad drawing as an apology.",
                        say = "I give back {pocketed}. Polished. With a drawing. It's an apology.", pocket_back = true },
        -- (Nothing that needs a threat in the room: round four's review heard "Leave him alone" in the middle
        -- of Flitwidget's thanks.)
        stand_up_for = { line = "{actor_char} backs {target_char} up: \"What {target_char} said. We're all in this together.\"",
                         say = "I'm with {target_char} on this. What {target_char} said. We're all in this together." },
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
                     effect = { weapon = 1, every = true }, ["for"] = { "rogue", "fighter", "cleric", "wizard" } },
}
M.CAREFUL_AT = 3         -- gentle acts before she notices
M.base = { name = "Euryale, the Gorgon", line = "A calm host in a white hood. Three attacks a turn, claws up close or her poison bow, and charm, while the hood is on; her stare and her snakes too when it comes off." }

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
    { id = "hyper", match = { "Hyper Destroyer Mode", "Hyper mode" }, plain = "Hyper Destroyer Mode",
      text = "The Steam Mech's red switch: for a few rounds it hits far harder, then it overheats and shuts down." },
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
          laugh = { reply = "Yes, but Telpur talks in his sleep. About hell. In detail.", asker = 2, mus = { flag = "rested" } },
          reason = { reply = "Time's funny in the museum. You pick up right where you stopped, bruises and all.", asker = -2 },
          danger = { reply = "You rest, and wake to find a statue at the foot of the stairs that wasn't there before.", asker = 1, mus = { flag = "rested", warn = true } },
      } },
    { id = "keep_boot", who = "jess", after = "gift_shop",
      ask = "can {char} take Telpur with us? the talking boot in the gift shop. asking for {char}",
      ask_if = { { when = { mark = "robbed" }, text = "can {char} take Telpur with us? the talking boot. legally, this time" } },
      about = "Telpur is the talking boot behind the gift shop's counter, who says he was once a great lord of the underworld. "
          .. "Jess loved him.",
      answers = {
          yes = { reply = "Telpur agrees to come along, as long as nobody wears him.", asker = 3, mus = { flag = "telpur_along" } },
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

-- What the table has heard named, by the words that name it (museum_night.heard sets the flag once a line
-- says one): the six-winged bird, once someone's said what it is, isn't "can't place it" any more.
M.names_heard = { bird_named = { "mythril singer", "when there's magic close by", "when there's magic about" } }

-- What the table has to be told before anyone at it can know (game/model/told.lua; the knowledge playtest of
-- November 5, docs/design/2026-11-05-knowledge-playtest.md). Each: the `words` that name it; `intro`, a phrase
-- in a line that tells it; `mask`, what's said instead until it's told ({ name, said as }, in order: a `told`
-- key changes it to `then_to`); `always`, a DM's label the table never hears. A moment's option or roll branch
-- can `tells` it outright. As the book has it: the Gorgon and her name come from Flitwidget's confession (p6)
-- or the hood coming off (p26); the foes' names are the DM's (p15, p20, p33 to p38).
M.told = {
    gorgon = { words = { "Gorgon", "Gorgons" },
               intro = { "a Gorgon called", "a Gorgon in a jar", "a Gorgon, sealed", "Euryale, a Gorgon", "the snakes in her hair",
                         "snakes for hair", "she's a Gorgon", "A Gorgon.", "A Gorgon. Euryale" },
               mask = { { "a Gorgon", "a monster" }, { "the Gorgon", "the monster" }, { "Gorgons", "monsters" },
                        { "Gorgon", "monster" } } },
    euryale = { words = { "Euryale" }, covered_by = { { flag = "truth" } },
                intro = { "called Euryale", "Her name is Euryale", "Euryale, a Gorgon", "A Gorgon. Euryale" },
                mask = { { "Euryale's door", "the door at the top of the stairs" },
                         { "Euryale", "the hooded woman", told = "gorgon", then_to = "the Gorgon" } } },
    ritual = { words = { "ritual" } },       -- (a secret too: game/data/museum/secrets.lua, learned a tablet line at a time)
    hood_off = {},          -- (her hood has come off in a fight: the snakes are out. Told by the fight, fight.tell_moments.)
    sisters = { words = { "her sisters" } },
    knight = { always = true, words = { "Knight of Shades" }, mask = { { "Knight of Shades", "black knight" } } },
    huntlings = { always = true, words = { "huntling", "huntlings", "kruthik" },      -- (told by the guide: secrets.kruthik)
                  mask = { { "kruthik huntlings", "armoured hunters" }, { "kruthik huntling", "armoured hunter" },
                           { "huntlings", "hunters" }, { "huntling", "hunter" }, { "kruthik", "armoured" } } },
    briars = { always = true, words = { "briar" },
               mask = { { "Briar Guardians", "living hedges" }, { "briar triceratops", "horned hedge-beast" },
                        { "briar boar", "hedge-boar" }, { "briar beast", "hedge-cat" }, { "briar", "hedge" } } },
    construct = { always = true, words = { "Bone Construct" }, mask = { { "Bone Construct", "bone guardian" } } },
    -- (Who the body was is for a closer look, p21: told with secrets.archivist or secrets.witness.)
    archivist_named = { always = true, words = { "archivist" },
                        mask = { { "dead archivist's", "dead man's" }, { "dead archivist", "dead man" }, { "the archivist's", "the dead man's" },
                                 { "the archivist", "the dead man" }, { "archivist", "dead man" } } },
    -- (The stat block's name, from a fight's label: "That's a crit on the Giant Scarab Swarm".)
    swarm = { always = true, words = { "Giant Scarab Swarm" }, mask = { { "Giant Scarab Swarm", "scarab swarm" } } },
    sentinel = { always = true, words = { "Sentinel" }, mask = { { "Sentinel", "metal statue" } } },
}

-- What the DM knows and the table doesn't, and the ways each can come out (game/model/secrets.lua): the same
-- keys as M.told's names.
M.secrets = require "game.data.museum.secrets"

-- Threads still open when the museum is over, for a later adventure to pick up by its tags (adventure.handoff).
M.why_here = "why {char_they} came to the museum"
M.slide = "A one-shot prologue: a gnome's travelling museum, and the Gorgon who took it over."
-- The adventure's own currency: a great roll can turn one up (night.lua), and the chain counts them (events.lua).
M.currency = { id = "francs", one = "Flitwidget Franc", many = "Flitwidget Francs", short = "Francs" }
-- A foe who gets away comes back: up the stairs, on Euryale's card (museum_night.after_room). The way-out card offers it.
M.escapes_return = true
-- When the book's next level comes, by the level they're at (the report).
M.level_when = { [1] = "after the gift shop.", [2] = "after the gift shop.", [3] = "when the museum is done." }
-- The prep board's story column before anything's happened.
M.story_start = "A gnome's museum has just rolled into town, and everyone's talking about it."
-- What the break's reading up covers (museum_night.maybe_break): the Gorgon only once they've heard of her.
M.read_up = { { when = { told = "gorgon" }, text = "They read up: the museum, the Gorgon, their notes." },
              "They read up: the museum, and their notes so far." }
M.threads = {
    { id = "mountain_road", name = "A murder up the mountain road", open_at_end = true, tags = { "mountain_road", "murder", "mountains" },
      who = "mus_flitwidget", text = "Flitwidget has had strange news from the mountains: a death among the clans up the "
          .. "mountain road, and nobody asking the right questions. He could use guards." },
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
          { label = "Its scarabs creep upstairs to her", mus = { mark = "scarabs", by = "mus_bone_construct" }, like = { dev = 1, sam = -1 } },
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
          -- (by: his doing, not theirs, in the log and in every line: the mark's `by` words.)
          { label = "Flitwidget wakes it himself, for the fight", mus = { mark = "mech", by = "mus_flitwidget" }, like = { sam = 2, dev = 1 } },
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
    -- The talk before her ultimatum (p25-26): what the friends ask, and her answers in our words. `read`: watching
    -- her answer (a hint of her sisters, p27: torn from home and sealed away, she glances at the tapestry).
    questions = {
        { ask = "Where are you from?", who = { "storyteller", "explorer", "method_actor" },
          answer = "Somewhere as far from here as it is from your home. I was taken from it, against my will, and sat gathering dust in this museum for a very long time.",
          read = { key = "sisters", skill = "insight", hint = 13, known = 21,
                   hint_says = "As she says \"taken\", her eyes go to a tapestry of three sisters behind her, and stay there a moment too long.",
                   tell = "Her eyes keep going to a tapestry of three sisters behind her. She isn't only talking about herself: she's one of them, and the other two were taken too." } },
        { ask = "What do you want with the museum?", who = { "tactician", "instigator", "storyteller" },
          answer = "To make it mine. A little world of my own, where every exhibit stays exactly where I put it." },
        { ask = "Why not just leave?", who = { "casual", "explorer", "method_actor" },
          answer = "Out there, nothing stays where it's put. In here, even the dust settles where I tell it to. Why would I leave?" },
        { ask = "What do you make of the gnome?", who = { "instigator", "method_actor", "casual" },
          answer = "Very little. Except that he is a great deal more than he looks. Of that, I'm certain." },
    },
    drink = {
        id = "mus_drink", type = "story", actor = { "casual", "method_actor", "instigator" }, party = true,   -- (theirs to drink or not: November 3)
        title = "A drink",
        text = "Euryale pours from a carafe of red wine. \"Such a long climb. Rest your feet, and have a glass.\" {actor_char} reaches for a cup.",
        text_if = { { when = { flag = "rematch" }, text = "The carafe is out again. \"Back so soon? Sit. Drink. You'll need it.\" {actor_char} reaches for a cup." } },
        options = {
            { label = "{actor_char} drinks.", want = "drink the wine", short = "drink up",
              roll = { dc = 12, skill = { "insight", "religion" }, convenient = "success",
                       success = { log = "It's just very good wine. Euryale looks faintly impressed.", effects = { { "actor", fun = 2, spotlight = 6 }, { "arch:method_actor", fun = 3 } } },
                       fail = { log = "The charm takes hold: the weapon comes down, and Euryale looks lovely, actually. If this comes to a fight, {actor_char} starts it charmed.",
                                effects = { { "actor", fun = 2, spotlight = 8 }, { "arch:instigator", fun = 4 }, { "others", challenge = 4 } }, mus = { flag = "charmed", risk = true, aspect = "Was charmed by a Gorgon, briefly" } } } },
            { label = "Nobody drinks.", want = "leave the wine alone", short = "leave the wine", lean = "safe", log = "Untouched cups. Euryale sighs, as if they've hurt her feelings.",
              -- (A table that knows what she is thinks twice about her wine: R10, the friends drank 70% of the time.)
              pulls = { { when = { flag = "truth" }, who = { "tactician", "storyteller", "casual" }, n = 1.2,
                          say = { "She turned people to stone. I'm not drinking anything she pours.", "Flitwidget told us what she is. No wine, thanks.",
                                  "A Gorgon's wine? Hard pass." } },
                        -- (What they can see: a room of screaming statues. The knowledge playtest took the table's
                        -- "they know what she is" away from tables Flitwidget never told.)
                        { who = { "tactician", "casual" }, n = 0.45,
                          say = { "Not with those statues watching. No wine, thanks.", "Everyone in here is made of stone and screaming. I'll pass.",
                                  "I'm not drinking anything up here. Look at this place." } } },
              effects = { { "arch:tactician", fun = 3 }, { "arch:casual", fun = 2 }, { "arch:storyteller", fun = 2 }, { "arch:butt_kicker", fun = 1.5 },
                          { "arch:method_actor", fun = -2 } } },
        },
    },
    talk = {
        id = "mus_ultimatum", type = "story", actor = { "storyteller", "method_actor", "instigator" }, party = true,   -- (their answer, not yours)
        title = "Join the collection",
        text = "Euryale sets down her cup. \"Here is your choice. Stay, as part of my collection. Or die.\" {actor_char} has one chance to answer.",
        text_if = { { when = { mark = "garden_burned", flag = "rematch" }, text = "Euryale doesn't sit. \"I'll ask once more. Stay, as part of my collection. Or die.\" {actor_char} has one chance to answer." },
                    { when = { mark = "garden_burned" }, text = "Euryale doesn't sit. \"Here is your choice. Stay, as part of my collection. Or die.\" {actor_char} has one chance to answer." },
                    { when = { flag = "rematch" }, text = "Euryale sets down her cup. \"I'll ask once more. Stay, as part of my collection. Or die.\" {actor_char} has one chance to answer." } },
        options = {
            { label = "Weapons out.", want = "fight her", edges = true, log = "Steel answers for them. Euryale stands, smiling. \"As you like.\"",
              effects = { { "arch:butt_kicker", fun = 6 }, { "arch:storyteller", fun = -1 } }, mus = { fight = true } },
            -- (The tapestry is the book's clue in plain view, p27; that she wants them found is hers to tell. The
            -- second round's review: "where the other two sisters are" before anyone had said she has any.)
            { label = "Bargain: ask about the sisters on her tapestry.", want = "ask her about the three sisters on the tapestry", short = "bargain with her", lean = "none", needs = { mark = "know" }, alt_needs = { flag = "tapestry" },
              roll = { dc = 14, skill = { "persuasion", "insight" }, convenient = "success",
                       success = { log = "Her hood dips. \"My sisters. Sealed in clay, as I was. Two jars, somewhere out there.\" She'd leave for that. She would.", tells = { "sisters" },
                                   effects = { { "actor", spotlight = 14, fun = 8 }, { "arch:storyteller", fun = 8, story = 8 }, { "arch:casual", fun = 3 }, { "arch:butt_kicker", fun = -3 } },
                                   mus = { ending = "bargain", aspect = "Talked a Gorgon into a bargain" } },
                       fail = { log = "\"You know nothing about my sisters.\" The hood comes down, a little.",
                                effects = { { "all", challenge = 6 } }, mus = { fight = true } } } },
            { label = "Offer her a cut of the donation box.", want = "buy her off with the donation box", short = "pay her off", lean = "none", needs = { mark = "robbed" }, escape = true,
              roll = { dc = 13, skill = { "deception", "persuasion" }, convenient = "success",
                       success = { log = "\"Thieves after my own heart.\" She takes the coin, and the back curtain, and she's gone.",
                                   effects = { { "actor", spotlight = 12, fun = 8 }, { "arch:instigator", fun = 8 }, { "arch:storyteller", fun = 2 }, { "arch:power_gamer", fun = -2 } },
                                   mus = { ending = "escape", aspect = "Paid a Gorgon to leave" } },
                       fail = { log = "\"You would rob your host twice?\" She laughs, and reaches for her bow.",
                                effects = { { "all", challenge = 6 } }, mus = { fight = true } } } },
            -- (by_holder: whoever carries the pages hands one over.)
            { label = "Hand her a page of the Lecturer's notes.", want = "put her to sleep with the Lecturer's notes", short = "send her to sleep",
              needs = { mark = "pages", holds_here = "pages" }, mus = { use = "pages" }, by_holder = "pages",
              roll = { dc = 13, skill = { "deception", "sleight_of_hand" }, convenient = "success",
                       success = { log = "She reads the first line, frowns, and is asleep before the second.",
                                   effects = { { "actor", spotlight = 14, fun = 8 }, { "arch:instigator", fun = 6 }, { "arch:casual", fun = 3 }, { "arch:butt_kicker", fun = -2 } },
                                   mus = { ending = "slept", aspect = "Put a Gorgon to sleep with a lecture" } },
                       fail = { log = "She glances at the page and smiles. \"I have read this lecture. I was there.\"",
                                effects = { { "all", challenge = 6 } }, mus = { fight = true } } } },
            { label = "Talk her round. Ask what she really wants.", want = "talk her round", short = "talk to her", lean = "safe", needs = { talk = 2 },
              roll = { dc = 15, skill = { "persuasion", "insight" }, convenient = "success",
                       success = { log = "For the first time, the calm slips. Out there was chaos; in here was safe. And lonely. \"Perhaps,\" she says, \"we need not fight.\"",
                                   effects = { { "actor", spotlight = 16, fun = 10 }, { "arch:storyteller", fun = 10, story = 10 }, { "arch:butt_kicker", fun = -4 } },
                                   mus = { ending = "ally", aspect = "Talked a Gorgon round" } },
                       fail = { log = "\"You do not get to know me.\" The calm comes back, colder.",
                                effects = { { "all", challenge = 6 } }, mus = { fight = true } } } },
        },
    },
    -- What the party brought that's good against her in a fight, for the ultimatum's vote when it has
    -- "Weapons out" (its `edges`), R10: a friend who likes a fair, clever fight counts them all ("We came
    -- ready for her: a mirror for her stare."), and whoever carries one wants to use it ("What did I
    -- bring a cupboard door up here for, then?"). item: whose it is (its holder, at the table);
    -- commander: the Mech's (the one who woke it). text: in anyone's words; mine: in the holder's.
    edges = {
        -- (Her stare and what a gorgon is, once the table knows she's one: told.lua. Before, a cupboard door and a
        -- book on cults are nothing to count on against her: the second round's review.)
        { when = { holds_here = "mirror", told = "gorgon" }, item = "mirror", text = "a mirror for her stare", mine = "a cupboard door" },
        { when = { mark = "know", holds_here = "gorgon_book", told = "gorgon" }, item = "gorgon_book", text = "everything the book says about gorgons",
          mine = "a whole book on gorgons" },
        { when = { holds_here = "bracelet" }, item = "bracelet", text = "Flitwidget's bracelet", mine = "Flitwidget's bracelet" },
        { when = { mark = "mech", flag = "hyper_saved" }, commander = true, text = "the Mech's red switch, saved for her",
          mine = "my Mech's red switch" },
        { when = { mark_by = { "mech", "mus_flitwidget" } }, text = "Flitwidget's Mech on our side", mine = "Flitwidget's Mech" },
        { when = { mark = "mech", not_flag = "hyper_saved", not_mark_by = { "mech", "mus_flitwidget" } }, commander = true,
          text = "the Mech on our side", mine = "my Mech" },
        { when = { holds_here = "arrows" }, item = "arrows", text = "Telpur's fire arrows", mine = "fire arrows" },
        { when = { holds_here = "arrows_lifted" }, item = "arrows_lifted", text = "a quiver of fire arrows", mine = "a quiver of fire arrows" },
        { when = { holds_here = "vorpal_sword" }, item = "vorpal_sword", text = "the vorpal sword", mine = "a vorpal sword" },
    },
    -- Said in the fight, the moment she yields (fight.lua: a boss prepped to yield, below a third
    -- of her hit points); then the yield card plays, once the fight has stopped.
    yield_line = "Euryale stops fighting, and her whole collection goes still around her.",
    -- (An ambush the second time up her stairs: she remembers the first. Round three, B3.)
    ambush_again = { "No welcome this time. \"You came back. I hoped you would.\" The bow is already up.",
                     "\"Again? I moved the statues to make room for you.\" An arrow is on the string before they reach the top step.",
                     "She's waiting at the top of the stairs this time, bow drawn. \"Last time was a rehearsal.\"" },
    -- What letting her get away costs (R5, D2: Conner, "make the escape card cost something visible on
    -- the boss board"): the book's reward is for a Gorgon beaten, so one who walks out, runs from a long
    -- fight or is paid to leave earns half of it. Shown on the showdown board, on every card that lets
    -- her go, and paid out in Flitwidget's thanks (adventure.reward_gold).
    escape = { share = 0.5,
               sub = "It costs: she's out, not beaten, and Flitwidget pays half the reward.",
               -- (The reward is real gold, not his Francs, which only spend in the gift shop: the board
               -- says so, and the report gives the same number with why it moved. Round three.)
               board = "If she gets away, Flitwidget pays half the reward: {half} gold each, not {full}. That's real gold, not his Francs. Letting her run from a long fight, letting her go when she yields and paying her off all count." },
    -- She died, but her collection still won the fight: she's fallen all the same.
    dead_but_lost = "Euryale is dead, but her collection drives them back down the stairs. By morning, without her, the exhibits go still.",
    yield = {
        id = "mus_yield", type = "boss", actor = { "storyteller", "casual", "butt_kicker" }, party = true,   -- (mercy is theirs)
        title = "\"Enough\"",
        -- (Snakes only once her hood's come off: told.lua's hood_off, the fight's veil.)
        text = "Down on one knee, Euryale lowers her bow. \"Enough. I yield. Let me go, and you'll never see me again.\"",
        text_if = { { when = { told = "hood_off" }, text = "Down on one knee, snakes hissing, Euryale lowers her bow. \"Enough. I yield. Let me go, and you'll never see me again.\"" } },
        options = {
            { label = "Let her go.", want = "let her go", lean = "none", log = "Nobody lifts a weapon as she gathers up her bow and stands.", escape = true,
              effects = { { "arch:storyteller", fun = 6 }, { "arch:casual", fun = 4 }, { "arch:butt_kicker", fun = -3 }, { "arch:power_gamer", fun = -3 } },
              mus = { ending = "escape", aspect = "Let a Gorgon walk free" } },
            -- (Only once they know there are sisters to find: game/data/museum/secrets.lua's sisters.)
            { label = "Make her a deal: her sisters, for her help.", want = "make her a deal", short = "deal with her", lean = "none", needs = { told = "sisters" },
              log = "A long silence. Then a nod. \"For my sisters.\"",
              effects = { { "arch:storyteller", fun = 8, story = 6 }, { "arch:butt_kicker", fun = -2 } }, mus = { ending = "bargain" } },
            -- (Not knowing yet, they can still ask what she wants: the book's way to the bargain, p27.)
            { label = "Ask her what she wants, if they let her live.", want = "ask her what she wants", short = "ask her", lean = "none", needs = { not_told = "sisters" },
              log = "She looks up at the tapestry. \"My sisters. Sealed in clay jars, as I was. Find them, and I'll owe you more than you know.\" A long silence, and then a nod.",
              tells = { "sisters" },
              effects = { { "arch:storyteller", fun = 8, story = 6 }, { "arch:butt_kicker", fun = -2 } }, mus = { ending = "bargain" } },
            { label = "Finish it.", want = "finish it", lean = "none", log = "{actor_char} doesn't hesitate. It's over.",
              -- (Once they've seen what she does with her hood off.)
              pulls = { { when = { told = "hood_off" }, who = { "butt_kicker", "tactician" }, n = 0.9,
                          say = { "Not after what we saw her do. Finish it.", "She'd do it again to the next ones up those stairs.",
                                  "She doesn't get a second chance at us." } } },
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
-- Each of the museum's monsters one at a time, for a line that names one ({Name_they}, util.pronoun_of):
-- a cast card's `pronoun` when it has one (M.npc_sheet's monster: the Sentinel, the Bone Construct and
-- the Knight of Shades "it", constructs all; the Lecturer "he"; Euryale "she"), else these. A swarm, a
-- hedge-beast, a huntling: "it". (Round three's merge: "Who does they go for?" for the biggest huntling.)
M.foe_pronouns = { kruthik_huntling = "it", giant_scarab_swarm = "it", briar_beast = "it", briar_triceratops = "it",
                   briar_boar = "it" }

-- How the prologue ends, by how they dealt with Euryale.
M.endings = {
    fallen = { chain = "the museum was Flitwidget's again", name = "Euryale falls",
               line = "She crumples as she falls, and whatever she was slips away into the gaps in the floor like smoke. Only a purple robe, a white hood and an emerald bow are left.",
               -- (How she fell changes what's left: her own reflection turned her to stone.)
               stone_line = "Euryale stands where the mirror caught her, stone from hood to bow. Around the lair, the other statues start to soften back into people.",
               flit = "\"Splendid! Though I wouldn't bet my caravan she's gone for good. Her kind have a habit of coming back.\"",
               -- (After a death tonight, his word on it is a quiet one: able.somber, museum_night.thanks_word.)
               flit_sad = "\"So she's gone. Her kind have a habit of coming back, but not tonight. Not tonight.\"" },
    bargain = { chain = "they struck a bargain with Euryale, and she left the museum", name = "A bargain with a Gorgon",
                line = "Euryale leaves the museum with a promise: they'll look for the two clay jars her sisters are trapped in, and she'll owe them a favour.",
                flit = "\"A bargain? With her? Well. I suppose that's one way to tidy up.\"",
                flit_sad = "\"A bargain with her. Well. I'd hoped it would cost less than this.\"" },
    escape = { chain = "Euryale slipped away", name = "Euryale slips away",
               line = "Euryale is gone through the black curtain, out into the world. The statues in the lair start to soften back into people. Somewhere out there, a Gorgon is loose: a problem for another night.",
               flit = "\"Out? Well, as long as she's out of my museum. Mostly that's what I wanted. Mostly. Half the reward, I think, for half a job.\"",
               flit_sad = "\"She's out of my museum. Half the reward, I think, for half a job. I'm sorry it cost you so much more.\"" },
    slept = { chain = "Euryale slept, and they carried her out", name = "Euryale, asleep",
              line = "They carry Euryale out through the black curtain, snoring softly, and leave her somewhere far from the museum. The statues in the lair start to soften back into people.",
              flit = "\"Asleep? On a lecture? I always said it was a very good lecture.\"",
              flit_sad = "\"Asleep, and carried out. I'm glad it's over. I'm sorry about the rest.\"" },
    ally = { chain = "Euryale came over to their side", name = "An unlikely ally",
             line = "Euryale stays, as curator of her own quiet wing. The statues soften back into people, blinking, one by one.",
             flit = "\"Co-curators? I... suppose she does have an eye for arrangement.\"",
             flit_sad = "\"Co-curators. She does have an eye for arrangement. I wish it hadn't cost so much to find out.\"" },
    timeout = { chain = "Euryale stayed upstairs", name = "Still upstairs",
                line = "Weeks went by and Euryale is still upstairs. Flitwidget packs up the caravan and moves on, very carefully.",
                flit = "\"Perhaps we come back to this one.\"" },
}
M.epilogue = {
    "And an invitation: Flitwidget needs guards for the road, and he's heard strange news from the mountains. A murder, and a conspiracy.",
}
-- What each friend says when the prologue ends: they want the full campaign.
-- ({char}: their hero now, who may not be the one they started with.)
M.want_more = {
    mara = { { "Okay, the Witness. A sunken city. I need to know. When's the campaign?", when = { flag = "witness_city" } },
             "That was a prologue? I've already got a notebook for the campaign.",
             "{char} has so many questions now. So many. Campaign, please.",
             -- (Only once they've heard it from her: the bargain over her sisters. The confirming playtest heard
             -- it after a gorgon book that only says there are three.)
             { "A Gorgon who only wanted her sisters back. I need the rest of that story.", when = { ending = "bargain", told = "gorgon" } } },
    dev = { "Same heroes, bigger fights? I'm in. Every Thursday.", "Level 4 and a gnome with a caravan. Let's go.",
            "{char} wants a rematch with something. Anything. Campaign?" },
    jess = { "{char} is keeping the gnome. {char} is keeping everything. Campaign. Now.", "I want to see where the caravan goes next.",
             "Somewhere out there is a museum with a bigger gift shop. Take me there." },
    sam = { "That was so much fun. Same time next week? For the real thing?", "I'll bring snacks for the whole campaign. That's a promise.",
            "{char} says a prayer for the road. And one for the snacks. Campaign?" },
}
-- The same, once a hero has died in the prologue (museum_night.after_showdown): own, when it was their
-- hero, tonight ({char}: the hero who died); was, their hero, on an earlier night, and they play someone new
-- now ({now}); other, when it was a friend's ({lost}: the heroes they lost).
M.want_more_sad = {
    mara = { was = { "{now} is ready for the campaign. And I haven't forgotten {char}.",
                     "I still have {char}'s character sheet. {now} gets the next page. Campaign." },
             own = { "I'll miss {char}. I'm already thinking about who comes next. Campaign? Yes.",
                     "{char} would have wanted to see the mountains. Somebody has to go for {char_them}. Campaign." },
             other = { "For {lost}. Yes. Campaign. I want to see where this goes.",
                       "I'm writing {lost} into my notes for the campaign. First page." } },
    dev = { was = { "{now} is in. But {char} gets the first toast.", "Same dice as {char}, new hero. Campaign. For {char}." },
            own = { "{char} went down swinging. I'll roll someone new. I'm in.",
                    "New character, same dice. Campaign. For {char}." },
            other = { "We do it for {lost}. Every Thursday. I'm in.",
                      "Campaign. And nobody goes down like {lost} did. Not on my watch." } },
    jess = { was = { "{now} wants the campaign. {char} would have wanted it more.", "I'm keeping {char}'s dice for {now}. Campaign." },
             own = { "{char} would want me to keep playing. So. New character. Campaign.",
                     "I'm keeping {char}'s dice for the next one. Campaign." },
             other = { "I'm in. We owe {lost} a proper story.", "Campaign. And {lost} gets a statue in it. A nice one." } },
    sam = { was = { "{now} brings the snacks now. {char} would've liked that.", "{char} first, then the campaign. {now} is ready." },
            own = { "I'll bring snacks and a new character. {char} would've liked that.",
                    "I'm not done. Somebody new, for {char}. Campaign." },
            other = { "I'll be there. For {lost}.", "Campaign. I'll bring the snacks. {lost} would've wanted snacks." } },
}

-- The group chat between sessions: what the friends say about the room they just played.
-- The everyday bit of the group chat, one a week: { who, line, who replies, their reply }.
M.chat_banter = {
    { "sam", "who's on snacks this week", "jess", "me. it's going to be crisps again" },
    { "mara", "i made a little map of the museum so far. it's mostly question marks", "dev", "very helpful. thank you" },
    { "jess", "can we start 15 min late thursday, bus thing", "sam", "np, i'll be late anyway", late = { jess = "bus", sam = "any" } },
    { "dev", "i've been practising brannoc's battle cry in the car", "mara", "please don't do it at the table" },
    { "sam", "bought new dice. they're green. they already roll badly", "jess", "a classic", dice = "jade" },   -- (his tray rolls them from now on)
    { "mara", "does anyone know if gnomes have middle names", "jess", "flitwidget absolutely has four" },
    { "dev", "work was so long today. thursday can't come fast enough", "sam", "same. i need dice in my hands" },
    { "jess", "i drew pip. it's bad. i'm sending it anyway", "mara", "it's PERFECT" },
    { "sam", "my cat sat on my character sheet and now oswin has a paw print", "dev", "that's canon now" },
    { "mara", "i've been reading about gorgons. for no reason", "jess", "for no reason. sure", when = { told = "gorgon" } },
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
      replies = { { label = "Only if Oswin can see who he's healing.", say = "only if oswin can see who he's healing", back = "fair", effects = { trust = 2 } },
                  { label = "I'll look it up and get back to you.", say = "i'll look it up and get back to you", back = "appreciate it", effects = { trust = 1, commitment = 1 } },
                  { label = "Sure, why not.", say = "sure, why not", back = "...ok cool", effects = { trust = -1, fun = 1 } } } },
    { id = "gorgon_strength", who = "dev", from = 2, when = { told = "gorgon" }, text = "@DM how strong is the gorgon. like on a scale of one to brannoc",
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
    { id = "brannoc_gorgons", who = "dev", from = 3, when = { told = "gorgon" }, text = "@DM would brannoc know anything about gorgons. soldier family and all",
      replies = { { label = "He's heard the stories.", say = "he's heard the stories. none of them end well", back = "nice. ominous", effects = { investment = 3 } },
                  { label = "Roll History when you get there.", say = "roll history when you get there", back = "rolling a 20 already", effects = { investment = 2 } } } },
}

-- The group chat about the rooms they just played (museum_week.write_chat): each entry is one friend's
-- take on something that happened there, said one of its ways (fresh across weeks), and only if it did
-- happen (`when`, as on moments; `won`/`lost`: the room's fight that session went that way). Never the
-- DM's card titles: what the friends saw, in their words. (The third playtest, alive 9: the chat was a
-- script, the same post after every hunting grounds, "good fight though" after they lost.)
-- What a friend says about something has to be something the party saw or learned (round three, B):
-- the sign only when they didn't use the water, the jugs only when the ritual worked, the lady only when
-- her painting was the one in the hall, the sunken city only once the notebook was read out.
M.chat = {
    street = { { who = "jess", when = { not_flag = "truth" }, "flitwidget is lying and i love him", "that gnome is hiding something and i respect it",
                 "flitwidget said incidents. INCIDENTS" },
               { who = "sam", "do we get a discount at the gift shop since we're the help", "is the help allowed in the gift shop",
                 "i want it known i was polite to the gnome" },
               { who = "mara", when = { flag = "truth" }, "a gorgon. in a jar. that BROKE. i have questions for flitwidget",
                 "so the jar broke and nobody thought to mention it on the poster" } },
    garden = { { who = "dev", won = true, "the topiary fight. ten out of ten", "i fought a hedge and won. put it on my headstone",
                 "brannoc vs the bushes, round one to brannoc" },
               { who = "mara", when = { seen = "mus_plaque", not_flag = "water" }, "the sign said use water. i'm thinking about that sign",
                 "still thinking about that sign by the pond" },
               { who = "jess", when = { mark = "garden_burned" }, "we set fire to a man's garden on our first night. iconic",
                 "in my defence the hedges started it" },
               { who = "sam", when = { flag = "water" }, "the water trick worked!! the sign was right", "pond water: underrated" },
               { who = "jess", when = { flag = "brass_key" }, "pip has a mystery key from a mystery pond and she's keeping it",
                 "what does the pond key open. i need to know" } },
    entrance = { { who = "jess", when = { seen = "mus_box", not_mark = "robbed" }, "i would like it on record that i only LOOKED at the box",
                   "the donation box and i have unfinished business" },
                 { who = "sam", when = { flag = "boon" }, "the statue said thank you. it was very loud", "best coin i ever spent. the statue was so polite" },
                 { who = "dev", when = { mark = "robbed" }, "we robbed a museum and a metal man fought us about it. good night",
                   "still thinking about that sentinel coming off its plinth" },
                 { who = "mara", when = { mark = "robbed" }, "we are thieves now. i'm writing it down", "so are we the baddies" } },
    -- (The measures only once the table's had them; a guardian calmed some other way is still a win.)
    chamber = { { who = "mara", when = { mark = "calmed", told = "ritual" }, "five gallons, three gallons, four gallons. i dreamt about jugs",
                  "we did the tablet's jug sums properly and i'm so proud of us" },
                { who = "mara", when = { mark = "calmed", not_told = "ritual" }, "the falcon jug was happy and the skeleton just stopped. we did that",
                  "still can't believe the jug thing worked" },
                { who = "dev", "three skulls is too many skulls", "that room was mostly sand and skulls and i loved it" },
                { who = "dev", when = { mark = "scarabs" }, "the guardian went down hard. worth it", "smashed the old guardian. no regrets. some regrets" },
                { who = "jess", when = { flag = "daggers" }, "the twin daggers are pip's now. legally", "pip has two daggers stuck together and she loves them" } },
    paintings = { { who = "jess", when = { seen = "mus_dice_painting" }, "WHO PAINTED US INTO THE PAINTING", "the painting of us. i'm not ok" },
                  { who = "mara", when = { flag = "portrait_mara" }, "the lady by the mountains. who is she", "i keep thinking about the lady by the mountains" },
                  -- (By how the knight got onto her card: left in its frame, or fought and got away. Round four's review
                  -- heard "we left the knight in its painting" after they'd fought it.)
                  { who = "dev", when = { mark = "knight", chose = { "mus_knight_frame", 1 } }, "the knight got away from us mid-fight and i will regret that",
                    "that knight ran off. it's going to be a problem later isn't it" },
                  { who = "dev", when = { mark = "knight", chose = { "mus_knight_frame", 2 } }, "we left the knight in its painting and i will regret that",
                    "that knight is going to be a problem later isn't it" },
                  { who = "sam", when = { flag = "paint" }, "a sword out of a painting. art is incredible", "the paint actually came off as a weapon. how" } },
    gift_shop = { { who = "jess", "telpur is my favourite character and he is a shoe", "telpur. the boot. i'd die for him", "a talking boot runs the till and nobody questions it" },
                  { who = "dev", "can i buy the marbles. just to own marbles", "telpur better have more stock next time", "telpur wouldn't haggle and i respect him" },
                  { who = "sam", when = { flag = "manual" }, "the mech manual is 400 pages and i've read 3", "chapter nine of the mech manual is just warnings" } },
    hunting = { { who = "sam", won = true, "those huntlings were smart. i hated it. good fight though", "the huntlings had a PLAN. rude",
                  "we beat the bug dogs and i'm still twitchy" },
                { who = "sam", lost = true, "those huntlings were smart. i hated it", "we got hunted. by bugs. i need a minute",
                  "the huntlings won that one and they know it" },
                { who = "dev", when = { mark = "pack" }, "we should've chased the ones that ran", "the ones that ran are going to come back. i can feel it" },
                { who = "mara", when = { mark = "mirror", told = "gorgon" }, "we are carrying a cupboard door around now. for reasons", "the mirror door is coming with us. trust the process" } },
    offices = { { who = "mara", when = { flag = "witness_city" }, "a city under the sea. the WITNESS. i have so many questions",
                  "the witness. under the sea. i can't stop thinking about it" },
                { who = "sam", when = { seen = "mus_office_inside", not_soft = "gore" }, "the eyes on his arms. not ok", "that office. i'm sleeping with the light on" },
                { who = "jess", when = { flag = "brass_key", seen = "mus_office_inside" }, "THE POND KEY OPENED THE DOOR", "told you the pond key was important" } },
    tomorrow = { { who = "dev", when = { mark = "mech" }, "WE HAVE A ROBOT", "we have a giant robot friend now. normal week" },
                 { who = "jess", when = { mark = "mech" }, "i'm calling it el roboto whatever its real name is", "the robot is called {mech} and i love {mech}" },
                 { who = "sam", when = { flag = "mech_burnt" }, "rip to the robot. we pressed the button", "we broke the robot. we broke flitwidget's robot" } },
    lecture = { { who = "sam", won = true, "that was my third period chemistry class", "a ghost who lectures. my worst nightmare and i beat it" },
                { who = "jess", "i fell asleep in real life a little", "the lecturer's voice is still in my head. send help" },
                { who = "mara", when = { mark = "pages" }, "we have pages that put people to sleep. this is the best item", "the sleepy notes are the most powerful thing we own" } },
    stairs = { { who = "dev", when = { not_flag = "rematch" }, "boss fight next week. finally", "next week we meet whoever's up there. i'm ready. i'm not ready" },
               { who = "mara", "something's been watching us this whole time hasn't it", "the curtain at the top of the stairs. i'm scared of a curtain" },
               { who = "jess", when = { flag = "seen" }, "pip met her eyes and came back. pip is fine. pip is not fine", "pip went up alone and i regret nothing. some things" } },
}
-- The group chat's very first night, before they've played: one of these, by the table's seed.
M.chat_intro = {
    { { "jess", "ok there's a MUSEUM in town and the guy running it is a gnome" }, { "mara", "a travelling museum of curiosities. i've already started a notebook" },
      { "dev", "are there monsters in it" }, { "jess", "dev it's a museum" }, { "dev", "so yes" }, { "sam", "i'll bring snacks. museum snacks" } },
    { { "mara", "has everyone seen the caravan by the market. the museum one" }, { "jess", "the travelling one? yes. obsessed" },
      { "dev", "is it haunted" }, { "mara", "it's a museum dev" }, { "dev", "that's not a no" }, { "sam", "snacks are on me this week" } },
    { { "sam", "so thursday. what are we playing" }, { "jess", "a GNOME has a MUSEUM in a CARAVAN" }, { "mara", "i already have questions about the gnome" },
      { "dev", "do i get to hit anything" }, { "jess", "probably the exhibits" }, { "dev", "sold" } },
}
-- A friend whose good news never came out on game night says it in the chat instead (the third
-- playtest, alive 14: "I'm saving it for the break", and nobody ever heard what it was).
M.chat_news = {
    mara = { "ok i never got to say it on thursday. I GOT INTO THE NIGHT COURSE", "forgot to tell everyone: night course. i'm in!!" },
    dev = { "forgot to say at the table. my sister had the baby!! photos incoming", "uncle dev. that's the news. uncle dev" },
    jess = { "nobody asked so i'm just saying it. I GOT THE PART", "the news i was saving: i got the part in the play!!" },
    sam = { "didn't want to interrupt the museum stuff but. i got the job", "the news from thursday: new job. starting monday" },
}

-- What each of the museum's people knows about the party (the DM runs them, so they remember):
-- the first ones that hold, as phrases for the talk card and their lines. when: as on moments.
M.memory = {
    mus_flitwidget = {
        { when = { mark = "robbed" }, text = "they robbed his donation box" },
        { when = { flag = "boon" }, text = "they dropped a coin in his donation box" },
        { when = { chose = { "mus_tidy", 1 } }, text = "they put his exhibits back" },
        { when = { chose = { "mus_return_paint", 1 } }, text = "they slid the paint back into his paintings" },
        { when = { mark = "mech" }, text = "they woke his Steam Mech" },
        { when = { flag = "truth" }, text = "they know what's really upstairs" },
        { when = { done = "street" }, text = "they said yes to his job" },
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
        -- (When it's over: the museum is his again. done: his first words; done_ask: when they ask about
        -- the reward, his answer to that, not the same words again: the second playtest review.)
        done = { warm = { "You did it. My museum! Quiet as a library. Have a biscuit. Have two." },
                 guarded = { "It's over. I'll be counting the exhibits for a week, mind." },
                 lie = { "I never doubted you for a moment. Well. One moment. Possibly two." } },
        done_ask = { warm = { "Your reward! {Gold_word} gold each, a pick from the shop, and my undying thanks." },
                     guarded = { "The reward. Yes. Once I've counted every exhibit. And the spoons." },
                     lie = { "Reward? Oh, the gold. Yes. And biscuits. Mostly biscuits." } },
        -- (The same, on a night a hero died: takeover.module_line, able.somber.)
        done_sad = { warm = { "You did it. I only wish it hadn't cost you so much." },
                     guarded = { "It's over. Sit down. I'll count the exhibits another day." },
                     lie = { "Nobody could have known it would come to this. Nobody." } },
        done_ask_sad = { warm = { "{Gold_word} gold each, and a pick from the shop. It doesn't seem enough, tonight." },
                         guarded = { "The reward. Yes. Later. When we've all had some tea." },
                         lie = { "Reward? Oh, it's all sorted. Don't you worry about the reward tonight." } },
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
        -- (Said after a friend's opening words to him as well as after something done well: round four's review
        -- heard "Splendid! Marvellous! I knew you had the look." answer "Just a few questions".)
        npc_good = { "Ha! I like you lot. I knew I would.", "Oh, you're good. You're very good.",
                     "Wonderful. You're exactly what this museum needed." },
        npc_bad = { "Now, now. Let's not upset the exhibits.", "That's... not how I would have done it. But it's done." },
        -- (After a death or a lost boss fight, seeing them again and praising them, quietly: night:npc_line
        -- asks "@sad" first. Round three's merge heard "My heroes! You're back! Tea?" after his grief.)
        npc_again_sad = { "Come in. Sit down, all of you.", "There you are. Come in. Mind the step.", "Come in, come in. Sit by the stove." },
        npc_good_sad = { "Thank you. That helps, tonight.", "That's kind. Thank you.", "Yes. Yes, that's right. Thank you." },
    },
    mus_telpur = {
        npc_greet = { "Wha? Oh! Customers. I was resting my laces. Welcome to the gift shop.", "Browse all you like. Whatever you break, you've bought." },
        npc_again = { "Back again? Lovely. Still no refunds.", "My favourite customers. Mind the marbles." },
        npc_good = { "Lovely choice. Very lovely. Can't take it back, mind.", "A customer with taste. Rare, round 'ere." },
        npc_again_sad = { "Come in. The shop's shut. Not to you.", "In you come. Quietly, now.", "Sit. Anywhere. Mind the marbles." },
        npc_good_sad = { "Ta. That's... ta.", "Good of you. Tonight especially.", "Thank you. Really." },
        npc_bad = { "Don't touch the marbles unless you're buying the marbles.", "I was a duke of the underworld, you know. I don't have to take this." },
    },
    mus_euryale = {
        npc_greet = { "Welcome. What a long way you've come.", "Come in. Sit. I've been listening to you all the way up." },
        npc_good = { "Oh, well done. Well done indeed.", "You're cleverer than the others were." },
        npc_bad = { "That was a mistake. A small one. You'll make bigger.", "Do you know how long I sat in that jar?" },
        npc_taunt = { "Look at me. Just for a moment.", "Every one of these statues was braver than you." },
        -- (Her last words as she falls: no victory taunt. The second playtest review.)
        npc_down = { "Tell my sisters... I kept a lovely house.", "So this is what my statues felt. How... quiet." },
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
    [3] = "The narrow stair. A smell of incense and wine. A curtain at the top, and someone humming behind it.",
}
-- The names the Steam Mech might have (the book's list).
M.mech_names = { "Hans", "Nevile", "Yukiko", "El Roboto", "Owen" }

return M
