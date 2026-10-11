-- The social layer (M6): Session Zero, the three table conflicts, the promises
-- the DM makes, and which DM conversations are open each week. Pure Lua.
--
-- A conflict is a pressure number that game night pushes around (who had the
-- spotlight, how rules calls went, jokes in serious moments). Past BREWING people
-- notice: a bystander messages you and the conflict's card can come up at the table.
-- Past ACTIVE it costs the people involved Commitment every week. It's settled by a
-- fix: a conversation, a group post, enough good calls at the table, or (for the tone
-- clash) planning a week that gives both sides their scene.

local content = require "game.model.content"
local score = require "game.model.score"
local util = require "game.model.util"

local M = {}

local function defs()
    return content.conflicts
end

-- Session Zero ---------------------------------------------------------------------------

-- The choices Session Zero starts with (the screen lets the DM change every one).
function M.default_choices()
    local d = content.session_zero.defaults
    local c = { tone = d.tone, asks = {}, rules = {} }
    for k, v in pairs(d.asks) do
        c.asks[k] = v
    end
    for k, v in pairs(d.rules) do
        c.rules[k] = v
    end
    return c
end

-- How each player feels about a set of choices, -n..n. Shown on the Session Zero screen.
function M.feelings(choices)
    local s0 = content.session_zero
    local out = {}
    for _, key in ipairs(content.players.order) do
        local total = 0
        local tone = s0.tones[choices.tone]
        if tone then
            total = total + (tone.like[key] or 0)
        end
        local ask = s0.asks[key]
        local answer = choices.asks[key]
        if ask and answer then
            total = total + (ask[answer].like or 0)
        end
        for _, rk in ipairs(s0.rules.order) do
            local opt = s0.rules[rk][choices.rules[rk] or ""]
            if opt then
                total = total + (opt.like[key] or 0)
            end
        end
        out[key] = total
    end
    return out
end

-- Settle Session Zero: the table rules, lines and veils, promises, how everyone starts
-- out feeling, and where the conflicts start.
function M.apply_session_zero(campaign, choices, held)
    local s0 = content.session_zero
    choices = choices or M.default_choices()
    local t = {
        held = held and true or false,
        tone = choices.tone,
        asks = {},
        rules = {},
        lines = {},     -- content tag -> player key: never happens
        veils = {},     -- content tag -> player key: happens off screen
        pushed = {},    -- content tag -> player key: they asked, you didn't agree
        promises = {},  -- promise id -> player key
    }
    for k, v in pairs(choices.asks) do
        t.asks[k] = v
    end
    for k, v in pairs(choices.rules) do
        t.rules[k] = v
    end
    for _, key in ipairs(s0.asks.order) do
        local ask = s0.asks[key]
        local agreed = t.asks[key] == "agree"
        if ask.content then
            if agreed then
                t[ask.kind == "line" and "lines" or "veils"][ask.content] = key
            else
                t.pushed[ask.content] = key
            end
        elseif ask.promise and agreed then
            t.promises[ask.promise] = key
        end
    end
    campaign.table = t
    -- Where the conflicts start.
    local start = {}
    for _, id in ipairs(defs().order) do
        start[id] = defs()[id].start
    end
    local function add(p)
        for id, v in pairs(p or {}) do
            start[id] = (start[id] or 0) + v
        end
    end
    add(s0.tones[t.tone].pressure)
    for _, key in ipairs(s0.asks.order) do
        local a = s0.asks[key][t.asks[key] or "agree"]
        add(a and a.pressure)
    end
    for _, rk in ipairs(s0.rules.order) do
        local opt = s0.rules[rk][t.rules[rk]]
        add(opt and opt.pressure)
    end
    for id, v in pairs(start) do
        campaign.conflicts[id].pressure = util.clamp(v, 0, 100)
    end
    -- Talking it all through up front: people start out feeling heard (or not).
    if held then
        local f = M.feelings(choices)
        for _, p in ipairs(campaign.players) do
            local like = f[p.key] or 0
            score.add(p, "trust", 1.5 * like + 2)
            score.add(p, "investment", like + 2)
            p.lag.trust, p.lag.investment = p.trust, p.investment
        end
        campaign:gain_empathy("session_zero")
    end
    return t
end

-- Conflicts -------------------------------------------------------------------------------

