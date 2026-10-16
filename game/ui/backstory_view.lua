-- Session Zero, part two (October 13): their backstories. One player at a time: they pitch their
-- hero's past, you ask what you want to know (six questions, all told), answer the idea they
-- bring, and choose what from that past turns up first. On the right, the page you're writing:
-- it opens their Story log, and the piece you chose waits at the front of your first hand.
-- The model is game/model/backstory.lua; the words are game/data/backstories.lua.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local panels = require "game.ui.panels"
local content = require "game.model.content"
local util = require "game.model.util"
local backstory = require "game.model.backstory"

local M = {}

-- Two uses (October 15): Session Zero's backstories for everyone at the table, or one player
-- joining a small table later (app.join = { key, backstories, ask }).
local function state(app)
    if app.join then
        app.join.backstories = app.join.backstories or {}
        return app.join
    end
    app.s0 = app.s0 or { asks = {}, rules = {} }
    app.s0.backstories = app.s0.backstories or {}
    return app.s0
end

local function choices(app)
    return state(app).backstories
end

local function keys(app)
    if app.join then
        return { app.join.key }
    end
    return app.campaign:table_keys()
end

local function budget(app)
    return app.join and backstory.data.JOIN_QUESTIONS or backstory.data.QUESTIONS
end

local function current(app)
    local all = choices(app)
    local st = state(app)
    local key = st.bs_key
    if not (key and backstory.data[key] and util.contains(keys(app), key)) then
        key = nil
        -- The first hero whose past isn't written yet.
        for _, k in ipairs(keys(app)) do
            if not key and backstory.data[k] and not (all[k] and all[k].hook) then
                key = k
            end
        end
        key = key or keys(app)[1]
        st.bs_key = key
    end
    return key
end

local function reaction(like, tired)
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

-- The four heroes along the top, each saying whether you've written their past yet.
local function tabs(app, key)
    local all = choices(app)
    local planner = require "game.model.planner"
    local tw = 262
    for i, k in ipairs(keys(app)) do
        local d = content.players[k]
        local x, y = 24 + (i - 1) * (tw + 10), 70
        local on = k == key
        local done = all[k] and all[k].hook
        if on then
            kit.box(x - 3, y - 3, tw + 6, 62, theme.select, { radius = 11 })
        end
        kit.button(x, y, tw, 56, "", function()
            state(app).bs_key = k
            app.refresh()
        end, { color = on and theme.panel3 or theme.panel2, hover = theme.button_hover, key = "bs_tab_" .. k })
        kit.dot(x + 28, y + 28, 40, panels.COLORS[k] or theme.panel3)
        kit.picture(x + 10, y + 10, 36, 36, panels.face(k))
        kit.text(x + 56, y + 7, d.char, "ui18b", theme.text)
        kit.text(x + 56, y + 31, d.name .. ", " .. string.lower(d.class_name), "ui14", theme.dim)
        local status = done and "Written" or "To write"
        kit.text(x + tw - 12, y + 9, status, "ui14", done and theme.green or theme.faint, { pivot = gui.PIVOT_NE })
        if planner.featured(app.campaign, k) then
            kit.text(x + tw - 12, y + 31, "Featured", "ui14", theme.gold, { pivot = gui.PIVOT_NE })
        end
    end
    -- How many questions the evening has left.
    local left = backstory.left(all, budget(app))
    local px = 1140
    kit.text(px, 74, "QUESTIONS LEFT", "ui14", theme.dim)
    for i = 1, budget(app) do
        kit.box(px + (i - 1) * 26, 98, 20, 20, i <= left and theme.gold or theme.panel3, { radius = 5 })
    end
    kit.text(px + budget(app) * 26 + 6, 98, util.int(left) .. " of " .. util.int(budget(app)), "ui14", theme.text)
end

local function head(x, y, text, sub)
    kit.text(x, y, text, "ui14", theme.gold)
    if sub then
        kit.text(x + kit.width(text, "ui14") + 12, y, sub, "ui14", theme.faint)
    end
    return y + 24
end

