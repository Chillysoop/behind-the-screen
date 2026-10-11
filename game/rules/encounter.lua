-- Encounter building and the difficulty meter.
-- The XP budget follows SRD 5.2.1 "Combat Encounter Difficulty" (p. 202); the
-- meter adds what thousands of simulated fights taught us (see tools/sim/battles.lua
-- and game/rules/data/difficulty_fit.lua).

local battle = require "game.rules.battle"
local creature = require "game.rules.creature"
local monsters = require "game.rules.data.monsters"
local party_mod = require "game.rules.party"
local spells = require "game.rules.spells"
local ai = require "game.rules.ai"

local M = {}

-- XP Budget per Character (p. 202): { Low, Moderate, High }.
M.XP_BUDGET = {
    [1] = { 50, 75, 100 }, [2] = { 100, 150, 200 }, [3] = { 150, 225, 400 }, [4] = { 250, 375, 500 },
    [5] = { 500, 750, 1100 }, [6] = { 600, 1000, 1400 },
}

M.LABELS = { "Trivial", "Low", "Moderate", "High", "Beyond High" }

function M.budget(level, n)
    local row = M.XP_BUDGET[level]
    return row[1] * n, row[2] * n, row[3] * n
end

function M.xp(monster_ids)
    local total = 0
    for _, id in ipairs(monster_ids) do
        total = total + monsters[id].xp
    end
    return total
end

