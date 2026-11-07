-- The 5e rule set (SRD 5.2.1): what a roll is, who rolls it, what a fight is, for an adventure whose `rules` is "5e"
-- (docs/design/rule-sets.md). The shared game asks a rule set these things and reads the result's tier (great, full,
-- partial, miss, botch); the numbers and the words are the set's own. The rest of the 5e engine is game/rules/:
-- the battle on its grid, the foes' tactics, spells, skills, monsters. Pure Lua, like the rest of game/rules/.

local skills = require "game.rules.skills"
local dice = require "game.kit.dice"      -- (the table's dice, any kind: 5e rolls the d20)

local M = {}

M.id = "5e"
M.title = "D&D 5e (SRD 5.2.1)"      -- (M.name is an approach's name: "Stealth")
M.dice = { notation = "1d20", sides = 20 }  -- what the dice tray shows (from game/kit/dice.lua, like any set's)
M.who_rolls = "dm"                         -- the DM rolls, in the open or behind the screen
M.fight = "tactical"                       -- fights on the battle grid (game/rules/battle.lua)
M.approaches = skills.NAMES                -- what a hero can try: the 18 skills, and the six abilities
M.difficulty_word = "DC"

-- 5e's engine, the parts the shared game reaches through game/model/ruleset.lua (`ruleset.part("battle")`), loaded on
-- first use. (Listed with literal requires, so Defold's builder packs each one.)
local PARTS = {
    ai = function() return require "game.rules.ai" end,
    battle = function() return require "game.rules.battle" end,
    creature = function() return require "game.rules.creature" end,
    encounter = function() return require "game.rules.encounter" end,
    hazards = function() return require "game.rules.hazards" end,
    museum = function() return require "game.rules.museum" end,
    party = function() return require "game.rules.party" end,
    rest = function() return require "game.rules.rest" end,
    skills = function() return require "game.rules.skills" end,
    spells = function() return require "game.rules.spells" end,
    subclasses = function() return require "game.rules.subclasses" end,
    ["data.classes"] = function() return require "game.rules.data.classes" end,
    ["data.equipment"] = function() return require "game.rules.data.equipment" end,
    ["data.hazards"] = function() return require "game.rules.data.hazards" end,
    ["data.magic_items"] = function() return require "game.rules.data.magic_items" end,
    ["data.monsters"] = function() return require "game.rules.data.monsters" end,
}
M.engine = setmetatable({}, {
    __index = function(t, k)
        local load = PARTS[k]
        if load then
            local part = load()
            rawset(t, k, part)
            return part
        end
    end,
})
-- 5e's own words: no other set's adventure may show one, and the shared game only says them through this set
-- (tools/tests/rules_fence_check.lua). Dice and grids aren't here: they're the table's (game/kit/), any set's to use.
M.owns = {
    "%f[%w]DCs?%f[%W]", "%f[%w]Advantage%f[%W]", "%f[%w]Disadvantage%f[%W]", "natural 20", "natural 1%f[%D]",
    "spell slot", "hit points", "%f[%w]HP%f[%W]", "%f[%w]AC%f[%W]", "Armor Class", "saving throw", "death save",
    "Heroic Inspiration", "Proficiency", "cantrip", "short rest", "long rest", "%f[%w]Insight%f[%W]", "%f[%w]Arcana%f[%W]",
    "%f[%w]Perception%f[%W]", "%f[%w]Investigation%f[%W]", "%f[%w]Persuasion%f[%W]", "%f[%w]Stealth%f[%W]",
    "%f[%w]Athletics%f[%W]", "%f[%w]Concentration%f[%W]", "%f[%w]Bless%f[%W]", "Cure Wounds", "Healing Word", "Detect Magic",
}

-- A hero's bonus for an approach: ability modifier and Proficiency Bonus (twice it with Expertise).
function M.mod(class, approach, level, subclass)
    return skills.mod(class, approach, level, subclass)
end
function M.name(approach)
    return skills.name(approach)
end
function M.signed(n)
    return skills.signed(n)
end

local D20, ADVANTAGE = dice.parse("1d20"), dice.parse("2d20kh1")

-- One die of the set's, off `rng` (game/model/rng.lua, or game/rules/dice.lua's forced faces).
function M.die(rng)
    return dice.roll(rng, D20).total
end

-- The die: one d20, or two and the better with Advantage ("adv"). The order the dice come off `rng` is part of the
-- result: a seeded playthrough is the same playthrough.
function M.roll(rng, edge)
    if edge == "adv" then
        local g = dice.roll(rng, ADVANTAGE).groups[1]
        local keep = g.kept[1] and 1 or 2
        return g.faces[keep], g.faces[3 - keep]
    end
    return M.die(rng), nil
end

-- How it came out, in the tiers the shared game reads (the DM's rulings, game/data/rulings.lua): triumph, success,
-- near, flop. A natural 20 or beating the DC by 5 is a triumph; a natural 1 or missing by 5 is a flop; a miss by
-- less is near, where a "yes, but" lives. (The DM's big rolls, game/model/night.lua's roll card.)
function M.tier(total, dc, natural)
    if natural == 20 or total >= dc + 5 then
        return "triumph"
    elseif total >= dc then
        return "success"
    elseif natural == 1 or total <= dc - 5 then
        return "flop"
    end
    return "near"
end

-- What a DC means for this roller, in words a newcomer can weigh: the number they need on the d20 and how often that
-- comes up. (A natural 20 always makes it: M.tier.)
function M.odds_line(dc, mod)
    local need = dc - (mod or 0)
    if need <= 2 then
        return "They make it on almost any roll."
    elseif need >= 20 then
        return "Only a natural 20 makes it (1 in 20)."
    end
    local chance = (21 - need) / 20
    -- (40% isn't "a coin flip": the card-led playtest, October 16.)
    local word = (chance >= 0.85 and "very likely") or (chance >= 0.6 and "likely") or (chance >= 0.45 and "a coin flip")
        or (chance >= 0.3 and "less likely than not") or (chance >= 0.15 and "unlikely") or "a long shot"
    return "They need " .. string.format("%d", math.floor(need + 0.5)) .. " or more on the d20: about "
        .. string.format("%d", math.floor(math.floor(chance * 100 + 0.5) + 0.5)) .. "%, " .. word .. "."
end

-- A check, whole: the die, the bonus, the tier, and the line for the log ("Pip: Stealth 14+7 = 21 vs DC 15,
-- success"). `extra` is anything already added to the bonus (a lesson learned, research), so the line says it all.
function M.check(rng, opts)
    local roll, other = M.roll(rng, opts.edge)
    local mod = opts.mod or 0
    local total = roll + mod
    return { roll = roll, other = other, mod = mod, total = total, dc = opts.dc, success = total >= opts.dc,
             tier = M.tier(total, opts.dc, roll), crit = roll == 20, fumble = roll == 1 }
end

-- The result's word for the log: "natural 20" and "natural 1" whatever the total, as the table says them.
function M.result_word(r)
    if r.roll == 20 then
        return "natural 20"
    elseif r.roll == 1 then
        return "natural 1"
    end
    return r.success and "success" or "miss"
end
local function int(x)
    return string.format("%d", math.floor(x + 0.5))
end
function M.line(who, approach, r)
    return who .. ": " .. M.name(approach) .. " " .. int(r.roll) .. M.signed(r.mod) .. " = " .. int(r.total)
        .. " vs DC " .. int(r.dc) .. ", " .. M.result_word(r)
end

return M
