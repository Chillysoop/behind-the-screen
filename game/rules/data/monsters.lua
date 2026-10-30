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
    darkvision = 60,                    -- Senses (Set the stage: who sees in the dark)
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
    darkvision = 60,                    -- Senses (Set the stage: who sees in the dark)
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
    darkvision = 60,                    -- Senses (Set the stage: who sees in the dark)
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
    darkvision = 60,                    -- Senses (Set the stage: who sees in the dark)
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
    darkvision = 60,                    -- Senses (Set the stage: who sees in the dark)
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
    darkvision = 60,                    -- Senses (Set the stage: who sees in the dark)
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
    darkvision = 60,                    -- Senses (Set the stage: who sees in the dark)
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
    darkvision = 60,                    -- Senses (Set the stage: who sees in the dark)
    abilities = { str = 19, dex = 8, con = 16, int = 5, wis = 7, cha = 7 },
    cr = "2", xp = 450, pb = 2,
    attacks = {
        { id = "greatclub", name = "Greatclub", kind = "melee", to_hit = 6, reach = 5, damage = { { 2, 8, 4, "bludgeoning" } } },
        { id = "javelin", name = "Javelin", kind = "both", to_hit = 6, reach = 5, range = { 30, 120 },
          damage = { { 2, 6, 4, "piercing" } }, ammo = 3 },
    },
    role = "brute",
})


-- The Vale Bestiary (A13): sixteen more from SRD 5.2.1, for the campaign styles' places and the
-- book the DM reads in week 2. New engine hooks: grapple (escape DC), pull, mark (the next attack on
-- the target has Advantage), drain (Hit Point maximum), bloodied_damage (swarms), rampage, web,
-- panache (Charmed), blood frenzy. A Hit Point maximum drained stays down until a Long Rest (p. 185).

add("pirate", {
    name = "Pirate", page = 314, size = "medium", type = "humanoid",
    ac = 14, hp = 33, hit_dice = "6d8+6", speed = 30,
    abilities = { str = 10, dex = 16, con = 12, int = 8, wis = 12, cha = 14 },
    saves = { dex = 5, cha = 4 },
    cr = "1", xp = 200, pb = 2,
    multiattack = { count = 2, any_of = { "dagger" }, replace = "panache" },
    attacks = {
        { id = "dagger", name = "Dagger", kind = "both", to_hit = 5, reach = 5, range = { 20, 60 },
          damage = { { 1, 4, 3, "piercing" } }, ammo = 6 },
    },
    -- Enthralling Panache: Wis DC 12, one creature within 30 ft; Charmed until the start of the
    -- pirate's next turn (it can't attack the pirate).
    panache = { save = "wis", dc = 12, range = 30, lasts = "start_of_attacker_next_turn" },
    role = "skirmisher",
})

add("merrow", {
    name = "Merrow", page = 308, size = "large", type = "monstrosity",
    ac = 13, hp = 45, hit_dice = "6d10+12", speed = 10, swim = 40,
    darkvision = 60,                    -- Senses (Set the stage: who sees in the dark)
    abilities = { str = 18, dex = 15, con = 15, int = 8, wis = 10, cha = 9 },
    cr = "2", xp = 450, pb = 2,
    multiattack = { count = 2, any_of = { "bite", "claw", "harpoon" }, seq = { "bite", "harpoon" } },
    attacks = {
        { id = "bite", name = "Bite", kind = "melee", to_hit = 6, reach = 5, damage = { { 1, 4, 4, "piercing" } },
          rider = { condition = "poisoned", lasts = "end_of_attacker_next_turn" } },     -- no save
        { id = "claw", name = "Claw", kind = "melee", to_hit = 6, reach = 5, damage = { { 2, 4, 4, "slashing" } } },
        { id = "harpoon", name = "Harpoon", kind = "both", to_hit = 6, reach = 5, range = { 20, 60 },
          damage = { { 2, 6, 4, "piercing" } }, pull = { feet = 15, max_size = "large" } },
    },
    role = "brute",
})

