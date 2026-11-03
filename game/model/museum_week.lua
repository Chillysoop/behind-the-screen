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
local ties = require "game.model.ties"

local MODULE = adventure.data
local M = {}

-- Prep -----------------------------------------------------------------------------------------

-- The museum's part of the prep board: which rooms are prepped, the knobs, the boss night's plan.
function M.new_prep(prep, campaign)
    prep.budget = MODULE.BUDGET
    prep.museum = { prepped = {}, knobs = {}, ahead = adventure.ahead(campaign), boss = adventure.boss_week(campaign) }
    -- Boss week: what the rooms they never played leave on her card is there now, so the showdown
    -- board you prep against is the fight they get (the playtest, Nov 2: a knight joined her
    -- after the board said he wouldn't). Her line for each comes at the night's start.
    if prep.museum.boss then
        for _, lb in ipairs(adventure.left_behind(campaign, true)) do
            if adventure.add_mark(campaign, lb.mark, lb.room) then
                local st = campaign.adv
                st.unannounced = st.unannounced or {}
                table.insert(st.unannounced, lb.mark)
            end
        end
    end
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

-- The DM bent the map in prep (game/ui/ties_view.lua: a lock set, removed or opened): tonight's
-- rooms again. Rooms and knobs no longer on the way give their hours back.
function M.reahead(prep, campaign)
    local pm = prep.museum
    if not pm then
        return
    end
    pm.ahead = adventure.ahead(campaign)
    pm.boss = adventure.boss_week(campaign)
    for id in pairs(pm.prepped) do
        if not util.contains(pm.ahead, id) then
            pm.prepped[id] = nil
        end
    end
    for kid in pairs(pm.knobs) do
        local k = MODULE.knobs[kid]
        if k and not util.contains(pm.ahead, k.room) then
            pm.knobs[kid] = nil
        end
    end
    prep.scenes = {}
    for _, id in ipairs(pm.ahead) do
        local r = MODULE.rooms[id]
        if not r.virtual then
            local slots = {}
            for kind, cid in pairs(r.comps or {}) do
                slots[kind] = content.components[cid]
            end
            table.insert(prep.scenes, { type = r.type, slots = slots, room = id })
        end
    end
    if pm.boss then
        campaign.adv.boss = campaign.adv.boss or { opener = "talk", style = "yields" }
    end
end

-- Between sessions, what came true opens the DM's locks (ties.lua): tonight's rooms again if so.
-- Called by the prep board once the questions between sessions are answered.
function M.sync_ties(prep, campaign)
    if not ties.any(campaign) then
        return false
    end
    local st = campaign.adv
    local before = #(st.lock_news or {})
    ties.week(campaign)
    local ahead = adventure.ahead(campaign)
    local same = #ahead == #(prep.museum.ahead or {})
    for i, id in ipairs(ahead) do
        same = same and prep.museum.ahead[i] == id
    end
    if not same or #(st.lock_news or {}) ~= before then
        M.reahead(prep, campaign)
        return true
    end
    return false
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
    -- The DM's locks: anything that came true by now opens before the board is dealt (ties.lua).
    ties.week(c)
    c.prep = prep_mod.new(c)
    M.new_prep(c.prep, c)
    c.leveled_now = nil
    social.start_week(c)
    progression.start_week(c)
    -- (The questions first: the chat posts this week's requests, not last week's answered ones.)
    c.adv.prompts = adventure.prompts(c)
    c.chat = M.write_chat(c)
    c.night = nil
    c.report = nil
    return c.prep
end

-- What last night did to each of them, in their own words for the chat (the playtest, Nov 2: the
-- chat was word for word every run). The night's own events first: a hero lost, a hero on the
-- floor, the last hit, being overruled at a fork, a call that made or spoiled their night, the
-- reason their hero came, paid off. One line each, the biggest first. Returns { key = text }.
local function strip(t)
    return string.lower((string.gsub(t or "", "[\"%[%]]", "")))
end

function M.night_lines(c, night)
    local out = {}
    if not night then
        return out
    end
    local week = c.week - 1
    local rng = c.rng
    local function put(key, lines)
        local p = c:player(key)
        if p and not out[key] then
            out[key] = util.fill(rng:pick(lines), { char = string.lower(p.char or ""), name = p.name })
        end
    end
    -- A hero lost.
    for key, nc in util.sorted_pairs(c.new_char or {}) do
        if nc.week == week and nc.was then
            local was = string.lower(nc.was)
            put(key, { "still not over " .. was .. ". rolling up someone new, be nice to them",
                       "rip " .. was .. ". i'm making a new one, they'll be worse at everything" })
            for _, q in ipairs(c.players) do
                if q.key ~= key and not out[q.key] then
                    out[q.key] = rng:pick({ was .. " deserved better tbh", "pouring one out for " .. was })
                    break
                end
            end
        end
    end
    local downs, kb = {}, {}
    for _, e in ipairs(night.ledger or {}) do
        if e.ev == "down" and e.who then
            downs[e.who] = (downs[e.who] or 0) + 1
        elseif e.ev == "killing_blow" and e.who then
            kb[e.who] = true
        end
    end
    for key, n in util.sorted_pairs(downs) do
        put(key, n >= 2 and { "{char} spent half of last week on the floor. not ideal", "{char} went down TWICE. i want a refund" }
            or { "{char} hit the floor last week and i'm still annoyed about it", "next time {char} is standing at the back" })
    end
    for key in util.sorted_pairs(kb) do
        put(key, { "for the record, that last hit was {char}'s", "just saying. {char}. last hit. that's all" })
    end
    -- (Overruled: the one it happened to most says so. Three people saying it is a pile-on.)
    local most, mn
    for key, n in util.sorted_pairs((night.mus and night.mus.overruled) or {}) do
        if not out[key] and (not mn or n > mn) then
            most, mn = key, n
        end
    end
    if most then
        put(most, mn >= 2 and { "were we ever actually going to get a say about where we went", "felt a bit on rails last week ngl" }
            or { "still think we should've gone the other way", "we got outvoted by the DM, noted" })
    end
    -- The call that moved them most, either way.
    for _, p in ipairs(c.players) do
        local best, bd
        for _, cl in ipairs(night.call_log or {}) do
            local d = cl.deltas[p.key]
            if d and math.abs(d) >= 6 and (not bd or math.abs(d) > math.abs(bd)) then
                best, bd = cl, d
            end
        end
        if best and not string.find(best.title or "", "^Round") then
            local what = strip(best.title)
            put(p.key, bd > 0 and { what .. ". more of that please", what .. ". best part of the night, no notes" }
                or { what .. "... not my favourite bit", "not gonna lie, " .. what .. " kind of killed it for me" })
        end
    end
    local adv = c.adv
    for key, wk in util.sorted_pairs(adv.hook_paid or {}) do
        if wk == week then
            put(key, { "{char} finally found what they came for. emotional", "ok {char}'s whole reason for coming paid off and i'm thrilled" })
        end
    end
    return out
end

-- The group chat: what the friends say about last week's rooms, and the requests waiting.
function M.write_chat(c)
    local st = c.adv
    local msgs = {}
    local said = {}
    -- Last night's own events first (three at most), then the rooms.
    local own = M.night_lines(c, c.night)
    for _, p in ipairs(c.players) do
        if own[p.key] and #msgs < 3 then
            said[p.key] = true
            table.insert(msgs, { who = p.name, key = p.key, text = own[p.key] })
        end
    end
    local last = {}
    for _, step in ipairs(st.path) do
        if step.week == c.week - 1 then
            table.insert(last, step.room)
        end
    end
    for _, room in ipairs(last) do
        for key, line in util.sorted_pairs(MODULE.chat[room] or {}) do
            local p = c:player(key)
            -- (A line about something only if it happened: { text, when }.)
            local text = type(line) == "table" and line[1] or line
            local ok = type(line) ~= "table" or adventure.test(c, line.when)
            if p and ok and not said[key] and #msgs < 5 then
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
                table.insert(msgs, { who = p.name, key = p.key, text = pr.ask or pr.def.ask, request = pr.id })
            end
        end
    end
    return msgs
end

-- What prepping a room really means (for the board): the minis to put out (the room's own fight,
-- or her card's on boss night), the people you'll voice, the props and handouts, and where a
-- Session Zero ask meets what's in it. Returns a list of { kind, text }.
function M.room_prep(c, id)
    local r = MODULE.rooms[id]
    local out = {}
    local ids = r.encounter
    if id == "lair" then
        ids = adventure.boss_encounter(c).ids
    end
    if ids and #ids > 0 then
        local monsters = require "game.rules.data.monsters"
        local count, order = {}, {}
        for _, mid in ipairs(ids) do
            if not count[mid] then
                table.insert(order, mid)
            end
            count[mid] = (count[mid] or 0) + 1
        end
        local bits = {}
        for _, mid in ipairs(order) do
            local m = monsters[mid]
            local name = string.lower(m and m.name or mid)
            table.insert(bits, util.int(count[mid]) .. " " .. name .. ((count[mid] > 1 and not string.find(name, "s$")) and "s" or ""))
        end
        table.insert(out, { kind = "minis", text = (r.optional_fight and "If it comes to a fight: " or "Minis: ") .. table.concat(bits, ", ") })
    end
    local pn = MODULE.prep_notes and MODULE.prep_notes[id] or {}
    for _, v in ipairs(pn.voices or {}) do
        table.insert(out, { kind = "voice", text = "Voice: " .. v })
    end
    if pn.handouts and #pn.handouts > 0 then
        table.insert(out, { kind = "handout", text = "Have ready: " .. util.join_names(pn.handouts) })
    end
    local t = c.table or {}
    for tag, rooms in pairs(MODULE.content or {}) do
        local what = rooms[id]
        local key = what and ((t.lines and t.lines[tag]) or (t.veils and t.veils[tag]) or (t.pushed and t.pushed[tag]))
        local p = key and c:player(key)
        if p then
            local how = (t.lines and t.lines[tag]) and "line" or ((t.veils and t.veils[tag]) and "veil" or "ask, which you pushed back on")
            local plan = (how == "line" and ", so you'll leave it out altogether") or (how == "veil" and ", so you'll keep it off screen")
                or ", and it plays as written"
            table.insert(out, { kind = "ask", text = p.name .. "'s " .. how .. ": " .. what .. plan })
        end
    end
    return out
end

-- After the night: what the adventure keeps, and the report's museum section.
function M.after_night(c, night, rep)
    local st = c.adv
    local mus = night.mus or {}
    -- Out of sessions with Euryale still upstairs: the book's quiet ending (Flitwidget moves on).
    if not st.ending and c.week >= MODULE.MAX_WEEKS then
        st.ending = "timeout"
    end
    rep.museum = {
        rooms = mus.rooms or {},
        marks = mus.added or {},
        bank = st.bank, harsh = mus.harsh_log or {},
        where = adventure.where(c),
        ending = st.ending,
        francs = st.francs,
        calls = night.top_calls and night:top_calls(5) or {},   -- (your calls tonight that moved them most)
        francs_tonight = mus.francs_earned or 0,          -- (earned tonight, whatever was spent)
        francs_spent = math.max(0, (mus.francs_start or st.francs or 0) + (mus.francs_earned or 0) - (st.francs or 0)),
        got = mus.got or {},
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