function M.init(campaign)
    campaign.conflicts = {}
    for _, id in ipairs(defs().order) do
        campaign.conflicts[id] = {
            id = id,
            pressure = defs()[id].start,
            state = "calm",     -- calm, brewing, active, fixed
            progress = 0,       -- good table moves toward settling it
            weeks = 0,          -- weeks brewing or active this time round
            fixes = {},         -- { week, how } for every time it was settled
            asked = {},         -- bystanders who have already messaged about it
        }
    end
    campaign.promises_due = {}  -- "look_it_up" -> { week, topic }
    campaign.suggested = {}     -- convo ids the DM offered in a conversation (free to post)
    M.apply_session_zero(campaign, nil, false)
end

local function is_live(c)
    return c.state == "brewing" or c.state == "active"
end
M.is_live = is_live

-- Recompute a conflict's state from its pressure.
local function restate(campaign, c)
    local d = defs()
    local before = c.state
    if c.state == "fixed" and c.pressure < d.BREWING then
        return
    end
    if c.pressure >= d.ACTIVE then
        c.state = "active"
    elseif c.pressure >= d.BREWING then
        c.state = "brewing"
    elseif c.state ~= "fixed" then
        c.state = "calm"
    end
    if is_live(c) and not (before == "brewing" or before == "active") then
        -- Good table moves made while it simmered down still count (progress keeps).
        c.since = c.since and before == "calm" and c.calmed and (campaign.week - c.calmed) <= 2 and c.since or campaign.week
        c.weeks = 0
        c.asked = {}
        c.recurred = #c.fixes > 0
    elseif before ~= "calm" and c.state == "calm" then
        c.calmed = campaign.week
    end
end

function M.push(campaign, id, amount)
    local c = campaign.conflicts[id]
    if not c then
        return
    end
    if amount > 0 and #c.fixes > 0 then
        amount = amount * defs().RECUR_RATE
    end
    c.pressure = util.clamp(c.pressure + amount, 0, 100)
    restate(campaign, c)
end

-- Settle a conflict. Returns true if it was live.
function M.resolve(campaign, id, how)
    local c = campaign.conflicts[id]
    if not c or not is_live(c) then
        return false
    end
    c.state = "fixed"
    c.how = how
    c.pressure = 0
    c.progress = 0
    table.insert(c.fixes, { week = campaign.week, how = how, took = campaign.week - (c.since or campaign.week) })
    -- Clearing the air.
    for _, key in ipairs(defs()[id].hurt) do
        local p = campaign:player(key)
        if p then
            score.add(p, "trust", 2)
            score.add(p, "commitment", 1)
        end
    end
    campaign.resolved_now = campaign.resolved_now or {}
    table.insert(campaign.resolved_now, { id = id, how = how })
    return true
end

local function present(campaign, key)
    local p = campaign:player(key)
    return p and p.present and not p.on_break
end

local function around(campaign, key)
    local p = campaign:player(key)
    return p and not p.on_break
end

local function has_tag(c, list)
    for _, t in ipairs(c.tags or {}) do
        for _, want in ipairs(list) do
            if t == want then
                return true
            end
        end
    end
    return false
end

