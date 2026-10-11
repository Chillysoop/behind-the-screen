-- The encounter builder's read on a fight (real-session pass): how hard it is (the M3 meter
-- and the SRD XP budget), and how it lines up against what this party can actually do:
-- who can hit what, who gets hit, damage they resist or are weak to, spells that won't
-- work on them, and anything that can drop a hero in one blow. Pure Lua.

local encounter = require "game.rules.encounter"
local monsters = require "game.rules.data.monsters"
local party_mod = require "game.rules.party"
local creature = require "game.rules.creature"
local util = require "game.model.util"

local M = {}

-- The monsters the builder offers, weakest first.
M.ROSTER = { "goblin_warrior", "bandit", "skeleton", "zombie", "wolf", "cultist", "goblin_boss", "tough", "ghoul",
             "dire_wolf", "bandit_captain", "ogre" }

M.MAX = 8

local function avg(parts)
    local t = 0
    for _, p in ipairs(parts or {}) do
        t = t + p[1] * (p[2] + 1) / 2 + (p[3] or 0)
    end
    return t
end

local function chance(need)
    return util.clamp((21 - need) / 20, 0.05, 0.95)
end

local function pct(x)
    return util.int(math.floor(x * 100 + 0.5)) .. "%"
end

-- The party at the table: rules creatures with their player.
function M.party(campaign)
    local out = {}
    local present = {}
    for _, p in ipairs(campaign.players) do
        if p.present then
            present[p.class] = p
        end
    end
    for _, c in ipairs(party_mod.build(campaign.level or 2, campaign.subclasses)) do
        if present[c.class] then
            c.player = present[c.class]
            if c.class == "wizard" then
                c.mage_armor = true      -- cast before every adventuring day
            end
            table.insert(out, c)
        end
    end
    return out
end

-- A short line per monster for the roster: "AC 15, 21 HP, CR 1".
function M.blurb(id)
    local m = monsters[id]
    if not m then
        return ""
    end
    return "AC " .. util.int(m.ac) .. ", " .. util.int(m.hp) .. " HP, CR " .. tostring(m.cr)
end

