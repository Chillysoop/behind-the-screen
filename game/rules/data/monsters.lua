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
    name = "Worg", page = 342, size = "large", type = "fey",
    ac = 13, hp = 26, hit_dice = "4d10+4", speed = 50,
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