-- Left: the conversation. Their pitch, your questions, their idea.
local function talk(app, key, x, y, w, h)
    local all = choices(app)
    local ch = all[key] or { asked = {} }
    local d = backstory.data[key]
    local pd = content.players[key]
    kit.box(x, y, w, h, theme.panel, { radius = 12 })
    local ix, iw = x + 20, w - 40
    local ty = head(ix, y + 16, "THEIR STORY", pd.name .. ", as " .. pd.char)
    local pitch = '"' .. d.pitch .. '"'
    kit.text(ix, ty, pitch, "story22", theme.log.quote, { w = iw })
    ty = ty + kit.text_height(pitch, "story22", iw) + 6
    kit.text(ix, ty, "You know " .. pd.name .. ": " .. pd.notes, "ui14", theme.dim, { w = iw })
    ty = ty + kit.text_height("You know " .. pd.name .. ": " .. pd.notes, "ui14", iw) + 14
    -- Your questions.
    local left = backstory.left(all, budget(app))
    local none_here = #(ch.asked or {}) == 0
    ty = head(ix, ty, "ASK", (left == 0 and none_here) and "No time left for questions. Take one back from someone else to ask here."
        or (app.join and "Each answer goes in their story. There's time for three."
            or "Each answer goes in their story. The evening has time for six, all told."))
    local order = {}
    for i, id in ipairs(ch.asked or {}) do
        order[id] = i
    end
    for _, q in ipairs(d.questions) do
        local n = order[q.id]
        local asked = n ~= nil
        if asked then
            kit.box(ix - 3, ty - 3, iw + 6, 38, theme.select, { radius = 9 })
        end
        kit.button(ix, ty, iw, 32, q.ask, function()
            backstory.toggle_question(all, key, q.id, budget(app))
            app.refresh()
        end, { font = "ui18", align = "left", pad_y = 5, color = asked and theme.panel3 or theme.button,
               hover = theme.button_hover, enabled = asked or left > 0, key = "bs_q_" .. q.id })
        ty = ty + 38
        if asked then
            local tired = n > (d.tires or 3)
            local word, col = reaction(q.like - (tired and 1 or 0), tired)
            local ans = '"' .. q.answer .. '"'
            local aw = iw - 190
            kit.text(ix + 14, ty, ans, "ui18", theme.text, { w = aw })
            kit.text(ix + iw, ty + 2, word, "ui14", col, { pivot = gui.PIVOT_NE })
            ty = ty + kit.text_height(ans, "ui18", aw) + 8
        end
    end
    -- Their own idea.
    ty = head(ix, ty + 8, "THEIR IDEA")
    local idea = pd.name .. ': "' .. d.idea.text .. '"'
    kit.text(ix, ty, idea, "ui18", theme.text, { w = iw })
    ty = ty + kit.text_height(idea, "ui18", iw) + 8
    local bw = (iw - 10) / 2
    for i, which in ipairs({ "yes", "no" }) do
        local o = d.idea[which]
        local on = ch.idea == which
        local bx = ix + (i - 1) * (bw + 10)
        if on then
            kit.box(bx - 3, ty - 3, bw + 6, 38, theme.select, { radius = 9 })
        end
        kit.button(bx, ty, bw, 32, o.label, function()
            all[key] = all[key] or { asked = {} }
            all[key].idea = (all[key].idea ~= which) and which or nil
            app.refresh()
        end, { font = "ui18", color = on and theme.panel3 or theme.button, hover = theme.button_hover, key = "bs_idea_" .. which })
    end
    ty = ty + 40
    if ch.idea then
        local o = d.idea[ch.idea]
        local reply = '"' .. o.reply .. '"'
        kit.text(ix + 14, ty, reply, "ui18", o.like >= 1 and theme.green or theme.orange, { w = iw - 14 })
        ty = ty + kit.text_height(reply, "ui18", iw - 14) + 8
    end
end

-- Joining later (October 15): their ask for the table, the one Session Zero would have heard.
-- Top of the right column (the conversation on the left is full). Returns where it ends.
local function ask_block(app, key, ix, ty, iw)
    local a = content.session_zero.asks[key]
    if not a then
        return ty
    end
    local bw = (iw - 10) / 2
    ty = head(ix, ty, "THEIR ASK", a.kind == "promise" and "A promise" or (a.kind == "line" and "A line" or "A veil"))
    local said = '"' .. a.text .. '"'
    kit.text(ix, ty, said, "ui18", theme.text, { w = iw })
    ty = ty + kit.text_height(said, "ui18", iw) + 8
    for i, which in ipairs({ "agree", "push" }) do
        local o = a[which]
        local on = app.join.ask == which
        local bx = ix + (i - 1) * (bw + 10)
        if on then
            kit.box(bx - 3, ty - 3, bw + 6, 38, theme.select, { radius = 9 })
        end
        kit.button(bx, ty, bw, 32, o.label, function()
            app.join.ask = which
            app.refresh()
        end, { font = "ui14", color = on and theme.panel3 or theme.button, hover = theme.button_hover, key = "join_ask_" .. which })
    end
    ty = ty + 40
    if app.join.ask then
        local o = a[app.join.ask]
        kit.text(ix + 14, ty, '"' .. o.reply .. '"', "ui18", o.like >= 1 and theme.green or theme.orange, { w = iw - 14, lines = 1 })
    end
    return ty + 30
