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
M.MAX_WEEKS = 3
M.BUDGET = 10
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
    { id = "oak_house", text = "Noke's Tower, if they take it, and the nobles who'll come asking for Noke",
      when = { flag = "took_house" }, page = 6 },
    { id = "lab_gear", text = "Lab gear and arcane odds and ends worth about 1,000 gp", when = { flag = "looted" }, page = 6 },
    -- (Ours: the side quest at the inn, and the museum's mountain road.)
    { id = "luenn_gold", text = "Sir Luenn's twenty gold, for finding his ring", when = { flag = "ring_back" } },
    { id = "inn_friends", text = "Friends at the Bogden Road Country Inn: Wenna, and Teddy", when = { flag = "wenna_thanked" } },
    { id = "hobbs_word", text = "Hobb's word on the death up the mountain road: the messenger was carried to where he was found",
      when = { flag = "drover_talked" } },
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
    mara = { { id = "magic", name = "Real magic", text = "Thessaly has heard there's a famous wizard's house somewhere near this road.", page = 2,
               room = "hall", intro = "A quiet inn, a hot meal, and a shelf of books by the fire. That's the whole plan for today.",
               payoff = "Shelves of transmutation, a lab full of half-finished work: more real magic in one room than most wizards see in a lifetime." } },
    dev = { { id = "rest", name = "An afternoon off", text = "Brannoc came for a drink and a sit-down.", page = 2,
              intro = "I've walked all day. I want a drink and a chair, in that order.",
              payoff = "A drink, a chair, and a fire. For about ten minutes." } },
    jess = { { id = "rumour", name = "Gossip", text = "The innkeeper has stories about the wizard in the woods, and Pip collects stories.", ours = true,
               intro = "Every innkeeper has stories. I want all of this one's.",
               payoff = "The innkeeper leans on the bar with a story about the wizard in the woods, and he's only getting started." } },
    sam = { { id = "kind", name = "Kindness", text = "Oswin looks after whoever needs it, people or animals.", ours = true,
              room = "woods_path", intro = "A warm hearth, good food, and nobody needing healing. Bliss.",
              payoff = "All the way along the path, the sheep keeps close to Oswin's heels." } },
}
M.content = {
    animals = { inn_common = "wolves in iron collars, and people trapped in beasts' bodies" },
    body_horror = { hall = "a man turned into a heap of mouths and eyes by a wand that misfires" },
    spiders = { inn_cellar = "a cellar full of webs, and the spiders that spin them" },
}

