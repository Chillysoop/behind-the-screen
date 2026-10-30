-- Prep in the museum (v2): the week's board for The Museum of Nightmares. Before the board, the
-- questions between sessions (requests in the group chat, loose ends, favors). On the board: where
-- the party stands on the museum map, tonight's rooms (prep each or wing it, and how you'll run
-- it), Euryale's card with every mark the party has left on it, and the friends down the right.
-- On boss night the middle becomes the showdown board. Rebuilt from scratch on every click.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local panels = require "game.ui.panels"
local content = require "game.model.content"
local util = require "game.model.util"
local adventure = require "game.model.adventure"
local museum_week = require "game.model.museum_week"

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
    kit.text(300, 24, "Between sessions: the group chat, and what's changed since last time.", "ui18", theme.dim)
    -- The chat down the left.
    kit.text(COL_L, 84, "THE GROUP CHAT", "ui14", theme.dim)
    local y = 108
    for _, m in ipairs(c.chat or {}) do
        local h = kit.text_height(m.text, "ui18", COL_LW - 60) + 14
        if y + h > 860 then
            break
        end
        kit.dot(COL_L + 14, y + 14, 26, panels.COLORS[m.key] or theme.panel3)
        kit.picture(COL_L + 2, y + 2, 24, 24, panels.face(m.key))
        kit.text(COL_L + 36, y, m.who, "ui14", theme.dim)
        kit.text(COL_L + 36, y + 18, m.text, "ui18", m.request and theme.gold or theme.text, { w = COL_LW - 50 })
        y = y + h + 18
    end
    local x, w = 460, 760
    kit.text(x, 84, "QUESTIONS THIS WEEK  (" .. util.int(#list) .. ")", "ui14", theme.dim)
    if not pr then
        return
    end
    local box_y = 112
    kit.box(x, box_y, w, 640, theme.panel, { radius = 12 })
    local def = pr.def
    if pr.kind == "request" then
        local p = c:player(def.who)
        kit.text(x + 24, box_y + 18, "A REQUEST", "ui14", theme.gold)
        kit.dot(x + 44, box_y + 70, 40, panels.COLORS[def.who] or theme.panel3)
        kit.picture(x + 26, box_y + 52, 36, 36, panels.face(def.who))
        kit.text(x + 76, box_y + 50, p.name .. " asks:", "ui18b", theme.text)
        kit.text(x + 76, box_y + 76, "\"" .. def.ask .. "\"", "story22", theme.text, { w = w - 110 })
        kit.text(x + 24, box_y + 136, "Every DM gets these. Fair, absurd, or both: how do you answer?", "ui18", theme.dim, { w = w - 48 })
        local by = box_y + 176
        for _, ans in ipairs(MODULE.ANSWERS) do
            local a = def.answers[ans]
            kit.button(x + 24, by, w - 48, 92, "", function()
                adventure.answer_request(c, pr.id, ans)
                app.refresh()
            end, { color = theme.panel2, hover = theme.button_hover, key = "req_" .. ans })
            kit.text(x + 40, by + 8, MODULE.ANSWER_NAMES[ans], "ui18b", theme.gold)
            kit.text(x + 40, by + 32, a.reply, "ui18", theme.text, { w = w - 300, lines = 2 })
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

local function room_state(c, id)
    local st = c.adv
    if st.done[id] then
        return "done"
    elseif st.skipped[id] then
        return "skipped"
    end
    local prep = c.prep
    if prep and prep.museum and util.contains(prep.museum.ahead, id) then
        return "ahead"
    end
    return "later"
end

function M.draw_map(app, x, y, w, h, opts)
    local c = app.campaign
    opts = opts or {}
    kit.box(x, y, w, h, kit.rgba("#000000", 0.22), { radius = 10 })
    local function pos(r)
        return x + 40 + (w - 80) * r.at[1] / 100, y + 26 + (h - 52) * (r.at[2] / 100)
    end
    -- The ways between rooms, drawn once each.
    local drawn = {}
    for _, id in ipairs(MODULE.order) do
        local r = MODULE.rooms[id]
        local x1, y1 = pos(r)
        for _, nid in ipairs(r.next or {}) do
            local key = id < nid and (id .. nid) or (nid .. id)
            if not drawn[key] then
                drawn[key] = true
                local x2, y2 = pos(MODULE.rooms[nid])
                kit.line(x1, y1, x2, y2, 2, kit.rgba("#b9a88e", 0.35))
            end
        end
    end
    for _, id in ipairs(MODULE.order) do
        local r = MODULE.rooms[id]
        local cx, cy = pos(r)
        local s = room_state(c, id)
        local label = r.map or (string.gsub(r.name, "^The ", ""))
        local tw = kit.width(label, "ui14") + 16
        local col = (s == "done" and kit.rgba("#4f6a3e")) or (s == "skipped" and kit.rgba("#2a201b"))
            or (s == "ahead" and theme.panel3) or theme.panel
        if r.boss then
            col = s == "done" and kit.rgba("#4f6a3e") or kit.rgba("#6a2e26")
        end
        if s == "ahead" then
            kit.box(cx - tw / 2 - 2, cy - 13, tw + 4, 26, theme.gold, { radius = 8 })
        end
        kit.box(cx - tw / 2, cy - 11, tw, 22, col, { radius = 7 })
        kit.text(cx, cy - 9, label, "ui14", s == "skipped" and theme.faint or theme.text, { pivot = gui.PIVOT_N })
        if s == "done" then
            kit.text(cx + tw / 2 + 3, cy - 10, "v", "ui14", theme.green)
        end
        -- Whose hook pays off here: their face beside the room.
        local hx = cx - tw / 2 - 14
        for _, p in ipairs(adventure.hooked(c, id)) do
            kit.dot(hx, cy, 18, panels.COLORS[p.key] or theme.panel3)
            kit.picture(hx - 8, cy - 8, 16, 16, panels.face(p.key))
            hx = hx - 18
        end
    end
    if opts.legend then
        kit.text(x + 12, y + h - 22, "Gold: tonight's rooms.  Green: done.  Faded: left behind.  Faces: a hero's reason for coming.",
            "ui14", theme.faint)
    end
end

-- Euryale's card -------------------------------------------------------------------------------

function M.boss_card(app, x, y, w, h, big)
    local c = app.campaign
    local card = adventure.boss_card(c)
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
        return
    end
    kit.text(x + 16, ty, "MARKS FROM THE BUILD-UP  (" .. util.int(#card.marks) .. ")", "ui14", theme.dim)
    ty = ty + 22
    -- Every mark, always inside the card (the engine run, October 30: the sixth spilled out over the
    -- showdown's rows): each with what it changes and why, or one line each when that won't fit.
    local full = 0
    for _, m in ipairs(card.marks) do
        full = full + 24 + kit.text_height(m.showdown .. ". (" .. m.why .. ".)", "ui14", w - 46) + 6
    end
    local compact = ty + full > y + h - 10
    for i, m in ipairs(card.marks) do
        local rowh = compact and 22 or (24 + kit.text_height(m.showdown .. ". (" .. m.why .. ".)", "ui14", w - 46) + 6)
        if ty + (compact and 18 or rowh - 6) > y + h - 8 then
            kit.text(x + w - 16, y + 10, "+" .. util.int(#card.marks - i + 1) .. " more in your notes", "ui14", theme.faint,
                { pivot = gui.PIVOT_NE })
            break
        end
        kit.box(x + 16, ty + (compact and 7 or 4), 6, 6, theme.gold, { radius = 3 })
        if compact then
            local nw = kit.width(m.name, "ui18b")
            kit.text(x + 30, ty, m.name, "ui18b", theme.text, { w = w - 46, lines = 1 })
            kit.text(x + 30 + nw + 10, ty + 3, m.showdown .. ".", "ui14", theme.dim, { w = math.max(40, w - 56 - nw), lines = 1 })
        else
            kit.text(x + 30, ty, m.name, "ui18b", theme.text, { w = w - 46, lines = 1 })
            kit.text(x + 30, ty + 22, m.showdown .. ". (" .. m.why .. ".)", "ui14", theme.dim, { w = w - 46, lines = 2 })
        end
        ty = ty + rowh
    end
end

-- Tonight's rooms ------------------------------------------------------------------------------

local function room_row(app, prep, id, x, y, w)
    local c = app.campaign
    local r = MODULE.rooms[id]
    local pm = prep.museum
    local knobs = r.knobs or {}
    local h = 54 + #knobs * 30
    if r.virtual then
        h = 50
    end
    kit.box(x, y, w, h, theme.panel, { radius = 10 })
    kit.box(x, y, 6, h, theme.scene[r.type] or theme.panel3, { radius = 3 })
    kit.text(x + 18, y + 8, r.name, "ui18b", theme.text)
    local nx = x + 18 + kit.width(r.name, "ui18b") + 10
    local tn = content.scenes[r.type] and content.scenes[r.type].name or r.type
    kit.text(nx, y + 11, tn .. (r.quick and ", short" or ""), "ui14", theme.dim)
    kit.text(x + 18, y + 30, r.sum, "ui14", theme.dim, { w = w - 220, lines = 1 })
    if not r.virtual and (r.cost or 0) > 0 then
        local on = pm.prepped[id]
        local label = on and ("Prepped  (" .. util.int(r.cost) .. "h)") or ("Prep it  (" .. util.int(r.cost) .. "h)")
        kit.button(x + w - 186, y + 8, 172, 32, label, function()
            museum_week.set_prepped(prep, id, not on)
            app.refresh()
        end, { font = "ui18b", color = on and theme.go or theme.button, hover = on and theme.go_hover or theme.button_hover,
               enabled = on or museum_week.can_prep(prep, id), key = "prep_" .. id })
        if not on and #knobs == 0 then
            kit.text(x + w - 14, y + 42, "Unprepped: you'll wing it.", "ui14", theme.faint, { pivot = gui.PIVOT_NE })
        end
    end
    local ky = y + 52
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

local function rooms(app, prep, x, y, w, max_y)
    local pm = prep.museum
    kit.text(x, y, "TONIGHT'S ROOMS", "ui14", theme.dim)
    kit.text(x + w, y, "The party picks the way at forks. Prep the side you think they'll take, or both.", "ui14", theme.faint,
        { pivot = gui.PIVOT_NE })
    y = y + 22
    for _, id in ipairs(pm.ahead) do
        if y > max_y - 40 then
            kit.text(x, y, "...and more beyond, if the night runs long.", "ui14", theme.faint)
            break
        end
        y = y + room_row(app, prep, id, x, y, w) + 6
    end
end

-- Boss night: the showdown board --------------------------------------------------------------

local ONE_OF_A_KIND = { knight_of_shades = "the Knight of Shades", the_lecturer = "the Lecturer", sentinel = "the Sentinel",
    bone_construct = "the Bone Construct" }

local function showdown(app, prep, x, y, w)
    local c = app.campaign
    local st = c.adv
    st.boss = st.boss or { opener = "talk", style = "yields" }
    M.boss_card(app, x, y, w, 360, true)
    y = y + 376
    local enc = adventure.boss_encounter(c)
    local brings = {}
    if st.marks.mech then
        table.insert(brings, "the Steam Mech" .. (st.mech_name and (", " .. st.mech_name) or ""))
    end
    if st.marks.mirror then
        table.insert(brings, "a polished cupboard door")
    end
    if st.marks.pages then
        table.insert(brings, "the Lecturer's notes")
    end
    if st.marks.know then
        table.insert(brings, "a book on gorgons")
    end
    if st.flags.arrows then
        table.insert(brings, "fire arrows")
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
    kit.text(x, y, "WHAT THE PARTY BRINGS", "ui14", theme.dim)
    kit.text(x + 220, y, #brings > 0 and util.join_names(brings) or "Themselves, and whatever's left in their packs.", "ui18", theme.text,
        { w = w - 220, lines = 2 })
    y = y + 50
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
                kit.box(bx - 3, by - 3, bw + 6, 82, theme.select, { radius = 9 })
            end
            kit.button(bx, by, bw, 76, "", function()
                st.boss[field] = id
                app.refresh()
            end, { color = on and theme.panel3 or theme.panel2, hover = theme.button_hover, key = "boss_" .. field .. "_" .. id })
            kit.text(bx + 12, by + 6, d.name, "ui18b", theme.text)
            kit.text(bx + 12, by + 30, d.blurb, "ui14", theme.dim, { w = bw - 24, lines = 1 })
            chips(bx + 12, by + 50, d.like, bw - 24)
            bx = bx + bw + 12
        end
        y = by + 90
    end
    choice("HOW SHE OPENS", "opener", MODULE.showdown.openers, { "talk", "ambush" })
    choice("HOW FAR SHE'LL GO", "style", MODULE.showdown.styles, { "yields", "last" })
end

-- The board --------------------------------------------------------------------------------------

local function top_bar(app, prep)
    local c = app.campaign
    kit.box(0, 0, kit.W, 66, theme.bg, { round = false })
    kit.text(24, 14, "SESSION " .. util.int(c.week), "title30", theme.gold)
    kit.text(300, 12, string.upper(MODULE.title), "ui14", theme.gold)
    kit.text(300, 32, prep.museum.boss and "Boss night: Euryale is waiting at the top of the stairs." or adventure.where(c),
        "ui18", theme.dim, { w = 520, lines = 1 })
    local left = prep:left()
    kit.text(900, 14, "PREP HOURS", "ui14", theme.dim)
    kit.text(900, 32, util.int(left) .. " of " .. util.int(prep.budget) .. " left", "ui18b", left > 0 and theme.text or theme.orange)
    kit.text(1060, 14, "FRANCS", "ui14", theme.dim)
    kit.text(1060, 32, util.int(c.adv.francs or 0), "ui18b", theme.gold)
    kit.text(1130, 14, "FAIR WARNING", "ui14", theme.dim)
    kit.text(1130, 32, util.int(c.adv.bank or 0) .. " in the bank", "ui18b", theme.teal)
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
                local done = c.adv.done[hk.room]
                kit.dot(x + 10, y + 10, 20, panels.COLORS[key] or theme.panel3)
                kit.picture(x + 1, y + 1, 18, 18, panels.face(key))
                kit.text(x + 28, y, p.char .. ": " .. hk.name .. ", in " .. util.lower_first(room.name)
                    .. (done and " (found)" or (c.adv.skipped[hk.room] and " (missed)" or "")), "ui14",
                    done and theme.green or (c.adv.skipped[hk.room] and theme.orange or theme.text), { w = w - 28, lines = 1 })
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
    kit.box(0, 0, kit.W, kit.H, theme.bg, { round = false })
    top_bar(app, prep)
    if prep.museum.boss then
        kit.text(COL_L, 84, "THE SHOWDOWN", "ui14", theme.red)
        kit.text(COL_L, 106, "Tonight isn't a run of rooms. It's one long scene with Euryale, and everything the party did "
            .. "on the way up is on her card.", "ui18", theme.text, { w = COL_LW })
        M.draw_map(app, COL_L, 230, COL_LW, 300)
        showdown(app, prep, COL_M, 84, COL_MW)
    else
        left_column(app, prep)
        M.draw_map(app, COL_M, 78, COL_MW, 228, { legend = true })
        rooms(app, prep, COL_M, 316, COL_MW, 892)
    end
    -- The friends, as on every prep board.
    local prep_view = util.lazy("game.ui.prep_view")
    kit.text(1196, 84, "THE TABLE", "ui14", theme.dim)
    if prep_view.empathy_meter then
        prep_view.empathy_meter(app)
    end
    local forecast = prep:forecast()
    for i, p in ipairs(c.players) do
        if prep_view.player_card then
            prep_view.player_card(app, prep, p, i, forecast)
        end
    end
end

return M
