-- Setting up a campaign, one decision at a time (October 26: the planner, Session Zero and the
-- backstories were three full pages of choices). One flow, in the frame game/ui/steps.lua draws:
--
--   The campaign   who's at the table, where most nights happen, three truths, a second
--                  threat, your dice (the planner: game/model/planner.lua)
--   Session Zero   how it should feel, each player's ask, each table rule (game/model/social.lua)
--   Backstories    for each hero: what you ask, their idea, what turns up first
--                  (game/model/backstory.lua)
--   Ready          whose stories come first (the planner's featured threads, asked once you've
--                  heard the backstories), then everything at a glance and session 1
--
-- Nothing's laid down until the last step, except who's at the table (the steps after it ask
-- the players who are there). A player joining a small table later gets the same backstory
-- steps for just them (the join flow, below).

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local panels = require "game.ui.panels"
local steps = require "game.ui.steps"
local prefs = require "game.ui.prefs"
local content = require "game.model.content"
local util = require "game.model.util"
local planner = require "game.model.planner"
local backstory = require "game.model.backstory"
local dice_sets = require "game.model.dice_sets"
local social = require "game.model.social"
local talk = require "game.data.setup_talk"

local M = {}

local X, W = 120, 1360      -- the question and its choices, in the panel under the room

-- What you've chosen so far: the plan, and Session Zero.
local function st(app)
    if not app.setup then
        local d = planner.data.default
        local truths = {}
        for i, id in ipairs(d.truths) do
            truths[i] = id
        end
        app.setup = {
            plan = { truths = truths, front = d.front, threads = {}, style = "frontier",
                     table = planner.data.screen_table or d.table,
                     dice = dice_sets.get(app.campaign).dm or dice_sets.offer(app.campaign)[1] },
            s0 = { asks = {}, rules = {}, backstories = {} },
        }
        -- Who's at the table, from the start: the steps after it ask the players who are there.
        if app.campaign.set_table then
            app.campaign:set_table(app.setup.plan.table)
        end
    end
    return app.setup
end
M.state = st

local function keys(app)
    return app.campaign:table_keys()
end

local function toggle(list, id, max)
    for i, v in ipairs(list) do
        if v == id then
            table.remove(list, i)
            return true
        end
    end
    if #list >= max then
        return false
    end
    table.insert(list, id)
    return true
end