add("giant_crab", {
    name = "Giant Crab", page = 350, size = "medium", type = "beast",
    ac = 15, hp = 13, hit_dice = "3d8", speed = 30, swim = 30, blindsight = 30,
    abilities = { str = 13, dex = 13, con = 11, int = 1, wis = 9, cha = 3 },
    cr = "1/8", xp = 25, pb = 2,
    attacks = {
        { id = "claw", name = "Claw", kind = "melee", to_hit = 3, reach = 5, damage = { { 1, 6, 1, "bludgeoning" } },
          grapple = { dc = 11, max_size = "medium", hands = 2 } },
    },
    role = "brute",
})

add("guard", {
    name = "Guard", page = 296, size = "medium", type = "humanoid",
    ac = 16, hp = 11, hit_dice = "2d8+2", speed = 30,
    abilities = { str = 13, dex = 12, con = 12, int = 10, wis = 11, cha = 10 },
    cr = "1/8", xp = 25, pb = 2,
    attacks = {
        { id = "spear", name = "Spear", kind = "both", to_hit = 3, reach = 5, range = { 20, 60 },
          damage = { { 1, 6, 1, "piercing" } }, ammo = 1 },
    },
    role = "brute",
})

add("spy", {
    name = "Spy", page = 329, size = "medium", type = "humanoid",
    ac = 12, hp = 27, hit_dice = "6d8", speed = 30,
    abilities = { str = 10, dex = 15, con = 10, int = 12, wis = 14, cha = 16 },
    cr = "1", xp = 200, pb = 2,
    attacks = {
        { id = "shortsword", name = "Shortsword", kind = "melee", to_hit = 4, reach = 5,
          damage = { { 1, 6, 2, "piercing" }, { 2, 6, 0, "poison" } } },
        { id = "hand_crossbow", name = "Hand Crossbow", kind = "ranged", to_hit = 4, range = { 30, 120 },
          damage = { { 1, 6, 2, "piercing" }, { 2, 6, 0, "poison" } } },
    },
    bonus = { "nimble_escape" },                 -- Cunning Action: Dash, Disengage or Hide
    role = "skirmisher",
})

add("swarm_of_rats", {
    name = "Swarm of Rats", page = 362, size = "medium", type = "beast", tags = { "swarm" },
    ac = 10, hp = 14, hit_dice = "4d8-4", speed = 30,
    darkvision = 30,                    -- Senses (Set the stage: who sees in the dark)
    abilities = { str = 9, dex = 11, con = 9, int = 2, wis = 10, cha = 3 },
    saves = { dex = 2 },
    cr = "1/4", xp = 50, pb = 2,
    resist = { "bludgeoning", "piercing", "slashing" },
    condition_immune = { "charmed", "frightened", "grappled", "paralyzed", "petrified", "prone", "restrained", "stunned" },
    traits = { "swarm" },                        -- can't regain Hit Points or gain Temporary Hit Points
    attacks = {
        { id = "bites", name = "Bites", kind = "melee", to_hit = 2, reach = 5, damage = { { 2, 4, 0, "piercing" } },
          bloodied_damage = { { 1, 4, 0, "piercing" } } },
    },
    role = "brute",
})

add("animated_armor", {
    name = "Animated Armor", page = 259, size = "medium", type = "construct",
    ac = 18, hp = 33, hit_dice = "6d8+6", speed = 25, blindsight = 60,
    abilities = { str = 14, dex = 11, con = 13, int = 1, wis = 3, cha = 1 },
    cr = "1", xp = 200, pb = 2,
    immune = { "poison", "psychic" },
    condition_immune = { "charmed", "deafened", "exhaustion", "frightened", "paralyzed", "petrified", "poisoned" },
    multiattack = { count = 2, any_of = { "slam" } },
    attacks = {
        { id = "slam", name = "Slam", kind = "melee", to_hit = 4, reach = 5, damage = { { 1, 6, 2, "bludgeoning" } } },
    },
    role = "brute",
})

