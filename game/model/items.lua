-- Magic items the party carries (A13). An item earned (its reward card won in a scene) goes to
-- whoever at the table wants it most and can use it, within the three-attunement limit; the
-- rules apply it from then on: in fights (game/model/fight.lua -> apply) and in the night's
-- checks (bonus and edge). Charges and once-a-day uses refill at dawn (a new night that starts
-- rested, or a Long Rest). Pure Lua. Data: game/rules/data/magic_items.lua.
--
-- campaign.items = { { id, holder = player key, week, charges, used = { pearl = true } }... }

local util = require "game.model.util"

local M = {}

local function data()
    return require "game.rules.data.magic_items"
end
M.data = data

function M.list(campaign)
    campaign.items = campaign.items or {}
    return campaign.items
end

function M.def(id)
    return data()[id]
end

function M.held_by(campaign, key)
    local out = {}
    for _, it in ipairs(M.list(campaign)) do
        if it.holder == key then
            table.insert(out, it)
        end
    end
    return out
end

local function attuned(campaign, key)
    local n = 0
    for _, it in ipairs(M.held_by(campaign, key)) do
        if M.def(it.id).attune then
            n = n + 1
        end
    end
    return n
end

-- Can this hero use it? (A shield needs a shield arm, the pearl a spellcaster, bracers a bow.)
local USES = {
    shield = { fighter = true, cleric = true },
    caster = { wizard = true, cleric = true },
    bow = { rogue = true, fighter = true },
}
function M.can_use(campaign, p, id)
    local d = M.def(id)
    if not d then
        return false
    end
    if d.needs and not (USES[d.needs] or {})[p.class] then
        return false
    end
    if d.attune and attuned(campaign, p.key) >= data().MAX_ATTUNED then
        return false
    end
    for _, it in ipairs(M.held_by(campaign, p.key)) do
        if it.id == id then
            return false                      -- one of each is plenty
        end
    end
    return true
end

-- Who takes it: the first class on its list who's at the table and can use it, else anyone who can.
function M.pick_holder(campaign, id, players)
    local d = M.def(id)
    players = players or campaign.players
    for _, cls in ipairs(d["for"] or {}) do
        for _, p in ipairs(players) do
            if p.class == cls and M.can_use(campaign, p, id) then
                return p
            end
        end
    end
    for _, p in ipairs(players) do
        if M.can_use(campaign, p, id) then
            return p
        end
    end
    return nil
end

-- The party earns an item. Returns the entry and who carries it.
function M.earn(campaign, id, players)
    local d = M.def(id)
    if not d then
        return nil
    end
    local p = M.pick_holder(campaign, id, players)
    local it = { id = id, holder = p and p.key or nil, week = campaign.week }
    if d.effect.charges then
        it.charges = d.effect.charges.n
    end
    table.insert(M.list(campaign), it)
    return it, p
end

-- Dawn: charges and once-a-day uses come back.
function M.dawn(campaign, rng)
    for _, it in ipairs(M.list(campaign)) do
        local d = M.def(it.id)
        local ch = d and d.effect.charges
        if ch and not it.destroyed then
            local r = ch.regain
            local n = r[3]
            for _ = 1, r[1] do
                n = n + (rng and rng:int(1, r[2]) or math.ceil(r[2] / 2))
            end
            it.charges = math.min(ch.n, (it.charges or 0) + n)
        end
        it.used = nil
    end
end

-- In a fight: put the hero's items on their sheet. pc: a creature from game/rules/party.lua.
function M.apply(campaign, key, pc)
    pc.items = {}
    for _, it in ipairs(M.held_by(campaign, key)) do
        local d = M.def(it.id)
        if d and not it.destroyed then
            local e = d.effect
            table.insert(pc.items, it)
            if e.weapon then
                pc.magic_weapon = math.max(pc.magic_weapon or 0, e.weapon)
                pc.item_weapon = e.weapon
            end
            if e.ac then
                pc.item_ac = (pc.item_ac or 0) + e.ac
            end
            if e.saves then
                pc.item_saves = (pc.item_saves or 0) + e.saves
            end
            if e.checks then
                pc.item_checks = (pc.item_checks or 0) + e.checks
            end
            if e.init then
                pc.item_init_adv = true
            end
            if e.bow_damage then
                pc.item_bow_damage = (pc.item_bow_damage or 0) + e.bow_damage
            end
            if e.charges then
                pc.res.wand = it.charges or 0
                pc.wand_item = it
            end
            if e.slot and not (it.used and it.used.slot) then
                pc.pearl = e.slot
                pc.pearl_item = it
            end
            if e.wound then
                pc.wound_closure = true
            end
        end
    end
end

-- After a fight: what the sheet spent comes back to the item (wand charges).
function M.settle(pc)
    if pc.wand_item then
        pc.wand_item.charges = pc.res.wand or 0
        if (pc.res.wand or 0) <= 0 and pc.wand_crumbled then
            pc.wand_item.destroyed = true
        end
    end
end

-- On game night, outside a fight: an item's bonus to a check, and Advantage it gives.
-- where: the scene's location card (for climbing or swimming).
local CLIMB_SWIM = { water = true, high = true, bridge = true, ship = true, island = true }
function M.check_bonus(campaign, key, skill, where)
    local n = 0
    for _, it in ipairs(M.held_by(campaign, key)) do
        local e = M.def(it.id).effect
        n = n + (e.checks or 0)
        if e.climb_swim and skill == "athletics" and where then
            for _, s in ipairs(where.setting or {}) do
                if CLIMB_SWIM[s] then
                    n = n + e.climb_swim
                    break
                end
            end
        end
    end
    return n
end

function M.check_edge(campaign, key, skill)
    for _, it in ipairs(M.held_by(campaign, key)) do
        local e = M.def(it.id).effect
        if e.adv and util.contains(e.adv, skill) then
            return "adv", M.def(it.id).name
        end
    end
    return nil
end

return M
