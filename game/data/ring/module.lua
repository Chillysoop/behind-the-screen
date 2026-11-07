-- Welcome to the Ring: Aurum 80, a forgotten sector of the Iron Ring, in the adventure standard
-- (docs/design/adventure-standard.md). Adapted from the starting adventure in the Death in Space core rules by Christian
-- Plogfors and Carl Niblaeus (Free League, 2021), pp. 78-91, for private playtesting. Pages are the book's printed
-- numbers. Every word here is ours, never the book's; tools/import/copy_check.py holds us to it.
--
-- It plays by the Death in Space rule set (game/rules/sets/dis.lua): a d20 and an ability against 12, void points for
-- every miss. The crew are four new characters, one for each friend, and their hub is a broken spacecraft they've just
-- spent their last holos on: the Brittle Star, at airlock 13C. The book gives no fixed way through (p. 79): the crew has
-- a broken hub, no fuel, a debt, two gangs pulling at them, and four hours before the sector's ringleader arrives.
-- `ours = true` marks what the game adds; `call` marks a question for Conner.

local M = {}

M.id = "ring"
M.title = "Welcome to the Ring"
M.rules = "dis"          -- (its rule set: docs/design/rule-sets.md)
M.author = "Christian Plogfors and Carl Niblaeus"
M.credit = "Adapted from Welcome to the Ring, the starting adventure in Death in Space by Christian Plogfors and Carl "
    .. "Niblaeus (Free League Publishing), for private playtesting."
M.MAX_WEEKS = 2
M.BUDGET = 10
M.pitch = "A broken spacecraft, no fuel, a debt, and two gangs about to go to war on a rusting space station. "
    .. "A short adventure: a session or two."
M.premise = {
    "Aurum 80 is a forgotten corner of the Iron Ring's Aurum sector, once the last stop for miners heading down to "
        .. "Inauro. Now its people save every holo for a ticket out, or spend it on non-phys dreams (p. 78).",
    "Two ring gangs share it: the Passel, who control the sector's output power, and Parliament, who run the computers "
        .. "that keep its air and water going. Their leaders, Roy Mirra and Monotone Tynall, were best friends once (p. 78).",
    "The crew has just bought a spacecraft cheap, docked at airlock 13C. It's cheap because it's broken, out of fuel, "
        .. "and 500 holos in docking fees behind, a debt now held by a salvaging crew (p. 78).",
    "The sector's ringleader, Suro \"Thorn\" Ragosa, is on the next shuttle with a gang of thugs, four hours out, coming "
        .. "to settle the gangs' quarrel her own way (p. 79).",
    "Either gang leader can get the hub repaired in three hours, for a favor. Hina Tsurutsuru, who runs the Tsurutsuru "
        .. "bar, can sell fuel, or give it to anyone who'll fly her out (pp. 79, 83).",
}

M.follows = { any = true }
M.handoff = {
    arrive = "dock",
    say = { "The shuttle doors grind open on Aurum 80's docking bay. Somewhere behind a heap of junk is airlock 13C, and "
                .. "behind that, the spacecraft you've just spent your last holos on." },
}
-- What the crew can keep (ours: the book leaves it open, p. 79).
M.keeps = {
    { id = "the_hub", text = "The Brittle Star, patched up and fuelled: a hub of their own", when = { flag = { "repaired", "fuelled" } } },
    { id = "hina_owes", text = "Hina Tsurutsuru, and the start of a simple life somewhere warm, thanks to them", when = { flag = "hina_aboard" } },
    { id = "roy_friend", text = "Roy Mirra's word, and the Passel's farm", when = { flag = "roy_deal_done" } },
    { id = "monotone_friend", text = "Monotone Tynall's favor, and a back way into Aurum's computers", when = { flag = "monotone_deal_done" } },
    { id = "the_debt", text = "A 500-holo debt the salvaging crew still means to collect", when = { not_flag = "debt_settled" } },
}
M.money = { coins = { "holos" }, note = "Holos for everything: a night in a bed capsule, a pint, a docking fee (p. 2)." }

-- The crew: four new characters, one for each friend, made by the book's steps (pp. 12-23): abilities, origin and its
-- benefit, background, trait, drive, looks, past allegiance, hit points, defense rating, a kit and a trinket. Each
-- suits the friend who plays it.
M.heroes = {
    mara = {
        char = "Ilse Varrow", pronouns = "she", mini = "crew_ilse", class = "translator", class_name = "Static noise translator",
        hello = { "Okay! I'm Mara, and I'm playing Ilse Varrow. She translates static. It's a whole thing.", "Me first. I'm Mara. This is Ilse: velocity cursed, hears voices in the noise, keeps a notebook nobody else can read." },
        gist = "Ilse Varrow, a velocity-cursed translator who hears voices in the static",
        short = "Mysteries, reveals, notes. Long fights lose her.",
        intro = "Velocity cursed: Ilse flickers at the edges when she's tired, and remembers places she's never been.",
        sheet = { bdy = -1, dex = 0, svy = 3, tec = 1, hp = 5, dr = 12 },
        origin = { name = "Velocity cursed", page = 13, benefit = "Future memory: once a session, she can ask the DM the way." },
        background = "Static noise translator", trait = "Eccentric", drive = "Secrets about the end",
        looks = "Hologlasses a size too small, and a face that glitches at the edges",
        allegiance = "An idea: through the whole Gem War she kept to her work and away from the fighting",
        kit = { "a tablet computer", "a translator that gets most languages", "a light EVA suit" },
        trinket = "A weatherproof notebook full of symbols nobody else can read",
        weapons = { { name = "Pistol", uses = 5, damage = "1d6", ranged = true } },
    },
    dev = {
        char = "Brask Hollin", pronouns = "he", mini = "crew_brask", class = "driller", class_name = "Asteroid driller",
        hello = { "I'm Dev. This is Brask Hollin. Driller. Big rifle. Fixes things by hitting them.", "Dev. Playing Brask. He's old, he's carbon, and he will not lose." },
        gist = "Brask Hollin, a carbon driller who fixes things, mostly by hitting them",
        short = "Fights and cool weapons. Long talks lose him.",
        intro = "Carbon: grown in a womb out past the belt, and happier in an EVA suit than out of one.",
        sheet = { bdy = 3, dex = 0, svy = -2, tec = 2, hp = 8, dr = 12 },
        origin = { name = "Carbon", page = 13, benefit = "Gearhead: he repairs things twice as fast." },
        background = "Asteroid driller", trait = "Too old for any of this", drive = "To never lose",
        looks = "Bullet scars, and a few metal splinters nobody ever dug out",
        allegiance = "The losing side: he lived through it, and it cost him",
        kit = { "an electric multi-tool", "a fusion welder", "duct tape", "a battered raid rifle" },
        trinket = "A wrench with a name engraved on the handle, not his",
        weapons = { { name = "Raid rifle", uses = 10, damage = "1d10", ranged = true }, { name = "Wrench", damage = "1d4" } },
    },
    jess = {
        char = "Mox Calloway", pronouns = "she", mini = "crew_mox", class = "swindler", class_name = "Gravity swindler",
        hello = { "I'm Jess, and I'll be doing a voice. Several voices. This is Mox Calloway.", "Jess! Playing Mox. She wears a mask, she has a voice scrambler, and she is not to be trusted." },
        gist = "Mox Calloway, a masked void swindler with a voice for every occasion",
        short = "Talking to NPCs in voice, and chaos. Don't cut her scenes short.",
        intro = "Void: robes, a mask, a voice through a scrambler, and visions of the edge of everything she doesn't talk about.",
        sheet = { bdy = -1, dex = 3, svy = 2, tec = -1, hp = 6, dr = 15 },
        origin = { name = "Void", page = 13, benefit = "Masked: overnight she can reshape her mask into someone else's face. From a distance, it fools most people." },
        background = "Gravity swindler", trait = "Passionate", drive = "Free will",
        looks = "A suit with holographic patterns under the robes",
        allegiance = "The contract: whoever paid best, on any side",
        kit = { "lockpicks", "a deck of holographic playing cards", "a voice scrambler" },
        trinket = "A small toy figure of herself, in a different mask every time anyone looks",
        weapons = { { name = "Pistol", uses = 5, damage = "1d6", ranged = true }, { name = "Knife", damage = "1d4" } },
    },
    sam = {
        char = "Pell Abernathy", pronouns = "he", mini = "crew_pell", class = "vagabond", class_name = "Orbit vagabond",
        hello = { "Sam. I'm playing Pell. He's a punk who grows plants. That's... yeah.", "I'm Sam. This is Pell Abernathy. He'll feed everyone. Even the robot." },
        gist = "Pell Abernathy, a punk vagabond who can grow dinner anywhere and feeds everyone",
        short = "Friends, snacks, a fair clever fight. Don't put him on the spot.",
        intro = "Punk: he's watched a few civilizations fall over, and kept his garden going through all of them.",
        sheet = { bdy = 1, dex = -1, svy = 2, tec = 0, hp = 7, dr = 11 },
        origin = { name = "Punk", page = 13, benefit = "Green thumb: he knows plants and what they're good for, and carries a pocket greenhouse." },
        background = "Orbit vagabond", trait = "Optimist", drive = "Friends",
        looks = "Patches all over his jacket saying how much he loves plants",
        allegiance = "Family: he stayed with his own and kept them fed",
        kit = { "a liquid purifier", "a hover hammock", "a box of spices", "incense" },
        trinket = "A music box with a little holographic galaxy turning inside",
        weapons = { { name = "Hammer", damage = "1d4" } },
    },
}
-- Who takes a fallen hero's place (the book: a new character joins the crew as soon as they can, p. 54). Ours.
M.pregens = {
    mara = { { id = "ri_juna", name = "Juna Ferro", pronouns = "she", intro = "hired", mini = "npc_stranger",
               class = "signal_tech", class_name = "Signal technician",
               hook = "The Brittle Star's last comms tech, who left in a hurry and wants to know what she left behind.",
               sheet = { bdy = 0, dex = 1, svy = 2, tec = 2, hp = 5, dr = 13 }, weapons = { { name = "Pistol", uses = 5, damage = "1d6", ranged = true } } } },
    dev = { { id = "ri_okke", name = "Okke Brandt", pronouns = "he", intro = "hired", mini = "npc_stranger",
              class = "hull_welder", class_name = "Hull welder",
              hook = "A welder from the docking bay's repair shops, owed a favor by the dead and calling it in.",
              sheet = { bdy = 3, dex = -1, svy = 0, tec = 1, hp = 7, dr = 11 }, weapons = { { name = "Fusion cutter", damage = "1d4" } } } },
    jess = { { id = "ri_vesper", name = "Vesper Quill", pronouns = "they", intro = "rescued", mini = "npc_stranger",
               class = "card_sharp", class_name = "Card sharp",
               hook = "A card sharp the crew pulled out of a bad game at the Tsurutsuru, who owes them a life.",
               sheet = { bdy = -1, dex = 3, svy = 1, tec = 0, hp = 5, dr = 15 }, weapons = { { name = "Knife", damage = "1d4" } } } },
    sam = { { id = "ri_tamsin", name = "Tamsin Reed", pronouns = "she", intro = "sibling", mini = "npc_stranger",
              class = "farm_hand", class_name = "Farm hand",
              hook = "A hand off Roy's farm who knew the dead from the fruit stalls, and won't hear of them going alone.",
              sheet = { bdy = 2, dex = 0, svy = 1, tec = -1, hp = 7, dr = 12 }, weapons = { { name = "Hammer", damage = "1d4" } } } },
}

