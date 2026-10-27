-- The week's prep, one decision at a time (October 26: "rework them to simplify and be more
-- step-by-step instead of full pages. Make one decision at a time"). The prep board's pieces,
-- each a step of its own in the frame game/ui/steps.lua draws, at the table with your friends:
--
--   This week          where the story stands (each hero's take on it, in a thought over their
--                      head), the group chat, each of the world's moves, levelling up, who the
--                      session is for, who shows up
--   The route          stop 1, 2 and 3 on the valley map
--   Stop 1, 2, 3       what kind of scene, who's there, what they're after, what gets in the way,
--                      what they can win, and the fight
--   Before the night   a seed, a spare evening, and tonight at a glance
--
-- The model is the same prep (game/model/prep.lua); its pieces draw from game/ui/prep_view.lua,
-- game/ui/valley_view.lua and game/ui/messages_view.lua. What your friends say comes from
-- game/data/setup_talk.lua.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local panels = require "game.ui.panels"
local steps = require "game.ui.steps"
local prefs = require "game.ui.prefs"
local content = require "game.model.content"
local util = require "game.model.util"
local score = require "game.model.score"
local talk = require "game.data.setup_talk"

local M = {}

local function prep_view()
    return require "game.ui.prep_view"
end
local ROUTE_ASIDE
local function valley_view()
    return require "game.ui.valley_view"
end

local function pr(app)
    return app.campaign.prep
end

-- Who's at the table this week (their bubbles).
local function here(app)
    local out = {}
    for _, p in ipairs(app.campaign.players) do
        if p.present and not p.on_break then
            table.insert(out, p.key)
        end
    end
    return out
end

local function staged(app)
    return prep_view().staged(app)
end

