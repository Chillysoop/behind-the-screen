-- Skills and ability checks for the four player characters (SRD 5.2.1, "Playing the
-- Game": Ability Checks and Skill Proficiencies, p. 6; Expertise in the Rules Glossary,
-- p. 179). Each character's proficiencies come from their class list, background and
-- species, chosen the way their player would:
--
--   Brannoc  Fighter (Perception, Survival), Soldier (Athletics, Intimidation), Human Skillful (Insight)
--   Pip      Rogue (Deception, Investigation, Perception, Persuasion), Criminal (Sleight of Hand, Stealth);
--            Expertise (Rogue level 1) in Stealth and Sleight of Hand
--   Oswin    Cleric (Medicine, Persuasion), Acolyte (Insight, Religion)
--   Thessaly Wizard (Insight, Investigation), Sage (Arcana, History), Elf Keen Senses (Perception);
--            Scholar (Wizard level 2): Expertise in Arcana
--
-- A check is d20 + the ability modifier + the Proficiency Bonus if proficient (twice it with
-- Expertise). Pure Lua.

local party = require "game.rules.party"

local M = {}

M.ABILITY = {
    athletics = "str",
    acrobatics = "dex", sleight_of_hand = "dex", stealth = "dex",
    arcana = "int", history = "int", investigation = "int", nature = "int", religion = "int",
    animal_handling = "wis", insight = "wis", medicine = "wis", perception = "wis", survival = "wis",
    deception = "cha", intimidation = "cha", performance = "cha", persuasion = "cha",
}

M.NAMES = {
    athletics = "Athletics", acrobatics = "Acrobatics", sleight_of_hand = "Sleight of Hand", stealth = "Stealth",
    arcana = "Arcana", history = "History", investigation = "Investigation", nature = "Nature", religion = "Religion",
    animal_handling = "Animal Handling", insight = "Insight", medicine = "Medicine", perception = "Perception",
    survival = "Survival", deception = "Deception", intimidation = "Intimidation", performance = "Performance",
    persuasion = "Persuasion",
    -- Plain ability checks.
    str = "Strength", dex = "Dexterity", con = "Constitution", int = "Intelligence", wis = "Wisdom", cha = "Charisma",
}

M.PROFICIENT = {
    fighter = { perception = true, survival = true, athletics = true, intimidation = true, insight = true },
    rogue = { deception = true, investigation = true, perception = true, persuasion = true,
              sleight_of_hand = true, stealth = true },
    cleric = { medicine = true, persuasion = true, insight = true, religion = true },
    wizard = { insight = true, investigation = true, arcana = true, history = true, perception = true },
}

M.EXPERTISE = {
    rogue = { stealth = true, sleight_of_hand = true },
    wizard = { arcana = true },          -- Scholar, from Wizard level 2
}

-- Silvertongue (our Rogue subclass, level 3) adds Expertise in Persuasion and Deception.
M.SUBCLASS_EXPERTISE = {
    silvertongue = { persuasion = true, deception = true },
}

local function pb(level)
    return 2 + math.floor(((level or 1) - 1) / 4)
end

local function abmod(score)
    return math.floor((score - 10) / 2)
end

-- The modifier a character adds to a check with this skill (or plain ability).
-- cls: "fighter", "rogue", "cleric", "wizard"; level and subclass as the campaign has them.
function M.mod(cls, skill, level, sub)
    level = level or 2
    local sheet = party.sheet(cls, level, level >= 3 and sub or nil)
    local ab = M.ABILITY[skill] or skill
    local score = sheet.abilities[ab] or 10
    local m = abmod(score)
    local prof = M.PROFICIENT[cls] and M.PROFICIENT[cls][skill]
    if prof then
        local expert = (M.EXPERTISE[cls] and M.EXPERTISE[cls][skill])
            or (sub and level >= 3 and M.SUBCLASS_EXPERTISE[sub] and M.SUBCLASS_EXPERTISE[sub][skill])
        m = m + pb(level) * (expert and 2 or 1)
    end
    return m
end

-- The best of several skills for this character: skill, modifier.
function M.best(cls, skills, level, sub)
    local best, bm
    for _, s in ipairs(skills) do
        local m = M.mod(cls, s, level, sub)
        if not bm or m > bm then
            best, bm = s, m
        end
    end
    return best, bm
end

function M.name(skill)
    return M.NAMES[skill] or skill
end

-- "+5", "-1", "+0"
function M.signed(m)
    m = math.floor(m + 0.5)
    return (m >= 0 and "+" or "") .. tostring(m)
end

return M
