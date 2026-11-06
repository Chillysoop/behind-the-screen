-- The Wild Sheep Chase at the Bogden Road Country Inn, in the adventure standard (docs/design/adventure-standard.md).
-- Adapted from *The Wild Sheep Chase* by Richard Jansen-Parkes (DMs Guild, 2016, six pages) and the Bogden Road
-- Country Inn sheet Conner shared. Pages are the reader's own PDF (`source = "inn"`: the inn sheet, which has no page
-- numbers). Every word here is ours, never the book's; tools/import/copy_check.py holds us to it.
--
-- The import pipeline's first draft (docs/design/2026-11-06-adventure-import.md, step 4). The standard holds all of
-- it; the engine plays it from step 5, so what's here is data a DM could have written by hand. It needs no other
-- adventure: a fresh party starts it at level 4, or one comes in from any adventure through adventure.handoff.
-- `ours = true` marks what the game adds that the book doesn't have; `call` marks a question for Conner.

local M = {}

M.id = "sheep"
M.title = "The Wild Sheep Chase"
M.author = "Richard Jansen-Parkes"
M.credit = "Adapted from The Wild Sheep Chase by Richard Jansen-Parkes (DMs Guild), for private playtesting. "
    .. "The Bogden Road Country Inn from the inn sheet shared with it."
M.levels = { 4, 5 }
M.START_LEVEL = 4
M.pitch = "A quiet afternoon at a country inn, until a sheep comes in at a gallop with a scroll in its mouth. "
    .. "A short adventure: a session or two."
M.premise = {
    "Finethir Shinebright, an elven wizard who works in transmutation, has spent two years as a sheep. His apprentice, "
        .. "Ahmed Noke, turned him into one with Shinebright's own wand of true polymorph (p3).",
    "Last night Noke left a door open. Shinebright stole a scroll that lets people understand animals and ran for town, "
        .. "looking for someone with enough magic to read it (p3).",
    "Noke's men are after him: Guz, a half-orc, with three wolves and a bear who are really people Noke changed (p2).",
    "Noke lives in Shinebright's old house in the woods, three platforms grown from living oaks. He keeps the wand on "
        .. "him, hardly sleeps, and is nearly out of money (p4, p6).",
    "Neither wizard is simply right: Shinebright treated Noke like a child for decades, and Noke paid him back with "
        .. "the wand (p4).",
}