-- Little per-week flags for decisions that leave nothing behind in the prep ("nobody in
-- particular", "improvise it", "not this week"): kept with the week they were made in.
local function flag(app, name)
    local f = app.prep_flags
    if not f or f.week ~= app.campaign.week then
        f = { week = app.campaign.week }
        app.prep_flags = f
    end
    f[name] = f[name] or {}
    return f[name]
end

local function say(text, like)
    return { text = text, like = like }
end

local function think(text, like)
    return { text = text, like = like, think = true }
end

-- A kind of scene as they'd say it: "a fight", "a trek into the unknown".
local SCENE_WORD = {
    combat = "fight", social = "social scene", exploration = "trek into the unknown", puzzle = "puzzle",
    mystery = "mystery", downtime = "quiet scene", set_piece = "big set piece",
}
local function scene_word(t)
    return SCENE_WORD[t] or string.lower(content.scenes[t].name)
end

-- What's on a hero's mind: the moment of last session they'd remember, and how their own story
-- stands (October 26: "recap where the current campaign story is... how the player characters
-- have experienced it").
local function memory(app, p)
    local log = app.campaign.session_log or {}
    local last = log[#log]
    if not last then
        return nil
    end
    local best
    for _, b in ipairs(require("game.model.recap").kept(last.recap)) do
        if b.text and string.find(b.text, p.char, 1, true) then
            best = (not best or b.pinned) and b or best
        end
    end
    return best and best.text
end

local function mind(app, key)
    local p = app.campaign:player(key)
    if not p then
        return nil
    end
    local storylines = require "game.model.storylines"
    local heat = storylines.heat(app.campaign, "bs_" .. key)
    if heat == "ended" then
        heat = "resolved"
    end
    local line = (talk.mind[heat] or talk.mind.unopened)[key] or ""
    local mem = memory(app, p)
    local like = (heat == "warm" or heat == "resolved") and 1 or ((heat == "cold" or heat == "loose") and -1 or 0)
    return think((mem and ("Still thinking about it: " .. mem .. "\n") or "") .. line, like)
end

-- What they say about a kind of scene, and the one they'd most like.
local function type_talk(app, key, t)
    local p = app.campaign:player(key)
    local v = p and score.taste(p, t) or 0
    local tier = v >= 1.3 and "love" or (v >= 0.5 and "like" or (v >= -0.3 and "meh" or "bored"))
    local like = tier == "love" and 2 or (tier == "like" and 1 or (tier == "meh" and 0 or -1))
    return say(util.capitalize(util.fill(talk.types[tier][key], { type = scene_word(t) })), like)
end

local function favourite_type(app, key)
    local p = app.campaign:player(key)
    if not p then
        return nil
    end
    local best, bv
    for _, t in ipairs(content.scenes.order) do
        local v = score.taste(p, t)
        if not bv or v > bv then
            best, bv = t, v
        end
    end
    return best
end

-- A card on a stop: whoever would love it, or be bored by it, says so.
local function card_talk(app, key, c)
    local lean = prep_view().card_leans(app, c)[key]
    if lean == 1 then
        return say(util.fill(talk.cards.love[key], { card = c.name }), 1)
    elseif lean == -1 then
        return say(util.fill(talk.cards.bored[key], { card = c.name }), -1)
    end
    return nil
end

-- The top bar's right end: your prep hours and your notes.
local function header(app)
    local prep = pr(app)
    local left = math.max(0, prep:left())
    local x0 = 1020
    kit.text(x0, 12, "PREP TIME", "ui14", theme.dim)
    kit.text(x0 + 84, 12, util.int(left) .. (left == 1 and " hour left" or " hours left"), "ui14", theme.text)
    for i = 1, prep.budget do
        kit.box(x0 + (i - 1) * 15, 36, 12, 12, i <= left and theme.gold or theme.panel3, { radius = 3 })
    end
    local nw = kit.width("Notes (N)", "ui14") + 28
    kit.button(steps.header_right() - nw, 16, nw, 38, "Notes (N)", function()
        if app.open_notes then
            app.open_notes()
        end
    end, { font = "ui14", key = "prep_notes" })
end

local function stop_name(app, i)
    local s = pr(app).scenes[i]
    if s.module then
        return require("game.model.books").module(s.module.id).name
    elseif s.open then
        return "an open scene"
    end
    local loc = s.slots.location
    return loc and loc.name or ("stop " .. util.int(i))
end

-- This week -----------------------------------------------------------------------------------

-- A storyline's log, in your notes.
local function open_log(app, id)
    if id then
        app.storylog_id = id
    end
    app.storylog_scroll = nil
    if app.open_notes then
        app.open_notes("storylog")
    end
end

local function story_step()
    return {
        id = "story", section = "This week",
        ask = function(app)
            local beat = app.campaign:arc_beat()
            return "Session " .. util.int(app.campaign.week) .. (beat and (": " .. beat.title) or "")
        end,
        sub = function(app)
            local beat = app.campaign:arc_beat()
            return (beat and (beat.about .. " " .. beat.hint) or "The story carries on. Game night is Thursday.")
                .. " Your notes (N) have what to read out."
        end,
        talk = function(app, key)
            return mind(app, key)
        end,
        draw = function(app, a)
            local chronicle = require "game.model.chronicle"
            local pv = chronicle.previously(app.campaign) or {}
            local cw = math.floor((a.w - 40) / 2)
            local y = a.y
            kit.text(a.x, y, pv.label or "THE STORY SO FAR", "ui14", theme.gold)
            y = y + 24
            -- A line a scene, each under its storyline's mark: click one for that storyline's log.
            local marks = require "game.ui.lore_marks"
            for k, l in ipairs(pv.lines or {}) do
                if k > 6 then
                    break
                end
                local th = math.min(kit.text_height(l.text, "ui18", cw - 24), 2 * kit.line_height("ui18"))
                if y + th > a.y + a.h then
                    break
                end
                kit.button(a.x - 6, y - 3, cw + 12, th + 6, "", function()
                    open_log(app, l.id or pv.open)
                end, { color = kit.rgba("#000000", 0), hover = theme.button_hover, key = "prev_line_" .. k })
                local tx = a.x
                if l.id and marks.storyline(app, l.id, a.x, y + 3, 18) then
                    tx = a.x + 24
                end
                kit.text(tx, y, l.text, "ui18", (l.out == "lose") and theme.orange or theme.text, { w = cw - (tx - a.x), lines = 2 })
                y = y + th + 6
            end
            local rx = a.x + cw + 40
            local ry = a.y
            if pv.next then
                kit.text(rx, ry, "THIS WEEK THEY'RE OUT TO", "ui14", theme.gold)
                ry = ry + 24
                kit.text(rx, ry, pv.next, "ui22b", theme.text, { w = cw, lines = 3 })
                ry = ry + math.min(kit.text_height(pv.next, "ui22b", cw), 3 * kit.line_height("ui22b")) + 14
            end
            for k, n in ipairs(pv.new or {}) do
                local text = "New in the story: " .. n.text
                local th = math.min(kit.text_height(text, "ui14", cw - 24), 2 * kit.line_height("ui14"))
                kit.button(rx - 6, ry - 3, cw + 12, th + 6, "", function()
                    open_log(app, n.id)
                end, { color = kit.rgba("#000000", 0), hover = theme.button_hover, key = "prev_new_" .. k })
                marks.storyline(app, n.id, rx, ry + 1, 16)
                kit.text(rx + 22, ry, text, "ui14", theme.teal, { w = cw - 22, lines = 2 })
                ry = ry + th + 6
            end
            if pv.behind and #pv.behind > 0 and ry < a.y + a.h - 60 then
                kit.text(rx, ry + 4, "BEHIND THE SCREEN  (only you know)", "ui14", theme.orange)
                ry = ry + 28
                for _, b in ipairs(pv.behind) do
                    local text = b.text or ""
                    local th = math.min(kit.text_height(text, "ui14", cw), 2 * kit.line_height("ui14"))
                    if ry + th > a.y + a.h then
                        break
                    end
                    kit.text(rx, ry, text, "ui14", theme.dim, { w = cw, lines = 2 })
                    ry = ry + th + 4
                end
            end
        end,
    }
end

-- The group chat: everyone's latest message over their head, and what's waiting on you.
local function latest_post(app, key)
    local chat = app.campaign.chat or {}
    for i = #chat, 1, -1 do
        if chat[i].key == key then
            return chat[i]
        end
    end
end

local function chat_step()
    local messages_view = require "game.ui.messages_view"
    return {
        id = "chat", section = "This week",
        skip = function(app)
            return #(app.campaign.chat or {}) == 0 and #messages_view.rows(app) == 0
        end,
        ask = "The group chat",
        sub = "What everyone's said since last time. Answer anyone you like, or just read.",
        talk = function(app, key)
            local m = latest_post(app, key)
            return m and say(m.text, nil) or nil
        end,
        draw = function(app, a)
            local c = app.campaign
            local seeds_mod = require "game.model.seeds"
            -- Left: what's waiting on an answer (theories, and ones you could make true), or the
            -- conversation before everyone's latest. Right: private messages and posts you could make.
            local rows = messages_view.rows(app)
            local rw = #rows > 0 and 440 or 0
            local w = a.w - (rw > 0 and (rw + 24) or 0)
            local y = a.y
            local waiting = false
            for i, m in ipairs(c.chat or {}) do
                if m.choices and y + 70 <= a.y + a.h then
                    waiting = true
                    kit.box(a.x, y, w, 64, theme.panel2, { radius = 10 })
                    kit.text(a.x + 16, y + 8, m.who .. ": " .. m.text, "ui18", theme.text, { w = w - 400, lines = 2 })
                    if m.answered then
                        kit.text(a.x + w - 16, y + 22, m.made_true and "You made it true. They don't know yet." or ("You: " .. m.answered),
                            "ui14", theme.teal, { pivot = gui.PIVOT_NE, w = 360, lines = 2 })
                    else
                        local bw = 116
                        for k, label in ipairs(m.choices) do
                            local bx = a.x + w - 16 - (#m.choices - k + 1) * (bw + 6)
                            kit.button(bx, y + 16, bw, 32, label, function()
                                c:answer_chat(i, k)
                                app.refresh()
                            end, { font = "ui14", key = "chat_" .. i .. "_" .. k })
                        end
                    end
                    y = y + 72
                end
            end
            for _, th in ipairs(seeds_mod.pinned(c)) do
                if y + 50 <= a.y + a.h then
                    waiting = true
                    local claim = seeds_mod.claim(th)
                    local p = c:player(th.key)
                    local ok, why = seeds_mod.can_steal(c, th)
                    kit.box(a.x, y, w, 44, kit.rgba("#f3df8a"), { radius = 8 })
                    kit.text(a.x + 16, y + 12, "THEORY: " .. (p and p.name or "?") .. ": " .. (claim and claim.says or ""), "ui14", theme.ink,
                        { w = w - 220, lines = 1 })
                    kit.button(a.x + w - 186, y + 7, 170, 30, "Make it true", function()
                        local done, msg = seeds_mod.steal(c, th)
                        local who = p and p.name or "They"
                        app.toast = done and ("Canon now: when \"" .. content.seeds[th.seed].name .. "\" pays off, it proves " .. who
                            .. " right.") or msg
                        app.toast_tone = done and "info" or nil
                        app.refresh()
                    end, { font = "ui14", enabled = ok, color = theme.go, hover = theme.go_hover, key = "steal_" .. th.seed })
                    if not ok and why then
                        kit.text(a.x + w - 196, y + 14, why, "ui14", theme.ink_dim, { pivot = gui.PIVOT_NE, w = 300, lines = 1 })
                    end
                    y = y + 52
                end
            end
            if not waiting then
                -- Nothing to answer: what was said before everyone's latest (their latest is in the bubbles).
                local latest = {}
                for _, p in ipairs(c.players) do
                    local m = latest_post(app, p.key)
                    if m then
                        latest[m] = true
                    end
                end
                local earlier = {}
                for k = #(c.chat or {}), 1, -1 do
                    local m = c.chat[k]
                    if not latest[m] and #earlier < 5 then
                        table.insert(earlier, 1, m)
                    end
                end
                if #earlier > 0 then
                    kit.text(a.x, y, "EARLIER", "ui14", theme.gold)
                    y = y + 22
                    for _, m in ipairs(earlier) do
                        local line = (m.who or "?") .. ": " .. (m.text or "")
                        local th = math.min(kit.text_height(line, "ui18", w), 2 * kit.line_height("ui18"))
                        if y + th > a.y + a.h then
                            break
                        end
                        kit.text(a.x, y, line, "ui18", theme.dim, { w = w, lines = 2 })
                        y = y + th + 6
                    end
                else
                    kit.text(a.x, y, "Nothing waiting on an answer. Their latest is over their heads.", "ui18", theme.faint, { w = w })
                end
            end
            if rw > 0 then
                local rx = a.x + a.w - rw
                kit.text(rx, a.y, "MESSAGES", "ui14", theme.gold)
                local ry = a.y + 24
                for _, r in ipairs(rows) do
                    if ry + 52 <= a.y + a.h then
                        kit.button(rx, ry, rw, 52, "", function()
                            messages_view.open(app, r.id)
                        end, { color = r.state == "New" and kit.rgba("#4a3a1c") or theme.panel2, hover = theme.button_hover,
                               key = "convo_" .. r.id })
                        kit.text(rx + 12, ry + 6, r.title, "ui18b", r.state == "New" and theme.gold or theme.text, { w = rw - 100, lines = 1 })
                        kit.text(rx + rw - 12, ry + 8, r.state, "ui14", theme.dim, { pivot = gui.PIVOT_NE })
                        kit.text(rx + 12, ry + 30, r.preview or "", "ui14", theme.dim, { w = rw - 24, lines = 1 })
                        ry = ry + 58
                    end
                end
            end
        end,
    }
end

-- Your friends: how each of them is doing, and a coffee with one (the prep board's player cards).
local MOOD_SAYS = {
    tired = "Long week. I'm running on fumes.",
    celebrating = "Best week in ages! Ask me why.",
    stressed = "Work's been a lot. I need Thursday.",
    chatty = "Oh, I've got so much to tell everyone.",
    distracted = "Sorry, what? One sec, my phone...",
}

local function friend_card(app, prep, p, x, y, w, h)
    local pv = prep_view()
    local empathy = require "game.model.empathy"
    local level = app.campaign:empathy()
    kit.box(x, y, w, h, theme.panel2, { radius = 10 })
    -- Their face and name: click for the character sheet.
    kit.button(x + 4, y + 4, w - 120, 44, "", function()
        if app.open_sheet then
            app.open_sheet(p.key)
        end
    end, { color = theme.panel2, hover = theme.button_hover, radius = 8, key = "sheet_" .. p.key })
    kit.dot(x + 28, y + 26, 38, panels.COLORS[p.key] or theme.panel3)
    kit.picture(x + 12, y + 10, 32, 32, panels.face(p.key))
    kit.text(x + 54, y + 8, p.name, "ui18b", theme.text)
    kit.text(x + 54, y + 30, kit.ellipsize(p.char .. ", " .. p.class_name, "ui14", w - 180), "ui14", theme.dim)
    local talked = prep.talked[p.key]
    if p.on_break then
        kit.button(x + w - 112, y + 10, 100, 32, talked and "Checked in" or "Check in  2h", function()
            if prep:talk(p.key) then
                app.refresh()
            end
        end, { font = "ui14", enabled = (not talked) and prep:can_talk(p.key), key = "talk_" .. p.key })
        kit.text(x + 14, y + 60, "Taking a break from Thursdays.", "ui18", theme.orange, { w = w - 28 })
        kit.text(x + 14, y + 88, talked and "You checked in. They'll be back sooner, and they know they're missed."
            or "A check-in brings them back sooner. They'll come back either way.", "ui14", theme.dim, { w = w - 28, lines = 3 })
        return
    elseif not p.present then
        kit.text(x + 14, y + 60, "Can't make it this week.", "ui18", theme.orange, { w = w - 28 })
        local warn = empathy.warning(level, p)
        kit.text(x + 14, y + 88, (warn and pv.WARNINGS[warn]) or p.notes, "ui14", warn and theme.orange or theme.faint,
            { w = w - 28, lines = 3 })
        return
    end
    if not staged(app) then
        kit.button(x + w - 112, y + 10, 100, 32, talked and "Talked" or "Coffee  2h", function()
            require("game.ui.talk_view").open(app, p.key)
        end, { font = "ui14", enabled = (not talked) and prep:can_talk(p.key), key = "talk_" .. p.key })
    end
    local yy = y + 58
    -- What a one-on-one told you, a warning, a feud, or their notes.
    local learned = require("game.model.one_on_one").summary(prep.talk_notes and prep.talk_notes[p.key])
    local warn = empathy.warning(level, p)
    local feud = pv.feud_line(app, p)
    local line, col = p.notes, theme.dim
    if learned then
        line, col = learned, theme.teal
    elseif warn and pv.WARNINGS[warn] then
        line, col = pv.WARNINGS[warn] .. (feud and (" " .. feud) or ""), theme.orange
    elseif feud then
        line, col = feud .. " " .. pv.short_notes(p), theme.orange
    end
    kit.text(x + 14, yy, line, "ui14", col, { w = w - 28, lines = 2 })
    yy = yy + 2 * kit.line_height("ui14") + 8
    local mood = score.mood(p)
    kit.text(x + 14, yy, p.mood_known and ("This week: " .. mood.name) or "This week: ?", "ui14",
        p.mood_known and theme.text or theme.faint)
    pv.goodwill(app, p, x + w - 112, yy)
    yy = yy + 28
    if staged(app) then
        -- Week 1: what kind of scene they love and which bore them, where the long-term bars go later.
        local loves, bored = {}, {}
        for _, id in ipairs(content.scenes.order) do
            local t = score.taste(p, id)
            if t >= 1 then
                table.insert(loves, { id, t })
            elseif t < 0 then
                table.insert(bored, { id, t })
            end
        end
        table.sort(loves, function(a, b) return a[2] > b[2] end)
        table.sort(bored, function(a, b) return a[2] < b[2] end)
        local function names(list)
            local out = {}
            for k, e in ipairs(list) do
                if k <= 2 then
                    table.insert(out, content.scenes[e[1]].name)
                end
            end
            return #out > 0 and table.concat(out, ", ") or nil
        end
        kit.text(x + 14, yy, "Loves: " .. (names(loves) or "a bit of everything"), "ui14", theme.text, { w = w - 28, lines = 1 })
        kit.text(x + 14, yy + 22, "Bored by: " .. (names(bored) or "nothing much"), "ui14", theme.dim, { w = w - 28, lines = 1 })
    else
        -- The long-term bars, as well as your Empathy lets you read them.
        local idx = 1
        for k, p2 in ipairs(app.campaign.players) do
            if p2 == p then
                idx = k
            end
        end
        for k, b in ipairs({ "commitment", "trust", "investment", "suspicion" }) do
            pv.long_bar(app, p, idx, b, x + 14, yy + 4 + (k - 1) * 22)
        end
    end
end

local function friends_step()
    return {
        id = "friends", section = "This week",
        ask = "How's everyone doing?",
        sub = function(app)
            if staged(app) then
                return "Your friends, and what they like. Click a face for their character sheet."
            end
            local empathy = require "game.model.empathy"
            return "As well as you read them (Empathy: " .. empathy.NAMES[app.campaign:empathy()] .. "). Coffee with one "
                .. "of them (2 hours) finds out how their week went. Weeks of low Commitment and someone takes a break."
        end,
        talk = function(app, key)
            local p = app.campaign:player(key)
            if p and p.mood_known and MOOD_SAYS[p.mood] then
                return say(MOOD_SAYS[p.mood], (p.mood == "celebrating" or p.mood == "chatty") and 1 or -1)
            end
        end,
        draw = function(app, a)
            local prep = pr(app)
            local list = {}
            for _, p in ipairs(app.campaign.players) do
                table.insert(list, { p = p })
            end
            for _, j in ipairs(app.campaign.joining and app.campaign:joining() or {}) do
                table.insert(list, { j = j })
            end
            local n = math.min(4, #list)
            local gap = 12
            local w = math.floor((a.w - (n - 1) * gap) / n)
            local h = a.h - 4
            for k, e in ipairs(list) do
                if k <= 4 then
                    local x = a.x + (k - 1) * (w + gap)
                    if e.p then
                        friend_card(app, prep, e.p, x, a.y, w, h)
                    else
                        -- Who's joining later (a small table): their chair, waiting.
                        local d = content.players[e.j.key]
                        kit.box(x, a.y, w, h, kit.rgba("#000000", 0.18), { radius = 10 })
                        kit.dot(x + 28, a.y + 26, 38, panels.COLORS[e.j.key] or theme.panel3)
                        kit.picture(x + 12, a.y + 10, 32, 32, panels.face(e.j.key))
                        kit.text(x + 54, a.y + 8, d.name, "ui18b", theme.dim)
                        kit.text(x + 54, a.y + 30, d.char .. ", " .. d.class_name, "ui14", theme.faint, { w = w - 68, lines = 1 })
                        kit.text(x + 14, a.y + 62, "Joins the table in session " .. util.int(e.j.week) .. ".", "ui18", theme.gold,
                            { w = w - 28 })
                        kit.text(x + 14, a.y + 92, (d.gist and (d.gist .. ". ") or "") .. "You'll hear their story before that week.",
                            "ui14", theme.faint, { w = w - 28, lines = 3 })
                    end
                end
            end
        end,
    }
end

-- Each of the world's moves, off screen.
local function world_step(i)
    local function move(app)
        local wd = require("game.model.world").get(app.campaign)
        return wd.week == app.campaign.week and wd.moves[i] or nil, wd
    end
    return {
        id = "world_" .. i, section = "This week",
        skip = function(app)
            return staged(app) or move(app) == nil
        end,
        ask = function(app)
            local m = move(app)
            local world = require "game.model.world"
            local ledger = require "game.model.ledger"
            return ledger.data[m.faction].name .. ": " .. world.move_def(m.faction, m.move).name
        end,
        sub = "Every faction makes a move off screen. Only you see this: decide what happens to this one.",
        done = function(app)
            local m = move(app)
            return m ~= nil and m.state ~= "pending"
        end,
        need = "Let it happen, bring it on screen, or hold it.",
        draw = function(app, a)
            local c = app.campaign
            local world = require "game.model.world"
            local ledger = require "game.model.ledger"
            local m, wd = move(app)
            local fd = ledger.data[m.faction]
            local mv = world.move_def(m.faction, m.move)
            local card = world.screen_card(c, m.faction, mv)
            local taken = false
            for _, o in ipairs(wd.moves) do
                taken = taken or (o.state == "screen" and o ~= m)
            end
            local function act(choice)
                return function()
                    local ok, why = world.decide(c, i, choice)
                    if not ok then
                        app.toast = why
                    end
                    app.refresh()
                end
            end
            if m.state ~= "pending" then
                local card_on = m.card and content.components[m.card]
                local text = (m.state == "hold" and "Held. It comes back next week.")
                    or (m.state == "screen" and not m.settled and ("On screen: \"" .. (card_on and card_on.name or "?")
                        .. "\" is in your hand. Put it on a stop: the party decides it."))
                    or m.text or ""
                local head = ({ let = "You rolled for it behind the screen.", hold = "Held.", screen = "On screen." })[m.state] or ""
                kit.text(a.x, a.y, head, "ui14", theme.gold)
                local ty = a.y + 24
                if m.state == "let" and m.dice then
                    require("game.ui.notebook_pages").move_result(a.x, ty, m)
                    ty = ty + 34
                end
                kit.text(a.x, ty, text, "ui22b", theme.text, { w = a.w, lines = 3 })
                -- (A roll can't be taken back; a hold or a card on screen can.)
                if m.state == "hold" or (m.state == "screen" and not m.settled) then
                    kit.button(a.x, a.y + 124, 200, 40, "Undo", act("undo"), { font = "ui18b", key = "world_undo_" .. util.int(i) })
                end
                return
            end
            local items = {
                { title = "Let it happen", key = "world_let_" .. util.int(i), click = act("let"),
                  body = "You roll for it behind the screen: " .. (fd.tier == 1 and "one die" or (util.int(fd.tier) .. " dice, keep the highest"))
                      .. ". On a 6 they pull it off, on a 4 or 5 half of it works, on 1 to 3 it backfires." },
                { title = "Bring it on screen", key = "world_screen_" .. util.int(i), click = act("screen"),
                  enabled = card ~= nil and not taken,
                  body = (taken and "One move on screen a week, and another one is. " or "")
                      .. (card and ("It comes into your hand as \"" .. card.name .. "\". Put it on a stop: if the party wins it, it goes badly for "
                      .. fd.short .. "; if they lose, it works.") or "There's no card for this move this week.") },
                { title = "Hold it", key = "world_hold_" .. util.int(i), click = act("hold"),
                  enabled = wd.holds < ledger.data.HOLDS, body = "It waits a week. You can hold " .. util.int(ledger.data.HOLDS)
                      .. " a week." },
            }
            steps.cards(app, a, items, { cols = 3, title_font = "ui18b", body_font = "ui14" })
        end,
    }
end

local function levelup_step()
    local function ready(app)
        return app.campaign:level_status().ready
    end
    return {
        id = "levelup", section = "This week",
        skip = function(app)
            return not ready(app) and flag(app, "levelled").done == nil
        end,
        ask = function(app)
            local lv = app.campaign:level_status()
            return lv.ready and ("The party's ready for level " .. util.int(lv.level + 1)) or ("The party is level " .. util.int(lv.level))
        end,
        sub = function(app)
            return app.campaign:level_status().overdue and "They've earned it, and they're starting to ask." or "They've earned it."
        end,
        talk = function(app, key)
            return ready(app) and say(talk.levelup[key], 2) or nil
        end,
        draw = function(app, a)
            local lv = app.campaign:level_status()
            if lv.ready then
                kit.button(a.x, a.y, 360, 64, "Level up to " .. util.int(lv.level + 1), function()
                    flag(app, "levelled").done = true
                    require("game.ui.levelup_view").level_up(app)
                end, { font = "ui22b", color = theme.go, hover = theme.go_hover, key = "level_up" })
                kit.text(a.x + 380, a.y + 20, "Or leave it for now: it'll wait.", "ui18", theme.dim)
            else
                kit.text(a.x, a.y, "Done: the party is level " .. util.int(lv.level) .. ".", "ui22b", theme.teal)
            end
        end,
    }
end

local function spotlight_step()
    return {
        id = "spotlight", section = "This week",
        skip = function(app)
            return staged(app)
        end,
        ask = "Who's this session for?",
        sub = "One player's story gets the night. Their next card goes on the board for you.",
        done = function(app)
            return pr(app).spot ~= nil or flag(app, "spot").none
        end,
        need = "Pick a player, or nobody in particular.",
        talk = function(app, key)
            local prep = pr(app)
            if prep.spot then
                if prep.spot == key then
                    return say(talk.spotlight.mine[key], 2)
                end
                local p = app.campaign:player(prep.spot)
                return say(util.fill(talk.spotlight.other[key], { char = p and p.char or "" }), 0)
            end
            local card = prep:spotlight_card(key)
            return card and think("Next for me: " .. card.name .. "?") or nil
        end,
        draw = function(app, a)
            local prep = pr(app)
            local items = {}
            for _, p in ipairs(app.campaign.players) do
                local card = p.present and prep:spotlight_card(p.key) or nil
                local on = prep.spot == p.key
                table.insert(items, {
                    title = p.char, body = card and ("Next: " .. card.name) or (p.present and "Nothing in their story is ready this week."
                        or "Out this week."),
                    on = on, enabled = card ~= nil or on, key = "spot_" .. p.key, title_pad = 50,
                    click = function()
                        flag(app, "spot").none = nil
                        if on then
                            prep:clear_spotlight()
                        else
                            local ok, why = prep:spotlight(p.key)
                            if not ok then
                                app.toast = why
                            end
                        end
                        app.refresh()
                    end,
                    deco = function(x, y, w)
                        kit.dot(x + w - 30, y + 30, 40, panels.COLORS[p.key] or theme.panel3)
                        kit.picture(x + w - 46, y + 14, 32, 32, panels.face(p.key))
                    end,
                })
            end
            table.insert(items, {
                title = "Nobody in particular", body = "Everyone shares the night.", on = flag(app, "spot").none and not prep.spot,
                key = "spot_none",
                click = function()
                    if prep.spot then
                        prep:clear_spotlight()
                    end
                    flag(app, "spot").none = true
                    app.refresh()
                end,
            })
            steps.cards(app, a, items, { cols = #items, title_font = "ui18b", body_font = "ui14" })
        end,
    }
end

local function guests_step()
    local ledger = require "game.model.ledger"
    return {
        id = "guests", section = "This week",
        skip = function(app)
            local o = pr(app):guest_options()
            return staged(app) or (#o.people == 0 and #o.places == 0)
        end,
        ask = "Who shows up?",
        sub = function(app)
            return "Bring back people the party has met (a favour if they like the party, trouble if they don't), or places "
                .. "they've been. Up to " .. util.int(ledger.data.GUESTS) .. ", or nobody."
        end,
        draw = function(app, a)
            local prep = pr(app)
            local c = app.campaign
            local items = {}
            for k, pid in ipairs(prep:guest_options().people) do
                if k <= 8 then
                    local on = prep.guests[pid] ~= nil
                    local ab = ledger.about(pid)
                    local label = ledger.label(ledger.att(c, pid))
                    local st = ledger.status(c, pid)
                    table.insert(items, {
                        title = ab.name, body = st == "got away" and "Got away last time" or label, on = on, key = "guest_" .. pid,
                        click = function()
                            if on then
                                prep:send_home(pid)
                            else
                                local ok, why = prep:bring_in(pid)
                                if not ok then
                                    app.toast = why
                                end
                            end
                            app.refresh()
                        end,
                    })
                end
            end
            local y = a.y
            if #items > 0 then
                y = steps.cards(app, a, items, { cols = math.min(4, #items), title_font = "ui18b", body_font = "ui14" })
            end
            -- Places they've been, to go back to.
            local places = prep:guest_options().places
            if #places > 0 and y + 40 <= a.y + a.h then
                kit.text(a.x, y + 6, "PLACES", "ui14", theme.gold)
                local cx, cy = a.x + kit.width("PLACES", "ui14") + 16, y
                for _, card in ipairs(places) do
                    local label = card.short and util.capitalize(card.short) or card.name
                    local bw = kit.width(label, "ui14") + 24
                    if cx + bw > a.x + a.w then
                        cx, cy = a.x + kit.width("PLACES", "ui14") + 16, cy + 38
                    end
                    if cy + 32 > a.y + a.h then
                        break
                    end
                    local on = prep.guests[card.id] ~= nil
                    kit.button(cx, cy, bw, 32, label, function()
                        if on then
                            prep:send_home(card.id)
                        else
                            local ok, why = prep:bring_in(card.id)
                            if not ok then
                                app.toast = why
                            end
                        end
                        app.refresh()
                    end, { font = "ui14", color = on and theme.go or theme.panel2, hover = theme.button_hover, key = "guest_" .. card.id })
                    cx = cx + bw + 8
                end
            end
        end,
    }
end

-- The route ----------------------------------------------------------------------------------

-- Beside the map: what you've settled this week that the route should serve.
local function aside_block(x, y, w, label, text, color)
    kit.text(x, y, label, "ui14", theme.gold)
    y = y + 22
    kit.text(x, y, text, "ui18", color or theme.text, { w = w, lines = 4 })
    return y + math.min(kit.text_height(text, "ui18", w), 4 * kit.line_height("ui18")) + 18
end

ROUTE_ASIDE = {
    x = 1196, w = 380,
    draw = function(app, x, y, w, h)
        local c = app.campaign
        local prep = pr(app)
        kit.box(x, y, w, 472, theme.panel, { radius = 10 })
        x, w, y = x + 16, w - 32, y + 14
        local beat = c:arc_beat()
        local pv = require("game.model.chronicle").previously(c) or {}
        if pv.next then
            y = aside_block(x, y, w, "THIS WEEK THEY'RE OUT TO", pv.next)
        elseif beat then
            y = aside_block(x, y, w, "THIS WEEK'S STORY", beat.about)
        end
        if prep.spot then
            local p = c:player(prep.spot)
            local card = prep:spotlight_card(prep.spot)
            y = aside_block(x, y, w, "FOR " .. string.upper(p and p.char or ""), card and ("Their story: " .. card.name
                .. ". It's in your hand.") or "Their night.")
        end
        local wd = require("game.model.world").get(c)
        for _, m in ipairs(wd.week == c.week and wd.moves or {}) do
            local card = m.state == "screen" and m.card and content.components[m.card]
            if card then
                y = aside_block(x, y, w, "ON SCREEN", "\"" .. card.name .. "\" is in your hand. Put it on a stop.", theme.teal)
            end
        end
        local names = {}
        for id in pairs(prep.guests or {}) do
            local ab = require("game.model.ledger").about(id)
            table.insert(names, ab and ab.name or (content.components[id] and content.components[id].name) or id)
        end
        table.sort(names)
        if #names > 0 and y < 470 then
            y = aside_block(x, y, w, "SHOWING UP", util.join_names(names) .. ".")
        end
        if y < 470 then
            aside_block(x, y, w, "TIP", "A place with a number on the map has that many of your cards happening there.", theme.dim)
        end
    end,
}

local function route_step(i)
    local function stop(app)
        return pr(app).scenes[i]
    end
    return {
        id = "route_" .. i, section = "The route", layout = "full", x = 24, w = 320,
        aside = ROUTE_ASIDE,
        skip = function(app)
            return stop(app) == nil
        end,
        ask = "Stop " .. util.int(i) .. ": where does the party go?",
        sub = function(app)
            local s = stop(app)
            if app.campaign.week == 1 and i == 1 then
                return "Every campaign starts at the Kettle. It's stop 1 already; you can still move it."
            elseif s.open then
                return "The players choose where to go: sketch a few spots they might."
            end
            return "Click a place on the valley map to see what's there, then make it stop " .. util.int(i) .. "."
        end,
        done = function(app)
            local s = stop(app)
            return s.slots.location ~= nil or s.module ~= nil or (s.open and #(s.spots or {}) > 0)
        end,
        need = function(app)
            return stop(app).open and "Sketch a spot or two." or "Pick a place on the map."
        end,
        enter = function(app)
            app.hand_page = nil
            app.route_stop = i
            local st = valley_view().state(app)
            st.open = nil
            st.stop = i
        end,
        draw = function(app, a)
            local prep = pr(app)
            local s = stop(app)
            app.route_stop = i
            -- The route so far, down the left.
            local y = a.y
            kit.text(a.x, y, "TONIGHT'S ROUTE", "ui14", theme.gold)
            y = y + 26
            for k = 1, #prep.scenes do
                local sk = prep.scenes[k]
                local set = sk.slots.location or sk.module or (sk.open and #(sk.spots or {}) > 0)
                kit.dot(a.x + 14, y + 14, 26, k == i and theme.gold or (set and theme.teal or theme.panel3))
                kit.text(a.x + 14, y + 14, util.int(k), "ui14", theme.ink, { pivot = gui.PIVOT_CENTER })
                kit.text(a.x + 36, y + 4, set and stop_name(app, k) or "Not chosen yet", "ui18", set and theme.text or theme.faint,
                    { w = a.w - 40, lines = 1 })
                y = y + 36
            end
            y = y + 10
            -- Or let the players choose (A15).
            kit.button(a.x, y, a.w, 40, s.open and "Open scene: the players choose (on)" or "Or let the players choose",
                function()
                    prep:set_open(i, not s.open)
                    app.refresh()
                end, { font = "ui14", color = s.open and theme.decision.agency or theme.panel2, key = "open_scene" })
            if s.open then
                -- Their spots, from the hand, your places, or the notes' suggestions.
                app.sel = { scene = i, kind = "location" }
                app.loc_tab = app.loc_tab or (#prep:spot_suggestions(i) > 0 and "suggested" or nil)
                app.hand_rect = { x = 364, y = 84, w = 812, h = 472 }
                prep_view().hand_drawer(app, prep, s, app.sel, "location", nil)
                app.hand_rect = nil
                return
            end
            -- The valley, and the place you've opened (or a note to pick one).
            valley_view().draw(app, prep)
            if not valley_view().side(app, prep) then
                local x, w = 920, 256
                kit.box(x, 84, w, 472, theme.paper, { radius = 10 })
                kit.text(x + 14, 100, "STOP " .. util.int(i), "ui14", theme.ink_dim)
                local loc = s.slots.location
                kit.text(x + 14, 124, loc and loc.name or "Pick a place", "ui22b", theme.ink, { w = w - 28 })
                kit.text(x + 14, 190, loc and "Click it on the map to see what's there, or pick another place."
                    or "Click a place on the map, or one below. Its card shows what happens there.", "ui14", theme.ink_dim,
                    { w = w - 28 })
            end
            -- Under the map, every place in play as a card: the most going on first.
            local valley = require "game.model.valley"
            local list = {}
            for id in pairs(valley.visible(app.campaign, prep)) do
                local card = content.components[id]
                if card then
                    table.insert(list, { id = id, card = card, n = #valley.cards_for(prep, id), stops = valley.stops_at(prep, id) })
                end
            end
            table.sort(list, function(p, q)
                if (#p.stops > 0) ~= (#q.stops > 0) then
                    return #p.stops > 0
                elseif p.n ~= q.n then
                    return p.n > q.n
                end
                return p.card.name < q.card.name
            end)
            local px, py, pw = 364, 572, 1212
            kit.text(px, py, "PLACES IN PLAY", "ui14", theme.gold)
            local cw, ch, gap = 196, 58, 7
            local cols = math.floor((pw + gap) / (cw + gap))
            local open_id = valley_view().state(app).open
            for k, e in ipairs(list) do
                local col, row = (k - 1) % cols, math.floor((k - 1) / cols)
                local bx, by = px + col * (cw + gap), py + 24 + row * (ch + gap)
                if by + ch > 826 then
                    break
                end
                local sub
                if #e.stops > 0 then
                    sub = "Stop " .. util.int(e.stops[1])
                elseif e.n > 0 then
                    sub = util.int(e.n) .. (e.n == 1 and " card happens here" or " cards happen here")
                elseif require("game.model.places").is_known(app.campaign, e.id) then
                    sub = "Been there: free"
                else
                    sub = util.int(prep:cost_of(e.card)) .. "h to prep"
                end
                kit.button(bx, by, cw, ch, "", function()
                    valley_view().open_place(app, e.id)
                    app.refresh()
                end, { color = open_id == e.id and theme.panel3 or theme.panel2, hover = theme.button_hover, radius = 8,
                       key = "route_place_" .. e.id })
                kit.text(bx + 10, by + 7, e.card.name, "ui14", theme.text, { w = cw - 20, lines = 1 })
                kit.text(bx + 10, by + 31, sub, "ui14", #e.stops > 0 and theme.gold or (e.n > 0 and theme.teal or theme.dim),
                    { w = cw - 20, lines = 1 })
            end
        end,
    }
end

-- Each stop ------------------------------------------------------------------------------------

local function stop_section(i)
    return "Stop " .. util.int(i)
end

local function type_step(i)
    local function stop(app)
        return pr(app).scenes[i]
    end
    return {
        id = "type_" .. i, section = stop_section(i),
        skip = function(app)
            local s = stop(app)
            return s == nil or s.open
        end,
        ask = function(app)
            return "Stop " .. util.int(i) .. ", " .. util.lower_first(stop_name(app, i)) .. ": what kind of scene?"
        end,
        sub = function(app)
            local sm = require "game.model.styles"
            local usual = sm.usual_types(app.campaign, 3)
            local names = {}
            for _, t in ipairs(usual) do
                table.insert(names, string.lower(content.scenes[t].name))
            end
            return "Everyone loves some kinds of scene and gets bored in others." .. (#names > 0 and (" Usual in "
                .. sm.def(sm.current(app.campaign)).name .. ": " .. util.join_names(names) .. ".") or "")
        end,
        done = function(app)
            local s = stop(app)
            return s.type ~= nil or s.module ~= nil
        end,
        need = "Pick a kind of scene.",
        talk = function(app, key)
            local s = stop(app)
            if s.type then
                return type_talk(app, key, s.type)
            end
            local fav = favourite_type(app, key)
            return fav and think("I'd love a " .. scene_word(fav) .. ".") or nil
        end,
        draw = function(app, a)
            local prep = pr(app)
            local s = stop(app)
            local pv = prep_view()
            local items = {}
            for _, key in ipairs(content.scenes.order) do
                local st = content.scenes[key]
                table.insert(items, {
                    title = st.name, body = st.short or st.blurb, on = s.type == key and not s.module, key = "type_" .. util.int(i) .. "_" .. key,
                    color = s.type == key and theme.scene[key] or nil, extra_h = prefs.chill() and 30 or 0,
                    click = function()
                        if s.module then
                            prep:clear_module(i)
                        end
                        prep:set_type(i, key)
                        app.refresh()
                    end,
                    deco = function(x, y, w, h)
                        for d = 1, 5 do
                            kit.dot(x + w - 14 - (5 - d) * 11, y + 22, 8, d <= st.tension and theme.text or kit.rgba("#000000", 0.25))
                        end
                        pv.faces(app, x + 12, y + h - 32, pv.type_leans(app, key), 20)
                    end,
                })
            end
            local y = steps.cards(app, a, items, { cols = #items, title_font = "ui18b", body_font = "ui14", gap = 8 })
            -- Published adventures from your books (A13): the whole scene, ready to run.
            local books_mod = require "game.model.books"
            local mods = books_mod.modules(app.campaign)
            if (#mods > 0 or s.module) and y + 40 <= a.y + a.h then
                kit.text(a.x, y + 8, "OR RUN A PUBLISHED ADVENTURE", "ui14", theme.gold)
                local mx = a.x + kit.width("OR RUN A PUBLISHED ADVENTURE", "ui14") + 16
                for _, mid in ipairs(mods) do
                    local m = books_mod.module(mid)
                    local label = m.name .. "  " .. util.int(content.books.MODULE_COST) .. "h"
                    local on = s.module and s.module.id == mid
                    local ok = prep:can_place_module(i, mid)
                    local bw = kit.width(label, "ui14") + 28
                    kit.button(mx, y, bw, 32, label, function()
                        if on then
                            prep:clear_module(i)
                        else
                            local placed, why = prep:place_module(i, mid)
                            if not placed then
                                app.toast = why
                            end
                        end
                        app.refresh()
                    end, { font = "ui14", color = on and theme.go or theme.decision.agency, hover = theme.button_hover,
                           enabled = ok or on, key = "module_" .. mid })
                    mx = mx + bw + 8
                end
            end
        end,
    }
end

local ASK = {
    cast = "Who's there?",
    goal = "What are they after?",
    complication = "What gets in the way?",
    reward = "What can they win?",
}
local SUB = {
    cast = "Someone for the party to meet, trust, or fight.",
    goal = "What the party sets out to do here. Leave it empty and they'll find one at the table.",
    complication = "The twist: what makes it harder than it looks.",
    reward = "What they get if it goes well.",
}

local function slot_step(i, kind)
    local function stop(app)
        return pr(app).scenes[i]
    end
    return {
        id = "slot_" .. i .. "_" .. kind, section = stop_section(i),
        skip = function(app)
            local s = stop(app)
            if s and s.module then
                -- A published adventure (A13): its person and its reward can be made yours.
                return not (kind == "cast" or kind == "reward")
            end
            return s == nil or s.open or s.type == nil
        end,
        ask = function(app)
            if stop(app).module then
                return kind == "cast" and "Recast its person?" or "Swap its reward?"
            end
            return ASK[kind]
        end,
        sub = function(app)
            if stop(app).module then
                return "Stop " .. util.int(i) .. ", " .. stop_name(app, i) .. ". Or keep the book's: it's ready to run."
            end
            return "Stop " .. util.int(i) .. ", " .. util.lower_first(stop_name(app, i)) .. ". " .. SUB[kind]
        end,
        done = function(app)
            local s = stop(app)
            return s.module ~= nil or s.slots[kind] ~= nil or flag(app, "improvise")[i .. kind] == true
        end,
        need = "Pick a card, or improvise it.",
        enter = function(app)
            app.hand_page = nil      -- (each slot's hand starts on its first page)
        end,
        talk = function(app, key)
            local s = stop(app)
            local c = s.slots[kind]
            if c then
                return card_talk(app, key, c)
            elseif s.module then
                return nil
            end
            -- Nothing picked yet: the card in your hand they're hoping for, if there is one.
            local prep = pr(app)
            for _, h in ipairs(prep.hand[kind] or {}) do
                if not prep:placed_at(h.id) and prep_view().card_leans(app, h)[key] == 1 then
                    return think(util.fill(talk.cards.hope[key], { card = h.name }), 1)
                end
            end
        end,
        draw = function(app, a)
            local prep = pr(app)
            local s = stop(app)
            if s.module then
                app.sel = { scene = i, kind = kind }
                app.hand_rect = { x = a.x - 16, y = a.y - 8, w = a.w + 16, h = a.h }
                prep_view().module_drawer(app, prep, s, app.sel, kind)
                app.hand_rect = nil
                return
            end
            local improv = flag(app, "improvise")
            -- Improvise it: nothing on the slot, and the night makes it up.
            local on = improv[i .. kind] and not s.slots[kind]
            kit.button(a.x + a.w - 330, a.y, 330, 34, on and "Improvising it at the table" or "Leave it: improvise it at the table",
                function()
                    if s.slots[kind] then
                        prep:clear(i, kind)
                    end
                    improv[i .. kind] = true
                    app.refresh()
                end, { font = "ui14", color = on and theme.go or theme.panel2, hover = theme.button_hover, key = "improvise_" .. kind })
            app.sel = { scene = i, kind = kind }
            app.hand_rect = { x = a.x - 14, y = a.y - 4, w = a.w - 340, h = a.h }
            prep_view().hand_drawer(app, prep, s, app.sel, kind, s.slots[kind])
            app.hand_rect = nil
            if s.slots[kind] then
                improv[i .. kind] = nil
            end
        end,
    }
end

local function fight_step(i)
    local function stop(app)
        return pr(app).scenes[i]
    end
    return {
        id = "fight_" .. i, section = stop_section(i),
        skip = function(app)
            local s = stop(app)
            return s == nil or s.open or not (s.type == "combat" or s.type == "set_piece")
        end,
        ask = function(app)
            return "Stop " .. util.int(i) .. ": the fight"
        end,
        sub = "There's a fight suggested for this stop, built around the party. Build your own, or keep it.",
        talk = function(app, key)
            return type_talk(app, key, stop(app).type)
        end,
        draw = function(app, a)
            local prep = pr(app)
            local enc = prep:encounter(i)
            local names = require("game.ui.notes_view").monster_list(enc.ids)
            kit.text(a.x, a.y, (enc.built and "YOUR FIGHT" or "THE SUGGESTED FIGHT"), "ui14", theme.gold)
            kit.text(a.x, a.y + 26, names, "ui22b", theme.text, { w = a.w })
            kit.button(a.x, a.y + 90, 260, 48, enc.built and "Change the fight" or "Build the fight", function()
                if app.open_encounter then
                    app.open_encounter(i)
                end
            end, { font = "ui18b", key = "fight_" .. util.int(i) })
            kit.text(a.x + 280, a.y + 104, "The builder has the monsters, the map, hazards, and how hard it is for this party.",
                "ui14", theme.dim, { w = a.w - 300 })
        end,
    }
end

-- Before the night -----------------------------------------------------------------------------

local function seed_step()
    return {
        id = "seed", section = "Before the night",
        skip = function(app)
            return #(pr(app).seed_ideas or {}) == 0
        end,
        ask = "Plant a seed?",
        sub = function(app)
            return "A small mystery now that pays off in 1 to " .. util.int(content.seeds.PAYOFF_WEEKS) .. " weeks. Game night mentions it; "
                .. "the table starts guessing."
        end,
        done = function(app)
            return pr(app).planted ~= nil or flag(app, "seed").none == true
        end,
        need = "Plant one, or not this week.",
        talk = function(app, key)
            local planted = pr(app).planted
            if not planted then
                return nil
            end
            local p = app.campaign:player(key)
            local def = content.seeds[planted]
            if p and def and (util.contains(def.fans or {}, p.primary) or util.contains(def.fans or {}, p.secondary)) then
                return say(talk.seed[key], 1)
            end
        end,
        draw = function(app, a)
            local prep = pr(app)
            local items = {}
            for _, id in ipairs(prep.seed_ideas) do
                local def = content.seeds[id]
                local planted = prep.planted == id
                table.insert(items, {
                    title = def.name, body = def.plant, foot = planted and "Planted" or (util.int(content.seeds.COST) .. "h"),
                    foot_color = planted and theme.teal or theme.gold, on = planted, enabled = planted or prep:can_plant(id),
                    key = "seed_" .. id,
                    -- Point at it for what it can become.
                    on_hover = function(spot, on)
                        prep_view().drop_hover(app)
                        if on and spot and spot.rect then
                            prep_view().seed_detail(app, id, spot.rect[1], spot.rect[2])
                        end
                    end,
                    click = function()
                        flag(app, "seed").none = nil
                        if planted then
                            prep:unplant()
                        else
                            local done, why = prep:plant(id)
                            if not done then
                                app.toast = why
                            end
                        end
                        app.refresh()
                    end,
                })
            end
            table.insert(items, {
                title = "Not this week", body = "Keep the hour.", on = flag(app, "seed").none and not prep.planted, key = "seed_none",
                click = function()
                    if prep.planted then
                        prep:unplant()
                    end
                    flag(app, "seed").none = true
                    app.refresh()
                end,
            })
            local y = steps.cards(app, a, items, { cols = #items, title_font = "ui18b", body_font = "ui14", gap = 10 })
            -- What's growing from seeds before.
            local grow = prep_view().growing(app, prep)
            if grow and y + 24 <= a.y + a.h then
                kit.text(a.x, y + 4, grow, "ui14", theme.teal, { w = a.w, lines = 2 })
            end
        end,
    }
end

local function evening_step()
    local seeds_mod = require "game.model.seeds"
    return {
        id = "evening", section = "This week",
        skip = function(app)
            return staged(app)
        end,
        ask = "An evening off for ideas?",
        sub = function(app)
            return "A novel, a movie night, rereading a backstory: an evening off draws fresh cards for your stops. "
                .. util.int(content.inspiration.PER_WEEK) .. " a week, and each costs prep time."
        end,
        done = function(app)
            return next(pr(app).inspired_by or {}) ~= nil or flag(app, "evening").none == true
        end,
        need = "Pick one, or not this week.",
        draw = function(app, a)
            local prep = pr(app)
            local insp = content.inspiration
            local books_mod = require "game.model.books"
            local items = {}
            for _, id in ipairs(insp.order) do
                local d = insp[id]
                local done = prep.inspired_by[id]
                local book_id = id == "supplement" and (prep.reading and prep.reading.book or books_mod.newest(app.campaign))
                local book = book_id and books_mod.book(book_id)
                local about = book and book.name or (d.short or d.about)
                if d.thread then
                    local p = seeds_mod.backstory_target(app.campaign)
                    about = util.fill(about, { name = p and p.name or "someone" })
                end
                local open_book = done and book and prep.reading and prep.reading.left > 0
                table.insert(items, {
                    title = book and "New book" or d.name, body = about,
                    foot = open_book and "Open" or (done and "Done" or (util.int(d.cost) .. "h")),
                    foot_color = done and theme.teal or theme.gold, on = done ~= nil,
                    enabled = seeds_mod.can_inspire(app.campaign, prep, id) or done ~= nil, key = "inspire_" .. id,
                    click = function()
                        flag(app, "evening").none = nil
                        if book and prep.reading then
                            require("game.ui.book_view").open(app)
                            return
                        end
                        local drawn = prep:inspire(id)
                        if book and prep.reading then
                            require("game.ui.book_view").open(app)
                            return
                        end
                        if drawn then
                            local names = {}
                            for _, c in ipairs(drawn) do
                                table.insert(names, c.name)
                            end
                            app.toast = #names > 0 and ("Drew: " .. table.concat(names, ", ")) or (d.seed and "A new seed idea."
                                or "Nothing new turned up.")
                            app.toast_tone = "info"
                        end
                        app.refresh()
                    end,
                })
            end
            table.insert(items, {
                title = "Not this week", body = "Keep the hours for the stops.", on = flag(app, "evening").none
                    and next(prep.inspired_by or {}) == nil, key = "evening_none",
                click = function()
                    flag(app, "evening").none = true
                    app.refresh()
                end,
            })
            steps.cards(app, a, items, { cols = #items, title_font = "ui18b", body_font = "ui14", gap = 8 })
        end,
    }
end

local FORECAST_LIKE = { loved = 2, fun = 1, fine = 0, bored = -1, out = -2 }

local function ready_step()
    return {
        id = "ready", section = "Before the night",
        ask = "Ready for Thursday?",
        sub = "Tonight at a glance. Anything left empty, you'll make up at the table.",
        done = function(app)
            return pr(app):ready()
        end,
        need = "Every stop needs a kind of scene.",
        talk = function(app, key)
            local f = pr(app):forecast()[key]
            if not f then
                return nil
            end
            local tier = score.tier(f)
            return think(talk.forecast[tier][key], FORECAST_LIKE[tier])
        end,
        draw = function(app, a)
            local prep = pr(app)
            local n = #prep.scenes
            local right = 440                  -- what's worth knowing, down the right
            local gap = 12
            local cw = math.floor((a.w - right - 20 - (n - 1) * gap) / n)
            local tensions = prep:pacing_now().tensions or {}
            local ch = math.min(a.h - 4, 200)
            for i, s in ipairs(prep.scenes) do
                local x = a.x + (i - 1) * (cw + gap)
                kit.button(x, a.y, cw, ch, "", function()
                    steps.go(app, M.flow, (s.open and "route_" or "type_") .. i)
                end, { color = theme.panel2, hover = theme.button_hover, radius = 10, key = "ready_stop_" .. i })
                kit.text(x + 14, a.y + 10, "STOP " .. util.int(i), "ui14", theme.gold)
                -- How intense it runs, 1 to 5.
                for k = 1, 5 do
                    kit.dot(x + cw - 16 - (5 - k) * 12, a.y + 18, 9, k <= (tensions[i] or 0) and theme.red or kit.rgba("#000000", 0.3))
                end
                local tname = s.module and "A published adventure" or (s.open and "Open: they choose"
                    or (s.type and content.scenes[s.type].name or "No kind of scene yet"))
                kit.text(x + 14, a.y + 32, tname, "ui18b", (s.type or s.open or s.module) and theme.text or theme.orange,
                    { w = cw - 28, lines = 1 })
                kit.text(x + 14, a.y + 56, util.capitalize(stop_name(app, i)), "ui14", theme.dim, { w = cw - 28, lines = 1 })
                local yy = a.y + 84
                if s.type == "combat" or s.type == "set_piece" then
                    local enc = prep:encounter(i)
                    kit.text(x + 14, yy, (enc.built and "Your fight: " or "Fight: ") .. require("game.ui.notes_view").monster_list(enc.ids),
                        "ui14", theme.gold, { w = cw - 28, lines = 1 })
                    yy = yy + 22
                end
                for _, kind in ipairs(content.kinds) do
                    local c = s.slots[kind]
                    if kind ~= "location" and yy + 20 <= a.y + ch then
                        kit.text(x + 14, yy, c and c.name or ("No " .. string.lower(content.kind_names[kind]) .. ": improvise"), "ui14",
                            c and theme.text or theme.faint, { w = cw - 28, lines = 1, gloss = false })
                        yy = yy + 22
                    end
                end
            end
            -- What's worth knowing, and what's still open this week.
            local rx = a.x + a.w - right
            kit.text(rx, a.y, "WORTH KNOWING", "ui14", theme.gold)
            local y = a.y + 22
            local notes = prep_view().pacing_notes(app, prep)
            for _, it in ipairs(prep_view().attention(app)) do
                table.insert(notes, { it, theme.orange })
            end
            for _, nt in ipairs(notes) do
                local th = math.min(kit.text_height(nt[1], "ui14", right - 18), 2 * kit.line_height("ui14"))
                if y + th > a.y + a.h then
                    break
                end
                kit.dot(rx + 5, y + 9, 7, nt[2])
                kit.text(rx + 16, y, nt[1], "ui14", theme.text, { w = right - 18, lines = 2 })
                y = y + th + 4
            end
        end,
    }
end

-- The flow ------------------------------------------------------------------------------------

local function run_night(app)
    if not pr(app):ready() then
        return
    end
    app.go("night")      -- (by way of the lore screen)
end

M.flow = {
    id = "prep",
    title = function(app)
        return "SESSION " .. util.int(app.campaign.week)
    end,
    layout = "table",
    header = header,
    header_x = 1000,
    people = here,
    steps = {},
    finish = { label = "Run game night  >", fn = run_night },
}
do
    local list = M.flow.steps
    table.insert(list, story_step())
    table.insert(list, chat_step())
    table.insert(list, friends_step())
    for i = 1, 6 do
        table.insert(list, world_step(i))
    end
    table.insert(list, levelup_step())
    table.insert(list, spotlight_step())
    table.insert(list, guests_step())
    table.insert(list, evening_step())
    for i = 1, 3 do
        table.insert(list, route_step(i))
    end
    for i = 1, 3 do
        table.insert(list, type_step(i))
        for _, kind in ipairs({ "cast", "goal", "complication", "reward" }) do
            table.insert(list, slot_step(i, kind))
        end
        table.insert(list, fight_step(i))
    end
    table.insert(list, seed_step())
    table.insert(list, ready_step())
end

function M.build(app)
    if app.prep_week ~= app.campaign.week then
        -- A new week starts at the beginning.
        app.prep_week = app.campaign.week
        steps.reset(app, M.flow)
    end
    app.prep_steps = true
    kit.gloss_scope({ story = true }, function()
        steps.draw(app, M.flow, { x = 120, w = 1360 })
    end)
    -- The Story log, over everything while it's open (S).
    require("game.ui.story_log_view").panel(app)
end

function M.next(app)
    return steps.next(app, M.flow)
end

function M.go(app, id)
    return steps.go(app, M.flow, id)
end

return M