-- After game night: the night's moves push each conflict around.
function M.after_night(campaign, night)
    local d = defs()
    local tbl = campaign.table
    -- The Pip show: how lopsided the spotlight was.
    if present(campaign, "jess") then
        local jess = campaign:player("jess")
        local total, n = 0, 0
        for _, p in ipairs(night.players) do
            if p.key ~= "jess" then
                total, n = total + p.m.spotlight, n + 1
            end
        end
        local gap = n > 0 and (jess.m.spotlight - total / n) or 0
        local push = 0.35 * math.max(0, gap - 10) + 1
        if gap < 0 then
            push = -4 -- the others had the better night
        end
        if tbl.promises.no_cut then
            push = push + 4
        end
        M.push(campaign, "spotlight", push)
    else
        M.push(campaign, "spotlight", -6)
    end
    -- Rules lawyering: every rules call lands on one side.
    local both = present(campaign, "dev") and present(campaign, "sam")
    for _, call in ipairs(night.rules_calls or {}) do
        local v = 0
        if call.leans == "cool" then
            v = 4 + (tbl.rules.rulings == "book" and 5 or 0)
        elseif call.leans == "book" or call.leans == "strict" then
            v = 2 + (tbl.rules.rulings == "cool" and 4 or 0) + (call.leans == "strict" and 2 or 0)
        elseif call.leans == "house" then
            v = -8
        end
        if not both then
            v = v * 0.4
        end
        M.push(campaign, "rules", v)
        if tbl.rules.rulings == "quick" and call.leans ~= "house" and not call.looked
            and not (campaign.promises_due.look_it_up and campaign.promises_due.look_it_up.week == campaign.week) then
            -- "Quick call now, look it up after": the table expects the follow-up.
            M.promise(campaign, call.topic, true)
        end
    end
    -- The tone clash: jokes in Mara's serious moments.
    if present(campaign, "mara") and present(campaign, "jess") then
        local base = ({ mixed = 2, heroic = 4, grim = 8, silly = 8 })[tbl.tone] or 4
        local thread_funny, thread_serious, goofy = 0, false, false
        for _, sc in ipairs(night.scenes) do
            if sc.terrain then
                local mara_thread, funny = false, false
                for _, c in pairs(sc.comps) do
                    if c.thread == "mara" then
                        mara_thread = true
                    end
                    if has_tag(c, { "funny", "chaos" }) then
                        funny = true
                    end
                end
                if mara_thread and funny then
                    thread_funny = thread_funny + 1
                elseif mara_thread then
                    thread_serious = true
                end
                if (funny or sc.type == "downtime") and not mara_thread then
                    goofy = true
                end
            end
        end
        M.push(campaign, "tone", base + 6 * thread_funny)
        -- One week, two scenes: the structural fix.
        if thread_serious and goofy and thread_funny == 0 then
            if not M.resolve(campaign, "tone", "split") then
                M.push(campaign, "tone", -6)
            end
        end
    else
        M.push(campaign, "tone", -3)
    end
    -- The night's conflict cards.
    for _, mv in ipairs(night.conflict_moves or {}) do
        local c = campaign.conflicts[mv.id]
        if mv.pressure then
            M.push(campaign, mv.id, mv.pressure)
        end
        if mv.promise == "look_it_up" then
            M.promise(campaign, mv.topic)
        end
        if mv.resolve then
            M.resolve(campaign, mv.id, mv.resolve)
        elseif mv.progress and is_live(c) then
            c.progress = c.progress + mv.progress
            if c.progress >= d.PROGRESS_TO_FIX then
                M.resolve(campaign, mv.id, "table")
            end
        end
    end
    -- A ruling you promised to look up and never posted.
    local due = campaign.promises_due.look_it_up
    if due and due.week < campaign.week then
        M.break_promise(campaign)
    end
end

-- The DM promised to look a ruling up and post it next week.
function M.break_promise(campaign)
    local due = campaign.promises_due.look_it_up
    campaign.promises_due.look_it_up = nil
    if not due then
        return
    end
    local sam = campaign:player("sam")
    if sam and not sam.on_break then
        score.add(sam, "trust", due.auto and -3 or -5)
    end
    M.push(campaign, "rules", due.auto and 6 or 10)
    campaign.broken_now = "look_it_up"
end

-- Promise to look a ruling up. An older promise still unkept doesn't vanish: it's broken
-- first, then the new one starts. auto: made by the "quick call" table rule itself.
function M.promise(campaign, topic, auto)
    local due = campaign.promises_due.look_it_up
    if due and due.week < campaign.week then
        M.break_promise(campaign)
        due = nil
    end
    if due then
        -- Already promised this week: it's the same promise.
        due.auto = due.auto and auto
        return
    end
    campaign.promises_due.look_it_up = { week = campaign.week, topic = topic, auto = auto and true or nil }
end

-- Start of a week: live conflicts cost Commitment and time ticks on.
function M.start_week(campaign)
    campaign.resolved_now = nil
    campaign.broken_now = nil
    for _, id in ipairs(defs().order) do
        local c = campaign.conflicts[id]
        if not is_live(c) then
            -- Small frictions fade if nothing feeds them.
            c.pressure = math.max(0, c.pressure - defs().FADE)
        end
        if is_live(c) then
            c.weeks = c.weeks + 1
            if c.state == "active" then
                for _, key in ipairs(defs()[id].hurt) do
                    if present(campaign, key) or around(campaign, key) then
                        score.add(campaign:player(key), "commitment", -defs().ESCALATE)
                    end
                end
            end
        end
    end
    campaign.suggested = {}
    campaign.open_convos = M.open_convos(campaign)