-- What it can follow, and what it takes in (adventure.handoff). Any adventure can lead here, or none.
M.follows = { any = true }
M.handoff = {
    time_skip = "a week or two later",          -- (Conner, November 6)
    arrive = "inn_common",
    say = { { when = { past = "museum" }, text = "A week or two after the museum, the road brings you to a country "
                .. "inn where the Bogden road meets the lord's road. An afternoon with nothing to do." },
            "The road brings you to a country inn where the Bogden road meets the lord's road. An afternoon with "
                .. "nothing to do." },
}
-- What the party can keep (the book's outcomes, p6), for the next adventure.
M.keeps = {
    { id = "transmuter", text = "A wizard in their debt who'll do transmutations up to 5th level for the cost of "
          .. "the components", when = { flag = "restored" }, page = 6 },
    { id = "debt", text = "Shinebright owes them, and says so, even while he's still a sheep", when = { flag = "refused" }, page = 6 },
    { id = "oak_house", text = "The house in the oaks, if they take it, and the nobles who'll come asking for Noke",
      when = { flag = "took_house" }, page = 6 },
    { id = "lab_gear", text = "Lab gear and arcane odds and ends worth about 1,000 gp", when = { flag = "looted" }, page = 6 },
}
M.money = { coins = { "gp", "sp", "cp" }, note = "Rooms in silver, meals and drink in copper (inn sheet)." }

M.heroes = {
    mara = { gist = "Thessaly, a wizard who wants to know everything", short = "Mysteries, reveals, notes. Long fights lose her." },
    dev = { gist = "Brannoc, a fighter who hits first", short = "Fights and cool weapons. Long talks lose him." },
    jess = { gist = "Pip, a rogue with sticky fingers", short = "Talking to NPCs in voice, and chaos. Don't cut her scenes short." },
    sam = { gist = "Oswin, a cleric who keeps everyone standing", short = "Friends, snacks, a fair clever fight. Don't put him on the spot." },
}
-- (The book's only hook is an afternoon off in a town big enough to keep a wizard, p2. The sheep picks the hero with
-- the most magic.)
M.hooks = {
    mara = { { id = "magic", name = "The most magic", text = "The sheep makes straight for Thessaly: she's the one it can feel.", page = 2 } },
    dev = { { id = "rest", name = "An afternoon off", text = "Brannoc came for a drink and a sit-down, and that's not what he gets.", page = 2 } },
    jess = { { id = "rumour", name = "Gossip", text = "Pip has Teddy's ear and wants every story he's got about the wizard in the woods.", ours = true } },
    sam = { { id = "kind", name = "Kindness", text = "Oswin can't watch a frightened animal be dragged off.", ours = true } },
}
M.content = {
    animals = { inn_common = "wolves in iron collars, and people trapped in beasts' bodies" },
    body_horror = { hall = "a man turned into a heap of mouths and eyes by a wand that misfires" },
}

-- Places, by layer ----------------------------------------------------------------------------------------------------
-- layer: region (the overland map), site (a settlement or a lone building), area (a room or keyed spot, on a board).
-- in: the place it sits in. exits: { to, gates } (a gate: what lets them through). travel: a region's routes.
M.places = {
    { id = "bogden_road", name = "The Bogden road", layer = "region", source = "inn", pages = { 4 },
      read = "Farm country where the Bogden road meets the lord's road, with woods to the south-east.",
      travel = {
          { from = "inn", to = "bogden", by = "the Bogden road", time = "an hour's walk", ours = true, call = 1 },
          { from = "inn", to = "woods_path", by = "the lord's road", time = "an hour or so", page = 4,
            note = "A few miles along the road, a gap in the bushes and a path into the oaks." },
          { from = "woods_path", to = "noke_house", by = "the path", time = "half an hour", page = 4,
            note = "About a mile of thin woodland, nobody living along it." },
      } },
    { id = "bogden", name = "Bogden", layer = "site", ["in"] = "bogden_road", ours = true, call = 1,
      read = "The town the road is named for. Its people speak of the wizard in the woods with fear and a bit of awe.",
      pages = { 2 } },
    { id = "inn", name = "The Bogden Road Country Inn", layer = "site", ["in"] = "bogden_road", source = "inn",
      read = "A big, busy coaching inn at the crossroads: a common room, two bars, a great hearth, a stage out back.",
      shops = {
          { id = "rooms", name = "Rooms for the night", source = "inn", call = 2,
            sells = { { name = "A bed in the shared room", price = { sp = 3 } }, { name = "A room of your own", price = { sp = 5 } },
                      { name = "The best room in the house", price = { sp = 8 } } } },
          { id = "food", name = "Meals and drink", source = "inn", call = 2, note = "Priced in copper (the inn sheet's menus)." },
      } },
    { id = "inn_common", name = "The common room", layer = "area", ["in"] = "inn", source = "inn", pages = { 2 },
      read = "Long tables, a crackling hearth, the bar along one wall, and a crowd in no hurry.",
      spots = { "hearth", "bar", "door", "tables" },
      exits = { { to = "inn_upstairs" }, { to = "inn_cellar" }, { to = "inn_yard" } },
      note = "If a fight starts here, tables and chairs go over (p2)." },
    { id = "inn_upstairs", name = "Upstairs", layer = "area", ["in"] = "inn", source = "inn",
      read = "A landing, a row of guest rooms, and the travellers' doors.", exits = { { to = "inn_common" } } },
    { id = "inn_cellar", name = "The cellar", layer = "area", ["in"] = "inn", source = "inn",
      read = "Barrels, cold stone, and the smell of beer.", exits = { { to = "inn_common" } } },
    { id = "inn_yard", name = "The yard and the stage", layer = "area", ["in"] = "inn", source = "inn",
      read = "A courtyard with a little stage for travelling players, and the road beyond the gate.",
      note = "In the open, frightened onlookers make difficult ground (p2).", exits = { { to = "inn_common" } } },
    { id = "woods_path", name = "The path through the oaks", layer = "site", ["in"] = "bogden_road", pages = { 4 },
      read = "A well-used path winding between tall oaks. The ground is churned with feet and paws.",
      spots = { "tracks" } },
    { id = "noke_house", name = "The house in the oaks", layer = "site", ["in"] = "bogden_road", pages = { 4 },
      read = "Four living oaks, their branches woven into three platforms, one above another.",
      note = "The platforms stand 10, 20 and 30 feet up; our boards are flat, so the heights are notes (p4)." },
    { id = "compound", name = "Under the platforms", layer = "area", ["in"] = "noke_house", pages = { 4, 5 },
      read = "A lawn under the platforms, two small wooden huts, and a big outhouse.",
      spots = { "lawn", "huts", "outhouse", "slope" },
      exits = { { to = "garden", by = "a ramp of roots" } } },
    { id = "garden", name = "The garden platform", layer = "area", ["in"] = "noke_house", pages = { 4 },
      read = "The lowest platform, about forty feet across, ringed with curling branches, flowers and small trees.",
      exits = { { to = "compound" }, { to = "hall", gates = { { check = "athletics", dc = 14, page = 4 },
                                                               { check = "thieves_tools", dc = 12, page = 4 } } } } },
    { id = "hall", name = "The hall", layer = "area", ["in"] = "noke_house", pages = { 4, 6 },
      read = "The biggest platform, walled in woven branches with window gaps: a library and lab, a sitting room, and "
          .. "a dining room with a kitchen.",
      spots = { "library", "lab", "sitting_room", "kitchen", "door" },
      exits = { { to = "garden" }, { to = "bedroom", by = "a small slope" } } },
    { id = "bedroom", name = "The bedroom", layer = "area", ["in"] = "noke_house", pages = { 5, 6 },
      read = "The smallest, highest platform: a wardrobe, a big wooden bed, a dressing table under clutter.",
      spots = { "bed", "wardrobe" }, exits = { { to = "hall" } } },
}
M.start = "inn_common"

-- People ----------------------------------------------------------------------------------------------------------
-- tier: named (the book's own), local (from a type template), crowd. stats: a core block by name with tweaks, or
-- the adventure's own (M.creatures). understood: what it takes for the table to understand them.
M.people = {
    { id = "sh_teddy", name = "Teddy Bolandeere", tier = "named", role = "Innkeeper", known = true, source = "inn",
      pronoun = "he", about = "Runs the inn and its bar. Warm, fatherly, and hears every story on the road.",
      wants = "A full house and no trouble", knows = { "rumours" }, where = { "inn_common" } },
    { id = "sh_shinebright", name = "Finethir Shinebright", tier = "named", role = "The sheep", pages = { 2, 3, 6 },
      pronoun = "he", companion = true,
      look = "A sheep like any other: white fleece, black face, curled horns. As an elf: thin as a reed, hair like "
          .. "straw, a very long nose (p2).",
      voice = "Educated, fussy, an elven accent, and a little bleat at the end of words.",
      about = "A transmuter who was famous once. Vain, fussy and full of lectures, but kind when it doesn't cost "
          .. "him much.",
      wants = "His wand back, and his own shape", knows = { "sheep_wizard", "guards_are_people", "wand_on_noke", "second_scroll" },
      stats = { core = "pony", int = 18, wis = 14, page = 2 },
      understood = { item = "speak_scroll", spell = "speak_with_animals" } },
    { id = "sh_guz", name = "Guz", tier = "named", role = "Noke's man", pages = { 2, 3 }, pronoun = "he",
      look = "A huge half-orc with small eyes, a hand never far from his greatsword.",
      voice = "Slow and blunt, with long words of Noke's he hasn't quite got right.",
      about = "Loyal to Noke, who never cared what he looked like. Thinks violence is how everyone gets things done.",
      wants = "Master Noke's sheep, alive", stats = { block = "guz" }, where = { "inn_common", "compound" } },
    { id = "sh_noke", name = "Ahmed Noke", tier = "named", role = "The apprentice", pages = { 4, 5, 6 }, pronoun = "he",
      look = "A frantic young human wizard, ink on his fingers, eyes that don't stop moving.",
      voice = "Fast and disjointed, boasting one moment and bitter the next.",
      about = "Served Shinebright for years and was never treated as more than a boy. Took the wand. Now he can't sleep "
          .. "for fear someone does the same to him.",
      wants = "Fame, a great contract, and nobody coming for the wand", knows = { "noke_why", "wand_on_noke", "bed_escape", "wand_unreliable" },
      stats = { block = "noke" }, where = { "hall" } },
    { id = "sh_turleon", name = "Count Behpoh Turleon", tier = "named", role = "A traveller", source = "inn",
      pronoun = "he", colour = true, about = "A nobleman staying at the inn, with business of his own.", where = { "inn_upstairs" } },
    { id = "sh_luenn", name = "Sir Luenn of Nordenin", tier = "named", role = "A traveller", source = "inn",
      pronoun = "he", colour = true, about = "A knight on the road, taking his ease by the hearth.", where = { "inn_common" } },
    { id = "inn_staff", name = "The inn's people", tier = "local", role = "Staff", source = "inn",
      about = "Two dozen of them, cooks, potboys, grooms, and every one loyal to Teddy.",
      template = { jobs = { "cook", "barmaid", "potboy", "groom", "stable hand" }, want = "an easy shift", quirk = "gossip" } },
    { id = "inn_crowd", name = "Drinkers and travellers", tier = "crowd", source = "inn", where = { "inn_common", "inn_yard" } },
}

-- The adventure's own creatures: the book's stat blocks as numbers (p2, p5), and core ones by name with the book's
-- changes. (The core ape, pony and gibbering mouther come into game/rules/data/monsters.lua in step 5.)
M.creatures = {
    guz = { name = "Guz", page = 2, size = "medium", type = "humanoid", ac = 14, hp = 67, hit_dice = "9d8+27", speed = 30,
            abilities = { str = 16, dex = 12, con = 17, int = 8, wis = 11, cha = 8 }, skills = { intimidation = 2 },
            cr = "2", xp = 450, traits = { "reckless" }, call = 3,
            attacks = { { id = "whirling_greatsword", name = "Whirling Greatsword", kind = "melee", to_hit = 5, reach = 5,
                          targets = 2, damage = { { 2, 6, 3, "slashing" } } } },
            tactics = "Talks, bribes or threatens first; attacks without warning when it isn't working. Fights the "
                .. "heavy hitters beside the bear while the wolves go for the sheep." },
    noke = { name = "Ahmed Noke", page = 5, size = "medium", type = "humanoid", ac = 12, hp = 55, hit_dice = "10d8+10",
             speed = 30, abilities = { str = 9, dex = 14, con = 12, int = 16, wis = 12, cha = 10 },
             saves = { int = 5, wis = 4 }, skills = { arcana = 6 }, cr = "2", xp = 450,
             spellcasting = { level = 7, ability = "int", dc = 14, to_hit = 6,
                              cantrips = { "ray_of_frost", "mending", "prestidigitation", "message" },
                              slots = { 4, 3, 3, 1 },
                              known = { { "expeditious_retreat", "jump", "thunderwave" }, { "enlarge_reduce", "levitate" },
                                        { "haste", "slow" }, { "polymorph" } } },
             attacks = { { id = "dagger", name = "Dagger", kind = "melee", to_hit = 5, reach = 5, range = { 20, 60 },
                           damage = { { 1, 4, 2, "piercing" } } } },
             tactics = "Weak in a fight himself. Enlarges the bear once it's out, adds Ray of Frost, guards his "
                 .. "concentration, and runs for the bedroom when it's lost or someone gets close." },
    bed_dragon = { name = "Bed Dragon Wyrmling", page = 5, size = "large", type = "dragon", ac = 16, hp = 75,
                   hit_dice = "10d8+30", speed = 30, climb = 30, fly = 30,
                   abilities = { str = 19, dex = 14, con = 17, int = 8, wis = 8, cha = 4 },
                   skills = { perception = 2, stealth = 5 }, vulnerable = { "fire" }, cr = "4", xp = 1100,
                   attacks = { { id = "bite", name = "Bite", kind = "melee", to_hit = 6, reach = 5, damage = { { 2, 10, 4, "piercing" } } } },
                   breath = { id = "splinter_breath", name = "Splinter Breath", recharge = { 5, 6 }, cone = 15, save = "dex",
                              dc = 13, damage = { { 7, 6, 0, "piercing" } }, half = true },
                   look = "A dragon of carved wood, bedsheets for wings, a pillow on the end of its tail.",
                   tactics = "Breathes whenever it can, else bites whoever's closest; goes for anyone using fire on it. "
                       .. "Turns back into a battered bed if it drops or Noke's concentration breaks." },
    wolf_guard = { core = "wolf", page = 2, mind = "a person inside", note = "Iron collars, eyes far too clever. Goes "
                       .. "round the party for the sheep." },
    bear_guard = { core = "brown_bear", page = 2, mind = "a person inside", note = "Under a filthy brown cloak until the "
                       .. "hood comes down." },
    ape_guard = { core = "ape", page = 5, mind = "a person inside", flees_below = 0.5,
                  tweaks = { attacks = { { id = "greatsword", name = "Greatsword", kind = "melee", to_hit = 5, reach = 5,
                                           damage = { { 2, 6, 3, "slashing" } } } } } },
    sheep = { core = "pony", page = 2, int = 18, wis = 14, note = "Shinebright, as a sheep." },
    mouther = { core = "gibbering_mouther", page = 5, note = "What the wand makes of Noke, or of anyone it misfires on." },
}

-- Threads, story events and endings --------------------------------------------------------------------------------
-- A thread is a hook with its ways to end. open_at_end: still open when this adventure is over, for a later one to
-- pick up by its tags (adventure.handoff carries it).
M.threads = {
    { id = "the_sheep", name = "Master Noke's sheep", who = "sh_noke", pages = { 2, 3 },
      clues = { "sheep_wizard", "guards_are_people", "noke_why" }, clock = "guards_search",
      ends = { "restored", "dead", "refused", "taken" } },
    { id = "the_wand", name = "The wand", who = "sh_noke", pages = { 3, 6 }, clues = { "wand_on_noke", "wand_unreliable" } },
    { id = "the_college", name = "Word to the college", pages = { 6 }, tags = { "shinebright", "college", "wizards" },
      open_at_end = true, when = { flag = "dead" },
      text = "Shinebright asked for word to be sent to his old college if the spell killed him." },
    { id = "the_nobles", name = "The nobles call on Noke", pages = { 6 }, tags = { "nobles", "oak_house" },
      open_at_end = true, when = { flag = "took_house" },
      text = "The local nobles will come calling on Noke, and find someone else living in his house." },
    { id = "the_guards", name = "The changed guards", pages = { 6 }, tags = { "polymorph", "shinebright" },
      open_at_end = true, when = { flag = "restored" },
      text = "Shinebright takes in the changed guards who ran, and means to give them their shapes back." },
}

-- trigger: on = arrive (a place), after (another event), choice (the table's), fight (it starts or turns), round
-- (a count of rounds after something), clock. required: it always happens. only_if: a condition on the log.
M.events = {
    { id = "sheep_arrives", at = "inn_common", trigger = { on = "arrive", at = "inn_common" }, required = true, page = 2,
      text = "Hooves on the boards, yelps, frantic bleating: a sheep comes through the crowd at a run, a fancy scroll in "
          .. "its teeth, and makes for the hero with the most magic." },
    { id = "scroll_read", at = "inn_common", trigger = { on = "choice", choice = "read the scroll aloud" }, page = 2,
      text = "The bleating turns into Common with an elven accent. The sheep introduces himself.",
      sets = { "understood" } },
    { id = "guz_arrives", at = "inn_common", trigger = { on = "after", event = "sheep_arrives", minutes = 5 }, required = true,
      page = 2, text = "Howling outside, and shouting. A huge half-orc shoulders in behind three collared wolves, a "
          .. "big figure in a dirty cloak at his back." },
    { id = "hood_falls", at = "inn_common", trigger = { on = "fight", event = "guz_arrives" }, page = 2,
      text = "The cloaked figure throws back its hood with a roar: a bear.", sets = { "hood_fell" } },
    { id = "sheep_taken", trigger = { on = "choice", choice = "the wolves carry the sheep off" }, page = 2,
      text = "Guz's lot make for the woods with the sheep. A chase, if anyone follows." },
    { id = "the_story", trigger = { on = "after", event = "guz_arrives" }, only_if = { flag = "understood" }, pages = { 3 },
      text = "Shinebright begs for help, promises riches, and tells his side: the tower, the wand, the apprentice." },
    { id = "house_seen", at = "noke_house", trigger = { on = "arrive", at = "noke_house" }, required = true, page = 4,
      text = "Through the treetops: platforms grown from four oaks, three apes dicing on the lawn below." },
    { id = "bear_comes_out", at = "compound", trigger = { on = "fight", at = "compound" }, page = 5,
      text = "The outhouse door bangs open, and a bear comes out to see what the noise is." },
    { id = "noke_demand", at = "hall", trigger = { on = "arrive", at = "garden" }, page = 5,
      text = "Noke appears at a window gap: give back the sheep, and he won't destroy them." },
    { id = "noke_flees", at = "hall", trigger = { on = "fight", turn = "lost or someone close" }, page = 5,
      text = "Noke casts, blurs away into the hall, and locks the door behind him." },
    { id = "bed_dragon", at = "bedroom", trigger = { on = "round", after = "noke_flees", rounds = 3 }, page = 5,
      text = "The bedroom roof bursts open: Noke rides out on his bed, which is now a dragon." },
    { id = "mouther", trigger = { on = "fight", event = "bed_dragon", turn = "the dragon falls" }, page = 5,
      text = "Babbling, Noke turns the wand on himself. It fizzes, bangs, and leaves a heap of mouths and eyes." },
    { id = "wand_touched", trigger = { on = "choice", choice = "pick up or handle the wand" }, page = 6,
      text = "The wand sparks under their fingers, not the way magic should." },
    { id = "the_spell", trigger = { on = "choice", choice = "use the wand on Shinebright" }, page = 6,
      text = "Shinebright asks that his college hear of it if this kills him. Then the roll." },
}

-- Each ending as a condition on the log (adventure.test).
M.endings = {
    restored = { name = "Restored", when = { flag = "restored" }, page = 6,
                 line = "Shinebright is an elf again, delighted, and has to be reminded of everything he promised." },
    dead = { name = "The spell failed", when = { flag = "dead" }, page = 6,
             line = "The wand failed him. What's left of Shinebright's house is theirs to leave alone or strip bare." },
    refused = { name = "Still a sheep", when = { flag = "refused" }, page = 6,
                line = "They wouldn't risk the wand. Shinebright puts on an old robe over his fleece and keeps hoping." },
    taken = { name = "Noke has his sheep", when = { flag = "taken" }, ours = true, call = 4,
              line = "Guz brought the sheep home, and nobody came after it." },
}
M.xp = { each = 500, page = 6 }

-- Clocks: counts that fire something.
M.clocks = {
    { id = "guards_search", name = "Noke's men are looking", unit = "days", count = 3, ours = true, call = 5, page = 3,
      text = "Noke has more guards. Left alone, they find the sheep again.", fires = "sheep_taken" },
    { id = "bed_dragon", name = "Three rounds", unit = "rounds", count = 3, page = 5, after = "noke_flees", fires = "bed_dragon" },
}

-- What the table knows -------------------------------------------------------------------------------------------
-- Teddy's rumours (p2: the town speaks of Noke with fear and awe). truth: true, false, or a half of it.
M.rumours = {
    { id = "boulders", who = "sh_teddy", where = "inn", truth = "half", page = 2,
      text = "\"The wizard in the woods once cleared a rockslide off the lord's road by turning the rocks into rabbits.\"",
      dm = "That was Shinebright, years ago. The town thinks it's the same wizard." },
    { id = "beasts", who = "sh_teddy", where = "inn", truth = "true", page = 4, ours = true,
      text = "\"Keeps animals for guards out there. Wolves that look at you like they're doing sums.\"" },
    { id = "unpaid", who = "sh_teddy", where = "inn", truth = "true", page = 6, ours = true,
      text = "\"He's been selling things. Books, bottles, a carriage. Owes half of Bogden, the way I hear it.\"" },
    { id = "elf_left", who = "sh_teddy", where = "inn", truth = "false", ours = true,
      text = "\"The old elf went travelling a couple of years back and left his boy the whole place.\"" },
    { id = "long_words", who = "sh_teddy", where = "inn", truth = "true", page = 3, ours = true,
      text = "\"His big half-orc comes in for supplies now and then. Uses words like 'sentimental' and gets them wrong.\"" },
    { id = "mountains", who = "sh_teddy", where = "inn", truth = "true", ours = true, picks_up = { "mountain_road" },
      only_if = { thread = "mountain_road" },
      text = "\"Travellers down from the mountains won't say much. Somebody died up there, and nobody's asking how.\"" },
}

-- What the table calls a secret name before it's told (game/model/told.lua).
M.told = {
    shinebright = { words = { "Shinebright", "Finethir" },
                    intro = { "Finethir Shinebright", "My name is Finethir", "I am Shinebright" },
                    mask = { { "Finethir Shinebright", "the sheep" }, { "Shinebright", "the sheep" }, { "Finethir", "the sheep" } } },
    bear = { words = { "bear" }, covered_by = { { flag = "hood_fell" } },
             mask = { { "a brown bear", "a hulking cloaked figure" }, { "the bear", "the cloaked figure" } } },
    bed_dragon = { words = { "bed dragon", "Bed Dragon" } },
    mouther = { words = { "gibbering mouther", "Gibbering Mouther" } },
}

M.secrets = require "game.data.sheep.secrets"

-- Things --------------------------------------------------------------------------------------------------------------
-- state: what can change. hidden: what's unknown until found out (a secret). rules: what it does, in rules terms.
M.items = {
    { id = "speak_scroll", name = "A sealed scroll", holder = "sh_shinebright", page = 2,
      text = "A fancy scroll. Its wax seal says Speak with Animals, modified.",
      rules = "Read aloud, it works: everyone who hears it understands the sheep. (How long for: the spell's ten "
          .. "minutes, unless Conner says otherwise.)", call = 6, once = true },
    { id = "speak_scroll_2", name = "Another sealed scroll", holder = "hall", page = 6, once = true,
      text = "The same seal as the first: Speak with Animals, modified.", rules = "As the first." },
    { id = "wand", name = "A cracked oak wand", holder = "sh_noke", page = 6, magic = "wand_true_polymorph",
      text = "A long thin oak twig with a fat iron band covered in runes, and cracks along its length.",
      state = { charges = "1d4-1, at least 1, back at dawn", dc = 17, cracked = true }, hidden = { "wand_unreliable" },
      rules = "Any spellcaster attuned to it for an hour can cast true polymorph from it, a charge a time. Each use: "
          .. "Arcana DC 17. Pass: it works, and the DC goes up by one for good. Fail by up to 5: the target becomes a "
          .. "gibbering mouther (only 9th-level magic undoes it; the target saves as usual). Fail by more: that, and "
          .. "the wand bursts for 1d12 force per charge left on everyone within 10 feet." },
    { id = "lab_gear", name = "Lab gear", holder = "hall", page = 6, value = { gp = 1000 },
      text = "Glassware, burners, jars and arcane bric-a-brac. Worth about a thousand gold to the right buyer." },
    { id = "robe", name = "An old robe", holder = "bedroom", page = 6, text = "One of Shinebright's robes, far too long for a sheep." },
}
M.magic_items = {
    wand_true_polymorph = { name = "Modified Wand of True Polymorph", rarity = "legendary", attune = true,
                            text = "See the wand's rules (p6)." },
}

M.glossary = {
    { id = "transmutation", match = { "transmutation", "transmuter" }, plain = "magic that changes what something is",
      text = "The school of magic that changes things: lead to gold, a boulder to a rabbit, a wizard to a sheep." },
}

return M
