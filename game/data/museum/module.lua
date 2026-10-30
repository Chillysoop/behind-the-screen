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
--   ending    (boss night) how it ends: fallen, bargain, escape, ally
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
          intro = "I've read about every wonder in the world. A museum with whole worlds inside it? I'm not missing that." },
        { id = "hermit", name = "Wonder", text = "After years with her books, other worlds behind a caravan curtain are too good to pass up.",
          room = "paintings", lean = 1, says = "Paintings of places that don't exist? Yes, please.",
          intro = "I've spent years with my books. Someone said there are other worlds behind that caravan's curtains. I want to see one." },
    },
    dev = {
        { id = "soldier", name = "Duty", text = "If something in that caravan is killing people, it's inside the town walls. That makes it Brannoc's problem.",
          room = "lair", lean = 2, says = "Point me at whatever's doing the killing.",
          intro = "I was a soldier. If something in that caravan is killing people in this town, it's my job to stop it." },
        { id = "folk_hero", name = "Rumour", text = "The taverns say the museum is dark magic. Somebody has to go and look, so Brannoc will.",
          room = "garden", lean = 1, says = "Dark magic. Sure. I'll bring an axe.",
          intro = "The taverns say the museum's dark magic. Somebody should go in and hit the dark magic. I volunteered." },
    },
    jess = {
        { id = "charlatan", name = "A con", text = "The gnome is running a con, and Pip isn't in on it. Unacceptable.",
          room = "street", lean = 2, says = "He's lying, and I want to know how good he is at it.",
          intro = "I know a con when I see one, and that gnome is running a good one. I want in." },
        { id = "criminal", name = "Lying low", text = "A doorway to another world is a lovely place to lie low for a while.",
          room = "gift_shop", lean = 1, says = "Somewhere nobody's looking for me? Sold.",
          intro = "I need somewhere to lie low for a bit. A whole other world behind a curtain? Perfect." },
    },
    sam = {
        { id = "acolyte", name = "Faith", text = "Rumour says some exhibits mock the gods. Oswin has been asked to take a look.",
          room = "chamber", lean = 2, says = "Somebody should check it's not blasphemous. Gently.",
          intro = "My temple asked me to look at the museum. Some of the exhibits might be, um, blasphemous. I'll be polite about it." },
        { id = "urchin", name = "A bad feeling", text = "The museum seems harmless. Oswin can't shake the feeling that it isn't.",
          room = "hunting", lean = 1, says = "Something's off about the whole thing. I'll keep an eye out.",
          intro = "Everyone says the museum's harmless. I grew up on the streets, and I've got a bad feeling about it." },
    },
}

-- What each player adds when they're all in at the first session's introductions (in place of the
-- old story's flourishes).
M.all_in = {
    mara = { "I've already started a notebook for the museum. Page one is just questions.", "I made Thessaly a library card. For a museum. I know." },
    dev = { "I sharpened Brannoc's greatsword. In my head. For an hour.", "His greatsword has a name. It's Ember." },
    jess = { "Pip has a lucky coin. It's not lucky. She stole it.", "Pip will be doing a voice for every exhibit. You've been warned." },
    sam = { "Oswin brought snacks for the museum. So did I.", "Oswin has a little prayer for doors. He says it at every door." },
}

-- What the heroes are in the prologue (replaces the old backstories while it runs).
M.heroes = {
    mara = { gist = "Thessaly, a wizard who wants to know everything", short = "Mysteries, reveals, notes. Long fights lose her." },
    dev = { gist = "Brannoc, a fighter who hits first", short = "Fights and cool weapons. Long talks lose him." },
    jess = { gist = "Pip, a rogue with sticky fingers", short = "Talking to NPCs in voice, and chaos. Don't cut her scenes short." },
    sam = { gist = "Oswin, a cleric who keeps everyone standing", short = "Friends, snacks, a fair clever fight. Don't put him on the spot." },
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
        read = "A quiet little shop at the foot of the stairs, and a boot asleep on the counter.",
        sum = "A rest, Telpur the talking boot, and somewhere to spend Flitwidget Francs. The book's place to stop for the night.",
        next = { "hunting" }, knobs = { "comedy" }, level = 3,
    },
    hunting = {
        name = "The Hunting Grounds", part = 2, type = "combat", cost = 2, at = { 50, 37 }, map = "Hunting Grounds",
        comps = { location = "mus_hunting", cast = "mus_huntlings", goal = "mus_hunt", complication = "mus_lure", reward = "mus_mirror" },
        encounter = { "kruthik_huntling", "kruthik_huntling", "kruthik_huntling", "kruthik_huntling", "kruthik_huntling" },
        boss_name = "the biggest huntling",
        read = "Up the stairs, a floor full of dioramas and stuffed beasts. It's messier up here, and something is watching.",
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
        read = "Between the studies, a narrow stair climbs toward a smell of smoke and wine.",
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
    },
    -- Not on the map: boss night's last scene, back downstairs, once she's dealt with (the book's
    -- ending, played as a scene so the finale is a whole evening and not one fight and a goodbye).
    thanks = {
        name = "Flitwidget's thanks", part = 3, type = "social", cost = 0, epilogue = true,
        comps = { location = "mus_gift_shop", cast = "mus_flitwidget", goal = "mus_settle_up", reward = "mus_thanks" },
        read = "Back down in the gift shop, Flitwidget has put out tea, a plate of biscuits and a very small cash box.",
        sum = "The reward, a pick from the shop, and what comes next.",
    },
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
    missed = "{names} {want} another look at {room}. Something in there got away from them.",
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
    mara = { painting = "a lady by an icy mountain road, looking straight out at Thessaly", gift = "nothing to take, only a question she can't stop thinking about" },
    dev = { painting = "a warrior in scarlet armour on a bridge, sword raised", gift = "the warrior's own blade, made of paint" },
    jess = { painting = "a smug duellist with a pistol in each hand", gift = "a painted pistol with one shot in it" },
    sam = { painting = "an empty golden throne with bats carved into it", gift = "a glass of something red that is definitely not wine" },
}

