-- The prep board's left column (M6): the group chat, where you can answer theories,
-- and your messages: DMs from players and conversations you start. Opening one
-- shows it in a modal over the board.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local content = require "game.model.content"
local util = require "game.model.util"

local M = {}

local X, W = 24, 320

local function name_of(app, key)
    if key == "dm" then
        return "You"
    elseif key == "group" then
        return "Group chat"
    end
    local p = app.campaign:player(key)
    return p and p.name or key
end

-- Conversations open this week, with what the list shows for each.
function M.rows(app)
    local c = app.campaign
    local prep = c.prep
    local out = {}
    for _, oc in ipairs(c.open_convos or {}) do
        local def = content.convos[oc.id]
        local thread = prep.convos[oc.id]
        local row = { id = oc.id, def = def, thread = thread }
        if def.opener == "player" then
            row.title = name_of(app, def.with)
            row.preview = util.fill(def.says, { topic = require("game.model.social").topic(c) })
            row.state = thread and (thread.done and "Answered" or "Open") or "New"
        else
            row.title = def.title
            row.preview = def.about and util.fill(def.about, { topic = require("game.model.social").topic(c) })
                or (def.with == "group" and "A post to the whole group." or ("A private message to " .. name_of(app, def.with) .. "."))
            local cost = prep:convo_cost(oc.id)
            row.cost = cost
            row.state = (thread and not thread.unpaid) and (thread.done and "Sent" or "Open")
                or (cost > 0 and (util.int(cost) .. "h") or "Free")
        end
        table.insert(out, row)
    end
    return out
end

function M.unread(app)
    local n = 0
    for _, r in ipairs(M.rows(app)) do
        if r.state == "New" then
            n = n + 1
        end
    end
    return n
end

local function group_chat(app, y0)
    local c = app.campaign
    local msgs = c.chat or {}
    -- Like any chat: the newest messages at the bottom; older ones scroll off the top.
    local heights = {}
    for i, m in ipairs(msgs) do
        heights[i] = 30 + kit.text_height(m.text, "ui18", W - 24) + (m.choices and 34 or 0)
    end
    local room = 885 - y0
    local first, used = #msgs + 1, 0
    for i = #msgs, 1, -1 do
        if used + heights[i] + 8 > room - (i > 1 and 22 or 0) then
            break
        end
        used = used + heights[i] + 8
        first = i
    end
    local y = y0
    if first > 1 then
        kit.text(X, y, util.int(first - 1) .. (first == 2 and " earlier message" or " earlier messages"), "ui14", theme.faint)
        y = y + 22
    end
    for i = first, #msgs do
        local m = msgs[i]
        local h = heights[i]
        local th = h - (m.choices and 34 or 0)
        local mine = m.key == "dm"
        kit.box(X, y, W, h, mine and kit.rgba("#28403c") or theme.panel2, { radius = 8 })
        kit.text(X + 12, y + 6, m.who, "ui18b", mine and theme.teal or theme.gold)
        kit.text(X + 12, y + 28, m.text, "ui18", theme.text, { w = W - 24 })
        if m.choices then
            local by = y + th
            if m.answered then
                kit.text(X + 12, by + 4, "You: " .. m.answered, "ui14", theme.teal)
            else
                local bw = (W - 24 - 12) / 3
                for k, label in ipairs(m.choices) do
                    local bx = X + 12 + (k - 1) * (bw + 6)
                    kit.button(bx, by, bw, 26, "", function()
                        c:answer_chat(i, k)
                        app.refresh()
                    end, { font = "ui14", key = "chat_" .. i .. "_" .. k })
                    kit.text(bx + bw / 2, by + 13, label, "ui14", theme.text, { pivot = gui.PIVOT_CENTER })
                end
            end
        end
        y = y + h + 8
    end
end

local function message_list(app, y0)
    local rows = M.rows(app)
    local y = y0
    if #rows == 0 then
        kit.text(X, y, "No messages this week. The table is happy, or quiet.", "ui18", theme.faint, { w = W })
        return
    end
    for _, r in ipairs(rows) do
        local h = 76
        if y + h > 885 then
            break
        end
        kit.button(X, y, W, h, "", function()
            M.open(app, r.id)
        end, { color = theme.panel2, hover = theme.button_hover, key = "convo_" .. r.id })
        kit.text(X + 12, y + 8, r.title, "ui18b", r.state == "New" and theme.gold or theme.text, { w = W - 90, lines = 1 })
        local sc = (r.state == "New" or r.state == "Free") and theme.gold or ((r.state == "Sent" or r.state == "Answered") and theme.faint or theme.dim)
        kit.text(X + W - 12, y + 10, r.state, "ui14", sc, { pivot = gui.PIVOT_NE })
        kit.text(X + 12, y + 34, r.preview, "ui14", theme.dim, { w = W - 24, lines = 2 })
        y = y + h + 8
    end
end

-- The left column of the prep board.
function M.column(app)
    app.chat_tab = app.chat_tab or "group"
    local unread = M.unread(app)
    local tabs = { { "group", "GROUP CHAT" }, { "messages", unread > 0 and ("MESSAGES  " .. util.int(unread)) or "MESSAGES" } }
    for i, t in ipairs(tabs) do
        local on = app.chat_tab == t[1]
        local bx = X + (i - 1) * 164
        kit.button(bx, 78, 156, 26, t[2], function()
            app.chat_tab = t[1]
            app.refresh()
        end, { font = "ui14", color = on and theme.panel3 or theme.bg, hover = theme.button_hover,
               text_color = (t[1] == "messages" and unread > 0) and theme.gold or (on and theme.text or theme.dim),
               key = "tab_" .. t[1] })
    end
    if app.chat_tab == "messages" then
        message_list(app, 112)
    else
        group_chat(app, 112)
    end
