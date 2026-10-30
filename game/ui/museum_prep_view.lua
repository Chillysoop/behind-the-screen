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
        { "garden", 0.17, 0.0, 1.0, 0.40 }, { "street", 0.0, 0.08, 0.15, 0.32 },
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
        kit.box(pond[1], pond[2], pond[3], pond[4], kit.rgba("#3a6f86", 0.55), { radius = 12 })
    end
    local label = r.map or (string.gsub(r.name, "^The ", ""))
    local font = "ui14"
    if kit.width(label, font) > w - 6 then
        label = kit.ellipsize(label, font, w - 6)
    end
    local ty = pond and (pond[2] + pond[4] + 2) or (y + math.max(1, (h - 18) / 2))
    kit.text(x + w / 2, ty, label, font, (s == "skipped") and theme.faint or theme.text, { pivot = gui.PIVOT_N })
    if s == "done" and w > 34 then
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
        if here == id then
            party_dots(c, rx + rw - 34, ry + rh - 8)
        end
    end
    if fl.down then
        local dx, dy, dw, dh = rect(fl.down)
        kit.box(dx, dy, dw, dh, kit.rgba("#000000", 0.25), { radius = 4 })
        kit.text(dx + dw / 2, dy + dh / 2 - 9, "down", "ui14", theme.faint, { pivot = gui.PIVOT_N })
    end
end

function M.draw_map(app, x, y, w, h, opts)
    local c = app.campaign
    opts = opts or {}
    kit.box(x, y, w, h, kit.rgba("#000000", 0.22), { radius = 10 })
    for _, f in ipairs(floor_frames(x, y, w, h, opts)) do
        draw_floor(app, c, f.fl, f.x, f.y, f.w, f.h)
    end
    -- What the DM has locked (the tie-and-lock editor).
    if c.adv and c.adv.locks and #c.adv.locks > 0 then
        M.draw_locks(app, M.plan(x, y, w, h, opts))
    end
    if opts.legend then
        kit.text(x + 12, y + h - 22, "Gold: tonight.  Green: done.  Brown: walked past.  Teal: where they are.  "
            .. "Faces: why a hero came.", "ui14", theme.faint, { w = w - 24, lines = 1 })
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
    local sides = map_repo.side_rooms_off(c, id)
    local sum = r.sum
    if #sides > 0 then
        local names = {}
        for _, sid in ipairs(sides) do
            table.insert(names, c.adv.side_rooms[sid].name)
        end
        sum = "Side room off here: " .. util.join_names(names) .. ". " .. sum
    end
    kit.text(x + 18, y + 30, sum, "ui14", #sides > 0 and theme.gold or theme.dim, { w = w - 220, lines = 1 })
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
    kit.text(x + w - 298, y, "The party picks the way. Prep where they'll go.", "ui14", theme.faint,
        { pivot = gui.PIVOT_NE })
    kit.button(x + w - 140, y - 6, 140, 26, "All maps", function()
        if app.open_maps then
            app.open_maps()
        end
    end, { font = "ui14", key = "open_maps" })
    -- The tie-and-lock editor (game/ui/ties_view.lua): lock a way or a card, tie one thing to another.
    local n = #(app.campaign.adv.locks or {}) + #(app.campaign.adv.ties or {})
    kit.button(x + w - 140 - 8 - 140, y - 6, 140, 26, n > 0 and ("Ties and locks (" .. util.int(n) .. ")") or "Ties and locks",
        function()
            if app.open_ties then
                app.open_ties()
            end
        end, { font = "ui14", color = n > 0 and theme.go or nil, hover = n > 0 and theme.go_hover or nil, key = "open_ties" })
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
    -- What the answers between sessions made come true opens the DM's locks (ties.lua).
    museum_week.sync_ties(prep, c)
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
