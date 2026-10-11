-- Traps and hazards (A10), built from SRD 5.2.1: the example traps (pp. 199-201), the Burning
-- and Falling hazards (Rules Glossary, pp. 178, 182), environmental effects (p. 195) and the
-- underwater combat rules (p. 16). Data only: the engine is game/rules/hazards.lua.
--
-- hazards: things that act in a fight, on the mat, every round (the encounter builder adds one;
--          a complication card can bring one: card.hazard)
--   every   "round": acts at the top of each round, before anyone's turn
--   xp      what it adds to the fight's difficulty for the meter (its damage over a fight,
--           in monster-XP terms; the battles sim checks fights with it land in the meter's bands)
--   fits    the place settings it belongs to (the builder suggests it there)
-- traps:   a scene's whole encounter in puzzle and exploration scenes: find it, disarm it, or
--          spring it and survive (a complication card brings one: card.trap)

local M = {}

M.hazards = {
    falling_rubble = {
        name = "Falling rubble", src = "Collapsing Roof, SRD 5.2.1 p. 199",
        about = "The ceiling's coming down a piece at a time. Dust trickles where the next chunk will fall.",
        every = "round", size = 2, save = { "dex", 13 }, damage = { 2, 10, 0, "bludgeoning" }, half = true,
        leaves = "difficult", per_round = 1, warn = true,
        xp = 150, dpr = 4, fits = { "under", "ruin", "indoor", "high", "bells" },
    },
    spreading_fire = {
        name = "Spreading fire", src = "Burning hazard, SRD 5.2.1 p. 178",
        about = "Fire on the floor, spreading every round. Step in it and you're Burning (1d4 a turn until you put it out).",
        every = "round", start = 3, spread = 2, burning = { 1, 4, 0, "fire" },
        xp = 125, dpr = 3, fits = { "forest", "camp", "town", "tavern", "indoor", "shop", "crowd" },
    },
    rising_water = {
        name = "Rising water", src = "Underwater Combat, SRD 5.2.1 p. 16",
        about = "The water comes up a row a round. Wading is Difficult Terrain; once it's deep, it's underwater combat.",
        every = "round", rise = 1, deep_after = 3,
        xp = 75, dpr = 0.5, fits = { "water", "under", "ship", "port", "island" },
    },
    crumbling_bridge = {
        name = "A bridge coming apart", src = "Falling hazard, SRD 5.2.1 p. 182",
        about = "Planks give way every round. Whoever's standing there falls 20 feet: 2d6, and they land Prone.",
        every = "round", per_round = 2, save = { "dex", 10 }, fall_feet = 20,
        xp = 125, dpr = 2.5, fits = { "bridge", "high" },
    },
    slippery_ice = {
        name = "Slippery ice", src = "Slippery Ice, SRD 5.2.1 p. 195",
        about = "Patches of ice: Difficult Terrain, and stepping on or starting a turn there is a DC 10 Dex save or Prone.",
        static = true, patches = 3, size = 2, save = { "dex", 10 },
        xp = 50, dpr = 0.5, fits = { "wild", "high", "outdoor", "water" },
    },
    strong_wind = {
        name = "Strong wind", src = "Strong Wind, SRD 5.2.1 p. 195",
        about = "A gale over the field: ranged weapon attacks have Disadvantage, and fliers have to land.",
        static = true, wind = true,
        xp = 50, dpr = 0.5, fits = { "high", "ship", "water", "outdoor", "island" },
    },
}
M.hazard_order = { "falling_rubble", "spreading_fire", "rising_water", "crumbling_bridge", "slippery_ice", "strong_wind" }

-- The SRD's example traps at levels 1-4 (Rolling Stone is for levels 11+ and stays out).
--   find:    the check that spots it (ability, skill, DC); "study" if it's a Study action
--   disarm:  what makes it safe once found (no check, or ability/skill/DC)
--   sprung:  what happens to whoever sets it off (save, damage, condition), and to how many
M.traps = {
    collapsing_roof = {
        name = "Collapsing roof", src = "SRD 5.2.1 p. 199", severity = "deadly",
        about = "A trip wire three inches off the floor, and a ceiling held up by two weak supports.",
        find = { "wis", "perception", 11 }, disarm = { none = true, text = "Once spotted, the wire is easy to step over." },
        sprung = { save = { "dex", 13 }, damage = { 2, 10, 0, "bludgeoning" }, half = true, who = "near" },
    },
    falling_net = {
        name = "Falling net", src = "SRD 5.2.1 p. 199", severity = "nuisance",
        about = "A trip wire between two columns, and a weighted net hanging in the dark above.",
        find = { "wis", "perception", 11 }, disarm = { none = true, text = "Cut the wire and the net stays up." },
        sprung = { save = { "dex", 10 }, condition = "restrained", escape = { "str", "athletics", 10 }, who = "first" },
    },
    fire_statue = {
        name = "Fire-casting statue", src = "SRD 5.2.1 pp. 199-200", severity = "deadly",
        about = "A dragon statue by a pressure plate, and a tiny glyph on its tongue.",
        find = { "wis", "perception", 10 }, disarm = { "int", "arcana", 15, text = "Read the glyph as \"fire\" and deface it." },
        sprung = { save = { "dex", 15 }, damage = { 2, 10, 0, "fire" }, half = true, who = "near" },
    },
    hidden_pit = {
        name = "Hidden pit", src = "SRD 5.2.1 p. 200", severity = "nuisance",
        about = "A ten-foot pit under a hinged lid that looks exactly like the floor.",
        find = { "int", "investigation", 15, study = true }, disarm = { none = true, text = "An iron spike under the lid holds it shut." },
        sprung = { damage = { 1, 6, 0, "bludgeoning" }, who = "first", climb = true },
    },
    poisoned_darts = {
        name = "Poisoned darts", src = "SRD 5.2.1 p. 200", severity = "deadly",
        about = "A pressure plate, and little holes in the walls hidden among the carvings.",
        find = { "wis", "perception", 15 }, disarm = { none = true, text = "Wax in the holes, or a spike under the plate." },
        sprung = { save = { "dex", 13 }, darts = { 1, 3 }, damage = { 1, 6, 0, "poison" }, who = "near" },
    },
    poisoned_needle = {
        name = "Poisoned needle", src = "SRD 5.2.1 p. 200", severity = "nuisance",
        about = "A needle hidden in a lock, for anyone who opens it without the key.",
        find = { "wis", "perception", 15 }, disarm = { "dex", "sleight_of_hand", 15, text = "Pick the needle out of the lock." },
        sprung = { save = { "con", 11 }, damage = { 1, 10, 0, "poison" }, half = true, condition = "poisoned", who = "first" },
    },
    spiked_pit = {
        name = "Spiked pit", src = "SRD 5.2.1 p. 201", severity = "deadly",
        about = "A hinged lid over ten feet of drop, and something sharp at the bottom.",
        find = { "int", "investigation", 15, study = true }, disarm = { none = true, text = "An iron spike under the lid holds it shut." },
        sprung = { damage = { 1, 6, 0, "bludgeoning" }, extra = { 2, 8, 0, "piercing" }, who = "first", climb = true },
    },
}
M.trap_order = { "collapsing_roof", "falling_net", "fire_statue", "hidden_pit", "poisoned_darts", "poisoned_needle", "spiked_pit" }

return M
