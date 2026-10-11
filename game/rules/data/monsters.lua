-- The slice's monster roster, from SRD 5.2.1 "Monsters A-Z" (pp. 258-364).
-- Stat blocks are transcribed as data: attacks list to-hit, reach or range,
-- damage parts { count, die, bonus, type }, and riders the engine knows.
-- abilities = scores; saves = the SAVE column where it differs from the modifier.

local M = {}

local function add(id, t)
    t.id = id
    M[id] = t
end

add("goblin_warrior", {
    name = "Goblin Warrior", page = 290, size = "small", type = "fey", tags = { "goblinoid" },
    ac = 15, hp = 10, hit_dice = "3d6", speed = 30,
    abilities = { str = 8, dex = 15, con = 10, int = 10, wis = 8, cha = 8 },
    cr = "1/4", xp = 50, pb = 2,
    attacks = {
        { id = "scimitar", name = "Scimitar", kind = "melee", to_hit = 4, reach = 5,
          damage = { { 1, 6, 2, "slashing" } }, adv_bonus = { 1, 4, 0, "slashing" } },
        { id = "shortbow", name = "Shortbow", kind = "ranged", to_hit = 4, range = { 80, 320 },
          damage = { { 1, 6, 2, "piercing" } }, adv_bonus = { 1, 4, 0, "piercing" } },
    },
    bonus = { "nimble_escape" },                 -- Disengage or Hide as a Bonus Action
    role = "skirmisher",
})

add("goblin_boss", {
    name = "Goblin Boss", page = 290, size = "small", type = "fey", tags = { "goblinoid" },
    ac = 17, hp = 21, hit_dice = "6d6", speed = 30,
    abilities = { str = 10, dex = 15, con = 10, int = 10, wis = 8, cha = 10 },
    cr = "1", xp = 200, pb = 2,
    multiattack = { count = 2, any_of = { "scimitar", "shortbow" } },
    attacks = {
        { id = "scimitar", name = "Scimitar", kind = "melee", to_hit = 4, reach = 5,
          damage = { { 1, 6, 2, "slashing" } }, adv_bonus = { 1, 4, 0, "slashing" } },
        { id = "shortbow", name = "Shortbow", kind = "ranged", to_hit = 4, range = { 80, 320 },
          damage = { { 1, 6, 2, "piercing" } }, adv_bonus = { 1, 4, 0, "piercing" } },
    },
    bonus = { "nimble_escape" },
    reactions = { "redirect_attack" },           -- swap with a Small/Medium ally within 5 ft; ally is attacked
    role = "skirmisher",
})

add("bandit", {
    name = "Bandit", page = 261, size = "medium", type = "humanoid",
    ac = 12, hp = 11, hit_dice = "2d8+2", speed = 30,
    abilities = { str = 11, dex = 12, con = 12, int = 10, wis = 10, cha = 10 },
    cr = "1/8", xp = 25, pb = 2,
    attacks = {
        { id = "scimitar", name = "Scimitar", kind = "melee", to_hit = 3, reach = 5, damage = { { 1, 6, 1, "slashing" } } },
        { id = "light_crossbow", name = "Light Crossbow", kind = "ranged", to_hit = 3, range = { 80, 320 },
          damage = { { 1, 8, 1, "piercing" } } },
    },
    role = "brute",
})

add("bandit_captain", {
    name = "Bandit Captain", page = 261, size = "medium", type = "humanoid",
    ac = 15, hp = 52, hit_dice = "8d8+16", speed = 30,
    abilities = { str = 15, dex = 16, con = 14, int = 14, wis = 11, cha = 14 },
    saves = { str = 4, dex = 5, wis = 2 },
    cr = "2", xp = 450, pb = 2,
    multiattack = { count = 2, any_of = { "scimitar", "pistol" } },
    attacks = {
        { id = "scimitar", name = "Scimitar", kind = "melee", to_hit = 5, reach = 5, damage = { { 1, 6, 3, "slashing" } } },
        { id = "pistol", name = "Pistol", kind = "ranged", to_hit = 5, range = { 30, 90 }, damage = { { 1, 10, 3, "piercing" } } },
    },
    reactions = { "parry" },                     -- +2 AC against a melee hit while holding a weapon
    role = "leader",
})

add("tough", {
    name = "Tough", page = 332, size = "medium", type = "humanoid",
    ac = 12, hp = 32, hit_dice = "5d8+10", speed = 30,
    abilities = { str = 15, dex = 12, con = 14, int = 10, wis = 10, cha = 11 },
    cr = "1/2", xp = 100, pb = 2,
    traits = { "pack_tactics" },
    attacks = {
        { id = "mace", name = "Mace", kind = "melee", to_hit = 4, reach = 5, damage = { { 1, 6, 2, "bludgeoning" } } },
        { id = "heavy_crossbow", name = "Heavy Crossbow", kind = "ranged", to_hit = 3, range = { 100, 400 },
          damage = { { 1, 10, 1, "piercing" } } },
    },
    role = "brute",
})

