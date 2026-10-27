-- The valley map on the prep board (the rebuild spec's first milestone, October 17): the places in
-- play, the roads between them, tonight's route numbered 1 to 3, and a coloured thread between
-- places that share a storyline the route moves. Click a place for its card beside the map, and
-- make it a stop. The model is game/model/valley.lua.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local util = require "game.model.util"
local content = require "game.model.content"
local valley = require "game.model.valley"
local places_mod = require "game.model.places"

local M = {}

M.X, M.Y, M.W, M.H = 364, 84, 536, 472
local PAD_X, PAD_TOP, PAD_BOTTOM = 34, 40, 46

local INK = theme.ink
local ROAD = kit.rgba("#b9a47c")
local ROAD_FAINT = kit.rgba("#b9a47c", 0.7)
local RIVER = kit.rgba("#8db0c0", 0.75)
local WOOD = kit.rgba("#6f8a55", 0.42)
local HILL = kit.rgba("#9a8460", 0.75)
local ROUTE = kit.rgba("#b07d22")
local STOP = kit.rgba("#e8b04a")
local GLOW = kit.rgba("#e08a4a", 0.55)
local CLEAR = kit.rgba("#000000", 0)

-- The map's state on the app, reset each week: which pin or place is open beside the map, and
-- which stop's scene card shows.
function M.state(app)
    local week = app.campaign.week
    if not app.valley or app.valley.week ~= week then
        app.valley = { week = week, open = nil, stop = 1 }
    end
    return app.valley
end

-- Which stop's scene card shows: the slot being filled, else the stop you picked.
function M.shown_stop(app, prep)
    local st = M.state(app)
    if app.sel and app.sel.scene then
        st.stop = app.sel.scene
    end
    return math.max(1, math.min(#prep.scenes, st.stop or 1))
end

function M.open_place(app, id)
    local st = M.state(app)
    st.open = id
    app.sel = nil
end

function M.show_stop(app, i)
    local st = M.state(app)
    st.open = nil
    st.stop = i
    if app.sel and app.sel.scene and app.sel.scene ~= i then
        app.sel = { scene = i, kind = app.sel.kind }
    end
end

local function to_px(n)
    local ix, iy = M.X + PAD_X, M.Y + PAD_TOP
    local iw, ih = M.W - 2 * PAD_X, M.H - PAD_TOP - PAD_BOTTOM
    return ix + n.x * iw, iy + n.y * ih
end
M.to_px = to_px

local function px_of(x, y)
    return to_px({ x = x, y = y })
end

-- A line from a to b with its ends pulled back from the pins.
local function trimmed(ax, ay, bx, by, ra, rb)
    local dx, dy = bx - ax, by - ay
    local d = math.sqrt(dx * dx + dy * dy)
    if d < ra + rb + 2 then
        return nil
    end
    return ax + dx / d * ra, ay + dy / d * ra, bx - dx / d * rb, by - dy / d * rb
end

local function dashed(x1, y1, x2, y2, thick, color, dash, gap)
    local dx, dy = x2 - x1, y2 - y1
    local d = math.sqrt(dx * dx + dy * dy)
    if d <= 0 then
        return
    end
    local t = 0
    while t < d do
        local e = math.min(d, t + dash)
        kit.line(x1 + dx * t / d, y1 + dy * t / d, x1 + dx * e / d, y1 + dy * e / d, thick, color)
        t = e + gap
    end
end

-- A gentle curve from a to b, bowed to one side by `bow` pixels, as short segments; dashed.
local function curve(ax, ay, bx, by, bow, thick, color)
    local mx, my = (ax + bx) / 2, (ay + by) / 2
    local dx, dy = bx - ax, by - ay
    local d = math.sqrt(dx * dx + dy * dy)
    if d <= 0 then
        return
    end
    local cx, cy = mx - dy / d * bow, my + dx / d * bow
    local steps = math.max(6, math.floor(d / 9))
    local px, py = ax, ay
    for k = 1, steps do
        local t = k / steps
        local u = 1 - t
        local x = u * u * ax + 2 * u * t * cx + t * t * bx
        local y = u * u * ay + 2 * u * t * cy + t * t * by
        if k % 2 == 1 then
            kit.line(px, py, x, y, thick, color)
        end
        px, py = x, y
    end
end

local function decor()
    local d = valley.data
    -- The river, from the hills to the sea.
    for k = 1, #d.river - 1 do
        local ax, ay = px_of(d.river[k][1], d.river[k][2])
        local bx, by = px_of(d.river[k + 1][1], d.river[k + 1][2])
        ay, by = math.max(ay, M.Y + 4), math.min(by, M.Y + M.H - 4)
        kit.line(ax, ay, bx, by, 7, RIVER)
        kit.dot(bx, by, 7, RIVER)
    end
    -- Woods: a few trees each.
    for _, w in ipairs(d.woods) do
        local x, y = px_of(w[1], w[2])
        kit.dot(x - 7, y + 2, 12, WOOD)
        kit.dot(x + 6, y + 1, 11, WOOD)
        kit.dot(x, y - 6, 13, WOOD)
    end
    -- Hills: little peaks.
    for _, h in ipairs(d.hills) do
        local x, y = px_of(h[1], h[2])
        kit.line(x - 11, y + 6, x, y - 5, 2.5, HILL)
        kit.line(x, y - 5, x + 11, y + 6, 2.5, HILL)
        kit.line(x + 4, y + 6, x + 12, y - 1, 2, HILL)
        kit.line(x + 12, y - 1, x + 19, y + 6, 2, HILL)
    end
end

-- Where a pin's name goes: its side, unless that runs into another name or off the map.
local function label_rect(n, px, py, side, font)
    local w, h = kit.width(n.name, font), kit.line_height(font)
    local gap = n.hub and 16 or 14
    if side == "l" then
        return px - gap - w, py - h / 2, w, h
    elseif side == "t" then
        return px - w / 2, py - gap - h, w, h
    elseif side == "b" then
        return px - w / 2, py + gap - 2, w, h
    end
    return px + gap, py - h / 2, w, h
end

local function overlaps(a, b)
    return a[1] < b[1] + b[3] and b[1] < a[1] + a[3] and a[2] < b[2] + b[4] and b[2] < a[2] + a[4]
end

local function inside_map(r)
    return r[1] >= M.X + 6 and r[1] + r[3] <= M.X + M.W - 6 and r[2] >= M.Y + 26 and r[2] + r[4] <= M.Y + M.H - PAD_BOTTOM + 8
end

local function place_labels(map)
    local taken = {}
    for _, n in ipairs(map.nodes) do
        local px, py = to_px(n)
        local hw = 14
        if #n.stops > 0 then
            -- A stop's numbered pill is wider than a pin.
            hw = math.max(15, (kit.width(table.concat(n.stops, ", "), "ui18b") + 16) / 2)
        end
        if n.cards > 0 then
            table.insert(taken, { px - hw, py - 24, hw + 24, 38 })   -- the pin and its badge
        else
            table.insert(taken, { px - hw, py - 14, hw * 2, 28 })
        end
    end
    local out = {}
    for _, n in ipairs(map.nodes) do
        local px, py = to_px(n)
        local font = n.hub and "ui18b" or "ui14"
        -- The first side that's clear; else the side that covers the least of what's there.
        local best, least
        for _, side in ipairs({ n.label, "r", "l", "b", "t" }) do
            local x, y, w, h = label_rect(n, px, py, side, font)
            local r = { x, y, w, h }
            if inside_map(r) then
                local covered = 0
                for _, t in ipairs(taken) do
                    if overlaps(r, t) then
                        covered = covered + (math.min(r[1] + r[3], t[1] + t[3]) - math.max(r[1], t[1]))
                            * (math.min(r[2] + r[4], t[2] + t[4]) - math.max(r[2], t[2]))
                    end
                end
                if covered == 0 then
                    best = r
                    break
                end
                if not least or covered < least then
                    best, least = r, covered
                end
            end
        end
        if not best then
            local x, y, w, h = label_rect(n, px, py, n.label, font)
            best = { math.max(M.X + 6, math.min(x, M.X + M.W - 6 - w)), y, w, h }
        end
        table.insert(taken, best)
        out[n.id] = { rect = best, font = font }
    end
    return out
end

local function legend(x, y)
    kit.dot(x + 8, y + 9, 18, STOP)
    kit.text(x + 8, y + 9, "1", "ui14", INK, { pivot = gui.PIVOT_CENTER })
    kit.text(x + 22, y, "Tonight's route", "ui14", theme.ink_dim)
    x = x + 22 + kit.width("Tonight's route", "ui14") + 18
    dashed(x, y + 9, x + 26, y + 9, 2.5, kit.rgba("#b0506a"), 5, 4)
    kit.text(x + 32, y, "A storyline", "ui14", theme.ink_dim)
    x = x + 32 + kit.width("A storyline", "ui14") + 18
    kit.dot(x + 8, y + 9, 20, GLOW)
    kit.dot(x + 8, y + 9, 10, INK)
    kit.text(x + 22, y, "Cold or owed", "ui14", theme.ink_dim)
    x = x + 22 + kit.width("Cold or owed", "ui14") + 18
    kit.dot(x + 8, y + 9, 13, INK)
    kit.dot(x + 8, y + 9, 7, theme.paper)
    kit.text(x + 22, y, "Not prepped", "ui14", theme.ink_dim)
end

-- The map itself.
function M.draw(app, prep)
    local st = M.state(app)
    local map = valley.map(app.campaign, prep)
    app.valley_map = map
    local shown = M.shown_stop(app, prep)
    kit.box(M.X, M.Y, M.W, M.H, theme.paper, { radius = 10 })
    kit.text(M.X + 14, M.Y + 10, "THE VALLEY", "ui14", theme.ink_dim)
    kit.text(M.X + 14 + kit.width("THE VALLEY", "ui14") + 12, M.Y + 10,
        "Click a place, then make it a stop.", "ui14", kit.rgba("#9a8a72"),
        { w = M.W - 150, lines = 1 })
    decor()
    -- Roads.
    for _, r in ipairs(map.roads) do
        local ax, ay = to_px(r.a)
        local bx, by = to_px(r.b)
        local x1, y1, x2, y2 = trimmed(ax, ay, bx, by, 10, 10)
        if x1 then
            if r.faint then
                dashed(x1, y1, x2, y2, 2, ROAD_FAINT, 4, 5)
            else
                kit.line(x1, y1, x2, y2, 3.5, ROAD)
            end
        end
    end
    -- Threads: storylines the route moves, to the other places they're at.
    local pair_count = {}
    for _, t in ipairs(map.threads) do
        local key = t.a.id < t.b.id and (t.a.id .. "|" .. t.b.id) or (t.b.id .. "|" .. t.a.id)
        pair_count[key] = (pair_count[key] or 0) + 1
        local k = pair_count[key]
        local ax, ay = to_px(t.a)
        local bx, by = to_px(t.b)
        local x1, y1, x2, y2 = trimmed(ax, ay, bx, by, 13, 13)
        if x1 then
            local bow = 14 + (k - 1) * 12
            curve(x1, y1, x2, y2, bow, 2.5, kit.rgba(t.color))
        end
    end
    -- The route, stop to stop.
    local legs = {}
    for _, r in ipairs(map.route) do
        if r.n and not r.open then
            legs[r.i] = legs[r.i] or r.n
        end
    end
    -- (Along the roads where a road goes there, else as the crow flies.)
    for i = 1, #prep.scenes - 1 do
        local a, b = legs[i], legs[i + 1]
        if a and b and a ~= b then
            local path = valley.road_path(app.campaign, a.id, b.id) or { a.id, b.id }
            for k = 1, #path - 1 do
                local ax, ay = px_of(valley.pos(app.campaign, path[k]))
                local bx, by = px_of(valley.pos(app.campaign, path[k + 1]))
                local ra = (k == 1) and 17 or 0
                local rb = (k == #path - 1) and 17 or 0
                local x1, y1, x2, y2 = trimmed(ax, ay, bx, by, ra, rb)
                if x1 then
                    kit.line(x1, y1, x2, y2, 4, ROUTE)
                    if k < #path - 1 then
                        kit.dot(x2, y2, 4, ROUTE)
                    end
                end
            end
        end
    end
    -- Pins, with their names; each is a button (pin and name together).
    local labels = place_labels(map)
    local open_node = st.open and valley.node_of(st.open)
    -- (Names first, pins over them: a click on a pin always opens that pin.)
    for _, n in ipairs(map.nodes) do
        local lab = labels[n.id].rect
        kit.button(lab[1] - 4, lab[2] - 2, lab[3] + 8, lab[4] + 4, "", function()
            M.open_place(app, n.id)
            app.refresh()
        end, { color = CLEAR, hover = kit.rgba("#000000", 0.07), radius = 6 })
    end
    for _, n in ipairs(map.nodes) do
        local px, py = to_px(n)
        kit.button(px - 15, py - 15, 30, 30, "", function()
            M.open_place(app, n.id)
            app.refresh()
        end, { color = CLEAR, hover = kit.rgba("#000000", 0.1), radius = 12, key = "pin_" .. n.id })
    end
    for _, n in ipairs(map.nodes) do
        local px, py = to_px(n)
        local selected = (open_node == n.id) or (not st.open and #n.stops > 0 and util.contains(n.stops, shown))
        if selected then
            kit.dot(px, py, #n.stops > 0 and 46 or 34, kit.rgba("#e8b04a", 0.45))
        end
        if n.glow == "cold" or n.glow == "loose" or #(n.owed or {}) > 0 then
            kit.dot(px, py, #n.stops > 0 and 42 or 30, GLOW)
        end
        if #n.stops > 0 then
            local label = {}
            for _, i in ipairs(n.stops) do
                table.insert(label, util.int(i))
            end
            local text = table.concat(label, ", ")
            local w = math.max(30, kit.width(text, "ui18b") + 16)
            kit.box(px - w / 2, py - 15, w, 30, STOP, { radius = 15 })
            if n.only_open then
                -- An open scene's spot: the players may come here, or go to another.
                kit.box(px - w / 2 + 3, py - 12, w - 6, 24, theme.paper, { radius = 12 })
            end
            kit.text(px, py, text, "ui18b", INK, { pivot = gui.PIVOT_CENTER })
        elseif n.hub then
            -- A town: a little house.
            kit.dot(px, py, 30, theme.paper)
            kit.icon(px - 12, py - 13, 24, "house", INK)
        elseif n.lead then
            kit.dot(px, py, 17, INK)
            kit.dot(px, py, 10, theme.paper)
        else
            kit.dot(px, py, 16, INK)
        end
        if n.cards > 0 then
            -- Cards in your hand that happen here.
            local bx, by = px + 13, py - 13
            kit.dot(bx, by, 19, kit.rgba("#4f7f3a"))
            kit.text(bx, by, util.int(n.cards), "ui14", theme.text, { pivot = gui.PIVOT_CENTER })
        end
        local lab = labels[n.id]
        kit.text(lab.rect[1], lab.rect[2], n.name, lab.font, INK)
    end
    legend(M.X + 14, M.Y + M.H - 30)
    -- What a click on the map or a place's card just did, over the map's foot (the first-prep tips
    -- sit over the drawer, where the board's notes usually show).
    if app.toast and app.toast_where == "map" then
        local text = app.toast
        local col = app.toast_tone == "info" and theme.teal or theme.orange
        app.toast, app.toast_tone, app.toast_where = nil, nil, nil
        local maxw = M.W - 60
        local tw = math.min(kit.width(text, "ui14"), maxw)
        local th = kit.text_height(text, "ui14", maxw)
        local bw, bh = tw + 32, th + 12
        local cx, cy = M.X + M.W / 2, M.Y + 54
        kit.box(cx - bw / 2, cy - bh / 2, bw, bh, theme.bg, { radius = math.min(bh / 2, 14) })
        kit.box(cx - bw / 2, cy - bh / 2, bw, 2, col, { round = false })
        kit.text(cx, cy - bh / 2 + 6, text, "ui14", col, { pivot = gui.PIVOT_N, w = maxw })
    end
end

-- The open place's card, beside the map (where the stop's scene card sits otherwise). ---------

local SIDE_X, SIDE_Y, SIDE_W, SIDE_H = 920, 84, 256, 472
M.SIDE_X = SIDE_X

local function kind_label(c)
    return string.upper(content.kind_names[c.kind] or c.kind)
end

-- The stop to offer first: the first one with no place, else the one showing.
local function next_free_stop(app, prep)
    -- In prep's steps, the stop the step is about (October 26).
    if app.route_stop and prep.scenes[app.route_stop] then
        return app.route_stop
    end
    for i, s in ipairs(prep.scenes) do
        if not s.open and not s.slots.location and not s.module then
            return i
        end
    end
    return M.shown_stop(app, prep)
end

local function status_line(app, prep, c)
    local stops = valley.stops_at(prep, c.id)
    if #stops > 0 then
        local list = {}
        for _, i in ipairs(stops) do
            table.insert(list, util.int(i))
        end
        return (#stops == 1 and "Stop " or "Stops ") .. table.concat(list, " and ") .. " of tonight's route.", theme.ink
    end
    local why = valley.visible(app.campaign, prep)[c.id]
    local cost = prep:cost_of(c)
    if places_mod.is_known(app.campaign, c.id) then
        return "One of your places: free to use again.", theme.ink
    elseif why == "lead" then
        return "A card in your hand happens here. " .. util.int(cost) .. "h to prep.", theme.ink
    elseif why == "owed" then
        return "Not prepped yet. " .. util.int(cost) .. "h to prep.", theme.ink
    end
    return "In your hand. " .. util.int(cost) .. "h to prep.", theme.ink
end

local function storyline_rows(app, prep, id, x, y, w, limit)
    local sl = require "game.model.storylines"
    local marks = require "game.ui.lore_marks"
    local ids = valley.storylines_at(app.campaign, prep, id)
    if #ids == 0 or y + 22 + 20 > limit then
        return y
    end
    kit.text(x, y, "STORYLINES HERE", "ui14", theme.ink_dim)
    y = y + 22
    for _, sid in ipairs(ids) do
        local d = sl.def(app.campaign, sid)
        if d then
            local h = sl.heat(app.campaign, sid)
            local text = util.capitalize(d.short or d.name) .. ": " .. (valley.HEAT_WORDS[h] or h)
            local th = kit.text_height(text, "ui14", w - 24)
            if y + th > limit then
                break
            end
            if not marks.storyline(app, sid, x, y + 1, 16, true) then
                kit.dot(x + 8, y + 9, 12, kit.rgba(d.color or "#e8b04a"))
            end
            local hot = (h == "cold" or h == "loose" or h == "cooling")
            kit.text(x + 24, y, text, "ui14", hot and kit.rgba("#9a4a1a") or theme.ink, { w = w - 24 })
            y = y + th + 6
        end
    end
    return y + 4
end

local function place_card(app, prep, id)
    local st = M.state(app)
    local x, y, w = SIDE_X, SIDE_Y, SIDE_W
    local c = content.components[id]
    kit.box(x, y, w, SIDE_H, theme.paper, { radius = 10 })
    local hub = valley.hub_of(id)
    if hub then
        kit.button(x + 8, y + 6, 150, 24, "< " .. valley.name(hub), function()
            st.open = hub
            app.refresh()
        end, { font = "ui14", color = CLEAR, hover = kit.rgba("#000000", 0.07), text_color = theme.ink_dim, align = "left",
               pad_y = 3, key = "place_back" })
    else
        kit.text(x + 12, y + 9, "PLACE", "ui14", theme.ink_dim)
    end
    kit.button(x + w - 34, y + 6, 26, 24, "x", function()
        st.open = nil
        app.refresh()
    end, { font = "ui14", color = CLEAR, hover = kit.rgba("#000000", 0.07), text_color = theme.ink_dim, key = "place_close" })
    local cy = y + 36
    kit.text(x + 14, cy, c.name, "ui22b", INK, { w = w - 28, lines = 2 })
    cy = cy + math.min(kit.text_height(c.name, "ui22b", w - 28), 2 * kit.line_height("ui22b")) + 4
    local tags = valley.tag_line(c)
    if tags ~= "" then
        kit.text(x + 14, cy, tags, "ui14", theme.ink_dim, { w = w - 28, lines = 1 })
        cy = cy + 22
    end
    -- On a planned stop, and worth a handout: a row for it above the route buttons.
    local on_stops = valley.stops_at(prep, id)
    local handout = #on_stops > 0 and not prep.scenes[on_stops[1]].open
        and require("game.model.handouts").worth_it(app.campaign, c)
    local limit = y + SIDE_H - 120 - (handout and 36 or 0)      -- the route buttons sit below
    local line, col = status_line(app, prep, c)
    kit.text(x + 14, cy, line, "ui14", col, { w = w - 28, lines = 2 })
    cy = cy + kit.text_height(line, "ui14", w - 28) + 10
    -- A pull you parked here: whose, and by when.
    for _, o in ipairs(require("game.model.pulls").owed_at(app.campaign, prep, id)) do
        local p = app.campaign:player(o.key)
        local owed = "Owed to " .. (p and p.name or "a player") .. ": you parked " .. o.name .. " in session "
            .. util.int(o.week) .. ". Make it a stop by session " .. util.int(o.due) .. "."
        local oh = kit.text_height(owed, "ui14", w - 28)
        if cy + oh <= limit then
            kit.text(x + 14, cy, owed, "ui14", kit.rgba("#9a4a1a"), { w = w - 28 })
            cy = cy + oh + 8
        end
    end
    -- The cards in your hand that happen here.
    local here = valley.cards_for(prep, id)
    if #here > 0 and cy + 22 + 44 <= limit then
        kit.text(x + 14, cy, "HAPPENS HERE", "ui14", theme.ink_dim)
        cy = cy + 22
        local at = valley.stops_at(prep, id)
        for k, hc in ipairs(here) do
            if cy + 44 > limit or k > 3 then
                kit.text(x + w - 14, cy - 20, "+" .. util.int(#here - k + 1) .. " more", "ui14", theme.ink_dim,
                    { pivot = gui.PIVOT_NE })
                break
            end
            -- On a stop, a click puts the card there; otherwise the place has to be a stop first.
            local i = at[1]
            kit.button(x + 12, cy, w - 24, 44, "", function()
                if not i then
                    app.toast = "Make " .. util.lower_first(c.name) .. " a stop first, then its cards go on that stop."
                elseif prep.scenes[i].open then
                    app.toast = "Stop " .. util.int(i) .. " is an open scene: the players choose, so it takes places only."
                else
                    local ok, why = prep:place(i, hc.id)
                    if ok then
                        require("game.ui.story_log_view").on_placed(app, hc)
                        app.toast, app.toast_tone = "\"" .. hc.name .. "\" is on stop " .. util.int(i) .. ".", "info"
                    else
                        app.toast = why
                    end
                end
                app.toast_where = "map"
                app.refresh()
            end, { color = theme.paper_dim, hover = kit.rgba("#f6edd6"), radius = 7, key = "here_" .. hc.id })
            kit.text(x + 22, cy + 4, kind_label(hc), "ui14", theme.ink_dim)
            if i and not prep.scenes[i].open then
                local tag = prep.scenes[i].slots[hc.kind] and ("swap onto stop " .. util.int(i)) or ("+ stop " .. util.int(i))
                kit.text(x + w - 22, cy + 4, tag, "ui14", kit.rgba("#2f6f3a"), { pivot = gui.PIVOT_NE })
            end
            kit.text(x + 22, cy + 21, kit.ellipsize(hc.name, "ui14", w - 48), "ui14", INK)
            cy = cy + 50
        end
        cy = cy + 4
    end
    cy = storyline_rows(app, prep, id, x + 14, cy, w - 28, limit)
    -- What it's like, and what kind of scene it suits, where there's room.
    if c.fits and #c.fits > 0 then
        local names = {}
        for k, t in ipairs(c.fits) do
            if k <= 3 and content.scenes[t] then
                table.insert(names, content.scenes[t].name)
            end
        end
        local suits = "Suits " .. string.lower(table.concat(names, ", ")) .. "."
        local h = kit.text_height(suits, "ui14", w - 28)
        if cy + h <= limit then
            kit.text(x + 14, cy, suits, "ui14", theme.ink_dim, { w = w - 28 })
            cy = cy + h + 8
        end
    end
    if c.line then
        local lh = kit.line_height("ui14")
        local lines = math.min(3, math.floor((limit - cy) / lh))
        if lines >= 2 then
            kit.text(x + 14, cy, c.line, "ui14", INK, { w = w - 28, lines = lines })
        end
    end
    -- Put it on the route.
    local by = y + SIDE_H - 112
    local n = next_free_stop(app, prep)
    local stops = valley.stops_at(prep, id)
    local function make(i)
        local ok, why = valley.make_stop(prep, i, id)
        if ok then
            M.show_stop(app, i)
            app.toast, app.toast_tone = c.name .. " is stop " .. util.int(i) .. ".", "info"
        else
            app.toast = why
        end
        app.toast_where = "map"
        app.refresh()
    end
    if #stops == 0 then
        local label = prep.scenes[n].slots.location and ("Swap it in at stop " .. util.int(n)) or ("Make it stop " .. util.int(n))
        kit.button(x + 12, by, w - 24, 40, label, function()
            make(n)
        end, { color = theme.go, hover = theme.go_hover, key = "make_stop" })
    else
        kit.button(x + 12, by, w - 24, 40, "Open stop " .. util.int(stops[1]), function()
            M.show_stop(app, stops[1])
            if app.route_stop then
                util.lazy("game.ui.prep_steps").go(app, "route_" .. stops[1])    -- (lazy: it draws this map)
            end
            app.refresh()
        end, { color = theme.go, hover = theme.go_hover, key = "open_stop", enabled = stops[1] ~= app.route_stop })
    end
    kit.text(x + 14, by + 50, "Or stop:", "ui14", theme.ink_dim)
    for i = 1, #prep.scenes do
        local on = util.contains(stops, i)
        local bx = x + 80 + (i - 1) * 56
        kit.button(bx, by + 46, 48, 28, util.int(i), function()
            if on then
                M.show_stop(app, i)
                app.refresh()
            else
                make(i)
            end
        end, { font = "ui18b", color = on and theme.go or theme.button, hover = theme.button_hover,
               key = "make_stop_" .. util.int(i) })
    end
    if handout then
        -- A handout of the place (game/model/handouts.lua), when it's worth one: here now that the
        -- place card is where a stop's place is set (October 20).
        local handouts = require "game.model.handouts"
        local made = prep.handouts and prep.handouts[id]
        kit.button(x + 12, by - 34, w - 24, 28, made and "Handout made (undo)" or ("Make a handout  " .. util.int(handouts.data.COST) .. "h"),
            function()
                local ok, why = handouts.toggle(prep, id)
                if not ok then
                    app.toast = why
                    app.toast_where = "map"
                end
                app.refresh()
            end, { font = "ui14", color = made and theme.go or theme.button, hover = theme.button_hover, pad_y = 4,
                   key = "handout_toggle",
                   enabled = made or (handouts.count(prep) < handouts.data.PER_WEEK and prep:left() >= handouts.data.COST) })
    end
    if #stops > 0 then
        kit.button(x + 12, by + 80, w - 24, 26, "Take it off the route", function()
            for _, i in ipairs(stops) do
                local s = prep.scenes[i]
                if s.open then
                    prep:remove_spot(i, id)
                else
                    valley.clear_stop(prep, i)
                end
            end
            app.refresh()
        end, { font = "ui14", color = CLEAR, hover = kit.rgba("#000000", 0.07), text_color = theme.ink_dim, key = "unstop" })
    end
end

-- A town's card: the places in it that are in play.
local function hub_card(app, prep, hub)
    local st = M.state(app)
    local x, y, w = SIDE_X, SIDE_Y, SIDE_W
    local n = app.valley_map and app.valley_map.by_id[hub]
    kit.box(x, y, w, SIDE_H, theme.paper, { radius = 10 })
    kit.text(x + 12, y + 9, "TOWN", "ui14", theme.ink_dim)
    kit.button(x + w - 34, y + 6, 26, 24, "x", function()
        st.open = nil
        app.refresh()
    end, { font = "ui14", color = CLEAR, hover = kit.rgba("#000000", 0.07), text_color = theme.ink_dim, key = "place_close" })
    kit.text(x + 14, y + 36, valley.name(hub), "ui22b", INK)
    local about = valley.data.hubs[hub].about
    kit.text(x + 14, y + 66, about, "ui14", theme.ink_dim, { w = w - 28, lines = 2 })
    local cy = y + 72 + kit.text_height(about, "ui14", w - 28) + 6
    local list = n and n.places or {}
    if #list == 0 then
        kit.text(x + 14, cy, "Nothing here in play this week.", "ui14", theme.ink_dim, { w = w - 28 })
        return
    end
    kit.text(x + 14, cy, "PLACES IN PLAY", "ui14", theme.ink_dim)
    cy = cy + 22
    local room = math.floor((y + SIDE_H - 12 - cy) / 44)
    for k, c in ipairs(list) do
        if k > room then
            kit.text(x + 14, cy, "+" .. util.int(#list - room) .. " more", "ui14", theme.ink_dim)
            break
        end
        local stops = valley.stops_at(prep, c.id)
        local tag
        if #stops > 0 then
            tag = "Stop " .. util.int(stops[1])
        elseif places_mod.is_known(app.campaign, c.id) then
            tag = "yours"
        else
            tag = util.int(prep:cost_of(c)) .. "h"
        end
        kit.button(x + 10, cy, w - 20, 40, "", function()
            st.open = c.id
            app.refresh()
        end, { color = #stops > 0 and kit.rgba("#e8c77a") or theme.paper_dim, hover = kit.rgba("#f6edd6"), key = "hub_place_" .. c.id })
        local mine = valley.cards_for(prep, c.id)
        if #mine > 0 then
            kit.dot(x + 26, cy + 20, 19, kit.rgba("#4f7f3a"))
            kit.text(x + 26, cy + 20, util.int(#mine), "ui14", theme.text, { pivot = gui.PIVOT_CENTER })
        end
        local name = util.capitalize(c.short or c.name)
        local font = kit.width(name, "ui18") <= w - 104 and "ui18" or "ui14"
        kit.text(x + 42, cy + (font == "ui18" and 10 or 12), kit.ellipsize(name, font, w - 104), font, INK)
        kit.text(x + w - 22, cy + 12, tag, "ui14", theme.ink_dim, { pivot = gui.PIVOT_NE })
        cy = cy + 44
    end
end

-- What sits beside the map: the open place's card, or nil (then the stop's scene card shows).
function M.side(app, prep)
    local st = M.state(app)
    if not st.open then
        return false
    end
    if valley.is_hub(st.open) then
        hub_card(app, prep, st.open)
    elseif content.components[st.open] then
        place_card(app, prep, st.open)
    else
        st.open = nil
        return false
    end
    return true
end

return M
