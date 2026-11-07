-- The DM's notes: the binder behind the screen. Open it with N or the Notes button on prep, game
-- night and the report; game night waits while it's open.
--   The museum     the map, what each room left behind, and why the heroes came
--   Upstairs       Euryale's card, what they've been warned about, the harsh calls, the Francs
--   This session   where they are, tonight's rooms as the book has them, and tonight so far
--   People         the museum's people they've met, and what they know of them
--   Session log    every session's report, kept
--   The party      who's playing whom, why their heroes came, and their character sheets

-- (5e's engine only through the adventure's rule set: docs/design/rule-sets.md, no leaks.)
local ruleset = require "game.model.ruleset"
local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local util = require "game.model.util"
local panels = require "game.ui.panels"
local adventure = require "game.model.adventure"

local M = {}

local X, Y, W, H = 110, 44, 1380, 816
-- The binder's tabs, down its left edge.
local TABS = { { "museum", "The adventure" }, { "upstairs", "Upstairs" }, { "session", "This session" },
               { "people", "People" }, { "log", "Session log" }, { "party", "The party" }, { "bag", "Your bag" }, { "tips", "Lore tips" } }
M.TABS = TABS
-- (The tabs this adventure has: "Upstairs" is the villain's card, and an adventure without one has no such tab.)
local function tabs_now(app)
    local out = {}
    local card = app and app.campaign and adventure.boss_card(app.campaign)
    for _, t in ipairs(TABS) do
        if t[1] ~= "upstairs" or card then
            table.insert(out, t)
        end
    end
    return out
end

-- The adventure, room by room: the map, what each room left behind, and why the heroes came.
local function tab_museum(app, x, y, w, h)
    local MODULE = adventure.data
    local c = app.campaign
    local st = c.adv
    util.lazy("game.ui.museum_prep_view").draw_map(app, x, y, 420, 330)
    local rx, ry = x + 440, y
    kit.text(rx, ry, "ROOM BY ROOM", "ui14", theme.dim)
    ry = ry + 22
    for _, id in ipairs(MODULE.order) do
        local r = MODULE.rooms[id]
        if not r.virtual then
            local state = st.done[id] and (st.done[id] == "win" and "Done" or "Done, roughly") or (st.skipped[id] and "Left behind")
                or (id == st.at and "Next") or "Ahead"
            local col = st.done[id] and theme.green or (st.skipped[id] and theme.faint or (id == st.at and theme.gold or theme.dim))
            kit.text(rx, ry, r.name, "ui18b", st.skipped[id] and theme.faint or theme.text)
            kit.text(rx + 270, ry + 2, state, "ui14", col)
            local marks = {}
            for _, mid in ipairs(st.mark_list) do
                if st.marks[mid].room == id then
                    -- (Mid-sentence: "she smelled the smoke and a drone through the floor", not "She smelled the
                    -- smoke, A drone through the floor": the confirming playtest.)
                    table.insert(marks, util.mid_sentence(MODULE.marks[mid].name, { Euryale = true }))
                end
            end
            local line = #marks > 0 and ("Left on Euryale's card: " .. util.join_names(marks) .. ".") or r.sum
            -- (Two lines when it needs them: "...somewhere to spend Flitwidget Francs. Th..." in the third playtest.)
            local nl = math.min(2, #kit.wrap(line, "ui14", w - 460))
            kit.text(rx, ry + 22, line, "ui14", #marks > 0 and theme.gold or theme.faint, { w = w - 460, lines = 2 })
            ry = ry + 27 + nl * kit.line_height("ui14")
        end
    end
    local hy = y + 350
    kit.text(x, hy, "WHY THEY CAME", "ui14", theme.dim)
    hy = hy + 22
    for _, p in ipairs(c.players) do
        local hk = adventure.hook(c, p.key)
        if hk then
            kit.text(x, hy, p.char .. ": " .. hk.name, "ui18b", theme.text)
            kit.text(x, hy + 22, hk.text, "ui14", theme.dim, { w = 420, lines = 2 })
            hy = hy + 66
        end
    end
    kit.text(x, y + h - 22, MODULE.credit, "ui14", theme.faint, { w = w })
end

-- Upstairs: Euryale's card, and what they've been warned about.
local function tab_upstairs(app, x, y, w, h)
    local c = app.campaign
    local warnings = require "game.model.warnings"
    util.lazy("game.ui.museum_prep_view").boss_card(app, x, y, 640, h - 40, true)
    local bx = x + 664
    local bw = w - 664
    kit.text(bx, y, "WHAT THEY'VE BEEN WARNED ABOUT", "ui14", theme.dim)
    local known = warnings.summary(c, 6)
    local ty = y + 22
    if #known == 0 then
        kit.text(bx, ty, "Nothing yet.", "ui18b", theme.text)
        ty = ty + 30
    end
    for _, line in ipairs(known) do
        kit.text(bx, ty, line, "ui14", theme.text, { w = bw, lines = 2 })
        ty = ty + ((#line > 70) and 42 or 24)    -- (about 70 characters to a line at this width)
    end
    kit.text(bx, ty + 6, "When something harsh happens, the table asks: did we know? A warning about that very thing, or a "
        .. "die everyone saw, and it lands as fair. Out of nowhere, and it costs you their Trust. Warn about everything, "
        .. "though, and nothing feels dangerous.", "ui14", theme.dim, { w = bw, lines = 5 })
    local hy = ty + 110
    local harsh = c.adv.harsh or { paid = 0, unpaid = 0 }
    kit.text(bx, hy, "HARSH CALLS SO FAR", "ui14", theme.dim)
    kit.text(bx, hy + 22, util.int(harsh.paid) .. " fair, " .. util.int(harsh.unpaid) .. " out of nowhere", "ui18b",
        harsh.unpaid > 0 and theme.orange or theme.text)
    kit.text(bx, hy + 64, "FLITWIDGET FRANCS", "ui14", theme.dim)
    kit.text(bx, hy + 86, util.int(c.adv.francs or 0), "ui22b", theme.gold)
end

-- The museum's people: who they've met, and what they know of them.
local function tab_museum_people(app, x, y, w, h)
    local adventure = require "game.model.adventure"
    local c = app.campaign
    local met = c.story and c.story.met or {}
    -- The people they've met, each with what they know; the rest as one line at the foot (the third
    -- playtest: "Someone they haven't met", twice, read as a mistake).
    local unmet = 0
    for _, pp in ipairs(adventure.data.people) do
        local seen = pp.known or met[pp.id] or adventure.met(c, pp.id) or (pp.id == "mus_telpur" and c.adv.done.gift_shop)
            or (pp.id == "mus_mech" and c.adv.done.tomorrow)
        if not seen then
            unmet = unmet + 1
        else
            -- (Nobody's role before they've met: the notebook isn't the DM's book. The Mech by its name.)
            local name = pp.name
            if pp.id == "mus_mech" and c.adv.marks.mech and c.adv.mech_name then
                name = pp.name .. ", " .. c.adv.mech_name
            end
            local nn = kit.text(x, y, name, "ui22b", theme.text, { gloss = false })
            kit.text(x + 320, y + 6, pp.role, "ui14", theme.dim)
            -- Their sheet, from their name (the playtest, November 3).
            require("game.ui.gloss").npc_spot(x - 2, y - 2, math.min(kit.width(name, "ui22b"), 310) + 4, 30, pp.id, nn)
            local mem = adventure.memory(c, pp.id)
            local about = pp.about .. (#mem > 0 and (" Knows " .. util.join_names(mem) .. ".") or "")
            kit.text(x, y + 30, about, "ui18", theme.dim, { w = w, lines = 2 })
            y = y + 86
        end
    end
    if unmet > 0 then
        kit.text(x, y, unmet == 1 and "One more person here they haven't met yet." or
            (util.int(unmet) .. " more people here they haven't met yet."), "ui18", theme.faint, { w = w })
    end
end

function M.open(app, tab)
    app.overlay = "notes"
    app.notes_tab = tab or app.notes_tab or "session"
    M.draw(app)
end

function M.close(app)
    if app.notes_layer then
        kit.drop(app.notes_layer)
        app.notes_layer = nil
    end
    if app.overlay == "notes" then
        app.overlay = nil
    end
    kit.reset_hover()
end

-- A heading inside the binder.
local function head(x, y, text)
    kit.text(x, y, string.upper(text), "ui14", theme.gold)
    return y + 22
end

-- Wrapped text that never gets cut: returns the y after it.
local function para(x, y, w, text, font, color)
    font = font or "ui18"
    kit.text(x, y, text, font, color or theme.text, { w = w })
    return y + kit.text_height(text, font, w) + 6
end

-- This session ---------------------------------------------------------------------------------------

-- An adventure's session is its rooms: where they are, tonight's rooms as the book has them
-- (what each is, the fight the book gives it, what prepping it means), and tonight so far.
local function tab_session(app, x, y, w)
    local c = app.campaign
    local adventure = require "game.model.adventure"
    local museum_week = require "game.model.museum_week"
    local MODULE = adventure.data
    local col_w = 640
    local ly = y
    kit.text(x, ly, "SESSION " .. util.int(c.week) .. " OF " .. string.upper(adventure.data.title or "the adventure"), "ui14", theme.dim)
    ly = ly + 20
    -- (A long "At a fork: ..." in a smaller hand rather than cut.)
    local where = adventure.where(c)
    local wfont = kit.width(where, "title30") > col_w and "ui22b" or "title30"
    local wh = kit.text_height(where, wfont, col_w)
    kit.text(x, ly, where, wfont, theme.text, { w = col_w, lines = 2 })
    ly = ly + math.max(44, math.min(wh, 2 * kit.line_height(wfont)) + 16)
    ly = head(x, ly, "Tonight's rooms")
    local pm = c.prep and c.prep.museum
    for _, id in ipairs(pm and pm.ahead or {}) do
        local r = MODULE.rooms[id]
        if r and not r.virtual and ly < 820 then
            kit.text(x, ly, r.name, "ui18b", theme.text)
            local prepped = pm.prepped and pm.prepped[id]
            kit.text(x + col_w, ly + 2, prepped and "Prepped" or "Not prepped", "ui14", prepped and theme.green or theme.faint,
                { pivot = gui.PIVOT_NE })
            ly = ly + 22
            ly = para(x + 12, ly, col_w - 12, r.sum, "ui14", theme.dim)
            for _, n in ipairs(museum_week.room_prep(c, id)) do
                ly = para(x + 12, ly, col_w - 12, n.text .. ".", "ui14", n.kind == "ask" and theme.teal or theme.faint)
            end
            ly = ly + 6
        end
    end
    local night = app.screen == "night" and app.night
    local rx = x + col_w + 40
    if night and night.scenes then
        local ry = head(rx, y, "Tonight so far")
        for _, sc in ipairs(night.scenes) do
            if sc.title then
                kit.text(rx + 12, ry, util.int(sc.index) .. ". " .. sc.title, "ui14", theme.text)
                ry = ry + 20
            end
        end
    end
end

-- The session log (M8, B7) ---------------------------------------------------------------------------------

-- Every session report, kept. Pick a week to reopen its recap: the title you chose, the beats you
-- kept (pinned ones marked), your note, the verdict and how each player felt.
local VERDICT_COLOR = { ["One for the stories"] = theme.gold, ["Great session"] = theme.green, ["Good session"] = theme.teal,
                        Okay = theme.dim, ["Rough night"] = theme.orange }
local TIER_COLOR = { loved = theme.green, fun = theme.teal, fine = theme.gold, bored = theme.orange, out = theme.red }

local function tab_log(app, x, y, w, h)
    local log = app.campaign.session_log or {}
    if #log == 0 then
        para(x, y, w, "No sessions yet. Every session report is kept here once the night is over.", "ui18", theme.faint)
        return
    end
    -- The weeks, newest first, down the left; a new week opens on the newest (the third playtest: at
    -- week 3 it still opened on session 1, picked a fortnight before).
    if app.log_week_at ~= app.campaign.week then
        app.log_week, app.log_week_at = nil, app.campaign.week
    end
    local pick = app.log_week
    local found
    for _, e in ipairs(log) do
        found = found or (e.week == pick and e)
    end
    found = found or log[#log]
    app.log_week = found.week
    local lx, ly = x, y
    for i = #log, 1, -1 do
        local e = log[i]
        if ly + 40 > y + h then
            break
        end
        local on = e == found
        local t = e.recap and e.recap.titles and e.recap.titles[e.recap.title or 1] or ("Session " .. util.int(e.week))
        -- (The night's title in two lines rather than cut: the confirming playtest's "1. From the Street to the
        -- Chamber of...".)
        local label = util.int(e.week) .. ".  " .. t
        local two = kit.width(label, "ui14") > 276
        local bh = two and 46 or 36
        if ly + bh > y + h then
            break
        end
        kit.button(lx, ly, 300, bh, "", function()
            app.log_week = e.week
            app.refresh_notes()
        end, { font = "ui14", color = on and theme.go or theme.panel2, hover = theme.button_hover, align = "left",
               key = "log_week_" .. util.int(e.week) })
        kit.text(lx + 12, ly + (two and 4 or 9), label, "ui14", theme.text, { w = 276, lines = 2 })
        ly = ly + bh + 6
    end
    -- The chosen session.
    local px, pw = x + 324, w - 324
    local e = found
    local r = e.recap or {}
    local title = r.titles and r.titles[r.title or 1] or ("Session " .. util.int(e.week))
    kit.text(px, y - 4, "SESSION " .. util.int(e.week), "ui14", theme.gold)
    kit.text(px, y + 16, title, "title30", theme.text)
    local vc = VERDICT_COLOR[e.verdict] or theme.dim
    kit.text(px + pw, y + 24, e.verdict or "", "ui18b", vc, { pivot = gui.PIVOT_NE })
    local ty = y + 66
    ty = head(px, ty, "The recap")
    local any = false
    for _, b in ipairs(r.beats or {}) do
        if not b.cut and ty < y + h - 230 then
            any = true
            if b.pinned then
                kit.icon(px, ty + 3, 14, "reward", theme.gold)
            end
            ty = para(px + 22, ty, pw - 22, b.text, "ui18", b.pinned and theme.gold or theme.text)
        end
    end
    if not any then
        ty = para(px, ty, pw, "Nothing kept from this one.", "ui18", theme.faint)
    end
    if (r.note or "") ~= "" then
        ty = para(px, ty + 4, pw, "Your note: " .. r.note, "hand24", kit.rgba("#f3df8a"))
    end
    ty = head(px, ty + 10, "How the table felt")
    for _, row in ipairs(e.players or {}) do
        if ty + 24 > y + h then
            break
        end
        kit.text(px, ty, row.name, "ui18b", theme.text)
        kit.text(px + 70, ty + 2, row.char or "", "ui14", theme.dim)
        local q = row.quote and ('"' .. row.quote .. '"') or (row.fun and "" or "Wasn't there.")
        kit.text(px + 190, ty + 2, kit.ellipsize(q, "ui14", pw - 190), "ui14", TIER_COLOR[row.tier] or theme.text)
        ty = ty + 26
    end
end

-- Your bag (Conner, November 6): what you can tuck where a friend pokes about on game night, and what you've given.

local BOOK_H = 92
local function tab_bag(app, x, y, w, h)
    local c = app.campaign
    local bag = require "game.model.dm_bag"
    local items = require "game.model.items"
    local list = bag.stock(c)
    local bagd = require "game.data.dm_bag"
    kit.text(x, y, "When a friend pokes at something on game night, you can answer as the dice say, tell them something "
        .. "real, or tuck one of these there. You can also put them in people's pockets from their sheets. What you give "
        .. "goes in a hero's pack and works from then on.", "ui18", theme.dim, { w = w })
    -- The books: an hour of prep reads one, and what it describes joins the bag. Only while you prep.
    local by = y + 76
    local bw = math.floor((w - 3 * 12) / 4)
    BOOK_H = 0
    for _, b in ipairs(bagd.books) do
        BOOK_H = math.max(BOOK_H, 10 + kit.text_height(b.name, "ui18b", bw - 20) + kit.text_height(b.about, "ui14", bw - 20) + 40)
    end
    kit.text(x, by, "BOOKS", "ui14", theme.gold)
    local prep = app.screen == "prep" and c.prep or nil
    kit.text(x + 70, by, prep and ("An hour of prep each. " .. util.int(prep:left()) .. " hours left.")
        or "Read between sessions, on the prep board.", "ui14", theme.faint)
    by = by + 22
    for i, b in ipairs(bagd.books) do
        local bx = x + (i - 1) * (bw + 12)
        -- (Whole, never cut: the name and its words wrap, and the box is as tall as the tallest needs.)
        kit.box(bx, by, bw, BOOK_H, theme.panel2, { radius = 8 })
        kit.text(bx + 10, by + 8, b.name, "ui18b", theme.text, { w = bw - 20 })
        local ay = by + 10 + kit.text_height(b.name, "ui18b", bw - 20)
        kit.text(bx + 10, ay, b.about, "ui14", theme.dim, { w = bw - 20 })
        local sy = by + BOOK_H - 30
        if bag.read_already(c, b.id) then
            kit.text(bx + 10, sy + 6, "Read. Its things are in your bag.", "ui14", theme.green, { w = bw - 20 })
        elseif b.needs and not bag.read_already(c, b.needs) then
            kit.text(bx + 10, sy + 6, "Read the one before it first.", "ui14", theme.faint, { w = bw - 20 })
        elseif prep then
            kit.button(bx + 10, sy, bw - 20, 26, "Read it (1 hour)", function()
                bag.read(c, prep, b.id)
                app.refresh_notes()
            end, { font = "ui14", key = "read_book_" .. b.id, enabled = bag.can_read(c, prep, b.id) })
        else
            kit.text(bx + 10, by + 68, "Not read yet.", "ui14", theme.faint)
        end
    end
    local cy = by + BOOK_H + 12
    local col_w = math.floor((w - 20) / 2)
    local rows = math.ceil(#list / 2)
    local rh = math.min(38, math.floor((h - (cy - y) - 150) / math.max(1, rows)))
    kit.text(x, cy, "IN YOUR BAG  (" .. util.int(#list) .. ")", "ui14", theme.gold)
    cy = cy + 22
    for i, e in ipairs(list) do
        local col = (i <= rows) and 0 or 1
        local row = (i <= rows) and (i - 1) or (i - 1 - rows)
        local ex, ey = x + col * (col_w + 20), cy + row * rh
        local left = bag.left(c, e)
        local label = util.capitalize(e.name) .. (left > 1 and ("  x" .. util.int(left)) or "")
        kit.text(ex, ey, e.rarity, "ui14", (require("game.data.dm_bag").RANK[e.rarity] or 0) >= 4 and theme.gold or theme.faint)
        kit.text(ex + 92, ey, kit.ellipsize(label, "ui18", col_w - 96), "ui18", theme.text)
        if rh >= 34 then
            kit.text(ex + 92, ey + 19, kit.ellipsize(e.text or "", "ui14", col_w - 96), "ui14", theme.dim)
        end
    end
    -- What's been given, and to whom (the inventory owns it now).
    local given = {}
    for id, n in util.sorted_pairs((c.dm_bag and c.dm_bag.used) or {}) do
        local e = require("game.data.dm_bag").by_id[id]
        if e and n > 0 then
            local who = {}
            for _, it in ipairs(items.list(c)) do
                if (it.thing == (e.thing or e.id) or it.id == (e.magic or e.thing or e.id)) and it.holder and it.from == "found" then
                    local pl = c:player(it.holder)
                    if pl and not util.contains(who, pl.char) then
                        table.insert(who, pl.char)
                    end
                end
            end
            table.insert(given, util.capitalize(e.name) .. (#who > 0 and (": " .. table.concat(who, ", ")) or ""))
        end
    end
    local gy = y + h - 20 - 20 * math.min(3, math.max(1, #given))
    kit.text(x, gy - 22, "GIVEN SO FAR", "ui14", theme.gold)
    if #given == 0 then
        kit.text(x, gy, "Nothing yet.", "ui18", theme.faint)
    end
    for i = 1, math.min(3, #given) do
        kit.text(x, gy + (i - 1) * 20, kit.ellipsize(given[#given - i + 1], "ui18", w), "ui18", theme.text)
    end
end

-- Lore tips (Conner, November 6): pointers you can hand out when a friend pokes about, to send them the right way.
local function tab_tips(app, x, y, w, h)
    local c = app.campaign
    local tips = require "game.model.lore_tips"
    local adv = require "game.model.adventure"
    kit.text(x, y, "When a friend pokes at something in the room a tip is for, you can hand it out. A tip points the way "
        .. "without giving the answer, and counts as a hint about what it points at.", "ui18", theme.dim, { w = w })
    local ty = y + 54
    local list = tips.list()
    local rh = math.min(48, math.floor((h - 60) / math.max(1, #list)))
    for _, t in ipairs(list) do
        local room = t.room and adv.data.rooms[t.room]
        local state = tips.given(c, t.id) and "Given" or (tips.useful(c, t) and "Ready" or "Not now")
        local tone = state == "Given" and theme.green or (state == "Ready" and theme.gold or theme.faint)
        kit.text(x, ty, state, "ui14", tone)
        kit.text(x + 80, ty, kit.ellipsize(t.name .. (room and ("  (" .. room.name .. ")") or "  (anywhere)"), "ui18b", w - 80),
            "ui18b", theme.text)
        if rh >= 40 then
            kit.text(x + 80, ty + 21, kit.ellipsize(t.text, "ui14", w - 80), "ui14", theme.dim)
        end
        ty = ty + rh
    end
    if #list == 0 then
        kit.text(x, ty, "This adventure has no tips written yet.", "ui18", theme.faint)
    end
end

-- The party -------------------------------------------------------------------------------------------------

local function tab_party(app, x, y, w, h)
    local c = app.campaign
    local gap = 14
    -- The shelf of fallen heroes (B3) along the bottom, when there's anyone on it.
    local fallen = M.fallen_rows(app)
    if #fallen > 0 then
        local fh = 30 + math.min(3, #fallen) * 20
        h = h - fh - 10
        kit.text(x, y + h + 12, "THE SHELF OF FALLEN HEROES", "ui14", theme.gold)
        for i = 1, math.min(3, #fallen) do
            kit.text(x, y + h + 12 + i * 20, kit.ellipsize(fallen[i], "ui14", w), "ui14", theme.dim)
        end
    end
    local cw = math.floor((w - 3 * gap) / 4)
    for i, p in ipairs(panels.seated(c.players)) do
        local px = x + (i - 1) * (cw + gap)
        kit.box(px, y, cw, h, theme.panel2, { radius = 10 })
        kit.dot(px + 50, y + 50, 80, panels.COLORS[p.key] or theme.panel3)
        kit.picture(px + 12, y + 12, 76, 76, panels.face(p.key))
        kit.picture(px + cw - 72, y + 10, 60, 75, panels.mini(p))
        local py = y + 98
        kit.text(px + 14, py, p.name, "ui22b", theme.text)
        kit.text(px + 14 + kit.width(p.name, "ui22b") + 8, py + 6, "plays " .. p.char, "ui18", theme.gold,
            { w = cw - 36 - kit.width(p.name, "ui22b") })
        py = py + 34
        local level = c.level or 2
        local sub = level >= 3 and c.subclasses and c.subclasses[p.class]
        local subs = ruleset.part("subclasses")
        local line = p.class_name .. ", level " .. util.int(level)
        if sub and subs.list[sub] then
            line = line .. ", " .. subs.list[sub].name
        end
        py = para(px + 14, py, cw - 28, line, "ui18", theme.text)
        -- The reason their hero came, and where it pays off.
        local adv = require "game.model.adventure"
        local hk = adv.hook(c, p.key)
        if hk then
            py = head(px + 14, py + 6, "Why they came")
            local room = adv.data.rooms[hk.room]
            local paid = (c.adv.hook_paid or {})[p.key]
            py = para(px + 14, py, cw - 28, hk.name .. ": " .. hk.text .. " It pays off in " .. util.lower_first(room.name)
                .. (paid and " (found)." or "."), "ui18", theme.text)
        end
        -- What they carry (items.lua, as on their sheet), each with what it does on hover (the third
        -- playtest: "Picked up: the Mech manual (Oswin has it)", and the party page didn't list it).
        local sheet_view = require("game.ui.sets").part("sheet_view")
        local carried = sheet_view.carrying(c, ruleset.engine("sheet").build(c, p.key))
        py = head(px + 14, py + 6, "Carrying")
        if #carried == 0 then
            py = para(px + 14, py, cw - 28, "Nothing yet.", "ui14", theme.faint)
        end
        local gl = require "game.ui.gloss"
        for _, it in ipairs(carried) do
            local tn = kit.text(px + 14, py, it.name, "ui14", theme.text, { w = cw - 28, lines = 1, gloss = false })
            if it.text and it.text ~= "" then
                gl.card_spot(px + 12, py - 1, cw - 24, 20, it.name, it.text, nil, tn)
            end
            py = py + 20
        end
        py = head(px + 14, py + 6, "At the table")
        py = para(px + 14, py, cw - 28, p.notes or "", "ui14", theme.dim)
        -- How they get on with the others (A17).
        local rapport = require "game.model.rapport"
        local bits = {}
        for _, q in ipairs(c.players) do
            if q ~= p then
                local word = rapport.word(c, p.key, q.key)
                if word and word ~= "Fine" then
                    table.insert(bits, word .. " with " .. q.name)
                end
            end
        end
        if #bits > 0 then
            py = head(px + 14, py + 6, "With the others")
            py = para(px + 14, py, cw - 28, table.concat(bits, ". ") .. ".", "ui14", theme.text)
        end
        if not p.present then
            py = para(px + 14, py + 4, cw - 28, p.on_break and "Taking a break from Thursdays." or "Out this week.", "ui14",
                theme.orange)
        end
        -- What they've been through (B3): a scar, the hero they lost.
        if p.scar then
            py = para(px + 14, py + 2, cw - 28, p.scar, "ui14", theme.dim)
        end
        if p.old_char then
            py = para(px + 14, py + 2, cw - 28, "Used to play " .. p.old_char .. ". They're on the shelf now.", "ui14", theme.faint)
        end
        kit.button(px + 14, y + h - 54, cw - 28, 40, "Character sheet", function()
            M.close(app)
            if app.open_sheet then
                app.open_sheet(p.key)
            end
        end, { font = "ui18b", key = "notes_sheet_" .. p.key })
    end
end

-- The shelf of fallen heroes (B3), under the party: name, class, level, and how they fell.
function M.fallen_rows(app)
    local rows = {}
    for _, f in ipairs(app.campaign.fallen or {}) do
        local p = app.campaign:player(f.key)
        table.insert(rows, f.char .. " (" .. (p and p.name or "?") .. "), " .. util.capitalize(f.class or "hero") .. " " .. util.int(f.level or 1)
            .. ": " .. f.how .. ", session " .. util.int(f.week) .. ".")
    end
    return rows
end

function M.draw(app)
    if app.notes_layer then
        kit.drop(app.notes_layer)
    end
    local l = kit.layer("notes", true)
    app.notes_layer = l
    app.refresh_notes = app.refresh_notes or function()
        if app.overlay == "notes" then
            M.draw(app)
        end
    end
    kit.box(0, 0, kit.W, kit.H, kit.rgba("#000000", 0.55), { round = false })
    kit.box(X, Y, W, H, theme.bg, { radius = 14 })
    kit.box(X, Y, W, 60, theme.panel, { radius = 14 })
    kit.text(X + 24, Y + 14, "YOUR NOTES", "title30", theme.gold)
    local tab = app.notes_tab or "session"
    local known = false
    for _, t in ipairs(tabs_now(app)) do
        known = known or t[1] == tab
    end
    if not known then
        tab = "session"
        app.notes_tab = tab
    end
    -- The tabs down the left, like a binder's dividers.
    local ty = Y + 76
    for _, t in ipairs(tabs_now(app)) do
        local on = tab == t[1]
        kit.button(X + 14, ty, 168, 38, t[2], function()
            app.notes_tab = t[1]
            M.draw(app)
        end, { font = "ui18b", color = on and theme.go or theme.panel2, hover = theme.button_hover, align = "left", pad_y = 9,
               key = "notes_tab_" .. t[1] })
        ty = ty + 44
    end
    local title = ""
    for _, t in ipairs(tabs_now(app)) do
        if t[1] == tab then
            title = t[2]
        end
    end
    kit.text(X + 260, Y + 20, string.upper(title), "ui18b", theme.dim)
    kit.button(X + W - 130, Y + 12, 110, 36, "Close", function()
        if app.close_overlay then
            app.close_overlay()
        else
            M.close(app)
        end
    end, { font = "ui18b", key = "notes_close" })
    local cx, cy = X + 204, Y + 76
    local cw, ch = W - 204 - 24, H - 76 - 22
    if tab == "museum" then
        tab_museum(app, cx, cy, cw, ch)
    elseif tab == "upstairs" then
        tab_upstairs(app, cx, cy, cw, ch)
    elseif tab == "people" then
        tab_museum_people(app, cx, cy, cw, ch)
    elseif tab == "session" then
        tab_session(app, cx, cy, cw)
    elseif tab == "log" then
        tab_log(app, cx, cy, cw, ch)
    elseif tab == "bag" then
        tab_bag(app, cx, cy, cw, ch)
    elseif tab == "tips" then
        tab_tips(app, cx, cy, cw, ch)
    else
        tab_party(app, cx, cy, cw, ch)
    end
end

return M