end

-- Conversations ----------------------------------------------------------------------------

-- Who's most likely to message you about a conflict this week.
local function bystander(campaign, id)
    local c = campaign.conflicts[id]
    local options = {}
    if id == "spotlight" then
        -- The one with the least spotlight lately.
        local list = {}
        for _, key in ipairs({ "sam", "mara", "dev" }) do
            local p = campaign:player(key)
            if around(campaign, key) and not c.asked[key] then
                table.insert(list, { key = key, s = p.spot_avg or 50 })
            end
        end
        table.sort(list, function(a, b)
            return a.s < b.s
        end)
        for _, e in ipairs(list) do
            table.insert(options, e.key)
        end
    elseif id == "rules" then
        local cool = 0
        for _, call in ipairs(campaign.last_rules_calls or {}) do
            if call.leans == "cool" then
                cool = cool + 1
            elseif call.leans == "book" or call.leans == "strict" then
                cool = cool - 1
            end
        end
        if cool >= 0 then
            options = { "sam", "dev" }
        else
            options = { "dev", "sam" }
        end
    elseif id == "tone" then
        options = { "mara", "jess" }
    end
    for _, key in ipairs(options) do
        if around(campaign, key) and not c.asked[key] and content.convos[id .. "_" .. key] then
            return key
        end
    end
end

-- The conversations open this week, in the order the Messages list shows them.
function M.open_convos(campaign)
    local list = {}
    local function add(id, why)
        local def = content.convos[id]
        if def and (def.with == "group" or around(campaign, def.with)) then
            table.insert(list, { id = id, why = why })
        end
    end
    for _, id in ipairs(defs().order) do
        local c = campaign.conflicts[id]
        if is_live(c) then
            -- A bystander messages you, once per person per flare-up.
            local who = bystander(campaign, id)
            if who then
                c.asked[who] = true
                add(id .. "_" .. who, "conflict")
            end
            if id == "spotlight" then
                add("spotlight_jess", "conflict")
            elseif id == "rules" then
                add("rules_house", "conflict")
                add("rules_vote", "conflict")
            elseif id == "tone" then
                add("tone_check", "conflict")
            end
        end
    end
    if campaign.promises_due.look_it_up then
        add("rules_followup", "promise")
    end
    return list
end

-- What the rules argument is about right now.
function M.topic(campaign)
    local due = campaign.promises_due.look_it_up
    if due and due.topic then
        return due.topic
    end
    local calls = campaign.last_rules_calls or {}
    local last = calls[#calls]
    return (last and last.topic) or "flanking"
end

-- One line per conflict for the report and the prep board. Returns a list of
-- { id, state, text, how } for conflicts that are live or were settled this week.
function M.status(campaign)
    local out = {}
    for _, id in ipairs(defs().order) do
        local c = campaign.conflicts[id]
        local d = defs()[id]
        if is_live(c) then
            table.insert(out, { id = id, state = c.state, name = d.name, text = d[c.state] })
        end
    end
    for _, r in ipairs(campaign.resolved_now or {}) do
        local d = defs()[r.id]
        table.insert(out, { id = r.id, state = "fixed", name = d.name, text = d.fixes[r.how] or "Settled.", how = r.how })
    end
    return out
end

-- Content on the board that touches a Session Zero ask, for prep warnings.
-- Returns a list of { key, tag, kind = "line" | "veil" | "pushed", card }.
function M.content_flags(campaign, cards)
    local t = campaign.table
    local out = {}
    for _, c in ipairs(cards) do
        for _, tag in ipairs(c.content or {}) do
            local key, kind
            if t.lines[tag] then
                key, kind = t.lines[tag], "line"
            elseif t.veils[tag] then
                key, kind = t.veils[tag], "veil"
            elseif t.pushed[tag] then
                key, kind = t.pushed[tag], "pushed"
            end
            if key then
                table.insert(out, { key = key, tag = tag, kind = kind, card = c })
            end
        end
    end
    return out
end

return M
