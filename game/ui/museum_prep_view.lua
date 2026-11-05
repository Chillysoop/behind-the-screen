-- Prep in the museum (v2): the week's board for The Museum of Nightmares. Before the board, the
-- questions between sessions (requests in the group chat, loose ends, favors). On the board: where
-- the party stands on the museum map, tonight's rooms (prep each or wing it, and how you'll run
-- it), Euryale's card with every mark the party has left on it, and the friends down the right.
-- On boss night the middle becomes the showdown board. Rebuilt from scratch on every click.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local panels = require "game.ui.panels"
local player_cards = require "game.ui.player_cards"
local ask_view = require "game.ui.ask_view"
local content = require "game.model.content"
local util = require "game.model.util"
local adventure = require "game.model.adventure"
local museum_week = require "game.model.museum_week"
local map_repo = require "game.model.map_repo"
local ties = require "game.model.ties"

local MODULE = adventure.data
local M = {}

local COL_L, COL_LW = 24, 380
local COL_M, COL_MW = 420, 756

local function like_color(v)
    if v > 0 then
        return theme.green
    elseif v < 0 then
        return theme.orange
    end
    return theme.faint
end

-- Name chips: who'd love this, who wouldn't.
local function chips(x, y, like, max_w)
    local cx = x
    for _, key in ipairs(content.players.order) do
        local v = like and like[key] or 0
        if v ~= 0 then
            local label = content.players[key].name .. (v > 0 and " +" or " -")
            if v >= 2 or v <= -2 then
                label = label .. (v > 0 and "+" or "-")
            end
            local w = kit.width(label, "ui14") + 12
            if cx + w > x + max_w then
                return cx
            end
            kit.box(cx, y, w, 20, like_color(v), { radius = 6 })
            kit.text(cx + 6, y + 1, label, "ui14", theme.ink)
            cx = cx + w + 5
        end
    end
    return cx
end

-- Between sessions -----------------------------------------------------------------------------

local function prompts(app)
    local c = app.campaign
    local list = {}
    for _, pr in ipairs(c.adv.prompts or {}) do
        if not c.adv.answered[pr.id] and not (pr.kind == "favor" and c.adv.favor_done[pr.id]) then
            table.insert(list, pr)
        end
    end
    -- A question for you in the group chat (museum_week.write_chat), last.
    for _, m in ipairs(c.chat or {}) do
        if m.ask and not m.answered then
            table.insert(list, { kind = "chat", id = "chat_" .. m.ask, msg = m })
        end
    end
    return list
end
M.prompts = prompts

-- How each friend would take an answer to a request (the asker most of all).
local function request_like(c, rq, answer)
    local out = {}
    local a = rq.answers[answer]
    for _, p in ipairs(c.players) do
        local d = 0
        for arch, v in pairs(MODULE.answer_like[answer] or {}) do
            d = d + v * require("game.model.score").arch(p, arch) * 0.5
        end
        if p.key == rq.who then
            d = d + (a.asker or 0)
        end
        out[p.key] = d >= 1 and 1 or (d <= -1 and -1 or 0)
        if d >= 2.5 then
            out[p.key] = 2
        elseif d <= -2.5 then
            out[p.key] = -2
        end
    end
    return out
end