-- Why each of them came aboard (ours: the book's crew come for a hub of their own, p. 78).
M.hooks = {
    mara = { { id = "signal", name = "A voice in the static", ours = true, room = "computer_center",
               text = "Ilse has been hearing the same broken signal in the static for weeks, and it's loudest near Aurum 80.",
               intro = "There's a pattern in the static out here. I want to know who's talking.",
               payoff = "Deep in Aurum's server racks, the signal she's been chasing is a stuck memory, playing over and over." } },
    dev = { { id = "fly", name = "Make it fly", ours = true, room = "hub",
              text = "Brask bought into the Brittle Star because nothing he's ever owned has flown.",
              intro = "It's a wreck. It's our wreck. Give me a welder and an afternoon.",
              payoff = "The Brittle Star's engine coughs, catches, and holds: Brask's hands on the controls." } },
    jess = { { id = "marks", name = "A fresh crowd", ours = true, room = "common",
               text = "Mox needs a new name and a new crowd, and Aurum 80 has never heard of her.",
               intro = "New station, new face, new name. Nobody here owes me money yet.",
               payoff = "Half the Tsurutsuru knows Mox by a name that isn't hers, and likes her." } },
    sam = { { id = "garden", name = "A garden", ours = true, room = "engine_room",
              text = "Pell heard there's a real farm somewhere in Aurum 80, and he hasn't seen green in months.",
              intro = "Somebody here grows real fruit. I'm going to find them and be their friend.",
              payoff = "A jungle in an engine hall, gone dry, and Pell already knows what it needs." } },
}

-- Content the table might want kept off screen or out (Session Zero's lines and veils, by tag and place).
M.content = {
    drugs = { common = "people high on non-phys and Hola! in every corner",
              computer_center = "addicts dreaming on the floor, and one who overdoses" },
    body_horror = { hub = "what the void can leave on a body: an extra eye, a darkness that moves under the skin" },
    murder = { dock = "a murder in an alleyway, and the killer running past" },
}
M.content_names = { drugs = "drug use", body_horror = "body horror", murder = "murder" }

M.session_zero = {
    pitch = "What should Aurum 80 feel like?",
    told = "You've told them the premise: a broken spacecraft of their own, docked on a rusting space station, and "
        .. "no money left.",
    tones = {
        grim = { name = "Grimy and dangerous", blurb = "The book's own feel: rust, debt, and everyone out for themselves.",
                 says = { mara = "Bleak, but with secrets in it. I can work with bleak.", dev = "Dangerous? Good. I'm bored of safe.",
                          jess = "Grimy is where the best cons are.", sam = "As long as somebody eats properly." } },
        western = { name = "A space western", blurb = "A frontier town in orbit: gangs, a bar, a showdown when the shuttle lands.",
                    says = { mara = "A western with a mystery at the bottom of it. Yes.", dev = "Showdown at the airlock. Sold.",
                             jess = "I want a saloon. I want to be thrown out of the saloon.", sam = "A western. I'll bring the beans." } },
        horror = { name = "Cosmic horror", blurb = "Something out in the dark is watching, and every miss lets it closer.",
                   says = { mara = "Yes. The void should feel like it's listening.", dev = "Horror's fine if I can shoot it.",
                            jess = "Can Mox still be charming while the void stares?", sam = "Not too scary, please. I'm here to unwind." } },
        comedy = { name = "A comedy of errors", blurb = "A wreck of a ship, a talking comms system, and nobody with a plan.",
                   says = { mara = "Then nobody minds what's in the static.", dev = "Comedy with fights in it?",
                            jess = "I was born for this.", sam = "Low stress. I can do low stress." } },
    },
    asks = {
        sam = { kind = "veil", content = "drugs",
                text = "People can be high in it, but don't describe anyone overdosing. Fade it out?",
                agree = { label = "We'll keep that off screen.", reply = "Thanks. That's all I needed." },
                push = { label = "It's part of the setting. Let's see.", reply = "Okay. I'll look away if I have to." } },
        mara = { kind = "line", content = "body_horror",
                 text = "No body horror on our characters. The void can be creepy, but nothing growing out of us.",
                 agree = { label = "Agreed. That's a line.", reply = "Thank you. That one matters." },
                 push = { label = "Can it happen to someone else?", reply = "Someone else, fine. Not us." } },
        jess = { text = "Let Mox talk to everyone. Don't cut my scenes short to get to a fight.",
                 agree = { reply = "YES. Mox has a voice for every single one of them." } },
    },
}
M.prep_notes = {
    dock = { voices = { "Ezra Pascal: a charming salvage captain who's very sorry about the debt" } },
    hub = { voices = { "the Brittle Star's comms: far too cheerful, and it has opinions" } },
    common = { voices = { "Hina Tsurutsuru: sharp, warm, always doing business" } },
    engine_room = { voices = { "Roy Mirra: friendly, with a very short fuse" } },
    computer_center = { voices = { "Monotone Tynall: flat, lonely, and about to do something rash" } },
    shuttle = { voices = { "Suro Ragosa: tired of everyone, and quick to shoot" } },
}

-- Where the crew can go next from the docking bay (museum_night.fork).
M.forks = { hub = { title = "Where now?", text = "The airlock to the Brittle Star, the bar in the machine, and the way up into the station." } }
M.fork_at = {
    dock = { text = "Airlock 13C behind its junk, the plaza with the bar in the drilling machine, and the elevators up into Aurum 80." },
    hub = { text = "Back out through the airlock into the docking bay: the bar in the machine, and the elevators." },
    bar_machine = { text = "The elevators up to the common area, the stairs down to the engine room, and the corridor to the computer center." },
    common = { text = "Down to the engine room and the Passel, or along to the computer center and Parliament." },
}
M.pull = {
    hub = { label = "Through airlock 13C, into the Brittle Star", want = "to see what they've bought", tags = { "explore", "cozy", "funny" } },
    bar_machine = { label = "To the bar in the drilling machine", want = "to find someone who knows things", tags = { "social", "rumours" } },
    common = { label = "Up to the common area and the Tsurutsuru", want = "to find Hina and her fuel", tags = { "social", "deal" } },
    engine_room = { label = "Down to the engine room and the Passel", want = "to find Roy Mirra", tags = { "social", "deal" } },
    computer_center = { label = "Along to the computer center and Parliament", want = "to find Monotone Tynall", tags = { "mystery", "deal" } },
}

-- Places ------------------------------------------------------------------------------------------------------------
M.places = {
    { id = "aurum80", name = "Aurum 80", layer = "site", pages = { 78 },
      read = "A rusting space station on the Iron Ring, a forgotten corner of the Aurum sector above the planet Inauro.",
      lore = "During the Gem Rush, the last stop for miners on their way down. Now its people are stuck, saving for a cryo "
          .. "ticket out or spending every holo on non-phys." },
    { id = "dock", name = "The docking bay", layer = "area", ["in"] = "aurum80", pages = { 80, 81 },
      read = "A metal shantytown with no plan to it. Work lights swing on chains far overhead, water drips everywhere, and "
          .. "faded letters on the floor still point the way to somewhere.",
      spots = { "airlock_13c", "junk", "repair_shops", "containers", "timer", "plaza", "airlocks" },
      exits = { { to = "hub", by = "airlock 13C" }, { to = "bar_machine" }, { to = "common", by = "the elevators" },
                { to = "shuttle", gates = { flag = "ragosa_here" } } },
      scene = { type = "social", setting = { "indoor" }, sum = "A broken hub, a debt, and a clock counting down.",
                cast = "ri_ezra", cast_line = false,
                goal = { name = "Arrival", aim = "find their hub and get their bearings", short = "find the hub",
                         line = "Goal: find airlock 13C and the spacecraft behind it.",
                         win = "They've found their hub, and they know what they owe.",
                         win_if = { { when = { flag = "debt_settled" }, text = "They've found their hub, and the salvagers are off their backs for now." } },
                         lose = "They've found their hub, and the salvagers want paying.", got = "a spacecraft of their own, sort of" } } },
    -- The hub: the crew's spacecraft, the Brittle Star (ours, made by the hub steps, pp. 26-33).
    { id = "hub", name = "The Brittle Star", layer = "area", ["in"] = "aurum80", pages = { 26, 27, 30, 33, 80 },
      read = "A cramped old spacecraft, dark but for its emergency lights: a command center full of loose cables, four bunks in "
          .. "the crew quarters, a mess with one long table, life support wheezing, and a cold engine at the back.",
      spots = { "command_center", "comms", "quarters", "mess", "life_support", "engine", "fuel_tank", "airlock" },
      exits = { { to = "dock", by = "airlock 13C" } },
      scene = { type = "exploration", quick = true, setting = { "indoor" }, sum = "Their own spacecraft: what's broken, and who's still aboard.",
                cast = "ri_comms", cast_line = false,
                goal = { name = "The Brittle Star", aim = "find out what's wrong with their hub", short = "look the hub over",
                         line = "Goal: find out how broken the Brittle Star really is.",
                         win = "They know what the Brittle Star needs: a repair crew, and fuel.",
                         win_if = { { when = { flag = "repaired", not_flag = "fuelled" }, text = "The Brittle Star is fixed. It just needs fuel." },
                                    { when = { flag = { "repaired", "fuelled" } }, text = "The Brittle Star is ready to fly." } },
                         lose = "Something's very wrong with the Brittle Star, and they can't tell what.", got = "a look at their hub" } } },
    { id = "bar_machine", name = "The bar in the machine", layer = "area", ["in"] = "aurum80", pages = { 80 },
      read = "A plaza in the middle of the docking bay, round an old drilling machine someone has made into a tiny bar serving "
          .. "water and sake. A tarp keeps the drips off.",
      spots = { "drill_bar", "tarp", "stools", "old_friend", "alley" },
      exits = { { to = "common", by = "the elevators" }, { to = "engine_room", by = "the stairs down" },
                { to = "computer_center", by = "the corridor" }, { to = "dock" } },
      scene = { type = "social", quick = true, setting = { "indoor" }, sum = "An old friend, and everything people are saying.",
                cast = "ri_friend", cast_line = false,
                goal = { name = "The bar in the machine", aim = "hear what's going on in Aurum 80", short = "hear the news",
                         line = "Goal: find out who can help with a broken hub.",
                         win = "They know who can fix the hub, who sells fuel, and who's coming on the next shuttle.",
                         lose = "They leave with more questions than they came with.", got = "the news" } } },
    { id = "common", name = "The common area", layer = "area", ["in"] = "aurum80", pages = { 82, 83 },
      read = "Noise everywhere: food stands, stink, scaffolding stacked with bed capsules up to the ceiling, and paths cut between "
          .. "heaps of rubbish. Three floors up, a bar spills out onto a platform: the Tsurutsuru.",
      spots = { "food_stands", "scaffolding", "capsules", "bar", "balcony", "hinas_office", "holo_screens" },
      exits = { { to = "engine_room", by = "the stairs down" }, { to = "computer_center" }, { to = "dock", by = "the elevators" } },
      scene = { type = "social", setting = { "indoor" }, sum = "Hina Tsurutsuru, her bar, and her fuel.",
                cast = "ri_hina", cast_line = false,
                goal = { name = "The Tsurutsuru", aim = "get fuel from Hina", short = "get fuel",
                         line = "Goal: get fuel for the Brittle Star.",
                         win = "Hina's fuel is theirs.",
                         win_if = { { when = { flag = "hina_promised" }, text = "Hina pays in fuel, up front: she's coming with them." } },
                         lose = "Hina won't sell, not to them, not today.", got = "fuel for the Brittle Star" } } },
    { id = "engine_room", name = "The engine room", layer = "area", ["in"] = "aurum80", pages = { 84, 85, 86, 87 },
      read = "Hot, thick with engine grease. Coloured lights hang from the ceiling like stars, kids run between fruit stalls, and "
          .. "steam comes up through the floor. A ring of cooling corridors round the engine hall: the Passel's turf.",
      spots = { "corridors", "fruit_stalls", "noodle_stand", "fans", "guards", "roys_office", "engine_hall_door" },
      exits = { { to = "computer_center" }, { to = "engine_hall", gates = { flag = "monotone_deal" } }, { to = "dock" } },
      scene = { type = "social", setting = { "indoor" }, sum = "Roy Mirra and the Passel, and a farm dying for water.",
                cast = "ri_roy", cast_line = false,
                goal = { name = "The Passel", aim = "win Roy Mirra round", short = "talk to Roy",
                         line = "Goal: get Roy Mirra's crew to fix the Brittle Star.",
                         win = "Roy will fix their hub, if they get water to his farm.",
                         win_if = { { when = { flag = "roy_deal_done" }, text = "The water's flowing, and Roy's crew is on the Brittle Star." } },
                         lose = "Roy wants nothing to do with them.", got = "Roy's word" } } },
    { id = "computer_center", name = "The computer center", layer = "area", ["in"] = "aurum80", pages = { 88, 89, 90, 91 },
      read = "Blue lights crawl over walls padded against noise, and the air smells of burnt circuits. Old computers stand in "
          .. "stacks under nests of wire, and in the main hall, people lie dreaming in non-phys visors: Parliament's turf.",
      spots = { "corridor", "main_hall", "dreamers", "server_room", "sleeping_pods", "office_door", "window" },
      exits = { { to = "relay", gates = { flag = "roy_deal" } }, { to = "engine_room" }, { to = "dock" } },
      scene = { type = "social", setting = { "indoor" }, sum = "Monotone Tynall and Parliament, and a favor that isn't what it seems.",
                cast = "ri_monotone", cast_line = false,
                goal = { name = "Parliament", aim = "get Monotone Tynall's help", short = "talk to Monotone",
                         line = "Goal: get Monotone Tynall to fix the Brittle Star.",
                         win = "Monotone will fix their hub, for a favor in the engine hall.",
                         win_if = { { when = { flag = "monotone_deal_done" }, text = "The circuit board's in, and Monotone's people are on the Brittle Star." },
                                    { when = { flag = "water_changed" }, text = "The water signal's changed, right under Monotone's nose." } },
                         lose = "Monotone won't see them.", got = "Monotone's favor" } } },
    -- Roy's favor (p. 85): the signal to the water systems, changed at the final relay unit outside, by the dish.
    { id = "relay", name = "The final relay unit", layer = "area", ["in"] = "aurum80", pages = { 85, 90, 91 },
      read = "Outside, in vacuum: the station's hull, a huge communications dish, and a battered unit beside it that tells the "
          .. "water systems what to do. Through a window, the computer center's main hall.",
      spots = { "hull", "dish", "relay_unit", "window", "airlock" },
      exits = { { to = "computer_center", by = "the airlock" } },
      scene = { type = "exploration", quick = true, setting = { "outdoor" }, sum = "A spacewalk to change the water signal.",
                goal = { name = "The relay", aim = "change the water signal at the relay", short = "hack the relay",
                         line = "Goal: change the signal to the water systems, out on the hull.",
                         win = "The water's flowing to Roy's farm.", lose = "The relay holds, and the farm stays dry.",
                         got = "water for the farm" } } },
    -- Monotone's favor (p. 89): a circuit board in the control unit in the central engine hall, the Passel's own.
    { id = "engine_hall", name = "The central engine hall", layer = "area", ["in"] = "aurum80", pages = { 84, 86, 89 },
      read = "Wet heat and a sweet smell of fruit, and an engine too loud to think over. Plants climb everything, most of them "
          .. "dry and withered. Racks of electronics stand by a control panel. A Passel member sleeps by the inner door.",
      spots = { "plants", "engine", "control_panel", "racks", "sleeper", "inner_door" },
      exits = { { to = "engine_room" } },
      scene = { type = "exploration", quick = true, setting = { "indoor" }, sum = "Monotone's circuit board, in the Passel's engine hall.",
                foes = { "passel", "passel" }, foes_name = "the Passel's guards", foes_short = "the guards",
                boss_name = "the Passel's guards", optional_fight = true,
                goal = { name = "The circuit board", aim = "install Monotone's circuit board", short = "install the board",
                         line = "Goal: get Monotone's circuit board into the control panel without being caught.",
                         win = "The board is in.", lose = "They're caught at the panel.", got = "Monotone's favor, done" } } },
    -- The shuttle (p. 79): Suro Ragosa and her thugs, come to settle it.
    { id = "shuttle", name = "The shuttle docks", layer = "area", ["in"] = "aurum80", pages = { 79 },
      read = "The timer hits zero. The shuttle grinds into its airlock, the docking bay empties of everyone with any sense, and "
          .. "Suro Ragosa steps out with a gang of thugs at her back.",
      spots = { "shuttle_airlock", "timer", "thugs", "crates", "airlock_13c" },
      exits = {},
      scene = { type = "combat", setting = { "indoor" }, sum = "Thorn Ragosa, come to settle it her way.", boss = true, difficulty = 3,
                cast = "ri_ragosa", foes = { "ragosa", "uwa_thug", "uwa_thug" }, foes_name = "Ragosa and her thugs",
                foes_short = "Ragosa's thugs", boss_name = "Thorn Ragosa", optional_fight = true,
                goal = { name = "Thorn Ragosa", aim = "deal with Suro Ragosa", short = "face Ragosa",
                         line = "Goal: get through Ragosa's arrival, alive.",
                         win_sets = "ragosa_beaten",
                         win = "Ragosa has what she came for, and they're still standing.",
                         lose = "Ragosa wanted blood, and she got it.", got = "Ragosa dealt with" } } },
}

M.start = "dock"
M.table_life = require "game.data.ring.table_life"
M.lore_tips = require "game.data.ring.tips"
M.timeout_ending = "war"
M.first_night_rewards = true
M.story_start = "A broken spacecraft at airlock 13C, a debt, and four hours before the sector's ringleader arrives."

-- People ------------------------------------------------------------------------------------------------------------
M.people = {
    { id = "ri_ezra", name = "Ezra Pascal", short = "Ezra", tier = "named", role = "Salvaging crew's captain", pages = { 81 },
      pronoun = "he", look = "Charming, patched from collar to boots, a gem-cutter's eyeglass pushed up on his forehead.",
      about = "Runs the salvaging crew: towing for far too many holos, and buying and selling debts. He's bought the crew's, "
          .. "500 holos of docking fees, and he owes the port authorities for fuel himself.",
      wants = "The crew's debt paid, today", knows = { "ezra_owes" }, stats = { block = "salvager" }, where = { "dock" } },
    { id = "ri_comms", name = "the Brittle Star's comms", short = "the comms", tier = "named", role = "What's left of the ship's mind", ours = true,
      pronoun = "it", look = "A speaker grille by the command chair, and a light that blinks when it's about to say something.",
      voice = "Bright, cheerful, and convinced it's helping.",
      about = "The Brittle Star was a chrome ship once, run by a chain of old AI mainframes. All that's left of them is the "
          .. "communications system, and it has a personality (p. 30).",
      wants = "To be useful, and to be talked to", knows = { "comms_log" }, where = { "hub" } },
    { id = "ri_cassius", name = "Cassius", tier = "named", role = "The ship's robot pet", ours = true, pronoun = "he", companion = true,
      look = "A robotic cat-thing in cosy synthetic fur, with one ear that won't stand up.",
      about = "Came with the ship (p. 33). Grumpy about everything, and fond of exactly nobody. Follows Pell around anyway.",
      wants = "To be left alone, near someone warm", where = { "hub" } },
    { id = "ri_friend", name = "Dace Korrin", short = "Dace", tier = "named", role = "An old friend of the crew", pages = { 80 }, call = 1,
      pronoun = "they", look = "Thinner than the crew remembers, always glancing at the elevators.",
      about = "Someone the crew knew years ago, before all this. Glad to see them, in trouble of their own, and quite happy to "
          .. "use them to get out of it. Dace tells Monotone and Roy both whatever they want to hear.",
      wants = "Their own troubles to go away", knows = { "friend_informs" }, where = { "bar_machine" } },
    { id = "ri_hina", name = "Hina Tsurutsuru", short = "Hina", tier = "named", role = "Owner of the Tsurutsuru", pages = { 83 },
      pronoun = "she", look = "Carbon, sharp-eyed, always with a drink in one hand and someone's tab in the other.",
      voice = "Warm and quick, and every sentence is a deal.",
      about = "A ring thug who used to be an astrochemist. She owns the Tsurutsuru, and she makes Hola!, a non-phys drug, "
          .. "from fuel and flowers out of Roy's farm, and sells it to Monotone. What she wants is out: off the Ring, "
          .. "somewhere warm, and quietly.",
      wants = "A ride off Aurum 80, without anyone noticing", knows = { "hina_hola", "hina_out" },
      stats = { block = "hina" }, where = { "common" } },
    { id = "ri_roy", name = "Roy Mirra", short = "Roy", tier = "named", role = "Leader of the Passel", pages = { 78, 85 },
      pronoun = "he", look = "A big punk with a friendly grin, a raid rifle never far from his hand.",
      voice = "Easy-going, right up until he isn't.",
      about = "Friendly, with a very short fuse. Spent his youth as a bodyguard on the satellites. Left Parliament and "
          .. "started the Passel when his mother died of non-phys, and he blames Monotone for it. He hates non-phys and "
          .. "anything to do with it. His farm is dying for water.",
      wants = "Water for the farm; and, underneath, Monotone to be sorry", knows = { "roy_coup", "roy_mother" },
      stats = { block = "roy" }, where = { "engine_room" } },
    { id = "ri_monotone", name = "Monotone Tynall", short = "Monotone", tier = "named", role = "Leader of Parliament", pages = { 78, 89 },
      pronoun = "they", look = "Slight and pale in the blue light, a memory cartridge jammed in a port behind one ear.",
      voice = "Flat and even, whatever they're saying.",
      about = "Unpredictable, and doesn't think much about what happens next. Used to fix drilling drones. Feels Roy "
          .. "betrayed the punks when he left. Lonely, with a memory cartridge stuck on old times. Their computers need "
          .. "more power than Roy will give them.",
      wants = "Aurum 80, and someone to share it with; Roy's friendship most of all", knows = { "monotone_board", "monotone_lonely" },
      stats = { block = "monotone" }, where = { "computer_center" } },
    { id = "ri_ragosa", name = "Suro \"Thorn\" Ragosa", short = "Ragosa", tier = "named", role = "The Aurum sector's ringleader", pages = { 79 },
      pronoun = "she", look = "Tall and tired, in a union jacket over body armor, a shotgun across her back.",
      voice = "Short, flat, and she doesn't repeat herself.",
      about = "Leads the UWA, the union that speaks for Aurum's workers to the mining companies, and speaks for Aurum to the "
          .. "rest of the Ring. Cares about staying in charge. She's sick of Roy and Monotone playing with the sector's "
          .. "power and air, and she'll shoot first.",
      wants = "To punish Roy and Monotone, and take Aurum 80 in hand", stats = { block = "ragosa" }, where = { "shuttle" } },
    { id = "ri_salvagers", name = "Elizi and Gonza Pascal", tier = "named", role = "The rest of the salvaging crew", pages = { 81 },
      about = "Elizi, a void and once a star chart reader, is the crew's brain; Gonza Pascal, carbon and once a driller, the "
          .. "muscle.", where = { "dock" } },
    { id = "ring_crowd", name = "The people of Aurum 80", tier = "crowd", pages = { 78, 80, 82 },
      about = "Workers off long shifts, miners waiting for a job, ex-prospectors who've lost everything, kids, vendors and "
          .. "non-phys dreamers." },
}

-- Their numbers (the book's, pp. 79-90): abilities, morale, hit points, defense rating and weapon (its damage and
-- shots before a reload from the weapons table, p. 122). The grid fight (game/rules/dis/battle.lua) fights with them.
M.creatures = {
    salvager = { name = "Salvaging crew", page = 81, abilities = { bdy = 2, dex = 0, svy = 1, tec = 1 }, morale = 7, hp = 8, dr = 12,
                 type = "humanoid", weapon = { ranged = true, uses = 5, name = "Pistol", damage = "1d6" } },
    hina = { name = "Hina Tsurutsuru", page = 83, abilities = { bdy = 0, dex = 0, svy = 4, tec = 1 }, morale = 9, hp = 7, dr = 12,
             type = "humanoid", weapon = { ranged = true, uses = 5, name = "Pistol", damage = "1d6" } },
    roy = { name = "Roy Mirra", page = 85, abilities = { bdy = 4, dex = 0, svy = 0, tec = 2 }, morale = 9, hp = 14, dr = 12,
            type = "humanoid", weapon = { ranged = true, uses = 10, name = "Raid rifle", damage = "1d10" } },
    passel = { name = "Passel member", page = 86, abilities = { bdy = 2, dex = -1, svy = 0, tec = 0 }, morale = 7, hp = 5, dr = 11,
               type = "humanoid", weapon = { ranged = true, uses = 5, name = "Pistol", damage = "1d6" } },
    monotone = { name = "Monotone Tynall", page = 89, abilities = { bdy = 0, dex = 0, svy = 2, tec = 4 }, morale = 8, hp = 10, dr = 12,
                 type = "humanoid", weapon = { ranged = true, uses = 10, name = "Compact rifle", damage = "1d8" } },
    parliament = { name = "Parliament member", page = 90, abilities = { bdy = -2, dex = 0, svy = 1, tec = 2 }, morale = 5, hp = 5, dr = 12,
                   type = "humanoid", weapon = { ranged = true, uses = 5, name = "Pistol", damage = "1d6" } },
    ragosa = { name = "Suro Ragosa", short = "Ragosa", page = 79, abilities = { bdy = 2, dex = 1, svy = 0, tec = 0 }, morale = 10, hp = 5, dr = 13,
               type = "humanoid", weapon = { ranged = true, uses = 4, name = "Shotgun", damage = "2d4" } },
    uwa_thug = { name = "UWA thug", page = 79, abilities = { bdy = 2, dex = 1, svy = 0, tec = 0 }, morale = 10, hp = 5, dr = 13,
                 type = "humanoid", weapon = { ranged = true, uses = 4, name = "Shotgun", damage = "2d4" } },
}

-- Threads, story events and endings --------------------------------------------------------------------------------
M.threads = {
    { id = "the_hub", name = "A broken hub", pages = { 78, 80 }, clues = { "comms_log" }, clock = "ragosa_shuttle",
      ends = { "away", "peace", "passel_wins", "parliament_wins", "war" } },
    { id = "the_debt", name = "The debt", who = "ri_ezra", pages = { 78, 81 }, clues = { "ezra_owes" }, tags = { "debt", "salvagers" },
      open_at_end = true, when = { not_flag = "debt_settled" },
      text = "The salvaging crew still holds the crew's 500-holo debt, and Ezra Pascal knows the Brittle Star by sight." },
    { id = "the_gangs", name = "Roy and Monotone", pages = { 78, 85, 89 }, clues = { "roy_mother", "monotone_lonely", "friend_informs" } },
    { id = "the_signal", name = "The voice in the static", tags = { "signal", "void" }, ours = true, open_at_end = true,
      when = { flag = "signal_found" },
      text = "The signal Ilse followed here is a stuck memory on Monotone's cartridge, and it's being broadcast. To whom?" },
    { id = "hinas_way_out", name = "Hina's way out", who = "ri_hina", tags = { "hina", "passenger" }, open_at_end = true,
      when = { flag = "hina_aboard" }, text = "Hina Tsurutsuru is aboard the Brittle Star, and she wants somewhere warm." },
}

-- A check here: d20 plus the ability, 12 or more (p. 36). `skill` is the ability (bdy, dex, svy, tec).
M.events = {
    { id = "arrival", at = "dock", when_in = "start", required = true, pages = { 78, 79 }, type = "story", title = "Aurum 80",
      text = "The shuttle leaves them on the docking bay floor with everything they own. Half the bay is staring up at a huge "
          .. "timer on the wall, counting down: four hours to the next shuttle. \"Thorn Ragosa's on that one,\" a vendor mutters, "
          .. "and starts packing up her stall." },
    { id = "the_debt", at = "dock", when_in = "mid", required = true, pages = { 78, 81 }, party = true, title = "The debt",
      actor = { "storyteller", "method_actor", "instigator" },
      text = "A man in patched-up everything is waiting by the junk in front of airlock 13C, two of his crew behind him. "
          .. "\"Ezra Pascal,\" he says, and he's very sorry about this. \"Your new ship's been sitting here running up docking "
          .. "fees. Five hundred holos. I bought the debt. Today would be lovely.\"",
      options = {
          { label = "Promise to pay before you leave.", want = "promise Ezra his holos before we go", short = "promise to pay",
            lean = "safe", log = "Ezra smiles and makes a note. \"Before you leave, then. I'll be right here. Right here.\"",
            mus = { flag = "debt_promised" } },
          { label = "Talk him down: the ship was sold without a word about it.", want = "talk Ezra down", short = "talk him down",
            lean = "talk",
            roll = { dc = 12, skill = { "svy" }, best = true,
                     success = { log = "Ezra laughs, and gives in on half of it. \"Two-fifty, and I never saw you. Pay when you can.\"",
                                 mus = { flag = "debt_halved" } },
                     fail = { log = "Ezra stops smiling. \"Five hundred. Before that shuttle lands.\" Gonza cracks his knuckles.",
                              mus = { flag = "debt_angry" } } } },
          { label = "Point out he's in a hole of his own.", want = "call Ezra on his own debts", short = "call his bluff",
            lean = "bold", when = { told = "ezra_owes" },
            roll = { dc = 12, skill = { "svy" }, best = true,
                     success = { log = "Ezra's smile goes thin, then wide. \"Fine. Tow a wreck for me some day and we're square.\" "
                                     .. "He tears the note in half.", mus = { flag = "debt_settled" } },
                     fail = { log = "\"My debts are my business,\" Ezra says. \"Yours are mine. Five hundred.\"", mus = { flag = "debt_angry" } } } },
          { label = "Tell him the ship's not worth five hundred, and walk past.", want = "walk right past him", short = "walk past",
            lean = "bold", log = "They step round Ezra and haul the junk off the airlock door. Behind them, the salvagers don't move, "
                .. "and don't stop watching.", mus = { flag = "debt_angry" } },
      } },
    { id = "the_murder", at = "dock", when_in = "end", pages = { 81 }, type = "story", title = "In the alley",
      text = "A scream from an alley between the repair shops. Someone in a non-phys visor bolts past them toward the elevators, "
          .. "holos spilling from his hands, and nobody else even looks up.",
      only_if = { not_flag = "quiet_dock" } },
    -- The hub (ours, from its background and quirk, pp. 30, 33).
    { id = "hub_wakes", at = "hub", when_in = "arrive", required = true, ours = true, type = "story", title = "Hello, crew",
      text = "Emergency lights flicker on as the airlock opens, and a speaker by the command chair crackles. \"Oh! Hello! "
          .. "Welcome aboard the Brittle Star! I'm the communications system. I'm all that's left of the ship's mind, actually, "
          .. "but let's not dwell. Everything's broken. Isn't this exciting?\" Something furry hisses at them from under the "
          .. "mess table." },
    { id = "the_damage", at = "hub", when_in = "mid", ours = true, party = true, title = "What's broken",
      actor = { "tactician", "explorer", "butt_kicker" },
      text = "The engine's cold, the fuel tank's dry, and half the command center's panels are dark. The comms offers a "
          .. "diagnostic. It's forty minutes long.",
      options = {
          { label = "Get under the panels and see for yourselves.", want = "get our hands dirty and find out", short = "look it over",
            lean = "look",
            roll = { dc = 12, skill = { "tec" }, best = true,
                     success = { log = "Burnt couplings in the engine, a cracked fuel line, a frame that's fine: nothing they can't fix "
                                     .. "with the right parts and a lot of time, or a proper repair crew in three hours. And no fuel at all.",
                                 mus = { flag = "damage_known" }, tells = { "hub_broken" }, tells_how = "check" },
                     fail = { log = "Everything they touch sparks or comes off in their hands. The comms tells them it's \"quite bad, "
                                  .. "really\", which is no help.", mus = { flag = "damage_guess" } } } },
          { label = "Let the comms run its diagnostic.", want = "let the comms tell us", short = "ask the comms", lean = "talk",
            log = "Forty minutes, three songs and a lot of opinions later: the engine needs a repair crew, the tank needs fuel, and "
                .. "the comms would like to be called something nicer than \"the comms\".",
            mus = { flag = "damage_known" }, tells = { "hub_broken" }, tells_how = "said" },
      } },
    { id = "comms_log", at = "hub", when_in = "end", ours = true, type = "story", title = "The old log",
      only_if = { flag = "damage_known" },
      text = "Before they go, the comms mentions, as if it's nothing, that it remembers the ship's last voyage. The log "
          .. "ends mid-sentence. It doesn't remember why.", tells = { "comms_log" } },
    -- The hub ready: the way out before Ragosa arrives (ours).
    { id = "undock", at = "hub", when_in = "leave", only_if = { flag = { "repaired", "fuelled" } }, ours = true, party = true,
      title = "Undock", actor = { "tactician", "butt_kicker", "storyteller" },
      text = "The Brittle Star hums under their feet for the first time: engine warm, tank full. The comms is beside itself. "
          .. "On the docking bay wall, the timer is still running.",
      options = {
          { label = "Undock and go, now.", want = "get out before Ragosa lands", short = "go now", lean = "safe",
            log = "Airlock 13C seals behind them, the clamps let go, and the Brittle Star drifts out past the Ring's rusted "
                .. "girders into the dark.", mus = { flag = "undocked" } },
          { label = "Stay and see it through.", want = "stay and see what happens when Ragosa lands", short = "stay", lean = "bold",
            log = "They power the engine back down and wait for the shuttle." },
      } },
    { id = "the_friend", at = "bar_machine", when_in = "start", pages = { 80 }, party = true, title = "An old friend",
      actor = { "storyteller", "method_actor", "casual" },
      text = "\"No. No way.\" Someone at the bar in the machine is staring at them: Dace Korrin, who they knew years ago, from "
          .. "before. Dace buys them a round of water and sake, and starts talking fast about who's who in Aurum 80.",
      options = {
          { label = "Catch up, and hear what Dace knows.", want = "hear Dace out", short = "catch up", lean = "talk",
            log = "Roy Mirra and the Passel can fix a hub in three hours. So can Monotone Tynall and Parliament. Hina at the "
                .. "Tsurutsuru sells fuel. And the next shuttle is bringing Thorn Ragosa, who wants blood. Dace has a little "
                .. "job for them too, later.", tells = { "rumour_fixers" }, tells_how = "said", mus = { flag = "heard_news" } },
          { label = "Ask what Dace isn't saying.", want = "find out what Dace is hiding", short = "read Dace", lean = "look",
            roll = { dc = 12, skill = { "svy" }, best = true,
                     success = { log = "Dace keeps glancing at the elevators, and talks a lot about both gangs. Too much: they're "
                                     .. "telling Roy and Monotone both whatever they hear.", mus = { flag = "heard_news" },
                                 tells = { "friend_informs", "rumour_fixers" }, tells_how = "check" },
                     fail = { log = "Dace is just glad to see them, as far as anyone can tell.", mus = { flag = "heard_news" },
                              tells = { "rumour_fixers" }, tells_how = "said" } } },
      } },
    { id = "the_offer", at = "common", when_in = "mid", required = true, pages = { 83 }, party = true, title = "Hina",
      actor = { "storyteller", "method_actor", "instigator" },
      text = "Hina Tsurutsuru has them brought up to her office, an old airlock at the back of the bar, before they've finished "
          .. "asking for her. \"You've got a spacecraft,\" she says. \"I've got fuel. Let's be friends.\"",
      options = {
          { label = "Offer her a ride off Aurum 80.", want = "offer Hina a ride out", short = "offer a ride", lean = "talk",
            log = "Hina's whole face changes. \"Somewhere warm. No fuss, no goodbyes.\" She pays up front, in fuel.",
            mus = { flag = "hina_promised", flags = { "fuelled" } }, tells = { "hina_out" }, tells_how = "said" },
          { label = "Haggle for the fuel.", want = "haggle Hina down", short = "haggle", lean = "bold",
            roll = { dc = 12, skill = { "svy" }, best = true,
                     success = { log = "It takes three drinks and a lot of laughing, but Hina sells them a tank's worth on credit, "
                                     .. "against whatever they make next.", mus = { flag = "fuelled" } },
                     fail = { log = "Hina laughs them out of her office. \"Come back with holos. Or a better offer.\"" } } },
          { label = "Ask where her fuel goes, besides spacecraft.", want = "ask Hina about the fuel", short = "ask about the fuel",
            lean = "look",
            roll = { dc = 12, skill = { "svy" }, best = true,
                     success = { log = "She doesn't deny it: fuel and flowers from Roy's farm make Hola!, and Monotone buys all she "
                                     .. "makes. \"Roy doesn't know. Let's keep it that way.\"", tells = { "hina_hola" }, tells_how = "check" },
                     fail = { log = "\"Spacecraft,\" Hina says, and smiles, and changes the subject." } } },
      } },
    { id = "roy_favor", at = "engine_room", when_in = "mid", required = true, pages = { 85 }, party = true, title = "A favor for a favor",
      actor = { "storyteller", "tactician", "casual" },
      text = "Roy Mirra finds them before they find him, slurping soup at a noodle stand. He's friendly, right up to the "
          .. "moment they mention Parliament. Then he tells them about his farm, dying for water, because Monotone's computers "
          .. "keep cutting the supply. \"Fix that, and my crew fixes your ship.\"",
      options = {
          { label = "Shake on it.", want = "take Roy's deal", short = "take the deal", lean = "safe",
            log = "Roy spits on his hand and holds it out. \"Change the water signal. Monotone's computer, or the relay out on "
                .. "the hull by the dish. Either'll do.\"", mus = { flag = "roy_deal" } },
          { label = "Tell him about Hina's Hola!.", want = "tell Roy where his flowers go", short = "tell him", lean = "bold",
            when = { told = "hina_hola" },
            log = "Roy goes very still, then very loud. Half the corridor runs. He'll deal with them, he says, but first he's going "
                .. "to deal with Hina.", mus = { flag = "roy_deal", flags = { "roy_angry" } } },
          { label = "Ask what happened between him and Monotone.", want = "ask Roy about Monotone", short = "ask about Monotone",
            lean = "talk",
            roll = { dc = 12, skill = { "svy" }, best = true,
                     success = { log = "His mother died of non-phys, he says, and Monotone kept selling it to her. He takes the deal "
                                     .. "anyway. \"Water. That's all I'm asking.\"", tells = { "roy_mother" }, tells_how = "check",
                                 mus = { flag = "roy_deal" } },
                     fail = { log = "\"Not your business.\" He takes their hands for the deal anyway, hard.", mus = { flag = "roy_deal" } } } },
      } },
    { id = "monotone_favor", at = "computer_center", when_in = "mid", required = true, pages = { 89 }, party = true, title = "Monotone",
      actor = { "storyteller", "explorer", "method_actor" },
      text = "Two friendly AI bodyguards show them into an office of holo photos: old friends, the time before the war, Roy and "
          .. "Hina in half of them. Monotone Tynall doesn't get up. \"A circuit board in the control panel in the engine hall. "
          .. "That's all. Then my people fix your hub.\"",
      options = {
          { label = "Take the board, and the deal.", want = "do Monotone's favor", short = "take the board", lean = "safe",
            log = "Monotone hands it over without looking at it. \"Half an hour's work,\" they say. It isn't.",
            mus = { flag = "monotone_deal" }, tells = { "monotone_board" }, tells_how = "said" },
          { label = "Change the water signal while they're talking.", want = "change the water signal on Monotone's computer",
            short = "change the signal", lean = "bold", when = { flag = "roy_deal" },
            roll = { dc = 12, skill = { "tec", "dex" }, best = true,
                     success = { log = "Somebody keeps Monotone talking about the old days; somebody else's hand finds the keyboard. "
                                     .. "By the time they leave, the water's running to Roy's farm.", mus = { flag = "water_changed", flags = { "roy_deal_done", "repaired" } } },
                     fail = { log = "Monotone sees. They don't shout; they just turn and look. The bodyguards walk the crew out.",
                              mus = { flag = "monotone_angry" } } } },
          { label = "Ask about the photos.", want = "ask Monotone about the old days", short = "ask about the photos", lean = "talk",
            roll = { dc = 12, skill = { "svy" }, best = true,
                     success = { log = "Roy, Hina and Monotone, years ago, laughing. \"He was my best friend,\" Monotone says, flat as ever. "
                                     .. "\"He left.\" The stuck cartridge behind their ear clicks, playing it again.",
                                 tells = { "monotone_lonely" }, tells_how = "check", mus = { flag = "signal_found" } },
                     fail = { log = "\"Old friends.\" That's all they say." } } },
      } },
    { id = "the_relay", at = "relay", when_in = "mid", required = true, pages = { 85, 90 }, party = true, title = "On the hull",
      actor = { "tactician", "explorer", "butt_kicker" },
      text = "Magnetic boots, a slow walk across the hull, the dish turning above them, and the relay unit, bolted down and "
          .. "rusted shut. Through a window: the main hall, full of dreamers.",
      options = {
          { label = "Hack the relay.", want = "hack the relay unit", short = "hack it", lean = "look",
            roll = { dc = 12, skill = { "tec" }, best = true,
                     success = { log = "The relay takes the new signal. Somewhere below, pipes bang, and water starts running to the farm.",
                                 mus = { flag = "water_changed", flags = { "roy_deal_done", "repaired" } } },
                     fail = { log = "The relay throws a spark that kills their suit lights for a long cold minute. It won't take the signal.",
                              mus = { flag = "relay_failed" } } } },
          { label = "Pry it open and rewire it by hand.", want = "rewire it by hand", short = "rewire it", lean = "bold",
            roll = { dc = 12, skill = { "bdy" }, best = true,
                     success = { log = "The cover comes off, the wires go where they're told. Water runs to the farm.",
                                 mus = { flag = "water_changed", flags = { "roy_deal_done", "repaired" } } },
                     fail = { log = "The cover tears free and spins off into the dark. The relay inside is fried.", mus = { flag = "relay_failed" } } } },
      } },
    { id = "the_board", at = "engine_hall", when_in = "mid", required = true, pages = { 86, 89 }, party = true, title = "The control panel",
      actor = { "tactician", "explorer", "instigator" },
      text = "The control panel by the racks, a sleeping Passel member by the inner door, and a tangle of wires behind the panel "
          .. "that look nothing like Monotone said they would.",
      options = {
          { label = "Get the board in, quietly.", want = "install the board without waking anyone", short = "install it", lean = "look",
            roll = { dc = 12, skill = { "tec" }, best = true,
                     success = { log = "Twenty sweaty minutes and the board clicks home. The panel blinks, and Monotone has the power. "
                                     .. "Their people are already on the Brittle Star.", mus = { flag = "monotone_deal_done", flags = { "repaired", "roy_betrayed" } } },
                     fail = { log = "A spark, a shout: the sleeper's awake, and the Passel know who was at their panel.",
                              mus = { flag = "caught_at_panel", flags = { "roy_angry" }, fight = true } } } },
          { label = "Leave the board, and tell Roy instead.", want = "tell Roy what Monotone wanted", short = "tell Roy", lean = "bold",
            log = "Roy reads the board in his big hands for a long time. \"Thank you,\" he says. He'll fix their ship, and he'll "
                .. "remember this.", mus = { flag = "roy_deal_done", flags = { "repaired", "monotone_angry" } } },
      } },
    -- Ragosa (p. 79): the shuttle, and how it's settled. The book leaves the ending to the table.
    { id = "ragosa_lands", at = "shuttle", when_in = "start", required = true, pages = { 79 }, party = true, title = "Thorn Ragosa",
      actor = { "storyteller", "tactician", "butt_kicker" },
      text = "Ragosa looks over the empty docking bay, then at them. \"You're the ones who've been running about between Roy "
          .. "and Monotone,\" she says. \"Tell me why I shouldn't settle this right here.\"",
      options = {
          { label = "Bring Roy and Monotone to the table, together.", want = "get Roy and Monotone to talk it out in front of her",
            short = "make peace", lean = "talk", when = { told = { "roy_mother", "monotone_lonely" } },
            roll = { dc = 12, skill = { "svy" }, best = true,
                     success = { log = "It takes everything the crew has. Roy and Monotone stand in the docking bay, not looking at each "
                                     .. "other, and say what they've never said. Ragosa lowers the shotgun. \"Fine. One more chance.\"",
                                 mus = { flag = "peace", no_fight = true } },
                     fail = { log = "Roy says one word too many. Monotone says one back. Ragosa has heard enough.", mus = { fight = true } } } },
          { label = "Hand her the Passel.", want = "give Ragosa the Passel", short = "side with Parliament", lean = "safe",
            when = { flag = "monotone_deal_done" },
            log = "They tell Ragosa where Roy's plans to overthrow her are kept. She thanks them, coldly, and heads for the engine room.",
            mus = { flag = "parliament_wins", no_fight = true } },
          { label = "Hand her Parliament.", want = "give Ragosa Parliament", short = "side with the Passel", lean = "safe",
            when = { flag = "roy_deal_done" },
            log = "They tell Ragosa about the Hola!, and who's been buying it. She heads for the computer center with her thugs.",
            mus = { flag = "passel_wins", no_fight = true } },
          { label = "Run for the Brittle Star, and undock.", want = "get to the Brittle Star and go", short = "run for it",
            lean = "safe", when = { flag = { "repaired", "fuelled" } },
            log = "They sprint for airlock 13C with Ragosa's thugs shouting behind them. The clamps let go, and the Brittle Star "
                .. "drifts out past the Ring's rusted girders into the dark.", mus = { flag = "undocked", no_fight = true } },
          { label = "Stand between her and the station.", want = "stand up to Ragosa", short = "stand up to her", lean = "bold",
            log = "Ragosa sighs, and unslings the shotgun.", mus = { fight = true } },
      } },
    { id = "ragosa_after", at = "shuttle", when_in = "end", ours = true, type = "story", title = "After",
      only_if = { not_flag = { "peace", "passel_wins", "parliament_wins", "ragosa_beaten" } },
      text = "Shots echo away down the docking bay. Whatever Ragosa came to do, Aurum 80 will be a long time getting over it.",
      sets = { "war" } },
}

M.beats = {
    the_debt = { "they promised Ezra his holos", { ok = "they talked Ezra down to half", did = "they tried to talk Ezra down" },
                 { ok = "they called Ezra's bluff, and he tore up the debt", did = "they tried to call Ezra's bluff" },
                 "they walked straight past the salvagers" },
    the_damage = { { ok = "they worked out what the Brittle Star needs", did = "they tried to work out what's wrong with the ship" },
                   "they let the comms run its diagnostic" },
    undock = { "they undocked and left Aurum 80 behind", "they stayed to see Ragosa land" },
    the_friend = { "they caught up with Dace, an old friend", { ok = "they worked out Dace informs on everyone", did = "they tried to read Dace" } },
    the_offer = { "they promised Hina a ride, and got her fuel", { ok = "they haggled Hina into fuel on credit", did = "they tried to haggle with Hina" },
                  { ok = "they learned what Hina's fuel is really for", did = "they asked Hina about her fuel" } },
    roy_favor = { "they took Roy's deal", "they told Roy about the Hola!", { ok = "they heard about Roy's mother", did = "they asked Roy about Monotone" } },
    monotone_favor = { "they took Monotone's circuit board", { ok = "they changed the water signal under Monotone's nose", did = "they tried to change the water signal" },
                       { ok = "they heard about Monotone and Roy, long ago", did = "they asked about the photos" } },
    the_relay = { { ok = "they hacked the relay and got the water running", did = "they tried to hack the relay" },
                  { ok = "they rewired the relay by hand", did = "they tried to rewire the relay" } },
    the_board = { { ok = "they put Monotone's board in the Passel's panel", did = "they tried to put Monotone's board in" },
                  "they took Monotone's board to Roy instead" },
    ragosa_lands = { { ok = "they made peace between Roy and Monotone", did = "they tried to make peace" }, "they gave Ragosa the Passel",
                     "they gave Ragosa Parliament", "they stood up to Ragosa" },
}

M.recap = {
    dock = { win = "found their spacecraft at airlock 13C", lose = "found their spacecraft and a debt that wants paying",
             since = { { when = { flag = "debt_halved" }, win = "talked the salvagers down to half the debt" } } },
    hub = { win = "worked out what the Brittle Star needs", lose = "poked about the Brittle Star none the wiser" },
    bar_machine = { win = "caught up with an old friend at the bar in the machine", lose = "found nothing useful at the bar in the machine" },
    common = { win = "got fuel from Hina Tsurutsuru", lose = "came away from the Tsurutsuru without fuel",
               since = { { when = { flag = "hina_promised" }, win = "promised Hina a ride, and got her fuel" } } },
    engine_room = { win = "struck a deal with Roy Mirra", lose = "got nowhere with the Passel" },
    computer_center = { win = "got Monotone Tynall's help", lose = "got nowhere with Parliament",
                        since = { { when = { flag = "water_changed" }, win = "changed the water signal in the computer center" } } },
    relay = { win = "got the water running from the relay on the hull", lose = "couldn't make the relay take the signal" },
    engine_hall = { win = "put Monotone's board in the engine hall", lose = "were caught at the Passel's panel" },
    shuttle = { win = "got through Ragosa's arrival", lose = "lost to Ragosa's thugs",
                fought = { win = "fought off Ragosa's thugs", lose = "lost the fight with Ragosa's thugs" } },
}

-- How it ends (ours: the book gives no fixed solution, p. 79).
M.endings = {
    away = { name = "Away clean", when = { flag = "undocked" }, ours = true, tone = "good",
             line = "The Brittle Star is out past the Ring before the shuttle lands, engine coughing, tank full, and the comms "
                 .. "singing to itself.",
             line_if = { { when = { not_flag = "debt_settled" },
                           text = "The Brittle Star is out past the Ring before the shuttle lands. Somewhere behind them, Ezra Pascal "
                               .. "is writing their name in a very small book." } } },
    peace = { name = "One more chance", when = { flag = "peace" }, ours = true, tone = "good",
              line = "Roy and Monotone have one more chance, and Ragosa is watching both of them. Aurum 80 breathes out." },
    passel_wins = { name = "The Passel's station", when = { flag = "passel_wins" }, ours = true, tone = "mixed",
                    line = "Ragosa takes Parliament apart, and Roy's people run the air and water now. The dreamers wake up with "
                        .. "nowhere to go." },
    parliament_wins = { name = "Parliament's station", when = { flag = "parliament_wins" }, ours = true, tone = "mixed",
                        line = "Ragosa takes the Passel apart, and Monotone has all the power they wanted, and no one to share it with." },
    ragosa_beaten = { name = "Thorn in her side", when = { flag = "ragosa_beaten" }, ours = true, tone = "mixed",
                      line = "Ragosa limps back onto her shuttle with what's left of her thugs. Roy and Monotone have one less "
                          .. "thing to fear, and one more: the crew of the Brittle Star." },
    war = { name = "Gang war", when = { flag = "war" }, ours = true, tone = "bad",
            line = "The gangs go to war the moment Ragosa lands. The crew gets out with their lives, and not much else." },
}

M.clocks = {
    -- (Four hours to the next shuttle, p. 79: the first session's worth. If they're still here after it, Ragosa lands.)
    { id = "ragosa_shuttle", name = "The next shuttle", unit = "sessions", count = 1, page = 79,
      text = "Thorn Ragosa is on the next shuttle, with thugs.", sets = "ragosa_here",
      said = "The timer on the docking bay wall reads zero. Somewhere beyond the airlocks, a shuttle is coming in.",
      when = { not_flag = { "undocked", "peace" } } },
}

-- What the table hears, and what they don't know yet.
M.rumours = {
    { id = "fixers", who = "ri_friend", where = "bar_machine", truth = "true", page = 79,
      text = "\"Roy Mirra or Monotone Tynall could fix your hub. Three hours. Ask what they want for it first.\"" },
    { id = "fuel", who = "ri_friend", where = "bar_machine", truth = "true", page = 79,
      text = "\"Hina, who has the Tsurutsuru. She's got fuel. She can probably sell you some.\"" },
    { id = "ragosa", who = "ri_friend", where = "dock", truth = "true", page = 79,
      text = "\"Four hours till the ringleader lands, with a gang behind her. That's going to end in blood.\"" },
    { id = "junk_ship", who = "ring_crowd", where = "dock", truth = "true", page = 81,
      text = "\"Did you hear somebody actually bought that heap of junk by the dock?\"" },
    { id = "backdoor", who = "ring_crowd", where = "engine_room", truth = "true", page = 85,
      text = "\"There's a back way into the computer center's systems. A unit outside, by the big dish.\"" },
    { id = "worse_elsewhere", who = "ring_crowd", where = "dock", truth = "half", page = 81,
      text = "\"Other sectors are worse than us, you know. Much worse.\"" },
    { id = "gang_war", who = "ring_crowd", where = "common", truth = "true", page = 83,
      text = "\"Rozzie behind the bar says she won't pick a side. She'll have to, soon.\"" },
}

M.told = {}

M.secrets = require "game.data.ring.secrets"

-- The hub (ours, by the book's hub steps, pp. 26-33): a spacecraft, its frame, its engine and its state.
M.hub = {
    name = "the Brittle Star", kind = "spacecraft", pages = { 26, 27, 30, 33 },
    dr = 11, condition = { now = 0, max = 5 }, fuel = { now = 0, max = 6 }, frame = 100,
    power = { source = "a standard chemical engine, slow", output = 3 },
    core = { "command center", "crew quarters", "life support", "mess" },
    modules = {},
    background = { page = 30, text = "An old chrome ship, once run by a chain of AI mainframes. Only the communications "
        .. "system is left of them, and it has a personality." },
    quirk = { page = 33, text = "It came with a grumpy robot pet in cosy synthetic fur." },
    -- What it says on the prep board, by how things stand.
    status = { { when = { flag = { "repaired", "fuelled" } }, text = "The Brittle Star: repaired and fuelled, ready to fly." },
               { when = { flag = "repaired" }, text = "The Brittle Star: repaired, no fuel." },
               { when = { flag = "fuelled" }, text = "The Brittle Star: fuelled, still broken." },
               "The Brittle Star: broken, no fuel, 500 holos owed." },
}

M.items = {
    { id = "circuit_board", name = "Monotone's circuit board", holder = "ri_monotone", page = 89,
      text = "A circuit board that lets whoever holds the computer center control the power to it." },
    { id = "roys_plans", name = "Roy's secret files", holder = "engine_room", page = 86,
      text = "Plans to overthrow Suro Ragosa as Aurum's leader, on drives in Roy's office." },
    { id = "monotones_computer", name = "Monotone's personal computer", holder = "computer_center", page = 90,
      text = "Locked, in Monotone's office: the code that tells the water systems what to do." },
}

M.glossary = {
    { id = "holo", match = { "%f[%w]holos%f[%W]", "%f[%w]holo%f[%W]" }, plain = "money",
      text = "Holos: what everyone in the Iron Ring pays with." },
    { id = "non_phys", match = { "non%-phys" }, plain = "virtual reality",
      text = "Non-phys: virtual worlds you go into through a visor, and the drug-like habit people make of them." },
    { id = "void_point", match = { "void points?" }, plain = "the void's hold on a hero",
      text = "Every miss gives a hero a void point, four at most. Spending one rolls a check twice and keeps the better, "
          .. "but if it still misses, the void may leave a mark." },
    { id = "hub", match = { "%f[%w]hub%f[%W]" }, plain = "the crew's home",
      text = "The crew's spacecraft or station: where they live, what they fix, what they fly." },
}

return M