end

-- The conversation modal ---------------------------------------------------------------------

function M.open(app, id)
    local prep = app.campaign.prep
    local thread, why = prep:open_convo(id)
    if not thread then
        app.toast = why
        app.refresh()
        return
    end
    app.convo = id
    app.convo_note = nil
    app.refresh()
end

function M.close(app)
    if app.convo then
        app.campaign.prep:close_convo(app.convo)
    end
    app.convo = nil
    app.convo_note = nil
    app.refresh()
end

-- Send option i in the open conversation.
function M.send(app, i)
    local c = app.campaign
    local id = app.convo
    local thread = id and c.prep.convos[id]
    if not thread or thread.done then
        return
    end
    local before = #thread.log
    local out, why = c.prep:reply(id, i)
    if not out then
        app.convo_note = why
        app.refresh()
        return
    end
    -- A post to the group shows up in the group chat too.
    if thread.with == "group" then
        for k = before + 1, #thread.log do
            local e = thread.log[k]
            table.insert(c.chat, { who = name_of(app, e.who), key = e.who, text = e.text })
        end
    end
    local notes = {}
    if out.failed then
        table.insert(notes, "That didn't land the way you hoped.")
    end
    if out.resolved then
        local def = content.conflicts[thread.def.conflict]
        table.insert(notes, "Settled: " .. (def.fixes[out.resolved] or "the air is clear."))
    end
    if out.unlocked then
        table.insert(notes, "You offered: " .. content.convos[out.unlocked].title .. ". It's in your messages, free this week.")
    end
    app.convo_note = #notes > 0 and table.concat(notes, " ") or nil
    app.refresh()
end

function M.modal(app)
    local c = app.campaign
    local id = app.convo
    local thread = id and c.prep.convos[id]
    if not thread then
        app.convo = nil
        return
    end
    kit.layer("convo", true)
    kit.box(0, 0, kit.W, kit.H, kit.rgba("#000000", 0.55), { round = false })
    local w = 800
    local x = 400
    local opts = require("game.model.convo").options(c, thread)
    local opt_h = 0
    for _, label in ipairs(opts) do
        opt_h = opt_h + math.max(44, kit.text_height(label, "ui18", w - 80) + 20) + 8
    end
    if thread.done then
        opt_h = 64
    end
    local note_h = app.convo_note and (kit.text_height(app.convo_note, "ui14", w - 48) + 16) or 0
    -- Bubbles, newest last; the modal grows to fit them, up to most of the screen.
    local bubbles, bubbles_h = {}, 0
    for k = #thread.log, 1, -1 do
        local e = thread.log[k]
        local bw = 520
        local bh = kit.text_height(e.text, "ui18", bw - 28) + (e.who == "dm" and 16 or 38)
        if bubbles_h + bh + 10 > 760 - 90 - opt_h - note_h then
            break
        end
        table.insert(bubbles, 1, { e = e, h = bh, w = bw })
        bubbles_h = bubbles_h + bh + 10
    end
    local h = math.max(360, math.min(780, 70 + bubbles_h + note_h + opt_h + 24))
    local y = math.floor((kit.H - h) / 2)
    kit.box(x, y, w, h, theme.bg, { radius = 14 })
    local title = thread.with == "group" and ("Group chat: " .. string.lower(string.sub(thread.def.title, 1, 1)) .. string.sub(thread.def.title, 2))
        or name_of(app, thread.with)
    kit.text(x + 24, y + 18, title, "ui22b", theme.text)
    local cost = thread.unpaid and c.prep:convo_cost(id) or thread.cost
    if cost and cost > 0 then
        kit.text(x + 24 + kit.width(title, "ui22b") + 12, y + 24,
            thread.unpaid and ("Sending costs " .. util.int(cost) .. "h of prep time") or (util.int(cost) .. "h of prep time"),
            "ui14", thread.unpaid and theme.gold or theme.dim)
    end
    kit.button(x + w - 120, y + 14, 100, 32, "Close", function()
        M.close(app)
    end, { font = "ui14", key = "convo_close" })
    -- The thread so far: theirs on the left, yours on the right.
    local by = y + h - 24 - opt_h - note_h - bubbles_h
    for _, b in ipairs(bubbles) do
        local mine = b.e.who == "dm"
        local bx = mine and (x + w - 24 - b.w) or (x + 24)
        kit.box(bx, by, b.w, b.h, mine and kit.rgba("#28403c") or theme.panel2, { radius = 10 })
        local ty = by + 8
        if not mine then
            kit.text(bx + 14, ty, name_of(app, b.e.who), "ui18b", theme.gold)
            ty = ty + 24
        end
        kit.text(bx + 14, ty, b.e.text, "ui18", theme.text, { w = b.w - 28 })
        by = by + b.h + 10
    end
    local oy = y + h - 24 - opt_h - note_h
    if app.convo_note then
        kit.text(x + 24, oy, app.convo_note, "ui14", theme.teal, { w = w - 48 })
        oy = oy + note_h
    end
    if thread.done then
        kit.button(x + w / 2 - 110, oy + 8, 220, 44, "Done", function()
            M.close(app)
        end, { color = theme.go, hover = theme.go_hover, key = "convo_done" })
        return
    end
    for k, label in ipairs(opts) do
        local bh = math.max(44, kit.text_height(label, "ui18", w - 80) + 20)
        kit.button(x + 24, oy, w - 48, bh, label, function()
            M.send(app, k)
        end, { font = "ui18", align = "left", key = "convo_opt_" .. k })
        oy = oy + bh + 8
    end
end

return M
