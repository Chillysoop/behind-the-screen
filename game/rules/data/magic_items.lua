-- Magic items (A13), from SRD 5.2.1 "Magic Items A-Z" (pp. 209-253). They arrive in the Vale
-- Bestiary & Treasury; a pulled item joins the deck as a reward card, and once the party earns it,
-- someone carries it and the rules apply it (game/model/items.lua). Data only.
--
-- effect: what the engine does with it
--   weapon      +n to attack and damage rolls with the hero's weapons
--   ac          +n Armor Class          saves   +n to every saving throw
--   checks      +n to every ability check
--   adv         { skill... }: Advantage on those checks (and init = true: on Initiative)
--   climb_swim  +n to Athletics when the place calls for climbing or swimming
--   bow_damage  +n damage with Longbows and Shortbows (and proficiency with them)
--   charges     a wand: { n, spell, max, regain = { count, die, bonus } }
--   slot        once a day (at dawn), regain one spent spell slot of this level or lower
--   wound       Periapt of Wound Closure: death saves of 9 or lower count as 10, Hit Point Dice heal double
-- for:   who'd want it, best first (the party hands it to the first one here who can use it)
-- needs: "shield" (holds one), "caster" (Pearl of Power), "bow" (uses one)

local M = {}

local function add(id, t)
    t.id = id
    M[id] = t
end

add("weapon_plus1", {
    name = "+1 Weapon", page = 253, rarity = "Uncommon", attune = false,
    text = "A bonus of +1 to attack rolls and damage rolls made with this magic weapon.",
    effect = { weapon = 1 }, ["for"] = { "fighter", "rogue", "cleric" },
})

add("shield_plus1", {
    name = "+1 Shield", page = 243, rarity = "Uncommon", attune = false,
    text = "While holding this Shield, +1 to Armor Class on top of the Shield's normal bonus.",
    effect = { ac = 1 }, needs = "shield", ["for"] = { "fighter", "cleric" },
})

add("sentinel_shield", {
    name = "Sentinel Shield", page = 243, rarity = "Uncommon", attune = false,
    text = "While holding this Shield, Advantage on Initiative rolls and Wisdom (Perception) checks.",
    effect = { adv = { "perception" }, init = true }, needs = "shield", ["for"] = { "cleric", "fighter" },
})

add("cloak_of_protection", {
    name = "Cloak of Protection", page = 216, rarity = "Uncommon", attune = true,
    text = "A +1 bonus to Armor Class and saving throws while you wear this cloak.",
    effect = { ac = 1, saves = 1 }, ["for"] = { "wizard", "rogue", "cleric", "fighter" },
})

add("boots_of_elvenkind", {
    name = "Boots of Elvenkind", page = 213, rarity = "Uncommon", attune = false,
    text = "Your steps make no sound, and you have Advantage on Dexterity (Stealth) checks.",
    effect = { adv = { "stealth" } }, ["for"] = { "rogue", "wizard", "fighter", "cleric" },
})

add("eyes_of_the_eagle", {
    name = "Eyes of the Eagle", page = 221, rarity = "Uncommon", attune = false,
    text = "Crystal lenses: Advantage on Wisdom (Perception) checks that rely on sight.",
    effect = { adv = { "perception" } }, ["for"] = { "rogue", "wizard", "cleric", "fighter" },
})

add("gloves_of_swimming_and_climbing", {
    name = "Gloves of Swimming and Climbing", page = 224, rarity = "Uncommon", attune = true,
    text = "A Climb Speed and a Swim Speed equal to your Speed, and +5 to Strength (Athletics) checks made to climb or swim.",
    effect = { climb_swim = 5 }, ["for"] = { "fighter", "rogue", "cleric", "wizard" },
})

add("bracers_of_archery", {
    name = "Bracers of Archery", page = 214, rarity = "Uncommon", attune = true,
    text = "Proficiency with the Longbow and Shortbow, and +2 to damage rolls made with them.",
    effect = { bow_damage = 2 }, needs = "bow", ["for"] = { "rogue", "fighter" },
})

add("wand_of_magic_missiles", {
    name = "Wand of Magic Missiles", page = 251, rarity = "Uncommon", attune = false,
    text = "7 charges. Spend 1 to 3 to cast Magic Missile (level 1, +1 level per extra charge). Regains 1d6 + 1 at dawn; "
        .. "spend the last and roll a d20: on a 1 it crumbles to ash.",
    effect = { charges = { n = 7, spell = "magic_missile", max = 3, regain = { 1, 6, 1 } } },
    ["for"] = { "wizard", "cleric", "rogue", "fighter" },
})

add("pearl_of_power", {
    name = "Pearl of Power", page = 234, rarity = "Uncommon", attune = true,
    text = "A Magic action to regain one expended spell slot of level 3 or lower. Once a day, until the next dawn.",
    effect = { slot = 3 }, needs = "caster", ["for"] = { "wizard", "cleric" },
})

add("stone_of_good_luck", {
    name = "Stone of Good Luck (Luckstone)", page = 248, rarity = "Uncommon", attune = true,
    text = "While this polished agate is on your person, +1 to ability checks and saving throws.",
    effect = { checks = 1, saves = 1 }, ["for"] = { "rogue", "cleric", "wizard", "fighter" },
})

add("periapt_of_wound_closure", {
    name = "Periapt of Wound Closure", page = 234, rarity = "Uncommon", attune = true,
    text = "Death Saving Throws of 9 or lower count as 10, and Hit Point Dice you roll heal double.",
    effect = { wound = true }, ["for"] = { "fighter", "cleric", "rogue", "wizard" },
})

M.order = { "weapon_plus1", "shield_plus1", "sentinel_shield", "cloak_of_protection", "boots_of_elvenkind",
            "eyes_of_the_eagle", "gloves_of_swimming_and_climbing", "bracers_of_archery", "wand_of_magic_missiles",
            "pearl_of_power", "stone_of_good_luck", "periapt_of_wound_closure" }

-- Attunement (SRD 5.2.1 Rules Glossary, p. 177): no more than three items at once.
M.MAX_ATTUNED = 3

return M
