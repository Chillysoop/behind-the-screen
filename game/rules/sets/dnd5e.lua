-- The 5e rule set (SRD 5.2.1): what a roll is, who rolls it, what a fight is, for an adventure whose `rules` is "5e"
-- (docs/design/rule-sets.md). The shared game asks a rule set these things and reads the result's tier (great, full,
-- partial, miss, botch); the numbers and the words are the set's own. The rest of the 5e engine is game/rules/:
-- the battle on its grid, the foes' tactics, spells, skills, monsters. Pure Lua, like the rest of game/rules/.

local skills = require "game.rules.skills"

local M = {}

M.id = "5e"
M.name = "D&D 5e (SRD 5.2.1)"
M.dice = { kind = "d20", sides = 20 }      -- what the dice tray shows
M.who_rolls = "dm"                         -- the DM rolls, in the open or behind the screen
M.fight = "tactical"                       -- fights on the battle grid (game/rules/battle.lua)
M.approaches = skills.NAMES                -- what a hero can try: the 18 skills, and the six abilities
M.difficulty_word = "DC"

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

-- The die: one d20, or two and the better with Advantage ("adv"). The order the dice come off `rng` is part of the
-- result: a seeded playthrough is the same playthrough.
function M.roll(rng, edge)
    local roll = rng:d20()
    local other
    if edge == "adv" then
        other = rng:d20()
        if other > roll then
            roll, other = other, roll
        end
    end
    return roll, other
end

-- How it came out. A check succeeds on total >= DC; a natural 20 that succeeds is a great one, a natural 1 that
-- misses is a botch.
function M.tier(roll, total, dc)
    local success = total >= dc
    if success then
        return roll == 20 and "great" or "full", success
    end
    return roll == 1 and "botch" or "miss", success
end

-- A check, whole: the die, the bonus, the tier, and the line for the log ("Pip: Stealth 14+7 = 21 vs DC 15,
-- success"). `extra` is anything already added to the bonus (a lesson learned, research), so the line says it all.
function M.check(rng, opts)
    local roll, other = M.roll(rng, opts.edge)
    local mod = opts.mod or 0
    local total = roll + mod
    local tier, success = M.tier(roll, total, opts.dc)
    return { roll = roll, other = other, mod = mod, total = total, dc = opts.dc, success = success, tier = tier,
             crit = roll == 20, fumble = roll == 1 }
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
