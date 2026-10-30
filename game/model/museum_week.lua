-- The week in the museum (v2): starting a week, the prep board's hours and choices, and what the
-- adventure keeps after a night. The prologue is strictly the module, so the old weekly machinery
-- (the story deck, factions, seeds, the valley) stays switched off while it runs. Engine-free.

local content = require "game.model.content"
local util = require "game.model.util"
local score = require "game.model.score"
local adventure = require "game.model.adventure"
local prep_mod = require "game.model.prep"
local bars = require "game.model.bars"
local social = require "game.model.social"
local progression = require "game.model.progression"

local MODULE = adventure.data
local M = {}

-- Prep -----------------------------------------------------------------------------------------

-- The museum's part of the prep board: which rooms are prepped, the knobs, the boss night's plan.
function M.new_prep(prep, campaign)
    prep.budget = MODULE.BUDGET
    prep.museum = { prepped = {}, knobs = {}, ahead = adventure.ahead(campaign), boss = adventure.boss_week(campaign) }
    -- The scenes the night expects, for its pacing read: tonight's rooms in order.
    prep.scenes = {}
    for _, id in ipairs(prep.museum.ahead) do
        local r = MODULE.rooms[id]
        if not r.virtual then
            local slots = {}
            for kind, cid in pairs(r.comps or {}) do
                slots[kind] = content.components[cid]
            end
            table.insert(prep.scenes, { type = r.type, slots = slots, room = id })
        end
    end
    if prep.museum.boss then
        campaign.adv.boss = campaign.adv.boss or { opener = "talk", style = "yields" }
    end
    return prep
end

function M.room_cost(id)
    local r = MODULE.rooms[id]
    return r and r.cost or 0
end

function M.knob_cost(id, value)
    local k = MODULE.knobs[id]
    return (k and value and k.cost) or 0
end

-- Hours on the museum board: rooms prepped and knobs that need writing.
function M.spent(prep)
    local pm = prep.museum
    local total = 0
    for id, on in pairs(pm.prepped) do
        if on then
            total = total + M.room_cost(id)
        end
    end
    for id, v in pairs(pm.knobs) do
        if v then
            total = total + M.knob_cost(id, v)
        end
    end
    if pm.boss then
        total = total + M.room_cost("lair")
    end
    return total
end

function M.can_prep(prep, id)
    local pm = prep.museum
    if pm.prepped[id] then
        return true
    end
    return prep:left() >= M.room_cost(id)
end

function M.set_prepped(prep, id, on)
    local pm = prep.museum
    if on and not M.can_prep(prep, id) then
        return false
    end
    pm.prepped[id] = on and true or nil
    return true
end

function M.set_knob(prep, id, value)
    local pm = prep.museum
    local cur = pm.knobs[id]
    local extra = M.knob_cost(id, value) - M.knob_cost(id, cur)
    if extra > 0 and prep:left() < extra then
        return false
    end
    pm.knobs[id] = value or nil
    return true
end

-- How each friend would take a choice: like values for the knob as it stands (-2..2).
function M.knob_like(id, value)
    local k = MODULE.knobs[id]
    if not k then
        return {}
    end
    if k.pick_hero then
        return value and { [value] = 2 } or {}
    end
    return k.like
end

-- Prep everything that fits, in order: what a quick DM does (and the tests' bots).
function M.prep_greedy(prep)
    for _, id in ipairs(prep.museum.ahead) do
        if M.can_prep(prep, id) and M.room_cost(id) > 0 then
            M.set_prepped(prep, id, true)
        end
    end
end

-- The week -------------------------------------------------------------------------------------

function M.start_week(c)
    c.week = c.week + 1
    local rng = c.rng
    c.empathy_up = nil
    c.looked = nil
    for _, p in ipairs(c.players) do
        p.mood = rng:pick(content.moods.order)
        p.mood_known = false
        -- The prologue is short and everyone's keen: the whole table comes every week.
        p.on_break = false
        p.present = true
    end
    c.new_chars = require("game.model.death").start_week(c)
    c.prep = prep_mod.new(c)
    M.new_prep(c.prep, c)
    c.leveled_now = nil
    social.start_week(c)
    progression.start_week(c)
    c.chat = M.write_chat(c)
    c.night = nil
    c.report = nil
    c.adv.prompts = adventure.prompts(c)
    return c.prep
end

-- The group chat: what the friends say about last week's rooms, and the requests waiting.
function M.write_chat(c)
    local st = c.adv
    local msgs = {}
    local last = {}
    for _, step in ipairs(st.path) do
        if step.week == c.week - 1 then
            table.insert(last, step.room)
        end
    end
    local said = {}
    for _, room in ipairs(last) do
        for key, text in util.sorted_pairs(MODULE.chat[room] or {}) do
            local p = c:player(key)
            if p and not said[key] and #msgs < 4 then
                said[key] = true
                table.insert(msgs, { who = p.name, key = key, text = text })
            end
        end
    end
    if c.week == 1 then
        local intro = {
            { "jess", "ok there's a MUSEUM in town and the guy running it is a gnome" },
            { "mara", "a travelling museum of curiosities. i've already started a notebook" },
            { "dev", "are there monsters in it" },
            { "sam", "i'll bring snacks. museum snacks" },
        }
        for _, l in ipairs(intro) do
            local p = c:player(l[1])
            if p then
                table.insert(msgs, { who = p.name, key = l[1], text = l[2] })
            end
        end
    end
    for _, pr in ipairs(st.prompts or adventure.prompts(c)) do
        if pr.kind == "request" then
            local p = c:player(pr.def.who)
            if p then
                table.insert(msgs, { who = p.name, key = p.key, text = pr.def.ask, request = pr.id })
            end
        end
    end
    return msgs
end

-- After the night: what the adventure keeps, and the report's museum section.
function M.after_night(c, night, rep)
    local st = c.adv
    local mus = night.mus or {}
    rep.museum = {
        rooms = mus.rooms or {},
        marks = mus.added or {},
        bank = st.bank, harsh = mus.harsh_log or {},
        where = adventure.where(c),
        ending = st.ending,
        francs = st.francs,
    }
    if night.ended_on_cliff then
        rep.museum.stopped = c.last_cliff
    end
end

-- Level-ups come at the book's milestones: the gift shop (level 3), and the end (level 4).
function M.level_ready(c)
    local st = c.adv
    if not st then
        return nil
    end
    if c.level == 2 and st.done.gift_shop then
        return true
    end
    if c.level == 3 and st.ending then
        return true
    end
    return false
end

-- Is the prologue over (the scrapbook comes next)?
function M.done(c)
    local st = c.adv
    return st and (st.ending ~= nil or c.week >= MODULE.MAX_WEEKS)
end

return M