add("cultist", {
    name = "Cultist", page = 278, size = "medium", type = "humanoid",
    ac = 12, hp = 9, hit_dice = "2d8", speed = 30,
    abilities = { str = 11, dex = 12, con = 10, int = 10, wis = 11, cha = 10 },
    saves = { wis = 2 },
    cr = "1/8", xp = 25, pb = 2,
    attacks = {
        { id = "ritual_sickle", name = "Ritual Sickle", kind = "melee", to_hit = 3, reach = 5,
          damage = { { 1, 4, 1, "slashing" }, { 0, 0, 1, "necrotic" } } },
    },
    role = "brute",
})

add("wolf", {
    name = "Wolf", page = 364, size = "medium", type = "beast",
    ac = 12, hp = 11, hit_dice = "2d8+2", speed = 40,
    abilities = { str = 14, dex = 15, con = 12, int = 3, wis = 12, cha = 6 },
    cr = "1/4", xp = 50, pb = 2,
    traits = { "pack_tactics" },
    attacks = {
        { id = "bite", name = "Bite", kind = "melee", to_hit = 4, reach = 5, damage = { { 1, 6, 2, "piercing" } },
          prone_max_size = "medium" },           -- Medium or smaller target has the Prone condition
    },
    role = "pack",
})

add("dire_wolf", {
    name = "Dire Wolf", page = 347, size = "large", type = "beast",
    ac = 14, hp = 22, hit_dice = "3d10+6", speed = 50,
    abilities = { str = 17, dex = 15, con = 15, int = 3, wis = 12, cha = 7 },
    cr = "1", xp = 200, pb = 2,
    traits = { "pack_tactics" },
    attacks = {
        { id = "bite", name = "Bite", kind = "melee", to_hit = 5, reach = 5, damage = { { 1, 10, 3, "piercing" } },
          prone_max_size = "large" },
    },
    role = "pack",
})

add("skeleton", {
    name = "Skeleton", page = 325, size = "medium", type = "undead",
    ac = 14, hp = 13, hit_dice = "2d8+4", speed = 30,
    abilities = { str = 10, dex = 16, con = 15, int = 6, wis = 8, cha = 5 },
    cr = "1/4", xp = 50, pb = 2,
    vulnerable = { "bludgeoning" },
    immune = { "poison" },
    condition_immune = { "exhaustion", "poisoned" },
    attacks = {
        { id = "shortsword", name = "Shortsword", kind = "melee", to_hit = 5, reach = 5, damage = { { 1, 6, 3, "piercing" } } },
        { id = "shortbow", name = "Shortbow", kind = "ranged", to_hit = 5, range = { 80, 320 }, damage = { { 1, 6, 3, "piercing" } } },
    },
    role = "brute",
})

add("zombie", {
    name = "Zombie", page = 343, size = "medium", type = "undead",
    ac = 8, hp = 15, hit_dice = "2d8+6", speed = 20,
    abilities = { str = 13, dex = 6, con = 16, int = 3, wis = 6, cha = 5 },
    saves = { wis = 0 },
    cr = "1/4", xp = 50, pb = 2,
    immune = { "poison" },
    condition_immune = { "exhaustion", "poisoned" },
    traits = { "undead_fortitude" },             -- Con save DC 5 + damage to drop to 1 HP instead (not Radiant or a crit)
    attacks = {
        { id = "slam", name = "Slam", kind = "melee", to_hit = 3, reach = 5, damage = { { 1, 8, 1, "bludgeoning" } } },
    },
    role = "brute",
})

add("ghoul", {
    name = "Ghoul", page = 288, size = "medium", type = "undead",
    ac = 12, hp = 22, hit_dice = "5d8", speed = 30,
    abilities = { str = 13, dex = 15, con = 10, int = 7, wis = 10, cha = 6 },
    cr = "1", xp = 200, pb = 2,
    immune = { "poison" },
    condition_immune = { "charmed", "exhaustion", "poisoned" },
    multiattack = { count = 2, any_of = { "bite" } },
    attacks = {
        { id = "bite", name = "Bite", kind = "melee", to_hit = 4, reach = 5,
          damage = { { 1, 6, 2, "piercing" }, { 1, 6, 0, "necrotic" } } },
        { id = "claw", name = "Claw", kind = "melee", to_hit = 4, reach = 5, damage = { { 1, 4, 2, "slashing" } },
          rider = { save = "con", dc = 10, condition = "paralyzed", lasts = "end_of_target_next_turn",
                    not_types = { "undead" }, not_traits = { "elf" } } },
    },
    role = "brute",
})

add("ogre", {
    name = "Ogre", page = 312, size = "large", type = "giant",
    ac = 11, hp = 68, hit_dice = "8d10+24", speed = 40,
    abilities = { str = 19, dex = 8, con = 16, int = 5, wis = 7, cha = 7 },
    cr = "2", xp = 450, pb = 2,
    attacks = {
        { id = "greatclub", name = "Greatclub", kind = "melee", to_hit = 6, reach = 5, damage = { { 2, 8, 4, "bludgeoning" } } },
        { id = "javelin", name = "Javelin", kind = "both", to_hit = 6, reach = 5, range = { 30, 120 },
          damage = { { 2, 6, 4, "piercing" } }, ammo = 3 },
    },
    role = "brute",
})

-- CR to XP (each stat block lists its XP; kept here for encounter math).
M.order = { "bandit", "cultist", "goblin_warrior", "wolf", "skeleton", "zombie", "tough",
            "goblin_boss", "dire_wolf", "ghoul", "bandit_captain", "ogre" }

return M
