-- What each hero carries (A13; the second playtest review, F10: "player characters should have a
-- real inventory, and acquiring items should be a real transaction"). One list owns it all,
-- campaign.items: the rules' magic items (the twin daggers, the vorpal sword, anything off someone
-- the DM put it on), the adventure's own things (MODULE.items with `carry`: a book bought in the gift
-- shop, a cupboard door prised off a diorama, a shoelace given between sessions) and each hero's
-- healing potions. Every entry has one holder. Bought is bought: the Francs leave the pool, the
-- thing leaves the shelf and goes to the hero who wanted it. Used up (a potion drunk, the fire arrows
-- loosed, a page read) is gone: the entry stays, marked `gone`, so the report can say so. Every line
-- that says someone has or uses something reads it from here.
--
-- A magic item goes to whoever at the table wants it most and can use it, within the
-- three-attunement limit; the rules apply it from then on: in fights (game/model/fight.lua ->
-- apply) and in the night's checks (bonus and edge). Charges and once-a-day uses refill at dawn (a
-- new night that starts rested, or a Long Rest). Pure Lua. Data: game/rules/data/magic_items.lua,
-- and the adventure's MODULE.items.
--
-- campaign.items = { { id, holder = player key, week, from = "found" | "bought" | "given" | "drop"
--                      | "start", thing = MODULE.items id, count, charges, used = { pearl = true },
--                      gone = week, destroyed, introduced = week }... }

local util = require "game.model.util"
local events = require "game.model.events"

local M = {}

