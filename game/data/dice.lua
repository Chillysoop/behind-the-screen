-- Dice sets (the table's dice): the DM picks one of three at the start of a campaign, the players
-- start on plain grey dice, and sets get better as the campaign goes: a gift from the DM, or a
-- player who's loving it turning up with a new set to show off. tools/gen_dice.py paints each
-- set's d20 texture (assets/textures/d20_<id>.png) and its swatch (assets/portraits/dice_<id>.png)
-- from these colours: body a to b, a swirl, the numbers.

local M = {}

M.SETS = {
    grey = { name = "Plain grey", tier = 0, a = "#7c7a78", b = "#9a9896", swirl = "#8a8886", numbers = "#f4f2ee",
             about = "The dice that came with the starter set." },
    amethyst = { name = "Amethyst swirl", tier = 2, a = "#3a2a6a", b = "#6a3a8a", swirl = "#2d5a7a", numbers = "#ffd678", rarity = "uncommon",
                 about = "Purple and blue, with gold numbers." },
    ember = { name = "Ember", tier = 2, a = "#5a140e", b = "#a8381a", swirl = "#e07a2a", numbers = "#ffe2a0", rarity = "common",
              about = "Red marble that looks warm even under the lamp." },
    jade = { name = "Jade", tier = 2, a = "#173f32", b = "#2e7a5a", swirl = "#8ac0a0", numbers = "#f3f0d0", rarity = "common",
             about = "Green stone, cream numbers." },
    deep_sea = { name = "Deep sea", tier = 2, a = "#10283e", b = "#1f5a7a", swirl = "#3aa0b0", numbers = "#e8f4ff", rarity = "uncommon",
                 about = "Blue that goes darker the longer you look." },
    rose = { name = "Rose quartz", tier = 2, a = "#b07888", b = "#e8b8c0", swirl = "#f4d8dc", numbers = "#5a2030", rarity = "common",
             about = "Soft pink with wine-dark numbers." },
    bone = { name = "Bone and gold", tier = 3, a = "#cfc2a4", b = "#efe6d0", swirl = "#ffffff", numbers = "#8a5a10", rarity = "rare",
             about = "Pale and heavy, with gold inlay." },
    galaxy = { name = "Galaxy", tier = 3, a = "#0a0a1e", b = "#2a1a4a", swirl = "#5a3a8a", numbers = "#ffffff", stars = true, rarity = "epic",
               about = "Deep space with little stars in it." },
    copper = { name = "Copper", tier = 3, a = "#6a3a20", b = "#c08050", swirl = "#e0a070", numbers = "#2a1a10", rarity = "rare",
               about = "Metal. They clatter. Everyone hears your rolls." },
    obsidian = { name = "Obsidian", tier = 3, a = "#101014", b = "#2a2a30", swirl = "#40404a", numbers = "#d84040", rarity = "epic",
                 about = "Black glass, red numbers. Dramatic." },
    -- The rarest sets, only ever out of a box (game/model/loot.lua; the playtest, November 3).
    dragonscale = { name = "Dragonscale", tier = 3, a = "#14301a", b = "#3a7a2a", swirl = "#d8b040", numbers = "#ffe9a0", rarity = "legendary",
                    about = "Green scales with a gold sheen. Warm to the touch, somehow." },
    sunburst = { name = "Sunburst", tier = 3, a = "#8a3a0a", b = "#f0a020", swirl = "#fff0a0", numbers = "#4a1a00", rarity = "legendary",
                 about = "Orange and gold, like holding a sunset." },
    voidstar = { name = "Voidstar", tier = 3, a = "#05030a", b = "#1a0a2a", swirl = "#7a3ad0", numbers = "#ff7ad8", stars = true, rarity = "mythic",
                 about = "Black as a starless sky, until the stars come out." },
    prism = { name = "Prism", tier = 3, a = "#3a6ab0", b = "#e05a9a", swirl = "#f0e060", numbers = "#ffffff", stars = true, rarity = "mythic",
              about = "Every colour at once, glittering." },
}
M.ORDER = { "grey", "amethyst", "ember", "jade", "deep_sea", "rose", "bone", "galaxy", "copper", "obsidian", "dragonscale", "sunburst",
            "voidstar", "prism" }
M.DM_CHOICES = 3

-- How rare a set is, and how often a box gives one (weights out of 100; game/model/loot.lua). The
-- happier the table, the better the box: a great night shifts the odds up a step.
M.RARITIES = {
    { id = "common", name = "Common", color = "#b8b0a4", weight = 50, gift = 1 },
    { id = "uncommon", name = "Uncommon", color = "#6abf6a", weight = 25, gift = 1.25 },
    { id = "rare", name = "Rare", color = "#5a9ae0", weight = 13, gift = 1.5 },
    { id = "epic", name = "Epic", color = "#b06ae0", weight = 7, gift = 2 },
    { id = "legendary", name = "Legendary", color = "#f0a030", weight = 4, gift = 2.5 },
    { id = "mythic", name = "Mythic", color = "#ff5a7a", weight = 1, gift = 3 },
}

-- A gift from the DM: once a week, after the session, to someone who earned it.
M.GIFT = { trust = 2, investment = 2, fun_next = 4, social_all = 3, again_weeks = 3 }
-- Showing off a new set before the session: a player who loved the last one and is all in.
M.SHOW_OFF = { commitment = 70, chance = 0.35, social_all = 3, fun = 4 }

M.GIFT_LINES = {
    "Wait, these are for me? Oh, they're beautiful.",
    "You got me dice? I'm not crying. Okay, a bit.",
    "New dice! These are going straight in the lucky bag.",
    "No way. These are SO much better than the grey ones.",
}
M.SHOW_LINES = {
    "Okay, before we start. New dice. Look at them. LOOK at them.",
    "I bought dice. Don't judge me. Okay, judge me, they're gorgeous.",
    "These are my new dice and they only roll twenties. Probably.",
    "Had to treat myself after last week. New set!",
}
M.FIRST_ROLL_LINES = {
    "Brought the dice you gave me. They've been on my desk all week.",
    "First night with the new dice. Be nice to me, dice.",
    "I've been rolling these at home. For practice. Don't laugh.",
}
M.REACT_LINES = { "Ooh, those are nice.", "Let me see! Oh, they're shiny.", "Okay, now I want new dice.",
                  "Those are going to roll so well.", "Respect. Those are beautiful." }

return M
