-- The adventure's people, as the DM sees them (the playtest, November 3: "NPCs should be
-- clickable, and bring up a character sheet"): who they are, where, how they stand with the party
-- now, their numbers when they fight, and what the DM has put in their pockets. A drop is the
-- DM's: an item from the rules' list, and how the party can get it (beat them, pick their
-- pocket, ask for it). Game night plays the drops (museum_night.drops): beaten, it falls out
-- after the fight; a pocket or an ask is the players' idea, and the DM rules on whether it works.
-- Pure Lua.
--
-- campaign.adv.drops = { [npc id] = { { item = magic item id, how = "beaten" | "pocket" | "ask", got = week } } }

-- (5e's engine only through the adventure's rule set: docs/design/rule-sets.md, no leaks.)
local ruleset = require "game.model.ruleset"
local util = require "game.model.util"

local M = {}

M.HOWS = {
    beaten = { label = "If they're beaten", short = "beaten", tip = "It falls out of whatever's left of them after the fight." },
    pocket = { label = "If someone picks their pocket", short = "pickpocket",
               tip = "Whoever's light-fingered can try: a Sleight of Hand roll, and they might notice." },
    ask = { label = "If someone asks for it", short = "asked for",
            tip = "Someone at the table can ask them for it. You decide what they say." },
}
M.HOW_ORDER = { "beaten", "pocket", "ask" }

local function module()
    local ok, adv = pcall(require, "game.model.adventure")
    return ok and adv.data or nil
end

-- Every person with a sheet: MODULE.npc_sheet, with names, roles and words from MODULE.people
-- and MODULE.sides.
function M.all()
    local MOD = module()
    if not (MOD and MOD.npc_sheet) then
        return {}
    end
    local by = {}
    for _, p in ipairs(MOD.people or {}) do
        by[p.id] = { name = p.name, role = p.role, about = p.about }
    end
    for _, s in ipairs(MOD.sides or {}) do
        for _, m in ipairs(s.members or {}) do
            local e = by[m.id] or {}
            by[m.id] = e
            e.short = e.short or m.name
            e.name = e.name or m.name
            e.role = e.role or m.role
            e.states = m.states
            e.side = s.name
            e.room = m.room
        end
    end
    local out = {}
    for _, id in ipairs(MOD.npc_sheet.order or {}) do
        local sh = MOD.npc_sheet[id]
        local e = by[id] or {}
        table.insert(out, { id = id, name = e.name or id, short = sh.short or e.short or e.name, role = e.role, about = sh.about or e.about,
                            states = e.states, side = e.side, room = sh.room or e.room, monster = sh.monster, sprite = sh.sprite,
                            hows = sh.hows or { "beaten" }, match = sh.match, not_before = sh.not_before })
    end
    return out
end

function M.get(id)
    for _, n in ipairs(M.all()) do
        if n.id == id then
            return n
        end
    end
end

-- How they stand now (standing.lua's line for them: what the party did, or "Still ahead"):
-- { text, tone }, or nil for someone with no line.
function M.state(campaign, n)
    if not (n.states or n.room) then
        return nil
    end
    local standing = require "game.model.standing"
    local text, tone = standing.member_line(campaign, { states = n.states, room = n.room })
    return { text = text, tone = tone }
end

-- Their numbers when they fight (the rules' stat block), or nil.
function M.stats(n)
    if not n.monster then
        return nil
    end
    local ok, mons = pcall(ruleset.engine, "data.monsters")
    local m = ok and mons[n.monster]
    if not m then
        return nil
    end
    local hp = m.hp or m.hp_max or (m.hit_points)
    return { hp = type(hp) == "table" and (hp.avg or hp[1]) or hp, ac = m.ac, cr = m.cr, size = m.size, type = m.type }
end

function M.drops(campaign, id)
    campaign.adv = campaign.adv or {}
    campaign.adv.drops = campaign.adv.drops or {}
    local list = campaign.adv.drops[id] or {}
    campaign.adv.drops[id] = list
    return list
end

-- What the DM can put in someone's pockets: what's in the DM's bag now (game/model/dm_bag.lua: Conner, November 6,
-- "add items to NPCs during session planning"), least to most powerful. Without a campaign, the rules' magic items.
function M.item_choices(campaign)
    local out = {}
    if campaign then
        for _, e in ipairs(require("game.model.dm_bag").stock(campaign)) do
            table.insert(out, e.id)
        end
        return out
    end
    local mi = ruleset.part("data.magic_items")
    for _, id in ipairs(mi.order or {}) do
        if mi[id] then
            table.insert(out, id)
        end
    end
    return out
end

-- What a pocketed thing is: a thing from the DM's bag, or one of the rules' magic items (an older save's).
-- { name, text, rarity, magic = rules id or nil, entry = bag entry or nil }
function M.drop_def(item)
    local e = require("game.data.dm_bag").by_id[item]
    if e then
        return { name = util.capitalize(e.name), text = e.text, rarity = e.rarity, magic = e.magic, entry = e }
    end
    local d = require("game.model.items").def(item)
    return d and { name = d.name, text = d.text, rarity = d.rarity, magic = item } or nil
end

-- Add one (the NPC's first way of getting it), change how, or take it back off them.
function M.add_drop(campaign, id, item)
    local n = M.get(id)
    if not n then
        return nil
    end
    local list = M.drops(campaign, id)
    for _, d in ipairs(list) do
        if d.item == item and not d.got then
            return d
        end
    end
    -- (From the bag: it comes out of it, and goes back if you take it off them again.)
    local e = require("game.data.dm_bag").by_id[item]
    if e and not require("game.model.dm_bag").take(campaign, e) then
        return nil
    end
    local d = { item = item, how = n.hows[1], bag = e and true or nil }
    table.insert(list, d)
    return d
end

function M.cycle_how(campaign, id, i)
    local n = M.get(id)
    local d = M.drops(campaign, id)[i]
    if not (n and d) or d.got then
        return
    end
    local at = 1
    for k, h in ipairs(n.hows) do
        if h == d.how then
            at = k
        end
    end
    d.how = n.hows[at % #n.hows + 1]
end

function M.remove_drop(campaign, id, i)
    local list = M.drops(campaign, id)
    if list[i] and not list[i].got then
        local d = table.remove(list, i)
        if d.bag then
            require("game.model.dm_bag").put_back(campaign, require("game.data.dm_bag").by_id[d.item])
        end
    end
end

-- The drops still to be had this way, in this room.
function M.waiting(campaign, room, how)
    local out = {}
    for _, n in ipairs(M.all()) do
        if n.room == room then
            for i, d in ipairs(M.drops(campaign, n.id)) do
                if d.how == how and not d.got then
                    table.insert(out, { npc = n, drop = d, i = i })
                end
            end
        end
    end
    return out
end

-- The glossary's words for them (game/ui/gloss.lua): their names, underlined wherever they're
-- written, a hover card, and a click for the sheet.
function M.terms()
    local out = {}
    for _, n in ipairs(M.all()) do
        local pats = {}
        for _, w in ipairs(n.match or { n.short or n.name }) do
            -- (Whole words only: "Telpur" in "Telpur's".)
            local esc = string.gsub(w, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
            table.insert(pats, "%f[%w]" .. esc .. "%f[^%w]")
        end
        table.insert(out, { id = "npc:" .. n.id, plain = n.name, npc = n.id, match = pats, not_before = n.not_before,
                            text = util.capitalize(n.role or "") .. ". " .. (n.about or "") .. " Click for their sheet." })
    end
    return out
end

return M