end

-- Right: what turns up first, and the page you're writing.
local function write(app, key, x, y, w, h)
    local all = choices(app)
    local ch = all[key] or { asked = {} }
    local d = backstory.data[key]
    local pd = content.players[key]
    local ix, iw = x, w
    local ty = y + 16
    if app.join then
        ty = ask_block(app, key, ix, ty, iw)
    end
    ty = head(ix, ty, "WHAT TURNS UP FIRST")
    local pick_text = "Pick the piece of " .. pd.char .. "'s past you'll bring in. It waits at the front of your "
        .. (app.join and "hand this week." or "first hand.")
    kit.text(ix, ty, pick_text, "ui14", theme.dim, { w = iw })
    ty = ty + kit.text_height(pick_text, "ui14", iw) + 8
    for _, hk in ipairs(d.hooks) do
        local on = ch.hook == hk.card
        local c = content.components[hk.card]
        local kind = c and content.kind_names[c.kind] or ""
        local word, col = feel_word(hk.like)
        local tw = iw - 180
        local bh = math.max(54, kit.text_height(hk.text, "ui18", tw) + 30)
        if on then
            kit.box(ix - 3, ty - 3, iw + 6, bh + 6, theme.select, { radius = 10 })
        end
        kit.button(ix, ty, iw, bh, "", function()
            all[key] = all[key] or { asked = {} }
            all[key].hook = hk.card
            app.refresh()
        end, { color = on and theme.panel3 or theme.panel2, hover = theme.button_hover, key = "bs_hook_" .. hk.card })
        kit.text(ix + 14, ty + 6, hk.text, "ui18", theme.text, { w = tw })
        kit.text(ix + 14, ty + bh - 22, string.upper(kind) .. ": " .. (c and c.name or hk.card), "ui14", theme.faint,
            { w = tw, lines = 1 })
        kit.text(ix + iw - 14, ty + 8, pd.name, "ui14", theme.dim, { pivot = gui.PIVOT_NE })
        kit.text(ix + iw - 14, ty + 28, word, "ui14", col, { pivot = gui.PIVOT_NE })
        ty = ty + bh + 8
    end
    -- The page you're writing: the first page of their Story log.
    ty = ty + 8
    local py, ph = ty, y + h - ty
    kit.box(ix, py, iw, ph, theme.paper, { radius = 8 })
    local px, pw = ix + 22, iw - 44
    local yy = py + 14
    kit.text(px, yy, string.upper(pd.char .. "'s past, as you wrote it"), "ui14", theme.ink_dim)
    yy = yy + 24
    local lines = { pd.premise or util.capitalize(pd.thread or "") }
    local q_order = {}
    for _, id in ipairs(ch.asked or {}) do
        local q = backstory.question(key, id)
        if q then
            table.insert(q_order, q.fact)
        end
    end
    for _, f in ipairs(q_order) do
        table.insert(lines, f)
    end
    if ch.idea == "yes" then
        table.insert(lines, d.idea.yes.fact)
    end
    local bottom = py + ph - 34
    for i, l in ipairs(lines) do
        local font = i == 1 and "ui18b" or "ui18"
        local hh = kit.text_height(l, font, pw - 16)
        if yy + hh > bottom - 50 then
            break
        end
        if i > 1 then
            kit.text(px, yy, "-", "ui18", theme.ink_dim)
        end
        kit.text(px + (i > 1 and 16 or 0), yy, l, font, theme.ink, { w = pw - 16 })
        yy = yy + hh + 6
    end
    local hk = ch.hook and backstory.hook_of(key, ch.hook)
    if hk then
        yy = yy + 4
        kit.text(px, yy, "TURNS UP FIRST", "ui14", kit.rgba("#8a5a1a"))
        yy = yy + 20
        if yy + kit.text_height(hk.text, "ui18", pw) <= bottom then
            kit.text(px, yy, hk.text, "ui18", theme.ink, { w = pw })
        end
    else
        kit.text(px, bottom - 20, "Choose what turns up first to finish the page.", "ui14", theme.ink_dim)
    end
    kit.text(px, py + ph - 26, "This is the first page of " .. pd.char .. "'s Story log.", "ui14", theme.ink_dim)