add("giant_spider", {
    name = "Giant Spider", page = 353, size = "large", type = "beast",
    ac = 14, hp = 26, hit_dice = "4d10+4", speed = 30,
    darkvision = 60,                    -- Senses (Set the stage: who sees in the dark)
    abilities = { str = 14, dex = 16, con = 12, int = 2, wis = 11, cha = 4 },
    cr = "1", xp = 200, pb = 2,
    traits = { "spider_climb", "web_walker" },
    attacks = {
        { id = "bite", name = "Bite", kind = "melee", to_hit = 5, reach = 5,
          damage = { { 1, 8, 3, "piercing" }, { 2, 6, 0, "poison" } } },
    },
    -- Web (Recharge 5-6): Dex DC 13, one creature within 60 ft; Restrained until the web is destroyed
    -- (AC 10; HP 5; Vulnerability to Fire; Immunity to Poison and Psychic).
    web = { save = "dex", dc = 13, range = 60, recharge = 5, ac = 10, hp = 5 },
    role = "skirmisher",
})

add("specter", {
    name = "Specter", page = 327, size = "medium", type = "undead",
    ac = 12, hp = 22, hit_dice = "5d8", speed = 30, fly = 50,
    darkvision = 60,                    -- Senses (Set the stage: who sees in the dark)
    abilities = { str = 1, dex = 14, con = 11, int = 10, wis = 10, cha = 11 },
    cr = "1", xp = 200, pb = 2,
    resist = { "acid", "bludgeoning", "cold", "fire", "lightning", "piercing", "slashing", "thunder" },
    immune = { "necrotic", "poison" },
    condition_immune = { "charmed", "exhaustion", "grappled", "paralyzed", "petrified", "poisoned", "prone",
                         "restrained", "unconscious" },
    traits = { "incorporeal" },
    attacks = {
        { id = "life_drain", name = "Life Drain", kind = "melee", to_hit = 4, reach = 5, damage = { { 2, 6, 0, "necrotic" } },
          drain = true },                        -- its Hit Point maximum drops by the damage taken
    },
    role = "skirmisher",
})

add("brown_bear", {
    name = "Brown Bear", page = 346, size = "large", type = "beast",
    ac = 11, hp = 22, hit_dice = "3d10+6", speed = 40,
    darkvision = 60,                    -- Senses (Set the stage: who sees in the dark)
    abilities = { str = 17, dex = 12, con = 15, int = 2, wis = 13, cha = 7 },
    cr = "1", xp = 200, pb = 2,
    multiattack = { count = 2, any_of = { "bite", "claw" }, seq = { "bite", "claw" } },
    attacks = {
        { id = "bite", name = "Bite", kind = "melee", to_hit = 5, reach = 5, damage = { { 1, 8, 3, "piercing" } } },
        { id = "claw", name = "Claw", kind = "melee", to_hit = 5, reach = 5, damage = { { 1, 4, 3, "slashing" } },
          prone_max_size = "large" },
    },
    role = "brute",
})

add("gnoll_warrior", {
    name = "Gnoll Warrior", page = 289, size = "medium", type = "fiend",
    ac = 15, hp = 27, hit_dice = "6d8", speed = 30,
    darkvision = 60,                    -- Senses (Set the stage: who sees in the dark)
    abilities = { str = 14, dex = 12, con = 11, int = 6, wis = 10, cha = 7 },
    cr = "1/2", xp = 100, pb = 2,
    attacks = {
        { id = "rend", name = "Rend", kind = "melee", to_hit = 4, reach = 5, damage = { { 1, 6, 2, "piercing" } } },
        { id = "bone_bow", name = "Bone Bow", kind = "ranged", to_hit = 3, range = { 150, 600 }, damage = { { 1, 10, 1, "piercing" } } },
    },
    bonus = { "rampage" },                       -- 1/Day: after damaging a Bloodied creature, move half and Rend again
    role = "brute",
})

add("worg", {
    name = "Worg", page = 342, size = "large", type = "fey", no_hands = true,     -- a wolf: no opening doors
    ac = 13, hp = 26, hit_dice = "4d10+4", speed = 50,
    darkvision = 60,                    -- Senses (Set the stage: who sees in the dark)
    abilities = { str = 16, dex = 13, con = 13, int = 7, wis = 11, cha = 8 },
    cr = "1/2", xp = 100, pb = 2,
    attacks = {
        { id = "bite", name = "Bite", kind = "melee", to_hit = 5, reach = 5, damage = { { 1, 8, 3, "piercing" } },
          mark = true },                         -- the next attack roll against the target has Advantage
    },
    role = "pack",
})