-- A bubble: what they say. like: how they feel (the bubble's edge and their pose).
local function say(text, like)
    return { text = text, like = like }
end

-- What they'd pick, before you've picked: the option they like best, said out loud.
local function leaning(key, opts, order, fmt)
    local best, bv
    for _, id in ipairs(order) do
        local o = opts[id]
        local v = o and o.like and o.like[key] or 0
        if not bv or v > bv then
            best, bv = id, v
        end
    end
    if best and bv and bv > 0 then
        return say(util.fill(fmt or "I'd go with \"{name}\".", { name = opts[best].name }), nil)
    end
    return say(talk.waiting[key], nil)
end

-- What they say about the option you picked: their own words, or how they feel about it.
local function react(o, key)
    local v = o.like and o.like[key] or 0
    local line = o.says and o.says[key]
    if not line then
        line = v >= 2 and "Love it." or (v >= 1 and "Good call." or (v >= 0 and "Fine by me." or (v >= -1 and "Hmm. Not my favourite."
            or "Really? Okay...")))
    end
    return say(line, v)
end

-- Seat whoever's at the table (an empty chair for anyone joining later), and the room camera.
local function seat(app, all)
    if not app.table_post then
        return
    end
    local present = {}
    for _, key in ipairs(content.players.order) do
        present[key] = all or util.contains(keys(app), key)
    end
    app.table_post("seats", { present = present })
end

-- The campaign (the planner) ----------------------------------------------------------------------

local function table_step()
    return {
        id = "table", section = "The campaign",
        ask = "Who's at the table?",
        sub = "Your four friends are keen, but a first campaign is easier to follow with fewer stories at once.",
        -- Everyone has a say here, the ones joining later too (from their empty chair).
        people = function() return content.players.order end,
        talk = function(app, key)
            local t = planner.data.tables[st(app).plan.table]
            for _, j in ipairs(t.join or {}) do
                if j.key == key then
                    return say(util.fill(talk.table.later[key], { week = util.int(j.week) }), 0)
                end
            end
            return say(talk.table.start[key], 1)
        end,
        draw = function(app, a)
            local s = st(app)
            local data = planner.data
            local items = {}
            for _, tid in ipairs(data.tables.order) do
                local t = data.tables[tid]
                table.insert(items, {
                    title = t.name, body = t.about, on = s.plan.table == tid, key = "table_" .. tid, title_pad = 220,
                    click = function()
                        s.plan.table = tid
                        app.campaign:set_table(tid)
                        seat(app)
                        app.refresh()
                    end,
                    deco = function(x, y, w)
                        for i, key in ipairs(t.start) do
                            local fx = x + w - 16 - #t.start * 50 + (i - 1) * 50
                            kit.dot(fx + 22, y + 34, 44, panels.COLORS[key] or theme.panel3)
                            kit.picture(fx + 4, y + 16, 36, 36, panels.face(key))
                        end
                    end,
                })
            end
            steps.cards(app, a, items, { cols = 2 })
        end,
    }
end

local function style_step()
    local function fit(app, key, sid)
        local p = app.campaign:player(key)
        return p and require("game.model.styles").fit(p, sid) or 0
    end
    return {
        id = "style", section = "The campaign",
        ask = "Where do most nights happen?",
        sub = "The campaign's style. Wherever it wanders, the bells still call the party home to Millbrook.",
        talk = function(app, key)
            local sid = st(app).plan.style
            local f = fit(app, key, sid)
            local name = content.styles.styles[sid].name
            local tier = f >= 1 and "keen" or (f < 0 and "unsure" or "meh")
            return say(util.fill(talk.style[tier][key], { style = name }), f >= 1 and 1 or (f < 0 and -1 or 0))
        end,
        draw = function(app, a)
            local s = st(app)
            local items = {}
            for _, sid in ipairs(content.styles.order) do
                local sd = content.styles.styles[sid]
                local keen, unsure = {}, {}
                for _, key in ipairs(keys(app)) do
                    local f = fit(app, key, sid)
                    if f >= 1 then
                        table.insert(keen, content.players[key].name)
                    elseif f < 0 then
                        table.insert(unsure, content.players[key].name)
                    end
                end
                local who = (#keen > 0 and ("Keen: " .. util.join_names(keen) .. ". ") or "")
                    .. (#unsure > 0 and ("Not sold: " .. util.join_names(unsure) .. ".") or "")
                table.insert(items, {
                    title = sd.name, body = sd.pitch, foot = who ~= "" and who or nil,
                    foot_color = #unsure > 0 and theme.orange or theme.teal,
                    on = s.plan.style == sid, key = "style_" .. sid,
                    click = function()
                        s.plan.style = sid
                        -- Truths and fronts from the old style don't come along.
                        for i = #s.plan.truths, 1, -1 do
                            local def = planner.truth_def(s.plan.truths[i])
                            if def and def.style and def.style ~= sid then
                                table.remove(s.plan.truths, i)
                            end
                        end
                        if not util.contains(planner.fronts_for(sid), s.plan.front) then
                            s.plan.front = planner.data.default.front
                        end
                        app.refresh()
                    end,
                })
            end
            steps.cards(app, a, items, { cols = 3, title_font = "ui18b", body_font = "ui14", gap = 12 })
        end,
    }
end

local function truths_step()
    return {
        id = "truths", section = "The campaign",
        ask = "Three truths about the world",
        sub = function(app)
            return "What everyone at the table knows going in. Two come from the campaign's style. "
                .. util.int(#st(app).plan.truths) .. " of " .. util.int(planner.data.PICK_TRUTHS) .. " picked."
        end,
        done = function(app)
            return #st(app).plan.truths == planner.data.PICK_TRUTHS
        end,
        need = "Pick three truths.",
        talk = function(app, key)
            return { text = talk.truths[key], think = true }
        end,
        draw = function(app, a)
            local s = st(app)
            local items = {}
            for _, t in ipairs(planner.truths_for(s.plan.style or "frontier")) do
                table.insert(items, {
                    title = t.name, body = t.about, on = util.contains(s.plan.truths, t.id), key = "truth_" .. t.id,
                    foot = t.style and ("From " .. content.styles.styles[t.style].name) or nil, foot_color = theme.gold,
                    click = function()
                        if not toggle(s.plan.truths, t.id, planner.data.PICK_TRUTHS) then
                            app.toast = "Three truths. Take one out first."
                        end
                        app.refresh()
                    end,
                })
            end
            steps.cards(app, a, items, { cols = 4, title_font = "ui18b", body_font = "ui14", gap = 10 })
        end,
    }
end

local function front_step()
    return {
        id = "front", section = "The campaign",
        ask = "A second threat, beside Kessrick's warband",
        sub = "Kessrick the Wolf is coming for the valley either way. Who else is moving against it?",
        done = function(app)
            return st(app).plan.front ~= nil
        end,
        talk = function(app, key)
            local id = st(app).plan.front
            local t = talk.fronts[id] or talk.fronts.other
            local f = planner.data.fronts[id]
            return say(util.fill(t[key], { front = f and f.name or "" }), t.like and t.like[key])
        end,
        draw = function(app, a)
            local s = st(app)
            local lo = content.lore
            local items = {}
            for _, id in ipairs(planner.fronts_for(s.plan.style or "frontier")) do
                local f = planner.data.fronts[id]
                local lines = { f.about }
                for k, p in ipairs(f.portents) do
                    table.insert(lines, util.int(k) .. ". " .. p.text)
                end
                table.insert(items, {
                    title = f.name, body = table.concat(lines, "\n"), foot = "If nobody stops them: " .. f.doom,
                    foot_color = theme.orange, on = s.plan.front == id, key = "front_" .. id, title_pad = 40,
                    click = function()
                        s.plan.front = id
                        app.refresh()
                    end,
                    deco = function(x, y, w)
                        local ic = lo.icons.fronts[id]
                        if ic then
                            local col = lo.opening.fronts[id] and lo.opening.fronts[id].color
                            kit.icon(x + w - 44, y + 14, 28, ic, col and kit.rgba(col) or theme.gold)
                        end
                    end,
                })
            end
            steps.cards(app, a, items, { cols = math.min(3, #items), title_font = "ui18b", body_font = "ui14" })
        end,
    }
end

local function dice_step()
    return {
        id = "dice", section = "The campaign",
        ask = "Your dice",
        sub = "The set you'll roll behind the screen. The players start on plain grey; better dice come later.",
        talk = function(app, key)
            return say(talk.dice[key], talk.dice.like[key])
        end,
        draw = function(app, a)
            local s = st(app)
            local items = {}
            for i, id in ipairs(dice_sets.offer(app.campaign)) do
                local set = dice_sets.data.SETS[id]
                table.insert(items, {
                    title = set.name, body = set.about, on = s.plan.dice == id, key = "dice_" .. i, title_pad = 100, tall = 130,
                    click = function()
                        s.plan.dice = id
                        app.refresh()
                    end,
                    deco = function(x, y, w, h)
                        kit.picture(x + w - 104, y + 12, 88, 88, "dice_" .. id)
                    end,
                })
            end
            steps.cards(app, a, items, { cols = 3, title_font = "ui18b", body_font = "ui14" })
        end,
    }
end

-- Session Zero ---------------------------------------------------------------------------------

local function tone_step()
    local tones = content.session_zero.tones
    return {
        id = "tone", section = "Session Zero",
        ask = "How should the campaign feel?",
        sub = "Before the first game, the table talks it through. Everyone has an opinion.",
        done = function(app)
            return st(app).s0.tone ~= nil
        end,
        need = "Pitch a tone.",
        talk = function(app, key)
            local t = st(app).s0.tone and tones[st(app).s0.tone]
            if t then
                return react(t, key)
            end
            return leaning(key, tones, tones.order, "Can it be \"{name}\"?")
        end,
        draw = function(app, a)
            local s0 = st(app).s0
            local items = {}
            for _, key in ipairs(tones.order) do
                local t = tones[key]
                table.insert(items, {
                    title = t.name, body = t.blurb, on = s0.tone == key, key = "tone_" .. key, extra_h = prefs.chill() and 36 or 0,
                    click = function()
                        s0.tone = key
                        app.refresh()
                    end,
                    deco = function(x, y, w, h)
                        steps.faces(x + 16, y + h - 40, t.like, keys(app))
                    end,
                })
            end
            steps.cards(app, a, items, { cols = 4, title_font = "ui18b", body_font = "ui14" })
        end,
    }
end

local KIND = { line = "A line: it never happens in the game.", veil = "A veil: it can happen, but off screen.",
               promise = "A promise about how you'll run things." }

local function ask_step(key)
    return {
        id = "ask_" .. key, section = "Session Zero",
        skip = function(app)
            return not util.contains(keys(app), key) or not content.session_zero.asks[key]
        end,
        ask = function()
            return content.players[key].name .. "'s ask"
        end,
        sub = function()
            local a = content.session_zero.asks[key]
            return a and KIND[a.kind] or ""
        end,
        done = function(app)
            return st(app).s0.asks[key] ~= nil
        end,
        need = "Agree, or push back.",
        talk = function(app, who)
            if who ~= key then
                return nil
            end
            local ask = content.session_zero.asks[key]
            local o = st(app).s0.asks[key] and ask[st(app).s0.asks[key]]
            if o then
                return say(o.reply, o.like)
            end
            return say(ask.text, nil)
        end,
        draw = function(app, a)
            local s0 = st(app).s0
            local ask = content.session_zero.asks[key]
            local items = {}
            for _, which in ipairs({ "agree", "push" }) do
                local o = ask[which]
                table.insert(items, {
                    title = o.label, on = s0.asks[key] == which, key = "ask_" .. key .. "_" .. which,
                    click = function()
                        s0.asks[key] = which
                        app.refresh()
                    end,
                })
            end
            steps.cards(app, a, items, { cols = 2, title_font = "ui18b" })
        end,
    }
end

local function rule_step(rk)
    local r = content.session_zero.rules[rk]
    return {
        id = "rule_" .. rk, section = "Session Zero",
        ask = r.name, sub = r.about,
        done = function(app)
            return st(app).s0.rules[rk] ~= nil
        end,
        need = "Pick one.",
        talk = function(app, key)
            local o = st(app).s0.rules[rk] and r[st(app).s0.rules[rk]]
            if o then
                return react(o, key)
            end
            return leaning(key, r, r.order)
        end,
        draw = function(app, a)
            local s0 = st(app).s0
            local items = {}
            for _, ok in ipairs(r.order) do
                local o = r[ok]
                table.insert(items, {
                    title = o.name, body = o.about, on = s0.rules[rk] == ok, key = "rule_" .. rk .. "_" .. ok, extra_h = prefs.chill() and 36 or 0,
                    click = function()
                        s0.rules[rk] = ok
                        app.refresh()
                    end,
                    deco = function(x, y, w, h)
                        steps.faces(x + 16, y + h - 40, o.like, keys(app))
                    end,
                })
            end
            steps.cards(app, a, items, { cols = math.min(4, #items), title_font = "ui18b", body_font = "ui14" })
        end,
    }
end

-- Backstories (and a player joining later) ------------------------------------------------------

local function asked_word(like, tired)
    if tired then
        return "One question too many", theme.orange
    elseif like >= 1 then
        return "Loved being asked", theme.green
    elseif like < 0 then
        return "Put on the spot", theme.orange
    end
    return "Happy to answer", theme.dim
end

local function feel_word(like)
    if like >= 2 then
        return "Loves it", theme.green
    elseif like >= 1 then
        return "Likes it", theme.teal
    elseif like < 0 then
        return "Uneasy", theme.orange
    end
    return "Fine with it", theme.dim
end

-- The hero's player, talking about their past: the pitch, then the answer to your latest question.
local function story_talk(key, all)
    local d = backstory.data[key]
    local ch = all[key]
    local asked = ch and ch.asked or {}
    if #asked > 0 then
        local q = backstory.question(key, asked[#asked])
        local tired = #asked > (d.tires or 3)
        return say(q.answer, q.like - (tired and 1 or 0))
    end
    return say(d.pitch, nil)
end

-- Your questions, one line each; the answers so far under the ones you asked.
local function questions(app, a, key, all, budget, joining)
    local d = backstory.data[key]
    local ch = all[key] or { asked = {} }
    local order = {}
    for i, id in ipairs(ch.asked or {}) do
        order[id] = i
    end
    local left = backstory.left(all, budget)
    local y = a.y
    for _, q in ipairs(d.questions) do
        local n = order[q.id]
        local asked = n ~= nil
        if asked then
            kit.box(a.x - 3, y - 3, a.w + 6, 40, theme.gold, { radius = 10 })
        end
        kit.button(a.x, y, a.w, 34, q.ask, function()
            if not backstory.toggle_question(all, key, q.id, budget) then
                app.toast = joining and "That's the three questions there's time for." or
                    "That's the six questions the evening has time for. Take one back to ask this."
            end
            app.refresh()
        end, { font = "ui18", align = "left", pad_y = 6, color = asked and theme.panel3 or theme.button,
               hover = theme.button_hover, enabled = asked or left > 0, key = "bs_q_" .. q.id })
        if asked then
            local tired = n > (d.tires or 3)
            local word, col = asked_word(q.like - (tired and 1 or 0), tired)
            kit.text(a.x + a.w - 14, y + 9, word, "ui14", col, { pivot = gui.PIVOT_NE })
        end
        y = y + 42
    end
end

local function idea_talk(key, all)
    local d = backstory.data[key]
    local ch = all[key]
    if ch and ch.idea then
        local o = d.idea[ch.idea]
        return say(o.reply, o.like)
    end
    return say(d.idea.text, nil)
end

local function idea(app, a, key, all)
    local d = backstory.data[key]
    local ch = all[key] or { asked = {} }
    local items = {}
    for _, which in ipairs({ "yes", "no" }) do
        local o = d.idea[which]
        table.insert(items, {
            title = o.label, on = ch.idea == which, key = "bs_idea_" .. which,
            click = function()
                all[key] = all[key] or { asked = {} }
                all[key].idea = which
                app.refresh()
            end,
        })
    end
    steps.cards(app, a, items, { cols = 2, title_font = "ui18b" })
end

local function hook_talk(key, all)
    local ch = all[key]
    local hk = ch and ch.hook and backstory.hook_of(key, ch.hook)
    if hk then
        local v = hk.like
        return say(v >= 2 and "Oh, that's the one. Yes!" or (v >= 1 and "Ooh, good pick." or (v >= 0 and "Sure, that works."
            or "Oh. That one first?")), v)
    end
    return { text = "Which bit of my past turns up first?", think = true }
end

local function hooks(app, a, key, all)
    local d = backstory.data[key]
    local ch = all[key] or { asked = {} }
    local items = {}
    for _, hk in ipairs(d.hooks) do
        local c = content.components[hk.card]
        local word, col = feel_word(hk.like)
        table.insert(items, {
            title = hk.text, foot = string.upper(c and content.kind_names[c.kind] or "") .. ": " .. (c and c.name or hk.card),
            on = ch.hook == hk.card, key = "bs_hook_" .. hk.card, title_pad = prefs.chill() and 70 or nil,
            click = function()
                all[key] = all[key] or { asked = {} }
                all[key].hook = hk.card
                app.refresh()
            end,
            deco = function(x, y, w)
                if prefs.chill() then      -- (how they'd feel about it, before you pick: Chill mode only)
                    kit.text(x + w - 16, y + 16, word, "ui14", col, { pivot = gui.PIVOT_NE })
                end
            end,
        })
    end
    steps.cards(app, a, items, { cols = #items, title_font = "ui18", gap = 12 })
end

local function bs_steps(key)
    local function at_table(app)
        return util.contains(keys(app), key) and backstory.data[key] ~= nil
    end
    local function all(app)
        return st(app).s0.backstories
    end
    local pd = content.players[key]
    local function only(fn)
        return function(app, who)
            if who == key then
                return fn(app)
            end
        end
    end
    return {
        {
            id = "bs_q_" .. key, section = "Backstories",
            skip = function(app) return not at_table(app) end,
            ask = pd.char .. "'s past: what do you ask?",
            sub = function(app)
                local left = backstory.left(all(app), backstory.data.QUESTIONS)
                return pd.name .. " pitches their hero. Each answer goes into " .. pd.char .. "'s story. The evening has time for "
                    .. util.int(backstory.data.QUESTIONS) .. " questions, all told: " .. util.int(left) .. " left."
            end,
            talk = only(function(app) return story_talk(key, all(app)) end),
            draw = function(app, a)
                questions(app, a, key, all(app), backstory.data.QUESTIONS)
            end,
        },
        {
            id = "bs_idea_" .. key, section = "Backstories",
            skip = function(app) return not at_table(app) end,
            ask = pd.name .. "'s idea",
            sub = "They've brought an idea for " .. pd.char .. "'s past. Say yes and it's part of the world.",
            done = function(app)
                local ch = all(app)[key]
                return ch ~= nil and ch.idea ~= nil
            end,
            need = "Yes, or not this time.",
            talk = only(function(app) return idea_talk(key, all(app)) end),
            draw = function(app, a)
                idea(app, a, key, all(app))
            end,
        },
        {
            id = "bs_hook_" .. key, section = "Backstories",
            skip = function(app) return not at_table(app) end,
            ask = "What from " .. pd.char .. "'s past turns up first?",
            sub = "It waits at the front of your first hand.",
            done = function(app)
                local ch = all(app)[key]
                return ch ~= nil and ch.hook ~= nil
            end,
            need = "Pick what turns up first.",
            talk = only(function(app) return hook_talk(key, all(app)) end),
            draw = function(app, a)
                hooks(app, a, key, all(app))
            end,
        },
    }
end

-- Ready -----------------------------------------------------------------------------------------

local function featured_step()
    return {
        id = "featured", section = "Ready",
        -- (A table of two features both, with nothing to choose.)
        skip = function(app)
            return #keys(app) <= planner.data.PICK_THREADS
        end,
        ask = "Whose stories come first?",
        sub = function(app)
            return "Pick two heroes to feature: their story cards come sooner. " .. util.int(#st(app).plan.threads) .. " of "
                .. util.int(planner.data.PICK_THREADS) .. " picked."
        end,
        done = function(app)
            local n = 0
            for _, k in ipairs(st(app).plan.threads) do
                if util.contains(keys(app), k) then
                    n = n + 1
                end
            end
            return n == planner.data.PICK_THREADS
        end,
        need = "Pick two.",
        talk = function(app, key)
            local on = util.contains(st(app).plan.threads, key)
            if on then
                return say(key == "sam" and "Oh! Okay. Oswin's up. I'll try." or "Yes! Thank you.", key == "sam" and 0 or 2)
            end
            return say(talk.featured[key], nil)
        end,
        draw = function(app, a)
            local s = st(app)
            local items = {}
            for _, p in ipairs(app.campaign.players) do
                local ch = s.s0.backstories[p.key]
                local hk = ch and ch.hook and backstory.hook_of(p.key, ch.hook)
                table.insert(items, {
                    title = p.char, body = util.capitalize(p.thread or ""), foot = hk and ("Turns up first: " .. hk.text) or nil,
                    on = util.contains(s.plan.threads, p.key), key = "thread_" .. p.key, title_pad = 60,
                    click = function()
                        if not toggle(s.plan.threads, p.key, planner.data.PICK_THREADS) then
                            app.toast = "Two heroes. Take one out first."
                        end
                        app.refresh()
                    end,
                    deco = function(x, y, w)
                        kit.dot(x + w - 34, y + 34, 48, panels.COLORS[p.key] or theme.panel3)
                        kit.picture(x + w - 54, y + 14, 40, 40, panels.face(p.key))
                    end,
                })
            end
            steps.cards(app, a, items, { cols = 4, title_font = "ui18b", body_font = "ui14" })
        end,
    }
end

local function feeling(v)
    return v >= 3 and 2 or (v >= 1 and 1 or (v >= -1 and 0 or -1))
end

local function summary_step()
    return {
        id = "ready", section = "Ready",
        ask = "Ready for session 1",
        sub = "The campaign you've set up. Go back to change anything.",
        next_label = "Start session 1  >",
        talk = function(app, key)
            local s0 = st(app).s0
            local f = social.feelings({ tone = s0.tone or "mixed", asks = s0.asks, rules = s0.rules, backstories = s0.backstories })
            return say(talk.ready[key], feeling(f[key] or 0))
        end,
        draw = function(app, a)
            local s = st(app)
            local p = s.plan
            local cw = math.floor((a.w - 40) / 2)
            local function row(x, y, label, text)
                kit.text(x, y + 2, label, "ui14", theme.gold, { gloss = false })
                kit.text(x + 180, y, text, "ui18", theme.text, { w = cw - 180, lines = 2 })
                return y + math.max(26, math.min(2, #kit.wrap(text, "ui18", cw - 180)) * kit.line_height("ui18") + 4)
            end
            local y = a.y
            y = row(a.x, y, "THE CAMPAIGN", planner.data.premise.name .. ", in " .. content.styles.styles[p.style].name)
            y = row(a.x, y, "AT THE TABLE", planner.data.tables[p.table].name)
            local tn = {}
            for _, id in ipairs(p.truths) do
                local def = planner.truth_def(id)
                table.insert(tn, def and (def.short or def.name) or id)
            end
            y = row(a.x, y, "TRUTHS", table.concat(tn, ", "))
            y = row(a.x, y, "THE THREATS", "Kessrick's warband, and " .. planner.data.fronts[p.front].name)
            local feat = {}
            local threads = #keys(app) <= planner.data.PICK_THREADS and keys(app) or p.threads
            for _, k in ipairs(threads) do
                table.insert(feat, content.players[k].char)
            end
            row(a.x, y, "FEATURED", util.join_names(feat))
            -- Session Zero.
            local rx = a.x + cw + 40
            local ry = a.y
            local s0 = s.s0
            ry = row(rx, ry, "THE FEEL", s0.tone and content.session_zero.tones[s0.tone].name or "")
            for _, rk in ipairs(content.session_zero.rules.order) do
                local r = content.session_zero.rules[rk]
                local o = s0.rules[rk] and r[s0.rules[rk]]
                ry = row(rx, ry, string.upper(r.name), o and o.name or "")
            end
        end,
    }
end

-- Lay it all down: the plan, your dice, Session Zero and the backstories; then week 1.
function M.finish(app)
    local s = st(app)
    local plan = s.plan
    local threads = {}
    for _, k in ipairs(#keys(app) <= planner.data.PICK_THREADS and keys(app) or plan.threads) do
        table.insert(threads, k)
    end
    planner.apply(app.campaign, { truths = plan.truths, front = plan.front, threads = threads, style = plan.style,
                                  table = plan.table })
    dice_sets.pick_dm(app.campaign, plan.dice)
    if app.paint_dice then
        app.paint_dice()
    end
    app.campaign:session_zero(s.s0)
    app.setup = nil
    steps.reset(app, M.flow)
    app.go("prep")
end

M.flow = {
    id = "setup",
    title = "SETTING UP",
    layout = "table",
    people = function(app)
        return keys(app)
    end,
    steps = {},
    finish = { label = "Start session 1  >", fn = function(app) M.finish(app) end },
}
do
    local list = M.flow.steps
    for _, s in ipairs({ table_step(), style_step(), truths_step(), front_step(), dice_step(), tone_step() }) do
        table.insert(list, s)
    end
    for _, key in ipairs(content.session_zero.asks.order) do
        table.insert(list, ask_step(key))
    end
    for _, rk in ipairs(content.session_zero.rules.order) do
        table.insert(list, rule_step(rk))
    end
    for _, key in ipairs(content.players.order) do
        for _, s in ipairs(bs_steps(key)) do
            table.insert(list, s)
        end
    end
    table.insert(list, featured_step())
    table.insert(list, summary_step())
end

-- A player joining a small table (October 15): their story, their idea, their ask, what turns up
-- first, and the welcome. app.join = { key, backstories, ask }.

local function join_all(app)
    app.join.backstories = app.join.backstories or {}
    return app.join.backstories
end

local function jkey(app)
    return app.join and app.join.key
end

local function jonly(fn)
    return function(app, who)
        if who == jkey(app) then
            return fn(app)
        end
    end
end

M.join_flow = {
    id = "join",
    title = function(app)
        local key = jkey(app)
        return key and (string.upper(content.players[key].name) .. " JOINS") or "JOINING"
    end,
    layout = "table",
    people = function(app)
        local out = {}
        for _, key in ipairs(keys(app)) do
            table.insert(out, key)
        end
        if jkey(app) and not util.contains(out, jkey(app)) then
            table.insert(out, jkey(app))
        end
        return out
    end,
    steps = {
        {
            id = "join_q", section = "Their story",
            ask = function(app)
                return content.players[jkey(app)].char .. "'s past: what do you ask?"
            end,
            sub = function(app)
                local left = backstory.left(join_all(app), backstory.data.JOIN_QUESTIONS)
                return content.players[jkey(app)].name .. " joins the table this week. Each answer goes into their story. There's time for "
                    .. util.int(backstory.data.JOIN_QUESTIONS) .. " questions: " .. util.int(left) .. " left."
            end,
            talk = jonly(function(app) return story_talk(jkey(app), join_all(app)) end),
            draw = function(app, a)
                questions(app, a, jkey(app), join_all(app), backstory.data.JOIN_QUESTIONS, true)
            end,
        },
        {
            id = "join_idea", section = "Their story",
            ask = function(app)
                return content.players[jkey(app)].name .. "'s idea"
            end,
            sub = "Say yes and it's part of the world.",
            done = function(app)
                local ch = join_all(app)[jkey(app)]
                return ch ~= nil and ch.idea ~= nil
            end,
            need = "Yes, or not this time.",
            talk = jonly(function(app) return idea_talk(jkey(app), join_all(app)) end),
            draw = function(app, a)
                idea(app, a, jkey(app), join_all(app))
            end,
        },
        {
            id = "join_ask", section = "Their ask",
            skip = function(app)
                return not content.session_zero.asks[jkey(app)]
            end,
            ask = function(app)
                return content.players[jkey(app)].name .. "'s ask"
            end,
            sub = function(app)
                local a = content.session_zero.asks[jkey(app)]
                return (a and KIND[a.kind] or "") .. " The one Session Zero would have heard."
            end,
            done = function(app)
                return app.join.ask ~= nil
            end,
            need = "Agree, or push back.",
            talk = jonly(function(app)
                local ask = content.session_zero.asks[jkey(app)]
                local o = app.join.ask and ask[app.join.ask]
                if o then
                    return say(o.reply, o.like)
                end
                return say(ask.text, nil)
            end),
            draw = function(app, a)
                local ask = content.session_zero.asks[jkey(app)]
                local items = {}
                for _, which in ipairs({ "agree", "push" }) do
                    table.insert(items, {
                        title = ask[which].label, on = app.join.ask == which, key = "join_ask_" .. which,
                        click = function()
                            app.join.ask = which
                            app.refresh()
                        end,
                    })
                end
                steps.cards(app, a, items, { cols = 2, title_font = "ui18b" })
            end,
        },
        {
            id = "join_hook", section = "Their story",
            ask = function(app)
                return "What from " .. content.players[jkey(app)].char .. "'s past turns up first?"
            end,
            sub = "It waits at the front of your hand this week.",
            done = function(app)
                local ch = join_all(app)[jkey(app)]
                return ch ~= nil and ch.hook ~= nil
            end,
            need = "Pick what turns up first.",
            talk = jonly(function(app) return hook_talk(jkey(app), join_all(app)) end),
            draw = function(app, a)
                hooks(app, a, jkey(app), join_all(app))
            end,
        },
    },
    finish = {
        label = function(app)
            return "Welcome " .. content.players[jkey(app)].name .. "  >"
        end,
        fn = function(app)
            M.welcome(app)
        end,
    },
}

function M.welcome(app)
    local key = jkey(app)
    if not key then
        return false
    end
    local ch = join_all(app)[key]
    if not (ch and ch.hook) then
        return false
    end
    app.campaign:welcome(key, { ask = app.join.ask, backstory = ch })
    app.join = nil
    steps.reset(app, M.join_flow)
    app.go("prep", { welcomed = true })
    return true
end

-- The screens, and Enter.
function M.build(app)
    st(app)
    seat(app)
    kit.gloss_scope({ story = true, table = true }, function()
        steps.draw(app, M.flow, { x = X, w = W })
    end)
end

function M.build_join(app)
    if app.table_post then
        local present = {}
        for _, key in ipairs(content.players.order) do
            present[key] = util.contains(keys(app), key) or key == jkey(app)
        end
        app.table_post("seats", { present = present })
    end
    kit.gloss_scope({ story = true, table = true }, function()
        steps.draw(app, M.join_flow, { x = X, w = W })
    end)
end

function M.next(app)
    return steps.next(app, M.flow)
end

function M.next_join(app)
    return steps.next(app, M.join_flow)
end

return M