-- Room moments: the calls each room puts to the DM on game night. at: "start" (before the room's
-- fight or checks), "mid" (between), "end" (after). Rooms play them in this order.
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
            log = "\"You'll see!\" says Flitwidget, and shoos them up the steps. \"It's bigger on the inside, I promise!\"",
            effects = { { "arch:explorer", fun = 3 }, { "arch:storyteller", fun = 2 } } },
      } },

    -- The garden ----------------------------------------------------------------------------------
    { id = "mus_plaque", room = "garden", at = "start", type = "story", actor = { "explorer", "tactician", "storyteller" },
      title = "A sign by the pond",
      text = "{actor_char} finds a little iron plaque by the pond: \"Beware the bushes. In case of emergency, use water.\" Signed FF.",
      options = {
          { label = "Let them use the water. Douse the hedges.",
            log = "Helmets full of pond water hit the topiary. The hedges twist, sprout and root themselves to the spot.",
            effects = { { "actor", spotlight = 8 }, { "arch:explorer", fun = 5 }, { "arch:tactician", fun = 5 }, { "all", challenge = -4 } },
            mus = { francs = 1, drop = { "briar_beast" }, flag = "water" } },
          { label = "They're bushes. Set them on fire.",
            log = "Oil, a torch, and a whoosh. Half the garden goes up like kindling.",
            effects = { { "arch:butt_kicker", fun = 6 }, { "arch:instigator", fun = 4 }, { "arch:storyteller", fun = -2 }, { "all", challenge = -4 } },
            mus = { drop = { "briar_boar" }, mark = "garden_burned" } },
          { label = "Just fight them. Steel, not water.",
            log = "Blades out. The hedges come at them all at once.",
            effects = { { "arch:butt_kicker", fun = 4 }, { "all", challenge = 6 } } },
      } },
    { id = "mus_pond", room = "garden", at = "end", type = "story", actor = { "instigator", "explorer" },
      title = "The dark pond",
      text = "{actor_char} wants a closer look at the pond. They all saw the tentacles.",
      options = {
          { label = "Let them. They know what's in there.",
            roll = { dc = 10, skill = { "acrobatics", "athletics" }, convenient = "success",
                     success = { log = "{actor_char} dodges a tentacle and fishes out a little brass key. Nobody knows what it opens. Yet.",
                                 effects = { { "actor", spotlight = 8, fun = 5 } }, mus = { risk = true, francs = 1, aspect = "Fished a brass key out of a haunted pond" } },
                     fail = { log = "A tentacle wraps {actor_char}'s ankle and drags them in up to the waist. They come out cut and furious.",
                              effects = { { "actor", spotlight = 6, challenge = 4 } }, mus = { risk = true, harsh = true, aspect = "Was dragged into a haunted pond" } } } },
          { label = "\"Are you sure? It's got tentacles.\"",
            log = "{actor_char} thinks better of it. The pond burbles, disappointed.",
            effects = { { "arch:instigator", fun = -2 }, { "arch:casual", fun = 2 } }, mus = { warn = true } },
      } },

    -- The entrance hall -------------------------------------------------------------------------
    { id = "mus_box", room = "entrance", at = "start", type = "story", actor = { "instigator", "method_actor" },
      title = "The donation box",
      text = "A glass case of coins from every world: \"This museum relies on donations.\" {actor_char} looks at the case, then the lock, then the metal guard standing right there.",
      options = {
          { label = "Somebody drops a coin in.",
            log = "A coin clinks in. Something warm settles over the giver, and the statue booms: \"THANK YOU FOR YOUR DONATION.\"",
            effects = { { "arch:casual", fun = 4 }, { "arch:method_actor", fun = 2 }, { "all", reward = 4 } },
            mus = { francs = 1, flag = "boon", careful = 1, favor = { who = "flitwidget", n = 1 } } },
          { label = "Let {actor_char} try the lock. The guard is right there.",
            log = "Two picks, one click, and a sound like a forge waking up. The Sentinel steps down off its plinth.",
            effects = { { "actor", spotlight = 12 }, { "arch:instigator", fun = 8 }, { "arch:butt_kicker", fun = 4 }, { "arch:tactician", trust = -1 } },
            mus = { risk = true, fight = true, mark = "robbed", favor = { who = "flitwidget", n = -1 }, aspect = "Tried to rob a museum's donation box" } },
          { label = "Rein them in, out of character: \"Not this one.\"",
            log = "You give {actor_char} a look over the screen. They put the picks away, sulking.",
            effects = { { "actor", fun = -6, trust = -1 }, { "others", fun = 2 } } },
      } },

    -- The Chamber of Ancients ------------------------------------------------------------------
    { id = "mus_tablet", room = "chamber", at = "start", type = "story", actor = { "storyteller", "tactician", "explorer" },
      title = "The cracked tablet",
      text = "{actor_char} kneels by the cracked tablet with the little notebook of glyphs, while the guardian lifts its staff.",
      options = {
          { label = "Give them time. Someone holds it off while they work it out.",
            roll = { dc = 12, skill = { "history", "investigation", "religion" }, convenient = "success",
                     success = { log = "Five gallons in the falcon, three in the jackal, and the goddess wants exactly four. Pour, tip, pour, tip, and onto the pedestal.",
                                 effects = { { "actor", spotlight = 14 }, { "arch:storyteller", fun = 6, story = 6 }, { "arch:tactician", fun = 6 }, { "arch:butt_kicker", fun = -3 } },
                                 mus = { no_fight = true, mark = "calmed", francs = 1, careful = 1, aspect = "Calmed a tomb guardian with an old ritual" } },
                     fail = { log = "The glyphs swim. It's going to be blades.",
                              effects = { { "arch:butt_kicker", fun = 3 } }, mus = { fight = true, flag = "ritual_failed" } } } },
          { label = "Skip the homework. Fight it.",
            log = "Brannoc doesn't need a tablet. Weapons out.",
            effects = { { "arch:butt_kicker", fun = 6 }, { "arch:storyteller", fun = -3 }, { "arch:tactician", fun = -2 } },
            mus = { fight = true } },
      } },
    { id = "mus_falcon", room = "chamber", at = "mid", when = { flag = "ritual_failed" }, type = "screen", actor = { "instigator", "storyteller", "power_gamer" },
      title = "A discontented falcon",
      text = "As the guardian closes in, {actor_char} grabs the half-full falcon jar for the pedestal anyway. The tablet was very clear about what happens to anyone who gets it wrong.",
      options = {
          { label = "Let them. The tablet warned them.",
            log = "The pedestal flares. {actor_char} is flung across the room and lands hard, barely breathing.",
            effects = { { "actor", spotlight = 10, challenge = 8 }, { "arch:butt_kicker", fun = 3 } },
            mus = { risk = true, harsh = true, aspect = "Was flung across a tomb by an unhappy goddess" } },
          { label = "\"Are you sure? Read the last line again.\"",
            log = "{actor_char} reads it again, swears, and puts the jar down.",
            effects = { { "actor", fun = -2 }, { "arch:casual", fun = 2 } }, mus = { warn = true } },
      } },
    { id = "mus_tidy", room = "chamber", at = "end", type = "story", actor = { "casual", "tactician", "instigator" },
      title = "Put it all back?",
      text = "The chamber's a mess: jars, daggers, the tablet and the little notebook, scattered across the sand.",
      options = {
          { label = "They tidy up. Flitwidget will notice.",
            log = "Everything goes back on its plinth. A Franc materialises in {actor_char}'s pocket.",
            effects = { { "arch:casual", fun = 4 }, { "arch:butt_kicker", boredom = 4 } },
            mus = { francs = 1, careful = 1, favor = { who = "flitwidget", n = 1 } } },
          { label = "{actor_char} pockets the twin daggers.",
            log = "Two curved daggers, rings locked together through the hilts. They're not coming apart, but they're coming along.",
            effects = { { "actor", fun = 5, reward = 5 }, { "arch:storyteller", fun = -1 } }, mus = { flag = "daggers", aspect = "Kept two daggers that won't come apart" } },
          { label = "Leave it. Onward.",
            log = "They step over the mess and keep moving.", effects = {} },
      } },

    -- The Hall of Paintings --------------------------------------------------------------------
    { id = "mus_reach", room = "paintings", at = "start", type = "story", actor = { "explorer", "instigator", "method_actor" },
      title = "The paint is wet",
      text = "{actor_char} leans close to {painting}. The paint is wet, and frost glitters on the frame. A hand would go right in.",
      options = {
          { label = "Let them reach in. They've seen the frost.",
            roll = { dc = 12, skill = { "athletics", "acrobatics", "arcana" }, convenient = "success",
                     success = { log = "{actor_char} pulls out {gift}, still wet. It'll last about an hour out here.",
                                 effects = { { "actor", spotlight = 12, fun = 6, reward = 6 }, { "arch:explorer", fun = 4 } },
                                 mus = { risk = true, flag = "paint", francs = 1, aspect = "Pulled a weapon out of a painting" } },
                     fail = { log = "The painting bites. {actor_char} pulls back an arm numb to the elbow, empty-handed.",
                              effects = { { "actor", spotlight = 6, challenge = 5 } }, mus = { risk = true, harsh = true, aspect = "Got frostbite from a painting" } } } },
          { label = "\"Those frames are frosted for a reason.\"",
            log = "{actor_char} keeps their hands in their pockets. The painted figure looks almost disappointed.",
            effects = { { "arch:explorer", fun = -2 }, { "arch:casual", fun = 2 } }, mus = { warn = true } },
      } },
    { id = "mus_dice_painting", room = "paintings", at = "mid", when = { knob = "dice" }, type = "table", actor = { "method_actor", "instigator", "casual" },
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
    { id = "mus_knight_frame", room = "paintings", at = "mid", type = "story", actor = { "explorer", "butt_kicker", "instigator" },
      title = "The Knight of Shades",
      text = "At the end of the hall, the black knight's portrait. {actor_char} wants a closer look. Its oils seem to shift.",
      options = {
          { label = "Let them look. Whatever happens, happens.",
            log = "The knight grips the edge of its frame and climbs out, oil streaming off its armour.",
            effects = { { "arch:butt_kicker", fun = 5 }, { "arch:explorer", fun = 3 }, { "all", challenge = 6 } },
            mus = { fight = true, aspect = "Woke the Knight of Shades" } },
          { label = "They give it a wide berth.",
            log = "Nobody goes near it. The knight's painted eyes follow them all the way to the door.",
            effects = { { "arch:casual", fun = 3 }, { "arch:butt_kicker", fun = -4 } },
            mus = { no_fight = true, mark = "knight" } },
      } },
    { id = "mus_return_paint", room = "paintings", at = "end", when = { flag = "paint" }, type = "story", actor = { "casual", "tactician" },
      title = "Put the paint back?",
      text = "The painted weapons are starting to drip. {actor_char} could slide them back into their paintings before they melt.",
      options = {
          { label = "Put them back. It feels polite.",
            log = "Each one slides home. A Franc appears, and the duellist in the frame tips his hat.",
            effects = { { "arch:casual", fun = 3 } }, mus = { francs = 1, careful = 1, favor = { who = "flitwidget", n = 1 } } },
          { label = "Keep them till they drip away.",
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
            log = "Telpur sulks, but rings up the sale.",
            effects = { { "arch:butt_kicker", fun = 2 }, { "arch:method_actor", fun = -3 } } },
      } },
    { id = "mus_shopping", room = "gift_shop", at = "mid", type = "story", actor = { "power_gamer", "tactician", "storyteller" },
      title = "What do they buy?",
      text = "The party pools its Flitwidget Francs on the counter: {francs} of them. Telpur waits, laces twitching.",
      shop = true,
      options = {
          { label = "A scholar's book on gorgon-worshippers (6 Francs)", price = 6,
            log = "The Tenets of the Rotting Temple. Thessaly starts reading before they've left the shop.",
            effects = { { "arch:storyteller", fun = 6, story = 5 }, { "arch:butt_kicker", fun = -1 } },
            mus = { mark = "know", spend = 6, favor = { who = "telpur", n = 1 } } },
          { label = "The Mech Instruction Manual (6 Francs)", price = 6,
            log = "A thick manual with a lot of diagrams and one page in red: HYPER DESTROYER MODE.",
            effects = { { "arch:tactician", fun = 6 }, { "arch:power_gamer", fun = 4 } },
            mus = { flag = "manual", spend = 6, favor = { who = "telpur", n = 1 } } },
          { label = "Fire arrows and a bucket of slime (5 Francs)", price = 5,
            log = "Arrows that burn and slime that bites. Brannoc is very happy.",
            effects = { { "arch:butt_kicker", fun = 6 }, { "arch:power_gamer", fun = 4 } },
            mus = { flag = "arrows", spend = 5, favor = { who = "telpur", n = 1 } } },
          { label = "Save the Francs for later.",
            log = "They keep their Francs. Telpur is personally offended.",
            effects = { { "arch:tactician", fun = 1 }, { "arch:power_gamer", fun = -2 } } },
      } },

    -- The Hunting Grounds ---------------------------------------------------------------------
    { id = "mus_tracks", room = "hunting", at = "start", when = { knob = "marks" }, type = "story", actor = { "tactician", "explorer", "butt_kicker" },
      title = "Scratch marks",
      text = "Fresh scratch marks lead across the floor to the cave model. {actor_char} points out they're very easy to follow. Almost as if someone wanted them followed.",
      options = {
          { label = "Follow them anyway. They know it's bait.",
            log = "They follow the trail with weapons out. The huntlings spring the trap, and the party was ready for it.",
            effects = { { "arch:butt_kicker", fun = 5 }, { "all", challenge = 4 } }, mus = { risk = true } },
          { label = "Go round. Make the hunters come to them.",
            log = "They put their backs to the bulette's skull and wait. It's the huntlings who have to come out.",
            effects = { { "arch:tactician", fun = 6 }, { "arch:butt_kicker", fun = -1 } }, mus = { flag = "no_surprise" } },
      } },
    { id = "mus_mirror", room = "hunting", at = "end", type = "story", actor = { "tactician", "explorer", "storyteller" },
      title = "Polished doors",
      text = "In the kitchen diorama, the cupboard doors are polished to a mirror shine. {actor_char} could prise one off.",
      options = {
          { label = "Take one. You never know.",
            log = "{actor_char} unscrews a cupboard door and straps it to their pack. Nobody asks why. Someone should.",
            effects = { { "actor", spotlight = 6 }, { "arch:tactician", fun = 4 } }, mus = { mark = "mirror", aspect = "Carried a cupboard door upstairs to fight a Gorgon" } },
          { label = "Leave the exhibits alone.",
            log = "They leave the kitchen as they found it.", effects = { { "arch:casual", fun = 1 } }, mus = { careful = 1 } },
      } },

    -- The offices -----------------------------------------------------------------------------
    { id = "mus_whispers", room = "offices", at = "mid", when = { knob = "witness" }, type = "screen", actor = { "storyteller", "explorer", "casual" },
      title = "Whispers",
      text = "{actor_char} bends over the archivist's body, eyes carved all over its arms. A faint voice starts whispering, to them alone.",
      options = {
          { label = "Roll for it, behind the screen.",
            roll = { dc = 13, skill = { "insight", "religion" }, secret = true, convenient = "success",
                     success = { log = "{actor_char} shakes it off. Just the wind. Probably.", effects = { { "actor", fun = 2 } } },
                     fail = { log = "Something old learns {actor_char}'s name. You write it down for later.",
                              effects = { { "actor", story = 8, fun = 4 }, { "arch:storyteller", investment = 2 } }, mus = { flag = "whispered", aspect = "Heard the Witness whisper their name" } } } },
          { label = "Pass them a note: they hear it, and only they know.",
            log = "You slide a folded note across the table. {actor_char}'s player reads it, goes pale, and says nothing.",
            effects = { { "actor", story = 10, fun = 6 }, { "arch:storyteller", investment = 3 }, { "arch:casual", fun = -1 } },
            mus = { flag = "whispered", aspect = "Heard the Witness whisper their name" } },
      } },

    -- The World of Tomorrow -------------------------------------------------------------------
    { id = "mus_code", room = "tomorrow", at = "start", type = "puzzle", actor = { "tactician", "power_gamer", "storyteller" },
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
    { id = "mus_hyper", room = "tomorrow", at = "end", when = { mark = "mech" }, type = "story", actor = { "instigator", "power_gamer", "butt_kicker" },
      title = "Hyper Destroyer Mode",
      text = "{actor_char} has found the red page in the manual: \"Hyper Destroyer Mode. Only if absolutely necessary.\" They're grinning.",
      options = {
          { label = "Let them try it, here and now.",
            roll = { dc = 12, skill = { "arcana", "investigation" }, convenient = "success",
                     success = { log = "The Mech swells, missiles pop out of its shoulders, and it shuts itself down again before anything explodes. Impressive. Terrifying.",
                                 effects = { { "actor", fun = 8 }, { "arch:power_gamer", fun = 5 } }, mus = { risk = true } },
                     fail = { log = "It overheats with a shriek of steam and a smell of burnt clockwork. The Mech won't be walking anywhere now.",
                              effects = { { "actor", fun = 2 }, { "arch:tactician", fun = -4 } }, mus = { risk = true, harsh = true, unmark = "mech", flag = "mech_burnt", aspect = "Burnt out the Steam Mech" } } } },
          { label = "\"Save it for the Gorgon.\"",
            log = "{actor_char} folds the page down. For the Gorgon.",
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
    { id = "mus_alone", room = "stairs", at = "start", when = { flag = "pip_alone" }, type = "table", actor = { "instigator" },
      title = "It's what Pip would do",
      text = "While the others argue, {actor_char} slips up the stairs alone. \"It's what Pip would do,\" says Jess, already halfway out of her chair.",
      options = {
          { label = "Let it ride. Run her alone for a bit.",
            log = "Pip creeps up to the curtain, hears a calm voice say her name, and scrambles back down. Jess is delighted. Everyone else waited ten minutes.",
            effects = { { "actor", fun = 8, spotlight = 14 }, { "others", fun = -4, boredom = 8 } }, table_min = 10, mus = { risk = true, flag = "seen", aspect = "Went up the Gorgon's stairs alone" } },
          { label = "Rein her in, kindly, out of character.",
            log = "\"Pip can scout next week, with the group.\" Jess pouts, then laughs.",
            effects = { { "actor", fun = -4 }, { "others", fun = 3, trust = 1 } } },
          { label = "Let it cost her: Euryale is waiting.",
            log = "At the top of the stairs, bronze eyes. Pip comes back down very pale, and very quiet.",
            effects = { { "actor", fun = 2, challenge = 8 }, { "arch:storyteller", fun = 3 } }, mus = { risk = true, harsh = true, flag = "seen", aspect = "Met a Gorgon's eyes alone, and came back" } },
      } },

    -- Euryale's lair ---------------------------------------------------------------------------
    -- The knight they walked past climbs out of a frame behind her couch. Its paint is still wet,
    -- and the book's answer to him is paint (weapons out of a painting cut him like he's paper).
    { id = "mus_lair_frame", room = "lair", at = "mid", when = { mark = "knight" }, type = "story", actor = { "explorer", "butt_kicker", "tactician" },
      title = "The frame behind the couch",
      text = "The black knight steps out of a frame behind her couch, and the paint he left behind is still wet. {actor_char} could reach in for something to fight him with.",
      options = {
          { label = "Reach in. It's worth the chill.",
            roll = { dc = 12, skill = { "athletics", "acrobatics", "arcana" }, convenient = "success",
                     success = { log = "{actor_char} pulls out a painted blade, dripping. Paint cuts paint.",
                                 effects = { { "actor", spotlight = 10, fun = 5 }, { "arch:tactician", fun = 3 } },
                                 mus = { risk = true, flag = "paint", aspect = "Armed the party out of a Gorgon's own painting" } },
                     fail = { log = "The frame bites. {actor_char} pulls back numb fingers with nothing in them.",
                              effects = { { "actor", challenge = 5 } }, mus = { risk = true, harsh = true } } } },
          { label = "No time. Swords out.",
            log = "They draw steel. The knight's armour drinks the first blow like ink.",
            effects = { { "arch:butt_kicker", fun = 3 }, { "arch:explorer", fun = -2 } }, mus = { warn = true } },
      } },
}

-- Euryale's card: the marks the build-up leaves on it. why: what the party did. showdown: what it
-- changes on boss night. thought: what she thinks, upstairs, when it lands (her inner voice).
-- from: the rooms that can leave it at their end (the night's own bookkeeping, not a moment), for
-- the tie-and-lock editor's outs.
-- foe: a monster that joins her (count: how many). ally: one that fights for the party.
-- opt: a battle option (game/rules: mirror, averted, drowsy, paint). talk: easier (+) or harder
-- (-) to talk her round.
M.marks = {
    topiary = { name = "Topiary at her couch", why = "Briar Guardians left standing in the garden", from = { "garden" },
                showdown = "A Briar Beast fights beside her", foe = "briar_beast",
                thought = "One of my hedges is still standing. Come here, kitten." },
    garden_burned = { name = "She smelled the smoke", why = "They set her garden on fire",
                      showdown = "She skips the drink and the small talk", talk = -2,
                      thought = "Fire. How crude. I liked that garden." },
    robbed = { name = "Thieves, like her", why = "They tried to rob the donation box",
               showdown = "She offers them a cut", thought = "They tried the gnome's little money box. Oh, I like them already." },
    scarabs = { name = "Scarabs in the walls", why = "They smashed the Bone Construct", from = { "chamber" },
                showdown = "A scarab swarm joins her", foe = "giant_scarab_swarm",
                thought = "They smashed the old guardian. Its beetles are mine now." },
    calmed = { name = "One guard fewer", why = "They calmed the Bone Construct with the ritual",
               showdown = "Nothing comes up from below to help her", talk = 1,
               thought = "They did the water ritual properly. Nobody does it properly." },
    knight = { name = "A knight in a frame", why = "The Knight of Shades was never woken",
               showdown = "The Knight steps out of a painting in her lair", foe = "knight_of_shades",
               thought = "They walked straight past my knight. He'll keep." },
    pack = { name = "Her pack", why = "Kruthik Huntlings ran from the fight", from = { "hunting" },
             showdown = "The survivors hunt beside her", foe = "kruthik_huntling",
             thought = "The little hunters came running to me. Good dogs." },
    mirror = { name = "A mirror in their packs", why = "They took a polished cupboard door",
               showdown = "Her stare can be turned back on her", opt = "mirror",
               thought = "One of them took a cupboard door. Why would anyone take a door?" },
    know = { name = "They know what she is", why = "They read up on gorgons",
             showdown = "They know to look away, and about her sisters", opt = "averted",
             thought = "Someone downstairs is reading about my kind. How flattering. How annoying." },
    mech = { name = "A machine on their side", why = "They woke the Steam Mech",
             showdown = "The Mech fights for them, and she goes for its commander", ally = "steam_mech",
             thought = "The gnome's toy is walking about. It's pointed at me, isn't it." },
    drone = { name = "A drone through the floor", why = "The Lecturer is still lecturing", from = { "lecture" },
              showdown = "Everyone starts tired, and her charm bites harder", opt = "drowsy",
              thought = "The bore is still droning. They'll come up here half asleep." },
    pages = { name = "Sleeping pages", why = "They took the Lecturer's notes", from = { "lecture" },
              showdown = "A trick: get her to read one", thought = "They silenced the bore and kept his notes. Clever, or just tidy?" },
    careful = { name = "Careful hands", why = "They were gentle with the exhibits",
                showdown = "She's curious about them, and easier to talk round", talk = 2,
                thought = "They put my exhibits back where they found them. Who does that?" },
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
M.mark_order = { "topiary", "garden_burned", "robbed", "scarabs", "calmed", "knight", "pack", "mirror", "know", "mech", "drone", "pages", "careful" }
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
             "Upstairs, Euryale listens to the museum creak, and smiles." },
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
M.requests = {
    { id = "vorpal", who = "dev", after = "garden",
      ask = "real question. can brannoc find a vorpal sword in this museum",
      answers = {
          yes = { reply = "Telpur stocks one. It costs 40 Francs.", asker = 3, mus = { flag = "vorpal_price" } },
          laugh = { reply = "There's a vorpal spork in the gift shop. It's very sharp. For a spork.", asker = 0 },
          reason = { reply = "Not at level 2. But the knight in the paintings has a very nice greatsword.", asker = -1 },
          danger = { reply = "There is one. It's behind Euryale's couch.", asker = 2, mus = { warn = true, flag = "vorpal_lair" } },
      } },
    { id = "long_rest", who = "sam", after = "gift_shop",
      ask = "can we start next time with a proper rest in the gift shop? oswin is out of spells",
      answers = {
          yes = { reply = "Yes. You wake up fully rested. Telpur snored all night.", asker = 3, mus = { flag = "rested" } },
          laugh = { reply = "Yes, but Telpur talks in their sleep. About hell. In detail.", asker = 2, mus = { flag = "rested" } },
          reason = { reply = "Time's funny in the museum. A short rest, and on we go.", asker = -2 },
          danger = { reply = "You rest, and wake to find a statue at the foot of the stairs that wasn't there before.", asker = 1, mus = { flag = "rested", warn = true } },
      } },
    { id = "keep_boot", who = "jess", after = "gift_shop",
      ask = "can pip keep the boot. asking for pip",
      answers = {
          yes = { reply = "Telpur agrees to come along, as long as nobody wears them.", asker = 3, mus = { flag = "telpur_along" } },
          laugh = { reply = "Telpur gives Pip a shoelace. It still talks. It won't stop.", asker = 2 },
          reason = { reply = "Telpur's bound to the shop. Visiting hours only.", asker = -1 },
          danger = { reply = "Telpur comes along, and talks during every sneaky bit.", asker = 2, mus = { flag = "telpur_along", warn = true } },
      } },
    { id = "study", who = "mara", after = "offices", needs_flag = "notebook",
      ask = "can thessaly study the archivist's notebook this week? properly",
      answers = {
          yes = { reply = "She finds a line about the Witness that nobody else would have spotted.", asker = 3, mus = { flag = "studied" } },
          laugh = { reply = "It's mostly doodles of eyes. Hundreds of them. Some quite good.", asker = -1 },
          reason = { reply = "Not without someone who reads that script. Hold on to it for the campaign.", asker = 0 },
          danger = { reply = "She studies it, and the whispering starts again at night.", asker = 2, mus = { flag = "whispered", warn = true } },
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
            { label = "He slips them a bracelet of protection", mus = { mark = "know" } },
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
            { label = "Gossip: the Gorgon hates fire and loves an audience", mus = { warn = true } },
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
        ambush = { name = "She strikes from the shadows", blurb = "No talk. Her bow is already drawn when they reach the top step.",
                   like = { mara = -1, dev = 2, jess = -1, sam = -1 } },
    },
    styles = {
        yields = { name = "She yields near the end", blurb = "As the book allows: beaten badly enough, she asks to stop.",
                   like = { mara = 1, dev = -1, jess = 1, sam = 2 } },
        last = { name = "She fights to the last", blurb = "No mercy asked, none given.",
                 like = { mara = 0, dev = 2, jess = 0, sam = -1 } },
    },
    drink = {
        id = "mus_drink", type = "story", actor = { "method_actor", "instigator", "casual" },
        title = "A drink",
        text = "Euryale pours from a carafe of red wine. \"You all look so tired. Sit. Drink.\" {actor_char} reaches for a cup.",
        options = {
            { label = "{actor_char} drinks.",
              roll = { dc = 12, skill = { "insight", "religion" }, convenient = "success",
                       success = { log = "It's just very good wine. Euryale looks faintly impressed.", effects = { { "actor", fun = 4, spotlight = 6 } } },
                       fail = { log = "{actor_char} decides she's lovely, actually, and puts their weapon down.",
                                effects = { { "actor", fun = 2, spotlight = 8 }, { "others", challenge = 4 } }, mus = { flag = "charmed", risk = true, aspect = "Was charmed by a Gorgon, briefly" } } } },
            { label = "Nobody drinks.", log = "Untouched cups. Euryale sighs, as if they've hurt her feelings.",
              effects = { { "arch:tactician", fun = 3 }, { "arch:method_actor", fun = -2 } } },
        },
    },
    talk = {
        id = "mus_ultimatum", type = "story", actor = { "storyteller", "method_actor", "instigator" },
        title = "Join the collection",
        text = "Euryale sets down her cup. \"Here is your choice. Stay, as part of my collection. Or die.\" {actor_char} has one chance to answer.",
        options = {
            { label = "Weapons out.", log = "Steel answers for them. Euryale stands, smiling. \"As you like.\"",
              effects = { { "arch:butt_kicker", fun = 6 }, { "arch:storyteller", fun = -1 } }, mus = { fight = true } },
            { label = "Bargain: help her find her sisters.", needs = { mark = "know" }, alt_needs = { flag = "tapestry" },
              roll = { dc = 14, skill = { "persuasion", "insight" }, convenient = "success",
                       success = { log = "Her hood dips. \"Two clay jars, somewhere out there.\" She'd leave for that. She would.",
                                   effects = { { "actor", spotlight = 14, fun = 8 }, { "arch:storyteller", fun = 8, story = 8 }, { "arch:butt_kicker", fun = -3 } },
                                   mus = { ending = "bargain", aspect = "Talked a Gorgon into a bargain" } },
                       fail = { log = "\"You know nothing about my sisters.\" The hood comes down, a little.",
                                effects = { { "all", challenge = 6 } }, mus = { fight = true } } } },
            { label = "Offer her a cut of the donation box.", needs = { mark = "robbed" },
              roll = { dc = 13, skill = { "deception", "persuasion" }, convenient = "success",
                       success = { log = "\"Thieves after my own heart.\" She takes the coin, and the back curtain, and she's gone.",
                                   effects = { { "actor", spotlight = 12, fun = 8 }, { "arch:instigator", fun = 8 }, { "arch:storyteller", fun = 2 } },
                                   mus = { ending = "escape", aspect = "Paid a Gorgon to leave" } },
                       fail = { log = "\"You would rob your host twice?\" She laughs, and reaches for her bow.",
                                effects = { { "all", challenge = 6 } }, mus = { fight = true } } } },
            { label = "Hand her a page of the Lecturer's notes.", needs = { mark = "pages" },
              roll = { dc = 13, skill = { "deception", "sleight_of_hand" }, convenient = "success",
                       success = { log = "She reads the first line, frowns, and is asleep before the second. They carry her out through the black curtain.",
                                   effects = { { "actor", spotlight = 14, fun = 8 }, { "all", fun = 4 }, { "arch:butt_kicker", fun = -2 } },
                                   mus = { ending = "escape", flag = "slept", aspect = "Put a Gorgon to sleep with a lecture" } },
                       fail = { log = "She glances at the page and smiles. \"I have read this lecture. I was there.\"",
                                effects = { { "all", challenge = 6 } }, mus = { fight = true } } } },
            { label = "Talk her round. Ask what she really wants.", needs = { talk = 2 },
              roll = { dc = 15, skill = { "persuasion", "insight" }, convenient = "success",
                       success = { log = "For the first time, the calm slips. Out there was chaos; in here was safe. And lonely. \"Perhaps,\" she says, \"we need not fight.\"",
                                   effects = { { "actor", spotlight = 16, fun = 10 }, { "arch:storyteller", fun = 10, story = 10 }, { "arch:butt_kicker", fun = -4 } },
                                   mus = { ending = "ally", aspect = "Talked a Gorgon round" } },
                       fail = { log = "\"You do not get to know me.\" The calm comes back, colder.",
                                effects = { { "all", challenge = 6 } }, mus = { fight = true } } } },
        },
    },
    yield = {
        id = "mus_yield", type = "boss", actor = { "storyteller", "casual", "butt_kicker" },
        title = "\"Enough\"",
        text = "Bloodied, snakes hissing, Euryale lowers her bow. \"Enough. I yield. Let me go, and you'll never see me again.\"",
        options = {
            { label = "Let her go.", log = "She walks out through the black curtain without looking back.",
              effects = { { "arch:storyteller", fun = 6 }, { "arch:casual", fun = 4 }, { "arch:butt_kicker", fun = -3 } }, mus = { ending = "escape", aspect = "Let a Gorgon walk free" } },
            { label = "Make her a deal: her sisters, for her help.",
              log = "A long silence. Then a nod. \"For my sisters.\"",
              effects = { { "arch:storyteller", fun = 8, story = 6 }, { "arch:butt_kicker", fun = -2 } }, mus = { ending = "bargain" } },
            { label = "Finish it.", log = "Brannoc doesn't hesitate. It's over.",
              effects = { { "arch:butt_kicker", fun = 8 }, { "arch:storyteller", fun = -3 } }, mus = { ending = "fallen", aspect = "Ended Euryale" } },
        },
    },
}

-- How the prologue ends, by how they dealt with Euryale.
M.endings = {
    fallen = { name = "Euryale falls",
               line = "She shrinks as she falls, her skin peeling into strips that slither into the cracks. Only a purple robe, a white hood and an emerald bow are left.",
               flit = "\"Splendid! Though I doubt she's really gone. Gorgons rarely die properly.\"" },
    bargain = { name = "A bargain with a Gorgon",
                line = "Euryale leaves the museum with a promise: they'll look for two clay jars, and she'll owe them a favour.",
                flit = "\"A bargain? With her? Well. I suppose that's one way to tidy up.\"" },
    escape = { name = "Euryale slips away",
               line = "Euryale is gone through the black curtain, out into the world. The statues in the lair start to soften back into people.",
               flit = "\"Out? Well, as long as she's out of my museum. Mostly that's what I wanted.\"" },
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
    mara = { "Okay, the Witness. A sunken city. I need to know. When's the campaign?", "That was a prologue? I've already got a notebook for the campaign." },
    dev = { "Same heroes, bigger fights? I'm in. Every Thursday.", "Level 4 and a gnome with a caravan. Let's go." },
    jess = { "Pip is keeping the gnome. Pip is keeping everything. Campaign. Now.", "I want to see where the caravan goes next." },
    sam = { "That was so much fun. Same time next week? For the real thing?", "I'll bring snacks for the whole campaign. That's a promise." },
}

-- The group chat between sessions: what the friends say about the room they just played.
M.chat = {
    street = { jess = "flitwidget is lying and i love him", sam = "do we get a discount at the gift shop since we're the help" },
    garden = { dev = "the topiary fight. ten out of ten", mara = "the sign said use water. i'm thinking about that sign" },
    entrance = { jess = "i would like it on record that i only LOOKED at the box", sam = "the statue said thank you. it was very loud" },
    chamber = { mara = "five gallons, three gallons, four gallons. i dreamt about jugs", dev = "three skulls is too many skulls" },
    paintings = { jess = "WHO PAINTED US INTO THE PAINTING", mara = "the lady by the mountains. who is she" },
    gift_shop = { jess = "telpur is my favourite character and they are a shoe", dev = "can i buy the marbles. for throwing" },
    hunting = { sam = "those huntlings were smart. i hated it. good fight though", dev = "we should've chased the ones that ran" },
    offices = { mara = "a city under the sea. the WITNESS. i have so many questions", sam = "the eyes on his arms. not ok" },
    tomorrow = { dev = "WE HAVE A ROBOT", jess = "i'm calling it el roboto whatever its real name is" },
    lecture = { sam = "that was my third period chemistry class", jess = "i fell asleep in real life a little" },
    stairs = { dev = "boss fight next week. finally", mara = "she's been watching us this whole time hasn't she" },
}

-- The DM's NPC lines, for game night's dialogue (game/model/dialogue.lua cells). speaker: the
-- cast card. trigger: npc_greet, npc_good, npc_bad, npc_taunt, npc_down.
M.npc_lines = {
    mus_flitwidget = {
        npc_greet = { "Welcome, welcome! Closed, I'm afraid. Temporarily. Ish.", "Ah! Adventurers! You have the look. The look of people who need money." },
        npc_good = { "Splendid! Marvellous! I knew you had the look.", "Oh, you're good. You're very good. Do you want a job? You have a job." },
        npc_bad = { "Now, now. Let's not upset the exhibits.", "That's... not how I would have done it. But it's done." },
    },
    mus_telpur = {
        npc_greet = { "Oh, bloody 'ell, fell asleep again. Welcome to the gift shop.", "Browse all you like. No refunds. Boss's orders." },
        npc_good = { "Lovely choice. Very lovely. Can't take it back, mind.", "A customer with taste. Rare, round 'ere." },
        npc_bad = { "Don't touch the marbles unless you're buying the marbles.", "I was a duke of the underworld, you know. I don't have to take this." },
    },
    mus_euryale = {
        npc_greet = { "Welcome. You all look so tired.", "Come in. Sit. I've been listening to you all the way up." },
        npc_good = { "Impressive. Very impressive.", "You're cleverer than the others were." },
        npc_bad = { "That was a mistake. A small one. You'll make bigger.", "Do you know how long I sat in that jar?" },
        npc_taunt = { "Look at me. Just for a moment.", "Every one of these statues was braver than you." },
        npc_down = { "Not... impressive enough.", "This is not over. It is never over, for my kind." },
    },
    mus_lecturer = {
        npc_greet = { "...and so, as I was saying, the history of soil...", "Sit. Sit. We are only on chapter forty." },
        npc_taunt = { "Settle down at the back.", "There will be a test." },
        npc_down = { "Class... dismissed...", "But I haven't... set the homework..." },
    },
}

-- What the night opens with, by part of the museum (the read-aloud before the first room).
M.openings = {
    [1] = "Everyone in town is talking about the new museum. The merchants were amazed. The guards were terrified. The children won't stop giggling.",
    [2] = "The gift shop door clicks shut behind them. Up the stairs, the museum gets untidier, and quieter.",
    [3] = "The narrow stair. A smell of smoke and wine. A curtain at the top, and someone humming behind it.",
}
-- The names the Steam Mech might have (the book's list).
M.mech_names = { "Hans", "Nevile", "Yukiko", "El Roboto", "Owen" }

return M