add("bugbear_warrior", {
    name = "Bugbear Warrior", page = 272, size = "medium", type = "fey", tags = { "goblinoid" },
    ac = 14, hp = 33, hit_dice = "6d8+6", speed = 30,
    darkvision = 60,                    -- Senses (Set the stage: who sees in the dark)
    abilities = { str = 15, dex = 14, con = 13, int = 8, wis = 11, cha = 9 },
    cr = "1", xp = 200, pb = 2,
    traits = { "abduct" },
    attacks = {
        { id = "grab", name = "Grab", kind = "melee", to_hit = 4, reach = 10, damage = { { 2, 6, 2, "bludgeoning" } },
          grapple = { dc = 12, max_size = "medium", hands = 1 } },
        { id = "light_hammer", name = "Light Hammer", kind = "both", to_hit = 4, reach = 10, range = { 20, 60 },
          damage = { { 3, 4, 2, "bludgeoning" } }, adv_vs_grappled = true, ammo = 3 },
    },
    role = "brute",
})

add("warrior_veteran", {
    name = "Warrior Veteran", page = 337, size = "medium", type = "humanoid",
    ac = 17, hp = 65, hit_dice = "10d8+20", speed = 30,
    abilities = { str = 16, dex = 13, con = 14, int = 10, wis = 11, cha = 10 },
    cr = "3", xp = 700, pb = 2,
    multiattack = { count = 2, any_of = { "greatsword", "heavy_crossbow" } },
    attacks = {
        { id = "greatsword", name = "Greatsword", kind = "melee", to_hit = 5, reach = 5, damage = { { 2, 6, 3, "slashing" } } },
        { id = "heavy_crossbow", name = "Heavy Crossbow", kind = "ranged", to_hit = 3, range = { 100, 400 },
          damage = { { 2, 10, 1, "piercing" } } },
    },
    reactions = { "parry" },
    role = "brute",
})