-- Where an encounter sits on the SRD scale. The meter runs 0..4: 0-1 below Low,
-- 1-2 Low, 2-3 Moderate, 3-4 High, 4+ beyond High. "Low" means it fits a Low budget.
function M.rate(level, n, monster_ids)
    local xp = M.xp(monster_ids)
    local low, mod, high = M.budget(level, n)
    local meter, label
    if xp <= low * 0.5 then
        meter, label = xp / (low * 0.5), 1
    elseif xp <= low then
        meter, label = 1 + (xp - low * 0.5) / (low * 0.5), 2
    elseif xp <= mod then
        meter, label = 2 + (xp - low) / (mod - low), 3
    elseif xp <= high then
        meter, label = 3 + (xp - mod) / (high - mod), 4
    else
        meter, label = 4 + (xp - high) / high, 5
    end
    return { xp = xp, low = low, moderate = mod, high = high, meter = meter, label = M.LABELS[label],
             category = label, count = #monster_ids, ratio = xp / mod }
end

-- The difficulty meter ------------------------------------------------------------------------

-- What a monster dishes out per round: its best attack's average damage times the chance
-- to hit Armor Class 16 (about the party's average), times its Multiattack.
function M.monster_dpr(m)
    local best = 0
    for _, a in ipairs(m.attacks) do
        local avg = 0
        for _, p in ipairs(a.damage) do
            avg = avg + p[1] * (p[2] + 1) / 2 + p[3]
        end
        local hit = math.min(0.95, math.max(0.05, (5 + a.to_hit) / 20))
        best = math.max(best, avg * hit)
    end
    return best * (m.multiattack and m.multiattack.count or 1)
end

-- The slice party's total Hit Points at a level (default subclasses).
local party_hp_cache = {}
function M.party_hp(level)
    if not party_hp_cache[level] then
        local total = 0
        for _, c in ipairs(party_mod.build(level)) do
            total = total + c.hp_max
        end
        party_hp_cache[level] = total
    end
    return party_hp_cache[level]
end

M.FEATURE_NAMES = {
    "bias",
    "log(XP / Moderate budget)",
    "log ratio squared",
    "monsters per character",
    "log ratio x monsters per character",
    "share of XP in the biggest monster",
    "party level - 3",
    "log(monster HP / party HP)",
    "log(4 rounds of monster damage / party HP)",
}

-- Features the fitted meter uses. Besides the SRD XP budget it reads the stat blocks
-- (Hit Points and damage), so new monsters get a forecast without new simulations.
-- opts.party_hp overrides the slice party's Hit Points.
function M.features(level, n, monster_ids, opts)
    local r = M.rate(level, n, monster_ids)
    local maxxp, hp, dpr = 0, 0, 0
    for _, id in ipairs(monster_ids) do
        local m = monsters[id]
        maxxp = math.max(maxxp, m.xp)
        hp = hp + m.hp
        dpr = dpr + M.monster_dpr(m)
    end
    local php = (opts and opts.party_hp) or M.party_hp(level) * n / 4
    -- The simulated fights span about a quarter of the Moderate budget up to 2.6 times it,
    -- with at most 2.5 monsters per character; outside that the forecast is held at the edge.
    local lr = math.log(r.xp / r.moderate)
    local per = #monster_ids / n
    r.extrapolated = lr < M.RANGE.lr[1] or lr > M.RANGE.lr[2] or per > M.RANGE.per
    lr = math.max(M.RANGE.lr[1], math.min(M.RANGE.lr[2], lr))
    per = math.min(M.RANGE.per, per)
    return { 1, lr, lr * lr, per, lr * per, maxxp / r.xp, level - 3,
             math.log(hp / php), math.log(4 * dpr / php) }, r
end
M.RANGE = { lr = { -1.5, 1.0 }, per = 2.5 }

local function sigmoid(z)
    if z > 30 then return 1 end
    if z < -30 then return 0 end
    return 1 / (1 + math.exp(-z))
end

local function dot(a, b)
    local s = 0
    for i = 1, math.min(#a, #b) do s = s + a[i] * b[i] end
    return s
end

M.DANGER = { "Breezy", "Tense", "Dangerous", "Deadly" }

-- What the DM sees while building a fight: the SRD category plus forecasts learned
-- from simulated fights. Returns nil forecasts if the fit hasn't been generated.
function M.meter(level, n, monster_ids, opts)
    local x, r = M.features(level, n, monster_ids, opts)
    local ok, fit = pcall(require, "game.rules.data.difficulty_fit")
    local out = { srd = r.label, xp = r.xp, budget = { r.low, r.moderate, r.high }, position = r.meter,
                  extrapolated = r.extrapolated }
    if ok and fit and #fit.someone_drops == #x then
        out.someone_drops = sigmoid(dot(fit.someone_drops, x))
        out.party_falls = sigmoid(dot(fit.party_falls, x))
        out.someone_dies = sigmoid(dot(fit.someone_dies, x))
        out.hp_lost = sigmoid(dot(fit.hp_lost, x))
        local d = 1
        if out.someone_drops >= 0.15 then d = 2 end
        if out.someone_drops >= 0.5 then d = 3 end
        if out.party_falls >= 0.15 or out.someone_dies >= 0.15 then d = 4 end
        out.danger = M.DANGER[d]
        out.danger_level = d
    end
    return out
end

-- Build a random encounter for a party at a target difficulty ("low" | "moderate" | "high"),
-- spending as much of the budget as possible without going over (p. 202).
function M.build(rng, level, n, target, pool)
    pool = pool or monsters.order
    local low, mod, high = M.budget(level, n)
    local budget = ({ low = low, moderate = mod, high = high })[target]
    local floor = ({ low = 0, moderate = low, high = mod })[target]
    for _ = 1, 50 do
        local list, xp = {}, 0
        -- One kind of monster, sometimes two (p. 203 "Number of Stat Blocks").
        local kinds = { pool[rng:int(1, #pool)] }
        if rng:chance(0.5) then
            table.insert(kinds, pool[rng:int(1, #pool)])
        end
        local guard = 0
        while guard < 40 do
            guard = guard + 1
            local id = kinds[rng:int(1, #kinds)]
            local m = monsters[id]
            if xp + m.xp <= budget and #list < 2 * n + 2 then
                table.insert(list, id)
                xp = xp + m.xp
            else
                local fits = false
                for _, k in ipairs(kinds) do
                    if xp + monsters[k].xp <= budget then fits = true end
                end
                if not fits or #list >= 2 * n + 2 then break end
            end
        end
        if #list > 0 and xp > floor * 0.85 then
            return list
        end
    end
    return { pool[1] }
end

-- Precast long-duration spells before the fight, spending slots as a real party would:
-- Mage Armor (8 hours), Aid (8 hours), Warding Bond (1 hour).
function M.prebuff(b, party)
    for _, c in ipairs(party) do
        if spells.has_spell(c, "mage_armor") and not c.armor then
            local slot = spells.find_slot(c, 1)
            if slot then
                spells.spend_slot(c, slot)
                c.mage_armor = true
            end
        end
    end
    for _, c in ipairs(party) do
        if spells.has_spell(c, "aid") and spells.find_slot(c, 2) then
            spells.spend_slot(c, 2)
            spells.list.aid.cast(b, c, 2, { party[1], party[2], party[4] })
        end
        if spells.has_spell(c, "warding_bond") and spells.find_slot(c, 2) then
            spells.spend_slot(c, 2)
            spells.list.warding_bond.cast(b, c, 2, party[1])
        end
    end
end

-- Lay out the battlefield: party on the left, monsters `distance` feet away on the right.
function M.place(b, party, foes, distance)
    local cx = 4
    local cy = math.floor(b.H / 2)
    local spots = { { cx + 1, cy }, { cx + 1, cy - 2 }, { cx - 1, cy + 1 }, { cx - 2, cy - 1 } }
    for i, c in ipairs(party) do
        local s = spots[i] or { cx - 2, cy + i }
        b:add(c, s[1], s[2])
    end
    local fx = cx + 1 + math.floor(distance / 5)
    local i = 0
    for _, m in ipairs(foes) do
        local col = math.floor(i / 5)
        local row = (i % 5) - 2
        b:add(m, math.min(b.W, fx + col), cy + row * 2 - (col % 2))
        i = i + 1
    end
end

-- One fight. opts: seed, subs, distance, verbose, prebuff (default true), keep_log.
function M.run(level, monster_ids, opts)
    opts = opts or {}
    local b = battle.new({ seed = opts.seed or 1, verbose = opts.verbose, ai = ai })
    b.keep_log = opts.keep_log
    local party = party_mod.build(level, opts.subs)
    local foes = {}
    local counts = {}
    for _, id in ipairs(monster_ids) do
        counts[id] = (counts[id] or 0) + 1
        table.insert(foes, creature.new_monster(id, " " .. counts[id]))
    end
    if opts.prebuff ~= false then
        M.prebuff(b, party)
    end
    M.place(b, party, foes, opts.distance or 40)
    local result = b:run()
    result.rating = M.rate(level, #party, monster_ids)
    result.log = b.lines
    result.party = party
    return result
end

return M