local function between(app)
    local c = app.campaign
    local list = prompts(app)
    local pr = list[1]
    kit.box(0, 0, kit.W, kit.H, theme.bg, { round = false })
    kit.text(24, 14, "SESSION " .. util.int(c.week), "title30", theme.gold)
    -- (What's on this screen, no more: the third playtest looked for "what's changed" and found no such part.)
    kit.text(300, 24, "Between sessions: the group chat, and the questions waiting for you before the prep board.", "ui18", theme.dim)
    -- The chat down the left: the newest at the bottom, as much as fits (a question for you is last).
    kit.text(COL_L, 84, "THE GROUP CHAT", "ui14", theme.dim)
    local chat = c.chat or {}
    local hs, first, total = {}, #chat + 1, 0
    for i = #chat, 1, -1 do
        local m = chat[i]
        local h = kit.text_height(m.text, "ui18", COL_LW - 60 - (m.reply and 12 or 0)) + 14 + 18
        if total + h > 860 - 108 then
            break
        end
        hs[i], total, first = h, total + h, i
    end
    local y = 108
    if first > 1 then
        kit.text(COL_L, y - 4, "(earlier messages above)", "ui14", theme.faint)
        y = y + 14
    end
    for i = first, #chat do
        local m = chat[i]
        local ix = COL_L + (m.reply and 12 or 0)
        if m.key == "dm" then
            kit.dot(ix + 14, y + 14, 26, theme.teal)
            kit.text(ix + 14, y + 6, "DM", "ui14", theme.bg, { pivot = gui.PIVOT_N, gloss = false })
        else
            kit.dot(ix + 14, y + 14, 26, panels.COLORS[m.key] or theme.panel3)
            kit.picture(ix + 2, y + 2, 24, 24, panels.face(m.key))
        end
        kit.text(ix + 36, y, m.who, "ui14", m.key == "dm" and theme.teal or theme.dim)
        kit.text(ix + 36, y + 18, m.text, "ui18", (m.ask and not m.answered) and theme.gold or theme.text,
            { w = COL_LW - 50 - (m.reply and 12 or 0), gloss = false })
        y = y + hs[i]
    end
    local x, w = 460, 760
    kit.text(x, 84, "QUESTIONS THIS WEEK  (" .. util.int(#list) .. ")", "ui14", theme.dim)
    if not pr then
        return
    end
    local box_y = 112
    kit.box(x, box_y, w, 640, theme.panel, { radius = 12 })
    local def = pr.def
    if pr.kind == "ruling" then
        kit.text(x + 24, box_y + 18, "A PROMISE", "ui14", theme.gold)
        -- Which rule (the third playtest: "a quick call on that rule" didn't say): the question as it
        -- came up and what you said, from last night's rules calls, when it has no topic of its own.
        local what = def.topic
        if what == "that rule" then
            for _, rc in ipairs(c.last_rules_calls or {}) do
                local hr = c.house_rules and c.house_rules[rc.card]
                if hr and not rc.looked and hr.title then
                    what = "\"" .. hr.title .. "\"" .. ((hr.ruling or "") ~= "" and (" (you said: \"" .. hr.ruling .. "\")") or "")
                    break
                end
            end
        end
        kit.text(x + 24, box_y + 50, "Last session you made a quick call on " .. what .. ", and told the table you'd look it up after.",
            "story22", theme.text, { w = w - 48, lines = 3 })
        kit.text(x + 24, box_y + 150, "That was the deal at Session Zero: quick call now, look it up after. Sam will remember either way.",
            "ui18", theme.dim, { w = w - 48 })
        local by = box_y + 210
        for i, o in ipairs({ { true, "Post what the rule really says", "Five minutes with the book, and a message in the chat." },
                             { false, "Let it slide", "Nobody's asked. Maybe nobody will." } }) do
            kit.button(x + 24, by, w - 48, 80, "", function()
                adventure.answer_ruling(c, pr.id, o[1])
                app.refresh()
            end, { color = theme.panel2, hover = theme.button_hover, key = "ruling_" .. i })
            kit.text(x + 40, by + 10, o[2], "ui18b", o[1] and theme.gold or theme.text)
            kit.text(x + 40, by + 38, o[3], "ui18", theme.dim, { w = w - 80, lines = 1 })
            by = by + 92
        end
    elseif pr.kind == "chat" then
        -- A question in the group chat: lore, a ruling, Thursday's plan. Your answer goes in the chat.
        local m = pr.msg
        kit.text(x + 24, box_y + 18, "A QUESTION FOR YOU, IN THE GROUP CHAT", "ui14", theme.gold)
        kit.dot(x + 44, box_y + 70, 40, panels.COLORS[m.key] or theme.panel3)
        kit.picture(x + 26, box_y + 52, 36, 36, panels.face(m.key))
        kit.text(x + 76, box_y + 50, m.who .. " asks the group chat:", "ui18b", theme.text)
        kit.text(x + 76, box_y + 76, "\"" .. m.text .. "\"", "story22", theme.text, { w = w - 110, gloss = false })
        kit.text(x + 24, box_y + 150, "Everyone can see your answer. Lore, a ruling or a plan: how you answer is part of the game.",
            "ui18", theme.dim, { w = w - 48 })
        local q
        for _, d in ipairs(MODULE.chat_ask or {}) do
            if d.id == m.ask then
                q = d
            end
        end
        local by = box_y + 196
        for i, r in ipairs(q and q.replies or {}) do
            kit.button(x + 24, by, w - 48, 54, "", function()
                museum_week.answer_chat(c, m, i)
                app.refresh()
            end, { color = theme.panel2, hover = theme.button_hover, key = "chat_reply_" .. i })
            kit.text(x + 40, by + 15, r.label, "ui18b", theme.text, { w = w - 80, lines = 1 })
            by = by + 64
        end
        kit.button(x + 24, by, w - 48, 44, "", function()
            m.answered = 0
            app.refresh()
        end, { color = theme.panel, hover = theme.button_hover, key = "chat_reply_0" })
        kit.text(x + 40, by + 11, "Leave it. Someone else will answer.", "ui18", theme.dim)
    elseif pr.kind == "request" then
        local p = c:player(def.who)
        -- (One-on-one, not in the group chat: the playtest, November 3.)
        kit.text(x + 24, box_y + 18, "A PRIVATE MESSAGE", "ui14", theme.gold)
        kit.dot(x + 44, box_y + 70, 40, panels.COLORS[def.who] or theme.panel3)
        kit.picture(x + 26, box_y + 52, 36, 36, panels.face(def.who))
        kit.text(x + 76, box_y + 50, p.name .. " messages you, just you:", "ui18b", theme.text)
        kit.text(x + 76, box_y + 76, "\"" .. (pr.ask or def.ask) .. "\"", "story22", theme.text, { w = w - 110 })
        -- What they mean, when it's from a few sessions back (the playtest, November 3: "I don't remember
        -- that"): the request's own reminder, then the line every DM knows.
        local hint = (def.about and (def.about .. " ") or "") .. "Every DM gets these. Fair, absurd, or both: how do you answer?"
        -- (Three lines when it needs them: the reminder and the line every DM knows, in full.)
        local hn = math.min(3, #kit.wrap(hint, "ui18", w - 48))
        kit.text(x + 24, box_y + 136, hint, "ui18", theme.dim, { w = w - 48, lines = 3 })
        local by = box_y + 136 + hn * kit.line_height("ui18") + 17
        for _, ans in ipairs(MODULE.ANSWERS) do
            local a = def.answers[ans]
            kit.button(x + 24, by, w - 48, 92, "", function()
                adventure.answer_request(c, pr.id, ans)
                app.refresh()
            end, { color = theme.panel2, hover = theme.button_hover, key = "req_" .. ans })
            kit.text(x + 40, by + 8, MODULE.ANSWER_NAMES[ans], "ui18b", theme.gold)
            kit.text(x + 40, by + 32, adventure.request_reply(c, def, a), "ui18", theme.text, { w = w - 300, lines = 2 })
            chips(x + w - 250, by + 10, request_like(c, def, ans), 220)
            by = by + 100
        end
    elseif pr.kind == "loose" then
        kit.text(x + 24, box_y + 18, "A LOOSE END", "ui14", theme.gold)
        kit.text(x + 24, box_y + 50, def.text, "story22", theme.text, { w = w - 48 })
        kit.text(x + 24, box_y + 130, "Something in the adventure lost its place. Pick where it goes, so the story stays consistent.",
            "ui18", theme.dim, { w = w - 48 })
        local by = box_y + 186
        for i, o in ipairs(def.options) do
            kit.button(x + 24, by, w - 48, 64, "", function()
                adventure.answer_loose(c, pr.id, i)
                app.refresh()
            end, { color = theme.panel2, hover = theme.button_hover, key = "loose_" .. i })
            kit.text(x + 40, by + 20, o.label, "ui18b", theme.text, { w = w - 330, lines = 1 })
            chips(x + w - 280, by + 22, o.like, 250)
            by = by + 74
        end
    elseif pr.kind == "favor" then
        app.favor_pick = app.favor_pick or {}
        local pick = app.favor_pick
        kit.text(x + 24, box_y + 18, "A FAVOR: " .. string.upper(def.name), "ui14", theme.gold)
        kit.text(x + 24, box_y + 50, def.text, "story22", theme.text, { w = w - 48 })
        local function column(cx, title, opts, field)
            kit.text(cx, box_y + 150, title, "ui14", theme.dim)
            local by = box_y + 176
            for i, o in ipairs(opts) do
                local on = pick[field] == i
                if on then
                    kit.box(cx - 3, by - 3, (w - 72) / 2 + 6, 70, theme.select, { radius = 9 })
                end
                kit.button(cx, by, (w - 72) / 2, 64, o.label, function()
                    pick[field] = i
                    app.refresh()
                end, { font = "ui18", color = on and theme.panel3 or theme.panel2, hover = theme.button_hover,
                       key = "favor_" .. field .. "_" .. i })
                by = by + 76
            end
        end
        column(x + 24, "ONE WAY IT HELPS THEM", def.helps, "help")
        column(x + 48 + (w - 72) / 2, "ONE WAY IT HURTS THEM", def.hurts, "hurt")
        kit.button(x + w - 244, box_y + 560, 220, 50, "Done  >", function()
            adventure.answer_favor(c, pr.id, pick.help, pick.hurt)
            app.favor_pick = nil
            app.refresh()
        end, { enabled = pick.help ~= nil and pick.hurt ~= nil, color = theme.go, hover = theme.go_hover, font = "ui22b",
               key = "favor_done" })
    end
    kit.text(x, 770, #list > 1 and ("Then " .. util.int(#list - 1) .. " more, then the prep board.") or "Then the prep board.",
        "ui14", theme.faint)
end

-- The museum map --------------------------------------------------------------------------------
-- The book's three floor plans, simplified: the garden and the ground floor (entrance, the two wings,
-- the gift shop and its stairs), the second floor (the Hunting Grounds round the studies, the World
-- of Tomorrow and the lecture theatre), and her lair at the top. Each room sits where the book's
-- map has it; colour says where the party has been.

local function room_state(c, id)
    local st = adventure.fill(c.adv)
    if st.done[id] then
        return "done"
    elseif st.skipped[id] then
        return "skipped"
    elseif st.passed[id] then
        return "passed"
    end
    local prep = c.prep
    if prep and prep.museum and util.contains(prep.museum.ahead, id) then
        return "ahead"
    end
    return "later"
end

-- Each floor: its title, and every room as a box in the floor's own 0..1 frame.
local FLOORS = {
    { title = "GROUND FLOOR", rooms = {
        { "garden", 0.17, 0.0, 1.0, 0.40 }, { "street", 0.0, 0.08, 0.16, 0.32 },
        { "entrance", 0.30, 0.44, 0.70, 0.57 }, { "chamber", 0.04, 0.59, 0.48, 0.84 },
        { "paintings", 0.52, 0.59, 0.96, 0.84 }, { "gift_shop", 0.26, 0.86, 0.74, 1.0 } },
      pond = { 0.44, 0.07, 0.74, 0.22 } },
    { title = "SECOND FLOOR", rooms = {
        { "hunting", 0.0, 0.0, 1.0, 1.0 }, { "lecture", 0.04, 0.10, 0.40, 0.34 },
        { "tomorrow", 0.04, 0.40, 0.40, 0.64 }, { "offices", 0.44, 0.10, 0.70, 0.40 },
        { "stairs", 0.44, 0.46, 0.70, 0.64 } },
      label = { "hunting", 0.5, 0.78 }, down = { 0.80, 0.30, 0.96, 0.56 } },
    { title = "TOP FLOOR", rooms = { { "lair", 0.0, 0.0, 1.0, 1.0 } } },
}

local function state_colour(s, r)
    if r and r.boss and s ~= "done" then
        return kit.rgba("#6a2e26")
    end
    return (s == "done" and kit.rgba("#4f6a3e")) or (s == "skipped" and kit.rgba("#2a201b"))
        or (s == "passed" and kit.rgba("#6a4a2a")) or (s == "ahead" and theme.panel3) or theme.panel
end

local function floor_room(app, c, id, x, y, w, h, here, backdrop, inner, pond)
    local r = MODULE.rooms[id]
    local s = room_state(c, id)
    if s == "ahead" or here then
        kit.box(x - 2, y - 2, w + 4, h + 4, here and theme.teal or theme.gold, { radius = 7 })
    end
    local col = state_colour(s, r)
    if inner and (s == "later" or s == "ahead") then
        col = s == "ahead" and theme.panel3 or kit.rgba("#4a3a30")   -- (a room inside the big hall shows up on it)
    end
    kit.box(x, y, w, h, col, { radius = 6 })
    if backdrop then
        return s
    end
    if pond then
        -- (Deep blue, not teal: teal on this map is where the party is, the third playtest's engine run.)
        kit.box(pond[1], pond[2], pond[3], pond[4], kit.rgba("#24405f", 0.75), { radius = 12 })
        -- (And named: an unlabelled blue shape read as a button, the confirming playtest.)
        if pond[4] >= 16 and kit.width("pond", "ui14") <= pond[3] - 4 then
            kit.text(pond[1] + pond[3] / 2, pond[2] + (pond[4] - 18) / 2, "pond", "ui14", kit.rgba("#9fb8d0", 0.8),
                { pivot = gui.PIVOT_N, gloss = false })
        end
    end
    -- (A pixel each side, not three: "Street", "Offices" and "Tomorrow" fit their boxes on the
    -- prep board; a box too small still names its room in full on hover.)
    -- On a smaller map (the boss board, the journey, the notes) the name is drawn smaller to fit its box, down
    -- to seven tenths, before it's ever cut (the confirming playtest: "S...", "Offi...", "Tomorr...").
    local label = r.map or (string.gsub(r.name, "^The ", ""))
    local font = "ui14"
    local scale
    local lw = kit.width(label, font)
    if lw > w - 2 then
        -- (At the smallest, it may reach a little onto the box's border: "Street" on the journey's map.)
        scale = math.max(0.7, (w - 2) / lw)
        if lw * scale > w + 4 + 0.01 then
            label = kit.ellipsize(label, font, (w + 4) / scale)
        end
        lw = kit.width(label, font) * scale
    end
    local ty = pond and (pond[2] + pond[4] + 2) or (y + math.max(1, (h - 18 * (scale or 1)) / 2))
    kit.text(x + w / 2, ty, label, font, (s == "skipped") and theme.faint or theme.text, { pivot = gui.PIVOT_N, scale = scale })
    if s == "done" and w > 34 and lw <= w - 26 then     -- (never over the name)
        kit.text(x + w - 4, y + 1, "v", "ui14", theme.green, { pivot = gui.PIVOT_NE })
    end
    return s
end

-- The heroes whose reason for coming pays off in a room: their faces in its corner.
local function faces(c, id, x, y)
    local hx = x + 9
    for _, p in ipairs(adventure.hooked(c, id)) do
        kit.dot(hx, y + 9, 16, panels.COLORS[p.key] or theme.panel3)
        kit.picture(hx - 7, y + 2, 14, 14, panels.face(p.key))
        hx = hx + 15
    end
end

-- Where the party stands: four little dots in their colours.
local function party_dots(c, x, y)
    for i, key in ipairs(content.players.order) do
        if c:player(key) then
            kit.dot(x + (i - 1) * 8, y, 8, panels.COLORS[key] or theme.text)
        end
    end
end

-- The floors as this adventure has them: the book's plans above when they fit its rooms (the museum),
-- else MODULE.floors, else one floor per part with each room where its `at` puts it (0..100).
local floors_cache
local function floors()
    if floors_cache then
        return floors_cache
    end
    local fits = true
    for _, fl in ipairs(FLOORS) do
        for _, rm in ipairs(fl.rooms) do
            fits = fits and MODULE.rooms[rm[1]] ~= nil
        end
    end
    for _, id in ipairs(MODULE.order or {}) do
        local found = false
        for _, fl in ipairs(FLOORS) do
            for _, rm in ipairs(fl.rooms) do
                found = found or rm[1] == id
            end
        end
        fits = fits and found
    end
    if MODULE.floors then
        floors_cache = MODULE.floors
    elseif fits then
        floors_cache = FLOORS
    else
        local by = {}
        local parts = {}
        for _, id in ipairs(MODULE.order or {}) do
            local r = MODULE.rooms[id]
            local part = r.part or 1
            if not by[part] then
                by[part] = { title = "PART " .. util.int(part), rooms = {} }
                table.insert(parts, part)
            end
            local at = r.at or { 50, 50 }
            local cx, cy = at[1] / 100, at[2] / 100
            table.insert(by[part].rooms, { id, math.max(0, cx - 0.14), math.max(0, cy - 0.1), math.min(1, cx + 0.14),
                                           math.min(1, cy + 0.1) })
        end
        table.sort(parts)
        floors_cache = {}
        for _, part in ipairs(parts) do
            table.insert(floors_cache, by[part])
        end
    end
    return floors_cache
end

-- Where each floor goes in a map box (the same sums draw_map has always done).
local function floor_frames(x, y, w, h, opts)
    local pad = 10
    local ix, iy, iw, ih = x + pad, y + 8, w - 2 * pad, h - 16 - (opts.legend and 20 or 0)
    local fls = floors()
    local out = {}
    if w / h >= 2.2 or #fls ~= 3 then
        -- Wide (the prep board): the floors side by side, the ground floor biggest.
        local shares = #fls == 3 and { 0.40, 0.36, 0.24 } or nil
        local fx = ix
        for i, fl in ipairs(fls) do
            local share = shares and shares[i] or (1 / #fls)
            local fw = iw * share - (i < #fls and 14 or 0)
            table.insert(out, { fl = fl, x = fx, y = iy, w = fw, h = ih })
            fx = fx + iw * share
        end
    else
        -- Squarer (the showdown, the notes, the recap): the ground floor left, the rest stacked.
        local lw = iw * 0.48
        table.insert(out, { fl = fls[1], x = ix, y = iy, w = lw - 10, h = ih })
        table.insert(out, { fl = fls[2], x = ix + lw, y = iy, w = iw - lw, h = ih * 0.58 - 6 })
        table.insert(out, { fl = fls[3], x = ix + lw + (iw - lw) * 0.2, y = iy + ih * 0.58, w = (iw - lw) * 0.6, h = ih * 0.42 })
    end
    return out
end

-- The floor plan in a map box, as rectangles: { rooms = { [id] = { x, y, w, h, floor, backdrop } },
-- floors = { { fl, x, y, w, h } }, doors = { { a, b, x, y } } }. game/ui/ties_view.lua draws on it.
function M.plan(x, y, w, h, opts)
    opts = opts or {}
    local out = { rooms = {}, floors = floor_frames(x, y, w, h, opts), doors = {} }
    for fi, f in ipairs(out.floors) do
        local fy, fh = f.y + 18, f.h - 18
        f.inner = { f.x, fy, f.w, fh }
        local function rect(rr)
            return f.x + rr[1] * f.w, fy + rr[2] * fh, (rr[3] - rr[1]) * f.w, (rr[4] - rr[2]) * fh
        end
        for i, rm in ipairs(f.fl.rooms) do
            local rx, ry, rw, rh = rect({ rm[2], rm[3], rm[4], rm[5] })
            out.rooms[rm[1]] = { x = rx, y = ry, w = rw, h = rh, floor = fi, backdrop = (i == 1 and f.fl.label ~= nil) }
        end
        if f.fl.label then
            local lr = out.rooms[f.fl.rooms[1][1]]
            lr.label_at = { f.x + f.fl.label[2] * f.w, fy + f.fl.label[3] * fh }
        end
        if f.fl.down then
            local dx, dy, dw, dh = rect(f.fl.down)
            f.down = { dx + dw / 2, dy + dh / 2 }
        end
    end
    -- Each door's spot: between two rooms on one floor; on a room inside a hall, on its edge toward
    -- the hall's name; a way up, on the upper floor (by its "down" if it has one).
    local function clamp(px, py, r)
        return math.max(r.x, math.min(r.x + r.w, px)), math.max(r.y, math.min(r.y + r.h, py))
    end
    for _, d in ipairs(ties.doors()) do
        local a, b = out.rooms[d[1]], out.rooms[d[2]]
        if a and b then
            local px, py
            if a.floor == b.floor then
                local outer, inner = (a.backdrop and a) or (b.backdrop and b), nil
                if outer then
                    inner = outer == a and b or a
                    local ax = outer.label_at or { outer.x + outer.w / 2, outer.y + outer.h / 2 }
                    px, py = clamp(ax[1], ax[2], inner)
                else
                    local ax, ay = clamp(b.x + b.w / 2, b.y + b.h / 2, a)
                    local bx, by = clamp(a.x + a.w / 2, a.y + a.h / 2, b)
                    px, py = (ax + bx) / 2, (ay + by) / 2
                end
            else
                local up = a.floor > b.floor and a or b
                local f = out.floors[up.floor]
                if f.down and up.backdrop then
                    px, py = f.down[1], f.down[2]
                else
                    px, py = up.x + up.w / 2, up.y + up.h - 10
                end
            end
            -- Two doors on one spot (a room off the hall with a door to its neighbour too): slide this one over.
            local function crowded(qx, qy)
                for _, o in ipairs(out.doors) do
                    if math.abs(o.x - qx) < 26 and math.abs(o.y - qy) < 26 then
                        return true
                    end
                end
                return false
            end
            if crowded(px, py) then
                for _, off in ipairs({ { 30, 0 }, { -30, 0 }, { 0, 30 }, { 0, -30 }, { 30, 30 }, { -30, -30 } }) do
                    if not crowded(px + off[1], py + off[2]) then
                        px, py = px + off[1], py + off[2]
                        break
                    end
                end
            end
            table.insert(out.doors, { a = d[1], b = d[2], x = px, y = py })
        end
    end
    return out
end

-- The DM's locks on the floor plan (game/model/ties.lua): a small lock on a room or door that's
-- shut, a faded one on what a lock is holding in some other way (a person, a card).
function M.draw_locks(app, plan, size)
    local c = app.campaign
    if not (c.adv and c.adv.locks and #c.adv.locks > 0) then
        return
    end
    size = size or 14
    for _, l in ipairs(c.adv.locks) do
        if not l.open then
            if l.kind == "room" and plan.rooms[l.room] then
                local r = plan.rooms[l.room]
                local lx = r.label_at and (r.label_at[1] - size / 2) or (r.x + r.w - size - 3)
                local ly = r.label_at and (r.label_at[2] - size - 4) or (r.y + 3)
                kit.box(lx - 2, ly - 2, size + 4, size + 4, kit.rgba("#000000", 0.55), { radius = 5 })
                kit.icon(lx, ly, size, "lock", theme.gold)
            elseif l.kind == "door" then
                for _, d in ipairs(plan.doors) do
                    if (d.a == l.a and d.b == l.b) or (d.a == l.b and d.b == l.a) then
                        kit.box(d.x - size / 2 - 2, d.y - size / 2 - 2, size + 4, size + 4, kit.rgba("#000000", 0.55), { radius = 5 })
                        kit.icon(d.x - size / 2, d.y - size / 2, size, "lock", theme.gold)
                    end
                end
            end
        end
    end
end

local function draw_floor(app, c, fl, x, y, w, h)
    kit.text(x, y, fl.title, "ui14", theme.dim)
    y, h = y + 18, h - 18
    local st = adventure.fill(c.adv)
    local here = st.pos or st.last_room
    local function rect(rr)
        return x + rr[1] * w, y + rr[2] * h, (rr[3] - rr[1]) * w, (rr[4] - rr[2]) * h
    end
    for i, rm in ipairs(fl.rooms) do
        local id = rm[1]
        local rx, ry, rw, rh = rect({ rm[2], rm[3], rm[4], rm[5] })
        local backdrop = (i == 1 and fl.label ~= nil)
        local pond
        if id == "garden" and fl.pond then
            pond = { rect(fl.pond) }
        end
        floor_room(app, c, id, rx, ry, rw, rh, here == id, backdrop, fl.label ~= nil and i > 1, pond)
        if backdrop then
            -- The big hall the other rooms open off: its name at the bottom.
            local lx, ly = x + fl.label[2] * w, y + fl.label[3] * h
            local r = MODULE.rooms[id]
            kit.text(lx, ly, r.map or r.name, "ui14", theme.text, { pivot = gui.PIVOT_N })
            if room_state(c, id) == "done" then
                kit.text(lx + kit.width(r.map or r.name, "ui14") / 2 + 4, ly, "v", "ui14", theme.green)
            end
        end
        faces(c, id, rx, ry)
        -- The party's dots only where they clear the room's name (the third playtest's engine run:
        -- dots over "Ancients", "Gift shop", "Lecture"); the teal outline says where they are anyway.
        if here == id and (backdrop or rh > 56) then
            party_dots(c, rx + rw - 34, ry + rh - 8)
        end
    end
    if fl.down then
        local dx, dy, dw, dh = rect(fl.down)
        kit.box(dx, dy, dw, dh, kit.rgba("#000000", 0.25), { radius = 4 })
        -- (Under its box, clear of the stair mark in it: the confirming playtest's engine run had the mark on
        -- the word on every map.)
        kit.text(dx + dw / 2, dy + dh + 1, "down", "ui14", theme.faint, { pivot = gui.PIVOT_N, gloss = false })
    end
end

local function room_label(id)
    local r = MODULE.rooms[id]
    return r and (r.map or (string.gsub(r.name, "^The ", ""))) or id
end

-- The stairs between floors (the playtest, November 3: "it isn't clear where the stairs are or how
-- they go between floors"): a stair mark at each end of every flight, with a hover saying where it goes.
function M.draw_stairs(app, plan)
    for _, d in ipairs(plan.doors) do
        local a, b = plan.rooms[d.a], plan.rooms[d.b]
        if a and b and a.floor ~= b.floor then
            local lo_id, hi_id = d.a, d.b
            if a.floor > b.floor then
                lo_id, hi_id = d.b, d.a
            end
            local lo, hi = plan.rooms[lo_id], plan.rooms[hi_id]
            local f = plan.floors[hi.floor]
            -- (Up: just left of the room's name, clear of the faces and the done tick.)
            local lw = math.min(kit.width(room_label(lo_id), "ui14"), lo.w - 6)
            local ux, uy = lo.x + lo.w / 2 - lw / 2 - 28, lo.y + math.max(1, (lo.h - 18) / 2)     -- (its arrow clear of the name)
            if lo.w - lw < 60 then
                ux, uy = lo.x + lo.w - 19, lo.y + 2       -- (a narrow room: its top corner, off the name)
                -- (On a small map even the corner is on the name, "Gift shop" on the boss board and the journey: just
                -- outside the room's right edge then.)
                local ny = lo.y + math.max(1, (lo.h - 18) / 2)
                if lo.x + lo.w / 2 + lw / 2 > ux - 1 and uy + 16 > ny then
                    ux = lo.x + lo.w + 2
                end
            end
            local ends = {
                { x = ux, y = uy, title = "Stairs up", dir = "up",
                  text = "From " .. room_label(lo_id) .. " up to " .. room_label(hi_id) .. ", on the floor above." },
            }
            if hi.backdrop and f.down then
                table.insert(ends, { x = f.down[1] - 8, y = f.down[2] - 24, title = "Stairs down", dir = "down",
                    text = "From " .. room_label(hi_id) .. " down to " .. room_label(lo_id) .. ", on the floor below." })
            else
                table.insert(ends, { x = hi.x + 3, y = hi.y + hi.h - 19, title = "Stairs down", dir = "down",
                    text = "From " .. room_label(hi_id) .. " down to " .. room_label(lo_id) .. ", on the floor below." })
            end
            -- (A room that is the stairs, by its name, needs no mark of its own.)
            if string.find(string.lower(room_label(lo_id)), "stair", 1, true) then
                table.remove(ends, 1)
            end
            for _, e in ipairs(ends) do
                kit.box(e.x - 1, e.y - 1, 18, 18, kit.rgba("#000000", 0.55), { radius = 4 })
                kit.icon(e.x, e.y, 16, "stairs", theme.gold)
                -- Which way they go (the playtest, November 3: the stairs up from below read as more stairs up).
                if e.dir then
                    kit.box(e.x + 11, e.y - 6, 12, 12, kit.rgba("#000000", 0.7), { radius = 6 })
                    kit.icon(e.x + 12, e.y - 5, 10, e.dir, e.dir == "up" and theme.green or theme.orange)
                end
                local gloss = util.lazy("game.ui.gloss")
                if gloss.card_spot then
                    gloss.card_spot(e.x - 2, e.y - 2, 20, 20, e.title, e.text)
                end
            end
        end
    end
end

function M.draw_map(app, x, y, w, h, opts)
    local c = app.campaign
    opts = opts or {}
    kit.box(x, y, w, h, kit.rgba("#000000", 0.22), { radius = 10 })
    for _, f in ipairs(floor_frames(x, y, w, h, opts)) do
        draw_floor(app, c, f.fl, f.x, f.y, f.w, f.h)
    end
    local plan = M.plan(x, y, w, h, opts)
    M.draw_stairs(app, plan)
    -- What the DM has locked (the tie-and-lock editor).
    if c.adv and c.adv.locks and #c.adv.locks > 0 then
        M.draw_locks(app, plan)
    end
    if opts.legend then
        local lx = x + 12
        kit.icon(lx, y + h - 21, 14, "stairs", theme.gold)
        kit.text(lx + 18, y + h - 22, "stairs.  Gold: tonight.  Green: done.  Brown: walked past.  Teal: where they are.  "
            .. "Faces: why a hero came.", "ui14", theme.faint, { w = w - 42, lines = 1 })
    end
end

-- Euryale's card -------------------------------------------------------------------------------

-- opts.fit: no taller than its marks need (the showdown: room for the rows under it). Returns the
-- height it took.
function M.boss_card(app, x, y, w, h, big, opts)
    local c = app.campaign
    local card = adventure.boss_card(c)
    if opts and opts.fit and #card.marks > 0 then
        local head = (big and 70 or 58) + kit.text_height(card.line, "ui14", w - 32) + 10 + 22
        local tw = w - 46
        local least = math.huge
        for _, try in ipairs({ "full", "medium" }) do
            local total = 0
            for _, m in ipairs(card.marks) do
                if try == "full" then
                    total = total + 24 + kit.text_height(m.showdown .. ". (" .. (m.why or "") .. ".)", "ui14", tw) + 6
                elseif kit.width(m.name, "ui18b") + 10 + kit.width(m.showdown .. ".", "ui14") <= tw then
                    total = total + 22
                else
                    total = total + 22 + math.min(2, #kit.wrap(m.showdown .. ".", "ui14", tw)) * kit.line_height("ui14") + 3
                end
            end
            if head + total + 12 <= h then
                least = head + total + 12
                break
            end
        end
        h = math.min(h, least)
    end
    kit.box(x, y, w, h, kit.rgba("#3a1f1a"), { radius = 12 })
    kit.box(x + 4, y + 4, w - 8, h - 8, kit.rgba("#2a1714"), { radius = 10 })
    kit.text(x + 16, y + 10, "UPSTAIRS", "ui14", theme.red)
    kit.text(x + 16, y + 28, card.name, big and "title30" or "ui22b", theme.gold)
    local ty = y + (big and 70 or 58)
    kit.text(x + 16, ty, card.line, "ui14", theme.dim, { w = w - 32, lines = 3 })
    ty = ty + kit.text_height(card.line, "ui14", w - 32) + 10
    if #card.marks == 0 then
        kit.text(x + 16, ty, "No marks yet. Everything the party does on the way up can change this card.", "ui14", theme.faint,
            { w = w - 32 })
        return h
    end
    kit.text(x + 16, ty, "MARKS FROM THE BUILD-UP  (" .. util.int(#card.marks) .. ")", "ui14", theme.dim)
    ty = ty + 22
    -- Every mark, always inside the card (the engine run, October 30: the sixth spilled out over the
    -- showdown's rows): each with what it changes and why; when that won't fit, what it changes in full
    -- (beside its name, or under it), never cut (the third playtest: "She skips the drink...", "They
    -- come up..."). Pointing at a mark always gives all of it, with its cause.
    local tw = w - 46
    local function said(m)
        return m.showdown .. ". (" .. (m.why or "") .. ".)"
    end
    local function beside(m)
        return kit.width(m.name, "ui18b") + 10 + kit.width(m.showdown .. ".", "ui14") <= tw
    end
    local function row_h(m, mode)
        if mode == "full" then
            return 24 + kit.text_height(said(m), "ui14", tw) + 6
        elseif mode == "medium" then
            return beside(m) and 22 or (22 + math.min(2, #kit.wrap(m.showdown .. ".", "ui14", tw)) * kit.line_height("ui14") + 3)
        end
        return 22
    end
    -- (When even that won't fit, the marks that do fit, each in full, and "+N more" for the rest: never a
    -- mark's effect cut short, the confirming playtest's seven marks beside the story list.)
    local mode = "medium"
    for _, try in ipairs({ "full", "medium" }) do
        local total = 0
        for _, m in ipairs(card.marks) do
            total = total + row_h(m, try)
        end
        if ty + total <= y + h - 10 then
            mode = try
            break
        end
    end
    local gl = util.lazy("game.ui.gloss")
    for i, m in ipairs(card.marks) do
        local rowh = row_h(m, mode)
        if ty + (mode == "compact" and 18 or rowh - 6) > y + h - 8 then
            local rest = #card.marks - i + 1
            kit.text(x + w - 16, y + 10, "+" .. util.int(rest) .. " more: Notes, Upstairs", "ui14", theme.faint,
                { pivot = gui.PIVOT_NE })
            if gl.card_spot then
                gl.card_spot(x + w - 16 - kit.width("+" .. util.int(rest) .. " more: Notes, Upstairs", "ui14"), y + 8,
                    kit.width("+" .. util.int(rest) .. " more: Notes, Upstairs", "ui14"), 20, "More marks",
                    "Her card has " .. util.int(rest) .. " more marks than fit here. Your notes (N), on the Upstairs page, "
                    .. "show every one: what it changes on boss night, and why it's there.")
            end
            break
        end
        -- (Under its words: a rules word in it keeps its own hover.)
        if gl.card_spot then
            gl.card_spot(x + 12, ty - 2, w - 28, rowh - 2, m.name, said(m))
        end
        kit.box(x + 16, ty + 7, 6, 6, theme.gold, { radius = 3 })
        kit.text(x + 30, ty, m.name, "ui18b", theme.text, { w = tw, lines = 1 })
        if mode == "full" then
            kit.text(x + 30, ty + 22, said(m), "ui14", theme.dim, { w = tw, lines = 2 })
        elseif beside(m) then
            kit.text(x + 30 + kit.width(m.name, "ui18b") + 10, ty + 3, m.showdown .. ".", "ui14", theme.dim)
        elseif mode == "medium" then
            kit.text(x + 30, ty + 21, m.showdown .. ".", "ui14", theme.dim, { w = tw, lines = 2 })
        else
            local nw = kit.width(m.name, "ui18b")
            kit.text(x + 30 + nw + 10, ty + 3, m.showdown .. ".", "ui14", theme.dim, { w = math.max(40, tw - 10 - nw), lines = 1 })
        end
        ty = ty + rowh
    end
    return h
end

-- Tonight's rooms ------------------------------------------------------------------------------

-- What prepping a room does, for its button's hover and the list's header (the playtest, November 3:
-- "it's unclear what prep it actually does, and what happens if something's not prepped").
local PREP_WHAT = "You read the room ahead, set out its map and minis, and practise its voices. A prepped room "
    .. "plays at its best. One you didn't prep still plays, but thinner: you skim the page while they wait "
    .. "(everyone gets a little bored), and its moments land weaker."


-- A room's row, laid out once for drawing and for the list's paging (the third playtest: the rows
-- cut off what mattered most, "Sam's veil: kruthik huntlings, armoured a...", "...the first hint of
-- something called the..."). The room's summary gets two lines; what prepping it means gets a line;
-- each Session Zero ask it touches (a line, a veil) gets a line of its own, so what to avoid is
-- always there to read; anything still too long shows in full on hover.
local SUM_W = 230       -- (the summary keeps clear of the Prep button and the "Unprepped" note)
local function row_parts(c, id, w)
    local r = MODULE.rooms[id]
    local out = { plain = {}, asks = {}, h = 50 }
    if r.virtual then
        return out
    end
    for _, n in ipairs(museum_week.room_prep(c, id)) do
        table.insert(n.kind == "ask" and out.asks or out.plain, n)
    end
    local sides = map_repo.side_rooms_off(c, id)
    local sum = r.sum
    if #sides > 0 then
        local names = {}
        for _, sid in ipairs(sides) do
            table.insert(names, c.adv.side_rooms[sid].name)
        end
        sum = "Side room off here: " .. util.join_names(names) .. ". " .. sum
    end
    out.sum, out.sides = sum, #sides > 0
    out.sum_lines = math.min(2, #kit.wrap(sum, "ui14", w - SUM_W))
    out.h = 54 + (out.sum_lines - 1) * kit.line_height("ui14") + (#out.plain > 0 and 22 or 0) + #out.asks * 22
        + #(r.knobs or {}) * 30
    return out
end

local function room_row(app, prep, id, x, y, w)
    local c = app.campaign
    local r = MODULE.rooms[id]
    local pm = prep.museum
    local knobs = r.knobs or {}
    -- What prepping it really means: minis, voices, handouts, a Session Zero ask it touches.
    local parts = row_parts(c, id, w)
    local h = parts.h
    kit.box(x, y, w, h, theme.panel, { radius = 10 })
    kit.box(x, y, 6, h, theme.scene[r.type] or theme.panel3, { radius = 3 })
    kit.text(x + 18, y + 8, r.name, "ui18b", theme.text)
    local nx = x + 18 + kit.width(r.name, "ui18b") + 10
    local tn = content.scenes[r.type] and content.scenes[r.type].name or r.type
    local tl = tn .. (r.quick and ", short" or "")
    kit.text(nx, y + 11, tl, "ui14", theme.dim)
    -- The map it plays on (v2: any map from the repository); a click opens the repository on it.
    if not r.virtual then
        local ref = map_repo.room_map(c, id)
        local e = ref and map_repo.find(c, ref)
        local label = e and ("Map: " .. e.title) or "Book's map"
        local mx = nx + kit.width(tl, "ui14") + 12
        local mw = math.min(kit.width(label, "ui14") + 30, x + w - 196 - mx)
        if mw > 70 then
            kit.button(mx, y + 8, mw, 22, kit.ellipsize(label, "ui14", mw - 28), function()
                if app.open_maps then
                    local lid = r.comps and r.comps.location
                    local own = content.terrain.by_location[lid or ""]
                    app.open_maps(ref or (own and ("board:" .. own)) or nil)
                end
            end, { font = "ui14", color = e and theme.go or theme.panel2, hover = theme.button_hover, key = "room_map_" .. id })
        end
    end
    local lh = kit.line_height("ui14")
    if parts.sum then
        kit.text(x + 18, y + 30, parts.sum, "ui14", parts.sides and theme.gold or theme.dim, { w = w - SUM_W, lines = 2 })
    end
    if not r.virtual and (r.cost or 0) > 0 then
        local on = pm.prepped[id]
        local label = on and ("Prepped  (" .. util.int(r.cost) .. "h)") or ("Prep it  (" .. util.int(r.cost) .. "h)")
        kit.button(x + w - 186, y + 8, 172, 32, label, function()
            museum_week.set_prepped(prep, id, not on)
            app.refresh()
        end, { font = "ui18b", color = on and theme.go or theme.button, hover = on and theme.go_hover or theme.button_hover,
               enabled = on or museum_week.can_prep(prep, id), key = "prep_" .. id })
        local gl = util.lazy("game.ui.gloss")
        if gl.card_spot then
            gl.card_spot(x + w - 186, y + 8, 172, 32, on and "Prepped" or ("Prep " .. util.lower_first(r.name)),
                PREP_WHAT .. " This one takes " .. util.int(r.cost) .. (r.cost == 1 and " hour." or " hours.")
                .. (on and " Click again to take the hours back." or ""))
        end
        if not on and #knobs == 0 then
            kit.text(x + w - 14, y + 42, "Unprepped: it plays thinner.", "ui14", theme.faint, { pivot = gui.PIVOT_NE })
        end
    end
    local ny = y + 50 + ((parts.sum_lines or 1) - 1) * lh
    local ky = y + 52 + ((parts.sum_lines or 1) - 1) * lh
    if #parts.plain > 0 then
        local bits, full = {}, {}
        for _, n in ipairs(parts.plain) do
            table.insert(bits, n.text)
            table.insert(full, n.text .. ".")
        end
        -- (All of it on hover: a long room's notes don't fit one line.)
        local gloss = util.lazy("game.ui.gloss")
        if gloss.card_spot then
            gloss.card_spot(x + 14, ny - 2, w - 28, 20, "Prepping " .. util.lower_first(r.name), table.concat(full, " "))
        end
        kit.text(x + 18, ny, table.concat(bits, ".  "), "ui14", theme.faint, { w = w - 36, lines = 1 })
        ny, ky = ny + 22, ky + 22
    end
    -- What a friend asked for at Session Zero, where this room touches it: a line each, in their colour.
    for _, n in ipairs(parts.asks) do
        kit.text(x + 18, ny, n.text .. ".", "ui14", theme.teal, { w = w - 36, lines = 1 })
        ny, ky = ny + 22, ky + 22
    end
    for _, kid in ipairs(knobs) do
        local k = MODULE.knobs[kid]
        local val = pm.knobs[kid]
        if k.pick_hero then
            kit.text(x + 18, ky + 6, k.name .. (k.cost and ("  (" .. util.int(k.cost) .. "h)") or "") .. ":", "ui14", theme.text)
            local bx = x + 18 + kit.width(k.name .. "  (1h):", "ui14") + 10
            for _, key in ipairs(content.players.order) do
                local p = c:player(key)
                local on = val == key
                local bw = kit.width(p.char, "ui14") + 18
                kit.button(bx, ky, bw, 26, p.char, function()
                    museum_week.set_knob(prep, kid, (not on) and key or nil)
                    app.refresh()
                end, { font = "ui14", color = on and theme.go or theme.button, hover = theme.button_hover, key = "knob_" .. kid .. "_" .. key })
                bx = bx + bw + 6
            end
        else
            local on = val and true or false
            kit.button(x + 18, ky, 30, 26, on and "x" or "", function()
                museum_week.set_knob(prep, kid, (not on) or nil)
                app.refresh()
            end, { font = "ui14", color = on and theme.go or theme.button, hover = theme.button_hover, key = "knob_" .. kid })
            local text = on and k.name or (k.name .. "?")
            kit.text(x + 56, ky + 4, text, "ui14", on and theme.text or theme.dim, { w = w - 330, lines = 1 })
            chips(x + w - 268, ky + 3, k.like, 254)
        end
        ky = ky + 30
    end
    return h
end

local function room_height(c, id, w)
    return row_parts(c, id, w or COL_MW).h
end

-- What to do with hours left over (museum_week.SPARE), at the foot of the list: each in full, on
-- two lines when it needs them (the third playtest: "Write a backup page (1h): The first room tonight
-- you didn't prep (a side room, a detour, one past tonight's)...").
local function spare_line(d)
    return d.name .. " (" .. util.int(d.cost) .. "h): " .. d.what
end
local function spare_h(w)
    local h = 22 + 24
    for _, d in ipairs(museum_week.SPARE) do
        h = h + 30 + (#kit.wrap(spare_line(d), "ui14", w - 40) > 1 and kit.line_height("ui14") or 0)
    end
    return h
end

local function spare_block(app, prep, x, y, w)
    local pm = prep.museum
    local left = prep:left()
    kit.text(x, y, "SPARE HOURS", "ui14", theme.dim)
    kit.text(x + 110, y, left > 0 and (util.int(left) .. (left == 1 and " hour left" or " hours left")) or "none left", "ui14",
        left > 0 and theme.gold or theme.faint)
    local ky = y + 22
    for _, d in ipairs(museum_week.SPARE) do
        local on = pm.spare and pm.spare[d.id]
        kit.button(x, ky, 30, 26, on and "x" or "", function()
            museum_week.set_spare(prep, d.id, not on)
            app.refresh()
        end, { font = "ui14", color = on and theme.go or theme.button, hover = theme.button_hover,
               enabled = on or left >= d.cost, key = "spare_" .. d.id })
        local line = spare_line(d)
        kit.text(x + 38, ky + 4, line, "ui14", on and theme.text or theme.dim, { w = w - 40, lines = 2 })
        ky = ky + 30 + (#kit.wrap(line, "ui14", w - 40) > 1 and kit.line_height("ui14") or 0)
    end
    local talk = require("game.model.prep").TALK_COST
    kit.text(x, ky, "Or talk to a friend (" .. util.int(talk) .. "h) from their card on the right. Hours you don't use carry to "
        .. "next week, up to " .. util.int(museum_week.CARRY_MAX) .. ".", "ui14", theme.faint, { w = w, lines = 1 })
end

-- The rooms, a page at a time when they don't all fit (the playtest, November 3: the list ran off the
-- bottom of the screen). The mouse wheel or the arrows page through them.
local function rooms(app, prep, x, y, w, max_y)
    local c = app.campaign
    local pm = prep.museum
    if app.rooms_week ~= c.week then
        app.rooms_week, app.rooms_first = c.week, 1
    end
    kit.text(x, y, "TONIGHT'S ROOMS", "ui14", theme.dim)
    local hint = "The party picks the way. Prep where they'll go."
    kit.text(x + w - 298, y, hint, "ui14", theme.faint, { pivot = gui.PIVOT_NE })
    local gloss = util.lazy("game.ui.gloss")
    if gloss.card_spot then
        gloss.card_spot(x, y - 2, w - 300, 20, "Prepping a room", PREP_WHAT .. " The party chooses where it goes, so prep "
            .. "the rooms you think they'll reach.")
    end
    kit.button(x + w - 140, y - 6, 140, 26, "All maps", function()
        if app.open_maps then
            app.open_maps()
        end
    end, { font = "ui14", key = "open_maps" })
    -- The tie-and-lock editor (game/ui/ties_view.lua): lock a way or a card, tie one thing to another.
    local n = #(c.adv.locks or {}) + #(c.adv.ties or {})
    kit.button(x + w - 140 - 8 - 140, y - 6, 140, 26, n > 0 and ("Ties and locks (" .. util.int(n) .. ")") or "Ties and locks",
        function()
            if app.open_ties then
                app.open_ties()
            end
        end, { font = "ui14", color = n > 0 and theme.go or nil, hover = n > 0 and theme.go_hover or nil, key = "open_ties" })
    y = y + 22
    -- The list: every room, then the spare hours.
    local items, hs = {}, {}
    for _, id in ipairs(pm.ahead) do
        table.insert(items, id)
        table.insert(hs, room_height(c, id, w) + 6)
    end
    table.insert(items, "spare")
    table.insert(hs, spare_h(w))
    local avail = max_y - y
    local total = 0
    for _, h in ipairs(hs) do
        total = total + h
    end
    local BAR = 28
    -- The last page: the furthest the list scrolls.
    local max_first = 1
    if total > avail then
        local sum = 0
        for i = #items, 1, -1 do
            sum = sum + hs[i]
            if sum + BAR > avail then
                max_first = math.min(#items, i + 1)
                break
            end
        end
    end
    local first = util.clamp(app.rooms_first or 1, 1, max_first)
    app.rooms_first = first
    app.rooms_scroll = { x = x, y = y, w = w, h = avail, max = max_first }
    local function pager(py, label, dir, key)
        kit.button(x, py, w, BAR - 4, label, function()
            app.rooms_first = util.clamp((app.rooms_first or 1) + dir, 1, max_first)
            app.refresh()
        end, { font = "ui14", color = theme.panel2, hover = theme.button_hover, key = key })
    end
    if first > 1 then
        pager(y, "^   " .. util.int(first - 1) .. (first - 1 == 1 and " more above" or " more above") .. "   (scroll up)", -1, "rooms_up")
        y = y + BAR
    end
    local i = first
    while i <= #items do
        local more = i < #items
        if y + hs[i] + (more and BAR or 0) > max_y and i > first then
            break
        end
        if items[i] == "spare" then
            spare_block(app, prep, x, y + 4, w)
            y = y + hs[i]
        else
            y = y + room_row(app, prep, items[i], x, y, w) + 6
        end
        i = i + 1
    end
    if i <= #items then
        local rest = #items - i + 1
        pager(math.min(y, max_y - BAR + 4), "v   " .. util.int(rest) .. " more below   (scroll down)", 1, "rooms_down")
    end
end

-- The mouse wheel over tonight's rooms pages through them.
function M.on_wheel(app, x, y, dir)
    local a = app.rooms_scroll
    if app.screen ~= "prep" or app.overlay or app.ask or not a then
        return false
    end
    local ly = kit.H - y
    if x < a.x or x > a.x + a.w or ly < a.y or ly > a.y + a.h then
        return false
    end
    local was = app.rooms_first or 1
    app.rooms_first = util.clamp(was + dir, 1, a.max or 1)
    if app.rooms_first ~= was then
        app.refresh()
    end
    return true
end

-- Boss night: the showdown board --------------------------------------------------------------

local ONE_OF_A_KIND = { knight_of_shades = "the Knight of Shades", the_lecturer = "the Lecturer", sentinel = "the Sentinel",
    bone_construct = "the Bone Construct" }

local CHOICE_H = 94

-- Where this week's hours went, on the board (the confirming playtest: the boss board went from 10 hours
-- left to 8 with nothing on it saying why). Her lair's hours are spent for you on boss night.
function M.week_hours(app, prep, x, y, w)
    local c = app.campaign
    local pm = prep.museum
    local bits = {}
    local function hours(n)
        return util.int(n) .. (n == 1 and " hour" or " hours")
    end
    if pm.boss then
        table.insert(bits, "her lair, " .. hours(museum_week.room_cost("lair")) .. " (boss night always takes them)")
    end
    for _, id in ipairs(pm.ahead or {}) do
        if pm.prepped[id] and MODULE.rooms[id] then
            table.insert(bits, util.lower_first(MODULE.rooms[id].name) .. ", " .. hours(museum_week.room_cost(id)))
        end
    end
    for id, v in util.sorted_pairs(pm.knobs or {}) do
        local cost = museum_week.knob_cost(id, v)
        if cost > 0 and MODULE.knobs[id] then
            table.insert(bits, "\"" .. MODULE.knobs[id].name .. "\", " .. hours(cost))
        end
    end
    for _, key in ipairs(content.players.order) do
        local p = prep.talked and prep.talked[key] and c:player(key)
        if p then
            table.insert(bits, "a talk with " .. p.name .. ", " .. hours(prep.TALK_COST or 2))
        end
    end
    for _, d in ipairs(museum_week.SPARE) do
        if pm.spare and pm.spare[d.id] then
            table.insert(bits, string.lower(string.sub(d.name, 1, 1)) .. string.sub(d.name, 2) .. ", " .. hours(d.cost))
        end
    end
    if (prep.extra or 0) > 0 then
        table.insert(bits, "other prep, " .. hours(prep.extra))
    end
    kit.text(x, y, "YOUR WEEK", "ui14", theme.dim)
    local line = (#bits > 0 and ("Your hours went on " .. util.join_names(bits) .. ". ") or "No hours spent yet. ")
        .. util.int(prep:left()) .. " of " .. util.int(prep.budget) .. " left."
    kit.text(x, y + 22, line, "ui14", theme.text, { w = w, lines = 4 })
    return y + 22 + math.min(4, #kit.wrap(line, "ui14", w)) * kit.line_height("ui14")
end

local function showdown(app, prep, x, y, w)
    local c = app.campaign
    local st = c.adv
    st.boss = st.boss or { opener = "talk", style = "yields" }
    y = y + M.boss_card(app, x, y, w, 360, true, { fit = true }) + 16
    local enc = adventure.boss_encounter(c)
    local brings = {}
    if st.marks.mech then
        table.insert(brings, "the Steam Mech" .. (st.mech_name and (" (" .. st.mech_name .. ")") or ""))
    end
    -- (What they bring is what's in their packs, and whose: items.lua, the one inventory. Used up is
    -- gone; a healing potion is everyone's, so it isn't listed here.)
    local items_mod = require "game.model.items"
    for _, it in ipairs(items_mod.list(c)) do
        if not it.gone and not it.destroyed and it.id ~= items_mod.POTION then
            local who = it.holder and c:player(it.holder)
            table.insert(brings, util.lower_first(items_mod.about(it).name) .. (who and (" (" .. who.char .. ")") or ""))
        end
    end
    local with, count, seen = {}, {}, {}
    for i = 2, #enc.ids do
        count[enc.ids[i]] = (count[enc.ids[i]] or 0) + 1
    end
    for i = 2, #enc.ids do
        local id = enc.ids[i]
        if not seen[id] then
            seen[id] = true
            local name = (string.gsub(id, "_", " "))
            -- The book's one-of-a-kind foes go by their names ("the Knight of Shades").
            local one = ONE_OF_A_KIND[id]
            table.insert(with, one or (count[id] > 1 and (util.int(count[id]) .. " " .. name .. "s") or ("a " .. name)))
        end
    end
    -- (All of it: the third playtest's "WHAT THE PARTY BRINGS: ... the...".)
    local bring = #brings > 0 and util.join_names(brings) or "Themselves, and whatever's left in their packs."
    local bf = #kit.wrap(bring, "ui18", w - 220) > 3 and "ui14" or "ui18"       -- (a long list, smaller)
    kit.text(x, y, "WHAT THE PARTY BRINGS", "ui14", theme.dim)
    kit.text(x + 220, y, bring, bf, theme.text, { w = w - 220, lines = 4 })
    y = y + math.max(50, math.min(4, #kit.wrap(bring, bf, w - 220)) * kit.line_height(bf) + 6)
    kit.text(x, y, "WHO'S WITH HER", "ui14", theme.dim)
    kit.text(x + 220, y, #with > 0 and util.join_names(with) or "Nobody. She's alone with her statues.", "ui18", theme.text,
        { w = w - 220, lines = 2 })
    y = y + 54
    local function choice(title, field, defs, order)
        kit.text(x, y, title, "ui14", theme.dim)
        local bx = x
        local by = y + 22
        local bw = (w - 12) / 2
        for _, id in ipairs(order) do
            local d = defs[id]
            local on = st.boss[field] == id
            if on then
                kit.box(bx - 3, by - 3, bw + 6, CHOICE_H + 6, theme.select, { radius = 9 })
            end
            -- (The blurb in full, on two lines: the third playtest's "As in the book: a drink, some
            -- questions, then an...".)
            kit.button(bx, by, bw, CHOICE_H, "", function()
                st.boss[field] = id
                app.refresh()
            end, { color = on and theme.panel3 or theme.panel2, hover = theme.button_hover, key = "boss_" .. field .. "_" .. id })
            kit.text(bx + 12, by + 6, d.name, "ui18b", theme.text)
            kit.text(bx + 12, by + 30, d.blurb, "ui14", theme.dim, { w = bw - 24, lines = 2 })
            chips(bx + 12, by + CHOICE_H - 26, d.like, bw - 24)
            bx = bx + bw + 12
        end
        y = by + CHOICE_H + 14
    end
    choice("HOW SHE OPENS", "opener", MODULE.showdown.openers, { "talk", "ambush" })
    -- Her card beats the book's opening where they disagree, and the board says so (the third
    -- playtest: "She skips the drink and the small talk" beside "a drink, some questions...").
    if st.boss.opener == "talk" and st.marks.garden_burned then
        local said = "Her card wins here: " .. string.lower(string.sub(MODULE.marks.garden_burned.name, 1, 1))
            .. string.sub(MODULE.marks.garden_burned.name, 2) .. ", so there's no drink and no small talk. She goes "
            .. "straight to her ultimatum."
        kit.text(x, y - 6, said, "ui14", theme.orange, { w = w, lines = 2 })
        y = y + math.min(2, #kit.wrap(said, "ui14", w)) * kit.line_height("ui14") + 8
    end
    -- What an ambush throws away: everything on her card that only works in the talk.
    if st.boss.opener == "ambush" then
        local lost = {}
        if st.marks.robbed then table.insert(lost, "offering her a cut of the box") end
        if st.marks.pages then table.insert(lost, "handing her the Lecturer's pages") end
        if st.marks.know then table.insert(lost, "a bargain over her sisters") end
        if adventure.talk_score(c) >= 2 then table.insert(lost, "talking her round") end
        if #lost > 0 then
            kit.text(x, y - 6, "With an ambush there's no talk, so " .. util.join_names(lost) .. (#lost == 1 and " won't come up." or " won't come up."),
                "ui14", theme.orange, { w = w, lines = 2 })
            y = y + 40
        end
    end
    choice("HOW FAR SHE'LL GO", "style", MODULE.showdown.styles, { "yields", "last" })
    -- What letting her get away costs (R5, D2): on the board before the night, as on the cards that
    -- let her go.
    local cost = adventure.escape_cost(c)
    if cost then
        kit.text(x, y - 4, "IF SHE GETS AWAY", "ui14", theme.dim)
        kit.text(x + 220, y - 4, cost, "ui14", theme.orange, { w = w - 220, lines = 3 })
    end
end

-- The board --------------------------------------------------------------------------------------

local function top_bar(app, prep)
    local c = app.campaign
    kit.box(0, 0, kit.W, 66, theme.bg, { round = false })
    kit.text(24, 14, "SESSION " .. util.int(c.week), "title30", theme.gold)
    -- Save to a slot of your own (November 3); the board autosaves too.
    kit.button(24 + kit.width("SESSION " .. util.int(c.week), "title30") + 14, 18, 72, 30, "Save", function()
        util.lazy("game.ui.saves_view").open(app, "save")
    end, { font = "ui14", key = "save_game" })
    kit.text(300, 12, string.upper(MODULE.title), "ui14", theme.gold)
    -- (A four-way fork in a smaller hand rather than cut: the confirming playtest's "At a fork: The offices,
    -- The World of Tomorrow, The lecture..." on nine screens.)
    local where = prep.museum.boss and "Boss night: Euryale is waiting at the top of the stairs." or adventure.where(c)
    local wfont = kit.width(where, "ui18") <= 590 and "ui18" or "ui14"
    kit.text(300, wfont == "ui18" and 32 or 35, where, wfont, theme.dim, { w = 590, lines = 1 })
    local left = prep:left()
    kit.text(900, 14, "PREP HOURS", "ui14", theme.dim)
    kit.text(900, 32, util.int(left) .. " of " .. util.int(prep.budget) .. " left", "ui18b", left > 0 and theme.text or theme.orange)
    kit.text(1060, 14, "FRANCS", "ui14", theme.dim)
    kit.text(1060, 32, util.int(c.adv.francs or 0), "ui18b", theme.gold)
    local warnings = require "game.model.warnings"
    local nw = warnings.count(c)
    kit.text(1130, 14, "WARNINGS", "ui14", theme.dim)
    kit.text(1130, 32, util.int(nw) .. (nw == 1 and " danger known" or " dangers known"), "ui18b", theme.teal)
    -- What the three numbers mean, on hover (the new-player playtest: nobody knew).
    local gloss = util.lazy("game.ui.gloss")
    if gloss.card_spot then
        gloss.card_spot(896, 10, 150, 46, "Prep hours",
            "Your week before game night. Prepping a room (reading it, setting out its map and minis) costs hours; a room "
            .. "you didn't prep plays thinner, and the table can tell. Hours left over: sleep well, write a backup page, "
            .. "or talk to a friend. Up to " .. util.int(museum_week.CARRY_MAX) .. " you don't use carry to next week."
            .. ((prep.carried or 0) > 0 and (" (" .. util.int(prep.carried) .. " of this week's came over from last week.)") or ""))
        gloss.card_spot(1056, 10, 66, 46, "Flitwidget Francs",
            "The museum's own money: one appears for each beaten exhibit, solved puzzle or clever use of the museum. "
            .. "The party spends them in the gift shop.")
        local known = warnings.summary(c, 5)
        gloss.card_spot(1126, 10, 140, 46, "Fair warning",
            "A harsh call lands as fair when they knew about that danger: you described it, asked \"Are you sure?\", or they "
            .. "found out for themselves. A die rolled in the open is fair on its own. Unwarned, it feels like it came out of "
            .. "nowhere. Warn about everything, though, and nothing feels dangerous. "
            .. (#known > 0 and ("They know: " .. table.concat(known, "; ") .. ".") or "They haven't been warned about anything yet."))
    end
    -- A milestone level the report offered and you left for later (level 3 after the gift shop).
    local lv = c:level_status()
    if lv.ready then
        kit.button(1252, 12, 92, 42, "Level up", function()
            util.lazy("game.ui.levelup_view").level_up(app)
        end, { font = "ui18b", color = lv.overdue and kit.rgba("#8a4a2a") or theme.button, key = "level_up" })
        kit.dot(1256, 16, 12, theme.orange)
    end
    kit.button(1356, 10, 220, 46, "Run game night  >", function()
        app.go("night")
    end, { color = theme.go, hover = theme.go_hover, font = "ui22b", key = "run_night" })
end

local function left_column(app, prep)
    local c = app.campaign
    local x, w = COL_L, COL_LW
    local y = 84
    kit.text(x, y, "THE STORY SO FAR", "ui14", theme.dim)
    y = y + 22
    local lines = adventure.story_so_far(c)
    if #lines == 0 then
        kit.text(x, y, "Nothing yet. A gnome's museum has just rolled into town, and everyone's talking about it.", "ui18", theme.text,
            { w = w })
        y = y + kit.text_height("Nothing yet. A gnome's museum has just rolled into town, and everyone's talking about it.", "ui18", w) + 12
    else
        for i = math.max(1, #lines - 4), #lines do
            local l = lines[i]
            local line = "S" .. util.int(l.week) .. "  " .. l.text
            kit.text(x, y, line, "ui14", l.outcome == "win" and theme.text or theme.orange, { w = w, lines = 2 })
            y = y + math.min(2 * kit.line_height("ui14"), kit.text_height(line, "ui14", w)) + 6
        end
        y = y + 6
    end
    local card = adventure.boss_card(c)
    local h = math.min(870 - y - 150, 150 + #card.marks * 62)
    if not prep.museum.boss then
        M.boss_card(app, x, y, w, math.max(170, h), false)
        y = y + math.max(170, h) + 16
    end
    -- Why each hero came: where their reason pays off.
    if y < 800 then
        kit.text(x, y, "WHY THEY CAME", "ui14", theme.dim)
        y = y + 22
        for _, key in ipairs(content.players.order) do
            local p = c:player(key)
            local hk = p and adventure.hook(c, key)
            if hk and y < 860 then
                local room = MODULE.rooms[hk.room]
                local done = (c.adv.hook_paid or {})[key] ~= nil      -- (the beat played, with them there)
                kit.dot(x + 10, y + 10, 20, panels.COLORS[key] or theme.panel3)
                kit.picture(x + 1, y + 1, 18, 18, panels.face(key))
                kit.text(x + 28, y, p.char .. ": " .. hk.name .. ", in " .. util.lower_first(room.name)
                    .. (done and " (found)" or ((c.adv.skipped[hk.room] or c.adv.done[hk.room]) and " (missed)" or "")), "ui14",
                    done and theme.green or ((c.adv.skipped[hk.room] or c.adv.done[hk.room]) and theme.orange or theme.text), { w = w - 28, lines = 1 })
                y = y + 24
            end
        end
    end
end

function M.build(app)
    local c = app.campaign
    local prep = c.prep
    if #prompts(app) > 0 then
        return between(app)
    end
    -- What the answers between sessions made come true opens the DM's locks (ties.lua).
    museum_week.sync_ties(prep, c)
    kit.box(0, 0, kit.W, kit.H, theme.bg, { round = false })
    top_bar(app, prep)
    if prep.museum.boss then
        kit.text(COL_L, 84, "THE SHOWDOWN", "ui14", theme.red)
        kit.text(COL_L, 106, "Tonight isn't a run of rooms. It's one long scene with Euryale, and everything the party did "
            .. "on the way up is on her card.", "ui18", theme.text, { w = COL_LW })
        M.draw_map(app, COL_L, 230, COL_LW, 300)
        M.week_hours(app, prep, COL_L, 552, COL_LW)
        showdown(app, prep, COL_M, 84, COL_MW)
    else
        left_column(app, prep)
        M.draw_map(app, COL_M, 78, COL_MW, 228, { legend = true })
        rooms(app, prep, COL_M, 316, COL_MW, 892)
    end
    -- The friends down the right.
    kit.text(1196, 84, "THE TABLE", "ui14", theme.dim)
    player_cards.empathy_meter(app)
    local forecast = prep:forecast()
    for i, p in ipairs(c.players) do
        player_cards.card(app, prep, p, i, forecast)
    end
end

-- Enter on the board: game night, after a word first if the party could still level up.
function M.run_night(app)
    local prep = app.campaign.prep
    if not prep:ready() then
        return
    end
    if not app.campaign:level_status().ready then
        app.go("night")
        return
    end
    ask_view.ask(app, { title = "Are you sure?", text = "There's still something you could do this week:",
        items = { "The party can level up." }, yes = "Run game night", no = "Go back", on_yes = function()
            app.go("night")
        end })
end

return M
