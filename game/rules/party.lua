-- The slice's four player characters as SRD 5.2.1 character sheets, at levels
-- 2 to 4, with any of their three subclasses from level 3. Ability scores use
-- the Standard Array by Class (p. 20) plus background increases (+2/+1, p. 21);
-- level 4 takes the Ability Score Improvement feat (+2 to the main ability).

local creature = require "game.rules.creature"

local M = {}

local function copy(t)
    local o = {}
    for k, v in pairs(t) do
        o[k] = type(v) == "table" and copy(v) or v
    end
    return o
end

-- Brannoc, Dev's Fighter: Human Soldier, Great Weapon Fighting, greatsword and javelins.
local function brannoc(level, sub)
    local s = {
        name = "Brannoc", player = "dev", class = "fighter", level = level, subclass = sub,
        species = "human", background = "soldier",
        abilities = { str = 17, dex = 14, con = 14, int = 8, wis = 10, cha = 12 },
        feats = { "savage_attacker", "alert" },
        fighting_style = "great_weapon_fighting",
        armor = "chain_mail", shield = false,
        weapons = { main = "greatsword", thrown = "javelin" },
        masteries = { "greatsword", "javelin", "flail" },
        potions = 1,
    }
    if sub == "spellguard" then
        -- A Spellguard trades some Charisma for Intelligence.
        s.abilities.int, s.abilities.cha = 12, 8
    end
    if level >= 4 then
        s.abilities.str = 19
        table.insert(s.masteries, "longsword")
    end
    return s
end

-- Pip, Jess's Rogue: Halfling Criminal, shortsword and dagger with Nick, shortbow.
local function pip(level, sub)
    local s = {
        name = "Pip", player = "jess", class = "rogue", level = level, subclass = sub,
        species = "halfling", background = "criminal",
        abilities = { str = 12, dex = 17, con = 14, int = 14, wis = 10, cha = 8 },
        feats = { "alert" },
        armor = "leather",
        weapons = { main = "shortsword", offhand = "dagger", ranged = "shortbow" },
        masteries = { "shortsword", "dagger" },
        potions = 1,
    }
    if sub == "silvertongue" then
        s.abilities.int, s.abilities.cha = 8, 14
    end
    if level >= 4 then
        s.abilities.dex = 19
    end
    return s
end

-- Oswin, Sam's Cleric: Dwarf Acolyte, Protector order, mace and shield.
local function oswin(level, sub)
    local prepared = {
        [2] = { "bless", "cure_wounds", "guiding_bolt", "healing_word", "shield_of_faith" },
        [3] = { "bless", "cure_wounds", "guiding_bolt", "healing_word", "shield_of_faith", "spiritual_weapon" },
        [4] = { "bless", "cure_wounds", "guiding_bolt", "healing_word", "shield_of_faith", "spiritual_weapon",
                "hold_person" },
    }
    local s = {
        name = "Oswin", player = "sam", class = "cleric", level = level, subclass = sub,
        species = "dwarf", background = "acolyte",
        abilities = { str = 14, dex = 8, con = 13, int = 10, wis = 17, cha = 13 },
        feats = { "magic_initiate_cleric" }, mi_spell = "healing_word",
        divine_order = "protector",
        armor = "chain_mail", shield = true,
        weapons = { main = "mace" },
        cantrips = { "sacred_flame", "guidance", "thaumaturgy", "spare_the_dying" },
        prepared = copy(prepared[level]),
        potions = 1,
    }
    -- Each domain fills its prepared list around its always-prepared spells, the way a
    -- player would: Aid (an 8-hour buff) makes every list.
    if sub == "life" and level >= 3 then
        s.prepared = { "guiding_bolt", "healing_word", "shield_of_faith", "spiritual_weapon", "inflict_wounds",
                       "prayer_of_healing" }
        if level >= 4 then table.insert(s.prepared, "hold_person") end
    elseif sub == "hearth" and level >= 3 then
        s.prepared = { "bless", "cure_wounds", "guiding_bolt", "healing_word", "spiritual_weapon", "inflict_wounds" }
        if level >= 4 then table.insert(s.prepared, "hold_person") end
    elseif sub == "mischief" and level >= 3 then
        s.prepared = { "bless", "cure_wounds", "guiding_bolt", "healing_word", "spiritual_weapon", "aid" }
        if level >= 4 then table.insert(s.prepared, "hold_person") end
    end
    if level >= 4 then
        s.abilities.wis = 19
    else
        table.remove(s.cantrips, 4)      -- the fourth cantrip arrives at level 4
    end
    return s
end

-- Thessaly, Mara's Wizard: Elf Sage, Mage Armor, Fire Bolt and a well-thumbed spellbook.
local function thessaly(level, sub)
    local prepared = {
        [2] = { "mage_armor", "magic_missile", "sleep", "burning_hands", "thunderwave" },
        [3] = { "mage_armor", "magic_missile", "sleep", "burning_hands", "shatter", "web" },
        [4] = { "mage_armor", "magic_missile", "sleep", "burning_hands", "shatter", "web", "scorching_ray" },
    }
    local s = {
        name = "Thessaly", player = "mara", class = "wizard", level = level, subclass = sub,
        species = "elf", background = "sage",
        abilities = { str = 8, dex = 12, con = 14, int = 17, wis = 14, cha = 10 },
        feats = { "magic_initiate_wizard" }, mi_spell = "shield",
        armor = nil, mage_armor = false,
        weapons = { main = "quarterstaff" },
        cantrips = { "fire_bolt", "ray_of_frost", "light", "shocking_grasp", "chill_touch" },
        prepared = copy(prepared[level]),
        potions = 1,
    }
    if level >= 4 then
        s.abilities.int = 19
        table.insert(s.cantrips, "acid_splash")
    end
    return s
end

M.builders = { fighter = brannoc, rogue = pip, cleric = oswin, wizard = thessaly }
M.order = { "fighter", "rogue", "cleric", "wizard" }
M.default_subclass = { fighter = "champion", rogue = "thief", cleric = "life", wizard = "evoker" }

-- Build the party. subs = { fighter = "champion", ... } (ignored below level 3).
function M.build(level, subs)
    subs = subs or M.default_subclass
    local out = {}
    for _, cls in ipairs(M.order) do
        local sub = level >= 3 and (subs[cls] or M.default_subclass[cls]) or nil
        local sheet = M.builders[cls](level, sub)
        local c = creature.new_pc(sheet)
        c.res.thrown = sheet.weapons.thrown and 8 or 0
        table.insert(out, c)
    end
    return out
end

function M.sheet(cls, level, sub)
    return M.builders[cls](level, sub)
end

return M
