-- rules: 5e   (5e's own, reached through the rule set: docs/design/rule-sets.md)
-- What a player's tile at the bottom of game night shows about their hero (the playtest, November 3:
-- "add key character references per class: AC, current/max health, spell slots, Channel Divinity,
-- Second Wind, Action Surge; only what's relevant for the class; always health and AC").
-- Read from the night's own sheets when there are any (live in a fight), else from where the party
-- left off (campaign.party_state), else the fresh sheet. Engine-free, and never touches the dice.

-- (5e's engine only through the adventure's rule set: docs/design/rule-sets.md, no leaks.)
local ruleset = require "game.model.ruleset"
local creature = ruleset.part("creature")
local party = ruleset.part("party")

local M = {}

-- What each resource is, for the tile's hover.
M.TIPS = {
    slots = "Spell slots: the spells of 1st level and up they can still cast before a rest. Cantrips are free.",
    channel = "Channel Divinity: a cleric's burst of their god's power (turning undead, healing). Back on a rest.",
    second_wind = "Second Wind: the fighter heals themselves as a Bonus Action. Back on a rest.",
    action_surge = "Action Surge: one extra action on their turn. Back on a rest.",
}

-- A fresh sheet for the hero, cached by class, level and subclass (it's the same every time).
local fresh_cache = {}
local function fresh(campaign, p)
    local level = campaign.level or 2
    local sub = level >= 3 and campaign.subclasses and campaign.subclasses[p.class] or nil
    local k = p.class .. ":" .. level .. ":" .. tostring(sub) .. ":" .. tostring(p.key)
    local c = fresh_cache[k]
    if not c then
        c = creature.new_pc(party.sheet(p.class, level, sub))
        require("game.model.items").apply(campaign, p.key, c)
        fresh_cache[k] = c
    end
    return c, level
end

local function copy_res(res)
    local o = {}
    for k, v in pairs(res or {}) do
        if type(v) == "table" then
            local t = {}
            for i, n in pairs(v) do
                t[i] = n
            end
            o[k] = t
        else
            o[k] = v
        end
    end
    return o
end

-- { hp, hp_max, ac, class, res = { { id, label, cur, max } or { id = "slots", levels = { { cur, max }... } } } }
function M.of(campaign, night, key)
    local p = campaign:player(key)
    if not p then
        return nil
    end
    local live = night and night.pcs and night.pcs[key]
    local base, level = fresh(campaign, p)
    local c = live or base
    local hp, hp_max, res = c.hp, c.hp_max, c.res
    if not live then
        local ps = campaign.party_state
        local s = ps and not ps.rested and ps.level == level and ps.pcs and ps.pcs[key]
        if s then
            hp_max = s.hp_max or hp_max
            hp = math.min(hp_max, math.max(0, s.hp or hp))
            res = copy_res(s.res)
        end
    end
    local ac
    if live then
        ac = creature.base_ac(c) + (c.item_ac or 0)
    else
        -- (Thessaly puts Mage Armor on before every adventuring day: the sheet's own number.)
        ac = (p.class == "wizard" and (13 + creature.abmod(base, "dex")) or creature.base_ac(base)) + (base.item_ac or 0)
    end
    local out = { hp = hp, hp_max = hp_max, ac = ac, class = p.class, res = {} }
    res = res or {}
    if p.class == "fighter" then
        table.insert(out.res, { id = "second_wind", label = "Second Wind", cur = res.second_wind or 0,
                                max = res.second_wind_max or base.res.second_wind_max or 1 })
        if (base.res.action_surge or 0) > 0 then
            table.insert(out.res, { id = "action_surge", label = "Action Surge", cur = res.action_surge or 0, max = 1 })
        end
    end
    if base.slots_max and #base.slots_max > 0 then
        local levels = {}
        for i, n in ipairs(base.slots_max) do
            table.insert(levels, { cur = math.min(n, (res.slots and res.slots[i]) or n), max = n })
        end
        table.insert(out.res, { id = "slots", label = "Slots", levels = levels })
    end
    if p.class == "cleric" and (base.res.channel_max or 0) > 0 then
        table.insert(out.res, { id = "channel", label = "Channel", cur = res.channel or 0, max = base.res.channel_max })
    end
    return out
end

return M