add("kobold_warrior", {
    name = "Kobold Warrior", page = 302, size = "small", type = "dragon",
    ac = 14, hp = 7, hit_dice = "3d6-3", speed = 30,
    darkvision = 60,                    -- Senses (Set the stage: who sees in the dark)
    abilities = { str = 7, dex = 15, con = 9, int = 8, wis = 7, cha = 8 },
    cr = "1/8", xp = 25, pb = 2,
    traits = { "pack_tactics" },                 -- (Sunlight Sensitivity: the Vale's kobolds keep to the dark)
    attacks = {
        { id = "dagger", name = "Dagger", kind = "both", to_hit = 4, reach = 5, range = { 20, 60 },
          damage = { { 1, 4, 2, "piercing" } }, ammo = 3 },
    },
    role = "pack",
})

add("scout", {
    name = "Scout", page = 322, size = "medium", type = "humanoid",
    ac = 13, hp = 16, hit_dice = "3d8+3", speed = 30,
    abilities = { str = 11, dex = 14, con = 12, int = 11, wis = 13, cha = 11 },
    cr = "1/2", xp = 100, pb = 2,
    multiattack = { count = 2, any_of = { "shortsword", "longbow" } },
    attacks = {
        { id = "shortsword", name = "Shortsword", kind = "melee", to_hit = 4, reach = 5, damage = { { 1, 6, 2, "piercing" } } },
        { id = "longbow", name = "Longbow", kind = "ranged", to_hit = 4, range = { 150, 600 }, damage = { { 1, 8, 2, "piercing" } } },
    },
    role = "skirmisher",
})

-- The Museum of Nightmares (v2) ---------------------------------------------------------------
-- The published adventure's own monsters (its Appendix B, not the SRD), for the three-session
-- arc. Numbers are as printed unless a "tuned" note says what changed and why. The rules they
-- need live in game/rules/museum.lua (each block's `museum` names its turn); the fields:
--   resist_nonmagical   Resistance to these types from attacks that aren't magical
--   paint               Vulnerable to paint-touched weapons (the battle's `paint` option)
--   charge              on an attack: closing `feet` this turn before the hit adds `extra`, and a save or Prone
--   briar_hooks         extra damage on its Opportunity Attacks (thorns that catch whoever pulls away)
--   false_appearance    a trait: a fight made only of these (or ambushers) starts with the party surprised
--   ambusher            a trait: the same, for monsters that wait hidden (the huntlings)
--   spawn               { id, at = fraction of HP, n, name }: what bursts out when it gets that hurt
--   nonlethal           on an attack: a hero it drops is knocked out (Stable), never dying
--   morale              { pack = fraction }: the pack runs once it has lost that much of itself
--   meter_dpr           what a turn of it really deals, for the difficulty meter, when its stat
--                       block's attacks don't show it (a gaze, a charm, a lecture)
M.MUSEUM = "The Museum of Nightmares"
local BRIAR_IMMUNE = { "blinded", "charmed", "deafened", "exhaustion", "frightened", "paralyzed", "petrified", "poisoned" }
local BPS = { "bludgeoning", "piercing", "slashing" }

add("briar_beast", {
    name = "Briar Beast", source = M.MUSEUM, museum = "briar", size = "medium", type = "construct",
    ac = 12, hp = 13, hit_dice = "3d8", speed = 50,
    abilities = { str = 14, dex = 15, con = 10, int = 3, wis = 14, cha = 7 },
    cr = "1/4", xp = 50, pb = 2,
    vulnerable = { "fire" }, immune = { "poison", "psychic" }, condition_immune = BRIAR_IMMUNE,
    traits = { "false_appearance" },
    briar_hooks = { 1, 4, 0, "piercing" },
    attacks = {
        { id = "thorn_talons", name = "Thorn Talons", kind = "melee", to_hit = 4, reach = 5, damage = { { 1, 6, 2, "piercing" } } },
    },
    role = "skirmisher",
})

add("briar_boar", {
    name = "Briar Boar", source = M.MUSEUM, museum = "briar", size = "small", type = "construct",
    ac = 11, hp = 11, hit_dice = "2d8+2", speed = 40,
    abilities = { str = 13, dex = 11, con = 12, int = 2, wis = 9, cha = 7 },
    cr = "1/4", xp = 50, pb = 2,
    vulnerable = { "fire" }, immune = { "poison", "psychic" }, condition_immune = BRIAR_IMMUNE,
    traits = { "false_appearance" },
    briar_hooks = { 1, 4, 0, "piercing" },
    attacks = {
        { id = "tusks", name = "Briar Tusks", kind = "melee", to_hit = 3, reach = 5, damage = { { 1, 6, 1, "slashing" } },
          charge = { feet = 20, extra = { 1, 6, 0, "slashing" }, save = "str", dc = 11 } },
    },
    role = "brute",
})

add("briar_triceratops", {
    name = "Briar Triceratops", source = M.MUSEUM, museum = "briar", size = "large", type = "construct",
    ac = 13, hp = 15, hit_dice = "3d8+2", speed = 40,
    -- (The printed Dexterity is "19 (+0)": the +0 is right for everything else on the block.)
    abilities = { str = 16, dex = 10, con = 12, int = 2, wis = 10, cha = 6 },
    -- Tuned: CR 1/4 (50 XP) as printed undersells two +5 attacks and a charge; CR 1 (200 XP) on the
    -- budget, so the meter warns the DM. The stat block itself is as printed.
    cr = "1", xp = 200, pb = 2,
    book = { cr = "1/4", xp = 50 },
    vulnerable = { "fire" }, immune = { "poison", "psychic" }, condition_immune = BRIAR_IMMUNE,
    traits = { "false_appearance" },
    multiattack = { count = 2, any_of = { "tusks", "hooves" }, seq = { "tusks", "hooves" } },
    attacks = {
        { id = "tusks", name = "Briar Tusks", kind = "melee", to_hit = 5, reach = 5, damage = { { 1, 6, 3, "slashing" } },
          charge = { feet = 20, extra = { 1, 6, 0, "slashing" }, save = "str", dc = 11 } },
        { id = "hooves", name = "Briar Hooves", kind = "melee", to_hit = 5, reach = 5, damage = { { 1, 6, 3, "bludgeoning" } } },
    },
    role = "brute",
})

add("sentinel", {
    name = "Sentinel", source = M.MUSEUM, museum = "sentinel", size = "large", type = "construct",
    ac = 15, hp = 52, hit_dice = "7d8+21", speed = 20,
    darkvision = 60,
    abilities = { str = 14, dex = 10, con = 16, int = 7, wis = 10, cha = 6 },
    cr = "2", xp = 450, pb = 2,
    resist = { "acid", "cold", "fire", "lightning", "thunder" }, resist_nonmagical = BPS,
    immune = { "poison" },
    nonlethal = true,                            -- Defender: it guards the donation box, it doesn't kill
    multiattack = { count = 2, any_of = { "fist" } },
    attacks = {
        { id = "fist", name = "Gauntleted Fist", kind = "melee", to_hit = 4, reach = 5, damage = { { 1, 6, 2, "bludgeoning" } },
          nonlethal = true },
    },
    role = "brute",
})

add("bone_construct", {
    name = "Bone Construct", source = M.MUSEUM, museum = "bone_construct", size = "large", type = "construct",
    -- Tuned: 33 Hit Points (6d8+6) become 45 (7d10+7), so the chamber lasts long enough for the
    -- scarabs to matter.
    ac = 18, hp = 45, hit_dice = "7d10+7", speed = 25, blindsight = 60,
    abilities = { str = 14, dex = 11, con = 13, int = 1, wis = 3, cha = 1 },
    cr = "1", xp = 200, pb = 2,
    book = { hp = 33 },
    immune = { "poison", "psychic" }, condition_immune = BRIAR_IMMUNE,
    -- Sands of the Ancients (Recharge 5-6): Dodge or Disengage as a Bonus Action.
    sands = { recharge = 5 },
    -- Crypt Scarabs: at half its Hit Points, a swarm of giant scarabs pours out of it.
    spawn = { id = "giant_scarab_swarm", at = 0.5, n = 1, name = "Crypt Scarabs" },
    multiattack = { count = 2, any_of = { "ritual_mace" } },
    attacks = {
        { id = "ritual_mace", name = "Ritual Mace", kind = "melee", to_hit = 4, reach = 5, damage = { { 1, 6, 2, "bludgeoning" } } },
    },
    role = "brute",
})

add("giant_scarab_swarm", {
    name = "Giant Scarab Swarm", source = M.MUSEUM, size = "medium", type = "construct", tags = { "swarm" },
    ac = 12, hp = 22, hit_dice = "5d8", speed = 30, fly = 30, blindsight = 60,
    abilities = { str = 5, dex = 15, con = 10, int = 2, wis = 12, cha = 4 },
    cr = "1/4", xp = 50, pb = 2,
    resist = BPS, immune = { "poison", "psychic" }, condition_immune = BRIAR_IMMUNE,
    traits = { "swarm" },                        -- can't regain Hit Points or gain Temporary Hit Points
    -- (Burrow, its latch-on attack, is left out: the pincers carry the fight.)
    attacks = {
        { id = "pincers", name = "Pincers", kind = "melee", to_hit = 4, reach = 5, damage = { { 2, 4, 0, "piercing" } },
          bloodied_damage = { { 1, 4, 0, "piercing" } } },
    },
    role = "brute",
})

add("knight_of_shades", {
    name = "Knight of Shades", source = M.MUSEUM, museum = "knight", size = "medium", type = "construct",
    ac = 12, hp = 67, hit_dice = "9d8+27", speed = 30,
    abilities = { str = 16, dex = 12, con = 17, int = 9, wis = 11, cha = 9 },
    -- Tuned: CR 2 (450 XP) on the budget instead of CR 1: against heroes without magic or paint
    -- it soaks up twice the blows, and beside Euryale that's what makes a fight run long.
    cr = "2", xp = 450, pb = 2,
    book = { cr = "1", xp = 200 },
    resist_nonmagical = BPS, vulnerable = { "fire" }, paint = true,
    immune = { "poison" }, condition_immune = BRIAR_IMMUNE,
    reckless = true,                             -- Advantage on its attacks; attacks on it have it too
    attacks = {
        { id = "greatsword", name = "Great Sword", kind = "melee", to_hit = 5, reach = 5, damage = { { 1, 10, 3, "slashing" } } },
    },
    role = "brute",
})

add("kruthik_huntling", {
    name = "Kruthik Huntling", source = M.MUSEUM, museum = "kruthik", size = "medium", type = "monstrosity",
    -- Tuned: 7 Hit Points (2d6+1) become 18 (4d8) and CR 1/4 becomes 1/2, so five of them are a
    -- real hunt for level 3 heroes (as printed, the heroes drop one with every hit).
    ac = 13, hp = 18, hit_dice = "4d8", speed = 40,
    darkvision = 60,
    abilities = { str = 8, dex = 14, con = 10, int = 10, wis = 8, cha = 8 },
    cr = "1/2", xp = 100, pb = 2,
    book = { hp = 7, cr = "1/4", xp = 50 },
    -- They wait hidden in the exhibits (Stealth +6) and strike first: a fight of only huntlings
    -- starts with the party surprised.
    traits = { "ambusher" },
    bonus = { "nimble_escape" },                 -- Nimble Survivor: Disengage or Hide as a Bonus Action
    morale = { pack = 0.6 },                     -- pack animals: they run before they lose
    multiattack = { count = 2, any_of = { "jaws", "talons" }, seq = { "jaws", "talons" } },
    attacks = {
        { id = "jaws", name = "Jaws", kind = "melee", to_hit = 4, reach = 5, damage = { { 1, 4, 2, "piercing" } } },
        { id = "talons", name = "Talons", kind = "melee", to_hit = 4, reach = 5, damage = { { 1, 4, 2, "slashing" } } },
    },
    role = "pack",
})

add("the_lecturer", {
    name = "The Lecturer", source = M.MUSEUM, museum = "lecturer", size = "medium", type = "undead",
    -- Tuned: 22 Hit Points (5d8) become 31 (7d8), so level 3 heroes hear more than a sentence of it.
    ac = 12, hp = 31, hit_dice = "7d8", speed = 30, fly = 30, hover = true,
    darkvision = 60,
    abilities = { str = 1, dex = 14, con = 11, int = 10, wis = 10, cha = 11 },
    cr = "1", xp = 200, pb = 2,
    resist = { "acid", "cold", "fire", "lightning", "thunder" }, resist_nonmagical = BPS,
    immune = { "necrotic", "poison" },
    condition_immune = { "charmed", "exhaustion", "grappled", "paralyzed", "petrified", "poisoned", "prone", "restrained",
                         "unconscious" },
    traits = { "incorporeal" },
    -- Bored to Death: one humanoid or beast within 30 ft that can hear, DC 14 Wisdom save or Charmed:
    -- it sits down and listens until someone tries to hurt it. (The exhaustion is left out.)
    bored = { save = "wis", dc = 14, range = 30 },
    attacks = {},
    book = { hp = 22 },
    meter_dpr = 4,
    role = "leader",
})

add("steam_mech", {
    name = "Steam Mech", source = M.MUSEUM, museum = "steam_mech", size = "large", type = "construct",
    ac = 13, hp = 29, hit_dice = "4d8+13", speed = 30,
    abilities = { str = 16, dex = 12, con = 17, int = 9, wis = 11, cha = 9 },
    cr = "1", xp = 200, pb = 2,
    resist_nonmagical = BPS, vulnerable = { "lightning" }, immune = { "poison" },
    condition_immune = { "charmed", "exhaustion", "grappled", "paralyzed", "petrified", "poisoned", "prone", "restrained",
                         "unconscious" },
    -- Hyper Destroyer Mode: AC +2, Speed +5 ft, +1d4 Lightning on its melee hits and Hyper Missiles
    -- as a Bonus Action; at the end of each of its turns in it, a Constitution save (DC 10 + turns
    -- in the mode) or it vents (2d6 Fire to everyone within 5 ft who fails a DC 12 Dex save) and
    -- shuts down at 0 Hit Points.
    hyper = { ac = 2, speed = 5, melee_extra = { 1, 4, 0, "lightning" }, dc = 10,
              vent = { save = "dex", dc = 12, damage = { 2, 6, 0, "fire" }, radius = 5 } },
    attacks = {
        { id = "steam_fists", name = "Steam Fists", kind = "melee", to_hit = 5, reach = 5, damage = { { 1, 8, 3, "bludgeoning" } } },
        { id = "chain_gun", name = "Chain Gun", kind = "ranged", to_hit = 3, range = { 60, 60 }, damage = { { 2, 4, 1, "piercing" } } },
    },
    missiles = { id = "hyper_missiles", name = "Hyper Missiles", kind = "ranged", to_hit = 1, range = { 60, 60 },
                 damage = { { 1, 4, 1, "piercing" } }, targets = 3 },
    role = "ally",
})

add("euryale", {
    name = "Euryale", source = M.MUSEUM, museum = "euryale", size = "medium", type = "monstrosity",
    -- Tuned (the book has her for four level 2 heroes; the arc meets her at level 3, alone or with
    -- a few of the museum's horrors): 65 Hit Points become 104 (16d8+32), she attacks three times
    -- (the book: once, and twice after the veil), and she's CR 3 (700 XP) instead of CR 2. A hero
    -- she charms tries the save again at the end of each of their turns (game/rules/museum.lua).
    ac = 16, hp = 104, hit_dice = "16d8+32", speed = 30,
    darkvision = 60,
    abilities = { str = 15, dex = 16, con = 14, int = 14, wis = 15, cha = 14 },
    cr = "3", xp = 700, pb = 2,
    book = { hp = 65, cr = "2", xp = 450, attacks = 1 },
    -- Lifting the Veil: on her first turn at half her Hit Points or less, the hood comes off: the
    -- Crown of Snakes joins her attacks and Petrify (once a day) is ready.
    veil = { at = 0.5 },
    -- Petrify (1/Day): everyone within 50 ft who can see her eyes, DC 12 Con save or Restrained,
    -- and again at the end of their next turn or Petrified until she's beaten. With a mirror held up
    -- she makes the save too.
    petrify = { save = "con", dc = 12, range = 50 },
    -- Spellcasting (Wisdom, DC 12, +4 to hit): Poison Spray at will (2d12, 30 ft, a 5th-level
    -- caster), Charm Person twice a day. Either can stand in for one of her attacks.
    spells = { dc = 12, to_hit = 4, slots = 2,
               poison_spray = { range = 30, damage = { { 2, 12, 0, "poison" } } },
               charm_person = { range = 30 } },
    -- Three attacks with claws or bow (one can be a spell instead); the Crown of Snakes adds one
    -- once the veil is off.
    multiattack = { count = 3, any_of = { "claws", "poison_bow" } },
    meter_dpr = 22,                              -- (her spells, the snakes and the gaze on top of the attacks)
    attacks = {
        { id = "claws", name = "Claws", kind = "melee", to_hit = 5, reach = 5, damage = { { 1, 6, 3, "slashing" } } },
        { id = "poison_bow", name = "Poison Bow", kind = "ranged", to_hit = 5, range = { 30, 120 },
          damage = { { 1, 6, 3, "piercing" }, { 1, 6, 0, "poison" } } },
        { id = "crown_of_snakes", name = "Crown of Snakes", kind = "melee", to_hit = 5, reach = 5, veiled = true,
          damage = { { 1, 6, 3, "piercing" }, { 1, 6, 0, "poison" } } },
    },
    role = "leader",
})

M.museum_order = { "briar_beast", "briar_boar", "briar_triceratops", "kruthik_huntling", "giant_scarab_swarm",
                   "bone_construct", "the_lecturer", "knight_of_shades", "steam_mech", "sentinel", "euryale" }

-- CR to XP (each stat block lists its XP; kept here for encounter math). base_order: the slice's
-- own roster; the rest come from the Vale Bestiary (A13, game/data/books.lua) once pulled.
M.base_order = { "bandit", "cultist", "goblin_warrior", "wolf", "skeleton", "zombie", "tough",
                 "goblin_boss", "dire_wolf", "ghoul", "bandit_captain", "ogre" }
M.order = { "bandit", "cultist", "goblin_warrior", "wolf", "skeleton", "zombie", "tough",
            "goblin_boss", "dire_wolf", "ghoul", "bandit_captain", "ogre",
            "kobold_warrior", "giant_crab", "guard", "swarm_of_rats", "scout", "gnoll_warrior", "worg",
            "pirate", "spy", "animated_armor", "giant_spider", "specter", "brown_bear", "bugbear_warrior",
            "merrow", "warrior_veteran" }

return M