-- Where the table can go next, when there's more than one way (museum_night.fork): after the common room, up the
-- stairs, down to the cellar, or out onto the road. What they see from where they stand, and what each way is.
M.forks = { hub = { title = "Where now?", text = "Stairs up, a trapdoor down, and the road outside." } }
M.fork_at = {
    inn_common = { text = "Tables going back on their legs. Stairs up to the rooms, the cellar trapdoor behind the bar, and the "
                       .. "front door onto the lord's road." },
    inn_upstairs = { text = "Back down the stairs into the warm: the cellar trapdoor behind the bar, and the road outside." },
    inn_cellar = { text = "Up the ladder into the common room: the stairs to the rooms, and the road outside." },
}
M.pull = {
    inn_upstairs = { label = "Up the stairs to Sir Luenn's room", want = "to look into Sir Luenn's ring", tags = { "mystery", "funny", "cozy" } },
    inn_cellar = { label = "Down through the trapdoor, into the cellar", want = "to poke about in the cellar", tags = { "explore", "danger", "loot" } },
    woods_path = { label = "Out onto the lord's road with the sheep", want = "to get going with the sheep", tags = { "action" } },
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
      read = "A big stone inn where the Bogden road meets the lord's road: hot food, company, and a bed on a long "
          .. "journey. Sooner or later every sort of traveller stops here, plenty of them shady.",
      lore = "A barracks in a great war more than a hundred years ago, then a barn, until the first Bolandeere started "
          .. "feeding travellers in it. The locals named it, and the name stuck.",
      note = "The windows are small and the ways out are few: easy for anyone, party or foe, to get trapped inside.",
      shops = {
          { id = "rooms", name = "Rooms for the night", source = "inn",
            sells = { { name = "The common room upstairs", price = { sp = 3 }, note = "a bed among strangers" },
                      { name = "A private room", price = { sp = 5 } }, { name = "The Sargent's Room", price = { sp = 8 },
                      note = "the best in the house; the sheet spells it so, after the old barracks" } } },
          { id = "food", name = "The kitchen (a forest menu)", source = "inn",
            sells = { { name = "Horsebread", price = { cp = 1 } }, { name = "River salmon", price = { sp = 1 } },
                      { name = "Venison with carrots and potatoes", price = { sp = 2 } }, { name = "Fried pork, country style", price = { sp = 3 } },
                      { name = "Baked apples", price = { cp = 2 } }, { name = "Wheat ale", price = { cp = 4 } },
                      { name = "Table wine", price = { cp = 6 } } },
            note = "Wild caught or grown nearby, and a cut above what farm folk eat at home." },
          { id = "services", name = "Other services", source = "inn",
            sells = { { name = "Mending", price = { cp = 1 }, note = "a garment" }, { name = "Laundry", price = { cp = 2 }, note = "a basket" },
                      { name = "A seat on a wagon going far", price = { gp = 5 }, note = "about that, a passenger; the roads are busy" } } },
      },
      work = { { name = "Guide or guard on a long wagon trip", pay = { sp = 2 }, per = "day", note = "and meals on the road" } } },
    { id = "inn_common", name = "The common room", layer = "area", ["in"] = "inn", source = "inn", pages = { 2 },
      read = "Tables of every size round a big central hearth, a pair of bars, the kitchen, a cloakroom, and a crowd in no hurry.",
      spots = { "hearth", "bar", "back_bar", "kitchen", "cloakroom", "tables", "door", "stairs" },
      exits = { { to = "inn_upstairs", by = "either of two stairs" }, { to = "inn_cellar", by = "a trapdoor behind one bar" },
                { to = "inn_yard" }, { to = "woods_path", by = "the lord's road" } },
      note = "If a fight starts here, tables and chairs go over (p2).",
      scene = { type = "social", setting = { "indoor" }, sum = "A sheep with a scroll, and the men who come for it.",
                cast = "sh_shinebright", cast_line = false, foes = { "guz", "wolf_guard", "wolf_guard", "wolf_guard", "bear_guard" },
                foes_name = "Guz and his beasts", foes_short = "Guz's crew", boss_name = "Guz", optional_fight = true,
                goal = { name = "An afternoon at the inn", aim = "have a quiet afternoon at the inn",
                         line = "Goal: an afternoon off, and whatever comes through the door.",
                         win = "Guz's crew is beaten or gone, and the sheep is still with them.",
                         win_if = { { when = { flag = "guz_left" }, text = "The sheep stays put, and the common room goes back to its drinks." } },
                         lose = "Guz's lot go out through the door with the sheep under the half-orc's arm.",
                         got = "a sheep with a wizard inside" } } },
    -- (The inn's upstairs and cellar, from the inn sheet, play as two short scenes off the common room, after Guz: the
    -- table picks one, both or neither, and setting off for the woods leaves them behind. What happens in them is ours
    -- (Conner, November 6: "fun exploration, with a mini side quest"): Sir Luenn's missing ring. A carried-on party
    -- also finds the museum's loose end there: a drover down off the mountain road, and what he saw.)
    { id = "inn_upstairs", name = "The rooms upstairs", layer = "area", ["in"] = "inn", source = "inn",
      read = "Five bedrooms, two of them shared, and a big sitting room round a great hearth where people tell "
          .. "stories into the night.",
      spots = { "sitting_room", "hearth", "shared_rooms", "sargents_room", "luenn_room", "stairs" }, exits = { { to = "inn_common" } },
      scene = { type = "exploration", quick = true, setting = { "indoor" }, sum = "Sir Luenn's missing ring, and a look round the rooms.",
                cast = "sh_luenn", cast_line = "A pale young noble, dressed far too well for the road, and in a temper.",
                goal = { name = "Sir Luenn's ring", aim = "look into Sir Luenn's ring", short = "find the ring",
                         line = "Goal: find out what happened to Sir Luenn's ring.",
                         line_if = { { when = { flag = "ring_back" }, text = "Goal: a look round upstairs, now the ring's back where it belongs." } },
                         win = "They've had a good look round upstairs.",
                         win_if = { { when = { flag = "ring_back" }, text = "Sir Luenn has his ring, and nobody's blaming Wenna." },
                                    { when = { flag = "ring_clue" }, text = "They've a good idea where the ring went: down." } },
                         lose = "Nobody upstairs can say where the ring went.", got = "a look at Sir Luenn's room" } } },
    { id = "inn_cellar", name = "The cellar", layer = "area", ["in"] = "inn", source = "inn",
      -- (The inn sheet's spiders are in the room's content, M.content: Sam's veil keeps them off screen.)
      read = "Barrels of beer and spirits, sacks of dry goods, and cobwebs in every corner. The old mud floor has turned "
          .. "to clay, and the place reeks of mildew.",
      note = "Dark but for what comes in when the storm doors are open.",
      spots = { "barrels", "sacks", "nest", "floor", "corners", "ladder", "storm_doors" },
      exits = { { to = "inn_common", by = "the trapdoor" }, { to = "inn_yard", by = "the storm doors" } },
      scene = { type = "exploration", quick = true, setting = { "indoor" }, sum = "The inn's cellar, and something behind the barrels.",
                foes = { "pack_rat", "cellar_rats", "cellar_rats" }, foes_name = "The cellar's rats", foes_short = "the rats",
                boss_name = "the pack rat", optional_fight = true, seen = false,
                foes_line = "Behind the last row of barrels, something rustles.",
                wake = "The heap heaves, and rats pour out from behind the barrels, a fat grey one at their head.",
                goal = { name = "The cellar", aim = "poke about in the cellar", short = "look round the cellar",
                         line = "Goal: a look round the cellar.",
                         line_if = { { when = { seen = "luenn_ring", not_flag = "ring_back" },
                                       text = "Goal: a look round the cellar, and an eye out for Sir Luenn's ring." } },
                         win = "They've seen what the cellar has to show.",
                         win_if = { { when = { flag = "ring_found" }, text = "The ring's found, and the cellar's quiet again." },
                                    { when = { flag = "rats_fought" }, text = "The rats are seen off, back into the walls." } },
                         lose = "The rats see them off, nipped and dusty, and the heap goes back behind the barrels.",
                         got = "what was behind the barrels" } } },
    { id = "inn_yard", name = "The loading yard", layer = "area", ["in"] = "inn", source = "inn",
      read = "Room outside for wagons to unload and horses to be tied up. On a fine day it's a stage.",
      note = "In the open, frightened onlookers make difficult ground (p2).", spots = { "stage", "hitching_rail", "gate" },
      exits = { { to = "inn_common" }, { to = "inn_cellar", by = "the storm doors" } } },
    { id = "woods_path", on = true, name = "The path through the oaks", layer = "site", ["in"] = "bogden_road", pages = { 4 },
      read = "A well-used path winding between tall oaks. The ground is churned with feet and paws.",
      spots = { "tracks" }, exits = { { to = "compound", by = "the path" } },
      -- (leaves: once they're on the road, the inn's rooms they didn't look into are behind them for good.)
      scene = { clears = { flags = { "talking" }, line = "Somewhere along the path the scroll wears off. The sheep's next word comes out as a bleat." },
                leaves = { "inn_upstairs", "inn_cellar" },
                 type = "exploration", quick = true, setting = { "outdoor", "wild" }, sum = "A walk into the oaks.",
                goal = { name = "Follow the sheep", line = "Goal: follow the path into the oaks, and see where the sheep leads.",
                         win = "Through the last of the oaks, the tower comes into sight.",
                         lose = "They find it in the end, after a long way round.", got = "the way to Noke's Tower" } } },
    { id = "noke_house", name = "Noke's Tower", layer = "site", ["in"] = "bogden_road", pages = { 4 },
      read = "Four living oaks, their branches woven into three platforms, one above another.",
      note = "The platforms stand 10, 20 and 30 feet up; our boards are flat, so the heights are notes (p4)." },
    { id = "compound", name = "The tower's yard", layer = "area", ["in"] = "noke_house", pages = { 4, 5 },
      read = "Through the treetops: platforms grown from four oaks, one above another. Below them, a lawn, two small "
          .. "wooden huts and a big outhouse.",
      spots = { "lawn", "huts", "outhouse", "slope" },
      exits = { { to = "garden", by = "a ramp of roots" } },
      -- (p5: Noke is up on the platforms, working. He orders the party to give back the sheep, and fights from up
      -- there: Enlarge on the bear once it's out, Ray of Frost, his concentration kept. When the fight's lost or
      -- someone gets close, he runs into the hall and locks it: game/rules/sheep.lua. His bed is a dragon by the time
      -- anyone reaches the bedroom, however long that takes.)
      scene = { type = "combat", setting = { "outdoor", "wild" }, sum = "Noke's guards on the lawn, and Noke above them.",
                foes_at = { noke = { 17, 8 } },
                foes = { "bear_guard", "ape_guard", "ape_guard", "ape_guard", "noke" }, foes_name = "Noke's guards",
                foes_short = "the guards", boss_name = "the bear",
                foes_line = "Three big apes in iron collars squat over a game of dice, greatswords stuck in the turf beside them.",
                goal = { name = "Get past the guards", line = "Goal: get past the guards to the platforms.",
                         win = "The guards are dealt with, and the ramp up is clear.",
                         -- (Ours: the guards win, and Noke has his sheep. The playtest, November 6: "they get past the guards"
                         -- after the whole party went down.)
                         lose = "The guards hold the yard. By the time anyone comes round, the sheep is gone, dragged up the "
                             .. "ramp bleating, and the gate is barred.", lose_sets = "taken",
                         got = "the way up into the house" } } },
    { id = "garden", on = true, name = "The garden platform", layer = "area", ["in"] = "noke_house", pages = { 4 },
      read = "The lowest platform, about forty feet across, ringed with curling branches, flowers and small trees.",
      exits = { { to = "compound" }, { to = "hall", gates = { { check = "athletics", dc = 14, page = 4 },
                                                               { check = "thieves_tools", dc = 12, page = 4 } } } },
      scene = { type = "puzzle", quick = true, setting = { "outdoor" }, sum = "A locked door into the hall.",
                goal = { name = "Get into the hall", line = "Goal: get through the locked door into the hall.",
                         win = "They're through into the hall.", lose = "They get through in the end, with a lot of noise.",
                         got = "a way into the hall" } } },
    { id = "hall", name = "The hall", layer = "area", ["in"] = "noke_house", pages = { 4, 6 },
      read = "The biggest platform, walled in woven branches with window gaps: a library and lab, a sitting room, and "
          .. "a dining room with a kitchen.",
      spots = { "library", "lab", "sitting_room", "kitchen", "door" },
      exits = { { to = "garden" }, { to = "bedroom", by = "a small slope" } },
      -- (p5: Noke ran through here and up to the bedroom, and has three rounds to wake his bed: the bedroom comes
      -- straight after.)
      scene = { type = "exploration", quick = true, setting = { "indoor" }, sum = "Noke's hall, and Noke gone up the slope.", digs = 3,
                hurry_on = true,
                -- (The wand is the goal once Shinebright's told them about it: a sealed scroll keeps it from them.)
                goal = { name = "After Noke", aim = "go after Noke", short = "go after Noke", line = "Goal: through the hall, and after Noke.",
                         line_if = { { when = { flag = "understood" }, text = "Goal: through the hall, and after Noke and the wand." } },
                         win = "The slope up to the bedroom is right there.", lose = "They lose a minute among the shelves.",
                         got = "the way up after Noke" } } },
    { id = "bedroom", name = "The bedroom", layer = "area", ["in"] = "noke_house", pages = { 5, 6 },
      read = "The smallest, highest platform: a wardrobe, a big wooden bed, a dressing table under clutter.",
      spots = { "bed", "wardrobe" }, exits = { { to = "hall" } },
      scene = { type = "combat", setting = { "indoor" }, sum = "Noke's last trick.", foes = { "bed_dragon" },
                foes_name = "The bed dragon", foes_short = "the bed dragon", boss_name = "the bed dragon",
                foes_line = "The big bed against the far wall creaks, all by itself.", seen = false,
                wakes = { feature = "bed", at = { bed_dragon = { 10, 3 } } },
                wake = "The bed rears up on its legs: carved wood for scales, sheets for wings, a pillow on its tail. Noke "
                    .. "scrambles up onto its back.",
                goal = { name = "Stop Noke", line = "Goal: get the wand, and decide what to do with it.",
                         win = "The dragon falls apart into a broken bed.",
                         -- (Ours: the dragon wins, and Noke has his sheep. The gate, November 6: a lost bedroom left nothing to play.)
                         lose = "The bed dragon wins. When they come round among the splinters, Noke is gone, and so is the sheep.",
                         lose_sets = "taken",
                         got = "the wand" } } },
}
M.start = "inn_common"
-- The small moments at the table (game/model/table_life.lua): what to poke at in each scene, who to ask.
M.table_life = require "game.data.sheep.table_life"
-- Lore tips the DM can hand out to point the way (game/model/lore_tips.lua).
M.lore_tips = require "game.data.sheep.tips"
-- Out of sessions with the job not done: Noke's other guards come for the sheep (Conner's three-day clock).
M.timeout_ending = "taken"
-- (A one-shot: its first night covers most of its places, so a small moment's reward can come up even then.)
M.first_night_rewards = true
-- The prep board's story column before anything's happened.
M.story_start = "An afternoon off at the Bogden Road Country Inn, where the Bogden road meets the lord's road."

-- People ----------------------------------------------------------------------------------------------------------
-- tier: named (the book's own), local (from a type template), crowd. stats: a core block by name with tweaks, or
-- the adventure's own (M.creatures). understood: what it takes for the table to understand them.
M.people = {
    { id = "sh_teddy", name = "Teddy Bolandeere", short = "Teddy", tier = "named", role = "Innkeeper and barman", known = true, source = "inn",
      pronoun = "he", look = "Short, round and brown, with a fatherly hand on every shoulder.",
      about = "Theodoro Bolandeere has run the inn for over twenty years. Warm and well loved, and behind the bar he "
          .. "hears every story on the road.",
      wants = "A full house and no trouble", knows = { "rumours" }, where = { "inn_common" } },
    { id = "sh_shinebright", name = "Finethir Shinebright", short = "Shinebright", tier = "named", role = "The sheep", pages = { 2, 3, 6 },
      pronoun = "he", companion = true,
      look = "A sheep like any other: white fleece, black face, curled horns.",
      voice = "Educated, fussy, an elven accent, and a little bleat at the end of words.",
      about = "A transmuter who was famous once. Vain, fussy and full of lectures, but kind when it doesn't cost "
          .. "him much. As an elf: thin as a reed, hair like straw, a very long nose (p2).",
      wants = "His wand back, and his own shape", knows = { "sheep_wizard", "guards_are_people", "wand_on_noke", "second_scroll" },
      stats = { core = "pony", int = 18, wis = 14, page = 2 },
      understood = { item = "speak_scroll", spell = "speak_with_animals", flag = "talking" } },
    { id = "sh_guz", name = "Guz", tier = "named", role = "Noke's man", pages = { 2, 3 }, pronoun = "he",
      look = "A huge half-orc with small eyes, a hand never far from his greatsword.",
      voice = "Slow and blunt, with long words of Noke's he hasn't quite got right.",
      about = "Loyal to Noke, who never cared what he looked like. Thinks violence is how everyone gets things done.",
      wants = "Master Noke's sheep, alive", stats = { block = "guz" }, where = { "inn_common", "compound" } },
    { id = "sh_noke", name = "Ahmed Noke", short = "Noke", tier = "named", role = "The apprentice", pages = { 4, 5, 6 }, pronoun = "he",
      look = "A frantic young human wizard, ink on his fingers, eyes that don't stop moving.",
      voice = "Fast and disjointed, boasting one moment and bitter the next.",
      about = "Served Shinebright for years and was never treated as more than a boy. Took the wand. Now he can't sleep "
          .. "for fear someone does the same to him.",
      wants = "Fame, a great contract, and nobody coming for the wand", knows = { "noke_why", "wand_on_noke", "bed_escape", "wand_unreliable" },
      stats = { block = "noke" }, where = { "hall" } },
    { id = "sh_turleon", name = "Count Behpoh Turleon", short = "Count Turleon", tier = "named", role = "A noble with an appetite", source = "inn",
      pronoun = "he", colour = true, look = "Stout and richly dressed, always near the food.",
      about = "A greedy, pleasure-loving count who'll slum it anywhere the common folk might put on a show. Pays "
          .. "anyone to \"perform\" for him, and what that means changes daily. With nothing to watch, he makes a show of his own.",
      wants = "A good meal and a spectacle", where = { "inn_common" } },
    { id = "sh_luenn", name = "Sir Luenn of Nordenin", short = "Sir Luenn", tier = "named", role = "A noble's second son", source = "inn",
      pronoun = "he", colour = true, look = "Pale, fair-haired and handsome, dressed far too well for the road.",
      about = "Lives on his father's money and his looks, and expects to be treated accordingly; when he isn't, he's "
          .. "unbearable. Would hire adventurers as bodyguards if a fight broke out, and carries the gold and jewels to do it.",
      wants = "Courtesy, and somebody else between him and trouble", where = { "inn_upstairs" } },
    -- (Ours, for the side quest upstairs: Teddy's niece, whom Sir Luenn blames for his ring.)
    { id = "sh_wenna", name = "Wenna Bolandeere", short = "Wenna", tier = "named", role = "A maid, and Teddy's niece", pronoun = "she",
      look = "Freckled and quick, flour to the elbows, her hair coming down.",
      about = "Teddy's sister's girl, who has worked at the inn since she was small and knows every room in it. She's never "
          .. "taken a thing, and right now nobody but her uncle believes her.",
      wants = "Her name cleared", where = { "inn_upstairs" } },
    -- (Ours, for a party carried on from the museum: the traveller down from the mountains that Teddy's rumour speaks of,
    -- who found the dead man the museum's last thread is about. A later adventure on the mountain road can bring him back.)
    { id = "sh_drover", name = "Hobb Marrow", short = "Hobb", tier = "named", role = "A drover down off the mountain road", pronoun = "he",
      look = "Weathered and silent, a hat turning round and round in his hands.",
      about = "Brought a string of mules down the mountain road and hasn't said ten words since. He found the dead man up "
          .. "there, and he was carrying something of the dead man's home to his mother, until it went missing in the night.",
      wants = "What he lost, back, and someone to tell" },
    { id = "inn_staff", name = "The inn's people", tier = "local", role = "Staff", source = "inn",
      about = "Two dozen of them, and half are family to the Bolandeeres, born or married in; the rest are farmers' children lucky "
          .. "to get the work. Teddy pays well, and they're loyal to him.",
      template = { jobs = { "bartender", "cook", "cleaner", "washer" }, want = "to keep Teddy happy", quirk = "gossip" } },
    { id = "inn_crowd", name = "Drinkers and travellers", tier = "crowd", source = "inn", where = { "inn_common", "inn_yard" },
      about = "Mostly travellers and farmers, with adventurers, merchants, highwaymen and drifters among them." },
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
    noke = { name = "Ahmed Noke", short = "Noke", page = 5, size = "medium", type = "humanoid", ac = 12, hp = 55, hit_dice = "10d8+10",
             speed = 30, abilities = { str = 9, dex = 14, con = 12, int = 16, wis = 12, cha = 10 },
             saves = { int = 5, wis = 4 }, skills = { arcana = 6 }, cr = "2", xp = 450,
             spellcasting = { level = 7, ability = "int", dc = 14, to_hit = 6,
                              cantrips = { "ray_of_frost", "mending", "prestidigitation", "message" },
                              slots = { 4, 3, 3, 1 },
                              known = { { "expeditious_retreat", "jump", "thunderwave" }, { "enlarge_reduce", "levitate" },
                                        { "haste", "slow" }, { "polymorph" } } },
             attacks = { { id = "dagger", name = "Dagger", kind = "melee", to_hit = 5, reach = 5, range = { 20, 60 },
                           damage = { { 1, 4, 2, "piercing" } } },
                         -- (Ray of Frost from his cantrips, as an attack: a 7th-level caster's 2d8.)
                         { id = "ray_of_frost", name = "Ray of Frost", kind = "ranged", to_hit = 6, range = { 60, 60 },
                           damage = { { 2, 8, 0, "cold" } } } },
             -- (Thunderwave, from his first-level slots: game/rules/sheep.lua.)
             rules_turn = "noke", thunderwave = { id = "thunderwave", save = "con", dc = 14, damage = { { 2, 8, 0, "thunder" } },
                                                  half = true, slots = 4 },
             -- (His second- and third-level slots: Enlarge on the bear once it's out, else Haste on an ape. One at a time:
             -- concentration. p5.)
             buffs = { enlarge = { slots = 3, on = "bear_guard", dice = { 1, 4, 0 } }, haste = { slots = 3, on = "ape_guard" } },
             flees_below = 0.5, escapes = true,
             flee_line = "%s casts Expeditious Retreat, blurs up the ramp into the hall, and the door slams and locks behind him.",
             tactics = "Weak in a fight himself. Enlarges the bear once it's out, adds Ray of Frost, guards his "
                 .. "concentration, and runs for the bedroom when it's lost or someone gets close." },
    bed_dragon = { name = "Bed Dragon Wyrmling", page = 5, size = "large", type = "dragon", ac = 16, hp = 75, rules_turn = "bed_dragon",
                   hit_dice = "10d8+30", speed = 30, climb = 30, fly = 30,
                   abilities = { str = 19, dex = 14, con = 17, int = 8, wis = 8, cha = 4 },
                   skills = { perception = 2, stealth = 5 }, vulnerable = { "fire" }, cr = "4", xp = 1100,
                   attacks = { { id = "bite", name = "Bite", kind = "melee", to_hit = 6, reach = 5, damage = { { 2, 10, 4, "piercing" } } } },
                   breath = { id = "splinter_breath", name = "Splinter Breath", recharge = { 5, 6 }, cone = 15, save = "dex",
                              dc = 13, damage = { { 7, 6, 0, "piercing" } }, half = true },
                   -- (p5: Noke rides it, and his Ray of Frost goes after whoever's backing away. game/rules/sheep.lua.)
                   rider = { name = "Noke", attack = { id = "ray_of_frost", name = "Noke's Ray of Frost", kind = "ranged", to_hit = 6,
                                                       range = { 60, 60 }, damage = { { 2, 8, 0, "cold" } } } },
                   look = "A dragon of carved wood, bedsheets for wings, a pillow on the end of its tail.",
                   tactics = "Breathes whenever it can, else bites whoever's closest; goes for anyone using fire on it. "
                       .. "Turns back into a battered bed if it drops or Noke's concentration breaks." },
    wolf_guard = { core = "wolf", page = 2, mind = "a person inside", note = "Iron collars, eyes far too clever. Goes "
                       .. "round the party for the sheep." },
    bear_guard = { core = "brown_bear", page = 2, rules_turn = "guard", mind = "a person inside", note = "Under a filthy brown cloak until the "
                       .. "hood comes down." },
    ape_guard = { core = "ape", page = 5, rules_turn = "guard", mind = "a person inside", flees_below = 0.5,
                  tweaks = { attacks = { { id = "greatsword", name = "Greatsword", kind = "melee", to_hit = 5, reach = 5,
                                           damage = { { 2, 6, 3, "slashing" } } } } } },
    sheep = { core = "pony", page = 2, int = 18, wis = 14, note = "Shinebright, as a sheep." },
    -- (Ours, the cellar's side quest: a pack rat the size of a cat, numbers like the SRD's giant rat, and the rats of its
    -- nest as swarms. A quick scrap for a party of fourth level, or none at all if they're clever.)
    pack_rat = { name = "Pack Rat", short = "the pack rat", size = "small", type = "beast", ac = 13, hp = 9, hit_dice = "2d6+2",
                 speed = 30, abilities = { str = 7, dex = 16, con = 12, int = 3, wis = 10, cha = 4 }, cr = "1/8", xp = 25,
                 traits = { "pack_tactics" },
                 attacks = { { id = "bite", name = "Bite", kind = "melee", to_hit = 5, reach = 5, damage = { { 1, 4, 3, "piercing" } } } },
                 flees_below = 0.5, flee_line = "%s drops what's in its teeth and dives into a crack in the clay wall.",
                 look = "A fat grey rat the size of a cat, with something shiny always in its teeth.",
                 tactics = "Bites from behind its swarms, and bolts for the wall when it's hurt." },
    cellar_rats = { core = "swarm_of_rats", note = "The rest of the nest." },
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
    -- (Hooks for other books, from the inn sheet: not played here, carried for a later adventure to pick up.)
    { id = "the_suitor", name = "Sir Luenn's courting", who = "sh_luenn", source = "inn", tags = { "suitor", "proposal", "luenn" },
      open_at_end = true, text = "Sir Luenn is on the road as a suitor. The inn sheet makes him the proposer in another "
          .. "book, An Enchanting Proposal." },
    { id = "noke_free", name = "Noke and the wand", tags = { "noke", "polymorph", "wand" }, open_at_end = true,
      when = { flag = "taken" }, ours = true,
      text = "Noke has his master back in the garden, the wand still in his sleeve, and he knows the party's faces." },
    -- (Ours: the museum's mountain road, picked up at the inn. What Hobb saw goes on with the party, under the same tags.)
    { id = "hobbs_word", name = "What Hobb saw", who = "sh_drover", tags = { "mountain_road", "murder", "mountains" }, ours = true,
      open_at_end = true, when = { flag = "drover_talked" },
      text = "Hobb the drover found the dead clan messenger at the foot of the pass, his cloak dry after a night of rain: "
          .. "carried there after, not fallen." },
    { id = "the_guards", name = "The changed guards", pages = { 6 }, tags = { "polymorph", "shinebright" },
      open_at_end = true, when = { flag = "restored" },
      text = "Shinebright takes in the changed guards who ran, and means to give them their shapes back." },
}

-- trigger: on = arrive (a place), after (another event), choice (the table's), fight (it starts or turns), round
-- (a count of rounds after something), clock. required: it always happens. only_if: a condition on the log.
-- The wand on Shinebright (p6): a spellcaster's DC 17 Intelligence (Arcana) check; short by five or less, he becomes a
-- gibbering mouther; by more, the wand also blows apart (1d12 force a charge on everyone within 10 feet).
local WAND_ROLL = { dc = 17, skill = { "arcana" }, best = true, casters = true,
    success = { log = "Light, a sound like a bell, and an elf stands where the sheep was, naked as the day: Finethir Shinebright, "
                    .. "who thanks them at great length and only gets to the money at the very end. There isn't any.",
                mus = { flag = "restored" }, tells = { "sheep_wizard", "cant_pay" }, tells_how = "moment" },
    fail = { log = "The wand bangs. Where the sheep was, a heap of mouths and eyes starts to gibber.", mus = { flag = "dead" } } }

M.events = {
    { id = "sheep_arrives", at = "inn_common", when_in = "start", required = true, page = 2, type = "story",
      title = "A sheep at a gallop", actor = { "storyteller" },
      text = "Hooves on the boards, yelps, frantic bleating: a sheep comes through the crowd at a run, a fancy scroll in "
          .. "its teeth, and makes straight for their table." },
    -- (p2: the sheep picks out whoever looks the most magical: Thessaly, when she's there.)
    { id = "scroll_read", at = "inn_common", when_in = "start", page = 2, party = true, title = "The scroll",
      actor = { "storyteller" },
      text = "The sheep drops the scroll in {actor_char}'s lap and stares up, waiting. The wax seal says Speak with "
          .. "Animals, modified.",
      options = {
          { label = "Break the seal and read it aloud.", want = "read the scroll and see what happens", short = "read it",
            lean = "look", log = "The words come out strange and old. The bleating turns into Common, with an elven accent. \"Finethir Shinebright,\" it says, \"transmuter, of some renown. Please. I need your help, and I can explain everything.\"",
            mus = { flag = "understood", flags = { "talking" } }, tells = { "sheep_wizard" }, tells_how = "read" },
          { label = "Check it over before anyone reads it.", want = "check the scroll over before anyone reads it",
            short = "check it first", lean = "safe",
            roll = { dc = 8, skill = { "arcana", "investigation" }, best = true,
                     success = { log = "A real scroll, a little odd, and nothing nasty in it. They break the seal. The bleating turns into Common, with an elven accent. \"Finethir Shinebright,\" it says, \"transmuter, of some renown. Please. I need your help, and I can explain everything.\"",
                                 mus = { flag = "understood", flags = { "talking" } }, tells = { "sheep_wizard" }, tells_how = "check" },
                     fail = { log = "Nobody can make head or tail of the seal, so it stays shut. The sheep butts it at their hands again, bleating, desperate." } } },
      } },
    { id = "guz_arrives", at = "inn_common", when_in = "mid", required = true, page = 2, party = true, title = "Noke's man",
      actor = { "tactician", "butt_kicker", "method_actor" },
      text = "Howling outside, and shouting. A huge half-orc shoulders in behind three collared wolves, a big figure in a "
          .. "dirty cloak at his back. \"Master Noke's sheep,\" he says, and holds out his hand. \"Give it here, and "
          .. "there won't be no unpleasantries.\"",
      options = {
          { label = "No. The sheep stays with us.", want = "tell him no, and see what he does", short = "refuse",
            lean = "bold", log = "Guz looks at them for a long moment. Then the wolves go for the sheep.",
            mus = { fight = true } },
          { label = "Talk him out of it.", want = "talk him round before anyone gets hurt", short = "talk him down", lean = "talk",
            roll = { dc = 15, skill = { "persuasion", "intimidation" }, best = true,
                     success = { log = "Guz works it through slowly, and doesn't like where it ends. He calls the wolves off and goes.",
                                 mus = { flag = "guz_left", no_fight = true } },
                     fail = { log = "Guz has heard enough. He draws the greatsword without a word.", mus = { fight = true } } } },
          { label = "Hand the sheep over. Not their business.", want = "let Noke's man have his sheep", short = "hand it over",
            lean = "safe", when = { not_flag = "understood" },
            effects = { { "all", fun = -3 }, { "arch:casual", fun = 2 } },
            log = "Guz tucks the sheep under one arm and leaves. The bleating fades down the road.",
            mus = { flag = "taken", no_fight = true } },
      } },
    { id = "hood_falls", at = "inn_common", trigger = { on = "fight", event = "guz_arrives" }, page = 2,
      text = "The cloaked figure throws back its hood with a roar: a bear.", sets = { "bear_seen" } },
    -- (Ours: a sheep that won't give up. A table that left the scroll sealed gets it back once the fuss is over.)
    { id = "scroll_again", at = "inn_common", when_in = "end", only_if = { not_flag = { "understood", "taken" } }, ours = true,
      party = true, title = "The scroll, again", actor = { "storyteller" },
      text = "Once it's quiet, the sheep noses the scroll back into {actor_char}'s hands and holds it there with one hoof.",
      options = {
          { label = "All right. Break the seal and read it.", want = "read the scroll this time", short = "read it", lean = "look",
            log = "The words come out strange and old. The bleating turns into Common, with an elven accent. \"Finethir Shinebright,\" it says, \"transmuter, of some renown. Please. I need your help, and I can explain everything.\"",
            mus = { flag = "understood", flags = { "talking" } }, tells = { "sheep_wizard" }, tells_how = "read" },
          { label = "Still no. Let it follow if it wants.", want = "leave the scroll sealed and let the sheep tag along",
            short = "leave it", lean = "safe",
            log = "The scroll goes in a pack, still sealed. The sheep follows them out onto the road, bleating at every step." },
      } },
    { id = "the_story", at = "inn_common", when_in = "end", only_if = { flag = "understood", not_flag = "taken" }, pages = { 3 },
      type = "story", title = "Shinebright's story", actor = { "storyteller", "casual", "explorer" },
      text = "Shinebright tells it all, at length: the tower in the oaks, and the wand his apprentice Noke turned on him "
          .. "and keeps on him day and night. Guz's beasts, the bear and the wolves, were people once: Noke's guards, changed. "
          .. "Noke has more of them, and they'll come looking. He promises them riches if they'll get his wand back.", tells = { "guards_are_people", "wand_on_noke" } },
    -- Sir Luenn's ring (ours): the side quest across the inn's upstairs and cellar. The hook comes down the stairs once
    -- the Guz business is over; the clues are upstairs; the ring is in a pack rat's nest behind the cellar barrels.
    { id = "luenn_ring", at = "inn_common", when_in = "end", only_if = { not_flag = "taken" }, ours = true, type = "story",
      title = "Sir Luenn's ring",
      text = "Boots on the stairs, and down them in a temper comes a pale young man in clothes far too good for the road: "
          .. "Sir Luenn of Nordenin, as he tells the whole room. His father's signet ring is gone from his room, and he knows "
          .. "who took it: the girl who made his bed. Teddy goes red to the ears. \"Wenna's my sister's girl, my lord. She's "
          .. "never taken so much as a crust.\" Sir Luenn offers twenty gold to whoever finds the ring, and the magistrate to "
          .. "whoever took it.",
      -- (A party carrying the museum's mountain road: the quiet traveller Teddy's rumour spoke of lost something too.)
      text_if = { { when = { thread = "mountain_road" },
                    text = "Boots on the stairs, and down them in a temper comes a pale young man in clothes far too good for the "
                        .. "road: Sir Luenn of Nordenin, as he tells the whole room. His father's signet ring is gone from his room, "
                        .. "and he knows who took it: the girl who made his bed. Teddy goes red to the ears. \"Wenna's my sister's "
                        .. "girl, my lord. She's never taken so much as a crust.\" Sir Luenn offers twenty gold to whoever finds the "
                        .. "ring. By the fire, a drover down off the mountain road looks up at that, then back at his hands. "
                        .. "\"Hobb lost something in the night as well,\" Teddy says quietly. \"Won't say what. Won't say much of "
                        .. "anything, since he came down.\"" } } },
    { id = "sheep_taken", trigger = { on = "choice", choice = "the wolves carry the sheep off" }, page = 2,
      text = "Guz's lot make for the woods with the sheep. A chase, if anyone follows." },
    { id = "ring_room", at = "inn_upstairs", when_in = "start", only_if = { seen = "luenn_ring", not_flag = "ring_found" }, ours = true,
      party = true, title = "Sir Luenn's room", actor = { "explorer", "method_actor", "instigator" },
      text = "Sir Luenn flings open his door: a good bed, a washstand, a small window, and on the washstand an open jewel box "
          .. "with nothing in it. \"There,\" he says. \"Gone in the night.\" Wenna hovers in the doorway behind them, twisting "
          .. "her apron.",
      options = {
          { label = "Look the room over.", want = "look the room over for whoever took it", short = "search the room", lean = "look",
            roll = { dc = 12, skill = { "investigation", "perception" }, best = true,
                     success = { log = "In the jewel box, where the ring should be, sits a beer cork stamped with the inn's B. Under "
                                     .. "the washstand, a hole gnawed through the skirting, grey hairs caught on its edge. Something "
                                     .. "small took the ring, and left a cork from the cellar in its place.",
                                 mus = { flag = "ring_clue" }, tells = { "ring_thief" }, tells_how = "check" },
                     fail = { log = "A good bed, a washstand, an empty box. Nothing that says who." } } },
          { label = "Ask Wenna what she saw.", want = "hear Wenna's side of it", short = "ask Wenna", lean = "talk",
            roll = { dc = 10, skill = { "insight", "persuasion" }, best = true,
                     success = { log = "Wenna's telling the truth, and she's frightened. \"Things go missing here all the time,\" she "
                                     .. "whispers. \"Spoons. Buttons. Mam's thimble. Uncle Teddy says it's the damp in the cellar. "
                                     .. "Damp doesn't take thimbles.\"",
                                 mus = { flag = "ring_clue" } },
                     fail = { log = "Wenna just cries, and Sir Luenn says that proves it." } } },
          { label = "Tell Sir Luenn to leave the girl alone.", want = "stand up for Wenna", short = "stand up for her", lean = "bold",
            roll = { dc = 13, skill = { "persuasion", "intimidation" }, best = true,
                     success = { log = "Sir Luenn opens his mouth, shuts it again, and allows that he'll wait for proof. Wenna gives "
                                     .. "them a look of pure gratitude.", mus = { flag = "wenna_safe" } },
                     fail = { log = "Sir Luenn draws himself up. \"The magistrate in Bogden will hear of it by morning,\" he says, "
                                  .. "and shuts the door on them." } } },
      } },
    { id = "the_nest", at = "inn_cellar", when_in = "mid", ours = true, party = true, title = "Behind the barrels",
      actor = { "explorer", "butt_kicker", "casual" },
      text = "Behind the last row of barrels, a heap of the inn's lost things: spoons, buttons, a thimble, a bent fork, all "
          .. "winking in the lamplight. Something under the heap is breathing.",
      text_if = {
          { when = { flag = "ring_clue", thread = "mountain_road" },
            text = "Behind the last row of barrels, the heap they were looking for: spoons, buttons, a thimble, a little horn "
                .. "token on a cord, and in among them a glint of gold the size of a signet ring. Something under the heap is breathing." },
          { when = { flag = "ring_clue" },
            text = "Behind the last row of barrels, the heap they were looking for: spoons, buttons, a thimble, and in among them "
                .. "a glint of gold the size of a signet ring. Something under the heap is breathing." },
          { when = { thread = "mountain_road" },
            text = "Behind the last row of barrels, a heap of the inn's lost things: spoons, buttons, a thimble, a little horn "
                .. "token on a cord, all winking in the lamplight. Something under the heap is breathing." } },
      options = {
          { label = "Shift the barrels and grab the lot.", want = "shift the barrels and grab the heap", short = "grab it", lean = "bold",
            log = "The first barrel rolls aside, and the heap explodes into rats.", mus = { fight = true, flag = "rats_fought" } },
          { label = "Coax out whatever's under there with something to eat.", want = "lure whatever's under there out with food",
            short = "lure it out", lean = "safe",
            roll = { dc = 12, skill = { "animal_handling", "nature" }, best = true,
                     success = { log = "A crust, a rind of cheese, and a lot of patience. A fat grey rat noses out, then another and "
                                     .. "another, and they follow the crumbs out through the storm doors and away across the yard. "
                                     .. "The heap is theirs.", mus = { flag = "ring_found" } },
                     fail = { log = "The cheese goes, and very nearly a finger with it. The heap boils over with rats.",
                              mus = { fight = true, flag = "rats_fought" } } } },
          { label = "Reach in quietly and lift out what shines.", want = "lift the shiny things out without waking anything",
            short = "lift it", lean = "look",
            roll = { dc = 13, skill = { "sleight_of_hand", "stealth" }, best = true,
                     success = { log = "Two fingers, very slowly. Out come a spoon, a thimble, a button, and a heavy gold ring with "
                                     .. "a crest on it. The heap sighs, and settles.", mus = { flag = "ring_found" } },
                     fail = { log = "A spoon clinks against a fork, and the whole heap wakes up at once.",
                              mus = { fight = true, flag = "rats_fought" } } } },
      } },
    -- (After a fight they won: the heap is theirs. A lost fight plays no end moments, so the ring stays in the nest.)
    { id = "nest_after_fight", at = "inn_cellar", when_in = "end", only_if = { flag = "rats_fought", not_flag = "ring_found" },
      ours = true, type = "story", title = "The heap", sets = { "ring_found" },
      text = "With the last rat gone through a crack in the clay, the heap is theirs: spoons, buttons, a thimble, and a heavy "
          .. "gold ring with a crest on it." },
    { id = "ring_back", at = "inn_cellar", when_in = "end", only_if = { flag = "ring_found" }, ours = true, party = true,
      title = "The ring", actor = { "storyteller", "method_actor", "casual" },
      text = "Back up the ladder, Sir Luenn is at the bar telling anyone who'll listen about thieving staff, and Wenna is "
          .. "behind it, red-eyed.",
      text_if = { { when = { flag = "wenna_safe" },
                    text = "Back up the ladder, Sir Luenn is at the bar, waiting for his proof with very bad grace. Wenna is "
                        .. "behind it, watching the trapdoor." } },
      options = {
          { label = "Give it back to Sir Luenn.", want = "hand Sir Luenn his ring", short = "give it back", lean = "safe",
            log = "Sir Luenn turns the ring over, slides it on, and counts out twenty gold as if every coin hurts. He doesn't "
                .. "look at Wenna. Teddy does, and squeezes her shoulder.", mus = { flag = "ring_back" } },
          { label = "Let Wenna give it back to him.", want = "let Wenna hand it over herself", short = "let Wenna do it", lean = "talk",
            log = "Wenna holds the ring out in front of the whole common room, and Sir Luenn has to thank her, and does, badly, "
                .. "and pays up. Teddy brings a dusty bottle out from under the bar and won't hear no: a healing potion a "
                .. "traveller paid his bill with, years back.", mus = { flag = "wenna_thanked", flags = { "ring_back" } } },
      } },
    -- (The museum's last thread, for a party carried on from it: what the pack rat took from the drover.)
    { id = "token_back", at = "inn_cellar", when_in = "end", only_if = { thread = "mountain_road", flag = "ring_found" }, ours = true,
      party = true, title = "The drover's token", actor = { "storyteller", "method_actor", "explorer" },
      text = "One more thing out of the heap: a little horn token on a cord, capped in silver, a mountain clan's mark cut into "
          .. "it. Teddy knows it at once. \"That's Hobb's. The drover by the fire, down off the mountain road. He's not said "
          .. "ten words since he came in.\" Hobb holds it in both hands for a long moment.",
      options = {
          { label = "Ask him what happened up the mountain road.", want = "hear what Hobb saw up the mountain road", short = "ask him",
            lean = "talk",
            log = "\"I found him,\" Hobb says. \"A clan messenger, at the foot of the pass, like he'd fallen. It rained all that "
                .. "night, and his cloak was bone dry. Somebody carried him there after.\" He turns the token over. \"This was "
                .. "his. I was taking it down to his mother. Nobody up there wanted it asked about.\"",
            mus = { flag = "drover_talked" } },
          { label = "Give it back, and let him be.", want = "give Hobb his token and leave him in peace", short = "let him be",
            lean = "safe", log = "Hobb closes his hand round it, nods his thanks, and goes back to staring at the fire." },
      } },
    { id = "tracks", at = "woods_path", when_in = "start", page = 4, party = true, title = "The path",
      actor = { "explorer", "tactician", "casual" },
      text = "A mile along the lord's road, there's a gap in the bushes, and the path goes off into the oaks.",
      options = {
          { label = "Read the tracks as they go.", want = "read the tracks and see who's been this way", short = "read the tracks",
            lean = "look", roll = { dc = 12, skill = { "survival", "nature" }, best = true,
                                    success = { log = "The freshest tracks are a big man's boots and four sets of paws, heading home. Noke's Tower isn't far.",
                                                mus = { flag = "tracked" } },
                                    fail = { log = "Too many feet, too many paws. They follow the path and see where it goes." } } },
          { label = "Just walk. Shinebright knows the way.", want = "keep moving and let the sheep lead", short = "walk on", lean = "safe",
            log = "The sheep trots ahead, stopping every so often to make sure they're still following." },
      } },
    { id = "bear_comes_out", at = "compound", trigger = { on = "fight", at = "compound" }, page = 5,
      text = "The outhouse door bangs open, and a bear comes out to see what the noise is.", sets = { "bear_seen" } },
    { id = "the_door", at = "garden", when_in = "start", page = 4, party = true, title = "The hall door",
      actor = { "instigator", "butt_kicker", "tactician" },
      text = "The door into the hall is heavy oak, and locked.",
      options = {
          { label = "Shoulder it open.", want = "put a shoulder to that door", short = "force it", lean = "bold",
            roll = { dc = 14, skill = { "athletics" }, best = true,
                     success = { log = "The lock gives with a crack, and the door swings in." },
                     fail = { log = "It takes three goes and a lot of noise. Anyone inside knows they're coming.", mus = { flag = "noisy" } } } },
          { label = "Pick the lock.", want = "pick the lock quietly", short = "pick it", lean = "safe",
            roll = { dc = 12, skill = { "sleight_of_hand" }, best = true,
                     success = { log = "A click, and the door eases open without a sound." },
                     fail = { log = "The pick snaps. In the end they force it, loudly.", mus = { flag = "noisy" } } } },
      } },
    { id = "noke_demand", at = "compound", when_in = "start", page = 5, party = true, title = "Noke",
      actor = { "method_actor", "storyteller", "butt_kicker" },
      text = "A thin man in a stained robe leans over the rail of the platform above. \"My man, Guz,\" he calls down. "
          .. "\"Where is he?\" Nobody answers, and his face falls. \"Never mind. Give me back the sheep, and I won't destroy you.\"",
      text_if = { { when = { flag = "guz_left" },
                    text = "A thin man in a stained robe leans over the rail of the platform above. \"Guz came back without my "
                        .. "sheep,\" he calls down. \"Talked out of it, he says. Well. Give me back the sheep, and I won't destroy you.\"" } },
      options = {
          { label = "Refuse. They're taking the wand.", want = "refuse him and go for the wand", short = "refuse", lean = "bold",
            log = "\"Then you're no use to me,\" Noke says, and shouts to the apes: \"Get my sheep!\"", mus = { fight = true } },
          { label = "Give him the sheep.", want = "give the sheep back to Noke", short = "give it back", lean = "safe",
            when = { not_flag = { "restored", "understood" } },     -- (once they've heard Shinebright, unthinkable)
            log = "The apes come and lead the sheep up the ramp, bleating. Noke doesn't even look at it. \"Good. Now go away.\"",
            mus = { flag = "taken", no_fight = true } },
          { label = "Hear him out first.", want = "hear his side before anyone casts anything", short = "hear him out", lean = "talk",
            log = "It comes out of him in a rush: years of chores, a master who never once called him a wizard. \"Take the "
                .. "wand if you like,\" he says. \"See what it makes of you. It's not the wand it was.\" Then he remembers "
                .. "who they've brought with them, and the air starts to fizz.",
            tells = { "noke_why", "wand_unreliable" }, tells_how = "ask", mus = { fight = true, flag = "heard_noke" } },
      } },
    { id = "noke_flees", at = "compound", trigger = { on = "fight", turn = "lost or someone close" }, page = 5,
      text = "Noke casts, blurs up the ramp into the hall, and locks the door behind him." },
    { id = "hall_search", at = "hall", when_in = "end", page = 6, party = true, title = "Noke's things",
      actor = { "explorer", "power_gamer", "instigator" },
      text = "With Noke gone up the slope, the hall is theirs: the library, the lab, and everything he bought with his "
          .. "master's money.",
      options = {
          { label = "Search the place, quickly.", want = "search the hall before going after him", short = "search it", lean = "look",
            log = "Lab gear worth a small fortune, and on the library shelves, a second scroll with the same seal as the "
                .. "first. {actor_char} reads it out, and the sheep's bleating turns into words.",
            mus = { flag = "looted", flags = { "talking", "understood" } }, tells = { "second_scroll", "sheep_wizard" },
            tells_how = "check" },
          { label = "Leave it. Noke first.", want = "go straight after Noke", short = "go after him", lean = "bold",
            log = "No time for the shelves. Up the slope, after him.", mus = { rush = true } },
      } },
    { id = "bed_dragon", at = "bedroom", when_in = "start", required = true, page = 5, type = "story", title = "The bed",
      text = "Up the slope to the top platform. Noke backs into the bedroom, the wand sparking in his fist, and points it at "
          .. "the big bed." },
    { id = "mouther", at = "bedroom", when_in = "end", page = 5, type = "story", title = "The wand misfires",
      text = "Babbling, Noke turns the wand on himself. It fizzes, bangs, and leaves a heap of mouths and eyes that drags "
          .. "itself into the trees. The wand rolls loose." },
    { id = "wand_touched", trigger = { on = "choice", choice = "pick up or handle the wand" }, page = 6,
      text = "The wand sparks under their fingers, not the way magic should." },
    { id = "the_spell", at = "bedroom", when_in = "end", page = 6, party = true, title = "The wand",
      risks = "shinebright",      -- (the risk is his, not theirs: a hurt hero doesn't make anyone shy of it)
      actor = { "storyteller", "tactician", "method_actor" },
      text = "The wand lies on the boards, sparking, not the way magic should. The sheep noses it towards them and bleats, once.",
      text_if = { { when = { flag = "talking" },
                    text = "The wand lies on the boards, sparking, not the way magic should. Shinebright looks up at them. "
                        .. "\"If this kills me,\" he says, \"tell my college.\"" } },
      -- (p6: only a spellcaster who's spent an hour attuning to it can use it, a DC 17 Intelligence (Arcana) check; a DC 15
      -- Arcana check on it shows how unreliable it is. Whoever's best at it of the casters at the table does it.)
      options = {
          { label = "Do it. Try the wand on him.", want = "give him his shape back with the wand", short = "use the wand",
            lean = "bold", roll = WAND_ROLL },
          { label = "Look at the wand properly first.", want = "work out what's wrong with that wand before anyone uses it",
            short = "study it", lean = "look", roll = { dc = 15, skill = { "arcana" }, best = true,
                     success = { log = "Someone's forced this wand to hold more than it should. Used, it makes monsters as often as wizards.",
                                 tells = { "wand_unreliable" }, tells_how = "check", mus = { flag = "studied" } },
                     fail = { log = "Nothing obvious, except that it sparks when it shouldn't.", mus = { flag = "studied" } } } },
          { label = "Don't risk it.", want = "leave the wand alone", short = "leave it", lean = "safe",
            log = "The wand goes in a pack, unused. The sheep finds an old robe in the wardrobe and pulls it on over its fleece.",
            mus = { flag = "refused" } },
      } },
    -- (p6: told how dangerous it is, Shinebright still wants to risk it; a good argument and a DC 15 Charisma
    -- (Persuasion) check talks him out of it.)
    { id = "the_spell_again", at = "bedroom", when_in = "end", page = 6, party = true, title = "He still wants it",
      only_if = { flag = "studied", not_flag = { "restored", "dead", "refused" } },
      risks = "shinebright", actor = { "storyteller", "method_actor", "tactician" },
      text = "The sheep plants its hooves by the wand and won't move. Whatever it costs, it wants to be an elf again.",
      text_if = { { when = { flag = "talking" },
                    text = "\"I don't care what's wrong with it,\" Shinebright says. \"I want my hands back. Do it.\"" } },
      options = {
          { label = "Do it anyway.", want = "try the wand on him anyway", short = "use the wand", lean = "bold", roll = WAND_ROLL },
          { label = "Talk him out of it.", want = "talk him out of the wand", short = "talk him out of it", lean = "talk",
            roll = { dc = 15, skill = { "persuasion" }, best = true,
                     success = { log = "It takes a while, and a good argument. In the end he lets the wand go in a pack, and thanks them for it.",
                                 mus = { flag = "refused" } },
                     fail = { log = "He won't hear it. The wand goes in a pack anyway, and the sheep doesn't speak to them all the way back.",
                              mus = { flag = "refused" } } } },
      } },
}

-- Each ending as a condition on the log (adventure.test).
-- The story so far, in the table's words (the chain and "last time": museum_night.beat_clause): each choice as what
-- they did, `ok` when its roll came off. The playtest, November 6: "the party read the scroll and see what happens".
M.beats = {
    scroll_read = { "they read the sheep's scroll aloud, and the sheep began to talk",
                    { ok = "they checked the sheep's scroll and read it, and the sheep began to talk",
                      did = "they tried to make sense of the sheep's scroll" } },
    guz_arrives = { "they told Guz the sheep was staying", { ok = "they talked Guz round", did = "they tried to talk Guz round" },
                    "they handed the sheep over to Guz" },
    scroll_again = { "they read the sheep's scroll at last, and the sheep began to talk", "they kept the sheep's scroll sealed" },
    ring_room = { { ok = "they searched Sir Luenn's room and found a cork where his ring should be", did = "they searched Sir Luenn's room" },
                  { ok = "they heard Wenna out, and believed her", did = "they tried to get Wenna's side of it" },
                  { ok = "they stood up for Wenna", did = "they tried to stand up for Wenna" } },
    the_nest = { "they shifted the cellar barrels and found a rats' nest",
                 { ok = "they coaxed the rats out of their nest with food", did = "they tried to coax the rats out with food" },
                 { ok = "they lifted the shiny things out of a rats' nest", did = "they tried to lift the shiny things out of a rats' nest" } },
    ring_back = { "they gave Sir Luenn back his ring", "they let Wenna give Sir Luenn back his ring" },
    token_back = { "they gave Hobb back his token, and heard what he saw up the mountain road", "they gave Hobb back his token" },
    tracks = { { ok = "they read the tracks on the path", did = "they tried to read the tracks" }, "they let the sheep lead the way" },
    the_door = { { ok = "they shouldered the hall door open", did = "they put a shoulder to the hall door" },
                 { ok = "they picked the hall door's lock", did = "they tried to pick the hall door's lock" } },
    noke_demand = { "they refused Noke", "they heard Noke out" },
    hall_search = { "they searched the hall and found a second scroll", "they went straight after Noke" },
    the_spell = { { ok = "they turned the sheep back into Shinebright with the wand", did = "they tried the wand on Shinebright" },
                  { ok = "they found out what was wrong with the wand", did = "they looked the wand over" },
                  "they left the wand alone" },
    the_spell_again = { { ok = "they used the wand anyway, and it worked", did = "they used the wand anyway" },
                        { ok = "they talked Shinebright out of the wand", did = "they tried to talk Shinebright out of the wand" } },
}

M.endings = {
    restored = { name = "Restored", when = { flag = "restored" }, page = 6, tone = "good",
                 line = "Shinebright is an elf again, delighted, and has to be reminded of everything he promised." },
    dead = { name = "The spell failed", when = { flag = "dead" }, page = 6, tone = "bad",
             line = "The wand failed him. What's left of Shinebright's house is theirs to leave alone or strip bare." },
    refused = { name = "Still a sheep", when = { flag = "refused" }, page = 6, tone = "mixed",
                line = "They wouldn't risk the wand. Shinebright puts on an old robe over his fleece and keeps hoping." },
    -- (Ours, as the failure: Conner, November 6.)
    taken = { name = "Noke has his sheep", when = { flag = "taken" }, ours = true, tone = "bad",
              line = "Noke's men brought the sheep home, and nobody came after it." },
}
M.xp = { each = 500, page = 6 }

-- Clocks: counts that fire something.
M.clocks = {
    -- (Three days: Conner, November 6.)
    { id = "guards_search", name = "Noke's men are looking", unit = "days", count = 3, ours = true, page = 3,
      text = "Noke has more guards. Left alone, they find the sheep again.", fires = "sheep_taken", sets = "taken",
      said = "A day later. Somewhere out in the oaks, Noke's other guards are still looking for that sheep.",
      when = { not_flag = "restored" } },
    { id = "bed_dragon", name = "Three rounds", unit = "rounds", count = 3, page = 5, after = "noke_flees", fires = "bed_dragon" },
}

-- What the table knows -------------------------------------------------------------------------------------------
-- Teddy's rumours (p2: the town speaks of Noke with fear and awe). truth: true, false, or a half of it.
M.rumours = {
    { id = "boulders", who = "sh_teddy", where = "inn_common", truth = "half", page = 2,
      text = "\"The wizard in the woods once cleared a rockslide off the lord's road by turning the rocks into rabbits.\"",
      dm = "That was Shinebright, years ago. The town thinks it's the same wizard." },
    { id = "beasts", who = "sh_teddy", where = "inn_common", truth = "true", page = 4, ours = true,
      text = "\"Keeps animals for guards out there. Wolves that look at you like they're doing sums.\"" },
    { id = "unpaid", who = "sh_teddy", where = "inn_common", truth = "true", page = 6, ours = true,
      text = "\"He's been selling things. Books, bottles, a carriage. Owes half of Bogden, the way I hear it.\"" },
    { id = "elf_left", who = "sh_teddy", where = "inn_common", truth = "false", ours = true,
      text = "\"The old elf went travelling a couple of years back and left his boy the whole place.\"" },
    { id = "long_words", who = "sh_teddy", where = "inn_common", truth = "true", page = 3, ours = true,
      text = "\"His big half-orc comes in for supplies now and then. Uses words like 'sentimental' and gets them wrong.\"" },
    { id = "mountains", who = "sh_teddy", where = "inn_common", truth = "true", ours = true, picks_up = { "mountain_road" },
      only_if = { thread = "mountain_road" },
      text = "\"Travellers down from the mountains won't say much. Somebody died up there, and nobody's asking how.\"" },
}

-- What the table calls a secret name before it's told (game/model/told.lua).
M.told = {
    shinebright = { words = { "Shinebright", "Finethir" },
                    intro = { "Finethir Shinebright", "My name is Finethir", "I am Shinebright" },
                    mask = { { "Finethir Shinebright", "the sheep" }, { "Shinebright", "the sheep" }, { "Finethir", "the sheep" } } },
    bear = { words = { "bear" }, intro = { "a bear" }, covered_by = { { flag = "bear_seen" } },
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
      rules = "Read aloud, it works: everyone who hears it understands the sheep, through the inn and the walk to the "
          .. "woods. Then he's a sheep again until the second scroll (Conner, November 6).", once = true },
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
    -- (Ours, the side quest's.)
    { id = "signet_ring", name = "Sir Luenn's signet ring", holder = "inn_cellar",
      text = "A heavy gold ring with the Nordenin crest, for sealing letters. In a pack rat's nest, behind the barrels." },
    { id = "teddys_potion", name = "Teddy's dusty bottle", carry = true, as = "potion_healing", when = { flag = "wenna_thanked" },
      text = "A healing potion a traveller paid his bill with, years back, from under Teddy's bar." },
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
