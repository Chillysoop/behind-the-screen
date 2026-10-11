-- Weapons and armor from SRD 5.2.1 ("Equipment", pp. 89-92), as data.
-- damage = { count, die, type }; versatile = two-handed die.
-- Properties: finesse, light, heavy, two_handed, thrown, ammunition, loading, reach.
-- range = { normal, long } in feet for Ammunition/Thrown weapons.

local W = {}

local function w(id, name, cat, kind, count, die, dtype, props, mastery, extra)
    local t = { id = id, name = name, category = cat, kind = kind, damage = { count, die, dtype }, mastery = mastery }
    for _, p in ipairs(props) do
        t[p] = true
    end
    for k, v in pairs(extra or {}) do
        t[k] = v
    end
    W[id] = t
    return t
end

-- Simple melee
w("club", "Club", "simple", "melee", 1, 4, "bludgeoning", { "light" }, "slow")
w("dagger", "Dagger", "simple", "melee", 1, 4, "piercing", { "finesse", "light", "thrown" }, "nick", { range = { 20, 60 } })
w("greatclub", "Greatclub", "simple", "melee", 1, 8, "bludgeoning", { "two_handed" }, "push")
w("handaxe", "Handaxe", "simple", "melee", 1, 6, "slashing", { "light", "thrown" }, "vex", { range = { 20, 60 } })
w("javelin", "Javelin", "simple", "melee", 1, 6, "piercing", { "thrown" }, "slow", { range = { 30, 120 } })
w("light_hammer", "Light Hammer", "simple", "melee", 1, 4, "bludgeoning", { "light", "thrown" }, "nick", { range = { 20, 60 } })
w("mace", "Mace", "simple", "melee", 1, 6, "bludgeoning", {}, "sap")
w("quarterstaff", "Quarterstaff", "simple", "melee", 1, 6, "bludgeoning", {}, "topple", { versatile = 8 })
w("sickle", "Sickle", "simple", "melee", 1, 4, "slashing", { "light" }, "nick")
w("spear", "Spear", "simple", "melee", 1, 6, "piercing", { "thrown" }, "sap", { range = { 20, 60 }, versatile = 8 })
-- Simple ranged
w("dart", "Dart", "simple", "ranged", 1, 4, "piercing", { "finesse", "thrown" }, "vex", { range = { 20, 60 } })
w("light_crossbow", "Light Crossbow", "simple", "ranged", 1, 8, "piercing", { "ammunition", "loading", "two_handed" }, "slow", { range = { 80, 320 } })
w("shortbow", "Shortbow", "simple", "ranged", 1, 6, "piercing", { "ammunition", "two_handed" }, "vex", { range = { 80, 320 } })
w("sling", "Sling", "simple", "ranged", 1, 4, "bludgeoning", { "ammunition" }, "slow", { range = { 30, 120 } })
-- Martial melee
w("battleaxe", "Battleaxe", "martial", "melee", 1, 8, "slashing", {}, "topple", { versatile = 10 })
w("flail", "Flail", "martial", "melee", 1, 8, "bludgeoning", {}, "sap")
w("glaive", "Glaive", "martial", "melee", 1, 10, "slashing", { "heavy", "reach", "two_handed" }, "graze")
w("greataxe", "Greataxe", "martial", "melee", 1, 12, "slashing", { "heavy", "two_handed" }, "cleave")
w("greatsword", "Greatsword", "martial", "melee", 2, 6, "slashing", { "heavy", "two_handed" }, "graze")
w("halberd", "Halberd", "martial", "melee", 1, 10, "slashing", { "heavy", "reach", "two_handed" }, "cleave")
w("longsword", "Longsword", "martial", "melee", 1, 8, "slashing", {}, "sap", { versatile = 10 })
w("maul", "Maul", "martial", "melee", 2, 6, "bludgeoning", { "heavy", "two_handed" }, "topple")
w("morningstar", "Morningstar", "martial", "melee", 1, 8, "piercing", {}, "sap")
w("pike", "Pike", "martial", "melee", 1, 10, "piercing", { "heavy", "reach", "two_handed" }, "push")
w("rapier", "Rapier", "martial", "melee", 1, 8, "piercing", { "finesse" }, "vex")
w("scimitar", "Scimitar", "martial", "melee", 1, 6, "slashing", { "finesse", "light" }, "nick")
w("shortsword", "Shortsword", "martial", "melee", 1, 6, "piercing", { "finesse", "light" }, "vex")
w("trident", "Trident", "martial", "melee", 1, 8, "piercing", { "thrown" }, "topple", { range = { 20, 60 }, versatile = 10 })
w("warhammer", "Warhammer", "martial", "melee", 1, 8, "bludgeoning", {}, "push", { versatile = 10 })
w("war_pick", "War Pick", "martial", "melee", 1, 8, "piercing", {}, "sap", { versatile = 10 })
w("whip", "Whip", "martial", "melee", 1, 4, "slashing", { "finesse", "reach" }, "slow")
-- Martial ranged
w("hand_crossbow", "Hand Crossbow", "martial", "ranged", 1, 6, "piercing", { "ammunition", "light", "loading" }, "vex", { range = { 30, 120 } })
w("heavy_crossbow", "Heavy Crossbow", "martial", "ranged", 1, 10, "piercing", { "ammunition", "heavy", "loading", "two_handed" }, "push", { range = { 100, 400 } })
w("longbow", "Longbow", "martial", "ranged", 1, 8, "piercing", { "ammunition", "heavy", "two_handed" }, "slow", { range = { 150, 600 } })
w("pistol", "Pistol", "martial", "ranged", 1, 10, "piercing", { "ammunition", "loading" }, "vex", { range = { 30, 90 } })

-- Armor (p. 92). base AC; dex_max nil = full Dex, 0 = none; str = Strength needed.
local A = {
    padded = { name = "Padded Armor", category = "light", base = 11, stealth_dis = true },
    leather = { name = "Leather Armor", category = "light", base = 11 },
    studded_leather = { name = "Studded Leather Armor", category = "light", base = 12 },
    hide = { name = "Hide Armor", category = "medium", base = 12, dex_max = 2 },
    chain_shirt = { name = "Chain Shirt", category = "medium", base = 13, dex_max = 2 },
    scale_mail = { name = "Scale Mail", category = "medium", base = 14, dex_max = 2, stealth_dis = true },
    breastplate = { name = "Breastplate", category = "medium", base = 14, dex_max = 2 },
    half_plate = { name = "Half Plate Armor", category = "medium", base = 15, dex_max = 2, stealth_dis = true },
    ring_mail = { name = "Ring Mail", category = "heavy", base = 14, dex_max = 0, stealth_dis = true },
    chain_mail = { name = "Chain Mail", category = "heavy", base = 16, dex_max = 0, str = 13, stealth_dis = true },
    splint = { name = "Splint Armor", category = "heavy", base = 17, dex_max = 0, str = 15, stealth_dis = true },
    plate = { name = "Plate Armor", category = "heavy", base = 18, dex_max = 0, str = 15, stealth_dis = true },
}

-- Potion of Healing (p. 99): Bonus Action to drink or
-- administer within 5 feet; regain 2d4 + 2.
local items = {
    potion_of_healing = { name = "Potion of Healing", heal = { 2, 4, 2 } },
}

return { weapons = W, armor = A, items = items, SHIELD_AC = 2 }