-- Everything the builder shows for this list of monster ids.
function M.analyze(campaign, ids)
    local level = campaign.level or 2
    local pcs = M.party(campaign)
    local n = math.max(1, #pcs)
    local out = { notes = {}, level = level, n = n }
    if #ids == 0 then
        return out
    end
    out.meter = encounter.meter(level, n, ids)
    local low, mod, high = encounter.budget(level, n)
    out.budget = { low = low, moderate = mod, high = high }
    out.xp = encounter.xp(ids)
    local seen, kinds = {}, {}
    for _, id in ipairs(ids) do
        if not seen[id] then
            seen[id] = 0
            table.insert(kinds, id)
        end
        seen[id] = seen[id] + 1
    end
    local notes = out.notes
    local function note(text, tone, weight)
        table.insert(notes, { text = text, tone = tone or "info", weight = weight or 1 })
    end
    -- Who can hit what: the toughest Armor Class against the party's best attack.
    local tough_id, tough_ac = nil, -1
    for _, id in ipairs(kinds) do
        if monsters[id].ac > tough_ac then
            tough_id, tough_ac = id, monsters[id].ac
        end
    end
    local best_pc, best_hit
    for _, c in ipairs(pcs) do
        local main = c.weapons and c.weapons.main and creature.weapon_attack(c, c.weapons.main,
            { two_handed = c.class == "wizard" })
        local th = main and main.to_hit or 0
        if c.casting then
            th = math.max(th, creature.spell_attack(c))
        end
        if not best_hit or th > best_hit then
            best_pc, best_hit = c, th
        end
    end
    if tough_id and best_pc then
        local p = chance(tough_ac - best_hit)
        if p < 0.55 then
            note(monsters[tough_id].name .. " (AC " .. util.int(tough_ac) .. ") is hard to hit: even " .. best_pc.name
                .. " lands only " .. pct(p) .. " of attacks.", "danger", 3)
        else
            note(monsters[tough_id].name .. " (AC " .. util.int(tough_ac) .. "): " .. best_pc.name .. " hits it " .. pct(p)
                .. " of the time.", "info", 1)
        end
    end
    -- Big hits: one blow that can drop a hero.
    local frail
    for _, c in ipairs(pcs) do
        if not frail or c.hp_max < frail.hp_max then
            frail = c
        end
    end
    for _, id in ipairs(kinds) do
        local m = monsters[id]
        local best, best_name = 0, nil
        for _, a in ipairs(m.attacks or {}) do
            local d = avg(a.damage)
            if d > best then
                best, best_name = d, a.name
            end
        end
        local per_round = best * (m.multiattack and m.multiattack.count or 1)
        if frail and per_round >= frail.hp_max * 0.6 then
            note(m.name .. ": " .. (best_name or "its attack") .. (m.multiattack and (" x" .. util.int(m.multiattack.count)) or "")
                .. " averages " .. util.int(math.floor(per_round + 0.5)) .. " a round. " .. frail.name .. " has "
                .. util.int(frail.hp_max) .. " HP.", "danger", 3)
        end
        -- How often they land on the best-armored hero.
    end
    -- Damage weaknesses and resistances against the party's weapons and spells.
    local bludgeon, radiant, fire = {}, {}, {}
    for _, c in ipairs(pcs) do
        local w = c.weapons and c.weapons.main
        if w == "mace" or w == "quarterstaff" or w == "maul" or w == "warhammer" then
            table.insert(bludgeon, c.name)
        end
        if c.class == "cleric" then
            table.insert(radiant, c.name)
        end
        if c.class == "wizard" then
            table.insert(fire, c.name)
        end
    end
    local sleepless, packs = {}, {}
    local sleeper
    for _, c in ipairs(pcs) do
        if c.class == "wizard" and c.known_spells and c.known_spells.sleep then
            sleeper = c
        end
    end
    for _, id in ipairs(kinds) do
        local m = monsters[id]
        for _, v in ipairs(m.vulnerable or {}) do
            if v == "bludgeoning" and #bludgeon > 0 then
                note(m.name .. " is Vulnerable to bludgeoning: " .. util.join_names(bludgeon) .. " deal double damage.", "good", 2)
            end
        end
        for _, r in ipairs(m.resist or {}) do
            note(m.name .. " resists " .. r .. " damage.", "danger", 1)
        end
        local undead_fort = false
        for _, t in ipairs(m.traits or {}) do
            if t == "undead_fortitude" then
                undead_fort = true
            end
            if t == "pack_tactics" then
                table.insert(packs, m.name)
            end
        end
        if undead_fort and #radiant > 0 then
            note(m.name .. ": Undead Fortitude keeps it up, unless the hit is radiant. " .. util.join_names(radiant)
                .. "'s Sacred Flame and Guiding Bolt finish it.", "good", 2)
        end
        local ci = {}
        for _, c in ipairs(m.condition_immune or {}) do
            ci[c] = true
        end
        if ci.exhaustion then
            table.insert(sleepless, m.name)
        elseif sleeper and m.hp <= 20 then
            local save = (m.saves and m.saves.wis) or math.floor((((m.abilities and m.abilities.wis) or 10) - 10) / 2)
            local fail = 1 - chance(creature.spell_dc(sleeper) - save)
            note(sleeper.name .. "'s Sleep: a " .. m.name .. " fails the save " .. pct(fail) .. " of the time.", "good",
                fail > 0.45 and 2 or 1)
        end
    end
    if sleeper and #sleepless > 0 then
        note(util.join_names(sleepless) .. (#sleepless == 1 and " never sleeps" or " never sleep") .. ": "
            .. sleeper.name .. "'s Sleep won't touch " .. (#sleepless == 1 and "it." or "them."), "danger", 2)
    end
    if #packs > 0 then
        note(util.join_names(packs) .. ": Pack Tactics. Advantage whenever a packmate is next to their target.", "danger", 1)
    end
    -- Crowds: area spells shine, and the action economy bites.
    if #ids >= 2 * n then
        local areas = {}
        for _, c in ipairs(pcs) do
            if c.class == "wizard" then
                table.insert(areas, c.name .. "'s Burning Hands and Thunderwave")
            end
        end
        note(util.int(#ids) .. " monsters against " .. util.int(n) .. " heroes: they act more often than the party does."
            .. (#areas > 0 and (" " .. areas[1] .. " love a crowd.") or ""), "danger", 2)
    end
    -- How hard they hit the toughest-armored hero.
    local armored
    for _, c in ipairs(pcs) do
        local ac = creature.base_ac(c)
        if not armored or ac > armored.ac then
            armored = { c = c, ac = ac }
        end
    end
    if armored then
        local hitter, hit_th = nil, -9
        for _, id in ipairs(kinds) do
            for _, a in ipairs(monsters[id].attacks or {}) do
                if a.to_hit > hit_th then
                    hitter, hit_th = id, a.to_hit
                end
            end
        end
        if hitter then
            local p = chance(armored.ac - hit_th)
            note(monsters[hitter].name .. " hits " .. armored.c.name .. " (AC " .. util.int(armored.ac) .. ") " .. pct(p)
                .. " of the time.", p >= 0.5 and "danger" or "good", 1)
        end
    end
    table.sort(notes, function(a, b)
        if a.weight ~= b.weight then
            return a.weight > b.weight
        end
        return a.text < b.text
    end)
    while #notes > 6 do
        table.remove(notes)
    end
    return out
end

return M