end

-- How everyone's feeling about Session Zero, backstories and all.
local function feelings(app)
    local social = require "game.model.social"
    local s0 = app.join and { asks = { [app.join.key] = app.join.ask } } or app.s0
    local full = { tone = s0.tone or "mixed", asks = s0.asks or {}, rules = s0.rules or {}, backstories = choices(app) }
    local f = social.feelings(full)
    local x = 230
    kit.text(x, 850, app.join and "HOW THEY FEEL" or "HOW EVERYONE FEELS", "ui14", theme.dim)
    x = x + kit.width(app.join and "HOW THEY FEEL" or "HOW EVERYONE FEELS", "ui14") + 18
    for _, key in ipairs(keys(app)) do
        local v = f[key] or 0
        if app.join then
            -- (No tone or rules to react to: only what you asked and wrote.)
            v = backstory.like(key, choices(app)[key])
            local a = content.session_zero.asks[key]
            v = v + ((a and app.join.ask and a[app.join.ask].like) or 0) + 1
        end
        local word = v >= 3 and "Heard" or (v >= 1 and "Happy" or (v >= -1 and "Okay" or "Uneasy"))
        local col = v >= 1 and theme.green or (v <= -2 and theme.orange or theme.dim)
        local name = content.players[key].name
        kit.text(x, 848, name, "ui18b", theme.text)
        x = x + kit.width(name, "ui18b") + 8
        kit.text(x, 849, word, "ui18", col)
        x = x + kit.width(word, "ui18") + 24
    end
end

function M.ready(app)
    if app.join then
        local ch = choices(app)[app.join.key]
        return (ch and ch.hook ~= nil) and (app.join.ask ~= nil or not content.session_zero.asks[app.join.key])
    end
    return backstory.complete(choices(app), keys(app))
end

-- A player joining a small table: welcome them, and on to the week (October 15).
function M.welcome(app)
    if not (app.join and M.ready(app)) then
        return false
    end
    local key = app.join.key
    app.campaign:welcome(key, { ask = app.join.ask, backstory = choices(app)[key] })
    app.join = nil
    app.go("prep", { welcomed = true })
    return true
end

-- Settle Session Zero, backstories and all, and on to week 1. (Only reached from the first page,
-- once everything on it is answered.)
function M.start(app)
    if not M.ready(app) then
        return false
    end
    app.campaign:session_zero(app.s0)
    app.s0 = nil
    app.go("prep")
    return true
end

function M.build(app)
    kit.box(0, 0, kit.W, kit.H, theme.bg, { round = false })
    local key = current(app)
    if app.join then
        local pd = content.players[key]
        local week = app.campaign.week + 1
        kit.text(24, 14, string.upper(pd.name) .. " JOINS THE TABLE", "title30", theme.gold)
        kit.text(24 + kit.width(string.upper(pd.name) .. " JOINS THE TABLE", "title30") + 24, 24,
            "Before session " .. util.int(week) .. ": hear " .. pd.char .. "'s story, and write it into the world.", "ui18", theme.dim)
    else
        kit.text(24, 14, "SESSION ZERO", "title30", theme.gold)
        kit.text(280, 24, "Their backstories: hear each one, ask what you want to know, and write it into the world.", "ui18", theme.dim)
    end
    tabs(app, key)
    talk(app, key, 24, 140, 760, 680)
    write(app, key, 808, 140, 768, 680)
    if not app.join then
        kit.button(24, 836, 180, 44, "<  The table", function()
            app.s0.page = nil
            app.refresh()
        end, { font = "ui18b", key = "bs_back" })
    end
    feelings(app)
    local ready = M.ready(app)
    if app.join then
        kit.button(1356, 830, 220, 50, "Welcome " .. content.players[key].name .. "  >", function()
            M.welcome(app)
        end, { enabled = ready, color = theme.go, hover = theme.go_hover, font = "ui22b", key = "join_start" })
        if not ready then
            kit.text(1340, 852, "Answer their ask and choose what turns up first.", "ui14", theme.dim, { pivot = gui.PIVOT_NE })
        end
        return
    end
    kit.button(1356, 830, 220, 50, "Start session 1  >", function()
        M.start(app)
    end, { enabled = ready, color = theme.go, hover = theme.go_hover, font = "ui22b", key = "s0_start" })
    if not ready then
        kit.text(1340, 852, "Choose what turns up first for every hero.", "ui14", theme.dim, { pivot = gui.PIVOT_NE })
    end
end

return M