-- Every thing that changes hands is an event in the log (R7: game/model/events.lua): what, who has it
-- now, how they got it (found, bought, given, stolen, off someone beaten), from whom, and the moment it
-- followed from. The inventory owns what each hero carries; the log owns how it got there.
local starting = false
local GOT = { found = "came away with", bought = "bought", given = "was given", stolen = "lifted", drop = "came away with" }
M.GOT = GOT                 -- (for the Dialogue Desk: the log's words for a thing changing hands)
local function log_get(campaign, it, whom, how_got)
    if starting or how_got == "start" or not campaign then
        return
    end
    local p = it.holder and campaign.player and campaign:player(it.holder)
    local about = M.about(it)
    local t = it.thing and M.thing(it.thing)
    local name = (t and util.lower_first(t.name or t.title)) or (about.magic and ("the " .. string.lower(about.name or "thing")))
        or util.lower_first(about.name or "something")
    local cause = events.cause(campaign)
    -- (A beat of its own only when nothing else tells it: a moment's choice already says what they
    -- took, and a theft is told by the theft.)
    local by_moment = cause and (events.get(campaign, cause) or {}).handing
    local text
    if p then
        if how_got == "stolen" and whom then
            local who = whom.short or whom.name or "someone"
            text = p.char .. " lifted " .. name .. " off " .. who
        else
            text = p.char .. " " .. (GOT[how_got] or "came away with") .. " " .. name
        end
    end
    events.add(campaign, { kind = "get", who = it.holder, whom = whom and whom.id or nil, thing = it.thing or it.id, how_got = how_got,
                           entry = it, from = cause, beat = (p and how_got ~= "bought" and how_got ~= "stolen" and not by_moment and campaign.night ~= nil) or nil,
                           text = text })
end
M.log_get = log_get

local function data()
    return require "game.rules.data.magic_items"
end
M.data = data

-- The adventure's own things (MODULE.items with `carry`), by id; the shared ones (a healing potion).
M.POTION = "potion_healing"
local SHARED = {
    potion_healing = { id = "potion_healing", name = "Potion of Healing", carry = true, stack = true,
                       text = "Drink it as a Bonus Action in a fight: 2d4 + 2 Hit Points back. One use." },
}
local function module_items()
    local ok, adv = pcall(require, "game.model.adventure")
    return ok and adv.data and adv.data.items or {}
end
function M.thing(id)
    if SHARED[id] then
        return SHARED[id]
    end
    for _, it in ipairs(module_items()) do
        if it.id == id and it.carry then
            return it
        end
    end
    return nil
end

-- The carried thing a `mus` (a flag set, a mark added) hands over, if any.
function M.thing_for(mus)
    if type(mus) ~= "table" then
        return nil
    end
    for _, it in ipairs(module_items()) do
        local w = it.carry and it.when
        if w and ((mus.flag and w.flag == mus.flag) or (mus.mark and w.mark == mus.mark)) then
            return it
        end
    end
    return nil
end

function M.list(campaign)
    campaign.items = campaign.items or {}
    return campaign.items
end

-- A magic item's rules (its `effect`), or nil for a thing that isn't magic.
function M.def(id)
    return data()[id]
end

-- What an entry is, for the sheet and the report: { name, text } either way.
function M.about(it)
    local d = M.def(it.id)
    if d then
        return { name = d.name, text = d.text or "", magic = true, page = d.page }
    end
    local t = M.thing(it.thing or it.id)
    if t then
        return { name = util.capitalize(t.title or t.name or it.id), text = t.text or "" }
    end
    return { name = util.capitalize(it.id or "something"), text = "" }
end

-- What a hero carries now (not used up, not gone).
function M.held_by(campaign, key)
    local out = {}
    for _, it in ipairs(M.list(campaign)) do
        if it.holder == key and not it.gone and not it.destroyed then
            table.insert(out, it)
        end
    end
    return out
end

-- Who carries this thing (a MODULE.items id or a magic item id): the entry and the holder's key.
-- present: only someone at the table tonight (players with `present`).
function M.holding(campaign, id, present)
    for _, it in ipairs(M.list(campaign)) do
        if (it.thing == id or it.id == id) and not it.gone and not it.destroyed and it.holder then
            local p = campaign.player and campaign:player(it.holder)
            if not present or (p and p.present) then
                return it, it.holder
            end
        end
    end
    return nil
end

function M.owned(campaign, id)
    return M.holding(campaign, id) ~= nil
end

-- How many of a stack a hero has (healing potions).
function M.count(campaign, key, id)
    local n = 0
    for _, it in ipairs(M.held_by(campaign, key)) do
        if it.id == id or it.thing == id then
            n = n + (it.count or 1)
        end
    end
    return n
end

-- A thing changes hands: into a hero's inventory. A non-stacking thing they already have isn't
-- given twice. holder: a player key (nil: the thing's own `to`, else the first friend at the table).
-- whom: who it came from, for the log (one of the museum's people, as npcs.lua has them: { id, name }).
function M.give(campaign, id, holder, from, whom)
    local t = M.thing(id)
    if not t then
        return nil
    end
    if not t.stack and M.owned(campaign, id) then
        return (M.holding(campaign, id))
    end
    -- (Someone's gift goes to the hero they're fondest of, from the log: Flitwidget's bracelet.)
    if not holder and t.from_fondest and campaign.players then
        local people = require "game.model.people"
        local best, bs
        for _, p in ipairs(campaign.players) do
            local sc = people.opinion(campaign, t.from_fondest, p.key)
            if p.present ~= false and (not bs or (sc or 0) > bs) then
                best, bs = p, sc or 0
            end
        end
        holder = best and best.key
    end
    if not holder then
        local pick = t.to and campaign.player and campaign:player(t.to)
        if not (pick and pick.present ~= false) then
            pick = nil
            for _, p in ipairs(campaign.players or {}) do
                if not pick and p.present then
                    pick = p
                end
            end
            pick = pick or (campaign.players or {})[1]
        end
        holder = pick and pick.key
    end
    local it = { id = id, thing = id, holder = holder, week = campaign.week, from = from or "found", count = t.count }
    if t.stack then
        it.count = 1
    end
    table.insert(M.list(campaign), it)
    log_get(campaign, it, whom, it.from)
    return it
end

-- Used up: one off a stack, or the whole thing. Returns the entry used, or nil.
function M.use(campaign, id, holder)
    for _, it in ipairs(M.list(campaign)) do
        if (it.thing == id or it.id == id) and not it.gone and not it.destroyed and (not holder or it.holder == holder) then
            it.count = it.count and (it.count - 1) or nil
            if not it.count or it.count <= 0 then
                it.gone = campaign.week or 0
            end
            if not starting then
                events.add(campaign, { kind = "use", who = it.holder, thing = it.thing or it.id, entry = it, gone = it.gone ~= nil or nil,
                                       from = events.cause(campaign) })
            end
            return it
        end
    end
    return nil
end

-- Every hero starts with what their sheet gives them (a healing potion), once a campaign; and a save
-- from before the inventory gets what it held then (adventure.lua's flags and marks, who picked
-- each thing up, the potions still in their packs): save.load calls this.
function M.start(campaign)
    if campaign.items_started then
        return
    end
    campaign.items_started = true
    starting = true             -- (what a hero starts with, or an old save held, isn't news: not logged as found)
    local ok, err = pcall(M.start_body, campaign)
    starting = false
    if not ok then
        error(err, 0)
    end
end

function M.start_body(campaign)
    local party = require "game.rules.party"
    local ps = campaign.party_state
    for _, p in ipairs(campaign.players or {}) do
        local raw = p.class and party.sheet(p.class, campaign.level or 2)
        local n = raw and raw.potions or 0
        local carried = ps and not ps.rested and ps.pcs and ps.pcs[p.key] and ps.pcs[p.key].res
        if carried and carried.potions then
            n = carried.potions
        end
        for _ = 1, n do
            local it = M.give(campaign, M.POTION, p.key, "start")
            if it then
                it.week = 0
            end
        end
    end
    local st = campaign.adv
    if not st then
        return
    end
    -- (What the adventure says they picked up before there was an inventory: its holder, if the
    -- old save knew one, and anything used up stays used up.)
    local holders = st.holders or {}
    for _, t in ipairs(module_items()) do
        local w = t.carry and t.when
        local got = w and ((w.flag and st.flags and st.flags[w.flag]) or (w.mark and st.marks and st.marks[w.mark]))
        if got and not t.magic and not M.owned(campaign, t.id) then
            local it = M.give(campaign, t.id, holders[w.flag or w.mark], "found")
            if it and t.once and st.items_used and st.items_used[t.id] then
                it.gone = st.items_used[t.id]
            end
        end
    end
    for _, it in ipairs(M.list(campaign)) do
        if not it.thing then
            for _, t in ipairs(module_items()) do
                if t.magic == it.id then
                    it.thing = t.id
                end
            end
        end
    end
    -- (Something taken off one of the museum's people points at its entry, not a copy of who has it.)
    for _, list in pairs(st.drops or {}) do
        for _, d in ipairs(list) do
            if d.got and not d.entry then
                for _, it in ipairs(M.list(campaign)) do
                    if it.id == d.item and (not d.holder or it.holder == d.holder) and not d.entry then
                        d.entry = it
                    end
                end
                d.holder = nil
            end
        end
    end
    st.charmed_hero = st.charmed_hero or holders.charmed
    st.holders = nil
end

local function attuned(campaign, key)
    local n = 0
    for _, it in ipairs(M.held_by(campaign, key)) do
        if M.def(it.id) and M.def(it.id).attune then
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

-- The party earns an item. Returns the entry and who carries it. how_got, whom: for the log (found,
-- or off someone beaten: "drop"; stolen, and who from).
function M.earn(campaign, id, players, how_got, whom)
    local d = M.def(id)
    if not d then
        return nil
    end
    local p = M.pick_holder(campaign, id, players)
    local it = { id = id, holder = p and p.key or nil, week = campaign.week, from = "found" }
    for _, t in ipairs(module_items()) do
        if t.magic == id then
            it.thing = t.id           -- (the adventure's name for it: the twin daggers)
        end
    end
    if d.effect.charges then
        it.charges = d.effect.charges.n
    end
    it.from = how_got or it.from
    table.insert(M.list(campaign), it)
    log_get(campaign, it, whom, it.from)
    return it, p
end

-- Dawn: charges and once-a-day uses come back.
function M.dawn(campaign, rng)
    for _, it in ipairs(M.list(campaign)) do
        local d = M.def(it.id)
        local ch = d and d.effect.charges
        if ch and not it.destroyed and not it.gone then
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
-- Their healing potions are the ones in their pack (drunk is drunk: no fresh one at the next level).
function M.apply(campaign, key, pc)
    M.start(campaign)
    pc.items = {}
    if pc.res then
        pc.res.potions = M.count(campaign, key, M.POTION)
        pc.potions_had = pc.res.potions
        pc.inv_key = key
    end
    for _, it in ipairs(M.held_by(campaign, key)) do
        local d = M.def(it.id)
        if d and not it.destroyed then
            local e = d.effect
            table.insert(pc.items, it)
            if e.weapon then
                pc.magic_weapon = math.max(pc.magic_weapon or 0, e.weapon)
                pc.item_weapon = e.weapon
                pc.weapon_item = string.lower(d.name)      -- (what the table calls their weapon now)
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

-- After a fight: what the sheet spent comes back to the item (wand charges), and a potion drunk
-- leaves the pack.
function M.settle(pc, camp)
    if camp and pc.inv_key and pc.res and pc.potions_had and (pc.res.potions or 0) < pc.potions_had then
        for _ = 1, pc.potions_had - (pc.res.potions or 0) do
            M.use(camp, M.POTION, pc.inv_key)
        end
        pc.potions_had = pc.res.potions or 0
    end
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
        local d = M.def(it.id)
        local e = d and d.effect or {}
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

-- topic: what the check is about ("gorgons"), for a thing that helps with one subject (the book).
function M.check_edge(campaign, key, skill, topic)
    for _, it in ipairs(M.held_by(campaign, key)) do
        local d = M.def(it.id)
        local e = d and d.effect
        if e and e.adv and util.contains(e.adv, skill) then
            return "adv", d.name
        end
        local t = not d and M.thing(it.thing or it.id)
        if t and t.adv and util.contains(t.adv, skill) and topic and t.topic == topic then
            return "adv", util.lower_first(t.title or t.name)
        end
    end
    return nil
end

return M
