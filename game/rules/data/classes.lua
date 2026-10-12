-- The four slice classes from SRD 5.2.1 ("Classes"), levels 1-4 only.
-- Pages: Cleric 36-40, Fighter 47-49, Rogue 61-64, Wizard 77-82.
-- Character advancement and fixed Hit Points: p. 23.

local C = {}

C.fighter = {
    name = "Fighter", page = 47,
    hit_die = 10, fixed_hp = 6,                -- 6 + Con per level after 1st
    saves = { "str", "con" },
    armor = { light = true, medium = true, heavy = true, shield = true },
    weapons = { simple = true, martial = true },
    primary = { "str", "dex" },
    standard_array = { str = 15, dex = 14, con = 13, int = 8, wis = 10, cha = 12 },
    levels = {
        [1] = { pb = 2, features = { "fighting_style", "second_wind", "weapon_mastery" }, second_wind = 2, masteries = 3 },
        [2] = { pb = 2, features = { "action_surge", "tactical_mind" }, second_wind = 2, masteries = 3 },
        [3] = { pb = 2, features = { "subclass" }, second_wind = 2, masteries = 3 },
        [4] = { pb = 2, features = { "asi" }, second_wind = 3, masteries = 4 },
    },
}

C.rogue = {
    name = "Rogue", page = 61,
    hit_die = 8, fixed_hp = 5,
    saves = { "dex", "int" },
    armor = { light = true },
    weapons = { simple = true, martial_finesse_or_light = true },
    primary = { "dex" },
    standard_array = { str = 12, dex = 15, con = 13, int = 14, wis = 10, cha = 8 },
    levels = {
        [1] = { pb = 2, features = { "expertise", "sneak_attack", "thieves_cant", "weapon_mastery" }, sneak = 1, masteries = 2 },
        [2] = { pb = 2, features = { "cunning_action" }, sneak = 1, masteries = 2 },
        [3] = { pb = 2, features = { "subclass", "steady_aim" }, sneak = 2, masteries = 2 },
        [4] = { pb = 2, features = { "asi" }, sneak = 2, masteries = 2 },
    },
}

C.cleric = {
    name = "Cleric", page = 36,
    hit_die = 8, fixed_hp = 5,
    saves = { "wis", "cha" },
    armor = { light = true, medium = true, shield = true },
    weapons = { simple = true },
    primary = { "wis" },
    casting = "wis",
    standard_array = { str = 14, dex = 8, con = 13, int = 10, wis = 15, cha = 12 },
    levels = {
        [1] = { pb = 2, features = { "spellcasting", "divine_order" }, cantrips = 3, prepared = 4, slots = { 2 } },
        [2] = { pb = 2, features = { "channel_divinity" }, channel = 2, cantrips = 3, prepared = 5, slots = { 3 } },
        [3] = { pb = 2, features = { "subclass" }, channel = 2, cantrips = 3, prepared = 6, slots = { 4, 2 } },
        [4] = { pb = 2, features = { "asi" }, channel = 2, cantrips = 4, prepared = 7, slots = { 4, 3 } },
    },
}

C.wizard = {
    name = "Wizard", page = 77,
    hit_die = 6, fixed_hp = 4,
    saves = { "int", "wis" },
    armor = {},
    weapons = { simple = true },
    primary = { "int" },
    casting = "int",
    standard_array = { str = 8, dex = 12, con = 13, int = 15, wis = 14, cha = 10 },
    levels = {
        [1] = { pb = 2, features = { "spellcasting", "ritual_adept", "arcane_recovery" }, cantrips = 3, prepared = 4, slots = { 2 } },
        [2] = { pb = 2, features = { "scholar" }, cantrips = 3, prepared = 5, slots = { 3 } },
        [3] = { pb = 2, features = { "subclass" }, cantrips = 3, prepared = 6, slots = { 4, 2 } },
        [4] = { pb = 2, features = { "asi" }, cantrips = 4, prepared = 7, slots = { 4, 3 } },
    },
}

-- Species (pp. 84-86), only the traits that matter at the table.
C.species = {
    human = { name = "Human", size = "medium", speed = 30, traits = { "resourceful", "versatile" } },
    dwarf = { name = "Dwarf", size = "medium", speed = 30, darkvision = 120, traits = { "dwarven_resilience", "dwarven_toughness" },
              resist = { "poison" } },
    halfling = { name = "Halfling", size = "small", speed = 30, traits = { "brave", "halfling_luck", "halfling_nimbleness" } },
    elf = { name = "Elf", size = "medium", speed = 30, darkvision = 60, traits = { "fey_ancestry", "trance" } },
}

-- Backgrounds (p. 83): three abilities (+2/+1 to two of them) and an Origin feat.
C.backgrounds = {
    acolyte = { name = "Acolyte", abilities = { "int", "wis", "cha" }, feat = "magic_initiate_cleric" },
    criminal = { name = "Criminal", abilities = { "dex", "con", "int" }, feat = "alert" },
    sage = { name = "Sage", abilities = { "con", "int", "wis" }, feat = "magic_initiate_wizard" },
    soldier = { name = "Soldier", abilities = { "str", "dex", "con" }, feat = "savage_attacker" },
}

-- Feats used by the slice (pp. 87-88).
C.feats = {
    alert = { name = "Alert", kind = "origin" },                         -- +PB to Initiative
    magic_initiate_cleric = { name = "Magic Initiate (Cleric)", kind = "origin" },
    magic_initiate_wizard = { name = "Magic Initiate (Wizard)", kind = "origin" },
    savage_attacker = { name = "Savage Attacker", kind = "origin" },     -- once per turn, roll weapon dice twice
    skilled = { name = "Skilled", kind = "origin" },
    asi = { name = "Ability Score Improvement", kind = "general" },
    archery = { name = "Archery", kind = "fighting_style" },             -- +2 ranged weapon attacks
    defense = { name = "Defense", kind = "fighting_style" },             -- +1 AC in armor
    great_weapon_fighting = { name = "Great Weapon Fighting", kind = "fighting_style" }, -- 1s and 2s count as 3
    two_weapon_fighting = { name = "Two-Weapon Fighting", kind = "fighting_style" },     -- add mod to Light extra attack
}

-- Proficiency bonus is +2 for levels 1-4 (p. 23).
function C.pb(level)
    return 2 + math.floor((level - 1) / 4)
end

return C
