-- Short and Long Rests (A16), per SRD 5.2.1's Rules Glossary and class features. Pure Lua,
-- like the rest of game/rules/: the night decides when they rest; this decides what comes back.
--
-- Short Rest (1 hour): spend Hit Point Dice (roll the die + Con modifier each, regaining at
--   least 1); one use of Second Wind and of Channel Divinity comes back, Action Surge comes back,
--   and a wizard may use Arcane Recovery once per Long Rest (slots totalling up to half their
--   level, rounded up, none above 5th).
-- Long Rest (8 hours): all HP, all Hit Point Dice, all spell slots and feature uses come back;
--   Temporary Hit Points end. You need at least 1 HP to rest.
-- An interrupted Long Rest that lasted at least an hour still gives Short Rest benefits.
-- (Page references are in the README; the 2024 rules give back all Hit Point Dice, not half.)

local creature = require "game.rules.creature"

local M = {}

-- How each kind of player spends Hit Point Dice: up to what share of HP, keeping some back.
M.SPEND = {
    tactician = { upto = 0.75, keep = 1 }, power_gamer = { upto = 0.8, keep = 1 },
    butt_kicker = { upto = 1, keep = 0 }, casual = { upto = 1, keep = 0 }, default = { upto = 0.7, keep = 0 },
}

local function roll(dice, n)
    if dice and dice.roll then
        return dice:roll(1, n)
    elseif dice and dice.int then
        return dice:int(1, n)
    end
    return math.floor((n + 1) / 2) + ((n % 2 == 0) and 1 or 0)   -- the average, rounded up
end

-- Spend Hit Point Dice (one at a time, as a player would). Returns HP regained.
function M.spend_hit_dice(c, dice, policy)
    policy = policy or M.SPEND.default
    local gained = 0
    if not c.hd or c.dead then
        return 0
    end
    local con = creature.mod(c.abilities.con)
    while c.hd.left > policy.keep and c.hp < c.hp_max * policy.upto do
        c.hd.left = c.hd.left - 1
        local h = math.max(1, roll(dice, c.hd.die) + con)
        local before = c.hp
        c.hp = math.min(c.hp_max, c.hp + h)
        gained = gained + (c.hp - before)
    end
    return gained
end

local function arcane_recovery(c)
    if c.class ~= "wizard" or c.arcane_used or not c.res.slots or not c.slots_max then
        return 0
    end
    local budget = math.ceil((c.level or 1) / 2)
    local got = 0
    for lvl = math.min(5, #c.slots_max), 1, -1 do
        while budget >= lvl and c.res.slots[lvl] < c.slots_max[lvl] do
            c.res.slots[lvl] = c.res.slots[lvl] + 1
            budget = budget - lvl
            got = got + 1
        end
    end
    if got > 0 then
        c.arcane_used = true
    end
    return got
end

-- A Short Rest: what each hero gets back. Returns { hp = n, slots = n }.
function M.short(c, dice, policy)
    if c.dead or c.hp < 1 then
        return { hp = 0, slots = 0 }
    end
    local hp = M.spend_hit_dice(c, dice, policy)
    local r = c.res
    if r.second_wind and r.second_wind_max then
        r.second_wind = math.min(r.second_wind_max, r.second_wind + 1)
    end
    if c.class == "fighter" and (c.level or 1) >= 2 then
        r.action_surge = 1
    end
    if r.channel and r.channel_max then
        r.channel = math.min(r.channel_max, r.channel + 1)
    end
    return { hp = hp, slots = arcane_recovery(c) }
end

-- A Long Rest: everything back. keep_potions: potions are things, not features.
function M.long(c)
    if c.dead or c.hp < 1 then
        -- Down but stable: they wake with 1 HP and rest from there (the night's ruling).
        if c.dead then
            return false
        end
        c.hp = 1
        c.down = false
    end
    local potions = c.res.potions
    for k, v in pairs(c.res_full or {}) do
        if type(v) == "table" then
            c.res[k] = {}
            for i, n in pairs(v) do
                c.res[k][i] = n
            end
        else
            c.res[k] = v
        end
    end
    c.res.potions = potions
    c.hp = c.hp_max
    c.temp = 0
    if c.hd then
        c.hd.left = c.hd.max
    end
    c.arcane_used = false
    return true
end

-- How full the party is: { hp = share of HP, slots = share of slots left, hd = dice left, worst }.
function M.state(pcs)
    local hp, hpm, sl, slm, hd, worst = 0, 0, 0, 0, 0, 1
    for _, c in ipairs(pcs or {}) do
        if not c.dead then
            hp, hpm = hp + math.max(0, c.hp), hpm + c.hp_max
            worst = math.min(worst, math.max(0, c.hp) / math.max(1, c.hp_max))
            for i, n in ipairs(c.slots_max or {}) do
                sl, slm = sl + (c.res.slots and c.res.slots[i] or 0), slm + n
            end
            hd = hd + (c.hd and c.hd.left or 0)
        end
    end
    return { hp = hpm > 0 and hp / hpm or 1, slots = slm > 0 and sl / slm or 1, hd = hd, worst = worst }
end

return M
